#!/usr/bin/env python3
"""Run shipped MapKV accounting and adjacent regression tests in an isolated module.

Requires an open editor map. No map metadata is written; only the isolated
module's cache changes. The module is loaded from /tmp and unloaded afterward.
"""
import json
import pathlib
import re
import subprocess
import time
import uuid

repo = pathlib.Path(__file__).resolve().parents[2]
call_script = repo.parent / "tm-control-mcp/tools/call.py"
run_id = "epp-kv-accounting-" + uuid.uuid4().hex[:12]
stage = pathlib.Path("/tmp") / run_id
stage.mkdir()
log = pathlib.Path.home() / "OpenplanetNext/Openplanet.log"
offset = log.stat().st_size


def call(args):
    response = json.loads(subprocess.check_output(
        ["python3", str(call_script), "--timeout", "15", "ControlPlugin", json.dumps(args)], text=True))
    if not response.get("ok") or not response.get("data", {}).get("result", {}).get("success"):
        raise RuntimeError(response)
    return response


for name in ("MapKV.as", "MapKVStore.as"):
    (stage / name).write_bytes((repo / "src/Editor" / name).read_bytes())
source = (repo / "src/Editor/MapKVStore_Test.as").read_text()
# Keep the synchronous checks, without enabling the full DEV memory reader.
source = source.replace("#if DEV", "").replace("#endif", "")
source = re.sub(r"    \[Test\]\n    void [^\n]+\n", "", source)
checks = re.findall(r"void (MapKVStore_Check\w+)\(\)", source)
assert checks, "No accounting checks found"
(stage / "Checks.as").write_text(source)
(stage / "info.toml").write_text('[meta]\nname = "MapKV accounting regression"\nauthor = "XertroV"\nversion = "0.0.1"\n[script]\ntimeout = 15000\n')
main = '''uint64 Dev_GetPointerForNod(CMwNod@ node) { return node is null ? 0 : 1; }
namespace ToML {
    CGameEditorPluginMap@ GetPluginPMT() { return null; }
    bool HasQueued(const string &in type) { return false; }
    void SendMessage(const string &in type, string[]@ data) {}
}
void Main() {
    auto result = Json::Object();
    result["passed"] = false;
    try {
        if (MapKVStore::EditorMap() is null) throw("Open an editor map first");
CALLS
        result["passed"] = true;
    } catch { result["error"] = getExceptionInfo(); }
    IO::File output(RECEIPT, IO::FileMode::Write);
    output.Write(Json::Write(result)); output.Close();
    print("MapKV accounting: " + Json::Write(result));
}
'''
receipt = stage / "receipt.json"
main = main.replace("CALLS", "\n".join("        Tests::" + name + "();" for name in checks))
main = main.replace("RECEIPT", json.dumps(str(receipt)))
(stage / "Main.as").write_text(main)
subprocess.run(["openplanet-lsp", "check", "--format", "plain", str(stage)], check=True)
try:
    (stage / "load.json").write_text(json.dumps(call({"action": "load", "path": str(stage) + "/"})))
    deadline = time.monotonic() + 10
    while not receipt.exists() and time.monotonic() < deadline:
        time.sleep(0.05)
    result = json.loads(receipt.read_text())
    result["checks"] = checks
    print(json.dumps(result))
    if not result["passed"]:
        raise SystemExit(1)
finally:
    (stage / "unload.json").write_text(json.dumps(call({"action": "unload", "id": run_id})))
    with log.open("rb") as stream:
        stream.seek(offset)
        (stage / "native.log").write_bytes(stream.read())
    print("Evidence: " + str(stage))
