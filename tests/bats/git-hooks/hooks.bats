#!/usr/bin/env bats

load '../helpers/common'

setup() {
	DOTFILES_DIR="$(get_dotfiles_dir)"
	POST_COMMIT="${DOTFILES_DIR}/scripts/hooks/post-commit-gitnexus.sh"
	INSTALLER="${DOTFILES_DIR}/scripts/install-git-hooks.sh"
	setup_temp_dir
}

teardown() {
	teardown_temp_dir
}

init_repo() {
	local repo="$1"
	git init -q "$repo"
	git -C "$repo" config user.email "test@example.com"
	git -C "$repo" config user.name "Test User"
	echo "initial" >"$repo/file.txt"
	git -C "$repo" add file.txt
	git -c core.hooksPath=/dev/null -C "$repo" commit -q -m initial
}

copy_post_commit() {
	local repo="$1"
	mkdir -p "$repo/scripts/hooks" "$repo/scripts/lib"
	cp "$POST_COMMIT" "$repo/scripts/hooks/post-commit-gitnexus.sh"
	chmod +x "$repo/scripts/hooks/post-commit-gitnexus.sh"
}

copy_gitnexus_runtime() {
	local repo="$1"
	mkdir -p "$repo/scripts/lib" "$repo/scripts/update/lib"
	cp "${DOTFILES_DIR}/scripts/lib/gitnexus_runtime.sh" "$repo/scripts/lib/"
	cp "${DOTFILES_DIR}/scripts/update/lib/node_runtime.sh" "$repo/scripts/update/lib/"
}

copy_hook_entrypoints() {
	local repo="$1"
	mkdir -p "$repo/.githooks"
	cp "${DOTFILES_DIR}/.githooks/post-commit" "$repo/.githooks/"
	chmod +x "$repo/.githooks/post-commit"
}

@test "post-commit honors DOTFILES_SKIP_HOOKS" {
	local repo="${TEST_TEMP_DIR}/repo"
	init_repo "$repo"
	copy_post_commit "$repo"

	run env DOTFILES_SKIP_HOOKS=1 bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"DOTFILES_SKIP_HOOKS=1"* ]]
}

@test "post-commit honors DOTFILES_SKIP_GITNEXUS" {
	local repo="${TEST_TEMP_DIR}/repo"
	init_repo "$repo"
	copy_post_commit "$repo"

	run env DOTFILES_SKIP_GITNEXUS=1 bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"DOTFILES_SKIP_GITNEXUS=1"* ]]
}

@test "post-commit skips refresh when GitNexus MCP or lock is active" {
	local repo="${TEST_TEMP_DIR}/repo"
	local trace="${TEST_TEMP_DIR}/trace"
	init_repo "$repo"
	copy_post_commit "$repo"
	cat >"$repo/scripts/lib/gitnexus_runtime.sh" <<'EOF'
gitnexus_index_in_use() { return 0; }
gitnexus_analyze_here() {
	printf '%s\n' "$*" >"$GNX_TRACE"
}
EOF

	run env GNX_TRACE="$trace" bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"MCP/index lock is active"* ]]
	[[ "$output" == *"gnx-analyze-here --skip-agents-md"* ]]
	local typo="gnanalyze""-here"
	[[ "$output" != *"$typo"* ]]
	[[ ! -f "$trace" ]]
}

@test "post-commit skips when GitNexus registry is not writable" {
	local repo="${TEST_TEMP_DIR}/repo"
	local gnx_home="${TEST_TEMP_DIR}/gitnexus-home"
	local trace="${TEST_TEMP_DIR}/trace"
	init_repo "$repo"
	copy_post_commit "$repo"
	mkdir -p "$gnx_home"
	echo '[]' >"$gnx_home/registry.json"
	chmod a-w "$gnx_home/registry.json"
	cat >"$repo/scripts/lib/gitnexus_runtime.sh" <<'EOF'
gitnexus_index_in_use() { return 1; }
gitnexus_analyze_here() {
	printf '%s\n' "$*" >"$GNX_TRACE"
}
EOF

	run env GNX_TRACE="$trace" GITNEXUS_HOME="$gnx_home" \
		bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"registry.json is not writable"* ]]
	[[ ! -f "$trace" ]]
}

