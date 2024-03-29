class ApplyTranslationTab : GenericApplyTab {

    ApplyTranslationTab(TabGroup@ p) {
        super(p, "Apply Translation", Icons::Magic + Icons::Arrows);
    }

    vec3 posOff = vec3();
    int3 coordsOff = int3();
    void DrawInner() override {
        UI::TextWrapped("Move blocks and items in the map. Optionally filter by name and/or location.");
        UI::TextWrapped("\\$f80Note:\\$z Normal/Ghost blocks cannot be moved outside of the map base (but Free blocks can).");

        UI::TextWrapped("For application to specific blocks/items, see 'Picked Block/Item'.");
        UI::Separator();
        vec3 origPO = posOff;
        int3 origCO = coordsOff;
        posOff = UI::InputFloat3("Position Offset", posOff);
        coordsOff = UX::InputInt3XYZ("Coords Offset", coordsOff);
        if (!MathX::Vec3Eq(origPO, posOff)) {
            coordsOff = PosToCoordDist(posOff);
        } else if (!MathX::Int3Eq(origCO, coordsOff)) {
            posOff = CoordDistToPos(coordsOff);
        }
        UI::Separator();
        GenericApplyTab::DrawInner();
    }

    void ApplyTo(CGameCtnBlock@ block) override {
        if (Editor::IsBlockFree(block)) {
            Editor::SetBlockLocation(block, Editor::GetBlockLocation(block) + posOff);
        } else {
            Editor::SetBlockCoord(block, Editor::GetBlockCoord(block) + Int3ToNat3(coordsOff));
        }
    }
    void ApplyTo(CGameCtnAnchoredObject@ item) override {
        item.AbsolutePositionInMap = posOff + item.AbsolutePositionInMap;
    }
    void OnApplyDone() override {
        Editor::MarkRefreshUnsafe();
    }
}
