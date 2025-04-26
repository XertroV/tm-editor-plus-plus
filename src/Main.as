bool UserHasPermissions = false;

void Main() {
    // sets vars that should be non-zero asap
    VTables::InitVTableAddrs();
    // Init_CreateTabGroups();

    // callbacks that must be registered first
    RegisterNewBlockCallback_Private(CustomCursorRotations::OnNewBlock, "CustomCursorRotations::OnNewBlock", 0);
    RegisterNewItemCallback_Private(CustomCursorRotations::OnNewItem, "CustomCursorRotations::OnNewItem", 0);

    RegisterNewBlockCallback_Private(FarlandsHelper::FH_OnAddBlock, "FarlandsHelper::FH_OnAddBlock", 1);
    RegisterNewItemCallback_Private(FarlandsHelper::FH_OnAddItem, "FarlandsHelper::FH_OnAddItem", 1);

    startnew(LoadFonts);
    // check permissions and version
    UserHasPermissions = Permissions::OpenAdvancedMapEditor();
    if (!UserHasPermissions) {
        NotifyWarning("This plugin requires the advanced map editor");
        return;
    }
    CheckAndSetGameVersionSafe();
    while (!GameVersionSafe) yield();

    if (GetApp().Editor !is null) {
        startnew(Editor::CacheMaterials);
    }

    startnew(UpdateEditorPlugin);
    RegisterOnEditorLoadCallback(Editor::CacheMaterials, "CacheMaterials");
    RegisterOnItemEditorLoadCallback(ClearSelectedOnEditorUnload, "ClearSelectedOnEditorUnload");
    RegisterOnEditorUnloadCallback(ClearSelectedOnEditorUnload, "ClearSelectedOnEditorUnload");

    RegisterOnEditorLoadCallback(HookOnMapSave::OnEnterEditor, "HookOnMapSave::OnEnterEditor");
    RegisterOnEditorUnloadCallback(HookOnMapSave::OnEditorLeave, "HookOnMapSave::OnEditorLeave");
#if DEV
    // testing grass stuff
    // PlacementHooks::SetupHooks();
    // RegisterNewBlockCallback_Private(PlacementHooks::Debug_OnBlockPlaced, "PlacementHooks::Debug_OnBlockPlaced", 0);
#endif
    RegisterOnEditorLoadCallback(PlacementHooks::SetupHooks, "PlacementHooks::SetupHooks");
    RegisterOnEditorUnloadCallback(PlacementHooks::UnloadHooks, "PlacementHooks::UnloadHooks");

    RegisterOnEditorStartingUpCallback(EditorPatches::OnEditorStartingUp, "EditorPatches::OnEditorStartingUp");

    RegisterOnEditorStartingUpCallback(OnEditorStartingFunc(PillarsChoice::OnEditorStartingUp), "PillarsChoice::OnEditorStartingUp");
    RegisterOnEditorLoadCallback(PillarsChoice::OnEditorLoad, "PillarsChoice::OnEditorLoad");
    RegisterOnEditorUnloadCallback(PillarsChoice::OnEditorUnload, "PillarsChoice::OnEditorUnload");
    // RegisterNewBlockCallback_Private(PillarsChoice::OnBlockPlaced, "PillarsChoice::OnBlockPlaced", 0);

    RegisterOnLeavingPlaygroundCallback(Editor::ImproveDefaultThumbnailLocation_OnReturnFromPg, "Editor::ImproveDefaultThumbnailLocation_OnReturnFromPg");

    MediatrackerSaver::RegisterCallbacks();

    VisSpriteDots::OnPluginLoad();

    // need to start this on load so that it's active when we enter the editor
    CustomCursorRotations::PromiscuousItemToBlockSnapping.IsApplied = S_EnablePromiscuousItemSnapping;
    ExtraUndoFix::OnLoad();
    Editor::OnPluginLoadSetUpMapThumbnailHook();
    SetUpEditMapIntercepts();
    CustomCursorRotations::BeforeAfterCursorUpdateHook.Apply();
    Editor::Setup_DeleteFreeblockCallbacks();
    RegisterNewAfterCursorUpdateCallback(CustomCursorRotations::CustomYaw_AfterCursorUpdate, "CustomCursorRotaitons::CustomYaw");
    // startnew(Editor::OffzonePatch::Apply);
    Editor::SetupApplySkinsCBs();
    CustomSelection::OnPluginLoad();
    FillBlocks::OnPluginLoad();

    Blocks::RegisterCallbacks(); // mostly to do with item SPlacements
    VegetRandomYaw::SetupCallbacks(); // for fixing trees on free blocks

    startnew(FarlandsHelper::CursorLoop).WithRunContext(Meta::RunContext::MainLoop);
    startnew(EditorCameraNearClipCoro).WithRunContext(Meta::RunContext::NetworkAfterMainLoop);
    startnew(Editor::ResetTrackMapChanges_Loop).WithRunContext(Meta::RunContext::BeforeScripts);

    startnew(RegisterEditorLeaveUndoStandingRespawnCheck);

    startnew(Loop_RunCtx_AfterMainLoop).WithRunContext(Meta::RunContext::AfterMainLoop);

    yield(2);
    startnew(ColorSelectionHook::SetupHooks);
    startnew(Gizmo::SetupGizmoHotkeysOnPluginStart);

    yield(2);
    Editor::SetInvPatchTy(S_InvPatchTy);

    sleep(400);
    CallbacksEnabledPostInit = true;

    startnew(LoadHotkeyDb);

    // auto fid = Fids::GetGame("GameData/Stadium/GameCtnDecoration/Map/DecoNoStadium48x48.Map.Gbx");

#if DEV
    // runGbxTest();
    // runZipTest();
    Murmur32::Hook();
    Test_Euler::Hook();
#endif
}

