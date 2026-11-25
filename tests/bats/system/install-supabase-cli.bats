#!/usr/bin/env bats

setup() {
	load '../helpers/common'
	DOTFILES_DIR="$(cd "${BATS_TEST_DIRNAME}/../../.." && pwd)"
	setup_temp_dir
	export HOME="$TEST_TEMP_DIR/home"
	export SUPABASE_CLI_TARGET_DIR="$HOME/.local/bin"
	export SUPABASE_FIXTURE="$TEST_TEMP_DIR/fixture"
	export SUPABASE_CALLS="$TEST_TEMP_DIR/calls"
	export SUPABASE_CANDIDATE_CALLS="$TEST_TEMP_DIR/candidate-calls"
	mkdir -p "$SUPABASE_CLI_TARGET_DIR" "$SUPABASE_FIXTURE" "$TEST_TEMP_DIR/bin" "$TEST_TEMP_DIR/payload"
	export PATH="$TEST_TEMP_DIR/bin:$PATH"
	export TEST_ARCH=x86_64 TEST_OS=Linux
	export TEST_RELEASE_VERSION=3.4.0
	export FIXTURE_VERSION=3.4.0
	cat >"$TEST_TEMP_DIR/bin/uname" <<'MOCK'
#!/usr/bin/env bash
case "$1" in
-s) echo "$TEST_OS" ;;
-m) echo "$TEST_ARCH" ;;
*) exit 97 ;;
esac
MOCK
	# Strict allowlist: every network request is local, even on failure paths.
	cat >"$TEST_TEMP_DIR/bin/curl" <<'MOCK'
#!/usr/bin/env bash
set -eu
printf '%s\n' "$*" >>"$SUPABASE_CALLS"
url="${@: -3:1}"
[[ "${@: -2:1}" == -o ]] || exit 98
case "$url" in
https://api.github.com/repos/supabase/cli/releases/latest) file=release.json ;;
"https://github.com/supabase/cli/releases/download/v${TEST_RELEASE_VERSION}/checksums.txt") file=checksums.txt ;;
"https://github.com/supabase/cli/releases/download/v${TEST_RELEASE_VERSION}/supabase_${TEST_RELEASE_VERSION}_linux_amd64.tar.gz") file="supabase_${TEST_RELEASE_VERSION}_linux_amd64.tar.gz" ;;
"https://github.com/supabase/cli/releases/download/v${TEST_RELEASE_VERSION}/supabase_${TEST_RELEASE_VERSION}_linux_arm64.tar.gz") file="supabase_${TEST_RELEASE_VERSION}_linux_arm64.tar.gz" ;;
*) exit 99 ;;
esac
[[ "${FAIL_DOWNLOAD:-}" != "$file" ]] || exit 22
cp "$SUPABASE_FIXTURE/$file" "${@: -1}"
MOCK
	chmod +x "$TEST_TEMP_DIR/bin/"*
	cat >"$TEST_TEMP_DIR/payload/supabase" <<'MOCK'
#!/usr/bin/env bash
printf '%s\n' "$*" >>"$SUPABASE_CANDIDATE_CALLS"
case "${1:-}" in
--version) echo "$FIXTURE_VERSION" ;;
--help) [[ "${FAIL_HELP:-0}" == 0 ]] ;;
*) exit 96 ;;
esac
MOCK
	chmod +x "$TEST_TEMP_DIR/payload/supabase"
	for arch in amd64 arm64; do
		tar -czf "$SUPABASE_FIXTURE/supabase_3.4.0_linux_${arch}.tar.gz" -C "$TEST_TEMP_DIR/payload" supabase
	done
	refresh_checksums
	jq -n '{tag_name:"v3.4.0",draft:false,prerelease:false,assets:(["supabase_3.4.0_linux_amd64.tar.gz","supabase_3.4.0_linux_arm64.tar.gz","checksums.txt"] | map({name:.,browser_download_url:("https://github.com/supabase/cli/releases/download/v3.4.0/"+.)}))}' >"$SUPABASE_FIXTURE/release.json"
}

teardown() {
	teardown_temp_dir
}

refresh_checksums() {
	(cd "$SUPABASE_FIXTURE" && sha256sum supabase_*.tar.gz) >"$SUPABASE_FIXTURE/checksums.txt"
}

old_binary() {
	printf '#!/usr/bin/env bash\necho 3.3.0\n' >"$SUPABASE_CLI_TARGET_DIR/supabase"
	chmod +x "$SUPABASE_CLI_TARGET_DIR/supabase"
	cp "$SUPABASE_CLI_TARGET_DIR/supabase" "$TEST_TEMP_DIR/old"
}

install_cli() {
	run bash "$DOTFILES_DIR/scripts/install-supabase-cli.sh" "$@"
}

