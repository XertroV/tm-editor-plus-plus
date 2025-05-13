class MapExtractItems : Tab {
    MapExtractItems(TabGroup@ parent) {
        super(parent, "\\$fa8Extract Items", Icons::MapO + Icons::ArrowRight + Icons::FolderOpenO);
        removable = false;
        // RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEnterEditor), this.tabName);
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

        auto mapContentZip = Fids::GetFake("MemoryTemp/CurrentMap_EmbeddedFiles/MapContentLoaded.zip");
        auto fidFolder = Fids::GetFakeFolder("MemoryTemp/CurrentMap_EmbeddedFiles/ContentLoaded");
        // zip
        if (mapContentZip !is null) {
            UI::Text(mapContentZip.FileName);
            UI::AlignTextToFramePadding();
            auto zipNod = cast<CPlugFileZip>(mapContentZip.Nod);
#if SIG_DEVELOPER
            UI::SameLine();
            if (UX::SmallButton(Icons::Cube + "##map-zip-fid-explore")) {
                ExploreNod("Map .zip Fid", mapContentZip);
            }
#endif
            UI::SameLine();
            UI::BeginDisabled(zipNod is null);
            if (UX::SmallButton("Copy entire MapContentLoaded.zip")) {
                if (Fids::Extract(mapContentZip)) {
                    NotifySuccess("Extracted MapContentLoaded.zip");
                    OpenExplorerPath(IO::FromDataFolder("Extract/MemoryTemp/CurrentMap_EmbeddedFiles"));
                } else {
                    NotifyError("Failed to extract MapContentLoaded.zip");
                }
            }
            UI::EndDisabled();
            if (zipNod !is null) {
                LabeledValue("NbFiles", zipNod.NbFiles);
            } else {
                UI::Text("Unexpected: FID.Nod (CPlugFileZip) is null.");
            }
        } else {
            UI::Text("MapContentLoaded.zip temporary zip file not found.");
        }

        UI::Separator();

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

    auto treeFlags = depth < 30 ? UI::TreeNodeFlags::DefaultOpen : UI::TreeNodeFlags::None;
    auto fidPtr = Dev_GetPointerForNod(folder);
    auto folderFromTmRoot = string(folder.DirName);
    if (folder.FullDirName.Contains("ContentLoaded\\")) {
        folderFromTmRoot = string(folder.FullDirName).Split("ContentLoaded\\")[1];
    }
    UI::PushID(fidPtr);

    if (UX::SmallButton(Icons::Cubes + Icons::SignOut + Icons::FolderOpenO + "##" + fidPtr)) {
        ExtractMapItemsFolder(folder);
    }
    AddSimpleTooltip("Extract all under " + folderFromTmRoot);
    UI::SameLine();
#if SIG_DEVELOPER
    if (UX::SmallButton(Icons::Cube + "##" + fidPtr)) {
        ExploreNod("FidFolder " + string(folder.DirName), folder);
    }
    UI::SameLine();
    CopiableLabeledValueTooltip("ptr", Text::FormatPointer(fidPtr));
    UI::SameLine();
#endif

    if (UI::TreeNode(string(folder.DirName), treeFlags)) {
        UI::PushID(folder.DirName);

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

    UI::PopID();
}

void DrawFidFileBrowser(CSystemFidFile@ file) {
    UI::PushID(file);

#if SIG_DEVELOPER
    if (UX::SmallButton("" + Icons::Cube)) {
        ExploreNod("FidFile " + file.FileName, file);
    }
    UI::SameLine();
    CopiableLabeledValueTooltip("ptr", Text::FormatPointer(Dev_GetPointerForNod(file)));
    UI::SameLine();
#endif
    UI::Text("\\$6e6" + string(file.FileName));
    UI::SameLine();

    if (file.Nod is null) {
        if (UX::SmallButton("Preload")) {
            auto nod = Fids::Preload(file);
            if (nod is null) NotifyError("Failed to preload nod in " + file.FileName);
        }
    } else {
        UI::Text("\\$f29" + Reflection::TypeOf(file.Nod).Name);
    }

    UI::PopID();
}



void ExtractMapItemsFile(CSystemFidFile@ file) {
    if (file is null) {
        NotifyWarning("Got unexpected null fid file");
        return;
    }
    if (file.Nod is null) Fids::Preload(file);
    if (!Fids::Extract(file)) {
        NotifyWarning("Failed to extract file: " + file.FileName);
        return;
    }
    string itemFileName = file.FileName;
    auto extractFolder = GetFidFolderExtractPath(file.ParentFolder);
    auto itemsFolder = IO::FromUserGameFolder(GetFidPathRelativeToDocsTM(file.ParentFolder.FullDirName));
    auto from = extractFolder + itemFileName;
    string to = itemsFolder + itemFileName;
    trace("Moving file: " + from + " to " + to);
    if (!IO::FileExists(from)) {
        NotifyWarning("Missing file after extraction: " + from);
    }
    IO::Move(from, to);
}

void ExtractMapItemsFolder(CSystemFidsFolder@ folder) {
    auto folderFromTmRoot = GetFidPathRelativeToDocsTM(folder.FullDirName);
    auto folderPath = IO::FromUserGameFolder(folderFromTmRoot);
    if (!IO::FolderExists(folderPath)) {
        IO::CreateFolder(folderPath);
        trace("Created folder: " + folderFromTmRoot);
    }
    for (uint i = 0; i < folder.Leaves.Length; i++) {
        ExtractMapItemsFile(folder.Leaves[i]);
    }
    for (uint i = 0; i < folder.Trees.Length; i++) {
        ExtractMapItemsFolder(folder.Trees[i]);
    }
}

string GetFidPathRelativeToDocsTM(const string &in fullDirName) {
    try {
        return fullDirName.Split("CurrentMap_EmbeddedFiles\\ContentLoaded\\")[1].Replace("\\", "/");
    } catch {
        NotifyError("Failed to get relative folder path from: " + fullDirName);
        return "";
    }
}

string GetFidFolderExtractPath(CSystemFidsFolder@ folder) {
    if (!folder.FullDirName.StartsWith("<fake>\\MemoryTemp\\")) {
        throw("fid folder isn't <fake>\\MemoryTemp\\");
    }
    auto relativeToExtract = string(folder.FullDirName).SubStr(7);
    return IO::FromDataFolder("Extract\\" + relativeToExtract).Replace("\\", "/");
}
// <fake>\MemoryTemp\CurrentMap_EmbeddedFiles\ContentLoaded\Items\z983-waypoint_stickers_2022\waypoint_stickers_2022_1XL\waypoint_stickers_6_1XL\
