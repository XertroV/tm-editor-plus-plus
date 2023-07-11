class EditorMiscTab : Tab {
    EditorMiscTab(TabGroup@ parent) {
        super(parent, "Editor Misc", Icons::Cog + Icons::Camera);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        UI::AlignTextToFramePadding();
        UI::Text("Camera:");

        auto occ = editor.OrbitalCameraControl;
        auto pmt = editor.PluginMapType;
        occ.m_ParamFov = UI::SliderFloat("FoV", occ.m_ParamFov, 5.0, 180, "%.1f");
        vec2 hv = vec2(pmt.CameraHAngle, pmt.CameraVAngle);
        hv = UX::SliderAngles2("H,V Angle", hv, -180, 180, "%.1f", vec2(0, -1.519));
        pmt.CameraHAngle = hv.x;
        pmt.CameraVAngle = hv.y;
        pmt.CameraToTargetDistance = UI::SliderFloat("Distance to Target", pmt.CameraToTargetDistance);
        pmt.CameraTargetPosition = UX::SliderFloat3("Target Position", pmt.CameraTargetPosition, -500, 2500, vec3(768, 70, 768));
        pmt.CameraPosition = UX::SliderFloat3("Camera Position", -500, 2500, vec3(798, 100, 798));

        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Spectators:");

        pmt.BleacherSpectatorsFillRatio = UI::InputFloat("BleacherSpectatorsFillRatio", pmt.BleacherSpectatorsFillRatio, .1);
        pmt.BleacherSpectatorsCount = UI::InputInt("BleacherSpectatorsCount", pmt.BleacherSpectatorsCount);


        UI::Separator();

        UI::AlignTextToFramePadding();
        UI::Text("Helpers:");

        editor.HideBlockHelpers = UI::Checkbox("HideBlockHelpers", editor.HideBlockHelpers);
        // editor.ExperimentalFeatures.ShowNextMapElemParamIMGUIWindow
    }
}
