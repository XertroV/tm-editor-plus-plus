[Setting hidden]
bool S_ShowBlockPlacementToolbar = true;

class CurrentBlock_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currBlockModel;

    CurrentBlock_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Block Placement Toolbar", Icons::Wrench, "bptb");
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
    }

    ~CurrentBlock_PlacementToolbar() {}

    void OnEditor() {
        this.windowOpen = S_ShowBlockPlacementToolbar;
    }

    void ResetCached() {
        @this.currBlockModel = null;
    }

    /*
    - Ghost/free - force variant
    - Rotate free block in cursor 90 degrees

    */

    /*
    - macroblock: to air/ground, reinit model
    */
}
