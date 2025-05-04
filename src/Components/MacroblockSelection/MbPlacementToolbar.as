[Setting hidden]
bool S_ShowMbPlacementToolbar = true;

class CurrentMacroblock_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currMbModel;

    CurrentMacroblock_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Macroblock Placement Toolbar", Icons::Wrench, "mbptb");
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
        RegisterSelectedBlockChangedCallback(ProcessNewSelectedMacroblock(this.OnMbChanged), this.tabName);
        RegisterPlacementModeChangedCallback(ProcessNewPlacementMode(this.OnPModeChanged), this.tabName);
    }

    ~CurrentMacroblock_PlacementToolbar() {}

    void OnEditor() {
        this.windowOpen = S_ShowMbPlacementToolbar;
    }

    void ResetCached() {
        @this.currMbModel = null;
    }

    void OnMbChanged(CGameCtnMacroBlockInfo@ mbi) {
        @currMbModel = ReferencedNod(mbi);
    }

    CGameCtnMacroBlockInfo@ get_MacroblockInfo() {
        if (currMbModel is null) return null;
        return currMbModel.AsMacroBlockInfo();
    }

    void OnPModeChanged(CGameEditorPluginMap::EPlaceMode newMode) {
        switch (newMode) {
            case CGameEditorPluginMap::EPlaceMode::Macroblock:
            case CGameEditorPluginMap::EPlaceMode::FreeMacroblock: {
                // do nothing
                break;
            }
            default: {
                // also nothing
            }
        }
    }

    bool ShouldShowWindow(CGameCtnEditorFree@ editor) override {
        return S_ShowMbPlacementToolbar && Editor::IsInMacroblockPlacementMode(editor, false);
    }

    void DrawInner_MainToolbar() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);

        DrawPlaceModeButtons(editor);
        UI::Separator();

        UI::Separator();
        DrawBigSnapButton();
        DrawInfPrecisionButtons();
        DrawLocalRotateButtons(editor);
    }

    bool isAir = false;
    bool isNorm = false;
    bool isCopyPaste = false;

    void DrawPlaceModeButtons(CGameCtnEditorFree@ editor) {
		auto mode = Editor::GetPlacementMode(editor);
		isNorm = mode == CGameEditorPluginMap::EPlaceMode::Macroblock;
		isFree = mode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
		isCopyPaste = mode == CGameEditorPluginMap::EPlaceMode::CopyPaste;
		isAir = IsMbPlaceInAirActive;

		bool cNorm = this.BtnToolbarHalfV(Icons::Cube, "Normal Macroblock Mode", isNorm ? BtnStatus::FeatureActive : BtnStatus::Default);
		bool cFree = this.BtnToolbarHalfV(Icons::Refresh, "Free Macroblock Mode", isFree ? BtnStatus::FeatureActive : BtnStatus::Default);
		bool cAir = this.BtnToolbarHalfV(BtnNameDynamic(isAir ? Icons::Cloud : Icons::Download, "bpt-air"), "Air Macroblock Mode", isAir ? BtnStatus::FeatureActive : BtnStatus::Default);

        if (cNorm) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Macroblock);
        if (cFree) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeMacroblock);
        if (cAir) IsMbPlaceInAirActive = !isAir;
        if (cNorm || cFree) {
            SelectCurrentMacroblock(editor);
        }
    }

    bool get_IsMbPlaceInAirActive() {
        return g_PlaceMacroblockAirModeActive;
    }
    void set_IsMbPlaceInAirActive(bool value) {
        g_PlaceMacroblockAirModeActive = value;
    }

    void SelectCurrentMacroblock(CGameCtnEditorFree@ editor) {
        auto mbi = MacroblockInfo;
        if (mbi is null) return;
        Editor::SetSelectedMacroBlockInfo(editor, mbi);
    }


    /*
    - macroblock: to air/ground
    - reinit model
    - place in air mode
    - show ghost/free in cursor
    - macroblock recording
    - stop or cancel
    - after: keep going or new

    - free: place anywhere, grid, smart rotate
    */

    /*
    - macroblock: to air/ground, reinit model
    */
}
