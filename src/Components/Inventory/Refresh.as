class ItemEmbedTab : Tab {
    ItemEmbedTab(TabGroup@ p) {
        super(p, "Embed Items", Icons::FolderOpenO + Icons::Refresh);
    }

    uint step = 1;

    void DrawInner() override {
        if (UI::Button("Reset##refrehs-items-step")) {
            step = 1;
            @step3Req = null;
        }
        UI::Separator();
        DrawStep1();
        UI::Separator();
        DrawStep2();
        UI::Separator();
        DrawStep3();
        UI::Separator();
        DrawStep4();
        UI::Separator();
    }

    uint lastRefresh = 0;

    CSystemFidsFolder@ itemsFolder;
    uint nbItemsInLocalFolder = 0;
    string[] localItemPaths;


    void DrawStep1() {
        UI::BeginDisabled(step != 1);
        UI::Text("Step 1. Scan for items");
        UI::Text("Last refresh: " + Time::Format(Time::Now - lastRefresh, true, true, true));
        UI::Text("Nb Items Counted: " + nbItemsInLocalFolder);
        if (localItemPaths.Length > 0) {
            UI::Text("First item: " + localItemPaths[0]);
        }
        if (localItemPaths.Length > 1) {
            UI::Text("2nd item: " + localItemPaths[1]);
        }

        if (UI::Button("Scan for Items")) {
            startnew(CoroutineFunc(RunStep1));
            lastRefresh = Time::Now;
            step++;
        }

        UI::EndDisabled();
    }

    string itemsFolderPrefix;

    void RunStep1() {
        @itemsFolder = Fids::GetUserFolder("Items");
        itemsFolderPrefix = itemsFolder.FullDirName;
        // Fids::UpdateTree(itemsFolder);
        // cache items
        nbItemsInLocalFolder = 0;
        localItemPaths.RemoveRange(0, localItemPaths.Length);
        CacheItemsFolder(itemsFolderPrefix.SubStr(0, itemsFolderPrefix.Length - 1));
    }

    void CacheItemsFolder(const string &in folderPath) {
        auto ctn = IO::IndexFolder(folderPath, true);
        for (uint i = 0; i < ctn.Length; i++) {
            if (IsItemFileName(ctn[i])) {
                nbItemsInLocalFolder++;
                localItemPaths.InsertLast(ctn[i].Replace('/', '\\').SubStr(itemsFolderPrefix.Length));
                trace('cached; ' + ctn[i]);
            }
        }
    }

    void CacheItemFids(CSystemFidsFolder@ folder) {
        for (uint i = 0; i < folder.Leaves.Length; i++) {
            CacheItemFids(folder.Leaves[i]);
        }
        for (uint i = 0; i < folder.Trees.Length; i++) {
            CacheItemFids(folder.Trees[i]);
        }
    }

    void CacheItemFids(CSystemFidFile@ leaf) {
        if (IsItemFileName(leaf.FileName)) {
            nbItemsInLocalFolder++;
            localItemPaths.InsertLast(string(leaf.FullFileName).SubStr(itemsFolderPrefix.Length));
            // trace('Caching local item: ' + leaf.FullFileName);
        }
    }

    bool IsItemFileName(const string &in fileName) {
        auto suffix = fileName.SubStr(fileName.Length - 9).ToLower();
        return suffix == ".item.gbx"; // || suffix == "block.gbx";
    }

    uint nbCachedInvItems = 0;
    string[] cachedInvItemPaths;

    void DrawStep2() {
        UI::BeginDisabled(step != 2);
        UI::Text("Step 2. Scan Inventory for Differences");
        UI::Text("Nb Items Counted: " + nbCachedInvItems);
        if (cachedInvItemPaths.Length > 0) {
            UI::Text("First item: " + cachedInvItemPaths[0]);
        }
        UI::Text("Items missing from Inventory: " + missingItems.Length);
        if (missingItems.Length > 0) {
            UI::Text("First missing item: " + missingItems[0]);
            if (missingItems.Length > 1)
                UI::Text("2nd. missing item: " + missingItems[1]);
        }

        if (UI::Button("Scan Inventory")) {
            startnew(CoroutineFunc(RunStep2));
            step++;
        }

        UI::EndDisabled();
    }

    void RunStep2() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = editor.PluginMapType.Inventory;
        CGameCtnArticleNodeDirectory@ itemRN = cast<CGameCtnArticleNodeDirectory>(inv.RootNodes[3]);
        CGameCtnArticleNodeDirectory@ customNode;
        for (uint i = itemRN.ChildNodes.Length - 1; i < itemRN.ChildNodes.Length; i--) {
            auto node = itemRN.ChildNodes[i];
            if (node.Name == "Custom") {
                @customNode = cast<CGameCtnArticleNodeDirectory>(node);
                break;
            }
        }
        if (customNode is null) {
            throw('could not find custom items node');
        }
        nbCachedInvItems = 0;
        cachedInvItemPaths.RemoveRange(0, cachedInvItemPaths.Length);
        CacheInvItem(customNode);
        CacheItemDiff();
    }

    void CacheInvItem(CGameCtnArticleNode@ node) {
        auto dir = cast<CGameCtnArticleNodeDirectory>(node);
        if (dir is null) {
            CacheInvItem(cast<CGameCtnArticleNodeArticle>(node));
        } else {
            CacheInvItem(dir);
        }
    }
    void CacheInvItem(CGameCtnArticleNodeDirectory@ node) {
        for (uint i = 0; i < node.ChildNodes.Length; i++) {
            CacheInvItem(node.ChildNodes[i]);
        }
    }
    void CacheInvItem(CGameCtnArticleNodeArticle@ node) {
        if (node.Article is null) {
            warn('null collector nod for ' + node.Name);
            return;
        }
        nbCachedInvItems++;
        // if we delete some files and refresh Fids, this can happen
        if (node.Article.CollectorFid is null) return;
        cachedInvItemPaths.InsertLast(string(node.Article.CollectorFid.FullFileName).SubStr(itemsFolderPrefix.Length));
    }

    dictionary seenItems;
    string[] missingItems;
    void CacheItemDiff() {
        seenItems.DeleteAll();
        missingItems.RemoveRange(0, missingItems.Length);
        for (uint i = 0; i < cachedInvItemPaths.Length; i++) {
            if (seenItems.Exists(cachedInvItemPaths[i])) {
                warn("duplicate item in inventory list: " + cachedInvItemPaths[i]);
            }
            seenItems[cachedInvItemPaths[i]] = true;
        }
        for (uint i = 0; i < localItemPaths.Length; i++) {
            if (!seenItems.Exists(localItemPaths[i])) {
                missingItems.InsertLast(localItemPaths[i]);
            }
        }
    }

    Net::HttpRequest@ step3Req;
    void DrawStep3() {
        UI::BeginDisabled(step != 3);
        UI::Text("Step 3. Request embed items to map");

        // UI::Text("Status: " + (step3Req is null ? "Not started" :
        //     !step3Req.Finished() ? "In Progress" :
        //     step3Req.ResponseCode() != 200 ? "Error: " + step3Req.Error()
        //     : "Done"));

        UI::BeginDisabled(step3Req !is null);
        if (UI::Button("Get Updated Map")) {
            startnew(CoroutineFunc(RunStep3));
        }
        UI::EndDisabled();

        UI::EndDisabled();
    }

    void RunStep3() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        Editor::SaveMapSameName(editor);
        yield();
        string mapFileName = editor.Challenge.MapInfo.FileName;
        if (mapFileName.Length == 0) return;
        string mapFileFullName = IO::FromUserGameFolder("Maps/" + mapFileName);
        CopyFile(mapFileFullName, mapFileFullName.SubStr(0, mapFileFullName.Length - 8) + "_backup.Map.Gbx");
        MemoryBuffer@ data = MemoryBuffer();
        data.Write(uint32(0));
        Json::Value@ items = Json::Array();
        for (uint i = 0; i < missingItems.Length; i++) {
            items.Add(missingItems[i]);
        }
        _WriteString(data, Json::Write(items));
        _WriteUint(data, items.Length);
        for (uint i = 0; i < missingItems.Length; i++) {
            _WriteFileBytes(data, itemsFolderPrefix + missingItems[i]);
        }
        yield();
        _WriteFileBytes(data, IO::FromUserGameFolder("Maps/" + mapFileName));
        data.Seek(0);
        _WriteUint(data, data.GetSize());
        data.Seek(0);
        string pl = data.ReadToBase64(data.GetSize());
        print('pl size: ' + data.GetSize() + ' / b64: ' + pl.Length);
        // @step3Req = Net::HttpPost("http://localhost:8000/itemrefresh/create_map", pl);
        @step3Req = Net::HttpPost("http://74.234.75.72:80/itemrefresh/create_map", pl);
        sleep(5000);
        trace('waited 5s');
        while (!step3Req.Finished()) {
            yield();
        }
        trace('req done');
        if (step3Req.ResponseCode() != 200) {
            warn('resp code: ' + step3Req.ResponseCode());
            return;
        }
        auto app = cast<CGameManiaPlanet>(GetApp());
        app.BackToMainMenu();
        AwaitReturnToMenu();
        sleep(50);
        auto buf = step3Req.Buffer();
        trace('writing to ' + mapFileFullName);
        IO::File mapFile(mapFileFullName, IO::FileMode::Write);
        mapFile.Write(buf);
        mapFile.Close();
        step++;
        sleep(50);
        cast<CGameManiaPlanet>(GetApp()).ManiaTitleControlScriptAPI.EditMap(mapFileName, '', '');
        step++;
    }

    void _WriteString(MemoryBuffer@ buf, const string &in str) {
        _WriteUint(buf, str.Length);
        buf.Write(str);
    }

    void _WriteUint(MemoryBuffer@ buf, uint val) {
        buf.Write(val);
    }

    void _WriteFileBytes(MemoryBuffer@ buf, const string &in filename) {
        IO::File f(filename, IO::FileMode::Read);
        auto fileContents = f.Read(f.Size());
        auto b64 = fileContents.ReadToBase64(fileContents.GetSize());
        _WriteUint(buf, fileContents.GetSize());
        buf.WriteFromBase64(b64);
    }

    void DrawStep4() {
        UI::BeginDisabled(step != 4);
        UI::Text("Step 4. Save, Load refresh map, Re-load this map");
        if (UI::Button("Load Refresh Map then reload this map")) {
            startnew(CoroutineFunc(RunStep4));
        }
        UI::EndDisabled();
    }

    void RunStep4() {
        Editor::NoSaveAndReloadMap();
        step = 1;
        @step3Req = null;
    }
}

const string RefreshMapFileName = "editor++-refresh-map.map.gbx";
const string RefreshMapLocalPath = IO::FromUserGameFolder("Maps/" + RefreshMapFileName);
