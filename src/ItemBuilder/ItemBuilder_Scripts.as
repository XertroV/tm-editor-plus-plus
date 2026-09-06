#if DEV
// Scriptable item creation. Trigger from outside the game by writing the hidden setting
// S_ItemBuilder_RunScript (tm-control-mcp SetPluginSetting), e.g.
//   uvbatch|Items\BF2_Crown.Item.Gbx|Items\Crown_U{i}.Item.Gbx|3|0.1|0|<filter>
//     filter: empty/-1 all visuals, "2" material index 2, "v1" visual index 1, "Gold" material-name substring
//   mats|Items\BF2_Crown.Item.Gbx        (lists visual -> material index / name)
//   uibatch|FX|-0.1|0.1|0.01|Items\IB_GenFX\DipFX_{i}.Item.Gbx|0   (Batch tab config; fields optional)
//   register|Items\IB_Gen                 (catalog-register every .Item.Gbx under a User folder)
//   rebuildinv                            (rebuild the map editor's Items tree from the catalog)
//   copy|Items\BF2_Crown.Item.Gbx|Items\CrownCopy.Item.Gbx
//   borrow|Items\BF2_Crown.Item.Gbx|Items\AeroVT.Item.Gbx|Items\CrownWithAeroMesh.Item.Gbx
// Result lands in S_ItemBuilder_LastResult (read with GetPluginSetting) and the log.
namespace ItemBuilder {
    [Setting hidden]
    string S_ItemBuilder_RunScript = "";
    [Setting hidden]
    string S_ItemBuilder_LastResult = "";

    void Runner() {
        while (true) {
            if (S_ItemBuilder_RunScript.Length > 0) {
                string spec = S_ItemBuilder_RunScript;
                S_ItemBuilder_RunScript = "";
                S_ItemBuilder_LastResult = "running";
                string res;
                try {
                    res = RunSpec(spec);
                } catch {
                    res = "EXC: " + getExceptionInfo();
                }
                S_ItemBuilder_LastResult = res;
                print("[ItemBuilder] " + spec + " => " + res);
            }
            sleep(250);
        }
    }

