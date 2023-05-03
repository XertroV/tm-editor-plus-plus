class TabGroup {
    Tab@ Parent = null;

    Tab@[] tabs;
    string groupName;
    string fullName;
    bool IsRoot = false;

    TabGroup() {
        // root
        groupName = "Root";
        fullName = "";
        IsRoot = true;
    }

    TabGroup(const string &in name, Tab@ parent) {
        groupName = name;
        @Parent = parent;
        fullName = parent.fullName;
        if (name.Length > 0 && name != parent.tabName) {
            fullName += " > " + name;
        }
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
    int selectedTabIx = 0;

    void DrawTabsAsSidebar(const string &in title = "") {
        framePadding = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);
        regionSize = UI::GetContentRegionAvail();
        auto sbWidth = (sideBarExpanded ? 170. : 60.) + framePadding.x * 2.;
        UI::PushStyleColor(UI::Col::Border, cWhite);
        if (UI::BeginChild("sidebar-left|" + fullName, vec2(sbWidth, 0), true)) {
            if (title.Length > 0) {
                UI::PushFont(g_Heading);
                UI::AlignTextToFramePadding();
                UI::Text(title);
                UI::PopFont();
            }
            if (UI::Button(Icons::Bars + "##expand-" + fullName)) {
                sideBarExpanded = !sideBarExpanded;
            }
            for (uint i = 0; i < tabs.Length; i++) {
                auto tab = tabs[i];
                if (UI::Selectable(sideBarExpanded ? tab.tabIconAndName : tab.tabIcon, selectedTabIx == i)) {
                    selectedTabIx = i;
                }
            }
        }
        UI::EndChild();
        UI::PopStyleColor();
        UI::SameLine();
        if (UI::BeginChild("inner|" + fullName, vec2(-1, -1), false)) {
            if (selectedTabIx >= 0 && selectedTabIx < tabs.Length) {
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
}
