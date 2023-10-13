[Setting hidden]
bool S_AutoUnlockCamera = false;

class EditorMiscTab : Tab {
    EditorMiscTab(TabGroup@ parent) {
        super(parent, "Editor Misc", Icons::Cog + Icons::Camera);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditorLoad), this.tabName);
        startnew(CoroutineFunc(this.WatchForVarResets));
    }

    void WatchForVarResets() {
        while (true) {
            yield();
            if (!IsInEditor) continue;
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            CheckSetHideBlockHelpers(editor);
        }
    }

    void CheckSetHideBlockHelpers(CGameCtnEditorFree@ editor) {
        if (S_ControlBlockHelpers && S_HideBlockHelpers != editor.HideBlockHelpers) {
            editor.HideBlockHelpers = S_HideBlockHelpers;
        }
    }

    bool _cameraUnlocked = false;

    void OnEditorLoad() {
        _cameraUnlocked = false;
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
        if (S_AutoUnlockCamera && !_cameraUnlocked) {
            UnlockCamera(editor.OrbitalCameraControl);
        }
    }

    void UnlockCamera(CGameControlCameraEditorOrbital@ occ) {
        Editor::UnlockCamera(occ);
        _cameraUnlocked = true;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto mapSize = editor.Challenge.Size;
        auto maxXZ = 32. * Math::Max(float(mapSize.x), mapSize.z);

        UI::AlignTextToFramePadding();
        UI::Text("Camera:");

        auto occ = editor.OrbitalCameraControl;

        auto occ_MinXZ = Dev::GetOffsetVec2(occ, GetOffset(occ, "m_TargetedPosition") + 0x18);
        auto occ_MaxXZ = Dev::GetOffsetVec2(occ, GetOffset(occ, "m_TargetedPosition") + 0x20);
        auto occ_YBounds = Dev::GetOffsetVec2(occ, GetOffset(occ, "m_TargetedPosition") + 0x28);

        UI::AlignTextToFramePadding();
        if (!_cameraUnlocked) {
            UI::Text("Camera Bounds: " + FormatX::Vec3(vec3(occ_MinXZ.x, occ_YBounds.x, occ_MinXZ.y)) + " to " + FormatX::Vec3(vec3(occ_MaxXZ.x, occ_YBounds.y, occ_MaxXZ.y)));
            UI::SameLine();
            if (UI::Button("Unlock Camera")) {
                UnlockCamera(occ);
            }
        } else {
            UI::Text("\\$8f8Camera Unlocked.");
            AddSimpleTooltip("Max bounds, +- 90 million in each axis");
        }
        UI::SameLine();
        S_AutoUnlockCamera = UI::Checkbox("Autounlock?##occ", S_AutoUnlockCamera);

        auto pmt = editor.PluginMapType;
        occ.m_ParamFov = UI::SliderFloat("FoV", occ.m_ParamFov, 5.0, 180, "%.1f");
        vec2 hv = vec2(pmt.CameraHAngle, pmt.CameraVAngle);
        hv = UX::SliderAngles2("H,V Angle", hv, -180, 180, "%.1f", vec2(0, -1.519));
        pmt.CameraHAngle = hv.x;
        pmt.CameraVAngle = hv.y;
        auto targetDist = editor.OrbitalCameraControl.m_CameraToTargetDistance;
        targetDist = UI::SliderFloat("Distance to Target", targetDist, 0, 1000);
        auto targetPos = editor.OrbitalCameraControl.m_TargetedPosition;
        targetPos = UX::SliderFloat3("Target Position", targetPos, -1000, maxXZ + 1000., vec3(768, 70, 768));

        pmt.CameraTargetPosition.x = targetPos.x;
        pmt.CameraTargetPosition.z = targetPos.z;
        pmt.CameraToTargetDistance = targetDist;
        editor.OrbitalCameraControl.m_TargetedPosition = targetPos;
        editor.OrbitalCameraControl.m_CameraToTargetDistance = targetDist;

        CopiableLabeledValue("Camera Position", editor.OrbitalCameraControl.Pos.ToString());
        // editor.OrbitalCameraControl.m_TargetedPosition = pmt.CameraTargetPosition;

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

        CheckSetHideBlockHelpers(editor);
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
