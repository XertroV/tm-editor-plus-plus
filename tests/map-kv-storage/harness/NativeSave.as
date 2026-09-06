#if DEV
// Save any nod to a User .Gbx outside the item editor.
// GbxArchive_SerializeNodToFid(fid, nod, mode) via AsCall (OP-thread native call).
// research/2026-09-03-SaveItemModelAsCall.md
namespace NativeSave {
    // Unique in Ghidra + live (slide 0) 2026-09-03.
    const string SerializePat = "48 89 5C 24 18 48 89 74 24 20 57 48 81 EC D0 01 00 00 48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 84 24 C0 01 00 00 48 8B D9 41 8B F0";
    const string SerializePrologue = "48 89 5C 24 18 48 89 74 24 20 57 48 81 EC D0 01 00 00";
    const uint ModeItem = 10;   // item editor mode: compressed, fid-bearing children become refs
    const uint ModeEmbed = 8;   // map-embed mode

    uint64 _serializeFn = 0;

    uint64 SerializeFn(string &out err) {
        err = "";
        if (_serializeFn != 0) return _serializeFn;
        uint64 fn = Dev_FindPatternCached(SerializePat);
        if (fn == 0) { err = "GbxArchive_SerializeNodToFid pattern not found"; return 0; }
        if (!Hex::BytesMatch(fn, SerializePrologue)) { err = "prologue mismatch at " + Text::FormatPointer(fn); return 0; }
        _serializeFn = fn;
        return fn;
    }

    // relPath is relative to the User drive, e.g. "Items\\Foo.Item.Gbx".
    // Fids::GetUser creates the CSystemFidFile when the file does not exist yet.
    CSystemFidFile@ DestFid(const string &in relPath) {
        string p = ItemBuilder::NormPath(relPath);
        return Fids::GetUser(p);
    }

    // The ident (model+0x28) is persisted and never recomputed on load; make it match the file name
    // relative to the Items folder, as the item editor does.
    void FixItemIdent(CGameItemModel@ model, const string &in relPath) {
        string p = ItemBuilder::NormPath(relPath);
        string rel = p.StartsWith("Items\\") ? p.SubStr(6) : p;
        MwId id;
        id.SetName(rel);
        Dev::SetOffset(model, O_ITEM_MODEL_Id, id.Value);
    }

    // Returns true when the native call reported success and the file exists on disk.
    bool SaveNodToUser(CMwNod@ nod, const string &in relPath, string &out err, uint mode = ModeItem) {
        err = "";
        if (nod is null) { err = "nod is null"; return false; }
        uint64 fn = SerializeFn(err);
        if (fn == 0) return false;
        err = AsCall::Ensure();
        if (err.Length > 0) return false;
        auto fid = DestFid(relPath);
        if (fid is null) { err = "Fids::GetUser returned null for " + relPath; return false; }
        auto model = cast<CGameItemModel>(nod);
        if (model !is null) FixItemIdent(model, relPath);
        uint64 ret = AsCall::Call3(fn, Dev_GetPointerForNod(fid), Dev_GetPointerForNod(nod), uint64(mode));
        string full = IO::FromUserGameFolder(relPath.Replace("\\", "/"));
        if ((ret & 0xFFFFFFFF) == 0) { err = "SerializeNodToFid returned 0 (cross-tree fid refs? see GbxFidRefSave.md)"; return false; }
        if (!IO::FileExists(full)) { err = "native call ok but file missing: " + full; return false; }
        return true;
    }
}
#endif
