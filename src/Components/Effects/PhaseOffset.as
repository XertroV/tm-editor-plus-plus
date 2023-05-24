class PhaseOffsetApplyTab : GenericApplyTab {
    PhaseOffsetApplyTab(TabGroup@ p) {
        super(p, "Apply Phase Offset", Icons::Magic + Icons::ClockO);
        RegisterNewItemCallback(ProcessItem(ApplyEffect));
    }

    bool ApplyEffect(CGameCtnAnchoredObject@ item) {
        if (!_IsActive) return false;
        ApplyTo(item);
        return true;
    }



    CGameCtnAnchoredObject::EPhaseOffset m_Phase = CGameCtnAnchoredObject::EPhaseOffset::None;
    void DrawInner() override {
        UI::TextWrapped("Apply a phase offset to items. Optionally filter by name and/or location.");
        UI::TextWrapped("For application to specific items, see 'Picked Block/Item'.");
        UI::Separator();
        m_Phase = DrawComboEPhaseOffset("Phase Offset", m_Phase);
        UI::Separator();
        _IsActive = UI::Checkbox("Force new items to selected Phase Offset (works for macroblocks)", _IsActive);
        UI::TextWrapped("Note: you'll need to refresh items manually, or save and reload the map for the update to apply.");
        UI::Separator();
        GenericApplyTab::DrawInner();
    }

    void ApplyTo(CGameCtnBlock@ block) override {
    }
    void ApplyTo(CGameCtnAnchoredObject@ item) override {
        item.AnimPhaseOffset = m_Phase;
    }
}
