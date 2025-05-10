class LaunchedCPsTab : Tab {
    LaunchedCPsTab(TabGroup@ p) {
        super(p, "Launched CPs", Icons::ClockO + Icons::Car);
        ShowNewIndicator = true;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto launchedCPs = Editor::GetLaunchedCPs(editor);
        if (launchedCPs is null) {
            UI::Text("\\$f80 Error! Cannot find Launched CPs!");
            return;
        }
        ItemModelTreeElement(null, -1, launchedCPs, "Launched CPs", true, O_EDITOR_LAUNCHEDCPS, false).Draw();
    }
}



class _GameSaveLaunchedCheckpoints {
    CGameSaveLaunchedCheckpoints@ gslcps;
    _GameSaveLaunchedCheckpoints(CGameSaveLaunchedCheckpoints@ gslcps) {
        @this.gslcps = gslcps;
    }

    // bufs at 0x18, 0x28
    // b1: 1 per cp + 1 for fin
    // b2: 0x1B -> 0x35 -> 0x50 -> (after a same cp) 0x51, then through fin -> 0x50 -> 0x51 after fin
    // 0x38: 1, 0x2d75
    // u1: 1 -> ? -> 4 -> (with cps) 5 -> 6
    // b1: 0x80 chunk length,

    RawBuffer@ GetCPsIndex() {
        return RawBuffer(gslcps, 0x18, 0x2F0);
    }

    RawBuffer@ GetLaunchStates() {
        return RawBuffer(gslcps, 0x28, 0x368);
    }
}
