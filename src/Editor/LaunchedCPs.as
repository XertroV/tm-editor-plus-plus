namespace Editor {
    CGameSaveLaunchedCheckpoints@ GetLaunchedCPs(CGameCtnEditorFree@ editor) {
        return cast<CGameSaveLaunchedCheckpoints>(Dev_GetOffsetNodSafe(editor, O_EDITOR_LAUNCHEDCPS));
    }
}
