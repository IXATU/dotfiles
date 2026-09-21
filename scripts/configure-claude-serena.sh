#!/usr/bin/env bash
# Register Serena in Claude Code without replacing any mutable Claude config.
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

if [[ "$dry_run" -eq 1 ]]; then
	printf '[DRY_RUN] Would run: claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd\n'
	exit 0
fi

command -v claude >/dev/null 2>&1 || {
	printf 'FAIL Claude CLI is not available\n' >&2
	exit 1
}
if claude mcp get serena >/dev/null 2>&1; then
	printf 'OK Claude MCP serena is already registered; existing configuration preserved\n'
	exit 0
fi
claude mcp add --scope user serena -- serena start-mcp-server --context claude-code --project-from-cwd
printf 'OK Claude MCP serena registered at user scope\n'
