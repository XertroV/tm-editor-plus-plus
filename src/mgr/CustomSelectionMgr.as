class CustomSelectionMgr {
    uint HIST_LIMIT = 10;

    bool active = false;
    array<array<nat3>@> history;
    nat3[]@ latestCoords = {};

    int currentlySelected = -1;

    CustomSelectionMgr() {}

    bool get_IsActive() {
        return active;
    }

    void Enable(vec3 color = vec3(1, .8, .3)) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.PluginMapType.CustomSelectionRGB = color;
        editor.PluginMapType.ShowCustomSelection();
        // startnew(CoroutineFunc(this.WatchLoop));
    }

    // void WatchLoop() {
    //     active = true;
    //     auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    //     while (!UI::IsMouseClicked() && (@editor = cast<CGameCtnEditorFree>(GetApp().Editor) !is null) {
    //         currentlySelected = editor.PluginMapType.CustomSelectionCoords.Length;
    //     }
    // }

    void Disable() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        CacheCustomSelectionCoords(editor.PluginMapType);
        editor.PluginMapType.HideCustomSelection();
        active = false;
    }

    void CacheCustomSelectionCoords(CGameEditorPluginMapMapType@ pmt) {
        nat3[] coords;
        for (uint i = 0; i < pmt.CustomSelectionCoords.Length; i++) {
            coords.InsertLast(pmt.CustomSelectionCoords[i]);
        }
        while (history.Length > HIST_LIMIT) {
            history.RemoveAt(0);
        }
        history.InsertLast(coords);
    }
}

CustomSelectionMgr@ customSelectionMgr = CustomSelectionMgr();
