/**
 * bugs:
 * - sometimes the input is missed and (presumably) the cursor is reset before next block is placed
 */

namespace FarlandsHelper {
    float CustomRotation;
    bool FL_Helper_Active;
    bool drawDebugFarlandsHelper = false;
    bool skipNextFrame = false;

    void CursorLoop() {
        if (!FarlandsHelper::Apply()) {
            warn("FAILED TO APPLY FARLANDS HELPER PATCH");
        }
        while (true) {
            yield();
            if (skipNextFrame) {
                yield();
                skipNextFrame = false;
                continue;
            }
            if (!IsInEditor) continue;
            // get the cursor
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            if (editor is null) continue;
            auto cursor = editor.Cursor;
            // do some checks first
            if (!cursor.UseFreePos) continue;
            if (!Editor::IsBlockOrMacroblockBeingDrawn(cursor)) continue;
            if (!Editor::IsInFreeBlockPlacementMode(editor)) continue;
            // check if block cursor is at the edge of the map
            bool atEdge = (0 == cursor.Coord.x * cursor.Coord.y * cursor.Coord.z)
                || (cursor.Coord.x == g_MapCoordBounds.x - 1 || cursor.Coord.y == g_MapCoordBounds.y - 1 || cursor.Coord.z == g_MapCoordBounds.z - 1)
                ;
            if (!atEdge && !S_EnableInfinitePrecisionFreeBlocks) continue;



            auto cam = Camera::GetCurrent();
            auto camPos = Camera::GetCurrentPosition();
            auto camMat = Camera::GetProjectionMatrix();
            auto screen = vec2(Draw::GetWidth(), Draw::GetHeight());

            // if (!atEdge) continue;

            // calculate the position of the cursor based on the ray
            // auto cam = Camera::GetCurrent();
            // auto camPos = Camera::GetCurrentPosition();
            // auto camMat = Camera::GetProjectionMatrix();
            auto picker = cam.m_Picker;
            // auto picker = GetApp().Viewport.Picker;
            auto occ = editor.OrbitalCameraControl;

            auto rayDir = picker.RayDir.xy;
            mat4 translation = mat4::Translate(vec3(cam.Location.tx, cam.Location.ty, cam.Location.tz));
            mat4 rotation = mat4::Inverse(mat4::Inverse(translation) * mat4(cam.Location));
            vec3 up =   (rotation * (vec3(0,1,0))).xyz;
            vec3 left = (rotation * (vec3(-1,0,0))).xyz;
            // vec3 dir =  (rotation * (vec3(0,0,1))).xyz;
            rotation = mat4::Rotate(rayDir.y/1.0, left) * mat4::Rotate(rayDir.x/1.3, up) * rotation;
            auto dir = (rotation * vec3(0,0,1)).xyz;


            // // TL is -1,-1
            // // picker.RayPos.xy / vec2(1.55, 0.88) + vec2(-0.01)
            // auto uv = vec4(picker.InputPos, vec2(-1.)); // picker.PosRect
            // // auto uv = vec4(lastMousePos / screen * -2. + 1., vec2(-1.)) * occ.m_CameraToTargetDistance;
            // DrawTextWithStroke(screen * vec2(.35, .28), "UV: " + uv.ToString() + " / " + (uvCalc / uv.xy).ToString(), vec4(1), 3);
            // auto invProj = mat4::Inverse(camMat);
            // auto equidistDirVec = (invProj * uv);
            // auto edvFromPreCalc = (invProj * uvPre);
            // DrawTextWithStroke(screen * vec2(.35, .32), "equidistDirVec: " + equidistDirVec.ToString(), vec4(1), 3);
            // DrawTextWithStroke(screen * vec2(.65, .32), "edvFromPreCalc: " + edvFromPreCalc.ToString(), vec4(1), 3);
            // // auto dir = equidistDirVec.Normalized().xyz;
            // dir = equidistDirVec.xyz;


            auto yPos = occ.m_TargetedPosition.y;
            auto coef = (yPos - camPos.y) / dir.y;
            auto finalPos = (dir * coef + camPos); // * vec3(1.031, 1, 1.031);
            cursor.FreePosInMap = finalPos;

            if (drawDebugFarlandsHelper) {
                // test drawings as helpers
                auto initPos = cursor.FreePosInMap;
                auto uvPre = (camMat * initPos);
                auto uvCalc = uvPre.xy / uvPre.w;

                nvg::BeginPath();
                nvg::FontSize(30.);

                DrawTextWithStroke(screen * vec2(.35, .16), "start pos " + initPos.ToString(), vec4(1), 3);
                DrawTextWithStroke(screen * vec2(.35, .2), "uvPre from Cam:: " + uvPre.ToString(), vec4(1), 3);
                DrawTextWithStroke(screen * vec2(.35, .24), "uvCalc from Cam:: " + uvCalc.ToString(), vec4(1), 3);

                DrawTextWithStroke(screen * vec2(.35, .36), "dir: " + dir.ToString(), vec4(1), 3);
                DrawTextWithStroke(screen * vec2(.35, .40), "yPos, coef: " + vec2(yPos, coef).ToString(), vec4(1), 3);
                DrawTextWithStroke(screen * vec2(.35, .44), "Pos: " + finalPos.ToString(), vec4(1), 3);
                DrawTextWithStroke(screen * vec2(.35, .48), "init/pos: " + (initPos / finalPos).ToString(), vec4(1), 3);
                nvgCircleWorldPos(initPos, vec4(.3, 1, .3, 1));
                nvgCircleWorldPos(finalPos);
                nvgToWorldPos(finalPos);
                nvgToWorldPos(finalPos * vec3(1, 0, 1) + vec3(0, 8, 0));
                // nvgCircleWorldPos(equidistDirVec);
                nvgCircleScreenPos(lastMousePos, vec4(.2, .5, 1, 1));
            }
        }
    }

