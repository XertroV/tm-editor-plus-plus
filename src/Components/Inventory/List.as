class InventoryMainTab : Tab {
    InventoryMainTab(TabGroup@ p) {
        super(p, "Inventory", Icons::FolderOpenO);
        BlocksInventoryBrowserTab(Children);
        // BlocksBrokenInventoryBrowserTab(Children);
        ItemsInventoryBrowserTab(Children);
        MacroblocksInventoryBrowserTab(Children);
        GenericInventoryBrowserTab(Children, "Grass", "", 2);
        canPopOut = false;
    }

    void DrawInner() override {
        Children.DrawTabs();
    }
}

class GenericInventoryBrowserTab : Tab {
    uint RootNodeIx = 1;

    GenericInventoryBrowserTab(TabGroup@ p, const string &in name, const string &in icon, uint rnIx) {
        super(p, name, icon);
        RootNodeIx = rnIx;
    }

    // 0: blocks but crashes, 1: blocks, 2: grass, 3: items, 4: macroblocks
    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) {
        return inv.RootNodes[RootNodeIx];
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) {
        warn('override me: SetPlacementMode');
        editor.ButtonNormalBlockModeOnClick();
        // editor.PluginMapType.Inventory.
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
#if SIG_DEVELOPER
        if (UI::Button(Icons::Cube + "##" + node.Name)) {
            ExploreNod("Article " + node.NodeName, node);
            // node.GetCollectorNod() points to .Article.LoadedNod (and probs loads it if need be)
            // auto cnod = node.GetCollectorNod();
            // if (cnod !is null) {
            //     ExploreNod("CollectorNod " + node.NodeName, cnod);
            // }
        }
        UI::SameLine();
#endif
        if (UI::Button(node.Name)) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            // we must set the placement node to the correct type, first, otherwise we get a crash
            SetPlacementMode(editor);
            auto inv = editor.PluginMapType.Inventory;
            inv.SelectArticle(node);
        }
    }

    void DrawInvNodeTreeDir(CGameCtnArticleNodeDirectory@ node) {
        bool isRoot = node.Name.Length == 0;
        if (isRoot || UI::TreeNode(string(node.Name))) {
            for (uint i = 0; i < node.ChildNodes.Length; i++) {
                DrawInvNodeTree(node.ChildNodes[i]);
            }
            if (!isRoot) UI::TreePop();
        }
    }
}

class BlocksInventoryBrowserTab : GenericInventoryBrowserTab {
    BlocksInventoryBrowserTab(TabGroup@ p) {
        super(p, "Blocks", Icons::FolderOpenO + Icons::Cube, 1);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        if (!Editor::IsInBlockPlacementMode(editor)) {
            // keeps old block placement options or cycles
            editor.ButtonNormalBlockModeOnClick();
        }
    }

    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) override {
        return inv.RootNodes[1];
    }
}
class BlocksBrokenInventoryBrowserTab : GenericInventoryBrowserTab {
    BlocksBrokenInventoryBrowserTab(TabGroup@ p) {
        super(p, "Root Node 0 crashes the game", Icons::FolderOpenO + Icons::Cube, 0);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        if (!Editor::IsInBlockPlacementMode(editor)) {
            // keeps old block placement options or cycles
            editor.ButtonNormalBlockModeOnClick();
        }
    }

    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) override {
        return inv.RootNodes[0];
    }
}

class ItemsInventoryBrowserTab : GenericInventoryBrowserTab {
    ItemsInventoryBrowserTab(TabGroup@ p) {
        super(p, "Items", Icons::FolderOpenO + Icons::Tree, 3);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        if (Editor::GetPlacementMode(editor) != CGameEditorPluginMap::EPlaceMode::Item) {
            Editor::SetItemPlacementMode(Editor::ItemMode::Normal);
            // if (Editor::GetItemPlacementMode() == Editor::ItemMode::None) {
            // }
        }
    }

    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) override {
        return inv.RootNodes[3];
    }
}

class MacroblocksInventoryBrowserTab : GenericInventoryBrowserTab {
    MacroblocksInventoryBrowserTab(TabGroup@ p) {
        super(p, "Macroblocks", Icons::FolderOpenO + Icons::Cubes, 4);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        editor.ButtonNormalMacroblockModeOnClick();
        // if (!Editor::IsInBlockPlacementMode(editor)) {
        //     // keeps old block placement options or cycles
        //     editor.ButtonNormalBlockModeOnClick();
        // }
    }

    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) override {
        return inv.RootNodes[4];
    }
}
