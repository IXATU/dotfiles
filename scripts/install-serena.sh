#!/usr/bin/env bash
# Install or converge Serena to the dotfiles-owned canonical version via uv tool.
set -euo pipefail

SERENA_VERSION="1.7.0"
SERENA_PACKAGE="serena-agent==${SERENA_VERSION}"
dry_run=0

case "${1:-}" in
--dry-run) dry_run=1 ;;
"") ;;
*)
	printf 'Usage: %s [--dry-run]\n' "$0" >&2
	exit 2
	;;
esac

case "${DRY_RUN:-}" in
1 | true | yes | on) dry_run=1 ;;
esac

serena_version() {
	command -v serena >/dev/null 2>&1 || return 1
	serena --version 2>/dev/null | head -n 1 | sed -E 's/^[Ss]erena[[:space:]]+//'
}

current="$(serena_version || true)"
owned=0
if command -v uv >/dev/null 2>&1 && uv tool list 2>/dev/null | grep -q "^serena-agent v${SERENA_VERSION}$"; then
	owned=1
fi
if [[ "$current" == "$SERENA_VERSION" && "$owned" -eq 1 ]]; then
	printf 'OK Serena already at canonical version %s\n' "$SERENA_VERSION"
	exit 0
fi

if ! command -v uv >/dev/null 2>&1; then
	printf 'FAIL uv is required; install it with make install-uv\n' >&2
	exit 1
fi

if [[ -z "$current" ]]; then
	printf 'INFO Serena is missing; canonical version is %s\n' "$SERENA_VERSION"
else
	printf 'INFO Serena version drift: %s -> %s\n' "$current" "$SERENA_VERSION"
fi

if [[ "$dry_run" -eq 1 ]]; then
	printf '[DRY_RUN] Would run: uv tool install %s\n' "$SERENA_PACKAGE"
	exit 0
fi

uv tool install "$SERENA_PACKAGE"
after="$(serena_version || true)"
if [[ "$after" != "$SERENA_VERSION" ]]; then
	printf 'FAIL Serena convergence produced %s, expected %s\n' "${after:-unavailable}" "$SERENA_VERSION" >&2
	exit 1
fi
printf 'OK Serena %s installed via uv tool\n' "$after"
