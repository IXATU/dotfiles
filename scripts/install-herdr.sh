#!/usr/bin/env bash
# Install or converge a direct Herdr installation and its initial agent integrations.
#
# Contract:
#   - DRY_RUN=1 or --dry-run prints mutating commands and writes nothing.
#   - Uses Herdr's checksum-verifying direct installer under ~/.local/bin.
#   - Keeps the direct install on the stable channel and verifies its version.
#   - Installs only integrations for agent CLIs already present on PATH.
#   - Uses Herdr's supported integration CLI so unrelated agent settings survive.
#   - Never installs mise, agent CLIs, or Pi, and never edits shell rc files.
set -euo pipefail

SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
# shellcheck source=scripts/lib/install_common.sh
source "${SCRIPT_DIR}/lib/install_common.sh"

HERDR_INSTALLER_URL="https://herdr.dev/install.sh"
HERDR_INSTALL_DIR="${HERDR_INSTALL_DIR:-${HOME}/.local/bin}"
HERDR_TARGET="${HERDR_INSTALL_DIR}/herdr"
dry_run=0

usage() {
	printf 'Usage: %s [--dry-run]\n' "$0"
}

case "${1:-}" in
--dry-run)
	dry_run=1
	;;
-h | --help)
	usage
	exit 0
	;;
"") ;;
*)
	usage >&2
	exit 2
	;;
esac

dry() {
	[[ "$dry_run" -eq 1 ]] || install_is_truthy "${DRY_RUN:-}"
}

herdr_binary() {
	if [[ -x "$HERDR_TARGET" ]]; then
		printf '%s\n' "$HERDR_TARGET"
		return 0
	fi
	command -v herdr 2>/dev/null
}

run_or_plan() {
	if dry; then
		printf '[DRY_RUN] Would run:'
		printf ' %q' "$@"
		printf '\n'
		return 0
	fi
	"$@"
}

install_direct() {
	if dry; then
		printf 'INFO Herdr is missing; direct stable bootstrap is required.\n'
		printf '[DRY_RUN] Would download %s to a temporary file.\n' "$HERDR_INSTALLER_URL"
		printf '[DRY_RUN] Would run: HERDR_INSTALL_DIR=%q sh /tmp/install-herdr.<rand>.sh\n' "$HERDR_INSTALL_DIR"
		return 0
	fi

	if ! command -v curl >/dev/null 2>&1; then
		install_label FAIL "curl is required to download ${HERDR_INSTALLER_URL}"
		return 1
	fi

	local tmp_file
	tmp_file="$(mktemp -t install-herdr.XXXXXX.sh)"
	# shellcheck disable=SC2064
	trap "rm -f '${tmp_file}'" EXIT INT TERM

	printf 'INFO Downloading official Herdr installer from %s\n' "$HERDR_INSTALLER_URL"
	curl -fsSL "$HERDR_INSTALLER_URL" -o "$tmp_file"
	[[ -s "$tmp_file" ]] || {
		install_label FAIL "Downloaded Herdr installer is empty"
		return 1
	}
	HERDR_INSTALL_DIR="$HERDR_INSTALL_DIR" sh "$tmp_file"

	rm -f "$tmp_file"
	trap - EXIT INT TERM
	[[ -x "$HERDR_TARGET" ]] || {
		install_label FAIL "Herdr installer did not create ${HERDR_TARGET}"
		return 1
	}
}

converge_runtime() {
	local herdr_bin="$1" installed_now="$2"
	local before channel after

	before="$($herdr_bin --version 2>/dev/null | head -n 1)"
	[[ -n "$before" ]] || {
		install_label FAIL "Could not read Herdr version from ${herdr_bin}"
		return 1
	}
	channel="$($herdr_bin channel show 2>/dev/null)"

	case "$channel" in
	stable)
		if [[ "$installed_now" -eq 1 ]]; then
			install_label OK "Herdr bootstrap selected stable channel"
		else
			run_or_plan "$herdr_bin" update
		fi
		;;
	preview)
		# Setting the direct-install channel also installs its latest release.
		run_or_plan "$herdr_bin" channel set stable
		;;
	*)
		install_label FAIL "Unexpected Herdr update channel: ${channel:-unavailable}"
		return 1
		;;
	esac

	if dry; then
		install_label INFO "Herdr version before convergence: ${before}"
		return 0
	fi

	after="$($herdr_bin --version 2>/dev/null | head -n 1)"
	[[ -n "$after" ]] || {
		install_label FAIL "Herdr version check failed after convergence"
		return 1
	}
	[[ "$($herdr_bin channel show 2>/dev/null)" == "stable" ]] || {
		install_label FAIL "Herdr channel is not stable after convergence"
		return 1
	}
	install_label OK "Herdr converged: ${before} -> ${after} (stable)"
}

integration_is_current() {
	local integration="$1" status="$2"
	grep -qE "^${integration}: current([[:space:]]|$)" <<<"$status"
}

converge_integration() {
	local herdr_bin="$1" status="$2" integration="$3" agent_command="$4"

	if ! command -v "$agent_command" >/dev/null 2>&1; then
		install_label SKIP "Herdr ${integration} integration: ${agent_command} is not installed"
		return 0
	fi
	if integration_is_current "$integration" "$status"; then
		install_label OK "Herdr ${integration} integration is current"
		return 0
	fi

	run_or_plan "$herdr_bin" integration install "$integration"
	if ! dry; then
		install_label OK "Herdr ${integration} integration installed/refreshed"
	fi
}

converge_integrations() {
	local herdr_bin="$1" status
	status="$($herdr_bin integration status)"

	converge_integration "$herdr_bin" "$status" claude claude
	converge_integration "$herdr_bin" "$status" codex codex
	converge_integration "$herdr_bin" "$status" opencode opencode
	converge_integration "$herdr_bin" "$status" cursor cursor-agent
}

main() {
	local herdr_bin="" installed_now=0

	printf '==> install-herdr (direct stable channel; opt-in)\n'
	printf '    Target: %s\n' "$HERDR_TARGET"
	printf '    Upstream: %s\n' "$HERDR_INSTALLER_URL"

	herdr_bin="$(herdr_binary || true)"
	if [[ -z "$herdr_bin" ]]; then
		install_direct
		if dry; then
			printf '[DRY_RUN] After bootstrap, would verify version/channel and install integrations only for detected agents.\n'
			return 0
		fi
		herdr_bin="$HERDR_TARGET"
		installed_now=1
	elif [[ "$herdr_bin" != "$HERDR_TARGET" ]]; then
		install_label FAIL "Herdr at ${herdr_bin} is not the dotfiles-managed direct install ${HERDR_TARGET}"
		printf 'Use its package manager to update it, or remove it before running make install-herdr.\n' >&2
		return 1
	fi

	converge_runtime "$herdr_bin" "$installed_now"
	converge_integrations "$herdr_bin"
}

main
