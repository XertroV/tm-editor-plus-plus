class ColorApplyTab : GenericApplyTab {
    ColorApplyTab(TabGroup@ p) {
        super(p, "Apply Color", Icons::Magic + Icons::PaintBrush);
    }

    int m_color = 4;
    void DrawInner() override {
        UI::TextWrapped("Apply \\$cccc\\$4c4o\\$66fl\\$f44o\\$888r\\$z to blocks and items. Optionally filter by name and/or location.");
        UI::TextWrapped("For application to specific blocks/items, see 'Picked Block/Item'.");
        UI::TextWrapped("For application to next block/item, see 'Next Placed'.");
        UI::Separator();
        m_color = DrawColorBtnChoice("Color to apply", m_color);
        UI::Separator();
        GenericApplyTab::DrawInner();
    }

    void ApplyTo(CGameCtnBlock@ block) override {
        block.MapElemColor = CGameCtnBlock::EMapElemColor(m_color);
    }

    void ApplyTo(CGameCtnAnchoredObject@ item) override {
        item.MapElemColor = CGameCtnAnchoredObject::EMapElemColor(m_color);
    }
}
