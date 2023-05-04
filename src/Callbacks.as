funcdef bool ProcessItem(CGameCtnAnchoredObject@ item);
funcdef bool ProcessBlock(CGameCtnBlock@ block);

ProcessItem@[] itemCallbacks;
ProcessBlock@[] blockCallbacks;

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

uint m_LastNbBlocks = 0;
uint m_LastNbItems = 0;

void CheckForNewBlocks(CGameCtnEditorFree@ editor) {
    if (editor is null) return;
    if (m_LastNbBlocks != editor.Challenge.Blocks.Length) {
        int newBlocks = int(editor.Challenge.Blocks.Length) - int(m_LastNbBlocks);
        m_LastNbBlocks = editor.Challenge.Blocks.Length;
        // just update the count, but don't fire callbacks
        if (EnteringEditor) {
            return;
        }
        trace('Detected new blocks: ' + newBlocks);
        if (newBlocks > 0) {
            auto startIx = int(editor.Challenge.Blocks.Length) - newBlocks;
            for (uint i = startIx; i < editor.Challenge.Blocks.Length; i++) {
                OnNewBlock(editor.Challenge.Blocks[i]);
            }
        }
    }
}

void OnNewBlock(CGameCtnBlock@ block) {
    for (uint i = 0; i < blockCallbacks.Length; i++) {
        blockCallbacks[i](block);
    }
}

void CheckForNewItems(CGameCtnEditorFree@ editor) {
    if (editor is null) return;
    if (m_LastNbItems != editor.Challenge.AnchoredObjects.Length) {
        int newItems = int(editor.Challenge.AnchoredObjects.Length) - int(m_LastNbItems);
        m_LastNbItems = editor.Challenge.AnchoredObjects.Length;
        // just update the count, but don't fire callbacks
        if (EnteringEditor) {
            return;
        }
        trace('Detected new items: ' + newItems);
        if (newItems > 0) {
            auto startIx = int(editor.Challenge.AnchoredObjects.Length) - newItems;
            for (uint i = startIx; i < editor.Challenge.AnchoredObjects.Length; i++) {
                OnNewItem(editor.Challenge.AnchoredObjects[i]);
            }
        }
    }
}

void OnNewItem(CGameCtnAnchoredObject@ item) {
    for (uint i = 0; i < itemCallbacks.Length; i++) {
        itemCallbacks[i](item);
    }
}