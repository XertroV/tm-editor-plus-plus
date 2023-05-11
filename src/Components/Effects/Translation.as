// todo: doesn't seem to work, and need to integrate baked blocks.

// class ApplyTranslationTab : GenericApplyTab {

//     ApplyTranslationTab(TabGroup@ p) {
//         super(p, "Apply Translation", Icons::Magic + Icons::Arrows);
//     }

//     vec3 posOff = vec3();
//     nat3 coordsOff = nat3();
//     void DrawInner() override {
//         UI::TextWrapped("Move blocks and items in the map. Optionally filter by name and/or location.");
//         UI::TextWrapped("For application to specific blocks/items, see 'Picked Block/Item'.");
//         UI::Separator();
//         vec3 origPO = posOff;
//         nat3 origCO = coordsOff;
//         posOff = UI::InputFloat3("Position Offset", posOff);
//         coordsOff = UX::InputNat3XYZ("Coords Offset", coordsOff);
//         if (!MathX::Vec3Eq(origPO, posOff)) {
//             coordsOff = PosToCoord(posOff);
//         } else if (!MathX::Nat3Eq(origCO, coordsOff)) {
//             posOff = CoordToPos(coordsOff);
//         }
//         UI::Separator();
//         GenericApplyTab::DrawInner();
//     }

//     void ApplyTo(CGameCtnBlock@ block) override {
//         if (Editor::IsBlockFree(block)) {
//             Editor::SetBlockLocation(block, Editor::GetBlockLocation(block) + posOff);
//         } else {
//             Editor::SetBlockCoord(block, Editor::GetBlockCoord(block) + coordsOff);
//         }
//     }
//     void ApplyTo(CGameCtnAnchoredObject@ item) override {
//         item.AbsolutePositionInMap = posOff + item.AbsolutePositionInMap;
//     }
//     void OnApplyDone() override {

//         Editor::MarkRefreshUnsafe();
//     }
// }
