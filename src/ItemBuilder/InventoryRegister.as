#if DEV
// Register User/Items files in the app-global collector catalog (no item editor needed) and,
// when a map editor is live, rebuild its Items tree so the new cards show up.
// research-priv/2026-08-24-InventoryAddItemAsCall.md (patterns, call chain, modes).
//
//   NGameItemUtils_AddOrRefreshItemModelArticle(model)          rcx only; editor-independent
//   CGameCtnEditorCommonInterface_RebuildArticleInventory(if, 3) rcx, edx; needs live map editor
//
// Each function is resolved by two independent anchors (semantic interior pattern + native
// call-site E8 decode) that must agree; otherwise the call is refused.
namespace ItemInventory {
    // NGameItemUtils_AddOrRefreshItemModelArticle: interior match at fn+0x0B
    const string AddPat = "83 BB F0 00 00 00 0B 0F 94 C1 E8 ?? ?? ?? ?? 48 8B 53 08 44 8B C8 4C 8B 05 ?? ?? ?? ?? 48 8B 0D ?? ?? ?? ?? C7 44 24 28 00 00 00 00 C7 44 24 20 03 00 00 00 E8";
    const uint AddPatOff = 0x0B;
    const string AddPrologue = "40 53 48 83 EC 40 48 8B D9 33 C9";
    // CGameEditorItem_AfterSave call site: E8 at +0x07
    const string AddCallerPat = "48 8B 8B F8 08 00 00 E8 ?? ?? ?? ?? 48 8B 83 F8 08 00 00 48 85 C0 74 ?? 48 8B 78 08";
    const uint AddCallerE8 = 0x07;

    // CGameCtnEditorCommonInterface_RebuildArticleInventory: interior match at fn+0x14
    const string RebuildPat = "C7 44 24 40 00 00 00 00 48 8B F1 48 8D 54 24 40 48 8B 49 40 49 8B D8 E8 ?? ?? ?? ?? 48 8B 46 40 4C 8B C3 8B D7 48 8B CE 4C 8B 88 98 04 00 00";
    const uint RebuildPatOff = 0x14;
    // CGameCtnEditorCommon_ProcessPendingItemEditRequest call site: E8 at +0x0E
    const string RebuildCallerPat = "48 8B 8E 20 06 00 00 45 33 C0 41 8D 50 03 E8 ?? ?? ?? ?? 48 85 DB 74 ?? 4C 8B AE 48 11 00 00 4C 8B C3 49 8B D5";
    const uint RebuildCallerE8 = 0x0E;

    const uint KindItems = 3;

    uint64 _addFn = 0, _rebuildFn = 0;

    uint64 DecodeCallTarget(uint64 e8At) {
        int rel = Dev::ReadInt32(e8At + 1);
        return e8At + 5 + uint64(int64(rel));
    }

    uint64 ResolveDual(const string &in name, const string &in pat, uint patOff, const string &in callerPat, uint callerE8, const string &in prologue, string &out err) {
        err = "";
        uint64 a = Dev_FindPatternCached(pat);
        if (a == 0) { err = name + ": interior pattern not found"; return 0; }
        uint64 c = Dev_FindPatternCached(callerPat);
        if (c == 0) { err = name + ": caller pattern not found"; return 0; }
        if (Dev::ReadUInt8(c + callerE8) != 0xE8) { err = name + ": caller anchor is not a CALL"; return 0; }
        uint64 fromPat = a - patOff;
        uint64 fromCall = DecodeCallTarget(c + callerE8);
        if (fromPat != fromCall) {
            err = name + ": anchors disagree " + Text::FormatPointer(fromPat) + " vs " + Text::FormatPointer(fromCall);
            return 0;
        }
        if (prologue.Length > 0 && !Hex::BytesMatch(fromPat, prologue)) { err = name + ": prologue mismatch at " + Text::FormatPointer(fromPat); return 0; }
        return fromPat;
    }

    uint64 AddFn(string &out err) {
        if (_addFn == 0) _addFn = ResolveDual("AddOrRefreshItemModelArticle", AddPat, AddPatOff, AddCallerPat, AddCallerE8, AddPrologue, err);
        return _addFn;
    }

