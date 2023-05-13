bool UserHasPermissions = false;

void Main() {
    LoadFonts();
    UserHasPermissions = Permissions::OpenAdvancedMapEditor();
    if (!UserHasPermissions) {
        NotifyWarning("This plugin requires the advanced map editor");
        return;
    }
    CheckAndSetGameVersionSafe();
}

uint lastInItemEditor = 0;

void RenderEarly() {
    if (!UserHasPermissions) return;
    if (!GameVersionSafe) return;
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    auto itemEditor = cast<CGameEditorItem>(GetApp().Editor);
    auto currPg = cast<CSmArenaClient>(GetApp().CurrentPlayground);

    IsInCurrentPlayground = currPg !is null;

    IsInItemEditor = itemEditor !is null;
    if (IsInItemEditor) lastInItemEditor = Time::Now;

    EnteringEditor = !IsInEditor;
    // we're in the editor if it's not null and we were in the editor, or if we weren't then we wait for the editor to be ready for a request
    IsInEditor = editor !is null && (
        IsInEditor || (
            editor.PluginMapType !is null
            && editor.PluginMapType.IsEditorReadyForRequest
        )
    );
    EnteringEditor = EnteringEditor && IsInEditor && (Time::Now - lastInItemEditor) > 1000;

    if (EnteringEditor) {
        EditorPriv::ResetRefreshUnsafe();
        Event::RunOnEditorLoadCbs();
    }
}

void Update(float dt) {
    UpdateAnimAndCamera();
}

void Render() {
    if (!GameVersionSafe) return;
    if (!UserHasPermissions) return;
    if (EnteringEditor)
        trace('Updating editor watchers.');
    // send null if we're not flagged as in the editor to wait for it to update
    UpdateEditorWatchers(IsInEditor ? cast<CGameCtnEditorFree>(GetApp().Editor) : null);
    if (EnteringEditor)
        trace('Done updating editor watchers.');
}

void RenderInterface() {
    UI_Main_Render();
}


void AwaitReturnToMenu() {
    auto app = cast<CTrackMania>(GetApp());
    // app.BackToMainMenu();
    while (app.Switcher.ModuleStack.Length == 0 || cast<CTrackManiaMenus>(app.Switcher.ModuleStack[0]) is null) {
        yield();
    }
    while (!app.ManiaTitleControlScriptAPI.IsReady) {
        yield();
    }
}

void AwaitEditor() {
    auto app = cast<CTrackMania>(GetApp());
    while (cast<CGameCtnEditorFree>(app.Editor) is null) yield();
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    while (!editor.PluginMapType.IsEditorReadyForRequest) yield();
}

void CopyFile(const string &in f1, const string &in f2) {
    trace("Copying " + f1 + " to " + f2);
    IO::File outFile(f2, IO::FileMode::Write);
    IO::File inFile(f1, IO::FileMode::Read);
    outFile.Write(inFile.Read(inFile.Size()));
    outFile.Close();
    inFile.Close();
}
