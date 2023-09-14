class GlobalPlacementOptionsTab : EffectTab {
    GlobalPlacementOptionsTab(TabGroup@ p) {
        super(p, "Next Placed", Icons::FolderOpenO + Icons::Download);
        RegisterNewItemCallback(ProcessItem(this.OnNewItem));
    }

    bool get__IsActive() override property {
        return f_RandomizeItemAnimOffset || f_RandomizeItemsInMbAnimOffsets || f_RandomizeMbAdditionalAnimOffset;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto pmt = editor.PluginMapType;
        pmt.NextMapElemColor = CGameEditorPluginMap::EMapElemColor(DrawColorBtnChoice("NextMapElemColor", pmt.NextMapElemColor));
        pmt.NextItemPhaseOffset = DrawComboEPhaseOffset("NextItemPhaseOffset", pmt.NextItemPhaseOffset);
        pmt.NextMbAdditionalPhaseOffset = DrawComboEPhaseOffset("NextMbAdditionalPhaseOffset", pmt.NextMbAdditionalPhaseOffset);
        // pmt.NextMapElemColor = DrawComboEMapElemColor("NextMapElemColor", pmt.NextMapElemColor);
        pmt.NextMapElemLightmapQuality = DrawComboEMapElemLightmapQuality("NextMapElemLightmapQuality", pmt.NextMapElemLightmapQuality);
        pmt.ForceMacroblockColor = UI::Checkbox("ForceMacroblockColor", pmt.ForceMacroblockColor);
        pmt.ForceMacroblockLightmapQuality = UI::Checkbox("ForceMacroblockLightmapQuality", pmt.ForceMacroblockLightmapQuality);
        editor.PasteAsFreeMacroBlock = UI::Checkbox("PasteAsFreeMacroBlock", editor.PasteAsFreeMacroBlock);

        // todo: paste as air macro block

        if (UI::CollapsingHeader("Animation Offsets")) {
            f_RandomizeItemAnimOffset = UI::Checkbox("Randomize Item Anim Offset", f_RandomizeItemAnimOffset);
            f_RandomizeMbAdditionalAnimOffset = UI::Checkbox("Randomize Mb Additional Anim Offset", f_RandomizeMbAdditionalAnimOffset);
            // f_RandomizeItemsInMbAnimOffsets = UI::Checkbox("Randomize Items In Mb Anim Offsets", f_RandomizeItemsInMbAnimOffsets);
            if (f_RandomizeMbAdditionalAnimOffset) {
                pmt.NextMbAdditionalPhaseOffset = CGameEditorPluginMap::EPhaseOffset(Math::Rand(0, 8));
            }
        }
    }

    bool f_RandomizeItemAnimOffset = false;
    bool f_RandomizeMbAdditionalAnimOffset = false;
    bool f_RandomizeItemsInMbAnimOffsets = false;

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        bool ret;
        if (f_RandomizeItemAnimOffset) {
            item.AnimPhaseOffset = CGameCtnAnchoredObject::EPhaseOffset(Math::Rand(0, 8));
            ret = true;
        }
        if (f_RandomizeMbAdditionalAnimOffset) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            editor.PluginMapType.NextMbAdditionalPhaseOffset = CGameEditorPluginMap::EPhaseOffset(Math::Rand(0, 8));
        }
        return ret;
    }
}