@test "post-commit skips when GitNexus home is not writable" {
	local repo="${TEST_TEMP_DIR}/repo"
	local gnx_home="${TEST_TEMP_DIR}/gitnexus-home-ro"
	local trace="${TEST_TEMP_DIR}/trace"
	init_repo "$repo"
	copy_post_commit "$repo"
	mkdir -p "$gnx_home"
	chmod a-w "$gnx_home"
	cat >"$repo/scripts/lib/gitnexus_runtime.sh" <<'EOF'
gitnexus_index_in_use() { return 1; }
gitnexus_analyze_here() {
	printf '%s\n' "$*" >"$GNX_TRACE"
}
EOF

	run env GNX_TRACE="$trace" GITNEXUS_HOME="$gnx_home" \
		bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"is not writable"* ]]
	[[ ! -f "$trace" ]]
}

@test "post-commit remains successful when GitNexus analyze fails" {
	local repo="${TEST_TEMP_DIR}/repo"
	local trace="${TEST_TEMP_DIR}/trace"
	init_repo "$repo"
	copy_post_commit "$repo"
	cat >"$repo/scripts/lib/gitnexus_runtime.sh" <<'EOF'
gitnexus_index_in_use() { return 1; }
gitnexus_analyze_here() {
	printf '%s\n' "$*" >"$GNX_TRACE"
	return 1
}
EOF

	run env GNX_TRACE="$trace" bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"refresh failed with exit code 1"* ]]
	[[ "$output" == *"commit kept"* ]]
	grep -q -- '--skip-agents-md' "$trace"
	run grep -q -- '--skip-skills' "$trace"
	[[ "$status" -ne 0 ]]
	run grep -q -- '--force' "$trace"
	[[ "$status" -ne 0 ]]
}

@test "post-commit timeout remains successful with a warning" {
	local repo="${TEST_TEMP_DIR}/repo"
	local fake_bin="${TEST_TEMP_DIR}/fake-bin"
	local trace="${TEST_TEMP_DIR}/timeout-trace"
	init_repo "$repo"
	copy_post_commit "$repo"
	mkdir -p "$fake_bin"
	cat >"$repo/scripts/lib/gitnexus_runtime.sh" <<'EOF'
gitnexus_index_in_use() { return 1; }
gitnexus_analyze_here() { return 99; }
EOF
	cat >"$fake_bin/timeout" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >"$TIMEOUT_TRACE"
exit 124
EOF
	chmod +x "$fake_bin/timeout"

	run env TIMEOUT_TRACE="$trace" PATH="$fake_bin:$PATH" \
		bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"timed out after 30s"* ]]
	[[ "$output" == *"commit kept"* ]]
	[[ "$output" == *"gnx-analyze-here --skip-agents-md"* ]]
	grep -q '^30s ' "$trace"
}

@test "post-commit uses the shared managed Node runtime without aliases" {
	local repo="${TEST_TEMP_DIR}/repo"
	local fake_bin="${TEST_TEMP_DIR}/fake-bin"
	local fake_home="${TEST_TEMP_DIR}/home"
	local managed_node="${TEST_TEMP_DIR}/managed/node"
	local trace="${TEST_TEMP_DIR}/trace"
	init_repo "$repo"
	copy_post_commit "$repo"
	copy_gitnexus_runtime "$repo"
	mkdir -p "$fake_bin" "$(dirname "$managed_node")" "$fake_home"

	cat >"$fake_bin/node" <<'EOF'
#!/usr/bin/env bash
echo "v20.18.2"
EOF
	cat >"$managed_node" <<'EOF'
#!/usr/bin/env bash
echo "v24.16.0"
EOF
	cat >"$fake_bin/pgrep" <<'EOF'
#!/usr/bin/env bash
exit 1
EOF
	cat >"$fake_bin/gitnexus" <<'EOF'
#!/usr/bin/env bash
echo "$*:$(command -v node):$(node --version)" >"$GNX_TRACE"
EOF
	chmod +x "$fake_bin/node" "$managed_node" "$fake_bin/pgrep" "$fake_bin/gitnexus"

	run env \
		HOME="$fake_home" \
		GNX_TRACE="$trace" \
		DOTFILES_MANAGED_NODE_BIN="$managed_node" \
		PATH="$fake_bin:$PATH" \
		bash -c "cd '$repo' && '$repo/scripts/hooks/post-commit-gitnexus.sh'"

	[[ "$status" -eq 0 ]]
	grep -q '^analyze \. --skip-agents-md:' "$trace"
	grep -q 'node-runtime\..*/node:v24.16.0' "$trace"
}

