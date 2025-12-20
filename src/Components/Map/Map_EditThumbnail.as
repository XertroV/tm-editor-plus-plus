// can use PMT to edit/show thumbnail stuff
//
class MapThumbnailPropsTab : Tab {
    MapThumbnailPropsTab(TabGroup@ parent) {
        super(parent, "Thumbnail" + NewIndicator, Icons::MapO + Icons::Camera);
        // RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEnterEditor), this.tabName);
    }

    uint64 lastSetThumbTime = 0;
    uint64 lastAutoThumbTime = 0;

    void DrawInner() override {
        auto now = Time::Now;
        auto app = cast<CTrackMania>(GetApp());
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) {
            UI::Text("No editor.");
            return;
        }
        auto map = editor.Challenge;

        g_MapPropsTab.DrawMapThumbnailLine(map);

        UI::SeparatorText("Operations");

        if (UI::Button("Edit Map Thumbnail")) {
            editor.ButtonAdditionalToolsOnClick();
            startnew(function() {
                yield();
                cast<CTrackMania>(GetApp()).MenuManager.DialogEditorAdditionalMenu_OnEditSnapCamera();
            });
        }

        // set from editor camera
        if (UI::Button("Set Thumbnail From Current View")) {
            SetMapThumbnailFromCurrentView(editor);
            lastSetThumbTime = now;
        }
        UX::DrawTempStatusMsgWithinTimeout("\\$iUpdated!", now - lastSetThumbTime);

        // auto thumbnail
        if (UI::Button("Set E++'s Automatic Thumbnail")) {
            Editor::ImproveDefaultThumbnailLocation(true);
            lastAutoThumbTime = now;
        }
        UX::DrawTempStatusMsgWithinTimeout("\\$iUpdated!", now - lastAutoThumbTime);


        UI::SeparatorText("Saved Thumbnail Data");

        auto pmt = editor.PluginMapType;
        pmt.ThumbnailCameraFovY = UI::SliderFloat("Camera FOV Y", pmt.ThumbnailCameraFovY, 1.0, 180.0);
        UI::SameLine();
        if (UI::Button("Reset###thumb-fov-reset-btn")) pmt.ThumbnailCameraFovY = 90.0;

        // normalize to -PI to PI
        pmt.ThumbnailCameraRoll = (pmt.ThumbnailCameraRoll + PI) % TAU - PI;
        pmt.ThumbnailCameraHAngle = (pmt.ThumbnailCameraHAngle + PI) % TAU - PI;

        pmt.ThumbnailCameraHAngle = UI::SliderFloat("Camera H Angle", pmt.ThumbnailCameraHAngle, -PI, PI);
        pmt.ThumbnailCameraVAngle = UI::SliderFloat("Camera V Angle", pmt.ThumbnailCameraVAngle, -HALF_PI, HALF_PI);
        pmt.ThumbnailCameraRoll = UI::SliderFloat("Camera Roll", pmt.ThumbnailCameraRoll, -PI, PI);

        pmt.ThumbnailCameraPosition = UX::InputFloat3("Camera Position", pmt.ThumbnailCameraPosition, vec3(256, 256, 256));

    }




    void SetMapThumbnailFromCurrentView(CGameCtnEditorFree@ editor) {
        auto cam = editor.OrbitalCameraControl;
        auto pmt = editor.PluginMapType;
        pmt.ThumbnailCameraFovY = cam.m_ParamFov;
        pmt.ThumbnailCameraHAngle = cam.m_CurrentHAngle;
        pmt.ThumbnailCameraVAngle = cam.m_CurrentVAngle;
        pmt.ThumbnailCameraRoll = 0;
        pmt.ThumbnailCameraPosition = cam.Pos;
    }
}
