namespace CControl {
    CControlBase@ FindChild(CControlContainer@ control, const string &in name) {
        MwId nameId = MwId();
        nameId.SetName(name);
        return FindChild(control, nameId.Value);
    }

    CControlBase@ FindChild(CControlContainer@ control, uint nameVal) {
        if (control is null) return null;
        if (control.Id.Value == nameVal) return control;
        auto nbChildren = control.Childs.Length;
        for (uint i = 0; i < nbChildren; i++) {
            if (control.Childs[i].Id.Value == nameVal) {
                return control.Childs[i];
            }
        }
        return null;
    }

    CControlBase@ FollowIdPath(CControlContainer@ control, string[]@ path) {
        for (uint i = 0; i < path.Length; i++) {
            auto child = FindChild(control, path[i]);
            if (child is null) {
                return null;
            }
            if (i == path.Length - 1) {
                return child;
            }
            @control = cast<CControlContainer>(child);
        }
        return null;
    }

    CControlListCard@ get_Editor_FrameInventoryArticlesCards() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        return cast<CControlListCard>(FollowIdPath(editor.EditorInterface.InterfaceRoot,
            {"FrameMain", "FrameInventories", "FrameInventory", "FrameInventoryArticles", "ListCardArticles"}
        ));
    }

    CControlListCard@ get_Editor_FrameInventoryPluginsArticles() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        return cast<CControlListCard>(FollowIdPath(editor.EditorInterface.InterfaceRoot,
            {"FrameMain", "FrameInventories", "FrameInventoryArticlesPlugins", "ListCardArticles"}
        ));
    }

    CControlButton@ get_Editor_FrameCopyPaste_SaveMacroblock() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        return cast<CControlButton>(FollowIdPath(editor.EditorInterface.InterfaceRoot,
            {"FrameMain", "FrameCopyPasteTools", "FrameMacroblock", "ButtonSelectionBoxSaveNew"}
        ));
    }

    CControlButton@ get_Editor_FrameCopyPaste_Copy() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        return cast<CControlButton>(FollowIdPath(editor.EditorInterface.InterfaceRoot,
            {"FrameMain", "FrameCopyPasteTools", "FrameMacroblock", "FrameButtonCopy", "ButtonSelectionBoxCopy"}
        ));
    }

    CControlButton@ get_Editor_FrameEditSnap_SaveBtn() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        return cast<CControlButton>(FollowIdPath(editor.EditorInterface.InterfaceRoot,
            {"FrameEditSnapCamera", "ButtonOk"}
        ));
    }

    CControlButton@ get_Editor_FrameEditSnap_RotateCameraBtn() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        return cast<CControlButton>(FollowIdPath(editor.EditorInterface.InterfaceRoot,
            {"FrameEditSnapCamera", "ButtonRotateIcon"}
        ));
    }


}


CGameMenuFrame@ GetDialogSaveAs() {
    auto cf = GetApp().BasicDialogs.Dialogs.CurrentFrame;
    if (cf !is null && cf.IdName == "FrameDialogSaveAs") {
        return cf;
    }
    return null;
}

bool SetSaveAsDialogEntryPath(const string &in path) {
    auto frame = GetDialogSaveAs();
    if (frame is null) return false;
    auto entryPath = cast<CControlEntry>(CControl::FollowIdPath(frame, {"FrameContent", "FrameSave", "EntryFileName"}));
    if (entryPath is null) return false;
    auto d = cast<CGameDialogs>(entryPath.Nod);
    if (d is null) return false;
    d.String = path;
    return true;
}

void ClickConfirmOpenOrSaveDialog() {
    auto frame = GetDialogSaveAs();
    if (frame is null) return;
    GetApp().BasicDialogs.DialogSaveAs_OnValidate();
}
