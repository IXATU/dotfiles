#!/usr/bin/env bats

load '../helpers/common'

bats_require_minimum_version 1.5.0

setup() {
	DOTFILES_DIR="$(get_dotfiles_dir)"
	LAUNCHER="${DOTFILES_DIR}/bin/ixatu-day"
	SCRIPT="${DOTFILES_DIR}/scripts/herdr-workday.py"
	CONFIG="${DOTFILES_DIR}/config/herdr/workday.toml"
	TMPL="${DOTFILES_DIR}/dot_local/bin/symlink_ixatu-day.tmpl"
	setup_temp_dir

	export HOME="${TEST_TEMP_DIR}/home"
	export IXATU_STATE_DIR="${TEST_TEMP_DIR}/ixatu-state"
	export IXATU_DEVICE_ID="test-device"
	export IXATU_DATE="2026-10-23"
	export HERDR_STUB_STATE="${TEST_TEMP_DIR}/herdr-state.json"
	export HERDR_STUB_LOG="${TEST_TEMP_DIR}/herdr.log"
	export IXATU_PROC_ROOT="${TEST_TEMP_DIR}/proc"
	export PATH="${TEST_TEMP_DIR}/bin:/usr/bin:/bin"
	mkdir -p "$HOME" "${TEST_TEMP_DIR}/bin" "$IXATU_PROC_ROOT"
	write_herdr_stub
	printf '{"running": false, "workspaces": []}\n' >"$HERDR_STUB_STATE"
}

teardown() {
	teardown_temp_dir
}

