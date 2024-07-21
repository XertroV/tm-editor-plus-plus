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
            editor.PluginMapType.HideEditorInterface = true;
            auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
            if (isAltDown) {
                pmt.EditMode = CGameEditorPluginMap::EditMode::FreeLook;
            } else {
                pmt.EditMode = origEditMode;
            }
            editor.Cursor.UseSnappedLoc = true;
            Editor::SetAllCursorMat(gizmo.GetCursorMat());
            yield();
        }
        IsActive = false;
    }

    BlockOrItem modeTargetType = BlockOrItem::Block;
    Editor::AABB@ bb = null;
    RotationTranslationGizmo@ gizmo;
    Editor::ItemSpecPriv@ itemSpec;
    Editor::BlockSpecPriv@ blockSpec;

    vec3 lastAppliedPivot;

    void Gizmo_Setup(CGameCtnEditorFree@ editor) {
        if (editor is null) {
            IsActive = false;
            return;
        }
        _OnActive_UpdatePMT(editor.PluginMapType);
        modeTargetType = lastPickedType;
        @itemSpec = null;
        @blockSpec = null;

        if (modeTargetType == BlockOrItem::Block) {
            lastPickedBlock = Editor::GetPickedBlock();
            auto b = lastPickedBlock.AsBlock();
            // if (!Editor::IsBlockFree(b)) {
            //     IsActive = false;
            //     return;
            // }
            auto size = Editor::GetBlockSize(b);
            @bb = Editor::AABB(mat4::Translate(Editor::GetBlockLocation(b)) * mat4::Inverse(Editor::GetBlockRotationMatrix(b)), size/2., size/2.);
            if (!Editor::IsInFreeBlockPlacementMode(editor)) {
                editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::FreeBlock;
            }
            @blockSpec = Editor::BlockSpecPriv(b);
        } else {
            Editor::SetCurrentPivot(editor, 0);
            CustomCursorRotations::SetCustomPYRAndCursor(lastPickedItemRot.Euler, editor.Cursor);
            @itemSpec = Editor::ItemSpecPriv(lastPickedItem.AsItem());
            yield();
            Editor::SetAllCursorPos(lastPickedItemPos);
            @bb = Editor::GetSelectedItemAABB();
            if (bb is null) {
                warn("no selected item BB");
            } else {
                dev_trace("bb.pos before: " + bb.pos.ToString());
                auto item = lastPickedItem.AsItem();
                auto im = item.ItemModel;
                // we need to account for the items pivot and default pivot
                lastAppliedPivot = Editor::GetItemPivot(item);
                if (im.DefaultPlacementParam_Content.PivotPositions.Length > 0) {
                    lastAppliedPivot = im.DefaultPlacementParam_Content.PivotPositions[0];
                }

                auto itemMat = Editor::GetItemMatrix(item);
                auto itemPos = item.AbsolutePositionInMap;
                // main bb to use to set cursor // mat4::Inverse
                auto rot = (mat4::Translate(itemPos * -1.) * itemMat);
                auto relPivot = mat4::Translate(lastPickedItemPivot + lastAppliedPivot);
                bb.mat = rot * relPivot;
                bb.mat = mat4::Translate(itemPos) * (bb.mat);
                bb.InvertRotation();
                // dev_trace("bb.pos mid: " + bb.pos.ToString());
                // // bb is not always accurate -- will use last cursor pos which only showed before user pressed ctrl
                // bb.pos = lastPickedItemPos;
                // dev_trace("bb.pos mid: " + bb.pos.ToString());
                // // we add the pivots here because the one from the item is -1.* the actual pivot according to params
                // bb.mat = bb.mat * relPivot;
                dev_trace("bb.pos after: " + bb.pos.ToString());
                dev_trace("lastAppliedPivot: " + lastAppliedPivot.ToString());
                dev_trace("lastPickedItemPivot: " + lastPickedItemPivot.ToString());
            }
            lastPickedItemRot.SetCursor(editor.Cursor);
        }
        if (bb is null) {
            IsActive = false;
            return;
        }
        editor.PluginMapType.AutoSave();
        if (modeTargetType == BlockOrItem::Block) {
            if (blockSpec.isFree) {
                Editor::DeleteFreeblocks({lastPickedBlock.AsBlock()});
            } else {
                Editor::DeleteBlocksAndItems({blockSpec}, {});
            }
            yield();
        } else {
            Editor::DeleteBlocksAndItems({}, {itemSpec});
        }
        Editor::SetAllCursorPos(bb.pos);
        @gizmo = RotationTranslationGizmo("gizmo").WithBoundingBox(bb)
            .WithOnApplyF(_GizmoOnApply).WithOnExitF(_GizmoOnCancel);
        Editor::SetAllCursorMat(gizmo.GetCursorMat());
        IsActive = true;
        // auto lookUv = Editor::DirToLookUvFromCamera(bb.pos);
        auto lookUv = Editor::GetCurrentCamState(editor).LookUV;
        Editor::SetCamAnimationGoTo(lookUv, bb.pos, bb.halfDiag.Length() * 6.);

        yield();
    }

    void _GizmoUpdateBBFromSelected() {
        yield(2);
        if (gizmo is null) return;
        @bb = Editor::GetSelectedItemAABB();
        gizmo.WithBoundingBox(bb);
    }

    void _GizmoOnApply() {
        // todo
        if (modeTargetType == BlockOrItem::Item) {
            itemSpec.pivotPos = lastAppliedPivot;
            itemSpec.pos = gizmo.pos + vec3(0, 56, 0);
            itemSpec.pyr = EulerFromRotationMatrix(mat4::Inverse(gizmo.rot));
            Editor::PlaceItems({itemSpec}, true);
        } else {
            blockSpec.flags = uint8(Editor::BlockFlags::Free);
            blockSpec.pos = gizmo.pos + vec3(0, 56, 0);
            blockSpec.pyr = EulerFromRotationMatrix(mat4::Inverse(gizmo.rot));
            Editor::PlaceBlocks({blockSpec}, true);
            if (blockSpec.skin !is null) {
                auto skin = blockSpec.skin;
                @blockSpec.skin = null;
                @skin.block = blockSpec;
                Editor::SetSkins({skin});
            }
        }
        IsActive = false;
        // startnew(DisableGizmoInAsync, uint64(1));
    }

    void _GizmoOnCancel() {
        IsActive = false;
        // Editor::PlaceItems({itemSpec}, false);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.PluginMapType.Undo();
    }

    void DisableGizmoInAsync(uint64 frames) {
        yield(frames);
        IsActive = false;
    }
}
