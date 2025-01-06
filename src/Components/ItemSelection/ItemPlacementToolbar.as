
[Setting hidden]
bool S_ShowItemPlacementToolbar = true;

class CurrentItem_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currItemModel;

    CurrentItem_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Item Placement Toolbar", Icons::Wrench);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterItemChangedCallback(ProcessNewSelectedItem(OnNewItemSelection), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
        // don't forget window position; needs to be singleton instance
        idNonce = "iptb";
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

    bool get_windowOpen() override property {
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        return S_ShowItemPlacementToolbar
            && editor !is null
            && Editor::IsInAnyItemPlacementMode(editor)
            && app.CurrentPlayground is null
            && Tab::get_windowOpen();
    }

    void _BeforeBeginWindow() override {
        UI::SetNextWindowPos(0, 400, UI::Cond::FirstUseEver);
        UI::SetNextWindowSize(d_ToolbarBtnSize.x, d_ToolbarBtnSize.y, UI::Cond::Appearing);
    }

    void DrawInner() override {
        auto pp = GetCurrPlacementParams();
        if (pp is null) {
            UI::Text("Select an item.");
            return;
        }
        bool toggleAutoRotate = BtnToolbar(Icons::Kenney::StickMoveLr + "##ar", "Auto Rotate", ActiveToBtnStatus(pp.AutoRotation));
        bool toggleItemToBlockSnapping = BtnToolbarHalfV(Icons::Magnet + Icons::Cube + "##itbs", "Item-to-Block Snapping", ActiveToBtnStatus(CustomCursorRotations::ItemSnappingEnabled));
        bool toggleAutoPivot = BtnToolbarHalfV("AP##ap", "Auto-Pivot: Automatically choose item pivot point", ActiveToBtnStatus(!pp.SwitchPivotManually));

        bool toggleGridDisable = BtnToolbarHalfV(Icons::Th + "##gd", "Grid Snap (RMB: Set Grid)" + RMBIcon, GridDisabledStatus(pp));
        DrawGridOptions_OnRMB(pp);

        bool decrGridSize = BtnToolbarHalfH("[##gd", "Decrease Grid Size (RMB: Set Grid)" + RMBIcon, GridStepBtnStatus(pp));
        DrawGridOptions_OnRMB(pp);

        UI::PushFont(g_MidFont);
        UI::SameLine();
        bool incrGridSize = BtnToolbarHalfH("]##gi", "Increase Grid Size (RMB: Set Grid)" + RMBIcon, GridStepBtnStatus(pp));
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
        if (toggleItemToBlockSnapping) CustomCursorRotations::ItemSnappingEnabled = !CustomCursorRotations::ItemSnappingEnabled;
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
