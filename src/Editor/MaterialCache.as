class FidCache {
    CSystemFidFile@[] files;

    protected void ResetCache() {
        files.RemoveRange(0, files.Length);
    }

    // for fileExt, do not add `.Gbx` at the end (added automatically for case stuff)
    protected void CacheFolder(CSystemFidsFolder@ folder, const string &in fileExt, const string &in origPath = "") {
        if (folder is null && origPath.Length > 0) {
            warn("Failed to get material folder: " + origPath);
            return;
        }
        wstring fname;
        for (uint i = 0; i < folder.Leaves.Length; i++) {
            fname = folder.Leaves[i].FileName;
            if (fname.EndsWith(fileExt + ".Gbx") || fname.EndsWith(fileExt + ".gbx")) {
                CacheFile(folder.Leaves[i]);
            }
        }
        for (uint i = 0; i < folder.Trees.Length; i++) {
            CacheFolder(folder.Trees[i], fileExt);
        }
    }

    protected void CacheFile(CSystemFidFile@ file) {
        files.InsertLast(file);
    }
}


string[] materialPaths = {
    "GameData/Stadium/Media",
    // "GameData/Stadium/Media/Modifier",
    "GameData/Stadium256/Media",
    "GameData/Effects/Media",
    "GameData/Editors/MeshEditorMedia",
    "GameData/Engines/Media",
    "GameData/Techno3/Media",
    "GameData/Menu/Media",
    "GameData/Sky/Media",
    "GameData/Clouds/Media",
    "GameData/ShootMania/Media",
    "GameData/PainterTech/Media",
    "GameData/Vehicles/Media"
};

class MaterialCache : FidCache {
    MaterialCache() {
        super();
        RefreshCacheBg();
    }

    void UpdateTrees() {
        Fids::UpdateTree(Fids::GetGameFolder(""));
        // for (uint i = 0; i < materialPaths.Length; i++) {
        //     auto folder = Fids::GetGameFolder(materialPaths[i]);
        //     if (folder !is null) Fids::UpdateTree(folder);
        //     else warn("Could not find materials folder: " + materialPaths[i]);
        // }
    }

    void RefreshCacheBg() {
        startnew(CoroutineFunc(this.RefreshCache));
    }

    void RefreshCache() {
        this.ResetCache();
        for (uint i = 0; i < materialPaths.Length; i++) {
            CacheFolder(Fids::GetGameFolder(materialPaths[i]), ".Material", materialPaths[i]);
            yield();
        }
    }

    void SearchEverywhereYields() {
        this.ResetCache();
        auto game = Fids::GetGameFolder("");
        auto user = Fids::GetUserFolder("");
        auto fake = Fids::GetFakeFolder("");
        auto resource = Fids::GetResourceFolder("");
        auto pgData = Fids::GetProgramDataFolder("");
        if (game !is null) CacheFolder(game, ".Material");
        yield();
        if (user !is null) CacheFolder(user, ".Material");
        yield();
        if (fake !is null) CacheFolder(fake, ".Material");
        yield();
        if (resource !is null) CacheFolder(resource, ".Material");
        yield();
        if (pgData !is null) CacheFolder(pgData, ".Material");
        yield();
    }

    void UpdateAllFidTreesYields() {
        auto game = Fids::GetGameFolder("");
        auto user = Fids::GetUserFolder("");
        auto fake = Fids::GetFakeFolder("");
        auto resource = Fids::GetResourceFolder("");
        auto pgData = Fids::GetProgramDataFolder("");
        if (game !is null) Fids::UpdateTree(game);
        yield();
        if (user !is null) Fids::UpdateTree(user);
        yield();
        if (fake !is null) Fids::UpdateTree(fake);
        yield();
        if (resource !is null) Fids::UpdateTree(resource);
        yield();
        if (pgData !is null) Fids::UpdateTree(pgData);
        yield();
    }
}


MaterialCache@ g_MaterialCache;

namespace Editor {
    void CacheMaterials() {
        if (g_MaterialCache is null) {
            @g_MaterialCache = MaterialCache();
        }
        // Notify("Instantiated materials cache.");
    }
}
