funcdef void OnCustomSelectionDoneF(CGameCtnEditorFree@ editor, CSmEditorPluginMapType@ pmt, nat3 min, nat3 max, vec3 coordSize);

class CustomSelectionMgr {
    uint HIST_LIMIT = 10;

    bool active = false;
    nat3[]@ latestCoords = {};

    int currentlySelected = -1;
    OnCustomSelectionDoneF@ doneCB;
    CGameEditorPluginMap::EPlaceMode origPlacementMode;
    Editor::ItemMode origItemMode;
    vec3 coordSize;

    CustomSelectionMgr() {
        RegisterOnLeavingPlaygroundCallback(CoroutineFunc(HideCustomSelection), "HideCustomSelection");
        RegisterOnEditorLoadCallback(CoroutineFunc(HideCustomSelection), "HideCustomSelection");
        RegisterNewAfterCursorUpdateCallback(CoroutineFunc(AfterCursorUpdate), "CustomSelectionMgr");
    }

    void HideCustomSelection() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null || editor.PluginMapType.CustomSelectionCoords.Length == 0) return;
        editor.PluginMapType.CustomSelectionCoords.RemoveRange(0, editor.PluginMapType.CustomSelectionCoords.Length);
        editor.PluginMapType.HideCustomSelection();
    }

    void AfterCursorUpdate() {
        if (!active) return;
        if (!freeSelectionMode) return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        editor.Cursor.UseFreePos = true;
        editor.Cursor.FreePosInMap = Picker::GetMouseToWorldAtHeight(editor.OrbitalCameraControl.m_TargetedPosition.y);
    }

    // for when Esc is pressed
    bool CheckCancel(bool down, VirtualKey key) {
        if (!IsActive || !down || key != VirtualKey::Escape) return false;
        Cancel();
        return true;
    }

    bool get_IsActive() {
        return active;
    }

    vec3 GetGridCoordSize(CGameCtnEditorFree@ editor) {
        switch (origPlacementMode) {
            case CGameEditorPluginMap::EPlaceMode::Block:
            case CGameEditorPluginMap::EPlaceMode::GhostBlock:
            case CGameEditorPluginMap::EPlaceMode::FreeBlock:
                return Editor::GetSelectedBlockSize(editor);
            case CGameEditorPluginMap::EPlaceMode::Item:
                return Editor::GetSelectedItemSize(editor);
            case CGameEditorPluginMap::EPlaceMode::Macroblock:
            case CGameEditorPluginMap::EPlaceMode::FreeMacroblock:
                return Editor::GetSelectedMacroblockSize(editor);
            default:
                return Editor::DEFAULT_COORD_SIZE;
        }
    }

    bool Enable(OnCustomSelectionDoneF@ cb) {
        if (active) {
            warn_every_60_s("Enabling a new custom selection while one is still active :/.");
            trace("Attempting to release exclusive cursor control if it's still active.");
            CursorControl::ReleaseExclusiveControl("custom-selection");
            // return false;
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return false;
        if (editor.PluginMapType.PlaceMode == CGameEditorPluginMap::EPlaceMode::CustomSelection) {
            NotifyWarning("Custom selection is already enabled. Change to block/item mode.");
            return false;
        }
        origPlacementMode = editor.PluginMapType.PlaceMode;
        origItemMode = Editor::GetItemPlacementMode(false, false);
        freeSelectionMode = Editor::IsAnyFreePlacementMode(origPlacementMode);
        coordSize = GetGridCoordSize(editor);
        if (coordSize.LengthSquared() < 0.01) {
            NotifyWarning("No size of object detected; setting to default coord size.");
            coordSize = Editor::DEFAULT_COORD_SIZE;
        }
        dev_trace('CustomSelectionMgr got coordSize: ' + coordSize.ToString() + ' for origPlacementMode: ' + tostring(origPlacementMode));
        if (SupportedFillModes.Find(origPlacementMode) < 0) {
            NotifyWarning("Place mode not supported for fill: " + tostring(origPlacementMode));
            return false;
        }
        @doneCB = cb;

        // Editor::CustomSelectionCoords_Clear(editor);
        // editor.PluginMapType.CustomSelectionCoords.Add(nat3(uint(-1)));
        auto cursorCoord = editor.PluginMapType.CursorCoord;
        CustomSelection::SetCoords(cursorCoord, cursorCoord);
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CustomSelection);
        // editor.PluginMapType.CustomSelectionRGB = lastColor.xyz;
        editor.PluginMapType.HideCustomSelection();
        editor.PluginMapType.CustomSelectionCoords.RemoveRange(0, editor.PluginMapType.CustomSelectionCoords.Length);

        //
        if (!CursorControl::IsExclusiveControlAvailable()) {
            NotifyWarning("Something else is controlling the cursor.");
            return false;
        }

        active = true;
        // Editor::EnableCustomCameraInputs();
        startnew(CoroutineFunc(this.WatchLoop)); //.WithRunContext(Meta::RunContext::BeforeScripts);
        return true;
    }

    // if user presses escape
    void Cancel() {
        _cancel = true;
        active = false;
    }

    bool freeSelectionMode = false;

    nat3 startCoord;
    // the last min coord
    protected nat3 updateMin;
    // the last max coord
    protected nat3 updateMax;

    vec3 startPos;
    vec3 updateMinPos;
    vec3 updateMaxPos;

    vec4 lastColor = vec4(1);

    protected bool _cancel = false;
    void WatchLoop() {
        auto app = GetApp();
        auto input = app.InputPort;
        // if we start with a cancel, check it isn't handled and then return if it's still true.
        if (_cancel) {
            yield();
            if (_cancel) {
                _cancel = false;
                return;
            }
        }

        if (!CursorControl::RequestExclusiveControl("custom-selection")) {
            NotifyWarning("Failed to acquire exclusive cursor control.");
            active = false;
            @doneCB = null;
            _cancel = false;
            return ;
        }

        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        // Editor::EnableCustomCameraInputs();
        while (!(UI::IsMouseDown() && !IsAltDown() && int(input.MouseVisibility) == 0) && ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) && !_cancel) {
            if (pmt.PlaceMode != CGameEditorPluginMap::EPlaceMode::CustomSelection
                || UI::IsKeyPressed(UI::Key::Escape)) {
                Notify("Cancelled custom selection.");
                _cancel = true;
                break;
            }
            currentlySelected = editor.PluginMapType.CustomSelectionCoords.Length;
            startCoord = editor.PluginMapType.CursorCoord;
            yield();
        }
        if (!_cancel) dev_trace('mouse is now down');
        float a = 1.; // .5;
        float b = .5; // should set to 0 for symmetric around 0
        while (UI::IsMouseDown() && ((@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) && !_cancel) {
            lastColor = vec4(Math::Sin(0.001 * Time::Now - .1337) * .5 * a + b, Math::Cos(.77 + 0.00127 * Time::Now) * .5 * a + b, 1. + 0. * Math::Sin(1.23 + 0.0014 * Time::Now) * a + b, 10) * .1;
            // pmt.CustomSelectionRGB = lastColor.xyz;
            if (pmt.PlaceMode != CGameEditorPluginMap::EPlaceMode::CustomSelection) break;
            UpdateSelection(editor, pmt, startCoord, pmt.CursorCoord);
            auto minPos = CoordToPos(updateMin);
            nvgDrawBlockBox(mat4::Translate(minPos), CoordDistToPos(updateMax - updateMin + 1), cWhite);
            editor.PluginMapType.HideCustomSelection();
            yield();
        }
        if (editor !is null && pmt.PlaceMode == CGameEditorPluginMap::EPlaceMode::CustomSelection && !_cancel) {
            dev_trace('mouse released, finalizing');
            Editor::DrawLines::ClearBoxFaces();
            try {
                dev_trace('running callback');
                if (doneCB !is null) {
                    startnew(CoroutineFunc(RunOnFillSelectionComplete));
                }
                yield(2);
                if (!IsInEditor) {
                    active = false;
                    @doneCB = null;
                    _cancel = false;
                    CursorControl::ReleaseExclusiveControl("custom-selection");
                    return;
                }
            } catch {
                PrintActiveContextStack();
                warn('catch in custom selection done callback: ' + getExceptionInfo());
            }
            // Editor::CustomSelectionCoords_Clear(editor);
            pmt.PlaceMode = origPlacementMode;
        }
        if (editor !is null) {
            HideCustomSelection();
            Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
            Editor::SetPlacementMode(editor, origPlacementMode);
            if (origPlacementMode == CGameEditorPluginMap::EPlaceMode::Item) {
                Editor::SetItemPlacementMode(origItemMode);
            }
        }
        active = false;
        @doneCB = null;
        _cancel = false;
        Editor::DrawLines::ClearBoxFaces();
        CursorControl::ReleaseExclusiveControl("custom-selection");
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
        CGameEditorPluginMap::EPlaceMode::FreeBlock,
        CGameEditorPluginMap::EPlaceMode::Item,
        CGameEditorPluginMap::EPlaceMode::Macroblock,
        CGameEditorPluginMap::EPlaceMode::FreeMacroblock
    };

    void OnFillSelectionComplete(CGameCtnEditorFree@ editor, CSmEditorPluginMapType@ pmt) {
        doneCB(editor, pmt, updateMin, updateMax, coordSize);
    }

    void RunOnFillSelectionComplete() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        OnFillSelectionComplete(editor, pmt);
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
        if (shouldSetCoordsNextFrame && false) {
            auto pmt = ToML::GetPluginPMT();
            if (minCoord == lastMin && maxCoord == lastMax && pmt.CustomSelectionCoords.Length > 0) {
                pmt.CustomSelectionCoords.RemoveRange(0, pmt.CustomSelectionCoords.Length);
            }
            shouldSetCoordsNextFrame = false;
            // might need to use normal editor PMT here?
            // pmt.ShowCustomSelection();
            pmt.PlaceMode = CGameEditorPluginMap::EPlaceMode::CustomSelection;
            // pmt.HideCustomSelection();
        }
    }

    nat3 minCoord;
    nat3 maxCoord;

    void SetCoords(nat3 min, nat3 max, vec4 color = vec4(.3)) {
        // dev_trace('SetCoords: ' + min.ToString() + ' to ' + max.ToString());
        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // if (editor is null) return;
        // auto pmt = editor.PluginMapType;
        // if (pmt is null) return;
        // pmt.CustomSelectionCoords.RemoveRange(0, pmt.CustomSelectionCoords.Length);
        // minCoord = min;
        // maxCoord = max;
        // shouldSetCoordsNextFrame = true;
        Editor::DrawLines::UpdateBoxFaces(CoordToPos(min), CoordToPos(max + 1), color);
    }
}