assert_preserved() {
	[[ "$status" -ne 0 ]]
	cmp "$TEST_TEMP_DIR/old" "$SUPABASE_CLI_TARGET_DIR/supabase"
	[[ "$("$SUPABASE_CLI_TARGET_DIR/supabase" --version)" == 3.3.0 ]]
	[[ -z "$(find "$SUPABASE_CLI_TARGET_DIR" -name '.supabase-stage.*' -print)" ]]
}

@test "Supabase installs stable official amd64 and arm64 archives and is idempotent" {
	for TEST_ARCH in x86_64 aarch64; do
		export TEST_ARCH
		rm -f "$SUPABASE_CLI_TARGET_DIR/supabase" "$SUPABASE_CALLS"
		install_cli
		[[ "$status" -eq 0 ]]
		[[ "$("$SUPABASE_CLI_TARGET_DIR/supabase" --version)" == 3.4.0 ]]
		[[ "$(stat -c %a "$SUPABASE_CLI_TARGET_DIR/supabase")" == 755 ]]
		[[ "$(wc -l <"$SUPABASE_CALLS")" -eq 3 ]]
		cp "$SUPABASE_CLI_TARGET_DIR/supabase" "$TEST_TEMP_DIR/installed"
		install_cli
		[[ "$status" -eq 0 && "$output" == *'already installed'* ]]
		cmp "$TEST_TEMP_DIR/installed" "$SUPABASE_CLI_TARGET_DIR/supabase"
		[[ "$(wc -l <"$SUPABASE_CALLS")" -eq 4 ]]
	done
}

@test "Supabase upgrades an older managed binary without touching a symlink target" {
	old_binary
	mv "$SUPABASE_CLI_TARGET_DIR/supabase" "$TEST_TEMP_DIR/external"
	ln -s "$TEST_TEMP_DIR/external" "$SUPABASE_CLI_TARGET_DIR/supabase"
	install_cli
	[[ "$status" -eq 0 ]]
	[[ ! -L "$SUPABASE_CLI_TARGET_DIR/supabase" ]]
	[[ "$("$SUPABASE_CLI_TARGET_DIR/supabase" --version)" == 3.4.0 ]]
	cmp "$TEST_TEMP_DIR/old" "$TEST_TEMP_DIR/external"
}

@test "Supabase fails closed and preserves old binary on any download failure" {
	old_binary
	for FAIL_DOWNLOAD in release.json checksums.txt supabase_3.4.0_linux_amd64.tar.gz; do
		export FAIL_DOWNLOAD
		install_cli
		assert_preserved
	done
}

@test "Supabase rejects draft prerelease malformed and untrusted release metadata" {
	old_binary
	cp "$SUPABASE_FIXTURE/release.json" "$TEST_TEMP_DIR/release"
	for filter in '.prerelease=true' '.draft=true' '.tag_name="v3.5.0-beta.1"' 'del(.prerelease)' '.tag_name="../../bad"' '.assets=[]' '.assets[0].browser_download_url="https://example.com/binary"' '.assets += [.assets[0]]'; do
		jq "$filter" "$TEST_TEMP_DIR/release" >"$SUPABASE_FIXTURE/release.json"
		install_cli
		assert_preserved
	done
	printf 'invalid json' >"$SUPABASE_FIXTURE/release.json"
	install_cli
	assert_preserved
}

@test "Supabase rejects missing duplicate malformed and mismatching SHA256 checksums" {
	old_binary
	cp "$SUPABASE_FIXTURE/checksums.txt" "$TEST_TEMP_DIR/checksums"
	for mode in missing duplicate malformed mismatch; do
		case "$mode" in
		missing) : >"$SUPABASE_FIXTURE/checksums.txt" ;;
		duplicate) cat "$TEST_TEMP_DIR/checksums" "$TEST_TEMP_DIR/checksums" >"$SUPABASE_FIXTURE/checksums.txt" ;;
		malformed) echo 'bad  supabase_3.4.0_linux_amd64.tar.gz' >"$SUPABASE_FIXTURE/checksums.txt" ;;
		mismatch) printf '%064d  supabase_3.4.0_linux_amd64.tar.gz\n' 0 >"$SUPABASE_FIXTURE/checksums.txt" ;;
		esac
		install_cli
		assert_preserved
		[[ ! -e "$SUPABASE_CANDIDATE_CALLS" ]]
	done
}

@test "Supabase preserves old binary on corrupt archive missing member version or help failure" {
	old_binary
	local archive="$SUPABASE_FIXTURE/supabase_3.4.0_linux_amd64.tar.gz"
	cp "$archive" "$TEST_TEMP_DIR/archive"
	printf 'corrupt' >"$archive"
	refresh_checksums
	install_cli
	assert_preserved
	tar -czf "$archive" --files-from /dev/null
	refresh_checksums
	install_cli
	assert_preserved
	cp "$TEST_TEMP_DIR/archive" "$archive"
	refresh_checksums
	export FIXTURE_VERSION=3.3.0
	install_cli
	assert_preserved
	export FIXTURE_VERSION=3.4.0 FAIL_HELP=1
	install_cli
	assert_preserved
}

