class ItemEmbedTab : Tab {
    ItemEmbedTab(TabGroup@ p) {
        super(p, "Refresh Items" + NewIndicator, Icons::FolderOpenO + Icons::Refresh);
    }

    uint step = 1;

    void DrawInner() override {
        UI::SetNextItemOpen(true, UI::Cond::FirstUseEver);
        if (UI::CollapsingHeader("About / Usage")) {
            UI::Indent();
            UI::TextWrapped("This will automate loading new items using the item editor (ones that are not in the inventory).\nUsage: download an item set via Item Exchange, then use this form.");
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
        UI::Text("Step 3. Load items");

        if (missingItems.Length == 0) {
            UI::Text("\\$f80No missing items detected.");
        }

        UI::TextWrapped("New folders/items will appear as the first elements of their respective folders.");

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

            if (UI::Button("Load Items")) {
                startnew(CoroutineFunc(RunStep3));
            }
        }

        UI::EndDisabled();
    }

    // reset at step 2
    string step3ReqError = "";

    void RunStep3() {
        ShowReloadingWindow = true;
        Reloading_IsSaving = true;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        string[] items;
        for (uint i = 0; i < missingItems.Length; i++) {
            if (selectedMissing[i]) {
                items.InsertLast(missingItems[i]);
            }
        }

        if (items.Length == 0) {
            NotifyWarning("cant refresh 0 items");
            ResetState();
            return;
        }
        Reloading_Total = items.Length;

        auto inv = Editor::GetInventoryCache();
        auto initModel = cast<CGameItemModel>(inv.GetItemByPath("LightCube8m").GetCollectorNod());
        if (initModel is null) NotifyWarning("Attempting to load init model but it is null");
        Editor::OpenItemEditor(editor, initModel);

        yield();
        for (uint i = 0; i < items.Length; i++) {
            RunLoadItem(editor, items[i], i == 0);
            Reloading_Done += 1;
        }
        RunLoadItem(editor, items[0], false);

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        ieditor.Exit();
        Reloading_IsSaving = false;
        Reloading_Done = 0;
        yield();
        yield();
        yield();

        while (inv.isRefreshing) yield();

        for (uint i = 0; i < items.Length; i++) {
            auto node = inv.GetItemByPath(items[i]);
            Editor::SetSelectedInventoryNode(editor, node, true);
            Reloading_Done++;
            yield();
        }
        Reloading_Done = 0;
        for (uint i = 0; i < items.Length; i++) {
            auto node = inv.GetItemByPath(items[i]);
            Editor::SetSelectedInventoryNode(editor, node, true);
            Reloading_Done++;
            yield();
        }

        ShowReloadingWindow = false;
        ResetState();
    }

    void RunLoadItem(CGameCtnEditorFree@ editor, const string &in item, bool isFirst) {
        auto itemPath = itemsFolderPrefix + "/" + item;
        auto itemPathBackup = itemPath + ".back";
        CopyFile(itemPath, itemPathBackup);
        if (isFirst) ItemEditor::OpenItem(item);
        else IO::Delete(itemPath);
        ItemEditor::SaveItemAs(item);
        CopyFile(itemPathBackup, itemPath);
        IO::Delete(itemPathBackup);
    }

    void ResetState() {
        step = 1;
        @step3Req = null;
        missingItems.RemoveRange(0, missingItems.Length);
        // cachedInvItemPaths.RemoveRange(0, cachedInvItemPaths.Length);
        localItemPaths.RemoveRange(0, localItemPaths.Length);
        Editor::GetInventoryCache().RefreshCacheSoon();
    }

    bool ShowReloadingWindow = false;
    bool Reloading_IsSaving = false;
    uint Reloading_Total = 1;
    uint Reloading_Done = 0;

    bool DrawWindow() override {
        if (ShowReloadingWindow) {
            auto screen = vec2(Draw::GetWidth(), Draw::GetHeight());
            auto midPos = screen * vec2(0.5, 0.25);
            auto msg = Reloading_IsSaving ? "[ Adding to Inventory: " : "Loading Items: ";
            msg += tostring(Reloading_Done) + " / " + Reloading_Total
                + Text::Format(" ( %2.1f%% ) ]", float(Reloading_Done) * 100. / Reloading_Total);
            float size = 40.;
            auto dims = Draw::MeasureString(msg, g_BigFont, size);
            auto tl = midPos - dims/2.;
            float pad = 20.;
            auto boxTL = tl - pad;
            auto boxSize = dims + (pad * 2.);

            auto dl = UI::GetForegroundDrawList();
            dl.AddRectFilled(vec4(boxTL, boxSize), vec4(.0, .0, .0, .7), pad);
            DrawList_AddTextWithStroke(dl, tl, vec4(1), vec4(0), msg, g_BigFont, size);
        }
        return Tab::DrawWindow();
    }
}
