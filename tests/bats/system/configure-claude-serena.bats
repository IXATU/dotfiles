#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	ADAPTER="${DOTFILES_DIR}/scripts/configure-claude-serena.sh"
	setup_temp_dir
}

teardown() {
	teardown_temp_dir
}

@test "Claude Serena adapter adds only the missing user-scoped MCP" {
	local stub_dir="${TEST_TEMP_DIR}/bin-add"
	local log="${TEST_TEMP_DIR}/claude-add.log"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
[[ "\$*" == 'mcp get serena' ]] && exit 1
[[ "\$*" == 'mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd' ]] && exit 0
exit 92
EOF
	chmod +x "${stub_dir}/claude"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 0 ]]
	grep -qx 'mcp get serena' "$log"
	grep -qx 'mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd' "$log"
}

@test "Claude Serena adapter preserves an existing registration and unrelated MCPs" {
	local stub_dir="${TEST_TEMP_DIR}/bin-existing"
	local log="${TEST_TEMP_DIR}/claude-existing.log"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
[[ "\$*" == 'mcp get serena' ]] && exit 0
exit 93
EOF
	chmod +x "${stub_dir}/claude"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 0 ]]
	[[ "$(wc -l <"$log")" -eq 1 ]]
	grep -qx 'mcp get serena' "$log"
}

@test "Claude Serena adapter DRY_RUN never invokes claude" {
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
	[[ "$output" == *"claude mcp add --scope user serena"* ]]
}
