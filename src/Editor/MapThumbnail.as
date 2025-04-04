namespace Editor {
    const uint O_MAP_THUMBNAIL_BUF = GetOffset("CGameCtnChallenge", "ObjectiveTextAuthor") - 0x10;

    MemoryBuffer@ ReadMapThumbnailRaw(CGameCtnChallenge@ map) {
        if (map is null) return null;
        auto bufPtr = Dev::GetOffsetUint64(map, O_MAP_THUMBNAIL_BUF);
        auto thumbBytes = Dev::GetOffsetUint32(map, O_MAP_THUMBNAIL_BUF + 0x8);
        auto buf = MemoryBuffer(thumbBytes);
        dev_trace("thumb buf at end? " + buf.AtEnd());
        auto rawBytes = Dev::ReadCString(bufPtr, thumbBytes);
        dev_trace("Read bytes " + rawBytes.Length);
        buf.Write(rawBytes);
        dev_trace("thumb buf at end? " + buf.AtEnd());
        dev_trace("Buf size: " + buf.GetSize());
        buf.Seek(0);
        return buf;
    }

    Dev::HookInfo@ saveMapThumbnailHook;
    // loads ptr to thumbnail buf, calls update thumbnail, loads a stack pointer, calls something else, then some tests and jmps
    // const string SAVE_MAP_THUMBNAIL_PATTERN = "48 8D 8F 78 01 00 00 E8 ?? ?? ?? ?? 44 8B 45 D8 48 8B 55 D0 48 8B 8F 78 01 00 00 E8 ?? ?? ?? ?? 48 8D 4D B8 E8 ?? ?? ?? ?? 48 85 DB 74 0E 83 43 10 FF 75 08 48 8B CB";
    // when overwriting thumbnail, it is the first code to access the thumbnail img buf at Map + 0x178.
    //                                                  88                                                          88
    const string SAVE_MAP_THUMBNAIL_PATTERN = "48 ?? ?? ?? 01 00 00 E8 ?? ?? ?? ?? 44 8B 45 ?? 48 8B 55 ?? 48 ?? ?? ?? 01 00 00 E8";
    const uint16 SAVE_MAP_THUMBNAIL_OFFSET1 = 7; // overwrites a call so no padding
    const uint16 SAVE_MAP_THUMBNAIL_OFFSET2 = 27; // overwrites a call so no padding

    namespace MapThumb {
        uint64 saveThumbPtr = 0;
        string origBytes1;
        string origBytes2;
        bool patchActive = false;
    }
    void OnPluginLoadSetUpMapThumbnailHook() {
        if (saveMapThumbnailHook !is null) return;
        MapThumb::saveThumbPtr = Dev::FindPattern(SAVE_MAP_THUMBNAIL_PATTERN);
        if (MapThumb::saveThumbPtr == 0) {
            NotifyWarning("Failed to find map thumbnail save code (for locking map thumbnail)");
            return;
        }
        // @saveMapThumbnailHook = Dev::Hook(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_POFFSET, 0, "Editor::_OnEditorSaveMapAfterThumbnailWritten");
    }

    void DisableMapThumbnailUpdate() {
        if (MapThumb::saveThumbPtr == 0 || MapThumb::patchActive) return;
        MapThumb::origBytes1 = Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET1, "90 90 90 90 90");
        MapThumb::origBytes2 = Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET2, "90 90 90 90 90");
        MapThumb::patchActive = true;
        dev_trace("Thumbnail hook: disabled thumbnail update");
    }

    void EnableMapThumbnailUpdate() {
        if (MapThumb::saveThumbPtr == 0 || !MapThumb::patchActive) return;
        Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET1, MapThumb::origBytes1);
        Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET2, MapThumb::origBytes2);
        MapThumb::patchActive = false;
        dev_trace("Thumbnail hook: enabled thumbnail update");
    }

    void _OnEditorSaveMapAfterThumbnailWritten() {
        dev_trace("Thumbnail hook: thumbnail written");
    }

    void ImproveDefaultThumbnailLocation_OnReturnFromPg() {
        dev_trace("ImproveDefaultThumbnailLocation_OnReturnFromPg called");
        startnew(ImproveDefaultThumbnailLocation_AfterPgAsync);
    }

    void ImproveDefaultThumbnailLocation_AfterPgAsync() {
        yield();
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        if (editor.PluginMapType.ValidationStatus == CGameEditorPluginMapMapType::EValidationStatus::Validated) {
            ImproveDefaultThumbnailLocation();
        } else {
            dev_trace("Map not validated, skipping thumbnail location improvement");
        }
    }

    void ImproveDefaultThumbnailLocation(bool force = false) {
        dev_trace("ImproveDefaultThumbnailLocation called");
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        bool isDefaultThumbnailLoc = pmt.ThumbnailCameraFovY == 90.0
            && pmt.ThumbnailCameraRoll == 0.0
            && 0.785 == Math::Round(pmt.ThumbnailCameraHAngle, 3)
            && 0.785 == Math::Round(pmt.ThumbnailCameraVAngle, 3);
        // if it's the default location, let's pick a better location
        if (!isDefaultThumbnailLoc && !force) return;
        // some nice angles with sun behind us
        float newCamHAngle = 1.235;
        float newCamVAngle = 0.666;
        auto cache = GetMapCache();
        auto mapObjsMinMax = cache.objsRoot.GetPointsMinMax();
        if (mapObjsMinMax is null) return;
        auto mapMin = mapObjsMinMax[0];
        auto mapMax = mapObjsMinMax[1];
        if (mapMin.x > mapMax.x) {
            // no objects?!
            dev_warn("No objects in map to set thumbnail location");
            return;
        }
        auto mapCenter = (mapMin + mapMax + vec3(32, 8, 32)) / 2;
        auto mapSize = mapMax - mapMin;
        auto mapDiag = mapSize.Length();
        // this is inspired but SetEditorOrbitalTarget but I just stuck some constants
        // in during debug and it worked out so whatever. Probably a bad idea to copy this code.
        auto camMat = mat4::Translate(mapCenter)
            * mat4::Rotate(newCamHAngle - HALF_PI + .5, DOWN)
            * mat4::Rotate(HALF_PI - newCamVAngle - .5, BACKWARD)
            * mat4::Translate(vec3(mapDiag * -.8, 0.0f, 0.0f))
            ;
        pmt.ThumbnailCameraPosition = (camMat * vec3(0.0f)).xyz;
        pmt.ThumbnailCameraHAngle = newCamHAngle;
        pmt.ThumbnailCameraVAngle = newCamVAngle;
        pmt.ThumbnailCameraFovY = 90.0;
        pmt.ThumbnailCameraRoll = 0.0;
    }
}