void Loop_RunCtx_AfterMainLoop() {
    while (true) {
        if (IsInEditor) {
            UpdateAnimAndCamera();
        }
        yield();
    }
}

void OnEnabled() {
    CustomCursorRotations::PromiscuousItemToBlockSnapping.IsApplied = S_EnablePromiscuousItemSnapping;
    ExtraUndoFix::OnLoad();
    Editor::OnPluginLoadSetUpMapThumbnailHook();
    SetUpEditMapIntercepts();
    CustomCursorRotations::BeforeAfterCursorUpdateHook.Apply();
}

void OnDestroyed() { Unload(true); }
void OnDisabled() { Unload(false); }
void Unload(bool freeMem = true) {
    // hmm not sure this is a great idea b/c some of it might be used by the game.
    // still, openplanet frees it anyway, so i guess nbd.
    Gizmo::_GizmoOnCancel();
    UnloadIntercepts();
    Editor::EnableMapThumbnailUpdate();
    HookOnMapSave::OnEditorLeave();
    Editor::OffzonePatch::Unapply();
    CheckUnhookAllRegisteredHooks();
    CustomCursor::ResetSnapRadius();
    CustomCursorRotations::PromiscuousItemToBlockSnapping.Unapply();
    CustomCursorRotations::BeforeAfterCursorUpdateHook.Unapply();
    LightMapCustomRes::Unpatch();
    PillarsChoice::IsActive = false;
    Gizmo::IsActive = false;
    NodPtrs::Cleanup();
    FreeAllAllocated();
#if DEV
    Murmur32::Unhook();
#endif
}

uint lastInItemEditor = 0;
bool everEnteredEditor = false;
uint lastTimeEnteredEditor = 0;
bool dismissedPluginEnableRequest = false;
bool dismissedCamReturnToStadium = false;
uint g_PriorRenderEarlyTime;
uint g_ThisRenderEarlyTime;
vec2 g_screen;
float g_scale = UI::GetScale();
// e.g., 1080/1440 for showing on 1080p
float g_stdPxToScreenPx = 1.;

