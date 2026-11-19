#!/usr/bin/env bats

setup() {
	bats_require_minimum_version 1.5.0
	umask 077
	REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
	export HOME="$BATS_TEST_TMPDIR/home"
	export DC_TEST="$BATS_TEST_TMPDIR/state"
	mkdir -p "$HOME/.local/share" "$DC_TEST" "$BATS_TEST_TMPDIR/bin"
	export PATH="$BATS_TEST_TMPDIR/bin:$PATH"
	CLI="$REPO/bin/dotfiles-dc-activate"
	ACTIVE="$HOME/.local/share/ixatu-mcp"
	STAGE="$HOME/.local/share/ixatu-mcp-staged/0.3.4"
	fixture "$ACTIVE" 0.3.3
	fixture "$STAGE" 0.3.4
	printf active >"$DC_TEST/service"
	cat >"$BATS_TEST_TMPDIR/bin/systemctl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DC_TEST/systemctl"
case "$*" in
  *LoadState*) echo "${LOAD_STATE:-loaded}" ;;
  *MainPID*) echo 100 ;;
  *is-active*) [[ "$(cat "$DC_TEST/service")" == active ]] ;;
  *stop*) echo inactive > "$DC_TEST/service" ;;
  *start*)
    if [[ -f "$DC_TEST/fail-start" ]]; then rm "$DC_TEST/fail-start"; exit 1; fi
    echo active > "$DC_TEST/service" ;;
  *) exit 1 ;;
esac
MOCK
	cat >"$BATS_TEST_TMPDIR/bin/pgrep" <<'MOCK'
#!/usr/bin/env bash
[[ ! -f "$DC_TEST/no-child" ]] || exit 1
if [[ -f "$DC_TEST/retry-child" ]]; then rm "$DC_TEST/retry-child"; exit 1; fi
[[ "${*: -1}" == 100 ]] || exit 1
printf '101 node %s/.local/share/ixatu-mcp/node_modules/@wonderwhy-er/desktop-commander/dist/index.js\n' "$HOME"
MOCK
	cat >"$BATS_TEST_TMPDIR/bin/curl" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >> "$DC_TEST/curl"
if [[ -f "$DC_TEST/fail-curl" ]]; then exit 1; fi
if [[ -f "$DC_TEST/retry" ]]; then rm "$DC_TEST/retry"; exit 1; fi
printf 200
MOCK
	cat >"$BATS_TEST_TMPDIR/bin/grep" <<'MOCK'
#!/usr/bin/env bash
if [[ "${*: -1}" == /proc/self/cgroup ]]; then
  [[ "${DC_CALLER_IN_SERVICE:-0}" == 1 ]]
else
  exec /usr/bin/grep "$@"
fi
MOCK
	chmod +x "$BATS_TEST_TMPDIR/bin/"*
}

fixture() {
	local root="$1" version="$2"
	mkdir -p "$root/node_modules/@wonderwhy-er/desktop-commander"
	node - "$root" "$version" <<'JS'
const fs = require('fs');
const [root, version] = process.argv.slice(2);
const name = '@wonderwhy-er/desktop-commander';
const entry = {version, integrity: 'sha512-' + Buffer.alloc(64, 1).toString('base64')};
const packages = {'': {dependencies: {[name]: version}}, ['node_modules/' + name]: entry};
fs.writeFileSync(root + '/node_modules/' + name + '/package.json', JSON.stringify({name, version, main: 'dist/index.js', engines: {node: '>=16'}}));
fs.mkdirSync(root + '/node_modules/' + name + '/dist', {recursive: true});
fs.writeFileSync(root + '/node_modules/' + name + '/dist/index.js', '// fixture');
fs.writeFileSync(root + '/package.json', JSON.stringify({dependencies: {[name]: version}}));
for (const file of ['/package-lock.json', '/node_modules/.package-lock.json']) {
  fs.writeFileSync(root + file, JSON.stringify({lockfileVersion: 3, packages}));
}
JS
}

apply_candidate() {
	run "$CLI" --apply 0.3.4 --health-url http://127.0.0.1:9999/health
}

assert_old() {
	[ "$(cat "$DC_TEST/service")" = active ]
	[[ "$(cat "$ACTIVE/node_modules/@wonderwhy-er/desktop-commander/package.json")" == *'"version":"0.3.3"'* ]]
	[ -f "$STAGE/package-lock.json" ]
}

