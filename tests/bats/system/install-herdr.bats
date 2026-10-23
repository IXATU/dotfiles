#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALL_HERDR="${DOTFILES_DIR}/scripts/install-herdr.sh"
	setup_temp_dir
}

teardown() {
	teardown_temp_dir
}

write_agent_stub() {
	local stub_dir="$1" command_name="$2"
	cat >"${stub_dir}/${command_name}" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	chmod +x "${stub_dir}/${command_name}"
}

write_herdr_stub() {
	local stub_dir="$1" state_dir="$2"
	mkdir -p "$stub_dir" "$state_dir"
	cat >"${stub_dir}/herdr" <<EOF
#!/usr/bin/env bash
set -euo pipefail
printf '%s\n' "\$*" >>"${state_dir}/commands.log"
case "\${1:-}" in
--version)
	printf 'herdr %s\n' "\$(cat "${state_dir}/version")"
	;;
update)
	printf '0.9.3\n' >"${state_dir}/version"
	;;
channel)
	case "\${2:-}" in
	show) cat "${state_dir}/channel" ;;
	set)
		printf '%s\n' "\${3}" >"${state_dir}/channel"
		printf '0.9.3\n' >"${state_dir}/version"
		;;
	esac
	;;
integration)
	case "\${2:-}" in
	status) cat "${state_dir}/integrations" ;;
	install) printf '%s\n' "\${3}" >>"${state_dir}/installed.log" ;;
	esac
	;;
esac
EOF
	chmod +x "${stub_dir}/herdr"
}

@test "install-herdr DRY_RUN plans official stable bootstrap without mutation" {
	local fake_home="${TEST_TEMP_DIR}/home-missing"
	mkdir -p "$fake_home"

	run env HOME="$fake_home" DRY_RUN=1 PATH="/usr/bin:/bin" bash "$INSTALL_HERDR"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"https://herdr.dev/install.sh"* ]]
	[[ "$output" == *"HERDR_INSTALL_DIR="*".local/bin"* ]]
	[[ "$output" == *"stable"* ]]
	[[ ! -e "${fake_home}/.local/bin/herdr" ]]
}

@test "install-herdr bootstraps through the official installer contract" {
	local fake_home="${TEST_TEMP_DIR}/home-bootstrap"
	local stub_dir="${TEST_TEMP_DIR}/bin-bootstrap"
	local source_dir="${TEST_TEMP_DIR}/source-bootstrap"
	local state_dir="${TEST_TEMP_DIR}/state-bootstrap"
	mkdir -p "$fake_home" "$stub_dir" "$source_dir" "$state_dir"
	printf '0.9.3\n' >"${state_dir}/version"
	printf 'stable\n' >"${state_dir}/channel"
	cat >"${state_dir}/integrations" <<'EOF'
claude: not installed (/tmp/claude-hook)
codex: not installed (/tmp/codex-hook)
opencode: not installed (/tmp/opencode-plugin)
cursor: not installed (/tmp/cursor-hook)
EOF
	write_herdr_stub "$source_dir" "$state_dir"
	cat >"${stub_dir}/curl" <<'EOF'
#!/usr/bin/env bash
set -euo pipefail
output=""
while [[ $# -gt 0 ]]; do
	case "$1" in
	-o)
		output="$2"
		shift 2
		;;
	*) shift ;;
	esac
done
cat >"$output" <<'INSTALLER'
#!/bin/sh
set -eu
mkdir -p "$HERDR_INSTALL_DIR"
cp "$HERDR_STUB_SOURCE" "$HERDR_INSTALL_DIR/herdr"
chmod +x "$HERDR_INSTALL_DIR/herdr"
INSTALLER
EOF
	chmod +x "${stub_dir}/curl"

	run env HOME="$fake_home" HERDR_STUB_SOURCE="${source_dir}/herdr" PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_HERDR"
	[[ "$status" -eq 0 ]]
	[[ -x "${fake_home}/.local/bin/herdr" ]]
	[[ "$output" == *"bootstrap selected stable channel"* ]]
	run grep -qx 'update' "${state_dir}/commands.log"
	[[ "$status" -ne 0 ]]
}

