#!/usr/bin/env python3
"""Run isolated native storage verification; never opens or saves an editor map."""
import hashlib
import json
import pathlib
import subprocess
import time
import uuid

here = pathlib.Path(__file__).resolve().parent
def find_control_mcp_call(start):
    """tm-control-mcp is a sibling of the plugin checkout, but a git worktree
    sits one level deeper (.worktrees/<branch>/), so walk up for it."""
    for base in [start] + list(start.parents):
        candidate = base.parent / 'tm-control-mcp/tools/call.py'
        if candidate.exists():
            return candidate
    raise SystemExit('tm-control-mcp/tools/call.py not found near ' + str(start))

repo = here.parent.parent
run_id = time.strftime('%Y%m%dT%H%M%S', time.gmtime()) + '-' + uuid.uuid4().hex[:8]
subprocess.run([str(here / 'build.sh'), run_id], check=True)
stage = pathlib.Path('/tmp') / ('epp-kv-storage-' + run_id)
fixture = pathlib.Path.home() / 'tm-docs/Tests/EppKVStorage' / run_id
call_script = find_control_mcp_call(repo)
log = pathlib.Path.home() / 'OpenplanetNext/Openplanet.log'
log_offset = log.stat().st_size

def call(args):
    out = subprocess.check_output(['python3', str(call_script), 'ControlPlugin', json.dumps(args)], text=True)
    response = json.loads(out)
    if not response.get('ok'):
        raise RuntimeError(out)
    return response

try:
    loaded = call({'action': 'load', 'path': str(stage) + '/'})
    (fixture / 'load.json').write_text(json.dumps(loaded, indent=2))
    receipt_path = fixture / 'receipt.json'
    deadline = time.monotonic() + 10
    while not receipt_path.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    receipt = json.loads(receipt_path.read_text())
    if not receipt.get('passed'):
        raise RuntimeError(str(receipt))
    expected = (fixture / 'expected.txt').read_bytes()
    actual = (fixture / 'actual.txt').read_bytes()
    assert len(expected) == 10240 and actual == expected
    assert (fixture / 'native-output.Gbx').read_bytes() == (fixture / 'fresh-reload.Gbx').read_bytes()
    receipt['payloadSha256'] = hashlib.sha256(actual).hexdigest()
    receipt['outputSha256'] = hashlib.sha256((fixture / 'native-output.Gbx').read_bytes()).hexdigest()
    (fixture / 'verified.json').write_text(json.dumps(receipt, indent=2) + '\n')
    print(json.dumps(receipt, indent=2))
finally:
    unloaded = call({'action': 'unload', 'id': stage.name})
    (fixture / 'unload.json').write_text(json.dumps(unloaded, indent=2))
    with log.open('rb') as stream:
        stream.seek(log_offset)
        (fixture / 'native.log').write_bytes(stream.read())
print('Evidence: ' + str(fixture))
