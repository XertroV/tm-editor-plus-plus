class HotkeysTab : Tab {
    HotkeysTab(TabGroup@ p) {
        super(p, "Hotkeys", Icons::Fire + Icons::KeyboardO);
    }

    void DrawInner() override {
        UI::AlignTextToFramePadding();
        UI_DrawHotkeyList();
    }
}


// thumbnail research
// r8: challenge
// Trackmania.exe+B72497 - 48 8D 15 C23A0301     - lea rdx,[Trackmania.exe+1BA5F60] { ("CGameCtnApp::SaveChallenge") }
