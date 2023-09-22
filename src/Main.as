bool UserHasPermissions = false;

void Main() {
    startnew(LoadFonts);
    UserHasPermissions = Permissions::OpenAdvancedMapEditor();
    if (!UserHasPermissions) {
        NotifyWarning("This plugin requires the advanced map editor");
        return;
    }
    CheckAndSetGameVersionSafe();
    if (GetApp().Editor !is null) {
        startnew(Editor::CacheMaterials);
    }
    RegisterOnEditorLoadCallback(Editor::CacheMaterials, "CacheMaterials");

    ExtraUndoFix::OnLoad();

    sleep(500);
    CallbacksEnabledPostInit = true;
    // if (GetApp().Editor is null) return;
    // if (Time::Now < 50000) return;

    // startnew(RunItemTest); // .WithRunContext(Meta::RunContext::AfterScripts);
}

#if DEV

void RunItemTest() {
    print('loading user32.dll');

    auto dll = Import::GetLibrary("user32.dll");
    print("dll is null? " + tostring(dll is null));
    auto SendInput = dll.GetFunction("SendInput");
    print("SendInput is null? " + tostring(SendInput is null));

    while (GetApp().Editor is null) yield();

    yield();
    yield();
    yield();
    yield();
    yield();
    yield();
    yield();
    yield();
    yield();
    trace('e++ waking up in 5s');

    auto ptrInputEditorStart = Dev::FindPattern(InputEditorPattern);

    sleep(5000);
    trace('e++ waking up');

    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    while (editor.Challenge.AnchoredObjects.Length > 0) {

    auto mousePosF = vec2(Draw::GetWidth(), Draw::GetHeight() - 4) / 2.;
    auto mousePos = int2(mousePosF.x, mousePosF.y);
    mousePos = int2(65535 / 2, 65535 / 2 - 1000);
    print("mousePos: " + mousePos.ToString());
    auto mouseClickPtr = GenerateMouseClickStruct(mousePos);
    // auto keypressPtr = GenerateKeyPressStruct(VirtualKey::Delete);
    // auto mouseClickPtrUp = GenerateMouseClickStruct(false);
    // auto after = SendInput.CallUInt32(2, mouseClickPtr, 40);
    print("delete item test:");
    auto item = DeleteItemTest();
    print("set place mode:");
    Editor::SetItemPlacementMode(Editor::ItemMode::Free);
    // yield();
    // print("send move:");
    // auto after = SendInput.CallUInt32(1, mouseClickPtr, 40);
    uint after = 0;
    print("yield:");
    // yield();
    yield();
    print("hook input editor: " + tostring(int(Dev::PushRegisters::SSE)));
    // auto h = Dev::Hook(PatchEditorInput::P_MOUSE_INPUT_TEST.ptr - 5, 0, "SetDeleteItemTest", Dev::PushRegisters::SSE);
    @inputEditorHook = Dev::Hook(PreGetPickedObjectRead_Ptr, 2, "SetDeleteItemTest", Dev::PushRegisters::SSE);
    print("delete from map:");
    Editor::DeleteItemFromMap(editor, item);
    print("mouse inputs:");
    after += SendInput.CallUInt32(2, mouseClickPtr + 40, 40);
    trace('send input returned: ' + after);
    // Editor::SetCamTargetedDistance(16.);
    yield();
    // Dev::Unhook(h);

    sleep(100);
    }
}

// This hooks in just above where the PickedObject is read for the first time
const string PreGetPickedObjectRead = "48 8B 8F 30 06 00 00 48 85 C9 74 09 E8 ?? ?? ?? ?? 85 C0 74 0D 48 39 B7 48 06 00 00";
const uint64 PreGetPickedObjectRead_Ptr = Dev::FindPattern(PreGetPickedObjectRead);
const uint PreGetPickedObjectRead_Padding = 2;

Dev::HookInfo@ inputEditorHook;

void SetDeleteItemTest() {
    trace("SetDeleteItemTest");
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    auto item = editor.Challenge.AnchoredObjects[0];
    Editor::DeleteItemFromMap(editor, item);
    // prev code ends here
    Dev::Unhook(inputEditorHook);
    @inputEditorHook = null;
}


// layout from VC++ (fields marked with increasing 0xZZZZ bytes)
// 00 00 00 00 CC CC CC CC
// 11 11 00 00 22 22 00 00
// 33 33 00 00 02 00 00 00
// 44 44 00 00 CC CC CC CC
// 55 55 00 00 00 00 00 00

