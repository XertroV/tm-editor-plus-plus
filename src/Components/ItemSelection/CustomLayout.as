class ItemCustomLayoutTab : Tab {
    ItemCustomLayoutTab(TabGroup@ parent) {
        super(parent, "Custom Layout", "");
        RegisterItemChangedCallback(ProcessNewSelectedItem(this.OnItemChanged));
    }

    bool appliedCustomItemLayout = false;

    CGameItemPlacementParam@ TmpPlacementParam = null;
    CGameItemModel@ TmpItemPlacementReplaced = null;

    string[] SampleGameItemNames = {"Flag8m", "Screen2x1Small", "RoadSign", "Lamp", "LightTubeSmall8m", "TunnelSupportArch8m", "ObstaclePillar2m", "CypressTall", "CactusMedium", "CactusVerySmall", "Spring"};

    void DrawInner() override {
        UI::TextWrapped("Custom items can be used with layouts by temporary replacing the custom item's layout with one from a Nadeo object (e.g., flags, or signs). However, you cannot save the map until the custom item's original layout is restored. Test this in a new map first to get a feel for it since it might be a little dangerous.");
        UI::TextWrapped("\\$4afNote:\\$z The item's original placement options/layouts will be set back to normal automatically when the current item changes.");
        UI::TextWrapped("\\$fa0Warning!\\$z Does not work with embedded items. They must be loaded in the inventory from the game's first start.");
        // UI::TextWrapped("\\$fa0Warning! \\$zGame crashes may occur (though they shouldn't) -- after you are done using this tool, I suggest you save the map and reload it.");
        CGameItemModel@ currentItem = null;
        if (selectedItemModel !is null) {
            @currentItem = selectedItemModel.AsItemModel();
        }
        if (currentItem is null) {
            UI::Text("Choose an item.");
        } else if (TmpPlacementParam is null) {
            UI::AlignTextToFramePadding();
            UI::Text("Replace layout of " + currentItem.IdName);
            for (uint i = 0; i < SampleGameItemNames.Length; i++) {
                if (UI::Button("With layout from " + SampleGameItemNames[i])) {
                    SetCustomPlacementParams(currentItem, SampleGameItemNames[i]);
                }
            }
        } else {
            UI::TextWrapped("Edit the layout in the layout tab and try placing the item on the edge of blocks, etc.");
            if (UI::Button("Restore original layouts")) {
                ResetTmpPlacement();
                appliedCustomItemLayout = true;
            }
            // UI::TextWrapped("\\$fa0 Warning! You MUST click this before changing items or your game will crash!");
        }
    }

    bool OnItemChanged(CGameItemModel@ itemModel) {
        ResetTmpPlacement();
        return false;
    }

    void ResetTmpPlacement() {
        if (TmpPlacementParam !is null && TmpItemPlacementReplaced !is null) {
            trace('resetting temporary item placement');
            @TmpItemPlacementReplaced.DefaultPlacementParam_Content = TmpPlacementParam;
            TmpItemPlacementReplaced.MwRelease();
            TmpPlacementParam.MwRelease();
        }
        @TmpPlacementParam = null;
        @TmpItemPlacementReplaced = null;
    }

    void SetCustomPlacementParams(CGameItemModel@ currentItem, const string &in nadeoItemName) {
        if (TmpPlacementParam !is null) {
            NotifyWarning("Tried to overwrite a tmp placement params! Refusing to do this.");
            return;
        }
        auto item = Editor::FindItemByName(nadeoItemName);
        if (item !is null) {
            @TmpPlacementParam = currentItem.DefaultPlacementParam_Content;
            @TmpItemPlacementReplaced = currentItem;
            TmpItemPlacementReplaced.MwAddRef();
            TmpPlacementParam.MwAddRef();
            @currentItem.DefaultPlacementParam_Content = item.DefaultPlacementParam_Content;
        } else {
            NotifyWarning("Could not find item: " + nadeoItemName);
        }
    }
}
