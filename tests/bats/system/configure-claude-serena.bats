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

@test "Claude Serena adapter adds the missing MCP and disables the duplicate plugin" {
	local stub_dir="${TEST_TEMP_DIR}/bin-add"
	local log="${TEST_TEMP_DIR}/claude-add.log"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
case "\$*" in
'mcp get serena') exit 1 ;;
'mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd --enable-web-dashboard true --open-web-dashboard false') ;;
'plugin disable -s user serena@claude-plugins-official') ;;
*) exit 92 ;;
esac
EOF
	chmod +x "${stub_dir}/claude"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 0 ]]
	grep -qx 'mcp get serena' "$log"
	grep -qx 'mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd --enable-web-dashboard true --open-web-dashboard false' "$log"
	grep -qx 'plugin disable -s user serena@claude-plugins-official' "$log"
	[[ "$output" == *"registered at user scope"* ]]
	[[ "$output" == *"duplicate Serena plugin disabled"* ]]
}

@test "Claude Serena adapter preserves an existing MCP and still disables the duplicate plugin" {
	local stub_dir="${TEST_TEMP_DIR}/bin-existing"
	local log="${TEST_TEMP_DIR}/claude-existing.log"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
case "\$*" in
'mcp get serena') ;;
'plugin disable -s user serena@claude-plugins-official') ;;
*) exit 93 ;;
esac
EOF
	chmod +x "${stub_dir}/claude"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -eq 0 ]]
	[[ "$(wc -l <"$log")" -eq 2 ]]
	grep -qx 'mcp get serena' "$log"
	grep -qx 'plugin disable -s user serena@claude-plugins-official' "$log"
	[[ "$output" == *"already registered; existing configuration preserved"* ]]
	[[ "$output" == *"duplicate Serena plugin disabled"* ]]
}

@test "Claude Serena adapter propagates duplicate plugin disable failure" {
	local stub_dir="${TEST_TEMP_DIR}/bin-disable-failure"
	local log="${TEST_TEMP_DIR}/claude-disable-failure.log"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/claude" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${log}"
case "\$*" in
'mcp get serena') ;;
'plugin disable -s user serena@claude-plugins-official') exit 7 ;;
*) exit 95 ;;
esac
EOF
	chmod +x "${stub_dir}/claude"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$ADAPTER"
	[[ "$status" -ne 0 ]]
	[[ "$output" != *"canonical Serena ready"* ]]
}

@test "Claude Serena adapter DRY_RUN previews registration and plugin disable without invoking claude" {
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
	[[ "$output" == *"--enable-web-dashboard true --open-web-dashboard false"* ]]
	[[ "$output" == *"claude plugin disable -s user serena@claude-plugins-official"* ]]
}
