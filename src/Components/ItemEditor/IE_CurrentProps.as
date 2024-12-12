class ItemEditCurrentPropsTab : Tab {
    ItemEditCurrentPropsTab(TabGroup@ p) {
        super(p, "Item Properties", Icons::Tree + Icons::ListAlt);
        ItemEditPlacementTab(Children);
        ItemEditLayoutTab(Children);
        ItemEditCloneLayoutTab(Children);
        ItemEditEntityTab(Children);
        // ItemEditMiscTab(Children);
#if SIG_DEVELOPER
        ItemEditDevTab(Children);
#endif
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

#if SIG_DEVELOPER
class ItemEditDevTab : ItemSelection_DevTab {
    ItemEditDevTab(TabGroup@ p) {
        super(p);
    }

    CGameItemModel@ GetItemModel() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        return ieditor.ItemModel;
    }
}
#endif

class ItemEditPlacementTab : ItemPlacementTab {
    ItemEditPlacementTab(TabGroup@ p) {
        super(p, "Placement", "");
        missingItemError = "Can not find item!? Unexpected since we're in the item editor.";
    }

    CGameItemModel@ GetItemModel() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }
}

class ItemEditLayoutTab : ItemLayoutTab {
    ItemEditLayoutTab(TabGroup@ p) {
        super(p, "Layouts", "");
        noItemError = "Can not find item!? Unexpected since we're in the item editor.";
    }

    CGameItemModel@ GetItemModel() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }
}


class ItemEditCloneLayoutTab : Tab {
    ItemEditCloneLayoutTab(TabGroup@ p) {
        super(p, "Clone Layout From", "");
    }

    CGameItemModel@ GetItemModel() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        return ieditor.ItemModel;
    }

    string noItemError = "missing item!?";

    string[] SampleGameItemNames = {"Flag8m", "Screen1x1", "Screen2x1", "Screen2x1Small", "RoadSign", "Lamp", "LightTubeSmall8m", "TunnelSupportArch8m", "ObstaclePillar2m", "CypressTall", "CactusMedium", "CactusVerySmall"};

    ItemSearcher@ itemPicker = ItemSearcher();

    bool replaceLayout = true;
    bool replacePlacementParams = true;
    bool replacePivotPositions = true;

    void DrawInner() override {
        UI::TextWrapped("Custom items can be used with layouts by replacing the custom item's layout with one from a Nadeo object (e.g., flags, or signs).");
        UI::TextWrapped("\\$f80Important!\\$z Once you save the item and return to the editor, you \\$<\\$f80*cannot re-enter the editor, and must restart the game*\\$>. Reloading from disk *might* work, but didn't seem to during testing. Without restarting the game, you will get a crash when loading back into the editor.");
        CGameItemModel@ currentItem = GetItemModel();

        replaceLayout = UI::Checkbox("Clone Layout?", replaceLayout);
        replacePlacementParams = UI::Checkbox("Copy Placement Params?", replacePlacementParams);
        replacePivotPositions = UI::Checkbox("Copy Pivot Positions?", replacePivotPositions);

        if (currentItem is null) {
            UI::Text(noItemError);
        } else {
            UI::AlignTextToFramePadding();
            if (lastRun + 10000 > Time::Now) {
                UI::TextWrapped("\\$8f4Layout replaced. Please save the item before returning to the main Editor.");
            }
            UI::AlignTextToFramePadding();
            UI::Text("Replace layout of " + currentItem.IdName + " (destination item)");
            UI::AlignTextToFramePadding();
            UI::Text("Choose a source item for the placement layout:");
            auto picked = itemPicker.DrawPrompt();
            if (picked !is null) {
                if (picked.Article.LoadedNod is null) picked.GetCollectorNod();
                SetCustomPlacementParams(currentItem, cast<CGameItemModel>(picked.Article.LoadedNod));
            }
        }
    }

    uint64 fidPointer = 0;
    uint lastRun = 0;

    void SetCustomPlacementParams(CGameItemModel@ currentItem, const string &in nadeoItemName) {
        // if (TmpItemPlacementRef !is null) {
        //     NotifyError("SetCustomPlacementParams called while TmpItemPlacementRef is not null!! Refusing to set placement params.");
        //     return;
        // }
        auto item = Editor::FindItemByName(nadeoItemName);
        if (item is null) {
            NotifyWarning("Could not find item: " + nadeoItemName);
            return;
        }
        SetCustomPlacementParams(currentItem, item);
    }

    void SetCustomPlacementParams(CGameItemModel@ currentItem, CGameItemModel@ sourceItem) {
        if (sourceItem is null) {
            NotifyWarning("Source item for placement params was null");
            return;
        }
        sourceItem.DefaultPlacementParam_Content.MwAddRef();
        @currentItem.DefaultPlacementParam_Content = sourceItem.DefaultPlacementParam_Content;
        MeshDuplication::ZeroFids(sourceItem.DefaultPlacementParam_Content);
        NotifyWarning("Item layout successfully replaced. Please save + reload the item.");
        lastRun = Time::Now;
    }
}

