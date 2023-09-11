class SkinsMainTab : Tab {
    SkinsMainTab(TabGroup@ parent) {
        super(parent, "Skinable", Icons::Television);
        canPopOut = false;
        // child tabs
        SkinnedBlocksTab(Children);
        SkinnedItemsTab(Children);
        (Children);
        (Children);
        (Children);
        // ItemSceneryPlacementTab(Children);
#if SIG_DEVELOPER
        Skinable_DevTab(Children);
#endif
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
        CopiableValue(selectedItemModel.AsItemModel().IdName);
    }
}


class SkinnedBlocksTab : Tab {
    SkinnedBlocksTab(TabGroup@ p) {
        super(p, "Blocks", "");
    }

    void DrawInner() override {
        ;
    }
}


class SkinnedItemsTab : Tab {
    SkinnedItemsTab(TabGroup@ p) {
        super(p, "Items", "");
    }

    void DrawInner() override {
        ;
    }
}



class Skinable_DevTab : Tab {
    Skinable_DevTab(TabGroup@ p) {
        super(p, "Dev", "");
    }

    void DrawInner() override {
        ;
    }
}
