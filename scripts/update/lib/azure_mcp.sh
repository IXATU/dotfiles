#!/usr/bin/env bash
# Opt-in Azure MCP pin, stable release discovery and verified activation.
azure_mcp_version() {
	local launcher="$HOME/.local/share/ixatu-azure-mcp-pilot/start.sh" ancestor
	# Version snapshots must not follow a launcher symlink into unrelated Home files.
	ancestor="$launcher"
	while [[ "$ancestor" != / ]]; do
		[[ ! -L "$ancestor" ]] || return 0
		ancestor="${ancestor%/*}"
		[[ -n "$ancestor" ]] || break
	done
	[[ -r "$launcher" ]] || return 0
	sed -nE 's@^exec ([^[:space:]]*/)?uvx[[:space:]]+--from[[:space:]]+msmcp-azure==([0-9]+\.[0-9]+\.[0-9]+)([[:space:]].*)?$@\2@p' "$launcher" 2>/dev/null || true
}

azure_mcp_snapshot() {
	[[ -f "$HOME/.local/share/ixatu-azure-mcp-pilot/start.sh" ]] || return 0
	local current
	current="$(azure_mcp_version)"
	tool_snapshot_has "Azure MCP" || tool_snapshot_add "Azure MCP" "$current" "$current"
}

azure_mcp_latest() {
	# Only non-yanked, final x.y.z releases with distribution files qualify.
	curl --fail --silent --show-error --connect-timeout 5 --max-time 15 --retry 0 \
		https://pypi.org/pypi/msmcp-azure/json 2>/dev/null |
		python3 -c '
import json, re, sys
try:
    releases = json.load(sys.stdin)["releases"]
    stable = [v for v, files in releases.items()
              if re.fullmatch(r"[0-9]+\.[0-9]+\.[0-9]+", v)
              and files and all(not f.get("yanked", False) for f in files)]
    print(max(stable, key=lambda v: tuple(map(int, v.split(".")))))
except (ValueError, KeyError, TypeError, AttributeError):
    sys.exit(1)
' 2>/dev/null
}

update_azure_mcp() {
	local current latest helper activation_log activation_status
	azure_mcp_snapshot
	if [[ ! -f "$HOME/.local/share/ixatu-azure-mcp-pilot/start.sh" ]]; then
		result_skip "WSL" "Azure MCP" "Optional managed pilot absent; no changes made"
		return 0
	fi
	current="$(azure_mcp_version)"
	if is_truthy "${DOTFILES_UPDATE_MOCK:-}"; then
		result_skip "WSL" "Azure MCP" "PINNED ${current:-unknown}; latest stable not checked (mock)"
	elif [[ ! "$current" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		result_warn "WSL" "Azure MCP" "Launcher pin unavailable; latest stable unknown; no changes made"
	elif ! latest="$(azure_mcp_latest)" || [[ ! "$latest" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]; then
		result_warn "WSL" "Azure MCP" "PINNED $current; latest stable unknown (PyPI unavailable); unchanged"
	elif [[ "$latest" != "$current" && "$(printf '%s\n%s\n' "$latest" "$current" | sort -V | tail -n 1)" == "$latest" ]]; then
		if [[ "${DOTFILES_MCP_AUTO_ACTIVATE:-1}" == 0 || "${current%%.*}" != "${latest%%.*}" ]]; then
			result_warn "WSL" "Azure MCP" "PINNED $current; latest stable $latest; ACTIVATION_PENDING (disabled or incompatible)"
		else
			helper="${DOTFILES_ROOT:-$(cd "$(dirname "${BASH_SOURCE[0]}")/../../.." && pwd)}/scripts/update/azure-mcp-activate.py"
			activation_log="${LOG_DIR:-$DOTFILES_UPDATE_RUN_DIR}/wsl-azure-mcp-activate.log"
			if python3 "$helper" "$latest" >"$activation_log" 2>&1; then
				tool_snapshot_add "Azure MCP" "$current" "$(azure_mcp_version)"
				result_info "WSL" "Azure MCP" "INSTALLED/ACTIVATED $latest; verified; see activation log"
			else
				activation_status=ACTIVATION_PENDING
				if grep -q 'ROLLBACK FAILED' "$activation_log"; then
					activation_status='ROLLBACK FAILED: manual recovery required'
				elif grep -q ROLLBACK "$activation_log"; then activation_status=ROLLBACK; fi
				result_warn "WSL" "Azure MCP" "PINNED $(azure_mcp_version); $activation_status; see activation log"
			fi
		fi
	else
		result_info "WSL" "Azure MCP" "PINNED $current; latest stable $latest; unchanged"
	fi
}