void RenderEarly() {
    g_PriorRenderEarlyTime = g_ThisRenderEarlyTime;
    g_ThisRenderEarlyTime = Time::Now;

    if (!UserHasPermissions) return;
    if (!GameVersionSafe) return;

    g_screen = vec2(Draw::GetWidth(), Draw::GetHeight());
    g_stdPxToScreenPx = g_screen.y / 1440.;
    Picker::RenderEarly();

    auto switcher = GetApp().Switcher;
    auto anyEditor = GetApp().Editor;
    auto editor = cast<CGameCtnEditorFree>(anyEditor);
    auto itemEditor = cast<CGameEditorItem>(anyEditor);
    auto meshEditor = cast<CGameEditorMesh>(anyEditor);
    auto mtEditor = cast<CGameEditorMediaTracker>(anyEditor);
    auto currPg = cast<CSmArenaClient>(GetApp().CurrentPlayground);

    WasInAnyEditor = IsInAnyEditor;
    IsInAnyEditor = anyEditor !is null;
    WasInPlayground = IsInCurrentPlayground;
    IsInCurrentPlayground = currPg !is null;

    EnteringItemEditor = !IsInItemEditor;
    IsInItemEditor = itemEditor !is null;
    if (IsInItemEditor) lastInItemEditor = Time::Now;
    EnteringItemEditor = IsInItemEditor && EnteringItemEditor;

    WasInMTEditor = IsInMTEditor;
    EnteringMTEditor = !IsInMTEditor;
    IsInMTEditor = mtEditor !is null;
    EnteringMTEditor = IsInMTEditor && EnteringMTEditor;
    LeavingMTEditor = WasInMTEditor && !IsInMTEditor;

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
    IsEnteringPlayground = IsInCurrentPlayground && !WasInPlayground;
        // && (!everEnteredEditor || (Time::Now - lastInItemEditor) > 1000);
    EditorWasStillOnStack = EditorStillOnStack;
    EditorStillOnStack = !IsInEditor && IsInAnyEditor && switcher.ModuleStack.Length > 1 && cast<CGameCtnEditorFree>(switcher.ModuleStack[0]) !is null;
    LeavingEditor = WasInEditor && !IsInEditor;

    // Only call entering/leaving editor if it's actually loading, rather than moving to item editor etc.
    if (EnteringEditor && !EditorWasStillOnStack) {
        EditorPriv::ResetRefreshUnsafe();
        Event::RunOnEditorLoadCbs();
        everEnteredEditor = true;
        lastTimeEnteredEditor = Time::Now;
        CacheMapBounds();
    } else if (LeavingEditor && !EditorStillOnStack) {
        Event::RunOnEditorUnloadCbs();
    }

    if (WasInAnyEditor && !IsInAnyEditor) {
        Event::RunOnEditorGoneNullCbs();
    }

    if (EnteringItemEditor) {
        Event::RunOnItemEditorLoadCbs();
    }
    if (EnteringMTEditor) {
        Event::RunOnMTEditorLoadCbs();
    }
    if (LeavingMTEditor) {
        Event::RunOnMTEditorUnloadCbs();
    }

    if (IsEnteringPlayground && IsInEditor) {
        Event::RunOnEnteringPlaygroundCbs();
    }
    if (IsLeavingPlayground && IsInEditor) {
        Event::RunOnLeavingPlaygroundCbs();
    }

    IsCalculatingShadows = IsInEditor && DGameCtnEditorFree(editor).IsCalculatingShadows;

    g_WasDragging = g_IsDragging;
    g_LmbDown = IsLMBPressed();

    UpdateScrollCache();
    if (g_toolbarExtras is null) {
        Dev_NotifyWarning("g_toolbarExtras is nulL!");
        return;
    }
    g_toolbarExtras.Draw();
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
    // if (!IsInEditor && g_MapBaseSizeChanger !is null && g_MapBaseSizeChanger.windowOpen) {
    //     g_MapBaseSizeChanger.DrawWindow();
    // }

    PillarsChoice::Render();
    if (IsInEditor) {
        Gizmo::Render();
        FillBlocks::RenderFillPrompt();
        MediatrackerSaver::RenderWindow();
    }
    if (IsInAnyEditor) {
        ToolsTG.DrawWindows();
    }

}

void RenderInterface() {
    UI_Main_Render();
}


void AwaitReturnToMenu() {
    auto app = cast<CTrackMania>(GetApp());
    // app.BackToMainMenu();
    while (!IsInMainMenu()) {
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
        sleep(0);
        // trace('paused');
        g_LastPause = Time::Now;
    }
}

bool g_LmbDown = false;
bool g_RmbDown = false;
bool g_MmbDown = false;
vec2 lastMbClickPos;
vec2 g_lastMousePos;
bool g_IsDragging = false;
// track drag status for last frame
bool g_WasDragging = false;

bool g_LastMouseBDown = false;
int g_LastMouseButton = 0;
int2 g_LastMouseButtonPos = int2();

UI::InputBlocking OnMouseButton(bool down, int button, int x, int y) {
    if (!IsInEditor) return UI::InputBlocking::DoNothing;
    if (IsInCurrentPlayground) return UI::InputBlocking::DoNothing;
    bool lmbDown = down && button == 0;
    bool rmbDown = down && button == 1;
    bool block = false;
    if (lmbDown && g_CoordPathDrawingTool.ShouldBlockLMB()) {
        block = true;
    } else {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        block = (lmbDown && FarlandsHelper::FH_CheckPlacing()) || block;
        block = (lmbDown && CheckPlaceMacroblockAirMode()) || block;
        block = (lmbDown && CheckPlacingItemFreeMode()) || block;
        block = (down && Gizmo::CheckEnterGizmoMode(editor, lmbDown, rmbDown)) || block;
    }

    g_LastMouseBDown = down;
    g_LastMouseButton = button;
    g_LastMouseButtonPos = int2(x, y);
    // dev_trace('LastMouseButton: ' + down + ", " + button + ", " + g_LastMouseButtonPos.ToString());

    block = block || g_IsDragging || g_WasDragging;
    return block ? UI::InputBlocking::Block : UI::InputBlocking::DoNothing;
}

