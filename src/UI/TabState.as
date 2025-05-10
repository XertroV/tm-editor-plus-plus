namespace TabState {
    const string K_GROUP_STATES = "groupStates";
    const string K_TAB_STATES = "tabStates";
    const string K_LAST_SAVE = "lastSave";
    const string K_VIEW_STATE = "viewState";

    TabGroup@[] tabGroups;
    Tab@[] allTabs;

    void OnNewTabGroup(TabGroup@ group) {
        _Log::Debug("TabState", "NewTabGroup: " + group.tabGroupId);
        tabGroups.InsertLast(group);
    }
    void OnNewTab(Tab@ tab) {
        _Log::Debug("TabState", "NewTab: " + tab.fullName);
        allTabs.InsertLast(tab);
    }
    void RemoveTab(Tab@ tab) {
        _Log::Debug("TabState", "RemoveTab: " + tab.fullName);
        auto ix = allTabs.FindByRef(tab);
        if (ix != -1) {
            allTabs.RemoveAt(ix);
        }
    }

    uint lastSaveTime = 0;
    uint lastSaveSoonReq = 0;
    uint loadedJsonSavedAt = 0;
    bool saveSoonWaiting = false;

    void OnPluginStart_LoadTabState() {
        startnew(_RunLoadNow);
    }

    bool _debug_PrintTraceSaveSoon = false;

    void SaveSoon() {
        if (!_HasLoadBeenCalled) return;
        lastSaveSoonReq = Time::Now;
        if (_debug_PrintTraceSaveSoon) {
            _Log::Trace("TabState", "SaveSoon called");
            PrintActiveContextStack();
        }
        if (saveSoonWaiting) return;
        saveSoonWaiting = true;
        startnew(_SaveSoonCoro);
        _Log::Trace("TabState", "SaveSoon started");
    }

    void _SaveSoonCoro() {
        // wait 5 seconds after last change; but not more than 15 seconds
        while (Time::Now - lastSaveSoonReq < 5000 && Time::Now - lastSaveTime < 15000) {
            yield(5);
        }
        _RunSaveNow();
        saveSoonWaiting = false;
    }

    const string TabStateJsonFilePath = IO::FromStorageFolder("_TabState.json");
    string _lastJsonDebug = "";

    void _RunSaveNow() {
        _Log::Trace("TabState", "Saving tab state");
        lastSaveTime = Time::Now;
        Json::Value@ root = Json::Object();
        string[] parts = {"{"};
        _WriteJsonKey(parts, K_GROUP_STATES);
        _GroupStatesToJson(parts);
        parts.InsertLast(",");
        // root[K_GROUP_STATES] =
        // root[K_TAB_STATES] =
        _WriteJsonKey(parts, K_TAB_STATES);
        _TabStatesToJson(parts);
        parts.InsertLast(",");
        // root["viewState"] = _GetViewState();
        // root[K_LAST_SAVE] = Time::Stamp;
        _WriteJsonKey(parts, K_LAST_SAVE);
        parts.InsertLast(tostring(Time::Stamp));
        // parts.InsertLast(",");

        parts.InsertLast("}");
        // Json::ToFile(TabStateJsonFilePath, root, false);
        _lastJsonDebug = string::Join(parts, "\n");
        WriteFile(TabStateJsonFilePath, _lastJsonDebug.Replace("\n", ""));
#if DEV
        // _lastJsonDebug = Json::Write(root, true);
#endif
    }

    bool _HasLoadBeenCalled = false;
    void _RunLoadNow() {
        if (!IO::FileExists(TabStateJsonFilePath)) return;
        _HasLoadBeenCalled = true;
        auto j = Json::FromFile(TabStateJsonFilePath);
        if (j.GetType() != Json::Type::Object) {
            _Log::Trace("TabState", "LoadNow: expected object; got " + tostring(j.GetType()));
            return;
        }

        _LoadGroupStates(j[K_GROUP_STATES]);
        _LoadTabStates(j[K_TAB_STATES]);
        // _SetViewState(j["viewState"]);
        loadedJsonSavedAt = j[K_LAST_SAVE];
    }

    void _GroupStatesToJson(string[]& parts) {
        parts.InsertLast("{");
        bool prefixComma = false;
        // Json::Value@ j = Json::Object();
        for (uint i = 0; i < tabGroups.Length; i++) {
            // tabGroups[i].Json_SetStateUnderKey(j);
            // if (i > 0) parts.InsertLast(",");
            prefixComma = tabGroups[i].WritingJson_WriteObjKeyEl(parts, prefixComma) || prefixComma;
        }
        parts.InsertLast("}");
        // return j;
    }

    void _LoadGroupStates(Json::Value@ j) {
        if (j.GetType() != Json::Type::Object) return;
        for (uint i = 0; i < tabGroups.Length; i++) {
            tabGroups[i].Json_LoadState(j);
        }
    }

    void _TabStatesToJson(string[]& parts) {
        // Json::Value@ j = Json::Object();
        parts.InsertLast("{");
        for (uint i = 0; i < allTabs.Length; i++) {
            if (i > 0) parts.InsertLast(",");
            allTabs[i].WritingJson_WriteObjKeyEl(parts);
        }
        parts.InsertLast("}");
        // return j;
    }

    void _LoadTabStates(Json::Value@ j) {
        if (j.GetType() != Json::Type::Object) return;
        for (uint i = 0; i < allTabs.Length; i++) {
            allTabs[i].Json_LoadState(j);
        }
    }

    void _WriteJsonKey(string[]& parts, const string &in key) {
        parts.InsertLast(DOUBLE_QUOTE + key + DOUBLE_QUOTE + ":");
    }

    // MARK: NavState

    void NavHistory(int dir, TabGroup@ tg) {
        if (dir == 0) return;
        auto histStack = GetNavHistoryStack(tg.tabGroupId);
        histStack.Move(dir);
    }

    dictionary navHistStacks;

    NavHistStack@ GetNavHistoryStack(const string &in tabGroupId) {
        if (tabGroupId == "") return null;
        if (navHistStacks.Exists(tabGroupId)) {
            return cast<NavHistStack>(navHistStacks[tabGroupId]);
        } else {
            NavHistStack@ stack = NavHistStack();
            @navHistStacks[tabGroupId] = stack;
            return stack;
        }
    }
}


