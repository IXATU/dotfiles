#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALLER="${DOTFILES_DIR}/scripts/install-claude-code.sh"
	setup_temp_dir
	export HOME="${TEST_TEMP_DIR}/home"
	export TMPDIR="${TEST_TEMP_DIR}/tmp"
	export CLAUDE_TEST_CALLS="${TEST_TEMP_DIR}/calls"
	export PATH="${TEST_TEMP_DIR}/bin:/usr/bin:/bin"
	mkdir -p "$HOME/.claude" "$TMPDIR" "${TEST_TEMP_DIR}/bin"
	cat >"${TEST_TEMP_DIR}/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "$*" >>"$CLAUDE_TEST_CALLS"
[[ "$*" == *https://claude.ai/install.sh* ]] || exit 90
while [[ "$1" != -o ]]; do shift; done
target="$2"
case "${CLAUDE_TEST_DOWNLOAD:-ok}" in
empty) : >"$target"; exit 0 ;;
invalid) printf 'if then\n' >"$target"; exit 0 ;;
network) exit 22 ;;
no-binary) printf 'exit 0\n' >"$target"; exit 0 ;;
failed-install) printf 'exit 42\n' >"$target"; exit 0 ;;
esac
cat >"$target" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == stable ]]
printf 'native %s\n' "$*" >>"$CLAUDE_TEST_CALLS"
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/claude" <<'CLAUDE'
#!/usr/bin/env bash
[[ "$1" == --version ]] || exit 91
printf '2.1.0 (Claude Code)\n'
CLAUDE
chmod +x "$HOME/.local/bin/claude"
INSTALL
CURL
	chmod +x "${TEST_TEMP_DIR}/bin/curl"
}

teardown() {
	teardown_temp_dir
}

@test "Claude native stable bootstrap ignores settings-only directory and cleans temporary installer" {
	run bash "$INSTALLER"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *'2.1.0 (Claude Code)'* ]]
	[[ -x "$HOME/.local/bin/claude" ]]
	grep -qx 'native stable' "$CLAUDE_TEST_CALLS"
	[[ -z "$(ls -A "$TMPDIR")" ]]
	[[ ! -e "$HOME/.bashrc" && ! -e "$HOME/.zshrc" ]]
	# Repeated bootstrap finds the native executable even outside PATH.
	run bash "$INSTALLER"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *preserving* ]]
	[[ "$(wc -l <"$CLAUDE_TEST_CALLS")" -eq 2 ]]
}

@test "Claude preserves working PATH installation without download or native replacement" {
	printf '#!/usr/bin/env bash\necho existing-version\n' >"${TEST_TEMP_DIR}/bin/claude"
	chmod +x "${TEST_TEMP_DIR}/bin/claude"
	run bash "$INSTALLER"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *existing-version*preserving* ]]
	[[ ! -e "$CLAUDE_TEST_CALLS" && ! -e "$HOME/.local" ]]
}

@test "Claude broken existing executable fails clearly without reinstalling" {
	printf '#!/usr/bin/env bash\nexit 42\n' >"${TEST_TEMP_DIR}/bin/claude"
	chmod +x "${TEST_TEMP_DIR}/bin/claude"
	run bash "$INSTALLER"
	[[ "$status" -ne 0 ]]
	[[ "$output" == *'failed --version'* ]]
	[[ ! -e "$CLAUDE_TEST_CALLS" ]]
}

@test "Claude missing dry run via flag and environment never downloads or writes" {
	local option
	for option in flag env; do
		if [[ "$option" == flag ]]; then
			run bash "$INSTALLER" --dry-run
		else
			run env DRY_RUN=1 bash "$INSTALLER"
		fi
		[[ "$status" -eq 0 ]]
		[[ "$output" == *'[DRY_RUN]'*'stable'* ]]
		[[ ! -e "$CLAUDE_TEST_CALLS" && ! -e "$HOME/.local" ]]
		[[ -z "$(ls -A "$TMPDIR")" ]]
	done
}

@test "Claude installed dry run preserves working CLI with no download" {
	printf '#!/usr/bin/env bash\necho existing-version\n' >"${TEST_TEMP_DIR}/bin/claude"
	chmod +x "${TEST_TEMP_DIR}/bin/claude"
	run bash "$INSTALLER" --dry-run
	[[ "$status" -eq 0 && "$output" == *preserving* ]]
	run env DRY_RUN=1 bash "$INSTALLER"
	[[ "$status" -eq 0 && "$output" == *preserving* ]]
	[[ ! -e "$CLAUDE_TEST_CALLS" && ! -e "$HOME/.local" ]]
	[[ -z "$(ls -A "$TMPDIR")" ]]
}

@test "Claude rejects empty invalid or failed downloads and cleans temporary files" {
	local mode
	for mode in empty invalid network failed-install no-binary; do
		run env CLAUDE_TEST_DOWNLOAD="$mode" bash "$INSTALLER"
		[[ "$status" -ne 0 && "$output" == *FAIL* ]]
		[[ ! -e "$HOME/.local/bin/claude" ]]
		[[ -z "$(ls -A "$TMPDIR")" ]]
	done
}

@test "Claude Make bootstrap stays opt-in and workspace orders Claude before Herdr even with parallel make" {
	run make -s -C "$DOTFILES_DIR" -j4 install-ai-workspace DRY_RUN=1
	[[ "$status" -eq 0 ]]
	[[ "$output" == *'claude.ai/install.sh'*'install-herdr'* ]]
	[[ ! -e "$CLAUDE_TEST_CALLS" && ! -e "$HOME/.local" ]]
	run grep -E '^install:' "${DOTFILES_DIR}/install.mk"
	[[ "$output" != *install-claude-code* && "$output" != *install-ai-workspace* && "$output" != *install-herdr* ]]
	grep -q 'system/install-claude-code.bats' "${DOTFILES_DIR}/tests/Makefile.tests"
}
