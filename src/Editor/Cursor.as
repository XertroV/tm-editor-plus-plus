namespace Editor {
    const uint16 O_CURSOR_SUBDIV = GetOffset("CGameCursorBlock", "Subdiv");

    CPlugTree@ GetCursorPlugTree(CGameCursorBlock@ cursor) {
        if (cursor is null || cursor.CursorBox is null || cursor.CursorBox.Mobil is null || !cursor.CursorBox.Mobil.IsVisible)
            return null;
        auto plugTree = Dev::GetOffsetNod(cursor.CursorBox, 0x18);
        return cast<CPlugTree>(plugTree);
    }

    // prefer GetCursorRot
    vec3 GetCursorPitchRollYaw(CGameCursorBlock@ cursor) {
        return vec3(cursor.Pitch,
            Math::ToRad(float(cursor.AdditionalDir) / 5.0 * 75.0),
            cursor.Roll);
    }

    EditorRotation@ GetCursorRot(CGameCursorBlock@ cursor) {
        return EditorRotation(cursor);
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
        auto posOffset = GetOffset(itemCursor, "CurrentPos");
        auto leftOffset = posOffset - 0x24;
        // auto upOffset = posOffset - 0x18;
        // auto dirOffset = posOffset - 0xC;
        return mat4(Dev::GetOffsetIso4(itemCursor, leftOffset));
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
