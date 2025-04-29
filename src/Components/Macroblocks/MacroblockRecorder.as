namespace MacroblockRecorder {
    Editor::MacroblockSpec@[] recorded;

    void RegisterCallbacks() {
        RegisterNewItemCallback(OnNewItem, "MacroblockRecorder");
        RegisterNewBlockCallback(OnNewBlock, "MacroblockRecorder");
        RegisterItemDeletedCallback(OnItemDeleted, "MacroblockRecorder");
        RegisterBlockDeletedCallback(OnBlockDeleted, "MacroblockRecorder");
    }

    CGameCtnAnchoredObject@[] newItems;
    CGameCtnBlock@[] newBlocks;

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        return false;
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        return false;
    }

    bool OnItemDeleted(CGameCtnAnchoredObject@ item) {
        return false;
    }

    bool OnBlockDeleted(CGameCtnBlock@ block) {
        return false;
    }
}
