#!/usr/bin/env bats

setup() {
	DOTFILES_DIR="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
	export DOTFILES_DIR
	export HOME="$BATS_TEST_TMPDIR/home"
	export MOCK_BIN="$BATS_TEST_TMPDIR/bin" CALLS="$BATS_TEST_TMPDIR/calls"
	export PYPI_JSON="$BATS_TEST_TMPDIR/pypi.json"
	export DOTFILES_UPDATE_RUN_DIR="$BATS_TEST_TMPDIR/run"
	unset DOTFILES_UPDATE_MOCK
	export DOTFILES_MCP_AUTO_ACTIVATE=0
	mkdir -p "$HOME/.local/share/ixatu-azure-mcp-pilot" "$MOCK_BIN"
	export LAUNCHER="$HOME/.local/share/ixatu-azure-mcp-pilot/start.sh"
	printf 'exec uvx --from msmcp-azure==3.0.0 azmcp server start --transport stdio\n' >"$LAUNCHER"
	printf '{"info":{"version":"4.0.0b1"},"releases":{"3.0.0":[{}],"4.0.0b1":[{}],"5.0.0rc1":[{}],"6.0.0.dev1":[{}],"7.0.0":[{"yanked":true}],"8.0.0":[]}}' >"$PYPI_JSON"
	# Restricted PATH: snapshots cannot invoke any workstation CLI.
	for cmd in bash mkdir dirname sed awk head tr sort tail date python3 cat grep; do
		ln -s "$(command -v "$cmd")" "$MOCK_BIN/$cmd"
	done
	cat >"$MOCK_BIN/curl" <<'CURL'
#!/usr/bin/env bash
printf 'curl %s\n' "$*" >> "$CALLS"
[[ "${CURL_FAIL:-0}" == 0 ]] || { echo private-network-error >&2; exit 28; }
cat "$PYPI_JSON"
CURL
	for cmd in uvx uv systemctl tunnel-client; do
		cat >"$MOCK_BIN/$cmd" <<'GUARD'
#!/usr/bin/env bash
printf 'FORBIDDEN %s\n' "$0 $*" >> "$CALLS"
exit 99
GUARD
	done
	chmod +x "$MOCK_BIN/curl" "$MOCK_BIN/uvx" "$MOCK_BIN/uv" "$MOCK_BIN/systemctl" "$MOCK_BIN/tunnel-client"
}

report() {
	run env PATH="$MOCK_BIN" bash -c '
    set -euo pipefail
    source "$DOTFILES_DIR/scripts/update/lib/environment.sh"
    source "$DOTFILES_DIR/scripts/update/lib/results.sh"
    source "$DOTFILES_DIR/scripts/update/lib/azure_mcp.sh"
    tool_snapshot_has() { [[ -f "$TOOL_SNAPSHOT_FILE" ]] && awk -F "\t" '\''$1 == "Azure MCP" {found=1} END {exit !found}'\'' "$TOOL_SNAPSHOT_FILE"; }
    result_init "$DOTFILES_UPDATE_RUN_DIR/results.tsv"
    tool_snapshot_init "$DOTFILES_UPDATE_RUN_DIR/snapshot.tsv"
    update_azure_mcp
    azure_mcp_snapshot
    cat "$RESULTS_FILE" "$TOOL_SNAPSHOT_FILE"
  '
	[ "$status" -eq 0 ]
	if [[ -f "$CALLS" ]]; then
		! grep -q FORBIDDEN "$CALLS"
	fi
}

@test "Azure MCP pin and stable latest ignore beta rc dev yanked and empty releases" {
	report
	[[ "$output" == *'PINNED 3.0.0; latest stable 3.0.0; unchanged'* ]]
	[[ "$output" == *$'Azure MCP\t3.0.0\t3.0.0\tunchanged'* ]]
	[ "$(grep -c '^Azure MCP' "$DOTFILES_UPDATE_RUN_DIR/snapshot.tsv")" -eq 1 ]
	grep -q -- '--connect-timeout 5 --max-time 15 --retry 0 https://pypi.org/pypi/msmcp-azure/json' "$CALLS"
}

