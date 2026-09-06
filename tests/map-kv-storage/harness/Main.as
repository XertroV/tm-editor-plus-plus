uint64 Dev_GetPointerForNod(CMwNod@ nod) { return NodPtr::Of(nod); }
uint64 Dev_FindPatternCached(const string &in pattern) { return Dev::FindPattern(pattern); }
// No editor plugin in this isolated harness: MapKVHealth uses the handle only
// to scope its records, a detached metadata node has no echoes, and there is
// nothing to resync with.
namespace ToML {
    CGameEditorPluginMap@ GetPluginPMT() { return null; }
    void ResyncPlease() {}
}
namespace FromML { bool metadataDisabled = false; }
const uint16 O_ITEM_MODEL_Id = 0x28;
namespace ItemBuilder { string NormPath(const string &in path) { return path.Replace("/", "\\"); } }
void Check(bool ok, const string &in message) { if (!ok) throw(message); }
void CopyFile(const string &in source, const string &in dest) {
    IO::File input(source, IO::FileMode::Read);
    IO::File output(dest, IO::FileMode::Write);
    output.Write(input.Read(input.Size()));
    output.Close(); input.Close();
}
string ReadFile(const string &in path) {
    IO::File input(path, IO::FileMode::Read);
    string value = input.ReadToEnd(); input.Close(); return value;
}
void CheckMetadata(CScriptTraitsMetadata@ md, const string &in expected, const string &in phase) {
    Check(md !is null, phase + ": not metadata");
    auto keys = MapKV::ListMetadataKeys(md);
    Check(keys.Length == 3, phase + ": expected three keys");
    string value;
    Check(MapKV::TryReadMetadataValue(md, "_EKV_Storage.payload", value), phase + ": payload absent");
    Check(value.Length == 10240 && value == expected, phase + ": 10240-byte payload mismatch");
    Check(MapKV::TryReadMetadataValue(md, "_EKV_Storage.empty", value) && value == "", phase + ": empty missing");
    Check(MapKV::TryReadMetadataValue(md, "_EKV_Storage.other", value) && value == "second key remains intact", phase + ": other mismatch");
    print("KV-STORAGE PASS " + phase + " keys=3 payloadBytes=10240");
}
void Main() {
    auto result = Json::Object();
    result["scope"] = "detached CScriptTraitsMetadata GBX native save and fresh reload; not whole-map save";
    result["run"] = RunId;
    try {
        auto map = MapKV::CurrentMap();
        auto activeMetadata = map is null ? null : map.ScriptMetadata;
        uint64 activeMapPtr = NodPtr::Of(map);
        uint64 activeMetadataPtr = NodPtr::Of(activeMetadata);
        uint64 mapFidBefore = map is null ? 0 : Dev::GetOffsetUint64(map, 8);
        uint64 metadataFidBefore = activeMetadata is null ? 0 : Dev::GetOffsetUint64(activeMetadata, 8);
        string expected = ReadFile(IO::FromUserGameFolder(RunDir + "expected.txt"));
        Check(expected.Length == 10240, "fixture must be exactly 10240 bytes");
        auto inputFid = Fids::GetUser(RunDir + "input.Gbx");
        Check(inputFid.Nod is null, "input path already cached; use unique run directory");
        auto input = cast<CScriptTraitsMetadata>(Fids::Preload(inputFid));
        Check(input !is activeMetadata, "fixture unexpectedly aliases active metadata");
        CheckMetadata(input, expected, "native-input-load");
        string error;
        Check(NativeSave::SaveNodToUser(input, RunDir + "native-output.Gbx", error), "native save: " + error);
        CheckMetadata(input, expected, "after-native-save");
        CopyFile(IO::FromUserGameFolder(RunDir + "native-output.Gbx"), IO::FromUserGameFolder(RunDir + "fresh-reload.Gbx"));
        auto freshFid = Fids::GetUser(RunDir + "fresh-reload.Gbx");
        Check(freshFid.Nod is null, "fresh reload path was cached");
        auto fresh = cast<CScriptTraitsMetadata>(Fids::Preload(freshFid));
        Check(fresh !is input && fresh !is activeMetadata, "fresh node must be distinct");
        CheckMetadata(fresh, expected, "cache-free-native-reload");
        string actual;
        Check(MapKV::TryReadMetadataValue(fresh, "_EKV_Storage.payload", actual), "fresh payload missing");
        IO::File actualFile(IO::FromUserGameFolder(RunDir + "actual.txt"), IO::FileMode::Write);
        actualFile.Write(actual); actualFile.Close();
        Check(MapKV::CurrentMap() is map, "active map changed during test");
        Check(map is null || map.ScriptMetadata is activeMetadata, "active metadata changed during test");
        Check(map is null || Dev::GetOffsetUint64(map, 8) == mapFidBefore, "active map fid changed");
        Check(activeMetadata is null || Dev::GetOffsetUint64(activeMetadata, 8) == metadataFidBefore, "active metadata fid changed");
        result["passed"] = true;
        result["payloadBytes"] = actual.Length;
        result["activeMapPointer"] = Text::FormatPointer(activeMapPtr);
        result["activeMetadataPointer"] = Text::FormatPointer(activeMetadataPtr);
        result["activeMapAndMetadataBindingsUnchanged"] = true;
        result["inputPointer"] = Text::FormatPointer(NodPtr::Of(input));
        result["freshPointer"] = Text::FormatPointer(NodPtr::Of(fresh));
        print("KV-STORAGE PASS active map and metadata identities/fid bindings unchanged");
    } catch {
        result["passed"] = false;
        result["error"] = getExceptionInfo();
        error("KV-STORAGE FAIL " + getExceptionInfo());
    }
    AsCall::Drop();
    IO::File receipt(IO::FromUserGameFolder(RunDir + "receipt.json"), IO::FileMode::Write);
    receipt.Write(Json::Write(result)); receipt.Close();
    print("KV-STORAGE RESULT " + Json::Write(result));
}
void OnDestroyed() {
    AsCall::Drop();
    uint64 scratch = NodPtr::tmpSpace;
    NodPtr::Cleanup();
    if (scratch != 0) Dev::Free(scratch);
}
