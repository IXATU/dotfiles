#!/usr/bin/env bash
# Install the pinned official Taplo CLI binary after SHA-256 verification.
set -euo pipefail

TAPLO_VERSION="0.10.0"
TARGET_DIR="${TAPLO_TARGET_DIR:-${HOME}/.local/bin}"
dry_run=0

case "${1:-}" in
--dry-run) dry_run=1 ;;
--upgrade | "") ;;
*)
	printf 'Usage: %s [--dry-run|--upgrade]\n' "$0" >&2
	exit 2
	;;
esac
case "${DRY_RUN:-}" in
1 | true | yes | on) dry_run=1 ;;
esac

taplo_version() {
	command -v taplo >/dev/null 2>&1 || return 1
	taplo --version 2>/dev/null | head -n 1 | sed -E 's/^[Tt]aplo[[:space:]]+//'
}

current="$(taplo_version || true)"
if [[ "$current" == "$TAPLO_VERSION" ]]; then
	printf 'OK Taplo already at canonical version %s\n' "$TAPLO_VERSION"
	exit 0
fi

case "$(uname -m)" in
x86_64 | amd64)
	asset="taplo-linux-x86_64.gz"
	checksum="8fe196b894ccf9072f98d4e1013a180306e17d244830b03986ee5e8eabeb6156"
	;;
aarch64 | arm64)
	asset="taplo-linux-aarch64.gz"
	checksum="033681d01eec8376c3fd38fa3703c79316f5e14bb013d859943b60a07bccdcc3"
	;;
*)
	printf 'FAIL unsupported Taplo architecture: %s\n' "$(uname -m)" >&2
	exit 1
	;;
esac
url="https://github.com/tamasfe/taplo/releases/download/${TAPLO_VERSION}/${asset}"

if [[ "$dry_run" -eq 1 ]]; then
	printf '[DRY_RUN] Would download official Taplo %s from %s\n' "$TAPLO_VERSION" "$url"
	printf '[DRY_RUN] Would verify SHA-256 %s and install to %s/taplo\n' "$checksum" "$TARGET_DIR"
	exit 0
fi

for command_name in curl gzip sha256sum install; do
	command -v "$command_name" >/dev/null 2>&1 || {
		printf 'FAIL missing required command: %s\n' "$command_name" >&2
		exit 1
	}
done

tmp_dir="$(mktemp -d -t install-taplo.XXXXXX)"
trap 'rm -rf "$tmp_dir"' EXIT INT TERM
curl -fsSL "$url" -o "${tmp_dir}/${asset}"
printf '%s  %s\n' "$checksum" "${tmp_dir}/${asset}" | sha256sum -c - >/dev/null
gzip -dc "${tmp_dir}/${asset}" >"${tmp_dir}/taplo"
mkdir -p "$TARGET_DIR"
install -m 0755 "${tmp_dir}/taplo" "${TARGET_DIR}/taplo"
printf 'OK Taplo %s installed at %s/taplo\n' "$TAPLO_VERSION" "$TARGET_DIR"
