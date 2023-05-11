
shared enum SourceSelection {
    Selected_Region, Specific_Coords, Min_Max_Position, Everywhere
}


shared SourceSelection DrawComboSourceSelection(const string &in label, SourceSelection val) {
    return SourceSelection(
        DrawArbitraryEnum(label, int(val), 4, function(int v) {
            return tostring(SourceSelection(v));
        })
    );
}


// todo, make shared
class GenericApplyTab : Tab {
    GenericApplyTab(TabGroup@ p, const string &in name, const string &in icon) {
        super(p, name, icon);
        startnew(CoroutineFunc(WatchFilterForUpdate));
    }


    void ApplyTo(CGameCtnAnchoredObject@ item) {
        throw('override me');
    }
    void ApplyTo(CGameCtnBlock@ block) {
        throw('override me');
    }

    SourceSelection currScope = SourceSelection::Everywhere;

    nat3 m_coordsMin;
    nat3 m_coordsMax;
    vec3 m_posMin;
    vec3 m_posMax;
    string[] filteredObjectNames;

    string m_objIdNameFilter = "*Tech";

    int nfInputFlags = UI::InputTextFlags::CallbackCompletion | UI::InputTextFlags::CallbackHistory | UI::InputTextFlags::EnterReturnsTrue
        | UI::InputTextFlags::CallbackAlways;

    bool showCachedHelpers = false;
    bool showRegionHelpers = true;

    void DrawInner() override {
        bool nameFilterEnter = false;
        // UI::SetNextItemWidth(UI::GetContentRegionAvail().x * .5);
        m_objIdNameFilter = UI::InputText("Add Names", m_objIdNameFilter, nameFilterEnter, nfInputFlags, UI::InputTextCallback(NameFilterCallback));
        bool nameFilterInputActive = UI::IsItemActive();
        if (nameFilterEnter) AddSuggestedNameToFilterList();
        // if (nameFilter)
        if (nameFilterInputActive) DrawNameFilterResults(UI::GetCursorPos() + UI::GetWindowPos());

        // UI::SameLine();
        if (UI::Button("Refresh Cache##" + idNonce)) {
            Editor::GetMapCache().RefreshCacheSoon();
        }
        // UI::TextDisabled("Use `Caches > Refresh Map Block/Item Cache` to refresh.");

        UI::AlignTextToFramePadding();
        if (filteredObjectNames.Length > 0) {
            UI::Text("Filtered block/item names:");
            UI::SameLine();
            DrawFilteredNamesResetBtn();
            UI::SetNextItemOpen(true, UI::Cond::Appearing);
            UI::SetNextItemWidth(400.);
            if (UI::CollapsingHeader("Results ("+filteredObjectNames.Length+")")) {
                UI::Indent();
                for (uint i = 0; i < filteredObjectNames.Length; i++) {
                    if (UX::SmallButton(Icons::Times + "##" + filteredObjectNames[i])) {
                        filteredObjectNames.RemoveAt(i);
                        i--;
                        continue;
                    }
                    UI::SameLine();
                    UI::Text(filteredObjectNames[i]);
                }
                UI::Unindent();
                UI::SetCursorPos(UI::GetCursorPos() + UI::GetStyleVarVec2(UI::StyleVar::FramePadding) * vec2(0, 1));
            }
        } else {
            UI::Text("Not filtering based on block/item name. (Name: any)");
        }

        UI::Separator();

        currScope = DrawComboSourceSelection("Location Filter", currScope);

        if (currScope == SourceSelection::Specific_Coords) {
            UI::Columns(2);
            m_coordsMin = UX::InputNat3XYZ("Coords: Min", MathX::Min(m_coordsMin, m_coordsMax));
            UI::NextColumn();
            m_coordsMax = UX::InputNat3XYZ("Coords: Max", MathX::Max(m_coordsMax, m_coordsMin));
            m_coordsMin = MathX::Min(m_coordsMin, m_coordsMax);
            UI::Columns(1);
            showRegionHelpers = UI::Checkbox("Show Region Helpers", showRegionHelpers);
            if (showRegionHelpers) DrawShowRegionHelpers(CoordToPos(m_coordsMin), CoordToPos(m_coordsMax + nat3(1)));
        } else if (currScope == SourceSelection::Min_Max_Position) {
            m_posMin = UI::InputFloat3("Pos: Min", MathX::Min(m_posMin, m_posMax));
            m_posMax = UI::InputFloat3("Pos: Max", MathX::Max(m_posMax, m_posMin));
            m_posMin = MathX::Min(m_posMin, m_posMax);
            showRegionHelpers = UI::Checkbox("Show Region Helpers", showRegionHelpers);
            if (showRegionHelpers) DrawShowRegionHelpers(m_posMin, m_posMax);
        } else if (currScope == SourceSelection::Everywhere) {
            UI::Text("Location: any");
        } else if (currScope == SourceSelection::Selected_Region) {
            UI::Text("Location: Selected regions (as in copy mode)");
        }

        UI::Separator();

        if (UI::Button("Refresh Preview##" + idNonce)) {
            startnew(CoroutineFuncUserdataInt64(UpdateApplicationTargets), 0);
        }
        UI::Text("Applying to:");
        UI::Indent();
        UI::Text("# Blocks: " + cachedTargetsB.Length);
        UI::Text("# Items: " + cachedTargetsI.Length);
        showCachedHelpers = UI::Checkbox("Show helpers for application targets", showCachedHelpers);
        UI::Unindent();

        if (showCachedHelpers) DrawShowCachedHelpers();

        string btnLabel = "Update All##";
        switch (currScope) {
            case SourceSelection::Specific_Coords:
                btnLabel = "Apply to Coords##";
                break;
            case SourceSelection::Min_Max_Position:
                btnLabel = "Apply to Region##";
                break;
            case SourceSelection::Selected_Region:
                btnLabel = "Apply to Selected##";
        }
        btnLabel += idNonce;

        if (UI::Button(btnLabel)) {
            startnew(CoroutineFuncUserdataInt64(UpdateApplicationTargets), 1);
        }
    }

