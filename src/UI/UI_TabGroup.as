const UI::MouseButton MOUSE_BUTTON_BACK = UI::MouseButton(3);
const UI::MouseButton MOUSE_BUTTON_FORWARD = UI::MouseButton(4);


class TabGroup : HasGroupMeta {
    // # From HasGroupMeta:
    // TabGroupMeta@ meta;

    // the parent tab
    Tab@ Parent = null;
    Tab@[] tabs;
    string tabGroupId;
    string groupName;
    string fullName;
    bool IsRoot = false;

    TabGroup(const string &in name, Tab@ parent) {
        groupName = name;
        @Parent = parent;
        // ! root tab init in its class
        if (parent is null) return;
        if (parent.Parent !is null) {
            tabGroupId = parent.Parent.tabGroupId + ".";
        }
        tabGroupId += Text::StripOpenplanetFormatCodes(name);
        fullName = parent.fullName;
        if (name.Length > 0 && name != parent.tabName) {
            fullName += " > " + name;
        }
        @meta = TabGroupMeta(this);
    }

    string RootTabGroupID() {
        if (Parent is null) return tabGroupId;
        return Parent.RootTabGroupID();
    }

    string mainWindowTitle;

    string MainWindowTitle() {
        if (mainWindowTitle.Length == 0) {
            mainWindowTitle = MenuTitle;
            if (groupName != "Root") {
                mainWindowTitle += " > " + groupName;
            }
        }
        return mainWindowTitle;
    }

    bool AnyActive() {
        for (uint i = 0; i < tabs.Length; i++) {
            auto t = cast<EffectTab>(tabs[i]);
            if (t is null) continue;
            if (t._IsActive) return true;
        }
        return false;
    }

    void SetChildSelected(Tab@ child, bool propagate = true) {
        if (child is null) return;
        auto ix = tabs.FindByRef(child);
        if (ix >= 0) selectedTabIx = ix;
        else warn("Could not find child: " + child.fullName);
        if (propagate && Parent !is null) Parent.SetSelectedTab();
    }

    // To be called based on which children are drawn as tabs
    void UpdateLastSelectedTab(int ix) {
        if (ix < 0 || ix >= int(tabs.Length)) return;
        if (selectedTabIx == ix) return;
        for (uint i = 0; i < tabs.Length; i++)
            tabs[i].SetSelectedInGroup(i == uint(ix));
    }

    bool HasTabNamed(const string &in name) {
        for (uint i = 0; i < tabs.Length; i++) {
            if (tabs[i].tabName == name) return true;
        }
        return false;
    }

    void FocusTab(const string &in name) {
        for (uint i = 0; i < tabs.Length; i++) {
            if (tabs[i].tabName == name) {
                tabs[i].SetSelectedTab();
                return;
            }
        }
        NotifyWarning("Could not find tab: " + name);
    }

    void AddTab(Tab@ t) {
        if (t.Parent !is null) {
            throw('tried to add a tab that already has a parent group.');
        }
        @t.Parent = this;
        tabs.InsertLast(t);
    }

    void RemoveTab(Tab@ t) {
        auto ix = tabs.FindByRef(t);
        if (ix >= 0) {
            tabs.RemoveAt(ix);
            @t.Parent = null;
            TabState::RemoveTab(t);
        }
    }

    int tabBarFlags = UI::TabBarFlags::None;

    void DrawTabs() {
        UI::BeginTabBar(groupName, tabBarFlags);

        for (uint i = 0; i < tabs.Length; i++) {
            if (tabs[i].DrawTab()) {
                UpdateLastSelectedTab(i);
            }
        }

        UI::EndTabBar();
    }

    void DrawTabsAsList(const string &in title = "") {
        UI::Separator();
        for (uint i = 0; i < tabs.Length; i++) {
            auto tab = tabs[i];
            UI::AlignTextToFramePadding();
            tab.DrawTab(false);
            UI::Separator();
        }
    }

    bool sideBarExpanded = true;
    vec2 framePadding;
    vec2 regionSize;
    int _selectedTabIx = 0;