    // const string GetRotationPattern = "8B 86 54 01 00 00 48 8B 5C 24 30 89 07 8B 86 58 01 00 00 48 8B 74 24 38 48 8B 7C 24 40 41 89 06 48 83 C4 20 41 5E C3 ??";
    const string GetRotationPattern = "8B 86 54 01 00 00 48 8B 5C 24 30 89 07 8B 86 58 01 00 00 48 8B 74 24 38 48 8B 7C 24 40 41 89 06 48 83 C4 20";

    uint64 getRotationPtr;
    Dev::HookInfo@ getRotationHook;
    bool Apply() {
        if (getRotationHook !is null) return false;
        if (getRotationPtr == 0) {
            getRotationPtr = Dev::FindPattern(GetRotationPattern);
        }
        if (getRotationPtr == 0) {
            warn_every_60_s("Could not find Cursor Get Rotation pattern");
            return false;
        }
        @getRotationHook = Dev::Hook(getRotationPtr, 1, "FarlandsHelper::OnGetCursorRotation", Dev::PushRegisters::SSE);
        return true;
    }

    bool Unapply() {
        if (getRotationHook is null) return false;
        Dev::Unhook(getRotationHook);
        return true;
    }

    void OnGetCursorRotation(uint64 rbx) {
        if (FL_Helper_Active) {
            Dev::Write(rbx, float(CustomRotation));
        }
    }

    bool CheckPlacingFreeBlock() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return false;
        auto cursor = editor.Cursor;
        if (!Editor::IsBlockOrMacroblockBeingDrawn(cursor)) return false;
        if (!cursor.UseFreePos) return false;
        if (!Editor::IsInFreeBlockPlacementMode(editor, true)) return false;
        if (cursor.Color != cursor.CannotPlaceNorJoinColor) return false;
        auto pos = cursor.FreePosInMap;
        auto rot = Editor::GetCursorRot(cursor).euler;

        if (!FarlandsHelper::ApplyAddBlockHook()) {
            warn("FAILED TO APPLY FARLANDS ADD BLOCK PATCH");
        } else {
            dev_trace("Applied on block hook");
        }

        _addBlockSetPos = pos;
        _addBlockSetRot = rot;

        cursor.FreePosInMap = vec3(Math::Rand(0.0, g_MapBounds.x - 32.), Math::Rand(0.0, g_MapBounds.y - 32.), Math::Rand(0.0, g_MapBounds.z - 32.));

        skipNextFrame = true;

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

    uint64 incrBlocksArrayLenPtr;
    Dev::HookInfo@ incrBlocksArrayLenHook;
    bool ApplyAddBlockHook() {
        if (incrBlocksArrayLenHook !is null) return false;
        if (incrBlocksArrayLenPtr == 0) {
            incrBlocksArrayLenPtr = Dev::FindPattern(IncrBlocksArrayLenPattern);
        }
        if (incrBlocksArrayLenPtr == 0) {
            warn_every_60_s("Could not find IncrBlocksArrayLenPattern");
            return false;
        }
        @incrBlocksArrayLenHook = Dev::Hook(incrBlocksArrayLenPtr + 5, 3, "FarlandsHelper::OnAddBlockHook", Dev::PushRegisters::SSE);
        return true;
    }

    bool UnapplyAddBlockHook() {
        if (incrBlocksArrayLenHook is null) return false;
        Dev::Unhook(incrBlocksArrayLenHook);
        @incrBlocksArrayLenHook = null;
        return true;
    }

    vec3 _addBlockSetPos;
    vec3 _addBlockSetRot;

    void OnAddBlockHook(uint64 rdx) {
        print('on add block hook');
        // return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
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



dictionary warnTracker;
void warn_every_60_s(const string &in msg) {
    if (warnTracker is null) return;
    if (warnTracker.Exists(msg)) {
        uint lastWarn = uint(warnTracker[msg]);
        if (Time::Now - lastWarn < 60000) return;
    } else {
        NotifyWarning(msg);
    }
    warnTracker[msg] = Time::Now;
    warn(msg);
}
