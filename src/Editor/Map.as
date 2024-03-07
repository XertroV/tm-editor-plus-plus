namespace Editor {
    void SetMapPlayerModel(CGameCtnChallenge@ map, uint playerModel, uint playerModelAuthor, uint playerModelCollection) {
        Dev::SetOffset(map, O_MAP_PLAYERMODEL_MWID_OFFSET, playerModel);
        // ~~author doesn't seem necessary
        Dev::SetOffset(map, O_MAP_PLAYERMODEL_AUTHOR_MWID_OFFSET, playerModelAuthor);
        Dev::SetOffset(map, O_MAP_PLAYERMODEL_COLLECTION_MWID_OFFSET, playerModelCollection);
        // todo: is collection necessary for mp4 cars?
    }

    // returns model id, model author id, and model collection id
    nat3 GetMapPlayerModel(CGameCtnChallenge@ map) {
        uint playerModel = Dev::GetOffsetUint32(map, O_MAP_PLAYERMODEL_MWID_OFFSET);
        uint playerModelAuthor = Dev::GetOffsetUint32(map, O_MAP_PLAYERMODEL_AUTHOR_MWID_OFFSET);
        uint playerModelCollection = Dev::GetOffsetUint32(map, O_MAP_PLAYERMODEL_COLLECTION_MWID_OFFSET);
        return nat3(playerModel, playerModelAuthor, playerModelCollection);
    }

    const uint16 ChallengeSizeOffset = GetOffset("CGameCtnChallenge", "Size");

    // works for Y only!! will crash otherwise
    void _SetMapSize(CGameCtnChallenge@ map, nat3 &in newSize) {
        Log::Trace('Setting map newsize: ' + newSize.ToString());
        Dev::SetOffset(map, ChallengeSizeOffset, newSize);
        Log::Trace('set offset');
        CacheMapBounds();
    }

    vec3 GetMapSize(CGameCtnChallenge@ map) {
        return CoordToPos(map.Size);
    }

    vec3 GetMapMidpoint(CGameCtnChallenge@ map) {
        return CoordToPos(map.Size) / 2;
    }

    // this works for height and doesn't crash stuff
    void SetNewMapHeight(CGameCtnChallenge@ map, uint newHeight) {
        _SetMapSize(map, nat3(map.Size.x, newHeight, map.Size.z));
    }

    // measured in partitions of a block; 3,1,3 => triggers are 1/3 w, 1/1 h, 1/3 d of a block
    nat3 GetMTTriggerSize(CGameCtnChallenge@ map) {
        return Dev::GetOffsetNat3(map, O_MAP_MTSIZE_OFFSET);
    }
    // measured in partitions of a block; 3,1,3 => triggers are 1/3 w, 1/1 h, 1/3 d of a block
    nat3 GetOffzoneTriggerSize(CGameCtnChallenge@ map) {
        return Dev::GetOffsetNat3(map, O_MAP_OFFZONE_SIZE_OFFSET);
    }

    // measured in partitions of a block; 3,1,3 => triggers are 1/3 w, 1/1 h, 1/3 d of a block
    void SetMTTriggerSize(CGameCtnChallenge@ map, nat3 size) {
        Dev::SetOffset(map, O_MAP_MTSIZE_OFFSET, size);
    }
    // measured in partitions of a block; 3,1,3 => triggers are 1/3 w, 1/1 h, 1/3 d of a block
    void SetOffzoneTriggerSize(CGameCtnChallenge@ map, nat3 size) {
        Dev::SetOffset(map, O_MAP_OFFZONE_SIZE_OFFSET, size);
    }

    bool SaveMapSameName(CGameCtnEditorFree@ editor) {
        string fileName = editor.Challenge.MapInfo.FileName;
        _restoreMapName = editor.Challenge.MapName;
        if (fileName.Length == 0) {
            NotifyWarning("Map must be saved, first.");
            return false;
        }
        editor.PluginMapType.SaveMap(fileName);
        startnew(_RestoreMapName);
        Log::Trace('saved map');
        return true;
    }

    string _restoreMapName;
    // set after calling SaveMapSameName
    void _RestoreMapName() {
        yield();
        if (_restoreMapName.Length == 0) return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.Challenge.MapName = _restoreMapName;
        Log::Trace('restored map name: ' + _restoreMapName);
    }

    void NoSaveAndReloadMap() {
        auto app = cast<CTrackMania>(GetApp());
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        string fileName = editor.Challenge.MapInfo.FileName;
        if (fileName.Length == 0) {
            NotifyWarning("Map must be saved, first.");
            return;
        }
        auto currCam = GetCurrentCamState(editor);
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        app.BackToMainMenu();
        Log::Trace('back to menu');
        AwaitReturnToMenu();
        sleep(100);
        app.ManiaTitleControlScriptAPI.EditMap(fileName, "", "");
        AwaitEditor();
        SetCamAnimationGoTo(currCam);
        @editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    }

    void SaveAndReloadMap() {
        Log::Trace('save and reload map');
        auto app = cast<CTrackMania>(GetApp());
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (!SaveMapSameName(editor)) {
            NotifyWarning("Map must be saved, first. Please save and reload manually!");
            return;
        }
        auto currCam = GetCurrentCamState(editor);
        string fileName = editor.Challenge.MapInfo.FileName;
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        app.BackToMainMenu();
        Log::Trace('back to menu');
        AwaitReturnToMenu();
        app.ManiaTitleControlScriptAPI.EditMap(fileName, "", "");
        AwaitEditor();
        startnew(_RestoreMapName);
        SetCamAnimationGoTo(currCam);
    }

    /// unused and unmaintained
    void SaveAndReloadMapWithRefreshMap(const string &in refreshMapName) {
        Log::Trace('save and reload map');
        auto app = cast<CTrackMania>(GetApp());
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        string fileName = editor.Challenge.MapInfo.FileName;
        if (!SaveMapSameName(editor)) {
            NotifyWarning("Map must be saved, first.");
            return;
        }
        auto currCam = GetCurrentCamState(editor);
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        app.BackToMainMenu();
        Log::Trace('back to menu');
        AwaitReturnToMenu();
        Log::Trace("edit map 2");
        sleep(1000);
        app.ManiaTitleControlScriptAPI.EditMap(refreshMapName, "", "");
        while (app.Editor is null) yield();
        @editor = cast<CGameCtnEditorFree>(app.Editor);
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        sleep(1000);
        Log::Trace('back to menu');

        app.BackToMainMenu();
        sleep(1000);
        AwaitReturnToMenu();
        app.ManiaTitleControlScriptAPI.EditMap(fileName, "", "");
        AwaitEditor();
        SetCamAnimationGoTo(currCam);
    }


    string RelativeMapPath(CSystemFidFile@ mapFid) {
        print(mapFid.FileName);
        return RelativeMapFolderPath(mapFid.ParentFolder) + mapFid.FileName;
    }

    // includes trailing `\`
    string RelativeMapFolderPath(CSystemFidsFolder@ folder) {
        print(folder.DirName);
        // check for root of relative path
        if (folder.DirName == "Maps" && cast<CSystemFidsDrive>(folder.ParentFolder) !is null) {
            return "";
        }
        return RelativeMapFolderPath(folder.ParentFolder) + folder.DirName + "/";
    }

    CHmsLightMapCache@ GetMapLightmapCache(CGameCtnChallenge@ map) {
        auto midNod = Dev_GetOffsetNodSafe(map, O_MAP_LIGHTMAP_STRUCT);
        return cast<CHmsLightMapCache>(Dev_GetOffsetNodSafe(midNod, 0x0));
    }

    string GetMapBuildInfo(CGameCtnChallenge@ map) {
        return Dev::GetOffsetString(map, O_MAP_BUILDINFO_STR);
    }

    void SetMapBuildInfo(CGameCtnChallenge@ map, const string &in newBuildInfo) {
        Dev::SetOffset(map, O_MAP_BUILDINFO_STR, newBuildInfo);
        // Editor::MarkRefreshUnsafe();
    }

    // long pattern but lots of matches otherwise
    const string PATTERN_COPY_BUILD_STRING_SAVING_MAP = "48 83 EC 38 89 51 74 48 8D 05 ?? ?? ?? ?? 48 83 C1 78 48 8D 54 24 20 80 3D ?? ?? ?? ?? 00 48 0F 45 05 ?? ?? ?? ?? 48 89 44 24 20 8B 05 ?? ?? ?? ?? 89 44 24 28 0F 28 44 24 20 66 0F 7F 44 24 20 E8 ?? ?? ?? ?? 48 83 C4 38";
    uint64 g_EditorWritesMapBuildInfoPtr = 0;

    uint64 GetEditorWritesMapBuildInfoPtr() {
        if (g_EditorWritesMapBuildInfoPtr == 0) {
            g_EditorWritesMapBuildInfoPtr = Dev::FindPattern(PATTERN_COPY_BUILD_STRING_SAVING_MAP);
        }
        return g_EditorWritesMapBuildInfoPtr;
    }

    void SetEditorWritesMapBuildInfo(const string &in newBuildInfo) {
        auto ptr = GetEditorWritesMapBuildInfoPtr();
        if (ptr > Dev::BaseAddress() && ptr < Dev::BaseAddressEnd()) {
            auto offset = Dev::ReadInt32(ptr + 10);
            auto fakeNod = Dev_GetNodFromPointer(ptr + 14 + offset);
            Dev::SetOffset(fakeNod, 0x0, newBuildInfo);
        }
    }

    string GetEditorWritesMapBuildInfo() {
        auto ptr = GetEditorWritesMapBuildInfoPtr();
        if (ptr > Dev::BaseAddress() && ptr < Dev::BaseAddressEnd()) {
            auto offset = Dev::ReadInt32(ptr + 10);
            auto fakeNod = Dev_GetNodFromPointer(ptr + 14 + offset);
            return Dev::GetOffsetString(fakeNod, 0x0);
        }
        return "";
    }

    // save and reload map to make this safe
    void SetModPackDesc(CGameCtnChallenge@ map, CSystemPackDesc@ newDesc) {
        auto priorModPack = map.ModPackDesc;
        newDesc.MwAddRef();
        Dev::SetOffset(map, O_MAP_MODPACK_DESC_OFFSET, newDesc);
        if (priorModPack !is null) {
            priorModPack.MwRelease();
        }
    }
}

/*

Trackmania.exe.text+B17A0E - 48 0F45 05 2A464B01   - cmovne rax,[Trackmania.exe+1FCD040] { (1C60CD5AE41) }

48 0F 45 05 2A 46 4B 01 48 89 44 24 20 8B 05 2B 46 4B 01 89 44 24 28
48 0F 45 05 ?? ?? ?? ?? 48 89 44 24 20 8B 05 ?? ?? ?? ?? 89 44 24 28 0F 28 44 24 20 66 0F 7F 44 24 20 E8

48 83 EC 38 89 51 74 48 8D 05 ?? ?? ?? ?? 48 83 C1 78 48 8D 54 24 20 80 3D ?? ?? ?? ?? 00 48 0F 45 05 ?? ?? ?? ?? 48 89 44 24 20 8B 05 ?? ?? ?? ?? 89 44 24 28 0F 28 44 24 20 66 0F 7F 44 24 20 E8 ?? ?? ?? ?? 48 83 C4 38

ptr + 14 + int(2A464B01)

*/