    int get_selectedTabIx() {
        return Math::Min(tabs.Length - 1, GetSelectedTabFor(tabGroupId));
    }
    void set_selectedTabIx(int value) {
        UpdateLastSelectedTab(value);
        SetSelectedTabFor(tabGroupId, value);
    }

    void DrawTabsAsSidebar(const string &in title = "") {
        ClickFlags clicks = ClickFlags(0b110);

        framePadding = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
        regionSize = UI::GetContentRegionAvail();
        auto sbWidth = (sideBarExpanded ? 170. : 60.) * UI::GetScale() + framePadding.x * 2.;
        UI::PushStyleColor(UI::Col::Border, vec4(1));
        if (UI::BeginChild("sidebar-left|" + fullName, vec2(sbWidth, 0), UI::ChildFlags::NavFlattened | UI::ChildFlags::Border)) {
            if (title.Length > 0) {
                // UI::PushFont(g_Heading);
                UI::AlignTextToFramePadding();
                UI::Text(title);
                // UI::PopFont();
            }
            if (UI::Button(Icons::Bars + "##expand-" + fullName)) {
                sideBarExpanded = !sideBarExpanded;
            }
            DrawSidebarTabEntries(clicks);
        }
        UI::EndChild();
        UI::PopStyleColor();
        UI::SameLine();
        if (UI::BeginChild("inner|" + fullName, vec2(-1, -1), UI::ChildFlags::NavFlattened)) {
            auto ix = selectedTabIx;
            if (ix >= 0 && ix < int(tabs.Length)) {
                if (tabs[ix].DrawTab(false)) {
                    UpdateLastSelectedTab(ix);
                }
            } else {
                UI::Text("No tab selected");
            }
        }
        UI::EndChild();

        auto isFocused = UI::IsWindowFocused(UI::FocusedFlags::RootAndChildWindows);
        // isFocused = UI::IsWindowFocused(UI::FocusedFlags::RootWindow);
        bool backClicked = false, fwdClicked = false;
        if (isFocused) {
            auto pos = UI::GetWindowPos();
            auto size = UI::GetWindowSize();
            // nvgCircleScreenPos(pos);
            // nvgCircleScreenPos(pos + size);
            // nvgCircleScreenPos(pos + size * vec2(0, 1));
            // nvgCircleScreenPos(pos + size * vec2(1, 0));
            // size = size * g_scaleInv;
            // nvgCircleScreenPos(pos + size);
            // nvgCircleScreenPos(pos + size * vec2(0, 1));
            // nvgCircleScreenPos(pos + size * vec2(1, 0));
            // size = size * g_scale * g_scale;
            // nvgCircleScreenPos(pos + size);
            // nvgCircleScreenPos(pos + size * vec2(0, 1));
            // nvgCircleScreenPos(pos + size * vec2(1, 0));
            bool isWithin = MathX::Within(UI::GetMousePos(), vec4(pos, size));
            if (isWithin) {
                backClicked = UI::IsMouseClicked(MOUSE_BUTTON_BACK);
                fwdClicked = UI::IsMouseClicked(MOUSE_BUTTON_FORWARD);
            }
        }

        if (backClicked) {
            OnNavigationBack();
        } else if (fwdClicked) {
            OnNavigationForward();
        }
    }

    void DrawSidebarTabEntries(ClickFlags clicks) {
        auto _selectedIx = selectedTabIx;
        for (int i = 0; i < int(tabs.Length); i++) {
            DrawSidebarTabEntry(i, tabs[i], i == _selectedIx, clicks, false);
        }
    }

    void DrawSidebarTabEntry(uint i, Tab@ tab, bool isActive, ClickFlags clicks, bool isFav) {
        if (UI::Selectable(sideBarExpanded ? tab.DisplayIconAndName : tab.DisplayIconWithId, isActive)) {
            selectedTabIx = i;
        }
        bool hovered = UI::IsItemHovered(UI::HoveredFlags::DelayNone);
        if (hovered) {
            if (clicks.RMB) tab.OnSideBarLabel_RightClick(isFav);
            else if (clicks.MMB) tab.OnSideBarLabel_MiddleClick();
        }
    }

    void OnNavigationBack() {
        TabState::NavHistory(-1, this);
    }
    void OnNavigationForward() {
        TabState::NavHistory(1, this);
    }