@test "activation help and status never mutate or contact service" {
	run "$CLI" --help
	[ "$status" -eq 0 ]
	[[ "$output" == *'--updater-apply'* ]]
	run "$CLI" --status
	[ "$status" -eq 0 ]
	[[ "$output" == *'ACTIVE 0.3.3'*'STAGED 0.3.4'* ]]
	[ ! -e "$DC_TEST/systemctl" ]
	assert_old
}

@test "activation defaults to validated dry-run and already active is no-op" {
	run "$CLI" 0.3.4
	[ "$status" -eq 0 ]
	[[ "$output" == *'DRY-RUN'* ]]
	run ! grep -Eq 'stop|start' "$DC_TEST/systemctl"
	run "$CLI" --apply 0.3.3
	[ "$status" -eq 0 ]
	[[ "$output" == *'already active'* ]]
	assert_old
}

@test "activation succeeds and preserves pre-existing backups" {
	mkdir -p "$HOME/.local/share/ixatu-mcp-rollback-0.3.2-old"
	echo keep >"$HOME/.local/share/ixatu-mcp-rollback-0.3.2-old/marker"
	apply_candidate
	[ "$status" -eq 0 ]
	[[ "$output" == *'ACTIVE 0.3.4'* ]]
	[ ! -d "$STAGE" ]
	[ "$(cat "$HOME/.local/share/ixatu-mcp-rollback-0.3.2-old/marker")" = keep ]
	[ "$(find "$HOME/.local/share" -maxdepth 1 -name 'ixatu-mcp-rollback-0.3.3-*' | wc -l)" -eq 1 ]
	[ "$(grep -c 'stop' "$DC_TEST/systemctl")" -eq 1 ]
	[ "$(grep -c 'start' "$DC_TEST/systemctl")" -eq 1 ]
}

@test "activation uses IXATU readiness default without extra flags" {
	run "$CLI" --apply 0.3.4
	[ "$status" -eq 0 ]
	[[ "$output" == *'ACTIVE 0.3.4'* ]]
	grep -Fq 'http://127.0.0.1:49187/readyz' "$DC_TEST/curl"
}

@test "activation retries initial HTTP failure" {
	touch "$DC_TEST/retry"
	apply_candidate
	[ "$status" -eq 0 ]
	[ "$(wc -l <"$DC_TEST/curl")" -eq 2 ]
}

@test "activation rolls back start failure and candidate can be retried" {
	touch "$DC_TEST/fail-start"
	apply_candidate
	[ "$status" -ne 0 ]
	[[ "$output" == *'ROLLBACK: previous runtime restored'* ]]
	assert_old
	apply_candidate
	[ "$status" -eq 0 ]
}

@test "activation waits at most 30 seconds then rolls back failed health" {
	# Fail health only for the new runtime; rollback health succeeds.
	cat >"$BATS_TEST_TMPDIR/bin/curl" <<'MOCK'
#!/usr/bin/env bash
[[ "$(cat "$HOME/.local/share/ixatu-mcp/node_modules/@wonderwhy-er/desktop-commander/package.json")" == *'"version":"0.3.3"'* ]] || exit 1
printf 200
MOCK
	local started=$SECONDS
	apply_candidate
	[ "$status" -ne 0 ]
	[ "$((SECONDS - started))" -ge 29 ]
	[ "$((SECONDS - started))" -lt 36 ]
	[[ "$output" == *'ROLLBACK: previous runtime restored'* ]]
	assert_old
}

@test "activation trap restores runtime on TERM during readiness" {
	cat >"$BATS_TEST_TMPDIR/bin/curl" <<'MOCK'
#!/usr/bin/env bash
if [[ ! -f "$DC_TEST/signalled" ]]; then
  touch "$DC_TEST/signalled"
  kill -TERM "$PPID"
  exit 1
fi
printf 200
MOCK
	apply_candidate
	[ "$status" -ne 0 ]
	assert_old
}

@test "activation refuses absent staging and downgrade and malformed version" {
	rm -rf "$STAGE"
	for version in 0.3.4 0.3.2 0.3.4-rc1 00.3.4 '../0.3.4'; do
		run "$CLI" --apply "$version"
		[ "$status" -ne 0 ]
	done
	[ ! -e "$DC_TEST/systemctl" ]
}

