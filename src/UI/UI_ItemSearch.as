class ItemSearcher {
    string idNonce;
    ItemSearcher() {
        idNonce = tostring(Math::Rand(0, 2000000000));
    }

    string[] filtered;
    string m_filterPrompt = "*Cube";
    string f_lastFilterTerm = m_filterPrompt;

    CGameCtnArticleNodeArticle@ DrawPrompt() {
        auto inv = Editor::GetInventoryCache();
        if (inv.NbItems == 0) {
            UI::Text("Inventory cache empty -- enter main editor to refresh.");
            return null;
        }

        bool pressedEnter;
        m_filterPrompt = UI::InputText("Name Search", m_filterPrompt, pressedEnter, UI::InputTextFlags::EnterReturnsTrue | UI::InputTextFlags::CallbackAlways, UI::InputTextCallback(NameFilterCallback));
        if (pressedEnter && filtered.Length > 0) {
            return FindItemNamed(filtered[0]);
        }

        return DrawFilterResults();
    }

    bool firstRunDone = false;

    CGameCtnArticleNodeArticle@ DrawFilterResults() {
        if (!firstRunDone) {
            firstRunDone = true;
            UpdateSearch();
        }
        if (filtered.Length == 0) {
            UI::Text("No items found matching query.");
            return null;
        }

        UI::Text("Filter Results: " + filtered.Length);

        string ret;

        if (UI::BeginChild("item-filter"+idNonce, vec2(), true)) {
            UI::ListClipper clip(filtered.Length);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    if (UI::Button("Select##" + filtered[i])) {
                        ret = filtered[i];
                    }
                    UI::AlignTextToFramePadding();
                    UI::SameLine();
                    UI::Text(filtered[i]);
                }
            }
        }
        UI::EndChild();

        return FindItemNamed(ret);
    }

    CGameCtnArticleNodeArticle@ FindItemNamed(const string &in itemPath) {
        if (itemPath.Length == 0) return null;
        auto inv = Editor::GetInventoryCache();
        for (uint i = 0; i < inv.ItemPaths.Length; i++) {
            if (itemPath == inv.ItemPaths[i]) {
                auto ret = inv.ItemInvNodes[i];
                auto collector = ret.GetCollectorNod();
                trace("Collector of type: " + UnkType(collector));
                if (!ret.Article.IsLoaded) {
                    ret.Article.Preload();
                }
                trace("Collector of type: " + UnkType(ret.GetCollectorNod()));
                return ret;
            }
        }
        return null;
    }





    void NameFilterCallback(UI::InputTextCallbackData@ data) {
        if (data.EventFlag != UI::InputTextFlags::CallbackAlways) {
            // trace('data.EventFlag: ' + tostring(data.EventFlag));
        }

        if (int(data.EventKey) > 0)
            trace('key: ' + tostring(data.EventKey));
        // bool isPgUpDown = data.EventKey == UI::Key::PageUp || data.EventKey == UI::Key::PageDown;

        // if (isPgUpDown || data.EventFlag == UI::InputTextFlags::CallbackHistory) {
        //     if (data.EventKey == UI::Key::UpArrow && f_suggestPos > -1) {
        //         f_suggestPos--;
        //     } else if (data.EventKey == UI::Key::DownArrow && f_blockNames.Length + f_itemNames.Length > 0) {
        //         f_suggestPos = Math::Min(f_suggestPos + 1, f_blockNames.Length + f_itemNames.Length - 1);
        //     } else {
        //         warn('unknown cb history key: ' + tostring(data.EventKey));
        //     }
        //     return;
        // } else if (data.EventFlag == UI::InputTextFlags::CallbackCompletion) {
        //     AddSuggestedNameToFilterList();
        // }

        if (f_lastFilterTerm != data.Text) {
            trace('changed');
            f_lastFilterTerm = data.Text;
            startnew(CoroutineFunc(UpdateSearch));
        }
    }


    string[]@ searchParts = {};

    void UpdateSearch() {
        auto inv = Editor::GetInventoryCache();
        filtered.RemoveRange(0, filtered.Length);
        @searchParts = f_lastFilterTerm.ToLower().Split("*");
        for (uint i = 0; i < inv.ItemPaths.Length; i++) {
            if (FilterMatchesName(inv.ItemPaths[i].ToLower(), inv.ItemPaths[i])) {
                filtered.InsertLast(inv.ItemPaths[i]);
            }
        }
    }

    bool FilterMatchesName(const string &in nameLower, const string &in name) {
        if (searchParts.Length > 0) {
            string rem = nameLower;
            int _ix = 0;
            for (uint i = 0; i < searchParts.Length; i++) {
                if (searchParts[i].Length == 0) continue;
                if (i == 0 && searchParts[i].Length > 0 && !rem.StartsWith(searchParts[i])) {
                    return false;
                } else {
                    _ix = rem.IndexOf(searchParts[i]);
                    if (_ix < 0) return false;
                    rem = rem.SubStr(_ix + searchParts[i].Length);
                }
            }
        }
        return true;
        // don't return result already in the filtered obj names list
        // return filtered.Find(name) < 0;
    }
}