@test "install-herdr updates a stable direct install and only refreshes outdated detected integrations" {
	local fake_home="${TEST_TEMP_DIR}/home-stable"
	local stub_dir="${fake_home}/.local/bin"
	local state_dir="${TEST_TEMP_DIR}/state-stable"
	mkdir -p "$fake_home" "$state_dir"
	printf '0.9.1\n' >"${state_dir}/version"
	printf 'stable\n' >"${state_dir}/channel"
	cat >"${state_dir}/integrations" <<'EOF'
claude: current (v10) (/tmp/claude-hook)
codex: current (v8) (/tmp/codex-hook)
opencode: outdated (v12 < v13) (/tmp/opencode-plugin)
cursor: not installed (/tmp/cursor-hook)
EOF
	write_herdr_stub "$stub_dir" "$state_dir"
	write_agent_stub "$stub_dir" claude
	write_agent_stub "$stub_dir" codex
	write_agent_stub "$stub_dir" opencode

	run env HOME="$fake_home" PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_HERDR"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"0.9.1"*"0.9.3"* ]]
	grep -qx 'update' "${state_dir}/commands.log"
	grep -qx 'integration install opencode' "${state_dir}/commands.log"
	run grep -q 'integration install claude' "${state_dir}/commands.log"
	[[ "$status" -ne 0 ]]
	run grep -q 'integration install codex' "${state_dir}/commands.log"
	[[ "$status" -ne 0 ]]
	run grep -q 'integration install cursor' "${state_dir}/commands.log"
	[[ "$status" -ne 0 ]]
	[[ "$(cat "${state_dir}/installed.log")" == "opencode" ]]
}

@test "install-herdr switches preview to stable without a redundant update" {
	local fake_home="${TEST_TEMP_DIR}/home-preview"
	local stub_dir="${fake_home}/.local/bin"
	local state_dir="${TEST_TEMP_DIR}/state-preview"
	mkdir -p "$fake_home" "$state_dir"
	printf '0.9.2-preview\n' >"${state_dir}/version"
	printf 'preview\n' >"${state_dir}/channel"
	cat >"${state_dir}/integrations" <<'EOF'
claude: not installed (/tmp/claude-hook)
codex: current (v8) (/tmp/codex-hook)
opencode: not installed (/tmp/opencode-plugin)
cursor: not installed (/tmp/cursor-hook)
EOF
	write_herdr_stub "$stub_dir" "$state_dir"
	write_agent_stub "$stub_dir" codex

	run env HOME="$fake_home" PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_HERDR"
	[[ "$status" -eq 0 ]]
	grep -qx 'channel set stable' "${state_dir}/commands.log"
	run grep -qx 'update' "${state_dir}/commands.log"
	[[ "$status" -ne 0 ]]
	[[ "$(cat "${state_dir}/channel")" == "stable" ]]
	[[ ! -e "${state_dir}/installed.log" ]]
}

@test "install-herdr supports argument dry-run and never invokes mutating Herdr commands" {
	local fake_home="${TEST_TEMP_DIR}/home-dry"
	local stub_dir="${fake_home}/.local/bin"
	local state_dir="${TEST_TEMP_DIR}/state-dry"
	mkdir -p "$fake_home" "$state_dir"
	printf '0.9.1\n' >"${state_dir}/version"
	printf 'stable\n' >"${state_dir}/channel"
	cat >"${state_dir}/integrations" <<'EOF'
claude: not installed (/tmp/claude-hook)
codex: not installed (/tmp/codex-hook)
opencode: outdated (v12 < v13) (/tmp/opencode-plugin)
cursor: not installed (/tmp/cursor-hook)
EOF
	write_herdr_stub "$stub_dir" "$state_dir"
	write_agent_stub "$stub_dir" codex
	write_agent_stub "$stub_dir" opencode

	run env HOME="$fake_home" PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_HERDR" --dry-run
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"[DRY_RUN] Would run:"*"herdr update"* ]]
	[[ "$output" == *"integration install codex"* ]]
	[[ "$output" == *"integration install opencode"* ]]
	run grep -qx 'update' "${state_dir}/commands.log"
	[[ "$status" -ne 0 ]]
	run grep -q '^integration install ' "${state_dir}/commands.log"
	[[ "$status" -ne 0 ]]
	[[ "$(cat "${state_dir}/version")" == "0.9.1" ]]
}