//*/



class ItemEditEntityTab : Tab {
    ItemEditEntityTab(TabGroup@ p) {
        super(p, "Edit Entity", "");
    }

    bool safetyCheck = false;

    void DrawInner() override {
        safetyCheck = UI::Checkbox("Enable this feature?", safetyCheck);
        UI::TextWrapped("This feature can help customize custom moving items. However, note that it uses `Dev::` calls and might be unsafe. Seems okay tho.");
        if (!safetyCheck) return;

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto item = ieditor.ItemModel;
        auto entity = item.EntityModel;

        CPlugPrefab@ prefabEntity = cast<CPlugPrefab>(entity);
        auto variantList = cast<NPlugItem_SVariantList>(entity);
        auto commonItemEntModel = cast<CGameCommonItemEntityModel>(entity);

        if (prefabEntity !is null) {
            DrawPrefabEntity(prefabEntity);
        } else if (variantList !is null) {
            DrawVariantList(variantList);
        } else if (commonItemEntModel !is null) {
            DrawCommonItemEntModel(commonItemEntModel);
        } else {
            UI::Text("Unknown entity type: " + Reflection::TypeOf(entity).Name);
        }
    }

    void DrawPrefabEntity(CPlugPrefab@ prefab) {
        if (prefab.Ents.Length >= 2) {
            auto ent1Model = cast<CPlugDynaObjectModel>(prefab.Ents[0].Model);
            auto ent2Model = cast<NPlugDyna_SKinematicConstraint>(prefab.Ents[prefab.Ents.Length - 1].Model);
            if (ent1Model is null || ent2Model is null) {
                UI::Text("Found DynaObject (Ents[0]): " + (ent1Model !is null));
                UI::Text("Found KinematicConstraints (Ents["+(prefab.Ents.Length - 1)+"]): " + (ent2Model !is null));
                return;
            }
            DrawCPlugDynaObjectModel(ent1Model);
            DrawKinematicConstraint(ent2Model);
        } else {
            UI::Text("not 2+ entities. unsure what to do.");
        }
    }

    void DrawVariantList(NPlugItem_SVariantList@ varList) {
        UI::TextWrapped('Entity type: NPlugItem_SVariantList. Usually these are in-game items so we can\'t do much anyway. Please log a feature request if you want this.');
    }

    void DrawCommonItemEntModel(CGameCommonItemEntityModel@ entity) {
        UI::TextWrapped('Entity type: CGameCommonItemEntityModel. Nothing much interesting to edit here, sorry.');
    }


