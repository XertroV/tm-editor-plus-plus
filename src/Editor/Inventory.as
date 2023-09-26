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


}
