[Setting hidden]
bool S_ShowBlockPlacementToolbar = true;

class CurrentBlock_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currBlockModel;

    CurrentBlock_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Block Placement Toolbar", Icons::Wrench, "bptb");
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
        RegisterSelectedBlockChangedCallback(ProcessNewSelectedBlock(this.OnBlockChanged), this.tabName);
        RegisterPlacementModeChangedCallback(ProcessNewPlacementMode(this.OnPModeChanged), this.tabName);
    }

    ~CurrentBlock_PlacementToolbar() {}

    void OnEditor() {
        this.windowOpen = S_ShowBlockPlacementToolbar;
    }

    void ResetCached() {
        @this.currBlockModel = null;
    }

    void OnBlockChanged(CGameCtnBlockInfo@ bi) {
        @currBlockModel = ReferencedNod(bi);
    }

    CGameCtnBlockInfo@ get_BlockInfo() {
        if (currBlockModel is null) return null;
        return currBlockModel.AsBlockInfo();
    }

    void OnPModeChanged(CGameEditorPluginMap::EPlaceMode newMode) {
        switch (newMode) {
            case CGameEditorPluginMap::EPlaceMode::Block:
            case CGameEditorPluginMap::EPlaceMode::GhostBlock:
            case CGameEditorPluginMap::EPlaceMode::FreeBlock: {
                // do nothing
                break;
            }
            default: {
                ResetBigSnap();
            }
        }
    }

    bool ShouldShowWindow(CGameCtnEditorFree@ editor) override {
        return S_ShowBlockPlacementToolbar && Editor::IsInBlockPlacementMode(editor, true);
    }

    void DrawInner_MainToolbar() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        DrawCopyRotationsButton(editor);
        UI::Separator();
        DrawPlaceModeButtons(editor);
        UI::Separator();
        DrawForcedVariantButtons(editor);
        UI::Separator();
        DrawBigSnapButton();
        DrawInfPrecisionButtons();
        DrawLocalRotateButtons(editor);

    }

    void DrawCopyRotationsButton(CGameCtnEditorFree@ editor) {
        bool active = S_CopyPickedBlockRotation;
        bool toggleCopyRot = this.BtnToolbarHalfV(Icons::FilesO + Icons::Dribbble, "Copy rotations from picked blocks to the cursor", active ? BtnStatus::FeatureActive : BtnStatus::Default);
        if (toggleCopyRot) {
            S_CopyPickedBlockRotation = !active;
        }
    }

    bool isNorm;
    bool isGhost;
    // bool isFree;
    bool isAir;

    void DrawPlaceModeButtons(CGameCtnEditorFree@ editor) {
        auto mode = Editor::GetPlacementMode(editor);
        isNorm = mode == CGameEditorPluginMap::EPlaceMode::Block;
        isGhost = mode == CGameEditorPluginMap::EPlaceMode::GhostBlock;
        isFree = mode == CGameEditorPluginMap::EPlaceMode::FreeBlock;
        isAir = Editor::GetIsBlockAirModeActive(editor);

        bool cNorm = this.BtnToolbarHalfV(Icons::Cube, "Normal Block Mode", isNorm ? BtnStatus::FeatureActive : BtnStatus::Default);
        bool cGhost = this.BtnToolbarHalfV(Icons::SnapchatGhost, "Ghost Block Mode", isGhost ? BtnStatus::FeatureActive : BtnStatus::Default);
        bool cFree = this.BtnToolbarHalfV(Icons::Refresh, "Free Block Mode", isFree ? BtnStatus::FeatureActive : BtnStatus::Default);
        bool cAir = this.BtnToolbarHalfV(BtnNameDynamic(isAir ? Icons::Cloud : Icons::Download, "bpt-air"), "Air Block Mode", isAir ? BtnStatus::FeatureActive : BtnStatus::Default);


        if (cNorm) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Block);
        if (cGhost) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::GhostBlock);
        if (cFree) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
        if (cAir) Editor::SetIsBlockAirModeActive(editor, !isAir);
        if (cNorm || cGhost || cFree) {
            SelectCurrentBlock(editor);
        }
    }

    bool _forcedVarEnabled = false;
    int _forcedVarIndex = -1;
    bool _forcedGround = false;
    void DrawForcedVariantButtons(CGameCtnEditorFree@ editor) {
        _forcedVarEnabled = int(editor.GhostBlockForcedVariantIndex) >= 0;
        auto gVar = _forcedVarEnabled && _forcedGround ? _forcedVarIndex : -1;
        auto aVar = _forcedVarEnabled && !_forcedGround ? _forcedVarIndex : -1;
        bool modeValid = Editor::IsInGhostOrFreeBlockPlacementMode(editor);
        auto gLabel = gVar > -1 ? "G:"+gVar+"###cy-gv" : "G###cy-gv";
        auto aLabel = aVar > -1 ? "A:"+aVar+"###cy-av" : "A###cy-av";

        bool toggleForcedV = this.BtnToolbarHalfV(Icons::ExclamationTriangle + Icons::ListUl, "Force variant for the current block. Ghost/Free only.", ForcedVarBtnStatus(editor));
        bool cycleGroundVar = this.BtnToolbarQ(gLabel, "Cycle Ground Variant", ForcedVarCycleBtnStatus(editor, true));
        bool cycleAirVar = this.BtnToolbarQ(aLabel, "Cycle Air Variant", ForcedVarCycleBtnStatus(editor, false), true);

        if (modeValid && toggleForcedV) ToggleForcedVar(editor);
        if (modeValid && cycleAirVar) SetForcedVar(editor, false, aVar + 1);
        if (modeValid && cycleGroundVar) SetForcedVar(editor, true, gVar + 1);
    }

    void ToggleForcedVar(CGameCtnEditorFree@ editor) {
        _forcedVarEnabled = !_forcedVarEnabled;
        if (_forcedVarEnabled) {
            editor.GhostBlockForcedVariantIndex = 0;
            editor.GhostBlockForcedGroundElseAir = _forcedGround;
        } else {
            editor.GhostBlockForcedVariantIndex = -1;
            // reselect current block to reset
            SelectCurrentBlock(editor);
        }
    }

    void SelectCurrentBlock(CGameCtnEditorFree@ editor) {
        dev_trace("Setting selected block to " + BlockInfo.Name);
        auto inv = Editor::GetInventoryCache();
        auto article = inv.GetBlockByName(BlockInfo.IdName);
        if (article !is null) {
            Editor::SetSelectedInventoryNode(editor, article, false);
        }
    }

    void SetForcedVar(CGameCtnEditorFree@ editor, bool ground, int index) {
        auto bi = BlockInfo;
        auto nbVars = Editor::GetNbBlockVariants(bi, ground);
        if (nbVars <= 0) {
            NotifyWarning("No " +(ground ? "ground" : "air")+ " variants for block " + bi.Name);
            return;
        }
        _forcedVarEnabled = true;
        _forcedVarIndex = index % nbVars;
        _forcedGround = ground;
        editor.GhostBlockForcedVariantIndex = _forcedVarIndex;
        editor.GhostBlockForcedGroundElseAir = ground;
    }

    BtnStatus ForcedVarBtnStatus(CGameCtnEditorFree@ editor) {
        if (Editor::IsInGhostOrFreeBlockPlacementMode(editor))
            return _forcedVarEnabled ? BtnStatus::FeatureActive : BtnStatus::Default;
        return BtnStatus::Disabled;
    }

    BtnStatus ForcedVarCycleBtnStatus(CGameCtnEditorFree@ editor, bool ground) {
        if (Editor::IsInGhostOrFreeBlockPlacementMode(editor))
            return _forcedVarEnabled && _forcedGround == ground ? BtnStatus::FeatureActive : BtnStatus::Default;
        return BtnStatus::Disabled;
    }

    bool _bigSnapActive = false;
    void ResetBigSnap() {
        CustomCursor::ResetSnapRadius();
        _bigSnapActive = false;
    }
    void ToggleBigSnap() {
        _bigSnapActive = !_bigSnapActive;
        if (_bigSnapActive) {
            float sr;
            while ((sr = CustomCursor::GetCurrentSnapRadius()) < 32.0) {
                CustomCursor::StepFreeBlockSnapRadius(true, sr < 31.5);
            }
        } else {
            ResetBigSnap();
        }
    }

    void DrawBigSnapButton() {
        auto btnStatus = isFree ? (_bigSnapActive ? BtnStatus::FeatureActive : BtnStatus::Default) : BtnStatus::Disabled;
        bool bigSnap = this.BtnToolbar(Icons::Expand + Icons::Magnet, "Big Snap for free blocks", btnStatus);
        if (bigSnap) ToggleBigSnap();
    }

    void DrawLocalRotateButtons(CGameCtnEditorFree@ editor) {
        auto btnStatus = FreeButtonStatusActive(S_CursorSmartRotate);
        bool toggleSmartRot = this.BtnToolbarHalfV("S 90" + DEGREES_CHAR, "Cursor Smart Rotate.\n Rotations are applied locally to current axes (like gizmo).\n Note: these need to fit into the existing cursor rotations, so aren't perfect.", btnStatus);
        if (toggleSmartRot) {
            S_CursorSmartRotate = !S_CursorSmartRotate;
        }
    }

    BtnStatus FreeButtonStatusActive(bool active) {
        return isFree ? (active ? BtnStatus::FeatureActive : BtnStatus::Default) : BtnStatus::Disabled;
    }

    /*
    - Ghost/free - force variant
    - Rotate free block in cursor 90 degrees

    */

    /*
    - macroblock: to air/ground, reinit model
    */
}