@test "activation refuses incompatible Node or invalid lock metadata before stop" {
	for mutation in version integrity engine hidden; do
		fixture "$STAGE" 0.3.4
		node - "$STAGE" "$mutation" <<'JS'
const fs = require('fs');
const [root, mutation] = process.argv.slice(2);
const file = mutation === 'hidden' ? '/node_modules/.package-lock.json' : '/package-lock.json';
const lock = JSON.parse(fs.readFileSync(root + file));
const entry = lock.packages['node_modules/@wonderwhy-er/desktop-commander'];
if (mutation === 'version') entry.version = '0.3.5';
if (mutation === 'integrity') entry.integrity = 'sha512-bad';
if (mutation === 'engine') entry.engines = {node: '>=999'};
if (mutation === 'hidden') entry.integrity = 'sha512-' + Buffer.alloc(64, 2).toString('base64');
fs.writeFileSync(root + file, JSON.stringify(lock));
JS
		apply_candidate
		[ "$status" -ne 0 ]
	done
	[ ! -e "$DC_TEST/systemctl" ]
	assert_old
}

@test "activation rejects hostile symlinks and writable trees; accepts internal npm links" {
	ln -s /tmp "$STAGE/escape"
	apply_candidate
	[ "$status" -ne 0 ]
	rm "$STAGE/escape"
	chmod o+w "$STAGE/node_modules"
	apply_candidate
	[ "$status" -ne 0 ]
	chmod o-w "$STAGE/node_modules"
	ln -s node_modules/@wonderwhy-er/desktop-commander/package.json "$STAGE/internal"
	run "$CLI" 0.3.4
	[ "$status" -eq 0 ]
	run ! grep -Eq 'stop|start' "$DC_TEST/systemctl"
}

@test "activation requires loaded active service and safe explicit health URL" {
	run env LOAD_STATE=not-found "$CLI" --apply 0.3.4 --health-url http://127.0.0.1/health
	[ "$status" -ne 0 ]
	echo inactive >"$DC_TEST/service"
	apply_candidate
	[ "$status" -ne 0 ]
	echo active >"$DC_TEST/service"
	for url in '' 'https://example.com/health' 'http://user:secret@127.0.0.1/health' 'http://127.0.0.1/health?token=secret'; do
		run "$CLI" --apply 0.3.4 --health-url "$url"
		[ "$status" -ne 0 ]
		[[ "$output" != *'secret'* ]]
	done
	run ! grep -Eq 'stop|start' "$DC_TEST/systemctl"
}

@test "activation refuses concurrent invocation without stopping service" {
	exec {guard}<"$HOME/.local/share"
	flock -x "$guard"
	apply_candidate
	[ "$status" -ne 0 ]
	[[ "$output" == *'another activation is running'* ]]
	run ! grep -Eq 'stop|start' "$DC_TEST/systemctl"
	exec {guard}<&-
	assert_old
}

@test "activation retries missing MCP child before accepting HTTP readiness" {
	touch "$DC_TEST/retry-child"
	apply_candidate
	[ "$status" -eq 0 ]
	[ ! -e "$DC_TEST/retry-child" ]
	[ "$(wc -l <"$DC_TEST/curl")" -eq 1 ]
}

@test "activation restores service if candidate directory move fails" {
	local real_mv
	real_mv="$(command -v mv)"
	export REAL_MV="$real_mv"
	cat >"$BATS_TEST_TMPDIR/bin/mv" <<'MOCK'
#!/usr/bin/env bash
if [[ "$*" == *ixatu-mcp-staged/0.3.4* && ! -f "$DC_TEST/move-failed" ]]; then
  touch "$DC_TEST/move-failed"
  exit 1
fi
exec "$REAL_MV" "$@"
MOCK
	chmod +x "$BATS_TEST_TMPDIR/bin/mv"
	apply_candidate
	[ "$status" -ne 0 ]
	[[ "$output" == *'ROLLBACK: previous runtime restored'* ]]
	assert_old
}

@test "activation rejects symlinked runtime roots before service operations" {
	mv "$STAGE" "$STAGE-real"
	ln -s "$STAGE-real" "$STAGE"
	apply_candidate
	[ "$status" -ne 0 ]
	[ ! -e "$DC_TEST/systemctl" ]
	mv "$ACTIVE" "$ACTIVE-real"
	ln -s "$ACTIVE-real" "$ACTIVE"
	run "$CLI" --status
	[ "$status" -ne 0 ]
}

@test "activation success survives failed final log output" {
	run bash -c '"$1" --apply 0.3.4 --health-url http://127.0.0.1:9999/health > /dev/full' _ "$CLI"
	[ "$status" -eq 0 ]
	[ ! -d "$STAGE" ]
	[ "$(grep -c 'stop' "$DC_TEST/systemctl")" -eq 1 ]
}

