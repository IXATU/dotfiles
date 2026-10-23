#!/usr/bin/env bash
# Bootstrap the official native stable CLI in HOME; preserve working installs.
# No shell rc/config edits, authentication, sudo, or npm fallback.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/install_common.sh
source "${SCRIPT_DIR}/lib/install_common.sh"

CLAUDE_INSTALLER_URL="https://claude.ai/install.sh"
CLAUDE_TARGET="${HOME}/.local/bin/claude"
dry_run=0
for arg in "$@"; do
	case "$arg" in
	--dry-run) dry_run=1 ;;
	-h | --help)
		printf 'Usage: %s [--dry-run]\n' "$0"
		exit 0
		;;
	*)
		install_label FAIL "Unknown argument: ${arg} (use --dry-run)" >&2
		exit 2
		;;
	esac
done

# A settings directory alone is not an installation. Also recognize the native
# binary when ~/.local/bin has not yet reached the caller's PATH.
claude_bin="$(command -v claude 2>/dev/null || true)"
if [[ -z "$claude_bin" && -x "$CLAUDE_TARGET" ]]; then
	claude_bin="$CLAUDE_TARGET"
fi
if [[ -n "$claude_bin" ]]; then
	if ! version="$("$claude_bin" --version 2>/dev/null)" || [[ -z "$version" ]]; then
		install_label FAIL "Claude at ${claude_bin} failed --version; repair the existing installation manually." >&2
		exit 1
	fi
	install_label OK "Claude Code already installed: ${version}; preserving ${claude_bin}"
	exit 0
fi

if [[ "$dry_run" -eq 1 ]] || install_is_truthy "${DRY_RUN:-}"; then
	printf '[DRY_RUN] Would download %s to a temporary file, validate with bash -n, and run bash <installer> stable.\n' "$CLAUDE_INSTALLER_URL"
	printf '[DRY_RUN] Would verify %s --version.\n' "$CLAUDE_TARGET"
	exit 0
fi

if ! command -v curl >/dev/null 2>&1; then
	install_label FAIL "curl is required to download ${CLAUDE_INSTALLER_URL}" >&2
	exit 1
fi
tmp_file="$(mktemp -t install-claude-code.XXXXXX.sh)"
trap 'rm -f -- "$tmp_file"' EXIT
trap 'exit 130' INT
trap 'exit 143' TERM
if ! curl -fsSL "$CLAUDE_INSTALLER_URL" -o "$tmp_file"; then
	install_label FAIL "Could not download the official Claude Code installer" >&2
	exit 1
fi
if [[ ! -s "$tmp_file" ]] || ! bash -n "$tmp_file" 2>/dev/null; then
	install_label FAIL "Downloaded Claude Code installer is empty or invalid Bash" >&2
	exit 1
fi
# Anthropic's installer verifies the downloaded native binary's checksum.
if ! bash "$tmp_file" stable; then
	install_label FAIL "Claude Code native stable installer failed" >&2
	exit 1
fi
if [[ ! -x "$CLAUDE_TARGET" ]] || ! version="$("$CLAUDE_TARGET" --version 2>/dev/null)" || [[ -z "$version" ]]; then
	install_label FAIL "Claude Code installer did not produce a working ${CLAUDE_TARGET}" >&2
	exit 1
fi
install_label OK "Claude Code installed: ${version} (${CLAUDE_TARGET})"
