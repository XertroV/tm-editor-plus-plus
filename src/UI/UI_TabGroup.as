class TabGroup {
    Tab@ Parent = null;

    Tab@[] tabs;
    string groupName;
    string fullName;
    bool IsRoot = false;

    TabGroup(const string &in name, Tab@ parent) {
        groupName = name;
        @Parent = parent;
        if (parent is null) return;
        fullName = parent.fullName;
        if (name.Length > 0 && name != parent.tabName) {
            fullName += " > " + name;
        }
    }

    bool AnyActive() {
        for (uint i = 0; i < tabs.Length; i++) {
            auto t = cast<EffectTab>(tabs[i]);
            if (t is null) continue;
            if (t._IsActive) return true;
        }
        return false;
    }

    void SetChildSelected(Tab@ child) {
        if (child is null) return;
        auto ix = tabs.FindByRef(child);
        if (ix >= 0) selectedTabIx = ix;
        else warn("Could not find child: " + child.fullName);
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
        }
    }

    void DrawTabs() {
        UI::BeginTabBar(groupName);

        for (uint i = 0; i < tabs.Length; i++) {
            tabs[i].DrawTab();
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
    int get_selectedTabIx() { return _selectedTabIx; }
    void set_selectedTabIx(int value) { _selectedTabIx = value; }

    void DrawTabsAsSidebar(const string &in title = "") {
        framePadding = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
        regionSize = UI::GetContentRegionAvail();
        auto sbWidth = (sideBarExpanded ? 170. : 60.) * UI::GetScale() + framePadding.x * 2.;
        UI::PushStyleColor(UI::Col::Border, vec4(1));
        if (UI::BeginChild("sidebar-left|" + fullName, vec2(sbWidth, 0), true)) {
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
            }
        }
        UI::EndChild();
        UI::PopStyleColor();
        UI::SameLine();
        if (UI::BeginChild("inner|" + fullName, vec2(-1, -1), false)) {
            if (selectedTabIx >= 0 && selectedTabIx < int(tabs.Length)) {
                tabs[selectedTabIx].DrawTab(false);
            } else {
                UI::Text("No tab selected");
            }
        }
        UI::EndChild();
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
}

class RootTabGroupCls : TabGroup {
    RootTabGroupCls() {
        super("Root", null);
        // root
        groupName = "Root";
        // fullName = "E++";
        fullName = PluginIcon + "\\$z";
        IsRoot = true;
    }

    int get_selectedTabIx() override property {
        return Math::Min(tabs.Length - 1, S_MainSelectedTab);
    }
    void set_selectedTabIx(int value) override property {
        S_MainSelectedTab = value;
    }
}
