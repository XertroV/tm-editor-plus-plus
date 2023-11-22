bool UserHasPermissions = false;

void Main() {
    startnew(LoadFonts);
    UserHasPermissions = Permissions::OpenAdvancedMapEditor();
    if (!UserHasPermissions) {
        NotifyWarning("This plugin requires the advanced map editor");
        return;
    }
    CheckAndSetGameVersionSafe();
    while (!GameVersionSafe) sleep(500);
    if (GetApp().Editor !is null) {
        startnew(Editor::CacheMaterials);
    }
    startnew(UpdateEditorPlugin);
    RegisterOnEditorLoadCallback(Editor::CacheMaterials, "CacheMaterials");
    RegisterOnItemEditorLoadCallback(ClearSelectedOnEditorUnload, "ClearSelectedOnEditorUnload");
    RegisterOnEditorUnloadCallback(ClearSelectedOnEditorUnload, "ClearSelectedOnEditorUnload");

    ExtraUndoFix::OnLoad();
    Editor::OnPluginLoadSetUpMapThumbnailHook();
    SetUpEditMapIntercepts();
    startnew(Editor::OffzonePatch::Apply);
    // startnew(FarlandsHelper::CursorLoop).WithRunContext(Meta::RunContext::MainLoop);

    sleep(500);
    CallbacksEnabledPostInit = true;

#if DEV
    // runGbxTest();
    // runZipTest();
#endif
}



void OnDestroyed() { Unload(); }
void OnDisabled() { Unload(); }
void Unload() {
    // hmm not sure this is a great idea b/c some of it might be used by the game.
    // still, openplanet frees it anyway, so i guess nbd.
    FreeAllAllocated();
    Editor::EnableMapThumbnailUpdate();
    Editor::OffzonePatch::Unapply();
    FarlandsHelper::UnapplyAddBlockHook();
    CheckUnhookAllRegisteredHooks();
}

uint lastInItemEditor = 0;
bool everEnteredEditor = false;
uint lastTimeEnteredEditor = 0;
bool dismissedPluginEnableRequest = false;
bool dismissedCamReturnToStadium = false;

void RenderEarly() {
#if DEV
    Picker::RenderEarly();
#endif

    if (!UserHasPermissions) return;
    if (!GameVersionSafe) return;
    auto anyEditor = GetApp().Editor;
    auto editor = cast<CGameCtnEditorFree>(anyEditor);
    auto itemEditor = cast<CGameEditorItem>(anyEditor);
    auto meshEditor = cast<CGameEditorMesh>(anyEditor);
    auto currPg = cast<CSmArenaClient>(GetApp().CurrentPlayground);

    WasInPlayground = IsInCurrentPlayground;
    IsInCurrentPlayground = currPg !is null;

    EnteringItemEditor = !IsInItemEditor;
    IsInItemEditor = itemEditor !is null;
    if (IsInItemEditor) lastInItemEditor = Time::Now;
    EnteringItemEditor = IsInItemEditor && EnteringItemEditor;

    IsInMeshEditor = meshEditor !is null;

    WasInEditor = IsInEditor;
    EnteringEditor = !IsInEditor;
    // we're in the editor if it's not null and we were in the editor, or if we weren't then we wait for the editor to be ready for a request
    IsInEditor = editor !is null && (
        IsInEditor || (
            editor.PluginMapType !is null
            && editor.PluginMapType.IsEditorReadyForRequest
        )
    );
    // we didn't fire this on being in the item editor, but we sorta do need it to refresh the caches.
    EnteringEditor = EnteringEditor && IsInEditor;
    IsLeavingPlayground = !IsInCurrentPlayground && WasInPlayground;
        // && (!everEnteredEditor || (Time::Now - lastInItemEditor) > 1000);
    auto LeavingEditor = WasInEditor && !IsInEditor;

    if (EnteringEditor) {
        EditorPriv::ResetRefreshUnsafe();
        Event::RunOnEditorLoadCbs();
        everEnteredEditor = true;
        lastTimeEnteredEditor = Time::Now;
        CacheMapBounds();
    } else if (LeavingEditor) {
        Event::RunOnEditorUnloadCbs();
    }

    if (EnteringItemEditor) {
        Event::RunOnItemEditorLoadCbs();
    }

    if (IsLeavingPlayground && IsInEditor) {
        Event::RunOnLeavingPlaygroundCbs();
    }

    g_WasDragging = g_IsDragging;
    g_LmbDown = IsLMBPressed();
}

void Render() {
    if (g_BigFont is null) return;
    if (!GameVersionSafe) return;
    if (!UserHasPermissions) return;
    if (EnteringEditor)
        trace('Updating editor watchers.');
    // send null if we're not flagged as in the editor to wait for it to update
    UpdateEditorWatchers(IsInEditor ? cast<CGameCtnEditorFree>(GetApp().Editor) : null);
    if (EnteringEditor)
        trace('Done updating editor watchers.');
    // if (IsInEditor) FarlandsHelper::Render();
    RenderItemEditorButtons();
    if (g_MapPropsTab !is null) g_MapPropsTab.DrawTestPlacementWindows();
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

uint g_LastPause = 0;
void CheckPause() {
    uint workMs = Time::Now < 60000 ? 1 : 4;
    if (g_LastPause + workMs < Time::Now) {
        yield();
        // trace('paused');
        g_LastPause = Time::Now;
    }
}

bool g_LmbDown = false;
bool g_RmbDown = false;
bool g_MmbDown = false;
vec2 lastMbClickPos;
vec2 lastMousePos;
bool g_IsDragging = false;
// track drag status for last frame
bool g_WasDragging = false;

UI::InputBlocking OnMouseButton(bool down, int button, int x, int y) {
    bool lmbDown = down && button == 0;
    bool block = lmbDown && CheckPlaceMacroblockAirMode();
    block = (lmbDown && CheckPlacingItemFreeMode()) || block;
    // block = (lmbDown && FarlandsHelper::CheckPlacingFreeBlock()) || block;

    block = block || g_IsDragging || g_WasDragging;
    return block ? UI::InputBlocking::Block : UI::InputBlocking::DoNothing;
}

// only updates when not hovering imgui and input not carried off imgui
void OnMouseMove(int x, int y) {
    lastMousePos = vec2(x, y);
    // trace(lastMousePos.ToString());
}

float g_FrameTime = 10.;
float g_AvgFrameTime = 10.;
void Update(float dt) {
    UpdateAnimAndCamera();

    g_FrameTime = dt;
    g_AvgFrameTime = g_AvgFrameTime * .9 + dt * .1;
}

// virtual keys that are registered for a hotkey
bool[] hotkeysFlags = array<bool>(256);

/** Called whenever a key is pressed on the keyboard. See the documentation for the [`VirtualKey` enum](https://openplanet.dev/docs/api/global/VirtualKey).
*/
UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    auto app = GetApp();
    if (app.Editor is null) return UI::InputBlocking::DoNothing;
    bool block = false;
    block = block || (S_BlockEscape && down && key == VirtualKey::Escape && app.CurrentPlayground is null);
    // trace('key down: ' + tostring(key));
    if (down && hotkeysFlags[key]) {
        // trace('checking hotkey: ' + tostring(key));
        block = CheckHotkey(key) == UI::InputBlocking::Block || block;
    }
    return block ? UI::InputBlocking::Block : UI::InputBlocking::DoNothing;
}
