class GlobalPlacementOptionsTab : Tab {
    GlobalPlacementOptionsTab(TabGroup@ p) {
        super(p, "Next Placed", Icons::FolderOpenO + Icons::Download);
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
    }
}
