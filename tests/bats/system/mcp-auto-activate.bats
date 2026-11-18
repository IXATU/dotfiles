#!/usr/bin/env bats

setup() {
	umask 077
	REPO="$(cd "$BATS_TEST_DIRNAME/../../.." && pwd)"
	export REPO
	export HOME="$BATS_TEST_TMPDIR/home"
	mkdir -p "$HOME/.local/share/ixatu-azure-mcp-pilot"
	chmod 700 "$HOME"
	export LAUNCHER="$HOME/.local/share/ixatu-azure-mcp-pilot/start.sh"
	cat >"$LAUNCHER" <<'LAUNCHER'
#!/usr/bin/env bash
set -euo pipefail
export PATH="$HOME/.local/bin:/usr/local/bin:/usr/bin:/bin"
export AZURE_TOKEN_CREDENTIALS=AzureCliCredential
exec uvx --from msmcp-azure==3.0.0 \
 azmcp server start --transport stdio --mode all \
 --namespace containerapps --namespace group --read-only
LAUNCHER
	chmod 700 "$LAUNCHER"
	unset DOTFILES_UPDATE_MOCK DOTFILES_MCP_AUTO_ACTIVATE
}

lifecycle() {
	run python3 - "$1" <<'PY'
import importlib.util, os, pathlib, sys
from unittest.mock import patch
spec = importlib.util.spec_from_file_location('activate', os.environ['REPO'] + '/scripts/update/azure-mcp-activate.py')
a = importlib.util.module_from_spec(spec)
spec.loader.exec_module(a)
case = sys.argv[1]
p = pathlib.Path(os.environ['LAUNCHER'])
old = p.read_bytes()
mode = p.stat().st_mode
calls = []
# Fail closed if this transaction ever tries to open a profile/credential path.
def audit(event, args):
    if event == 'open' and isinstance(args[0], (str, bytes)):
        name = os.fsdecode(args[0])
        assert '/.config/' not in name and not name.endswith('runtime.env'), name
sys.addaudithook(audit)

def svc(action):
    calls.append(action)
    assert a.SERVICE == 'ixatu-azure-mcp-pilot.service'
    if case == 'inactive' or (case == 'rollback' and action == 'restart' and calls.count('restart') == 1):
        raise RuntimeError('mock service failure')

def smoke(uvx, version, env):
    calls.append('smoke:' + version)
    assert env['UV_NO_CONFIG'] == '1'
    assert not any('KEY' in k or 'SECRET' in k for k in env)
    if case == 'invalid-baseline':
        raise ValueError('unsafe baseline')
    if case == 'invalid-contract' and version != '3.0.0':
        return {'schemas': 'changed'}
    return {'schemas': 'same'}

def warm(args, **kwargs):
    calls.append('download')
    assert pathlib.Path(args[0]).name == 'uvx'
    assert args[1:] == ['--from', 'msmcp-azure==3.1.0', 'azmcp', '--help']
    assert kwargs['timeout'] == 180
    if case == 'download-failure':
        raise RuntimeError('mock download failure')

def ready(path, version):
    calls.append('ready:' + version)
    assert a.launcher(path)[3] == version
    if case == 'postflight-failure' and version != '3.0.0':
        raise ValueError('mock health failure')

version = '3.0.0' if case == 'noop' else '4.0.0' if case == 'major' else '3.1.0'
if case == 'symlink':
    p.rename(p.with_name('original'))
    p.symlink_to(p.with_name('original'))
if case == 'scope':
    p.write_text(p.read_text().replace('--namespace group', '--namespace subscription'))
    old = p.read_bytes()
if case == 'unexpected':
    p.write_text('echo arbitrary-command\n' + p.read_text())
    old = p.read_bytes()
if case == 'absolute':
    p.write_text(p.read_text().replace('exec uvx', 'exec ' + os.environ['HOME'] + '/.local/bin/uvx'))
    old = p.read_bytes()
if case == 'optout':
    os.environ['DOTFILES_MCP_AUTO_ACTIVATE'] = '0'
if case == 'mock':
    os.environ['DOTFILES_UPDATE_MOCK'] = '1'
if case == 'lock':
    lock = os.open(p.parent, os.O_RDONLY)
    a.fcntl.flock(lock, a.fcntl.LOCK_EX | a.fcntl.LOCK_NB)
failed = False
with patch.object(a, 'service', svc), patch.object(a, 'run', warm), patch.object(a, 'smoke', smoke), patch.object(a, 'ready', ready), patch.object(sys, 'argv', ['activate', version]):
    try:
        a.main()
    except Exception:
        import traceback
        traceback.print_exc()
        failed = True
success = case in ('success', 'absolute')
assert failed == (not success and case != 'noop'), (case, calls, failed)
assert p.stat().st_mode == mode
if success:
    assert p.read_bytes() == old.replace(b'msmcp-azure==3.0.0', b'msmcp-azure==3.1.0')
    assert calls == ['is-active', 'smoke:3.0.0', 'download', 'smoke:3.1.0', 'is-active', 'restart', 'ready:3.1.0'], calls
else:
    assert p.read_bytes() == old
    if case in ('rollback', 'postflight-failure'):
        assert calls.count('restart') == 2 and calls[-1] == 'ready:3.0.0', calls
    else:
        assert 'restart' not in calls
assert not list(p.parent.glob('.start-*'))
print('PASS', case)
PY
	[ "$status" -eq 0 ]
	[[ "$output" == *"PASS $1"* ]]
}

