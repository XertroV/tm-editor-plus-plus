funcdef void OnCustomSelectionDoneF(CGameCtnEditorFree@ editor, CSmEditorPluginMapType@ pmt);

class CustomSelectionMgr {
    uint HIST_LIMIT = 10;

    bool active = false;
    nat3[]@ latestCoords = {};

    int currentlySelected = -1;
    OnCustomSelectionDoneF@ doneCB;

    CustomSelectionMgr() {
        AddHotkey(VirtualKey::F, true, false, false, HotkeyFunction(this.OnFillHotkey), "Fill Selection");
        // RegisterOnLeavingPlaygroundCallback(CoroutineFunc(HideCustomSelection), "HideCustomSelection");
        // RegisterOnEditorLoadCallback(CoroutineFunc(HideCustomSelection), "HideCustomSelection");
    }

    void HideCustomSelection() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.PluginMapType.CustomSelectionCoords.RemoveRange(0, editor.PluginMapType.CustomSelectionCoords.Length);
        editor.PluginMapType.HideCustomSelection();
    }

    UI::InputBlocking OnFillHotkey() {
        startnew(CoroutineFunc(Enable));
        @doneCB = OnCustomSelectionDoneF(this.OnFillSelectionComplete);
        dev_trace('running enable hotkey');
        // blocks editor inputs, unblock next frame
        Editor::EnableCustomCameraInputs();
        startnew(Editor::DisableCustomCameraInputs);
        return UI::InputBlocking::DoNothing;
    }

    bool get_IsActive() {
        return active;
    }

    CGameEditorPluginMap::EPlaceMode origPlacementMode;


    void Enable() {
        if (active) {
            Notify("Cannot enable a new custom selection while one is still active.");
            return;
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        origPlacementMode = editor.PluginMapType.PlaceMode;
        if (SupportedFillModes.Find(origPlacementMode) < 0) {
            NotifyWarning("Place mode not supported for fill: " + tostring(origPlacementMode));
        }
        // Editor::CustomSelectionCoords_Clear(editor);
        // editor.PluginMapType.CustomSelectionCoords.Add(nat3(uint(-1)));
        auto cursorCoord = editor.PluginMapType.CursorCoord;
        CustomSelection::SetCoords(cursorCoord, cursorCoord);
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CustomSelection);
        editor.PluginMapType.CustomSelectionRGB = lastColor.xyz;
        editor.PluginMapType.ShowCustomSelection();
        active = true;
        // Editor::EnableCustomCameraInputs();
        startnew(CoroutineFunc(this.WatchLoop)); //.WithRunContext(Meta::RunContext::BeforeScripts);
    }

    // if user presses escape
    void Cancel() {
        _cancel = true;
    }

    nat3 startCoord;
    // bool updateML = false;
    protected nat3 updateMin;
    protected nat3 updateMax;
    // use UpdateSelection
    protected void _DoUpdateSelection() { // ref@ r
        throw('deprecating');
        // if (!updateML) return;
        // updateML = false;
        // dev_trace('updating selection: ');
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        Editor::CustomSelectionCoords_Clear(editor);
        for (uint x = updateMin.x; x <= updateMax.x; x++) {
            for (uint y = updateMin.y; y <= updateMax.y; y++) {
                for (uint z = updateMin.z; z <= updateMax.z; z++) {
                    editor.PluginMapType.CustomSelectionCoords.Add(nat3(x, y, z));
                }
            }
        }
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        pmt.CustomSelectionRGB = vec3(Math::Sin(0.001 * Time::Now) * .5 + .5, Math::Cos(0.001 * Time::Now) * .5 + .5, 1);
    }

    vec4 lastColor;

    protected bool _cancel = false;
    void WatchLoop() {
        auto app = GetApp();
        auto input = app.InputPort;

        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        // Editor::EnableCustomCameraInputs();
        while (!(UI::IsMouseDown() && int(input.MouseVisibility) == 0) && ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) && !_cancel) {
            if (pmt.PlaceMode != CGameEditorPluginMap::EPlaceMode::CustomSelection) break;
            currentlySelected = editor.PluginMapType.CustomSelectionCoords.Length;
            startCoord = editor.PluginMapType.CursorCoord;
            yield();
        }
        if (!_cancel) dev_trace('mouse is now down');
        float a = 1.; // .5;
        float b = .5; // should set to 0 for symmetric around 0
        while (UI::IsMouseDown() && ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) && !_cancel) {
            lastColor = vec4(Math::Sin(0.001 * Time::Now) * a + b, Math::Cos(.77 + 0.00127 * Time::Now) * a + b, 1. + 0. * Math::Sin(1.23 + 0.0014 * Time::Now) * a + b, -10.) * .1;
            pmt.CustomSelectionRGB = lastColor.xyz;
            if (pmt.PlaceMode != CGameEditorPluginMap::EPlaceMode::CustomSelection) break;
            UpdateSelection(editor, pmt, startCoord, pmt.CursorCoord);
            auto minPos = CoordToPos(updateMin);
            nvgDrawBlockBox(mat4::Translate(minPos), CoordToPos(updateMax + 1) - minPos);
            yield();
        }
        if (editor !is null && pmt.PlaceMode == CGameEditorPluginMap::EPlaceMode::CustomSelection && !_cancel) {
            dev_trace('mouse released');
            try {
                dev_trace('running callback');
                if (doneCB !is null) doneCB(editor, pmt);
                if (!IsInEditor) {
                    active = false;
                    @doneCB = null;
                    _cancel = false;
                    return;
                }
            } catch {
                warn('catch in custom selection done callback: ' + getExceptionInfo());
            }
            // Editor::CustomSelectionCoords_Clear(editor);
            pmt.PlaceMode = origPlacementMode;
        }
        if (editor !is null) {
            pmt.HideCustomSelection();
            pmt.CustomSelectionCoords.RemoveRange(0, pmt.CustomSelectionCoords.Length);
        }
        active = false;
        @doneCB = null;
        _cancel = false;
        // Editor::DisableCustomCameraInputs();
    }

    nat3 tmp1;
    nat3 tmp2;

    bool hideNext = true;
    void UpdateSelection(CGameCtnEditorFree@ editor, CSmEditorPluginMapType@ pmt, nat3 start, nat3 end) {
        tmp1 = MathX::Min(start, end); // updateMin
        tmp2 = MathX::Max(start, end); // updateMax
        updateMin = tmp1;
        updateMax = tmp2;
        CustomSelection::SetCoords(updateMin, updateMax, lastColor);
        // _DoUpdateSelection();
        return;
    }

    void Disable() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // CacheCustomSelectionCoords(editor.PluginMapType);
        editor.PluginMapType.HideCustomSelection();
        editor.PluginMapType.CustomSelectionCoords.RemoveRange(0, editor.PluginMapType.CustomSelectionCoords.Length);
        active = false;
    }

    void CacheCustomSelectionCoords(CGameEditorPluginMapMapType@ pmt) {
        nat3[] coords;
        for (uint i = 0; i < pmt.CustomSelectionCoords.Length; i++) {
            coords.InsertLast(pmt.CustomSelectionCoords[i]);
        }
    }

    CGameEditorPluginMap::EPlaceMode[] SupportedFillModes = {
        CGameEditorPluginMap::EPlaceMode::Block,
        CGameEditorPluginMap::EPlaceMode::GhostBlock,
        CGameEditorPluginMap::EPlaceMode::Item,
        CGameEditorPluginMap::EPlaceMode::Macroblock
    };

    void OnFillSelectionComplete(CGameCtnEditorFree@ editor, CSmEditorPluginMapType@ pmt) {
        int3 coord;
        nat3 c;

        CGameCtnBlockInfo@ block;
        CGameCtnMacroBlockInfo@ macroblock;
        CGameItemModel@ item;
        if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Block) {
            @block = selectedBlockInfo is null ? null : selectedBlockInfo.AsBlockInfo();
        } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::GhostBlock) {
            @block = selectedGhostBlockInfo is null ? null : selectedGhostBlockInfo.AsBlockInfo();
        } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Macroblock) {
            @macroblock = selectedMacroBlockInfo.AsMacroBlockInfo();
        } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Item) {
            @item = selectedItemModel.AsItemModel();
        }
        if (block is null && macroblock is null && item is null) return;
        dev_trace('Running OnFillSelectionComplete');
        for (uint i = 0; i < pmt.CustomSelectionCoords.Length; i++) {
            c = pmt.CustomSelectionCoords[i];
            coord = int3(c.x, c.y, c.z);
            if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Block) {
                pmt.PlaceBlock(block, coord, pmt.CursorDir);
            } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::GhostBlock) {
                pmt.PlaceGhostBlock(block, coord, pmt.CursorDir);
            } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Item) {
                NotifyWarning("Item fill mode not implemented yet");
                return;
            } else if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Macroblock) {
                NotifyWarning("Macroblock fill mode not implemented yet");
                return;
            } else {
                NotifyWarning("Unsupported for fill mode: " + tostring(origPlacementMode));
                return;
            }
            CheckPause();
            if (UI::IsKeyPressed(UI::Key::Escape)) {
                trace("Exiting fill loop as escape was pressed");
                break;
            }
            // if we exit the editor, this loop would crash the game
            if (!IsInEditor) return;
        }
        pmt.AutoSave();
        // pmt.Selection
    }
}

