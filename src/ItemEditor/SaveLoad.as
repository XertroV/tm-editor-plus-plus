namespace ItemEditor {
    bool HasItemBeenSaved() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        return ieditor.ItemModel.IdName != "Unassigned";
    }

    // save the item under this path
    void SaveItemAs(const string &in path) {
        auto frame = GetDialogSaveAs();
        if (frame is null) {
            NotifyWarning("SaveAs dialog does not appear to be open.");
            return;
        }
        SaveAsGoToRoot();
        SaveAsDialogSetPath(path);
        // yield();
        ClickConfirmOpenOrSave();
    }

    // save item with the same name, if it has been saved before
    void SaveItem() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (!HasItemBeenSaved()) {
            NotifyWarning("Cannot save item under same name if it's not yet been saved.");
        } else {
            SaveItemAs(ieditor.ItemModel.IdName);
        }
    }

    CGameMenuFrame@ GetDialogSaveAs() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        auto cf = GetApp().BasicDialogs.Dialogs.CurrentFrame;
        if (cf !is null && cf.IdName == "FrameDialogSaveAs") {
            return cf;
        }
        return null;
    }

    void SaveAsGoToRoot() {
        auto frame = GetDialogSaveAs();
        if (frame is null) return;
        auto buttonUp = cast<CControlButton>(GetFrameChildFromChain(frame, {0, 4, 1, 0}));
        auto entryPath = cast<CControlEntry>(GetFrameChildFromChain(frame, {0, 4, 1, 3}));
        uint count = 0;
        while (string(entryPath.String) != "$3CFItems\\$z") {
            trace(entryPath.String);
            buttonUp.OnAction();
            trace(string(entryPath.String) + " " + count);
            count++;
            if (count > 20) {
                warn('too many up presses');
                break;
            }
            yield();
        }
    }

    void SaveAsDialogSetPath(const string &in savePath) {
        auto frame = GetDialogSaveAs();
        if (frame is null) return;
        auto entryPath = cast<CControlEntry>(GetFrameChildFromChain(frame, {0, 1, 0}));
        cast<CGameDialogs>(entryPath.Nod).String = savePath;
    }

    void ClickConfirmOpenOrSave() {
        auto frame = GetDialogSaveAs();
        if (frame is null) return;
        GetApp().BasicDialogs.DialogSaveAs_OnValidate();
    }

    void ClickOpenItem() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return;
        auto frame = GetDialogSaveAs();
        if (frame !is null) return;
        Editor::DoItemEditorAction(ieditor, Editor::ItemEditorAction::OpenItem);
    }
}

CControlBase@ GetFrameChildFromChain(CControlFrame@ frame, uint[]@ childs) {
    CControlFrame@ next = frame;
    for (uint i = 0; i < childs.Length; i++) {
        auto childIx = childs[i];
        if (i < childs.Length - 1) {
            @next = cast<CControlFrame>(next.Childs[childIx]);
        } else {
            return next.Childs[childIx];
        }
    }
    return null;
}