    void DrawCPlugDynaObjectModel(CPlugDynaObjectModel@ model) {
        // real materials are probs in the Mesh
        // if (model.DynaShape.MaterialIds.Length > 0) {
        //     auto ds = model.DynaShape;
        //     // note, these can be updated from either StaticShape or DynaShape
        //     ds.MaterialIds[0].PhysicId = DrawComboEPlugSurfaceMaterialId("PhysicId", ds.MaterialIds[0].PhysicId);
        //     ds.MaterialIds[0].GameplayId = DrawComboEPlugSurfaceGameplayId("GameplayId", ds.MaterialIds[0].GameplayId);
        // }

        LabeledValue(".WaterModel is null", model.WaterModel is null);
        model.IsStatic = UI::Checkbox("IsStatic", model.IsStatic);
        model.DynamizeOnSpawn = UI::Checkbox("DynamizeOnSpawn", model.DynamizeOnSpawn);
        model.LocAnimIsPhysical = UI::Checkbox("LocAnimIsPhysical", model.LocAnimIsPhysical);
        // model.Mass = UI::InputFloat("Mass", model.Mass);
        // model.LightAliveDurationSc_Min = UI::InputFloat("LightAliveDurationSc_Min", model.LightAliveDurationSc_Min);
        // model.LightAliveDurationSc_Max = UI::InputFloat("LightAliveDurationSc_Max", model.LightAliveDurationSc_Max);
        // if (UI::CollapsingHeader("StaticShape")) {
        //     UI::Indent();
        //     model.DynaShape_BoxSizeX = UI::InputFloat("DynaShape_BoxSizeX", model.DynaShape_BoxSizeX);
        //     model.DynaShape_BoxSizeY = UI::InputFloat("DynaShape_BoxSizeY", model.DynaShape_BoxSizeY);
        //     model.DynaShape_BoxSizeZ = UI::InputFloat("DynaShape_BoxSizeZ", model.DynaShape_BoxSizeZ);
        //     model.StaticShape_BoxSizeX = UI::InputFloat("StaticShape_BoxSizeX", model.StaticShape_BoxSizeX);
        //     model.StaticShape_BoxSizeY = UI::InputFloat("StaticShape_BoxSizeY", model.StaticShape_BoxSizeY);
        //     model.StaticShape_BoxSizeZ = UI::InputFloat("StaticShape_BoxSizeZ", model.StaticShape_BoxSizeZ);
        //     model.StaticShape_AABB.m_Center = UI::InputFloat3("StaticShape_AABB.m_Center", model.StaticShape_AABB.m_Center);
        //     model.StaticShape_AABB.m_HalfDiag = UI::InputFloat3("StaticShape_AABB.m_HalfDiag", model.StaticShape_AABB.m_HalfDiag);
        //     UI::Unindent();
        // }
    }
}

const uint16 transAnimFuncOffset = GetOffset("NPlugDyna_SKinematicConstraint", "TransAnimFunc");
const uint16 rotAnimFuncOffset = GetOffset("NPlugDyna_SKinematicConstraint", "RotAnimFunc");

void DrawKinematicConstraint(NPlugDyna_SKinematicConstraint@ model) {
    DrawSAnimFunc("TransAnimFunc", model, transAnimFuncOffset);

    model.TransAxis = DrawComboEAxis("TransAxis", model.TransAxis);
    model.TransMin = UI::InputFloat("TransMin", model.TransMin);
    model.TransMax = UI::InputFloat("TransMax", model.TransMax);

    DrawSAnimFunc("RotAnimFunc", model, rotAnimFuncOffset);

    model.RotAxis = DrawComboEAxis("RotAxis", model.RotAxis);
    model.AngleMinDeg = UI::InputFloat("AngleMinDeg", model.AngleMinDeg);
    model.AngleMaxDeg = UI::InputFloat("AngleMaxDeg", model.AngleMaxDeg);
}

void DrawSAnimFunc(const string &in label, NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    if (model is null) return;
    uint len = Dev::GetOffsetUint8(model, offset);
    auto arrStartOffset = offset + 0x4;
    if (UI::CollapsingHeader(label + " ("+len+")###" + label + Dev_GetPointerForNod(model))) {
        UI::Indent();
        if (len < 4 && UI::Button("Add New Easing to Chain##"+label)) {
            Notify("Note: you may need to save and re-edit the item for new easings to be loaded.");
            _SAnimFunc_IncrementEasingCountSetDefaults(model, offset);
        }
        if (len > 1 && UI::Button("Remove Last Easing from Chain##"+label)) {
            _SAnimFunc_DecrementEasingCount(model, offset);
        }
        for (uint i = 0; i < len; i++) {
            if (i > 0) UI::Separator();

            auto sfOffset = arrStartOffset + i * 0x8;
            auto type = Dev::GetOffsetUint8(model, sfOffset);
            auto reverse = Dev::GetOffsetUint8(model, sfOffset + 0x1) == 1;
            auto duration = Dev::GetOffsetUint32(model, sfOffset + 0x4);

            type = uint8(DrawComboSubFuncEasings("Easing##"+i+label, SubFuncEasings(type)));
            reverse = UI::Checkbox("Reverse##"+i+label, reverse);
            duration = Math::Clamp(UI::InputInt("Duration##"+i+label, duration), 0, 2000000000);

            Dev::SetOffset(model, sfOffset + 0x0, type);
            Dev::SetOffset(model, sfOffset + 0x1, reverse ? 0x1 : 0x0);
            Dev::SetOffset(model, sfOffset + 0x4, duration);
        }
        UI::Unindent();
    }
}


SubFuncEasings DrawComboSubFuncEasings(const string &in label, SubFuncEasings val) {
    return SubFuncEasings(
        DrawArbitraryEnum(label, int(val), 11, function(int v) {
            return tostring(SubFuncEasings(v));
        })
    );
}
