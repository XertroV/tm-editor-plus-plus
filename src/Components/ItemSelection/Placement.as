class ItemPlacementTab : Tab {
    ItemPlacementTab(TabGroup@ parent) {
        super(parent, "Placement", "");
    }

    ItemPlacementTab(TabGroup@ parent, const string &in name, const string &in icon) {
        super(parent, name, icon);
    }

    CGameItemModel@ GetItemModel() {
        if (selectedItemModel is null) {
            return null;
        }
        return selectedItemModel.AsItemModel();
    }

    string missingItemError = "No item selcted.";

    void DrawInner() override {
        auto item = GetItemModel();
        if (item is null) {
            UI::Text(missingItemError);
            return;
        }
        DrawFullPlacementDetails(item);
    }

    void DrawFullPlacementDetails(CGameItemModel@ item) {
        auto pp_content = item.DefaultPlacementParam_Content;
        if (pp_content is null) {
            UI::Text("\\$fb4PlacementParam_Content is null!");
            return;
        }

        // main placement
        DrawMainPlacement(pp_content.PlacementClass, Editor::GetItemNbVariants(item));

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
        pp_content.IsFreelyAnchorable = UI::Checkbox("IsFreelyAnchorable", pp_content.IsFreelyAnchorable);
        AddSimpleTooltip("Unknown");
        pp_content.YawOnly = UI::Checkbox("YawOnly", pp_content.YawOnly);
        AddSimpleTooltip("In item mode: will only allow yaw to be changed. Note: keeps rotations set before YawOnly is checked -- it's like YawOnly just blocks the inputs to change Pitch and Roll, but doesn't reset prior rotations.");

        pp_content.Cube_Center = UI::InputFloat3("Cube_Center", pp_content.Cube_Center);
        AddSimpleTooltip("Usually 0,0,0");
        pp_content.Cube_Size = UI::InputFloat("Cube_Size", pp_content.Cube_Size);
        AddSimpleTooltip("Unclear if this does anything, often 0");

        // todo: more

        UI::Text("\\$888Note: possible future additions: PivotPositions, MagnetLocations, PivotRotations (mb deprecated).");
    }

    void DrawMainPlacement(NPlugItemPlacement_SClass@ pc, uint nbVars) {
        LabeledValue("SizeGroup.Name", pc.SizeGroup.GetName());
        UI::TextWrapped("CompatibleIdGroups: " + CompatibleIdGroupsStr(pc));
        UI::TextWrapped("GroupCurPatchLayouts: " + GroupCurPatchLayoutsStr(pc));
        pc.AlwaysUp = UI::Checkbox("Always Up", pc.AlwaysUp);
        AddSimpleTooltip("When false, the item will be perpendicular to the surface.\nUseful for sloped blocks. (Default: true)");
        pc.AlignToInterior = UI::Checkbox("Align To Interior", pc.AlignToInterior);
        AddSimpleTooltip("When false, the item can be pre-rotated\n(before snapping) to get different alignments.\n(Default: true)");
        pc.AlignToWorldDir = UI::Checkbox("Align To World Dir", pc.AlignToWorldDir);
        AddSimpleTooltip("When true, items will always face this direction. (Default: false)");
        pc.WorldDir = UI::InputFloat3("World Dir", pc.WorldDir);
        AddSimpleTooltip("Vector of the direction to face. Y=Up. (Default: 0,0,1)");
        if (nbVars > 1) {
            pc.CurVariant = Math::Clamp(UI::InputInt("Current Variant", pc.CurVariant), 0, Math::Max(1, nbVars) - 1);
        }
    }

    string GroupCurPatchLayoutsStr(NPlugItemPlacement_SClass@ pc) {
        string ret = "{ ";
        for (uint i = 0; i < pc.GroupCurPatchLayouts.Length; i++) {
            if (i > 0) {
                ret += ", ";
            }
            ret += tostring(pc.GroupCurPatchLayouts[i]);
        }
        ret += " }";
        return ret;
    }

    string CompatibleIdGroupsStr(NPlugItemPlacement_SClass@ pc) {
        string ret = "{ ";
        for (uint i = 0; i < pc.CompatibleIdGroups.Length; i++) {
            if (i > 0) {
                ret += ", ";
            }
            ret += pc.CompatibleIdGroups[i].GetName();
            // ret += "(" + pc.CompatibleIdGroups[i].Value + ", "
            //     + pc.CompatibleIdGroups[i].GetName() + ")";
        }
        ret += " }";
        return ret;
    }

    void DrawMagnetOptions() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        if (UI::CollapsingHeader("Item to Item Snaping (Magnet)")) {
            auto ef = editor.ExperimentalFeatures;
            ef.MagnetSnapDistance = UI::SliderFloat("Item Snap Dist.", ef.MagnetSnapDistance, 0., 64.);
            AddSimpleTooltip("Default: 1.25");
            ef.ShowMagnetsInItemCursor = UI::Checkbox("Show Item Magnet Points", ef.ShowMagnetsInItemCursor);
            AddSimpleTooltip("Similar to block connection indicators for items that snap together.");
        }
    }
}
