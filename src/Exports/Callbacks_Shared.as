namespace Editor {
    namespace Callbacks {
        shared funcdef bool ProcessItem(CGameCtnAnchoredObject@ item);
        shared funcdef bool ProcessBlock(CGameCtnBlock@ block);
        shared funcdef bool ProcessNewSelectedItem(CGameItemModel@ itemModel);
        shared funcdef void ProcessNewSelectedBlock(CGameCtnBlockInfo@ blockInfo);
        shared funcdef void ProcessNewSelectedMacroBlock(CGameCtnMacroBlockInfo@ mbInfo);
        shared funcdef void ProcessTerrainChanged(MacroblockSpec@ terrainDiff);
        shared funcdef void ProcessMapSaved(bool mapSaved, bool onlyScriptMetadataModified);

#if FALSE
        // for vscode extension completion
        shared funcdef void CoroutineFunc();
        shared funcdef void CoroutineFuncUserdataInt64(int64 userdata);
#endif

        shared funcdef void IEppExtension_OnKill(IEppExtension@ extension);

        // To use this class, inherit from it and set the callback handles you want to use. Leave the others null.
        // Then, call Editor::Callbacks::Exts::RegisterExtension(myExtension) to register it.
        // Handles to callback functions must be set at this time for them to be registered for callback.
        shared class IEppExtension {
            // if not set to the name of the
            string name;

            private bool _isDead;
            bool get_isDead() final { return _isDead; }
            // should be called from the plugin's OnDestroyed method to avoid keeping stale references
            void kill() final {
                _isDead = true;
                if (_onKill !is null) _onKill(this);
            }

            // for internal use only
            private IEppExtension_OnKill@ _onKill;
            void _internal_setOnKill(IEppExtension_OnKill@ func) final {
                if (_onKill !is null) {
                    throw("onKill already set");
                }
                @_onKill = func;
            }
            IEppExtension_OnKill@ get_onKill() final {
                return _onKill;
            }

            CoroutineFunc@ onEditorLoad;
            CoroutineFunc@ onEditorStartingUp;
            CoroutineFunc@ onItemEditorLoad;
            CoroutineFunc@ onMTEditorLoad;
            CoroutineFunc@ onMTEditorUnload;
            CoroutineFunc@ onEditorUnload;
            CoroutineFunc@ onEditorGoneNull;
            CoroutineFunc@ onLeavingPlayground;
            CoroutineFunc@ onEnteringPlayground;
            CoroutineFunc@ onMapTypeUpdate;
            CoroutineFunc@ afterMapTypeUpdate;
            CoroutineFunc@ onAfterCursorUpdate;
            CoroutineFunc@ onBeforeCursorUpdate;

            // Argument is a CGameEditorPluginMap::EMapElemColor cast to int64
            CoroutineFuncUserdataInt64@ onApplyColorToSelection;

            // Fired when the user triggers the editor's save input/button
            // (EditorInput/Save via the E++ editor plugin's PendingEvents).
            // Best-effort pre-save: metadata writes queued here may land 1-2
            // frames later and can lose a race with a quick Ctrl+S.
            // Only fires while E++'s supporting editor plugin is active.
            CoroutineFunc@ onEditorSaveMap;
            // Fired after the save dialog resolves (MapSavedOrSaveCancelled).
            // mapSaved=false means the save was cancelled;
            // onlyScriptMetadataModified=true means nothing but script metadata
            // changed since the previous save. The reliable post-save backstop.
            ProcessMapSaved@ afterEditorSaveMap;

            // Called when a new item is added to the map, but before the game begins rendering it.
            ProcessItem@ onPlaceItem;
            // Called when an item is deleted from the map.
            ProcessItem@ onDeleteItem;
            // Called when a new block is added to the map, but before the game begins rendering it.
            ProcessBlock@ onPlaceBlock;
            // Called when a block is deleted from the map.
            ProcessBlock@ onDeleteBlock;
            // Called when a terrain block is added. Terrain blocks have no genealogy info;
            // use onTerrainChanged for settled state.
            ProcessBlock@ onPlaceTerrainBlock;
            // Called when a terrain block is removed. See onPlaceTerrainBlock.
            ProcessBlock@ onDeleteTerrainBlock;
            // Called each frame that terrain edits land on the genealogy grid (so a
            // terraform drag fires it repeatedly; not fired while a terrain
            // resync/apply is pending). Sync consumers use it to checkpoint state
            // ahead of the settled diff.
            CoroutineFunc@ onTerrainDirty;
            // Called after terrain edits settle (two quiet frames) with a terrain-only
            // MacroblockSpec diff of the changed cells. Registering this makes E++ the
            // owner of the terrain snapshot: do NOT poll GetTerrainDiffSpec yourself.
            ProcessTerrainChanged@ onTerrainChanged;
            // Called when a new item is selected in the editor.
            ProcessNewSelectedItem@ onNewSelectedItem;
        }
    }
}
