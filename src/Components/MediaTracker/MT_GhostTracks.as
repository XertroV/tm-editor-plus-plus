class MT_GhostTracks : Tab {
    MT_GhostTracks(TabGroup@ p) {
        super(p, "Ghost Tracks", Icons::SnapchatGhost);
        // RegisterOnMTEditorLoadCallback(CoroutineFunc(this.OnMTEditorLoad), "GhostTracks");
    }

    // void OnMTEditorLoad() {
    //     startnew(CoroutineFunc(MTEditorWatchLoop));
    // }

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

        auto pluginApi = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        if (pluginApi is null) {
            UI::Text("Plugin API null!?");
            return;
        }

        auto clip = pluginApi.Clip;
        if (clip is null) {
            UI::Text("clip is null!?");
            return;
        }

        DrawGhostTracks(clip);
    }

    void DrawGhostTracks(CGameCtnMediaClip@ clip) {
        UI::Text("Clip: " + clip.Name);
        if (UI::Button("Randomize Colors & Enable Forced Hue")) {
            RandomizeColorsAndEnableForcedHue(clip);
            Notify("Randomized ghost colors and enabled forced heu. Also set trail intensity to 1.0");
        }
        // UI::Indent();
        for (uint i = 0; i < clip.Tracks.Length; i++) {
            auto item = clip.Tracks[i];
            DrawGhostTrack(item);
        }
        // UI::Unindent();
    }

    void DrawGhostTrack(CGameCtnMediaTrack@ track) {
        if (track is null || track.Blocks.Length == 0) return;
        auto b = cast<CGameCtnMediaBlockEntity>(track.Blocks[0]);
        if (b is null) return;
        auto trackPtr = Dev_GetPointerForNod(track);
        if (UI::TreeNode(track.Name + "##" + trackPtr)) {
            UI::PushID(tostring(trackPtr));
            for (uint i = 0; i < track.Blocks.Length; i++) {
                @b = cast<CGameCtnMediaBlockEntity>(track.Blocks[i]);
                if (b is null) continue;
                DrawGhostBlock(i, DGameCtnMediaBlockEntity(b), trackPtr);
            }
            UI::PopID();
            UI::TreePop();
        }
    }

    void DrawGhostBlock(uint ix, DGameCtnMediaBlockEntity@ block, uint64 trackPtr) {
        auto name = "Block " + ix + ".##" + trackPtr;
        if (UI::TreeNode(name)) {
            UI::PushID(name);
            CopiableLabeledValue("GhostName", block.GhostName);
            block.ForceHue = UI::Checkbox("Force Hue", block.ForceHue);
            block.StartOffset = UI::InputFloat("Start Offset", block.StartOffset);
            // CopiableLabeledValue("Start Offset", tostring(block.StartOffset));
            auto keys = block.Keys;

            auto nbKeys = keys.Length;
            UI::Text("Keys: " + nbKeys);
            // UI::Indent();
            for (uint i = 0; i < nbKeys; i++) {
                if (UI::TreeNode("Key " + i, UI::TreeNodeFlags::DefaultOpen)) {
                    auto k = keys.GetKey(i);
                    CopiableLabeledValue("Time", tostring(k.StartTime));
                    k.Lights = Math::Clamp(UI::InputInt("Lights", k.Lights), 0, 2);
                    k.TrailColor = UI::InputColor3("Trail Color", k.TrailColor);
                    k.TrailIntensity = UI::InputFloat("Trail Intensity", k.TrailIntensity);
                    k.SelfIllumIntensity = UI::InputFloat("SelfIllum Intensity", k.SelfIllumIntensity);
                    UI::TreePop();
                }
            }
            // UI::Unindent();
            UI::PopID();
            UI::TreePop();
        }
    }

    void RandomizeColorsAndEnableForcedHue(CGameCtnMediaClip@ clip) {
        for (uint i = 0; i < clip.Tracks.Length; i++) {
            auto track = clip.Tracks[i];
            for (uint j = 0; j < track.Blocks.Length; j++) {
                auto block = cast<CGameCtnMediaBlockEntity>(track.Blocks[j]);
                if (block is null) continue;
                RandomizeColorsAndEnableForcedHue(DGameCtnMediaBlockEntity(block));
            }
        }
    }

    void RandomizeColorsAndEnableForcedHue(DGameCtnMediaBlockEntity@ block) {
        block.ForceHue = true;
        auto keys = block.Keys;
        auto nbKeys = keys.Length;
        for (uint i = 0; i < nbKeys; i++) {
            auto k = keys.GetKey(i);
            k.TrailIntensity = 1.0;
            k.TrailColor = vec3(Rand01(), Rand01(), Rand01()).Normalized();
        }
    }
}