@test "activation works through the published symlink pattern" {
	mkdir -p "$HOME/.local/bin"
	ln -s "$CLI" "$HOME/.local/bin/dotfiles-dc-activate"
	run "$HOME/.local/bin/dotfiles-dc-activate" 0.3.4
	[ "$status" -eq 0 ]
	[[ "$output" == *DRY-RUN* ]]
	assert_old
}

@test "updater mode activates compatible patch and is idempotent" {
	run "$CLI" 0.3.4 --updater-apply
	[ "$status" -eq 0 ]
	[[ "$output" == *'ACTIVE 0.3.4'* ]]
	run "$CLI" 0.3.4 --updater-apply
	[ "$status" -eq 0 ]
	[[ "$output" == *'already active'* ]]
	[ "$(grep -c stop "$DC_TEST/systemctl")" -eq 1 ]
}

@test "updater mode refuses zero major minor and major transitions" {
	for version in 0.4.0 1.0.0; do
		run "$CLI" "$version" --updater-apply
		[ "$status" -ne 0 ]
		[[ "$output" == *'incompatible updater version'* ]]
	done
	[ ! -e "$DC_TEST/systemctl" ]
	assert_old
}

@test "updater mode opt-out and mock prevent service mutation" {
	for flag in DOTFILES_MCP_AUTO_ACTIVATE=0 DOTFILES_UPDATE_MOCK=1; do
		run env "$flag" "$CLI" 0.3.4 --updater-apply
		[ "$status" -ne 0 ]
		[[ "$output" == *'disabled'* ]]
	done
	[ ! -e "$DC_TEST/systemctl" ]
	assert_old
}

@test "updater mode rolls back failed restart with service isolation" {
	touch "$DC_TEST/fail-start"
	run "$CLI" 0.3.4 --updater-apply
	[ "$status" -ne 0 ]
	[[ "$output" == *ROLLBACK* ]]
	run ! grep -Eq 'azure|49188' "$DC_TEST/systemctl" "$DC_TEST/curl"
	assert_old
}

dc_updater() {
	local latest="$1"
	local semver
	semver="$(node -e 'const fs=require("fs"),m=require("module"); console.log(require("path").dirname(m.createRequire(fs.realpathSync(process.argv[1])).resolve("semver/package.json")))' "$(command -v npm)")"
	mkdir -p "$BATS_TEST_TMPDIR/bin/node_modules"
	ln -s "$semver" "$BATS_TEST_TMPDIR/bin/node_modules/semver"
	cat >"$BATS_TEST_TMPDIR/bin/npm" <<'MOCK'
#!/usr/bin/env bash
[[ "$1" == view ]] || { echo FORBIDDEN-package-operation >&2; exit 99; }
printf '%s\n' "$LATEST"
MOCK
	chmod +x "$BATS_TEST_TMPDIR/bin/npm"
	run env LATEST="$latest" DOTFILES_ROOT="$REPO" LOG_DIR="$DC_TEST" bash -c '
    set -euo pipefail
    source "$DOTFILES_ROOT/scripts/update/lib/dc_local.sh"
    result_info() { echo "$*"; }
    result_warn() { echo "$*"; }
    result_skip() { echo "$*"; }
    tool_snapshot_has() { return 0; }
    tool_snapshot_add() { echo "snapshot $*"; }
    update_dc_local
  '
	[ "$status" -eq 0 ]
	[[ "$output" != *FORBIDDEN* ]]
}

@test "DC updater invokes verified activation and records new active snapshot" {
	dc_updater 0.3.4
	[[ "$output" == *'INSTALLED/ACTIVATED 0.3.4'* ]]
	[[ "$output" == *'snapshot Desktop Commander 0.3.3 0.3.4'* ]]
	run ! grep -q azure "$DC_TEST/systemctl"
}

@test "DC updater equal stable version never invokes services or package install" {
	dc_updater 0.3.3
	[[ "$output" == *unchanged* ]]
	[ ! -e "$DC_TEST/systemctl" ]
	assert_old
}

@test "DC updater failure warns without aborting and old runtime is ready" {
	touch "$DC_TEST/fail-start"
	dc_updater 0.3.4
	[[ "$output" == *ROLLBACK* ]]
	assert_old
}

@test "DC updater incompatible version remains staged without restart" {
	fixture "$HOME/.local/share/ixatu-mcp-staged/0.4.0" 0.4.0
	dc_updater 0.4.0
	[[ "$output" == *ACTIVATION_PENDING* ]]
	[ ! -e "$DC_TEST/systemctl" ]
	assert_old
}

