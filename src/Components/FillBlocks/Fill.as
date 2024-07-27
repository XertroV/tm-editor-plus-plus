namespace FillBlocks {
    CGameEditorPluginMap::EPlaceMode origPlacementMode;

    void OnPluginLoad() {
        AddHotkey(VirtualKey::F, true, false, false, HotkeyFunction(OnFillHotkey), "Fill Selection");
    }

    UI::InputBlocking OnFillHotkey() {
        dev_trace('running enable hotkey');
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        origPlacementMode = editor.PluginMapType.PlaceMode;
        if (!customSelectionMgr.Enable(OnFillSelectionComplete)) {
            warn("FillBlocks::OnFillHotkey: custom selection manager failed to start");
            return UI::InputBlocking::DoNothing;
            // warn_every_60_s('FillBlocks::OnFillHotkey: custom selection manager is already enabled');
        }
        return UI::InputBlocking::Block;
        // blocks editor inputs, unblock next frame
        // Editor::EnableCustomCameraInputs();
        // startnew(Editor::DisableCustomCameraInputs);
    }

    void OnFillSelectionComplete(CGameCtnEditorFree@ editor, CSmEditorPluginMapType@ pmt, nat3 min, nat3 max) {
        Filler@ filler = Filler().WithInitialPlaceMode(origPlacementMode);

        // dev_trace('Running OnFillSelectionComplete');
        // for (uint i = 0; i < pmt.CustomSelectionCoords.Length; i++) {
        //     c = pmt.CustomSelectionCoords[i];
        //     coord = int3(c.x, c.y, c.z);
        //     if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Block) {
        //         pmt.PlaceBlock(block, coord, pmt.CursorDir);
        //     } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::GhostBlock) {
        //         pmt.PlaceGhostBlock(block, coord, pmt.CursorDir);
        //     } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Item) {
        //         NotifyWarning("Item fill mode not implemented yet");
        //         return;
        //     } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Macroblock) {
        //         NotifyWarning("Macroblock fill mode not implemented yet");
        //         return;
        //     } else {
        //         NotifyWarning("Unsupported for fill mode: " + tostring(origPlacementMode));
        //         return;
        //     }
        //     CheckPause();
        //     if (UI::IsKeyPressed(UI::Key::Escape)) {
        //         trace("Exiting fill loop as escape was pressed");
        //         break;
        //     }
        //     // if we exit the editor, this loop would crash the game
        //     if (!IsInEditor) return;
        // }
        // pmt.AutoSave();
    }

    class Filler {
        CGameEditorPluginMap::EPlaceMode placeMode;

        Filler() {}

        Filler@ WithInitialPlaceMode(CGameEditorPluginMap::EPlaceMode placeMode) {
            this.placeMode = placeMode;
            if (!GetObjectFromPM()) {
                warn("Failed to get object from place mode");
                return null;
            }
            return this;
        }

        CGameCtnBlockInfo@ block;
        CGameCtnMacroBlockInfo@ macroblock;
        CGameItemModel@ item;

        bool GetObjectFromPM() {
            if (placeMode == CGameEditorPluginMap::EPlaceMode::Block) {
                @block = selectedBlockInfo is null ? null : selectedBlockInfo.AsBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::GhostBlock) {
                @block = selectedGhostBlockInfo is null ? null : selectedGhostBlockInfo.AsBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::FreeBlock) {
                @block = selectedGhostBlockInfo is null ? null : selectedGhostBlockInfo.AsBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::Macroblock) {
                @macroblock = selectedMacroBlockInfo.AsMacroBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock) {
                @macroblock = selectedMacroBlockInfo.AsMacroBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::Item) {
                @item = selectedItemModel.AsItemModel();
            } else {
                warn("Unsupported place mode: " + tostring(placeMode));
                return false;
            }
            return block !is null || item !is null || macroblock !is null;
        }

        Editor::MacroblockSpec@ GetMacroblockSpec() {
            return Editor::MacroblockSpecPriv();
        }

    }
}
