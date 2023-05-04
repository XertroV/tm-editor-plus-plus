class FocusedItemTab : Tab, NudgeItemBlock {
    FocusedItemTab(TabGroup@ parent, const string &in name) {
        super(parent, name, Icons::Crosshairs + Icons::Cube);
        removable = true;
    }

    CGameCtnAnchoredObject@ get_FocusedItem() {
        throw("override me");
        return null;
    }

    private bool showHelpers = true;
    bool get_ShowHelpers() {
        return showHelpers;
    }
    void set_ShowHelpers(bool value) {
        showHelpers = value;
    }

    private bool showItemBox = true;
    bool get_ShowItemBox() {
        return showItemBox;
    }
    void set_ShowItemBox(bool value) {
        showItemBox = value;
    }

    protected bool m_ItemChanged = false;
    float cursorCoordHelpersSize = 10.;

    void DrawInner() override {
        auto item = FocusedItem;
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (item is null || editor is null) {
            UI::Text("No picked Item. Ctrl+Hover to pick a Item.");
            return;
        }

        CopiableLabeledValue("Name", item.ItemModel.IdName);
        CopiableLabeledValue("Pos", item.AbsolutePositionInMap.ToString());
        CopiableLabeledValue("P,Y,R (Rad)", Editor::GetItemRotation(item).ToString());

        LabeledValue("Is Flying", item.IsFlying);
        LabeledValue("Variant", item.IVariant);

        UI::Separator();

        if (ShowHelpers) {
            nvgCircleWorldPos(item.AbsolutePositionInMap);
            nvg::StrokeColor(vec4(0, 1, 1, 1));
            nvg::StrokeWidth(3);
            nvg::Stroke();
            nvgToWorldPos(item.AbsolutePositionInMap);
            nvgDrawCoordHelpers(Editor::GetItemMatrix(item), cursorCoordHelpersSize);
        }

        ShowHelpers = UI::Checkbox("Draw Item Rot Helper", ShowHelpers);
        cursorCoordHelpersSize = UI::InputFloat("Rot Helpers Size", cursorCoordHelpersSize);

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Edit Picked Item Properties (Helper dot shows position)");

        item.AbsolutePositionInMap = UI::InputFloat3("Pos.##picked-item-pos", item.AbsolutePositionInMap);
        Editor::SetItemRotation(item, UX::InputAngles3("Rot (Deg)##picked-item-rot", Editor::GetItemRotation(item)));
        item.MapElemColor = DrawEnumColorChooser(item.MapElemColor);

        if (UI::Button("Refresh All##items")) {
            auto nbRefs = Reflection::GetRefCount(item);
            Editor::RefreshBlocksAndItems(editor);
            if (nbRefs != Reflection::GetRefCount(item)) {
                @lastPickedItem = ReferencedNod(editor.Challenge.AnchoredObjects[editor.Challenge.AnchoredObjects.Length - 1]);
                UpdatePickedItemCachedValues();
                @item = lastPickedItem.AsItem();
            }
        }

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Nudge Picked Item:");

        DrawNudgeFor(item);

        UI::Separator();
        if (UI::CollapsingHeader("Relative/Absolute Position Calculator (useful for static respawns)")) {
            UI::Indent();

            UI::Text("Absolute to Relative");
            m_Calc_AbsPosition = UI::InputFloat3("Abs.", m_Calc_AbsPosition);
            UI::SameLine();
            if (UI::Button("Reset###clac-abs-position")) {
                m_Calc_AbsPosition = vec3();
            }
            auto m = Editor::GetItemMatrix(item);
            vec3 relPos = (mat4::Inverse(m) * m_Calc_AbsPosition).xyz;
            CopiableLabeledValue("Relative Position", relPos.ToString());

            UI::Separator();
            UI::Text("Relative to Absolute");

            m_Calc_RelPosition = UI::InputFloat3("Rel.", m_Calc_RelPosition);
            UI::SameLine();
            if (UI::Button("Reset###clac-rel-position")) {
                m_Calc_RelPosition = vec3();
            }
            vec3 absPos = (m * m_Calc_RelPosition).xyz;
            CopiableLabeledValue("Absolute Position", absPos.ToString());

            UI::Unindent();
        }
    }

    vec3 m_Calc_AbsPosition = vec3();
    vec3 m_Calc_RelPosition = vec3();
}

class PickedItemTab : FocusedItemTab {
    PickedItemTab(TabGroup@ parent) {
        super(parent, "Picked Item");
        removable = false;
    }

    bool get_ShowHelpers() override property {
        return S_DrawPickedItemHelpers;
    }

    void set_ShowHelpers(bool value) override property {
        S_DrawPickedItemHelpers = value;
    }

    CGameCtnAnchoredObject@ get_FocusedItem() override property {
        if (lastPickedItem is null)
            return null;
        return lastPickedItem.AsItem();
    }
}

class PinnedItemTab : FocusedItemTab {
    ReferencedNod@ pinnedItem;

    PinnedItemTab(TabGroup@ parent, CGameCtnAnchoredObject@ Item) {
        super(parent, Item.ItemModel.Name + "@" + Item.AbsolutePositionInMap.ToString());
        @pinnedItem = ReferencedNod(Item);
    }

    CGameCtnAnchoredObject@ get_FocusedItem() override property {
        if (pinnedItem is null)
            return null;
        return pinnedItem.AsItem();
    }
}
