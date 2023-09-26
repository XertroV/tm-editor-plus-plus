// enum InventoryRootNode {
//     CrashBlocks = 0,
//     Blocks = 1,
//     Grass = 2,
//     Items = 3,
//     Macroblocks = 4,
// }


class InventoryMainV2Tab : Tab {
    InventoryMainV2Tab(TabGroup@ p) {
        super(p, "Inventory V2", Icons::FolderOpenO);
        canPopOut = true;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // we can occasionally get an index out of range exception entering the editor.
        if (editor.PluginMapType.Inventory.RootNodes.Length < 4) {
            return;
        }

        UI::Unindent();
        // UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(0));
        // UI::PushStyleVar(UI::StyleVar::WindowPadding, vec2(0));
        // UI::PushStyleVar(UI::StyleVar::ChildRounding, 0);
        // UI::PushStyleVar(UI::StyleVar::CellPadding, vec2(0));
        InvDrawVals::Update();
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(0));
        DrawInvMain(editor, Editor::GetInventoryCache());
        UI::PopStyleVar(1);
        UI::Indent();

        Children.DrawTabs();
    }

    float colWidth;
    float colGap = 12.;
    float colPad;

    InvColumn@ MainCol = MainInvColumn();

    void DrawInvMain(CGameCtnEditorFree@ editor, Editor::InventoryCache@ inv) {
        // we want to draw the inventory vertically, going left to right in columns.
        // idea is to stick it at the left of the screen.
        // each column is scrollable

        // column1 is the base column: Blocks, Items x3, Macroblocks, (and grass, mb)
        MainCol.Draw(editor, inv);
    }
}



namespace InvDrawVals {
    float colWidth;
    float colWidthFull;
    float colGap = 12.;
    float colPad;
    vec2 initItemSpacing;

    void Update() {
        colWidth = S_IconSize.x;
        colWidthFull = colWidth + colGap + UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize);
        colPad = colGap / 2.;
        initItemSpacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
    }
}

string selectedInvDir;

class InvNode {
    FavObj@ ui;
    bool isItem, isDirectory;
    InvColumn@ parent;
    string fullName;
    FavObj@ firstLeaf;

    InvNode(CGameCtnArticleNode@ node, bool isItem, InvColumn@ parent) {
        this.isItem = isItem;
        @this.parent = parent;
        this.isDirectory = node.IsDirectory && cast<CGameCtnArticleNodeDirectory>(node) !is null;
        fullName = node.IsDirectory ? parent.PathAppend(node.NodeName) : string(node.NodeName);
        @ui = FavObj(fullName, isItem, isDirectory, isDirectory ? CoroutineFunc(this.DirCallback) : null);
        if (isDirectory) SetFirstLeaf(cast<CGameCtnArticleNodeDirectory>(node));
    }
    // for subclasses that want to set things up
    InvNode(InvColumn@ parent) {
        @this.parent = parent;
    }

    void SetFirstLeaf(CGameCtnArticleNodeDirectory@ node) {
        CGameCtnArticleNodeDirectory@ lastNode = node;
        while (node !is null) {
            @lastNode = node;
            @node = cast<CGameCtnArticleNodeDirectory>(node.ChildNodes[0]);
        }
        @firstLeaf = FavObj(cast<CGameCtnArticleNodeArticle>(lastNode.ChildNodes[0]).NodeName, isItem, false);
        trace('DEBUG firstLeaf: ' + firstLeaf.nodeName);
    }

    // cb for selection
    void DirCallback() {
        trace('dir callback: ' + ui.nodeName);
        parent.OpenChildDir(this);
    }

    void Draw(CGameCtnEditorFree@ editor, Editor::InventoryCache@ inv) {
        if (firstLeaf !is null) firstLeaf.DrawFavBgEntry();
        ui.DrawFavEntry(editor, inv);
    }
}

class InvNodeBlocks : InvNode {
    InvNodeBlocks(InvColumn@ parent) {
        super(parent);
        isItem = false;
        isDirectory = true;
        @ui = FavObj("Blocks", isItem, isDirectory, CoroutineFunc(this.DirCallback));
    }
}
class InvNodeItemsOfficial : InvNode {
    InvNodeItemsOfficial(InvColumn@ parent) {
        super(parent);
        isItem = true;
        isDirectory = true;
        @ui = FavObj("Items Official", isItem, isDirectory, CoroutineFunc(this.DirCallback));
    }
}
class InvNodeItemsClub : InvNode {
    InvNodeItemsClub(InvColumn@ parent) {
        super(parent);
        isItem = true;
        isDirectory = true;
        @ui = FavObj("Items Club", isItem, isDirectory, CoroutineFunc(this.DirCallback));
    }
}
class InvNodeItemsCustom : InvNode {
    InvNodeItemsCustom(InvColumn@ parent) {
        super(parent);
        isItem = true;
        isDirectory = true;
        @ui = FavObj("Items Custom", isItem, isDirectory, CoroutineFunc(this.DirCallback));
    }
}
class InvNodeMacroblocks : InvNode {
    InvNodeMacroblocks(InvColumn@ parent) {
        super(parent);
        isItem = false;
        isDirectory = true;
        @ui = FavObj("Macroblocks", isItem, isDirectory, CoroutineFunc(this.DirCallback));
    }
}

