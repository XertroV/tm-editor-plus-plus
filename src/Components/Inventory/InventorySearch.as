class InventorySearchTab : Tab {
    InvSearcher@ searcher;
    bool setKbFocusOnSearchbar = false;

    InventorySearchTab(TabGroup@ p) {
        super(p, "Inv. Search" + NewIndicator, Icons::FolderOpenO + Icons::Search);
        canPopOut = true;
        @searcher = InvSearcher();
        searcher.SetUpdateCallbacks(CoroutineFunc(this.SearchUpdateStart), CoroutineFunc(this.SearchUpdateEnd));
        // Oem5 = backslash `\`
        AddHotkey(VirtualKey::Oem5, false, false, false, HotkeyFunction(this.OnShowSearchWindow));
        closeWindowOnEscape = true;
    }

    UI::InputBlocking OnShowSearchWindow() {
        if (windowOpen) return UI::InputBlocking::DoNothing;
        windowOpen = true;
        setKbFocusOnSearchbar = true;
        return UI::InputBlocking::Block;
    }

    int get_WindowFlags() override property {
        // return UI::WindowFlags::HorizontalScrollbar;
        return UI::WindowFlags::None;
    }

    bool DrawWindow() override {
        if (windowOpen) UI::SetNextWindowSize(500, 400, UI::Cond::Appearing);
        return Tab::DrawWindow();
    }

    vec2 availableSize;
    vec2 initCursorPos;
    float maxCursorPos;
    float maxCursorY;
    float minCursorY;
    float resWidth;
    vec2 promptCursorPos;

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = Editor::GetInventoryCache();
        UI::PushFont(g_BigFont);
        UI::Text("Search Inventory");
        UI::SameLine();
        UI::Text("\\$88e" + Icons::QuestionCircle);
        UI::PopFont();
        promptCursorPos = UI::GetCursorPos();
        AddMarkdownTooltip("### Search the inventory for items, blocks, and macroblocks.\n"
            "Use \\<space\\> or '*' to indicate wildcards.<br>"
            "Backslash to quicksearch.\n"
            "Escape to close the window.<br>"
            "Unless the search term is prefixed with '=', a wildcard is automatically inserted before the search term.<br>"
            // todo: filter on types (blocks, items, macroblocks, folders)
            );
        UI::SameLine();
        UI::SetCursorPos(UI::GetCursorPos() + vec2(0, 5));
        UI::Text("\\$aaaSearch terms: " + searcher.searchTermPartsStr);

        UI::SetCursorPos(promptCursorPos);
        UI::PushFont(g_BigFont);
        if (setKbFocusOnSearchbar) {
            UI::SetKeyboardFocusHere();
            setKbFocusOnSearchbar = false;
            searcher.m_filterPrompt = "";
        }
        searcher.DrawPrompt();
        UI::SameLine();
        if (UI::Button("Toggle Labels")) {
            ToggleLables();
        }
        UI::PopFont();

        if (UI::BeginChild("##searchresults", vec2(-1, -1), true)) {
            availableSize = UI::GetContentRegionAvail();
            initCursorPos = UI::GetCursorPos();
            resWidth = S_IconSize.x;
            maxCursorPos = initCursorPos.x + availableSize.x - resWidth * 2.0;
            minCursorY = initCursorPos.y - S_IconSize.y + UI::GetScrollY();
            maxCursorY = initCursorPos.y + availableSize.y + S_IconSize.y + UI::GetScrollY();
            vec2 currCursorPos;

            bool doSameLine = false;
            for (uint i = 0; i < results.Length; i++) {
                auto fe = results[i];
                if (doSameLine) {
                    UI::SameLine();
                }
                currCursorPos = UI::GetCursorPos();
                doSameLine = currCursorPos.x < maxCursorPos;
                if (currCursorPos.y > minCursorY && currCursorPos.y < maxCursorY) {
                    fe.DrawFavEntry(editor, inv);
                } else {
                    UI::Dummy(S_IconSize);
                }
            }
            if (hasMoreResults) {
                if (UI::Button("Load next " + pageSize + " results.")) {
                    offset += pageSize;
                    results.RemoveRange(0, results.Length);
                    startnew(CoroutineFunc(this.SearchUpdateEnd));
                }
            }
        }
        UI::EndChild();
    }

    void ToggleLables() {
        showingLabels = !showingLabels;
        resAmbAlpha = showingLabels ? 0.35 : 0.0;
        for (uint i = 0; i < results.Length; i++) {
            results[i].ambientAlpha = resAmbAlpha;
        }
    }

    bool showingLabels = true;
    FavObj@[] results;
    uint totalSearchRes;
    uint nbResults;
    uint offset;
    bool hasMoreResults = false;
    uint pageSize = 100;
    uint minResultsIfPossible = 10;
    float resAmbAlpha = 0.35;

    void SearchUpdateStart() {
        results.RemoveRange(0, results.Length);
        totalSearchRes = 0;
        nbResults = 0;
        offset = 0;
        hasMoreResults = false;
    }

    void SearchUpdateEnd() {
        yield();
        Notify('SearchUpdateEnd');
        auto inv = Editor::GetInventoryCache();
        totalSearchRes = searcher.filtered.Length;
        nbResults = Math::Min(totalSearchRes, pageSize);
        uint startFrom = Math::Min(offset, Math::Max(minResultsIfPossible, totalSearchRes) - minResultsIfPossible);
        uint endAt = Math::Min(startFrom + pageSize, totalSearchRes);
        hasMoreResults = endAt < totalSearchRes;
        for (uint i = startFrom; i < endAt; i++) {
            auto name = searcher.filtered[i];
            auto item = inv.GetItemByPath(name);
            auto block = inv.GetBlockByName(name);
            auto mb = inv.GetMacroblockByName(name);
            auto itemFolder = inv.GetItemDirectory(name);
            auto blockFolder = inv.GetBlockDirectory(name);
            auto mbFolder = inv.GetMacroblockDirectory(name);
            if (item !is null) {
                results.InsertLast(FavObj(name, InvObjectType::Item));
            } else if (block !is null) {
                results.InsertLast(FavObj(name, InvObjectType::Block));
            } else if (mb !is null) {
                results.InsertLast(FavObj(name, InvObjectType::Macroblock));
            } else if (itemFolder !is null) {
                results.InsertLast(FavObj(name, InvObjectType::ItemFolder));
            } else if (blockFolder !is null) {
                results.InsertLast(FavObj(name, InvObjectType::BlockFolder));
            } else if (mbFolder !is null) {
                results.InsertLast(FavObj(name, InvObjectType::MacroblockFolder));
            } else {
                NotifyWarning("Inventory item not found: " + name);
                continue;
            }
            results[results.Length - 1].WithAmbAlpha(resAmbAlpha).WithSelectedCb(CoroutineFunc(this.OnSelectedObject));
        }
    }

    void OnSelectedObject() {
        if (windowOpen) {
            windowOpen = false;
            setKbFocusOnSearchbar = false;
        }
    }
}

