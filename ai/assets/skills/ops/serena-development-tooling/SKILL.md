---
name: serena-development-tooling
description: Use when choosing among workstation code-search, semantic-navigation, Python quality, typing, and TOML tools.
---

# Dotfiles Serena Development Tooling

## Guidelines: Choose the Narrowest Tool

- For text/regex search, use `rg`.
- For syntax or AST patterns, use `ast-grep`.
- For architecture, impact, and execution flows, use GitNexus.
- For symbols, references, and semantic refactors, use Serena.
- For Python lint and formatting, use Ruff.
- For primary Python typing, use Pyright.
- For a second typing opinion, use ty.
- For TOML formatting, linting, and validation, use Taplo.

Serena complements GitNexus; it does not replace the architecture and impact graph. Combine them when a change needs both blast-radius analysis and symbol-aware editing.

## Start a Serena Task

1. Confirm `serena --version` works and the Serena MCP is connected.
2. Confirm or activate the current project in Serena.
3. Respect an existing `.serena/project.yml`.
4. Agents do not modify `language_servers` during a normal handoff unless explicitly authorized.

Serena supports multiple language servers simultaneously. Do not switch engines or restart Serena merely because work moves between Python, TypeScript, YAML, or TOML.

Cursor may start with a GUI cwd unrelated to the workspace, so activate the project explicitly when needed. Codex, OpenCode, and Claude use `--project-from-cwd` because their CLI sessions normally inherit the repository cwd.

## Project Commands Win

The global tools provide workstation capability and discovery. Inside a repository, prefer its pinned commands such as `uv run ruff`, `uv run ty`, or `npm run ...` when declared by that project. Never make project CI depend on the workstation-global version.
