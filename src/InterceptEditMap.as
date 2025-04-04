bool INTERCEPTS_SET_UP = false;

void SetUpEditMapIntercepts() {
    if (INTERCEPTS_SET_UP) return;
    INTERCEPTS_SET_UP = true;
// #if DEV
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditMap", _EditMap);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditMap2", _EditMap2);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditMap3", _EditMap3);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditMap4", _EditMap4);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditMap5", _EditMap5);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap1", _EditNewMap1);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap2", _EditNewMap2);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap3", _EditNewMap3);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap4", _EditNewMap4);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMapFromBaseMap", _EditNewMapFromBaseMap);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMapFromBaseMap2", _EditNewMapFromBaseMap2);
    Dev::InterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMapFromBaseMap3", _EditNewMapFromBaseMap3);
// #endif
    Dev::InterceptProc("CGameEditorPluginMap", "LayerCustomEvent", _CGameEditorPluginMap_LayerCustomEvent);
}

void UnloadIntercepts() {
    if (!INTERCEPTS_SET_UP) return;
    INTERCEPTS_SET_UP = false;
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditMap", _EditMap);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditMap2", _EditMap2);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditMap3", _EditMap3);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditMap4", _EditMap4);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditMap5", _EditMap5);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap1", _EditNewMap1);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap2", _EditNewMap2);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap3", _EditNewMap3);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMap4", _EditNewMap4);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMapFromBaseMap", _EditNewMapFromBaseMap);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMapFromBaseMap2", _EditNewMapFromBaseMap2);
    Dev::ResetInterceptProc("CGameManiaTitleControlScriptAPI", "EditNewMapFromBaseMap3", _EditNewMapFromBaseMap3);
    Dev::ResetInterceptProc("CGameEditorPluginMap", "LayerCustomEvent", _CGameEditorPluginMap_LayerCustomEvent);
}

bool _EditMap(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(true);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditMap");
    // return true;
}

bool _EditMap2(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(true);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditMap2");
    // return true;
}

bool _EditMap3(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(true);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditMap3");
    // return true;
}

bool _EditMap4(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(true);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditMap4");
    // return true;
}

bool _EditMap5_Passthrough = false;

// used for UI things
bool _EditMap5(CMwStack &in stack, CMwNod@ nod) {
    if (_EditMap5_Passthrough) {
        Event::RunOnEditorStartingUpCbs(true);
        return true;
    }
    bool onlyForced = stack.CurrentBool(0);
    bool upgradeAdv = stack.CurrentBool(1);
    auto pluginArgs = stack.CurrentBufferWString(2);
    auto pluginScripts = stack.CurrentBufferWString(3);
    string playerModel = stack.CurrentWString(4);
    string modNameOrUrl = stack.CurrentWString(5);
    string decoration = stack.CurrentString(6);
    string map = stack.CurrentWString(7);
    CGameManiaTitleControlScriptAPI@ titleApi = cast<CGameManiaTitleControlScriptAPI>(nod);
    EditMapIntercept::EditMap5(titleApi, map, decoration, modNameOrUrl, playerModel, pluginScripts, pluginArgs, upgradeAdv, onlyForced);
    return false;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditMap5");
    // CGameManiaTitleControlScriptAPI@ titleApi = cast<CGameManiaTitleControlScriptAPI>(nod);
    // // void EditMap5(
    // // wstring Map, string Decoration, wstring ModNameOrUrl, wstring PlayerModel,
    // // MwFastBuffer<wstring>& EditorPluginsScripts, MwFastBuffer<wstring>& EditorPluginsArguments,
    // // bool UpgradeToAdvancedEditor, bool OnlyUseForcedPlugins)
    // bool onlyForced = stack.CurrentBool(0);
    // bool upgradeAdv = stack.CurrentBool(1);
    // auto pluginArgs = stack.CurrentBufferWString(2);
    // auto pluginScripts = stack.CurrentBufferWString(3);
    // string playerModel = stack.CurrentWString(4);
    // string modNameOrUrl = stack.CurrentWString(5);
    // string decoration = stack.CurrentString(6);
    // string map = stack.CurrentWString(7);
    // // probably puzzle mode or something, but the plugin is fine to load
    // // if (onlyForced) return true;

    // MwFastBuffer<wstring> _pluginScripts;
    // MwFastBuffer<wstring> _pluginArgs;
    // string pluginScriptsTxt;
    // string pluginArgsTxt;
    // for (uint i = 0; i < pluginScripts.Length; i++) {
    //     auto s = string(pluginScripts[i]);
    //     _pluginScripts.Add(s);
    //     pluginScriptsTxt += (i > 0 ? ", " : "") + s;
    // }
    // for (uint i = 0; i < pluginArgs.Length; i++) {
    //     auto s = string(pluginArgs[i]);
    //     _pluginArgs.Add(s);
    //     pluginArgsTxt += (i > 0 ? ", " : "") + s;
    // }
    // // pluginScripts.Add(wstring("EditorPlusPlus.Script.txt"));
    // // pluginArgs.Add(wstring(""));

    // dev_trace("map: " + map);
    // dev_trace("decoration: " + decoration);
    // dev_trace("modNameOrUrl: " + modNameOrUrl);
    // dev_trace("playerModel: " + playerModel);
    // dev_trace("pluginScripts: " + pluginScriptsTxt);
    // dev_trace("pluginArgs: " + pluginArgsTxt);
    // dev_trace("upgradeAdv: " + upgradeAdv);
    // dev_trace("onlyForced: " + onlyForced);

    // return true;

    // EDIT_MAP_PASSTHROUGH = true;
    // titleApi.EditMap5(map, decoration, modNameOrUrl, playerModel, pluginScripts, pluginArgs, upgradeAdv, onlyForced);
    // EDIT_MAP_PASSTHROUGH = false;

    // return false;
}

