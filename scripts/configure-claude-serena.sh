#!/usr/bin/env bash
# Register Serena in Claude Code without replacing any mutable Claude config.
set -euo pipefail

serena_args=(
	start-mcp-server
	--context claude-code
	--project-from-cwd
	--enable-web-dashboard true
	--open-web-dashboard false
)
plugin_id="serena@claude-plugins-official"

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
	printf '[DRY_RUN] Would run: claude mcp add --scope user serena -- serena %s\n' "${serena_args[*]}"
	printf '[DRY_RUN] Would run: claude plugin disable -s user %s\n' "$plugin_id"
	exit 0
fi

command -v claude >/dev/null 2>&1 || {
	printf 'FAIL Claude CLI is not available\n' >&2
	exit 1
}
if claude mcp get serena >/dev/null 2>&1; then
	printf 'OK Claude MCP serena is already registered; existing configuration preserved\n'
else
	claude mcp add --scope user serena -- serena "${serena_args[@]}"
	printf 'OK Claude MCP serena registered at user scope\n'
fi

if claude plugin disable -s user "$plugin_id"; then
	printf 'OK Claude duplicate Serena plugin disabled: %s\n' "$plugin_id"
else
	status=$?
	printf 'FAIL Claude could not disable duplicate Serena plugin: %s\n' "$plugin_id" >&2
	exit "$status"
fi

printf 'OK Claude canonical Serena ready (user MCP; duplicate plugin disabled)\n'
