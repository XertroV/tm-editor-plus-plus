funcdef bool ProcessItem(CGameCtnAnchoredObject@ item);
funcdef bool ProcessBlock(CGameCtnBlock@ block);
funcdef bool ProcessNewSelectedItem(CGameItemModel@ itemModel);

CoroutineFunc@[] onEditorLoadCbs;
ProcessItem@[] itemCallbacks;
ProcessBlock@[] blockCallbacks;
ProcessNewSelectedItem@[] selectedItemChangedCbs;
// CoroutineFunc@[] selectedBlockChangedCbs;

void RegisterOnEditorLoadCallback(CoroutineFunc@ f) {
    if (f !is null) {
        onEditorLoadCbs.InsertLast(f);
    }
}

void RegisterNewItemCallback(ProcessItem@ f) {
    if (f !is null) {
        itemCallbacks.InsertLast(f);
    }
}

void RegisterNewBlockCallback(ProcessBlock@ f) {
    if (f !is null) {
        blockCallbacks.InsertLast(f);
    }
}

void RegisterItemChangedCallback(ProcessNewSelectedItem@ f) {
    if (f !is null) {
        selectedItemChangedCbs.InsertLast(f);
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
    }
    bool OnNewBlock(CGameCtnBlock@ block) {
        bool updated = false;
        for (uint i = 0; i < blockCallbacks.Length; i++) {
            updated = blockCallbacks[i](block) || updated;
        }
        return updated;
    }
    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        bool updated = false;
        for (uint i = 0; i < itemCallbacks.Length; i++) {
            updated = itemCallbacks[i](item) || updated;
        }
        return updated;
    }
    void OnSelectedItemChanged(CGameItemModel@ itemModel) {
        for (uint i = 0; i < selectedItemChangedCbs.Length; i++) {
            selectedItemChangedCbs[i](itemModel);
        }
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
        if (EnteringEditor) {
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
        if (EnteringEditor) {
            return false;
        }
        trace('Detected new items: ' + newItems);
        if (newItems > 0) {
            bool updated = false;
            auto startIx = int(editor.Challenge.AnchoredObjects.Length) - newItems;
            for (uint i = startIx; i < editor.Challenge.AnchoredObjects.Length; i++) {
                updated = Event::OnNewItem(editor.Challenge.AnchoredObjects[i]) || updated;
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
