namespace ItemEditor {
    bool HasItemBeenSaved() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        return ieditor.ItemModel.IdName != "Unassigned";
    }

    // save the item under this path
    void SaveItemAs(const string &in path) {
        auto frame = GetDialogSaveAs();
        if (frame is null) {
            auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
            Editor::DoItemEditorAction(ieditor, Editor::ItemEditorAction::SaveItem);
            yield();
            @frame = GetDialogSaveAs();
        }
        if (frame is null) {
            NotifyWarning("SaveAs dialog does not appear to be open.");
            throw("SaveAs dialog does not appear to be open.");
            return;
        }
        SaveAsGoToRoot();
        SaveAsDialogSetPath(path);
        yield();
        trace('saving');
        ClickConfirmOpenOrSave();
        yield();
        trace('check for overwrite');
        CheckForOverwriteDialogAndClose();
        yield();
        CheckForFailureMessage();
        yield();
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

    void UpdateThumbnailAndSaveItem() {
        trace('Auto updating thumbnail and resaving item.');
        ItemEditor::UpdateThumbnail(S_AutoThumbnailDirection);
        ItemEditor::SaveItem();
    }

    // Warning! Will unzero FIDs after it's been triggered.
    void SaveAndReloadItem() {
        SaveAndReloadItem(true);
    }

    void SaveAndReloadItem(bool unzero) {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return;
        if (!HasItemBeenSaved()) {
            NotifyError("Please save the item first.\n\nYou must have first saved the item.");
        } else {
            SaveItem();
            yield();
            OpenItem(ieditor.ItemModel.IdName);
            yield();
            if (unzero) {
                ManipPtrs::RunUnzero();
            }
            yield();
            SaveItem();
            yield();
            if (S_UpdateItemThumbnailAfterReload) {
                UpdateThumbnailAndSaveItem();
            }
        }
    }

    void OpenItem(const string &in path) {
        ClickOpenItem();
        yield();
        SaveAsGoToRoot();
        SaveAsDialogSetPath(path);
        ClickConfirmOpenOrSave();
        yield();
    }

    void CheckForOverwriteDialogAndClose() {
        auto frame = GetDialogYesNo();
        if (frame is null) {
            trace('no overwrite dialog found');
            return;
        }
        // while ((@frame = GetDialogYesNo()) is null)
        auto labelMsg = cast<CControlLabel>(GetFrameChildFromChain(frame, {1, 0, 2, 0}));
        bool checksOut = labelMsg.Label.StartsWith("The file")
            && labelMsg.Label.EndsWith(" already exists.\nOverwrite it?");
        if (!checksOut) return;
        // auto yesBtn = cast<CControlLabel>(GetFrameChildFromChain(frame, {1, 0, 2, 1, 0}));
        GetApp().BasicDialogs.AskYesNo_Yes();
        // yield();
    }

    void CheckForFailureMessage() {
        // auto frame = GetDialogYesNo();
        // auto labelMsg = cast<CControlLabel>(GetFrameChildFromChain(frame, {1, 0, 2, 0}));
        // bool checksOut = labelMsg.Label.StartsWith("The file")
        //     && labelMsg.Label.EndsWith(" already exists.\nOverwrite it?");
        // if (!checksOut) return;
        // // auto yesBtn = cast<CControlLabel>(GetFrameChildFromChain(frame, {1, 0, 2, 1, 0}));
        // GetApp().BasicDialogs.AskYesNo_Yes();
        // // yield();
    }

    CGameMenuFrame@ GetDialogYesNo() {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null) return null;
        auto cf = GetApp().BasicDialogs.Dialogs.CurrentFrame;
        if (cf !is null && cf.IdName == "FrameAskYesNo") {
            return cf;
        } else if (cf !is null) {
            trace('yes no dialog expected but got named: ' + cf.IdName);
        }
        return null;
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
        while (string(entryPath.String) != "$3CFItems\\$z" && string(entryPath.String) != "$3CFBlocks\\$z") {
            trace(entryPath.String);
            auto nbSlashes = string(entryPath.String).Split("\\").Length;
            auto bd = GetApp().BasicDialogs;
            for (uint i = 0; i < nbSlashes - 2; i++) {
                bd.DialogSaveAs_HierarchyUp();
            }
            // buttonUp.OnAction();
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

CControlBase@ GetFrameChildFromChain(CControlContainer@ frame, uint[]@ childs) {
    CControlContainer@ next = frame;
    for (uint i = 0; i < childs.Length; i++) {
        auto childIx = childs[i];
        // trace('getting child ' + i + ' at ix ' + childIx);
        if (i < childs.Length - 1) {
            @next = cast<CControlContainer>(next.Childs[childIx]);
            // trace('got child: ' + next.IdName);
        } else {
            return next.Childs[childIx];
        }
    }
    return null;
}
