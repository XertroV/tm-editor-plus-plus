class ItemSelectionTab : Tab {
    ItemSelectionTab(TabGroup@ parent) {
        super(parent, "Selected Item", Icons::FolderOpenO + Icons::Tree);
        canPopOut = false;
        // child tabs
        ItemPlacementTab(Children);
        ItemLayoutTab(Children);
        ItemCustomLayoutTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabs();
    }

    void _HeadingLeft() override {
        Tab::_HeadingLeft();

        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // auto pmt = editor.PluginMapType;
        if (selectedItemModel is null)
            return;

        UI::SameLine();
        UI::Text(selectedItemModel.AsItemModel().IdName);
    }
}