@test "install-herdr is opt-in and wired into system bats" {
	grep -q '^install-herdr:' "${DOTFILES_DIR}/install.mk"
	run grep -E '^install:' "${DOTFILES_DIR}/install.mk"
	[[ "$status" -eq 0 ]]
	[[ "$output" != *"install-herdr"* ]]
	grep -q 'system/install-herdr\.bats' "${DOTFILES_DIR}/tests/Makefile.tests"
}

@test "Herdr skip-update converges all detected hooks without replacing stable runtime" {
	local fake_home="${TEST_TEMP_DIR}/home" state="${TEST_TEMP_DIR}/state"
	local bin="${fake_home}/.local/bin"
	write_herdr_stub "$bin" "$state"
	printf '0.9.1\n' >"$state/version"
	printf 'stable\n' >"$state/channel"
	: >"$state/integrations"
	local agent
	for agent in claude codex opencode cursor-agent; do write_agent_stub "$bin" "$agent"; done
	run env HOME="$fake_home" PATH="$bin:/usr/bin:/bin" bash "$INSTALL_HERDR" --skip-update
	[[ "$status" -eq 0 ]]
	[[ "$(cat "$state/version")" == 0.9.1 ]]
	[[ "$(cat "$state/installed.log")" == $'claude\ncodex\nopencode\ncursor' ]]
	run grep -Eq '^(update|channel set)' "$state/commands.log"
	[[ "$status" -ne 0 ]]
	for agent in claude codex opencode cursor; do printf '%s: current\n' "$agent"; done >"$state/integrations"
	run env HOME="$fake_home" PATH="$bin:/usr/bin:/bin" bash "$INSTALL_HERDR" --skip-update
	[[ "$status" -eq 0 ]]
	[[ "$(wc -l <"$state/installed.log")" -eq 4 ]]
}

@test "Herdr skip-update refuses preview without channel change or update" {
	local fake_home="${TEST_TEMP_DIR}/home" state="${TEST_TEMP_DIR}/state"
	local bin="${fake_home}/.local/bin"
	write_herdr_stub "$bin" "$state"
	printf '0.9.2-preview\n' >"$state/version"
	printf 'preview\n' >"$state/channel"
	run env HOME="$fake_home" PATH="$bin:/usr/bin:/bin" bash "$INSTALL_HERDR" --skip-update
	[[ "$status" -ne 0 && "$output" == *'make install-herdr manually'* ]]
	run grep -Eq '^(update|channel set|integration install)' "$state/commands.log"
	[[ "$status" -ne 0 ]]
}

@test "Herdr skip-update combines with dry-run in either order" {
	local order
	for order in '--skip-update --dry-run' '--dry-run --skip-update'; do
		# Intentional splitting: test both supported flag orders.
		# shellcheck disable=SC2086
		run env HOME="${TEST_TEMP_DIR}/missing" PATH=/usr/bin:/bin bash "$INSTALL_HERDR" $order
		[[ "$status" -eq 0 && "$output" == *DRY_RUN* ]]
		[[ ! -e "${TEST_TEMP_DIR}/missing" ]]
	done
}

@test "WSL workspace mock skips installers and is wired after Cursor in tools only" {
	local updater="${DOTFILES_DIR}/scripts/update/update-wsl.sh"
	# Expansion belongs to the child shell.
	# shellcheck disable=SC2016
	run env UPDATER="$updater" HOME="${TEST_TEMP_DIR}/home" PATH=/usr/bin:/bin DOTFILES_UPDATE_MOCK=1 DOTFILES_UPDATE_RUN_DIR="${TEST_TEMP_DIR}/run" bash -c '
		set -- --section none
		source "$UPDATER"
		run_ai_workspace
	'
	[[ "$status" -eq 0 ]]
	grep -q $'OK\tWSL\tClaude Code CLI\tmocked' "${TEST_TEMP_DIR}/run/wsl-results.tsv"
	grep -q $'OK\tWSL\tHerdr\tmocked' "${TEST_TEMP_DIR}/run/wsl-results.tsv"
	[[ ! -e "${TEST_TEMP_DIR}/home" ]]
	[[ "$(grep '^want_section tools' "$updater" | tail -2)" == $'want_section tools && run_cursor_agent\nwant_section tools && run_ai_workspace' ]]
}

