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

        auto fidFolder = Fids::GetFakeFolder("MemoryTemp/CurrentMap_EmbeddedFiles/ContentLoaded");
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
        UI::PushID(folder.DirName);

#if SIG_DEVELOPER
        if (UI::Button("Explore FidFolder " + Icons::Cube)) {
            ExploreNod("FidFolder " + string(folder.DirName), folder);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(folder)));
#endif
        uint nbLeaves = folder.Leaves.Length;
        uint nbTrees = folder.Trees.Length;
        for (uint i = 0; i < nbTrees; i++) {
            DrawFidFolderBrowser(folder.Trees[i], depth == 0 && nbLeaves == 0 ? 0 : depth + 1);
        }
        for (uint i = 0; i < nbLeaves; i++) {
            DrawFidFileBrowser(folder.Leaves[i]);
        }

        UI::PopID();
        UI::TreePop();
    }
}

void DrawFidFileBrowser(CSystemFidFile@ file) {
    UI::PushID(file);

#if SIG_DEVELOPER
    if (UI::Button("Explore Nod " + Icons::Cube)) {
        ExploreNod("FidFile " + file.FileName, file);
    }
    UI::SameLine();
    CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(file)));
#endif
    UI::Text(string(file.FileName));

    UI::PopID();
}