@test "Supabase preserves old binary on failed atomic publication" {
	old_binary
	printf '#!/usr/bin/env bash\nexit 1\n' >"$TEST_TEMP_DIR/bin/mv"
	chmod +x "$TEST_TEMP_DIR/bin/mv"
	install_cli
	assert_preserved
}

@test "Supabase dry runs flags and Make target never use network or create destination" {
	rm -rf "$SUPABASE_CLI_TARGET_DIR"
	install_cli --dry-run
	[[ "$status" -eq 0 && "$output" == *DRY_RUN* ]]
	run env DRY_RUN=1 bash "$DOTFILES_DIR/scripts/install-supabase-cli.sh"
	[[ "$status" -eq 0 ]]
	run make -C "$DOTFILES_DIR" install-supabase-cli DRY_RUN=1
	[[ "$status" -eq 0 && "$output" == *DRY_RUN* ]]
	[[ ! -e "$SUPABASE_CALLS" && ! -d "$SUPABASE_CLI_TARGET_DIR" ]]
}

@test "Supabase unsupported platforms fail before network and preserve old binary" {
	old_binary
	export TEST_ARCH=riscv64
	install_cli
	assert_preserved
	export TEST_ARCH=x86_64 TEST_OS=Darwin
	install_cli
	assert_preserved
	[[ ! -e "$SUPABASE_CALLS" ]]
}

# Source with no selected section, then run only the real Supabase update step.
# HOME and network are isolated; other installers and service actions cannot run.
update_cli() {
	run bash -c '
set -euo pipefail
repo="$1"
set -- --section none
export DOTFILES_UPDATE_RUN_DIR="$HOME/run"
source "$repo/scripts/update/update-wsl.sh"
run_supabase_cli
capture_workstation_snapshot
' bash "$DOTFILES_DIR"
}

@test "Supabase updater reports installed updated unchanged and logs through existing mechanisms" {
	for expected in installed updated unchanged; do
		case "$expected" in
		installed) before="" ;;
		updated) old_binary; before=3.3.0 ;;
		unchanged) before=3.4.0 ;;
		esac
		rm -rf "$HOME/run"
		update_cli
		[[ "$status" -eq 0 ]]
		grep -q $'OK\tWSL\tSupabase CLI\t' "$HOME/run/wsl-results.tsv"
		grep -q "Supabase CLI"$'\t'"$before"$'\t3.4.0\t'"$expected" "$HOME/run/tool-snapshot.tsv"
		[[ -s "$HOME/run/logs/wsl-supabase-cli.log" ]]
	done
}

@test "Supabase updater records incident on network failure and snapshots preserved old version" {
	old_binary
	export FAIL_DOWNLOAD=release.json
	update_cli
	[[ "$status" -eq 0 ]]
	grep -q $'FAIL\tWSL\tSupabase CLI\t' "$HOME/run/wsl-results.tsv"
	grep -q $'Supabase CLI\t3.3.0\t3.3.0\tunchanged' "$HOME/run/tool-snapshot.tsv"
	cmp "$TEST_TEMP_DIR/old" "$SUPABASE_CLI_TARGET_DIR/supabase"
}

@test "Supabase updater mock records unavailable snapshot and never downloads" {
	run env DOTFILES_UPDATE_MOCK=1 DOTFILES_UPDATE_RUN_DIR="$HOME/run" \
		bash "$DOTFILES_DIR/scripts/update/update-wsl.sh" --section tools
	[[ "$status" -eq 0 ]]
	grep -q $'Supabase CLI\t\t\tunavailable' "$HOME/run/tool-snapshot.tsv"
	[[ ! -e "$SUPABASE_CALLS" && ! -e "$HOME/run/logs/wsl-supabase-cli.log" ]]
}

@test "Supabase resolves a future stable tag dynamically without a code version pin" {
	export TEST_RELEASE_VERSION=4.1.2 FIXTURE_VERSION=4.1.2
	for arch in amd64 arm64; do
		mv "$SUPABASE_FIXTURE/supabase_3.4.0_linux_${arch}.tar.gz" "$SUPABASE_FIXTURE/supabase_4.1.2_linux_${arch}.tar.gz"
	done
	sed -i 's/3.4.0/4.1.2/g' "$SUPABASE_FIXTURE/release.json"
	refresh_checksums
	install_cli
	[[ "$status" -eq 0 ]]
	[[ "$("$SUPABASE_CLI_TARGET_DIR/supabase" --version)" == 4.1.2 ]]
	grep -q '/v4.1.2/supabase_4.1.2_linux_amd64.tar.gz' "$SUPABASE_CALLS"
}