write_herdr_stub() {
	cat >"${TEST_TEMP_DIR}/bin/herdr" <<'PY'
#!/usr/bin/env python3
import json
import os
import sys
from pathlib import Path

state_path = Path(os.environ["HERDR_STUB_STATE"])
log_path = Path(os.environ["HERDR_STUB_LOG"])
args = sys.argv[1:]
with log_path.open("a", encoding="utf-8") as stream:
    stream.write(json.dumps(args) + "\n")

if args[:2] == ["--session", "ixatu"]:
    args = args[2:]

state = json.loads(state_path.read_text(encoding="utf-8"))

def save():
    temp = state_path.with_suffix(".tmp")
    temp.write_text(json.dumps(state), encoding="utf-8")
    temp.replace(state_path)

def option(name, default=None):
    try:
        return args[args.index(name) + 1]
    except ValueError:
        return default

if args[:2] == ["session", "list"]:
    sessions = [
        {"name": "ixatu-lab", "running": True},
        {"name": "ixatu", "running": bool(state["running"])},
    ]
    print(json.dumps({"sessions": sessions}))
elif args == ["server"]:
    state["running"] = True
    save()
elif args[:2] == ["workspace", "list"]:
    records = []
    for workspace in state["workspaces"]:
        records.append({
            "workspace_id": workspace["id"],
            "label": workspace["label"],
            "tab_count": len(workspace["tabs"]),
        })
    print(json.dumps({"result": {"type": "workspace_list", "workspaces": records}}))
elif args[:2] == ["workspace", "create"]:
    number = len(state["workspaces"]) + 1
    workspace_id = f"w{number}"
    tab_id = f"{workspace_id}:t1"
    pane_id = f"{workspace_id}:p1"
    workspace = {
        "id": workspace_id,
        "label": option("--label"),
        "cwd": option("--cwd"),
        "tabs": [{"id": tab_id, "label": "shell", "pane": pane_id}],
    }
    state["workspaces"].append(workspace)
    save()
    print(json.dumps({"result": {
        "workspace": {"workspace_id": workspace_id, "label": workspace["label"]},
        "tab": {"tab_id": tab_id, "label": "shell"},
        "root_pane": {"pane_id": pane_id},
    }}))
elif args[:2] == ["tab", "list"]:
    workspace_id = option("--workspace")
    workspace = next(item for item in state["workspaces"] if item["id"] == workspace_id)
    tabs = [
        {"tab_id": tab["id"], "workspace_id": workspace_id, "label": tab["label"]}
        for tab in workspace["tabs"]
    ]
    print(json.dumps({"result": {"type": "tab_list", "tabs": tabs}}))
elif args[:2] == ["tab", "create"]:
    workspace_id = option("--workspace")
    workspace = next(item for item in state["workspaces"] if item["id"] == workspace_id)
    number = len(workspace["tabs"]) + 1
    tab_id = f"{workspace_id}:t{number}"
    pane_id = f"{workspace_id}:p{number}"
    tab = {"id": tab_id, "label": option("--label"), "pane": pane_id}
    workspace["tabs"].append(tab)
    save()
    print(json.dumps({"result": {"tab": {"tab_id": tab_id}, "root_pane": {"pane_id": pane_id}}}))
elif args[:2] == ["tab", "rename"]:
    tab_id, label = args[2], args[3]
    for workspace in state["workspaces"]:
        for tab in workspace["tabs"]:
            if tab["id"] == tab_id:
                tab["label"] = label
    save()
    print(json.dumps({"result": {"type": "tab_renamed"}}))
elif args[:2] == ["pane", "list"]:
    workspace_id = option("--workspace")
    workspace = next(item for item in state["workspaces"] if item["id"] == workspace_id)
    panes = []
    for tab in workspace["tabs"]:
        pane = {"pane_id": tab["pane"], "tab_id": tab["id"], "workspace_id": workspace_id}
        if os.environ.get("HERDR_STUB_OCCUPIED_TAB") == tab["label"]:
            pane.update({"agent": "codex", "agent_status": "working"})
        panes.append(pane)
    print(json.dumps({"result": {"type": "pane_list", "panes": panes}}))
elif args[:2] == ["pane", "process-info"]:
    # Herdr 0.9.5 requires --pane ID; a positional pane ID is rejected.
    if len(args) != 4 or args[2] != "--pane":
        print("unknown option: " + (args[2] if len(args) > 2 else "<missing>"), file=sys.stderr)
        sys.exit(2)
    pane_id = args[3]
    occupied = False
    for workspace in state["workspaces"]:
        for tab in workspace["tabs"]:
            if tab["pane"] == pane_id and os.environ.get("HERDR_STUB_OCCUPIED_TAB") == tab["label"]:
                occupied = True
    foreground = [{"pid": 9001, "name": "codex"}] if occupied else []
    print(json.dumps({"result": {"process_info": {
        "pane_id": pane_id, "shell_pid": 100, "foreground_processes": foreground,
    }}}))
elif args[:2] == ["pane", "run"]:
    command = " ".join(args[3:])
    failure = os.environ.get("HERDR_STUB_FAIL_RUN", "")
    if failure and failure in command:
        print(json.dumps({"error": {"code": "pane_busy", "message": "simulated failure"}}), file=sys.stderr)
        sys.exit(1)
    # Actual Herdr 0.9.5 pane run: exit 0 with no JSON/stdio output.
    pass
elif not args:
    pass
else:
    print(f"unsupported Herdr stub arguments: {args!r}", file=sys.stderr)
    sys.exit(2)
PY
	chmod +x "${TEST_TEMP_DIR}/bin/herdr"
}

create_all_directories() {
	mkdir -p \
		"$HOME/dotfiles" \
		"$HOME/projects/devx" \
		"$HOME/projects/ixatu-operations" \
		"$HOME/projects/energy-billing-automation" \
		"$HOME/projects/energy-market-data"
}

run_ixatu_day() {
	run env \
		IXATU_DOTFILES_DIR="$DOTFILES_DIR" \
		HERDR_BIN="${TEST_TEMP_DIR}/bin/herdr" \
		bash "$LAUNCHER" "$@"
}

