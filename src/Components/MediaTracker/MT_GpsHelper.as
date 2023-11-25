class MT_GpsHelperTab : Tab {
    MT_GpsHelperTab(TabGroup@ p) {
        super(p, "GPS Helper", Icons::Car + Icons::Camera + Icons::Medkit);
        RegisterOnMTEditorLoadCallback(CoroutineFunc(this.OnMTEditorLoad), "GpsHelper");
    }

    void OnMTEditorLoad() {
        startnew(CoroutineFunc(MTEditorWatchLoop));
    }

    void MTEditorWatchLoop() {
        yield();
        CGameEditorMediaTracker@ mteditor;
        while ((@mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor)) !is null) {
            try {
                CheckGPSCamTarget(mteditor);
            } catch {
                warn("Exception during MTEditorWatchLoop: " + getExceptionInfo());
            }
            sleep(1373);
        }
    }

    string[] gpsWarningClips;

    void CheckGPSCamTarget(CGameEditorMediaTracker@ mteditor, bool shouldFix = false) {
        tabInWarningState = false;
        gpsWarningClips.RemoveRange(0, gpsWarningClips.Length);
        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        auto cg = api.ClipGroup;
        for (uint i = 0; i < cg.Clips.Length; i++) {
            auto clip = cg.Clips[i];
            CGameCtnMediaBlockCameraGame@ badCamBlock;
            bool hasGhost = false;
            // ghosts are under cams but useful if we find them first
            for (int tx = clip.Tracks.Length - 1; tx >= 0; tx--) {
                auto track = clip.Tracks[tx];
                for (int bx = track.Blocks.Length - 1; bx >= 0; bx--) {
                    auto block = track.Blocks[bx];
                    auto entBlock = cast<CGameCtnMediaBlockEntity>(block);
                    auto playerCamBlock = cast<CGameCtnMediaBlockCameraGame>(block);
                    if (entBlock !is null) {
                        hasGhost = true;
                        break;
                    }
                    if (playerCamBlock !is null && playerCamBlock.ClipEntId == 0) {
                        if (hasGhost && shouldFix) {
                            MTBlockCameraGame(playerCamBlock).ClipEntId = 1;
                        } else {
                            @badCamBlock = playerCamBlock;
                            break;
                        }
                    }
                }
                if (badCamBlock !is null && hasGhost) {
                    if (shouldFix) {
                        MTBlockCameraGame(badCamBlock).ClipEntId = 1;
                        @badCamBlock = null;
                    } else {
                        break;
                    }
                }
            }
            if (badCamBlock !is null && hasGhost) {
                tabInWarningState = true;
                gpsWarningClips.InsertLast(string(clip.Name));
            }
        }
    }

    void DrawInner() override {
        auto map = GetApp().RootMap;
        if (map is null) {
            UI::Text("RootMap is null!");
            return;
        }

        auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
        if (mteditor is null) {
            UI::Text("App.Editor is not a MediaTracker editor!");
            return;
        }

        if (gpsWarningClips.Length == 0) {
            UI::Text("\\$3b3GPS Camera Target Checker: OK");
        } else {
            UI::TextWrapped("\\$f80Clips with a Player Camera set to Local Player (if it's a GPS, this should be fixed):\n> " + string::Join(gpsWarningClips, ", "));
            if (UI::Button("Set all bad player camera tracks to target 1st ghost")) {
                CheckGPSCamTarget(mteditor, true);
                uint count = 1;
                while (tabInWarningState && count < 5) {
                    CheckGPSCamTarget(mteditor, true);
                    count++;
                }
            }
        }
    }
}


class MTBlockCameraGame {
    CGameCtnMediaBlockCameraGame@ bCamGame;
    MTBlockCameraGame(CGameCtnMediaBlockCameraGame@ bCamGame) {
        @this.bCamGame = bCamGame;
    }

    uint get_ClipEntId() {
        return bCamGame.ClipEntId;
    }
    void set_ClipEntId(uint value) {
        Dev::SetOffset(bCamGame, GetOffset("CGameCtnMediaBlockCameraGame", "ClipEntId"), value);
    }
}
