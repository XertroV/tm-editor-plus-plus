class BlockSelectionTab : Tab {
    BlockSelectionTab(TabGroup@ parent) {
        super(parent, "Selected Block", Icons::FolderOpenO + Icons::Cube);
        canPopOut = false;
        // child tabs
        SetGhostVariantTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabsAsList();
    }

    void _HeadingLeft() override {
        Tab::_HeadingLeft();

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;
        bool inGhostMode = pmt.PlaceMode == CGameEditorPluginMap::EPlaceMode::GhostBlock;
        auto bi = inGhostMode ? selectedGhostBlockInfo : selectedBlockInfo;
        if (bi is null)
            return;

        UI::SameLine();
        UI::Text(bi.AsBlockInfo().Name);
    }
}
