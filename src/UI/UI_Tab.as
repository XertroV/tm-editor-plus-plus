class Tab : HasTabMeta {
    string idNonce;

    // bool canCloseTab = false;
    TabGroup@ Parent = null;
    TabGroup@ Children = null;
    TabGroup@ WindowChildren = null;

    string tabName;
    // ID of the tab...
    string tabId;
    string fullName;
    string tabIcon;
    string tabIconAndName;
    uint windowExtraId = 0;
    bool addRandWindowExtraId = false;
    int nameIdValue = -1;

    bool removable = false;
    bool canPopOut = true;
    // false when popped out, true otherwise
    bool tabOpen = true;
    bool expandWindowNextFrame = false;
    bool windowExpanded = false;
    bool closeWindowOnEscape = false;
    bool isSelectedInGroup = false;
    bool ShowNewIndicator = false;

    bool tabInWarningState = false;

    bool get_windowOpen() { return !tabOpen; }
    void set_windowOpen(bool value) {
        if (tabOpen == value) startnew(CoroutineFunc(this.OnStaleMeta));
        tabOpen = !value;
    }

    Tab(TabGroup@ parent, const string &in tabName, const string &in icon) {
        this.tabName = tabName;
        // .Parent set here
        parent.AddTab(this);

        fullName = parent.fullName + " > " + tabName;
        tabId = parent.tabGroupId + "." + Json::Write(Json::Value(Text::StripOpenplanetFormatCodes(tabName)));
        tabIcon = " " + icon;
        tabIconAndName = tabIcon + " " + tabName;
        idNonce = "t" + Text::Format("%x", Math::Rand(0, TWO_MILLION));

        @Children = TabGroup(tabName, this);
        @WindowChildren = TabGroup(tabName+"WC", this);

        if (addRandWindowExtraId) {
            windowExtraId = Math::Rand(0, TWO_BILLION);
        }
        @meta = TabMeta(this);
        nameIdValue = meta.tabNameIdValue;
    }

    const string get_DisplayIconAndName() {
        if (tabInWarningState) {
            return "\\$f80" + tabIconAndName + "  " + Icons::ExclamationTriangle;
        }
        return tabIconAndName + (ShowNewIndicator ? NewIndicator : "");
    }

    const string get_DisplayIcon() {
        return tabIcon;
    }

    const string get_DisplayIconWithId() {
        return tabIcon + "###" + tabName;
    }

    protected bool _openSidebarContextMenu = false;

    // triggered from main ui when drawing tab label in sidebar. Used for popping out / options.
    void OnSideBarLabel_RightClick() {
        _openSidebarContextMenu = true;
        AddMiscWindowRenderCallback(TmpWindowRenderF(this.DrawSidebarContextMenu));

    }
    void OnSideBarLabel_MiddleClick() {
        if (canPopOut) windowOpen = true;
    }

    protected bool _ShouldSelectNext = false;

    void SetSelectedTab() {
        _ShouldSelectNext = true;
        Parent.SetChildSelected(this);
    }

    void SetSelectedTab_Debounce() {
        isSelectedInGroup = true;
        _ShouldSelectNext = true;
        if (Parent !is null) {
            Parent.SetChildSelected(this, false);
            if (Parent.Parent !is null)
                Parent.Parent.SetSelectedTab_Debounce();
        }
        _Log::Trace("Tab::"+fullName, "SetSelectedTab_Debounce => " + isSelectedInGroup);
        startnew(CoroutineFunc(OnStaleMeta));
    }

    void SetSelectedInGroup(bool value) {
        if (isSelectedInGroup == value) return;
        isSelectedInGroup = value;
        startnew(CoroutineFunc(OnStaleMeta));
        _Log::Debug("Tab::"+fullName, "SetSelectedInGroup => " + value);
        if (value) {
            TabState::GetNavHistoryStack(RootTabGroupID()).Push(this);
        }
    }

    string RootTabGroupID() {
        return Parent.RootTabGroupID();
    }

    void OnStaleMeta() {
        meta.SetOpenFlags(this);
        meta.MarkStale();
    }

    int get_TabFlags() {
        int flags = UI::TabItemFlags::NoCloseWithMiddleMouseButton
            | UI::TabItemFlags::NoReorder
            ;
        if (_ShouldSelectNext) {
            _ShouldSelectNext = false;
            flags |= UI::TabItemFlags::SetSelected;
        }
        return flags;
    }

    int get_WindowFlags() {
        return UI::WindowFlags::None
            // UI::WindowFlags::AlwaysAutoResize
            // | UI::WindowFlags::NoCollapse
            ;
    }

    void DrawTogglePop() {
        if (UI::Button((tabOpen ? Icons::Expand : Icons::Compress) + "##" + fullName)) {
            windowOpen = !windowOpen;
        }
        if (removable) {
            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() + vec2(20, 0));
            if (UI::Button(Icons::Trash + "##" + fullName)) {
                Parent.RemoveTab(this);
            }
        }
    }

    void DrawMenuItem() {
        if (UI::MenuItem(DisplayIconAndName, "", windowOpen)) {
            windowOpen = !windowOpen;
        }
    }

    // returns true if the tab was drawn
    bool DrawTab(bool asTabItem = true) {
        if (!asTabItem) {
            return DrawTabWrapInner();
        }
        bool ret = false;
        if (UI::BeginTabItem(tabName, TabFlags)) {
            if (UI::BeginChild(fullName))
                ret = DrawTabWrapInner();
            UI::EndChild();
            UI::EndTabItem();
        }
        return ret;
    }

    bool DrawTabWrapInner() {
        UX::LayoutLeftRight("tabHeader|"+fullName,
            CoroutineFunc(_HeadingLeft),
            CoroutineFunc(_HeadingRight)
        );
        UI::Indent();
        if (!tabOpen) {
            UI::Text("Currently popped out.");
        } else {
            DrawInnerWrapID();
        }
        UI::Unindent();
        return true;
    }

    void _HeadingLeft() {
        UI::AlignTextToFramePadding();
        UI::Text(tabName + ": ");
    }

    void _HeadingRight() {
        DrawFavoriteButton();
        if (!tabOpen) {
            if (!windowExpanded) {
                if (UI::Button("Expand Window##"+fullName)) {
                    expandWindowNextFrame = true;
                }
                UI::SameLine();
            }
            if (UI::Button("Return to Tab##"+fullName)) {
                windowOpen = !windowOpen;
            }
        } else {
            if (canPopOut) {
                DrawTogglePop();
            }
        }
    }

    // override me
    bool get_favEnabled() {return false;}
    InvObjectType type;

    void SetupFav(InvObjectType type) {
        this.type = type;
    }

    void DrawFavoriteButton() {
        if (!favEnabled) return;
        auto idName = GetFavIdName();
        if (idName.Length == 0) return;

        bool isFav = g_Favorites.IsFavorited(idName, type);
        if (isFav && UI::ButtonColored(Icons::Star, .4)) {
            g_Favorites.RemoteFromFavorites(idName, type);
        } else if (!isFav && UI::Button(Icons::Star)) {
            g_Favorites.AddToFavorites(idName, type);
        }
        UI::SameLine();
    }

    // override me
    string GetFavIdName() {
        return "";
    }

    void DrawInner() {
        UI::Text("Tab Inner: " + tabName);
        UI::Text("Overload `DrawInner()`");
    }

    void DrawInnerWrapID() {
        UI::PushID(idNonce);
        DrawInner();
        UI::PopID();
    }

    vec2 lastWindowPos;
    bool DrawWindow() {
        if (windowOpen) {
            if (expandWindowNextFrame && windowOpen && addRandWindowExtraId) {
                UI::SetNextWindowPos(int(lastWindowPos.x), int(lastWindowPos.y));
                windowExtraId = Math::Rand(0, TWO_BILLION);
            }
            expandWindowNextFrame = false;
            windowExpanded = false;
            _BeforeBeginWindow();
            if (UI::Begin(fullName + "##" + windowExtraId, windowOpen, WindowFlags)) {
                windowExpanded = true;
                // DrawTogglePop();
                DrawInnerWrapID();
                if (closeWindowOnEscape && UI::IsKeyPressed(UI::Key::Escape) && UI::IsWindowFocused(UI::FocusedFlags::RootAndChildWindows)) {
                    windowOpen = false;
                }
            }
            lastWindowPos = UI::GetWindowPos();
            UI::End();
        }

        Children.DrawWindows();
        WindowChildren.DrawWindowsAndRemoveTabsWhenClosed();

        return windowOpen;
    }

    void _BeforeBeginWindow() {
        // override
        UI::SetNextWindowSize(600, 400, UI::Cond::FirstUseEver);
    }

    bool DrawSidebarContextMenu() {
        if (_openSidebarContextMenu) {
            UI::OpenPopup("sb|" + fullName);
            _openSidebarContextMenu = false;
        }
        if (UI::BeginPopupContextItem("sb|" + fullName)) {
            if (UI::MenuItem("Pop Out")) {
                windowOpen = !windowOpen;
            }
            if (UI::MenuItem("Favorite Tab")) {
                Parent.FavoriteTab(this);
            }
            Parent.DrawHideShowTabMenuItem(this);
            UX::CloseCurrentPopupIfMouseFarAway();
            UI::EndPopup();
            return true;
        }
        return false;
    }

    void AfterLoadedState() {
        if (meta.IsSelected) {
            _Log::Trace("Tab::AfterLoadedState", fullName + " selected");
            _ShouldSelectNext = true;
        }
        if (meta.WindowOpen) {
            _Log::Trace("Tab::AfterLoadedState", fullName + " window open");
            tabOpen = false; // implies windowOpen => true
        }
        if (meta.idNonce.Length > 0) idNonce = meta.idNonce;
        else meta.idNonce = idNonce;
    }
}