CustomSelectionMgr@ customSelectionMgr = CustomSelectionMgr();




namespace CustomSelection {
    void OnPluginLoad() {
        RegisterOnEditorLoadCallback(OnEnterEditor, "Custom Selection");
        RegisterOnMapTypeUpdateCallback(OnMapTypeUpdate, "Custom Selection");
    }

    void OnEnterEditor() {

    }

    nat3 lastMin;
    nat3 lastMax;

    bool shouldSetCoordsNextFrame;
    void OnMapTypeUpdate() {
        if (shouldSetCoordsNextFrame) {
            auto pmt = ToML::GetPluginPMT();
            pmt.HideCustomSelection();
            if (minCoord == lastMin && maxCoord == lastMax && pmt.CustomSelectionCoords.Length > 0) {
                pmt.CustomSelectionCoords.RemoveRange(0, pmt.CustomSelectionCoords.Length);
            }
            print("Setting coords next frame: " + minCoord.ToString() + " to " + maxCoord.ToString());
            shouldSetCoordsNextFrame = false;
            WriteCoordsToPMT();
        }
    }

    nat3 minCoord;
    nat3 maxCoord;

    void SetCoords(nat3 min, nat3 max, vec4 color = vec4()) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto pmt = editor.PluginMapType;
        if (pmt is null) return;
        pmt.CustomSelectionCoords.RemoveRange(0, pmt.CustomSelectionCoords.Length);
        minCoord = min;
        maxCoord = max;
        // shouldSetCoordsNextFrame = true;
        Editor::DrawLines::UpdateBoxFaces(CoordToPos(min), CoordToPos(max + 1), color);
    }

    void WriteCoordsToPMT() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto pmt = editor.PluginMapType;
        if (pmt is null) return;
        auto size = maxCoord - minCoord + 1;
        auto nbCoords = size.x * size.y * size.z;
        auto currSize = pmt.CustomSelectionCoords.Length;
        pmt.ShowCustomSelection();
        pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::CustomSelection;

        // pmt.CustomSelectionCoords.RemoveRange(0, currSize);
        // if (lastFrameSelectedOrigin) {
        //     pmt.CustomSelectionCoords.Add(minCoord);
        //     pmt.CustomSelectionCoords.Add(maxCoord);
        // }
        // // if (!lastFrameSelectedOrigin) pmt.CustomSelectionCoords.Add(nat3());
        // lastFrameSelectedOrigin = !lastFrameSelectedOrigin;
        return;


        uint i;
        auto xy = size.x * size.y;
        for (i = 0; i < currSize; i++) {
            pmt.CustomSelectionCoords[i] = minCoord + nat3(i % size.x, (i / size.x) % size.y, i / xy);
        }

        if (currSize < nbCoords) {
            for (; i < nbCoords; i++) {
                pmt.CustomSelectionCoords.Add(minCoord + nat3(i % size.x, (i / size.x) % size.y, i / xy));
            }
        } else if (currSize > nbCoords) {
            pmt.CustomSelectionCoords.RemoveRange(nbCoords, currSize - nbCoords);
        }
    }
}
