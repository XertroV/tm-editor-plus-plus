class InventoryMainTab : Tab {
    InventoryMainTab(TabGroup@ p) {
        super(p, "Inventory", Icons::FolderOpenO);
        BlocksInventoryBrowserTab(Children);
        Blocks2InventoryBrowserTab(Children);
        // ItemsInventoryBrowserTab(Children);
        // MacroblocksInventoryBrowserTab(Children);
        canPopOut = false;
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

class GenericInventoryBrowserTab : Tab {
    GenericInventoryBrowserTab(TabGroup@ p, const string &in name, const string &in icon) {
        super(p, name, icon);
    }

    // 0/1: blocks, 2: grass, 3: items, 4: macroblocks
    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) {
        throw('override me');
        return null;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = editor.PluginMapType.Inventory;
        auto rn = GetRootNode(inv);
        DrawInvNodeTree(rn);
    }

    void DrawInvNodeTree(CGameCtnArticleNode@ node) {
        if (node.IsDirectory) {
            DrawInvNodeTreeDir(cast<CGameCtnArticleNodeDirectory>(node));
        } else {
            DrawInvNodeTreeArticle(cast<CGameCtnArticleNodeArticle>(node));
        }
    }

    void DrawInvNodeTreeArticle(CGameCtnArticleNodeArticle@ node) {
        // UI::TreeNodeFlags::Leaf
        if (UI::Button(node.Name)) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            auto inv = editor.PluginMapType.Inventory;
            inv.SelectArticle(node);
        }
    }

    void DrawInvNodeTreeDir(CGameCtnArticleNodeDirectory@ node) {
        if (UI::TreeNode(node.Name.Length > 0 ? string(node.Name) : tabName)) {
            for (uint i = 0; i < node.ChildNodes.Length; i++) {
                DrawInvNodeTree(node.ChildNodes[i]);
            }
            UI::TreePop();
        }
    }
}

class BlocksInventoryBrowserTab : GenericInventoryBrowserTab {
    BlocksInventoryBrowserTab(TabGroup@ p) {
        super(p, "Blocks", Icons::FolderOpenO + Icons::Cube);
    }

    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) override {
        return inv.RootNodes[0];
    }
}
class Blocks2InventoryBrowserTab : GenericInventoryBrowserTab {
    Blocks2InventoryBrowserTab(TabGroup@ p) {
        super(p, "Blocks2", Icons::FolderOpenO + Icons::Cube);
    }

    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) override {
        return inv.RootNodes[1];
    }
}

class ItemsInventoryBrowserTab : GenericInventoryBrowserTab {
    ItemsInventoryBrowserTab(TabGroup@ p) {
        super(p, "Items", Icons::FolderOpenO + Icons::Tree);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = editor.PluginMapType.Inventory;
    }
}

class MacroblocksInventoryBrowserTab : GenericInventoryBrowserTab {
    MacroblocksInventoryBrowserTab(TabGroup@ p) {
        super(p, "Macroblocks", Icons::FolderOpenO + Icons::Cubes);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = editor.PluginMapType.Inventory;
    }
}
