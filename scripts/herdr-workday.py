#!/usr/bin/env python3
"""Reconcile the declarative IXATU Herdr workday session."""

from __future__ import annotations

import argparse
import datetime as dt
import fcntl
import hashlib
import json
import os
import re
import shlex
import socket
import subprocess
import sys
import time
import tomllib
from dataclasses import dataclass
from pathlib import Path
from typing import Any


@dataclass(frozen=True)
class Space:
    name: str
    tab: str
    cwd: Path
    command: str | None = None
    kind: str | None = None
    daily: bool = False
    task: str | None = None


@dataclass
class Target:
    space: Space
    workspace_id: str
    tab_id: str
    panes: list[dict[str, Any]]


class WorkdayError(RuntimeError):
    """A safe, user-facing workday setup failure."""


def parse_args() -> argparse.Namespace:
    parser = argparse.ArgumentParser(
        description="Prepare or reuse the declarative IXATU Herdr workday."
    )
    parser.add_argument(
        "--dry-run",
        action="store_true",
        help="show reconciliation decisions without creating sessions or processes",
    )
    return parser.parse_args()


def load_config(path: Path) -> tuple[str, list[Space]]:
    try:
        with path.open("rb") as stream:
            raw = tomllib.load(stream)
    except (OSError, tomllib.TOMLDecodeError) as exc:
        raise WorkdayError(f"cannot read workday config {path}: {exc}") from exc

    session = raw.get("session")
    entries = raw.get("spaces")
    if not isinstance(session, str) or not session:
        raise WorkdayError("workday config requires a non-empty session")
    if not isinstance(entries, list) or not entries:
        raise WorkdayError("workday config requires at least one [[spaces]] entry")

    spaces: list[Space] = []
    names: set[str] = set()
    for index, entry in enumerate(entries, start=1):
        if not isinstance(entry, dict):
            raise WorkdayError(f"spaces entry {index} must be a table")
        try:
            name = entry["name"]
            tab = entry["tab"]
            cwd_text = entry["cwd"]
        except KeyError as exc:
            raise WorkdayError(
                f"spaces entry {index} is missing {exc.args[0]}"
            ) from exc
        if not all(isinstance(value, str) and value for value in (name, tab, cwd_text)):
            raise WorkdayError(f"spaces entry {index} has an invalid name, tab, or cwd")
        if name in names:
            raise WorkdayError(f"duplicate workspace name in config: {name}")
        names.add(name)

        command = entry.get("command")
        kind = entry.get("kind")
        daily = entry.get("daily", False)
        task = entry.get("task")
        if command is not None and not isinstance(command, str):
            raise WorkdayError(f"command for {name} must be a string")
        if kind is not None and not isinstance(kind, str):
            raise WorkdayError(f"kind for {name} must be a string")
        if not isinstance(daily, bool):
            raise WorkdayError(f"daily for {name} must be true or false")
        if daily and (not command or not isinstance(task, str) or not task):
            raise WorkdayError(f"daily space {name} requires command and task")

        spaces.append(
            Space(
                name=name,
                tab=tab,
                cwd=Path(os.path.expanduser(cwd_text)).resolve(strict=False),
                command=command,
                kind=kind,
                daily=daily,
                task=task,
            )
        )
    return session, spaces


