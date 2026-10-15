#!/usr/bin/env bats

load '../helpers/common'

setup() {
  DOTFILES_DIR="$(get_dotfiles_dir)"
  INSTALLER="${DOTFILES_DIR}/scripts/install-cursor-agent.sh"
  UPDATER="${DOTFILES_DIR}/scripts/update/update-wsl.sh"
  setup_temp_dir
  export HOME="${TEST_TEMP_DIR}/home"
  mkdir -p "${HOME}/.local/bin" "${TEST_TEMP_DIR}/fakebin"
  export CURSOR_TEST_CALLS="${TEST_TEMP_DIR}/calls.log"
  : > "${CURSOR_TEST_CALLS}"
  export PATH="${TEST_TEMP_DIR}/fakebin:${HOME}/.local/bin:${PATH}"
}

teardown() {
  teardown_temp_dir
}

@test "installed Cursor Agent uses vendor update and stays in managed HOME" {
  cat >"${HOME}/.local/bin/agent" <<'SH'
#!/usr/bin/env bash
if [[ "$1" == "update" ]]; then echo update >>"$CURSOR_TEST_CALLS"; exit 0; fi
if [[ "$1" == "--version" ]]; then echo "2026.10.14-test"; exit 0; fi
exit 1
SH
  chmod +x "${HOME}/.local/bin/agent"
  run bash "$INSTALLER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026.10.14-test"* ]]
  [ "$(cat "$CURSOR_TEST_CALLS")" = update ]
}

@test "missing Cursor Agent runs official HTTPS installer and checks installed binary" {
  cat >"${TEST_TEMP_DIR}/fakebin/curl" <<'SH'
#!/usr/bin/env bash
printf '%s\n' "$@" > "$CURSOR_TEST_CALLS"
target=""
while [[ "$#" -gt 0 ]]; do
  if [[ "$1" == "-o" ]]; then target="$2"; break; fi
  shift
done
test -n "$target" || exit 2
cat >"$target" <<'INSTALL'
#!/usr/bin/env bash
set -euo pipefail
mkdir -p "$HOME/.local/bin"
cat >"$HOME/.local/bin/agent" <<'AGENT'
#!/usr/bin/env bash
if [[ "$1" == "--version" ]]; then echo "2026.10.14-installed"; exit 0; fi
exit 2
AGENT
chmod +x "$HOME/.local/bin/agent"
INSTALL
SH
  chmod +x "${TEST_TEMP_DIR}/fakebin/curl"
  run bash "$INSTALLER"
  [ "$status" -eq 0 ]
  [[ "$output" == *"2026.10.14-installed"* ]]
  grep -Fxq 'https://cursor.com/install' "$CURSOR_TEST_CALLS"
  [ -x "${HOME}/.local/bin/agent" ]
}

@test "dotfiles update tracks Cursor Agent in tools and snapshot" {
  grep -Fq 'want_section tools && run_cursor_agent' "$UPDATER"
  grep -Fq 'snapshot_current_tool "Cursor Agent CLI" agent --version' "$UPDATER"
  grep -Fq 'snapshot_current_tool "Claude Code CLI" claude --version' "$UPDATER"
  grep -Fq 'run_versioned_step run_step "WSL" "Cursor Agent CLI"' "$UPDATER"
}
