class AutoPlaceItemsTab : Tab {
    AutoPlaceItemsTab(TabGroup@ parent) {
        super(parent, "Auto Place Items", Icons::Database + Icons::Tree);
        ShowNewIndicator = true;
        ShowDevIndicator = true;
        // RegisterSelectedBlockChangedCallback(ProcessNewSelectedBlock(this.OnNewSelectedBlock), tabName);
        // RegisterOnEditorLoadCallback(CoroutineFunc(this.OnLoadEditor), tabName);
    }

    // void OnNewSelectedBlock(CGameCtnBlockInfo@ blockInfo) {
    //     if (!windowOpen) return;
    //     if (blockInfo is null) return;
    //     startnew(CoroutineFunc(RefreshTool));
    // }

    // void OnLoadEditor() {
    //     if (!windowOpen) return;
    //     // this only really does anything for reloading E++ while in the editor
    //     auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    //     auto bi = Editor::GetSelectedBlockInfo(editor);
    //     if (bi !is null) {
    //         // startnew(CoroutineFunc(RefreshTool));
    //     }
    // }

    void DrawInner() override {

    }
}
