#!/usr/bin/env bats

setup() {
	bats_require_minimum_version 1.5.0
	REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
	CLI="$REPO/bin/dotfiles-azure-mcp-pilot"
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME/.local/bin"
	export PILOT_CALLS="$BATS_TEST_TMPDIR/calls"
	for tool in az uvx tunnel-client curl systemctl; do
		cat >"$HOME/.local/bin/$tool" <<'MOCK'
#!/usr/bin/env bash
printf '%s %s\n' "${0##*/}" "$*" >> "$PILOT_CALLS"
if [[ "${0##*/}" == uvx ]]; then
  printf '%s\n' "$PATH" "$AZURE_TOKEN_CREDENTIALS" "$AZURE_MCP_COLLECT_TELEMETRY" >> "$PILOT_CALLS"
fi
MOCK
		chmod +x "$HOME/.local/bin/$tool"
	done
	LAUNCHER="$HOME/.local/share/ixatu-azure-mcp-pilot/start.sh"
	PROFILE="$HOME/.config/tunnel-client/ixatu-azure-mcp-pilot.yaml"
	UNIT="$HOME/.config/systemd/user/ixatu-azure-mcp-pilot.service"
	KEY="$HOME/.config/ixatu-azure-mcp-pilot/runtime.env"
}

@test "default and explicit previews are read-only and do not execute tools" {
	for flags in '' '--check' '--dry-run'; do
		read -r -a flag_args <<<"$flags"
		run "$CLI" "${flag_args[@]}" tunnel_pc09
		[ "$status" -eq 0 ]
		[[ "$output" == *PREVIEW* ]]
	done
	[ ! -e "$HOME/.config" ]
	[ ! -e "$HOME/.local/share" ]
	[ ! -e "$PILOT_CALLS" ]
}

@test "apply is idempotent, isolated and does not create a secret or start service" {
	mkdir -p "$HOME/.config/tunnel-client"
	printf 'DC sentinel\n' >"$HOME/.config/tunnel-client/default.yaml"
	run "$CLI" --apply tunnel_pc09
	[ "$status" -eq 0 ]
	local before
	before="$(sha256sum "$LAUNCHER" "$PROFILE" "$UNIT")"
	run "$CLI" --apply tunnel_pc09
	[ "$status" -eq 0 ]
	[ "$before" = "$(sha256sum "$LAUNCHER" "$PROFILE" "$UNIT")" ]
	[ "$(cat "$HOME/.config/tunnel-client/default.yaml")" = 'DC sentinel' ]
	[ ! -e "$KEY" ]
	[ ! -e "$PILOT_CALLS" ]
	[ "$(stat -c %a "$PROFILE")" = 600 ]
	[ "$(stat -c %a "$LAUNCHER")" = 700 ]
	[ "$(find "$HOME/.config" -type f | wc -l)" -eq 3 ]
}

@test "launcher pins stable package, CLI auth, safe PATH and read-only namespaces" {
	run "$CLI" --apply tunnel_pc09
	[ "$status" -eq 0 ]
	run env PATH=/usr/bin:/bin "$LAUNCHER"
	[ "$status" -eq 0 ]
	grep -Fxq 'uvx --from msmcp-azure==3.0.0 azmcp server start --transport stdio --mode all --namespace containerapps --namespace group --read-only' "$PILOT_CALLS"
	grep -Fxq "$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin" "$PILOT_CALLS"
	grep -Fxq AzureCliCredential "$PILOT_CALLS"
	grep -Fxq false "$PILOT_CALLS"
	grep -Fq 'Environment="PATH=%h/.local/bin:/usr/local/bin:/usr/bin:/bin"' "$UNIT"
	grep -Fq 'api_key: "env:AZURE_MCP_CONTROL_PLANE_API_KEY"' "$PROFILE"
	grep -Fq 'level: warn' "$PROFILE"
	grep -Fq '127.0.0.1:49188' "$PROFILE"
	run ! grep -Eq '@latest|beta|49187|desktop-commander|/home/jesus' "$PROFILE" "$UNIT" "$LAUNCHER"
}

