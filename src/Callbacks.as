funcdef bool ProcessItem(CGameCtnAnchoredObject@ item);
funcdef bool ProcessBlock(CGameCtnBlock@ block);
funcdef bool ProcessNewSelectedItem(CGameItemModel@ itemModel);

CoroutineFunc@[] onEditorLoadCbs;
string[] onEditorLoadCbNames;
CoroutineFunc@[] onItemEditorLoadCbs;
string[] onItemEditorLoadCbNames;
CoroutineFunc@[] onEditorUnloadCbs;
string[] onEditorUnloadCbNames;
ProcessItem@[] itemCallbacks;
string[] itemCallbackNames;
ProcessBlock@[] blockCallbacks;
string[] blockCallbackNames;
ProcessNewSelectedItem@[] selectedItemChangedCbs;
string[] selectedItemChangedCbNames;
// CoroutineFunc@[] selectedBlockChangedCbs;

// set this shortly after loading the plugin
bool CallbacksEnabledPostInit = false;

void RegisterOnEditorLoadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onEditorLoadCbs.InsertLast(f);
        onEditorLoadCbNames.InsertLast(name);
    }
}
void RegisterOnItemEditorLoadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onItemEditorLoadCbs.InsertLast(f);
        onItemEditorLoadCbNames.InsertLast(name);
    }
}
void RegisterOnEditorUnloadCallback(CoroutineFunc@ f, const string &in name) {
    if (f !is null) {
        onEditorUnloadCbs.InsertLast(f);
        onEditorUnloadCbNames.InsertLast(name);
    }
}

void RegisterNewItemCallback(ProcessItem@ f, const string &in name) {
    if (f !is null) {
        itemCallbacks.InsertLast(f);
        itemCallbackNames.InsertLast(name);
    }
}

void RegisterNewBlockCallback(ProcessBlock@ f, const string &in name) {
    if (f !is null) {
        blockCallbacks.InsertLast(f);
        blockCallbackNames.InsertLast(name);
    }
}

void RegisterItemChangedCallback(ProcessNewSelectedItem@ f, const string &in name) {
    if (f !is null) {
        selectedItemChangedCbs.InsertLast(f);
        selectedItemChangedCbNames.InsertLast(name);
    }
}

// void RegisterBlockChangedCallback(CoroutineFunc@ f) {
//     if (f !is null) {
//         selectedBlockChangedCbs.InsertLast(f);
//     }
// }


namespace Event {
    void RunOnEditorLoadCbs() {
        trace("Running OnEditorLoad callbacks");
        for (uint i = 0; i < onEditorLoadCbs.Length; i++) {
            onEditorLoadCbs[i]();
        }
        trace("Finished OnEditorLoad callbacks");
    }
    void RunOnItemEditorLoadCbs() {
        trace("Running OnItemEditorLoad callbacks");
        for (uint i = 0; i < onItemEditorLoadCbs.Length; i++) {
            onItemEditorLoadCbs[i]();
        }
        trace("Finished OnEditorLoad callbacks");
    }
    void RunOnEditorUnloadCbs() {
        trace("Running OnEditorUnload callbacks");
        for (uint i = 0; i < onEditorUnloadCbs.Length; i++) {
            onEditorUnloadCbs[i]();
        }
        trace("Finished OnEditorUnload callbacks");
    }
    bool OnNewBlock(CGameCtnBlock@ block) {
        bool updated = false;
        bool lastUpdated = false;
        for (uint i = 0; i < blockCallbacks.Length; i++) {
            updated = blockCallbacks[i](block) || updated;
            if (updated && !lastUpdated) trace("NewBlock Callback triggered update: " + blockCallbackNames[i]);
            lastUpdated = updated;
        }
        return updated;
    }
    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        trace("Running OnNewItem");
        bool updated = false;
        bool lastUpdated = false;
        for (uint i = 0; i < itemCallbacks.Length; i++) {
            updated = itemCallbacks[i](item) || updated;
            if (updated && !lastUpdated) trace("NewItem Callback triggered update: " + itemCallbackNames[i]);
            lastUpdated = updated;
        }
        trace("Finished OnNewItem");
        return updated;
    }
    void OnSelectedItemChanged(CGameItemModel@ itemModel) {
        trace("Running OnSelectedItemChanged");
        for (uint i = 0; i < selectedItemChangedCbs.Length; i++) {
            selectedItemChangedCbs[i](itemModel);
        }
        trace("Finished OnSelectedItemChanged");
    }
}

uint m_LastNbBlocks = 0;
uint m_LastNbItems = 0;

bool CheckForNewBlocks(CGameCtnEditorFree@ editor) {
    if (editor is null) return false;
    if (m_LastNbBlocks != editor.Challenge.Blocks.Length) {
        int newBlocks = int(editor.Challenge.Blocks.Length) - int(m_LastNbBlocks);
        m_LastNbBlocks = editor.Challenge.Blocks.Length;
        // just update the count, but don't fire callbacks
        if (EnteringEditor || !CallbacksEnabledPostInit) {
            return false;
        }
        trace('Detected new blocks: ' + newBlocks);
        if (newBlocks > 0) {
            auto startIx = int(editor.Challenge.Blocks.Length) - newBlocks;
            bool updated = false;
            for (uint i = startIx; i < editor.Challenge.Blocks.Length; i++) {
                updated = Event::OnNewBlock(editor.Challenge.Blocks[i]) || updated;
            }
            return updated;
        }
    }
    return false;
}


bool CheckForNewItems(CGameCtnEditorFree@ editor) {
    if (editor is null) return false;
    if (m_LastNbItems != editor.Challenge.AnchoredObjects.Length) {
        int newItems = int(editor.Challenge.AnchoredObjects.Length) - int(m_LastNbItems);
        m_LastNbItems = editor.Challenge.AnchoredObjects.Length;
        // just update the count, but don't fire callbacks
        if (EnteringEditor || !CallbacksEnabledPostInit) {
            return false;
        }
        trace('Detected new items: ' + newItems);
        if (newItems > 0) {
            bool updated = false;
            bool lastUpdated = false;
            auto startIx = int(editor.Challenge.AnchoredObjects.Length) - newItems;
            for (uint i = startIx; i < editor.Challenge.AnchoredObjects.Length; i++) {
                updated = Event::OnNewItem(editor.Challenge.AnchoredObjects[i]) || updated;
                // if (updated && !lastUpdated) trace("Updating after " + i + " callbacks.");
                lastUpdated = updated;
            }
            return updated;
        }
    }
    return false;
}


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
