namespace Editor {
    bool IsSpaceBarDown(CGameCtnEditorFree@ editor) {
        return Dev::GetOffsetUint32(editor, O_EDITOR_SPACEHELD) > 0;
    }
}