class Herdr:
    def __init__(self, binary: str, session: str) -> None:
        self.binary = binary
        self.session = session

    def _run(
        self, args: list[str], *, session: bool = True, check: bool = True
    ) -> subprocess.CompletedProcess[str]:
        command = [self.binary]
        if session:
            command.extend(["--session", self.session])
        command.extend(args)
        try:
            return subprocess.run(
                command,
                check=check,
                text=True,
                capture_output=True,
            )
        except FileNotFoundError as exc:
            raise WorkdayError(f"Herdr binary not found: {self.binary}") from exc
        except subprocess.CalledProcessError as exc:
            detail = (exc.stderr or exc.stdout or "Herdr command failed").strip()
            raise WorkdayError(f"{detail} (exit {exc.returncode})") from exc

    def json(self, args: list[str], *, session: bool = True) -> dict[str, Any]:
        completed = self._run(args, session=session)
        try:
            payload = json.loads(completed.stdout)
        except json.JSONDecodeError as exc:
            raise WorkdayError(
                f"Herdr returned invalid JSON for {' '.join(args)}"
            ) from exc
        if not isinstance(payload, dict):
            raise WorkdayError(f"Herdr returned an invalid object for {' '.join(args)}")
        return payload

    def result(self, args: list[str]) -> dict[str, Any]:
        payload = self.json(args)
        result = payload.get("result")
        if not isinstance(result, dict):
            raise WorkdayError(f"Herdr response has no result for {' '.join(args)}")
        return result

    def session_running(self) -> bool:
        payload = self.json(["session", "list", "--json"], session=False)
        sessions = payload.get("sessions", [])
        return any(
            isinstance(item, dict)
            and item.get("name") == self.session
            and item.get("running") is True
            for item in sessions
        )

    def start_session(self) -> None:
        try:
            process = subprocess.Popen(
                [self.binary, "--session", self.session, "server"],
                stdin=subprocess.DEVNULL,
                stdout=subprocess.DEVNULL,
                stderr=subprocess.DEVNULL,
                start_new_session=True,
            )
        except FileNotFoundError as exc:
            raise WorkdayError(f"Herdr binary not found: {self.binary}") from exc

        deadline = time.monotonic() + 8
        while time.monotonic() < deadline:
            if self.session_running():
                return
            if process.poll() not in (None, 0):
                break
            time.sleep(0.05)
        raise WorkdayError(f"Herdr session {self.session!r} did not become ready")

    def attach(self) -> None:
        os.execvp(self.binary, [self.binary, "--session", self.session])


def records(result: dict[str, Any], key: str) -> list[dict[str, Any]]:
    value = result.get(key, [])
    if not isinstance(value, list):
        raise WorkdayError(f"Herdr result field {key} is not a list")
    return [item for item in value if isinstance(item, dict)]


def reconcile_space(herdr: Herdr, space: Space) -> Target:
    workspaces = records(herdr.result(["workspace", "list"]), "workspaces")
    workspace = next(
        (item for item in workspaces if item.get("label") == space.name), None
    )

    if workspace is None:
        created = herdr.result(
            [
                "workspace",
                "create",
                "--cwd",
                str(space.cwd),
                "--label",
                space.name,
                "--no-focus",
            ]
        )
        workspace_record = created.get("workspace", {})
        tab_record = created.get("tab", {})
        pane_record = created.get("root_pane", {})
        workspace_id = workspace_record.get("workspace_id")
        tab_id = tab_record.get("tab_id")
        pane_id = pane_record.get("pane_id")
        if not all(isinstance(value, str) for value in (workspace_id, tab_id, pane_id)):
            raise WorkdayError(
                f"Herdr did not return IDs for new workspace {space.name}"
            )
        herdr.result(["tab", "rename", tab_id, space.tab])
        print(f"CREATE {space.name} / {space.tab} ({space.cwd})")
        return Target(
            space, workspace_id, tab_id, [{"pane_id": pane_id, "tab_id": tab_id}]
        )

    workspace_id = workspace.get("workspace_id")
    if not isinstance(workspace_id, str):
        raise WorkdayError(f"Herdr workspace {space.name} has no workspace_id")
    tabs = records(herdr.result(["tab", "list", "--workspace", workspace_id]), "tabs")
    tab = next((item for item in tabs if item.get("label") == space.tab), None)
    if tab is None:
        created = herdr.result(
            [
                "tab",
                "create",
                "--workspace",
                workspace_id,
                "--cwd",
                str(space.cwd),
                "--label",
                space.tab,
                "--no-focus",
            ]
        )
        tab_record = created.get("tab", {})
        pane_record = created.get("root_pane", {})
        tab_id = tab_record.get("tab_id")
        pane_id = pane_record.get("pane_id")
        if not all(isinstance(value, str) for value in (tab_id, pane_id)):
            raise WorkdayError(f"Herdr did not return IDs for new tab {space.tab}")
        print(f"CREATE tab {space.name} / {space.tab} ({space.cwd})")
        return Target(
            space, workspace_id, tab_id, [{"pane_id": pane_id, "tab_id": tab_id}]
        )

    tab_id = tab.get("tab_id")
    if not isinstance(tab_id, str):
        raise WorkdayError(f"Herdr tab {space.tab} has no tab_id")
    panes = records(
        herdr.result(["pane", "list", "--workspace", workspace_id]), "panes"
    )
    tab_panes = [pane for pane in panes if pane.get("tab_id") == tab_id]
    print(f"REUSE  {space.name} / {space.tab}")
    return Target(space, workspace_id, tab_id, tab_panes)


