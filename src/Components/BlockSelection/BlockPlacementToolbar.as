[Setting hidden]
bool S_ShowBlockPlacementToolbar = true;

class CurrentBlock_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currBlockModel;

    CurrentBlock_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Block Placement Toolbar", Icons::Wrench, "bptb");
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
        RegisterSelectedBlockChangedCallback(ProcessNewSelectedBlock(this.OnBlockChanged), this.tabName);
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

    bool ShouldShowWindow(CGameCtnEditorFree@ editor) override {
        return S_ShowBlockPlacementToolbar && Editor::IsInBlockPlacementMode(editor, true);
    }

    void DrawInner_MainToolbar() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        DrawForcedVariantButtons(editor);
    }

    bool _forcedVarEnabled = false;
    int _forcedVarIndex = -1;
    bool _forcedGround = false;
    void DrawForcedVariantButtons(CGameCtnEditorFree@ editor) {
        bool toggleForcedV = this.BtnToolbarHalfV("Force V.", "Force a specific variant for the current block", ForcedVarBtnStatus(editor));
        auto gVar = _forcedVarEnabled && _forcedGround ? _forcedVarIndex : -1;
        auto aVar = _forcedVarEnabled && !_forcedGround ? _forcedVarIndex : -1;
        bool cycleGroundVar = this.BtnToolbarQ("G:"+gVar+"###cy-gv", "Cycle Ground Variant", ForcedVarCycleBtnStatus(editor, true));
        UI::SameLine();
        bool cycleAirVar = this.BtnToolbarQ("A:"+aVar+"###cy-av", "Cycle Air Variant", ForcedVarCycleBtnStatus(editor, false));
    }

    BtnStatus ForcedVarBtnStatus(CGameCtnEditorFree@ editor) {
        if (Editor::IsInGhostOrFreeBlockPlacementMode(editor))
            return _forcedVarEnabled ? BtnStatus::FeatureActive : BtnStatus::Default;
        return BtnStatus::FeatureBlocked;
    }

    BtnStatus ForcedVarCycleBtnStatus(CGameCtnEditorFree@ editor, bool ground) {
        if (Editor::IsInGhostOrFreeBlockPlacementMode(editor))
            return _forcedVarEnabled && _forcedGround == ground ? BtnStatus::FeatureActive : BtnStatus::Default;
        return BtnStatus::FeatureBlocked;
    }

    /*
    - Ghost/free - force variant
    - Rotate free block in cursor 90 degrees

    */

    /*
    - macroblock: to air/ground, reinit model
    */
}
