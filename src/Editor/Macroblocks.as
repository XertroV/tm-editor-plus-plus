namespace Editor {
    void SetSelectedMacroBlockInfo(CGameCtnEditorFree@ editor, CGameCtnMacroBlockInfo@ mbi) {
        if (mbi is editor.CurrentMacroBlockInfo) return;
        auto prevMBI = editor.CurrentMacroBlockInfo;
        if (prevMBI !is null) {
            prevMBI.MwRelease();
            Dev::SetOffset(editor, O_EDITOR_CurrentMacroBlockInfo, null);
        }
        if (mbi is null) return;
        Dev::SetOffset(editor, O_EDITOR_CurrentMacroBlockInfo, mbi);
        mbi.MwAddRef();
    }

    void SetCopyPasteMacroBlockInfo(CGameCtnEditorFree@ editor, CGameCtnMacroBlockInfo@ mbi) {
        if (mbi is editor.CopyPasteMacroBlockInfo) return;
        auto prevMBI = editor.CopyPasteMacroBlockInfo;
        if (prevMBI !is null) {
            prevMBI.MwRelease();
            Dev::SetOffset(editor, O_EDITOR_CopyPasteMacroBlockInfo, null);
        }
        if (mbi is null) return;
        Dev::SetOffset(editor, O_EDITOR_CopyPasteMacroBlockInfo, mbi);
        mbi.MwAddRef();
    }

    // returns the macroblock info depending on copy/paste mode or not
    CGameCtnMacroBlockInfo@ GetCursorMacroBlockInfo(CGameCtnEditorFree@ editor) {
        if (Editor::IsInCopyPasteMode(editor, false)) {
            return editor.CopyPasteMacroBlockInfo;
        }
        return editor.CurrentMacroBlockInfo;
    }
}
