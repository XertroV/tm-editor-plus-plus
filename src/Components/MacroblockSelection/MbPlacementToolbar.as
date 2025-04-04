[Setting hidden]
bool S_ShowMbPlacementToolbar = true;

class CurrentMacroblock_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currMbModel;

    CurrentMacroblock_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Macroblock Placement Toolbar", Icons::Wrench, "mbptb");
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
    }

    ~CurrentMacroblock_PlacementToolbar() {}

    void OnEditor() {
        this.windowOpen = S_ShowMbPlacementToolbar;
    }

    void ResetCached() {
        @this.currMbModel = null;
    }

    bool ShouldShowWindow(CGameCtnEditorFree@ editor) override {
        return false;
    }

    /*
    - Ghost/free - force variant
    - Rotate free block in cursor 90 degrees

    */

    /*
    - macroblock: to air/ground, reinit model
    */
}