    // draw show/hide toggle for tab in context menu
    void DrawHideShowTabMenuItem(Tab& tab) {
        if (meta is null) {
            _Log::Warn_NID("TabGroup", "No meta for tab group: " + tabGroupId);
            return;
        }
        bool isHidden = meta.IsHidden(tab.nameIdValue);
        if (UI::MenuItem(isHidden ? "Show Tab" : "Hide Tab")) {
            meta.ToggleHidden(tab.nameIdValue);
        }
    }

    int GetTabIx(Tab@ t) {
        if (t is null) return -1;
        auto ix = tabs.FindByRef(t);
        if (ix < 0) {
            _Log::Warn_NID("GetTabIx", "Tab not found: " + t.fullName);
        }
        return ix;
    }

    // setTo requires toggle = false
    void FavoriteTab(Tab@ t, bool toggle = true, bool setTo = false) {
        auto ix = GetTabIx(t);
        if (ix >= 0) {
            if ((!toggle && setTo) || (toggle && !meta.IsFavorite(t.nameIdValue))) {
                meta.AddFavorite(t.nameIdValue);
            } else {
                meta.RemFavorite(t.nameIdValue);
            }
        }
    }

    Tab@ FindTabNamedId(int idValue) {
        for (uint i = 0; i < tabs.Length; i++) {
            if (tabs[i].nameIdValue == idValue) return tabs[i];
        }
        return null;
    }

    void DrawWindows() {
        for (uint i = 0; i < tabs.Length; i++) {
            tabs[i].DrawWindow();
        }
    }

    void DrawWindowsAndRemoveTabsWhenClosed() {
        for (uint i = 0; i < tabs.Length; i++) {
            if (!tabs[i].DrawWindow()) {
                tabs.RemoveAt(i);
                i--;
            }
        }
    }

    void DrawTabsAsMenuItems() {
        for (uint i = 0; i < tabs.Length; i++) {
            tabs[i].DrawMenuItem();
        }
    }

    void AterLoadedState() {
        //
    }
}

mixin class HasGroupMeta {
    TabGroupMeta@ meta;

    // void Json_SetStateUnderKey(Json::Value@ j) {
    //     meta.WriteToJson(j);
    // }
    bool WritingJson_WriteObjKeyEl(string[]& parts, bool commaPrefix = false) {
        if (tabs.Length == 0) return false;
        auto prior = parts.Length;
        meta.WritingJson_WriteObjKeyEl(parts);
        if (commaPrefix) parts[prior] = "," + parts[prior];
        return true;
    }

    void Json_LoadState(Json::Value@ j) {
        meta.LoadFromJson(j);
        AterLoadedState();
    }
}

// MARK: RootTabGroup

class RootTabGroupCls : TabGroup {
    string[] categories;
    int[] categoryEndIxs;
    bool[] categoryIsOpen;

    RootTabGroupCls(const string &in name = "Root") {
        super(name, null);
        // root
        groupName = name;
        fullName = PluginIcon;
        tabGroupId = Text::StripOpenplanetFormatCodes(name);
        IsRoot = true;
        @meta = TabGroupMeta(this);
    }

    void StartCategories(const string &in initialCategoryName) {
        categories.InsertLast(initialCategoryName);
        categoryIsOpen.InsertLast(true);
    }

    void BeginCategory(const string &in name, bool isOpen = false) {
        categories.InsertLast(name);
        categoryEndIxs.InsertLast(tabs.Length);
        categoryIsOpen.InsertLast(isOpen);
    }

    void FinalizeCategories() {
        BeginCategory("Hidden", true);
    }

    bool SetCategoryOpen(uint catIx, bool isOpen) {
        if (catIx >= categoryIsOpen.Length) return false;
        categoryIsOpen[catIx] = isOpen;
        meta.UpdateCategoriesOpen(categories, categoryIsOpen);
        return isOpen;
    }

