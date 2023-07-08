class EditorMiscTab : Tab {
    EditorMiscTab(TabGroup@ parent) {
        super(parent, "Editor Camera", Icons::Cog + Icons::Camera);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto occ = editor.OrbitalCameraControl;
        auto pmt = editor.PluginMapType;
        occ.m_ParamFov = UI::SliderFloat("FoV", occ.m_ParamFov, 5.0, 180, "%.1f");
        vec2 hv = vec2(pmt.CameraHAngle, pmt.CameraVAngle);
        hv = UX::SliderAngles2("H,V Angle", hv, -180, 180, "%.1f", vec2(0, -1.519));
        pmt.CameraHAngle = hv.x;
        pmt.CameraVAngle = hv.y;

        pmt.BleacherSpectatorsFillRatio = UI::InputFloat("BleacherSpectatorsFillRatio", pmt.BleacherSpectatorsFillRatio, .1);
        pmt.BleacherSpectatorsCount = UI::InputInt("BleacherSpectatorsCount", pmt.BleacherSpectatorsCount);
    }
}
