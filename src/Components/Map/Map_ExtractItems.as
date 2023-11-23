class MapExtractItems : Tab {
    MapExtractItems(TabGroup@ parent) {
        super(parent, "\\$f00Extract Items", Icons::MapO + Icons::ArrowRight + Icons::FolderOpenO);
        removable = false;
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEnterEditor), this.tabName);
    }

    void OnEnterEditor() {
    }

    void DrawInner() override {
        CGameCtnChallenge@ map = null;
        CGameCtnEditorFree@ editor = null;
        try {
            @map = (@editor = cast<CGameCtnEditorFree>(GetApp().Editor)).Challenge;
        } catch {};
        if (map is null) {
            UI::Text("Open a map in the editor.");
            return;
        }

        auto fidFolder = Fids::GetFakeFolder("<fake>\\MemoryTemp\\CurrentMap_EmbeddedFiles\\ContentLoaded");
        if (fidFolder is null) {
            UI::Text("Failed to get folder for embedded items.");
            return;
        }

        DrawFidFolderBrowser(fidFolder);
    }
}


void DrawFidFolderBrowser(CSystemFidsFolder@ folder, uint depth = 0) {
    if (folder is null) {
        UI::Text("Folder null!");
        return;
    }

    auto treeFlags = depth < 3 ? UI::TreeNodeFlags::DefaultOpen : UI::TreeNodeFlags::None;
    if (UI::TreeNode(string(folder.DirName), treeFlags)) {


        UI::TreePop();
    }
}
