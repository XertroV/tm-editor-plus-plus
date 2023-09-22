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
    ReferencedNod@ TmpItemPlacementRef = null;

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

    void DrawInner() override {
        UI::TextWrapped("Custom items can be used with layouts by replacing the custom item's layout with one from a Nadeo object (e.g., flags, or signs).");
        UI::TextWrapped("\\$f80Important!\\$z Once you save the item and return to the editor, you \\$<\\$f80*cannot re-enter the editor, and must restart the game*\\$>. Reloading from disk *might* work, but didn't seem to during testing. Without restarting the game, you will get a crash when loading back into the editor.");
        CGameItemModel@ currentItem = GetItemModel();
        if (currentItem is null) {
            UI::Text(noItemError);
        } else if (TmpItemPlacementRef is null) {
            UI::AlignTextToFramePadding();
            UI::Text("Replace layout of " + currentItem.IdName + " (destination item)");
            UI::AlignTextToFramePadding();
            UI::Text("Choose a source item for the placement layout:");
            auto picked = itemPicker.DrawPrompt();
            if (picked !is null) {
                SetCustomPlacementParams(currentItem, cast<CGameItemModel>(picked.Article.LoadedNod));
            }

            // for (uint i = 0; i < SampleGameItemNames.Length; i++) {
            //     if (UI::Button("With layout from " + SampleGameItemNames[i])) {
            //         SetCustomPlacementParams(currentItem, SampleGameItemNames[i]);
            //     }
            // }
        } else {
            UI::TextWrapped("Layout replaced. Please save the item and return to the main Editor.");
        }
    }

    uint64 fidPointer = 0;

    void SetCustomPlacementParams(CGameItemModel@ currentItem, const string &in nadeoItemName) {
        if (TmpItemPlacementRef !is null) {
            NotifyError("SetCustomPlacementParams called while TmpItemPlacementRef is not null!! Refusing to set placement params.");
            return;
        }
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
        trace('getting tmp item placement ref');
        @TmpItemPlacementRef = ReferencedNod(sourceItem.DefaultPlacementParam_Content);
        trace('add ref to current');
        currentItem.DefaultPlacementParam_Content.MwAddRef();
        trace('set current to other');
        @currentItem.DefaultPlacementParam_Content = sourceItem.DefaultPlacementParam_Content;
        trace('getting fid');
        auto fidPointer = Dev::GetOffsetUint64(currentItem.DefaultPlacementParam_Content, 0x8);
        print("Zeroing Fid: " + Text::FormatPointer(fidPointer));
        Dev::SetOffset(currentItem.DefaultPlacementParam_Content, 0x8, uint64(0));
        NotifyWarning("Item layout successfully replaced. Please save the item.");
        startnew(CoroutineFunc(WaitForLeftItemEditor));
    }

    void WaitForLeftItemEditor() {
        trace("Fixing placement param Fid: waiting to leave Item Editor");
        while (true) {
            yield();
            auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
            if (ieditor is null) break;
        }
        trace("Fixing placement param Fid: Left Item Editor");
        if (TmpItemPlacementRef is null) return;
        trace("Fixing placement param Fid: tmpRef is set");
        auto placementParam = TmpItemPlacementRef.AsPlacementParam();
        if (placementParam is null) return;
        trace("Fixing placement param Fid: got placement param");
        Dev::SetOffset(placementParam, 0x8, fidPointer);
        fidPointer = 0;
        @TmpItemPlacementRef = null;
        trace("Fixing placement param Fid: done");
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
            SAnimFunc_IncrementEasingCountSetDefaults(model, offset);
        }
        if (len > 1 && UI::Button("Remove Last Easing from Chain##"+label)) {
            SAnimFunc_DecrementEasingCount(model, offset);
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

void SAnimFunc_SetIx(NPlugDyna_SKinematicConstraint@ model, uint16 offset, uint8 ix, SubFuncEasings type, bool reverse, uint duration) {
    uint8 len = Dev::GetOffsetUint8(model, offset);
    if (ix > len) throw('out of bounds');
    uint16 arrStartOffset = offset + 4;
    auto sfOffset = arrStartOffset + ix * 0x8;
    Dev::SetOffset(model, sfOffset + 0x0, uint8(type));
    Dev::SetOffset(model, sfOffset + 0x1, reverse ? 0x1 : 0x0);
    Dev::SetOffset(model, sfOffset + 0x4, duration);
}

uint8 SAnimFunc_GetLength(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    return Dev::GetOffsetUint8(model, offset);
}

void SAnimFunc_DecrementEasingCount(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    uint8 len = Dev::GetOffsetUint8(model, offset);
    if (len <= 1) throw ('cannot decrement past 1');
    Dev::SetOffset(model, offset, uint8(len - 1));
}

void SAnimFunc_IncrementEasingCountSetDefaults(NPlugDyna_SKinematicConstraint@ model, uint16 offset) {
    uint8 len = Dev::GetOffsetUint8(model, offset);
    uint8 ix = len;
    auto arrStartOffset = offset + 0x4;
    // 4 maximum otherwise we overwrite other memory.
    if (ix > 3) throw('cannot add more easings.');
    auto sfOffset = arrStartOffset + ix * 0x8;
    // set type, reverse, duration to known values
    Dev::SetOffset(model, sfOffset, uint8(SubFuncEasings::QuadInOut));
    Dev::SetOffset(model, sfOffset + 0x1, uint8(0));
    Dev::SetOffset(model, sfOffset + 0x2, uint16(0));
    Dev::SetOffset(model, sfOffset + 0x4, uint32(7500));
    // finally, write new length
    Dev::SetOffset(model, offset, uint32(len + 1));
}



SubFuncEasings DrawComboSubFuncEasings(const string &in label, SubFuncEasings val) {
    return SubFuncEasings(
        DrawArbitraryEnum(label, int(val), 11, function(int v) {
            return tostring(SubFuncEasings(v));
        })
    );
}

// comment many of these because they don't work

enum SubFuncEasings {
    None = 0,
    Linear = 1,
    QuadIn,
    QuadOut,
    QuadInOut,
    CubicIn,
    CubicOut,
    CubicInOut,
    QuartIn,
    QuartOut,
    QuartInOut,
    // QuintIn,
    // QuintOut,
    // QuintInOut,
    // SineIn,
    // SineOut,
    // SineInOut,
    // ExpIn,
    // ExpOut,
    // ExpInOut,
    // CircIn,
    // CircOut,
    // CircInOut,
    // BackIn,
    // BackOut,
    // BackInOut,
    // ElasticIn,
    // ElasticOut,
    // ElasticInOut,
    // ElasticIn2,
    // ElasticOut2,
    // ElasticInOut2,
    // BounceIn,
    // BounceOut,
    // BounceInOut,
}
