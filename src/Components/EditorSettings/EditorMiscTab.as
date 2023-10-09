class EditorMiscTab : Tab {
    EditorMiscTab(TabGroup@ parent) {
        super(parent, "Editor Misc", Icons::Cog + Icons::Camera);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditorLoad), this.tabName);
    }

    void OnEditorLoad() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        UpdateEditorValuesSync(editor);

        if (S_DefaultToAirMode) {
            // editor.ButtonAirBlockModeOnClick();
            Editor::SetIsBlockAirModeActive(editor, true);
        }
    }

    void UpdateEditorValuesSync(CGameCtnEditorFree@ editor) {
        // note: this function must stay cheap due to call in DrawInner
        if (int(editor.ExperimentalFeatures.AutoSavePeriod) != S_AutosavePeriod && S_AutosavePeriod > 0) {
            editor.ExperimentalFeatures.AutoSavePeriod = uint(S_AutosavePeriod);
        }
        if (S_ControlBlockHelpers) {
            editor.HideBlockHelpers = S_HideBlockHelpers;
        }
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto mapSize = editor.Challenge.Size;
        auto maxXZ = 32. * Math::Max(float(mapSize.x), mapSize.z);

        UI::AlignTextToFramePadding();
        UI::Text("Camera:");

        auto occ = editor.OrbitalCameraControl;
        auto pmt = editor.PluginMapType;
        occ.m_ParamFov = UI::SliderFloat("FoV", occ.m_ParamFov, 5.0, 180, "%.1f");
        vec2 hv = vec2(pmt.CameraHAngle, pmt.CameraVAngle);
        hv = UX::SliderAngles2("H,V Angle", hv, -180, 180, "%.1f", vec2(0, -1.519));
        pmt.CameraHAngle = hv.x;
        pmt.CameraVAngle = hv.y;
        pmt.CameraToTargetDistance = UI::SliderFloat("Distance to Target", pmt.CameraToTargetDistance, 0, 1000);
        pmt.CameraTargetPosition = UX::SliderFloat3("Target Position", pmt.CameraTargetPosition, -1000, maxXZ + 1000., vec3(768, 70, 768));
        CopiableLabeledValue("Camera Position", pmt.CameraPosition.ToString());

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Spectators:");

        pmt.BleacherSpectatorsFillRatio = UI::InputFloat("BleacherSpectatorsFillRatio", pmt.BleacherSpectatorsFillRatio, .1);
        pmt.BleacherSpectatorsCount = UI::InputInt("BleacherSpectatorsCount", pmt.BleacherSpectatorsCount);

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Editor Features:");

        if (S_AutosavePeriod < 1) {
            S_AutosavePeriod = editor.ExperimentalFeatures.AutoSavePeriod;
        }
        S_AutosavePeriod = Math::Clamp(UI::InputInt("AutoSavePeriod", S_AutosavePeriod), 10, 3600 * 8);

        S_DefaultToAirMode = UI::Checkbox("Default to Air mode for blocks", S_DefaultToAirMode);

        editor.HideBlockHelpers = UI::Checkbox("Hide Block Helpers", editor.HideBlockHelpers);

        S_ControlBlockHelpers = UI::Checkbox("Save and persist Hide Block Helpers", S_ControlBlockHelpers);
        if (S_ControlBlockHelpers) {
            S_HideBlockHelpers = editor.HideBlockHelpers;
        }

        S_BlockEscape = UI::Checkbox("Block escape key from leaving the editor", S_BlockEscape);

        // set values in case they changed
        UpdateEditorValuesSync(editor);
    }
}
