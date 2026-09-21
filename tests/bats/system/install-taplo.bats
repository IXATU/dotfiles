#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALL_TAPLO="${DOTFILES_DIR}/scripts/install-taplo.sh"
	setup_temp_dir
}

teardown() {
	teardown_temp_dir
}

@test "install-taplo DRY_RUN plans official checksum-verified binary without mutation" {
	local fake_home="${TEST_TEMP_DIR}/home"
	mkdir -p "$fake_home"
	run env HOME="$fake_home" DRY_RUN=1 PATH="/usr/bin:/bin" bash "$INSTALL_TAPLO"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"github.com/tamasfe/taplo/releases/download/0.10.0/"* ]]
	[[ "$output" == *"verify SHA-256"* ]]
	[[ ! -e "${fake_home}/.local/bin/taplo" ]]
}

@test "install-taplo is a no-op at the canonical version" {
	local stub_dir="${TEST_TEMP_DIR}/bin"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/taplo" <<'EOF'
#!/usr/bin/env bash
echo "taplo 0.10.0"
EOF
	chmod +x "${stub_dir}/taplo"
	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_TAPLO"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"already at canonical version 0.10.0"* ]]
}

@test "install.mk exposes Taplo outside the install aggregate" {
	grep -q '^install-taplo:' "${DOTFILES_DIR}/install.mk"
	run grep -E '^install:' "${DOTFILES_DIR}/install.mk"
	[[ "$status" -eq 0 ]]
	[[ "$output" != *"install-taplo"* ]]
}