    void DrawSidebarTabEntries(ClickFlags clicks) override {
        string categoryName = "";
        uint catIx = uint(-1);
        uint nextCatStartsTabIx = 0;
        uint nbCategories = categories.Length;
        auto textCol = UI::GetStyleColor(UI::Col::Text);
        UI::PushStyleColor(UI::Col::Text, textCol);
        bool isOpen = true;
        auto stix = selectedTabIx;
        // we break after looping over categories
        for (uint i = 0;; i++) {
            while (i >= nextCatStartsTabIx && nbCategories > 0) {
                catIx++;
                categoryName = categories[catIx];
                isOpen = categoryIsOpen[catIx];
                nextCatStartsTabIx = (catIx+1) >= nbCategories ? -1 : categoryEndIxs[catIx];
                bool containsActiveTab = i <= uint(stix) && stix < int(nextCatStartsTabIx);
                // bool shouldOpen = !isOpen && containsActiveTab;
                // if (shouldOpen) isOpen = SetCategoryOpen(catIx, true);
                // UI::PushFont(isOpen ? g_BoldFont : g_NormFont);
                DrawCategoryHeader(catIx, categoryName, isOpen, containsActiveTab);
                // UI::SeparatorText("\\$i\\$ffc" + categoryName);
                // UI::PopFont();
                if (categoryName == "Favorites" && isOpen) {
                    UI::PushID("fav");
                    DrawFavoriteTabs_Sidebar(clicks, stix);
                    UI::PopID();
                }
                if (categoryName == "Hidden" && isOpen) {
                    UI::PushID("hidden");
                    DrawHiddenTabs_Sidebar(clicks, stix);
                    UI::PopID();
                }
            }
            if (i >= tabs.Length) break;
            if (!isOpen) continue;
            if (meta.IsHidden(tabs[i].nameIdValue)) continue;
            DrawSidebarTabEntry(i, tabs[i], i == uint(stix), clicks, false);
        }

        UI::PopStyleColor();
    }

    void DrawHiddenTabs_Sidebar(ClickFlags cf, int stix) {
        auto nb = this.meta.hidden.Length;
        for (uint i = 0; i < nb; i++) {
            auto tab = FindTabNamedId(this.meta.hidden[i]);
            if (tab is null) {
                _Log::Warn("DrawHiddenTabs_Sidebar", "Unknown: " + MwIdValueToStr(this.meta.hidden[i]), true);
                this.meta.hidden.RemoveAt(i);
                i--;
            } else {
                auto tix = GetTabIx(tab);
                DrawSidebarTabEntry(tix, tab, tix == stix, cf, true);
            }
        }
    }

    void DrawFavoriteTabs_Sidebar(ClickFlags cf, int stix) {
        auto nb = this.meta.favorites.Length;
        for (uint i = 0; i < nb; i++) {
            auto tab = FindTabNamedId(this.meta.favorites[i]);
            if (tab is null) {
                _Log::Warn("DrawFavoriteTabs_Sidebar", "Unknown: " + MwIdValueToStr(this.meta.favorites[i]), true);
                this.meta.favorites.RemoveAt(i);
                i--;
            } else {
                auto tix = GetTabIx(tab);
                DrawSidebarTabEntry(tix, tab, tix == stix, cf, true);
            }
        }
    }