    void DrawShowRegionHelpers(vec3 min, vec3 max) {
        nvgDrawBlockBox(mat4::Translate(min), max - min);
    }

    void DrawShowCachedHelpers() {
        for (uint i = 0; i < cachedTargetsB.Length; i++) {
            auto b = cachedTargetsB[i];
            nvgDrawBlockBox(b.mat, b.size);
        }
        for (uint i = 0; i < cachedTargetsI.Length; i++) {
            auto item = cachedTargetsI[i];
            nvgDrawCoordHelpers(item.mat, 5.0);
        }
    }

    Editor::BlockInMap@[] cachedTargetsB;
    Editor::ItemInMap@[] cachedTargetsI;

    // 1 to run application
    void UpdateApplicationTargets(int64 runApplication) {
        trace('Running: UpdateApplicationTargets');
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (currScope == SourceSelection::Selected_Region) {
            Editor::UpdateNbSelectedItemsAndBlocks(editor);
        }
        auto pmt = editor.PluginMapType;
        auto @blocks = ApplyingToCalcBlocks(pmt);
        auto @items = ApplyingToCalcItems(pmt);
        cachedTargetsB.RemoveRange(0, cachedTargetsB.Length);
        cachedTargetsI.RemoveRange(0, cachedTargetsI.Length);
        for (uint i = 0; i < blocks.Length; i++) {
            cachedTargetsB.InsertLast(Editor::BlockInMap(i, blocks[i]));
            if (runApplication == 1) ApplyTo(blocks[i]);
        }
        for (uint i = 0; i < items.Length; i++) {
            cachedTargetsI.InsertLast(Editor::ItemInMap(i, items[i]));
            if (runApplication == 1) ApplyTo(items[i]);
        }
        if (runApplication == 1)
            OnApplyDone();
    }

    // overload this to stop auto-refresh
    void OnApplyDone() {
        Editor::RefreshBlocksAndItems(cast<CGameCtnEditorFree>(GetApp().Editor));
    }

