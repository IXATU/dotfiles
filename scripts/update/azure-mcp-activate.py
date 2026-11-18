#!/usr/bin/env python3
"""Conservative Azure pilot transaction. Never read tunnel profiles or credentials."""
import contextlib
import fcntl
import json
import os
from pathlib import Path
import re
import selectors
import shlex
import signal
import stat
import subprocess
import sys
import tempfile
import time
import urllib.request

SERVICE = 'ixatu-azure-mcp-pilot.service'
FLAGS = ['azmcp', 'server', 'start', '--transport', 'stdio', '--mode', 'all',
         '--namespace', 'containerapps', '--namespace', 'group', '--read-only']
TOOLS = {'containerapps_list', 'group_list', 'group_resource_list'}
STABLE = r'(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)\.(?:0|[1-9][0-9]*)'


def require(ok):
    if not ok:
        raise ValueError('preflight/contract validation failed')


def run(args, timeout=45, env=None):
    proc = subprocess.Popen(args, env=env, stdin=subprocess.DEVNULL,
                            stdout=subprocess.DEVNULL, stderr=subprocess.DEVNULL,
                            start_new_session=True)
    try:
        code = proc.wait(timeout=timeout)
        if code:
            raise subprocess.CalledProcessError(code, args)
    finally:
        if proc.poll() is None:
            os.killpg(proc.pid, signal.SIGKILL)
            proc.wait(timeout=3)


def service(action):
    run(['systemctl', '--user', action, SERVICE])


def launcher(path):
    home = Path(os.environ['HOME'])
    require(home.is_absolute() and home.resolve() == home)
    require(path == home / '.local/share/ixatu-azure-mcp-pilot/start.sh')
    for item in [path, *path.parents]:
        st = item.lstat()
        require(not stat.S_ISLNK(st.st_mode))
        if item == home or home in item.parents:
            require(st.st_uid == os.getuid() and not st.st_mode & 0o022)
        if item == home:
            break
    st = path.stat()
    require(stat.S_ISREG(st.st_mode) and st.st_nlink == 1 and st.st_mode & 0o100)
    text = path.read_bytes().decode('utf-8')
    require(text.splitlines()[0] in ('#!/usr/bin/env bash', '#!/bin/bash'))
    # Accept only the known pilot shell preamble. Never source/evaluate it.
    lines = text.replace('\\\n', '').splitlines()
    allowed = {
        'set -euo pipefail', 'set +x',
        'export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"',
        'export AZURE_TOKEN_CREDENTIALS=AzureCliCredential',
        'export AZURE_MCP_COLLECT_TELEMETRY=false',
        'export AZURE_MCP_COLLECT_TELEMETRY_MICROSOFT=false',
        'export AZURE_EXTENSION_USE_DYNAMIC_INSTALL=no', 'export UV_NO_PROGRESS=1',
    }
    guard = ['for tool in az uvx; do',
             'command -v "$tool" >/dev/null || { printf \'ERROR: missing %s in pilot PATH\\n\' "$tool" >&2; exit 1; }',
             'done']
    commands = []
    i = 0
    while i < len(lines):
        line = lines[i].strip()
        if line == guard[0]:
            require([v.strip() for v in lines[i:i + 3]] == guard)
            i += 3
            continue
        if line and not line.startswith('#') and line not in allowed:
            commands.append(shlex.split(line))
        i += 1
    require(len(commands) == 1)
    cmd = commands[0]
    require(len(cmd) >= 5 and cmd[0] == 'exec' and cmd[2] == '--from')
    require(cmd[1] == 'uvx' or cmd[1] == str(home / '.local/bin/uvx'))
    require(re.fullmatch('msmcp-azure==' + STABLE, cmd[3]))
    require(cmd[4:] == FLAGS)
    require(text.count(cmd[3]) == 1)
    return text, st, cmd[1], cmd[3].split('==')[1]


def smoke(uvx, version, env):
    """MCP newline JSON stdio; bounded buffer/deadline; no tools/call."""
    cmd = [uvx, '--offline', '--from', 'msmcp-azure==' + version, *FLAGS]
    proc = subprocess.Popen(cmd, stdin=subprocess.PIPE, stdout=subprocess.PIPE,
                            stderr=subprocess.DEVNULL, env=env, start_new_session=True)
    selector = selectors.DefaultSelector()
    selector.register(proc.stdout, selectors.EVENT_READ)
    buffer = b''
    deadline = time.monotonic() + 45

    def send(value):
        proc.stdin.write(json.dumps(value).encode() + b'\n')
        proc.stdin.flush()

    def response(request_id):
        nonlocal buffer
        while time.monotonic() < deadline:
            if b'\n' in buffer:
                line, buffer = buffer.split(b'\n', 1)
                value = json.loads(line)
                if value.get('id') == request_id:
                    require('error' not in value and 'result' in value)
                    return value['result']
                continue
            if selector.select(max(0, deadline - time.monotonic())):
                chunk = os.read(proc.stdout.fileno(), 65536)
                require(chunk)
                buffer += chunk
                require(len(buffer) <= 2_000_000)
        raise TimeoutError('MCP timeout')

    try:
        send({'jsonrpc': '2.0', 'id': 1, 'method': 'initialize', 'params': {
            'protocolVersion': '2024-11-05', 'capabilities': {},
            'clientInfo': {'name': 'dotfiles-preflight', 'version': '1'}}})
        initialized = response(1)
        require(initialized.get('protocolVersion') == '2024-11-05')
        require('tools' in initialized.get('capabilities', {}))
        send({'jsonrpc': '2.0', 'method': 'notifications/initialized'})
        send({'jsonrpc': '2.0', 'id': 2, 'method': 'tools/list', 'params': {}})
        result = response(2)
        tools = result['tools']
        require(not result.get('nextCursor') and len(tools) == 3)
        require({tool['name'] for tool in tools} == TOOLS)
        schemas = {}
        for tool in tools:
            schema = tool['inputSchema']
            require(schema.get('type') == 'object')
            require(isinstance(schema.get('properties', {}), dict))
            require(isinstance(schema.get('required', []), list))
            require(set(schema.get('required', [])) <= set(schema.get('properties', {})))
            require(tool.get('annotations', {}).get('readOnlyHint', True) is True)
            schemas[tool['name']] = (schema, tool.get('outputSchema'))
        return schemas
    finally:
        selector.close()
        # Reap the entire uvx/server process group, including startup failures.
        try:
            os.killpg(proc.pid, signal.SIGTERM)
            proc.wait(timeout=3)
        except (ProcessLookupError, subprocess.TimeoutExpired):
            try:
                os.killpg(proc.pid, signal.SIGKILL)
            except ProcessLookupError:
                pass
            proc.wait(timeout=3)
        proc.stdin.close()
        proc.stdout.close()


