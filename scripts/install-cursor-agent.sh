#!/usr/bin/env bash
# Cursor Agent CLI: install and update through the official Cursor distribution.
# Invoked by dotfiles-update, never by Chezmoi. No sudo, credentials or shell edits.
set -euo pipefail

MANAGED_AGENT="$HOME/.local/bin/agent"
if [[ -x "$MANAGED_AGENT" ]]; then
	"$MANAGED_AGENT" update
else
	installer="$(mktemp)"
	trap 'rm -f "$installer"' EXIT
	# Fetch to a temporary file so failures cannot execute a partial script.
	curl --proto '=https' --tlsv1.2 -fsSL -o "$installer" https://cursor.com/install
	bash "$installer"
fi

if [[ ! -x "$MANAGED_AGENT" ]]; then
	printf 'Cursor Agent installer did not create %s\n' "$MANAGED_AGENT" >&2
	exit 1
fi
"$MANAGED_AGENT" --version
