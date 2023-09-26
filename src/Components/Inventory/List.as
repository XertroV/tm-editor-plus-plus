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
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // we can occasionally get an index out of range exception entering the editor.
        if (editor.PluginMapType.Inventory.RootNodes.Length < 4) {
            return;
        }
        Children.DrawTabs();
    }
}

class GenericInventoryBrowserTab : Tab {
    uint RootNodeIx = 1;
    CGameCtnArticleNode@ OverrideRootNode;

    bool showExplore = true;
    bool showPopout = true;

    GenericInventoryBrowserTab(TabGroup@ p, const string &in name, const string &in icon, uint rnIx) {
        super(p, name, icon);
        RootNodeIx = rnIx;
        @WindowChildren = TabGroup(name, this);
    }

    // 0: blocks but crashes, 1: blocks, 2: grass, 3: items, 4: macroblocks
    CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) {
        if (OverrideRootNode !is null) {
            return OverrideRootNode;
        }
        return inv.RootNodes[RootNodeIx];
    }

    // override this method in classes that inherit this if they aren't for blocks
    void SetPlacementMode(CGameCtnEditorFree@ editor) {
        // warn('override me: SetPlacementMode');
        editor.ButtonNormalBlockModeOnClick();
        // editor.PluginMapType.Inventory.
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = editor.PluginMapType.Inventory;
        auto rn = GetRootNode(inv);
        if (rn.Name.Length > 0)
            UI::Text(tabName);
        DrawInvNodeTree("", rn);
    }

    void DrawInvNodeTree(const string &in prior, CGameCtnArticleNode@ node) {
        if (node.IsDirectory) {
            DrawInvNodeTreeDir(prior, cast<CGameCtnArticleNodeDirectory>(node));
        } else {
            DrawInvNodeTreeArticle(cast<CGameCtnArticleNodeArticle>(node));
        }
    }

    void DrawInvNodeTreeArticle(CGameCtnArticleNodeArticle@ node) {
#if SIG_DEVELOPER
        if (showExplore) {
            if (UI::Button(Icons::Cube + "##" + node.Name)) {
                ExploreNod("Article " + node.NodeName, node);
                // node.GetCollectorNod() points to .Article.LoadedNod (and probs loads it if need be)
                // auto cnod = node.GetCollectorNod();
                // if (cnod !is null) {
                //     ExploreNod("CollectorNod " + node.NodeName, cnod);
                // }
            }
            UI::SameLine();
        }
#endif
        if (UI::Button(TrimNodeName(node.Name))) {
            OnSelectNode(node);
        }
    }

    void OnSelectNode(CGameCtnArticleNodeArticle@ node) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // we must set the placement node to the correct type, first, otherwise we get a crash
        SetPlacementMode(editor);
        auto inv = editor.PluginMapType.Inventory;
        inv.SelectArticle(node);
    }

    dictionary nodeNameTrimmedCache;
    const string TrimNodeName(const string &in name) {
        if (name.Contains("\\")) {
            if (!nodeNameTrimmedCache.Exists(name)) {
                auto parts = name.Split("\\");
                nodeNameTrimmedCache[name] = parts[parts.Length - 1];
            }
            return string(nodeNameTrimmedCache[name]);
        }
        return name;
    }

    void DrawInvNodeTreeDir(const string &in prior, CGameCtnArticleNodeDirectory@ node) {
        bool isRoot = prior.Length == 0 || node.Name.Length == 0;
        auto nextPrior = (isRoot ? "" : prior) + node.Name + " > ";
        if (!isRoot) {
            if (showPopout && UX::SmallButton(Icons::Expand + "##inv-" + nextPrior)) {
                // create an instance of the current class
                // as a standalone tab with a new 'root node'
                // that is an emphemeral window that is cleared
                // from memory when closed
                CreateTempChildWindow(nextPrior, node);
            }
            UI::SameLine();
        }
        // if (isRoot) UI::SetNextItemOpen(isRoot, UI::Cond::Always);
        if (isRoot || UI::TreeNode(string(node.Name))) {
            for (uint i = 0; i < node.ChildNodes.Length; i++) {
                DrawInvNodeTree(nextPrior, node.ChildNodes[i]);
            }
            if (!isRoot) UI::TreePop();
        }
    }

    // override this to create an appropriate type with the right methods
    GenericInventoryBrowserTab@ CreateNewSameType(TabGroup@ p, const string &in name, const string &in icon) {
        return GenericInventoryBrowserTab(p, name, icon, RootNodeIx);
    }

    GenericInventoryBrowserTab@ CreateTempChildWindow(const string &in prior, CGameCtnArticleNodeDirectory@ node) {
        auto popoutTab = CreateNewSameType(Parent.Parent.WindowChildren, prior, "");
        popoutTab.windowOpen = true;
        @popoutTab.OverrideRootNode = node;
        return popoutTab;
    }
}

class BlocksInventoryBrowserTab : GenericInventoryBrowserTab {
    BlocksInventoryBrowserTab(TabGroup@ p) {
        super(p, "Blocks", Icons::FolderOpenO + Icons::Cube, 1);
    }

    BlocksInventoryBrowserTab(TabGroup@ p, const string &in name) {
        super(p, name, "", 1);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        Editor::EnsureBlockPlacementMode(editor);
    }

    GenericInventoryBrowserTab@ CreateNewSameType(TabGroup@ p, const string&in name, const string&in icon) override {
        return BlocksInventoryBrowserTab(p, name);
    }
}

class BlocksBrokenInventoryBrowserTab : GenericInventoryBrowserTab {
    BlocksBrokenInventoryBrowserTab(TabGroup@ p) {
        super(p, "Root Node 0 crashes the game", Icons::FolderOpenO + Icons::Cube, 0);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        Editor::EnsureBlockPlacementMode(editor);
        // if (!Editor::IsInBlockPlacementMode(editor)) {
        //     // keeps old block placement options or cycles
        //     editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
        // }
    }
}

class ItemsInventoryBrowserTab : GenericInventoryBrowserTab {
    ItemsInventoryBrowserTab(TabGroup@ p) {
        super(p, "Items", Icons::FolderOpenO + Icons::Tree, 3);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        Editor::EnsureItemPlacementMode(editor);

        // if (Editor::GetPlacementMode(editor) != CGameEditorPluginMap::EPlaceMode::Item) {
        //     editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
        //     Editor::SetItemPlacementMode(Editor::ItemMode::Normal);
        //     // if (Editor::GetItemPlacementMode() == Editor::ItemMode::None) {
        //     // }
        // }
    }
}

class MacroblocksInventoryBrowserTab : GenericInventoryBrowserTab {
    MacroblocksInventoryBrowserTab(TabGroup@ p) {
        super(p, "Macroblocks", Icons::FolderOpenO + Icons::Cubes, 4);
    }

    void SetPlacementMode(CGameCtnEditorFree@ editor) override {
        Editor::EnsureMacroblockPlacementMode(editor);
        // editor.ButtonNormalMacroblockModeOnClick();
        // editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Macroblock;
        // if (!Editor::IsInBlockPlacementMode(editor)) {
        //     // keeps old block placement options or cycles
        //     editor.ButtonNormalBlockModeOnClick();
        // }
    }
}