def atomic(path, data, metadata):
    fd, name = tempfile.mkstemp(prefix='.start-', dir=path.parent)
    try:
        with os.fdopen(fd, 'wb') as stream:
            stream.write(data.encode())
            os.fchown(stream.fileno(), metadata.st_uid, metadata.st_gid)
            os.fchmod(stream.fileno(), stat.S_IMODE(metadata.st_mode))
            stream.flush()
            os.fsync(stream.fileno())
        os.replace(name, path)
    finally:
        if os.path.exists(name):
            os.unlink(name)


def ready(path, version):
    deadline = time.monotonic() + 30
    # A redirect must not turn another endpoint's HTTP 200 into local readiness.
    class NoRedirect(urllib.request.HTTPRedirectHandler):
        def redirect_request(self, *args, **kwargs):
            return None

    opener = urllib.request.build_opener(urllib.request.ProxyHandler({}), NoRedirect())
    while time.monotonic() < deadline:
        try:
            service('is-active')
            require(launcher(path)[3] == version)
            with opener.open('http://127.0.0.1:49188/readyz', timeout=1) as reply:
                require(200 <= reply.status < 300)
            return
        except (OSError, ValueError, subprocess.SubprocessError):
            time.sleep(1)
    raise TimeoutError('readiness timeout')


def main():
    require(os.environ.get('DOTFILES_MCP_AUTO_ACTIVATE', '1') != '0')
    require(os.environ.get('DOTFILES_UPDATE_MOCK', '0') == '0')
    version = sys.argv[1]
    require(re.fullmatch(STABLE, version))
    path = Path(os.environ['HOME']) / '.local/share/ixatu-azure-mcp-pilot/start.sh'
    text, metadata, uvx, old = launcher(path)
    if version == old:
        print('UNCHANGED ' + old)
        return
    current, candidate = tuple(map(int, old.split('.'))), tuple(map(int, version.split('.')))
    require(candidate > current and candidate[0] == current[0])
    # Lock directory inode, no lockfile or symlink opening. Covers entire preflight.
    with contextlib.ExitStack() as stack:
        lock = os.open(path.parent, os.O_RDONLY | os.O_DIRECTORY | os.O_NOFOLLOW)
        stack.callback(os.close, lock)
        fcntl.flock(lock, fcntl.LOCK_EX | fcntl.LOCK_NB)
        require(launcher(path)[0] == text)
        service('is-active')
        require('/' + SERVICE not in Path('/proc/self/cgroup').read_text())
        env = {'HOME': os.environ['HOME'],
               'PATH': os.environ['HOME'] + '/.local/bin:/usr/local/bin:/usr/bin:/bin',
               'UV_NO_CONFIG': '1', 'UV_NO_PROGRESS': '1',
               'AZURE_TOKEN_CREDENTIALS': 'AzureCliCredential',
               'AZURE_MCP_COLLECT_TELEMETRY': 'false',
               'AZURE_MCP_COLLECT_TELEMETRY_MICROSOFT': 'false',
               'AZURE_EXTENSION_USE_DYNAMIC_INSTALL': 'no'}
        baseline = smoke(uvx, old, env)
        # Warm uv cache before touching the service; all later smoke is offline.
        run([uvx, '--from', 'msmcp-azure==' + version, 'azmcp', '--help'], timeout=180, env=env)
        require(smoke(uvx, version, env) == baseline)
        print('PREPARED ' + version, flush=True)
        require(launcher(path)[0] == text)
        service('is-active')
        try:
            atomic(path, text.replace('msmcp-azure==' + old, 'msmcp-azure==' + version), metadata)
            service('restart')
            ready(path, version)
        except BaseException:
            for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
                signal.signal(sig, signal.SIG_IGN)
            try:
                atomic(path, text, metadata)
                service('restart')
                ready(path, old)
                print('ROLLBACK: previous launcher restored; service ready', flush=True)
            except BaseException:
                print('ROLLBACK FAILED: manual launcher/service recovery required', flush=True)
            raise
        print('INSTALLED/ACTIVATED ' + version, flush=True)


if __name__ == '__main__':
    def interrupted(signum, _frame):
        raise InterruptedError('activation interrupted')

    for sig in (signal.SIGHUP, signal.SIGINT, signal.SIGTERM):
        signal.signal(sig, interrupted)
    try:
        main()
    except Exception:
        # No subprocess/launcher output, Azure data or environment in updater logs.
        print('ACTIVATION_PENDING: validation or activation failed; inspect local service status', file=sys.stderr)
        sys.exit(1)
