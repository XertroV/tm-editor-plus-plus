namespace ItemEditor {
    void UpdateThumbnail(uint direction) {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        PressEditThumbnailButton(ieditor);
        yield();
        ChooseEditItemDirection(ieditor, direction);
        yield();
    }

    void PressEditThumbnailButton(CGameEditorItem@ ieditor) {
        auto listCardProperties = cast<CControlContainer>(GetFrameChildFromChain(ieditor.FrameRoot, {4, 1, 0, 1}));
        auto iconFrameIx = FindChildFrameIxWithFirstNodLabeled(listCardProperties, "|ItemProperty|Icon");
        if (iconFrameIx < 0) throw('child frame for icon not found');
        auto buttonParent = cast<CControlContainer>(GetFrameChildFromChain(ieditor.FrameRoot, {4, 1, 0, 1, iconFrameIx, 5}));
        if (buttonParent is null || buttonParent.IdName != "CardParamNod") throw('couldnt find button parent');
        auto btnEdit = buttonParent.Childs[0];
        auto btnNew = buttonParent.Childs[3];
        if (btnEdit.IsVisible) btnEdit.OnAction();
        else if (btnNew.IsVisible) btnNew.OnAction();
    }

    void ChooseEditItemDirection(CGameEditorItem@ ieditor, uint direction) {
        direction = direction % 4;
        auto frame = GetActiveMenu0CurrentFrame_ChooseEnum(ieditor.Game);
        auto label = cast<CControlLabel>(GetFrameChildFromChain(frame, {0, 0, 3, 1}));
        if (label is null || label.Label != "Edit icon:") throw('incorrect dialog open');
        auto gridBtns = cast<CControlGrid>(GetFrameChildFromChain(frame, {0, 0, 2}));
        // first btn import from file, then the 4 directions:
        // SE, NE, NW, SW
        auto btn = cast<CGameControlCardGeneric>(gridBtns.Childs[1 + direction]);
        btn.Childs[0].OnAction();
    }
}

int FindChildFrameIxWithFirstNodLabeled(CControlContainer@ frame, const string &in childLabelName) {
    for (int i = frame.Childs.Length - 1; i >= 0; i--) {
        auto child = cast<CControlContainer>(frame.Childs[i]);
        if (child is null || child.Childs.Length == 0) continue;
        auto firstChild = cast<CControlLabel>(child.Childs[0]);
        if (firstChild is null || childLabelName != string(firstChild.Label)) continue;
        return i;
    }
    return -1;
}

CGameMenuFrame@ GetActiveMenu0CurrentFrame(CGameCtnApp@ app) {
    if (app.ActiveMenus.Length == 0) return null;
    return app.ActiveMenus[0].CurrentFrame;
}

CGameMenuFrame@ GetActiveMenu0CurrentFrame_ChooseEnum(CGameCtnApp@ app) {
    auto cf = GetActiveMenu0CurrentFrame(app);
    if (cf is null || cf.IdName != "FrameDialogChooseEnum") return null;
    return cf;
}
