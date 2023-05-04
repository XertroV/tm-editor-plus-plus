
class Tab {
    string idNonce = "tab-" + Math::Rand(0, 2000000000);

    // bool canCloseTab = false;
    TabGroup@ Parent = null;
    TabGroup@ Children = null;

    string tabName;
    string fullName;
    string tabIcon;
    string tabIconAndName;

    bool removable = false;
    bool canPopOut = true;
    bool tabOpen = true;
    bool windowOpen {
        get { return !tabOpen; }
        set { tabOpen = !value; }
    }

    Tab(TabGroup@ parent, const string &in tabName, const string &in icon) {
        this.tabName = tabName;
        // .Parent set here
        parent.AddTab(this);
        fullName = parent.fullName + " > " + tabName;
        tabIcon = " " + icon;
        tabIconAndName = tabIcon + " " + tabName;
        @Children = TabGroup(tabName, this);
    }

    int get_TabFlags() {
        return UI::TabItemFlags::NoCloseWithMiddleMouseButton
            | UI::TabItemFlags::NoReorder
            ;
    }

    int get_WindowFlags() {
        return UI::WindowFlags::AlwaysAutoResize
            // | UI::WindowFlags::NoCollapse
            ;
    }

    void DrawTogglePop() {
        if (UI::Button((tabOpen ? Icons::Expand : Icons::Compress) + "##" + fullName)) {
            tabOpen = !tabOpen;
        }
        if (removable) {
            UI::SameLine();
            UI::SetCursorPos(UI::GetCursorPos() + vec2(20, 0));
            if (UI::Button(Icons::Trash + "##" + fullName)) {
                Parent.RemoveTab(this);
            }
        }
    }

    void DrawTab(bool withItem = true) {
        if (!withItem) {
            DrawTabWrapInner();
            return;
        }
        if (UI::BeginTabItem(tabName, TabFlags)) {
            DrawTabWrapInner();
            UI::EndTabItem();
        }
    }

    void DrawTabWrapInner() {
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
    }

    void _HeadingLeft() {
        UI::AlignTextToFramePadding();
        UI::Text(tabName + ": ");
    }

    void _HeadingRight() {
        if (!tabOpen) {
            if (UI::Button("Return to Tab##"+fullName)) {
                tabOpen = !tabOpen;
            }
        } else {
            if (canPopOut) {
                DrawTogglePop();
            }
        }
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

    void DrawWindow() {
        Children.DrawWindows();
        if (!windowOpen) return;
        if (UI::Begin(fullName, windowOpen, WindowFlags)) {
            // DrawTogglePop();
            DrawInnerWrapID();
        }
        UI::End();
    }
}