@test "DC updater inside live service leaves candidate pending without killing caller" {
	run env DC_CALLER_IN_SERVICE=1 "$CLI" 0.3.4 --updater-apply
	[ "$status" -ne 0 ]
	[[ "$output" == *'caller belongs to DC service'* ]]
	[ ! -e "$DC_TEST/systemctl" ]
	assert_old
}

@test "DC stable major permits compatible minor updates" {
	fixture "$ACTIVE" 1.1.0
	fixture "$HOME/.local/share/ixatu-mcp-staged/1.2.0" 1.2.0
	run "$CLI" 1.2.0 --updater-apply
	[ "$status" -eq 0 ]
	[[ "$output" == *'ACTIVE 1.2.0'* ]]
}

# Exercise validation directly: candidate code and service operations must not run.
validate_executable() {
	local executable="$1"
	node - "$STAGE" "$executable" <<'JS'
const fs = require('fs');
const [root, executable] = process.argv.slice(2);
const file = root + '/node_modules/@wonderwhy-er/desktop-commander/package.json';
const pkg = JSON.parse(fs.readFileSync(file));
// A valid main must not hide an invalid bin declaration.
pkg.bin = {'desktop-commander': executable};
if (executable === 'dist/index.js') delete pkg.main;
fs.writeFileSync(file, JSON.stringify(pkg));
JS
	run node "$REPO/scripts/dc/validate.cjs" stage "$STAGE" 0.3.4 "$(command -v npm)"
}

@test "DC validator accepts bin-only package without executing candidate code" {
	printf 'throw new Error("candidate executed");\n' >"$STAGE/node_modules/@wonderwhy-er/desktop-commander/dist/index.js"
	validate_executable dist/index.js
	[ "$status" -eq 0 ]
	[ ! -e "$DC_TEST/systemctl" ]
}

@test "DC validator refuses unsafe or absent bin even with valid main fallback" {
	for executable in '../../../package.json' /etc/passwd dist/missing.js ''; do
		validate_executable "$executable"
		[ "$status" -ne 0 ]
	done
	[ ! -e "$DC_TEST/systemctl" ]
}

@test "DC validator refuses bin symlink outside package and missing executable metadata" {
	local package="$STAGE/node_modules/@wonderwhy-er/desktop-commander"
	ln -s "$STAGE/package.json" "$package/dist/escape.js"
	validate_executable dist/escape.js
	[ "$status" -ne 0 ]
	node - "$package/package.json" <<'JS'
const fs = require('fs');
const file = process.argv[2], pkg = JSON.parse(fs.readFileSync(file));
delete pkg.bin;
delete pkg.main;
fs.writeFileSync(file, JSON.stringify(pkg));
JS
	run node "$REPO/scripts/dc/validate.cjs" stage "$STAGE" 0.3.4 "$(command -v npm)"
	[ "$status" -ne 0 ]
	[ ! -e "$DC_TEST/systemctl" ]
}

@test "DC validator ignores absent optional Windows engines, but rejects them if installed" {
	# npm lockfiles include platform-specific optional entries absent from Linux WSL.
	node - "$STAGE" <<'JS'
const fs = require('fs');
const root = process.argv[2];
const path = root + '/package-lock.json';
const lock = JSON.parse(fs.readFileSync(path));
lock.packages['node_modules/@img/sharp-win32-ia32'] = {
  version: '0.35.5', optional: true, os: ['win32'], cpu: ['ia32'],
  engines: {node: '^20.9.0'}
};
fs.writeFileSync(path, JSON.stringify(lock));
JS
	run node "$REPO/scripts/dc/validate.cjs" stage "$STAGE" 0.3.4 "$(command -v npm)"
	[ "$status" -eq 0 ]
	mkdir -p "$STAGE/node_modules/@img/sharp-win32-ia32"
	run node "$REPO/scripts/dc/validate.cjs" stage "$STAGE" 0.3.4 "$(command -v npm)"
	[ "$status" -ne 0 ]
}

@test "DC updater corrects writable owned staging parent before activating" {
	chmod 775 "$HOME/.local/share/ixatu-mcp-staged"
	dc_updater 0.3.4
	[[ "$output" == *'INSTALLED/ACTIVATED 0.3.4'* ]]
	[ "$(stat -c %a "$HOME/.local/share/ixatu-mcp-staged")" -eq 700 ]
}
