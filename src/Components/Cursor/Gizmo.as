enum Axis {
    X, Y, Z
}

const vec3& AxisToVec(Axis a) {
    switch (a) {
        case Axis::X: return RIGHT;
        case Axis::Y: return UP;
        case Axis::Z: return FORWARD;
    }
    throw("unknown axis: " + tostring(a));
    return UP;
}

const vec3& AxisToVecForRot(Axis a) {
    switch (a) {
        case Axis::X: return LEFT;
        case Axis::Y: return UP;
        case Axis::Z: return BACKWARD;
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
            // startnew(GizmoLoop); // .WithRunContext(Meta::RunContext::AfterScripts);
            startnew(GizmoLoop).WithRunContext(Meta::RunContext::GameLoop);
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            origEditMode = CGameEditorPluginMap::EditMode::Place;
            origPlaceMode = Editor::GetPlacementMode(editor);
            origCustomYawActive = CustomCursorRotations::CustomYawActive;
            // CustomCursor::NoSetCursorVisFlagPatchActive = true;
        } else if (!v) {
            OnGoInactive();
        } else {
            NotifyWarning("Gizmo could not get exclusive control");
        }
    }

    void OnGoInactive() {
        _IsActive = false;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoSetCursorVisFlagPatchActive = false;
        CustomCursorRotations::CustomYawActive = origCustomYawActive;
        CursorControl::ReleaseExclusiveControl(gizmoControlName);
        @gizmo = null;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor !is null) {
            _OnInactive_UpdatePMT(editor.PluginMapType);
        }
    }

    void _OnActive_UpdatePMT(CGameEditorPluginMapMapType@ pmt) {
        pmt.EnableEditorInputsCustomProcessing = true;
        // this appears unneccessary; but Editor UI toolbox can interfere
        // pmt.HideEditorInterface = true;
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
        if (Editor::IsInMacroblockPlacementMode(editor, false)) {
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::FreeBlock;
        }
        IsActive = true;
        // don't block click => ctrl+click will select the block/item for us
        return false;
    }

    CGameEditorPluginMap::EditMode origEditMode;
    CGameEditorPluginMap::EPlaceMode origPlaceMode;
    bool origCustomYawActive;

    void GizmoLoop() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        Gizmo_Setup(editor);
        CustomCursorRotations::CustomYawActive = false;
        yield();
        bool isItem = modeTargetType == BlockOrItem::Item;
        CustomCursor::NoSetCursorVisFlagPatchActive = !isItem;
        CustomCursor::NoHideCursorItemModelsPatchActive = isItem;
        while (IsActive && (@editor = cast<CGameCtnEditorFree>(app.Editor)) !is null) {
            if (IsEscDown()) {
                _GizmoOnCancel();
                break;
            }
            // update cursor from gizmo
            bool isAltDown = IsAltDown();
            editor.PluginMapType.EnableEditorInputsCustomProcessing = !isAltDown;
            editor.PluginMapType.HideEditorInterface = true;
            auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
            if (!isItem) Editor::SetCursorBlockVisible(editor.Cursor, true);
            editor.Cursor.Color = vec3(0.039f, 0.039f, 0.078f);
            if (isAltDown) {
                pmt.EditMode = CGameEditorPluginMap::EditMode::FreeLook;
                editor.Cursor.UseFreePos = true;
            } else {
                pmt.EditMode = origEditMode;
                if (pmt.PlaceMode != origPlaceMode) {
                    pmt.PlaceMode = origPlaceMode;
                }
            }
            editor.Cursor.UseSnappedLoc = true;
            if (CustomCursorRotations::CustomYawActive) {
                CustomCursorRotations::CustomYawActive = false;
            }
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

    // just used to track item initial pivot
    vec3 lastAppliedPivot;
    uint lastAppliedPivotIx = 0;

    void CyclePivot() {
        if (modeTargetType == BlockOrItem::Block) {
            if (gizmo.pivotPoint.LengthSquared() < 0.01) {
                ApplyPivot(bb.halfDiag);
            } else {
                ApplyPivot(vec3());
            }
        } else {
            auto pp = itemSpec.Model.DefaultPlacementParam_Content;
            if (pp.PivotPositions.Length > 1) {
                lastAppliedPivotIx = (lastAppliedPivotIx + 1) % pp.PivotPositions.Length;
                ApplyPivot(pp.PivotPositions[lastAppliedPivotIx] - lastAppliedPivot);
            } else {
                lastAppliedPivotIx = uint(-1);
                if (gizmo.pivotPoint.LengthSquared() < 0.01) {
                    ApplyPivot(bb.halfDiag - lastAppliedPivot);
                } else {
                    ApplyPivot(vec3());
                }
            }
        }
    }

    void ApplyPivot(vec3 newPivot) {
        gizmo.SetPivotPoint(newPivot);
    }

    void Gizmo_Setup(CGameCtnEditorFree@ editor) {
        if (editor is null) {
            IsActive = false;
            return;
        }
        _OnActive_UpdatePMT(editor.PluginMapType);
        modeTargetType = lastPickedType;
        @itemSpec = null;
        @blockSpec = null;
        lastAppliedPivot = vec3();

        if (modeTargetType == BlockOrItem::Block) {
            yield();
            CGameCtnBlock@ b;
            if (lastPickedBlock is null || (@b = lastPickedBlock.AsBlock()) is null) {
                warn("no last picked block");
                IsActive = false;
                return;
            }
            auto size = Editor::GetBlockSize(b);
            @bb = Editor::AABB(mat4::Translate(Editor::GetBlockLocation(b)) * mat4::Inverse(Editor::GetBlockRotationMatrix(b)), size/2., size/2.);
            if (!Editor::IsInFreeBlockPlacementMode(editor)) {
                editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::FreeBlock;
            }
            @blockSpec = Editor::BlockSpecPriv(b);
            yield();
        } else {
            auto item = lastPickedItem.AsItem();
            if (item is null) {
                warn("no last picked item");
                IsActive = false;
                return;
            }
            Editor::SetCurrentPivot(editor, 0);
            CustomCursorRotations::SetCustomPYRAndCursor(lastPickedItemRot.Euler, editor.Cursor);
            @itemSpec = Editor::ItemSpecPriv(item);
            yield(2);
            Editor::SetAllCursorPos(lastPickedItemPos);
            @bb = Editor::GetSelectedItemAABB();
            if (bb is null) {
                warn("no selected item BB");
            } else {
                dev_trace("bb.pos before: " + bb.pos.ToString());
                auto im = item.ItemModel;
                // we need to account for the items pivot and default pivot
                lastAppliedPivot = Editor::GetItemPivot(item);
                lastAppliedPivotIx = 0;
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
                Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
                Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
                Editor::SetEditorPickedBlock(editor, null);
                Editor::DeleteFreeblocks(array<CGameCtnBlock@> = {lastPickedBlock.AsBlock()});
                // Editor::QueueFreeBlockDeletion(blockSpec);
                // Editor::RunDeleteFreeBlockDetection();
                // startnew(Editor::RunDeleteFreeBlockDetection).WithRunContext(Meta::RunContext::GameLoop);
                // yield(3);
                Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
                Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
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

        if (modeTargetType == BlockOrItem::Item) {
            gizmo.WithPlacementParams(lastPickedItem.AsItem().ItemModel.DefaultPlacementParam_Content);
            // gizmo.pivotPoint = lastAppliedPivot;
        } else if (modeTargetType == BlockOrItem::Block) {
            // blocks are offset by 0.25 in the local y axis for the free-block cursor.
            gizmo.OffsetBlockOnStart();
        }

        Editor::SetAllCursorMat(gizmo.GetCursorMat());
        IsActive = true;
        // auto lookUv = Editor::DirToLookUvFromCamera(bb.pos);
        auto lookUv = Editor::GetCurrentCamState(editor).LookUV;
        if (S_Gizmo_MoveCameraOnStart) {
            Editor::SetCamAnimationGoTo(lookUv, bb.pos, bb.halfDiag.Length() * 6.);
        }

        yield();
    }

    void _GizmoUpdateBBFromSelected() {
        yield(2);
        if (gizmo is null) return;
        @bb = Editor::GetSelectedItemAABB();
        gizmo.WithBoundingBox(bb);
    }

    void _GizmoOnApply() {
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        if (modeTargetType == BlockOrItem::Item) {
            dev_trace("Applying gizmo item: ");
            dev_trace("   lastAppliedPivot: " + lastAppliedPivot.ToString());
            dev_trace("   gizmo.placementParamOffset: " + gizmo.placementParamOffset.ToString());
            dev_trace("   gizmo.pivotPoint: " + gizmo.pivotPoint.ToString());

            itemSpec.pivotPos = (lastAppliedPivot * -1.); // - gizmo.placementParamOffset * 2.;
            itemSpec.pos = gizmo.pos + vec3(0, 56, 0) + gizmo.GetRotatedPivotPoint();
            itemSpec.coord = Int3ToNat3(PosToCoordDist(itemSpec.pos));
            itemSpec.pyr = EulerFromRotationMatrix(mat4::Inverse(gizmo.rot));
            Editor::PlaceItems({itemSpec}, true);
        } else {
            gizmo.OffsetBlockOnApply();
            blockSpec.flags = uint8(Editor::BlockFlags::Free);
            blockSpec.pos = gizmo.pos + vec3(0, 56, 0) + gizmo.GetRotatedPivotPoint();
            blockSpec.pyr = EulerFromRotationMatrix(mat4::Inverse(gizmo.rot));
            Editor::PlaceBlocks({blockSpec}, true);
            startnew(_AfterApply_SetBlockSkin);
        }
        IsActive = false;
        // startnew(DisableGizmoInAsync, uint64(1));
    }

    void _AfterApply_SetBlockSkin() {
        if (blockSpec.skin !is null) {
            auto skin = blockSpec.skin;
            @blockSpec.skin = null;
            @skin.block = blockSpec;
            Editor::SetSkins({skin});
            yield();
            Editor::SetSkins({skin});
        }
    }

    void _GizmoOnCancel() {
        if (!IsActive) return;
        bool hadGizmo = gizmo !is null;
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        IsActive = false;
        if (hadGizmo) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            editor.PluginMapType.Undo();
        }
    }

    void DisableGizmoInAsync(uint64 frames) {
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        yield(frames);
        IsActive = false;
    }
}

[Setting hidden]
bool S_Gizmo_MoveCameraOnStart = true;
