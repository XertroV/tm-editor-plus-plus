class SetLinkedCheckpointsTab : EffectTab {
    SetLinkedCheckpointsTab(TabGroup@ parent) {
        super(parent, "Auto Link Checkpoints", Icons::Link);
        RegisterNewItemCallback(ProcessItem(this.OnNewItem));
        RegisterNewBlockCallback(ProcessBlock(this.OnNewBlock));
    }

    protected bool _IsActive = false;

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (!_IsActive || item.WaypointSpecialProperty is null)
            return false;
        item.WaypointSpecialProperty.Order = m_order;
        if (m_linked) {
            item.WaypointSpecialProperty.LinkedCheckpointToggle();
        }
        return true;
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        if (!_IsActive || block.WaypointSpecialProperty is null)
            return false;
        block.WaypointSpecialProperty.Order = m_order;
        if (m_linked) {
            block.WaypointSpecialProperty.LinkedCheckpointToggle();
        }
        return true;
    }

    bool m_linked = false;
    uint m_order = 1;

    void DrawInner() override {
        _IsActive = UI::Checkbox("Set new CPs properties", _IsActive);
        UI::BeginDisabled(!_IsActive);
        m_linked = UI::Checkbox("Linked CP?", m_linked);
        UI::SetNextItemWidth(170.0);
        m_order = UI::InputInt("CP Order", m_order);
        UI::EndDisabled();
    }
}
