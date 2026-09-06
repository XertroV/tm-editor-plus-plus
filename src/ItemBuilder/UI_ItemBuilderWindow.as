#if DEV
// Item Builder window (Plugins > Editor++ > Item Builder in the main menu).
//
// Workspace: nods loaded by path or from the Items browser (fresh copies by default), plus
//            components extracted from them (EntityModel, meshes, user materials) for borrowing.
// Build:     base slot + ordered ops (UV shift, set EntityModel / mesh / material from a slot) -> Save.
// Batch:     template item + ops whose numeric parameter sweeps a range; every combination is a
//            fresh copy of the template saved under a {i}/{v} pattern.
namespace ItemBuilderUI {
    [Setting hidden]
    bool S_ShowWindow = false;

    const string DefaultTemplate = "Items\\BF2_ASSETS\\BF2_Collectable_Droplets_Animated\\Starter_Dip_Animated_2j.Item.Gbx";
    const string DefaultTemplateCopy = "Items\\IB_Templates\\Starter_Dip_Animated_2j.Item.Gbx";

    // ---------------------------------------------------------------- workspace

    class Slot {
        string name;
        string path;      // user path the nod (or its parent item) came from
        string origin;    // "fresh" / "cached" / "component of <slot>"
        CMwNod@ nod;
        Slot(const string &in name, const string &in path, const string &in origin, CMwNod@ nod) {
            this.name = name; this.path = path; this.origin = origin;
            @this.nod = nod;
            if (nod !is null) nod.MwAddRef();
        }
        ~Slot() { if (nod !is null) nod.MwRelease(); }
        string TypeName() {
            if (nod is null) return "null";
            auto ty = Reflection::TypeOf(nod);
            return ty is null ? "?" : ty.Name;
        }
        string Label() { return name + "  \\$888" + TypeName() + "  \\$666" + origin; }
    }

    array<Slot@> slots;
    int selectedSlot = -1;
    string log;

    void Log(const string &in s) {
        log = "[" + Time::Stamp + "] " + s + "\n" + log;
        if (log.Length > 8000) log = log.SubStr(0, 8000);
        print("[ItemBuilderUI] " + s);
    }

    Slot@ AddSlot(const string &in name, const string &in path, const string &in origin, CMwNod@ nod) {
        if (nod is null) { Log("not added (null nod): " + name); return null; }
        auto s = Slot(name, path, origin, nod);
        slots.InsertLast(s);
        selectedSlot = int(slots.Length) - 1;
        return s;
    }

    void LoadIntoSlot(const string &in userPath, bool fresh) {
        string e;
        CMwNod@ nod = fresh ? ItemBuilder::LoadFreshNod(userPath, e) : cast<CMwNod>(ItemBuilder::LoadCached(userPath, e));
        if (nod is null) { Log("load failed: " + userPath + " " + e); return; }
        string name = userPath;
        int ix = name.LastIndexOf("\\");
        if (ix >= 0) name = name.SubStr(ix + 1);
        AddSlot(name, userPath, fresh ? "fresh" : "cached", nod);
        Log((fresh ? "loaded fresh " : "loaded cached ") + userPath);
    }

    Slot@ SlotAt(int i) { return i >= 0 && i < int(slots.Length) ? slots[i] : null; }

    // ---------------------------------------------------------------- item file list

    array<string> itemPaths;   // relative to User dir, "Items\..."
    string browseFilter = "";
    bool itemListLoaded = false;

    void RefreshItemList() {
        itemPaths.RemoveRange(0, itemPaths.Length);
        string root = IO::FromUserGameFolder("Items");
        auto files = IO::IndexFolder(root, true);
        string rootNorm = root.Replace("\\", "/");
        if (!rootNorm.EndsWith("/")) rootNorm += "/";
        for (uint i = 0; i < files.Length; i++) {
            string f = files[i].Replace("\\", "/");
            if (!f.ToLower().EndsWith(".item.gbx")) continue;
            if (f.StartsWith(rootNorm)) f = f.SubStr(rootNorm.Length);
            itemPaths.InsertLast("Items\\" + f.Replace("/", "\\"));
        }
        itemPaths.SortAsc();
        itemListLoaded = true;
    }

    // ---------------------------------------------------------------- ops

    enum OpKind { UvShift = 0, SetEntityModel = 1, SetMesh = 2, SetUserMaterial = 3, SetEntityModelEdition = 4, SetMaterialLink = 5, ReplaceVisual = 6, ReplaceVisualFromFiles = 7 }
    const array<string> OpKindNames = {"UV shift", "Set EntityModel (slot)", "Set mesh (slot)", "Set user material (slot)", "Set EntityModelEdition (slot)", "Set material link (list)", "Replace visual (slot)", "Replace visual (mesh files list)"};

    class Op {
        OpKind kind = OpKind::UvShift;
        // UvShift
        float du = 0.0, dv = 0.0;
        string filter = "";       // ItemBuilder::ParseVisualFilter syntax
        // slot-based
        int slot = -1;
        int matIdx = 0;
        // SetMaterialLink: user material [s2mIdx][matIdx] gets links[k] (batch sweeps the list)
        int s2mIdx = 0;
        int visIdx = 0;
        array<string> links;      // SetMaterialLink: material links; ReplaceVisualFromFiles: User paths of donor meshes
        string linksText;
        int donorS2m = 0, donorVis = 0;
        // batch range on du (axis 0) or dv (axis 1)
        bool ranged = false;
        int rangeAxis = 0;
        float rStart = -0.1, rEnd = 0.1, rStep = 0.01;
        bool skipZero = true;     // drop the value that would leave the template unchanged

