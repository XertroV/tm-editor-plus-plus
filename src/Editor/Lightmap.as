namespace Editor {
    CHmsLightMap@ GetCurrentLightMap(CGameCtnEditorFree@ editor) {
        auto map = editor.Challenge;
        auto mood = map.Decoration.DecoMood;
        // nod explorer says it's an FID not a CHmsLightMap
        CSystemFidFile@ lmFid = cast<CSystemFidFile>(mood.HmsLightMap);
        CHmsLightMap@ lm = cast<CHmsLightMap>(lmFid.Nod);
        auto @lm_PImp = lm.m_PImp;
        return lm;
    }

    NHmsLightMap_SPImp@ GetCurrentLightMapDetails(CGameCtnEditorFree@ editor) {
        CHmsLightMap@ lm = GetCurrentLightMap(editor);
        auto @lm_PImp = lm.m_PImp;
        return lm_PImp;
    }

    // cacheSmall goes null on place block/item

}
