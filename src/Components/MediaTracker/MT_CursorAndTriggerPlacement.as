const uint16 O_MTAPI_PlaceHeight = GetOffset("CGameEditorMediaTrackerPluginAPI", "PopUpMessage") + 0x10;
const uint16 O_MTAPI_BlockCursor = GetOffset("CGameEditorMediaTrackerPluginAPI", "PopUpMessage") + 0x18;

class MT_CursorAndTriggerPlacementTab : Tab {
    MT_CursorAndTriggerPlacementTab(TabGroup@ p) {
        super(p, "Cursor & Trigger", "");
    }

    void DrawInner() override {
        UI::Text("UNSTABLE FEATURE; NEEDS REWORK");
        if (true) return;
        auto app = GetApp();
        auto mteditor = cast<CGameEditorMediaTracker>(app.Editor);
        if (mteditor is null) return;

        UI::PushItemWidth(UI::GetContentRegionAvail().x / 2.);
        auto api = cast<CGameEditorMediaTrackerPluginAPI>(mteditor.PluginAPI);
        UX::InputIntDevUint32("MT Trigger Placement Height (0 - 254)", api, O_MTAPI_PlaceHeight, 0, 0xffFE);
//         auto blockCursor = cast<CGameCursorBlock>(Dev_GetOffsetNodSafe(api, O_MTAPI_BlockCursor));
//         if (blockCursor !is null) {
//             UI::SeparatorText("Cursor");
//             LabeledValue("Cursor Coord", blockCursor.Coord, true);
// #if SIG_DEVELOPER
//             CopiableLabeledPtr(blockCursor);
// #endif
//         }

        UI::SeparatorText("Camera");
//         auto editorCam = GetMTOrbitalCam(mteditor);
// #if SIG_DEVELOPER
//         CopiableLabeledPtr(editorCam);
// #endif
//         if (editorCam !is null) {
//             LabeledValue("Target Pos", editorCam.m_TargetedPosition);
//             if (UI::Button("Set MT Placement Y to Camera Target")) {
//                 Dev::SetOffset(api, O_MTAPI_PlaceHeight, uint(editorCam.m_TargetedPosition.y / 8. + 8.));
//             }
//         } else {
//             UI::Text("Could not get orbital cam");
//         }

        UI::PopItemWidth();
    }

    CGameControlCameraEditorOrbital@ GetMTOrbitalCam(CGameEditorMediaTracker@ mtEditor) {
        if (mtEditor is null) return null;
        auto ptr = Dev::GetOffsetUint64(mtEditor, 0x60);
        if (ptr == 0) return null;
        if (Dev_PointerLooksBad(ptr)) {
            warn("MT Editor orbital cam -- bad pointer: " + Text::FormatPointer(ptr));
            return null;
        }
        auto cam = DGameCamera(ptr);
        if (cam is null || cam.CurrentCamControl is null) return null;
        return cast<CGameControlCameraEditorOrbital>(cam.CurrentCamControl);
    }
}


/**
 * 0x18 -> ptr
 * 0x378 -> CGameControlCameraEditorOrbital
 */

 /*

-- unlocking MT cursor height. Patch 1:

Trackmania.exe.text+10879E0 - 48 83 EC 28           - sub rsp,28 { 40 }
Trackmania.exe.text+10879E4 - 48 8B D1              - mov rdx,rcx
Trackmania.exe.text+10879E7 - 48 8B 49 18           - mov rcx,[rcx+18]
Trackmania.exe.text+10879EB - 48 81 C1 98000000     - add rcx,00000098 { 152 }
Trackmania.exe.text+10879F2 - E8 C9CFFEFF           - call Trackmania.exe.text+10749C0
Trackmania.exe.text+10879F7 - B9 FFFFFF7F           - mov ecx,7FFFFFFF { was mov ecx,[rax+0000026C]
 }
Trackmania.exe.text+10879FC - 90                    - nop
Trackmania.exe.text+10879FD - 8B 82 38050000        - mov eax,[rdx+00000538]
Trackmania.exe.text+1087A03 - FF C9                 - dec ecx
Trackmania.exe.text+1087A05 - FF C0                 - inc eax
Trackmania.exe.text+1087A07 - 85 C0                 - test eax,eax
Trackmania.exe.text+1087A09 - 7F 0F                 - jg Trackmania.exe.text+1087A1A
Trackmania.exe.text+1087A0B - C7 82 38050000 00000000 - mov [rdx+00000538],00000000 { 0 }
Trackmania.exe.text+1087A15 - 48 83 C4 28           - add rsp,28 { 40 }
Trackmania.exe.text+1087A19 - C3                    - ret
Trackmania.exe.text+1087A1A - 3B C1                 - cmp eax,ecx
Trackmania.exe.text+1087A1C - 0F4D C1               - cmovge eax,ecx
Trackmania.exe.text+1087A1F - 89 82 38050000        - mov [rdx+00000538],eax
Trackmania.exe.text+1087A25 - 48 83 C4 28           - add rsp,28 { 40 }


Trackmania.exe.text+10879F7 - 8B 88 6C020000        - mov ecx,[rax+0000026C] { was mov ecx,[rax+0000026C]
 }


48 83 EC 28 48 8B D1 48 8B 49 18 48 81 C1 98 00 00 00 E8 C9 CF FE FF
8B 88 6C 02 00 00 8B 82 38 05 00 00 FF C9 FF C0 85 C0 7F 0F C7 82 38 05 00 00 00 00 00 00 48 83 C4 28 C3 3B C1 0F 4D C1

 */
