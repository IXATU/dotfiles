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