@test "install-git-hooks configures local hooks path and is idempotent" {
	local repo="${TEST_TEMP_DIR}/repo"
	init_repo "$repo"
	copy_hook_entrypoints "$repo"

	run bash -c "cd '$repo' && bash '$INSTALLER'"
	[[ "$status" -eq 0 ]]
	[[ "$(git -C "$repo" config --local --get core.hooksPath)" == ".githooks" ]]

	run bash -c "cd '$repo' && bash '$INSTALLER'"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"already .githooks"* ]]
}

@test "install-git-hooks does not overwrite another local hooks path" {
	local repo="${TEST_TEMP_DIR}/repo"
	init_repo "$repo"
	copy_hook_entrypoints "$repo"
	git -C "$repo" config --local core.hooksPath custom-hooks

	run bash -c "cd '$repo' && bash '$INSTALLER'"
	[[ "$status" -eq 1 ]]
	[[ "$output" == *"refusing to overwrite"* ]]
	[[ "$(git -C "$repo" config --local --get core.hooksPath)" == "custom-hooks" ]]
}

@test "versioned post-commit hook entrypoint is an executable delegator" {
	[[ ! -e "${DOTFILES_DIR}/.githooks/pre-commit" ]]
	[[ -x "${DOTFILES_DIR}/.githooks/post-commit" ]]
	grep -q 'scripts/hooks/post-commit-gitnexus.sh' "${DOTFILES_DIR}/.githooks/post-commit"
}

@test "install-git-hooks is explicit and discoverable" {
	grep -q '^install-git-hooks:' "${DOTFILES_DIR}/install.mk"
	[[ "$(grep '^install:' "${DOTFILES_DIR}/install.mk")" != *"install-git-hooks"* ]]
	[[ "$(grep '^update:' "${DOTFILES_DIR}/update.mk")" != *"install-git-hooks"* ]]
	run make -C "$DOTFILES_DIR" help
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"make install-git-hooks"* ]]
}

@test "hook documentation covers behavior and escape variables" {
	local doc
	for doc in \
		"${DOTFILES_DIR}/docs/INSTALL.md" \
		"${DOTFILES_DIR}/docs/OPERATIONS_CHEATSHEET.md"; do
		grep -q 'make install-git-hooks' "$doc"
		grep -q 'DOTFILES_SKIP_HOOKS=1' "$doc"
		grep -q 'DOTFILES_SKIP_GITNEXUS=1' "$doc"
	done
}

@test "GitNexus hook policy documents post-commit best-effort refresh" {
	local policy="${DOTFILES_DIR}/docs/GITNEXUS_OPERATIONAL_POLICY.md"
	grep -q 'gnx-analyze-here --force --skip-agents-md' "$policy"
	grep -q 'gnx-analyze-here --skip-agents-md' "$policy"
	grep -q '30 segundos' "$policy"
	grep -q 'MCP/procesos GitNexus' "$policy"
}

@test "GitNexus hook docs and scripts do not mention gnanalyze typo" {
	local typo="gnanalyze""-here"
	run grep -R "$typo" \
		"${DOTFILES_DIR}/scripts/hooks" \
		"${DOTFILES_DIR}/docs/GITNEXUS_OPERATIONAL_POLICY.md" \
		"${DOTFILES_DIR}/docs/INSTALL.md" \
		"${DOTFILES_DIR}/docs/OPERATIONS_CHEATSHEET.md" \
		"${DOTFILES_DIR}/tests/bats/git-hooks"
	[[ "$status" -eq 1 ]]
}
