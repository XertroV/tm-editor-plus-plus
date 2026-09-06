#if DEV
// Builder for CGameItemModel nods outside the item editor.
//
//   auto r = ItemBuilder::Builder("Items\\MyCrown_Shifted.Item.Gbx")
//       .FromFresh("Items\\BF2_Crown.Item.Gbx")      // independent copy loaded from disk
//       .UvShift(0.1, 0.0)                            // TexCoord0 of every Solid2 visual
//       .Save();
//   if (!r.ok) warn(r.err);
//
// Fresh copies: null fid.Nod, Fids::Preload (game reads the file again), then restore the
// original fid<->nod binding so the cached item is untouched (SetFid.as helpers).
// Borrowed nods: taken from another (fresh or cached) item and ref-counted with MwAddRef.
// Save: NativeSave (AsCall GbxArchive_SerializeNodToFid). research/2026-09-03-SaveItemModelAsCall.md
namespace ItemBuilder {
    funcdef void MutateFn(CGameItemModel@ model);

    class Result {
        bool ok = false;
        string err;
        string path;
        CGameItemModel@ model;
    }

    string NormPath(const string &in p) {
        string s = p.Replace("/", "\\");
        while (s.Contains("\\\\")) s = s.Replace("\\\\", "\\");
        while (s.StartsWith("\\")) s = s.SubStr(1);
        return s;
    }

    // Cached load (same nod the game / other code sees).
    CGameItemModel@ LoadCached(const string &in userPath, string &out err) {
        err = "";
        auto fid = Fids::GetUser(NormPath(userPath));
        if (fid is null) { err = "no fid: " + userPath; return null; }
        auto nod = fid.Nod;
        if (nod is null) @nod = Fids::Preload(fid);
        auto model = cast<CGameItemModel>(nod);
        if (model is null) err = "not a CGameItemModel: " + userPath;
        return model;
    }

    // Independent copy: detach fid.Nod, Preload again, then put the original binding back.
    // The fresh nod is left unbound (nod+0x8 = 0); Save binds it to the destination fid.
    CMwNod@ LoadFreshNod(const string &in userPath, string &out err) {
        err = "";
        auto fid = Fids::GetUser(NormPath(userPath));
        if (fid is null) { err = "no fid: " + userPath; return null; }
        string full = IO::FromUserGameFolder(NormPath(userPath).Replace("\\", "/"));
        if (!IO::FileExists(full)) { err = "file missing: " + full; return null; }
        CMwNod@ orig = fid.Nod;
        if (orig !is null) Dev::SetOffset(fid, O_FID_Nod, uint64(0));
        CMwNod@ fresh = Fids::Preload(fid);
        // restore game integrity: original nod owns the fid again, fresh nod is unbound
        Dev::SetOffset(fid, O_FID_Nod, orig !is null ? Dev_GetPointerForNod(orig) : uint64(0));
        if (fresh !is null) Dev::SetOffset(fresh, 0x8, uint64(0));
        if (fresh is null) err = "Preload returned null: " + userPath;
        return fresh;
    }

    CGameItemModel@ LoadFresh(const string &in userPath, string &out err) {
        auto nod = LoadFreshNod(userPath, err);
        auto model = cast<CGameItemModel>(nod);
        if (model is null && err.Length == 0) err = "not a CGameItemModel: " + userPath;
        return model;
    }

