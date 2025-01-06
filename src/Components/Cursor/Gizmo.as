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
        @gizmo = null;

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
        pmt.EnableEditorInputsCustomProcessing = false;
        pmt.HideEditorInterface = false;
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
        origModeType = origModeWasItem ? BlockOrItem::Item : BlockOrItem::Block;
        if (origModeWasItem) {
            dev_trace("Item placement mode: " + tostring(origItemPlacementMode));
        }

        shouldReplaceTarget = lmb;
        IsActive = true;
        // LMB: don't block click => ctrl+click will select the block/item for us
        if (lmb) return false;
        return true;
    }

    CGameEditorPluginMap::EditMode origEditMode;
    CGameEditorPluginMap::EPlaceMode origPlaceMode;
    CGameEditorPluginMap::EPlaceMode desiredGizmoPlaceMode;
    Editor::ItemMode origItemPlacementMode;
    bool origCustomYawActive;
    bool wasInFreeBlockMode = false;
    bool origModeWasItem = false;
    bool origModeWasBlock = false;
    BlockOrItem origModeType = BlockOrItem::Block;
    EditorRotation@ origCursor;

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
        }

        if (!shouldReplaceTarget) {
            if (modePlacingType == BlockOrItem::Block) {
                targetVariant = Editor::GetCurrentBlockVariant(editor.Cursor);
                @placingBlockModel = Editor::GetSelectedBlockInfo(editor);
                targetSize = Editor::GetBlockSize(placingBlockModel);
            }

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
            editor.PluginMapType.PlaceMode = CGameEditorPluginMap::EPlaceMode::Item;
            Editor::SetCurrentPivot(editor, 0);
            CustomCursorRotations::SetCustomPYRAndCursor(itemSpec.pyr, editor.Cursor);
            yield(2);
            Editor::SetAllCursorPos(targetPos);
            @bb = Editor::GetSelectedItemAABB();
            if (bb is null) {
                warn("no selected item BB");
            } else {
                dev_trace("bb.pos before: " + bb.pos.ToString());
                // we need to account for the items pivot and default pivot
                lastAppliedPivot = itemSpec.pivotPos;
                lastAppliedPivotIx = 0;
                auto pickedModel = itemSpec.Model;
                // ? why did we default to the first pivot? we had the pivot above.
                if (pickedModel.DefaultPlacementParam_Content.PivotPositions.Length > 0) {
                    lastAppliedPivot = pickedModel.DefaultPlacementParam_Content.PivotPositions[0];
                }

                itemSpec.Model.DefaultPlacementParam_Content.PlacementClass.CurVariant = itemSpec.variantIx;

                // main bb to use to set cursor // mat4::Inverse
                auto rot = (mat4::Translate(targetPos * -1.) * itemMat);
                auto relPivot = mat4::Translate(lastPickedItemPivot + lastAppliedPivot);
                bb.mat = rot * relPivot;
                bb.mat = mat4::Translate(targetPos) * (bb.mat);
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
        CustomCursor::NoHideCursorItemModelsPatchActive = false;
        CustomCursor::NoShowCursorItemModelsPatchActive = false;
        if (modePlacingType == BlockOrItem::Item) {
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
            // this will only unapply if it was applied earlier
            gizmo.OffsetBlockOnApply();
            blockSpec.flags = uint8(Editor::BlockFlags::Free);
            blockSpec.pos = gizmo.pos + vec3(0, 56, 0) + gizmo.GetRotatedPivotPoint();
            blockSpec.pyr = EulerFromRotationMatrix(mat4::Inverse(gizmo.rot));
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
            DrawHotkeyRow("Apply / Place", hk_Apply);
            DrawHotkeyRow("Place & Continue", hk_ApplyAndContinue);
            DrawHotkeyRow("Set Camera to Pivot", hk_ResetCam);
            DrawHotkeyRow("Cycle Pivot", hk_CyclePivot);
            DrawHotkeyRow("Move Pivot to Bottom", hk_MovePivotBot);
            DrawHotkeyRow("Move Pivot to Top", hk_MovePivotTop);
            DrawHotkeyRow("Move Pivot to Back", hk_MovePivotBack);
            DrawHotkeyRow("Move Pivot to Front", hk_MovePivotFront);
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
    Hotkey@ hk_ApplyAndContinue;
    Hotkey@ hk_ResetCam;
    Hotkey@ hk_CyclePivot;
    Hotkey@ hk_MovePivotBot;
    Hotkey@ hk_MovePivotTop;
    Hotkey@ hk_MovePivotBack;
    Hotkey@ hk_MovePivotFront;
    Hotkey@ hk_MovePivotLeft;
    Hotkey@ hk_MovePivotRight;

    void SetupGizmoHotkeysOnPluginStart() {
        @hk_Apply = AddHotkey(VirtualKey::Space, false, false, false, Gizmo::Hotkey_Apply, "Gizmo: Apply / Place");
        @hk_ApplyAndContinue = AddHotkey(VirtualKey::Space, false, false, true, Gizmo::Hotkey_ApplyAndContinue, "Gizmo: Place & Continue");
        @hk_ResetCam = AddHotkey(VirtualKey::C, false, false, false, Gizmo::Hotkey_ResetCam, "Gizmo: Set Camera to Pivot");
        @hk_CyclePivot = AddHotkey(VirtualKey::Tab, false, false, false, Gizmo::Hotkey_CyclePivot, "Gizmo: Cycle Pivot");
        @hk_MovePivotBot = AddHotkey(VirtualKey::Q, false, false, false, Gizmo::Hotkey_MovePivotBot, "Gizmo: Move Pivot to Bottom");
        @hk_MovePivotTop = AddHotkey(VirtualKey::E, false, false, false, Gizmo::Hotkey_MovePivotTop, "Gizmo: Move Pivot to Top");
        @hk_MovePivotBack = AddHotkey(VirtualKey::W, false, false, false, Gizmo::Hotkey_MovePivotBack, "Gizmo: Move Pivot to Back");
        @hk_MovePivotFront = AddHotkey(VirtualKey::S, false, false, false, Gizmo::Hotkey_MovePivotFront, "Gizmo: Move Pivot to Front");
        @hk_MovePivotLeft = AddHotkey(VirtualKey::A, false, false, false, Gizmo::Hotkey_MovePivotLeft, "Gizmo: Move Pivot to Left");
        @hk_MovePivotRight = AddHotkey(VirtualKey::D, false, false, false, Gizmo::Hotkey_MovePivotRight, "Gizmo: Move Pivot to Right");
    }

    UI::InputBlocking Hotkey_Apply() {
        if (IsActive) _GizmoOnApply();
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_ApplyAndContinue() {
        if (IsActive) _GizmoOnApplyAndContinue();
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_ResetCam() {
        if (IsActive) gizmo.FocusCameraOn(gizmo.pos);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_CyclePivot() {
        if (IsActive) CyclePivot();
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotBot() {
        if (IsActive) gizmo.MovePivotTo(Axis::Y, 0);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotTop() {
        if (IsActive) gizmo.MovePivotTo(Axis::Y, 1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotBack() {
        if (IsActive) gizmo.MovePivotTo(Axis::Z, 0);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotFront() {
        if (IsActive) gizmo.MovePivotTo(Axis::Z, 1);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotLeft() {
        if (IsActive) gizmo.MovePivotTo(Axis::X, 0);
        return UI::InputBlocking::DoNothing;
    }

    UI::InputBlocking Hotkey_MovePivotRight() {
        if (IsActive) gizmo.MovePivotTo(Axis::X, 1);
        return UI::InputBlocking::DoNothing;
    }
}

// MARK: Settings

[Setting hidden]
bool S_Gizmo_MoveCameraOnStart = true;
