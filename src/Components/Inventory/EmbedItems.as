class ItemEmbedTab : Tab {
    ItemEmbedTab(TabGroup@ p) {
        super(p, "Embed Items", Icons::FolderOpenO + Icons::Refresh);
    }

    uint step = 1;

    void DrawInner() override {
        UI::SetNextItemOpen(true, UI::Cond::FirstUseEver);
        if (UI::CollapsingHeader("About / Usage")) {
            UI::Indent();
            UI::TextWrapped("This will embed new items in the map if they are not in the inventory.\nUsage: download an item set via Item Exchange, then use this form. Note that the maximum request size (including the map) is ~12 MB.\nSaving the map will remove all embedded items that are not placed in the map. However, they will remain in the inventory until you fully exit the editor. In this way, you can add multiple new items without restarting the game.\nEmbedded items will by added to existing folders if they exist, otherwise will be the final entry in the item inventory (far right).");
            UI::Unindent();
        }
        if (UI::Button("Reset##refresh-items-step")) {
            ResetState();
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
    string[] localItemPaths;

    void DrawStep1() {
        UI::BeginDisabled(step != 1);
        UI::Text("Step 1. Scan for items");
        UI::Text("Last refresh: " + Time::Format(Time::Now - lastRefresh, false, true, true));
        UI::Text("Nb Items Counted: " + localItemPaths.Length);
        UI::BeginDisabled(false);
        if (localItemPaths.Length > 0) {
            CopiableLabeledValue("First item", localItemPaths[0]);
        }
        if (localItemPaths.Length > 1) {
            CopiableLabeledValue("2nd item", localItemPaths[1]);
        }
        UI::EndDisabled();

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
        localItemPaths.RemoveRange(0, localItemPaths.Length);
        CacheItemsFolder(itemsFolderPrefix.SubStr(0, itemsFolderPrefix.Length - 1));
    }

    void CacheItemsFolder(const string &in folderPath) {
        auto ctn = IO::IndexFolder(folderPath, true);
        for (uint i = 0; i < ctn.Length; i++) {
            if (IsItemFileName(ctn[i])) {
                localItemPaths.InsertLast(ctn[i].Replace('/', '\\').SubStr(itemsFolderPrefix.Length));
                // trace('cached; ' + ctn[i]);
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
            localItemPaths.InsertLast(string(leaf.FullFileName).SubStr(itemsFolderPrefix.Length));
            // trace('Caching local item: ' + leaf.FullFileName);
        }
    }

    bool IsItemFileName(const string &in fileName) {
        auto suffix = fileName.SubStr(fileName.Length - 9).ToLower();
        return suffix == ".item.gbx"; // || suffix == "block.gbx";
    }

    // string[] cachedInvItemPaths;

    void DrawStep2() {
        auto cache = Editor::GetInventoryCache();
        UI::BeginDisabled(step != 2);
        UI::Text("Step 2. Scan Inventory for Differences");
        UI::Text("Nb Items Counted: " + cache.NbItems);
        if (cache.ItemPaths.Length > 0) {
            CopiableLabeledValue("First item", cache.ItemPaths[0]);
        }
        UI::Text("Items missing from Inventory: " + missingItems.Length);
        if (missingItems.Length > 0) {
            UI::BeginDisabled(false);
            CopiableLabeledValue("First missing item", missingItems[0]);
            if (missingItems.Length > 1)
                CopiableLabeledValue("2nd. missing item", missingItems[1]);
            UI::EndDisabled();
        }

        if (UI::Button("Scan Inventory")) {
            startnew(CoroutineFunc(RunStep2));
            step++;
        }

        UI::EndDisabled();
    }

    void RunStep2() {
        step3ReqError = "";
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
        CacheItemDiff();
    }

    dictionary seenItems;
    string[] missingItems;
    void CacheItemDiff() {
        seenItems.DeleteAll();
        missingItems.RemoveRange(0, missingItems.Length);
        selectedMissing.RemoveRange(0, selectedMissing.Length);
        auto cache = Editor::GetInventoryCache();
        for (uint i = 0; i < cache.ItemPaths.Length; i++) {
            if (seenItems.Exists(cache.ItemPaths[i])) {
                warn("duplicate item in inventory list: " + cache.ItemPaths[i]);
            }
            seenItems[cache.ItemPaths[i]] = true;
        }
        for (uint i = 0; i < localItemPaths.Length; i++) {
            if (!seenItems.Exists(localItemPaths[i])) {
                missingItems.InsertLast(localItemPaths[i]);
                selectedMissing.InsertLast(true);
            }
        }
    }

    bool[] selectedMissing;
    Net::HttpRequest@ step3Req;
    void DrawStep3() {
        UI::BeginDisabled(step != 3);
        UI::Text("Step 3. Request embed items to map");

        if (missingItems.Length == 0) {
            UI::Text("\\$f80No missing items detected.");
        }

        UI::TextWrapped("New folders/items will appear as the last elements of their respective folders.");
        UI::TextWrapped("Note: will also automatically save, request, and reload the map. (Creates a backup every time.)");
        UI::TextWrapped("Note: Too many items may make the request fail; max: ~12mb incl map.");

        UI::TextWrapped("\\$f80Warning:\\$z If you get msg like 'Error while retrieving map! Missing items:', click 'Load Anyway' and then 'No'. (If this doesn't work, you can experiment, and say something in the support thread.)");

        if (step == 3 && missingItems.Length > 0) {
            UI::SetNextItemOpen(true, UI::Cond::Appearing);
            if (UI::CollapsingHeader("Select Items to Embed")) {
                UI::Indent();

                bool setAll = false, setTo = false;

                if (selectedMissing.Length != missingItems.Length) {
                    selectedMissing.Resize(missingItems.Length);
                    setAll = true; setTo = true;
                }

                if (UI::Button("Select All##items-to-embed")) {
                    setAll = true;
                    setTo = true;
                }
                UI::SameLine();
                if (UI::Button("Select None##items-to-embed")) {
                    setAll = true;
                    setTo = false;
                }

                for (uint i = 0; i < selectedMissing.Length; i++) {
                    selectedMissing[i] = UI::Checkbox(missingItems[i], selectedMissing[i]);
                    if (setAll) selectedMissing[i] = setTo;
                }

                UI::Unindent();
            }

            UI::Text("Status: " + (step3ReqError.Length == 0 ? step3Req is null ? "Not started" : "In Progress" : "\\$f80Last Req Error:\\$z " + step3ReqError));

            UI::BeginDisabled(step3Req !is null);
            if (UI::Button("Get Updated Map")) {
                startnew(CoroutineFunc(RunStep3));
            }
            UI::EndDisabled();
        }

        UI::EndDisabled();
    }

    // reset at step 2
    string step3ReqError = "";

    void RunStep3() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        Editor::SaveMapSameName(editor);
        yield();
        string mapFileName = editor.Challenge.MapInfo.FileName;
        if (mapFileName.Length == 0) return;
        string mapFileFullName = IO::FromUserGameFolder("Maps/" + mapFileName);
        CopyFile(mapFileFullName, mapFileFullName.SubStr(0, mapFileFullName.Length - 8) + ".Map.Gbx_backup_" + Time::Stamp);
        MemoryBuffer@ data = MemoryBuffer();
        data.Write(uint32(0));
        Json::Value@ items = Json::Array();
        uint countItems = 0;
        for (uint i = 0; i < missingItems.Length; i++) {
            if (selectedMissing[i]) {
                items.Add(missingItems[i]);
                trace('added embed request item: ' + missingItems[i]);
                countItems++;
            }
        }
        _WriteString(data, Json::Write(items));
        _WriteUint(data, items.Length);
        for (uint i = 0; i < items.Length; i++) {
            _WriteFileBytes(data, itemsFolderPrefix + string(items[i]));
        }
        yield();
        _WriteFileBytes(data, IO::FromUserGameFolder("Maps/" + mapFileName));
        data.Seek(0);
        _WriteUint(data, data.GetSize());
        data.Seek(0);
        string pl = data.ReadToBase64(data.GetSize());
        print('pl size: ' + data.GetSize() + ' / b64: ' + pl.Length);
        @step3Req = Net::HttpRequest();
        step3Req.Method = Net::HttpMethod::Post;
        step3Req.Url = "https://map-monitor.xk.io/itemrefresh/create_map";
#if DEV
        // step3Req.Url = "http://localhost:8000/itemrefresh/create_map";
#endif
        step3Req.Body = pl;
        step3Req.Start();
        // @step3Req = Net::HttpPost(, pl);
        // sleep(3000);
        try {
            while (!step3Req.Finished()) {
                // long sleeps to avoid crash condition
                sleep(500);
            }
        } catch {
            step3ReqError = getExceptionInfo();
            NotifyWarning("Exception making request: " + step3ReqError);
            ResetState();
            return;
        }
        step3ReqError = "";
        trace('req done');
        if (step3Req.ResponseCode() != 200) {
            NotifyWarning('Error getting map: ' + step3Req.ResponseCode() + "; " + step3Req.Error());
            ResetState();
            return;
        }
        auto app = cast<CGameManiaPlanet>(GetApp());
        auto currCam = Editor::GetCurrentCamState(editor);
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
        AwaitEditor();
        Editor::SetCamAnimationGoTo(currCam);
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
        UI::Text("Step 4. Save, Load refresh map, Re-load this map (should be automatic)");
        if (UI::Button("Load Refresh Map then reload this map")) {
            startnew(CoroutineFunc(RunStep4));
        }
        UI::EndDisabled();
    }

    void RunStep4() {
        Editor::NoSaveAndReloadMap();
        ResetState();
    }

    void ResetState() {
        step = 1;
        @step3Req = null;
        missingItems.RemoveRange(0, missingItems.Length);
        // cachedInvItemPaths.RemoveRange(0, cachedInvItemPaths.Length);
        localItemPaths.RemoveRange(0, localItemPaths.Length);
        Editor::GetInventoryCache().RefreshCacheSoon();
    }
}