    string RunSpec(const string &in spec) {
        auto parts = spec.Split("|");
        if (parts.Length == 0) return "empty spec";
        string cmd = parts[0].ToLower();
        if (cmd == "copy" && parts.Length >= 3) return Script_Copy(parts[1], parts[2]);
        if (cmd == "uvbatch" && parts.Length >= 5) {
            float du = Text::ParseFloat(parts[4]);
            float dv = parts.Length >= 6 ? Text::ParseFloat(parts[5]) : 0.0;
            auto f = ParseVisualFilter(parts.Length >= 7 ? parts[6] : "");
            return Script_UvBatch(parts[1], parts[2], Text::ParseInt(parts[3]), du, dv, f);
        }
        if (cmd == "describe" && parts.Length >= 2) { string e; auto m = LoadCached(parts[1], e); return m is null ? "FAIL " + e : Describe(m); }
        if (cmd == "mats" && parts.Length >= 2) return Script_ListMaterials(parts[1]);
        if (cmd == "register" && parts.Length >= 2) { string e; string r = ItemInventory::RegisterFolder(parts[1], e); return "register " + r + (e.Length > 0 ? " errors: " + e : ""); }
        if (cmd == "invfind" && parts.Length >= 2) {
            auto inv = Editor::GetInventoryCache();
            if (inv.isRefreshing) return "inventory cache refreshing";
            string needle = parts[1].ToLower(); string res; uint n = 0;
            for (uint i = 0; i < inv.ItemPaths.Length; i++) {
                if (!inv.ItemPaths[i].ToLower().Contains(needle)) continue;
                n++; if (n <= 5) res += inv.ItemPaths[i] + "; ";
            }
            return "invfind " + n + " of " + inv.ItemPaths.Length + ": " + res;
        }
        if (cmd == "rebuildinv") { string e; return ItemInventory::RebuildEditorItemsTree(e) ? "rebuilt" : "FAIL " + e; }
        if (cmd == "listmods") return Script_ListModifiers(parts.Length >= 2 ? parts[1] : "SpecialFX");
        if (cmd == "matbatch" && parts.Length >= 10) {
            // matbatch|template|pattern|s2m|matIdx|SpecialFX|uvStart|uvEnd|uvStep|uvFilter
            ItemBuilderUI::batchTemplate = parts[1];
            ItemBuilderUI::batchPattern = parts[2];
            ItemBuilderUI::batchOps.RemoveRange(0, ItemBuilderUI::batchOps.Length);
            auto linkOp = ItemBuilderUI::Op();
            linkOp.kind = ItemBuilderUI::OpKind::SetMaterialLink;
            linkOp.s2mIdx = Text::ParseInt(parts[3]); linkOp.matIdx = Text::ParseInt(parts[4]);
            linkOp.links = ModifierLinks(parts[5]);
            // "other" materials: drop the link the target material already has
            {
                string e; auto tm = LoadCached(parts[1], e);
                array<CPlugSolid2Model@> ms; if (tm !is null) CollectSolid2(tm, ms);
                auto cur = linkOp.s2mIdx >= 0 && linkOp.s2mIdx < int(ms.Length) ? UserMaterialAt(ms[linkOp.s2mIdx], uint(linkOp.matIdx)) : null;
                if (cur !is null) { int ix = linkOp.links.Find(cur._LinkFull); if (ix >= 0) linkOp.links.RemoveAt(ix); }
            }
            auto uvOp = ItemBuilderUI::Op();
            uvOp.ranged = true; uvOp.rangeAxis = 0;
            uvOp.rStart = Text::ParseFloat(parts[6]); uvOp.rEnd = Text::ParseFloat(parts[7]); uvOp.rStep = Text::ParseFloat(parts[8]);
            uvOp.filter = parts[9];
            ItemBuilderUI::batchOps.InsertLast(linkOp);
            ItemBuilderUI::batchOps.InsertLast(uvOp);
            if (linkOp.links.Length == 0) return "matbatch: no modifier materials named " + parts[5];
            ItemBuilderUI::RunBatch();
            return "matbatch " + ItemBuilderUI::batchDone + "/" + ItemBuilderUI::batchTotal + " (" + linkOp.links.Length + " links x " + uvOp.RangeCount() + " uv)";
        }
        if (cmd == "place" && parts.Length >= 2) {
            // place|folder|layout(0 row,1 grid,2 prefix)|columns|ox|oy|oz|dx|dz
            ItemBuilderUI::placeFolder = parts[1];
            if (parts.Length >= 3) ItemBuilderUI::placeLayout = ItemBuilderUI::PlaceLayout(Text::ParseInt(parts[2]));
            if (parts.Length >= 4) ItemBuilderUI::placeColumns = Text::ParseInt(parts[3]);
            if (parts.Length >= 7) ItemBuilderUI::placeOrigin = vec3(Text::ParseFloat(parts[4]), Text::ParseFloat(parts[5]), Text::ParseFloat(parts[6]));
            if (parts.Length >= 9) ItemBuilderUI::placeSpacing = vec2(Text::ParseFloat(parts[7]), Text::ParseFloat(parts[8]));
            ItemBuilderUI::RefreshPlaceMatches();
            ItemBuilderUI::PlaceCoro();
            return "place " + ItemBuilderUI::placeMatches.Length;
        }
        if (cmd == "swapvis" && parts.Length >= 8) {
            // swapvis|base|dest|s2m|vis|donorPath|donorS2m|donorVis
            auto b = Builder(parts[2]).FromFresh(parts[1]).ReplaceVisualFrom(Text::ParseInt(parts[3]), Text::ParseInt(parts[4]), parts[5], Text::ParseInt(parts[6]), Text::ParseInt(parts[7]));
            string e; auto m = b.SaveAndReload(e);
            return m is null ? "FAIL " + e : "OK " + parts[2] + " " + Describe(m);
        }
        if (cmd == "visbatch" && parts.Length >= 8) {
            // visbatch|template|pattern|s2m|vis|donorFolder|donorS2m|donorVis
            ItemBuilderUI::batchTemplate = parts[1];
            ItemBuilderUI::batchPattern = parts[2];
            ItemBuilderUI::batchOps.RemoveRange(0, ItemBuilderUI::batchOps.Length);
            auto op = ItemBuilderUI::Op();
            op.kind = ItemBuilderUI::OpKind::ReplaceVisualFromFiles;
            op.s2mIdx = Text::ParseInt(parts[3]); op.visIdx = Text::ParseInt(parts[4]);
            op.links = ItemBuilderUI::MeshFilesUnder(parts[5]);
            op.donorS2m = Text::ParseInt(parts[6]); op.donorVis = Text::ParseInt(parts[7]);
            ItemBuilderUI::batchOps.InsertLast(op);
            if (op.links.Length == 0) return "visbatch: no mesh files under " + parts[5];
            ItemBuilderUI::RunBatch();
            return "visbatch " + ItemBuilderUI::batchDone + "/" + ItemBuilderUI::batchTotal;
        }
        if (cmd == "uibatch") {
            // uibatch|filter|start|end|step|pattern|axis  (all optional; overrides the Batch tab's first op)
            ItemBuilderUI::InitBatchDefaults();
            auto op = ItemBuilderUI::batchOps[0];
            if (parts.Length >= 2) op.filter = parts[1];
            if (parts.Length >= 3) op.rStart = Text::ParseFloat(parts[2]);
            if (parts.Length >= 4) op.rEnd = Text::ParseFloat(parts[3]);
            if (parts.Length >= 5) op.rStep = Text::ParseFloat(parts[4]);
            if (parts.Length >= 6) ItemBuilderUI::batchPattern = parts[5];
            if (parts.Length >= 7) op.rangeAxis = Text::ParseInt(parts[6]);
            ItemBuilderUI::RunBatch();
            return "uibatch " + ItemBuilderUI::batchDone + "/" + ItemBuilderUI::batchTotal;
        }
        if (cmd == "borrow" && parts.Length >= 4) return Script_BorrowEntityModel(parts[1], parts[2], parts[3]);
        return "unknown spec: " + spec;
    }

