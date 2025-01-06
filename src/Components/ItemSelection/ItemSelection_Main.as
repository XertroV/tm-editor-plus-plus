class ItemSelectionTab : Tab {
    ItemSelectionTab(TabGroup@ parent) {
        super(parent, "Current Item", Icons::FolderOpenO + Icons::Tree);
        canPopOut = false;
        SetupFav(InvObjectType::Item);
        // child tabs
        ItemPlacementTab(Children);
        ItemLayoutTab(Children);
        ItemCustomLayoutTab(Children);
        TerrainAffinityTab(Children);
        ItemModelBrowserTab(Children);
        // ItemSceneryPlacementTab(Children);
#if SIG_DEVELOPER
        ItemSelection_DevTab(Children);
#endif
    }

    bool get_favEnabled() override property {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.CurrentItemModel !is null;
    }

    string GetFavIdName() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.CurrentItemModel.IdName;
    }

    void DrawInner() override {
        Children.DrawTabs();
    }

    void _HeadingLeft() override {
        Tab::_HeadingLeft();

        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // auto pmt = editor.PluginMapType;
        if (selectedItemModel is null)
            return;

        UI::SameLine();
        CopiableValue(selectedItemModel.AsItemModel().IdName);
    }
}


#if SIG_DEVELOPER
class ItemSelection_DevTab : Tab {
    ItemSelection_DevTab(TabGroup@ p) {
        super(p, "Dev", Icons::ExclamationTriangle);
    }

    CGameItemModel@ GetItemModel() {
        if (selectedItemModel !is null)
            return selectedItemModel.AsItemModel();
        return null;
    }

    void DrawInner() override {
        auto itemModel = GetItemModel();
        if (itemModel is null) {
            UI::Text("Select an item.");
            return;
        }

        if (UI::Button(Icons::Cube + " Explore ItemModel")) {
            ExploreNod(itemModel);
        }

        UI::Separator();

        auto varList = cast<NPlugItem_SVariantList>(itemModel.EntityModel);
        auto prefab = cast<CPlugPrefab>(itemModel.EntityModel);

        if (varList !is null) {
            UI::Text("VariantList: " + varList.Variants.Length);
            for (uint i = 0; i < varList.Variants.Length; i++) {
                if (UI::Button(Icons::Cube + " Explore EntityModel for Variant " + i)) {
                    ExploreNod(varList.Variants[i].EntityModel);
                }
            }
        } else if (prefab !is null) {
            UI::Text("Prefab.Ents: " + prefab.Ents.Length);
            for (uint i = 0; i < prefab.Ents.Length; i++) {
                CPlugStaticObjectModel@ staticmodel = cast<CPlugStaticObjectModel>(prefab.Ents[i].Model);
                if (staticmodel is null) continue;
                CopiableLabeledValue("Solid2Model Ptr ." + i, Text::FormatPointer(Dev::GetOffsetUint64(staticmodel, GetOffset("CPlugStaticObjectModel", "Mesh"))));
            }
        }

        UI::Separator();

        DrawMaterialModifier(itemModel.MaterialModifier);


#if DEV
        UI::Separator();
        if (UI::Button(Icons::Cube + " Explore a new CPlugMaterialUserInst")) {
            auto mui = CPlugMaterialUserInst();
            mui.MwAddRef();
            ExploreNod(mui);
        }

        if (itemModel.Name == "Screen1x1") {
            @prefab = cast<CPlugPrefab>(varList.Variants[0].EntityModel);
            auto som = cast<CPlugStaticObjectModel>(prefab.Ents[0].Model);
            CopiableLabeledValue("Solid2Model Ptr", Text::FormatPointer(Dev::GetOffsetUint64(som, GetOffset("CPlugStaticObjectModel", "Mesh"))));
        }
#endif

    }
}
#endif



class ItemSceneryPlacementTab : Tab {
    ItemSceneryPlacementTab(TabGroup@ parent) {
        super(parent, "Scenery Placement", "");
    }

