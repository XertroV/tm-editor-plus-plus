// class ItemEditMacroVariationsTab : Tab {
//     ItemEditMacroVariationsTab(TabGroup@ p) {
//         super(p, "Create Variants", Icons::ListOl + Icons::FloppyO);
//     }

//     CGameItemModel@ GetItemModel() {
//         auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
//         if (ieditor is null) return null;
//         return ieditor.ItemModel;
//     }

//     void DrawInner() override {
//         Tab::DrawInner();

//     }
// }
