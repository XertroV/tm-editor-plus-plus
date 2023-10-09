const string EDITOR_PLUGIN_FOLDER_PATH = IO::FromUserGameFolder("Scripts/EditorPlugins/");
const string EDITOR_PLUGIN_PATH = IO::FromUserGameFolder("Scripts/EditorPlugins/EditorPlugin_EditorPlusPlus.Script.txt");
void UpdateEditorPlugin() {
    if (!IO::FolderExists(EDITOR_PLUGIN_FOLDER_PATH)) {
        IO::CreateFolder(EDITOR_PLUGIN_FOLDER_PATH);
    }
    IO::File f(EDITOR_PLUGIN_PATH, IO::FileMode::Write);
    f.Write(EDITORPLUGIN_EDITORPLUSPLUS_SCRIPT_TXT);
    f.Close();
    yield();
    RegisterOnEditorLoadCallback(EditorPlugin::OnEditorLoad, "EditorPlugin::OnEditorLoad");
}

namespace EditorPlugin {
    void OnEditorLoad() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // reload scripts = {10, 0};
        // script buttons list card articles = {0, 12, 0, 0};
        // script buttons list card articles = {0, 12, 0, 1};
    }
}
