#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	INSTALL_SERENA="${DOTFILES_DIR}/scripts/install-serena.sh"
	setup_temp_dir
}

teardown() {
	teardown_temp_dir
}

write_serena_stubs() {
	local stub_dir="$1" version_file="$2" uv_log="$3"
	mkdir -p "$stub_dir"
	cat >"${stub_dir}/serena" <<EOF
#!/usr/bin/env bash
[[ -f "${version_file}" ]] || exit 127
printf 'Serena %s\n' "\$(cat "${version_file}")"
EOF
	cat >"${stub_dir}/uv" <<EOF
#!/usr/bin/env bash
printf '%s\n' "\$*" >>"${uv_log}"
if [[ "\$*" == 'tool list' && -f "${version_file}" ]]; then
	printf 'serena-agent v%s\n- serena\n' "\$(cat "${version_file}")"
	exit 0
fi
if [[ "\$*" == 'tool install serena-agent==1.7.0' ]]; then
	printf '1.7.0\n' >"${version_file}"
	exit 0
fi
exit 91
EOF
	chmod +x "${stub_dir}/serena" "${stub_dir}/uv"
}

@test "install-serena plans canonical install when missing without mutation" {
	local fake_home="${TEST_TEMP_DIR}/home-missing"
	local stub_dir="${TEST_TEMP_DIR}/bin-missing"
	mkdir -p "$fake_home" "$stub_dir"
	cat >"${stub_dir}/uv" <<'EOF'
#!/usr/bin/env bash
echo "uv must not run in DRY_RUN" >&2
exit 90
EOF
	chmod +x "${stub_dir}/uv"

	run env HOME="$fake_home" DRY_RUN=1 PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_SERENA"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"missing"* ]]
	[[ "$output" == *"uv tool install serena-agent==1.7.0"* ]]
}

@test "install-serena is a no-op at the canonical version" {
	local stub_dir="${TEST_TEMP_DIR}/bin-same"
	local version_file="${TEST_TEMP_DIR}/same-version"
	local uv_log="${TEST_TEMP_DIR}/same-uv.log"
	printf '1.7.0\n' >"$version_file"
	write_serena_stubs "$stub_dir" "$version_file" "$uv_log"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_SERENA"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"already at canonical version 1.7.0"* ]]
	grep -qx 'tool list' "$uv_log"
	[[ "$(wc -l <"$uv_log")" -eq 1 ]]
}

@test "install-serena converges version drift to the canonical version" {
	local stub_dir="${TEST_TEMP_DIR}/bin-drift"
	local version_file="${TEST_TEMP_DIR}/drift-version"
	local uv_log="${TEST_TEMP_DIR}/drift-uv.log"
	printf '1.6.0\n' >"$version_file"
	write_serena_stubs "$stub_dir" "$version_file" "$uv_log"

	run env PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_SERENA"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"1.6.0 -> 1.7.0"* ]]
	grep -qx 'tool install serena-agent==1.7.0' "$uv_log"
	[[ "$(cat "$version_file")" == "1.7.0" ]]
}

@test "install-serena DRY_RUN preserves a drifted installation" {
	local stub_dir="${TEST_TEMP_DIR}/bin-dry-drift"
	local version_file="${TEST_TEMP_DIR}/dry-drift-version"
	local uv_log="${TEST_TEMP_DIR}/dry-drift-uv.log"
	printf '1.6.0\n' >"$version_file"
	write_serena_stubs "$stub_dir" "$version_file" "$uv_log"

	run env DRY_RUN=1 PATH="${stub_dir}:/usr/bin:/bin" bash "$INSTALL_SERENA"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"DRY_RUN"* ]]
	[[ "$(cat "$version_file")" == "1.6.0" ]]
	grep -qx 'tool list' "$uv_log"
	[[ "$(wc -l <"$uv_log")" -eq 1 ]]
}

@test "install.mk exposes Serena and Claude adapter targets" {
	grep -q '^install-serena:' "${DOTFILES_DIR}/install.mk"
	grep -q '^configure-claude-serena:' "${DOTFILES_DIR}/install.mk"
}