[Setting hidden]
bool S_AllowNonCarSportPlayerModelsEditingMap = true;

namespace EditMapIntercept {
    void EditMap5(CGameManiaTitleControlScriptAPI@ titleApi, const string &in map, const string &in decoration, const string &in modNameOrUrl, string _playerModel, MwFastBuffer<wstring> &in pluginScripts, MwFastBuffer<wstring> &in pluginArgs, bool upgradeAdv, bool onlyForced) {
        dev_trace("map: " + map);
        dev_trace("decoration: " + decoration);
        dev_trace("modNameOrUrl: " + modNameOrUrl);
        dev_trace("playerModel: " + _playerModel);
        dev_trace("pluginScripts: " + MwBufWstrToString(pluginScripts));
        dev_trace("pluginArgs: " + MwBufWstrToString(pluginArgs));
        dev_trace("upgradeAdv: " + upgradeAdv);
        dev_trace("onlyForced: " + onlyForced);

        if (S_AllowNonCarSportPlayerModelsEditingMap && _playerModel == "CarSport") {
            trace("Allowing any player/car model for editing map");
            _playerModel = "";
        }

        _EditMap5_Passthrough = true;
        titleApi.EditMap5(map, decoration, modNameOrUrl, _playerModel, pluginScripts, pluginArgs, upgradeAdv, onlyForced);
        _EditMap5_Passthrough = false;
    }

    string MwBufWstrToString(MwFastBuffer<wstring> &in buf) {
        string str;
        for (uint i = 0; i < buf.Length; i++) {
            str += (i > 0 ? ", " : "") + string(buf[i]);
        }
        return str;
    }
}


bool _EditNewMap1(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(false);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditNewMap1");
    // return true;
}
bool _EditNewMap2(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(false);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditNewMap2");

    // // -M  void EditNewMap2(string Environment, string Decoration, wstring ModNameOrUrl, wstring PlayerModel, wstring MapType, bool UseSimpleEditor, wstring EditorPluginScript, string EditorPluginArgument)
    // auto pluginArg = stack.CurrentString(0);
    // auto pluginScript = stack.CurrentWString(1);
    // auto useSimple = stack.CurrentBool(2);
    // auto mapType = stack.CurrentWString(3);
    // auto playerModel = stack.CurrentWString(4);
    // auto modNameOrUrl = stack.CurrentWString(5);
    // auto decoration = stack.CurrentString(6);
    // auto environment = stack.CurrentString(7);
    // dev_trace("environment: " + environment);
    // dev_trace("decoration: " + decoration);
    // dev_trace("modNameOrUrl: " + modNameOrUrl);
    // dev_trace("playerModel: " + playerModel);
    // dev_trace("mapType: " + mapType);
    // dev_trace("useSimple: " + useSimple);
    // dev_trace("pluginScript: " + pluginScript);
    // dev_trace("pluginArg: " + pluginArg);

    // return true;
}
bool _EditNewMap3(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(false);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditNewMap3");
    // return true;
}

