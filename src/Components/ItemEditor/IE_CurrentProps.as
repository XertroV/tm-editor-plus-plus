class ItemEditCurrentPropsTab : Tab {
    ItemEditCurrentPropsTab(TabGroup@ p) {
        super(p, "Item Properties", Icons::Tree + Icons::ListAlt);
        ItemEditPlacementTab(Children);
        ItemEditLayoutTab(Children);
        // unable to save these items atm
        // ItemEditCloneLayoutTab(Children);
        ItemEditEntityTab(Children);
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

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

/*

    ! Does not work. Editor complains that it can't save the item.

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

    string[] SampleGameItemNames = {"Flag8m", "Screen2x1Small", "RoadSign", "Lamp", "LightTubeSmall8m", "TunnelSupportArch8m", "ObstaclePillar2m", "CypressTall", "CactusMedium", "CactusVerySmall"};

    void DrawInner() override {
        UI::TextWrapped("Custom items can be used with layouts by replacing the custom item's layout with one from a Nadeo object (e.g., flags, or signs).");
        CGameItemModel@ currentItem = GetItemModel();
        if (currentItem is null) {
            UI::Text(noItemError);
        } else {
            UI::AlignTextToFramePadding();
            UI::Text("Replace layout of " + currentItem.IdName);
            for (uint i = 0; i < SampleGameItemNames.Length; i++) {
                if (UI::Button("With layout from " + SampleGameItemNames[i])) {
                    SetCustomPlacementParams(currentItem, SampleGameItemNames[i]);
                }
            }
        }
    }

    void SetCustomPlacementParams(CGameItemModel@ currentItem, const string &in nadeoItemName) {
        auto item = Editor::FindItemByName(nadeoItemName);
        if (item !is null) {
            @currentItem.DefaultPlacementParam_Content = item.DefaultPlacementParam_Content;
            NotifyWarning("Item layout successfully replaced. Please save the item.");
        } else {
            NotifyWarning("Could not find item: " + nadeoItemName);
        }
    }
}

*/



class ItemEditEntityTab : Tab {
    ItemEditEntityTab(TabGroup@ p) {
        super(p, "Entity", "");
    }

    void DrawInner() override {
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
        if (prefab.Ents.Length == 2) {
            auto ent1Model = cast<CPlugDynaObjectModel>(prefab.Ents[0].Model);
            auto ent2Model = cast<NPlugDyna_SKinematicConstraint>(prefab.Ents[1].Model);
            DrawCPlugDynaObjectModel(ent1Model);
            DrawKinematicConstraint(ent2Model);
        } else {
            UI::Text("not 2 entities. unsure what to do.");
        }
    }

    void DrawVariantList(NPlugItem_SVariantList@ varList) {
        UI::Text('todo');
    }

    void DrawCommonItemEntModel(CGameCommonItemEntityModel@ entity) {
        UI::Text('todo');
    }


    void DrawCPlugDynaObjectModel(CPlugDynaObjectModel@ model) {
        if (model.DynaShape.MaterialIds.Length > 0) {
            auto ds = model.DynaShape;
            // note, these can be updated from either StaticShape or DynaShape
            ds.MaterialIds[0].PhysicId = DrawComboEPlugSurfaceMaterialId("PhysicId", ds.MaterialIds[0].PhysicId);
            ds.MaterialIds[0].GameplayId = DrawComboEPlugSurfaceGameplayId("GameplayId", ds.MaterialIds[0].GameplayId);
        }


        LabeledValue(".WaterModel is null", model.WaterModel is null);
        model.IsStatic = UI::Checkbox("IsStatic", model.IsStatic);
        model.DynamizeOnSpawn = UI::Checkbox("DynamizeOnSpawn", model.DynamizeOnSpawn);
        model.LocAnimIsPhysical = UI::Checkbox("LocAnimIsPhysical", model.LocAnimIsPhysical);
        model.Mass = UI::InputFloat("Mass", model.Mass);
        model.LightAliveDurationSc_Min = UI::InputFloat("LightAliveDurationSc_Min", model.LightAliveDurationSc_Min);
        model.LightAliveDurationSc_Max = UI::InputFloat("LightAliveDurationSc_Max", model.LightAliveDurationSc_Max);
        if (UI::CollapsingHeader("StaticShape")) {
            UI::Indent();
            model.DynaShape_BoxSizeX = UI::InputFloat("DynaShape_BoxSizeX", model.DynaShape_BoxSizeX);
            model.DynaShape_BoxSizeY = UI::InputFloat("DynaShape_BoxSizeY", model.DynaShape_BoxSizeY);
            model.DynaShape_BoxSizeZ = UI::InputFloat("DynaShape_BoxSizeZ", model.DynaShape_BoxSizeZ);
            model.StaticShape_BoxSizeX = UI::InputFloat("StaticShape_BoxSizeX", model.StaticShape_BoxSizeX);
            model.StaticShape_BoxSizeY = UI::InputFloat("StaticShape_BoxSizeY", model.StaticShape_BoxSizeY);
            model.StaticShape_BoxSizeZ = UI::InputFloat("StaticShape_BoxSizeZ", model.StaticShape_BoxSizeZ);
            model.StaticShape_AABB.m_Center = UI::InputFloat3("StaticShape_AABB.m_Center", model.StaticShape_AABB.m_Center);
            model.StaticShape_AABB.m_HalfDiag = UI::InputFloat3("StaticShape_AABB.m_HalfDiag", model.StaticShape_AABB.m_HalfDiag);
            UI::Unindent();
        }
    }

    uint16 transAnimFuncOffset = GetOffset("NPlugDyna_SKinematicConstraint", "TransAnimFunc");
    uint16 rotAnimFuncOffset = GetOffset("NPlugDyna_SKinematicConstraint", "RotAnimFunc");

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
        uint len = Dev::GetOffsetUint32(model, offset);
        auto arrStartOffset = offset + 0x4;
        if (UI::CollapsingHeader(label + " ("+len+")")) {
            UI::Indent();
            if (len < 4 && UI::Button("Add New Easing to Chain##"+label)) {
            }
            for (uint i = 0; i < len; i++) {
                if (i > 0) UI::Separator();

                auto sfOffset = arrStartOffset + i * 0x8;
                auto type = Dev::GetOffsetUint8(model, sfOffset);
                auto reverse = Dev::GetOffsetUint8(model, sfOffset + 0x1) == 1;
                auto duration = Dev::GetOffsetUint32(model, sfOffset + 0x4);

                type = uint8(DrawComboSubFuncEasings("Easing##"+i+label, SubFuncEasings(type)));
                reverse = UI::Checkbox("Reverse##"+i+label, reverse);
                duration = Math::Clamp(UI::InputInt("Duration##"+i+label, duration), 50, 10000000000);

                Dev::SetOffset(model, sfOffset + 0x0, type);
                Dev::SetOffset(model, sfOffset + 0x1, reverse ? 0x1 : 0x0);
                Dev::SetOffset(model, sfOffset + 0x4, duration);
            }
            UI::Unindent();
        }
    }
}


SubFuncEasings DrawComboSubFuncEasings(const string &in label, SubFuncEasings val) {
    return SubFuncEasings(
        DrawArbitraryEnum(label, int(val), 35, function(int v) {
            return tostring(SubFuncEasings(v));
        })
    );
}

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
    QuintIn,
    QuintOut,
    QuintInOut,
    SineIn,
    SineOut,
    SineInOut,
    ExpIn,
    ExpOut,
    ExpInOut,
    CircIn,
    CircOut,
    CircInOut,
    BackIn,
    BackOut,
    BackInOut,
    ElasticIn,
    ElasticOut,
    ElasticInOut,
    ElasticIn2,
    ElasticOut2,
    ElasticInOut2,
    BounceIn,
    BounceOut,
    BounceInOut,
}
