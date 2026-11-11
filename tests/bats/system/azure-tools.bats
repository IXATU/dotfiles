#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	CHECK_SCRIPT="${DOTFILES_DIR}/scripts/check-azure-tools.sh"
	AZURE_ALIASES="${DOTFILES_DIR}/zsh/55-aliases-azure.zsh"
	AZURE_DOC="${DOTFILES_DIR}/docs/ops/azure-tooling.md"
	setup_temp_dir
}

teardown() {
	teardown_temp_dir
}

@test "check-azure-tools.sh exists" {
	[[ -f "${CHECK_SCRIPT}" ]]
}

@test "check-azure-tools.sh passes bash -n" {
	run bash -n "${CHECK_SCRIPT}"
	[[ "${status}" -eq 0 ]]
}

@test "azure aliases module exists" {
	[[ -f "${AZURE_ALIASES}" ]]
}

@test "azure aliases module passes bash -n" {
	run bash -n "${AZURE_ALIASES}"
	[[ "${status}" -eq 0 ]]
}

@test "azure tooling docs exist" {
	[[ -f "${AZURE_DOC}" ]]
}

@test "check-azure-tools.sh does not contain forbidden Azure commands" {
	local forbidden=(
		"az login"
		"az account set"
		"az group create"
		"az group delete"
		"az acr create"
		"az acr delete"
		"az containerapp create"
		"az containerapp delete"
		"az sql"
		"az keyvault"
	)

	local pattern
	for pattern in "${forbidden[@]}"; do
		run grep -F "${pattern}" "${CHECK_SCRIPT}"
		[[ "${status}" -ne 0 ]]
	done
}

@test "azure aliases do not contain destructive aliases" {
	run grep -E '^alias .*=(.*delete|.*remove|.*purge)' "${AZURE_ALIASES}"
	[[ "${status}" -ne 0 ]]
}

@test "zshrc loads azure aliases before local overrides" {
	run grep -n '55-aliases-azure.zsh' "${DOTFILES_DIR}/zshrc"
	[[ "${status}" -eq 0 ]]
}

@test "Azure account check verifies expected tenant and selected subscription" {
	local stub_dir="${TEST_TEMP_DIR}/bin"
	local az_log="${TEST_TEMP_DIR}/az.log"
	mkdir -p "$stub_dir"
	for cmd in git make jq curl; do
		ln -s "$(command -v "$cmd")" "$stub_dir/$cmd"
	done
	cat >"${stub_dir}/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	cat >"${stub_dir}/az" <<'EOF'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"${AZ_TEST_LOG}"
case "$*" in
  "version --query \"azure-cli\" --output tsv") printf '2.79.0\n' ;;
  "account show --query tenantId --output tsv") printf 'cafb7744-aedc-4c62-8a02-0474058bbfaa\n' ;;
  "account show --query id --output tsv") printf '00000000-0000-0000-0000-000000000001\n' ;;
  "account show --query name --output tsv") printf 'Production\n' ;;
  "extension show --name containerapp --query name --output tsv") printf 'containerapp\n' ;;
esac
EOF
	chmod +x "${stub_dir}/az" "${stub_dir}/docker"

	run env AZ_TEST_LOG="$az_log" PATH="${stub_dir}:/usr/bin:/bin" "$CHECK_SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"Production (00000000-0000-0000-0000-000000000001)"* ]]
	[[ "$output" != *"Development"* ]]
	[[ "$output" != *"operator@example.com"* ]]
	[[ "$output" != *"client-secret"* ]]
	grep -Fq "account show --query tenantId --output tsv" "$az_log"
	grep -Fq "account show --query id --output tsv" "$az_log"
}

@test "Azure account check does not print account details for a different tenant" {
	local stub_dir="${TEST_TEMP_DIR}/bin-mismatch"
	mkdir -p "$stub_dir"
	for cmd in git make jq curl; do
		ln -s "$(command -v "$cmd")" "$stub_dir/$cmd"
	done
	cat >"${stub_dir}/docker" <<'EOF'
#!/usr/bin/env bash
exit 0
EOF
	cat >"${stub_dir}/az" <<'EOF'
#!/usr/bin/env bash
case "$*" in
  "version --query \"azure-cli\" --output tsv") printf '2.79.0\n' ;;
  "account show --query tenantId --output tsv") printf '11111111-1111-1111-1111-111111111111\n' ;;
  "account show --query id --output tsv") printf 'SHOULD-NOT-PRINT\n' ;;
  "account show --query name --output tsv") printf 'Secret Subscription\n' ;;
  "extension show --name containerapp --query name --output tsv") printf 'containerapp\n' ;;
esac
EOF
	chmod +x "${stub_dir}/az" "${stub_dir}/docker"

	run env PATH="${stub_dir}:/usr/bin:/bin" "$CHECK_SCRIPT"
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"no pertenece al tenant esperado"* ]]
	[[ "$output" != *"SHOULD-NOT-PRINT"* ]]
	[[ "$output" != *"Secret Subscription"* ]]
	[[ "$output" != *"11111111-1111-1111-1111-111111111111"* ]]
}
