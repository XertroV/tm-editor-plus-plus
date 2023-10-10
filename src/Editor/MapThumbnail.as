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
    const string SAVE_MAP_THUMBNAIL_PATTERN = "48 8D 8F 78 01 00 00 E8 ?? ?? ?? ?? 44 8B 45 D8 48 8B 55 D0 48 8B 8F 78 01 00 00 E8 ?? ?? ?? ?? 48 8D 4D B8 E8 ?? ?? ?? ?? 48 85 DB 74 0E 83 43 10 FF 75 08 48 8B CB";
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
        // @saveMapThumbnailHook = Dev::Hook(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_POFFSET, 0, "Editor::_OnEditorSaveMapAfterThumbnailWritten");
    }

    void DisableMapThumbnailUpdate() {
        if (MapThumb::saveThumbPtr == 0 || MapThumb::patchActive) return;
        MapThumb::origBytes1 = Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET1, "90 90 90 90 90");
        MapThumb::origBytes2 = Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET2, "90 90 90 90 90");
        MapThumb::patchActive = true;
    }

    void EnableMapThumbnailUpdate() {
        if (MapThumb::saveThumbPtr == 0 || !MapThumb::patchActive) return;
        Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET1, MapThumb::origBytes1);
        Dev::Patch(MapThumb::saveThumbPtr + SAVE_MAP_THUMBNAIL_OFFSET2, MapThumb::origBytes2);
        MapThumb::patchActive = false;
    }

    void _OnEditorSaveMapAfterThumbnailWritten() {
        dev_trace("Thumbnail hook: thumbnail written");
    }
}


/*

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
