#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	ADAPTER="${DOTFILES_DIR}/scripts/configure-claude-gitnexus.sh"
	LAUNCHER="${HOME}/.local/share/chezmoi/bin/mcp-gitnexus-launcher"
	setup_temp_dir
}

teardown() {
	teardown_temp_dir
}

@test "Claude GitNexus adapter adds only the missing user-scoped MCP" {
	local stub_dir="${TEST_TEMP_DIR}/bin-add"
	local log="${TEST_TEMP_DIR}/claude-add.log"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
[[ "\$*" == 'mcp get gitnexus' ]] && exit 1
[[ "\$*" == "mcp add --scope user gitnexus -- ${LAUNCHER}" ]] && exit 0
exit 92
EOF
	chmod +x "${stub_dir}/claude"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 0 ]]
	grep -qx 'mcp get gitnexus' "$log"
	grep -qx "mcp add --scope user gitnexus -- ${LAUNCHER}" "$log"
}

@test "Claude GitNexus adapter preserves an existing registration and unrelated MCPs" {
	local stub_dir="${TEST_TEMP_DIR}/bin-existing"
	local log="${TEST_TEMP_DIR}/claude-existing.log"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
[[ "\$*" == 'mcp get gitnexus' ]] && exit 0
exit 93
EOF
	chmod +x "${stub_dir}/claude"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 0 ]]
	[[ "$(wc -l <"$log")" -eq 1 ]]
	grep -qx 'mcp get gitnexus' "$log"
}

@test "Claude GitNexus adapter DRY_RUN never invokes claude" {
	local stub_dir="${TEST_TEMP_DIR}/bin-dry"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<'EOF'
#!/usr/bin/env bash
echo "claude must not run in DRY_RUN" >&2
exit 94
EOF
	chmod +x "${stub_dir}/claude"

	run env DRY_RUN=1 PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"claude mcp add --scope user gitnexus"* ]]
}

@test "Claude GitNexus adapter fails clearly when the launcher is missing" {
	local stub_dir="${TEST_TEMP_DIR}/bin-nolauncher"
	local fake_home="${TEST_TEMP_DIR}/fake-home"
	local log="${TEST_TEMP_DIR}/claude-nolauncher.log"
	mkdir -p "$stub_dir" "$fake_home"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
exit 95
EOF
	chmod +x "${stub_dir}/claude"

	run env HOME="$fake_home" PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 1 ]]
	[[ "$output" == *"GitNexus MCP launcher is missing"* ]]
	[[ "$output" == *"mcp-gitnexus-launcher"* ]]
	[[ ! -e "$log" ]]
}
