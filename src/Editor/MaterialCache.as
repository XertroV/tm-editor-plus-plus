class FidCache {
    CSystemFidFile@[] files;

    protected void CacheFolder(CSystemFidsFolder@ folder, const string &in fileExt) {
        for (uint i = 0; i < folder.Leaves.Length; i++) {
            if (folder.Leaves[i].FileName.EndsWith(fileExt)) {
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

class MaterialCache : FidCache {
    MaterialCache() {
        super();
        auto stadium = Fids::GetGameFolder("GameData/Stadium/Media");
        auto stad256 = Fids::GetGameFolder("GameData/Stadium256/Media");
        CacheFolder(stadium, ".Material.Gbx");
        CacheFolder(stad256, ".Material.Gbx");
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
