namespace FillBlocks {
    CGameEditorPluginMap::EPlaceMode origPlacementMode;
    bool origAirMode;
    uint objVariant;
    CGameEditorPluginMap::EMapElemColor currColor = CGameEditorPluginMap::EMapElemColor::Default;


    void OnPluginLoad() {
        AddHotkey(VirtualKey::F, true, false, false, HotkeyFunction(OnFillHotkey), "Fill Selection");
    }

    EditorRotation@ fillCursorRot;

    UI::InputBlocking OnFillHotkey() {
        dev_trace('running enable hotkey');
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        origPlacementMode = editor.PluginMapType.PlaceMode;
        origAirMode = Editor::GetIsBlockAirModeActive(editor);
        objVariant = Editor::GetCurrentBlockVariant(editor.Cursor);
        currColor = editor.PluginMapType.NextMapElemColor;
        @fillCursorRot = Editor::GetCursorRot(editor.Cursor);
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

        if (filler.IsBig() || filler.IsModeFree() || filler.IsModeAnyItem()) {
            ShowPrompt_FillWindow(filler);
            AwaitPrompt_FillWindow();
            if (PromptCanceled_FillWindow()) {
                warn("Fill canceled by user");
                return;
            }
        }

        // if using world coords, rotate item obj size to match cursor rotation
        if (!w_RotateFillDirToLocal && filler.IsModeAnyItem() && Editor::IsEastOrWest(int(editor.Cursor.Dir))) {
            fillObjSize = vec3(fillObjSize.z, fillObjSize.y, fillObjSize.x);
        }

        auto mb = filler.GetMacroblockSpec();
        Editor::MacroblockSpec@[]@ chunks;
        if (w_ApplyInChunks) {
            @chunks = mb.CreateChunks(w_ChunkSize);
        } else {
            @chunks = { mb };
        }
        for (uint i = 0; i < chunks.Length; i++) {
            bool isLast = i == chunks.Length - 1;
            Editor::PlaceMacroblock(chunks[i], isLast);
            CheckPause();
            if (UI::IsKeyPressed(UI::Key::Escape)) {
                trace("Exiting fill loop as escape was pressed");
                break;
            }
            // if we exit the editor, this loop would crash the game
            if (!IsInEditor) return;
        }
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

        // Block free modes
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

        // free block, mb, item
        bool IsModeAnyFree() {
            return IsModeFree() || IsModeAnyItem();
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
            vec3 axes = fillObjSize;
            // create a lot of buffer in start,end
            vec3 start = min - (max - min);
            vec3 end = max + (max - min);
            vec3 midPoint = (start + end) / 2;

            vec3 left = vec3(axes.x, 0, 0);
            vec3 up = vec3(0, axes.y, 0);
            vec3 forward = vec3(0, 0, axes.z);

            if (w_RotateFillDirToLocal && this.IsModeAnyFree()) {
                auto mat = fillCursorRot.GetMatrix();
                left = EnsurePositive((mat * left).xyz, Axis::X);
                up = EnsurePositive((mat * up).xyz, Axis::Y);
                forward = EnsurePositive((mat * forward).xyz, Axis::Z);
            }

            vec3[] @along_x = {midPoint};
            vec3[] @along_xy = {};
            vec3[] @along_xyz = {};

            vec3 p = midPoint;
            vec3 dir = left;
            for (float sign = -1; sign <= 1; sign += 2) {
                dir = left * sign;
                p = midPoint + dir;
                while (MathX::Within(p, start, end)) {
                    along_x.InsertLast(p);
                    p += dir;
                }
            }

            dir = up;
            for (uint i = 0; i < along_x.Length; i++) {
                p = along_x[i];
                along_xy.InsertLast(p);
                for (float sign = -1; sign <= 1; sign += 2) {
                    dir = up * sign;
                    p = along_x[i] + dir;
                    while (MathX::Within(p, start, end)) {
                        along_xy.InsertLast(p);
                        p += dir;
                    }
                }
            }

            dir = forward;
            for (uint i = 0; i < along_xy.Length; i++) {
                p = along_xy[i];
                along_xyz.InsertLast(p);
                for (float sign = -1; sign <= 1; sign += 2) {
                    dir = forward * sign;
                    p = along_xy[i] + dir;
                    while (MathX::Within(p, start, end)) {
                        along_xyz.InsertLast(p);
                        p += dir;
                    }
                }
            }

            auto nearlyMax = max - vec3(0.01);
            for (uint i = 0; i < along_xyz.Length; i++) {
                if (MathX::Within(along_xyz[i], min, nearlyMax)) {
                    locs.InsertLast(along_xyz[i]);
                }
            }


            return locs;
        }

        /*
        correctly rotates blocks, but does not fill in the area (rather translates the area too)


            for (float x = start.x; x < end.x; x += axes.x) {
                for (float y = start.y; y < end.y; y += axes.y) {
                    for (float z = start.z; z < end.z; z += axes.z) {
                        locs.InsertLast(vec3(x, y, z));
                    }
                }
            }
            if (w_RotateFillDirToLocal) {
                auto mat = fillCursorRot.GetMatrix();
                mat = mat4::Translate(start) * mat * mat4::Translate(start * -1);
                for (uint i = 0; i < locs.Length; i++) {
                    locs[i] = (mat * locs[i]).xyz;
                }
            }
        */

        // Size in nb of objects
        vec3 GetNbObjectsVec3() {
            return (max - min) / fillObjSize;
        }

        // Size in world space
        vec3 GetVolume() {
            return (max - min);
        }



        bool IsBig() {
            auto size = GetNbObjectsVec3();
            // 2304 = 48 * 48; so this will let us do a no-ground for a standard 48x48 map
            return size.x * size.y * size.z > 2304;
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
                    b.color = CGameCtnBlock::EMapElemColor(int(currColor));
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
                    itemSpec.color = CGameCtnAnchoredObject::EMapElemColor(int(currColor));
                    mb.AddItem(itemSpec);
                }
            }
        }
    }




    // MARK: Window

    bool w_FillPrompt = false;
    bool w_FillPromptCanceled = false;
    Filler@ w_Filler;
    vec3 w_origFillObjSize;
    bool w_ApplyInChunks = false;
    const int CHUNKSIZE_DEFAULT = 2304;
    int w_ChunkSize = CHUNKSIZE_DEFAULT;
    bool w_RotateFillDirToLocal = false;


    void ShowPrompt_FillWindow(Filler@ filler) {
        w_FillPrompt = true;
        w_FillPromptCanceled = false;
        @w_Filler = filler;
        w_origFillObjSize = fillObjSize;
    }

    void AwaitPrompt_FillWindow() {
        while (w_FillPrompt) {
            yield();
        }
        @w_Filler = null;
    }

    bool PromptCanceled_FillWindow() {
        return w_FillPromptCanceled;
    }

    void RenderFillPrompt() {
        if (!w_FillPrompt) return;
        auto fillVol = w_Filler.GetVolume();
        nvgDrawRect3d(w_Filler.min, fillVol, vec4(1, 1, 1, 0.5));
        if (UI::Begin("Fill Selection", w_FillPrompt, UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize)) {
            auto estimateFillObjsNb = CeilAndProduct(fillVol / fillObjSize);
            UI::Text("\\$i\\$bbbFill Volume Size: " + fillVol.ToString());
            UI::Text("\\$i\\$bbbFill Coordinate Size: " + (fillVol / Editor::DEFAULT_COORD_SIZE).ToString());
            UI::Text("Obj count estimate: " + estimateFillObjsNb);
            UI::Text("# in X, Y, Z: <" + (Math::Round(fillVol.x / fillObjSize.x, 1)) +
                ", " + (Math::Round(fillVol.y / fillObjSize.y, 1)) +
                ", " + (Math::Round(fillVol.z / fillObjSize.z, 1)) + ">");
            UI::Text("\\$i\\$bbbRounds up.");

            UI::Separator();
            UI::SetNextItemWidth(200);
            fillObjSize = UX::InputFloat3("Size (x,y,z)", fillObjSize, w_origFillObjSize);
            UI::TextWrapped("\\$i\\$bbbIncrease these numbers to space out the objects more.");
            UI::TextWrapped("\\$i\\$bbbTo create \\$<\\$fddone layer only\\$>, set the Y size to be very large. (The center of the layer will be at the center of the fill volume.)");
            UI::TextWrapped("\\$i\\$bbbFor \\$<\\$fddrotated items\\$>, set the size XYZ to the items normal dimensions to fit them together perfectly.");
            UX::ControlButton("¼", QuickSize_1_4_OnClick);
            UX::ControlButton("⅓", QuickSize_1_3_OnClick);
            UX::ControlButton("½", QuickSize_1_2_OnClick);
            UX::ControlButton("⅔", QuickSize_2_3_OnClick);
            UX::ControlButton("¾", QuickSize_3_4_OnClick);
            UX::ControlButton("1", QuickSize_1_1_OnClick);
            UX::ControlButton("1½", QuickSize_3_2_OnClick);
            UX::ControlButton("2", QuickSize_2_1_OnClick);
            UX::ControlButton("3", QuickSize_3_1_OnClick);
            UI::Dummy(vec2());

            UI::Separator();
            w_ApplyInChunks = UI::Checkbox("Apply Fill in chunks", w_ApplyInChunks);
            UI::SetNextItemWidth(100);
            UI::BeginDisabled(!w_ApplyInChunks);
            w_ChunkSize = UI::InputInt("Chunk Size", w_ChunkSize, 100);
            w_ChunkSize = Math::Max(w_ChunkSize, 100);
            UI::SameLine();
            if (UI::Button("Reset##chunk-size")) {
                w_ChunkSize = CHUNKSIZE_DEFAULT;
            }
            UI::EndDisabled();

            UI::Separator();
            w_RotateFillDirToLocal = UI::Checkbox("Fill along local coords", w_RotateFillDirToLocal);
            UI::TextWrapped("\\$i\\$bbbIf you have a rotated block/item in the cursor, this will fill along the local axes (not world axes). Regular blocks (e.g., flat platform or road) will fit together as though snapped. For connectable block gates, smaller X with y=8,z=32 will make tightly packed layers, but no flickering.");

            if (UI::Button("Run Fill (or Space/Enter)")) {
                OnFillPrompt_Accept();
            }
            UI::SameLine();
            if (UI::Button("Cancel (or Esc)")) {
                OnFillPrompt_Cancel();
            }
        }
        UI::End();
    }

    void OnFillPrompt_Accept() {
        w_FillPrompt = false;
        w_FillPromptCanceled = false;
    }
    void OnFillPrompt_Cancel() {
        w_FillPrompt = false;
        w_FillPromptCanceled = true;
    }

    // returns true for blocking
    bool CheckDismissPromptHotkeys(bool down, VirtualKey key) {
        if (!w_FillPrompt) return false;
        if (!down) return false;
        if (key == VirtualKey::Escape) {
            OnFillPrompt_Cancel();
            return true;
        }
        if (key == VirtualKey::Space || key == VirtualKey::Return) {
            OnFillPrompt_Accept();
            return true;
        }
        return false;
    }

    void QuickSize_1_4_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE / 4.0);
    }
    void QuickSize_1_3_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE / 3.0);
    }
    void QuickSize_1_2_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE / 2.0);
    }
    void QuickSize_2_3_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE / 3.0 * 2.0);
    }
    void QuickSize_3_4_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE / 4.0 * 3.0);
    }
    void QuickSize_1_1_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE);
    }
    void QuickSize_3_2_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE / 2.0 * 3.0);
    }
    void QuickSize_2_1_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE * 2.0);
    }
    void QuickSize_3_1_OnClick() {
        SetQuickSize(Editor::DEFAULT_COORD_SIZE * 3.0);
    }
    void SetQuickSize(vec3 size) {
        fillObjSize = size;
    }

}

float CeilAndProduct(vec3 v) {
    return Math::Ceil(v.x) * Math::Ceil(v.y) * Math::Ceil(v.z);
}

bool IsWithinFlex(float start, float val, float end) {
    auto high = Math::Max(start, end);
    auto low = Math::Min(start, end);
    if (start > end) {
        return val > end && val <= start;
    }
    return val >= start && val < end;
}

vec3 EnsurePositive(vec3 v, Axis axis) {
    switch (axis) {
        case Axis::X:
            if (v.x < 0) return v * -1;
            return v;
        case Axis::Y:
            if (v.y < 0) return v * -1;
            return v;
        case Axis::Z:
            if (v.z < 0) return v * -1;
            return v;
    }
    return v;
}
