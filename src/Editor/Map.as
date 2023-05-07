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

    void SaveAndReloadMap() {
        Log::Trace('save and reload map');
        auto app = cast<CTrackMania>(GetApp());
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        string fileName = editor.Challenge.MapInfo.FileName;
        if (fileName.Length == 0) {
            NotifyWarning("Map must be saved, first.");
            return;
        }
        editor.PluginMapType.SaveMap(fileName);
        Log::Trace('saved');
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        app.BackToMainMenu();
        Log::Trace('back to menu');
        AwaitReturnToMenu();
        app.ManiaTitleControlScriptAPI.EditMap(fileName, "", "");
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
