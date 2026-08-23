// Temporary TV-screen / apply-skin pipeline logger.
// Delete this folder (and the two Main.as call sites) to remove it.
//
// Patterns unique 2026-08-22: 1 Ghidra, 1 on-disk PE, 1 live Trackmania.exe .text.

namespace TvScreenLog {
    [Setting category="TvScreenLog" name="Enable hooks"]
    bool S_Enabled = true;

    [Setting category="TvScreenLog" name="Show window"]
    bool S_ShowWindow = true;

    [Setting category="TvScreenLog" name="Log ApplyBlockDisp (hot)"]
    bool S_LogApplyBlockDisp = true;

    const uint MAX_LOG = 200;
    const uint APPLY_DISP_MIN_MS = 125;

    string[] g_Log;
    uint g_Dropped;
    uint g_LastApplyDispMs;
    uint g_ApplyDispSeen;
    bool g_SetupDone;

    class Site {
        string name;
        string pattern;
        uint padding;
        string fn;
        HookHelper@ hook;

        Site(const string &in name, const string &in pattern, uint padding, const string &in fn) {
            this.name = name;
            this.pattern = pattern;
            this.padding = padding;
            this.fn = fn;
        }
    }

    Site@[] g_Sites;

    // NPlugSkinManialink_ApplySkinModelFromGameSkin @ 0x1405a50a0 (NOT TVScreen)
    const string Pat_ApplyManialinkSkinModel =
        "48 89 5C 24 18 55 56 57 41 54 41 55 41 56 41 57 48 8B EC 48 83 EC 60 48 8B F9 4D 8B F0 48 8B 49 20";

    // NPlugSkinnedModel_SMgr_CreateSkinInstance @ 0x1405aa640
    const string Pat_CreateSkinInstance =
        "48 89 5C 24 10 48 89 7C 24 18 55 41 54 41 55 41 56 41 57 48 8D 6C 24 D9 48 81 EC B0 00 00 00";

    // Skin.json TEST/JZ inside CreateSkinInstance @ 0x1405aa79e
    const string Pat_SkinJsonGate =
        "48 85 C0 0F 84 ?? ?? 00 00 48 8D 05 ?? ?? ?? ?? 4C 89 6D BF";

    const uint64 SMGR_GLOBAL = 0x141fa9ea8;
    uint64 g_SMgr;

    // ApplyBlockDispInMulInsideVideoSourceOverride @ 0x1405a9b90
    const string Pat_ApplyBlockDisp =
        "40 55 56 41 56 41 57 48 8D 6C 24 88 48 81 EC 78 01 00 00 48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 45 18";

    // CGameEditorPluginMap_SetItemSkin @ 0x140f99680
    const string Pat_SetItemSkin =
        "48 85 D2 0F 84 ?? ?? 00 00 48 89 5C 24 08 48 89 74 24 10 57 48 83 EC 40 48 8B 42 18";

    // native SetItemSkins write (AO+0x98/+0xA0) @ 0x14100e480
    const string Pat_SetItemSkinsNative =
        "48 89 5C 24 08 48 89 6C 24 10 48 89 74 24 18 48 89 7C 24 20 41 56 48 83 EC 20 41 8B E9 49 8B F0";

    // ResolveSkinNameOrUrlToPackDesc @ 0x140f99170
    const string Pat_ResolveSkinUrl =
        "40 55 53 56 57 41 56 48 8B EC 48 83 EC 60 48 8B 05 ?? ?? ?? ?? 48 33 C4 48 89 45 F0 41 83 78 08 00";

    // CGameEditorPluginMap_IsCollectorModelSkinnable @ 0x14100f610
    const string Pat_IsCollectorSkinnable =
        "48 83 EC 38 E8 ?? ?? ?? ?? 4C 8B 81 A0 04 00 00 4C 8B CA 48 8B D0 "
        "C7 44 24 20 01 00 00 00 33 C9 E8 ?? ?? ?? ?? 48 83 C4 38 C3";

