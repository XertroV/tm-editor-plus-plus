class BlockSelectionTab : Tab {
    BlockSelectionTab(TabGroup@ parent) {
        super(parent, "Current Block", Icons::FolderOpenO + Icons::Cube);
        canPopOut = false;
        // child tabs
        SetGhostVariantTab(Children);
        // BlockPlacementTagTab(Children);
        BlockVariantBrowserTab(Children);
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
        CopiableValue(bi.AsBlockInfo().Name);
    }
}




/**
 * This might, after angelscript supports modifying MwSArrays,
 * let us put sprint trees on snow or something, as though they were snow trees.
 */
class BlockPlacementTagTab : Tab {
    // try changing material modifier or placement tag or something
    BlockPlacementTagTab(TabGroup@ parent) {
        super(parent, "Placement Tag", "");
    }

    bool hasPlacement = false;
    NPlugItemPlacement_STag@ ipTag = null;
    NPlugItemPlacement_STag@ tmpIpTag = null;
    CGameCtnBlockInfo@ biFrom = null;
    CGameCtnBlockInfo@ biTo = null;

    void DrawInner() override {
        if (selectedGhostBlockInfo is null) {
            UI::Text("Select a block.");
            return;
        }
        // auto bi = selectedGhostBlockInfo.AsBlockInfo();
        // if (biTo !is null) {
        //     if (UI::Button("Restore Placement")) {
        //         hasPlacement = false;
        //         @biTo.MatModifierPlacementTag = tmpIpTag;
        //         @biTo = null;
        //         @biFrom = null;
        //         @tmpIpTag = null;
        //         @ipTag = null;
        //     }
        // } else if (!hasPlacement) {
        //     UI::Text("Copy placement from " + bi.Name);
        //     if (UI::Button("Copy##placementtag")) {
        //         hasPlacement = true;
        //         @biFrom = bi;
        //         @ipTag = bi.MatModifierPlacementTag;
        //     }
        // } else {
        //     UI::Text("Copy placement to " + bi.Name);
        //     if (UI::Button("Overwrite##placementtag")) {
        //         @tmpIpTag = bi.MatModifierPlacementTag;
        //         @biTo = bi;
        //         @bi.MatModifierPlacementTag = ipTag;
        //     }
        // }
    }
}
