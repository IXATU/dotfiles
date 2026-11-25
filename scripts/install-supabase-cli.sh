#!/usr/bin/env bash
# Converge the official stable Linux CLI; never authenticate or start services.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/install_common.sh
source "${SCRIPT_DIR}/lib/install_common.sh"
TARGET_DIR="${SUPABASE_CLI_TARGET_DIR:-${HOME}/.local/bin}"
API_URL="https://api.github.com/repos/supabase/cli/releases/latest"

case "${1:-}" in
--dry-run) DRY_RUN=1 ;;
--upgrade | "") ;;
*)
	printf 'Usage: %s [--dry-run|--upgrade]\n' "$0" >&2
	exit 2
	;;
esac
if install_is_truthy "${DRY_RUN:-}"; then
	printf '[DRY_RUN] Resolve stable Supabase CLI from %s\n' "$API_URL"
	printf '[DRY_RUN] Verify official Linux amd64/arm64 tarball against upstream checksums.txt; atomically install to %s/supabase\n' "$TARGET_DIR"
	exit 0
fi

[[ "$(uname -s)" == Linux ]] || {
	install_label FAIL 'Supabase CLI requires Linux'
	exit 1
}
case "$(uname -m)" in
x86_64 | amd64) arch=amd64 ;;
aarch64 | arm64) arch=arm64 ;;
*)
	install_label FAIL 'Unsupported Supabase CLI architecture'
	exit 1
	;;
esac
for cmd in curl jq sha256sum tar timeout; do
	command -v "$cmd" >/dev/null 2>&1 || {
		install_label FAIL "Missing prerequisite: $cmd"
		exit 1
	}
done

# Private workspace; staging lives on the destination filesystem for atomic rename.
tmp_dir="$(mktemp -d -t install-supabase-cli.XXXXXX)"
stage_dir=""
trap 'rm -rf -- "$tmp_dir"; if [[ -n "$stage_dir" ]]; then rm -rf -- "$stage_dir"; fi' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
curl_args=(--fail --silent --show-error --location --proto '=https' --proto-redir '=https' --connect-timeout 10 --max-time 120)
curl "${curl_args[@]}" "$API_URL" -o "$tmp_dir/release.json"
# Fail closed on missing flags, prerelease tags, malformed JSON, or unsafe tags.
tag="$(jq -er 'select(.draft == false and .prerelease == false) | .tag_name | select(type == "string" and test("^v[0-9]+\\.[0-9]+\\.[0-9]+$"))' "$tmp_dir/release.json")"
version="${tag#v}"
asset="supabase_${version}_linux_${arch}.tar.gz"
base_url="https://github.com/supabase/cli/releases/download/${tag}"
# Require exactly one official asset of each kind. Never trust arbitrary metadata URLs.
for name in "$asset" checksums.txt; do
	jq -e --arg name "$name" --arg url "$base_url/$name" \
		'[.assets[] | select(.name == $name)] | length == 1 and .[0].browser_download_url == $url' \
		"$tmp_dir/release.json" >/dev/null
done
current=""
if [[ -x "$TARGET_DIR/supabase" ]]; then
	current="$(timeout 15 "$TARGET_DIR/supabase" --version 2>/dev/null || true)"
fi
if [[ "$current" == "$version" ]]; then
	install_label OK "Supabase CLI ${version} already installed at ${TARGET_DIR}/supabase"
	exit 0
fi
curl "${curl_args[@]}" "$base_url/checksums.txt" -o "$tmp_dir/checksums.txt"
curl "${curl_args[@]}" "$base_url/$asset" -o "$tmp_dir/$asset"
checksum="$(awk -v name="$asset" '$2 == name { print $1 }' "$tmp_dir/checksums.txt")"
[[ "$checksum" =~ ^[a-fA-F0-9]{64}$ ]] || {
	install_label FAIL 'Missing, duplicate or invalid SHA256 entry'
	exit 1
}
printf '%s  %s\n' "$checksum" "$tmp_dir/$asset" | sha256sum -c - >/dev/null
mkdir -p "$TARGET_DIR"
stage_dir="$(mktemp -d "$TARGET_DIR/.supabase-stage.XXXXXX")"
# Stream only the named binary into a new regular file; archive paths/links cannot
# write outside staging. tar errors (including missing member) abort the install.
tar -xzOf "$tmp_dir/$asset" supabase >"$stage_dir/supabase"
[[ -s "$stage_dir/supabase" ]]
chmod 0755 "$stage_dir/supabase"
[[ "$(timeout 15 "$stage_dir/supabase" --version)" == "$version" ]] || {
	install_label FAIL 'Downloaded CLI version mismatch'
	exit 1
}
timeout 15 "$stage_dir/supabase" --help >/dev/null
# -T replaces a symlink itself and refuses directories; no in-place truncation.
mv -fT -- "$stage_dir/supabase" "$TARGET_DIR/supabase"
install_label OK "Supabase CLI ${version} installed at ${TARGET_DIR}/supabase"