uint64 GenerateMouseClickStruct(int2 pos) {
    auto ptr = Dev::Allocate(200);
    Dev::Write(ptr, uint32(0)); // type
    Dev::Write(ptr+0x4, uint32(0)); // unused
    Dev::Write(ptr+0x8, uint32(pos.x)); // x (0,65535) for absolute
    Dev::Write(ptr+0xC, uint32(pos.y)); // y (0,65535) for absolute
    Dev::Write(ptr+0x10, uint32(0)); // mouseData, should be zero
    Dev::Write(ptr+0x14, 0x0001
        // | 0x0002
        | 0x8000
        ); // dwFlags, left down and left up  | 1=move, 2=down, 4=up, 8000=absolute, 0x4000=virtauldesk
    Dev::Write(ptr+0x18, 0); // typestamp, provided by system
    // 0x1C: unused
    Dev::Write(ptr+0x20, uint64(0)); // ptr to extra data
    // LMB release
    ptr += 40;
    Dev::Write(ptr, uint32(0)); // type
    Dev::Write(ptr+0x4, uint32(0)); // unused
    Dev::Write(ptr+0x8, uint32(0)); // x (0,65535) for absolute
    Dev::Write(ptr+0xC, uint32(0)); // y (0,65535) for absolute
    Dev::Write(ptr+0x10, uint32(0)); // mouseData, should be zero
    Dev::Write(ptr+0x14, 0x0002); // dwFlags, left down and left up  | 1=move, 2=down, 4=up, 8000=absolute, 0x4000=virtauldesk
    Dev::Write(ptr+0x18, 0); // typestamp, provided by system
    // 0x1C: unused
    Dev::Write(ptr+0x20, uint64(0)); // ptr to extra data
    // LMB release
    ptr += 40;
    Dev::Write(ptr, uint32(0)); // type
    Dev::Write(ptr+0x4, uint32(0)); // unused
    Dev::Write(ptr+0x8, uint32(pos.x)); // x (0,65535) for absolute
    Dev::Write(ptr+0xC, uint32(pos.y)); // y (0,65535) for absolute
    Dev::Write(ptr+0x10, uint32(0)); // mouseData, should be zero
    Dev::Write(ptr+0x14, 0x0004); // dwFlags, left down and left up  | 0x0004 //  | 0x4000 | 0x8000
    Dev::Write(ptr+0x18, 0); // typestamp, provided by system
    // 0x1C: unused
    Dev::Write(ptr+0x20, uint64(0)); // ptr to extra data

    ptr -= 40;
    ptr -= 40;
    return ptr;
}

uint64 GenerateKeyPressStruct(VirtualKey key) {
    auto ptr = Dev::Allocate(80);
    Dev::Write(ptr, uint32(1)); // type
    Dev::Write(ptr+0x4, uint32(0)); // unused
    Dev::Write(ptr+0x8, uint16(key)); // keycode
    Dev::Write(ptr+0xA, uint16(0)); // wScan
    Dev::Write(ptr+0xC, uint32(0)); // dwFlags; 0 down, 2 up
    Dev::Write(ptr+0x10, uint32(0)); // time
    // unassigned
    // Dev::Write(ptr+0x14, 0x0004); // dwFlags, left down and left up  | 0x0004
    Dev::Write(ptr+0x18, uint64(0)); // dwExtraInfo
    // rest unused
    // LMB release
    ptr += 40;
    Dev::Write(ptr, uint32(1)); // type
    Dev::Write(ptr+0x4, uint32(0)); // unused
    Dev::Write(ptr+0x8, uint16(key)); // keycode
    Dev::Write(ptr+0xA, uint16(0)); // wScan
    Dev::Write(ptr+0xC, uint32(2)); // dwFlags; 0 down, 2 up
    Dev::Write(ptr+0x10, uint32(0)); // time
    // unassigned
    // Dev::Write(ptr+0x14, 0x0004); // dwFlags, left down and left up  | 0x0004
    Dev::Write(ptr+0x18, uint64(0)); // dwExtraInfo
    // rest unused

    ptr -= 40;
    return ptr;
}

// uint64 GenerateKeyPressStruct(VirtualKey key, bool down = true) {
//     auto ptr = Dev::Allocate(40);
//     Dev::Write(ptr, uint32(0)); // type
//     Dev::Write(ptr+0x4, uint32(0)); // unused
//     Dev::Write(ptr+0x8, uint32(0)); // relative x
//     Dev::Write(ptr+0xC, uint32(0)); // relative y
//     Dev::Write(ptr+0x10, uint32(0)); // mouseData, should be zero
//     Dev::Write(ptr+0x14, lmbDown ? 0x0002 : 0x0004); // dwFlags, left down and left up  | 0x0004
//     Dev::Write(ptr+0x18, 0); // typestamp, provided by system
//     // 0x1C: unused
//     Dev::Write(ptr+0x20, uint64(0)); // ptr to extra data
//     return ptr;
// }