count_log_matching() {
	local pattern="$1"
	python3 - "$HERDR_STUB_LOG" "$pattern" <<'PY'
import json
import sys

count = 0
with open(sys.argv[1], encoding="utf-8") as stream:
    for line in stream:
        if sys.argv[2] in " ".join(json.loads(line)):
            count += 1
print(count)
PY
}

@test "configuration declares the six semantic workday spaces" {
	run python3 - "$CONFIG" <<'PY'
import sys
import tomllib

with open(sys.argv[1], "rb") as stream:
    config = tomllib.load(stream)
spaces = config["spaces"]
assert config["session"] == "ixatu"
assert [space["name"] for space in spaces] == [
    "00 · Tools", "01 · Dotfiles", "02 · DevX", "03 · Operations",
    "04 · Billing", "05 · Market Data",
]
assert [space["tab"] for space in spaces] == [
    "DC Remote", "Updates", "Vault Status", "Shell", "Shell", "Shell",
]
PY
	[[ "$status" -eq 0 ]]
}

@test "first run creates all available spaces and their initial tabs" {
	create_all_directories
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$(count_log_matching 'workspace create')" -eq 6 ]]
	[[ "$(count_log_matching 'tab rename')" -eq 6 ]]
}

@test "missing project directories are warned and not cloned or created" {
	mkdir -p "$HOME/dotfiles" "$HOME/projects/devx" "$HOME/projects/ixatu-operations"
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"04 · Billing"*"missing"* ]]
	[[ "$output" == *"05 · Market Data"*"missing"* ]]
	[[ "$(count_log_matching 'workspace create')" -eq 4 ]]
	[[ ! -e "$HOME/projects/energy-billing-automation" ]]
}

@test "second run reuses workspaces and tabs without duplicates" {
	create_all_directories
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$(count_log_matching 'workspace create')" -eq 6 ]]
	[[ "$(count_log_matching 'tab rename')" -eq 6 ]]
}

@test "workday uses Herdr 0.9.5 pane process-info --pane selector" {
    create_all_directories
    run_ixatu_day
    [[ "$status" -eq 0 ]]
    run python3 - "$HERDR_STUB_LOG" <<'PYCODE'
import json
import sys
from pathlib import Path
calls = [json.loads(line) for line in Path(sys.argv[1]).read_text().splitlines()]
infos = [args for args in calls if "process-info" in args]
assert infos, "expected real pane process checks"
assert all(args[:3] == ["--session", "ixatu", "pane"] for args in infos)
assert all(args[3:5] == ["process-info", "--pane"] and len(args) == 6 for args in infos)
PYCODE
    [[ "$status" -eq 0 ]]
}

@test "daily commands are admitted once per local date and device" {
	create_all_directories
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$(count_log_matching 'dotfiles-update')" -eq 1 ]]
	[[ "$(count_log_matching 'uv run devx vault status')" -eq 1 ]]
	[[ -f "$IXATU_STATE_DIR/test-device/2026-10-23/dotfiles-update.json" ]]
	[[ -f "$IXATU_STATE_DIR/test-device/2026-10-23/devx-vault-status.json" ]]
}

@test "a new local date permits both daily commands again" {
	create_all_directories
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	export IXATU_DATE="2026-10-24"
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$(count_log_matching 'dotfiles-update')" -eq 2 ]]
	[[ "$(count_log_matching 'uv run devx vault status')" -eq 2 ]]
}

@test "pane run accepts real Herdr 0.9.5 empty stdout for DC and daily tasks" {
    create_all_directories
    run_ixatu_day
    [[ "$status" -eq 0 ]]
    [[ "$output" == *"RUN    00 · Tools / DC Remote"* ]]
    [[ "$output" == *"RUN    01 · Dotfiles / Updates"* ]]
    [[ "$output" == *"RUN    02 · DevX / Vault Status"* ]]
    [[ "$(count_log_matching 'pane run')" -eq 3 ]]
}

