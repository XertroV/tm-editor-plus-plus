const uint16 O_MTAPI_PlaceHeight = GetOffset("CGameEditorMediaTrackerPluginAPI", "PopUpMessage") + 0x10;
const uint16 O_MTAPI_BlockCursor = GetOffset("CGameEditorMediaTrackerPluginAPI", "PopUpMessage") + 0x18;

class MT_CursorAndTriggerPlacementTab : Tab {
    MT_CursorAndTriggerPlacementTab(TabGroup@ p) {
        super(p, "Cursor & Trigger", "");
    }

    void DrawInner() override {
        UI::PushItemWidth(UI::GetContentRegionAvail().x / 2.);

        auto mteditor = cast<CGameEditorMediaTracker>(GetApp().Editor);
        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        UX::InputIntDevUint32("MT Trigger Placement Height (0 - 254)", api, O_MTAPI_PlaceHeight, 0, 0xFE);
        auto blockCursor = cast<CGameCursorBlock>(Dev::GetOffsetNod(api, O_MTAPI_BlockCursor));
        if (blockCursor !is null) {
            LabeledValue("Cursor Coord", blockCursor.Coord, true);
        }

        auto editorCam = GetMTOrbitalCam(api);
        if (editorCam !is null) {
            LabeledValue("Target Pos", editorCam.m_TargetedPosition);
            if (UI::Button("Set MT Placement to Camera Target")) {
                Dev::SetOffset(api, O_MTAPI_PlaceHeight, uint(editorCam.m_TargetedPosition.y / 8. + 8.));
            }
        }

        UI::PopItemWidth();
    }

    CGameControlCameraEditorOrbital@ GetMTOrbitalCam(CGameEditorMediaTrackerPluginAPI@ api) {
        auto fakeNod = Dev_GetOffsetNodSafe(api, 0x18);
        return cast<CGameControlCameraEditorOrbital>(Dev_GetOffsetNodSafe(fakeNod, 0x378));
    }
}


/**
 * 0x18 -> ptr
 * 0x378 -> CGameControlCameraEditorOrbital
 */
