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
        if (UX::ButtonMbDisabled("Scan Map", SPlacement::initRunning)) {
            startnew(SPlacement::InitCoro);
        }

        UX::StartValuesTable("autop");
        UX::ValuesTableRow("seenBlockInfoIds", SPlacement::seenBlockInfoIds.Length);
        UX::ValuesTableRow("blockInfoIds", SPlacement::blockInfoIds.Length);
        UX::ValuesTableRow("seenMobilIds", SPlacement::seenMobilIds.Length);
        UX::ValuesTableRow("blockToMobilIds", SPlacement::blockToMobilIxs.Length);
        UX::ValuesTableRow("mobilPrefabIds", SPlacement::mobilPrefabIds.Length);
        UX::ValuesTableRow("placements", SPlacement::placements.Length);
        UX::EndValuesTable();

        UI::Separator();

        UX::StartValuesTable("biPlaceNbs", 3);
        for (uint i = 0; i < SPlacement::blockInfoIds.Length; i++) {
            auto bi = SPlacement::blockInfoIds[i];
            // auto placements = SPlacement::GetPlacements(bi);
            UX::ValuesTableRow(MwIdValueToStr(bi), SPlacement::CountPlacements(bi));
            UI::TableNextColumn();
            if (UI::Button("Show Placements##" + i)) {
                OnClickShowPlacements(bi);
            }
        }
        UX::EndValuesTable();
    }

    void OnClickShowPlacements(uint bi) {

    }
}
