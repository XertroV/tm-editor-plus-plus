funcdef bool ProcessItem(CGameCtnAnchoredObject@ item);
funcdef bool ProcessBlock(CGameCtnBlock@ block);
funcdef bool ProcessNewSelectedItem(CGameItemModel@ itemModel);
funcdef void OnEditorStartingFunc(bool editingElseNew);

CoroutineFunc@[] onEditorLoadCbs;
string[] onEditorLoadCbNames;
OnEditorStartingFunc@[] onEditorStartingUp;
string[] onEditorStartingUpNames;
CoroutineFunc@[] onItemEditorLoadCbs;
string[] onItemEditorLoadCbNames;
CoroutineFunc@[] onMTEditorLoadCbs;
string[] onMTEditorLoadCbNames;
CoroutineFunc@[] onMTEditorUnloadCbs;
string[] onMTEditorUnloadCbNames;
CoroutineFunc@[] onEditorUnloadCbs;
string[] onEditorUnloadCbNames;
CoroutineFunc@[] onEditorGoneNullCbs;
string[] onEditorGoneNullCbNames;
ProcessItem@[] itemCallbacks;
string[] itemCallbackNames;
ProcessItem@[] itemDelCallbacks;
string[] itemDelCallbackNames;
ProcessBlock@[] blockCallbacks;
string[] blockCallbackNames;
ProcessBlock@[] blockDelCallbacks;
string[] blockDelCallbackNames;
ProcessNewSelectedItem@[] selectedItemChangedCbs;
string[] selectedItemChangedCbNames;
CoroutineFunc@[] onLeavingPlaygroundCbs;
string[] onLeavingPlaygroundCbNames;
CoroutineFunc@[] onEnteringPlaygroundCbs;
string[] onEnteringPlaygroundCbNames;
CoroutineFunc@[] onMapTypeUpdateCbs;
string[] onMapTypeUpdateCbNames;
CoroutineFunc@[] afterMapTypeUpdateCbs;
string[] afterMapTypeUpdateCbNames;
CoroutineFunc@[] onAfterCursorUpdateCbs;
string[] onAfterCursorUpdateCbNames;
CoroutineFunc@[] onBeforeCursorUpdateCbs;
string[] onBeforeCursorUpdateCbNames;
CoroutineFuncUserdataInt64@[] onApplyColorToSelectionCbs;
string[] onApplyColorToSelectionCbNames;
// CoroutineFunc@[] selectedBlockChangedCbs;

// CoroutineFunc@[] onEditorSaveMapCbs;
// string[] onEditorSaveMapCbNames;
// CoroutineFunc@[] afterEditorSaveMapCbs;
// string[] afterEditorSaveMapCbNames;

// set this shortly after loading the plugin
bool CallbacksEnabledPostInit = false;

void RegisterOnEditorLoadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onEditorLoadCbs.InsertLast(f);
        onEditorLoadCbNames.InsertLast(name);
    }
    trace("Registered OnEditorLoad callback: " + name);
}
void RegisterOnEditorStartingUpCallback(OnEditorStartingFunc@ f, const string &in name) {
    if (f !is null) {
        onEditorStartingUp.InsertLast(f);
        onEditorStartingUpNames.InsertLast(name);
    }
    // trace("Registered OnEditorStartingUp callback: " + name);
}
void RegisterOnItemEditorLoadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onItemEditorLoadCbs.InsertLast(f);
        onItemEditorLoadCbNames.InsertLast(name);
    }
}
void RegisterOnMTEditorLoadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onMTEditorLoadCbs.InsertLast(f);
        onMTEditorLoadCbNames.InsertLast(name);
    }
}
void RegisterOnMTEditorUnloadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onMTEditorUnloadCbs.InsertLast(f);
        onMTEditorUnloadCbNames.InsertLast(name);
    }
}

// when editor changes (e.g., editor -> item editor)
void RegisterOnEditorUnloadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onEditorUnloadCbs.InsertLast(f);
        onEditorUnloadCbNames.InsertLast(name);
    }
}

// when returning to menu
void RegisterOnEditorGoneNullCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onEditorGoneNullCbs.InsertLast(f);
        onEditorGoneNullCbNames.InsertLast(name);
    }
}

void RegisterNewItemCallback_Private(ProcessItem@ f, const string &in name, uint index) {
    if (f is null) throw("null callback passed to RegisterNewItemCallback_Private");
    itemCallbacks.InsertAt(index, f);
    itemCallbackNames.InsertAt(index, name);
}

