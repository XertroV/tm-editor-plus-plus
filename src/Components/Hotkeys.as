class HotkeysTab : Tab {
    HotkeysTab(TabGroup@ p) {
        super(p, "Hotkeys" + NewIndicator, Icons::Fire + Icons::KeyboardO);
    }

    void DrawInner() override {
        UI::AlignTextToFramePadding();
        UI::TextWrapped("\\$fa6Note: under editor plugins, enable the EditorPlusPlus plugin to update the custom selection box.");
        UI::AlignTextToFramePadding();
        UI::Text("Ctrl + F: Fill area with blocks (click + drag)");
    }
}


// thumbnail research
// r8: challenge
// Trackmania.exe+B72497 - 48 8D 15 C23A0301     - lea rdx,[Trackmania.exe+1BA5F60] { ("CGameCtnApp::SaveChallenge") }
