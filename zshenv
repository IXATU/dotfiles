# Minimal environment for every zsh process, including agents without a TTY.
# Keep this file silent: no prompt, plugins, runtime managers or secrets.
# Preserve inherited entries after the canonical user and system commands.
typeset -U path PATH
path=("$HOME/.local/bin" "$HOME/.npm-global/bin" /usr/local/bin /usr/bin /bin "${path[@]}")
export PATH