    void DrawInner() override {
        if (selectedItemModel is null || selectedItemModel.AsItemModel() is null) {
            UI::Text("Select an item");
            return;
        }
        auto itemModel = selectedItemModel.AsItemModel();
        auto varList = cast<NPlugItem_SVariantList>(itemModel.EntityModel);

        if (varList is null) {
            UI::Text("item does not have a list of variants");
            return;
        }

        UI::TextWrapped("");

        if (lastPickedBlock is null || lastPickedBlock.AsBlock() is null) {
            UI::Text("Next, pick a block");
            return;
        }
        auto block = lastPickedBlock.AsBlock();
        auto bi = block.BlockInfo;

        if (bi.MatModifierPlacementTag is null) {
            UI::Text("Block does nod have a scenery placement tag");
            return;
        }

        UI::Text("Add " + block.BlockInfo.IdName + " to variants of " + itemModel.IdName);
        if (UI::Button("Add Block Placement Tag to Variants")) {
            for (uint i = 0; i < varList.Variants.Length; i++) {
                varList.Variants[i].Tags;
            }
            // bi.MatModifierPlacementTag
        }
    }
}



class PlacementClassCopy {
    PlacementClassCopy() {}
    ~PlacementClassCopy() {
        if (PlacementClass !is null) PlacementClass.MwRelease();
    }

    PlacementClassCopy(CGameItemPlacementParam@ placeParams) {
        SetFrom(placeParams);
    }

    void SetFrom(CGameItemPlacementParam@ placeParams) {
        PivotPositions.Resize(0);
        for (uint i = 0; i < placeParams.PivotPositions.Length; i++) {
            PivotPositions.InsertLast(placeParams.PivotPositions[i]);
        }
        SwitchPivotManually = placeParams.SwitchPivotManually;
        FlyStep = placeParams.FlyStep;
        FlyOffset = placeParams.FlyOffset;
        GhostMode = placeParams.GhostMode;
        GridSnap_HStep = placeParams.GridSnap_HStep;
        GridSnap_VStep = placeParams.GridSnap_VStep;
        GridSnap_HOffset = placeParams.GridSnap_HOffset;
        GridSnap_VOffset = placeParams.GridSnap_VOffset;
        PivotSnap_Distance = placeParams.PivotSnap_Distance;
        YawOnly = placeParams.YawOnly;
        NotOnObject = placeParams.NotOnObject;
        AutoRotation = placeParams.AutoRotation;
        Cube_Center = placeParams.Cube_Center;
        Cube_Size = placeParams.Cube_Size;
        // m_PivotPositions.Resize(0);
        PivotRotations.Resize(0);
        for (uint i = 0; i < placeParams.PivotRotations.Length; i++) {
            PivotRotations.InsertLast(placeParams.PivotRotations[i]);
        }
        m_MagnetLocs_Degrees.Resize(0);
        for (uint i = 0; i < placeParams.m_MagnetLocs_Degrees.Length; i++) {
            m_MagnetLocs_Degrees.InsertLast(_TransYawPitchRollDeg(placeParams.m_MagnetLocs_Degrees[i]));
        }
        HasPath = placeParams.HasPath;
        IsFreelyAnchorable = placeParams.IsFreelyAnchorable;
        @PlacementClass = placeParams.PlacementClass;
        PlacementClass.MwAddRef();
    }

