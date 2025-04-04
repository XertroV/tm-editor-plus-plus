class MassDeleteTab : GenericApplyTab {
    MassDeleteTab(TabGroup@ p) {
        super(p, "Mass Delete", Icons::Magic + Icons::Trash);
    }

    void DrawInner() override {
        UI::TextWrapped("Delete all specified instances of blocks / items in the map.");
        UI::Separator();
        GenericApplyTab::DrawInner();
    }

    Editor::MacroblockSpec@ mb;

    void BeforeApply() override {
        @mb = Editor::MakeMacroblockSpec();
    }

    void ApplyTo(CGameCtnBlock@ block) override {
        mb.AddBlock(block);
    }

    void ApplyTo(CGameCtnAnchoredObject@ item) override {
        mb.AddItem(item);
    }

    void AfterApply() override {
        if (mb.Length == 0) {
            NotifyWarning("No blocks or items were selected.");
            return;
        }
        Editor::DeleteMacroblock(mb, true);
    }
}
