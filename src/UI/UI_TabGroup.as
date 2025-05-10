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
            tabs[i].SetSelectedInGroup(i == ix);
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
        bool rClick = UI::IsMouseClicked(UI::MouseButton::Right);
        bool mClick = UI::IsMouseClicked(UI::MouseButton::Middle);

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
            for (int i = 0; i < int(tabs.Length); i++) {
                auto tab = tabs[i];
                if (UI::Selectable(sideBarExpanded ? tab.DisplayIconAndName : tab.DisplayIconWithId, selectedTabIx == i)) {
                    selectedTabIx = i;
                }
                bool hovered = UI::IsItemHovered(UI::HoveredFlags::DelayNone);
                if (hovered) {
                    if (rClick) tab.OnSideBarLabel_RightClick();
                    else if (mClick) tab.OnSideBarLabel_MiddleClick();
                }
            }
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

    void FavoriteTab(Tab@ t) {
        if (t is null) return;
        auto ix = tabs.FindByRef(t);
        if (t.nameIdValue < 0) {
            _Log::Warn_NID("FavoriteTab", "Tab has no nameIdValue: " + t.fullName);
        }
        if (ix >= 0) {
            meta.AddFavorite(t.nameIdValue);
            // todo: favorites logic
            // tabs.RemoveAt(ix);
            // tabs.InsertAt(0, t);
        }
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

class RootTabGroupCls : TabGroup {
    RootTabGroupCls(const string &in name = "Root") {
        super(name, null);
        // root
        groupName = name;
        fullName = PluginIcon;
        tabGroupId = Text::StripOpenplanetFormatCodes(name);
        IsRoot = true;
        @meta = TabGroupMeta(this);
    }
}

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
