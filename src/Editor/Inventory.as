namespace Editor {
    InventoryCache@ _InventoryCache = InventoryCache();
    InventoryCache@ GetInventoryCache() {
        return _InventoryCache;
    }

    enum InventoryRootNode {
        CrashBlocks = 0,
        Blocks = 1,
        Grass = 2,
        Items = 3,
        Macroblocks = 4,
    }
    enum InventoryItemsFolder {
        Official = 0,
        Club = 1,
        Custom = 2,
    }

    CGameCtnArticleNode@ GetInventoryRootNode(InventoryRootNode rootNode) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.PluginMapType.Inventory.RootNodes[rootNode];
    }

    CGameCtnArticleNode@ GetInventoryItemFolder(InventoryItemsFolder folder) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto rn = cast<CGameCtnArticleNodeDirectory>(editor.PluginMapType.Inventory.RootNodes[InventoryRootNode::Items]);
        return rn.ChildNodes[folder];
    }

    // 0 = show all. 1 = hide 1 level. 2 = hide 2 levels. If set to more than the available number of levels it will reset to 0;
    void SetInventoryItemHiddenFolderDepth(CGameEditorGenericInventory@ inventory, uint8 v) {
        Dev::SetOffset(inventory, O_INVENTORY_ItemHideFolderDepth, v);
    }
    void SetInventoryBlockHiddenFolderDepth(CGameEditorGenericInventory@ inventory, uint8 v) {
        Dev::SetOffset(inventory, O_INVENTORY_NormHideFolderDepth, v);
    }
    void SetInventoryGhostBlockHiddenFolderDepth(CGameEditorGenericInventory@ inventory, uint8 v) {
        Dev::SetOffset(inventory, O_INVENTORY_GhostHideFolderDepth, v);
    }
    uint8 GetInventoryItemHiddenFolderDepth(CGameEditorGenericInventory@ inventory) {
        return Dev::GetOffsetUint8(inventory, O_INVENTORY_ItemHideFolderDepth);
    }
    uint8 GetInventoryBlockHiddenFolderDepth(CGameEditorGenericInventory@ inventory) {
        return Dev::GetOffsetUint8(inventory, O_INVENTORY_NormHideFolderDepth);
    }
    uint8 GetInventoryGhostBlockHiddenFolderDepth(CGameEditorGenericInventory@ inventory) {
        return Dev::GetOffsetUint8(inventory, O_INVENTORY_GhostHideFolderDepth);
    }
    CGameCtnArticleNodeDirectory@ GetInventoryItemSelectedFolder(CGameEditorGenericInventory@ inventory) {
        return cast<CGameCtnArticleNodeDirectory>(Dev::GetOffsetNod(inventory, O_INVENTORY_ItemSelectedFolder));
    }
    CGameCtnArticleNodeDirectory@ GetInventoryBlockSelectedFolder(CGameEditorGenericInventory@ inventory) {
        return cast<CGameCtnArticleNodeDirectory>(Dev::GetOffsetNod(inventory, O_INVENTORY_NormSelectedFolder));
    }
    CGameCtnArticleNodeDirectory@ GetInventoryGhostBlockSelectedFolder(CGameEditorGenericInventory@ inventory) {
        return cast<CGameCtnArticleNodeDirectory>(Dev::GetOffsetNod(inventory, O_INVENTORY_GhostSelectedFolder));
    }
}