    CGameCtnBlock@[] ApplyingToCalcBlocks(CGameEditorPluginMap@ pmt) {
        CGameCtnBlock@[] objs;
        for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
            if (MatchesConditions(pmt.ClassicBlocks[i])) {
                objs.InsertLast(pmt.ClassicBlocks[i]);
            }
        }
        for (uint i = 0; i < pmt.GhostBlocks.Length; i++) {
            if (MatchesConditions(pmt.GhostBlocks[i])) {
                objs.InsertLast(pmt.GhostBlocks[i]);
            }
        }
        return objs;
    }
    CGameCtnAnchoredObject@[] ApplyingToCalcItems(CGameEditorPluginMap@ pmt) {
        CGameCtnAnchoredObject@[] objs;
        for (uint i = 0; i < pmt.Map.AnchoredObjects.Length; i++) {
            if (MatchesConditions(pmt.Map.AnchoredObjects[i])) {
                objs.InsertLast(pmt.Map.AnchoredObjects[i]);
            }
        }
        return objs;
    }


    bool MatchesConditions(CGameCtnBlock@ block) {
        if (filteredObjectNames.Length > 0 && filteredObjectNames.Find(block.BlockInfo.IdName) < 0)
            return false;
        return PosMatchesCondition(Editor::GetBlockLocation(block));
    }
    bool MatchesConditions(CGameCtnAnchoredObject@ item) {
        if (filteredObjectNames.Length > 0 && filteredObjectNames.Find(item.ItemModel.IdName) < 0)
            return false;
        return PosMatchesCondition(item.AbsolutePositionInMap);
    }

    bool PosMatchesCondition(vec3 pos) {
        switch (currScope) {
            case SourceSelection::Everywhere: return true;
            case SourceSelection::Selected_Region:
                return Editor::selectedCoords.Exists(PosToCoord(pos).ToString());
            case SourceSelection::Specific_Coords:
                return MathX::Within(PosToCoord(pos), m_coordsMin, m_coordsMax);
            case SourceSelection::Min_Max_Position:
                return MathX::Within(pos, m_posMin, m_posMax);
        }
        return false;
    }


    void DrawFilteredNamesResetBtn() {
        if (UI::Button("Reset##bi-filtered")) {
            filteredObjectNames.RemoveRange(0, filteredObjectNames.Length);
        }
    }

    void AddSuggestedNameToFilterList() {
        auto i = f_suggestPos;
        if (i < 0) {
            for (uint x = 0; x < f_blockNames.Length; x++) {
                InsertUniqueSorted(filteredObjectNames, f_blockNames[x]);
            }
            for (uint x = 0; x < f_itemNames.Length; x++) {
                InsertUniqueSorted(filteredObjectNames, f_itemNames[x]);
            }
            f_blockNames.RemoveRange(0, f_blockNames.Length);
            f_itemNames.RemoveRange(0, f_itemNames.Length);
            return;
        }
        bool isItem = i >= f_blockNames.Length;
        if (isItem) {
            i -= f_blockNames.Length;
        }
        auto toAdd = isItem ? f_itemNames[i] : f_blockNames[i];
        (isItem ? f_itemNames : f_blockNames).RemoveAt(i);
        InsertUniqueSorted(filteredObjectNames, toAdd);
    }

    void InsertUniqueSorted(string[]@ arr, const string &in toAdd) {
        for (uint x = 0; x < arr.Length; x++) {
            if (toAdd < arr[x]) {
                arr.InsertAt(x, toAdd);
                return;
            }
            if (toAdd == arr[x]) return;
        }
        arr.InsertLast(toAdd);
    }

    string[] searchParts;
    string[] f_blockNames = {"A block"};
    string[] f_itemNames = {"An item"};
    string f_lastFilterTerm = m_objIdNameFilter;
    int f_suggestPos = 0;
    bool f_isStale = true;

    void NameFilterCallback(UI::InputTextCallbackData@ data) {
        if (data.EventFlag != UI::InputTextFlags::CallbackAlways) {
            trace('data.EventFlag: ' + tostring(data.EventFlag));
        }

        if (int(data.EventKey) > 0)
            trace('key: ' + tostring(data.EventKey));
        bool isPgUpDown = data.EventKey == UI::Key::PageUp || data.EventKey == UI::Key::PageDown;

        if (isPgUpDown || data.EventFlag == UI::InputTextFlags::CallbackHistory) {
            if (data.EventKey == UI::Key::UpArrow && f_suggestPos > -1) {
                f_suggestPos--;
            } else if (data.EventKey == UI::Key::DownArrow && f_blockNames.Length + f_itemNames.Length > 0) {
                f_suggestPos = Math::Min(f_suggestPos + 1, f_blockNames.Length + f_itemNames.Length - 1);
            } else {
                warn('unknown cb history key: ' + tostring(data.EventKey));
            }
            return;
        } else if (data.EventFlag == UI::InputTextFlags::CallbackCompletion) {
            AddSuggestedNameToFilterList();
        }

        if (f_lastFilterTerm != data.Text) {
            f_suggestPos = 0;
            f_isStale = true;
            f_lastFilterTerm = data.Text;
        }
    }

    void WatchFilterForUpdate() {
        auto mapCache = Editor::GetMapCache();
        while (true) {
            yield();
            if (f_isStale) {
                f_blockNames.RemoveRange(0, f_blockNames.Length);
                f_itemNames.RemoveRange(0, f_itemNames.Length);
                SetFilterParts();
                for (uint i = 0; i < mapCache.BlockTypes.Length; i++) {
                    if (FilterMatchesName(mapCache.BlockTypesLower[i], mapCache.BlockTypes[i])) {
                        f_blockNames.InsertLast(mapCache.BlockTypes[i]);
                    }
                }
                for (uint i = 0; i < mapCache.ItemTypes.Length; i++) {
                    if (FilterMatchesName(mapCache.ItemTypesLower[i], mapCache.ItemTypes[i])) {
                        f_itemNames.InsertLast(mapCache.ItemTypes[i]);
                    }
                }
                f_isStale = false;
            }
        }
    }

    void SetFilterParts() {
        searchParts = f_lastFilterTerm.ToLower().Split("*");
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
        // don't return result already in the filtered obj names list
        return filteredObjectNames.Find(name) < 0;
    }

    void DrawNameFilterResults(vec2 pos) {
        // UI::SetNextWindowSize(400, -1, UI::Cond::Always);
        UI::SetNextWindowPos(pos.x, pos.y, UI::Cond::Always);
        UI::PushStyleColor(UI::Col::PopupBg, vec4(0, 0, 0, .99));
        UI::PushStyleColor(UI::Col::Border, vec4(.9));
        UI::PushStyleVar(UI::StyleVar::FrameBorderSize, 1.0);
        UI::BeginTooltip();
        auto total = f_blockNames.Length + f_itemNames.Length;
        auto nbToShow = Math::Min(10, total);
        auto startIx = Math::Max(0, f_suggestPos - nbToShow / 2);
        auto endIx = Math::Min(total, startIx + nbToShow);
        if (endIx == total) startIx = Math::Max(0, total - nbToShow);
        UI::TextDisabled("Results: " + total + " / <Tab> to add many / Wildcard: *");
        if (f_suggestPos >= total) {
            f_suggestPos = total - 1;
        }
        UI::Selectable("Add All Results", f_suggestPos == -1);
        for (uint i = startIx; i < endIx; i++) {
            bool isItem = i >= f_blockNames.Length;
            int _i = isItem ? i - f_blockNames.Length : i;
            if (DrawNameFilterResult(i + 1, _i, isItem, f_suggestPos == i)) {
                f_suggestPos = i;
            }
        }
        UI::EndTooltip();

        UI::PopStyleVar();
        UI::PopStyleColor(2);
    }

    bool DrawNameFilterResult(int resultNumber, int ix, bool isItem, bool isFocused) {
        bool clicked = UI::Selectable(Text::Format("%d. ", resultNumber) + (isItem ? f_itemNames[ix] : f_blockNames[ix]), isFocused);
        return clicked;
    }
}
