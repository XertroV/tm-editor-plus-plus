namespace Editor {
    bool IsSpaceBarDown(CGameCtnEditorFree@ editor) {
        return Dev::GetOffsetUint32(editor, O_EDITOR_SPACEHELD) > 0;
    }

    bool SetSpaceBarDown(CGameCtnEditorFree@ editor, bool down, bool autoLiftNextFrame = false) {
        Dev::SetOffset(editor, O_EDITOR_SPACEHELD, uint(down ? 1 : 0));
        if (autoLiftNextFrame) startnew(SetSpaceBarLiftedAsync);
        return down;
    }

    void SetSpaceBarLiftedAsync() {
        yield();
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        SetSpaceBarDown(editor, false);
    }
}
