namespace Editor {
    CPlugTree@ GetCursorPlugTree(CGameCursorBlock@ cursor) {
        if (cursor is null || cursor.CursorBox is null || cursor.CursorBox.Mobil is null || !cursor.CursorBox.Mobil.IsVisible)
            return null;
        auto plugTree = Dev::GetOffsetNod(cursor.CursorBox, 0x18);
        return cast<CPlugTree>(plugTree);
    }

    // prefer GetCursorRot
    vec3 GetCursorPitchRollYaw(CGameCursorBlock@ cursor) {
        return vec3(cursor.Pitch,
            float(cursor.AdditionalDir) / 5.0 * 75.0 / 180.0 * Math::PI,
            cursor.Roll);
    }

    EditorRotation@ GetCursorRot(CGameCursorBlock@ cursor) {
        return EditorRotation(cursor);
    }
}
