#!/usr/bin/env bash
# Register GitNexus in Claude Code without replacing any mutable Claude config.
# The MCP server is launched through the canonical Chezmoi-managed launcher, so
# registration never depends on npx or a direct `gitnexus mcp` invocation.
set -euo pipefail

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

launcher="${HOME}/.local/share/chezmoi/bin/mcp-gitnexus-launcher"

if [[ "$dry_run" -eq 1 ]]; then
	printf '[DRY_RUN] Would run: claude mcp add --scope user gitnexus -- %s\n' "$launcher"
	exit 0
fi

command -v claude >/dev/null 2>&1 || {
	printf 'FAIL Claude CLI is not available\n' >&2
	exit 1
}
[[ -x "$launcher" ]] || {
	printf 'FAIL GitNexus MCP launcher is missing: %s\n' "$launcher" >&2
	printf '      Reinstall it with: make install-dotfiles\n' >&2
	exit 1
}
if claude mcp get gitnexus >/dev/null 2>&1; then
	printf 'OK Claude MCP gitnexus is already registered; existing configuration preserved\n'
	exit 0
fi
claude mcp add --scope user gitnexus -- "$launcher"
printf 'OK Claude MCP gitnexus registered at user scope\n'
