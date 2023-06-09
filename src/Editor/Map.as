namespace Editor {
    const uint16 ChallengeSizeOffset = GetOffset("CGameCtnChallenge", "Size");

    // works for Y only!! will crash otherwise
    void _SetMapSize(CGameCtnChallenge@ map, nat3 &in newSize) {
        Log::Trace('Setting map newsize: ' + newSize.ToString());
        Dev::SetOffset(map, ChallengeSizeOffset, newSize);
        Log::Trace('set offset');
    }

    // this works for height and doesn't crash stuff
    void SetNewMapHeight(CGameCtnChallenge@ map, uint newHeight) {
        _SetMapSize(map, nat3(map.Size.x, newHeight, map.Size.z));
    }

    bool SaveMapSameName(CGameCtnEditorFree@ editor) {
        string fileName = editor.Challenge.MapInfo.FileName;
        if (fileName.Length == 0) {
            NotifyWarning("Map must be saved, first.");
            return false;
        }
        editor.PluginMapType.SaveMap(fileName);
        Log::Trace('saved map');
        return true;
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

    }

    void SaveAndReloadMap() {
        Log::Trace('save and reload map');
        auto app = cast<CTrackMania>(GetApp());
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (!SaveMapSameName(editor)) {
            NotifyWarning("Map must be saved, first.");
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
        SetCamAnimationGoTo(currCam);
    }

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
}