    void CollectSolid2(CMwNod@ nod, array<CPlugSolid2Model@>@ acc) {
        if (nod is null) return;
        auto s2m = cast<CPlugSolid2Model>(nod);
        if (s2m !is null) { acc.InsertLast(s2m); return; }
        auto item = cast<CGameItemModel>(nod);
        if (item !is null) { CollectSolid2(item.EntityModel, acc); return; }
        auto so = cast<CPlugStaticObjectModel>(nod);
        if (so !is null) { CollectSolid2(so.Mesh, acc); return; }
        auto dyna = cast<CPlugDynaObjectModel>(nod);
        if (dyna !is null) { CollectSolid2(dyna.Mesh, acc); return; }
        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) {
            for (uint i = 0; i < prefab.Ents.Length; i++) CollectSolid2(prefab.Ents[i].Model, acc);
            return;
        }
        auto common = cast<CGameCommonItemEntityModel>(nod);
        if (common !is null) { CollectSolid2(common.StaticObject, acc); return; }
    }

    array<CPlugVisual@>@ Solid2Visuals(CPlugSolid2Model@ s2m) {
        array<CPlugVisual@> ret;
        uint n = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 8);
        auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        for (uint i = 0; i < n && buf !is null; i++) {
            auto vis = cast<CPlugVisual>(Dev::GetOffsetNod(buf, i * 8));
            if (vis !is null) ret.InsertLast(vis);
        }
        return ret;
    }

    int MaterialIndexOfVisual(CPlugSolid2Model@ s2m, uint visIdx) { return VisualUVs::MaterialIndexOfVisual(s2m, visIdx); }
    string MaterialName(CPlugSolid2Model@ s2m, int matIdx) { return VisualUVs::MaterialName(s2m, matIdx); }

    CPlugVisual@ VisualAt(CPlugSolid2Model@ s2m, uint visIdx) {
        uint n = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 8);
        if (visIdx >= n) return null;
        auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        return buf is null ? null : cast<CPlugVisual>(Dev::GetOffsetNod(buf, visIdx * 8));
    }

    // Swap the visual in slot visIdx for another CPlugVisualIndexedTriangles (e.g. from a Blender
    // Mesh.Gbx). The slot keeps its ShadedGeoms material binding, so the donor's vertex layout must
    // suit that material (Position/Normal/TexCoord0, and TexCoord1 if the material is lightmapped).
    bool ReplaceVisual(CPlugSolid2Model@ s2m, uint visIdx, CPlugVisual@ donor, string &out err) {
        err = "";
        if (s2m is null || donor is null) { err = "ReplaceVisual: null"; return false; }
        if (cast<CPlugVisualIndexedTriangles>(donor) is null) { err = "ReplaceVisual: donor is not CPlugVisualIndexedTriangles"; return false; }
        uint n = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 8);
        if (visIdx >= n) { err = "ReplaceVisual: visual " + visIdx + " >= " + n; return false; }
        auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        if (buf is null) { err = "ReplaceVisual: visuals buffer null"; return false; }
        auto old = Dev::GetOffsetNod(buf, visIdx * 8);
        if (old is donor) return true;
        donor.MwAddRef();
        Dev::SetOffset(buf, uint16(visIdx * 8), donor);
        if (old !is null) old.MwRelease();
        return true;
    }

    // Load a mesh file (Items\X.Mesh.Gbx or an item) and pick one of its visuals.
    CPlugVisual@ LoadDonorVisual(const string &in userPath, uint s2mIdx, uint visIdx, bool fresh, string &out err, array<CMwNod@>@ keepAlive = null) {
        CMwNod@ nod = fresh ? LoadFreshNod(userPath, err) : null;
        if (!fresh) {
            auto fid = Fids::GetUser(NormPath(userPath));
            if (fid !is null) { @nod = fid.Nod; if (nod is null) @nod = Fids::Preload(fid); }
            if (nod is null) err = "no nod: " + userPath;
        }
        if (nod is null) return null;
        if (keepAlive !is null) { nod.MwAddRef(); keepAlive.InsertLast(nod); }
        array<CPlugSolid2Model@> models;
        CollectSolid2(nod, models);
        if (s2mIdx >= models.Length) { err = "donor has " + models.Length + " Solid2 (wanted #" + s2mIdx + "): " + userPath; return null; }
        auto vis = VisualAt(models[s2mIdx], visIdx);
        if (vis is null) err = "donor Solid2 #" + s2mIdx + " has no visual #" + visIdx + ": " + userPath;
        return vis;
    }

    CPlugMaterialUserInst@ UserMaterialAt(CPlugSolid2Model@ s2m, uint matIdx) {
        uint n = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_USERMAT_BUF + 8);
        if (matIdx >= n) return null;
        auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_USERMAT_BUF);
        return buf is null ? null : cast<CPlugMaterialUserInst>(Dev::GetOffsetNod(buf, matIdx * 0x18));
    }

    // Point a user material inst at another game material, e.g. "Stadium\\Media\\Modifier\\Cruise\\SpecialFX".
    // Only _LinkFull is written: game-exported items (e.g. the BF2 dips) carry Link/_Link_OldCompat
    // as Unassigned and resolve the material from the full link alone.
    bool SetUserMaterialLink(CPlugMaterialUserInst@ mat, const string &in linkFull) {
        if (mat is null) return false;
        mat._LinkFull = linkFull.Replace("/", "\\");
        return true;
    }

    // Which visuals a UV edit touches. Default: all.
    class VisualFilter {
        int s2mIdx = -1;         // exact Solid2 index within the item (CollectSolid2 order)
        int visIdx = -1;         // exact visual index
        int matIdx = -1;         // exact material index (ShadedGeoms)
        string matName;          // case-insensitive substring of MaterialName()
        bool Matches(CPlugSolid2Model@ s2m, uint v, int s2mIx = -1) {
            if (s2mIdx >= 0 && s2mIx != s2mIdx) return false;
            if (visIdx >= 0 && int(v) != visIdx) return false;
            if (matIdx >= 0 || matName.Length > 0) {
                int mi = MaterialIndexOfVisual(s2m, v);
                if (matIdx >= 0 && mi != matIdx) return false;
                if (matName.Length > 0 && !MaterialName(s2m, mi).ToLower().Contains(matName.ToLower())) return false;
            }
            return true;
        }
    }

    bool IsUintStr(const string &in t) { return t.Length > 0 && t == tostring(Text::ParseInt(t)) && Text::ParseInt(t) >= 0; }

    // "" / "-1" all; "3" material index; "v2" visual index; anything else material-name substring.
    // Optional "s<N>" prefix restricts to Solid2 #N: "s1v0", "s0m2", "s1", "s0 Ice".
    VisualFilter@ ParseVisualFilter(const string &in spec) {
        VisualFilter f;
        string t = spec.Trim();
        if (t.Length == 0 || t == "-1") return f;
        if (t.ToLower().StartsWith("s")) {
            uint n = 1;
            while (n < t.Length && t[n] >= 0x30 && t[n] <= 0x39) n++;
            if (n > 1) {
                f.s2mIdx = Text::ParseInt(t.SubStr(1, n - 1));
                t = t.SubStr(n).Trim();
                if (t.Length == 0) return f;
            }
        }
        if (t.ToLower().StartsWith("v") && Text::ParseInt(t.SubStr(1)) >= 0 && t.SubStr(1) == tostring(Text::ParseInt(t.SubStr(1)))) { f.visIdx = Text::ParseInt(t.SubStr(1)); return f; }
        if (t == tostring(Text::ParseInt(t))) { f.matIdx = Text::ParseInt(t); return f; }
        f.matName = t;
        return f;
    }

    uint ShiftVisualUv(CPlugVisual@ vis, float du, float dv, uint semantic = 10) { return VisualUVs::Shift(vis, semantic, du, dv); }

    class Builder {
        string dest;
        CGameItemModel@ model;
        string err;
        private array<CMwNod@> held;

        Builder(const string &in destUserPath) {
            dest = NormPath(destUserPath);
        }

        bool Ok() { return err.Length == 0 && model !is null; }

        private void Hold(CMwNod@ n) {
            if (n is null) return;
            n.MwAddRef();
            held.InsertLast(n);
        }

        // Base model: fresh copy of an existing User item.
        Builder@ FromFresh(const string &in userPath) {
            if (err.Length > 0) return this;
            @model = LoadFresh(userPath, err);
            Hold(model);
            return this;
        }

        // Base model: the cached nod (mutations affect the loaded item; use for read-only or batch+restore).
        Builder@ FromCached(const string &in userPath) {
            if (err.Length > 0) return this;
            @model = LoadCached(userPath, err);
            Hold(model);
            return this;
        }

        // Base model: a nod you already hold.
        Builder@ FromModel(CGameItemModel@ m) {
            if (err.Length > 0) return this;
            if (m is null) { err = "FromModel: null"; return this; }
            @model = m;
            Hold(model);
            return this;
        }

        // Replace EntityModel with a nod borrowed from another item (fresh copy by default).
        Builder@ BorrowEntityModel(const string &in userPath, bool fresh = true) {
            if (err.Length > 0) return this;
            string e;
            auto src = fresh ? LoadFresh(userPath, e) : LoadCached(userPath, e);
            if (src is null) { err = "BorrowEntityModel: " + e; return this; }
            Hold(src);
            return SetEntityModel(src.EntityModel);
        }

        Builder@ SetEntityModel(CMwNod@ em) {
            if (err.Length > 0) return this;
            if (model is null) { err = "SetEntityModel: no base model"; return this; }
            if (em is null) { err = "SetEntityModel: null"; return this; }
            auto old = model.EntityModel;
            em.MwAddRef();
            Dev::SetOffset(model, O_ITEM_MODEL_EntityModel, em);
            if (old !is null) old.MwRelease();
            return this;
        }

        // Shift TexCoord0 on every Solid2 visual (or only visuals of one material index).
        Builder@ UvShift(float du, float dv, int onlyMaterialIndex = -1, uint semantic = 10) {
            VisualFilter f; f.matIdx = onlyMaterialIndex;
            return UvShiftFiltered(du, dv, f, semantic);
        }
        Builder@ UvShiftVisual(uint visIdx, float du, float dv, uint semantic = 10) {
            VisualFilter f; f.visIdx = int(visIdx);
            return UvShiftFiltered(du, dv, f, semantic);
        }
        Builder@ UvShiftMaterial(const string &in matNameSubstr, float du, float dv, uint semantic = 10) {
            VisualFilter f; f.matName = matNameSubstr;
            return UvShiftFiltered(du, dv, f, semantic);
        }
        Builder@ UvShiftFiltered(float du, float dv, VisualFilter@ f, uint semantic = 10) {
            if (err.Length > 0) return this;
            if (model is null) { err = "UvShift: no base model"; return this; }
            array<CPlugSolid2Model@> models;
            CollectSolid2(model, models);
            uint touched = 0;
            for (uint m = 0; m < models.Length; m++) {
                auto vis = Solid2Visuals(models[m]);
                for (uint v = 0; v < vis.Length; v++) {
                    if (!f.Matches(models[m], v, int(m))) continue;
                    touched += ShiftVisualUv(vis[v], du, dv, semantic);
                }
            }
            if (touched == 0) err = "UvShift: no Float2 semantic-" + semantic + " attribute found (or filter matched no visual)";
            return this;
        }

        // Replace Solid2[s2mIdx].Visuals[visIdx] with a visual you already hold.
        Builder@ ReplaceVisual(uint s2mIdx, uint visIdx, CPlugVisual@ donor) {
            if (err.Length > 0) return this;
            if (model is null) { err = "ReplaceVisual: no base model"; return this; }
            array<CPlugSolid2Model@> models;
            CollectSolid2(model, models);
            if (s2mIdx >= models.Length) { err = "ReplaceVisual: no Solid2 #" + s2mIdx; return this; }
            string e;
            if (!ItemBuilder::ReplaceVisual(models[s2mIdx], visIdx, donor, e)) err = e;
            return this;
        }

        // Same, taking the visual from another mesh/item file on disk.
        Builder@ ReplaceVisualFrom(uint s2mIdx, uint visIdx, const string &in donorPath, uint donorS2m = 0, uint donorVis = 0, bool fresh = true) {
            if (err.Length > 0) return this;
            string e;
            auto vis = LoadDonorVisual(donorPath, donorS2m, donorVis, fresh, e, held);
            if (vis is null) { err = "ReplaceVisualFrom: " + e; return this; }
            return ReplaceVisual(s2mIdx, visIdx, vis);
        }

        Builder@ Mutate(MutateFn@ fn) {
            if (err.Length > 0) return this;
            if (model is null) { err = "Mutate: no base model"; return this; }
            fn(model);
            return this;
        }

        Result@ Save(uint mode = NativeSave::ModeItem) {
            Result r;
            r.path = dest;
            @r.model = model;
            if (err.Length > 0) { r.err = err; return r; }
            if (model is null) { r.err = "nothing to save"; return r; }
            string e;
            r.ok = NativeSave::SaveNodToUser(model, dest, e, mode);
            r.err = e;
            return r;
        }

        // Save, then load the written file fresh from disk (proves persistence).
        CGameItemModel@ SaveAndReload(string &out e) {
            auto r = Save();
            if (!r.ok) { e = r.err; return null; }
            return LoadFresh(dest, e);
        }

        ~Builder() {
            for (uint i = 0; i < held.Length; i++) held[i].MwRelease();
        }
    }
}
#endif