    void OnPluginLoad() {
        if (g_SetupDone) return;
        g_SetupDone = true;
        g_Sites.InsertLast(Site("ApplyManialinkSkinModel", Pat_ApplyManialinkSkinModel, 0, "TvScreenLog::OnApplyManialinkSkinModel"));
        g_Sites.InsertLast(Site("ApplyBlockDispMulInside", Pat_ApplyBlockDisp, 0, "TvScreenLog::OnApplyBlockDisp"));
        g_Sites.InsertLast(Site("CreateSkinInstance", Pat_CreateSkinInstance, 0, "TvScreenLog::OnCreateSkinInstance"));
        // Do not hook 0x1405aa79e (TEST/JZ Skin.json). HookHelper replays the
        // stolen JZ from the cave; the relative disp then jumps into garbage and
        // CreateSkinInstance never returns (game freeze 2026-08-22).
        g_Sites.InsertLast(Site("SetItemSkin", Pat_SetItemSkin, 4, "TvScreenLog::OnSetItemSkin"));
        g_Sites.InsertLast(Site("SetItemSkinsNative", Pat_SetItemSkinsNative, 0, "TvScreenLog::OnSetItemSkinsNative"));
        g_Sites.InsertLast(Site("ResolveSkinUrl", Pat_ResolveSkinUrl, 2, "TvScreenLog::OnResolveSkinUrl"));
        // Do not hook IsCollectorModelSkinnable — same prologue as Editor::ForceCollectorSkinnable.
        for (uint i = 0; i < g_Sites.Length; i++) {
            @g_Sites[i].hook = HookHelper(g_Sites[i].pattern, 0, g_Sites[i].padding, g_Sites[i].fn, Dev::PushRegisters::SSE, true);
        }
        if (S_Enabled) ApplyAll();
        Add("TvScreenLog ready (" + g_Sites.Length + " sites)");
    }

    void ApplyAll() {
        for (uint i = 0; i < g_Sites.Length; i++) {
            if (g_Sites[i].hook is null) continue;
            if (g_Sites[i].hook.IsApplied()) continue;
            bool ok = g_Sites[i].hook.Apply();
            Add((ok ? "hooked " : "FAILED ") + g_Sites[i].name + " @ " + Text::FormatPointer(g_Sites[i].hook.PatternPtr));
        }
    }

    void UnapplyAll() {
        for (uint i = 0; i < g_Sites.Length; i++) {
            if (g_Sites[i].hook is null) continue;
            g_Sites[i].hook.Unapply();
        }
        Add("hooks off");
    }

    void Add(const string &in line) {
        string msg = "[" + Time::Now + "] " + line;
        g_Log.InsertLast(msg);
        if (g_Log.Length > MAX_LOG) {
            g_Log.RemoveRange(0, g_Log.Length - MAX_LOG);
            g_Dropped++;
        }
        trace("[TvScreenLog] " + line);
    }

    string NodLabel(uint64 ptr) {
        if (ptr == 0) return "null";
        if (Dev_PointerLooksBad(ptr)) return "bad:" + Text::FormatPointer(ptr);
        auto nod = Dev_GetNodFromPointer(ptr);
        if (nod is null) return Text::FormatPointer(ptr);
        string cls = Reflection::TypeOf(nod).Name;
        string extra = "";
        auto item = cast<CGameCtnAnchoredObject>(nod);
        if (item !is null) {
            extra = " " + string(item.ItemModel.IdName);
        }
        auto model = cast<CGameItemModel>(nod);
        if (model !is null) {
            extra = " " + string(model.IdName) + " author=" + string(model.Author.GetName());
        }
        auto skin = cast<CPlugGameSkin>(nod);
        if (skin !is null) {
            extra = " " + GameSkinShort(skin);
        }
        auto s2 = cast<CPlugSolid2Model>(nod);
        if (s2 !is null) {
            extra = " " + Solid2Short(s2);
        }
        auto pd = cast<CSystemPackDesc>(nod);
        if (pd !is null) {
            extra = " url=" + string(pd.Url) + " name=" + string(pd.Name);
        }
        return cls + extra + " " + Text::FormatPointer(ptr);
    }

