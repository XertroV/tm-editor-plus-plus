class PhaseOffsetApplyTab : GenericApplyTab {
    PhaseOffsetApplyTab(TabGroup@ p) {
        super(p, "Apply Phase Offset", Icons::Magic + Icons::ClockO);
        RegisterNewItemCallback(ProcessItem(ApplyEffect), this.tabName);
    }

    bool ApplyEffect(CGameCtnAnchoredObject@ item) {
        if (!_IsActive) return false;
        ApplyTo(item);
        return true;
    }


    CGameCtnAnchoredObject::EPhaseOffset m_Phase = CGameCtnAnchoredObject::EPhaseOffset::None;
    bool m_SetRandPhase = false;
    bool m_DistributeRandPhases = false;
    void DrawInner() override {
        UI::TextWrapped("Apply a phase offset to items. Optionally filter by name and/or location.");
        UI::TextWrapped("For application to specific items, see 'Picked Block/Item'.");
        UI::Separator();
        m_SetRandPhase = UI::Checkbox("Set Random Phase Offset", m_SetRandPhase);
        AddSimpleTooltip("Enable/disable this to change the other options");
        UI::BeginDisabled(!m_SetRandPhase);
        // UI::SameLine();
        // m_DistributeRandPhases = UI::Checkbox("Evenly Distribute Random Phases", m_DistributeRandPhases);
        UI::EndDisabled();
        UI::BeginDisabled(m_SetRandPhase);
        m_Phase = DrawComboEPhaseOffset("Set Phase Offset", m_Phase);
        UI::EndDisabled();
        UI::Separator();
        _IsActive = UI::Checkbox("Force new items to selected Phase Offset (works for macroblocks)", _IsActive);
        UI::TextWrapped("Note: you'll need to refresh items manually, or save and reload the map for the update to apply.");
        UI::Separator();
        GenericApplyTab::DrawInner();
    }

    void ApplyTo(CGameCtnBlock@ block) override {
    }
    void ApplyTo(CGameCtnAnchoredObject@ item) override {
        if (m_SetRandPhase) {
            if (m_DistributeRandPhases) {
                item.AnimPhaseOffset = CGameCtnAnchoredObject::EPhaseOffset(Math::Rand(0, 8));
            } else {
                item.AnimPhaseOffset = CGameCtnAnchoredObject::EPhaseOffset(Math::Rand(0, 8));
            }
        } else {
            item.AnimPhaseOffset = m_Phase;
        }
    }
}