@test "Azure MCP detects original PC08 launcher with an absolute uvx path" {
	printf 'exec /home/jesus/.local/bin/uvx --from msmcp-azure==3.0.0 \\\n azmcp server start --read-only\n' >"$LAUNCHER"
	report
	[[ "$output" == *'PINNED 3.0.0; latest stable 3.0.0; unchanged'* ]]
}

@test "Azure MCP maintenance opt-out reports pending without changing launcher" {
	printf '{"releases":{"3.9.0":[{}],"3.10.0":[{}],"4.0.0b1":[{}]}}' >"$PYPI_JSON"
	cp "$LAUNCHER" "$BATS_TEST_TMPDIR/before"
	report
	[[ "$output" == *'PINNED 3.0.0; latest stable 3.10.0; ACTIVATION_PENDING'* ]]
	[[ "$output" == *$'Azure MCP\t3.0.0\t3.0.0\tunchanged'* ]]
	cmp "$LAUNCHER" "$BATS_TEST_TMPDIR/before"
}

@test "Azure MCP different configured pin is reported and never downgraded" {
	sed -i 's/3.0.0/9.1.2/' "$LAUNCHER"
	report
	[[ "$output" == *'PINNED 9.1.2; latest stable 3.0.0; unchanged'* ]]
	[[ "$output" == *$'Azure MCP\t9.1.2\t9.1.2\tunchanged'* ]]
}

@test "Azure MCP network failure warns gracefully retaining snapshot without raw errors" {
	export CURL_FAIL=1
	report
	[[ "$output" == *'WARN'*'PINNED 3.0.0; latest stable unknown'* ]]
	[[ "$output" != *private-network-error* ]]
	[[ "$output" == *$'Azure MCP\t3.0.0\t3.0.0\tunchanged'* ]]
}

@test "Azure MCP invalid JSON or no stable release yields unknown latest" {
	for payload in 'invalid' '{"releases":{"4.0.0b1":[{}]}}' '{"info":{"version":"3.0.0"}}'; do
		printf '%s' "$payload" >"$PYPI_JSON"
		report
		[[ "$output" == *'latest stable unknown'* ]]
	done
}

@test "Azure MCP absent optional pilot skips without network" {
	rm "$LAUNCHER"
	report
	[[ "$output" == *'SKIP'*'Optional managed pilot absent'* ]]
	[ ! -e "$CALLS" ]
}

@test "Azure MCP unrecognized launcher warns without executing or disclosing content" {
	printf 'echo private-launcher-content\nexec uvx --from msmcp-azure==4.0.0b1 azmcp server start --transport stdio\n' >"$LAUNCHER"
	report
	[[ "$output" == *'WARN'*'Launcher pin unavailable'* ]]
	[[ "$output" != *private-launcher-content* ]]
	[ ! -e "$CALLS" ]
}

@test "Azure MCP missing curl or Python warns and preserves pin" {
	for cmd in curl python3; do
		mv "$MOCK_BIN/$cmd" "$BATS_TEST_TMPDIR/$cmd"
		report
		[[ "$output" == *'WARN'*'PINNED 3.0.0; latest stable unknown'* ]]
		mv "$BATS_TEST_TMPDIR/$cmd" "$MOCK_BIN/$cmd"
	done
}

@test "Azure MCP mock reports pin without network" {
	export DOTFILES_UPDATE_MOCK=1
	report
	[[ "$output" == *'PINNED 3.0.0; latest stable not checked (mock)'* ]]
	[ ! -e "$CALLS" ]
}

@test "Azure MCP mock with unrecognized launcher skips without workstation warnings" {
	export DOTFILES_UPDATE_MOCK=1
	printf '# custom launcher\n' >"$LAUNCHER"
	report
	[[ "$output" == *'SKIP'*'PINNED unknown; latest stable not checked (mock)'* ]]
	[[ "$output" != *WARN* ]]
	[ ! -e "$CALLS" ]
}

