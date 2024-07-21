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

        UI::Text("Add " + block.DescId.GetName() + " to variants of " + itemModel.IdName);
        if (UI::Button("Add Block Placement Tag to Variants")) {
            for (uint i = 0; i < varList.Variants.Length; i++) {
                varList.Variants[i].Tags;
            }
            // bi.MatModifierPlacementTag
        }
    }
}

const string RMBIcon = " " + Icons::Kenney::MouseRightButton;

[Setting hidden]
bool S_ShowItemPlacementToolbar = true;

class CurrentItem_PlacementToolbar : Tab {
    ReferencedNod@ currItemModel;

    CurrentItem_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Item Placement Toolbar", Icons::Wrench);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterItemChangedCallback(ProcessNewSelectedItem(OnNewItemSelection), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
    }

    ~CurrentItem_PlacementToolbar() {}

    void OnEditor() {
        this.windowOpen = S_ShowItemPlacementToolbar;
    }

    bool OnNewItemSelection(CGameItemModel@ itemModel) {
        if (currItemModel !is null) {
            RestoreOrigPP();
        }
        @currItemModel = ReferencedNod(itemModel);
        _CacheCurrentItemPlacementParams();
        _isFlyingDisabled = false;
        _isGridDisabled = false;
        return false;
    }

    void RestoreOrigPP() {
        if (currItemModel is null) return;
        auto itemModel = currItemModel.AsItemModel();
        if (itemModel is null) return;
        auto @placeParams = itemModel.DefaultPlacementParam_Content;
        if (placeParams is null) return;
        placementClassCopy.CopyTo(placeParams);
    }

    void _CacheCurrentItemPlacementParams() {
        if (currItemModel is null) return;
        auto itemModel = currItemModel.AsItemModel();
        if (itemModel is null) { ResetCached(); return; }
        auto @placeParams = itemModel.DefaultPlacementParam_Content;
        if (placeParams is null) {ResetCached(); return;}
        placementClassCopy.SetFrom(placeParams);
    }

    CGameItemModel@ GetItemModel() {
        if (currItemModel !is null)
            return currItemModel.AsItemModel();
        return null;
    }

    CGameItemPlacementParam@ GetCurrPlacementParams() {
        auto itemModel = GetItemModel();
        if (itemModel is null) return null;
        return itemModel.DefaultPlacementParam_Content;
    }

    PlacementClassCopy placementClassCopy;

    void ResetCached() {
        RestoreOrigPP();
        placementClassCopy.ResetCached();
        @currItemModel = null;
    }

    int get_WindowFlags() override {
        return UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar;
    }

    bool BtnToolbar(const string &in label, const string &in desc, BtnStatus status, vec2 size = vec2()) {
        if (size.LengthSquared() == 0) size = d_ToolbarBtnSize;
        auto hue = BtnStatusHue(status);
        auto click = UI::ButtonColored(label, hue, .6, .6, size);
        if (desc.Length > 0) AddSimpleTooltip(desc, true);
        return click;
    }

    bool BtnToolbarHalfH(const string &in label, const string &in desc, BtnStatus status) {
        float framePad = UI::GetStyleVarVec2(UI::StyleVar::FramePadding).x;
        return BtnToolbar(label, desc, status, vec2(d_ToolbarBtnSize.x * .5 - framePad, d_ToolbarBtnSize.y));
    }

    bool BtnToolbarHalfV(const string &in label, const string &in desc, BtnStatus status) {
        return BtnToolbar(label, desc, status, vec2(d_ToolbarBtnSize.x, d_ToolbarBtnSize.y * .5));
    }

    bool get_windowOpen() override property {
        return S_ShowItemPlacementToolbar
            && Editor::IsInAnyItemPlacementMode(cast<CGameCtnEditorFree>(GetApp().Editor))
            && Tab::get_windowOpen();
    }

    void _BeforeBeginWindow() override {
        UI::SetNextWindowPos(0, 400, UI::Cond::FirstUseEver);
    }

    void DrawInner() override {
        auto pp = GetCurrPlacementParams();
        if (pp is null) {
            UI::Text("Select an item.");
            return;
        }
        bool toggleAutoRotate = BtnToolbar(Icons::Kenney::StickMoveLr + "##ar", "Auto Rotate", ActiveToBtnStatus(pp.AutoRotation));
        bool toggleAutoPivot = BtnToolbar("AP##ap", "Automatically choose item pivot point", ActiveToBtnStatus(!pp.SwitchPivotManually));

        bool toggleGridDisable = BtnToolbarHalfV(Icons::Th + "##gd", "Grid Snap" + RMBIcon, GridDisabledStatus(pp));
        DrawGridOptions_OnRMB(pp);

        bool decrGridSize = BtnToolbarHalfH("[##gd", "Decrease Grid Size" + RMBIcon, GridStepBtnStatus(pp));
        DrawGridOptions_OnRMB(pp);

        UI::PushFont(g_MidFont);
        UI::SameLine();
        bool incrGridSize = BtnToolbarHalfH("]##gi", "Increase Grid Size" + RMBIcon, GridStepBtnStatus(pp));
        DrawGridOptions_OnRMB(pp);
        UI::PopFont();

        UI::AlignTextToFramePadding();
        UI::Text(Text::Format("%.1f", pp.GridSnap_HStep) + ", " + Text::Format("%.1f", pp.GridSnap_VStep));

        bool toggleFlying = BtnToolbarHalfV((pp.FlyStep > 0 ? Icons::Plane : Icons::Tree) + "###flyTog", "Toggle Flying / Lock to Ground", ActiveToBtnStatus(pp.FlyStep > 0));

        // bool flyingStepUp = BtnToolbarHalfH(Icons::AngleUp + "##flyUp", "Increase Flying Step", ActiveToBtnStatus(pp.FlyStep > 0));

        DrawGridOptsPopup(pp);

        if (toggleFlying) ToggleFlying(pp);

        if (toggleGridDisable) ToggleGridDisabled(pp);
        if (decrGridSize && !_isGridDisabled) GridDecrease(pp, 1);
        if (incrGridSize && !_isGridDisabled) GridIncrease(pp, 1);
        if (toggleAutoRotate) ToggleAutoRotate(pp);
        if (toggleAutoPivot) ToggleAutoPivot(pp);
    }

    void DrawGridOptions_OnRMB(CGameItemPlacementParam@ pp) {
        if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right)) {
            UI::OpenPopup("GridOptions");
        }
    }

    void DrawGridOptsPopup(CGameItemPlacementParam@ pp) {
        bool closePopup = false;
        UI::PushFont(g_NormFont);
        if (UI::BeginPopup("GridOptions")) {
            if (UI::Button("Reset Grid")) {
                pp.GridSnap_HStep = placementClassCopy.GridSnap_HStep;
                pp.GridSnap_VStep = placementClassCopy.GridSnap_VStep;
                pp.GridSnap_HOffset = placementClassCopy.GridSnap_HOffset;
                pp.GridSnap_VOffset = placementClassCopy.GridSnap_VOffset;
                _isGridDisabled = false;
            }
            UI::Separator();
            if (UI::MenuItem("Disable Grid", "", _isGridDisabled)) ToggleGridDisabled(pp);
            UI::BeginDisabled(_isGridDisabled);
            pp.GridSnap_HStep = UI::InputFloat("H Step", pp.GridSnap_HStep, 0.1);
            pp.GridSnap_VStep = UI::InputFloat("V Step", pp.GridSnap_VStep, 0.1);
            pp.GridSnap_HOffset = UI::InputFloat("H Offset", pp.GridSnap_HOffset, 0.1);
            pp.GridSnap_VOffset = UI::InputFloat("V Offset", pp.GridSnap_VOffset, 0.1);
            UI::EndDisabled();

            UX::CloseCurrentPopupIfMouseFarAway(closePopup);

            UI::EndPopup();
        }
        UI::PopFont();

    }

    BtnStatus FlyToggleBtnStatus(CGameItemPlacementParam@ pp) {
        return pp.FlyStep > 0 ? BtnStatus::FeatureActive : BtnStatus::Default;
    }

    BtnStatus GridStepBtnStatus(CGameItemPlacementParam@ pp) {
        return _isGridDisabled ? BtnStatus::FeatureBlocked : BtnStatus::Default;
    }

    BtnStatus GridDisabledStatus(CGameItemPlacementParam@ pp) {
        return _isGridDisabled ? BtnStatus::FeatureBlocked : BtnStatus::Default;
    }

    BtnStatus ActiveToBtnStatus(bool active) {
        return active ? BtnStatus::FeatureActive : BtnStatus::Default;
    }

    bool _isFlyingDisabled = false;
    vec2 _disabledFlyingCache = vec2(0);

    void ToggleFlying(CGameItemPlacementParam@ pp) {
        _isFlyingDisabled = pp.FlyStep > 0;
        if (_isFlyingDisabled) {
            _disabledFlyingCache = vec2(pp.FlyStep, pp.FlyOffset);
            pp.FlyStep = 0;
            pp.FlyOffset = 0;
        } else {
            pp.FlyStep = _disabledFlyingCache.x;
            pp.FlyOffset = _disabledFlyingCache.y;
            if (pp.FlyStep <= 0) pp.FlyStep = 1;
        }
    }

    bool _isGridDisabled = false;
    vec4 _disabledGridCache = vec4(0);

    void ToggleGridDisabled(CGameItemPlacementParam@ pp) {
        _isGridDisabled = !_isGridDisabled;
        if (_isGridDisabled) {
            _disabledGridCache = vec4(pp.GridSnap_HStep, pp.GridSnap_VStep, pp.GridSnap_HOffset, pp.GridSnap_VOffset);
            pp.GridSnap_HStep = 0;
            pp.GridSnap_VStep = 0;
            pp.GridSnap_HOffset = 0;
            pp.GridSnap_VOffset = 0;
        } else {
            pp.GridSnap_HStep = _disabledGridCache.x;
            pp.GridSnap_VStep = _disabledGridCache.y;
            pp.GridSnap_HOffset = _disabledGridCache.z;
            pp.GridSnap_VOffset = _disabledGridCache.w;
        }
    }

    void ToggleAutoRotate(CGameItemPlacementParam@ pp) {
        if (!pp.AutoRotation) {
            pp.FlyStep = 0;
            pp.GridSnap_HStep = 0;
            pp.GridSnap_VStep = 0;
        } else {
            pp.FlyStep = placementClassCopy.FlyStep;
            pp.GridSnap_HStep = placementClassCopy.GridSnap_HStep;
            pp.GridSnap_VStep = placementClassCopy.GridSnap_VStep;
        }
        pp.AutoRotation = !pp.AutoRotation;
    }

    void GridIncrease(CGameItemPlacementParam@ pp, float step) {
        while (pp.GridSnap_HStep < step || pp.GridSnap_VStep < step) {
            step *= .5;
            if (step < 0.025) {
                step = 0.025;
                break;
            }
        }
        pp.GridSnap_HStep = Math::Clamp(pp.GridSnap_HStep + step, 0., 320.);
        pp.GridSnap_VStep = Math::Clamp(pp.GridSnap_VStep + step, 0., 320.);
        float maxGSStep = Math::Max(pp.GridSnap_HStep, pp.GridSnap_VStep);
        if (maxGSStep > 0.5) {
            float frac = maxGSStep < 2.0 ? 0.1 : maxGSStep < 4 ? 0.5 : 1.0;
            pp.GridSnap_HStep = Math::Round(pp.GridSnap_HStep / frac) * frac;
            pp.GridSnap_VStep = Math::Round(pp.GridSnap_VStep / frac) * frac;
        }
    }

    void GridDecrease(CGameItemPlacementParam@ pp, float step) {
        while (pp.GridSnap_HStep < step * 2. || pp.GridSnap_VStep < step * 2.) {
            step *= .5;
            if (step < 0.025) {
                step = 0.025;
                break;
            }
        }
        pp.GridSnap_HStep = Math::Clamp(pp.GridSnap_HStep - step, 0., 320.);
        pp.GridSnap_VStep = Math::Clamp(pp.GridSnap_VStep - step, 0., 320.);
    }

    void ToggleAutoPivot(CGameItemPlacementParam@ pp) {
        pp.SwitchPivotManually = !pp.SwitchPivotManually;
    }
}

enum BtnStatus {
    Default,
    FeatureActive,
    FeatureBlocked,
}

float BtnStatusHue(BtnStatus status) {
    switch (status) {
        case BtnStatus::Default: {
            auto d = UI::GetStyleColor(UI::Col::Button);
            return UI::ToHSV(d.x, d.y, d.z).x;
        }
        case BtnStatus::FeatureActive: return 0.3;
        case BtnStatus::FeatureBlocked: return 0.1;
    }
    return 0.5;
}

const vec2 d_ToolbarBtnSize = vec2(48);

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