    string GameSkinShort(CPlugGameSkin@ skin) {
        if (skin is null) return "GameSkin=null";
        uint nbFid = Dev::GetOffsetUint32(skin, 0x58 + 0x8);
        uint nbCls = Dev::GetOffsetUint32(skin, 0x78 + 0x8);
        uint nbBmp = 0;
        auto clsBuf = Dev::GetOffsetNod(skin, 0x78);
        uint n = nbCls;
        if (n > 32) n = 32;
        for (uint i = 0; i < n; i++) {
            if (Dev::GetOffsetUint32(clsBuf, 4 * i) == 0x9079000) nbBmp++;
        }
        return "path=" + Dev::GetOffsetString(skin, 0x18)
            + " fids=" + nbFid + " cls=" + nbCls + " bmp9079=" + nbBmp
            + " b0=" + Dev::GetOffsetUint32(skin, 0xB0);
    }

    string Solid2Short(CPlugSolid2Model@ s2) {
        if (s2 is null) return "s2=null";
        uint nbMat = Dev::GetOffsetUint32(s2, 0xC8 + 0x8);
        uint nbUser = Dev::GetOffsetUint32(s2, 0xF8 + 0x8);
        uint nbCust = Dev::GetOffsetUint32(s2, 0x1F8 + 0x8);
        return "mats=" + nbMat + " userInsts=" + nbUser + " customMats=" + nbCust;
    }

    string MatModShort(CPlugGameSkinAndFolder@ mm) {
        if (mm is null) return "null";
        string folder = "folder=null";
        if (mm.RemapFolder !is null) {
            folder = "folder=" + string(mm.RemapFolder.DirName) + " leaves=" + mm.RemapFolder.Leaves.Length;
        }
        return GameSkinShort(mm.Remapping) + " " + folder;
    }

    void OnApplyManialinkSkinModel(uint64 rcx, uint64 rdx, uint64 r8) {
        try {
            Add("ApplyManialinkSkinModel this=" + NodLabel(rcx) + " gameSkin=" + NodLabel(rdx) + " r8=" + Text::FormatPointer(r8));
        } catch {
            Add("ApplyManialinkSkinModel threw");
        }
    }

    void OnCreateSkinInstance(uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
        try {
            if (rcx != 0) g_SMgr = rcx;
            Add("CreateSkinInstance smgr=" + Text::FormatPointer(rcx)
                + " gameSkin=" + NodLabel(rdx)
                + " packs=" + Text::FormatPointer(r8)
                + " owner=" + NodLabel(r9));
        } catch {
            Add("CreateSkinInstance threw");
        }
    }

    void OnSkinJsonGate(uint64 rax, uint64 r14) {
        try {
            Add("Skin.json " + (rax == 0 ? "MISS → ClassicSkin" : "HIT")
                + " gameSkin=" + NodLabel(r14));
        } catch {
            Add("SkinJsonGate threw");
        }
    }

    void OnApplyBlockDisp(uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
        g_ApplyDispSeen++;
        if (!S_LogApplyBlockDisp) return;
        uint now = Time::Now;
        if (now - g_LastApplyDispMs < APPLY_DISP_MIN_MS) return;
        g_LastApplyDispMs = now;
        try {
            Add("ApplyBlockDisp mesh=" + NodLabel(rdx) + " rcx=" + Text::FormatPointer(rcx)
                + " r8=" + Text::FormatPointer(r8) + " seen=" + g_ApplyDispSeen);
        } catch {
            Add("ApplyBlockDisp threw");
        }
    }

    void OnSetItemSkin(uint64 rcx, uint64 rdx, uint64 r8) {
        try {
            Add("SetItemSkin item=" + NodLabel(rdx) + " r8=" + Text::FormatPointer(r8) + " pmt=" + Text::FormatPointer(rcx));
        } catch {
            Add("SetItemSkin threw");
        }
    }