    string Describe(CGameItemModel@ m) {
        if (m is null) return "null";
        string em = m.EntityModel !is null && Reflection::TypeOf(m.EntityModel) !is null ? Reflection::TypeOf(m.EntityModel).Name : "null";
        return "IdName=" + m.IdName + " EntityModel=" + em;
    }

    // Fresh copy of src saved under dest; reloads from disk to verify.
    string Script_Copy(const string &in src, const string &in dest) {
        auto b = Builder(dest).FromFresh(src);
        string e;
        auto reloaded = b.SaveAndReload(e);
        if (reloaded is null) return "FAIL " + e;
        return "OK " + dest + " " + Describe(reloaded);
    }

    // Links of every Stadium\Media\Modifier\<X>\<fxName> material (from the GameData fid tree).
    array<string> ModifierLinks(const string &in fxName) {
        array<string> ret;
        auto folder = Fids::GetGameFolder("GameData/Stadium/Media/Modifier");
        if (folder is null) return ret;
        for (uint i = 0; i < folder.Trees.Length; i++) {
            auto sub = folder.Trees[i];
            for (uint j = 0; j < sub.Leaves.Length; j++) {
                if (string(sub.Leaves[j].ShortFileName).ToLower() == fxName.ToLower()) {
                    ret.InsertLast("Stadium\\Media\\Modifier\\" + sub.DirName + "\\" + sub.Leaves[j].ShortFileName);
                }
            }
        }
        ret.SortAsc();
        return ret;
    }

    string Script_ListModifiers(const string &in fxName) {
        auto links = ModifierLinks(fxName);
        string res = "" + links.Length + ": ";
        for (uint i = 0; i < links.Length; i++) res += links[i] + "; ";
        return res;
    }

    // visual index -> material index / name, per Solid2 in the item.
    string Script_ListMaterials(const string &in src) {
        string e;
        auto m = LoadCached(src, e);
        if (m is null) return "FAIL " + e;
        array<CPlugSolid2Model@> models;
        CollectSolid2(m, models);
        string res;
        for (uint i = 0; i < models.Length; i++) {
            auto vis = Solid2Visuals(models[i]);
            res += "solid2[" + i + "]: ";
            for (uint v = 0; v < vis.Length; v++) {
                int mi = MaterialIndexOfVisual(models[i], v);
                auto um = mi >= 0 ? UserMaterialAt(models[i], uint(mi)) : null;
                res += "v" + v + "->m" + mi + " '" + MaterialName(models[i], mi) + "'" + (um !is null ? " link=" + um.Link.GetName() + " name=" + um._Name.GetName() : "") + "; ";
            }
        }
        return res.Length > 0 ? res : "no Solid2 found";
    }

    // N files, file k has TexCoord0 shifted by k*du, k*dv on the visuals the filter selects.
    string Script_UvBatch(const string &in src, const string &in destPattern, int count, float du, float dv, VisualFilter@ f) {
        string res;
        for (int k = 1; k <= count; k++) {
            string dest = destPattern.Replace("{i}", tostring(k));
            auto r = Builder(dest).FromFresh(src).UvShiftFiltered(du * float(k), dv * float(k), f).Save();
            res += (r.ok ? "OK " : "FAIL ") + dest + (r.ok ? "" : " " + r.err) + "; ";
            yield();
        }
        return res;
    }

    // Base item with the EntityModel of another item.
    string Script_BorrowEntityModel(const string &in baseSrc, const string &in donorSrc, const string &in dest) {
        auto b = Builder(dest).FromFresh(baseSrc).BorrowEntityModel(donorSrc);
        string e;
        auto reloaded = b.SaveAndReload(e);
        if (reloaded is null) return "FAIL " + e;
        return "OK " + dest + " " + Describe(reloaded);
    }
}
#endif