class InvColumn {
    int selectedChild = -1;
    InvNode@[] children;
    bool isItem;
    string nodeName;
    InvColumn@ parent;
    string fullPath;
    string childId;
    InvColumn@ openChild;

    InvColumn(InvColumn@ parent, const string &in nodeName, MwFastBuffer<CGameCtnArticleNode@> &in children, bool isItem) {
        this.isItem = isItem;
        @this.parent = parent;
        fullPath = nodeName;
        childId = "inv-node-" + fullPath;
        this.nodeName = nodeName;
        for (uint i = 0; i < children.Length; i++) {
            this.children.InsertLast(InvNode(children[i], isItem, this));
        }
    }
    InvColumn(bool manualSetup) {}

    string PathAppend(const string &in childName) {
        if (fullPath.Length > 0) return fullPath + "\\" + childName;
        return childName;
    }

    void OpenChildDir(InvNode@ node) {
        if (!node.isDirectory) {
            NotifyWarning("Cannot open an inventory node that is not a directory");
            return;
        }
        auto inv = Editor::GetInventoryCache();
        auto invNode = cast<CGameCtnArticleNodeDirectory>(node.ui.GetInvArticle(inv));
        @openChild = InvColumn(this, node.ui.nodeName, invNode.ChildNodes, node.isItem);
    }

    void Draw(CGameCtnEditorFree@ editor, Editor::InventoryCache@ inv) {
        float h = UI::GetWindowContentRegionMin().y - UI::GetCursorPos().y + UI::GetScrollY() - UI::GetStyleVarVec2(UI::StyleVar::FramePadding).y * 4;
        if (UI::BeginChild(childId, vec2(InvDrawVals::colWidthFull, h), false, UI::WindowFlags::AlwaysVerticalScrollbar)) {
            UI::Dummy(vec2(InvDrawVals::colPad));
            UI::ListClipper clip(children.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::Dummy(vec2(InvDrawVals::colPad));
                    UI::SameLine();
                    UI::PushStyleVar(UI::StyleVar::ItemSpacing, InvDrawVals::initItemSpacing);
                    children[i].Draw(editor, inv);
                    UI::PopStyleVar(1);
                    UI::Dummy(vec2(InvDrawVals::colPad));
                }
            }
            UI::Dummy(vec2(InvDrawVals::colPad));
        }
        UI::EndChild();
        UI::SameLine();
        if (openChild !is null) {
            openChild.Draw(editor, inv);
        }
    }
}

class MainInvColumn : InvColumn {
    MainInvColumn() {
        super(true);
        fullPath = "";
        childId = "inv-node-root";
        // nodeName = "";
        children.InsertLast(InvNodeBlocks(this));
        children.InsertLast(InvNodeItemsOfficial(this));
        children.InsertLast(InvNodeItemsClub(this));
        children.InsertLast(InvNodeItemsCustom(this));
        children.InsertLast(InvNodeMacroblocks(this));
    }
}



// class GenericInventoryBrowserTab : Tab {
//     uint RootNodeIx = 1;
//     CGameCtnArticleNode@ OverrideRootNode;

//     bool showExplore = true;
//     bool showPopout = true;

//     GenericInventoryBrowserTab(TabGroup@ p, const string &in name, const string &in icon, uint rnIx) {
//         super(p, name, icon);
//         RootNodeIx = rnIx;
//         @WindowChildren = TabGroup(name, this);
//     }

//     // 0: blocks but crashes, 1: blocks, 2: grass, 3: items, 4: macroblocks
//     CGameCtnArticleNode@ GetRootNode(CGameEditorGenericInventory@ inv) {
//         if (OverrideRootNode !is null) {
//             return OverrideRootNode;
//         }
//         return inv.RootNodes[RootNodeIx];
//     }

//     // override this method in classes that inherit this if they aren't for blocks
//     void SetPlacementMode(CGameCtnEditorFree@ editor) {
//         // warn('override me: SetPlacementMode');
//         editor.ButtonNormalBlockModeOnClick();
//         // editor.PluginMapType.Inventory.
//     }

//     void DrawInner() override {
//         auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
//         auto inv = editor.PluginMapType.Inventory;
//         auto rn = GetRootNode(inv);
//         if (rn.Name.Length > 0)
//             UI::Text(tabName);
//         DrawInvNodeTree("", rn);
//     }

//     void DrawInvNodeTree(const string &in prior, CGameCtnArticleNode@ node) {
//         if (node.IsDirectory) {
//             DrawInvNodeTreeDir(prior, cast<CGameCtnArticleNodeDirectory>(node));
//         } else {
//             DrawInvNodeTreeArticle(cast<CGameCtnArticleNodeArticle>(node));
//         }
//     }