mixin class HasTabMeta {
    TabMeta@ meta;

    // void Json_SetStateUnderKey(Json::Value@ j) {
    //     meta.WriteToJson(j);
    // }
    void WritingJson_WriteObjKeyEl(string[]& parts) {
        meta.WritingJson_WriteObjKeyEl(parts);
    }

    void Json_LoadState(Json::Value@ j) {
        meta.LoadFromJson(j);
        AfterLoadedState();
    }

    // void AddMiscWindowRenderCallback(RenderCallback@ callback) {
    //     if (meta !is null) {
    //         meta.AddMiscWindowRenderCallback(callback);
    //     }
    // }
}



class TodoTab : Tab {
    string description;

    TodoTab(TabGroup@ parent, const string&in tabName, const string&in icon, const string &in desc = "??") {
        super(parent, "\\$888" + tabName, icon);
        description = desc;
        canPopOut = false;
    }

    void DrawInner() override {
        UI::TextWrapped("Todo. This tab will " + description);
        UI::TextWrapped("Request features in the `Help > Plugin Support Thread` on the openplanet discord! It helps with prioritization and provides ideas for new features.");
        // creates some min width:
        // UI::Text("This tab full name is: " + fullName);
    }
}


// namespace TabState {
//     [Setting hidden]
//     string S_TabStatePoppedJson = "[]";

//     [Setting hidden]
//     string S_TabStateMain = "";
// }
