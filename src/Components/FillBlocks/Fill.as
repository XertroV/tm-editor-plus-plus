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
        @fillCursorRot = Editor::GetCursorRot(editor.Cursor).WithCardinalOnly(!Editor::IsAnyFreePlacementMode(origPlacementMode));
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
        Editor::SetPlacementMode(editor, filler.placeMode);
        if (filler.IsModeAnyItem()) {
            Editor::SetItemPlacementMode(filler.itemMode);
        }
    }

    class Filler {
        CGameEditorPluginMap::EPlaceMode placeMode;
        bool isAirMode;
        Editor::ItemMode itemMode;

        Filler() {}

        Filler@ WithInitialPlaceMode(CGameEditorPluginMap::EPlaceMode placeMode, bool isAirMode) {
            this.isAirMode = isAirMode;
            this.placeMode = placeMode;
            if (IsModeAnyItem()) {
                itemMode = Editor::GetItemPlacementMode(false, false);
            }
            if (!GetObjectFromPM()) {
                warn("Failed to get object from place mode");
                return null;
            }
            return this;
        }

        Filler@ WithMinMax(nat3 min, nat3 max) {
            this.min = CoordToPos(min);
            this.max = CoordToPos(max + nat3(1, 1, 1));
            this.coordMin = min;
            this.coordMax = max;
            return this;
        }

        nat3 coordMin;
        nat3 coordMax;

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

        bool  IsModeBlockNormOrGhost() {
            return placeMode == CGameEditorPluginMap::EPlaceMode::Block
                || placeMode == CGameEditorPluginMap::EPlaceMode::GhostBlock;
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
                || placeMode == CGameEditorPluginMap::EPlaceMode::Macroblock;
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

        array<vec3>@ GetFillLocationsOnGrid() {
            auto mat = fillCursorRot.GetMatrix();
            auto fillObjDims = MathX::Abs((mat * fillObjSize).xyz);
            auto size = Vec3ToNat3(MathX::Round(fillObjDims / Editor::DEFAULT_COORD_SIZE));
            array<vec3> locs;
            for (uint x = coordMin.x; x <= coordMax.x; x += size.x) {
                for (uint y = coordMin.y; y <= coordMax.y; y += size.y) {
                    for (uint z = coordMin.z; z <= coordMax.z; z += size.z) {
                        locs.InsertLast(CoordToPos(nat3(x, y, z)));
                    }
                }
            }
            return locs;
        }

        array<vec3>@ GetFillLocations() {
            if (IsModeOnGrid()) {
                return GetFillLocationsOnGrid();
            }
            array<vec3> locs;
            vec3 axes = fillObjSize;
            // enough buffer to ensure we fill the entire volume
            vec3 extraDist = vec3(fillObjSize.Length() * 2.0);
            // create a lot of buffer in start,end
            vec3 start = min - extraDist;
            vec3 end = max + extraDist;
            vec3 midPoint = (start + end) / 2;

            vec3 left = vec3(axes.x, 0, 0);
            vec3 up = vec3(0, axes.y, 0);
            vec3 forward = vec3(0, 0, axes.z);

            auto mat = fillCursorRot.GetMatrix();
            if (w_RotateFillDirToLocal && this.IsModeAnyFree()) {
                left = (mat * left).xyz; // EnsurePositive((mat * left).xyz, Axis::X);
                up = (mat * up).xyz; // EnsurePositive((mat * up).xyz, Axis::Y);
                forward = (mat * forward).xyz; // EnsurePositive((mat * forward).xyz, Axis::Z);
            } else if (IsModeAnyFree()) {
                // midPoint -= fillObjSize / -2;
            }
            midPoint -= (mat * (fillObjSize / -2)).xyz;
            // dev
            nvgDrawPointRing(midPoint, 4.0, cRed);

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

            dir = forward;
            for (uint i = 0; i < along_x.Length; i++) {
                p = along_x[i];
                along_xy.InsertLast(p);
                for (float sign = -1; sign <= 1; sign += 2) {
                    dir = forward * sign;
                    p = along_x[i] + dir;
                    while (MathX::Within(p, start, end)) {
                        along_xy.InsertLast(p);
                        p += dir;
                    }
                }
            }

            dir = up;
            for (uint i = 0; i < along_xy.Length; i++) {
                p = along_xy[i];
                along_xyz.InsertLast(p);
                for (float sign = -1; sign <= 1; sign += 2) {
                    dir = up * sign;
                    p = along_xy[i] + dir;
                    while (MathX::Within(p, start, end)) {
                        along_xyz.InsertLast(p);
                        p += dir;
                    }
                }
            }

            vec3[] topLayer = {};
            auto nearlyMax = max - vec3(0.0025);

            for (uint i = 0; i < along_xyz.Length; i++) {
                p = along_xyz[i];
                if (MathX::Within(p, min, nearlyMax)) {
                    if (!MathX::Within(p + up, min, nearlyMax)) {
                        // if the point 'above' this
                        topLayer.InsertLast(p);
                    } else {
                        locs.InsertLast(along_xyz[i]);
                    }
                }
            }

            for (uint i = 0; i < topLayer.Length; i++) {
                locs.InsertLast(topLayer[i]);
            }
            lastLocsNbTopLayer = topLayer.Length;

            return locs;
        }
        uint lastLocsNbTopLayer = 0;

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
            uint topLayerStartIx = locs.Length - lastLocsNbTopLayer;
            SortLocationsByHeightAscending(locs, 0, topLayerStartIx - 1);
            // SortLocationsByHeightDescending(locs, 0, topLayerStartIx - 1);
            bool ghost = IsModeGhost();
            bool free = IsModeFree();
            bool isNormBlock = IsModeAnyBlock() && !ghost && !free;
            auto groundCoordY = Editor::GetGroundCoordY(editor.Challenge);
            bool airMode = IsModeAir();
            // for water blocks mostly,

            if (block !is null) {
                bool setAltVar = ShouldSetAltVariant(block);
                for (uint i = 0; i < locs.Length; i++) {
                    auto b = Editor::MakeBlockSpec(block, locs[i], cursorRot.Euler);
                    // reset flags
                    b.SetToNormal();
                    // set ghost/free if needed
                    if (ghost) b.isGhost = true;
                    else if (free) b.isFree = true;
                    // only set ground if not ghost or free
                    if (isNormBlock) b.isGround = b.coord.y == groundCoordY;
                    // set the variant to 1 if it's not a top-layer block
                    b.variant = setAltVar && i < topLayerStartIx ? 1 : objVariant;
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

        bool ShouldSetAltVariant(CGameCtnBlockInfo@ block) {
            if (!IsModeAnyBlock()) return false;
            if (block.AdditionalVariantsAir.Length == 0 || block.AdditionalVariantsGround.Length == 0) return false;
            auto idName = block.IdName;
            if (idName.Contains("RoadWater")) return false;
            if (idName.Contains("TrackWallWater")) return true;
            if (idName.Contains("DecoWallWater")) return true;
            if (BLOCK_SET_ALT_VARS.Find(idName) >= 0) return true;
            return false;
        }
    }

    // blocks that have a beneath variant like deep water platform;
    // note: we match TrackWallWater separately
    const string[] BLOCK_SET_ALT_VARS = {
        "DecoWallWaterBase", "DecoWallWaterDiag"
    };



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

funcdef int QS_vec3_LessF(const vec3 &in m1, const vec3 &in m2);
void QuickSort_Vec3(vec3[]@ arr, QS_vec3_LessF@ f, int left = 0, int right = -1) {
    if (arr.Length < 2) return;
    if (right < 0) right = arr.Length - 1;
    int i = left;
    int j = right;
    vec3 pivot = arr[(left + right) / 2];
    vec3 temp;

    while (i <= j) {
        while (f(arr[i], pivot) < 0) i++;
        while (f(arr[j], pivot) > 0) j--;
        if (i <= j) {
            temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
            i++;
            j--;
        }
    }

    if (left < j) QuickSort_Vec3(arr, f, left, j);
    if (i < right) QuickSort_Vec3(arr, f, i, right);
}

void SortLocationsByHeightAscending(array<vec3>@ locs, int start = 0, int end = -1) {
    QuickSort_Vec3(locs, function(const vec3 &in m1, const vec3 &in m2) {
        if (m1.y < m2.y) return -1;
        if (m1.y > m2.y) return 1;
        return 0;
    }, start, end);
}

void SortLocationsByHeightDescending(array<vec3>@ locs, int start = 0, int end = -1) {
    QuickSort_Vec3(locs, function(const vec3 &in m1, const vec3 &in m2) {
        if (m1.y < m2.y) return 1;
        if (m1.y > m2.y) return -1;
        return 0;
    }, start, end);
}