    void CopyTo(CGameItemPlacementParam@ placeParams) {
        while (PivotPositions.Length > placeParams.m_PivotPositions.Length) {
            placeParams.m_PivotPositions.Add(PivotPositions[PivotPositions.Length - 1]);
        }
        for (uint i = 0; i < PivotPositions.Length; i++) {
            placeParams.m_PivotPositions[i] = PivotPositions[i];
        }
        placeParams.SwitchPivotManually = SwitchPivotManually;
        placeParams.FlyStep = FlyStep;
        placeParams.FlyOffset = FlyOffset;
        placeParams.GhostMode = GhostMode;
        placeParams.GridSnap_HStep = GridSnap_HStep;
        placeParams.GridSnap_VStep = GridSnap_VStep;
        placeParams.GridSnap_HOffset = GridSnap_HOffset;
        placeParams.GridSnap_VOffset = GridSnap_VOffset;
        placeParams.PivotSnap_Distance = PivotSnap_Distance;
        placeParams.YawOnly = YawOnly;
        placeParams.NotOnObject = NotOnObject;
        placeParams.AutoRotation = AutoRotation;
        placeParams.Cube_Center = Cube_Center;
        placeParams.Cube_Size = Cube_Size;
        // placeParams.m_PivotPositions.Resize(0);
        // placeParams.PivotRotations.RemoveRange(0, placeParams.PivotRotations.Length);
        // for (uint i = 0; i < PivotRotations.Length; i++) {
        //     placeParams.PivotRotations.Add(PivotRotations[i]);
        // }
        // placeParams.m_MagnetLocs_Degrees.RemoveRange(0, placeParams.m_MagnetLocs_Degrees.Length);
        // for (uint i = 0; i < m_MagnetLocs_Degrees.Length; i++) {
        //     placeParams.m_MagnetLocs_Degrees.Add(GmTransYawPitchRollDeg(m_MagnetLocs_Degrees[i]));
        // }
        placeParams.HasPath = HasPath;
        placeParams.IsFreelyAnchorable = IsFreelyAnchorable;
        // @placeParams.PlacementClass = PlacementClass;
        // placeParams.PlacementClass.MwAddRef();
    }

    void ResetCached() {
        PivotPositions.Resize(0);
        SwitchPivotManually = true;
        FlyStep = 1;
        FlyOffset = 0;
        GhostMode = false;
        GridSnap_HStep = 1;
        GridSnap_VStep = 1;
        GridSnap_HOffset = 0;
        GridSnap_VOffset = 0;
        PivotSnap_Distance = 1;
        YawOnly = false;
        NotOnObject = false;
        AutoRotation = false;
        Cube_Center = vec3(0);
        Cube_Size = 1;
        // m_PivotPositions.Resize(0);
        PivotRotations.Resize(0);
        m_MagnetLocs_Degrees.Resize(0);
        HasPath = false;
        IsFreelyAnchorable = false;
        if (PlacementClass !is null) PlacementClass.MwRelease();
        @PlacementClass = null;
    }

    vec3[] PivotPositions;
    bool SwitchPivotManually;
    float FlyStep;
    float FlyOffset;
    bool GhostMode;
    float GridSnap_HStep;
    float GridSnap_VStep;
    float GridSnap_HOffset;
    float GridSnap_VOffset;
    float PivotSnap_Distance;
    bool YawOnly;
    bool NotOnObject;
    bool AutoRotation;
    vec3 Cube_Center;
    float Cube_Size;
    // array<vec3> m_PivotPositions;
    array<quat> PivotRotations;
    array<_TransYawPitchRollDeg> m_MagnetLocs_Degrees;
    bool HasPath;
    bool IsFreelyAnchorable;
    NPlugItemPlacement_SClass@ PlacementClass;
}

class _TransYawPitchRollDeg {
    vec3 t;
    vec3 pyr;

    _TransYawPitchRollDeg() {
        t = vec3(0);
        pyr = vec3(0);
    }

    _TransYawPitchRollDeg(GmTransYawPitchRollDeg@ typr) {
        SetFrom(typr);
    }

    void SetFrom(GmTransYawPitchRollDeg@ typr) {
        t = typr.Trans;
        pitchDeg = typr.PitchDeg;
        yawDeg = typr.YawDeg;
        rollDeg = typr.RollDeg;
    }

    vec3 GetTranslation() {
        return t;
    }
    float x {
        get { return t.x; }
        set { t.x = value; }
    }
    float y {
        get { return t.y; }
        set { t.y = value; }
    }
    float z {
        get { return t.z; }
        set { t.z = value; }
    }
    float pitchDeg {
        get { return Math::ToDeg(pyr.x); }
        set { pyr.x = Math::ToRad(value); }
    }
    float yawDeg {
        get { return Math::ToDeg(pyr.y); }
        set { pyr.y = Math::ToRad(value); }
    }
    float rollDeg {
        get { return Math::ToDeg(pyr.z); }
        set { pyr.z = Math::ToRad(value); }
    }

    mat4 GetRotXZY() {
        return EulerToRotationMatrix(pyr, EulerOrder::XZY);
    }
}
