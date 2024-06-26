class ColorApplyTab : GenericApplyTab {
    ColorApplyTab(TabGroup@ p) {
        super(p, "Apply Color", "\\$<\\$44f" + Icons::Magic + "\\$4f4" + Icons::PaintBrush + "\\$>");
    }

    bool showStructurePillarWarning = false;

    int m_color = 4;
    void DrawInner() override {
        UI::TextWrapped("Apply \\$cccc\\$4c4o\\$66fl\\$f44o\\$888r\\$z to blocks and items. Optionally filter by name and/or location.");
        UI::TextWrapped("For application to specific blocks/items, see 'Picked Block/Item'.");
        UI::TextWrapped("For application to next block/item, see 'Next Placed'.");
        UI::Separator();
        m_color = DrawColorBtnChoice("Color to apply", m_color);
        UI::Separator();
        if (UI::Button("Add all Structure Support block types")) {
            auto structures = PillarsChoice::GetStructureObjNames();
            for (uint i = 0; i < structures.Length; i++) {
                InsertUniqueSorted(filteredObjectNames, structures[i]);
            }
            showStructurePillarWarning = true;
        }
        UI::Separator();
        if (showStructurePillarWarning) {
            UI::TextWrapped("\\$f80Note: you might want to remove StructurePillar from the list, they were colored before the May 2024 update.");
            UI::Separator();
            if (filteredObjectNames.Length < 23) {
                showStructurePillarWarning = false;
            }
        }
        GenericApplyTab::DrawInner();
    }

    void ApplyTo(CGameCtnBlock@ block) override {
        block.MapElemColor = CGameCtnBlock::EMapElemColor(m_color);
    }
    void ApplyTo(CGameCtnAnchoredObject@ item) override {
        item.MapElemColor = CGameCtnAnchoredObject::EMapElemColor(m_color);
    }
}
