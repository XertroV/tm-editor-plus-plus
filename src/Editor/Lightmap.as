namespace Editor {
    CHmsLightMap@ GetCurrentLightMap(CGameCtnEditorFree@ editor) {
        auto map = editor.Challenge;
        if (map is null || map.Decoration is null) return null;
        auto mood = map.Decoration.DecoMood;
        if (mood is null || mood.HmsLightMap is null) return null;
        // nod explorer says it's an FID not a CHmsLightMap
        CSystemFidFile@ lmFid = cast<CSystemFidFile>(mood.HmsLightMap);
        if (lmFid is null) return null;
        // if the fid Nod is null, then we are probably using a different lightmap loaded due to the environment / mod
        if (lmFid.Nod is null) {
            auto lmFolder = Fids::GetGameFolder("GameData/LightMap/HmsPackLightMap");
            for (int i = 0; i < lmFolder.Leaves.Length; i++) {
                auto lm = cast<CHmsLightMap>(lmFolder.Leaves[i].Nod);
                if (lm !is null)
                    return lm;
            }
            trace('Could not find loaded LM in folder: ' + lmFolder.FullDirName);
        }
        return cast<CHmsLightMap>(lmFid.Nod);
    }

    NHmsLightMap_SPImp@ GetCurrentLightMapDetails(CGameCtnEditorFree@ editor) {
        CHmsLightMap@ lm = GetCurrentLightMap(editor);
        if (lm is null) return null;
        return lm.m_PImp;
    }

    // cacheSmall goes null on place block/item
}
