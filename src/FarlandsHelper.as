/**
 * bugs:
 * - sometimes the input is missed and (presumably) the cursor is reset before next block is placed
 */

namespace FarlandsHelper {
    // float CustomRotation = 0.1;
    bool FL_Helper_Active = false;
    bool drawDebugFarlandsHelper = false;
    bool resetCursorAfterNextPlacement = false;
    vec3 lastCursorPos;

    bool IsCameraInFarlands() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto cam = Editor::GetCurrentCamState(editor);
        // 210m is a little more than 3 * (256*32)^2;
        return cam.Pos.LengthSquared() > 210e6;
    }

    void Render() {
        if (FL_Helper_Active) {
            // nvgDrawHorizGridHelper(lastCursorPos, vec4(1), 1.5, 32., 3);
        }
    }

    void CursorLoop() {
        GetCursorRotation_BlockCreation_Hook.Apply();
        GetCursorRotation_ForDrawing_Hook.Apply();
        while (true) {
            yield();
            // if (skipNextFrame) {
            //     yield();
            //     skipNextFrame = false;
            //     continue;
            // }
            if (!IsInEditor) continue;
            // get the cursor
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) continue;
            auto cursor = editor.Cursor;
            // do some checks first
            bool isPlacingItem = Editor::IsInAnyItemPlacementMode(editor);
            if (!Editor::IsAnythingBeingDrawn(cursor)) continue;
            if (!Editor::IsInAnyFreePlacementMode(editor)) continue;
            if (!cursor.UseFreePos && !isPlacingItem) continue;
            // check if block cursor is at the edge of the map
            bool atEdge = (0 == cursor.Coord.x * cursor.Coord.y * cursor.Coord.z)
                || (cursor.Coord.x == g_MapCoordBounds.x - 1 || cursor.Coord.y == g_MapCoordBounds.y - 1 || cursor.Coord.z == g_MapCoordBounds.z - 1)
                ;
            if (!atEdge && !S_EnableInfinitePrecisionFreeBlocks) continue;

            // auto occ = editor.OrbitalCameraControl;
            auto camTarget = editor.PluginMapType.CameraTargetPosition;
            lastCursorPos = Picker::GetMouseToWorldAtHeight(camTarget.y);
            cursor.FreePosInMap = lastCursorPos;
            if (isPlacingItem) {
                Dev::SetOffset(editor.ItemCursor, O_ITEMCURSOR_CurrentPos, lastCursorPos);
            }
        }
    }

    HookHelper@ GetCursorRotation_ForDrawing_Hook = HookHelper(
        "0F 11 0B F2 0F 11 43 10 48 8B 5C 24 60 48 83 C4 50 5F C3",
        3, 0, "FarlandsHelper::_GetCursorRotation_SetViaRbxPlus0xC"
    );
    HookHelper@ GetCursorRotation_BlockCreation_Hook = HookHelper(
        "8B 86 ?? ?? 00 00 48 8B 5C 24 30 89 07 8B 86 ?? ?? 00 00 48 8B 74 24 38 48 8B 7C 24 40 41 89 06 48 83 C4 20",
        0, 1, "FarlandsHelper::_GetCursorRotation_SetViaRbx"
    );

    // note: only works for blocks
    // const string GetRotationPattern = "8B 86 54 01 00 00 48 8B 5C 24 30 89 07 8B 86 58 01 00 00 48 8B 74 24 38 48 8B 7C 24 40 41 89 06 48 83 C4 20 41 5E C3 ??";
    // const string GetRotationPattern = ;

    float get_CustomRotation() {
        return float(Time::Now) / 1000. % TAU;
    }

    void _GetCursorRotation_SetViaRbx(uint64 rbx) {
        // dev_trace("OnGetCursorRotation");
        if (FL_Helper_Active) {
            Dev::Write(rbx, float(CustomRotation));
            // Dev::Write(rbx + 0x10, float(CustomRotation));
            // dev_trace("Wrote custom rotation: " + CustomRotation);
        }
    }
    // this works, but
    void _GetCursorRotation_SetViaRbxPlus0xC(uint64 rbx) {
        // dev_trace("OnGetCursorRotation");
        if (FL_Helper_Active) {
            // todo, make sure
            Dev::Write(rbx + 0xC, float(CustomRotation)); //  % (TAU / 4.)
            // if (Time::Now / 1000 % 2 == 0)
            // dev_trace("Wrote custom rotation: " + CustomRotation);
        }
    }

    // free block stuff
    // return true to block click -- always returns false atm
    bool CheckPlacingFreeBlock() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return false;
        auto cursor = editor.Cursor;
        if (!Editor::IsBlockOrMacroblockBeingDrawn(cursor)) return false;
        if (!cursor.UseFreePos) return false;
        if (!Editor::IsInFreeBlockPlacementMode(editor, true)) return false;
        if (cursor.Color != cursor.CannotPlaceNorJoinColor) return false;
        if (GetApp().Viewport.Picker.Overlay !is null) return false;
        _addBlockSetPos = cursor.FreePosInMap;
        @_prevCursorState = Editor::GetCursorRot(cursor);
        _addBlockSetRot = _prevCursorState.euler;

        if (!FarlandsHelper::ApplyAddBlockHook()) {
            NotifyWarning("FAILED TO APPLY FARLANDS ADD BLOCK PATCH");
        } else {
            dev_trace("Applied on block hook");
        }

        // need to reset cursor rotations b/c some blocks need to be placed flat
        cursor.AdditionalDir = CGameCursorBlock::EAdditionalDirEnum::P0deg;
        cursor.Pitch = 0;
        cursor.Roll = 0;
        cursor.Dir = CGameCursorBlock::ECardinalDirEnum::North;
        // choose a random spot in the map, below the ground
        cursor.FreePosInMap = vec3(Math::Rand(32.0, g_MapBounds.x - 32.), Math::Rand(8.0, 16.), Math::Rand(32.0, g_MapBounds.z - 32.));
        // attempt to avoid missing a click input
        resetCursorAfterNextPlacement = true;

        return false;

        // // auto placeCoord = int3(0, g_MapCoordBounds.y / 2, 0);
        // if (!editor.PluginMapType.PlaceBlock(editor.CurrentBlockInfo, placeCoord, CGameEditorPluginMap::ECardinalDirections::North)) {
        //     NotifyWarning('failed to place block');
        //     return false;
        // }
        // auto block = editor.PluginMapType.GetBlock(placeCoord);
        // if (block is null) {
        //     NotifyWarning("got null block!?!??!");
        //     return false;
        // }
        // Editor::ConvertNormalToFree(block, pos, rot);
        // editor.PluginMapType.AutoSave();
        // Editor::RefreshBlocksAndItems(editor);
        // return true;
    }

    const string IncrBlocksArrayLenPattern = "E8 ?? ?? ?? ?? 48 8B 9C 24 28 01 00 00 C7 85 F0 05 00 00 01 00 00 00 48 85 DB 0F 85 F8 00 00 00 45 85 E4 75 10 49 8B CE E8 ?? ?? ?? ?? 85 C0 0F 84 D5 00 00 00 8B 94 24 F8 00 00 00 49 8B CE BB FF FF FF FF";

    HookHelper@ IncrBlocksArrayLenHook = HookHelper(
        IncrBlocksArrayLenPattern,
        5, 3, "FarlandsHelper::OnAddBlockHook"
    );

    uint64 incrBlocksArrayLenPtr;
    Dev::HookInfo@ incrBlocksArrayLenHook;
    bool ApplyAddBlockHook() {
        if (IncrBlocksArrayLenHook.IsApplied()) return true;
        return IncrBlocksArrayLenHook.Apply();
        // if (incrBlocksArrayLenHook !is null) return false;
        // if (incrBlocksArrayLenPtr == 0) {
        //     incrBlocksArrayLenPtr = Dev::FindPattern(IncrBlocksArrayLenPattern);
        // }
        // if (incrBlocksArrayLenPtr == 0) {
        //     warn_every_60_s("Could not find IncrBlocksArrayLenPattern");
        //     return false;
        // }
        // @incrBlocksArrayLenHook = Dev::Hook(incrBlocksArrayLenPtr + 5, 3, "FarlandsHelper::OnAddBlockHook", Dev::PushRegisters::SSE);
        // return true;
    }

    bool UnapplyAddBlockHook() {
        if (IncrBlocksArrayLenHook is null) return false;
        if (!IncrBlocksArrayLenHook.IsApplied()) return true;
        return IncrBlocksArrayLenHook.Unapply();
        // Dev::Unhook(incrBlocksArrayLenHook);
        // @incrBlocksArrayLenHook = null;
        // return true;
    }

    vec3 _addBlockSetPos;
    vec3 _addBlockSetRot;
    EditorRotation@ _prevCursorState;

    void OnAddBlockHook(uint64 rdx) {
        dev_trace('on add block hook');
        // return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto map = editor.Challenge;
        if (map is null) return;
        auto block = map.Blocks[map.Blocks.Length - 1];
        if (block is null) {
            NotifyWarning("on add block hook got null block!");
        } else {
            Editor::SetBlockLocation(block, _addBlockSetPos);
            Editor::SetBlockRotation(block, _addBlockSetRot);
        }
        if (!UnapplyAddBlockHook()) {
            NotifyWarning("Failed to unapply add block hook");
        } else {
            dev_trace("unapplied on add block hook");
        }
        if (editor.Cursor is null) return;
        _prevCursorState.SetCursor(editor.Cursor);
        editor.Cursor.FreePosInMap = _addBlockSetPos;
    }
}


