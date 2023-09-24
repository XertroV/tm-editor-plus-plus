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
        AddSimpleTooltip("Auto-rotate items to match the surface");
        pp_content.GhostMode = UI::Checkbox("GhostMode", pp_content.GhostMode);
        AddSimpleTooltip("Unknown");
        pp_content.IsFreelyAnchorable = UI::Checkbox("IsFreelyAnchorable", pp_content.IsFreelyAnchorable);
        AddSimpleTooltip("Unknown");
        pp_content.YawOnly = UI::Checkbox("YawOnly", pp_content.YawOnly);
        AddSimpleTooltip("In item mode: will only allow yaw to be changed. Note: keeps rotations set before YawOnly is checked -- it's like YawOnly just blocks the inputs to change Pitch and Roll, but doesn't reset prior rotations.");
        pp_content.SwitchPivotManually = UI::Checkbox("SwitchPivotManually", pp_content.SwitchPivotManually);
        AddSimpleTooltip("If true: you need to press Q to change the pivot. Otherwise the game does this automatically, which can be annoying.");

        // pp_content.Cube_Center = UI::InputFloat3("Cube_Center", pp_content.Cube_Center);
        // AddSimpleTooltip("Usually 0,0,0");
        // pp_content.Cube_Size = UI::InputFloat("Cube_Size", pp_content.Cube_Size);
        // AddSimpleTooltip("Unclear if this does anything, often 0");

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);

        int remPivot = -1;
        if (UI::CollapsingHeader("Pivot Positions")) {
            for (uint i = 0; i < pp_content.m_PivotPositions.Length; i++) {
                UI::AlignTextToFramePadding();
                UI::Text("" + i + ". ");
                UI::SameLine();
                UI::SetNextItemWidth(200);
                pp_content.m_PivotPositions[i] = UI::InputFloat3("P. " + i, pp_content.m_PivotPositions[i]);
                if (ieditor !is null) {
                    UI::SameLine();
                    if (UI::Button(Icons::Times + "##del-pp-"+i)) {
                        remPivot = i;
                    }
                }
            }
            if (UI::Button(Icons::Plus + " New##pp")) {
                pp_content.AddPivotPosition();
            }
            UI::SameLine();
            if (UI::Button(Icons::Times + " Last##pp")) {
                pp_content.RemoveLastPivotPosition();
            }
            UI::SameLine();
            if (UI::Button(Icons::Trash + " All##pp")) {
                pp_content.RemoveAllPivotPositions();
            }
            if (UI::Button("AppendPivotPositionsFromMagnets")) {
                pp_content.AppendPivotPositionsFromMagnets();
            }
        }

        // always empty?
        // if (UI::CollapsingHeader("Pivot Rotations")) {
        //     int remPivot = -1;
        //     for (uint i = 0; i < pp_content.PivotRotations.Length; i++) {
        //         auto item = pp_content.PivotRotations[i];
        //         UI::AlignTextToFramePadding();
        //         UI::Text("" + i + ". ");
        //         UI::SameLine();
        //         UI::SetNextItemWidth(200);
        //         pp_content.PivotRotations[i] = UX::InputQuat("R. " + i, pp_content.PivotRotations[i]);
        //         if (ieditor !is null) {
        //             UI::SameLine();
        //             if (UI::Button(Icons::Times + "##del-pp-"+i)) {
        //                 remPivot = i;
        //             }
        //         }
        //     }
        // }
        if (remPivot >= 0 && pp_content.PivotPositions.Length > 0) {
            pp_content.PivotPositions[remPivot] = pp_content.PivotPositions[pp_content.PivotPositions.Length - 1];
            pp_content.RemoveLastPivotPosition();
        }

        int remMag = -1;
        if (UI::CollapsingHeader("Magnet Locations")) {
            for (uint i = 0; i < pp_content.m_MagnetLocs_Degrees.Length; i++) {
                UI::AlignTextToFramePadding();
                UI::Text("" + i + ". ");
                UI::SameLine();
                UI::SetNextItemWidth(200);
                pp_content.m_MagnetLocs_Degrees[i].Trans = UI::InputFloat3("T (x,y,z)   ", pp_content.m_MagnetLocs_Degrees[i].Trans);
                UI::SameLine();
                UI::SetNextItemWidth(200);
                auto angles = MathX::ToRad(vec3(pp_content.m_MagnetLocs_Degrees[i].PitchDeg, pp_content.m_MagnetLocs_Degrees[i].YawDeg, pp_content.m_MagnetLocs_Degrees[i].RollDeg));
                angles = MathX::ToDeg(UX::InputAngles3("R (p,y,r)", angles));
                pp_content.m_MagnetLocs_Degrees[i].PitchDeg = angles.x;
                pp_content.m_MagnetLocs_Degrees[i].YawDeg = angles.y;
                pp_content.m_MagnetLocs_Degrees[i].RollDeg = angles.z;
                if (ieditor !is null) {
                    UI::SameLine();
                    if (UI::Button(Icons::Times + "##del-pp-"+i)) {
                        remMag = i;
                    }
                }
            }
            if (UI::Button(Icons::Plus + "##ml")) {
                pp_content.AddMagnetLoc();
            }
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Back")) {
                pp_content.AddMagnetLoc_Back();
            }
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Down")) {
                pp_content.AddMagnetLoc_Down();
            }
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Front")) {
                pp_content.AddMagnetLoc_Front();
            }
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Left")) {
                pp_content.AddMagnetLoc_Left();
            }
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Right")) {
                pp_content.AddMagnetLoc_Right();
            }
            UI::SameLine();
            if (UI::Button(Icons::Plus + " Up")) {
                pp_content.AddMagnetLoc_Up();
            }

            if (UI::Button(Icons::Times + " Last##ml")) {
                pp_content.RemoveLastMagnetLoc();
            }
            UI::SameLine();
            if (UI::Button(Icons::Trash + " All##ml")) {
                pp_content.RemoveAllMagnetLocs();
            }
        }
        if (remMag >= 0) {
            pp_content.m_MagnetLocs_Degrees[remMag].Trans = pp_content.m_MagnetLocs_Degrees[pp_content.m_MagnetLocs_Degrees.Length - 1].Trans;
            pp_content.m_MagnetLocs_Degrees[remMag].PitchDeg = pp_content.m_MagnetLocs_Degrees[pp_content.m_MagnetLocs_Degrees.Length - 1].PitchDeg;
            pp_content.m_MagnetLocs_Degrees[remMag].YawDeg = pp_content.m_MagnetLocs_Degrees[pp_content.m_MagnetLocs_Degrees.Length - 1].YawDeg;
            pp_content.m_MagnetLocs_Degrees[remMag].RollDeg = pp_content.m_MagnetLocs_Degrees[pp_content.m_MagnetLocs_Degrees.Length - 1].RollDeg;
        }

        // todo: more

        // UI::Text("\\$888Note: possible future additions: PivotPositions, MagnetLocations, PivotRotations (mb deprecated).");
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
