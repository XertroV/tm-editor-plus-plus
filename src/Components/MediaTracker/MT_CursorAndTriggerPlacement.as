const uint16 O_MTAPI_PlaceHeight = GetOffset("CGameEditorMediaTrackerPluginAPI", "PopUpMessage") + 0x10;
const uint16 O_MTAPI_BlockCursor = GetOffset("CGameEditorMediaTrackerPluginAPI", "PopUpMessage") + 0x18;

class MT_CursorAndTriggerPlacementTab : Tab {
    MT_CursorAndTriggerPlacementTab(TabGroup@ p) {
        super(p, "Cursor & Trigger", "");
    }

    void DrawInner() override {
        auto app = GetApp();
        auto mteditor = cast<CGameEditorMediaTracker>(app.Editor);
        if (mteditor is null) return null;

        UI::PushItemWidth(UI::GetContentRegionAvail().x / 2.);
        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        UX::InputIntDevUint32("MT Trigger Placement Height (0 - 254)", api, O_MTAPI_PlaceHeight, 0, 0xFE);
        auto blockCursor = cast<CGameCursorBlock>(Dev::GetOffsetNod(api, O_MTAPI_BlockCursor));
        if (blockCursor !is null) {
            LabeledValue("Cursor Coord", blockCursor.Coord, true);
        }

        auto editorCam = GetMTOrbitalCam(mteditor);
        if (editorCam !is null) {
            LabeledValue("Target Pos", editorCam.m_TargetedPosition);
            if (UI::Button("Set MT Placement to Camera Target")) {
                Dev::SetOffset(api, O_MTAPI_PlaceHeight, uint(editorCam.m_TargetedPosition.y / 8. + 8.));
            }
        } else {
            UI::Text("Could not get orbital cam");
        }

        UI::PopItemWidth();
    }

    CGameControlCameraEditorOrbital@ GetMTOrbitalCam(CGameEditorMediaTracker@ mtEditor) {
        if (mtEditor is null) return null;
        auto cam = DGameCamera(Dev::GetOffsetUint64(mtEditor, 0x60));
        return cast<CGameControlCameraEditorOrbital>(cam.CurrentCamControl);
    }
}


/**
 * 0x18 -> ptr
 * 0x378 -> CGameControlCameraEditorOrbital
 */