write_workspace_fixture() {
	export HOME="${TEST_TEMP_DIR}/home"
	export UPDATER="${DOTFILES_DIR}/scripts/update/update-wsl.sh"
	export DOTFILES_UPDATE_RUN_DIR="${TEST_TEMP_DIR}/run"
	export HERDR_STUB_SOURCE="${TEST_TEMP_DIR}/source/herdr"
	export PATH="${TEST_TEMP_DIR}/bin:/usr/bin:/bin"
	mkdir -p "$HOME/.claude" "${TEST_TEMP_DIR}/bin"
	write_herdr_stub "${TEST_TEMP_DIR}/source" "${TEST_TEMP_DIR}/state"
	printf 'stable\n' >"${TEST_TEMP_DIR}/state/channel"
	printf '0.9.1\n' >"${TEST_TEMP_DIR}/state/version"
	: >"${TEST_TEMP_DIR}/state/integrations"
	cat >"${TEST_TEMP_DIR}/bin/curl" <<'CURL'
#!/usr/bin/env bash
set -euo pipefail
url="$2"
while [[ "$1" != -o ]]; do shift; done
case "$url" in
https://claude.ai/install.sh)
	[[ "${FAIL_CLAUDE:-0}" == 0 ]] || exit 22
	cat >"$2" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail
[[ "$1" == stable ]]
mkdir -p "$HOME/.local/bin"
printf '#!/usr/bin/env bash\necho 2.1.0\n' >"$HOME/.local/bin/claude"
chmod +x "$HOME/.local/bin/claude"
INSTALL
	;;
https://herdr.dev/install.sh)
	cat >"$2" <<'INSTALL'
#!/bin/sh
set -eu
mkdir -p "$HERDR_INSTALL_DIR"
cp "$HERDR_STUB_SOURCE" "$HERDR_INSTALL_DIR/herdr"
INSTALL
	;;
*) exit 90 ;;
esac
CURL
	chmod +x "${TEST_TEMP_DIR}/bin/curl"
}

@test "WSL workspace bootstraps Claude before Herdr hooks and records versions without runtime update" {
	write_workspace_fixture
	run bash -c '
		set -- --section none
		source "$UPDATER"
		run_ai_workspace
	'
	[[ "$status" -eq 0 ]]
	grep -qx 'integration install claude' "${TEST_TEMP_DIR}/state/commands.log"
	run grep -Eq '^(update|channel set)' "${TEST_TEMP_DIR}/state/commands.log"
	[[ "$status" -ne 0 ]]
	grep -q $'OK\tWSL\tClaude Code CLI\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	grep -q $'OK\tWSL\tHerdr\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	grep -q $'Claude Code CLI\t.*2.1.0' "$DOTFILES_UPDATE_RUN_DIR/tool-snapshot.tsv"
	grep -q $'Herdr\t.*0.9.1' "$DOTFILES_UPDATE_RUN_DIR/tool-snapshot.tsv"
}

@test "WSL workspace isolates Claude download failure and continues Herdr and later steps" {
	write_workspace_fixture
	# Expansion belongs to the child shell.
	# shellcheck disable=SC2016
	run env FAIL_CLAUDE=1 bash -c '
		set -- --section none
		source "$UPDATER"
		run_ai_workspace
		run_step WSL Later "$LOG_DIR/later.log" true
	'
	[[ "$status" -eq 0 ]]
	grep -q $'FAIL\tWSL\tClaude Code CLI\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	grep -q $'OK\tWSL\tHerdr\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	grep -q $'OK\tWSL\tLater\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	run grep -q '^integration install claude' "${TEST_TEMP_DIR}/state/commands.log"
	[[ "$status" -ne 0 ]]
}

@test "WSL workspace isolates Herdr preview failure and continues later steps" {
	write_workspace_fixture
	mkdir -p "$HOME/.local/bin"
	cp "$HERDR_STUB_SOURCE" "$HOME/.local/bin/herdr"
	printf 'preview\n' >"${TEST_TEMP_DIR}/state/channel"
	run bash -c '
		set -- --section none
		source "$UPDATER"
		run_ai_workspace
		run_step WSL Later "$LOG_DIR/later.log" true
	'
	[[ "$status" -eq 0 ]]
	grep -q $'OK\tWSL\tClaude Code CLI\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	grep -q $'FAIL\tWSL\tHerdr\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	grep -q $'OK\tWSL\tLater\t' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
	run grep -Eq '^(update|channel set|integration install)' "${TEST_TEMP_DIR}/state/commands.log"
	[[ "$status" -ne 0 ]]
}