class InvSearcher : ItemSearcher {
    InvSearcher() {
        super();
        this.drawFilteredResults = false;
        this.searchFoldersToo = true;
        this.m_filterPrompt = "";
        this.inputFieldLabel= "##invsearchprompt";
    }

    string searchTermPartsStr;

    void SetSearchParts() override {
        string filterTerm = f_lastFilterTerm;
        bool exact = filterTerm.StartsWith("=");
        if (exact) {
            filterTerm = filterTerm.SubStr(1);
        }
        @searchParts = string::SplitAny(filterTerm.ToLower(), " *");

        if (!exact && filterTerm.Length > 0 && searchParts[0] != "") {
            searchParts.InsertAt(0, "");
        }
        searchTermPartsStr = Json::Write(searchParts.ToJson());
    }
}

namespace string {
    string[] SplitAny(const string &in str, const string &in delims) {
        array<string> parts;
        int start = 0;
        int end = 0;
        while (end < str.Length) {
            if (delims.Contains((str.SubStr(end, 1)))) {
                if (end > start) {
                    parts.InsertLast(str.SubStr(start, end - start));
                } else {
                    parts.InsertLast("");
                }
                start = end + 1;
            }
            end++;
        }
        if (end > start) {
            parts.InsertLast(str.SubStr(start, end - start));
        }
        if (parts.Length == 0) {
            parts.InsertLast(str);
        }
        return parts;
    }
}
