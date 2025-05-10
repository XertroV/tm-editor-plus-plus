class BlockSelectionTab : Tab {
    BlockSelectionTab(TabGroup@ parent) {
        super(parent, "Current Block", Icons::FolderOpenO + Icons::Cube);
        canPopOut = false;
        SetupFav(InvObjectType::Block);
        // child tabs
        SetGhostVariantTab(Children);
        // BlockPlacementTagTab(Children);
        BlockVariantBrowserTab(Children);
        NormalBlockModelBrowserTab(Children);
        GhostBlockModelBrowserTab(Children);
        // ClipsInspectorTab(Children);
    }

    bool get_favEnabled() override property {
        auto currBlock = CurrentBlockSelection;
        return currBlock !is null && currBlock.nod !is null;
    }

    string GetFavIdName() override {
        return CurrentBlockSelection.AsBlockInfo().IdName;
    }

    void DrawInner() override {
        Children.DrawTabs();
    }

    ReferencedNod@ get_CurrentBlockSelection() {
        if (IsInGhostMode) {
            return selectedGhostBlockInfo;
        }
        return selectedBlockInfo;
    }

    bool get_IsInGhostMode() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;
        return pmt.PlaceMode == CGameEditorPluginMap::EPlaceMode::GhostBlock;
    }

    void _HeadingLeft() override {
        Tab::_HeadingLeft();

        auto biRef = CurrentBlockSelection;
        if (biRef is null || biRef.AsBlockInfo() is null) {
            UI::Text("No block selected");
            return;
        }
        UI::SameLine();
        CopiableValue(biRef.AsBlockInfo().Name);
    }
}




/**
 * This might, after angelscript supports modifying MwSArrays,
 * let us put spring trees on snow or something, as though they were snow trees.
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