@test "doctor uses metadata only, never executes az or uvx, and probes only pilot health" {
	run "$CLI" --apply tunnel_pc09
	[ "$status" -eq 0 ]
	mkdir -p "${KEY%/*}"
	printf 'do-not-source; touch %s/leaked\n' "$HOME" >"$KEY"
	chmod 600 "$KEY"
	local before
	before="$(sha256sum "$KEY" "$LAUNCHER" "$PROFILE" "$UNIT")"
	run "$CLI" --doctor
	[ "$status" -eq 0 ]
	[[ "$output" != *do-not-source* ]]
	[ ! -e "$HOME/leaked" ]
	[ "$before" = "$(sha256sum "$KEY" "$LAUNCHER" "$PROFILE" "$UNIT")" ]
	grep -Fq 'http://127.0.0.1:49188/readyz' "$PILOT_CALLS"
	run ! grep -Eq '^(az|uvx|systemctl|tunnel-client) ' "$PILOT_CALLS"
	chmod 644 "$KEY"
	run "$CLI" --status
	[ "$status" -ne 0 ]
	[[ "$output" == *unsafe* ]]
}

@test "missing tooling fails actionably without writes or network" {
	for tool in az uvx tunnel-client; do
		mv "$HOME/.local/bin/$tool" "$HOME/.local/bin/$tool.saved"
		# OS installations may satisfy az/uvx; hide them with an explicit failing executable check below.
		if ! PATH=/usr/local/bin:/usr/bin:/bin command -v "$tool" >/dev/null; then
			run "$CLI" --apply tunnel_pc09
			[ "$status" -ne 0 ]
			[[ "$output" == *missing*"$tool"* ]]
		fi
		mv "$HOME/.local/bin/$tool.saved" "$HOME/.local/bin/$tool"
	done
	[ ! -e "$HOME/.config" ]
	[ ! -e "$PILOT_CALLS" ]
}

@test "conflicts, symlinks, different IDs and CLI keys never overwrite files" {
	mkdir -p "${UNIT%/*}"
	printf unrelated >"$UNIT"
	run "$CLI" --apply tunnel_pc09
	[ "$status" -ne 0 ]
	[ "$(cat "$UNIT")" = unrelated ]
	[ ! -e "$LAUNCHER" ]
	rm "$UNIT"
	run "$CLI" --apply tunnel_pc09
	[ "$status" -eq 0 ]
	run "$CLI" --apply tunnel_other
	[ "$status" -ne 0 ]
	run "$CLI" --runtime-key secret-canary
	[ "$status" -ne 0 ]
	[[ "$output" != *secret-canary* ]]
	mkdir -p "${KEY%/*}"
	ln -s "$BATS_TEST_TMPDIR/unrelated" "$KEY"
	run "$CLI" --apply tunnel_pc09
	[ "$status" -ne 0 ]
	[ ! -e "$BATS_TEST_TMPDIR/unrelated" ]
}

@test "conflicting modes cannot turn a requested preview into apply" {
	for flags in '--check --apply' '--apply --dry-run' '--status --apply'; do
		read -r -a flag_args <<<"$flags"
		run "$CLI" "${flag_args[@]}" tunnel_pc09
		[ "$status" -ne 0 ]
	done
	[ ! -e "$HOME/.config" ]
}

@test "apply preserves an existing runtime key and doctor fails unavailable health" {
	mkdir -p "${KEY%/*}"
	printf 'test-secret-canary\n' >"$KEY"
	chmod 600 "$KEY"
	local before
	before="$(sha256sum "$KEY")"
	run "$CLI" --apply tunnel_pc09
	[ "$status" -eq 0 ]
	[[ "$output" != *test-secret-canary* ]]
	[ "$before" = "$(sha256sum "$KEY")" ]
	run ! grep -q test-secret-canary "$PROFILE" "$UNIT" "$LAUNCHER"
	printf '#!/bin/sh\nexit 1\n' >"$HOME/.local/bin/curl"
	run "$CLI" --status
	[ "$status" -ne 0 ]
	[[ "$output" == *'readyz: unavailable'* ]]
	[[ "$output" != *test-secret-canary* ]]
}
