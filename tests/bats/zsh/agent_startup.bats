#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	skip_if_command_missing zsh
	REPO_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	TEST_HOME="${BATS_TEST_TMPDIR}/home"
	mkdir -p "$TEST_HOME/dotfiles" "$TEST_HOME/.local/bin" "$TEST_HOME/.npm-global/bin" "$TEST_HOME/.cache"
	cp -r "$REPO_DIR/zsh" "$TEST_HOME/dotfiles/"
	cp "$REPO_DIR/zshrc" "$TEST_HOME/.zshrc"
	[[ ! -f "$REPO_DIR/zshenv" ]] || cp "$REPO_DIR/zshenv" "$TEST_HOME/.zshenv"
	for cli in uv claude chezmoi; do
		printf '#!/bin/sh\nexit 0\n' >"$TEST_HOME/.local/bin/$cli"
		chmod +x "$TEST_HOME/.local/bin/$cli"
	done
	printf '#!/bin/sh\nexit 0\n' >"$TEST_HOME/.npm-global/bin/codex"
	chmod +x "$TEST_HOME/.npm-global/bin/codex"
	# Fail loudly if any interactive-only startup runs without a terminal.
	mkdir -p "$TEST_HOME/.oh-my-zsh" "$TEST_HOME/.nvm"
	printf 'print OMZ_LOADED\n' >"$TEST_HOME/.oh-my-zsh/oh-my-zsh.sh"
	printf 'print NVM_LOADED\n' >"$TEST_HOME/.nvm/nvm.sh"
	printf 'print LOCAL_LOADED\n' >"$TEST_HOME/.zshrc.local"
	printf 'print P10K_LOADED\n' >"$TEST_HOME/.p10k.zsh"
	printf 'print INSTANT_LOADED\n' >"$TEST_HOME/.cache/p10k-instant-prompt-$(id -un).zsh"
}

@test "agent shells resolve user CLIs with minimal inherited PATH and no startup output" {
	for mode in -c -lc -lic; do
		run env -i HOME="$TEST_HOME" PATH=/usr/bin:/bin TERM=dumb /usr/bin/zsh "$mode" '
			[[ ! -t 0 && ! -t 1 && ! -t 2 ]] || exit 10
			for cli in uv claude chezmoi; do
				[[ $(command -v "$cli") == "$HOME/.local/bin/$cli" ]] || exit 11
			done
			[[ $(command -v codex) == "$HOME/.npm-global/bin/codex" ]] || exit 12
			for cli in gh node; do
				[[ ! -x /usr/bin/$cli ]] || [[ $(command -v "$cli") == /usr/bin/$cli ]] || exit 13
			done
			print PASS
		' </dev/null
		[[ "$status" -eq 0 && "$output" == PASS ]]
	done
}

@test "minimal PATH is idempotent, deduplicated and inherited by child processes" {
	run env -i HOME="$TEST_HOME" PATH=/usr/bin:/bin:/usr/bin:/opt/agent:/opt/agent /usr/bin/zsh -c '
		before=$PATH
		source "$HOME/.zshenv"
		[[ $PATH == $before && ${#path} == ${#${(u)path}} ]] || exit 1
		[[ $path[1] == "$HOME/.local/bin" && $path[2] == "$HOME/.npm-global/bin" ]] || exit 2
		[[ ${path[(Ie)/opt/agent]} -gt 0 ]] || exit 3
		[[ $(/bin/sh -c "command -v uv") == "$HOME/.local/bin/uv" ]] || exit 4
		print PASS
	'
	[[ "$status" -eq 0 && "$output" == PASS ]]
}

@test "interactive terminal still loads instant prompt, NVM, OMZ, p10k and local config" {
	skip_if_command_missing python3
	run python3 - "$TEST_HOME" <<'PY'
import errno
import os
import pty
import select
import sys
import time

pid, fd = pty.fork()
if pid == 0:
    os.execve('/usr/bin/zsh', ['zsh', '-lic', 'print TERMINAL_OK'],
              {'HOME': sys.argv[1], 'PATH': '/usr/bin:/bin', 'TERM': 'xterm-256color'})
output = b''
deadline = time.monotonic() + 15
try:
    while True:
        if time.monotonic() > deadline:
            os.kill(pid, 9)
            raise AssertionError('terminal startup timed out')
        if not select.select([fd], [], [], 0.1)[0]:
            continue
        try:
            chunk = os.read(fd, 65536)
        except OSError as error:
            if error.errno != errno.EIO:
                raise
            break
        if not chunk:
            break
        output += chunk
finally:
    os.close(fd)
_, status = os.waitpid(pid, 0)
text = output.decode(errors='replace')
assert status == 0, text
for marker in ('INSTANT_LOADED', 'NVM_LOADED', 'OMZ_LOADED', 'P10K_LOADED', 'LOCAL_LOADED', 'TERMINAL_OK'):
    assert marker in text, text
assert text.index('INSTANT_LOADED') < text.index('OMZ_LOADED'), text
PY
	[[ "$status" -eq 0 ]]
}

@test "Chezmoi manages zshenv, refuses custom content and preserves authorized backups" {
	skip_if_command_missing chezmoi
	TEST_HOME="$BATS_TEST_TMPDIR/chezmoi-home"
	mkdir -p "$TEST_HOME/dotfiles"
	local source_dir="$BATS_TEST_TMPDIR/source"
	mkdir -p "$source_dir/.chezmoiscripts"
	cp "$REPO_DIR/symlink_dot_zshenv.tmpl" "$REPO_DIR/.chezmoiignore" "$source_dir/"
	cp "$REPO_DIR/.chezmoiscripts/run_before_00_backup_rc_files.sh.tmpl" "$source_dir/.chezmoiscripts/"
	cp "$REPO_DIR/zshenv" "$TEST_HOME/dotfiles/zshenv"
	rm -f "$TEST_HOME/.zshenv"
	run env HOME="$TEST_HOME" chezmoi --source="$source_dir" --destination="$TEST_HOME" apply
	[[ "$status" -eq 0 ]]
	[[ $(readlink "$TEST_HOME/.zshenv") == "$TEST_HOME/dotfiles/zshenv" ]]
	run env HOME="$TEST_HOME" chezmoi --source="$source_dir" --destination="$TEST_HOME" apply
	[[ "$status" -eq 0 ]]
	[[ -z $(find "$TEST_HOME" -name '.zshenv.backup.*' -print) ]]
	rm "$TEST_HOME/.zshenv"
	printf '# custom startup\n' >"$TEST_HOME/.zshenv"
	run env -u ZSH_RC_APPLY HOME="$TEST_HOME" chezmoi --source="$source_dir" --destination="$TEST_HOME" apply
	[[ "$status" -ne 0 && "$output" == *ABORT* ]]
	[[ $(cat "$TEST_HOME/.zshenv") == '# custom startup' ]]
	run env HOME="$TEST_HOME" ZSH_RC_APPLY=1 chezmoi --source="$source_dir" --destination="$TEST_HOME" apply --force
	[[ "$status" -eq 0 ]]
	[[ $(readlink "$TEST_HOME/.zshenv") == "$TEST_HOME/dotfiles/zshenv" ]]
	[[ $(cat "$TEST_HOME"/.zshenv.backup.*) == '# custom startup' ]]
}
