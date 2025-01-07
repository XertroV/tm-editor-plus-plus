enum Axis {
    X, Y, Z
}

// useful to flip XZ when doing camera things
const vec3& AxisToVec(Axis a) {
    switch (a) {
        case Axis::X: return RIGHT;
        case Axis::Y: return UP;
        case Axis::Z: return FORWARD;
    }
    throw("unknown axis: " + tostring(a));
    return UP;
}

// returns vec3(1) - AxisToVec(a); so the axis is zeroed but other axes aren't.
const vec3 AxisToAntiVec(Axis a) {
    switch (a) {
        case Axis::X: return vec3(1) - RIGHT;
        case Axis::Y: return vec3(1) - UP;
        case Axis::Z: return vec3(1) - FORWARD;
    }
    throw("unknown axis: " + tostring(a));
    return vec3(1) - UP;
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

[Setting hidden]
bool S_Gizmo_ApplyBlockOffset = true;

[Setting hidden]
bool S_Gizmo_InvertApplyModifier = false;

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
            @origCursor = CustomCursorRotations::GetEditorCursorRotations(editor.Cursor);
        } else if (!v) {
            OnGoInactive();
        } else {
            NotifyWarning("Gizmo could not get exclusive control");
        }
    }

    void OnGoInactive() {
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;
        CustomCursor::NoSetCursorVisFlagPatchActive = false;
        CustomCursorRotations::CustomYawActive = origCustomYawActive;
        CursorControl::ReleaseExclusiveControl(gizmoControlName);
        if (gizmo !is null) gizmo.CleanUp();
        @gizmo = null;

        if (itemSpec !is null) {
            itemSpec.Model.DefaultPlacementParam_Content.SwitchPivotManually = origPlacementSwitchPivotManually;
        }

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        origCursor.SetCursor(editor.Cursor);
        // CustomCursorRotations::SetCustomPYRAndCursor

        if (editor !is null) {
            _OnInactive_UpdatePMT(editor.PluginMapType);
        }
        if (Editor::GetPlacementMode(editor) != origPlaceMode) {
            Editor::SetPlacementMode(editor, origPlaceMode);
        }
        if (origModeWasItem) {
            Editor::SetItemPlacementMode(origItemPlacementMode);
        }
        _IsActive = false;
    }

    void _OnActive_UpdatePMT(CGameEditorPluginMapMapType@ pmt) {
        pmt.EnableEditorInputsCustomProcessing = true;
        // this appears unneccessary; but Editor UI toolbox can interfere
        // pmt.HideEditorInterface = true;
    }

    void _OnInactive_UpdatePMT(CGameEditorPluginMapMapType@ pmt) {
        startnew(SetCustomInputsProcessingFalseWhenSpaceReleased);
        pmt.HideEditorInterface = false;
        pmt.NextMapElemColor = origCursorColor;
    }

    void SetCustomInputsProcessingFalseWhenSpaceReleased() {
        while (true) {
            if (UI::IsKeyDown(UI::Key::Space)) yield();
            else break;
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        pmt.EnableEditorInputsCustomProcessing = false;
    }

    void Render() {
        if (!IsActive) return;
        if (gizmo is null) return;
        gizmo.Render();
    }

    // MARK: Enter Gizmo Mode

    // will enter gizmo mode if conditions are met. returns whether to block click, always false
    bool CheckEnterGizmoMode(CGameCtnEditorFree@ editor, bool lmb, bool rmb) {
        if (editor is null) return false;
        if (IsActive) return false;
        if (!lmb && !rmb) return false;
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
        wasInFreeBlockMode = Editor::IsInFreeBlockPlacementMode(editor, false);

        origItemPlacementMode = Editor::GetItemPlacementMode(false);
        origModeWasItem = Editor::IsInAnyItemPlacementMode(editor, false);
        origModeWasBlock = Editor::IsInBlockPlacementMode(editor, false);
        origCursorColor = editor.PluginMapType.NextMapElemColor;
        origModeType = origModeWasItem ? BlockOrItem::Item : BlockOrItem::Block;
        if (origModeWasItem) {
            dev_trace("Item placement mode: " + tostring(origItemPlacementMode));
        }
        Editor::SetCurrentPivot(editor, 0);

        shouldReplaceTarget = lmb;
        IsActive = true;
        // LMB: don't block click => ctrl+click will select the block/item for us
        if (lmb) return false;
        return true;
    }

    CGameEditorPluginMap::EditMode origEditMode;
    CGameEditorPluginMap::EPlaceMode origPlaceMode;
    CGameEditorPluginMap::EPlaceMode desiredGizmoPlaceMode;
    CGameEditorPluginMap::EMapElemColor origCursorColor;
    Editor::ItemMode origItemPlacementMode;
    bool origCustomYawActive;
    bool wasInFreeBlockMode = false;
    bool origModeWasItem = false;
    bool origModeWasBlock = false;
    BlockOrItem origModeType = BlockOrItem::Block;
    EditorRotation@ origCursor;
    CGameEditorPluginMap::EMapElemColor placingColor;
    bool origPlacementSwitchPivotManually = false;

    // LMB: remove target and select it
    // RMB: keep target, use current block/item
    bool shouldReplaceTarget = false;

    // MARK: Gizmo Loop

    void GizmoLoop() {
        auto app = GetApp();
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(app.Editor);
        Gizmo_Setup(editor);
        CustomCursorRotations::CustomYawActive = false;
        yield();
        bool isItem = modePlacingType == BlockOrItem::Item;
        CustomCursor::NoSetCursorVisFlagPatchActive = !isItem;
        if (isItem) CustomCursor::NoHideCursorItemModelsPatchActive = true;
        CustomCursor::NoShowCursorItemModelsPatchActive = !isItem;

        desiredGizmoPlaceMode = origPlaceMode;
        if (isItem) {
            desiredGizmoPlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
        } else if (origPlaceMode == CGameEditorPluginMap::EPlaceMode::FreeBlock) {
            // fix for offset in freeblock mode.
            desiredGizmoPlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
        }

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
                if (pmt.PlaceMode != desiredGizmoPlaceMode) {
                    pmt.PlaceMode = desiredGizmoPlaceMode;
                }
            }
            editor.Cursor.UseSnappedLoc = true;
            if (CustomCursorRotations::CustomYawActive) {
                CustomCursorRotations::CustomYawActive = false;
            }
            if (pmt.NextMapElemColor != placingColor) {
                placingColor = pmt.NextMapElemColor;
                origCursorColor = placingColor;
                dev_warn("Gizmo updated color to " + tostring(placingColor));
                CustomCursor::TriggerUpdateCursorItemModels(editor);
            }
            if (Editor::GetCurrentPivot(editor) != 0) {
                Editor::SetCurrentPivot(editor, 0);
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
    // separate picked target from thing we'll place (supports 'duplication' and 'place at' via RMB)
    BlockOrItem modePlacingType = BlockOrItem::Block;
    // when we get an item bounding box, it will be offset from the item location by some amount
    // vec3 modelOffset;

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

    float[] pivotYs = {0, 2, 8, 10, 16, 18, 24, 26, 32};

    void CycleYPivot() {
        auto pp = gizmo.PivotPointOrDest;
        float currPivotY = pp.y;
        for (uint i = 0; i < pivotYs.Length; i++) {
            if (currPivotY < pivotYs[i]) {
                ApplyPivot(vec3(pp.x, pivotYs[i], pp.z));
                return;
            }
        }
        ApplyPivot(vec3(pp.x, pivotYs[0], pp.z));
    }

    void CenterPivot() {
        gizmo.MovePivotTo(Axis::X, 0, true, false);
        gizmo.MovePivotTo(Axis::Y, 0, true, false);
        gizmo.MovePivotTo(Axis::Z, 0);
    }

    void ApplyPivot(vec3 newPivot) {
        gizmo.SetPivotPoint(newPivot);
    }


    // MARK: Setup

    void Gizmo_Setup(CGameCtnEditorFree@ editor) {
        if (editor is null) {
            IsActive = false;
            return;
        }
        _OnActive_UpdatePMT(editor.PluginMapType);

        modeTargetType = lastPickedType;
        modePlacingType =  shouldReplaceTarget ? lastPickedType : origModeType;
        @itemSpec = null;
        @blockSpec = null;
        lastAppliedPivot = vec3();
        bool applyingItem = modePlacingType == BlockOrItem::Item;
        bool modeMismatch = applyingItem != origModeWasItem;
        // modelOffset = vec3();

        // fix mode mismatch, otherwise we place blocks when gizmoing an item from block mode
        if (modeMismatch) {
            if (applyingItem) {
                origPlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
            } else {
                origPlaceMode = CGameEditorPluginMap::EPlaceMode::Block;
            }
        }

        // problem: we need to separate getting the spec from the edit mode setup.
        // We might have picked a block, but want to place an item there (if RMB), and not delete the original block.
        // so we need to get the blockspec, but turn it into an item spec with the relevant itemModel.
        // or vice versa, place a block at some location.



        CGameCtnBlock@ b;
        CGameCtnAnchoredObject@ item;
        vec3 targetPos;
        mat4 targetRot;
        vec3 targetSize;
        uint targetVariant;
        mat4 itemMat;
        CGameCtnBlockInfo@ placingBlockModel;
        CGameItemModel@ placingItemModel;

        if (modeTargetType == BlockOrItem::Block) {
            yield();
            if (lastPickedBlock is null || (@b = lastPickedBlock.AsBlock()) is null) {
                warn("no last picked block");
                IsActive = false;
                return;
            }
            @blockSpec = Editor::BlockSpecPriv(b);
            @placingBlockModel = b.BlockModel;
            targetPos = Editor::GetBlockLocation(b);
            targetRot = Editor::GetBlockRotationMatrix(b);
            targetSize = Editor::GetBlockSize(b);
            targetVariant = blockSpec.variant;
            placingColor = CGameEditorPluginMap::EMapElemColor(int(b.MapElemColor));
        } else {
            CGameCtnAnchoredObject@ item;
            if (lastPickedItem is null || (@item = lastPickedItem.AsItem()) is null) {
                warn("no last picked item");
                IsActive = false;
                return;
            }
            @itemSpec = Editor::ItemSpecPriv(item);
            @placingItemModel = item.ItemModel;
            targetPos = lastPickedItemPos;
            targetRot = lastPickedItemRot.GetMatrix();
            itemMat = Editor::GetItemMatrix(item);
            // @bb = Editor::GetItemAABB(placingItemModel);
            placingColor = CGameEditorPluginMap::EMapElemColor(int(item.MapElemColor));
        }

        if (!shouldReplaceTarget) {
            // color = users current
            placingColor = origCursorColor;

            // we always do this for blocks
            if (modePlacingType == BlockOrItem::Block) {
                targetVariant = Editor::GetCurrentBlockVariant(editor.Cursor);
                @placingBlockModel = Editor::GetSelectedBlockInfo(editor);
                targetSize = Editor::GetBlockSize(placingBlockModel);
            }

            // depending on whether the picked object is of the same type or not.
            if (modePlacingType != modeTargetType) {
                if (modePlacingType == BlockOrItem::Block) {
                    @blockSpec = cast<Editor::BlockSpecPriv>(itemSpec.ToBlockSpec(placingBlockModel, targetVariant, false));
                } else if (selectedItemModel !is null) {
                    @placingItemModel = selectedItemModel.AsItemModel();
                    @itemSpec = cast<Editor::ItemSpecPriv>(blockSpec.ToItemSpec(placingItemModel, Editor::GetCurrentPivot(editor), Editor::GetCurrentItemVariant(editor)));
                    itemMat = Editor::GetBlockMatrix(b);
                }
            } else {
                if (modePlacingType == BlockOrItem::Block) {
                    blockSpec.SetBlockInfo(placingBlockModel);
                    blockSpec.variant = targetVariant;
                    blockSpec.EnsureValidVariant();
                } else {
                    @placingItemModel = editor.CurrentItemModel;
                    itemSpec.SetModel(placingItemModel);
                    itemSpec.variantIx = Editor::GetCurrentItemVariant(editor);
                    auto pp = placingItemModel.DefaultPlacementParam_Content;
                    itemSpec.pivotPos = pp.PivotPositions.Length == 0 ? vec3() : pp.PivotPositions[Editor::GetCurrentPivot(editor) % pp.PivotPositions.Length];
                }
            }

            if (modePlacingType == BlockOrItem::Block) {
                blockSpec.color = CGameCtnBlock::EMapElemColor(int(placingColor));
            } else {
                itemSpec.color = CGameCtnAnchoredObject::EMapElemColor(int(placingColor));
            }
        }

        editor.PluginMapType.EditMode = CGameEditorPluginMap::EditMode::Place;

        if (modePlacingType == BlockOrItem::Block) {
            @bb = Editor::AABB(mat4::Translate(targetPos) * mat4::Inverse(targetRot), targetSize/2., targetSize/2.);
            if (!wasInFreeBlockMode) {
                editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::FreeBlock;
            }
            Editor::SetSelectedBlockInfo(editor, blockSpec.BlockInfo);
            yield();
            // testing
            Editor::SetCurrentBlockVariant(editor.Cursor, targetVariant);
        } else if (modePlacingType == BlockOrItem::Item) {
            origPlacementSwitchPivotManually = itemSpec.Model.DefaultPlacementParam_Content.SwitchPivotManually;
            itemSpec.Model.DefaultPlacementParam_Content.SwitchPivotManually = true;

            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
            CustomCursorRotations::SetCustomPYRAndCursor(itemSpec.pyr, editor.Cursor);
            yield(2);
            Editor::SetAllCursorPos(targetPos);
            @bb = Editor::GetSelectedItemAABB();
            if (bb is null) {
                warn("no selected item BB");
            } else {
                dev_trace("bb.pos before: " + bb.pos.ToString());
                // we need to account for the items pivot and default pivot
                lastAppliedPivot = itemSpec.pivotPos * -1;
                lastAppliedPivotIx = 0;
                auto pickedModel = itemSpec.Model;
                // ? why did we default to the first pivot? we had the pivot above.
                if (pickedModel.DefaultPlacementParam_Content.PivotPositions.Length > 0) {
                    lastAppliedPivot = pickedModel.DefaultPlacementParam_Content.PivotPositions[Editor::GetCurrentPivot(editor)];
                }

                itemSpec.Model.DefaultPlacementParam_Content.PlacementClass.CurVariant = itemSpec.variantIx;

                auto bbOrigPos = bb.pos;
                // main bb to use to set cursor // mat4::Inverse
                auto rot = (mat4::Translate(targetPos * -1.) * itemMat);
                auto relPivot = mat4::Translate((lastPickedItemPivot + lastAppliedPivot) * 1.);
                bb.mat = rot * relPivot;
                bb.mat = mat4::Translate(targetPos) * (bb.mat);
                bb.InvertRotation();
                // modelOffset = bb.pos - bbOrigPos;
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

        if (shouldReplaceTarget) {
            editor.PluginMapType.AutoSave();
            if (modeTargetType == BlockOrItem::Block) {
                // origPlaceMode = CGameEditorPluginMap::EPlaceMode::FreeBlock;
                if (blockSpec.isFree) {
                    Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
                    Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
                    Editor::SetEditorPickedBlock(editor, null);
                    Editor::DeleteFreeblocks(array<CGameCtnBlock@> = {lastPickedBlock.AsBlock()});
                    Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
                    Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
                } else {
                    Editor::DeleteBlocksAndItems({blockSpec}, {});
                }
                yield();
            } else {
                Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Item);
                Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
                Editor::DeleteBlocksAndItems({}, {itemSpec});
            }
        }

        Editor::SetAllCursorPos(bb.pos);
        @gizmo = RotationTranslationGizmo("gizmo").WithBoundingBox(bb)
            .WithOnApplyF(_GizmoOnApply).WithOnExitF(_GizmoOnCancel);

        if (modePlacingType == BlockOrItem::Item) {
            gizmo.WithPlacementParams(placingItemModel.DefaultPlacementParam_Content);
            // gizmo.pivotPoint = lastAppliedPivot;
        } else if (modePlacingType == BlockOrItem::Block) {
            // blocks are offset by 0.25 in the local y axis for the free-block cursor.
            // sometimes this is not necessary. IDK :/
            // if (S_Gizmo_ApplyBlockOffset && wasInFreeBlockMode) {
            //     gizmo.OffsetBlockOnStart();
            // }
        }

        editor.PluginMapType.NextMapElemColor = placingColor;
        Editor::SetAllCursorMat(gizmo.GetCursorMat());
        IsActive = true;
        // auto lookUv = Editor::DirToLookUvFromCamera(bb.pos);
        auto lookUv = Editor::GetCurrentCamState(editor).LookUV;
        if (S_Gizmo_MoveCameraOnStart) {
            Editor::SetCamAnimationGoTo(lookUv, bb.pos, bb.halfDiag.Length() * 4.);
        }

        yield();
    }

    void _GizmoUpdateBBFromSelected() {
        yield(2);
        if (gizmo is null) return;
        @bb = Editor::GetSelectedItemAABB();
        gizmo.WithBoundingBox(bb);
    }

    // MARK: Callbacks

    void _GizmoOnApply() {
        _GizmoOnApply_Params(true);
    }

    void _GizmoOnApplyAndContinue() {
        _GizmoOnApply_Params(false);
    }

    void _GizmoOnApply_Params(bool setInactiveAfter = true) {
        if (modePlacingType == BlockOrItem::Item) {
            dev_trace("Applying gizmo item: ");
            dev_trace("   lastAppliedPivot: " + lastAppliedPivot.ToString());
            dev_trace("   gizmo.placementParamOffset: " + gizmo.placementParamOffset.ToString());
            dev_trace("   gizmo.pivotPoint: " + gizmo.pivotPoint.ToString());
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            itemSpec.isFlying = 1;
            itemSpec.pivotPos = gizmo.GetPivot(Editor::GetCurrentPivot(editor)) * -1.; // - gizmo.placementParamOffset * 2.;
            itemSpec.pos = gizmo.pos + vec3(0, 56, 0) + gizmo.GetRotatedPivotPoint();
            itemSpec.coord = Int3ToNat3(PosToCoordDist(itemSpec.pos));
            itemSpec.pyr = EulerFromRotationMatrix(mat4::Inverse(gizmo.rot));
            itemSpec.color = CGameCtnAnchoredObject::EMapElemColor(int(placingColor));
            Editor::PlaceItems({itemSpec}, true);
        } else {
            // this will only unapply if it was applied earlier
            gizmo.OffsetBlockOnApply();
            blockSpec.flags = uint8(Editor::BlockFlags::Free);
            blockSpec.pos = gizmo.pos + vec3(0, 56, 0) + gizmo.GetRotatedPivotPoint();
            blockSpec.pyr = EulerFromRotationMatrix(mat4::Inverse(gizmo.rot));
            blockSpec.color = CGameCtnBlock::EMapElemColor(int(placingColor));
            Editor::PlaceBlocks({blockSpec}, true);
            startnew(_AfterApply_SetBlockSkin);
        }
        if (setInactiveAfter) {
            IsActive = false;
        }
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
        if (hadGizmo && shouldReplaceTarget) {
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            editor.PluginMapType.Undo();
        }
        IsActive = false;
    }

    void DisableGizmoInAsync(uint64 frames) {
        yield(frames);
        IsActive = false;
    }

    // MARK: Hotkeys

    void DrawHotkeysTable() {
        if (UI::BeginTable("gizmo hotkeys", 2)) {
            UI::TableSetupColumn("Hotkey", UI::TableColumnFlags::WidthStretch, .25);
            UI::TableSetupColumn("Action", UI::TableColumnFlags::WidthStretch, .75);
            // UI::TableHeadersRow();
            DrawHotkeyRow("Apply / Place (w/ Shift: and Continue)", hk_Apply);
            DrawHotkeyRow("Undo", hk_Undo);
            DrawHotkeyRow("Set Camera to Pivot", hk_ResetCam);
            DrawHotkeyRow("Cycle Pivot", hk_CyclePivot);
            DrawHotkeyRow("Cycle Y Pivot", hk_CycleYPivot);
            DrawHotkeyRow("Move Pivot to Bottom", hk_MovePivotBot);
            DrawHotkeyRow("Move Pivot to Top", hk_MovePivotTop);
            DrawHotkeyRow("Move Pivot to Back", hk_MovePivotZFwd);
            DrawHotkeyRow("Move Pivot to Front", hk_MovePivotZBack);
            DrawHotkeyRow("Move Pivot to Left", hk_MovePivotLeft);
            DrawHotkeyRow("Move Pivot to Right", hk_MovePivotRight);
            UI::EndTable();
        }
    }

    void DrawHotkeyRow(const string &in name, Hotkey@ hk) {
        UI::TableNextRow();
        UI::TableNextColumn();
        UI::Text(hk.formatted);
        UI::TableNextColumn();
        UI::Text(name);
    }

    Hotkey@ hk_Apply;
    Hotkey@ hk_ResetCam;
    Hotkey@ hk_CyclePivot;
    Hotkey@ hk_MovePivotBot;
    Hotkey@ hk_MovePivotTop;
    Hotkey@ hk_MovePivotZFwd;
    Hotkey@ hk_MovePivotZBack;
    Hotkey@ hk_MovePivotLeft;
    Hotkey@ hk_MovePivotRight;
    Hotkey@ hk_Undo;
    Hotkey@ hk_CycleYPivot;
    Hotkey@ hk_CenterPivot;

    void SetupGizmoHotkeysOnPluginStart() {
        @hk_Apply = AddHotkey(VirtualKey::Space, false, false, false, Gizmo::Hotkey_Apply, "Gizmo: Apply / Place", true);
        @hk_ResetCam = AddHotkey(VirtualKey::C, false, false, false, Gizmo::Hotkey_ResetCam, "Gizmo: Set Camera to Pivot");
        @hk_CyclePivot = AddHotkey(VirtualKey::Tab, false, false, false, Gizmo::Hotkey_CyclePivot, "Gizmo: Cycle Pivot");
        @hk_CycleYPivot = AddHotkey(VirtualKey::Y, false, false, false, Gizmo::Hotkey_CycleYPivot, "Gizmo: Cycle Y Pivot");
        @hk_MovePivotBot = AddHotkey(VirtualKey::Q, false, false, false, Gizmo::Hotkey_MovePivotBot, "Gizmo: Move Pivot to Bottom");
        @hk_MovePivotTop = AddHotkey(VirtualKey::E, false, false, false, Gizmo::Hotkey_MovePivotTop, "Gizmo: Move Pivot to Top");
        @hk_MovePivotZFwd = AddHotkey(VirtualKey::W, false, false, false, Gizmo::Hotkey_MovePivotZFwd, "Gizmo: Move Pivot to ZFwd");
        @hk_MovePivotZBack = AddHotkey(VirtualKey::S, false, false, false, Gizmo::Hotkey_MovePivotZBack, "Gizmo: Move Pivot to ZBack");
        @hk_MovePivotLeft = AddHotkey(VirtualKey::A, false, false, false, Gizmo::Hotkey_MovePivotLeft, "Gizmo: Move Pivot to Left");
        @hk_MovePivotRight = AddHotkey(VirtualKey::D, false, false, false, Gizmo::Hotkey_MovePivotRight, "Gizmo: Move Pivot to Right");
        @hk_Undo = AddHotkey(VirtualKey::U, false, false, false, Gizmo::Hotkey_Undo, "Gizmo: Undo");
        @hk_CenterPivot = AddHotkey(VirtualKey::R, false, false, false, Gizmo::Hotkey_CenterPivot, "Gizmo: Center Pivot");
    }

    UI::InputBlocking Hotkey_Apply() {
        if (IsActive) {
            if (IsShiftDown() ^^ S_Gizmo_InvertApplyModifier) {
                _GizmoOnApplyAndContinue();
            } else {
                _GizmoOnApply();
            }
        }
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_ResetCam() {
        if (IsActive) gizmo.FocusCameraOn(gizmo.pos);
        // block b/c 'C' can do something in editor to change item cursor stuff
        // might been because of auto pivot
        // return UI::InputBlocking::Block;
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_CyclePivot() {
        if (IsActive) CyclePivot();
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_CycleYPivot() {
        if (IsActive) CycleYPivot();
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_CenterPivot() {
        if (IsActive) CenterPivot();
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotBot() {
        if (IsActive) gizmo.MovePivotToVisual(Axis::Y, -1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotTop() {
        if (IsActive) gizmo.MovePivotToVisual(Axis::Y, 1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotZFwd() {
        if (IsActive) gizmo.MovePivotToVisual(Axis::Z, 1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotZBack() {
        if (IsActive) gizmo.MovePivotToVisual(Axis::Z, -1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotLeft() {
        if (IsActive) gizmo.MovePivotToVisual(Axis::X, -1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotRight() {
        if (IsActive) gizmo.MovePivotToVisual(Axis::X, 1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_Undo() {
        if (IsActive) gizmo.Undo();
        return UI::InputBlocking::DoNothing;
    }
}

// MARK: Settings

[Setting hidden]
bool S_Gizmo_MoveCameraOnStart = true;

#if DEV
bool D_Gizmo_DrawBoundingBox = true;
#else
bool D_Gizmo_DrawBoundingBox = false;
#endif
