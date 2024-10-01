namespace FillBlocks {
    CGameEditorPluginMap::EPlaceMode origPlacementMode;
    bool origAirMode;
    uint objVariant;


    void OnPluginLoad() {
        AddHotkey(VirtualKey::F, true, false, false, HotkeyFunction(OnFillHotkey), "Fill Selection");
    }

    UI::InputBlocking OnFillHotkey() {
        dev_trace('running enable hotkey');
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        origPlacementMode = editor.PluginMapType.PlaceMode;
        origAirMode = Editor::GetIsBlockAirModeActive(editor);
        objVariant = Editor::GetCurrentBlockVariant(editor.Cursor);
        if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Item) {
            try {
                objVariant = editor.CurrentItemModel.DefaultPlacementParam_Content.PlacementClass.CurVariant;
            } catch {
                warn("Failed to get item variant! " + getExceptionInfo());
                objVariant = 0;
            }
        }
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

    vec3 fillObjSize;

    void OnFillSelectionComplete(CGameCtnEditorFree@ editor, CSmEditorPluginMapType@ pmt, nat3 min, nat3 max, vec3 coordSize) {
        fillObjSize = coordSize;
        Filler@ filler = Filler().WithInitialPlaceMode(origPlacementMode, origAirMode)
            .WithMinMax(min, max);
        Editor::PlaceMacroblock(filler.GetMacroblockSpec(), true);

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
        bool isAirMode;

        Filler() {}

        Filler@ WithInitialPlaceMode(CGameEditorPluginMap::EPlaceMode placeMode, bool isAirMode) {
            this.isAirMode = isAirMode;
            this.placeMode = placeMode;
            if (!GetObjectFromPM()) {
                warn("Failed to get object from place mode");
                return null;
            }
            return this;
        }

        Filler@ WithMinMax(nat3 min, nat3 max) {
            this.min = CoordToPos(min);
            this.max = CoordToPos(max + nat3(1, 1, 1));
            return this;
        }

        // min of selection in world space
        vec3 min;
        // max of selection in world space
        vec3 max;

        CGameCtnBlockInfo@ block;
        CGameCtnMacroBlockInfo@ macroblock;
        CGameItemModel@ item;

        bool GetObjectFromPM() {
            if (placeMode == CGameEditorPluginMap::EPlaceMode::Block) {
                @block = selectedBlockInfo is null ? null : selectedBlockInfo.AsBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::GhostBlock
                    || placeMode == CGameEditorPluginMap::EPlaceMode::FreeBlock) {
                @block = selectedGhostBlockInfo is null ? null : selectedGhostBlockInfo.AsBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::Macroblock
                    || placeMode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock) {
                @macroblock = selectedMacroBlockInfo.AsMacroBlockInfo();
            } else if (placeMode == CGameEditorPluginMap::EPlaceMode::Item) {
                @item = selectedItemModel.AsItemModel();
            } else {
                warn("Unsupported place mode: " + tostring(placeMode));
                return false;
            }
            return block !is null || item !is null || macroblock !is null;
        }

        bool IsModeOnGrid() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::Block
                || placeMode == CGameEditorPluginMap::EPlaceMode::GhostBlock
                || placeMode == CGameEditorPluginMap::EPlaceMode::Macroblock;
        }

        bool IsModeAnyBlock() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::Block
                || placeMode == CGameEditorPluginMap::EPlaceMode::GhostBlock
                || placeMode == CGameEditorPluginMap::EPlaceMode::FreeBlock;
        }

        bool IsModeAnyItem() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::Item;
        }

        bool IsModeAnyMacroblock() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::Macroblock
                || placeMode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
        }

        bool IsModeFree() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::FreeBlock
                || placeMode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
        }

        bool IsModeGhost() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::GhostBlock;
        }

        bool IsModeNormal() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::Block
                || placeMode == CGameEditorPluginMap::EPlaceMode::Macroblock
                || placeMode == CGameEditorPluginMap::EPlaceMode::Item;
        }

        bool IsModeAir() {
            return isAirMode;
        }

        Editor::MacroblockSpec@ GetMacroblockSpec() {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            auto mb = Editor::MacroblockSpecPriv();
            auto cursorRot = CustomCursorRotations::GetEditorCursorRotations(editor.Cursor);
            if (IsModeOnGrid()) @cursorRot = EditorRotation(editor.Cursor);
            PopulateMacroblockSpec(mb, cursorRot);
            return mb;
        }

        array<vec3>@ GetFillLocations() {
            array<vec3> locs;
            for (float x = min.x; x < max.x; x += fillObjSize.x) {
                for (float y = min.y; y < max.y; y += fillObjSize.y) {
                    for (float z = min.z; z < max.z; z += fillObjSize.z) {
                        locs.InsertLast(vec3(x, y, z));
                    }
                }
            }
            return locs;
        }

        void PopulateMacroblockSpec(Editor::MacroblockSpecPriv@ mb, EditorRotation@ cursorRot) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            auto locs = GetFillLocations();
            // bool normal = IsModeNormal();
            bool ghost = IsModeGhost();
            bool free = IsModeFree();
            bool airMode = IsModeAir();
            if (block !is null) {
                for (uint i = 0; i < locs.Length; i++) {
                    auto b = Editor::MakeBlockSpec(block, locs[i], cursorRot.Euler);
                    // reset flags
                    b.SetToNormal();
                    // set ghost/free if needed
                    if (ghost) b.isGhost = true;
                    else if (free) b.isFree = true;
                    // only set ground if not ghost or free
                    // else b.isGround = locs[i].y == 0.0;
                    b.variant = objVariant;
                    mb.AddBlock(b);
                }
            } else if (macroblock !is null) {
                for (uint i = 0; i < locs.Length; i++) {
                    mb.AddMacroblock(macroblock, locs[i], cursorRot.Euler);
                }
            } else if (item !is null) {
                for (uint i = 0; i < locs.Length; i++) {
                    auto itemSpec = Editor::MakeItemSpec(item, locs[i], cursorRot.Euler);
                    itemSpec.variantIx = objVariant;
                    mb.AddItem(itemSpec);
                }
            }
        }
    }
}
