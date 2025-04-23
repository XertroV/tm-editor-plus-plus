
[Setting hidden]
bool S_ShowItemPlacementToolbar = true;


class CurrentItem_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currItemModel;

    CurrentItem_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Item Placement Toolbar", Icons::Wrench, "iptb");
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterItemChangedCallback(ProcessNewSelectedItem(OnNewItemSelection), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
    }

    ~CurrentItem_PlacementToolbar() {}

    void OnEditor() {
        this.windowOpen = S_ShowItemPlacementToolbar;
        RandomizeVegitationLayouts::OnEditor();
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

    bool ShouldShowWindow(CGameCtnEditorFree@ editor) override {
        return S_ShowItemPlacementToolbar && Editor::IsInAnyItemPlacementMode(editor);
    }

    void DrawInner_MainToolbar() override {
        auto pp = GetCurrPlacementParams();
        if (pp is null) {
            UI::Text("Select an item.");
            return;
        }

        isFree = Editor::GetItemPlacementMode(true, true) == Editor::ItemMode::Free;

        DrawCopyRotsBtn();
        bool toggleItemToBlockSnapping = BtnToolbarHalfV(Icons::Magnet + Icons::Cube + "##itbs", "Item-to-Block Snapping", ActiveToBtnStatus(CustomCursorRotations::ItemSnappingEnabled));
        // bool toggleInfPrec = this.BtnToolbarHalfV("∞" + Icons::MousePointer, "Place Anywhere / Infinite Precision", ActiveFreeToBtnStatus(S_EnableInfinitePrecisionFreeBlocks));

        UI::Separator();

        DrawItemModeButtons();

        UI::Separator();

        bool toggleAutoRotate = BtnToolbar(Icons::Kenney::StickMoveLr + "##ar", "Auto Rotate", ActiveToBtnStatus(pp.AutoRotation));
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
        bool toggleRandomizeVeg = BtnToolbarHalfV(Icons::Random + Icons::Leaf, "Randomize Vegetation Layouts", ActiveToBtnStatus(RandomizeVegitationLayouts::IsActive));

        UI::Separator();

        DrawInfPrecisionButtons();
        DrawLocalRotateButtons();

        // bool flyingStepUp = BtnToolbarHalfH(Icons::AngleUp + "##flyUp", "Increase Flying Step", ActiveToBtnStatus(pp.FlyStep > 0));

        DrawGridOptsPopup(pp);

        if (toggleFlying) ToggleFlying(pp);
        if (toggleRandomizeVeg) RandomizeVegitationLayouts::Toggle();

        if (toggleGridDisable) ToggleGridDisabled(pp);
        if (decrGridSize && !_isGridDisabled) GridDecrease(pp, 1);
        if (incrGridSize && !_isGridDisabled) GridIncrease(pp, 1);
        if (toggleAutoRotate) ToggleAutoRotate(pp);
        if (toggleAutoPivot) ToggleAutoPivot(pp);
        if (toggleItemToBlockSnapping) CustomCursorRotations::ItemSnappingEnabled = !CustomCursorRotations::ItemSnappingEnabled;
        // if (toggleInfPrec) S_EnableInfinitePrecisionFreeBlocks = !S_EnableInfinitePrecisionFreeBlocks;
    }

    bool isFreeGround, isNormal;

    void DrawItemModeButtons() {
        auto itemMode = Editor::GetItemPlacementMode(false, false);
        isFreeGround = itemMode == Editor::ItemMode::FreeGround;
        isNormal = itemMode == Editor::ItemMode::Normal;

        bool cNorm = this.BtnToolbarHalfV(Icons::Cube, "Normal Item Mode", ActiveToBtnStatus(isNormal));
        bool cGround = this.BtnToolbarHalfV(Icons::Download, "Free Ground Item Mode", ActiveToBtnStatus(isFreeGround));
        bool cFree = this.BtnToolbarHalfV(Icons::Refresh, "Free Item Mode", ActiveToBtnStatus(isFree));

        if (cNorm) Editor::SetItemPlacementMode(Editor::ItemMode::Normal);
        if (cGround) Editor::SetItemPlacementMode(Editor::ItemMode::FreeGround);
        if (cFree) Editor::SetItemPlacementMode(Editor::ItemMode::Free);
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

    BtnStatus ActiveFreeToBtnStatus(bool active) {
        return isFree ? (active ? BtnStatus::FeatureActive : BtnStatus::Default) : BtnStatus::Disabled;
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

    void DrawLocalRotateButtons() {
        auto btnStatus = ActiveFreeToBtnStatus(S_CursorSmartRotate);
        bool toggleSmartRot = this.BtnToolbarHalfV("S 90" + DEGREES_CHAR, "Cursor Smart Rotate.\n Rotations are applied locally to current axes (like gizmo).\n Note: these need to fit into the existing cursor rotations, so aren't perfect.", btnStatus);
        if (toggleSmartRot) {
            S_CursorSmartRotate = !S_CursorSmartRotate;
        }
    }

    void DrawCopyRotsBtn() {
        bool toggleCopyRot = this.BtnToolbarHalfV(Icons::FilesO + Icons::Dribbble, "Copy rotations from picked items to the cursor", ActiveToBtnStatus(S_CopyPickedItemRotation));
        if (toggleCopyRot) {
            S_CopyPickedItemRotation = !S_CopyPickedItemRotation;
        }
    }
}


[Setting hidden]
bool S_RandomizeVegitationLayouts = false;

namespace RandomizeVegitationLayouts {
    bool IsActive {
        get { return S_RandomizeVegitationLayouts; }
        set {
            S_RandomizeVegitationLayouts = value;
            Start_UpdateRunRVL();
        }
    }

    void Toggle() {
        IsActive = !IsActive;
    }

    void OnEditor() {
        Start_UpdateRunRVL();
    }

    void Start_UpdateRunRVL() {
        Hook_ItemCursor_SetPZoneId.SetApplied(IsActive);
        // startnew(UpdateRunRVL).WithRunContext(Meta::RunContext::AfterScripts);
    }

    DSceneItemPlacement_SMgr2@ GetItemPlacementMgr(CGameCtnApp@ app) {
        auto mgrPtr = FindPhyMgrPtr(app, CLSID_NSceneItemPlacement_SMgr);
        if (mgrPtr == 0) return null;
        return DSceneItemPlacement_SMgr2(mgrPtr);
    }

    class DSceneItemPlacement_SMgr2 : DSceneItemPlacement_SMgr {
        DSceneItemPlacement_SMgr2(uint64 ptr) {
            super(ptr);
        }

        MemoryIter@ GetZoneIdsIter() {
            auto bufAddr = Ptr + 0x18;
            // +0x8 is like the number of spare entries to use from the start or something?
            auto lenAddr = bufAddr + 0xC;
            auto capAddr = bufAddr + 0x10;
            auto len = Dev::ReadUInt32(lenAddr);
            auto cap = Dev::ReadUInt32(capAddr);
            auto elsAddr = Dev::ReadUInt64(bufAddr);
            return MemoryIter(elsAddr, len, cap).WithSpan(4);
        }

        // get the ID from zone ID list at a given index
        int GetZoneId(int idIx) {
            return GetZoneIdsIter().Skip(idIx).NextUint();
        }

        // find an ID in the list at 0x18
        int FindZoneIdIndex(int id) {
            if (id < 0) return -1;
            auto bufAddr = Ptr + 0x18;
            // +0x8 is like the number of spare entries to use from the start or something?
            auto lenAddr = bufAddr + 0xC;
            auto capAddr = bufAddr + 0x10;
            auto len = Dev::ReadUInt32(lenAddr);
            auto cap = Dev::ReadUInt32(capAddr);
            auto elsAddr = Dev::ReadUInt64(bufAddr);
            if (elsAddr == 0) {
                dev_warn('FindZoneIdIndex: elsAddr == 0');
                return -1;
            }
            if (len == 0) return -1;
            if (len > cap) {
                dev_warn('FindZoneIdIndex: len > cap: ' + len + ' > ' + cap);
                len = cap;
            }
            for (uint ix = 0; ix < len; ix++) {
                auto idAddr = elsAddr + ix * 0x4;
                auto idVal = Dev::ReadUInt32(idAddr);
                if (idVal == id) {
                    return ix;
                }
            }
            dev_warn('FindZoneIdIndex: id not found: ' + id);
            return -1;
        }

        int lastSetPlacementIxRanomized = -1;
        void RandomizePlacement(int zoneIx) {
            if (zoneIx >= 0) {
                auto zone = Zones.GetSZone(zoneIx);
                auto lastSetIx = lastSetPlacementIxRanomized;
                auto nbPlacements = zone.PlacementNb;
                if (nbPlacements > 1) {
                    auto ixWas = zone.PlacementIx;
                    auto newIx = Math::Rand(0, nbPlacements);
                    auto count = 0;
                    while (count < 10 && (ixWas == newIx || (newIx == lastSetIx && nbPlacements > 2))) {
                        newIx = Math::Rand(0, nbPlacements);
                    }
                    if (count == 0) newIx = (ixWas + 1) % nbPlacements;
                    zone.PlacementIx = newIx;
                    lastSetPlacementIxRanomized = newIx;
                    dev_trace('AfterItemCursorPlacementZoneIdUpdated block #'+GetZoneCtnBlockMwId(zone)+' : zoneIx: ' + zoneIx + ' zone.PlacementIx: ' + ixWas + ' -> ' + zone.PlacementIx);
                }
            } else {
                dev_trace('zoneIx < 0: ' + zoneIx);
            }
        }

        int GetZoneCtnBlockMwId(DSceneItemPlacement_SZone@ zone) {
            if (zone is null) return -1;
            auto block = zone.Block;
            if (block is null) return -1;
            return block.Id.Value;
        }
    }

    uint64 FindPhyMgrPtr(CGameCtnApp@ app, uint classId) {
        auto iPhy = Dev::GetOffsetNod(app, O_APP_GAMESCENE + 0x8);
        auto nb = Dev::GetOffsetUint32(iPhy, O_ISCENEVIS_METAMGR);
        // trace("FindMgrPtr: nb = " + nb);
        auto startOffset = O_ISCENEVIS_METAMGR + 0x8;
        auto endOffset = O_ISCENEVIS_METAMGR + 0x8 + nb * 0x10;
        for (uint o = startOffset; o < endOffset; o += 0x10) {
            // auto mgrPtr = Dev::GetOffsetUint64(iPhy, o);
            auto ptr = Dev::GetOffsetUint64(iPhy, o + 0x8);
            if (ptr == 0) continue;
            if (Dev_PointerLooksBad(ptr)) {
                Dev_NotifyWarning("FindMgrPtr: bad pointer " + Text::FormatPointer(ptr));
                continue;
            }
            auto clsId = Dev::ReadUInt32(ptr + 0x10);
            if (clsId == classId) {
                return Dev::GetOffsetUint64(iPhy, o);
            }
        }
        return 0;
    }

    // // offset = 7
    // const string Pattern_SetPZoneId = "0F 29 95 ?? 00 00 00 E8 ?? ?? ?? ?? 48 8D 8D ?? 01 00 00 E8";
    // FunctionHookHelper@ Hook_ItemCursor_SetPZoneId = FunctionHookHelper(
    //     Pattern_SetPZoneId, 7, 0, "RandomizeVegitationLayouts::AfterItemCursorPlacementZoneIdUpdated", Dev::PushRegisters::SSE, false
    // );
    // offset = 0; padding = 1
    const string Pattern_SetPZoneId = "89 9F 88 00 00 00 0F 28 00";
    HookHelper@ Hook_ItemCursor_SetPZoneId = HookHelper(
        Pattern_SetPZoneId, 0, 1, "RandomizeVegitationLayouts::AfterItemCursorPlacementZoneIdUpdated", Dev::PushRegisters::SSE, false
    );


    int lastSbpZoneId = -1;
    // rdi is ItemCursor
    void AfterItemCursorPlacementZoneIdUpdated(uint64 rdi) {
        if (!S_RandomizeVegitationLayouts) {
            dev_warn('AfterItemCursorPlacementZoneIdUpdated but S_RandomizeVegitationLayouts not active');
            return;
        }

        auto app = GetApp();
        // auto editor = cast<CGameCtnEditorFree>(app.Editor);
        // auto sbpZoneId = Editor::GetItemCursorSnappedBlockPlacementZoneId(editor.ItemCursor);
        auto sbpZoneId = Dev::ReadInt32(rdi + O_ITEMCURSOR_SnappedBlockPlacementZoneId);
        if (sbpZoneId >= 0 && sbpZoneId != lastSbpZoneId) {
            lastSbpZoneId = sbpZoneId;
            auto itemPlacementMgr = GetItemPlacementMgr(app);
            auto zoneIx = itemPlacementMgr.GetZoneId(sbpZoneId);
            itemPlacementMgr.RandomizePlacement(zoneIx);
        } else if (sbpZoneId < 0) {
            dev_warn("AfterItemCursorPlacementZoneIdUpdated: sbpZoneId < 0: " + sbpZoneId + " -- but hook only happens after updating with id >= 0");
        }
    }
}


/*

idea: hook the function that writes the placementZoneId to ItemCursor so we can randomize things before the cursor is updated.

Trackmania.exe.text+DE3D5F - F2 0F11 8D E0000000   - movsd [rbp+000000E0],xmm1
Trackmania.exe.text+DE3D67 - 0F29 95 80000000      - movaps [rbp+00000080],xmm2
Trackmania.exe.text+DE3D6E - E8 AD503100           - call Trackmania.exe.text+10F8E20 { set placementZoneId to value
 }
Trackmania.exe.text+DE3D73 - 48 8D 8D D0010000     - lea rcx,[rbp+000001D0]
Trackmania.exe.text+DE3D7A - E8 B17633FF           - call Trackmania.exe.text+11B430
Trackmania.exe.text+DE3D7F - E9 80FCFFFF           - jmp Trackmania.exe.text+DE3A04


F2 0F 11 8D E0 00 00 00
0F 29 95 80 00 00 00
E8 AD 50 31 00
48 8D 8D D0 01 00 00
E8 B1 76 33 FF


0F 29 95 ?? 00 00 00 E8 ?? ?? ?? ?? 48 8D 8D ?? 01 00 00 E8

hmm, this is too late in execution (and the models shown are updated before this)

hook just after the index is updated:
(still sometimes shows an old one for 1 frame, but rare)


Trackmania.exe.text+10F8F3A - 89 9F 88000000        - mov [rdi+00000088],ebx { SET PLACEMENT ZONE ID
 }
Trackmania.exe.text+10F8F40 - 0F28 00               - movaps xmm0,[rax]
Trackmania.exe.text+10F8F43 - F2 0F10 48 10         - movsd xmm1,[rax+10]
Trackmania.exe.text+10F8F48 - 0F11 47 70            - movups [rdi+70],xmm0
Trackmania.exe.text+10F8F4C - F2 0F11 8F 80000000   - movsd [rdi+00000080],xmm1

89 9F 88 00 00 00
0F 28 00
F2 0F 10 48 10
0F 11 47 70
F2 0F 11 8F 80 00 00 00

89 9F 88 00 00 00 0F 28 00
F2 0F 10 48 10
0F 11 47 70
F2 0F 11 8F 80 00 00 00

*/
