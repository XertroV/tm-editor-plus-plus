class SetAllCheckpointsTab : EffectTab {
    SetAllCheckpointsTab(TabGroup@ parent) {
        super(parent, "Set All Checkpoints", Icons::Link);
    }

    protected bool SafetyDisabled = false;

    bool m_toItems = true;
    bool m_toBlocks = true;
    bool m_linked = false;
    uint m_order = 1;

    void DrawInner() override {
        SafetyDisabled = UI::Checkbox("Enable (Safety Check)", SafetyDisabled);
        UI::BeginDisabled(!SafetyDisabled);
        m_toItems = UI::Checkbox("Apply to Items", m_toItems);
        m_toBlocks = UI::Checkbox("Apply to Blocks", m_toBlocks);
        m_linked = UI::Checkbox("Linked CP?", m_linked);
        UI::SetNextItemWidth(170.0);
        m_order = UI::InputInt("CP Order", m_order);
        if (UI::Button("Set ALL CPs to this status")) {
            SetAllCPsOrder();
        }
        UI::EndDisabled();
    }

    void SetAllCPsOrder() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        if (m_toBlocks) {
            trace("setting Blocks");
            for (uint i = 0; i < map.Blocks.Length; i++) {
                if (SetBlock(map.Blocks[i])) {
                    trace("set block");
                }
            }
        }
        if (m_toItems) {
            trace("setting Items");
            for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
                if (SetItem(map.AnchoredObjects[i])) {
                    trace("set item");
                }
            }
        }
    }

    bool SetItem(CGameCtnAnchoredObject@ item) {
        if (!SafetyDisabled || item.WaypointSpecialProperty is null) return false;
        if (item.WaypointSpecialProperty.Tag == "Spawn" || item.WaypointSpecialProperty.Tag == "Goal") return false;
        item.WaypointSpecialProperty.Order = m_order;
        if (m_linked ^^ item.WaypointSpecialProperty.Tag.StartsWith("Linked")) {
            item.WaypointSpecialProperty.LinkedCheckpointToggle();
        }
        return true;
    }

    bool SetBlock(CGameCtnBlock@ block) {
        if (!SafetyDisabled || block.WaypointSpecialProperty is null) return false;
        if (block.WaypointSpecialProperty.Tag == "Spawn" || block.WaypointSpecialProperty.Tag == "Goal") return false;
        block.WaypointSpecialProperty.Order = m_order;
        if (m_linked ^^ block.WaypointSpecialProperty.Tag.StartsWith("Linked")) {
            block.WaypointSpecialProperty.LinkedCheckpointToggle();
        }
        return true;
    }
}