    void DrawCategoryHeader(uint catIx, const string &in name, bool isOpen, bool containsActiveTab) {
        float height = UI::GetTextLineHeight() * 1.35;
        // vec2 framePad = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
        vec2 framePad = UI::GetStyleVarVec2(UI::StyleVar::CellPadding);
        vec4 secondaryBg = cBlack0;
        auto navHighlight = UI::GetStyleColor(UI::Col::NavHighlight);
        vec4 catBgCol = navHighlight * vec4(.5);
        catBgCol.w = 0.6;

        auto dl = UI::GetWindowDrawList();
        auto catPad = vec2(0, 2);
        auto origPos = UI::GetCursorScreenPos();
        auto pos = origPos - framePad;
        origPos += catPad;
        UI::SetCursorScreenPos(pos);

        auto avail = UI::GetContentRegionAvail();
        auto size = vec2(avail.x, height) + framePad*2.0 + catPad*2.0;
        auto rect = vec4(pos, size);

        // dummy and clicks
        UI::Dummy(size);
        bool hovered = UI::IsItemHovered(UI::HoveredFlags::DelayNone);
        if (hovered) {
            UI::SetMouseCursor(UI::MouseCursor::Hand);
            secondaryBg = catBgCol * .7;
            catBgCol = catBgCol * 1.6;
        }
        if (hovered && UI::IsMouseClicked()) {
            isOpen = SetCategoryOpen(catIx, !categoryIsOpen[catIx]);
            // if (!isOpen && containsActiveTab) {
            //     selectedTabIx = -1; // categoryEndIxs[catIx];
            // }
        }
        UI::SetCursorScreenPos(pos);

        // The bg and label
        dl.AddRectFilledMultiColor(rect, catBgCol, secondaryBg, secondaryBg, catBgCol);
        UI::SetCursorScreenPos(origPos);
        auto icon = isOpen ? Icons::AngleDown : Icons::AngleRight;
        auto textCol = hovered ? "\\$fff" : "\\$eee";
        textCol += isOpen ? "\\$i" : "";
        UI::SeparatorText(icon + textCol + "\\$s " + name);
        auto finalPos = UI::GetCursorScreenPos() + catPad;
        UI::SetCursorScreenPos(finalPos);
        // ensure we don't get UI assertion failures
        UI::Dummy(vec2(0));
        UI::SetCursorScreenPos(finalPos);
    }

    void AterLoadedState() override {
        auto favKeys = meta.categoriesOpen.GetKeys();
        for (uint i = 0; i < categories.Length; i++) {
            auto name = categories[i];
            if (favKeys.Find(name) > -1) {
                categoryIsOpen[i] = J::ToBool(meta.categoriesOpen[name], false);
            }
        }
        SetCategoryOpen(FindCatIdForTabIx(selectedTabIx), true);
    }

    int FindCatIdForTabIx(int tabIx) {
        for (uint i = 0; i < categoryEndIxs.Length; i++) {
            if (tabIx < categoryEndIxs[i]) return i;
        }
        return -1;
    }
}



// MARK: selected tab setting

Json::Value@ _cachedSelectedTabsJson = null;

int GetSelectedTabFor(const string &in tabGroupId) {
    if (_cachedSelectedTabsJson is null) {
        @_cachedSelectedTabsJson = Json::Parse(S_SelectedTabsJson);
    }
    auto @j = _cachedSelectedTabsJson;
    if (j.GetType() != Json::Type::Object || !j.HasKey(tabGroupId)) {
        return 0;
    }
    try {
        return int(j[tabGroupId]);
    } catch {
        j[tabGroupId] = 0;
        return 0;
    }
}

void SetSelectedTabFor(const string &in tabGroupId, int value) {
    if (_cachedSelectedTabsJson is null) {
        @_cachedSelectedTabsJson = Json::Parse(S_SelectedTabsJson);
    }
    auto @j = _cachedSelectedTabsJson;
    if (j.GetType() != Json::Type::Object) {
        @j = Json::Object();
    }
    j[tabGroupId] = value;
    S_SelectedTabsJson = Json::Write(j);
}




class ClickFlags {
    int flags;

    ClickFlags(int getMask = 0xF) {
        flags = 0;
        if (getMask & (1 << 0) != 0) Set(0, UI::IsMouseClicked(UI::MouseButton::Left));
        if (getMask & (1 << 1) != 0) Set(1, UI::IsMouseClicked(UI::MouseButton::Right));
        if (getMask & (1 << 2) != 0) Set(2, UI::IsMouseClicked(UI::MouseButton::Middle));
        if (getMask & (1 << 3) != 0) Set(3, UI::IsMouseClicked(MOUSE_BUTTON_BACK));
        if (getMask & (1 << 4) != 0) Set(4, UI::IsMouseClicked(MOUSE_BUTTON_FORWARD));
    }

    bool get_LMB() { return (flags & 1) != 0; }
    // right mouse button
    bool get_RMB() { return (flags & 2) != 0; }
    // middle mouse button
    bool get_MMB() { return (flags & 4) != 0; }
    bool get_BackMB() { return (flags & 8) != 0; }
    bool get_ForwardMB() { return (flags & 16) != 0; }

    void Set(int flagPos, bool value) {
        if (value) flags |= (1 << flagPos);
        else flags &= ~(1 << flagPos);
    }
}
