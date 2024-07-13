namespace Editor {
    const uint16 O_CURSOR_SUBDIV = GetOffset("CGameCursorBlock", "Subdiv");

    CPlugTree@ GetCursorPlugTree(CGameCursorBlock@ cursor) {
        if (cursor is null || cursor.CursorBox is null || cursor.CursorBox.Mobil is null || !cursor.CursorBox.Mobil.IsVisible)
            return null;
        auto plugTree = Dev::GetOffsetNod(cursor.CursorBox, 0x18);
        return cast<CPlugTree>(plugTree);
    }

    // vec4 GetCursorBoxBB(CGameCursorBlock@ cursor) {
    //     auto tree = GetCursorPlugTree(cursor);

    // }

    // prefer GetCursorRot
    vec3 GetCursorPitchRollYaw(CGameCursorBlock@ cursor) {
        return vec3(cursor.Pitch,
            Math::ToRad(float(cursor.AdditionalDir) / 5.0 * 75.0),
            cursor.Roll);
    }

    EditorRotation@ GetCursorRot(CGameCursorBlock@ cursor) {
        return EditorRotation(cursor);
    }

    void SetAllCursorMat(const mat4 &in mat) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pos = vec3(mat.tx, mat.ty, mat.tz);
        auto invTrans = mat4::Translate(pos * -1);
        // item cursor expects this for some reason
        auto rot = (invTrans * mat);
        SetAllCursorPos(pos);
        auto cursorPYR = PitchYawRollFromRotationMatrix(mat4::Inverse(rot));
        // auto cursorPYR = EulerFromRotationMatrix(rot);
        auto er = EditorRotation(cursorPYR);
        er.SetCursor(editor.Cursor);
        SetItemCursorMat(editor.ItemCursor, mat);
        // SetItemCursorPos(editor.ItemCursor, pos);
        CustomCursorRotations::cursorCustomPYR = cursorPYR;
        CustomCursorRotations::NormalizeCustomYaw(editor.Cursor, editor.Cursor.Dir);
    }

    void SetAllCursorPos(vec3 pos) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.Cursor.FreePosInMap = pos;
        editor.Cursor.Coord = PosToCoord(pos);
        editor.Cursor.UseFreePos = true;
        if (editor.Cursor.UseSnappedLoc) {
            editor.Cursor.SnappedLocInMap_Trans = pos;
        }
        SetItemCursorPos(editor.ItemCursor, pos);
    }

    void SetItemCursorPos(CGameCursorItem@ itemCursor, vec3 pos) {
        Dev::SetOffset(itemCursor, O_ITEMCURSOR_CurrentPos, pos);
    }

    vec3 GetItemCursorPos(CGameCursorItem@ itemCursor) {
        return itemCursor.CurrentPos;
    }

    vec3 GetCursorPos(CGameCtnEditorFree@ editor) {
        if (Editor::IsInAnyItemPlacementMode(editor)) {
            return GetItemCursorPos(editor.ItemCursor);
        } else if (Editor::IsInAnyFreePlacementMode(editor)) {
            return editor.Cursor.FreePosInMap;
        } else {
            return Picker::GetMouseToWorldAtHeight(editor.OrbitalCameraControl.m_TargetedPosition.y);
        }
    }

    mat4 GetItemCursorMat(CGameCursorItem@ itemCursor) {
        // bit of a placeholder. vectors Left, Up, Dir immediately before current pos in memory.
        auto leftOffset = O_ITEMCURSOR_CurrentPos - 0x24;
        // auto upOffset = posOffset - 0x18;
        // auto dirOffset = posOffset - 0xC;
        return mat4(Dev::GetOffsetIso4(itemCursor, leftOffset));
    }

    // note: rotations should be backwards from what you expect
    void SetItemCursorMat(CGameCursorItem@ itemCursor, const mat4 &in mat) {
        auto leftOffset = O_ITEMCURSOR_CurrentPos - 0x24;
        Dev::SetOffset(itemCursor, leftOffset, iso4(mat));
    }

    // 4 bools (A,B,C,D); A,B true for blocks and macroblocks, C true for all, D true for all but items
    bool IsAnythingBeingDrawn(CGameCursorBlock@ cursor) {
        return Dev::GetOffsetUint8(cursor, O_CURSOR_SUBDIV + (0x1F8 - 0x1E4)) == 0x1;
    }
    bool IsBlockOrMacroblockBeingDrawn(CGameCursorBlock@ cursor) {
        return Dev::GetOffsetUint8(cursor, O_CURSOR_SUBDIV + (0x1F0 - 0x1E4)) == 0x1;
    }
    bool IsItemBeingDrawn(CGameCursorBlock@ cursor) {
        return Dev::GetOffsetUint8(cursor, O_CURSOR_SUBDIV + (0x1F8 - 0x1E4)) == 0x1
            && Dev::GetOffsetUint8(cursor, O_CURSOR_SUBDIV + (0x1FC - 0x1E4)) == 0x0
            && Dev::GetOffsetUint8(cursor, O_CURSOR_SUBDIV + (0x1F0 - 0x1E4)) == 0x0;
    }
}




namespace CursorControl {
    bool _ExclusiveControl = false;
    string _ExclusiveControlName = "";

    bool RequestExclusiveControl(const string &in name) {
        if (IsExclusiveControlAvailable()) {
            _ExclusiveControl = true;
            _ExclusiveControlName = name;
            return true;
        }
        return false;
    }

    void ReleaseExclusiveControl(const string &in name) {
        if (_ExclusiveControl && _ExclusiveControlName == name) {
            _ExclusiveControl = false;
            _ExclusiveControlName = "";
        } else {
            warn("Tried to release exclusive control for " + name + " but it was not held. Owner: " + _ExclusiveControlName);
        }
    }

    bool IsExclusiveControlAvailable() {
        return !_ExclusiveControl;
    }
}