void RegisterNewItemCallback(ProcessItem@ f, const string &in name) {
    if (f !is null) {
        itemCallbacks.InsertLast(f);
        itemCallbackNames.InsertLast(name);
    }
}

void RegisterItemDeletedCallback_Private(ProcessItem@ f, const string &in name, uint index) {
    if (f is null) throw("null callback passed to RegisterItemDeletedCallback_Private");
    itemDelCallbacks.InsertAt(index, f);
    itemDelCallbackNames.InsertAt(index, name);
}

void RegisterItemDeletedCallback(ProcessItem@ f, const string &in name) {
    if (f !is null) {
        itemDelCallbacks.InsertLast(f);
        itemDelCallbackNames.InsertLast(name);
    }
}

void RegisterNewBlockCallback_Private(ProcessBlock@ f, const string &in name, uint index) {
    if (f is null) throw("null callback passed to RegisterNewBlockCallback_Private");
    blockCallbacks.InsertAt(index, f);
    blockCallbackNames.InsertAt(index, name);
}

void RegisterNewBlockCallback(ProcessBlock@ f, const string &in name) {
    if (f !is null) {
        blockCallbacks.InsertLast(f);
        blockCallbackNames.InsertLast(name);
    }
}

void RegisterBlockDeletedCallback_Private(ProcessBlock@ f, const string &in name, uint index) {
    if (f is null) throw("null callback passed to RegisterBlockDeletedCallback_Private");
    blockDelCallbacks.InsertAt(index, f);
    blockDelCallbackNames.InsertAt(index, name);
}

void RegisterBlockDeletedCallback(ProcessBlock@ f, const string &in name) {
    if (f !is null) {
        blockDelCallbacks.InsertLast(f);
        blockDelCallbackNames.InsertLast(name);
    }
}

void RegisterItemChangedCallback(ProcessNewSelectedItem@ f, const string &in name) {
    if (f !is null) {
        selectedItemChangedCbs.InsertLast(f);
        selectedItemChangedCbNames.InsertLast(name);
    }
}

void RegisterOnLeavingPlaygroundCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onLeavingPlaygroundCbs.InsertLast(f);
        onLeavingPlaygroundCbNames.InsertLast(name);
    }
}

void RegisterOnEnteringPlaygroundCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onEnteringPlaygroundCbs.InsertLast(f);
        onEnteringPlaygroundCbNames.InsertLast(name);
    }
}

void RegisterOnMapTypeUpdateCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onMapTypeUpdateCbs.InsertLast(f);
        onMapTypeUpdateCbNames.InsertLast(name);
    }
}

// void RegisterAfterMapTypeUpdateCallback(CoroutineFunc@ f, const string &in name) {
//     if (f !is null) {
//         afterMapTypeUpdateCbs.InsertLast(f);
//         afterMapTypeUpdateCbNames.InsertLast(name);
//     }
// }

void RegisterNewAfterCursorUpdateCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onAfterCursorUpdateCbs.InsertLast(f);
        onAfterCursorUpdateCbNames.InsertLast(name);
    }
}

void RegisterNewBeforeCursorUpdateCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onBeforeCursorUpdateCbs.InsertLast(f);
        onBeforeCursorUpdateCbNames.InsertLast(name);
    }
}

void RegisterOnApplyColorToSelectionCallback(CoroutineFuncUserdataInt64@ f, const string &in name) {
    if (f !is null) {
        onApplyColorToSelectionCbs.InsertLast(f);
        onApplyColorToSelectionCbNames.InsertLast(name);
    }
}

// void RegisterOnEditorSaveMapCallback(CoroutineFunc@ f, const string &in name) {
//     if (f !is null) {
//         onEditorSaveMapCbs.InsertLast(f);
//         onEditorSaveMapCbNames.InsertLast(name);
//     }
// }

// void RegisterAfterEditorSaveMapCallback(CoroutineFunc@ f, const string &in name) {
//     if (f !is null) {
//         afterEditorSaveMapCbs.InsertLast(f);
//         afterEditorSaveMapCbNames.InsertLast(name);
//     }
// }

// void RegisterBlockChangedCallback(CoroutineFunc@ f) {
//     if (f !is null) {
//         selectedBlockChangedCbs.InsertLast(f);
//     }
// }

