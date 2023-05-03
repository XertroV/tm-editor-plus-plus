class ItemPlacementTab : Tab {
    ItemPlacementTab(TabGroup@ parent) {
        super(parent, "Placement", "");
    }

    void DrawInner() override {
        if (selectedItemModel is null) {
            UI::Text("no selcted item");
            return;
        }
        auto curr = selectedItemModel.AsItemModel();
        auto pp_content = curr.DefaultPlacementParam_Content;
        if (pp_content is null) {
            UI::Text("\\$fb4PlacementParam_Content is null!");
            return;
        }

        // main placement
        DrawMainPlacement(pp_content.PlacementClass);

        DrawMagnetOptions();

        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("General Placement Params");
        pp_content.GridSnap_HStep = UI::InputFloat("GridSnap_HStep", pp_content.GridSnap_HStep, 0.01);
        AddSimpleTooltip("Decrease to make item placement more precise in the XZ plane. \\$s\\$fb0Item Mode Only!\\$z\nDefault: 1.0 (usually).");
        pp_content.GridSnap_VStep = UI::InputFloat("GridSnap_VStep", pp_content.GridSnap_VStep, 0.01);
        AddSimpleTooltip("Unknown or untested.\n Default?: 0.0 (some items may differ)");
        pp_content.GridSnap_HOffset = UI::InputFloat("GridSnap_HOffset", pp_content.GridSnap_HOffset, 0.01);
        AddSimpleTooltip("Unknown or untested.\n Default?: 0.0 (some items may differ)");
        pp_content.GridSnap_VOffset = UI::InputFloat("GridSnap_VOffset", pp_content.GridSnap_VOffset, 0.01);
        AddSimpleTooltip("Unknown or untested.\n Default?: 0.0 (some items may differ)");
        pp_content.PivotSnap_Distance = UI::InputFloat("PivotSnap_Distance", pp_content.PivotSnap_Distance, 0.01);
        AddSimpleTooltip("Unknown or untested.\n Defaults?: -1.0, 0.0 (some items may differ)");
        pp_content.FlyStep = UI::InputFloat("FlyStep", pp_content.FlyStep, 0.01);
        AddSimpleTooltip("In item mode: When <= 0, the item will lock to the ground. When > 0, it's how far each scroll up/down input moves you up/down.");
        pp_content.FlyOffset = UI::InputFloat("FlyOffset", pp_content.FlyStep, 0.01);
        AddSimpleTooltip("Unknown");
        pp_content.AutoRotation = UI::Checkbox("AutoRotation", pp_content.AutoRotation);
        AddSimpleTooltip("Unknown");
        pp_content.GhostMode = UI::Checkbox("GhostMode", pp_content.GhostMode);
        AddSimpleTooltip("Unknown");
        pp_content.YawOnly = UI::Checkbox("YawOnly", pp_content.YawOnly);
        AddSimpleTooltip("In item mode: will only allow yaw to be changed. Note: keeps rotations set before YawOnly is checked -- it's like YawOnly just blocks the inputs to change Pitch and Roll, but doesn't reset prior rotations.");

        // todo: more

        UI::Text("\\$888Note: still more properties can be added.");
    }

    void DrawMainPlacement(NPlugItemPlacement_SClass@ pc) {
        pc.AlwaysUp = UI::Checkbox("Always Up", pc.AlwaysUp);
        AddSimpleTooltip("When false, the item will be perpendicular to the surface.\nUseful for sloped blocks. (Default: true)");
        pc.AlignToInterior = UI::Checkbox("Align To Interior", pc.AlignToInterior);
        AddSimpleTooltip("When false, the item can be pre-rotated\n(before snapping) to get different alignments.\n(Default: true)");
        pc.AlignToWorldDir = UI::Checkbox("Align To World Dir", pc.AlignToWorldDir);
        AddSimpleTooltip("When true, items will always face this direction. (Default: false)");
        pc.WorldDir = UI::InputFloat3("World Dir", pc.WorldDir);
        AddSimpleTooltip("Vector of the direction to face. Y=Up. (Default: 0,0,1)");
    }

    void DrawMagnetOptions() {
        if (UI::CollapsingHeader("Item to Item Snaping")) {
            auto ef = cast<CGameCtnEditorFree>(GetApp().Editor).ExperimentalFeatures;
            ef.MagnetSnapDistance = UI::SliderFloat("Item Snap Dist.", ef.MagnetSnapDistance, 0., 64.);
            AddSimpleTooltip("Default: 1.25");
            ef.ShowMagnetsInItemCursor = UI::Checkbox("Show Item Magnet Points", ef.ShowMagnetsInItemCursor);
            AddSimpleTooltip("Similar to block connection indicators for items that snap together.");
        }
    }
}