@test "Azure compatible activation preserves launcher text mode and service isolation" { lifecycle success; }
@test "Azure activation accepts absolute uvx path" { lifecycle absolute; }
@test "Azure equal version is a genuine no-op without package or service operations" { lifecycle noop; }
@test "Azure major mismatch never downloads or restarts" { lifecycle major; }
@test "Azure inactive service never downloads or restarts" { lifecycle inactive; }
@test "Azure candidate contract failure retains launcher and live service" { lifecycle invalid-contract; }
@test "Azure failed download retains launcher and live service" { lifecycle download-failure; }
@test "Azure restart failure restores launcher atomically and verifies rollback" { lifecycle rollback; }
@test "Azure readiness failure restores launcher and restarts previous version" { lifecycle postflight-failure; }
@test "Azure rejects symlink launcher" { lifecycle symlink; }
@test "Azure rejects unauthorized namespaces" { lifecycle scope; }
@test "Azure rejects unexpected shell commands" { lifecycle unexpected; }
@test "Azure opt-out prevents package and service operations" { lifecycle optout; }
@test "Azure mock prevents package and service operations" { lifecycle mock; }
@test "Azure concurrent activation lock refuses mutation" { lifecycle lock; }

@test "Azure MCP stdio verifies initialize and exact tools with object schemas without tools call" {
	cat >"$BATS_TEST_TMPDIR/uvx" <<'PY'
#!/usr/bin/env python3
import json, os, sys
assert sys.argv[1:4] == ['--offline', '--from', 'msmcp-azure==3.1.0']
for line in sys.stdin:
    req = json.loads(line)
    method = req['method']
    assert method in ('initialize', 'notifications/initialized', 'tools/list')
    if method == 'notifications/initialized':
        continue
    if method == 'initialize':
        result = {'protocolVersion': '2024-11-05', 'capabilities': {'tools': {}}}
    else:
        names = ['containerapps_list', 'group_list', 'group_resource_list']
        if os.environ.get('BAD') == 'tools':
            names.append('group_delete')
        schema = {'type': 'object', 'properties': {}, 'required': []}
        if os.environ.get('BAD') == 'schema':
            schema['type'] = 'string'
        result = {'tools': [{'name': n, 'inputSchema': schema, 'annotations': {'readOnlyHint': os.environ.get('BAD') != 'write'}} for n in names]}
    print(json.dumps({'jsonrpc': '2.0', 'id': req['id'], 'result': result}), flush=True)
PY
	chmod +x "$BATS_TEST_TMPDIR/uvx"
	run python3 - "$BATS_TEST_TMPDIR/uvx" <<'PY'
import importlib.util, os, sys
s = importlib.util.spec_from_file_location('a', os.environ['REPO'] + '/scripts/update/azure-mcp-activate.py')
a = importlib.util.module_from_spec(s)
s.loader.exec_module(a)
for bad in ('', 'tools', 'schema', 'write'):
    env = dict(os.environ, BAD=bad)
    failed = False
    try:
        result = a.smoke(sys.argv[1], '3.1.0', env)
        assert set(result) == a.TOOLS
    except ValueError:
        failed = True
    assert failed == bool(bad), bad
PY
	[ "$status" -eq 0 ]
}

@test "Azure invalid current read-only contract prevents downloading or restarting" { lifecycle invalid-baseline; }
