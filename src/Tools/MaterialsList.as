// Kinematic / dyna vis intern-forces vis-const 2. CubeOut / Dyna0 shaders draw;
// Block-only, PyPxz, LightFromMap, MaterialStatic_* do not.
// research/2026-08-31-KinematicMaterials.md
enum EMovingItemMat {
    Unknown = 0,
    Works = 1,
    Invisible = 2
}

bool MaterialWorksForMovingItems(CPlugMaterial@ mat) {
    return ClassifyMaterialForMovingItems(mat) == EMovingItemMat::Works;
}

bool MaterialWorksForMovingItems(CPlugMaterialUserInst@ ui) {
    return ClassifyMaterialForMovingItems(ui) == EMovingItemMat::Works;
}

bool MaterialWorksForMovingItems(CSystemFidFile@ fid) {
    return ClassifyMaterialForMovingItems(fid) == EMovingItemMat::Works;
}

EMovingItemMat ClassifyMaterialForMovingItems(CPlugMaterial@ mat) {
    if (mat is null) return EMovingItemMat::Unknown;
    return ClassifyMovingItemMatName(MaterialShaderFamilyName(mat));
}

EMovingItemMat ClassifyMaterialForMovingItems(CPlugMaterialUserInst@ ui) {
    if (ui is null) return EMovingItemMat::Unknown;
    if (ui.IsUsingGameMaterial) {
        auto game = ResolveGameMaterialFromUserInst(ui);
        if (game !is null) return ClassifyMaterialForMovingItems(game);
        return ClassifyMovingItemMatName(ui._LinkFull);
    }
    string m = MwId(Dev::GetOffsetUint32(ui, 0x48)).GetName();
    if (m.StartsWith("MaterialDyna0_")) return EMovingItemMat::Works;
    if (m.StartsWith("MaterialStatic_") || m.StartsWith("MaterialChar_") || m.StartsWith("MaterialVehicle_")) {
        return EMovingItemMat::Invisible;
    }
    return EMovingItemMat::Unknown;
}

EMovingItemMat ClassifyMaterialForMovingItems(CSystemFidFile@ fid) {
    if (fid is null) return EMovingItemMat::Unknown;
    auto mat = cast<CPlugMaterial>(fid.Nod);
    if (mat !is null) return ClassifyMaterialForMovingItems(mat);
    return ClassifyMovingItemMatName(string(fid.FileName));
}

string MaterialShaderFamilyName(CPlugMaterial@ mat) {
    string n = MovingItemFidName(cast<CSystemFidFile>(GetFidFromNod(mat)));
    auto parent = cast<CPlugMaterial>(Dev::GetOffsetNod(mat, O_MATERIAL_PARENT));
    if (parent !is null) n += " " + MovingItemFidName(cast<CSystemFidFile>(GetFidFromNod(parent)));
    uint64 table = Dev::GetOffsetUint64(mat, O_MATERIAL_SHADER_TABLE);
    uint count = Dev::GetOffsetUint32(mat, O_MATERIAL_SHADER_TABLE + 0x8);
    if (table != 0 && count > 0 && count < 16) {
        auto shNod = Dev_GetNodFromPointer(Dev::ReadUInt64(table + 0x8));
        auto shFid = cast<CSystemFidFile>(shNod);
        if (shFid is null && shNod !is null) @shFid = cast<CSystemFidFile>(GetFidFromNod(shNod));
        if (shFid !is null) n += " " + MovingItemFidName(shFid);
    }
    return n;
}

string MovingItemFidName(CSystemFidFile@ fid) {
    if (fid is null) return "";
    return string(fid.FileName);
}

CPlugMaterial@ ResolveGameMaterialFromUserInst(CPlugMaterialUserInst@ ui) {
    string link = ui._LinkFull;
    if (link.Length == 0) link = ui.Link.GetName();
    if (link.Length == 0) return null;
    string rel = "GameData/" + link.Replace("\\", "/") + ".Material.Gbx";
    auto fid = Fids::GetGame(rel);
    if (fid is null) @fid = Fids::GetGame(rel.Replace(".Material.Gbx", ".Material.gbx"));
    if (fid is null) return null;
    if (fid.Nod is null) Fids::Preload(fid);
    return cast<CPlugMaterial>(fid.Nod);
}

EMovingItemMat ClassifyMovingItemMatName(const string &in raw) {
    string n = raw.ToLower();
    if (n.Length == 0) return EMovingItemMat::Unknown;
    if (n.Contains("cubeout") || n.Contains("_cout") || n.Contains("dyna_")) return EMovingItemMat::Works;
    if (n.Contains("pypxz") || n.Contains("pxz")) return EMovingItemMat::Invisible;
    if (n.Contains("lightfrommap") || n.Contains("pc3") || n.Contains("pdiff")) return EMovingItemMat::Invisible;
    if (n.Contains("block_") && !n.Contains("cout") && !n.Contains("cubeout")) return EMovingItemMat::Invisible;
    return EMovingItemMat::Unknown;
}

string MovingItemMatTag(EMovingItemMat v) {
    if (v == EMovingItemMat::Works) return "\\$8f8ok";
    if (v == EMovingItemMat::Invisible) return "\\$f88no";
    return "\\$888?";
}

bool MaterialsListCanInspectFids(bool mapEditorReady, bool itemEditorReady, bool meshEditorReady, bool mtEditorReady) {
    return mapEditorReady || itemEditorReady || meshEditorReady || mtEditorReady;
}