class NavHistStack {
    array<Tab@> stack;
    int pos = -1;

    void Move(int dir) {
        if (dir == 0) return;
        int slm1 = stack.Length - 1;
        while (dir > 0 && pos < slm1) {
            pos++;
            dir--;
        }
        while (dir < 0 && pos > 0) {
            pos--;
            dir++;
        }
        auto @cur = GetCurrent();
        if (cur !is null) cur.SetSelectedTab_Debounce();
    }

    void Push(Tab@ tab) {
        if (pos < int(stack.Length) - 1) {
            stack.RemoveRange(pos + 1, stack.Length - pos - 1);
        }
        if (stack.Length == 0 || stack[stack.Length - 1] !is tab) {
            stack.InsertLast(tab);
        }
        pos = stack.Length - 1;
    }

    Tab@ GetCurrent() {
        if (pos < 0 || pos >= stack.Length) return null;
        return stack[pos];
    }
}


void WriteFile(const string &in path, const string &in content) {
    auto dir = Path::GetDirectoryName(path);
    if (!IO::FolderExists(dir)) {
        auto storage = IO::FromStorageFolder("");
        if (!dir.StartsWith(storage)) {
            _Log::Error("WriteFile", "path is not in storage folder: " + path);
            return;
        }
        IO::CreateFolder(dir, true);
    }
    IO::File outFile(path, IO::FileMode::Write);
    outFile.Write(content);
    outFile.Close();
}