    uint64 RebuildFn(string &out err) {
        if (_rebuildFn == 0) _rebuildFn = ResolveDual("RebuildArticleInventory", RebuildPat, RebuildPatOff, RebuildCallerPat, RebuildCallerE8, "", err);
        return _rebuildFn;
    }

    // Does the app catalog already hold an article for this fid?
    bool IsInCatalog(CSystemFidFile@ fid) {
        if (fid is null) return false;
        auto cat = GetApp().GlobalCatalog;
        if (cat is null) return false;
        for (uint c = 0; c < cat.Chapters.Length; c++) {
            auto ch = cat.Chapters[c];
            if (ch is null) continue;
            for (uint a = 0; a < ch.Articles.Length; a++) {
                if (ch.Articles[a] !is null && ch.Articles[a].CollectorFid is fid) return true;
            }
        }
        return false;
    }

    // Register one User item ("Items\\Foo.Item.Gbx"). Loads (cached) if needed. nMode 3 => refresh or add.
    bool RegisterItem(const string &in relPath, string &out err) {
        err = "";
        uint64 fn = AddFn(err);
        if (fn == 0) return false;
        err = AsCall::Ensure();
        if (err.Length > 0) return false;
        auto fid = Fids::GetUser(relPath.Replace("/", "\\"));
        if (fid is null) { err = "no fid: " + relPath; return false; }
        auto model = cast<CGameItemModel>(fid.Nod);
        if (model is null) @model = cast<CGameItemModel>(Fids::Preload(fid));
        if (model is null) { err = "not a loadable CGameItemModel: " + relPath; return false; }
        if (Dev::GetOffsetUint64(model, 0x8) == 0) { err = "model has no fid (+0x8): " + relPath; return false; }
        AsCall::Invoke(fn, Dev_GetPointerForNod(model), 0, 0, 0);
        if (!IsInCatalog(fid)) { err = "call returned but catalog has no article for " + relPath; return false; }
        return true;
    }

    // All .Item.Gbx under a User folder ("Items\\IB_Gen"). Returns "ok/total" summary; failures listed in err.
    string RegisterFolder(const string &in relFolder, string &out err) {
        err = "";
        string rel = relFolder.Replace("/", "\\");
        while (rel.EndsWith("\\")) rel = rel.SubStr(0, rel.Length - 1);
        Fids::UpdateTree(Fids::GetUserFolder("Items"));
        string root = IO::FromUserGameFolder(rel.Replace("\\", "/"));
        if (!IO::FolderExists(root)) { err = "folder missing: " + root; return "0/0"; }
        auto files = IO::IndexFolder(root, true);
        string userRoot = IO::FromUserGameFolder("").Replace("\\", "/");
        if (!userRoot.EndsWith("/")) userRoot += "/";
        uint ok = 0, total = 0;
        for (uint i = 0; i < files.Length; i++) {
            string f = files[i].Replace("\\", "/");
            if (!f.ToLower().EndsWith(".item.gbx")) continue;
            total++;
            if (f.StartsWith(userRoot)) f = f.SubStr(userRoot.Length);
            string e;
            if (RegisterItem(f.Replace("/", "\\"), e)) ok++;
            else err += e + "; ";
            if (i % 8 == 7) yield();
        }
        return ok + "/" + total;
    }

    bool InMapEditor() {
        return cast<CGameCtnEditorFree>(GetApp().Editor) !is null;
    }

    // Full Items-tree rebuild from the catalog (what the game does when the item editor exits).
    bool RebuildEditorItemsTree(string &out err) {
        err = "";
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) { err = "not in the map editor"; return false; }
        if (editor.EditorInterface is null) { err = "EditorInterface is null"; return false; }
        uint64 fn = RebuildFn(err);
        if (fn == 0) return false;
        err = AsCall::Ensure();
        if (err.Length > 0) return false;
        AsCall::Call2(fn, Dev_GetPointerForNod(editor.EditorInterface), KindItems);
        Editor::GetInventoryCache().RefreshCacheSoon();
        return true;
    }
}
#endif
