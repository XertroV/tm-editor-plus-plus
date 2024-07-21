/**
 * bugs:
 * - sometimes the input is missed and (presumably) the cursor is reset before next block is placed
 */

void DrawInfinitePrecisionSetting() {
    S_EnableInfinitePrecisionFreeBlocks = UI::Checkbox("Enable infinite precision for free blocks / items / macroblocks" + BetaIndicator + Icons::ExclamationTriangle, S_EnableInfinitePrecisionFreeBlocks);
    AddSimpleTooltip("Overwrite the cursor position so you can preview and place blocks outside the stadium. You should also unlock the editor camera (under Editor Misc). Can be used to prevent item snapping.\n\\$f80Warning! If you have trouble placing things, disable this!");
}

namespace FarlandsHelper {
    // float CustomRotation = 0.1;
    bool FL_Helper_Active = false;
    bool drawDebugFarlandsHelper = false;
    bool updateBlockPosFHHelper = false;
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
            if (!S_EnableInfinitePrecisionFreeBlocks) continue;
            if (!IsInEditor) continue;
            // get the cursor
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) continue;
            auto pmt = editor.PluginMapType;
            auto cursor = editor.Cursor;
            if (cursor is null || editor.ItemCursor is null) continue;
            auto itemCursor = DGameCursorItem(editor.ItemCursor);
            bool isSnapping = itemCursor.snappedGlobalIx != -1;
            if (isSnapping) continue;
            // do some checks first
            // if (!Editor::IsInPlacementMode(editor)) continue;
            if (pmt.EditMode != CGameEditorPluginMap::EditMode::Place) continue;
            // bool isPlacingItem = Editor::IsInAnyItemPlacementMode(editor, false);
            // if (!Editor::IsInAnyFreePlacementMode(editor)) continue;
            auto placeMode = pmt.PlaceMode;
            bool isPlacingAnythingFree = placeMode == CGameEditorPluginMap::EPlaceMode::FreeBlock || placeMode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock
                || (placeMode == CGameEditorPluginMap::EPlaceMode::Item && Editor::GetItemPlacementMode() == Editor::ItemMode::Free);
            bool isPlacingItem = placeMode == CGameEditorPluginMap::EPlaceMode::Item;
            if (!isPlacingAnythingFree) continue;
            if (!Editor::IsAnythingBeingDrawn(cursor)) continue;
            if (!cursor.UseFreePos && !isPlacingItem) continue;
            if (!S_EnableInfinitePrecisionFreeBlocks) continue;
            // waiting for game to place stuff
            // skip if we're setting the cursor pos atm
            if (updateBlockPosFHHelper) continue;

            // skip if something else is doing cursor things
            if (!CursorControl::RequestExclusiveControl(farlandsHelperCursorControlName)) continue;

            // auto occ = editor.OrbitalCameraControl;
            auto camTarget = editor.PluginMapType.CameraTargetPosition;
            lastCursorPos = Picker::GetMouseToWorldAtHeight(camTarget.y);
            cursor.FreePosInMap = lastCursorPos;
            if (isPlacingItem) {
                Dev::SetOffset(editor.ItemCursor, O_ITEMCURSOR_CurrentPos, lastCursorPos);
            }
            if (CustomCursorRotations::CustomYawActive &&
                CustomCursorRotations::HasCustomCursorSnappedPos &&
                cursor.UseSnappedLoc
            ) {
                cursor.SnappedLocInMap_Trans = lastCursorPos;
            }

            CursorControl::ReleaseExclusiveControl(farlandsHelperCursorControlName);
        }
    }

    const string farlandsHelperCursorControlName = "FarlandsHelper::CursorLoop";

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
            Dev::Write(rbx + 0xC, float(CustomRotation)); //  % (TAU / 4.)
            // if (Time::Now / 1000 % 2 == 0)
            // dev_trace("Wrote custom rotation: " + CustomRotation);
        }
    }

    // free block stuff
    // return true to block click -- always returns false atm
    bool FH_CheckPlacing() {
        if (!S_EnableInfinitePrecisionFreeBlocks) return false;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return false;
        auto cursor = editor.Cursor;
        // if (!Editor::IsBlockOrMacroblockBeingDrawn(cursor)) return false;
        bool isPlacingItem = Editor::IsInAnyItemPlacementMode(editor);
        if (!Editor::IsAnythingBeingDrawn(cursor)) return false;
        if (!Editor::IsInAnyFreePlacementMode(editor)) return false;
        if (!cursor.UseFreePos && !isPlacingItem) return false;
        if (!Editor::IsInPlacementMode(editor)) return false;

        // if (!Editor::IsInFreeBlockPlacementMode(editor, true)) return false;
        // if (cursor.Color != cursor.CannotPlaceNorJoinColor) return false;

        // instead of trying to figure out if we want to overwrite the cursor, just always do it

        // bool cursorCannotPlaceColor = cursor.Color == cursor.CannotPlaceNorJoinColor;
        // bool cursorOutOfStadium = cursor.FreePosInMap.x < 0 || cursor.FreePosInMap.x > g_MapBounds.x
        //     || cursor.FreePosInMap.z < 0 || cursor.FreePosInMap.z > g_MapBounds.z
        //     || cursor.FreePosInMap.y < 0 || cursor.FreePosInMap.y > g_MapBounds.y
        //     || S_EnableInfinitePrecisionFreeBlocks;
        // if (!cursorOutOfStadium && !cursorCannotPlaceColor) return false;

        if (GetApp().Viewport.Picker.Overlay !is null) return false;
        _addBlockSetPos = cursor.FreePosInMap;
        @_addBlockSetRot = CustomCursorRotations::GetEditorCursorRotations(cursor);
        dev_trace('setting cursor to middle of map');

        cursor.FreePosInMap = _addBlockCursorPos = Editor::GetMapMidpoint(editor.Challenge);
        if (!CustomCursorRotations::HasCustomCursorSnappedPos && cursor.UseSnappedLoc) {
            _addBlockSetPos = cursor.SnappedLocInMap_Trans;
        }
        cursor.SnappedLocInMap_Trans = _addBlockCursorPos;
        // cursor.SnappedLocInMap_Pitch = 0.;
        // cursor.SnappedLocInMap_Roll = 0.;
        // cursor.SnappedLocInMap_Yaw = 0.;
        cursor.Coord = editor.Challenge.Size / 2;
        cursor.Coord.y = 8;
        updateBlockPosFHHelper = true;
        checkedCursorPos = false;

        if (isPlacingItem) {
            Editor::SetItemCursorPos(editor.ItemCursor, _addBlockCursorPos);
        }

        startnew(FH_ResetCursorAfterPlaced).WithRunContext(Meta::RunContext::AfterMainLoop);

        return false;
    }

    void FH_ResetCursorAfterPlaced() {
        yield();
        updateBlockPosFHHelper = false;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;
        // yield()
        cursor.FreePosInMap = _addBlockSetPos;
        cursor.SnappedLocInMap_Trans = _addBlockSetPos;
        Editor::SetItemCursorPos(editor.ItemCursor, _addBlockSetPos);
    }
    vec3 _addBlockSetPos;
    EditorRotation@ _addBlockSetRot;
    vec3 _addBlockCursorPos;

    bool checkedCursorPos = false;

    bool FH_OnBI_CheckCursor() {
        if (!updateBlockPosFHHelper) return false;
        if (!checkedCursorPos) {
            checkedCursorPos = true;
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) return false;
            if (editor.Cursor.FreePosInMap != _addBlockCursorPos) {
                updateBlockPosFHHelper = false;
                dev_trace("Detected bad cursor pos, not updating!!");
            }
        }
        return updateBlockPosFHHelper;
    }

    bool FH_OnAddBlock(CGameCtnBlock@ block) {
        // updateBlockPosFHHelper check implicit in check cursor
        if (!FH_OnBI_CheckCursor()) return false;
        if (!Editor::IsBlockFree(block)) return false;
        auto origPos = Editor::GetBlockLocation(block, true);
        auto finalPos = _addBlockSetPos + origPos - _addBlockCursorPos;
        Editor::SetBlockLocation(block, finalPos);
        // Editor::SetBlockRotation(block, _addBlockSetRot.Euler);
        // dev_trace('set location on block: ' + block.Id.Value + ': ' + origPos.ToString() + ' -> ' + _addBlockSetPos.ToString() + ' (with cursor pos: '+_addBlockCursorPos.ToString()+')');
        // dev_trace('final pos: ' + finalPos.ToString());
        return false;
    }

    bool FH_OnAddItem(CGameCtnAnchoredObject@ item) {
        // updateBlockPosFHHelper check implicit in check cursor
        if (!FH_OnBI_CheckCursor()) return false;
        auto origPos = Editor::GetItemLocation(item);
        auto finalPos = _addBlockSetPos + origPos - _addBlockCursorPos;
        Editor::SetItemLocation(item, finalPos);
        // Editor::SetItemRotation(item, _addBlockSetRot.Euler);
        // dev_trace('set location on block: ' + item.Id.Value + ': ' + origPos.ToString() + ' -> ' + _addBlockSetPos.ToString() + ' (with cursor pos: '+_addBlockCursorPos.ToString()+')');
        // dev_trace('final pos: ' + finalPos.ToString());
        return false;
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