void Main2() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

    /* ITEM EDITOR TEST
    uint sleepTime = 1000;
    while (sleepTime > 4) {
        trace('sleepTime: ' + sleepTime);
        for (int i = 0; i < editor.Challenge.AnchoredObjects.Length; i++) {
            trace('-----');
            auto item = editor.Challenge.AnchoredObjects[i];
            Editor::OpenItemEditor(editor, item);
            trace('> editing item : ' + i + "; " + item.IdName);
            sleep(sleepTime);
            trace('> exiting item editor');
            auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
            if (ieditor is null) continue;
            Editor::DoItemEditorAction(ieditor, Editor::ItemEditorAction::LeaveItemEditor);
            sleep(sleepTime);
        }
        sleepTime /= 2;
    }
    auto item = editor.Challenge.AnchoredObjects[0];
    Editor::OpenItemEditor(editor, item);
    */

    sleep(2000);

    // auto item = editor.Challenge.AnchoredObjects[0];
    // auto name = item.ItemModel.IdName;
    // Editor::DeleteItemFromMap(editor, item);
    // trace('Deleted: ' + name);
    // startnew(PatchEditorInput::Load);

    // @editor.Challenge.AnchoredObjects[46].WaypointSpecialProperty = CGameWaypointSpecialProperty();
    // startnew(DeleteItemTest).WithRunContext(Meta::RunContext::BeforeScripts);
    print("doing thing");
    auto ptrAfterInputs = Dev::FindPattern("4C 8B 6C 24 28 4C 8B 64 24 30 3D 1E 00 07 80 75 17 FF C7 83 FF 10 73 10 49 8B 06 49 8B CE FF 50 38 3D 1E 00 07 80 74 E9");
    print("ptr: " + Text::FormatPointer(ptrAfterInputs));
    auto h2 = Dev::Hook(ptrAfterInputs, 0, "IfLeftMBPatchClick", Dev::PushRegisters::SSE);
    // auto h = Dev::Hook(, 2, "DeleteItemTest");
    yield();
    yield();
    yield();
    yield();
    sleep(20000);
    yield();
    // Dev::Unhook(h);
    Dev::Unhook(h2);
}

// auto ptrAfterInputs = Dev::FindPattern("0F 10 64 24 28 0F 10 44 24 38 0F 10 4C 24 48 0F 11 23 0F 11 43 10 0F 11 4B 20 48 83 C4 60 5B C3");
auto ptrAfterInputs = Dev::FindPattern("4C 8B 6C 24 28 4C 8B 64 24 30 3D 1E 00 07 80 75 17 FF C7 83 FF 10 73 10 49 8B 06 49 8B CE FF 50 38 3D 1E 00 07 80 74 E9");
// uint64 inputMemPtr = 0x7FF61DDEAF90;

CGameCtnAnchoredObject@ DeleteItemTest() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    auto item = editor.Challenge.AnchoredObjects[0];
    auto itemName = item.ItemModel.IdName;
    trace('' + Time::Now + 'deleting a ' + itemName);
    // Editor::SetCamAnimationGoTo(vec2(.5, .5), item.AbsolutePositionInMap, 1);
    // UpdateCameraProgress(1.0);
    // Editor::FinalizeAnimationNow();
    return item;
}

void IfLeftMBPatchClick(uint64 rbx) {
    trace('call ');// + tostring(rbx));
    // if (rbx is null) {
    //     trace('rbx null');
    // } else {
    //     auto mouse = cast<CInputDeviceDx8Mouse>(rbx);
    //     if (mouse is null) {
    //         trace('mouse null');
    //     } else {
    //         Dev::SetOffset(mouse, 0x1AC, uint8(0x80));
    //         DeleteItemTest();
    //     }
    // }
    // if (r10 == uint64(0x7FF61DBB9FB0)) {
    //     Dev::Write(uint64(inputMemPtr) + 8, uint64(0x80));
    //     Dev::Write(uint64(inputMemPtr) + 0x10, vec2(0));
    //     Dev::Write(uint64(inputMemPtr) + 0x18, uint64(0x1));
    //     DeleteItemTest();
    // // }
    // trace('r10: ' + Text::FormatPointer(r10));
}


void OnDestroyed() { Unload(); }
void OnDisabled() { Unload(); }
void Unload() {
    // hmm not sure this is a great idea b/c some of it might be used by the game.
    // still, openplanet frees it anyway, so i guess nbd.
    FreeAllAllocated();
    // PatchEditorInput::Unload();
}

#endif

uint lastInItemEditor = 0;
bool everEnteredEditor = false;

void RenderEarly() {
    if (!UserHasPermissions) return;
    if (!GameVersionSafe) return;
    auto anyEditor = GetApp().Editor;
    auto editor = cast<CGameCtnEditorFree>(anyEditor);
    auto itemEditor = cast<CGameEditorItem>(anyEditor);
    auto meshEditor = cast<CGameEditorMesh>(anyEditor);
    auto currPg = cast<CSmArenaClient>(GetApp().CurrentPlayground);

    IsInCurrentPlayground = currPg !is null;

    IsInItemEditor = itemEditor !is null;
    if (IsInItemEditor) lastInItemEditor = Time::Now;

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
        // && (!everEnteredEditor || (Time::Now - lastInItemEditor) > 1000);
    auto LeavingEditor = WasInEditor && anyEditor is null;

    if (EnteringEditor) {
        EditorPriv::ResetRefreshUnsafe();
        Event::RunOnEditorLoadCbs();
        everEnteredEditor = true;
    } else if (LeavingEditor) {
        Event::RunOnEditorUnloadCbs();
    }
}

void Update(float dt) {
    UpdateAnimAndCamera();
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