def pane_process_info(herdr: Herdr, pane_id: str) -> dict[str, Any]:
    result = herdr.result(["pane", "process-info", pane_id])
    info = result.get("process_info")
    return info if isinstance(info, dict) else {}


def available_pane(herdr: Herdr, target: Target) -> str | None:
    for pane in target.panes:
        pane_id = pane.get("pane_id")
        if not isinstance(pane_id, str) or pane.get("agent"):
            continue
        info = pane_process_info(herdr, pane_id)
        shell_pid = info.get("shell_pid")
        foreground = info.get("foreground_processes", [])
        if not isinstance(foreground, list):
            continue
        foreign = [
            process
            for process in foreground
            if isinstance(process, dict) and process.get("pid") != shell_pid
        ]
        if not foreign:
            return pane_id
    return None


def pane_foreground_pids(herdr: Herdr, target: Target) -> set[int]:
    pids: set[int] = set()
    for pane in target.panes:
        pane_id = pane.get("pane_id")
        if not isinstance(pane_id, str):
            continue
        foreground = pane_process_info(herdr, pane_id).get("foreground_processes", [])
        if isinstance(foreground, list):
            pids.update(
                process["pid"]
                for process in foreground
                if isinstance(process, dict) and isinstance(process.get("pid"), int)
            )
    return pids


def desktop_commander_pids(proc_root: Path) -> set[int]:
    matches: set[int] = set()
    try:
        entries = list(proc_root.iterdir())
    except OSError:
        return matches
    for entry in entries:
        if not entry.name.isdigit() or int(entry.name) == os.getpid():
            continue
        try:
            command = (
                (entry / "cmdline")
                .read_bytes()
                .replace(b"\0", b" ")
                .decode("utf-8", errors="replace")
            )
        except OSError:
            continue
        if "@wonderwhy-er/desktop-commander" in command and re.search(
            r"(?:^|\s)remote(?:\s|$)", command
        ):
            matches.add(int(entry.name))
    return matches


