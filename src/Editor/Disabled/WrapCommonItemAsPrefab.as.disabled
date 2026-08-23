// Replace CGameCommonItemEntityModel with a 1-ent CPlugPrefab whose
// Ents[0].Model is the existing CPlugStaticObjectModel (identity loc).
// Prefab nod comes from an isolated User copy of PodiumDisk.Prefab.Gbx
// (game-inited fields). Ents are rewritten with WriteEntRef — do not copy
// official SEntRef bytes (ModelFid). MwAddRef only; never MwRelease.
namespace Editor {
    // Custom User item that embeds a prefab (no GameData fid-refs). Drop yours here.
    const string WrapPrefabDonorRel = "Items/_epp/WrapPrefabDonor.Item.Gbx";

    CPlugPrefab@ PrefabFromLoadedNod(CMwNod@ nod) {
        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) return prefab;
        return PrefabFromItemModel(cast<CGameItemModel>(nod));
    }

    CPlugPrefab@ PrefabFromItemModel(CGameItemModel@ im) {
        if (im is null || im.EntityModel is null) return null;
        auto prefab = cast<CPlugPrefab>(im.EntityModel);
        if (prefab !is null) return prefab;
        auto vars = cast<NPlugItem_SVariantList>(im.EntityModel);
        if (vars is null) return null;
        for (uint i = 0; i < vars.Variants.Length; i++) {
            @prefab = cast<CPlugPrefab>(vars.Variants[i].EntityModel);
            if (prefab !is null) return prefab;
        }
        return null;
    }

    CPlugPrefab@ LoadIsolatedPrefabDonor() {
        string src = IO::FromUserGameFolder(WrapPrefabDonorRel);
        if (!IO::FileExists(src)) {
            warn("Wrap prefab donor missing: " + src);
            return null;
        }
        string rel = "Items/_epp/wrap-" + Time::Now + ".Item.Gbx";
        string dest = IO::FromUserGameFolder(rel);
        IO::CreateFolder(IO::FromUserGameFolder("Items/_epp"), true);
        CopyFile(src, dest);
        auto itemsFolder = Fids::GetUserFolder("Items");
        if (itemsFolder !is null) Fids::UpdateTree(itemsFolder);
        auto userRoot = Fids::GetUserFolder("");
        if (userRoot !is null) Fids::UpdateTree(userRoot);
        string fidPath = rel.Replace("/", "\\");
        auto fid = Fids::GetUser(fidPath);
        if (fid is null) {
            warn("Wrap prefab donor GetUser failed: " + fidPath);
            return null;
        }
        auto nod = Fids::Preload(fid);
        auto prefab = PrefabFromLoadedNod(nod);
        if (prefab is null) {
            warn("Wrap prefab donor has no CPlugPrefab: " + (nod is null ? "null" : Reflection::TypeOf(nod).Name));
            return null;
        }
        prefab.MwAddRef();
        return prefab;
    }

    CPlugPrefab@ NewPrefabNod() {
        auto donor = LoadIsolatedPrefabDonor();
        if (donor !is null) return donor;
        auto prefab = CPlugPrefab();
        if (prefab is null) throw("WrapCommonItemEntityAsPrefab: CPlugPrefab() returned null");
        prefab.MwAddRef();
        return prefab;
    }

    CPlugPrefab@ WrapCommonItemEntityAsPrefab(CGameItemModel@ model) {
        if (model is null) throw("WrapCommonItemEntityAsPrefab: ItemModel is null");
        if (cast<CPlugPrefab>(model.EntityModel) !is null) {
            throw("WrapCommonItemEntityAsPrefab: EntityModel is already a CPlugPrefab");
        }
        auto common = cast<CGameCommonItemEntityModel>(model.EntityModel);
        if (common is null) {
            string got = model.EntityModel is null ? "null" : Reflection::TypeOf(model.EntityModel).Name;
            throw("WrapCommonItemEntityAsPrefab: EntityModel is " + got + ", expected CGameCommonItemEntityModel");
        }
        auto staticObj = cast<CPlugStaticObjectModel>(common.StaticObject);
        if (staticObj is null) {
            string got = common.StaticObject is null ? "null" : Reflection::TypeOf(common.StaticObject).Name;
            throw("WrapCommonItemEntityAsPrefab: StaticObject is " + got + ", expected CPlugStaticObjectModel");
        }

        auto prefab = NewPrefabNod();
        auto allocd = BufferAlloc::Alloc(1, SZ_ENT_REF);
        allocd.WriteToNod(prefab, O_PREFAB_ENTS, 1);
        MeshDuplication::WriteEntRef(prefab, 0, staticObj, quat(1, 0, 0, 0), vec3(0), 0);

        Dev::SetOffset(model, O_ITEM_MODEL_EntityModel, prefab);
        return prefab;
    }
}