// only updates when not hovering imgui and input not carried off imgui
void OnMouseMove(int x, int y) {
    g_lastMousePos = vec2(x, y);
    // trace(g_lastMousePos.ToString());
}

int2 g_ScrollThisFrame = int2();
int2 g_LastScroll = int2();
uint g_NewScrollTime;

/** Called whenever the mouse wheel is scrolled. `x` and `y` are the scroll delta values.
*/
UI::InputBlocking OnMouseWheel(int x, int y) {
    g_LastScroll = int2(x, y);
    g_NewScrollTime = Time::Now;
    return UI::InputBlocking::DoNothing;
}


void UpdateScrollCache() {
    if (g_NewScrollTime > 0) {
        g_ScrollThisFrame = g_LastScroll;
        g_NewScrollTime = 0;
    }
    else {
        g_ScrollThisFrame = int2();
    }
}

float g_FrameTime = 10.;
float g_AvgFrameTime = 10.;
void Update(float dt) {
    g_FrameTime = dt;
    g_AvgFrameTime = g_AvgFrameTime * .9 + dt * .1;
}

// virtual keys that are registered for a hotkey
bool[] hotkeysFlags = array<bool>(256);


UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
    auto resp = OnKeyPress_Inner(down, key);
    if (resp == UI::InputBlocking::Block && IsInEditor) {
        Editor::EnableCustomCameraInputs();
        startnew(Editor::DisableCustomCameraInputs);
        return UI::InputBlocking::DoNothing;
    }
    return resp;
}

UI::InputBlocking OnKeyPress_Inner(bool down, VirtualKey key) {
    bool block = false;
    if (Bind::IsRebinding) {
        // expecting a key press for rebinding
        return Bind::OnKeyPress(down, key);
    }
    if (!IsInAnyEditor) return UI::InputBlocking::DoNothing;

    auto app = GetApp();
    auto editor = cast<CGameCtnEditorFree>(app.Editor);
    if (editor is null) return UI::InputBlocking::DoNothing;
    if (app.CurrentPlayground !is null) return OnKeyPressInPlayground(app, editor, down, key);
    if (IsCalculatingShadows) return UI::InputBlocking::DoNothing;
    if (app.BasicDialogs.Dialogs.CurrentFrame !is null) return UI::InputBlocking::DoNothing;
    block = block || ShouldBlockEscapePress(down, key, app, editor);
    block = customSelectionMgr.CheckCancel(down, key) || block;
    block = FillBlocks::CheckDismissPromptHotkeys(down, key) || block;
    // trace('key down: ' + tostring(key));
    if (hotkeysFlags[key]) {
        // trace('checking hotkey: ' + tostring(key));
        block = CheckHotkey(down, key) == UI::InputBlocking::Block || block;
    }
    if ((Time::Now - _hotkeysLastVisible) < 500 && down) {
        _ShowLastKeyPressed(key);
    }

    return block ? UI::InputBlocking::Block : UI::InputBlocking::DoNothing;
}

bool ShouldBlockEscapePress(bool down, VirtualKey key, CGameCtnApp@ app, CGameCtnEditorFree@ editor) {
    return down && key == VirtualKey::Escape
        && (S_BlockEscape || customSelectionMgr.IsActive)
        && app.CurrentPlayground is null
        && !Editor::IsInTestPlacementMode(editor);
}

[Setting hidden]
VirtualKey S_SetRespawnPosTestModeHotkey = VirtualKey::Home;

UI::InputBlocking OnKeyPressInPlayground(CGameCtnApp@ app, CGameCtnEditorFree@ editor, bool down, VirtualKey key) {
    // only test mode
    if (!Editor::IsInTestMode(editor)) return UI::InputBlocking::DoNothing;
    bool block = false;
    if (hotkeysFlags[key]) {
        // trace('checking hotkey: ' + tostring(key));
        block = CheckHotkey(down, key, false) == UI::InputBlocking::Block || block;
    }

    // if (down && key == S_SetRespawnPosTestModeHotkey) {
    //     Editor::SetEditorTestModeRespawnPositionFromCurrentVis();
    // }
    // // block = block || CheckPlaygroundHotkeys(app, editor, down, key);
    return block ? UI::InputBlocking::Block : UI::InputBlocking::DoNothing;
}