def atomic_write_json(path: Path, payload: dict[str, Any]) -> None:
    temporary = path.with_name(f".{path.name}.{os.getpid()}.tmp")
    with temporary.open("w", encoding="utf-8") as stream:
        json.dump(payload, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    os.replace(temporary, path)


def claim_daily_task(path: Path, payload: dict[str, Any]) -> bool:
    path.parent.mkdir(parents=True, exist_ok=True)
    try:
        descriptor = os.open(path, os.O_WRONLY | os.O_CREAT | os.O_EXCL, 0o600)
    except FileExistsError:
        return False
    with os.fdopen(descriptor, "w", encoding="utf-8") as stream:
        json.dump(payload, stream, sort_keys=True)
        stream.write("\n")
        stream.flush()
        os.fsync(stream.fileno())
    return True


def tracked_command(space: Space, claim: Path) -> str:
    result = claim.with_suffix(".result")
    result_template = f"{result}.tmp.XXXXXX"
    return (
        f"( cd {shlex.quote(str(space.cwd))} && {space.command}; "
        "ixatu_status=$?; "
        'if [ "$ixatu_status" -eq 0 ]; then ixatu_result=success; '
        "else ixatu_result=failed; fi; "
        f"ixatu_tmp=$(mktemp {shlex.quote(result_template)}); "
        "printf 'status=%s\\nexit_code=%s\\n' "
        '"$ixatu_result" "$ixatu_status" >"$ixatu_tmp"; '
        f'mv -f -- "$ixatu_tmp" {shlex.quote(str(result))}; '
        'exit "$ixatu_status" )'
    )


def device_id() -> str:
    override = os.environ.get("IXATU_DEVICE_ID")
    if override:
        cleaned = re.sub(r"[^A-Za-z0-9._-]", "-", override).strip("-")
        if cleaned:
            return cleaned
    try:
        identity = Path("/etc/machine-id").read_text(encoding="utf-8").strip()
    except OSError:
        identity = socket.gethostname()
    return hashlib.sha256(identity.encode("utf-8")).hexdigest()[:16]


def local_date() -> str:
    return (
        os.environ.get("IXATU_DATE")
        or dt.datetime.now().astimezone().date().isoformat()
    )


def schedule_daily(
    herdr: Herdr, target: Target, state_dir: Path, day: str, device: str
) -> None:
    space = target.space
    if not space.daily or not space.task or not space.command:
        return
    claim = state_dir / device / day / f"{space.task}.json"
    if claim.exists():
        print(f"SKIP   {space.tab}: already attempted on {day} for {device}")
        return
    pane_id = available_pane(herdr, target)
    if pane_id is None:
        print(f"WARN   occupied pane; not running {space.name} / {space.tab}")
        return

    payload = {
        "attempted_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
        "date": day,
        "device": device,
        "status": "claimed",
        "task": space.task,
    }
    if not claim_daily_task(claim, payload):
        print(f"SKIP   {space.tab}: concurrent invocation already claimed it")
        return
    try:
        herdr.result(["pane", "run", pane_id, tracked_command(space, claim)])
    except WorkdayError:
        payload["status"] = "failed"
        payload["failure"] = "herdr-pane-run"
        atomic_write_json(claim, payload)
        print(f"WARN   failed to schedule {space.name} / {space.tab}")
        return
    payload["status"] = "admitted"
    atomic_write_json(claim, payload)
    print(f"RUN    {space.name} / {space.tab}: {space.command}")


def handle_desktop_commander(
    herdr: Herdr, target: Target, state_dir: Path, proc_root: Path
) -> None:
    command = target.space.command
    if not command:
        return
    active = desktop_commander_pids(proc_root)
    if active:
        if active & pane_foreground_pids(herdr, target):
            print("REUSE  Desktop Commander already active in DC Remote")
            return
        pane_id = available_pane(herdr, target)
        if pane_id is None:
            print(
                "WARN   occupied DC Remote pane; Desktop Commander is active externally"
            )
            return
        message = "Desktop Commander is active externally; no duplicate started."
        herdr.result(["pane", "run", pane_id, f"printf '%s\\n' {shlex.quote(message)}"])
        print("REUSE  Desktop Commander is active externally")
        return

    launch_marker = state_dir / "desktop-commander-launch.json"
    if launch_marker.exists():
        try:
            age = time.time() - launch_marker.stat().st_mtime
        except OSError:
            age = 0
        if age < 30:
            print("SKIP   Desktop Commander launch was admitted recently")
            return
    pane_id = available_pane(herdr, target)
    if pane_id is None:
        print("WARN   occupied pane; not launching Desktop Commander")
        return
    herdr.result(["pane", "run", pane_id, command])
    state_dir.mkdir(parents=True, exist_ok=True)
    atomic_write_json(
        launch_marker,
        {
            "admitted_at": dt.datetime.now().astimezone().isoformat(timespec="seconds"),
            "status": "admitted",
        },
    )
    print(f"RUN    {target.space.name} / {target.space.tab}: {command}")


def describe_dry_run(herdr: Herdr, spaces: list[Space]) -> None:
    running = herdr.session_running()
    print(f"DRY-RUN session {herdr.session}: {'reuse' if running else 'create'}")
    existing: dict[str, set[str]] = {}
    if running:
        for workspace in records(herdr.result(["workspace", "list"]), "workspaces"):
            name = workspace.get("label")
            workspace_id = workspace.get("workspace_id")
            if not isinstance(name, str) or not isinstance(workspace_id, str):
                continue
            tabs = records(
                herdr.result(["tab", "list", "--workspace", workspace_id]), "tabs"
            )
            existing[name] = {
                tab["label"] for tab in tabs if isinstance(tab.get("label"), str)
            }
    dc_active = bool(
        desktop_commander_pids(Path(os.environ.get("IXATU_PROC_ROOT", "/proc")))
    )
    for space in spaces:
        if not space.cwd.is_dir():
            decision = "skip: directory missing"
        elif space.name not in existing:
            decision = "create workspace and tab"
        elif space.tab not in existing[space.name]:
            decision = "reuse workspace; create tab"
        else:
            decision = "reuse workspace and tab"
        command = space.command or "none"
        if space.kind == "desktop-commander" and dc_active:
            command = "skip launch: active externally"
        elif space.daily:
            command = f"daily once: {command}"
        print(
            f"DRY-RUN {space.name} / {space.tab}: {decision}; cwd={space.cwd}; command={command}"
        )


def main() -> int:
    args = parse_args()
    dotfiles_dir = Path(
        os.environ.get("IXATU_DOTFILES_DIR", str(Path.home() / "dotfiles"))
    ).resolve(strict=False)
    config_path = Path(
        os.environ.get(
            "IXATU_WORKDAY_CONFIG", str(dotfiles_dir / "config/herdr/workday.toml")
        )
    )
    session, spaces = load_config(config_path)
    herdr = Herdr(os.environ.get("HERDR_BIN", "herdr"), session)

    if args.dry_run:
        describe_dry_run(herdr, spaces)
        return 0

    state_dir = Path(
        os.environ.get("IXATU_STATE_DIR", str(Path.home() / ".local/state/ixatu"))
    ).resolve(strict=False)
    state_dir.mkdir(parents=True, exist_ok=True)
    lock_path = state_dir / "workday.lock"
    with lock_path.open("a+", encoding="utf-8") as lock:
        fcntl.flock(lock.fileno(), fcntl.LOCK_EX)
        if not herdr.session_running():
            print(f"START  Herdr session {session}")
            herdr.start_session()
        else:
            print(f"REUSE  Herdr session {session}")

        targets: list[Target] = []
        for space in spaces:
            if not space.cwd.is_dir():
                print(f"WARN   {space.name}: directory missing; skipping {space.cwd}")
                continue
            targets.append(reconcile_space(herdr, space))

        proc_root = Path(os.environ.get("IXATU_PROC_ROOT", "/proc"))
        day = local_date()
        device = device_id()
        for target in targets:
            if target.space.kind == "desktop-commander":
                handle_desktop_commander(herdr, target, state_dir, proc_root)
            elif target.space.daily:
                schedule_daily(herdr, target, state_dir, day, device)

    print(f"ATTACH Herdr session {session}")
    sys.stdout.flush()
    sys.stderr.flush()
    herdr.attach()
    return 0


if __name__ == "__main__":
    try:
        raise SystemExit(main())
    except WorkdayError as exc:
        print(f"ERROR: {exc}", file=sys.stderr)
        raise SystemExit(1) from exc
