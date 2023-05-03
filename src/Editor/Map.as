namespace Editor_Map {
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

    nat3 g_NewMapSize;
    nat3 g_OrigMapSize;
    string m_Archetype;
    string m_DecorationName;
    string m_MapMod;
    ReferencedNod@ g_Decoration = null;
    ReferencedNod@ g_SavedMap = null;

    void SetSizeSaveReload(CGameCtnChallenge@ map, nat3 &in newSize) {
        g_NewMapSize = newSize;
        g_OrigMapSize = map.Size;
        m_Archetype = map.VehicleName.GetName();
        if (map.VehicleName.Value == 0xFFFFFFFF) {
            m_Archetype = "CarSport";
        }
        @g_Decoration = ReferencedNod(map.Decoration);
        m_DecorationName = map.DecorationName;
        m_MapMod = map.ModPackDesc is null ? "" : string(map.ModPackDesc.FileName);
        startnew(SaveAndReloadMap);
    }
    string _lastMapFileName;

    void SaveAndReloadMap() {
        Log::Trace('save and reload map');
        auto app = cast<CTrackMania>(GetApp());
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        string fileName = editor.Challenge.MapInfo.FileName;
        if (fileName.Length == 0) {
            NotifyWarning("Map must be saved, first.");
            return;
        }

        if (g_Decoration is null) {
            NotifyWarning("Cannot reload map because deco null.");
            return;
        }

        trace('setting deco size');
        auto deco = g_Decoration.AsDecoration();
        CacheDecoSize(deco.DecoSize);
        deco.DecoSize.SizeX = g_NewMapSize.x;
        deco.DecoSize.SizeY = g_NewMapSize.y;
        deco.DecoSize.SizeZ = g_NewMapSize.z;

        Log::Trace('set new size');
        _SetMapSize(editor.Challenge, g_NewMapSize);
        // return;
        // editor.Challenge.CheckPlayField();
        Log::Trace('saving');
        // editor.PluginMapType.SaveMap(fileName);

        // if (app.BasicDialogs.Dialog == CGameDialogs::EDialog::WaitMessage) {
        //     app.BasicDialogs.WaitMessage_Ok();
        // }
        // if (app.BasicDialogs.Dialog == CGameDialogs::EDialog::Message) {
        //     app.BasicDialogs.Message_Ok();
        // }
        // app.BasicDialogs.DialogSaveAs_OnValidate();

        // editor.ButtonSaveOnClick();
        // while (!editor.PluginMapType.IsEditorReadyForRequest) yield();


        Log::Trace('saved');
        _SetMapSize(editor.Challenge, g_OrigMapSize);
        // return;
        Log::Trace('set orig size');


        // @g_SavedMap = ReferencedNod(editor.Challenge);
        // editor.PluginMapType
        app.BackToMainMenu();
        Log::Trace('back to menu');
        _lastMapFileName = fileName;
        startnew(_WaitAndReloadLastMap);
    }

    nat3 g_OrigDecoSize = nat3();

    void CacheDecoSize(CGameCtnDecorationSize@ size) {
        g_OrigDecoSize.x = size.SizeX;
        g_OrigDecoSize.y = size.SizeY;
        g_OrigDecoSize.z = size.SizeZ;
    }
    void ResetDecoSize(CGameCtnDecorationSize@ size) {
        size.SizeX = g_OrigDecoSize.x;
        size.SizeY = g_OrigDecoSize.y;
        size.SizeZ = g_OrigDecoSize.z;
    }

    void _WaitAndReloadLastMap() {
        AwaitReturnToMenu();
        yield();
        trace('back at menu, ~~updating decoration~~');
        auto app = cast<CTrackMania>(GetApp());

        // auto map = g_SavedMap.AsMap();
        // _SetMapSize(map, g_NewMapSize);
        // auto fid = cast<CSystemFidFile>(GetFidFromNod(map));

        // if (Fids::Extract(fid)) {
        //     auto relPath = RelativeMapPath(fid);
        //     auto copyFrom = IO::FromDataFolder("Extract/" + relPath);
        //     auto copyTo = IO::FromUserGameFolder("Maps/" + relPath);
        //     CopyFile(copyFrom, copyTo);
        // } else {
        //     NotifyWarning('failed to extract map');
        //     return;
        // }

        // trace('edit map 2: ' + _lastMapFileName + ", " + m_DecorationName + ", " + m_MapMod + ", " + m_Archetype);
        // yield();

        app.ManiaTitleControlScriptAPI.EditMap(_lastMapFileName, "", "");
        // _SetMapSize(map, g_NewMapSize);

        // app.ManiaTitleControlScriptAPI.EditMap2(_lastMapFileName, m_DecorationName, m_MapMod, m_Archetype, "", "");

        trace('awaiting editor');

        while (app.Editor is null) yield();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
        // @g_SavedMap = null;

        ResetDecoSize(g_Decoration.AsDecoration().DecoSize);

        return;

        trace('got editor, saving');
        // x a b
        // _SetMapSize(editor.Challenge, g_NewMapSize);
        // trace('set offset, saving');

        editor.PluginMapType.SaveMap(editor.Challenge.MapInfo.FileName);
        yield();

        app.BackToMainMenu();
        @editor = null;
        AwaitReturnToMenu();

        // ResetDecoSize(deco.DecoSize);
        @g_Decoration = null;

        app.ManiaTitleControlScriptAPI.EditMap(_lastMapFileName, "", "");

        while (app.Editor is null) yield();
        @editor = cast<CGameCtnEditorFree>(app.Editor);
        while (!editor.PluginMapType.IsEditorReadyForRequest) yield();


        // app.ManiaTitleControlScriptAPI.EditNewMap2()
        // string Environment, string Decoration, wstring ModNameOrUrl, wstring PlayerModel,
        // wstring MapType, bool UseSimpleEditor, wstring EditorPluginScript,
        // string EditorPluginArgument

        // app.ManiaTitleControlScriptAPI.EditMap2()
        //wstring Map, string Decoration, wstring ModNameOrUrl, wstring PlayerModel,
        // wstring EditorPluginScript, string EditorPluginArgument
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
