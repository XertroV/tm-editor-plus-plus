bool g_PlaceMacroblockAirModeActive = false;

class GlobalPlacementOptionsTab : EffectTab {
    GlobalPlacementOptionsTab(TabGroup@ p) {
        super(p, "Next Placed", Icons::FolderOpenO + Icons::Download);
        RegisterNewItemCallback(ProcessItem(this.OnNewItem), this.tabName);
    }

    bool get__IsActive() override property {
        return f_RandomizeItemAnimOffset || f_RandomizeItemsInMbAnimOffsets || f_RandomizeMbAdditionalAnimOffset
            || g_PlaceMacroblockAirModeActive;
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
        AddSimpleTooltip("Appears to not work.");

        UI::Separator();

        editor.UseNewPillars = UI::Checkbox("UseNewPillars (False = No Pillars for MacroBlocks, including paste, but can't enter block air mode)", editor.UseNewPillars);

        editor.ExperimentalFeatures.IsAutoAirMappingEnabled = UI::Checkbox("IsAutoAirMappingEnabled", editor.ExperimentalFeatures.IsAutoAirMappingEnabled);
        AddSimpleTooltip("Can be used to do macroblocks in air mode");
        editor.ExperimentalFeatures.AutoAirMapping_MaxPillarCount = Math::Clamp(UI::InputInt("AutoAirMapping_MaxPillarCount", editor.ExperimentalFeatures.AutoAirMapping_MaxPillarCount), 0, 255);

        g_PlaceMacroblockAirModeActive = UI::Checkbox("Place Macroblocks in Air Mode (Deprecated atl to UseNewPillars)", g_PlaceMacroblockAirModeActive);

        UI::Separator();

        S_HelpPlaceItemsOnFreeBlocks = UI::Checkbox("Help place autorotated items on free blocks", S_HelpPlaceItemsOnFreeBlocks);
        AddSimpleTooltip("Normally, the game doesn't let you place freelay anchorable and autorotated items on free blocks. Checking this box will enable the helper so that you can place these items.\n\nItem Placement Requirements: 0 for GridSnap_HStep and GridSnap_VStep, AutoRotation=true, GhostMode=false, IsFreelyAnchorable=true.");
        DrawInfinitePrecisionSetting();

        if (UI::CollapsingHeader("Animation Offsets")) {
            f_RandomizeItemAnimOffset = UI::Checkbox("Randomize Item Anim Offset", f_RandomizeItemAnimOffset);
            f_RandomizeMbAdditionalAnimOffset = UI::Checkbox("Randomize Mb Additional Anim Offset", f_RandomizeMbAdditionalAnimOffset);
            // f_RandomizeItemsInMbAnimOffsets = UI::Checkbox("Randomize Items In Mb Anim Offsets", f_RandomizeItemsInMbAnimOffsets);
            if (Time::Now - lastUpdate > 100) {
                lastUpdate = Time::Now;
                if (f_RandomizeMbAdditionalAnimOffset) {
                    pmt.NextMbAdditionalPhaseOffset = CGameEditorPluginMap::EPhaseOffset(Math::Rand(0, 8));
                }
                if (f_RandomizeItemAnimOffset) {
                    pmt.NextItemPhaseOffset = CGameEditorPluginMap::EPhaseOffset(Math::Rand(0, 8));
                }
            }
        }
    }

    uint lastUpdate = 0;

    bool f_RandomizeItemAnimOffset = false;
    bool f_RandomizeMbAdditionalAnimOffset = false;
    bool f_RandomizeItemsInMbAnimOffsets = false;

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (!(f_RandomizeItemAnimOffset || f_RandomizeItemsInMbAnimOffsets)) return false;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (f_RandomizeItemAnimOffset) {
            editor.PluginMapType.NextItemPhaseOffset = CGameEditorPluginMap::EPhaseOffset(Math::Rand(0, 8));
        }
        if (f_RandomizeMbAdditionalAnimOffset) {
            editor.PluginMapType.NextMbAdditionalPhaseOffset = CGameEditorPluginMap::EPhaseOffset(Math::Rand(0, 8));
        }
        return false;
    }
}

// true => block click
bool CheckPlaceMacroblockAirMode() {
    // dev_trace('CheckPlaceMacroblockAirMode');
    if (!g_PlaceMacroblockAirModeActive) return false;
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    if (editor is null) return false;
    auto pmt = editor.PluginMapType;
    if (pmt.PlaceMode == CGameEditorPluginMap::EPlaceMode::Macroblock && pmt.CursorMacroblockModel !is null) {
        pmt.PlaceMacroblock_AirMode(pmt.CursorMacroblockModel, Nat3ToInt3(pmt.CursorCoord), pmt.CursorDir);
        pmt.AutoSave();
        return true;
    }
    return false;
}

[Setting hidden]
bool S_HelpPlaceItemsOnFreeBlocks = false;

// true => block click
bool CheckPlacingItemFreeMode() {
    // dev_trace('CheckPlacingItemFreeMode');
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    if (!S_HelpPlaceItemsOnFreeBlocks || editor is null) return false;
    auto picker = GetApp().Viewport.Picker;
    if (picker.Overlay !is null) return false;
    auto pmt = editor.PluginMapType;
    if (Editor::IsInAnyItemPlacementMode(editor, true) && Editor::GetItemPlacementMode() == Editor::ItemMode::Normal) {
        auto coord = Nat3ToInt3(pmt.CursorCoord);
        auto inv = Editor::GetInventoryCache();
        auto article = inv.GetBlockByName("TrackWallSlopeUTop");
        if (article is null) return false;
        auto bm = cast<CGameCtnBlockInfo>(article.GetCollectorNod());
        bool shouldPlace = pmt.CanPlaceBlock_NoDestruction(bm, coord, pmt.CursorDir, false, 0);
        dev_trace('shouldPlace: ' + shouldPlace);
        if (shouldPlace) {
            bool didPlace = pmt.PlaceBlock_NoDestruction(bm, coord, pmt.CursorDir);
            dev_trace('didPlace: ' + didPlace);
            if (didPlace) {
                startnew(_WatchAndCleanUp, array<nat3> = {pmt.CursorCoord}).WithRunContext(Meta::RunContext::AfterMainLoop);
                ExtraUndoFix::DisableUndo();
            }
        }
    } else {
        // dev_trace('not in item mode');
    }
    return false;
}


void _WatchAndCleanUp(ref@ r) {
    ExtraUndoFix::EnableUndo();
    auto coord = cast<nat3[]>(r)[0];
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    if (editor is null) return;
    auto pmt = editor.PluginMapType;
    auto inv = Editor::GetInventoryCache();
    auto article = inv.GetBlockByName("TrackWallSlopeUTop");
    auto bm = cast<CGameCtnBlockInfo>(article.GetCollectorNod());
    auto map = editor.Challenge;
    CGameCtnAnchoredObject@[] moved;
    for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
        if (map.AnchoredObjects[i].BlockUnitCoord == coord) {
            moved.InsertLast(map.AnchoredObjects[i]);
            map.AnchoredObjects[i].BlockUnitCoord.x = uint(-1);
        }
    }
    pmt.RemoveBlockSafe(bm, Nat3ToInt3(coord), pmt.CursorDir);
    for (uint i = 0; i < moved.Length; i++) {
        moved[i].BlockUnitCoord.x = coord.x;
    }
    pmt.AutoSave();
}
