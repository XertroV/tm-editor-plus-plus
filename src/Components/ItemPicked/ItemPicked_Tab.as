class FocusedItemTab : Tab, NudgeItemBlock {
    private ReferencedNod@ pinnedItem;

    FocusedItemTab(TabGroup@ parent, const string &in name) {
        super(parent, name, "\\$f44" + Icons::Crosshairs + "\\$z" + Icons::Cube);
        removable = true;
        SetupFav(InvObjectType::Item);
    }

    bool get_favEnabled() override property {
        return FocusedItem !is null && FocusedItem.nod !is null;
    }

    string GetFavIdName() override {
        if (!favEnabled) return "";
        return FocusedItem.AsItem().ItemModel.IdName;
    }

    ReferencedNod@ get_FocusedItem() {
        return pinnedItem;
    }

    void set_FocusedItem(ReferencedNod@ value) {
        @pinnedItem = value;
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

    string nullItemError = "No item.";

    void DrawInner() override {
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (FocusedItem is null || FocusedItem.AsItem() is null || editor is null) {
            UI::Text(nullItemError);
            return;
        }

        UI::Indent();
        UI::TextWrapped("\\$af0 " + Icons::ExclamationTriangle + " \\$iHey!   \\$zWhy not try the new gizmo? (Ctrl+Shift Click on an item)");
        UI::Unindent();

        UI::Separator();

        auto item = FocusedItem.AsItem();

        // if this is true the item was removed from the map
        if (Reflection::GetRefCount(item) == 1) {
            auto refound = Editor::FindReplacementItemAfterUpdate(editor, item);
            @FocusedItem = null;
            if (refound is null)
                return;
            @FocusedItem = ReferencedNod(refound);
            @item = FocusedItem.AsItem();
        }

        vec3 initPos = item.AbsolutePositionInMap;
        vec3 initRot = Editor::GetItemRotation(item);
        auto initColor = item.MapElemColor;
        auto initFlying = item.IsFlying;
        auto initIVar = item.IVariant;

        UI::Columns(2, "pickeditem", false);


        CopiableLabeledValue("Name", item.ItemModel.IdName);
        CopiableLabeledValue("Pos", item.AbsolutePositionInMap.ToString());
        CopiableLabeledValue("P,Y,R (Deg)", MathX::ToDeg(initRot).ToString());
        CopiableLabeledValue("Coord", item.BlockUnitCoord.ToString());
        CopiableLabeledValue("Pivot", Editor::GetItemPivot(item).ToString());

        UI::NextColumn();

#if SIG_DEVELOPER
        // UI::AlignTextToFramePadding();
        if (UX::SmallButton(Icons::Cube + " Explore AnchoredObj##picked")) {
            ExploreNod("Item " + Editor::GetItemUniqueBlockID(item), item);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(item)));
#endif
        if (UX::SmallButton("Edit This Item")) {
            Editor::OpenItemEditor(editor, item);
        }
        if (UX::SmallButton("Edit This Item Model")) {
            Editor::OpenItemEditor(editor, item.ItemModel);
        }

        auto modelFid = GetFidFromNod(item.ItemModel);
        if (UX::SmallButton("Open Item Folder")) {
            try {
                if (modelFid is null) NotifyWarning("Failed to get FID for this item.");
                else if (modelFid.FullFileName.Contains("<virtual>")) NotifyWarning("Cannot open folder for a vanilla item.");
                else OpenExplorerPath(modelFid.ParentFolder.FullDirName);
            } catch {
                NotifyError(getExceptionInfo());
            }
        }
        LabeledValue("Size (KB)", modelFid !is null ? tostring(modelFid.ByteSizeEd) : "?");
        auto mbInstId = Editor::GetItemMbInstId(item);
        LabeledValue("MB Inst ID", mbInstId);
        if (mbInstId >= 0) {
            UI::SameLine();
            if (UX::SmallButton("Clear")) {
                Editor::SetItemMbInstId(item, -1);
            }
        }

        UI::Columns(1);

        // full width
        auto assocBlock = Editor::GetItemsBlockAssociation(item);
        if (assocBlock is null) {
            // UI::SameLine();
            if (UX::SmallButton("Set BlockUnitCoord from Pos")) {
                item.BlockUnitCoord = PosToCoord(item.AbsolutePositionInMap);
            }
        }
        if (assocBlock is null) {
            UI::TextDisabled("No associated block.");
        } else {
            if (UI::CollapsingHeader("Associated Block")) {
                UI::Indent();
                CopiableLabeledValue("Name", assocBlock.BlockInfo.IdName);
                CopiableLabeledValue("Coord", assocBlock.Coord.ToString());
                if (UI::Button("Remove Association")) {
                    Editor::DissociateItem(item);
                }
                UI::Unindent();
            }
        }

        auto bgskin = Editor::GetItemBGSkin(item);
        if (bgskin !is null) {
            ItemModelTreeElement(null, -1, bgskin, "BG Skin", true, O_ANCHOREDOBJ_BGSKIN_PACKDESC).Draw();
        } else {
            UI::TextDisabled("No BG skin");
        }
        auto fgskin = Editor::GetItemFGSkin(item);
        if (fgskin !is null) {
            ItemModelTreeElement(null, -1, fgskin, "FG Skin", true, O_ANCHOREDOBJ_FGSKIN_PACKDESC).Draw();
        } else {
            UI::TextDisabled("No FG skin");
        }

        UI::Separator();

        UI::PushItemWidth(G_GetSmallerInputWidth());

        if (ShowHelpers) {
            nvgCircleWorldPos(item.AbsolutePositionInMap);
            nvg::StrokeColor(vec4(0, 1, 1, 1));
            nvg::StrokeWidth(3);
            nvg::Stroke();
            // nvgCircleWorldPos((Editor::GetItemMatrix(item) * Editor::GetItemPivot(item)).xyz);
            // nvgCircleWorldPos((Editor::GetItemMatrix(item) * mat4::Translate(Editor::GetItemPivot(item)) * vec3(0,0,0)).xyz);
            // nvg::Stroke();
            // nvgCircleWorldPos((Editor::GetItemMatrix(item) * mat4::Translate(Editor::GetItemPivot(item)) * vec3(2, 8, 0)).xyz);
            // nvg::StrokeWidth(3);
            // nvg::Stroke();
            nvgToWorldPos(item.AbsolutePositionInMap);
            nvgDrawCoordHelpers(Editor::GetItemMatrix(item), cursorCoordHelpersSize);
        }

        ShowHelpers = UI::Checkbox("Draw Item Rot Helper", ShowHelpers);
        cursorCoordHelpersSize = UI::InputFloat("Rot Helpers Size", cursorCoordHelpersSize);

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Edit Picked Item Properties (Helper dot shows position)");

        item.AbsolutePositionInMap = UX::InputFloat3("Pos.##picked-item-pos", item.AbsolutePositionInMap);
        item.BlockUnitCoord = UX::InputNat3("Block Coord.##picked-item-coord", item.BlockUnitCoord);

        vec3 outRot = UX::InputAngles3("Rot (Deg)##picked-item-rot", initRot);
        Editor::SetItemRotation(item, outRot);

        item.AnimPhaseOffset = DrawComboEPhaseOffset("Phase", item.AnimPhaseOffset);
        item.MapElemLmQuality = DrawEnumLmQualityChooser(item.MapElemLmQuality);
        item.MapElemColor = DrawEnumColorChooser(item.MapElemColor);

        item.IsFlying = UI::Checkbox("Is Flying", item.IsFlying);
        DrawEditVariants(item);

        auto skipForceRefresh = initColor != item.MapElemColor
            || !MathX::Vec3Eq(initPos, item.AbsolutePositionInMap)
            || !MathX::Vec3Eq(initRot, outRot);

        auto changed = skipForceRefresh
            || initFlying != item.IsFlying
            || initIVar != item.IVariant
            ;


        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Nudge Picked Item:");

        if (DrawNudgeFor(item)) {
            changed = true;
            skipForceRefresh = true;
        }

        if (changed) {
            trace('Updating modified item');
            // @FocusedItem = ReferencedNod(Editor::RefreshSingleItemAfterModified(editor, item, !skipForceRefresh));
            @FocusedItem = ReferencedNod(editor.Challenge.AnchoredObjects[editor.Challenge.AnchoredObjects.Length - 1]);
            @item = FocusedItem.AsItem();
            if (item is null) return;
        }

        UI::Separator();
        if (UI::CollapsingHeader("Relative/Absolute Position Calculator (useful for static respawns) ")) {
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

        UI::PopItemWidth();
    }

    void DrawEditVariants(CGameCtnAnchoredObject@ item) {
        // auto commonItemEntModel = cast<CGameCommonItemEntityModel>(item.ItemModel.EntityModel);
        auto variantList = cast<NPlugItem_SVariantList>(item.ItemModel.EntityModel);
        if (variantList !is null && 0 <= item.IVariant && item.IVariant < variantList.Variants.Length) {
            auto nbVars = variantList.Variants.Length;
            item.IVariant = Math::Clamp(UI::InputInt("Variant", item.IVariant), 0, nbVars - 1);

            auto currVar = variantList.Variants[item.IVariant];
            string fileName = currVar.EntityModelFidForReload !is null ? string(currVar.EntityModelFidForReload.FileName) : "??";

            LabeledValue("Nb Variants", nbVars);
            UI::SameLine();
            LabeledValue("Current", fileName);

            if (UI::CollapsingHeader("Variant Details")) {
                UI::Indent();
                for (uint i = 0; i < variantList.Variants.Length; i++) {
                    DrawVariantInfo(i, variantList.Variants[i]);
                }
                UI::Unindent();
            }
        } else {
            UI::TextDisabled("IVariant: " + item.IVariant);
        }
    }

    void DrawVariantInfo(uint ix, NPlugItem_SVariant@ variant) {
        UI::AlignTextToFramePadding();
        string fileName = variant.EntityModelFidForReload !is null ? string(variant.EntityModelFidForReload.FileName) : "??";
        string msg = fileName + " :: ";
        msg += variant.EntityModel !is null ? Reflection::TypeOf(variant.EntityModel).Name : "null?";
        UI::Text("" + ix + ". " + msg);
        UI::SameLine();
        variant.HiddenInManualCycle = UI::Checkbox("##.HiddenInManualCycle"+fileName, variant.HiddenInManualCycle);
        AddSimpleTooltip(".HiddenInManualCycle");
#if SIG_DEVELOPER
        UI::SameLine();
        if (UI::Button(Icons::Cube+"##variant"+ix)) {
            ExploreNod("Variant", variant.EntityModel);
        }
#endif
    }

    vec3 m_Calc_AbsPosition = vec3();
    vec3 m_Calc_RelPosition = vec3();
}

class PickedItemTab : FocusedItemTab {
    PickedItemTab(TabGroup@ parent) {
        super(parent, "Picked Item");
        removable = false;
        nullItemError = "No picked Item. Ctrl+Hover to pick a Item.";
    }

    bool get_windowOpen() override property {
        if (S_PickedItemWindowOpen == tabOpen) {
            tabOpen = !S_PickedItemWindowOpen;
        }
        return S_PickedItemWindowOpen;
    }

    void set_windowOpen(bool value) override property {
        tabOpen = !value;
        S_PickedItemWindowOpen = value;
    }

    bool get_ShowHelpers() override property {
        return S_DrawPickedItemHelpers;
    }

    void set_ShowHelpers(bool value) override property {
        S_DrawPickedItemHelpers = value;
    }

    ReferencedNod@ get_FocusedItem() override property {
        return lastPickedItem;
    }

    void set_FocusedItem(ReferencedNod@ value) override property {
        @lastPickedItem = value;
        startnew(UpdatePickedItemCachedValues);
    }
}

class PinnedItemTab : FocusedItemTab {
    PinnedItemTab(TabGroup@ parent, CGameCtnAnchoredObject@ Item) {
        super(parent, Item.ItemModel.Name + "@" + Item.AbsolutePositionInMap.ToString());
        @FocusedItem = ReferencedNod(Item);
    }
}