        bool IsList() { return kind == OpKind::SetMaterialLink || kind == OpKind::ReplaceVisualFromFiles; }

        int RawRangeCount() {
            if (IsList()) return Math::Max(1, int(links.Length));
            if (!ranged || rStep <= 0) return 1;
            return int(Math::Floor((rEnd - rStart) / rStep + 1e-4)) + 1;
        }
        int ZeroIndex() {
            if (IsList() || !ranged || !skipZero || rStep <= 0) return -1;
            int k = int(Math::Round(-rStart / rStep));
            if (k < 0 || k >= RawRangeCount()) return -1;
            return Math::Abs(rStart + rStep * float(k)) < rStep * 1e-3 ? k : -1;
        }
        int RangeCount() { return RawRangeCount() - (ZeroIndex() >= 0 ? 1 : 0); }
        // k is the index into the (possibly zero-skipped) sequence
        float RangeValue(int k) {
            int z = ZeroIndex();
            if (z >= 0 && k >= z) k++;
            return rStart + rStep * float(k);
        }
        bool IsSweep() { return IsList() ? links.Length > 0 : ranged; }
        // Text used for {vN} in the output pattern.
        string RangeLabel(int k) {
            if (IsList()) {
                if (k < 0 || k >= int(links.Length)) return "";
                auto parts = links[k].Replace("/", "\\").Split("\\");
                if (kind == OpKind::ReplaceVisualFromFiles) {
                    string stem = parts[parts.Length - 1];
                    int dot = stem.IndexOf(".");
                    return dot > 0 ? stem.SubStr(0, dot) : stem;
                }
                return parts.Length >= 2 ? parts[parts.Length - 2] : parts[parts.Length - 1];
            }
            return FormatFloatForName(RangeValue(k), rStep, rStart, rEnd);
        }

        string Summary() {
            if (kind == OpKind::UvShift) {
                string s = "UV shift du=" + du + " dv=" + dv + (filter.Length > 0 ? " [" + filter + "]" : " [all]");
                if (ranged) s += " range " + (rangeAxis == 0 ? "du" : "dv") + " " + rStart + ".." + rEnd + " step " + rStep + (skipZero ? " skip0" : "") + " (" + RangeCount() + ")";
                return s;
            }
            if (kind == OpKind::SetMaterialLink) return "material link s" + s2mIdx + "[" + matIdx + "] <- " + links.Length + " links";
            if (kind == OpKind::ReplaceVisualFromFiles) return "visual s" + s2mIdx + "[" + visIdx + "] <- " + links.Length + " mesh files (donor s" + donorS2m + "[" + donorVis + "])";
            if (kind == OpKind::ReplaceVisual) return "visual s" + s2mIdx + "[" + visIdx + "] <- " + (slot >= 0 && slot < int(slots.Length) ? slots[slot].name : "<none>");
            string sl = slot >= 0 && slot < int(slots.Length) ? slots[slot].name : "<none>";
            if (kind == OpKind::SetUserMaterial) return "user material[" + matIdx + "] <- " + sl;
            return OpKindNames[int(kind)] + " <- " + sl;
        }

        // Apply to a builder; k = range index (ignored when not ranged).
        void Apply(ItemBuilder::Builder@ b, int k) {
            if (kind == OpKind::UvShift) {
                float u = du, v = dv;
                if (ranged) { if (rangeAxis == 0) u = RangeValue(k); else v = RangeValue(k); }
                b.UvShiftFiltered(u, v, ItemBuilder::ParseVisualFilter(filter));
                return;
            }
            if (kind == OpKind::SetMaterialLink) { ApplySetLink(b, k); return; }
            if (kind == OpKind::ReplaceVisualFromFiles) {
                if (k < 0 || k >= int(links.Length)) { b.err = "Replace visual: no donor #" + k; return; }
                b.ReplaceVisualFrom(uint(s2mIdx), uint(visIdx), links[k], uint(donorS2m), uint(donorVis), true);
                return;
            }
            if (kind == OpKind::ReplaceVisual) {
                auto ds = slot >= 0 && slot < int(slots.Length) ? slots[slot] : null;
                auto dv = ds is null ? null : cast<CPlugVisual>(ds.nod);
                if (dv is null) { b.err = "Replace visual: slot is not a CPlugVisual"; return; }
                b.ReplaceVisual(uint(s2mIdx), uint(visIdx), dv);
                return;
            }
            auto s = slot >= 0 && slot < int(slots.Length) ? slots[slot] : null;
            if (s is null || s.nod is null) { b.err = "op '" + Summary() + "': no slot"; return; }
            if (kind == OpKind::SetEntityModel) { b.SetEntityModel(s.nod); return; }
            if (kind == OpKind::SetEntityModelEdition) { SetNodField(b, b.model, O_ITEM_MODEL_EntityModelEdition, s.nod); return; }
            if (kind == OpKind::SetMesh) { ApplySetMesh(b, s.nod); return; }
            if (kind == OpKind::SetUserMaterial) { ApplySetUserMat(b, s.nod); return; }
        }

        void ApplySetLink(ItemBuilder::Builder@ b, int k) {
            if (k < 0 || k >= int(links.Length)) { b.err = "Set material link: no link #" + k; return; }
            array<CPlugSolid2Model@> models;
            ItemBuilder::CollectSolid2(b.model, models);
            if (s2mIdx < 0 || s2mIdx >= int(models.Length)) { b.err = "Set material link: no Solid2 #" + s2mIdx; return; }
            auto mat = ItemBuilder::UserMaterialAt(models[s2mIdx], uint(matIdx));
            if (mat is null) { b.err = "Set material link: no user material #" + matIdx + " on Solid2 #" + s2mIdx; return; }
            ItemBuilder::SetUserMaterialLink(mat, links[k]);
        }

