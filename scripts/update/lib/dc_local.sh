#!/usr/bin/env bash
# Local IXATU MCP versions; never replace a live service runtime.
dc_local_version() {
	local file="$HOME/.local/share/ixatu-mcp/node_modules/@wonderwhy-er/desktop-commander/package.json"
	[[ -f "$file" ]] || return 0
	node -p "require(process.argv[1]).version" "$file" 2>/dev/null || true
}

dc_tunnel_version() {
	local binary="$HOME/.local/bin/tunnel-client"
	[[ -x "$binary" ]] || return 0
	"$binary" --version 2>/dev/null | head -n 1 | sed -E 's/^v?([0-9]+\.[0-9]+\.[0-9]+).*/\1/' || true
}

dc_is_stable_version() {
	[[ "$1" =~ ^[0-9]+\.[0-9]+\.[0-9]+$ ]]
}

dc_newer_version() {
	[[ "$1" != "$2" ]] && [[ "$(printf '%s\n%s\n' "$1" "$2" | sort -V | tail -n 1)" == "$1" ]]
}

dc_snapshot() {
	local dc tunnel
	dc="$(dc_local_version)"
	tunnel="$(dc_tunnel_version)"
	tool_snapshot_has "Desktop Commander" || tool_snapshot_add "Desktop Commander" "$dc" "$dc"
	tool_snapshot_has "Tunnel Client" || tool_snapshot_add "Tunnel Client" "$tunnel" "$tunnel"
}

update_dc_local() {
	local installed latest tunnel_installed tunnel_latest stage tmp candidate
	installed="$(dc_local_version)"
	tunnel_installed="$(dc_tunnel_version)"
	dc_snapshot

	if [[ -z "$installed" ]]; then
		result_warn "WSL" "Desktop Commander" "Local managed installation not found; no changes made"
	elif ! command -v npm >/dev/null 2>&1; then
		result_warn "WSL" "Desktop Commander" "npm unavailable; cannot check latest release"
	else
		latest="$(npm view @wonderwhy-er/desktop-commander version --fetch-timeout=10000 --fetch-retries=0 2>/dev/null || true)"
		if ! dc_is_stable_version "$latest"; then
			result_warn "WSL" "Desktop Commander" "Stable upstream version unavailable; installed $installed retained"
		elif dc_newer_version "$latest" "$installed"; then
			stage="$HOME/.local/share/ixatu-mcp-staged/$latest"
			candidate="$stage/node_modules/@wonderwhy-er/desktop-commander/package.json"
			if [[ ! -f "$candidate" ]]; then
				mkdir -p "$(dirname "$stage")"
				tmp="$(mktemp -d "$(dirname "$stage")/.dc-stage.XXXXXXXX")"
				if npm install --prefix "$tmp" --save-exact --package-lock --ignore-scripts --no-audit --no-fund "@wonderwhy-er/desktop-commander@$latest" >"$LOG_DIR/wsl-desktop-commander.log" 2>&1 &&
					[[ "$(node -p "require(process.argv[1]).version" "$tmp/node_modules/@wonderwhy-er/desktop-commander/package.json" 2>/dev/null)" == "$latest" ]]; then
					mv "$tmp" "$stage"
				else
					result_warn "WSL" "Desktop Commander" "Staging failed; installed $installed retained; see log"
				fi
				[[ -d "$tmp" ]] && rm -rf "$tmp"
			fi
			if [[ -f "$candidate" ]] && [[ "$(node -p "require(process.argv[1]).version" "$candidate" 2>/dev/null)" == "$latest" ]]; then
				result_warn "WSL" "Desktop Commander" "STAGED $latest; ACTIVE $installed; ACTIVATION_PENDING (restart is manual, not performed)"
			fi
		else
			result_info "WSL" "Desktop Commander" "Installed $installed; latest stable $latest; unchanged"
		fi
	fi

	if [[ -z "$tunnel_installed" ]]; then
		result_warn "WSL" "Tunnel Client" "Binary unavailable; no changes made"
	elif ! command -v gh >/dev/null 2>&1; then
		result_warn "WSL" "Tunnel Client" "gh unavailable; installed $tunnel_installed retained"
	else
		tunnel_latest="$(GH_PROMPT_DISABLED=1 gh api repos/openai/tunnel-client/releases/latest --jq '.tag_name' 2>/dev/null || true)"
		tunnel_latest="${tunnel_latest#v}"
		if ! dc_is_stable_version "$tunnel_latest"; then
			result_warn "WSL" "Tunnel Client" "Stable upstream release unavailable; installed $tunnel_installed retained"
		elif dc_newer_version "$tunnel_latest" "$tunnel_installed"; then
			result_warn "WSL" "Tunnel Client" "Available $tunnel_latest; ACTIVE $tunnel_installed; manual checksum-verified activation required"
		else
			result_info "WSL" "Tunnel Client" "Installed $tunnel_installed; latest stable $tunnel_latest; unchanged"
		fi
	fi
}