//CgameCursorItem
// 0x5c: Vec3 of current pos, editable


/**
 *
 * block cursor rotation (rads) is moved into [rbx] after the call:

Trackmania.exe+DBDF1F - E8 FCE20D00           - call Trackmania.exe+E9C220 { turn direction into thing

 }
Trackmania.exe+DBDF24 - F3 0F11 03            - movss [rbx],xmm0 { move angle to stack register
 }
Trackmania.exe+DBDF28 - 8B 86 54010000        - mov eax,[rsi+00000154]
Trackmania.exe+DBDF2E - 48 8B 5C 24 30        - mov rbx,[rsp+30]
Trackmania.exe+DBDF33 - 89 07                 - mov [rdi],eax
Trackmania.exe+DBDF35 - 8B 86 58010000        - mov eax,[rsi+00000158]
Trackmania.exe+DBDF3B - 48 8B 74 24 38        - mov rsi,[rsp+38]
Trackmania.exe+DBDF40 - 48 8B 7C 24 40        - mov rdi,[rsp+40]
Trackmania.exe+DBDF45 - 41 89 06              - mov [r14],eax
Trackmania.exe+DBDF48 - 48 83 C4 20           - add rsp,20 { 32 }
Trackmania.exe+DBDF4C - 41 5E                 - pop r14
Trackmania.exe+DBDF4E - C3                    - ret


pattern: 8B 86 54 01 00 00 48 8B 5C 24 30 89 07 8B 86 58 01 00 00 48 8B 74 24 38 48 8B 7C 24 40 41 89 06 48 83 C4 20 41 5E C3
- hook with padding = 1


 * preview for items is elsewhere,

Trackmania.exe+10C435D - 0F11 0B               - movups [rbx],xmm1 { angle moved into rbx
 }
Trackmania.exe+10C4360 - F2 0F11 43 10         - movsd [rbx+10],xmm0
Trackmania.exe+10C4365 - 48 8B 5C 24 60        - mov rbx,[rsp+60]
Trackmania.exe+10C436A - 48 83 C4 50           - add rsp,50 { 80 }
Trackmania.exe+10C436E - 5F                    - pop rdi
Trackmania.exe+10C436F - C3                    - ret


full:


Trackmania.exe+10C432E - E8 ED7EDDFF           - call Trackmania.exe+E9C220
Trackmania.exe+10C4333 - 0F10 4C 24 20         - movups xmm1,[rsp+20]
Trackmania.exe+10C4338 - 48 8B C3              - mov rax,rbx
Trackmania.exe+10C433B - F3 0F10 57 28         - movss xmm2,[rdi+28]
Trackmania.exe+10C4340 - F2 0F10 CE            - movsd xmm1,xmm6
Trackmania.exe+10C4344 - 0F28 74 24 40         - movaps xmm6,[rsp+40]
Trackmania.exe+10C4349 - 0FC6 C9 93            - shufps xmm1,xmm1,-6D { 147 }
Trackmania.exe+10C434D - F3 0F10 C8            - movss xmm1,xmm0
Trackmania.exe+10C4351 - F3 0F10 47 24         - movss xmm0,[rdi+24]
Trackmania.exe+10C4356 - 0FC6 C9 39            - shufps xmm1,xmm1,39 { 57 }
Trackmania.exe+10C435A - 0F14 C2               - unpcklps xmm0,xmm2
Trackmania.exe+10C435D - 0F11 0B               - movups [rbx],xmm1 { angle moved into rbx
 }
Trackmania.exe+10C4360 - F2 0F11 43 10         - movsd [rbx+10],xmm0
Trackmania.exe+10C4365 - 48 8B 5C 24 60        - mov rbx,[rsp+60]
Trackmania.exe+10C436A - 48 83 C4 50           - add rsp,50 { 80 }
Trackmania.exe+10C436E - 5F                    - pop rdi
Trackmania.exe+10C436F - C3                    - ret




pattern: 0F 11 0B F2 0F 11 43 10 48 8B 5C 24 60 48 83 C4 50 5F C3
offset = 3
padding = 0

-------------

hooking adding blocks -- this code called after adding a free block to the blocks array:

Trackmania.exe+AF7F39 - E8 D2D965FF           - call Trackmania.exe+155910 { update blocks array len
 }
Trackmania.exe+AF7F3E - 48 8B 9C 24 28010000  - mov rbx,[rsp+00000128]
Trackmania.exe+AF7F46 - C7 85 F0050000 01000000 - mov [rbp+000005F0],00000001 { 1 }
Trackmania.exe+AF7F50 - 48 85 DB              - test rbx,rbx
Trackmania.exe+AF7F53 - 0F85 F8000000         - jne Trackmania.exe+AF8051
Trackmania.exe+AF7F59 - 45 85 E4              - test r12d,r12d
Trackmania.exe+AF7F5C - 75 10                 - jne Trackmania.exe+AF7F6E
Trackmania.exe+AF7F5E - 49 8B CE              - mov rcx,r14
Trackmania.exe+AF7F61 - E8 EA4D3900           - call Trackmania.exe+E8CD50
Trackmania.exe+AF7F66 - 85 C0                 - test eax,eax
Trackmania.exe+AF7F68 - 0F84 D5000000         - je Trackmania.exe+AF8043
Trackmania.exe+AF7F6E - 8B 94 24 F8000000     - mov edx,[rsp+000000F8]
Trackmania.exe+AF7F75 - 49 8B CE              - mov rcx,r14
Trackmania.exe+AF7F78 - BB FFFFFFFF           - mov ebx,FFFFFFFF { -1 }


// pattern = "E8 D2 D9 65 FF 48 8B 9C 24 28 01 00 00 C7 85 F0 05 00 00 01 00 00 00 48 85 DB 0F 85 F8 00 00 00 45 85 E4 75 10 49 8B CE E8 EA 4D 39 00 85 C0 0F 84 D5 00 00 00 8B 94 24 F8 00 00 00 49 8B CE BB FF FF FF FF";
pattern = "E8 ?? ?? ?? ?? 48 8B 9C 24 28 01 00 00 C7 85 F0 05 00 00 01 00 00 00 48 85 DB 0F 85 F8 00 00 00 45 85 E4 75 10 49 8B CE E8 ?? ?? ?? ?? 85 C0 0F 84 D5 00 00 00 8B 94 24 F8 00 00 00 49 8B CE BB FF FF FF FF";




 *
 */
