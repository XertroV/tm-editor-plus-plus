namespace MediatrackerSaver {
    void RegisterCallbacks() {
        RegisterOnMTEditorLoadCallback(MediatrackerSaver::OnEnterMTEditor, "MediatrackerSaver::OnEnterMTEditor");
        RegisterOnMTEditorUnloadCallback(MediatrackerSaver::OnLeaveMTEditor, "MediatrackerSaver::OnLeaveMTEditor");
        RegisterOnEditorUnloadCallback(MediatrackerSaver::OnLeaveMainEditor, "MediatrackerSaver::OnLeaveMainEditor");
    }

    void OnEnterMTEditor() {}

    void OnLeaveMTEditor() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto map = editor.Challenge;
        if (map is null) return;
        SetClipG(MTClipTy::EndRace, map.ClipGroupEndRace);
        SetClipG(MTClipTy::InGame, map.ClipGroupInGame);
        SetClip(MTClipTy::Ambiance, map.ClipAmbiance);
        SetClip(MTClipTy::Intro, map.ClipIntro);
        SetClip(MTClipTy::Podium, Editor::GetMapPodiumClip(map));
        startnew(WatchForClipChanges);
    }

    void OnLeaveMainEditor() {
        SetClip(MTClipTy::Ambiance, null);
        SetClip(MTClipTy::Intro, null);
        SetClip(MTClipTy::Podium, null);
        SetClipG(MTClipTy::EndRace, null);
        SetClipG(MTClipTy::InGame, null);
    }

    uint _watchForClipChangesNonce = 0;

    void WatchForClipChanges() {
        auto app = GetApp();
        auto myNonce = ++_watchForClipChangesNonce;
        while (IsInAnyEditor && _watchForClipChangesNonce == myNonce) {
            if (IsInEditor) {
                CheckForMissingClips(app.RootMap);
            }
            yield(5);
        }
        dev_trace("MediatrackerSaver::WatchForClipChanges exited (myNonce = " + myNonce + ")");
    }


    enum MTClipTy {
        InGame, EndRace, Podium, Intro, Ambiance
    }

    CGameCtnMediaClipGroup@ clipEndRace;
    CGameCtnMediaClipGroup@ clipInGame;
    CGameCtnMediaClip@ clipIntro;
    CGameCtnMediaClip@ clipPodium;
    CGameCtnMediaClip@ clipAmbiance;

    void SetClip(MTClipTy ty, CGameCtnMediaClip@ clip) {
        if (ty == MTClipTy::Intro) {
            auto oldClip = clipIntro;
            @clipIntro = clip;
            AddRefIfNonNull(clipIntro);
            ReleaseIfNonNull(oldClip);
        } else if (ty == MTClipTy::Podium) {
            auto oldClip = clipPodium;
            @clipPodium = clip;
            AddRefIfNonNull(clipPodium);
            ReleaseIfNonNull(oldClip);
        } else if (ty == MTClipTy::Ambiance) {
            auto oldClip = clipAmbiance;
            @clipAmbiance = clip;
            AddRefIfNonNull(clipAmbiance);
            ReleaseIfNonNull(oldClip);
        } else {
            throw("Invalid MTClipTy (only intro, podium, or ambiance)");
        }
    }

    void SetClipG(MTClipTy ty, CGameCtnMediaClipGroup@ clip) {
        if (ty == MTClipTy::EndRace) {
            auto oldClip = clipEndRace;
            @clipEndRace = clip;
            AddRefIfNonNull(clipEndRace);
            ReleaseIfNonNull(oldClip);
        } else if (ty == MTClipTy::InGame) {
            auto oldClip = clipInGame;
            @clipInGame = clip;
            AddRefIfNonNull(clipInGame);
            ReleaseIfNonNull(oldClip);
        } else {
            throw("Invalid MTClipTy (only ingame or endrace)");
        }
    }

    void CheckForMissingClips(CGameCtnChallenge@ map) {
        if (map is null) {
            haveSomeClipsGoneMissing = false;
            return;
        }
        if (map.ClipGroupEndRace !is clipEndRace
            || map.ClipGroupInGame !is clipInGame
            || map.ClipAmbiance !is clipAmbiance
            || map.ClipIntro !is clipIntro
            || Editor::GetMapPodiumClip(map) !is clipPodium) {
            haveSomeClipsGoneMissing = true;
            return;
        }
        haveSomeClipsGoneMissing = false;
    }

    bool HasClip(MTClipTy ty) {
        if (ty == MTClipTy::Intro) return clipIntro !is null;
        if (ty == MTClipTy::Podium) return clipPodium !is null;
        if (ty == MTClipTy::Ambiance) return clipAmbiance !is null;
        if (ty == MTClipTy::EndRace) return clipEndRace !is null;
        if (ty == MTClipTy::InGame) return clipInGame !is null;
        throw("Invalid MTClipTy");
        return false;
    }

    bool IsClipChanged(MTClipTy ty, CGameCtnChallenge@ map) {
        return GetMapClipNod(ty, map) !is GetClipNod(ty);
    }

    CMwNod@ GetClipNod(MTClipTy ty) {
        if (ty == MTClipTy::Intro) return clipIntro;
        if (ty == MTClipTy::Podium) return clipPodium;
        if (ty == MTClipTy::Ambiance) return clipAmbiance;
        if (ty == MTClipTy::EndRace) return clipEndRace;
        if (ty == MTClipTy::InGame) return clipInGame;
        throw("Invalid MTClipTy");
        return null;
    }

    CMwNod@ GetMapClipNod(MTClipTy ty, CGameCtnChallenge@ map) {
        if (ty == MTClipTy::Intro) return map.ClipIntro;
        if (ty == MTClipTy::Podium) return Editor::GetMapPodiumClip(map);
        if (ty == MTClipTy::Ambiance) return map.ClipAmbiance;
        if (ty == MTClipTy::EndRace) return map.ClipGroupEndRace;
        if (ty == MTClipTy::InGame) return map.ClipGroupInGame;
        throw("Invalid MTClipTy");
        return null;
    }

    void SetClipFromMap(MTClipTy ty, CGameCtnChallenge@ map) {
        if (ty == MTClipTy::Intro) SetClip(ty, map.ClipIntro);
        else if (ty == MTClipTy::Podium) SetClip(ty, Editor::GetMapPodiumClip(map));
        else if (ty == MTClipTy::Ambiance) SetClip(ty, map.ClipAmbiance);
        else if (ty == MTClipTy::EndRace) SetClipG(ty, map.ClipGroupEndRace);
        else if (ty == MTClipTy::InGame) SetClipG(ty, map.ClipGroupInGame);
        else throw("Invalid MTClipTy");
    }

    void SetClipOnMap(MTClipTy ty, CGameCtnChallenge@ map) {
        if (ty == MTClipTy::Intro) {
            auto oldClip = map.ClipIntro;
            @map.ClipIntro = clipIntro;
            ReleaseIfNonNull(oldClip);
            AddRefIfNonNull(clipIntro);
        } else if (ty == MTClipTy::Podium) {
            auto oldClip = Editor::GetMapPodiumClip(map);
            Editor::SetMapPodiumClip(map, clipPodium);
            ReleaseIfNonNull(oldClip);
            AddRefIfNonNull(clipPodium);
        } else if (ty == MTClipTy::Ambiance) {
            auto oldClip = map.ClipAmbiance;
            @map.ClipAmbiance = clipAmbiance;
            ReleaseIfNonNull(oldClip);
            AddRefIfNonNull(clipAmbiance);
        } else if (ty == MTClipTy::EndRace) {
            auto oldClip = map.ClipGroupEndRace;
            @map.ClipGroupEndRace = clipEndRace;
            ReleaseIfNonNull(oldClip);
            AddRefIfNonNull(clipEndRace);
        } else if (ty == MTClipTy::InGame) {
            auto oldClip = map.ClipGroupInGame;
            @map.ClipGroupInGame = clipInGame;
            ReleaseIfNonNull(oldClip);
            AddRefIfNonNull(clipInGame);
        } else {
            throw("Invalid MTClipTy");
        }
    }

    bool haveSomeClipsGoneMissing = false;

    void RenderWindow() {
        if (!haveSomeClipsGoneMissing) return;
        if (!IsInEditor) return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        UI::PushFont(g_BigFont);
        UI::SetNextWindowPos(g_screen.x / 2 - 100, g_screen.y / 2 - 100, UI::Cond::Appearing);
        if (UI::Begin("Missing Clips", UI::WindowFlags::NoCollapse | UI::WindowFlags::AlwaysAutoResize)) {
            UI::Text("Some MT clips have changed (did you \\$<\\$dd0Undo\\$>?)");
            UI::Text("Please either \\$<\\$i\\$f80Ignore\\$> or \\$<\\$8f0\\$iRestore\\$> the clips");
            if (UI::BeginTable("##MissingClips", 3, UI::TableFlags::SizingFixedFit)) {
                // longer at bottom so you can click the top button without moving the mouse
                DrawIgnoreOrRestoreFor(MTClipTy::Intro, "Intro", map);
                DrawIgnoreOrRestoreFor(MTClipTy::InGame, "In Game", map);
                DrawIgnoreOrRestoreFor(MTClipTy::Podium, "Podium", map);
                DrawIgnoreOrRestoreFor(MTClipTy::EndRace, "End Race", map);
                DrawIgnoreOrRestoreFor(MTClipTy::Ambiance, "Ambiance", map);
                UI::EndTable();
            }
        }
        UI::End();
        UI::PopFont();
    }

    void DrawIgnoreOrRestoreFor(MTClipTy ty, string name, CGameCtnChallenge@ map) {
        if (!HasClip(ty)) return;
        if (!IsClipChanged(ty, map)) return;
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::AlignTextToFramePadding();
        UI::Text(name);
        UI::TableNextColumn();
        if (UI::ButtonColored("Ignore##" + name, hueOrange)) {
            SetClipFromMap(ty, map);
            CheckForMissingClips(map);
        }
        UI::TableNextColumn();
        if (UI::ButtonColored("Restore##" + name, hueGreen)) {
            SetClipOnMap(ty, map);
            CheckForMissingClips(map);
        }
    }
}