        void ApplySetMesh(ItemBuilder::Builder@ b, CMwNod@ mesh) {
            if (cast<CPlugSolid2Model>(mesh) is null) { b.err = "Set mesh: slot is not a CPlugSolid2Model"; return; }
            auto owner = FindMeshOwner(b.model.EntityModel);
            if (owner is null) { b.err = "Set mesh: no CPlugStaticObjectModel / CPlugDynaObjectModel in EntityModel"; return; }
            uint16 off = cast<CPlugStaticObjectModel>(owner) !is null ? O_StaticObjMesh : O_DynaObjMesh;
            SetNodField(b, owner, off, mesh);
        }

        void ApplySetUserMat(ItemBuilder::Builder@ b, CMwNod@ mat) {
            if (cast<CPlugMaterialUserInst>(mat) is null) { b.err = "Set user material: slot is not a CPlugMaterialUserInst"; return; }
            array<CPlugSolid2Model@> models;
            ItemBuilder::CollectSolid2(b.model, models);
            if (models.Length == 0) { b.err = "Set user material: no Solid2"; return; }
            auto s2m = models[0];
            uint n = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_USERMAT_BUF + 8);
            if (uint(matIdx) >= n) { b.err = "Set user material: index " + matIdx + " >= " + n; return; }
            auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_USERMAT_BUF);
            SetNodField(b, buf, uint16(matIdx * 0x18), mat);
        }
    }

    uint16 O_StaticObjMesh = GetOffset("CPlugStaticObjectModel", "Mesh");
    uint16 O_DynaObjMesh = GetOffset("CPlugDynaObjectModel", "Mesh");

    // AddRef new, write pointer, release old.
    void SetNodField(ItemBuilder::Builder@ b, CMwNod@ owner, uint16 offset, CMwNod@ val) {
        if (owner is null) { b.err = "SetNodField: null owner"; return; }
        auto old = Dev::GetOffsetNod(owner, offset);
        if (old is val) return;
        val.MwAddRef();
        Dev::SetOffset(owner, offset, val);
        if (old !is null) old.MwRelease();
    }

    CMwNod@ FindMeshOwner(CMwNod@ nod) {
        if (nod is null) return null;
        if (cast<CPlugStaticObjectModel>(nod) !is null || cast<CPlugDynaObjectModel>(nod) !is null) return nod;
        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) {
            for (uint i = 0; i < prefab.Ents.Length; i++) {
                auto r = FindMeshOwner(prefab.Ents[i].Model);
                if (r !is null) return r;
            }
        }
        auto common = cast<CGameCommonItemEntityModel>(nod);
        if (common !is null) return FindMeshOwner(common.StaticObject);
        return null;
    }

    // ---------------------------------------------------------------- build state

    int buildBase = -1;
    string buildDest = "Items\\IB_Build\\Built.Item.Gbx";
    array<Op@> buildOps;

    // ---------------------------------------------------------------- batch state

    string batchTemplate = DefaultTemplate;
    string batchTemplateCopy = DefaultTemplateCopy;
    string batchPattern = "Items\\IB_Gen\\StarterDip_{i}.Item.Gbx";
    array<Op@> batchOps;
    bool batchRunning = false;
    int batchDone = 0, batchTotal = 0;
    bool batchCancel = false;
    bool batchRegister = true;   // register each saved variant in the app catalog
    array<string> batchSaved;

    void InitBatchDefaults() {
        if (batchOps.Length > 0) return;
        Op@ o = Op();
        o.kind = OpKind::UvShift;
        o.ranged = true; o.rangeAxis = 0; o.rStart = -0.1; o.rEnd = 0.1; o.rStep = 0.01;
        batchOps.InsertLast(o);
    }

    int BatchCombinations() {
        int n = 1;
        for (uint i = 0; i < batchOps.Length; i++) n *= batchOps[i].RangeCount();
        return n;
    }

    // Fixed-width so names sort numerically: decimals from the step, integer part padded to the
    // widest endpoint. -0.5 with step 0.02 -> "m0_50"; 12.5 with step 0.5 in 0..100 -> "p012_5".
    string FormatFloatForName(float v, float step = 0.001, float lo = 0, float hi = 0) {
        int dec = step > 0 ? int(Math::Ceil(-Math::Log10(step) - 1e-6)) : 3;
        dec = Math::Clamp(dec, 0, 4);
        int intDigits = tostring(int(Math::Floor(Math::Max(Math::Abs(lo), Math::Abs(hi))))).Length;
        string body = Text::Format("%0" + (intDigits + (dec > 0 ? dec + 1 : 0)) + "." + dec + "f", Math::Abs(v));
        return (v < 0 ? "m" : "p") + body.Replace(".", "_");
    }

    string PadIndex(int i, int total) {
        string s = tostring(i);
        int w = tostring(Math::Max(1, total)).Length;
        while (int(s.Length) < w) s = "0" + s;
        return s;
    }

    void RunBatch() {
        batchRunning = true; batchCancel = false;
        batchDone = 0; batchTotal = BatchCombinations();
        Log("batch: " + batchTotal + " variants from " + batchTemplate);
        batchSaved.RemoveRange(0, batchSaved.Length);
        array<int> idx(batchOps.Length, 0);
        for (int i = 0; i < batchTotal && !batchCancel; i++) {
            // decode mixed-radix index
            int rem = i;
            string dest = batchPattern.Replace("{i}", PadIndex(i + 1, batchTotal));
            for (uint o = 0; o < batchOps.Length; o++) {
                int c = batchOps[o].RangeCount();
                idx[o] = rem % c; rem /= c;
                if (batchOps[o].IsSweep()) dest = dest.Replace("{v" + o + "}", batchOps[o].RangeLabel(idx[o]));
            }
            auto b = ItemBuilder::Builder(dest).FromFresh(batchTemplate);
            for (uint o = 0; o < batchOps.Length; o++) batchOps[o].Apply(b, idx[o]);
            auto r = b.Save();
            Log((r.ok ? "OK " : "FAIL ") + dest + (r.ok ? "" : " " + r.err));
            if (r.ok) batchSaved.InsertLast(dest);
            batchDone = i + 1;
            yield();
        }
        batchRunning = false;
        Log("batch " + (batchCancel ? "cancelled" : "done") + ": " + batchDone + "/" + batchTotal);
        if (batchRegister && batchSaved.Length > 0) RegisterPaths(batchSaved);
    }

    // ---------------------------------------------------------------- inventory

    string invFolder = "Items\\IB_Gen";
    bool invBusy = false;

    void RegisterPaths(array<string>@ paths) {
        Fids::UpdateTree(Fids::GetUserFolder("Items"));
        uint ok = 0;
        for (uint i = 0; i < paths.Length; i++) {
            string e;
            if (ItemInventory::RegisterItem(paths[i], e)) ok++;
            else Log("register FAIL " + paths[i] + ": " + e);
            if (i % 8 == 7) yield();
        }
        Log("registered " + ok + "/" + paths.Length + " in catalog" + (ItemInventory::InMapEditor() ? "" : " (visible on next map-editor entry)"));
        if (ok > 0 && ItemInventory::InMapEditor()) {
            string e;
            Log(ItemInventory::RebuildEditorItemsTree(e) ? "editor Items tree rebuilt" : "rebuild FAIL " + e);
        }
    }

    void RegisterFolderCoro() {
        invBusy = true;
        string e;
        string res = ItemInventory::RegisterFolder(invFolder, e);
        Log("register folder " + invFolder + ": " + res + (e.Length > 0 ? " errors: " + e : ""));
        invBusy = false;
    }

    void DrawInventory() {
        UI::TextWrapped("Registers .Item.Gbx files in the game's collector catalog without the item editor. Outside the map editor the items appear under Items > Custom on the next editor entry; inside it, rebuild the tree.");
        UI::Separator();
        invFolder = UI::InputText("Folder (User dir)", invFolder);
        UI::BeginDisabled(invBusy);
        if (UI::Button(Icons::Database + " Register folder in catalog")) startnew(RegisterFolderCoro);
        UI::EndDisabled();
        UI::SameLine();
        batchRegister = UI::Checkbox("Auto-register after Batch / Build (and rebuild the tree when in the editor)", batchRegister);
        UI::Separator();
        bool inEd = ItemInventory::InMapEditor();
        UI::Text(inEd ? "\\$8f8Map editor is open" : "\\$f80Not in the map editor");
        UI::BeginDisabled(!inEd);
        if (UI::Button(Icons::Refresh + " Rebuild editor Items tree (kind 3)")) {
            string e;
            Log(ItemInventory::RebuildEditorItemsTree(e) ? "Items tree rebuilt" : "rebuild FAIL " + e);
        }
        UI::EndDisabled();
        UI::SameLine(); UI::TextDisabled("(?)");
        if (UI::IsItemHovered()) UI::SetTooltip("Same call the game makes when the item editor exits. Recreates Official/Club/Custom from the catalog; Custom order may change.");
        UI::Separator();
        string e1, e2;
        uint64 a = ItemInventory::AddFn(e1), r = ItemInventory::RebuildFn(e2);
        UI::Text("\\$888AddOrRefreshItemModelArticle: " + (a != 0 ? Text::FormatPointer(a) : "\\$f44" + e1));
        UI::Text("\\$888RebuildArticleInventory: " + (r != 0 ? Text::FormatPointer(r) : "\\$f44" + e2));
    }

    // ---------------------------------------------------------------- place (map editor)

    enum PlaceLayout { Row = 0, Grid = 1, RowsByPrefix = 2 }
    const array<string> PlaceLayoutNames = {"Single row", "Grid (N columns)", "One row per name prefix (before last _)"};
    string PlaceLayoutName(int v) { return v >= 0 && v < int(PlaceLayoutNames.Length) ? PlaceLayoutNames[v] : "?"; }

    string placeFolder = "IB_ModFX\\SpecialFX";   // relative to Items, as in the inventory cache
    PlaceLayout placeLayout = PlaceLayout::RowsByPrefix;
    int placeColumns = 10;
    vec3 placeOrigin = vec3(96, 24, 96);
    vec2 placeSpacing = vec2(8, 8);            // x = along a row, y = between rows
    float placeYaw = 0;
    bool placeBusy = false;
    array<string> placeMatches;
    string placeMatchedFolder = "";

    void RefreshPlaceMatches() {
        placeMatches.RemoveRange(0, placeMatches.Length);
        auto inv = Editor::GetInventoryCache();
        string pre = ItemBuilder::NormPath(placeFolder).ToLower();
        if (pre.StartsWith("items\\")) pre = pre.SubStr(6);
        if (pre.Length > 0 && !pre.EndsWith("\\")) pre += "\\";
        for (uint i = 0; i < inv.ItemPaths.Length; i++) {
            if (inv.ItemPaths[i].ToLower().StartsWith(pre)) placeMatches.InsertLast(inv.ItemPaths[i]);
        }
        placeMatches.SortAsc();
        placeMatchedFolder = placeFolder;
    }

    string PrefixOf(const string &in path) {
        string name = path;
        int ix = name.LastIndexOf("\\");
        if (ix >= 0) name = name.SubStr(ix + 1);
        if (name.ToLower().EndsWith(".item.gbx")) name = name.SubStr(0, name.Length - 9);
        // strip trailing numeric tokens: "Boost2_m0_02" -> "Boost2", "StarterDip_07" -> "StarterDip"
        while (true) {
            int us = name.LastIndexOf("_");
            if (us <= 0) break;
            string tail = name.SubStr(us + 1);
            if (tail.Length == 0) break;
            uint start = (tail[0] == 0x6D || tail[0] == 0x70) ? 1 : 0; // m / p sign
            bool numeric = tail.Length > start;
            for (uint i = start; i < tail.Length; i++) if (tail[i] < 0x30 || tail[i] > 0x39) { numeric = false; break; }
            if (!numeric) break;
            name = name.SubStr(0, us);
        }
        return name;
    }

    // Row/column for item #k under the chosen layout.
    void PlaceCell(uint k, int &out row, int &out col) {
        if (placeLayout == PlaceLayout::Row) { row = 0; col = int(k); return; }
        if (placeLayout == PlaceLayout::Grid) { int c = Math::Max(1, placeColumns); row = int(k) / c; col = int(k) % c; return; }
        // RowsByPrefix: matches are sorted, so equal prefixes are contiguous
        row = 0; col = 0;
        string cur = PrefixOf(placeMatches[0]);
        for (uint i = 1; i <= k; i++) {
            string p = PrefixOf(placeMatches[i]);
            if (p != cur) { row++; col = 0; cur = p; } else col++;
        }
    }

    void PlaceCoro() {
        placeBusy = true;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) { Log("place: not in the map editor"); placeBusy = false; return; }
        Editor::ItemSpec@[] specs;
        uint missing = 0;
        for (uint k = 0; k < placeMatches.Length; k++) {
            auto model = Editor::GetInventoryItemModelByPath(placeMatches[k]);
            if (model is null) { missing++; continue; }
            int row, col;
            PlaceCell(k, row, col);
            vec3 pos = placeOrigin + vec3(placeSpacing.x * float(col), 0, placeSpacing.y * float(row));
            specs.InsertLast(Editor::ItemSpecPriv(model, pos, vec3(0, Math::ToRad(placeYaw), 0)));
        }
        Log("place: " + specs.Length + " items (" + missing + " not loadable from inventory)");
        const uint CHUNK = 50;
        uint placed = 0;
        for (uint i = 0; i < specs.Length; i += CHUNK) {
            Editor::ItemSpec@[] batch;
            uint end = Math::Min(i + CHUNK, specs.Length);
            for (uint j = i; j < end; j++) batch.InsertLast(specs[j]);
            bool ok = false;
            try { ok = Editor::PlaceItems(batch, true); } catch { Log("place EXC: " + getExceptionInfo()); break; }
            if (!ok) { Log("place: chunk at " + i + " failed"); break; }
            placed += batch.Length;
            yield();
        }
        Log("placed " + placed + "/" + specs.Length);
        placeBusy = false;
    }

    void DrawPlace() {
        bool inEd = ItemInventory::InMapEditor();
        if (!inEd) UI::Text("\\$f80Open the map editor to place items.");
        UI::TextWrapped("Places every inventory item under a folder in a regular layout so a batch can be compared side by side.");
        placeFolder = UI::InputText("Folder (under Items)", placeFolder);
        if (UI::Button(Icons::Search + " Find items") || (placeMatchedFolder != placeFolder && inEd)) RefreshPlaceMatches();
        UI::SameLine();
        UI::Text("" + placeMatches.Length + " items" + (placeMatches.Length > 0 ? "  \\$888first: " + placeMatches[0] : ""));
        placeLayout = PlaceLayout(DrawArbitraryEnum("Layout", int(placeLayout), PlaceLayoutNames.Length, PlaceLayoutName));
        if (placeLayout == PlaceLayout::Grid) placeColumns = UI::InputInt("Columns", placeColumns);
        placeOrigin = UI::InputFloat3("Origin (world pos)", placeOrigin);
        UI::SameLine();
        UI::BeginDisabled(!inEd);
        if (UI::Button("From cursor")) placeOrigin = Editor::GetCursorPos(cast<CGameCtnEditorFree>(GetApp().Editor));
        UI::EndDisabled();
        placeSpacing = UI::InputFloat2("Spacing (along row, between rows)", placeSpacing);
        placeYaw = UI::InputFloat("Yaw (deg)", placeYaw);
        if (placeLayout == PlaceLayout::RowsByPrefix && placeMatches.Length > 0) {
            int rows = 0, cols = 0; PlaceCell(placeMatches.Length - 1, rows, cols);
            UI::Text("\\$888" + (rows + 1) + " rows");
        }
        UI::BeginDisabled(!inEd || placeBusy || placeMatches.Length == 0);
        if (UI::Button(Icons::Cubes + " Place " + placeMatches.Length + " items")) startnew(PlaceCoro);
        UI::EndDisabled();
        UI::SameLine(); UI::TextDisabled("(?)");
        if (UI::IsItemHovered()) UI::SetTooltip("Adds one undo point per 50 items. Ctrl+Z removes them.");
    }

    // ---------------------------------------------------------------- render

    void DrawMenuItem() {
        if (UI::MenuItem(Icons::Cubes + " Item Builder", "", S_ShowWindow)) S_ShowWindow = !S_ShowWindow;
    }

    void Render() {
        if (!S_ShowWindow) return;
        InitBatchDefaults();
        UI::SetNextWindowSize(900, 700, UI::Cond::FirstUseEver);
        if (UI::Begin(Icons::Cubes + " Item Builder###ItemBuilderWin", S_ShowWindow)) {
            UI::BeginTabBar("ib-tabs");
            if (UI::BeginTabItem("Workspace")) { DrawWorkspace(); UI::EndTabItem(); }
            if (UI::BeginTabItem("Build")) { DrawBuild(); UI::EndTabItem(); }
            if (UI::BeginTabItem("Batch / Template")) { DrawBatch(); UI::EndTabItem(); }
            if (UI::BeginTabItem("Inventory")) { DrawInventory(); UI::EndTabItem(); }
            if (UI::BeginTabItem("Place")) { DrawPlace(); UI::EndTabItem(); }
            if (UI::BeginTabItem("Log")) { DrawLog(); UI::EndTabItem(); }
            UI::EndTabBar();
        }
        UI::End();
    }

    string loadPath = "Items\\BF2_Crown.Item.Gbx";

    void DrawWorkspace() {
        UI::Columns(2, "ib-ws", true);
        // ---- left: loaders
        UI::Text("\\$bbbLoad by path (relative to User dir)");
        UI::SetNextItemWidth(UI::GetContentRegionAvail().x);
        loadPath = UI::InputText("##ib-loadpath", loadPath);
        if (UI::Button("Load fresh")) LoadIntoSlot(loadPath, true);
        UI::SameLine();
        if (UI::Button("Load cached")) LoadIntoSlot(loadPath, false);
        UI::SameLine();
        UI::TextDisabled("(?)");
        if (UI::IsItemHovered()) UI::SetTooltip("Fresh: independent copy read from disk (safe to mutate).\nCached: the game's own nod (mutations affect it).");

        UI::Separator();
        UI::Text("\\$bbbBrowse Items folder");
        if (UI::Button(Icons::Refresh + " Refresh list")) RefreshItemList();
        UI::SameLine();
        UI::SetNextItemWidth(UI::GetContentRegionAvail().x);
        browseFilter = UI::InputText("##ib-filter", browseFilter);
        if (!itemListLoaded) RefreshItemList();
        UI::BeginChild("ib-files", vec2(0, 260), true);
        string fl = browseFilter.ToLower();
        uint shown = 0;
        for (uint i = 0; i < itemPaths.Length && shown < 400; i++) {
            if (fl.Length > 0 && !itemPaths[i].ToLower().Contains(fl)) continue;
            shown++;
            UI::PushID(int(i));
            if (UI::Button("fresh")) LoadIntoSlot(itemPaths[i], true);
            UI::SameLine();
            if (UI::Button("cached")) LoadIntoSlot(itemPaths[i], false);
            UI::SameLine();
            if (UI::Selectable(itemPaths[i].SubStr(6), false)) loadPath = itemPaths[i];
            UI::PopID();
        }
        UI::EndChild();
        UI::Text("\\$888" + itemPaths.Length + " items");

        UI::Separator();
        UI::Text("\\$bbbSlots");
        UI::BeginChild("ib-slots", vec2(0, 0), true);
        for (uint i = 0; i < slots.Length; i++) {
            UI::PushID(int(i));
            if (UI::Selectable(i + ". " + slots[i].Label(), int(i) == selectedSlot)) selectedSlot = int(i);
            UI::PopID();
        }
        UI::EndChild();

        UI::NextColumn();
        // ---- right: selected slot
        auto s = SlotAt(selectedSlot);
        if (s is null) {
            UI::Text("\\$888Select a slot.");
        } else {
            UI::Text(s.name + "  \\$888" + s.TypeName());
            UI::Text("\\$888" + s.path + "  " + s.origin);
            if (UI::Button(Icons::Search + " Explore nod")) ExploreNod(s.name, s.nod);
            UI::SameLine();
            if (UI::Button(Icons::Trash + " Remove slot")) {
                slots.RemoveAt(selectedSlot);
                selectedSlot = Math::Min(selectedSlot, int(slots.Length) - 1);
                UI::Columns(1);
                return;
            }
            auto model = cast<CGameItemModel>(s.nod);
            if (model !is null) {
                UI::SameLine();
                if (UI::Button("Use as build base")) buildBase = selectedSlot;
                UI::SameLine();
                if (UI::Button("Use as template")) batchTemplate = s.path;
            }
            UI::Separator();
            UI::Text("\\$bbbComponents (click to borrow into a slot)");
            UI::BeginChild("ib-comps", vec2(0, 0), true);
            DrawComponents(s);
            UI::EndChild();
        }
        UI::Columns(1);
    }

    void BorrowBtn(Slot@ from, const string &in compName, CMwNod@ comp) {
        if (comp is null) { UI::Text("\\$666" + compName + ": null"); return; }
        auto ty = Reflection::TypeOf(comp);
        UI::PushID(compName);
        if (UI::Button("Borrow")) AddSlot(from.name + " > " + compName, from.path, "component of " + from.name, comp);
        UI::SameLine();
        if (UI::Button(Icons::Search)) ExploreNod(compName, comp);
        UI::SameLine();
        UI::Text(compName + "  \\$888" + (ty is null ? "?" : ty.Name));
        UI::PopID();
    }

    void DrawComponents(Slot@ s) {
        auto model = cast<CGameItemModel>(s.nod);
        if (model !is null) {
            BorrowBtn(s, "EntityModel", model.EntityModel);
            BorrowBtn(s, "EntityModelEdition", model.EntityModelEdition);
            BorrowBtn(s, "DefaultPlacement", model.DefaultPlacementParam_Content);
        }
        auto prefab = cast<CPlugPrefab>(s.nod);
        if (prefab is null && model !is null) @prefab = cast<CPlugPrefab>(model.EntityModel);
        if (prefab !is null) {
            for (uint i = 0; i < prefab.Ents.Length; i++) BorrowBtn(s, "Ents[" + i + "].Model", prefab.Ents[i].Model);
        }
        array<CPlugSolid2Model@> models;
        ItemBuilder::CollectSolid2(s.nod, models);
        for (uint m = 0; m < models.Length; m++) {
            UI::PushID(int(m));
            BorrowBtn(s, "Solid2[" + m + "]", models[m]);
            UI::Indent();
            uint nUser = Dev::GetOffsetUint32(models[m], O_SOLID2MODEL_USERMAT_BUF + 8);
            auto ubuf = Dev::GetOffsetNod(models[m], O_SOLID2MODEL_USERMAT_BUF);
            for (uint i = 0; i < nUser && ubuf !is null; i++) {
                auto mat = Dev::GetOffsetNod(ubuf, i * 0x18);
                BorrowBtn(s, "UserMat[" + i + "] " + ItemBuilder::MaterialName(models[m], int(i)), mat);
            }
            auto vis = ItemBuilder::Solid2Visuals(models[m]);
            for (uint v = 0; v < vis.Length; v++) {
                int mi = ItemBuilder::MaterialIndexOfVisual(models[m], v);
                BorrowBtn(s, "Visual[" + v + "] -> mat " + mi + " " + ItemBuilder::MaterialName(models[m], mi), vis[v]);
            }
            UI::Unindent();
            UI::PopID();
        }
    }

    // Every *.Mesh.Gbx / *.Item.Gbx under a User folder ("Items\\Icons"), sorted, as User-relative paths.
    array<string> MeshFilesUnder(const string &in relFolder) {
        array<string> ret;
        string rel = ItemBuilder::NormPath(relFolder);
        string root = IO::FromUserGameFolder(rel.Replace("\\", "/"));
        if (!IO::FolderExists(root)) return ret;
        string userRoot = IO::FromUserGameFolder("").Replace("\\", "/");
        if (!userRoot.EndsWith("/")) userRoot += "/";
        auto files = IO::IndexFolder(root, true);
        for (uint i = 0; i < files.Length; i++) {
            string f = files[i].Replace("\\", "/");
            string fl = f.ToLower();
            if (!fl.EndsWith(".mesh.gbx") && !fl.EndsWith(".item.gbx")) continue;
            if (f.StartsWith(userRoot)) f = f.SubStr(userRoot.Length);
            ret.InsertLast(f.Replace("/", "\\"));
        }
        ret.SortAsc();
        return ret;
    }

    string OpKindName(int v) { return v >= 0 && v < int(OpKindNames.Length) ? OpKindNames[v] : "?"; }

    void DrawOpEditor(Op@ op, bool allowRange) {
        op.kind = OpKind(DrawArbitraryEnum("Kind", int(op.kind), OpKindNames.Length, OpKindName));
        if (op.kind == OpKind::UvShift) {
            op.du = UI::InputFloat("du", op.du, 0.01);
            op.dv = UI::InputFloat("dv", op.dv, 0.01);
            op.filter = UI::InputText("filter", op.filter);
            UI::SameLine(); UI::TextDisabled("(?)");
            if (UI::IsItemHovered()) UI::SetTooltip("empty = all visuals; 2 = material index; v2 = visual index; text = material-name substring");
            if (allowRange) {
                op.ranged = UI::Checkbox("Sweep a range", op.ranged);
                if (op.ranged) {
                    op.rangeAxis = UI::SliderInt("axis (0=du, 1=dv)", op.rangeAxis, 0, 1);
                    op.rStart = UI::InputFloat("start", op.rStart, 0.01);
                    op.rEnd = UI::InputFloat("end", op.rEnd, 0.01);
                    op.rStep = UI::InputFloat("step", op.rStep, 0.001);
                    op.skipZero = UI::Checkbox("Skip zero (no-op variant)", op.skipZero);
                    UI::Text("\\$888" + op.RangeCount() + " values");
                }
            }
        } else if (op.kind == OpKind::ReplaceVisual) {
            op.s2mIdx = UI::InputInt("Solid2 index", op.s2mIdx);
            op.visIdx = UI::InputInt("visual index", op.visIdx);
            op.slot = DrawSlotCombo("donor visual (slot)", op.slot);
            UI::TextWrapped("\\$888Borrow a visual from any loaded mesh/item in Workspace > Components. The slot keeps its material; the donor needs Position/Normal/TexCoord0 (and TexCoord1 if lightmapped).");
        } else if (op.kind == OpKind::ReplaceVisualFromFiles) {
            op.s2mIdx = UI::InputInt("Solid2 index", op.s2mIdx);
            op.visIdx = UI::InputInt("visual index", op.visIdx);
            op.donorS2m = UI::InputInt("donor Solid2 index", op.donorS2m);
            op.donorVis = UI::InputInt("donor visual index", op.donorVis);
            op.linksText = UI::InputText("mesh folder (User dir) or paths", op.linksText);
            UI::SameLine();
            if (UI::Button("Scan folder")) op.links = MeshFilesUnder(op.linksText);
            UI::Text("\\$888" + op.links.Length + " donor files; batch sweeps them ({vN} = file stem)");
        } else if (op.kind == OpKind::SetMaterialLink) {
            op.s2mIdx = UI::InputInt("Solid2 index", op.s2mIdx);
            op.matIdx = UI::InputInt("user material index", op.matIdx);
            bool changed;
            op.linksText = UI::InputTextMultiline("links (one per line)", op.linksText, changed, vec2(0, 120));
            if (changed) { op.links = op.linksText.Split("\n"); for (int i = int(op.links.Length) - 1; i >= 0; i--) { op.links[i] = op.links[i].Trim(); if (op.links[i].Length == 0) op.links.RemoveAt(i); } }
            UI::Text("\\$888" + op.links.Length + " links; batch sweeps them ({vN} = modifier folder name)");
        } else {
            op.slot = DrawSlotCombo("slot", op.slot);
            if (op.kind == OpKind::SetUserMaterial) op.matIdx = UI::InputInt("material index", op.matIdx);
        }
    }

    int DrawSlotCombo(const string &in label, int cur) {
        string curName = cur >= 0 && cur < int(slots.Length) ? cur + ". " + slots[cur].name : "<none>";
        if (UI::BeginCombo(label, curName)) {
            for (uint i = 0; i < slots.Length; i++) {
                if (UI::Selectable(i + ". " + slots[i].Label(), int(i) == cur)) cur = int(i);
            }
            UI::EndCombo();
        }
        return cur;
    }

    void DrawOpsList(array<Op@>@ ops, bool allowRange) {
        for (uint i = 0; i < ops.Length; i++) {
            UI::PushID(int(i));
            bool open = UI::TreeNode(i + ". " + ops[i].Summary() + "###op" + i);
            UI::SameLine();
            if (UI::Button(Icons::Trash)) { ops.RemoveAt(i); i--; if (open) UI::TreePop(); UI::PopID(); continue; }
            if (i > 0) { UI::SameLine(); if (UI::Button(Icons::ArrowUp)) { auto t = ops[i]; @ops[i] = ops[i - 1]; @ops[i - 1] = t; } }
            if (open) { DrawOpEditor(ops[i], allowRange); UI::TreePop(); }
            UI::PopID();
        }
        if (UI::Button(Icons::Plus + " Add op")) ops.InsertLast(Op());
    }

    void DrawBuild() {
        buildBase = DrawSlotCombo("Base model (slot)", buildBase);
        UI::SameLine(); UI::TextDisabled("(?)");
        if (UI::IsItemHovered()) UI::SetTooltip("Load the base as a fresh copy in Workspace so the game's cached item stays untouched.");
        buildDest = UI::InputText("Destination", buildDest);
        UI::Separator();
        UI::Text("\\$bbbOperations (applied in order)");
        DrawOpsList(buildOps, false);
        UI::Separator();
        auto base = SlotAt(buildBase);
        bool canSave = base !is null && cast<CGameItemModel>(base.nod) !is null;
        UI::BeginDisabled(!canSave);
        if (UI::Button(Icons::FloppyO + " Build & Save")) {
            auto b = ItemBuilder::Builder(buildDest).FromModel(cast<CGameItemModel>(base.nod));
            for (uint i = 0; i < buildOps.Length; i++) buildOps[i].Apply(b, 0);
            auto r = b.Save();
            Log((r.ok ? "built OK " : "build FAIL ") + buildDest + (r.ok ? "" : " " + r.err));
            if (r.ok) startnew(CoroutineFuncUserdataString(VerifyReload), buildDest);
            if (r.ok && batchRegister) { array<string> one = {buildDest}; RegisterPaths(one); }
        }
        UI::EndDisabled();
        if (!canSave) UI::Text("\\$f80Pick a CGameItemModel slot as base.");
    }

    void VerifyReload(const string &in path) {
        string e;
        auto m = ItemBuilder::LoadFresh(path, e);
        if (m is null) { Log("reload FAIL " + path + " " + e); return; }
        Log("reload OK " + path + " " + ItemBuilder::Describe(m));
        AddSlot("reloaded " + path.SubStr(path.LastIndexOf("\\") + 1), path, "fresh", m);
    }

    void DrawBatch() {
        UI::Text("\\$bbbTemplate");
        batchTemplate = UI::InputText("Template item", batchTemplate);
        batchTemplateCopy = UI::InputText("Copy template to", batchTemplateCopy);
        if (UI::Button("Save template copy")) {
            auto r = ItemBuilder::Builder(batchTemplateCopy).FromFresh(batchTemplate).Save();
            Log((r.ok ? "template copy OK " : "template copy FAIL ") + batchTemplateCopy + (r.ok ? "" : " " + r.err));
            if (r.ok) { batchTemplate = batchTemplateCopy; itemListLoaded = false; }
        }
        UI::SameLine();
        if (UI::Button("Load template into workspace")) LoadIntoSlot(batchTemplate, true);
        UI::Separator();
        batchPattern = UI::InputText("Output pattern", batchPattern);
        UI::SameLine(); UI::TextDisabled("(?)");
        if (UI::IsItemHovered()) UI::SetTooltip("{i} = 1-based index; {v0}, {v1}, ... = value of ranged op N (e.g. m0_05 for -0.05)");
        UI::Separator();
        UI::Text("\\$bbbOperations (each ranged op multiplies the variant count)");
        DrawOpsList(batchOps, true);
        UI::Separator();
        int total = BatchCombinations();
        UI::Text("Variants: " + total);
        if (batchRunning) {
            UI::ProgressBar(float(batchDone) / float(Math::Max(1, batchTotal)), vec2(-1, 0), batchDone + " / " + batchTotal);
            if (UI::Button("Cancel")) batchCancel = true;
        } else {
            UI::BeginDisabled(total <= 0 || total > 2000);
            if (UI::Button(Icons::Cogs + " Generate " + total + " items")) startnew(RunBatch);
            UI::EndDisabled();
            if (total > 2000) UI::Text("\\$f80Too many variants (cap 2000).");
        }
    }

    void DrawLog() {
        if (UI::Button("Clear")) log = "";
        UI::BeginChild("ib-log", vec2(0, 0), true);
        UI::TextWrapped(log);
        UI::EndChild();
    }
}
#endif
