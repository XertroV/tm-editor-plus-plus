enum Axis {
    X, Y, Z
}

const vec3& AxisToVec(Axis a) {
    switch (a) {
        case Axis::X: return RIGHT;
        case Axis::Y: return UP;
        case Axis::Z: return BACKWARD;
    }
    throw("unknown axis: " + tostring(a));
    return UP;
}

const vec3& AxisToVecForRot(Axis a) {
    switch (a) {
        case Axis::X: return LEFT;
        case Axis::Y: return UP;
        case Axis::Z: return FORWARD;
    }
    throw("unknown axis: " + tostring(a));
    return UP;
}

namespace Gizmo {
    enum Mode {
        Rotation,
        Translation
    }

    const string gizmoControlName = "Gizmo";

    bool _IsActive = false;

    bool get_IsActive() {
        return _IsActive;
    }
    void set_IsActive(bool v) {
        if (_IsActive == v) return;
        if (v && CursorControl::RequestExclusiveControl(gizmoControlName)) {
            _IsActive = v;
            startnew(GizmoLoop); // .WithRunContext(Meta::RunContext::AfterScripts);
        } else if (!v) {
            OnGoInactive();
        } else {
            NotifyWarning("Gizmo could not get exclusive control");
        }
    }

    void OnGoInactive() {
        _IsActive = false;
        CursorControl::ReleaseExclusiveControl(gizmoControlName);
        @gizmo = null;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor !is null) {
            _OnInactive_UpdatePMT(editor.PluginMapType);
        }
    }

    void _OnActive_UpdatePMT(CGameEditorPluginMapMapType@ pmt) {
        pmt.EnableEditorInputsCustomProcessing = true;
    }

    void _OnInactive_UpdatePMT(CGameEditorPluginMapMapType@ pmt) {
        pmt.EnableEditorInputsCustomProcessing = false;
        pmt.HideEditorInterface = false;
    }

    void Render() {
        if (!IsActive) return;
        if (gizmo is null) return;
        gizmo.Render();
    }

    // will enter gizmo mode if conditions are met. returns whether to block click, always false
    bool CheckEnterGizmoMode(CGameCtnEditorFree@ editor) {
        if (editor is null) return false;
        if (!CursorControl::IsExclusiveControlAvailable()) return false;
        // true while ctrl is down
        if (Editor::GetEditMode(editor) != CGameEditorPluginMap::EditMode::Pick) return false;
        // we want shift down too
        if (!IsShiftDown()) return false;
        if (!IsCtrlDown()) return false;
        // conditions met
        IsActive = true;
        // don't block click => ctrl+click will select the block/item for us
        return false;
    }

    CGameEditorPluginMap::EditMode origEditMode;
    CGameEditorPluginMap::EPlaceMode origPlaceMode;

    void GizmoLoop() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        Gizmo_Setup(editor);
        origEditMode = Editor::GetEditMode(editor);
        while (IsActive && (@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) {
            // update cursor from gizmo
            bool isAltDown = IsAltDown();
            editor.PluginMapType.EnableEditorInputsCustomProcessing = !isAltDown;
            // editor.PluginMapType.HideEditorInterface = true;
            auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
            if (isAltDown) {
                editor.PluginMapType.EditMode = CGameEditorPluginMap::EditMode::FreeLook;
            } else {
                editor.PluginMapType.EditMode = origEditMode;
            }
            Editor::SetAllCursorMat(gizmo.GetCursorMat());
            yield();
        }
        IsActive = false;
    }

    BlockOrItem modeTargetType = BlockOrItem::Block;
    Editor::AABB@ bb = null;
    RotationTranslationGizmo@ gizmo;

    void Gizmo_Setup(CGameCtnEditorFree@ editor) {
        if (editor is null) {
            IsActive = false;
            return;
        }
        _OnActive_UpdatePMT(editor.PluginMapType);
        modeTargetType = lastPickedType;
        if (modeTargetType == BlockOrItem::Block) {
            lastPickedBlock = Editor::GetPickedBlock();
            auto b = lastPickedBlock.AsBlock();
            if (!Editor::IsBlockFree(b)) {
                IsActive = false;
                return;
            }
            auto size = Editor::GetBlockSize(b);
            @bb = Editor::AABB(Editor::GetBlockMatrix(b), size/2., size/2.);
            if (!Editor::IsInFreeBlockPlacementMode(editor)) {
                editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::FreeBlock;
            }
        } else {
            Editor::SetAllCursorPos(lastPickedItemPos);
            CustomCursorRotations::SetCustomPYRAndCursor(lastPickedItemRot.Euler, editor.Cursor);
            startnew(_GizmoUpdateBBFromSelected);
            yield();
            @bb = Editor::GetSelectedItemAABB();
            if (bb is null) {
                warn("no selected item BB");
            } else {
                bb.mat = mat4::Inverse(Editor::GetItemMatrix(lastPickedItem.AsItem()));
                // bb is not always accurate -- will use last cursor pos which only showed before user pressed ctrl
                bb.pos = lastPickedItemPos;
            }
            lastPickedItemRot.SetCursor(editor.Cursor);
        }
        if (bb is null) {
            IsActive = false;
            return;
        }
        Editor::SetAllCursorPos(bb.pos);
        @gizmo = RotationTranslationGizmo("gizmo").WithBoundingBox(bb)
            .WithOnApplyF(_GizmoOnApply).WithOnExitF(_GizmoOnCancel);
        IsActive = true;
    }

    void _GizmoUpdateBBFromSelected() {
        yield(2);
        if (gizmo is null) return;
        @bb = Editor::GetSelectedItemAABB();
        gizmo.WithBoundingBox(bb);
    }

    void _GizmoOnApply() {
        // todo
    }

    void _GizmoOnCancel() {
        IsActive = false;
    }
}