/*

v get thumb buf ptr                                         v get thumb buf ptr
48 ?? ?? 78 01 00 00 E8 ?? ?? ?? ?? 44 8B 45 ?? 48 8B 55 ?? 48 ?? ?? 78 01 00 00 E8 // ?? ?? ?? ??
                     ^ call         ^ get stack stuff                            ^ call

48 8D 8E 78 01 00 00
E8 78 3A 4E FF
44 8B 45 E0
48 8B 55 D8
48 8B 8E 78 01 00 00
E8 C4 57 B2 00


Trackmania.exe.text+D5093C - 48 8D 8E 78010000     - lea rcx,[rsi+00000178]
Trackmania.exe.text+D50943 - E8 783A4EFF           - call Trackmania.exe.text+2343C0
Trackmania.exe.text+D50948 - 44 8B 45 E0           - mov r8d,[rbp-20]
Trackmania.exe.text+D5094C - 48 8B 55 D8           - mov rdx,[rbp-28]
Trackmania.exe.text+D50950 - 48 8B 8E 78010000     - mov rcx,[rsi+00000178]
Trackmania.exe.text+D50957 - E8 C457B200           - call Trackmania.exe.text+1876120
Trackmania.exe.text+D5095C - 48 8D 4D C0           - lea rcx,[rbp-40]
Trackmania.exe.text+D50960 - E8 3B3C3CFF           - call Trackmania.exe.text+1145A0
Trackmania.exe.text+D50965 - 48 85 DB              - test rbx,rbx
Trackmania.exe.text+D50968 - 74 0E                 - je Trackmania.exe.text+D50978
Trackmania.exe.text+D5096A - 83 43 10 FF           - add dword ptr [rbx+10],-01 { 255 }
Trackmania.exe.text+D5096E - 75 08                 - jne Trackmania.exe.text+D50978
Trackmania.exe.text+D50970 - 48 8B CB              - mov rcx,rbx
Trackmania.exe.text+D50973 - E8 C8F752FF           - call Trackmania.exe.text+280140
Trackmania.exe.text+D50978 - 83 47 10 FF           - add dword ptr [rdi+10],-01 { 255 }






-- main part we're matching, but we want to nop the call at +27 = +0x1b, so should probably have the pattern match the E8 (call, last byte) at least.
48 ?? ?? 78 01 00 00 E8 ?? ?? ?? ?? 48 8D 4D ?? E8 ?? ?? ?? ?? 48 85 DB 74 0E
-- this part feels reliable
83 43 10 FF 75 08 48 8B CB E8



48 ?? ?? 78 01 00 00
E8 ?? ?? ?? ??
48 8D 4D ??
E8 ?? ?? ?? ??
48 85 DB
74 0E
83 43 10 FF
75 08
48 8B CB

Trackmania.exe.text+D50950 - 48 8B 8E 78010000     - mov rcx,[rsi+00000178]
Trackmania.exe.text+D50957 - E8 C457B200           - call Trackmania.exe.text+1876120
Trackmania.exe.text+D5095C - 48 8D 4D C0           - lea rcx,[rbp-40]
Trackmania.exe.text+D50960 - E8 3B3C3CFF           - call Trackmania.exe.text+1145A0
Trackmania.exe.text+D50965 - 48 85 DB              - test rbx,rbx
Trackmania.exe.text+D50968 - 74 0E                 - je Trackmania.exe.text+D50978
Trackmania.exe.text+D5096A - 83 43 10 FF           - add dword ptr [rbx+10],-01 { 255 }
Trackmania.exe.text+D5096E - 75 08                 - jne Trackmania.exe.text+D50978
Trackmania.exe.text+D50970 - 48 8B CB              - mov rcx,rbx


OLD:
Trackmania.exe+D2EA1F - 48 8B 8F 78010000
Trackmania.exe+D2EA26 - E8 252EB300
Trackmania.exe+D2EA2B - 48 8D 4D B8
Trackmania.exe+D2EA2F - E8 7C373EFF
Trackmania.exe+D2EA34 - 48 85 DB
Trackmania.exe+D2EA37 - 74 0E
Trackmania.exe+D2EA39 - 83 43 10 FF
Trackmania.exe+D2EA3D - 75 08
Trackmania.exe+D2EA3F - 48 8B CB

*/
