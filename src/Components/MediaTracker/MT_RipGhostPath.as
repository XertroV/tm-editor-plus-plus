class MT_RipGhostPathTab : Tab {
    MT_RipGhostPathTab(TabGroup@ p) {
        super(p, "Rip Ghost Path", Icons::Car + Icons::Crosshairs + Icons::ListAlt);
        RegisterOnMTEditorLoadCallback(CoroutineFunc(this.OnMTEditorLoad), tabName);
    }

    private string ghostRipFolder = IO::FromStorageFolder("ripped-ghosts");

    string lastClipName = "";
    uint lastClipTracksLen = 0;

    void OnMTEditorLoad() {
        lastClipName = "";
        ResetCache();
        if (!IO::FolderExists(ghostRipFolder)) {
            IO::CreateFolder(ghostRipFolder);
        }
    }

    bool checkedForGhost = false;
    bool canRipGhost = false;
    int ripGhostTrackNb = -1;

    void ResetCache() {
        checkedForGhost = false;
        canRipGhost = false;
        ripGhostTrackNb = -1;
        lastSavedGhostRip = "";
        StopRipNow();
    }

    /*
    void CheckGPSCamTarget(CGameEditorMediaTracker@ mteditor, bool shouldFix = false) {
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
    */


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

        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        auto clip = api.Clip;

        if (clip.Name != lastClipName || clip.Tracks.Length != lastClipTracksLen) {
            lastClipName = clip.Name;
            lastClipTracksLen = clip.Tracks.Length;
            ResetCache();
        }

        if (!checkedForGhost) {
            DrawCheckForGhostPrompt();
            return;
        }

        if (!canRipGhost) {
            UI::TextWrapped("No ghost to rip. Please add a ghost.");
            return;
        }

        if (ripGhostTrackNb < 0) {
            UI::TextWrapped("Something went wrong: the ghost track index is " + ripGhostTrackNb);
            return;
        }

        UI::BeginDisabled(CurrentlyRippingGhost);
        UI::AlignTextToFramePadding();
        UI::TextWrapped("Ready to rip ghost at track number " + (ripGhostTrackNb + 1));

        UI::AlignTextToFramePadding();
        UI::TextWrapped("\\$f80Please do not have any recorded ghosts / ghosts references playing. (Author ghost, and reference ghost 1, 2, 3.)\\$z If you only see 1 ghost, then it's fine.");

        playbackSpeedWhileRipping = UI::SliderFloat("Playback Speed While Ripping", playbackSpeedWhileRipping, 0.1, 20.0, "%.1f");
        AddSimpleTooltip("Ghost positions are recorded every 50ms, so it should be relatively safe to run this at 5x @ 100fps. Can be adjusted depending on resolution needs.");

        if (UI::Button("Begin ripping ghost")) {
            startnew(CoroutineFunc(this.RunRipGhost));
        }

        UI::Separator();

        if (UI::Button("Open output ghost positions folder")) {
            OpenExplorerPath(ghostRipFolder);
        }

        if (lastSavedGhostRip.Length > 0) {
            UI::Text("Last saved ghost rip: " + lastSavedGhostRip);
        }

        UI::EndDisabled();

        if (CurrentlyRippingGhost) {
            UI::AlignTextToFramePadding();
            UI::TextWrapped("\\$f80Currently ripping ghost. Please let this run.");
            DrawRipStatus();
            if (UI::Button("Stop Ripping")) {
                this.StopRipNow();
            }
        }
    }

    float playbackSpeedWhileRipping = 4.0;

    void DrawCheckForGhostPrompt() {
        UI::Text("Status: have not yet checked for a ghost to rip.");
        UI::TextWrapped("This will select the 1st ghost found -- please isolate the ghost (ctrl+c and, in a new trigger, ctrl+v) if it is not the 1st ghost.");
        if (UI::Button("Check for ghost to rip")) {
            startnew(CoroutineFunc(this.CheckForGhostToRip));
        }
    }

    void CheckForGhostToRip() {
        auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        auto clip = api.Clip;
        checkedForGhost = true;
        for (uint i = 0; i < clip.Tracks.Length; i++) {
            auto track = clip.Tracks[i];
            if (track.Blocks.Length == 0) continue;
            auto ghostBlock = cast<CGameCtnMediaBlockEntity>(track.Blocks[0]);
            if (ghostBlock is null) continue;
            canRipGhost = true;
            ripGhostTrackNb = i;
            break;
        }
    }


    void RunRipGhost() {
        auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        auto clip = api.Clip;
        // auto track = clip.Tracks[ripGhostTrackNb];
        api.PlaySpeed = 5.0;
        api.CurrentTimer = 0.0;
        startnew(CoroutineFunc(this.RecordVisibleGhostData));
        yield();
        api.TimePlay();
    }

    vec3[] ghostPositions;

    void ZeroRecordingBuffer() {
        ghostPositions.RemoveRange(0, ghostPositions.Length);
    }

    bool CurrentlyRippingGhost = false;
    void RecordVisibleGhostData() {
        if (CurrentlyRippingGhost) return;
        auto app = GetApp();
        ZeroRecordingBuffer();
        CSceneVehicleVis@ vis;
        CurrentlyRippingGhost = true;
        float lastRipTime = 0.0;
        while ((@vis = VehicleState::GetSingularVis(app.GameScene)) !is null && CurrentlyRippingGhost) {
            ghostPositions.InsertLast(vis.AsyncState.Position);
            float currTime = GetCurrentMTPlaybackTime();
            if (currTime < lastRipTime) break;
            lastRipTime = currTime;
            yield();
        }
        CurrentlyRippingGhost = false;
        SaveGhostRip();
        try {
            auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
            auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
            api.TimeStop();
            api.PlaySpeed = 1.0;
            api.CurrentTimer = 0.0;
        } catch {
            trace("Exception trying to stop the MT timer: " + getExceptionInfo());
        }
    }

    float GetCurrentMTPlaybackTime() {
        auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        return api.CurrentTimer;
    }

    void StopRipNow() {
        CurrentlyRippingGhost = false;
    }

    void DrawRipStatus() {
        if (!CurrentlyRippingGhost) {
            UI::Text("Not ripping.");
            return;
        }

        UI::Text("Ripped Positions: " + ghostPositions.Length);
    }

    string lastSavedGhostRip;

    void SaveGhostRip() {
        lastSavedGhostRip = Time::Stamp + "_ghost.csv";
        Notify('Saving ' + ghostPositions.Length + ' ghost positions to ' + lastSavedGhostRip);
        IO::File f(ghostRipFolder + "/" + lastSavedGhostRip, IO::FileMode::Write);
        for (uint i = 0; i < ghostPositions.Length; i++) {
            f.WriteLine(ghostPositions[i].ToString());
        }
        f.Close();
        NotifySuccess("Saved ghost positions to " + lastSavedGhostRip);
    }
}