@test "active Desktop Commander is not duplicated" {
	create_all_directories
	mkdir -p "$IXATU_PROC_ROOT/4242"
	printf 'node\0npx\0@wonderwhy-er/desktop-commander@latest\0remote\0' >"$IXATU_PROC_ROOT/4242/cmdline"
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"Desktop Commander"*"externally"* ]]
	[[ "$(count_log_matching 'npx @wonderwhy-er/desktop-commander@latest remote')" -eq 0 ]]
	[[ "$(count_log_matching 'active externally')" -eq 1 ]]
}

@test "pane admission failure is recorded and not retried indefinitely" {
	create_all_directories
	export HERDR_STUB_FAIL_RUN="uv run devx vault status"
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"failed to schedule"*"Vault Status"* ]]
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$(count_log_matching 'uv run devx vault status')" -eq 1 ]]
	grep -q '"status": "failed"' "$IXATU_STATE_DIR/test-device/2026-10-23/devx-vault-status.json"
}

@test "concurrent invocations do not duplicate daily commands or spaces" {
	create_all_directories
	# Expansion belongs to the child shell used for the concurrency fixture.
	# shellcheck disable=SC2016
	run env IXATU_DOTFILES_DIR="$DOTFILES_DIR" HERDR_BIN="${TEST_TEMP_DIR}/bin/herdr" bash -c '
		bash "$IXATU_DOTFILES_DIR/bin/ixatu-day" >"$TEST_TEMP_DIR/one.out" 2>&1 &
		first=$!
		bash "$IXATU_DOTFILES_DIR/bin/ixatu-day" >"$TEST_TEMP_DIR/two.out" 2>&1 &
		second=$!
		wait "$first"
		wait "$second"
	'
	[[ "$status" -eq 0 ]]
	[[ "$(count_log_matching 'workspace create')" -eq 6 ]]
	[[ "$(count_log_matching 'dotfiles-update')" -eq 1 ]]
	[[ "$(count_log_matching 'uv run devx vault status')" -eq 1 ]]
}

@test "dry-run reports decisions without starting sessions or writing state" {
	create_all_directories
	run_ixatu_day --dry-run
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"DRY-RUN"*"00 · Tools"*"05 · Market Data"* ]]
	[[ "$(count_log_matching 'server')" -eq 0 ]]
	[[ "$(count_log_matching 'workspace create')" -eq 0 ]]
	[[ "$(count_log_matching 'pane run')" -eq 0 ]]
	[[ ! -e "$IXATU_STATE_DIR" ]]
}

@test "existing foreign session and occupied tab remain untouched" {
	create_all_directories
	cat >"$HERDR_STUB_STATE" <<'JSON'
{"running": true, "workspaces": [{"id": "w1", "label": "00 · Tools", "cwd": "/tmp", "tabs": [{"id": "w1:t1", "label": "DC Remote", "pane": "w1:p1"}]}]}
JSON
	export HERDR_STUB_OCCUPIED_TAB="DC Remote"
	mkdir -p "$IXATU_PROC_ROOT/4242"
	printf 'node\0@wonderwhy-er/desktop-commander@latest\0remote\0' >"$IXATU_PROC_ROOT/4242/cmdline"
	run_ixatu_day
	[[ "$status" -eq 0 ]]
	[[ "$output" == *"occupied"*"DC Remote"* ]]
	[[ "$(count_log_matching 'workspace close')" -eq 0 ]]
	[[ "$(count_log_matching 'tab close')" -eq 0 ]]
	run grep -q 'ixatu-lab.*\(stop\|delete\)' "$HERDR_STUB_LOG"
	[[ "$status" -ne 0 ]]
}

@test "launcher is reproducibly published by the Chezmoi symlink template" {
	[[ -x "$LAUNCHER" ]]
	[[ -f "$SCRIPT" ]]
	[[ -f "$TMPL" ]]
	[[ "$(cat "$TMPL")" == '{{ .chezmoi.homeDir }}/dotfiles/bin/ixatu-day' ]]
}