//     void DrawInvNodeTreeArticle(CGameCtnArticleNodeArticle@ node) {
// #if SIG_DEVELOPER
//         if (showExplore) {
//             if (UI::Button(Icons::Cube + "##" + node.Name)) {
//                 ExploreNod("Article " + node.NodeName, node);
//                 // node.GetCollectorNod() points to .Article.LoadedNod (and probs loads it if need be)
//                 // auto cnod = node.GetCollectorNod();
//                 // if (cnod !is null) {
//                 //     ExploreNod("CollectorNod " + node.NodeName, cnod);
//                 // }
//             }
//             UI::SameLine();
//         }
// #endif
//         if (UI::Button(TrimNodeName(node.Name))) {
//             OnSelectNode(node);
//         }
//     }

//     void OnSelectNode(CGameCtnArticleNodeArticle@ node) {
//         auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
//         // we must set the placement node to the correct type, first, otherwise we get a crash
//         SetPlacementMode(editor);
//         auto inv = editor.PluginMapType.Inventory;
//         inv.SelectArticle(node);
//     }

//     dictionary nodeNameTrimmedCache;
//     const string TrimNodeName(const string &in name) {
//         if (name.Contains("\\")) {
//             if (!nodeNameTrimmedCache.Exists(name)) {
//                 auto parts = name.Split("\\");
//                 nodeNameTrimmedCache[name] = parts[parts.Length - 1];
//             }
//             return string(nodeNameTrimmedCache[name]);
//         }
//         return name;
//     }

//     void DrawInvNodeTreeDir(const string &in prior, CGameCtnArticleNodeDirectory@ node) {
//         bool isRoot = prior.Length == 0 || node.Name.Length == 0;
//         auto nextPrior = (isRoot ? "" : prior) + node.Name + " > ";
//         if (!isRoot) {
//             if (showPopout && UX::SmallButton(Icons::Expand + "##inv-" + nextPrior)) {
//                 // create an instance of the current class
//                 // as a standalone tab with a new 'root node'
//                 // that is an emphemeral window that is cleared
//                 // from memory when closed
//                 CreateTempChildWindow(nextPrior, node);
//             }
//             UI::SameLine();
//         }
//         // if (isRoot) UI::SetNextItemOpen(isRoot, UI::Cond::Always);
//         if (isRoot || UI::TreeNode(string(node.Name))) {
//             for (uint i = 0; i < node.ChildNodes.Length; i++) {
//                 DrawInvNodeTree(nextPrior, node.ChildNodes[i]);
//             }
//             if (!isRoot) UI::TreePop();
//         }
//     }

//     // override this to create an appropriate type with the right methods
//     GenericInventoryBrowserTab@ CreateNewSameType(TabGroup@ p, const string &in name, const string &in icon) {
//         return GenericInventoryBrowserTab(p, name, icon, RootNodeIx);
//     }

//     GenericInventoryBrowserTab@ CreateTempChildWindow(const string &in prior, CGameCtnArticleNodeDirectory@ node) {
//         auto popoutTab = CreateNewSameType(Parent.Parent.WindowChildren, prior, "");
//         popoutTab.windowOpen = true;
//         @popoutTab.OverrideRootNode = node;
//         return popoutTab;
//     }
// }

// class BlocksInventoryBrowserTab : GenericInventoryBrowserTab {
//     BlocksInventoryBrowserTab(TabGroup@ p) {
//         super(p, "Blocks", Icons::FolderOpenO + Icons::Cube, 1);
//     }

//     BlocksInventoryBrowserTab(TabGroup@ p, const string &in name) {
//         super(p, name, "", 1);
//     }

//     void SetPlacementMode(CGameCtnEditorFree@ editor) override {
//         Editor::EnsureBlockPlacementMode(editor);
//     }

//     GenericInventoryBrowserTab@ CreateNewSameType(TabGroup@ p, const string&in name, const string&in icon) override {
//         return BlocksInventoryBrowserTab(p, name);
//     }
// }

// class BlocksBrokenInventoryBrowserTab : GenericInventoryBrowserTab {
//     BlocksBrokenInventoryBrowserTab(TabGroup@ p) {
//         super(p, "Root Node 0 crashes the game", Icons::FolderOpenO + Icons::Cube, 0);
//     }

//     void SetPlacementMode(CGameCtnEditorFree@ editor) override {
//         Editor::EnsureBlockPlacementMode(editor);
//     }
// }

// class ItemsInventoryBrowserTab : GenericInventoryBrowserTab {
//     ItemsInventoryBrowserTab(TabGroup@ p) {
//         super(p, "Items", Icons::FolderOpenO + Icons::Tree, 3);
//     }

//     void SetPlacementMode(CGameCtnEditorFree@ editor) override {
//         Editor::EnsureItemPlacementMode(editor);
//     }
// }

// class MacroblocksInventoryBrowserTab : GenericInventoryBrowserTab {
//     MacroblocksInventoryBrowserTab(TabGroup@ p) {
//         super(p, "Macroblocks", Icons::FolderOpenO + Icons::Cubes, 4);
//     }

//     void SetPlacementMode(CGameCtnEditorFree@ editor) override {
//         Editor::EnsureMacroblockPlacementMode(editor);
//     }
// }
