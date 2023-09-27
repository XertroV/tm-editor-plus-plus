
class IE_AdvancedTab : Tab {
    IE_AdvancedTab(TabGroup@ p) {
        super(p, "Advanced" + NewIndicator, Icons::ExclamationTriangle + Icons::Cogs);
    }

    void DrawInner() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;

        if (UI::Button("Open Item")) {
            Editor::DoItemEditorAction(ieditor, Editor::ItemEditorAction::OpenItem);
        }
        if (UI::Button("Save and Reopen Item")) {
            startnew(ItemEditor::SaveAndReloadItem);
        }

        UI::Separator();

        if (UI::Button("Zero ItemModel Fids")) {
            try {
                MeshDuplication::ZeroFidsUnknownModelNod(im);
                NotifySuccess("Zeroed ItemModel FIDs");
            } catch {
                NotifyError("Exception zeroing fids: " + getExceptionInfo());
            }
        }
        if (UI::Button("Zero ItemModel.EntityModel Fids")) {
            try {
                MeshDuplication::ZeroFidsUnknownModelNod(im.EntityModel);
                NotifySuccess("Zeroed ItemModel.EntityModel FIDs");
            } catch {
                NotifyError("Exception zeroing fids: " + getExceptionInfo());
            }
        }

        UI::Separator();

        UI::Text("Zeroed Fids / Manipulated Pointers: " + ManipPtrs::recentlyModifiedPtrs.Length);
        if (UI::Button("Unzero Fids & Undo ptr manip")) {
            ManipPtrs::RunUnzero();
        }
    }
}