// used for all UI calls
bool _EditNewMap4(CMwStack &in stack, CMwNod@ nod) {
    Event::RunOnEditorStartingUpCbs(false);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // CGameManiaTitleControlScriptAPI@ titleApi = cast<CGameManiaTitleControlScriptAPI>(nod);
    // dev_trace("_EditNewMap4");
    // // string Environment, string Decoration, wstring ModNameOrUrl,
    // // wstring PlayerModel, wstring MapType, bool UseSimpleEditor,
    // // MwFastBuffer<wstring>& EditorPluginsScripts, MwFastBuffer<wstring>& EditorPluginsArguments,
    // // bool OnlyUseForcedPlugins
    // bool onlyForced = stack.CurrentBool(0);
    // auto pluginArgs = stack.CurrentBufferWString(1);
    // auto pluginScripts = stack.CurrentBufferWString(2);
    // bool useSimple = stack.CurrentBool(3);
    // string mapType = stack.CurrentWString(4);
    // string playerModel = stack.CurrentWString(5);
    // string modNameOrUrl = stack.CurrentWString(6);
    // string decoration = stack.CurrentString(7);
    // string environment = stack.CurrentString(8);

    // MwFastBuffer<wstring> _pluginScripts;
    // MwFastBuffer<wstring> _pluginArgs;
    // _pluginScripts.Add(wstring("EditorPlusPlus.Script.txt"));
    // _pluginArgs.Add(wstring(""));
    // string pluginScriptsTxt;
    // string pluginArgsTxt;
    // for (uint i = 0; i < pluginScripts.Length; i++) {
    //     auto s = string(pluginScripts[i]);
    //     _pluginScripts.Add(s);
    //     pluginScriptsTxt += (i > 0 ? ", " : "") + s;
    // }
    // for (uint i = 0; i < pluginArgs.Length; i++) {
    //     auto s = string(pluginArgs[i]);
    //     _pluginArgs.Add(s);
    //     pluginArgsTxt += (i > 0 ? ", " : "") + s;
    // }

    // dev_trace("environment: " + environment);
    // dev_trace("decoration: " + decoration);
    // dev_trace("modNameOrUrl: " + modNameOrUrl);
    // dev_trace("playerModel: " + playerModel);
    // dev_trace("mapType: " + mapType);
    // dev_trace("useSimple: " + useSimple);
    // dev_trace("pluginScripts: " + pluginScriptsTxt);
    // dev_trace("pluginArgs: " + pluginArgsTxt);
    // dev_trace("onlyForced: " + onlyForced);

    // EDIT_MAP_PASSTHROUGH = true;
    // titleApi.EditNewMap4(environment, decoration, modNameOrUrl, playerModel, mapType, useSimple, pluginScripts, pluginArgs, onlyForced);
    // EDIT_MAP_PASSTHROUGH = false;

    // return false;
}
bool _EditNewMapFromBaseMap(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(false);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditNewMapFromBaseMap");
    // return true;
}
bool _EditNewMapFromBaseMap2(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(false);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditNewMapFromBaseMap2");
    // return true;
}
bool _EditNewMapFromBaseMap3(CMwStack &in stack) {
    Event::RunOnEditorStartingUpCbs(false);
    return true;
    // if (EDIT_MAP_PASSTHROUGH) return true;
    // dev_trace("_EditNewMapFromBaseMap3");
    // return true;
}


bool _CGameEditorPluginMap_LayerCustomEvent(CMwStack &in stack, CMwNod@ nod) {
    string type = stack.CurrentWString(1);
    if (!type.StartsWith("E++")) return true;
    auto data = stack.CurrentBufferWString(0);
    OnEppLayerCustomEvent(type.SubStr(4), data);
    return false;
}