bool MaterialsListCanInspectFidsNow() {
    return MaterialsListCanInspectFids(IsInEditor, IsInItemEditor, IsInMeshEditor, IsInMTEditor);
}

class MaterialsListTab : Tab {
    MaterialsListTab(TabGroup@ parent) {
        super(parent, "Materials List", Icons::MapO + Icons::ListAlt);
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::HorizontalScrollbar;
    }

    bool DrawWindow() override {
        UI::SetNextWindowSize(450, Display::GetHeight() / 2);
        return Tab::DrawWindow();
    }

    CSystemFidFile@[] filtered;
    string filter;
    bool loadingUnknownNods = false;
    uint lastUnknownCount = 0;

    CSystemFidFile@[]@ ListedFiles() {
        if (filter.Length > 0) return filtered;
        return g_MaterialCache.files;
    }

    uint CountUnknownListed() {
        auto @files = ListedFiles();
        uint n = 0;
        for (uint i = 0; i < files.Length; i++) {
            if (ClassifyMaterialForMovingItems(files[i]) == EMovingItemMat::Unknown) n++;
        }
        return n;
    }

    void LoadUnknownNods() {
        loadingUnknownNods = true;
        auto @files = ListedFiles();
        uint nPre = 0;
        for (uint i = 0; i < files.Length; i++) {
            if (!MaterialsListCanInspectFidsNow()) break;
            auto fid = files[i];
            if (ClassifyMaterialForMovingItems(fid) != EMovingItemMat::Unknown) continue;
            if (fid.Nod is null) {
                Fids::Preload(fid);
                nPre++;
            }
            auto mat = cast<CPlugMaterial>(fid.Nod);
            if (mat !is null) {
                auto parent = cast<CPlugMaterial>(Dev::GetOffsetNod(mat, O_MATERIAL_PARENT));
                if (parent !is null) {
                    auto pf = cast<CSystemFidFile>(GetFidFromNod(parent));
                    if (pf !is null && pf.Nod is null) Fids::Preload(pf);
                }
            }
            CheckPause("MaterialsListTab::LoadUnknownNods");
        }
        loadingUnknownNods = false;
        Notify("Preloaded " + nPre + " material nods.");
    }

    void DrawInner() override {
        if (!MaterialsListCanInspectFidsNow()) {
            UI::TextDisabled("Waiting for the editor to finish loading...");
            return;
        }

        if (g_MaterialCache is null) {
            UI::Text("Missing materials cache!");
            return;
        }

        if (UI::Button("Refresh Materials")) {
            g_MaterialCache.RefreshCacheBg();
        }
        UI::SameLine();
        if (UI::Button("Update Fid Trees")) {
            startnew(CoroutineFunc(g_MaterialCache.UpdateAllFidTreesYields));
        }
        UI::SameLine();
        if (UI::Button("Expanded Search")) {
            startnew(CoroutineFunc(g_MaterialCache.SearchEverywhereYields));
        }

        UI::Text("Nb Materials Found: " + g_MaterialCache.files.Length);

        UI::Text("Material Paths:");

        bool changed = false;
        filter = UI::InputText("Filter", filter, changed);
        if (UI::Button("Reset Filter")) {
            filter = "";
        }

        if (changed) startnew(CoroutineFunc(UpdateFiltered));

        auto @files = ListedFiles();
        lastUnknownCount = CountUnknownListed();

        if (UI::Button("Copy all listed to clipboard")) {
            string[] names;
            for (uint i = 0; i < files.Length; i++) {
                names.InsertLast(FID_GetListName(files[i], false));
            }
            IO::SetClipboard(Text::Join(names, "\n"));
            Notify("Copied " + names.Length + " material paths to clipboard.");
        }
        UI::SameLine();
        UI::BeginDisabled(loadingUnknownNods || lastUnknownCount == 0);
        if (UI::Button("Load ? Nods (" + lastUnknownCount + ")")) {
            startnew(CoroutineFunc(LoadUnknownNods));
        }
        UI::EndDisabled();

        UI::Indent();

        UI::TextDisabled("moving: ok = CubeOut/Dyna0; no = PyPxz/Block/Static; ? = Load ? Nods or unknown name");

        UI::ListClipper clip(files.Length);
        while (clip.Step()) {
            for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                UI::Text(MovingItemMatTag(ClassifyMaterialForMovingItems(files[i])));
                UI::SameLine();
                CopiableValue(FID_GetListName(files[i]));
            }
        }

        UI::Unindent();
    }

    string FID_GetListName(CSystemFidFile@ file, bool shortFileName = true) {
        auto parts = string(file.ParentFolder.FullDirName).Split("GameData\\");
        auto folder = parts[parts.Length - 1];
        return folder + (shortFileName ? file.ShortFileName : file.FileName);
    }

    uint updateNonce = 0;
    void UpdateFiltered() {
        auto myNonce = ++updateNonce;
        auto lowerFilter = filter.ToLower();
        filtered.RemoveRange(0, filtered.Length);
        for (uint i = 0; i < g_MaterialCache.files.Length; i++) {
            if (!MaterialsListCanInspectFidsNow()) break;
            if (myNonce != updateNonce) break;
            auto item = g_MaterialCache.files[i];
            if (string(item.ShortFileName).ToLower().Contains(lowerFilter)) {
                filtered.InsertLast(item);
            }
            CheckPause("MaterialsListTab::UpdateFiltered");
        }
    }
}
