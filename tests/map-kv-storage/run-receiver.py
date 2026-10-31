#!/usr/bin/env python3
"""Exercise the shipped receiver against page-local data, never map metadata."""
import json
import pathlib
import subprocess

repo = pathlib.Path(__file__).resolve().parents[2]
source = (repo / "ml-scripts/EditorPlugin_EditorPlusPlus.Script.txt").read_text()
start = source.index("Integer MapKVUtf8Bytes(")
end = source.index("\nVoid DropMapKVParts", start)
functions = source[start:end].replace("declare metadata Text[Text] _EKV_ for Map;", "declare Text[Text] _EKV_ for Page;")
script = '''#Include "TextLib" as TL
Void SendEvent(Text Kind, Text[] Args) {
    declare Text[] Payload = [Kind];
    foreach (Arg in Args) Payload.add(Arg);
    SendCustomEvent("MLHook_Event_EppReceiverTest", Payload);
}
''' + functions + '''
main() {
    declare Text[] Samples = ["", "abc", "%", "日本", "😀", "a %&+\\n"];
    foreach (Sample in Samples) SendEvent("bytes", ["" ^ MapKVUtf8Bytes(Sample)]);
    declare Text[Text] _EKV_ for Page;
    declare Text Large = "日";
    while (TL::Length(Large) < 34000) Large = Large ^ Large;
    _EKV_["_EKV_A"] = Large;
    ApplyMapKV("_EKV_B", Large, "18446744073709551614");
    SendEvent("unchanged", ["" ^ _EKV_.count]);
    _EKV_.clear();
    ApplyMapKV("_EKV_C", "日本😀", "18446744073709551614");
}
'''
args = dict(script=script, context="in-editor", pageUid="EppReceiverTest", replace=True,
            persist=False, waitMs=250, collectMs=500, resultEvent="EppReceiverTest")
result = json.loads(subprocess.check_output(
    ["python3", str(repo.parent / "tm-control-mcp/tools/call.py"), "RunManialinkScript", json.dumps(args)], text=True))
path = pathlib.Path("/tmp/epp-mapkv-receiver-result.json")
path.write_text(json.dumps(result, indent=2))
output = result["data"]["result"]["output"]
rows = [row["dataParts"] for row in output["results"]]
assert rows == [["bytes", str(n)] for n in (0, 3, 1, 6, 4, 6)] + [
    ["MapKVSetRejected", "_EKV_B", "18446744073709551614"],
    ["unchanged", "1"],
    ["MapKVSet", "_EKV_C", "日本😀", "18446744073709551614"],
], rows
assert output["executionConfirmed"] and output["removedAfter"]
print("PASS: UTF-8 byte boundaries, overflow rejected without mutation, exact 64-bit write ID echo")
print("Evidence: " + str(path))