@test "Azure MCP snapshot integrated outside tools and mock tools never query PyPI" {
	# Permit only inert version probes already used by the existing updater.
	printf '#!/usr/bin/env bash\nexit 0\n' >"$MOCK_BIN/uv"
	for section in none tools; do
		run env PATH="$MOCK_BIN" DOTFILES_UPDATE_MOCK=1 bash "$DOTFILES_DIR/scripts/update/update-wsl.sh" --section "$section"
		[ "$status" -eq 0 ]
		grep -q $'^Azure MCP\t3.0.0\t3.0.0\tunchanged$' "$DOTFILES_UPDATE_RUN_DIR/tool-snapshot.tsv"
		[ ! -e "$CALLS" ]
		if [[ "$section" == tools ]]; then
			grep -q 'latest stable not checked (mock)' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
		else
			! grep -q 'Azure MCP' "$DOTFILES_UPDATE_RUN_DIR/wsl-results.tsv"
		fi
	done
}

activation_boundary() {
	export DOTFILES_MCP_AUTO_ACTIVATE=1 DOTFILES_ROOT="$BATS_TEST_TMPDIR/checkout"
	mkdir -p "$DOTFILES_ROOT/scripts/update"
	cat >"$DOTFILES_ROOT/scripts/update/azure-mcp-activate.py" <<'PY'
import os, pathlib, sys
p = pathlib.Path(os.environ['LAUNCHER'])
assert sys.argv[1] == '3.1.0'
if os.environ.get('ACTIVATION_FAIL'):
    print('ROLLBACK: previous launcher restored; service ready')
    sys.exit(1)
p.write_text(p.read_text().replace('3.0.0', sys.argv[1]))
print('INSTALLED/ACTIVATED ' + sys.argv[1])
PY
	printf '{"releases":{"3.1.0":[{}]}}' >"$PYPI_JSON"
}

@test "Azure updater default activation boundary updates pin and final snapshot" {
	activation_boundary
	report
	[[ "$output" == *'INSTALLED/ACTIVATED 3.1.0'* ]]
	grep -q $'^Azure MCP\t3.0.0\t3.1.0\tupdated$' "$DOTFILES_UPDATE_RUN_DIR/snapshot.tsv"
}

@test "Azure updater rollback warns and continues with previous pin" {
	activation_boundary
	export ACTIVATION_FAIL=1
	report
	[[ "$output" == *ROLLBACK* ]]
	[[ "$(cat "$LAUNCHER")" == *3.0.0* ]]
}

@test "Azure updater major mismatch skips activation even with automation enabled" {
	activation_boundary
	printf '{"releases":{"4.0.0":[{}]}}' >"$PYPI_JSON"
	report
	[[ "$output" == *ACTIVATION_PENDING* ]]
	[[ "$(cat "$LAUNCHER")" == *3.0.0* ]]
}

@test "Azure partially yanked release is never an automatic candidate" {
	printf '{"releases":{"3.0.0":[{}],"3.1.0":[{}, {"yanked":true}]}}' >"$PYPI_JSON"
	report
	[[ "$output" == *'latest stable 3.0.0; unchanged'* ]]
}

@test "Azure pin reader refuses launcher symlink before opening its contents" {
	mv "$LAUNCHER" "$BATS_TEST_TMPDIR/unrelated"
	ln -s "$BATS_TEST_TMPDIR/unrelated" "$LAUNCHER"
	report
	[[ "$output" == *'Launcher pin unavailable'* ]]
	[ ! -e "$CALLS" ]
}

@test "Azure pin reader refuses symlinked runtime ancestors" {
	mv "$HOME/.local/share/ixatu-azure-mcp-pilot" "$BATS_TEST_TMPDIR/unrelated"
	ln -s "$BATS_TEST_TMPDIR/unrelated" "$HOME/.local/share/ixatu-azure-mcp-pilot"
	report
	[[ "$output" == *'Launcher pin unavailable'* ]]
	[ ! -e "$CALLS" ]
}
