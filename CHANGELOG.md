# Changelog

Este archivo contiene las últimas 5 releases. Para el historial completo, consulta los archivos en el directorio `releases/`.

## [v0.5.0] - 2026-10-23

## Changes
### Added
- 2026-10-23 14:23 [6cc75ec](https://github.com/IXATU/dotfiles/commit/6cc75ec) feat(herdr): add declarative IXATU workday launcher (#25) (Jesús)
  Add six declarative Herdr workspaces, idempotent ixatu-day startup and safe per-day Dotfiles/DevX tasks. Validate live WSL Herdr 0.9.5 protocol and provide short readable commands, tests and Chezmoi launcher. Acceptance PASS on PC-IXATU-09.

### Documentation
- 2026-10-23 14:28 [3e5019c](https://github.com/IXATU/dotfiles/commit/3e5019c) docs(release): prepare v0.5.0 Herdr Workday (#26) (Jesús)
  Record Herdr Workday v0.5.0 highlights, live Acceptance and replication procedure.


## [v0.3.0] - 2026-10-23

## Changes
### Added
- 2026-10-15 14:17 [69919f1](https://github.com/IXATU/dotfiles/commit/69919f1) feat(tooling): manage Cursor Agent CLI via dotfiles update (#20) (Jesús)
- 2026-10-01 14:03 [331c244](https://github.com/IXATU/dotfiles/commit/331c244) feat: manage Herdr runtime reproducibly (#18) (Jesús)

### Fixed
- 2026-10-23 10:44 [4527c90](https://github.com/IXATU/dotfiles/commit/4527c90) fix(zsh): Classic Lightest P10k and lazy Docker aliases (#21) (Jesús)
  * fix(zsh): classic lightest prompt and safe lazy Docker aliases
  * test(zsh): include Classic prompt regression checks in standard gate
- 2026-09-25 11:49 [b66d2e0](https://github.com/IXATU/dotfiles/commit/b66d2e0) fix(azure-mcp): restore ICU runtime dependency (#16) (Jesús)
- 2026-09-25 10:39 [7c8a9fa](https://github.com/IXATU/dotfiles/commit/7c8a9fa) fix(serena): converge Cursor runtime configuration (#14) (Jesús)
- 2026-09-22 10:16 [a512e40](https://github.com/IXATU/dotfiles/commit/a512e40) fix(zsh): keep prompt paths and branches unambiguous (Jesús)

### Documentation
- 2026-10-23 10:47 [cf9a30a](https://github.com/IXATU/dotfiles/commit/cf9a30a) docs(release): prepare v0.3.0 workstation baseline (#22) (Jesús)


## [v0.2.0] - 2026-09-22

## Changes
### Added
- 2026-09-22 08:44 [1dbe61d](https://github.com/IXATU/dotfiles/commit/1dbe61d) feat(tooling): manage Gitleaks and converge Node 24 baseline (#9) (Jesús)
  Manage Gitleaks via checksum-verified official releases, reuse the canonical installer in validation, and converge the workstation Node installer to the declared Node 24 baseline while preserving Node >=22 compatibility.

### Documentation
- 2026-09-22 09:14 [5256393](https://github.com/IXATU/dotfiles/commit/5256393) docs(release): prepare v0.2.0 (#11) (Jesús)
  Add v0.2.0 release notes and changelog entry so the release tag includes its own documentation.

### Refactored
- 2026-09-22 09:01 [eb558ab](https://github.com/IXATU/dotfiles/commit/eb558ab) refactor(agent): retire treegen and static STRUCTURE workflow (#10) (Jesús)
  Retire treegen, generated STRUCTURE.md and the pre-commit snapshot workflow. Keep only the GitNexus post-commit hook and use dynamic repository discovery via Serena, GitNexus and normal file search.


## [v0.1.0] - 2026-09-21

## Changes
### Added
- 2026-09-21 10:50 [c03bfed](https://github.com/IXATU/dotfiles/commit/c03bfed) feat(ai): add Serena and development tooling (Jesús)
  Integrate Serena 1.7.0, global Pyright/ty/Ruff/Taplo tooling, Claude Serena/GitNexus adapters, workstation snapshot coverage, and project-owned Serena configuration.
- 2026-06-14 13:56 [1224988](https://github.com/IXATU/dotfiles/commit/1224988) feat(makefile): add secrets readiness check and update help documentation (Cursor Agent)
  - Introduced a new `secrets-check` target in `install.mk` to verify SOPS/Age/Chezmoi secrets readiness without mutating values.
  - Updated the help section in `tests/Makefile.tests` to include the new `secrets-check` command for better user guidance.
  - Integrated the `secrets-check` into the system tests to ensure its functionality is validated during testing.
- 2026-06-14 13:20 [0836368](https://github.com/IXATU/dotfiles/commit/0836368) feat(docker): improve Docker command resolution and error handling in update scripts (Cursor Agent)
  - Introduced a new function `resolve_responsive_docker_bin` to streamline Docker command resolution, allowing for fallback to `docker.exe` when the primary Docker command is unresponsive.
  - Enhanced error messages to provide clearer guidance when Docker is unavailable, improving user experience during Excalidraw image operations.
  - Updated `update-check.sh` to utilize the new resolution function, ensuring accurate status reporting for Docker commands.
- 2026-06-14 13:05 [4846959](https://github.com/IXATU/dotfiles/commit/4846959) feat(docker): enhance Docker command resolution and error handling in scripts (Cursor Agent)
  - Added support for resolving Docker commands in `ai-cursor-check.sh` and `update-excalidraw.sh`, allowing for fallback to `docker.exe` when the primary Docker command is unresponsive.
  - Improved error messages to provide clearer guidance when Docker is not available, enhancing user experience during Excalidraw image operations.
  - Updated test cases to validate the new Docker command resolution logic and ensure proper handling of various scenarios, including unresponsive Docker commands.
- 2026-06-13 11:48 [be65f52](https://github.com/IXATU/dotfiles/commit/be65f52) feat(ci): add gitleaks secret scanning to CI workflow and update documentation (Cursor Agent)
  - Integrated gitleaks into the CI workflow for secret scanning by adding a new step in `.github/workflows/test.yml`.
  - Updated `docs/TESTING.md` to reflect the inclusion of the gitleaks step in the CI process, clarifying its purpose and usage.
  - Enhanced test coverage by adding a new test case in `tests/bats/git-hooks/hooks.bats` to validate behavior when tree generation produces empty output.
- 2026-06-13 11:17 [eb235b9](https://github.com/IXATU/dotfiles/commit/eb235b9) feat(update): refine color-coding logic for WinGet summary results (Cursor Agent)
  - Enhanced the `Get-WinGetSummaryResultColor` function to improve color determination for various result statuses, including handling of additional cases like "unchanged" and "error".
  - Introduced a new `Test-WinGetSummaryResultColorContract` function to validate the color output against expected results, ensuring consistency in the summary display.
  - Updated tests to verify the presence of the new function and the refined logic in the PowerShell script.
- 2026-06-13 11:06 [9549927](https://github.com/IXATU/dotfiles/commit/9549927) feat(update): add color-coded output for WinGet summary results (Cursor Agent)
  - Introduced a new function `Get-WinGetSummaryResultColor` to determine the color for displaying WinGet results based on their status.
  - Updated the `Write-WindowsSemanticSummary` function to utilize the new color-coding feature, enhancing the visibility of package update statuses in the console output.
  - Enhanced tests to verify the presence of the new function and the color output in the PowerShell script.
- 2026-06-13 10:57 [e5aae71](https://github.com/IXATU/dotfiles/commit/e5aae71) feat(update): enhance WinGet inventory display and add ShowInventory option (Cursor Agent)
  - Updated the inventory classification in `UPDATE.md` to include a summary of managed apps with their statuses.
  - Introduced a new `-ShowInventory` switch in the PowerShell script to display detailed inventory results for managed apps.
  - Modified shell scripts to support the new `ShowInventory` option, allowing users to toggle this feature via environment variables.
- 2026-06-13 10:21 [eadc3d6](https://github.com/IXATU/dotfiles/commit/eadc3d6) feat(update): improve WinGet inventory tracking with UTF-8 encoding and duplicate handling (Cursor Agent)
  - Enhanced the `windows-winget-inventory.tsv` to include a `duplicate_count` field, allowing for better tracking of packages with multiple installed entries.
  - Updated the PowerShell script to write TSV files without BOM, ensuring compatibility and proper encoding.
  - Modified inventory classification logic to reflect duplicate counts in the output messages.
- 2026-06-13 10:09 [932f861](https://github.com/IXATU/dotfiles/commit/932f861) feat(update): enhance Windows update workflow with inventory tracking and detailed logging (Cursor Agent)
  - Added new inventory tracking features to the PowerShell script, generating `windows-winget-inventory.tsv` and `windows-winget-snapshot.tsv` for comprehensive package coverage analysis.
  - Introduced a new `SelfTestWinGetInventory` switch to facilitate testing of inventory functionality.
  - Updated the logging mechanism to include detailed package statuses and coverage classifications.
- 2026-06-13 09:54 [01484be](https://github.com/IXATU/dotfiles/commit/01484be) feat(powershell_update); enhance Windows update workflow with detailed logging and retry options (Cursor Agent)
  - Updated PowerShell script to log detailed WinGet upgrade results in a new TSV format, including package status and execution duration.
  - Introduced options for including unknown packages and retrying failed updates from a TSV file.
  - Modified shell scripts to pass new parameters for unknown package inclusion and retry functionality.
- 2026-06-09 18:19 [4eecc41](https://github.com/IXATU/dotfiles/commit/4eecc41) feat(dotfiles-apply): add chezmoi status preview functionality (Cursor Agent)
  - Introduced `run_chezmoi_status_preview` to summarize the status of chezmoi-managed files, filtering benign script entries while preserving real changes.
  - Updated `run_preview` to call the new status preview function instead of the previous status command.
  - Enhanced test coverage to validate the new status preview behavior, ensuring expected entries are reported correctly and non-script changes are visible.
- 2026-06-09 08:45 [b9cd1cc](https://github.com/IXATU/dotfiles/commit/b9cd1cc) feat(gitnexus): enhance post-install script handling and npm ignore-scripts validation (jesus)
  - Introduced a function to check if npm ignore-scripts is enabled, preventing installation if true.
  - Updated `run_gitnexus_postinstall_scripts` to dynamically retrieve postinstall scripts from package.json.
  - Enhanced error messaging for missing postinstall scripts and ignore-scripts scenarios.
- 2026-06-07 13:02 [efe386a](https://github.com/IXATU/dotfiles/commit/efe386a) feat(runtime): add clean-runtime-skills and github-identity-check scripts (Cursor Agent)
  - Introduced `clean-runtime-skills.sh` for dry-run inspection and cleanup of runtime skills symlinks in user directories.
  - Added `github-identity-check.sh` for offline diagnostics of GitHub identity, ensuring proper token management and remote verification.
  - Updated `update.mk` to include new targets for both scripts, enhancing the Makefile with additional functionality.
- 2026-06-07 12:06 [42514c4](https://github.com/IXATU/dotfiles/commit/42514c4) feat(secrets): introduce diagnose-secret-surfaces script and enhance documentation (Cursor Agent)
  - Added `diagnose-secret-surfaces.sh` for read-only scanning of plaintext secrets in local cache files, ensuring sensitive information is not exposed.
  - Updated `TOKEN_GITHUB_GH.md` and `AGENT_WORKFLOW.md` to include guidance on managing Codex shell snapshots and using the new diagnostic script.
  - Enhanced `OPERATIONS_CHEATSHEET.md` to reflect the new cleaning procedures for local snapshots containing potential secrets.
- 2026-06-07 11:13 [abb531e](https://github.com/IXATU/dotfiles/commit/abb531e) feat(security): add OSV scanning capabilities and enhance validation scripts (Cursor Agent)
  - Introduced `osv_scan.sh` and `security-osv-scan.sh` scripts for improved vulnerability scanning.
  - Updated `agent-validate-changed.sh` to integrate OSV scanning with strict mode handling.
  - Enhanced documentation in `AGENT_WORKFLOW.md`, `OPERATIONS_CHEATSHEET.md`, and `TESTING.md` to clarify OSV scanning behavior and configurations.
- 2026-06-07 10:27 [4349db9](https://github.com/IXATU/dotfiles/commit/4349db9) feat(git-flow): update dotfiles policy and documentation for manual PR integration (Cursor Agent)
  - Changed `.git-flow-policy.env` to set manual PR modes for development and main branches, enabling validation commands for feature and release flows.
  - Updated `GIT_FLOW_POLICY.md` to reflect the new operational policy and checklist for integrating changes.
  - Revised `GIT_WORKFLOW.md` to emphasize the recommended use of `git feat` and `git rel` for manual PR creation.
- 2026-06-07 10:23 [839d9ae](https://github.com/IXATU/dotfiles/commit/839d9ae) feat(git-flow): implement PR modes and merge strategies for feature and release flows (Cursor Agent)
  - Added support for `pr_auto` and `pr_immediate` modes in `git feat` and `git rel`, allowing automatic and immediate merging of pull requests.
  - Updated `GIT_FLOW_POLICY.md` to reflect the new PR modes and their semantics, including detailed descriptions of merge strategies.
  - Enhanced `git_feat.sh` and `git_rel.sh` scripts to handle the new PR modes and integrate merge strategy options.
- 2026-06-07 10:19 [9bdfc3f](https://github.com/IXATU/dotfiles/commit/9bdfc3f) feat(git-flow): enhance PR policy documentation and implement dry-run functionality (Cursor Agent)
  - Updated GIT_FLOW_POLICY.md to clarify the implementation status of manual PR creation for both feature and release flows.
  - Added details on the new `--dry-run` option for `git feat` and `git rel`, allowing users to preview actions without executing them.
  - Revised GIT_WORKFLOW.md to reflect the availability of manual PR creation and dry-run capabilities.
- 2026-06-07 09:57 [873613c](https://github.com/IXATU/dotfiles/commit/873613c) feat(validation): enhance agent validation and documentation for .claude directory (Cursor Agent)
  - Updated agent validation scripts to include a guard against the presence of the `.claude/` directory, ensuring compliance with ADR 0004.
  - Enhanced AGENT_WORKFLOW.md, TESTING.md, and VALIDATION_MATRIX.md to reflect the new validation checks and remediation steps for `.claude/`.
  - Added tests to verify the functionality of the new guard and ensure that the validation process correctly identifies and handles the `.claude/` directory.
- 2026-06-07 09:50 [3d21e79](https://github.com/IXATU/dotfiles/commit/3d21e79) feat(script-conventions): enhance documentation and introduce check mode for tree generation (Cursor Agent)
  - Updated AGENT_WORKFLOW.md to include references to the new `--check` flag for safe validation of STRUCTURE.md without modifications.
  - Revised AI_REPO_MAP.md to document the implications of the `--check` flag in the context of script usage.
  - Enhanced OPERATIONS_CHEATSHEET.md and TESTING.md to reflect the new conventions for dry-run and check modes, ensuring clarity in command usage.
- 2026-06-07 09:47 [6ee35f0](https://github.com/IXATU/dotfiles/commit/6ee35f0) feat(dotfiles-apply): update documentation and enhance agent workflow (Cursor Agent)
  - Revised AGENT_WORKFLOW.md to clarify the usage of `dotfiles-apply` and its related commands, emphasizing safe application practices.
  - Updated AI_REPO_MAP.md to include `dotfiles-apply` in the context of repo wrappers and their functions.
  - Enhanced CHEZMOI.md with detailed descriptions of the `dotfiles-apply` command and its safe usage guidelines.
- 2026-06-07 09:41 [c38f4f2](https://github.com/IXATU/dotfiles/commit/c38f4f2) feat(validation): add agent validation report command and update documentation (Cursor Agent)
  - Introduced `make agent-validate-report` to generate a persistent Markdown report at `build/agent-validation/latest.md`, capturing validation results even on failure.
  - Updated AGENT_WORKFLOW.md, OPERATIONS_CHEATSHEET.md, TESTING.md, and VALIDATION_MATRIX.md to include references and details about the new report command.
  - Enhanced the .gitignore file to exclude the new agent validation report directory.
- 2026-06-07 09:38 [7c586ad](https://github.com/IXATU/dotfiles/commit/7c586ad) feat(validation): update agent validation commands and enhance documentation (Cursor Agent)
  - Revised AGENT_WORKFLOW.md to clarify the usage of `make agent-validate`, `make agent-validate-changed`, `make agent-validate-audit`, and `make agent-validate-full`.
  - Improved OPERATIONS_CHEATSHEET.md with detailed descriptions of validation commands and their contexts.
  - Updated SYSTEM_DEPENDENCIES.md to reflect changes in validation command semantics.
- 2026-06-07 09:23 [6d11236](https://github.com/IXATU/dotfiles/commit/6d11236) feat(update): update maintenance commands and improve documentation clarity (Cursor Agent)
  - Replaced instances of `make update` with `dotfiles-update` in various documentation files to standardize the command usage for daily updates.
  - Enhanced descriptions in README.md, SKILL.md, and UPDATE.md to clarify the purpose and usage of `dotfiles-update`.
  - Updated aliases conventions in aliases-conventions.mdc to reflect new guidelines and removed outdated sections.
- 2026-06-07 09:01 [1bc41ae](https://github.com/IXATU/dotfiles/commit/1bc41ae) feat(git_feat): enhance command behavior to utilize current feature branch without argument (Cursor Agent)
  - Updated `git feat` to allow usage without a branch argument, defaulting to the current feature branch if it matches the configured prefix.
  - Enhanced documentation in GIT_FLOW_POLICY.md and GIT_WORKFLOW.md to clarify this new behavior and provide usage examples.
  - Added tests to verify the correct functionality of the command in various scenarios, including validation checks for branch naming and prefix adherence.
- 2026-06-07 08:47 [f6aee9c](https://github.com/IXATU/dotfiles/commit/f6aee9c) feat(git_feat): implement feature PR mode for streamlined branch integration (Cursor Agent)
  - Introduced `FLOW_MODE_TO_DEV=pr` for `git feat`, enabling automatic creation of Pull Requests using GitHub CLI.
  - Updated documentation in GIT_FLOW_POLICY.md and GIT_WORKFLOW.md to reflect new PR capabilities and usage examples.
  - Enhanced validation checks to ensure proper branch naming and validation commands before creating PRs.
- 2026-06-07 08:01 [9c25ba1](https://github.com/IXATU/dotfiles/commit/9c25ba1) feat(gitflow): enhance git feat and git rel with policy loading and validation (Cursor Agent)
  - Implemented phase 2 features in git feat and git rel, including policy loading from `.git-flow-policy.env` and validation commands before merging.
  - Added `--print-policy` option to both commands for effective policy inspection without executing merges or pushes.
  - Updated scripts to utilize custom remote names and branch prefixes, improving flexibility in repository management.
- 2026-06-07 07:47 [5a79cc6](https://github.com/IXATU/dotfiles/commit/5a79cc6) feat(gitflow policies): add GIT_FLOW_POLICY.md to README and update test targets for git-flow (Cursor Agent)
  - Included a new document, GIT_FLOW_POLICY.md, outlining the opt-in policy for evolving the git feat / git rel workflow.
  - Updated the test targets in Makefile.tests to include bats-git-flow for comprehensive testing of the new git flow policy.
- 2026-06-06 22:28 [f7a5ddf](https://github.com/IXATU/dotfiles/commit/f7a5ddf) feat(visualization): add VisiData support and update documentation for optional tools (Cursor Agent)
  - Included VisiData (`vd`) as an optional tool for exploring CSV, TSV, JSON, and tabular files in SKILL.md and SYSTEM_DEPENDENCIES.md.
  - Updated INSTALL.md to reflect the installation instructions for VisiData.
  - Enhanced tests to verify the inclusion of VisiData in the system dependencies check, ensuring proper documentation alignment.
- 2026-06-06 22:17 [f5e6952](https://github.com/IXATU/dotfiles/commit/f5e6952) feat(zsh): add fzf integration and update documentation for optional tools (Cursor Agent)
  - Included the fzf script in the zsh configuration for enhanced fuzzy finding capabilities.
  - Updated SKILL.md to mention the use of fzf for interactive file and history searches.
  - Enhanced INSTALL.md and SYSTEM_DEPENDENCIES.md to include installation instructions for fzf and lnav as optional tools.
- 2026-06-06 21:58 [10de2c4](https://github.com/IXATU/dotfiles/commit/10de2c4) feat(store_etl_ops): implement configurable workdir resolution and update documentation (Cursor Agent)
  - Introduced a new function to resolve the Store ETL workspace using the `STORE_ETL_WORKDIR` environment variable, with a fallback to `/home/jesus/proyectos/store-etl`.
  - Updated the `server.py` to handle workdir validation, ensuring it exists and contains necessary repository markers.
  - Enhanced documentation in `MCP_QUICKREF.md`, `MCP_TAXONOMY.md`, and `VERIFICAR_MCP_STORE_ETL.md` to clarify workdir configuration and error handling.
- 2026-06-06 21:26 [5dc427b](https://github.com/IXATU/dotfiles/commit/5dc427b) feat(ai-assets): implement validation to prevent materializing AI assets in dotfiles checkout (Cursor Agent)
  - Added a new function to refuse the creation of agent skill surfaces within the dotfiles repository, enhancing the governance of AI asset locations.
  - Updated the script to use absolute paths for better clarity and reliability.
  - Enhanced tests to verify that the script correctly refuses to create symlinks for agent skills in the source directory, ensuring robust error handling and messaging.
- 2026-06-06 21:05 [9b94d4b](https://github.com/IXATU/dotfiles/commit/9b94d4b) feat(powershell): enhance WinGet package parser with self-test functionality (Cursor Agent)
  - Added a new self-test feature for the WinGet package parser in the PowerShell script, allowing validation against predefined fixtures without requiring WinGet execution.
  - Introduced helper functions for line comparison and non-empty line retrieval to facilitate the self-test process.
  - Updated the `parse-winget-log.py` script documentation to clarify its role as an auxiliary parser for WSL diagnostics.
- 2026-06-06 20:57 [92b3c9f](https://github.com/IXATU/dotfiles/commit/92b3c9f) feat(playwright): update CHEZMOI and OPERATIONS documentation to include Playwright Docker (Cursor Agent)
  - Enhanced the CHEZMOI documentation to clarify the management of dotfiles and the addition of Playwright Docker as a launcher in the local bin.
  - Added a new section in OPERATIONS.md detailing the usage and configuration of Playwright Docker for browser automation without local installations.
  - Updated references to include the new launcher in relevant commands and examples, ensuring comprehensive guidance for users.
- 2026-06-06 20:20 [dd58993](https://github.com/IXATU/dotfiles/commit/dd58993) feat(powershell): enhance WinGet upgrade process with live output filtering (Cursor Agent)
  - Introduced new functions `Get-WinGetConsoleLine` and `Invoke-WinGetLiveFiltered` to improve console output handling during WinGet upgrades.
  - Updated `Run-NativeLiveLogged` to support live filtered output, enhancing user experience by providing real-time feedback.
  - Revised tests to validate the new functionality and ensure accurate logging and output during the upgrade process.

### Fixed
- 2026-06-13 11:59 [14566f0](https://github.com/IXATU/dotfiles/commit/14566f0) fix(tests): wire `github-identity-check.bats` into the `bats-system` target (Cursor Agent)
  - Added `github-identity-check.bats` to the `bats-system` target in `Makefile.tests` to ensure it runs during system tests.
  - Updated documentation in `TESTING.md` to clarify that some Bats files remain unwired for automated testing, specifically noting the omission of `github-identity-check.bats` from the previous mention.
- 2026-06-13 11:51 [0ac4a50](https://github.com/IXATU/dotfiles/commit/0ac4a50) fix(tests): wire `clean-runtime-skills.bats` into the `bats-system` target (Cursor Agent)
  - Added `clean-runtime-skills.bats` to the `bats-system` target in `Makefile.tests` to ensure it runs during system tests.
  - Updated documentation in `TESTING.md` to clarify the status of Bats files in the `tests/bats/` directory, emphasizing that some files remain unwired for automated testing.
- 2026-06-09 17:47 [837da4e](https://github.com/IXATU/dotfiles/commit/837da4e) fix(github-identity-check): enhance remote classification for IXATU organization (Cursor Agent)
  - Updated the `infer_profile` function to classify remotes from the IXATU organization as 'oficina/fork'.
  - Modified warning message to include IXATU organization in the expected remote profiles.
  - Added a test to verify that IXATU organization remotes are correctly classified, ensuring accurate profile inference.
- 2026-06-09 08:39 [a4ed305](https://github.com/IXATU/dotfiles/commit/a4ed305) fix(gitnexus): streamline installation and enhance post-install scripts (jesus)
  - Updated installation instructions for GitNexus CLI to use `scripts/install-gitnexus.sh` instead of npm commands.
  - Enhanced `install-gitnexus.sh` to include post-install scripts for setting up GitNexus grammar.
  - Modified documentation in `SYSTEM_DEPENDENCIES.md` and `0002-gitnexus-mcp.md` to reflect the new installation process.
- 2026-06-07 11:53 [940ffcf](https://github.com/IXATU/dotfiles/commit/940ffcf) fix(secrets): enhance GitHub token management and documentation (Cursor Agent)
  - Added `github-token-policy.bats` to enforce isolation of GitHub tokens in MCP and `gh` CLI contexts.
  - Updated `run_after_00_gen_secrets.sh.tmpl` to prevent global export of `GH_TOKEN` and `GITHUB_TOKEN`, ensuring they are only available in the appropriate contexts.
  - Revised documentation in `TOKEN_GITHUB_GH.md`, `CAMBIAR_TOKEN_GITHUB.md`, and `SECRETS_EXAMPLES.md` to clarify token usage and sourcing practices.
- 2026-06-07 11:28 [63679bc](https://github.com/IXATU/dotfiles/commit/63679bc) fix(git-flow): enhance auto-merge behavior for PR modes (Cursor Agent)
  - Updated `GIT_FLOW_POLICY.md`, `GIT_WORKFLOW.md`, and ADR 0008 to clarify the behavior of `pr_auto` mode, allowing immediate merging if the PR is already in clean status.
  - Modified `git_flow_policy.sh` to implement fallback logic for immediate merging when auto-merge is unavailable due to clean status.
  - Added tests to verify the new fallback behavior for both feature and release flows, ensuring correct handling of clean status scenarios.
- 2026-06-07 10:43 [785479d](https://github.com/IXATU/dotfiles/commit/785479d) fix(git-flow): update documentation for local feature integration and auto-merge PRs (Cursor Agent)
  - Revised `.git-flow-policy.env` to reflect the new integration strategy using local merges for features and automatic pull requests for releases.
  - Updated `GIT_FLOW_POLICY.md` and `GIT_WORKFLOW.md` to clarify the changes in the integration flow and the use of validation commands.
  - Enhanced tests to ensure consistency with the updated policy and verify the correct implementation of local and auto-merge behaviors.
- 2026-06-07 10:38 [12c740a](https://github.com/IXATU/dotfiles/commit/12c740a) fix(git-flow): update flow modes in .git-flow-policy.env (Cursor Agent)
  - Changed FLOW_MODE_TO_DEV from 'pr' to 'local' to facilitate local development.
  - Updated FLOW_MODE_TO_MAIN to 'pr_auto' for automatic pull request handling.
  - Removed unnecessary lines for improved clarity and conciseness in the configuration file.
- 2026-06-07 08:49 [f993840](https://github.com/IXATU/dotfiles/commit/f993840) fix(git_feat): resolve issues with PR mode validation and documentation updates (Cursor Agent)
  - Fixed validation checks in the `git feat` PR mode to ensure proper branch naming and command execution.
  - Updated GIT_FLOW_POLICY.md and GIT_WORKFLOW.md to clarify usage and examples related to the PR mode.
  - Enhanced test coverage to verify the correctness of validation processes and error handling in PR creation.
- 2026-06-07 08:08 [8771028](https://github.com/IXATU/dotfiles/commit/8771028) fix(GITNEXUS): update operational policy and enhance test coverage (Cursor Agent)
  - Added recommendations for immediate recovery using `--force --skip-agents-md` in GITNEXUS_OPERATIONAL_POLICY.md.
  - Updated test cases to verify the presence of new documentation and ensure no typos in hook scripts.
  - Enhanced output messages in Makefile.tests for better clarity during test dependency installation and validation processes.
- 2026-06-06 22:52 [e07e531](https://github.com/IXATU/dotfiles/commit/e07e531) fix(hooks): update pre-commit hook to auto-stage STRUCTURE.md changes (Cursor Agent)
  - Modified the pre-commit hook to automatically stage STRUCTURE.md if it is regenerated by treegen, allowing the commit to proceed without manual intervention.
  - Updated documentation in INSTALL.md and OPERATIONS_CHEATSHEET.md to reflect the new behavior of the pre-commit hook.
  - Enhanced tests to verify that STRUCTURE.md is staged automatically and that unrelated unstaged files remain unaffected.
- 2026-06-06 20:37 [1737eb0](https://github.com/IXATU/dotfiles/commit/1737eb0) fix(validation): add check for non-canonical agent skill directories (Cursor Agent)
  - Introduced a new validation function to ensure that agent skills are located only under `ai/assets/skills`, preventing the use of non-canonical directories like `.claude/skills`.
  - Updated the validation script to include this new check, enhancing the governance of skill structure.
  - Added a corresponding test to verify that the validation fails when a non-canonical directory is present, ensuring robust error messaging and validation feedback.

### Documentation
- 2026-06-14 14:08 [142dd65](https://github.com/IXATU/dotfiles/commit/142dd65) docs(cheatsheets): clarify human decision points in OFFICE_SETUP_CHEATSHEET (Cursor Agent)
  - Updated the OFFICE_SETUP_CHEATSHEET to specify that updates to the local `dev` branch and decisions regarding push, merge conflict resolution, commits, and rebases are human decisions, enhancing clarity for users.
- 2026-06-14 14:05 [9d01d8d](https://github.com/IXATU/dotfiles/commit/9d01d8d) docs(cheatsheets): add OFFICE_SETUP_CHEATSHEET and update references (Cursor Agent)
  - Introduced a new `OFFICE_SETUP_CHEATSHEET.md` to provide a comprehensive guide for setting up office laptops with WSL2, Chezmoi, SOPS/Age, and Docker Desktop.
  - Updated `README.md` and `OPERATIONS_CHEATSHEET.md` to include links to the new cheatsheet, enhancing documentation for office setup processes.
- 2026-06-14 13:28 [a87c73e](https://github.com/IXATU/dotfiles/commit/a87c73e) docs(excalidraw): update Excalidraw workspace path resolution in documentation (Cursor Agent)
  - Clarified the path resolution for the Excalidraw workspace in the MCP documentation, specifying the use of Chezmoi variables for mounting.
  - Adjusted the description of file access restrictions to reflect the updated binding process, ensuring better understanding of path traversal protection.
- 2026-06-13 11:20 [fa8cddc](https://github.com/IXATU/dotfiles/commit/fa8cddc) docs(releases): added changelog for feature/updating-updates-on-powershell (Cursor Agent)
  - Added a new changelog file summarizing the integration of six commits related to enhancing the Windows update workflow and WinGet inventory features.
  - Included details on improvements such as color-coding for summary results, inventory tracking, and detailed logging enhancements.
  - Documented the integration date and status for better tracking of feature development.
- 2026-06-09 20:23 [a721d21](https://github.com/IXATU/dotfiles/commit/a721d21) docs(gitnexus): update GitNexus MCP documentation with agent-first policy details (Cursor Agent)
  - Added a status update to clarify the agent-first GitNexus runtime policy and the use of the MCP launcher.
  - Revised the execution pattern section to reflect the current method of invoking GitNexus without `npx`.
  - Updated installation details to emphasize the creation of a canonical symlink for agent access.
- 2026-06-09 19:13 [0eab757](https://github.com/IXATU/dotfiles/commit/0eab757) docs(operations): add shell-audit-check command and update validation matrix (Cursor Agent)
  - Introduced `make shell-audit-check` to the operations cheatsheet, providing a focused shell audit for agents.
  - Updated `TESTING.md` to reflect the inclusion of `zsh -n` in the `make test-lint` command for enhanced linting.
  - Revised the validation matrix to incorporate `shell-audit-check` in the extended validation for `scripts/*` and `bin/*`, clarifying its role as a focused audit tool rather than a substitute for `test-lint`.
- 2026-06-09 18:50 [3bad2cd](https://github.com/IXATU/dotfiles/commit/3bad2cd) docs(gitnexus): update fallback procedures and agent workflow for GitNexus availability (Cursor Agent)
  - Added fallback guidelines in SKILL.md for scenarios where GitNexus is unavailable or returns errors, emphasizing manual review and testing.
  - Updated AGENT_WORKFLOW.md to clarify the use of GitNexus and fallback procedures for micro-BUILDs, ensuring agents follow the new protocols.
  - Enhanced GITNEXUS_OPERATIONAL_POLICY.md with detailed fallback steps and reporting templates for better operational clarity.
- 2026-06-09 08:58 [eb76c1b](https://github.com/IXATU/dotfiles/commit/eb76c1b) docs(releases): added changelog (jesus)
  - Enhanced error handling in `run_gitnexus_postinstall_scripts` to provide clearer feedback when post-install scripts are missing or when npm ignore-scripts is enabled.
  - Updated validation logic to ensure that installation proceeds only when appropriate conditions are met.
  - Added additional tests to cover new error scenarios and ensure robust handling of post-install script execution.
- 2026-06-07 10:46 [35f8017](https://github.com/IXATU/dotfiles/commit/35f8017) docs(releases): added changelog (Cursor Agent)
- 2026-06-07 10:14 [d9cce0b](https://github.com/IXATU/dotfiles/commit/d9cce0b) docs(adrs): finalize dotfiles-update and ups removal decisions (Cursor Agent)
  - Updated AGENT_FIRST_SUMMARY.md to reflect the closure of the `dotfiles-update` and `ups` removal decisions, marking them as implemented and closed respectively.
  - Revised ADR 0009 to indicate the implementation status of the `dotfiles-update` global wrapper, including details on its functionality and usage.
  - Updated ADR 0010 to confirm the complete removal of the `ups` command, clarifying that no legacy alias will be provided.
- 2026-06-07 10:01 [945886e](https://github.com/IXATU/dotfiles/commit/945886e) docs(summary): update references to AGENT_FIRST_SUMMARY.md across documentation (Cursor Agent)
  - Replaced instances of AGENT_WORKFLOW.md with AGENT_FIRST_SUMMARY.md in multiple files to streamline operational guidance.
  - Enhanced documentation consistency by ensuring all relevant files reference the new summary and checklist for agent workflows.
  - Updated README.md, AI_REPO_MAP.md, VALIDATION_MATRIX.md, and SCRIPT_CONVENTIONS.md to include the AGENT_FIRST_SUMMARY.md link for improved clarity.
- 2026-06-07 09:35 [bd810e2](https://github.com/IXATU/dotfiles/commit/bd810e2) docs(adrs): enhance documentation and tests for Architecture Decision Records (Cursor Agent)
  - Updated AGENT_WORKFLOW.md and AI_REPO_MAP.md to include references to the ADRs directory and its README.
  - Added a section in README.md to highlight the purpose of ADRs in documenting architectural decisions.
  - Introduced tests to verify the existence and structure of ADR files, ensuring consistency and completeness in documentation.
- 2026-06-07 09:33 [d0d308f](https://github.com/IXATU/dotfiles/commit/d0d308f) docs(handoffs): enhance agent workflow documentation and add handoff templates (Cursor Agent)
  - Updated ai/README.md to include links to handoff templates for better guidance on agent workflows.
  - Expanded docs/AGENT_WORKFLOW.md with detailed descriptions of handoff templates and their required sections.
  - Added a new skill entry for 'Dotfiles Agent Review' in ai/assets/skills/README.md to clarify its purpose in post-change reviews.
- 2026-06-07 09:31 [179437f](https://github.com/IXATU/dotfiles/commit/179437f) docs(agent): add operational contract and references for agent workflows (Cursor Agent)
  - Introduced a new section in AGENTS.md detailing the operational contract for working with dotfiles, including links to relevant documentation.
  - Updated ai/README.md to reference the agent workflow and repo map for better clarity on operational procedures.
  - Enhanced docs/README.md with links to agent-related documents, improving accessibility to important resources.
- 2026-06-07 08:15 [fd0d00e](https://github.com/IXATU/dotfiles/commit/fd0d00e) docs(GIT_FLOW_POLICY): enhance documentation for future policy features and validation processes (Cursor Agent)
  - Added details on `DELETE_FEATURE_BRANCH` and `OPEN_BROWSER` parsing for future policy use.
  - Included a manual validation fixture for testing scripts in a disposable repository.
  - Documented validation success and failure paths for `git feat` and `git rel`, emphasizing the importance of policy checks before executing critical operations.
- 2026-06-06 23:16 [e0848e5](https://github.com/IXATU/dotfiles/commit/e0848e5) docs(releases): added changelog for branch #23 (Cursor Agent)
  - Hooks Git más robustos: pre-commit regenera y auto-stagea STRUCTURE.md; post-commit actualiza GitNexus con comportamiento más claro.
  - Mejor integración de fzf en Zsh.
  - Añadido soporte/documentación para VisiData como herramienta opcional de inspección tabular.
- 2026-06-06 22:37 [40c7485](https://github.com/IXATU/dotfiles/commit/40c7485) docs(ops): add wsl2-raw-data-inspection skill and update documentation (Cursor Agent)
  - Introduced the `wsl2-raw-data-inspection` skill for secure inspection of CSV/JSON/raw ETL data.
  - Updated `SKILL.md` for `wsl2-local-tools` to reference the new skill for raw data handling.
  - Enhanced `README.md` to include the new skill in the list of available operations, ensuring comprehensive documentation.

### Refactored
- 2026-06-14 12:50 [f21d6ab](https://github.com/IXATU/dotfiles/commit/f21d6ab) refactor(excalidraw): update workspace host resolution and improve script handling (Cursor Agent)
  - Modified the SKILL.md documentation to clarify the host bind mount resolution process for the Excalidraw workspace.
  - Updated `ai-cursor-check.sh` and `update-excalidraw.sh` scripts to utilize a new function for resolving the Excalidraw workspace host, enhancing flexibility with paths containing spaces.
  - Enhanced test cases to validate the new workspace resolution logic, ensuring proper handling of Chezmoi configurations and legacy paths.
- 2026-06-13 11:46 [1d8117c](https://github.com/IXATU/dotfiles/commit/1d8117c) refactor(codex): remove legacy config and update documentation (Cursor Agent)
  - Deleted the outdated `codex/config.toml` file to streamline configuration management.
  - Updated `README-mcp.md` and `README.md` to reflect the new configuration source in `dot_codex/private_config.toml.tmpl`.
  - Adjusted references in documentation to ensure clarity on the configuration process and usage.
- 2026-06-10 08:50 [6daa999](https://github.com/IXATU/dotfiles/commit/6daa999) refactor(gitnexus): align GitNexus post-commit hook with canonical refresh policy (jesus)
- 2026-06-09 20:16 [763fa95](https://github.com/IXATU/dotfiles/commit/763fa95) refactor(gitnexus): improve installation and path alignment procedures (Cursor Agent)
  - Enhanced SKILL.md and GITNEXUS_OPERATIONAL_POLICY.md to clarify the installation process and the importance of symlink creation for agent-first path alignment.
  - Updated MCP_QUICKREF.md and OPERATIONS_CHEATSHEET.md to reflect changes in GitNexus installation paths and symlink management.
  - Improved install-gitnexus.sh to ensure the creation of a canonical symlink from ~/.local/bin/gitnexus to the npm installation.
- 2026-06-09 19:47 [056eda0](https://github.com/IXATU/dotfiles/commit/056eda0) refactor(gitnexus): enhance path alignment diagnostics and update operational policies (Cursor Agent)
  - Expanded SKILL.md to include details on GitNexus path alignment, emphasizing its importance for agent safety and operational integrity.
  - Updated GITNEXUS_OPERATIONAL_POLICY.md to reflect the new path alignment checks and their implications for read-only operations.
  - Revised MCP_QUICKREF.md and OPERATIONS_CHEATSHEET.md to incorporate path alignment considerations for agents.
- 2026-06-09 19:07 [1e01692](https://github.com/IXATU/dotfiles/commit/1e01692) refactor(canonical-target): update SCRIPT_CONVENTIONS and TESTING documentation for shell-audit-check (Cursor Agent)
  - Revised SCRIPT_CONVENTIONS.md to include `make shell-audit-check` in the list of read-only validators, clarifying its usage.
  - Enhanced TESTING.md with details about the `make shell-audit-check` command, outlining its focused shell audit capabilities and exclusions.
  - Updated Makefile.tests to add `shell-audit-check` as a phony target and included it in the help section for better visibility.
- 2026-06-09 18:43 [3e75593](https://github.com/IXATU/dotfiles/commit/3e75593) refactor(agent-validation): enhance agent-validate-report functionality and deprecate AGENT_VALIDATE_CMD (Cursor Agent)
  - Updated `agent-validate-report` to use an allowlisted validation target via `AGENT_VALIDATE_TARGET`, replacing the deprecated `AGENT_VALIDATE_CMD`.
  - Improved error handling for unsupported validation selectors, ensuring safer execution and clearer feedback.
  - Enhanced the report generation process to include detailed command execution logs and warnings for deprecated usage.
- 2026-06-09 18:32 [e75767b](https://github.com/IXATU/dotfiles/commit/e75767b) refactor(excalidraw): update README and SKILL documentation for canonical source paths (Cursor Agent)
  - Revised README.md to clarify the canonical source path for the Excalidraw skill and emphasized the avoidance of checkout-local agent skill surfaces.
  - Updated SKILL.md to reflect the new paths for rendering and setup instructions, ensuring consistency across documentation.
  - Adjusted references in render_excalidraw.py to point to the correct directory structure, enhancing usability for users.
- 2026-06-07 10:58 [fd92527](https://github.com/IXATU/dotfiles/commit/fd92527) refactor(gitnexus): implement dotfiles analyze policy and enhance post-commit behavior (Cursor Agent)
  - Added `diagnose-checkout-ai-surface.sh` script for diagnosing AI surface issues in dotfiles.
  - Updated `GITNEXUS_OPERATIONAL_POLICY.md` to clarify the use of `--skip-skills` during `gitnexus analyze` in dotfiles checkouts.
  - Enhanced `post-commit-gitnexus.sh` to include `--skip-skills` in warnings and commands.
- 2026-06-07 09:14 [f43ec03](https://github.com/IXATU/dotfiles/commit/f43ec03) refactor(git_flow_policy): adjust flow modes and validation settings for improved branch management (Cursor Agent)
  - Changed `FLOW_MODE_TO_DEV` to `local` and `FLOW_MODE_TO_MAIN` to `pr` for better alignment with branch workflows.
  - Updated validation settings by disabling `VALIDATE_TO_DEV` and enabling `VALIDATE_TO_MAIN`, along with defining a new validation command for the main branch.
  - Added merge strategy configurations for both development and main branches to enhance clarity in merging processes.
- 2026-06-07 09:04 [e09fa12](https://github.com/IXATU/dotfiles/commit/e09fa12) refactor(git_flow_policy): update validation commands and add main branch configuration (Cursor Agent)
  - Introduced `FLOW_MODE_TO_MAIN=local` and updated validation commands for both development and main branches in `.git-flow-policy.env`.
  - Enhanced `VALIDATE_CMD_TO_DEV` to include additional checks for better validation coverage.
  - Set `VALIDATE_TO_MAIN` to false and defined a new command for full validation on the main branch.
- 2026-06-07 08:28 [4ffbd03](https://github.com/IXATU/dotfiles/commit/4ffbd03) refactor(GIT_FLOW_POLICY): update documentation and examples for feature branch preservation (Cursor Agent)
  - Clarified the behavior of `DELETE_FEATURE_BRANCH` in the context of feature branch integration.
  - Added a canonical example of `.git-flow-policy.env` for better user guidance.
  - Updated `GIT_WORKFLOW.md` to reflect the new default behavior of archiving feature branches.
- 2026-06-06 23:01 [e4ee3e4](https://github.com/IXATU/dotfiles/commit/e4ee3e4) refactor(hooks): enhance post-commit behavior and documentation (Cursor Agent)
  - Updated the post-commit hook to skip refresh when GitNexus MCP or index lock is active, ensuring commits remain valid and the index does not become stale.
  - Improved error handling for non-writable GitNexus home and registry files, providing actionable warnings to users.
  - Revised documentation in GITNEXUS_OPERATIONAL_POLICY.md, INSTALL.md, and OPERATIONS_CHEATSHEET.md to reflect the new post-commit behavior and clarify manual refresh procedures.
- 2026-06-06 22:02 [9624630](https://github.com/IXATU/dotfiles/commit/9624630) refactor(update): clarify mcp-server-fetch installation in WSL update process (Cursor Agent)
  - Updated documentation to specify that `make update-wsl` does not install `mcp-server-fetch` as a persistent tool, instead managing it at runtime via `uvx`.
  - Modified the `update-wsl.sh` script to reflect this change, ensuring clarity in the installation process.
  - Added tests to verify that the `mcp-server-fetch` installation behavior aligns with the updated documentation, confirming it is not installed persistently.
- 2026-06-06 22:00 [11c1e14](https://github.com/IXATU/dotfiles/commit/11c1e14) refactor(manifest): update MCP profiles in MANIFEST.yaml and documentation for clarity (Cursor Agent)
  - Enhanced the `MANIFEST.yaml` to include status and descriptions for reserved profiles: `store-etl`, `ixatu`, and `project-local`, clarifying their inactive status.
  - Updated `MCP_QUICKREF.md` and `MCP_TAXONOMY.md` to reflect the changes in profile management and emphasize that reserved profiles are not operational.
  - Added a new test for consistency between MCP taxonomy and manifest profiles to ensure documentation accuracy.
- 2026-06-06 21:56 [82cdc86](https://github.com/IXATU/dotfiles/commit/82cdc86) refactor(operations): update agent validation commands and clarify OSV scanning options (Cursor Agent)
  - Enhanced the documentation for `make agent-validate-changed` to specify that it performs local checks by default and requires `SECURITY_ONLINE=1` for strict OSV scanning.
  - Updated the `TESTING.md` file to reflect the new behavior of the agent validation command, emphasizing the distinction between local and online security checks.
  - Modified the `agent-validate-changed.sh` script to include a conditional for running the OSV online scan based on the `SECURITY_ONLINE` environment variable, improving flexibility in validation processes.
- 2026-06-06 21:16 [b3ea38e](https://github.com/IXATU/dotfiles/commit/b3ea38e) refactor(playwright): remove run_after_16_link_playwright_docker script and update documentation (Cursor Agent)
  - Deleted the `run_after_16_link_playwright_docker.sh.tmpl` script as it is no longer needed.
  - Updated CHEZMOI and OPERATIONS documentation to reflect the change, clarifying the management of `playwright-docker` as a direct symlink in the local bin.
  - Enhanced tests to verify the new symlink management for `playwright-docker`, ensuring proper functionality and documentation alignment.

### Tests
- 2026-06-07 09:53 [7d67c48](https://github.com/IXATU/dotfiles/commit/7d67c48) test(regression): introduce regression index and enhance documentation (Cursor Agent)
  - Added `make bats-agent` command to run the agent regression index, facilitating dedicated testing for historical risks.
  - Updated AGENT_WORKFLOW.md, AI_REPO_MAP.md, and VALIDATION_MATRIX.md to include references to the new regression index and its usage.
  - Enhanced SCRIPT_CONVENTIONS.md to document the purpose of the regression index tests.

### Chores
- 2026-06-14 14:10 [ee17ac9](https://github.com/IXATU/dotfiles/commit/ee17ac9) chore(release): add changelog for feature/fixing-laptop-ixatu-issues (Cursor Agent)
  - Created a new changelog file summarizing the integration of seven commits related to enhancements and documentation updates in the Cursor Agent.
  - Documented integration date, base branch, and status for better tracking of feature development.
- 2026-06-13 12:05 [e0fb49a](https://github.com/IXATU/dotfiles/commit/e0fb49a) chore(release): add changelog for feature/refactors-by-composer (Cursor Agent)
  - Created a new changelog file summarizing the integration of four commits related to testing and CI improvements in the Cursor Agent.
  - Documented the integration date, base branch, and status for better tracking of feature development.
- 2026-06-07 09:43 [bf9716a](https://github.com/IXATU/dotfiles/commit/bf9716a) chore(gitignore): update .gitignore to exclude .claude runtime surface (Cursor Agent)
  - Modified .gitignore to prevent the checkout of the .claude directory, aligning with the agent runtime surface requirements.
  - Added tests to ensure the .claude directory is not present in the dotfiles repository and that it is correctly ignored during checkout.
