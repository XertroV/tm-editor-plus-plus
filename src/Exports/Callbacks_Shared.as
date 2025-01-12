namespace Editor {
    namespace Callbacks {
        shared funcdef bool ProcessItem(CGameCtnAnchoredObject@ item);
        shared funcdef bool ProcessBlock(CGameCtnBlock@ block);
        shared funcdef bool ProcessNewSelectedItem(CGameItemModel@ itemModel);
        shared funcdef void ProcessNewSelectedBlock(CGameCtnBlockInfo@ blockInfo);
        shared funcdef void ProcessNewSelectedMacroBlock(CGameCtnMacroBlockInfo@ mbInfo);

#if FALSE
        // for vscode extension completion
        shared funcdef void CoroutineFunc();
        shared funcdef void CoroutineFuncUserdataInt64(int64 userdata);
#endif

        shared funcdef void IEppExtension_OnKill(IEppExtension@ extension);

        // To use this class, inherit from it and set the callback handles you want to use. Leave the others null.
        // Then, call Editor::Callbacks::RegisterExtension(myExtension) to register it.
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

            // CoroutineFunc@ onEditorSaveMap;
            // CoroutineFunc@ afterEditorSaveMap;

            // Called when a new item is added to the map, but before the game begins rendering it.
            ProcessItem@ onPlaceItem;
            // Called when an item is deleted from the map.
            ProcessItem@ onDeleteItem;
            // Called when a new block is added to the map, but before the game begins rendering it.
            ProcessBlock@ onPlaceBlock;
            // Called when a block is deleted from the map.
            ProcessBlock@ onDeleteBlock;
            // Called when a new item is selected in the editor.
            ProcessNewSelectedItem@ onNewSelectedItem;
        }
    }
}