    void OnSetItemSkinsNative(uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
        try {
            Add("SetItemSkinsNative ao=" + NodLabel(rdx) + " skins=" + Text::FormatPointer(r8) + " refresh=" + r9);
        } catch {
            Add("SetItemSkinsNative threw");
        }
    }

    void OnResolveSkinUrl(uint64 rcx, uint64 rdx, uint64 r8) {
        try {
            Add("ResolveSkinUrl collector=" + NodLabel(rdx) + " nameOrUrl=" + Text::FormatPointer(r8));
        } catch {
            Add("ResolveSkinUrl threw");
        }
    }

    void OnIsCollectorSkinnable(uint64 rcx, uint64 rdx) {
        try {
            Add("IsCollectorModelSkinnable model=" + NodLabel(rdx));
        } catch {
            Add("IsCollectorModelSkinnable threw");
        }
    }

    void DumpPlacedScreens() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Challenge is null) {
            Add("DumpPlacedScreens: not in map editor");
            return;
        }
        auto items = editor.Challenge.AnchoredObjects;
        uint n = 0;
        for (uint i = 0; i < items.Length; i++) {
            auto item = items[i];
            if (item is null || item.ItemModel is null) continue;
            string idn = string(item.ItemModel.IdName);
            string name = string(item.ItemModel.Name);
            if (!idn.ToLower().Contains("screen") && !name.ToLower().Contains("screen")) continue;
            n++;
            auto model = item.ItemModel;
            auto gs = cast<CPlugGameSkin>(Dev::GetOffsetNod(model, O_ITEM_MODEL_SKIN));
            auto bg = Editor::GetItemBGSkin(item);
            auto fg = Editor::GetItemFGSkin(item);
            Add("placed[" + i + "] " + idn + " name=" + name
                + " author=" + string(model.Author.GetName())
                + " cid=" + Dev::GetOffsetUint32(model, O_ITEM_MODEL_Id)
                + " aoBG=" + PackDescShort(bg) + " aoFG=" + PackDescShort(fg)
                + " matMod=" + MatModShort(model.MaterialModifier)
                + " gameSkin=" + GameSkinShort(gs));
        }
        Add("DumpPlacedScreens done (" + n + " screen-like)");
    }

    string PackDescShort(CSystemPackDesc@ pd) {
        if (pd is null) return "null";
        string url = string(pd.Url);
        string name = string(pd.Name);
        if (url.Length > 0) return url;
        if (name.Length > 0) return name;
        return Text::FormatPointer(Dev_GetPointerForNod(pd));
    }

    uint64 ResolveSMgr() {
        if (g_SMgr != 0 && !Dev_PointerLooksBad(g_SMgr)) return g_SMgr;
        uint64 p = 0;
        try { p = Dev::SafeReadUInt64(SMGR_GLOBAL); } catch { p = 0; }
        if (p != 0 && !Dev_PointerLooksBad(p)) g_SMgr = p;
        return g_SMgr;
    }

    string BindKind(uint64 bind) {
        if (bind == 0 || Dev_PointerLooksBad(bind)) return "none";
        uint64 fn8 = 0;
        uint64 fn18 = 0;
        uint id = 0;
        try {
            id = Dev::SafeReadUInt32(bind);
            fn8 = Dev::SafeReadUInt64(bind + 8);
            fn18 = Dev::SafeReadUInt64(bind + 0x18);
        } catch {
            return "bad:" + Text::FormatPointer(bind);
        }
        string kind = "id=" + Text::Format("0x%08x", id);
        if (id == 0x30205000 || fn8 == 0x1405a9b90 || fn18 == 0x1405a9b90) kind += " TVScreen";
        else if (id == 0x30207000 || fn8 == 0x1405a8260 || fn18 == 0x1405a8260) kind += " ClassicSkin";
        else if (id == 0x3020b000 || fn8 == 0x1405a50a0 || fn18 == 0x1405a50a0) kind += " Manialink";
        else if (id == 0x30209000) kind += " Parallax";
        else if (id == 0x30208000) kind += " MatRemap";
        else kind += " fn=" + Text::FormatPointer(fn8);
        return kind;
    }

    void DumpBoundSkins() {
        uint64 smgr = ResolveSMgr();
        if (smgr == 0) {
            Add("DumpBoundSkins: SMgr unknown (apply a skin or wait for vis)");
            return;
        }
        uint64 buf = 0;
        uint count = 0;
        try {
            buf = Dev::SafeReadUInt64(smgr + 0x70);
            count = Dev::SafeReadUInt32(smgr + 0x78);
        } catch {
            Add("DumpBoundSkins: failed reading AllSkins");
            return;
        }
        Add("AllSkins smgr=" + Text::FormatPointer(smgr) + " count=" + count);
        if (buf == 0 || Dev_PointerLooksBad(buf)) return;
        uint n = count;
        if (n > 64) n = 64;
        for (uint i = 0; i < n; i++) {
            uint64 sskin = 0;
            try { sskin = Dev::SafeReadUInt64(buf + 8 * i); } catch { continue; }
            if (sskin == 0 || Dev_PointerLooksBad(sskin)) continue;
            uint usage = 0;
            uint64 gs = 0, bg = 0, fg = 0, owner = 0, bind = 0;
            try {
                usage = Dev::SafeReadUInt32(sskin);
                gs = Dev::SafeReadUInt64(sskin + 8);
                bg = Dev::SafeReadUInt64(sskin + 0x10);
                fg = Dev::SafeReadUInt64(sskin + 0x18);
                owner = Dev::SafeReadUInt64(sskin + 0x20);
                bind = Dev::SafeReadUInt64(sskin + 0x38);
            } catch {
                continue;
            }
            Add("  [" + i + "] use=" + usage
                + " bind=" + BindKind(bind)
                + " gs=" + NodLabel(gs)
                + " bg=" + NodLabel(bg)
                + " fg=" + NodLabel(fg)
                + " owner=" + NodLabel(owner));
        }
    }

    bool Render() {
        if (!S_ShowWindow) return true;
        if (UI::Begin("TV-screen log", S_ShowWindow)) {
            bool en = UI::Checkbox("hooks on", S_Enabled);
            if (en != S_Enabled) {
                S_Enabled = en;
                if (en) ApplyAll();
                else UnapplyAll();
            }
            UI::SameLine();
            S_LogApplyBlockDisp = UI::Checkbox("log ApplyBlockDisp", S_LogApplyBlockDisp);
            UI::SameLine();
            if (UI::Button("Dump placed screens")) DumpPlacedScreens();
            UI::SameLine();
            if (UI::Button("Dump bound skins")) DumpBoundSkins();
            UI::SameLine();
            if (UI::Button("Clear")) {
                g_Log.RemoveRange(0, g_Log.Length);
                g_Dropped = 0;
            }
            UI::Text("ApplyBlockDisp seen: " + g_ApplyDispSeen + "  dropped: " + g_Dropped);
            for (uint i = 0; i < g_Sites.Length; i++) {
                auto@ s = g_Sites[i];
                uint64 p = s.hook is null ? 0 : s.hook.PatternPtr;
                string st = "missing";
                if (s.hook !is null && s.hook.IsApplied()) st = "on";
                else if (p != 0) st = "found";
                UI::Text(s.name + "  " + st + "  " + Text::FormatPointer(p));
            }
            UI::Separator();
            UI::BeginChild("tvslog", vec2(0, 0), false);
            if (g_Mono !is null) UI::PushFont(g_Mono);
            int start = 0;
            if (g_Log.Length > 80) start = int(g_Log.Length) - 80;
            for (uint i = start; i < g_Log.Length; i++) {
                UI::TextWrapped(g_Log[i]);
            }
            if (g_Mono !is null) UI::PopFont();
            UI::EndChild();
        }
        UI::End();
        return true;
    }
}