namespace Event {
    bool TMP_DISABLE_ONBlockItem_CB = false;
    void DisableOnBlockItemCB() {
        TMP_DISABLE_ONBlockItem_CB = true;
    }
    void EnableOnBlockItemCB() {
        TMP_DISABLE_ONBlockItem_CB = false;
    }
    void RunOnEditorLoadCbs() {
        Log::Trace("Running OnEditorLoad callbacks");
        for (uint i = 0; i < onEditorLoadCbs.Length; i++) {
            trace("Running OnEditorLoad callback: " + onEditorLoadCbNames[i]);
            onEditorLoadCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnEditorLoad();
        Log::Trace("Finished OnEditorLoad callbacks");
    }
    void RunOnEditorStartingUpCbs(bool editingElseNew) {
        Log::Trace("Running OnEditorStartingUp callbacks");
        for (uint i = 0; i < onEditorStartingUp.Length; i++) {
            onEditorStartingUp[i](editingElseNew);
        }
        Editor::Callbacks::Exts::Run_OnEditorStartingUp();
        Log::Trace("Finished OnEditorStartingUp callbacks");
    }
    void RunOnItemEditorLoadCbs() {
        Log::Trace("Running OnItemEditorLoad callbacks");
        for (uint i = 0; i < onItemEditorLoadCbs.Length; i++) {
            onItemEditorLoadCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnItemEditorLoad();
        Log::Trace("Finished OnItemEditorLoad callbacks");
    }
    void RunOnMTEditorLoadCbs() {
        Log::Trace("Running OnMTEditorLoad callbacks");
        for (uint i = 0; i < onMTEditorLoadCbs.Length; i++) {
            onMTEditorLoadCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnMTEditorLoad();
        Log::Trace("Finished OnMTEditorLoad callbacks");
    }
    void RunOnMTEditorUnloadCbs() {
        Log::Trace("Running OnMTEditorUnload callbacks");
        for (uint i = 0; i < onMTEditorUnloadCbs.Length; i++) {
            onMTEditorUnloadCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnMTEditorUnload();
        Log::Trace("Finished OnMTEditorLoad callbacks");
    }
    void RunOnEditorUnloadCbs() {
        Log::Trace("Running OnEditorUnload callbacks");
        for (uint i = 0; i < onEditorUnloadCbs.Length; i++) {
            onEditorUnloadCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnEditorUnload();
        Log::Trace("Finished OnEditorUnload callbacks");
    }
    void RunOnEditorGoneNullCbs() {
        Log::Trace("Running OnEditorGoneNull callbacks");
        for (uint i = 0; i < onEditorGoneNullCbs.Length; i++) {
            onEditorGoneNullCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnEditorGoneNull();
        Log::Trace("Finished OnEditorGoneNull callbacks");
    }
    bool OnNewBlock(CGameCtnBlock@ block) {
        if (TMP_DISABLE_ONBlockItem_CB) return false;
        bool updated = false;
        bool lastUpdated = false;
        for (uint i = 0; i < blockCallbacks.Length; i++) {
            updated = blockCallbacks[i](block) || updated;
            if (updated && !lastUpdated) Log::Trace("NewBlock Callback triggered update: " + blockCallbackNames[i]);
            lastUpdated = updated;
        }
        Editor::Callbacks::Exts::Run_OnPlaceBlock(block);
        Editor::TrackMap_OnAddBlock(block);
        return updated;
    }
    bool OnBlockDeleted(CGameCtnBlock@ block) {
        if (TMP_DISABLE_ONBlockItem_CB) return false;
        bool updated = false;
        bool lastUpdated = false;
        for (uint i = 0; i < blockDelCallbacks.Length; i++) {
            updated = blockDelCallbacks[i](block) || updated;
            if (updated && !lastUpdated) Log::Trace("DelBlock Callback triggered update: " + blockCallbackNames[i]);
            lastUpdated = updated;
        }
        Editor::Callbacks::Exts::Run_OnDeleteBlock(block);
        Editor::TrackMap_OnRemoveBlock(block);
        return updated;
    }
    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (TMP_DISABLE_ONBlockItem_CB) return false;
        Log::Trace("Running OnNewItem");
        bool updated = false;
        bool lastUpdated = false;
        for (uint i = 0; i < itemCallbacks.Length; i++) {
            updated = itemCallbacks[i](item) || updated;
            if (updated && !lastUpdated) Log::Trace("NewItem Callback triggered update: " + itemCallbackNames[i]);
            lastUpdated = updated;
        }
        Editor::Callbacks::Exts::Run_OnPlaceItem(item);
        Log::Trace("Finished OnNewItem");
        Editor::TrackMap_OnAddItem(item);
        return updated;
    }
    bool OnItemDeleted(CGameCtnAnchoredObject@ item) {
        if (TMP_DISABLE_ONBlockItem_CB) return false;
        Log::Trace("Running OnItemDeleted");
        bool updated = false;
        bool lastUpdated = false;
        for (uint i = 0; i < itemDelCallbacks.Length; i++) {
            updated = itemDelCallbacks[i](item) || updated;
            if (updated && !lastUpdated) Log::Trace("DelItem Callback triggered update: " + itemCallbackNames[i]);
            lastUpdated = updated;
        }
        Editor::Callbacks::Exts::Run_OnDeleteItem(item);
        Editor::TrackMap_OnRemoveItem(item);
        return updated;
    }
    bool OnSetItemBgSkin(CGameCtnAnchoredObject@ item) {
        if (TMP_DISABLE_ONBlockItem_CB) return false;
        Log::Trace("Running OnSetItemBgSkin");
        Editor::TrackMap_OnSetSkin(GetSkinPath(Editor::GetItemFGSkin(item)), GetSkinPath(Editor::GetItemBGSkin(item)), null, item);
        return false;
    }
    bool OnSetItemFgSkin(CGameCtnAnchoredObject@ item) {
        if (TMP_DISABLE_ONBlockItem_CB) return false;
        Log::Trace("Running OnSetItemFgSkin");
        Editor::TrackMap_OnSetSkin(GetSkinPath(Editor::GetItemFGSkin(item)), GetSkinPath(Editor::GetItemBGSkin(item)), null, item);
        return false;
    }
    bool OnSetBlockSkin(CGameCtnBlock@ block) {
        if (TMP_DISABLE_ONBlockItem_CB) return false;
        Log::Trace("Running OnSetBlockSkin");
        Editor::TrackMap_OnSetSkin(GetSkinPath(block.Skin.ForegroundPackDesc), GetSkinPath(block.Skin.PackDesc), block, null);
        return false;
    }
    void OnSelectedItemChanged(CGameItemModel@ itemModel) {
        Log::Trace("Running OnSelectedItemChanged");
        for (uint i = 0; i < selectedItemChangedCbs.Length; i++) {
            selectedItemChangedCbs[i](itemModel);
        }
        Editor::Callbacks::Exts::Run_OnNewSelectedItem(itemModel);
        Log::Trace("Finished OnSelectedItemChanged");
    }
    void RunOnLeavingPlaygroundCbs() {
        Log::Trace("Running OnLeavingPlayground callbacks");
        for (uint i = 0; i < onLeavingPlaygroundCbs.Length; i++) {
            onLeavingPlaygroundCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnLeavingPlayground();
        Log::Trace("Finished OnLeavingPlayground callbacks");
    }
    void RunOnEnteringPlaygroundCbs() {
        Log::Trace("Running OnEnteringPlayground callbacks");
        for (uint i = 0; i < onEnteringPlaygroundCbs.Length; i++) {
            onEnteringPlaygroundCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnEnteringPlayground();
        Log::Trace("Finished OnEnteringPlayground callbacks");
    }
    void OnMapTypeUpdate() {
        // don't log these, 2 every frame :/
        // Log::Trace("Running OnMapTypeUpdate");
        for (uint i = 0; i < onMapTypeUpdateCbs.Length; i++) {
            onMapTypeUpdateCbs[i]();
        }
        // Log::Trace("Finished OnMapTypeUpdate");
        Editor::Callbacks::Exts::Run_OnMapTypeUpdate();
    }
    void AfterMapTypeUpdate() {
        // don't log these, 2 every frame :/
        // Log::Trace("Running AfterMapTypeUpdate");
        for (uint i = 0; i < afterMapTypeUpdateCbs.Length; i++) {
            afterMapTypeUpdateCbs[i]();
        }
        // Log::Trace("Finished AfterMapTypeUpdate");
        Editor::Callbacks::Exts::Run_AfterMapTypeUpdate();
    }
    void OnAfterCursorUpdate() {
        for (uint i = 0; i < onAfterCursorUpdateCbs.Length; i++) {
            onAfterCursorUpdateCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnAfterCursorUpdate();
    }
    void OnBeforeCursorUpdate() {
        for (uint i = 0; i < onBeforeCursorUpdateCbs.Length; i++) {
            onBeforeCursorUpdateCbs[i]();
        }
        Editor::Callbacks::Exts::Run_OnBeforeCursorUpdate();
    }
    void OnApplyColorToSelection(CGameEditorPluginMap::EMapElemColor col) {
        for (uint i = 0; i < onApplyColorToSelectionCbs.Length; i++) {
            onApplyColorToSelectionCbs[i](int64(col));
        }
        Editor::Callbacks::Exts::Run_OnApplyColorToSelection(int64(col));
    }
    void OnSetBlockColor(CGameCtnBlock@ block) {
        Editor::TrackMap_OnSetBlockColor(block);
    }
    void OnSetItemColor(CGameCtnAnchoredObject@ item) {
        Editor::TrackMap_OnSetItemColor(item);
    }
    void RunOnEditorSaveMapCbs() {
        throw("not enabled");
        // Log::Trace("Running OnEditorSaveMap callbacks");
        // for (uint i = 0; i < onEditorSaveMapCbs.Length; i++) {
        //     onEditorSaveMapCbs[i]();
        // }
        // Log::Trace("Finished OnEditorSaveMap callbacks");
    }
    void RunAfterEditorSaveMapCbs() {
        throw("not enabled");
        // Log::Trace("Running AfterEditorSaveMap callbacks");
        // for (uint i = 0; i < afterEditorSaveMapCbs.Length; i++) {
        //     afterEditorSaveMapCbs[i]();
        // }
        // Log::Trace("Finished AfterEditorSaveMap callbacks");
    }
}

uint m_LastNbBlocks = 0;
uint m_LastNbItems = 0;

// Deprecated
// bool CheckForNewBlocks_Deprecated(CGameCtnEditorFree@ editor) {
//     if (editor is null) return false;
//     if (m_LastNbBlocks != editor.Challenge.Blocks.Length) {
//         int newBlocks = int(editor.Challenge.Blocks.Length) - int(m_LastNbBlocks);
//         m_LastNbBlocks = editor.Challenge.Blocks.Length;
//         // just update the count, but don't fire callbacks
//         if (EnteringEditor || !CallbacksEnabledPostInit) {
//             return false;
//         }
//         dev_trace('Detected new blocks: ' + newBlocks);
//         if (newBlocks > 0) {
//             auto startIx = int(editor.Challenge.Blocks.Length) - newBlocks;
//             bool updated = false;
//             for (uint i = startIx; i < editor.Challenge.Blocks.Length; i++) {
//                 updated = Event::OnNewBlock(editor.Challenge.Blocks[i]) || updated;
//             }
//             return updated;
//         }
//     }
//     return false;
// }

// Deprecated
// bool CheckForNewItems_Deprecated(CGameCtnEditorFree@ editor) {
//     if (editor is null) return false;
//     if (m_LastNbItems != editor.Challenge.AnchoredObjects.Length) {
//         int newItems = int(editor.Challenge.AnchoredObjects.Length) - int(m_LastNbItems);
//         m_LastNbItems = editor.Challenge.AnchoredObjects.Length;
//         // just update the count, but don't fire callbacks
//         if (EnteringEditor || !CallbacksEnabledPostInit) {
//             return false;
//         }
//         dev_trace('Detected new items: ' + newItems);
//         if (newItems > 0) {
//             bool updated = false;
//             bool lastUpdated = false;
//             auto startIx = int(editor.Challenge.AnchoredObjects.Length) - newItems;
//             for (uint i = startIx; i < editor.Challenge.AnchoredObjects.Length; i++) {
//                 updated = Event::OnNewItem(editor.Challenge.AnchoredObjects[i]) || updated;
//                 // if (updated && !lastUpdated) trace("Updating after " + i + " callbacks.");
//                 lastUpdated = updated;
//             }
//             return updated;
//         }
//     }
//     return false;
// }


uint _lastSelectedBlockInfoId = 0;
uint _lastSelectedItemModelId = 0;

void CheckForNewSelectedItem(CGameCtnEditorFree@ editor) {
    if (editor is null) return;
    if (editor.CurrentItemModel is null) return;
    auto im = editor.CurrentItemModel;
    if (im.Id.Value != _lastSelectedItemModelId) {
        _lastSelectedItemModelId = im.Id.Value;
        Event::OnSelectedItemChanged(im);
    }
}
