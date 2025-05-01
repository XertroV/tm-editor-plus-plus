namespace MacroblockRecorder {
    // The MB being recorded currently.
    Editor::MacroblockSpecPriv@ recordingMB;
    // The recorded MB to move into copy-paste.
    Editor::MacroblockSpecPriv@ recordedMB;

    [Setting hidden]
    bool S_RecordMB_ForceAir = true;
    [Setting hidden]
    bool S_RecordMB_ForceFree = false;
    [Setting hidden]
    bool S_RecordMB_ForceGround = false;
    [Setting hidden]
    bool S_RecordMB_SaveAfterMbConstruction = true;
    [Setting hidden]
    bool S_RecordMB_Save_AutoNameAndSave = false;
    [Setting hidden]
    Editor::AlignWithinBlock S_RecordMB_AlignWithinBlock = Editor::AlignWithinBlock::None;

    bool get_IsActive() {
        return recordingMB !is null;
    }

    Editor::MacroblockSpec@ GetRecordingMB() {
        return recordingMB;
    }

    void StartRecording() {
        if (recordingMB is null) {
            @recordingMB = Editor::MacroblockSpecPriv();
        } else {
            NotifyWarning("MacroblockRecorder is already recording.");
        }
    }

    void StopRecording(bool cancel) {
        if (recordingMB is null) {
            NotifyWarning("MacroblockRecorder cannot stop because it is not recording.");
            return;
        }
        // possible 1 frame race condition with _WillRun but we don't expect this to be an issue normally.
        if (_WillRun) NotifyWarning("MacroblockRecorder: StopRecording called while _WillRun is true. Some events might be dropped.");
        if (!cancel) {
            // this will reference the recordingMB so it's not lost.
            OnFinishedRecording();
        }
        @recordingMB = null;
    }

    void RegisterCallbacks() {
        RegisterNewItemCallback(OnNewItem, "MacroblockRecorder");
        RegisterNewBlockCallback(OnNewBlock, "MacroblockRecorder");
        RegisterItemDeletedCallback(OnItemDeleted, "MacroblockRecorder");
        RegisterBlockDeletedCallback(OnBlockDeleted, "MacroblockRecorder");
    }

    CGameCtnAnchoredObject@[] newItems;
    CGameCtnBlock@[] newBlocks;
    CGameCtnAnchoredObject@[] removedItems;
    CGameCtnBlock@[] removedBlocks;
    bool _WillRun = false;

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (recordingMB !is null && item !is null) {
            item.MwAddRef();
            newItems.InsertLast(item);
            if (!_WillRun) OnChanged_RunSoon();
        }
        return false;
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        if (recordingMB !is null && block !is null) {
            block.MwAddRef();
            newBlocks.InsertLast(block);
            if (!_WillRun) OnChanged_RunSoon();
        }
        return false;
    }

    bool OnItemDeleted(CGameCtnAnchoredObject@ item) {
        if (recordingMB !is null && item !is null) {
            item.MwAddRef();
            removedItems.InsertLast(item);
            if (!_WillRun) OnChanged_RunSoon();
        }
        return false;
    }

    bool OnBlockDeleted(CGameCtnBlock@ block) {
        if (recordingMB !is null && block !is null) {
            block.MwAddRef();
            removedBlocks.InsertLast(block);
            if (!_WillRun) OnChanged_RunSoon();
        }
        return false;
    }

    void OnChanged_RunSoon() {
        if (_WillRun) return;
        _WillRun = true;
        startnew(OnChanged_Run);
    }

    // Run after all placements done so that effects like jitter already happened.
    void OnChanged_Run() {
        _WillRun = false;

        if (recordingMB !is null) {
            // ~~remove before adding to avoid issues with the order of events (though shouldn't be an issue)~~
            for (uint i = 0; i < newItems.Length; i++) { recordingMB.AddItem1(newItems[i]).SetCoordAndFlying(); }
            for (uint i = 0; i < newBlocks.Length; i++) { recordingMB.AddBlock(newBlocks[i]); }
            for (uint i = 0; i < removedItems.Length; i++) { _RemoveMbItem(removedItems[i]); }
            for (uint i = 0; i < removedBlocks.Length; i++) { _RemoveMbBlock(removedBlocks[i]); }
        }

        ClearAllCachedObjects();
    }

    void _RemoveMbBlock(CGameCtnBlock@ block) {
        // assumes recordingMB is not null
        for (uint i = 0; i < recordingMB.Blocks.Length; i++) {
            if (recordingMB.Blocks[i].MatchesBlock(block)) {
                recordingMB.Blocks.RemoveAt(i);
                return;
            }
        }
        NotifyWarning("MacroblockRecorder: Could not find block to remove: " + block.BlockInfo.Name + " at " + block.Coord.ToString());
    }

    void _RemoveMbItem(CGameCtnAnchoredObject@ item) {
        // assumes recordingMB is not null
        for (uint i = 0; i < recordingMB.Items.Length; i++) {
            if (recordingMB.Items[i].MatchesItem(item)) {
                recordingMB.Items.RemoveAt(i);
                return;
            }
        }
        NotifyWarning("MacroblockRecorder: Could not find item to remove: " + item.ItemModel.Name + " at " + item.AbsolutePositionInMap.ToString());
    }


    void ClearAllCachedObjects() {
        for (uint i = 0; i < newItems.Length; i++) {
            newItems[i].MwRelease();
        }
        for (uint i = 0; i < newBlocks.Length; i++) {
            newBlocks[i].MwRelease();
        }
        for (uint i = 0; i < removedItems.Length; i++) {
            removedItems[i].MwRelease();
        }
        for (uint i = 0; i < removedBlocks.Length; i++) {
            removedBlocks[i].MwRelease();
        }
        newItems.RemoveRange(0, newItems.Length);
        newBlocks.RemoveRange(0, newBlocks.Length);
        removedItems.RemoveRange(0, removedItems.Length);
        removedBlocks.RemoveRange(0, removedBlocks.Length);
    }

    void OnFinishedRecording() {
        @recordedMB = recordingMB;
        startnew(OnFinishedRecording_Async);
    }

    void OnFinishedRecording_Async() {
        _AwaitCursorControl();
        TransferRecordedMbToEditorCopyPasteMb(recordedMB);
    }

    const string mbRecorderInputsControlName = "MbRecorder::TransferRecordedMbToEditorCopyPasteMb";
    void _AwaitCursorControl() {
        if (!CursorControl::RequestExclusiveControl(mbRecorderInputsControlName)) {
            NotifyWarning("MacroblockRecorder: waiting for " + CursorControl::_ExclusiveControlName + " to finish.");
            while (!CursorControl::RequestExclusiveControl(mbRecorderInputsControlName)) yield();
        }
    }

    void TransferRecordedMbToEditorCopyPasteMb(Editor::MacroblockSpecPriv@ mb) {
        // throw("Hmm got an infinite loop");
        auto app = GetApp();
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) return;
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
        // safety check
        CursorControl::EnsureExclusiveOwnedBy(mbRecorderInputsControlName);

        // if we are already in copy paste or macroblock mode, we should exit it
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Block);

        // now we need to manipulate the editor's copy-paste macroblock
        auto copyPasteMb = SetManipulatingMB(editor.CopyPasteMacroBlockInfo);
        if (copyPasteMb is null) {
            dev_trace("CopyPasteMacroBlockInfo is null; copying all...");
            pmt.CopyPaste_SelectAll();
            pmt.CopyPaste_Copy();
            if ((@copyPasteMb = SetManipulatingMB(editor.CopyPasteMacroBlockInfo)) is null) NotifyError("CopyPasteMacroBlockInfo is null after CopyPaste_Copy()!");
            else {
                auto tmp = DGameCtnMacroBlockInfo(copyPasteMb);
                dev_trace("MB.Blocks: " + tmp.Blocks.Length);
                dev_trace("MB.Items: " + tmp.Items.Length);
            }
        }

        // otherwise, populate its macroblock
        if (!mb.MacroblockHasSufficientCapacity(copyPasteMb)) {
            dev_trace("MacroblockRecorder: CopyPaste macroblock does not have sufficient capacity; selecting region and copying.");
            dev_trace("MacroblockRecorder: Missing " + mb.missingMBCapacityBlocks + " blocks and " + mb.missingMBCapacityItems + " items.");
            // we need to increase its capacity
            // pmt.CopyPaste_ResetSelection();
            pmt.CopyPaste_AddOrSubSelection(mb.GetMinBlockCoords() -1, mb.GetMaxBlockCoords() + 1);
            pmt.CopyPaste_Copy();
            @copyPasteMb = SetManipulatingMB(editor.CopyPasteMacroBlockInfo);
            CheckForNoValidBlocksMsgAndDismiss(app);

            if (!mb.MacroblockHasSufficientCapacity(copyPasteMb)) {
                dev_warn("MacroblockRecorder: CopyPaste macroblock does not have sufficient capacity after 1st copy.");
                dev_warn("MacroblockRecorder: Missing " + mb.missingMBCapacityBlocks + " blocks and " + mb.missingMBCapacityItems + " items.");
                // pmt.CopyPaste_ResetSelection();
                // pmt.CopyPaste_AddOrSubSelection(int3(-2147483648), int3(2147483647));
                pmt.CopyPaste_SelectAll();
                pmt.CopyPaste_Copy();
                @copyPasteMb = SetManipulatingMB(editor.CopyPasteMacroBlockInfo);
            }
        }
        CheckForNoValidBlocksMsgAndDismiss(app);
        // after resetting selection, the MB is cleared; we fix this later. (We want to reset selection before bailing out if it fails)
        pmt.CopyPaste_ResetSelection();

        // check we're all good
        if (!mb.MacroblockHasSufficientCapacity(copyPasteMb) || copyPasteMb is null) {
            NotifyError("Unable to create a macroblock large enough for the recording.  "
                "Please place at least: " + mb.missingMBCapacityBlocks + " blocks and " + mb.missingMBCapacityItems + " items.");
            // throws
            BailOut_OnFinishedRecording();
        }

        // after resetting selection, the MB is cleared; set it back.
        Dev::SetOffset(editor, O_EDITOR_CopyPasteMacroBlockInfo, copyPasteMb);
        copyPasteMb.MwAddRef();
        Dev::SetOffset(editor, O_EDITOR_CurrentMacroBlockInfo, copyPasteMb);
        copyPasteMb.MwAddRef();

        // undo the +56 to pos.y
        mb.UndoMacroblockHeightOffset();

        // save coords for later use
        // Editor::ClearSelectedCoordsBuffer(editor);
        auto startCoord = mb.GetMinBlockCoords();// - int3(1, 8, 1);
        auto endCoord = mb.GetMaxBlockCoords();// + int3(1, 8, 1) + 1;

        // move the contents of the macroblock into the smallest area
        mb.MoveAllToOrigin();
        if (S_RecordMB_AlignWithinBlock != Editor::AlignWithinBlock::None) {
            mb.AlignAll(S_RecordMB_AlignWithinBlock);
        }
        nat3 mbSize = mb.GetCoordSize();
        bool hasGround = mb.HasGround();
        if (S_RecordMB_ForceFree) mb.SetAllBlocksFree();
        mb.SetAllItemsFlying();

        // okay, now write to MB
        mb._WriteDirectlyToMacroblock(copyPasteMb);
        dev_trace("Size before: " + Editor::GetMacroblockCoordSize(copyPasteMb).ToString());
        Editor::SetMacroblockCoordSize(copyPasteMb, mbSize);
        dev_trace("Size after: " + Editor::GetMacroblockCoordSize(copyPasteMb).ToString());
        bool setGround = hasGround && !S_RecordMB_ForceAir && !S_RecordMB_ForceFree;
        Editor::SetMacroblockGround(copyPasteMb, setGround);
        if (copyPasteMb.GeneratedBlockInfo.VariantGround !is null) {
            copyPasteMb.GeneratedBlockInfo.VariantGround.AutoTerrainPlaceType = CGameCtnBlockInfoVariantGround::EnumAutoTerrainPlaceType::DoNotPlace;
        }
        copyPasteMb.Connected = false;
        copyPasteMb.Initialized = false;
        dev_trace("Setting macroblock generated block info null");
        Dev::SetOffset(copyPasteMb, O_MACROBLOCKINFO_GeneratedBlockInfo, uint64(0));

        // dev_trace("Setting macroblock temp FID");
        // SetNodFid(copyPasteMb, Drive::User, "Blocks/Stadium/_epp_tmp.Macroblock.Gbx");
        // pmt.SaveMacroblock(copyPasteMb);

        dev_trace("Changing placement mode");

        // Editor::SetMacroblockSize
        // now change to copy-paste mode
        // todo: test while in view/cam mode
        // Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
        // Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CopyPaste);
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeMacroblock);
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CopyPaste);
        // pmt.Select

        if (copyPasteMb.GeneratedBlockInfo !is null && copyPasteMb.GeneratedBlockInfo.VariantGround !is null) {
            // bounds can be too big so reset
            copyPasteMb.GeneratedBlockInfo.VariantGround.ResetVariantCompletely();
            // but now size is 1,1,1 again, so set it
            Editor::SetMacroblockCoordSize(copyPasteMb, mbSize);
        }
        auto camState = Editor::CamState(editor.OrbitalCameraControl);

        if (S_RecordMB_SaveAfterMbConstruction) {
            // now, save the macroblock -- this overwrites our hard work so we need to hook
            // the recreation of it (from the selection) so we can replace the new macroblock with ours

            // we don't need the patch if we're moving blocks and items in the map to fool selection
            // _ApplySaveMbPatch();
            auto topRightCornerMin = Nat3ToInt3(editor.Challenge.Size) - 7;
            auto topRightCornerMid = Nat3ToInt3(editor.Challenge.Size) - 4;
            auto topRightCornerMax = Nat3ToInt3(editor.Challenge.Size) - 1;

            try {
                dev_trace("Move items in map if not in macroblock");
                // set selection coords then modify all blocks and items to
                // move coords/positions out of the way. After, move them back.
                ModifyMapObjects_SetCoordsOutside_Filtered(editor.Challenge, startCoord, endCoord, mb);

                _Patcher_AllowEmptyMacroblockCreation.Apply();

                dev_trace("Set selection coords to: " + startCoord.ToString() + " / " + endCoord.ToString());
                pmt.CopyPaste_ResetSelection();
                pmt.CopyPaste_AddOrSubSelection(startCoord, endCoord);
                // auto nbSelected =
                // pmt.CopyPaste_AddOrSubSelection(topRightCornerMin, topRightCornerMax); // add it so we know we can remove it later
                pmt.CopyPaste_Copy();
                yield();
                // pmt.CopyPaste_ResetSelection();
                // pmt.CopyPaste_AddOrSubSelection(startCoord, endCoord); // just main
                // pmt.CopyPaste_AddOrSubSelection(topRightCornerMin, topRightCornerMax); // remove it
                // pmt.CopyPaste_Copy();


                dev_trace("run click save macroblock (in copy paste toolbar)");
                // activates hook and sets up 3d scene for the macroblock
                CControl::Editor_FrameCopyPaste_SaveMacroblock.OnAction();
                _Patcher_AllowEmptyMacroblockCreation.Unapply();
                yield();

                dev_trace('set camera and rotate');
                // bug: thumbnail won't show :/
                // Editor::SetSnapCameraLocation(editor, camState.Loc);
                // Editor::SetSnapCameraPosition(editor, camState.CamPos);
                auto rotateCamBtn = CControl::Editor_FrameEditSnap_RotateCameraBtn;
                while (!rotateCamBtn.IsVisible || !rotateCamBtn.Parent.IsVisible) {
                    dev_trace("yield: rotateBtnVisibility");
                    yield();
                }
                rotateCamBtn.OnAction();

                // ~~this works, but does let you place it outside the stadium (size 1,1,1 on reloading sometimes) which~~
                if (S_RecordMB_Save_AutoNameAndSave) {
                    yield();
                    auto saveSnapMbBtn = CControl::Editor_FrameEditSnap_SaveBtn;
                    while (!saveSnapMbBtn.IsVisible || !saveSnapMbBtn.Parent.IsVisible) {
                        dev_trace("yield: saveSnapMbBtnVisibility");
                        yield();
                    }
                    saveSnapMbBtn.OnAction();
                    while (GetDialogSaveAs() is null) {
                        dev_trace("yield: get dialog save as");
                        yield();
                    }
                    if (SetSaveAsDialogEntryPath("_epp_tmp.Macroblock.Gbx")) {
                        ClickConfirmOpenOrSaveDialog();
                        // in case we have an overwrite prompt
                        yield();
                        app.BasicDialogs.AskYesNo_Yes();
                    } else {
                        NotifyError("Failed to set save-as path.");
                        yield();
                        app.BasicDialogs.HideDialogs();
                    }
                }
            } catch {
                NotifyError("MacroblockRecorder: Failed to automate saving macroblock. " + getExceptionInfo());
            }
            // todo: unapply patch
            _UnapplySaveMbPatch();
            ModifyMapObjects_SetCoords_Reset();
        }


        CursorControl::ReleaseExclusiveControl(mbRecorderInputsControlName);

        // pmt.Cursor.Move(CGameEditorPluginMap::ECardinalDirections8::North);
        // pmt.Cursor.Move(CGameEditorPluginMap::ECardinalDirections8::South);
        pmt.Cursor.Raise();
        pmt.Cursor.Lower();

        if (_manipulating.GeneratedBlockInfo !is null) {
            // do this after we change placement mode too.
            if (_manipulating.GeneratedBlockInfo.VariantGround !is null) {
                _manipulating.GeneratedBlockInfo.VariantGround.AutoTerrainPlaceType = CGameCtnBlockInfoVariantGround::EnumAutoTerrainPlaceType::DoNotPlace;
            }
        } else {
            dev_warn("MacroblockRecorder: Generated block info is null");
        }
    }

    CGameCtnMacroBlockInfo@ _manipulating;
    CGameCtnMacroBlockInfo@ SetManipulatingMB(CGameCtnMacroBlockInfo@ mb) {
        if (mb !is null) mb.MwAddRef();
        if (_manipulating !is null) _manipulating.MwRelease();
        @_manipulating = mb;
        return mb;
    }

    void BailOut_OnFinishedRecording() {
        // release exclusive control
        CursorControl::ReleaseExclusiveControl(mbRecorderInputsControlName);
        // move the recorded macroblock back to recording
        @recordingMB = recordedMB;
        @recordedMB = null;
        throw("Nonfatal / Safe: Bailing out of OnFinishedRecording.");
    }

    void CheckForNoValidBlocksMsgAndDismiss(CGameCtnApp@ app) {
        if (app.ActiveMenus.Length > 0) {
            app.BasicDialogs.HideDialogs();
        }
    }

    const string Patch_NopSetCopyPasteMbInfo = "E8 ?? ?? ?? ?? 49 8B 85 ?? 06 00 00";
    // MemPatcher@ _Patcher_NopSetCopyPasteMbInfo = MemPatcher(Patch_NopSetCopyPasteMbInfo, {0}, {"90 90 90 90 90"});
    FunctionHookHelper@ _Hook_CallSetCopyPasteMbInfo = FunctionHookHelper(Patch_NopSetCopyPasteMbInfo, 0, 0, "MacroblockRecorder::_On_SetCopyPasteMbInfo", Dev::PushRegisters::Basic, true);

    // hooks CGameCtnMacroBlockInfo::GenerateBlockInfo(mbInfo)
    // const string Pattern_OnUpdateCopyPasteMbInfo = "40 53 48 83 EC 20 48 8B D9 E8 ?? ?? ?? ?? 33 D2 89 83 ?? 01 00 00";
    // HookHelper@ _OnUpdateCopyPasteMbInfo_Hook = HookHelper(Pattern_OnUpdateCopyPasteMbInfo, 0x0, 0x1, "MacroblockRecorder::_OnUpdateCopyPasteMbInfo", Dev::PushRegisters::Basic, false);

    const string Patch_AllowEmptyMacroblockCreation = "89 4d c0 45 85 ed 0f 85 ?? 01 00 00";
    MemPatcher@ _Patcher_AllowEmptyMacroblockCreation = MemPatcher(Patch_AllowEmptyMacroblockCreation, {6}, {"90 e9"});

    void _On_SetCopyPasteMbInfo() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        Dev::SetOffset(editor, O_EDITOR_CopyPasteMacroBlockInfo, _manipulating);
        _manipulating.MwAddRef();
        Dev::SetOffset(editor, O_EDITOR_CurrentMacroBlockInfo, _manipulating);
        _manipulating.MwAddRef();
    }

    // not needed
    void _OnUpdateCopyPasteMbInfo(CGameCtnMacroBlockInfo@ rcx) {
        if (rcx is null) {
            dev_warn("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; rcx is null");
            return;
        }
        dev_trace("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; rcx: " + rcx.Name + " refcount: " + Reflection::GetRefCount(rcx));
        if (_manipulating is null) {
            dev_warn("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; _manipulating is null");
            return;
        }
        /* for inner hook */
        recordedMB._WriteDirectlyToMacroblock(rcx);
        // dev_trace("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; _MacroblockInfo_SwapBuffers");
        // _MacroblockInfo_SwapBuffers(rcx, _manipulating);
        // for good luck
        // rcx.MwAddRef();
        // _manipulating.MwAddRef();
        // SetManipulatingMB(rcx);
        dev_trace("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; _MacroblockInfo_SwapBuffers Done");
        // unhook self, only called once
        // _UnapplySaveMbPatch();
    }

    // void _MacroblockInfo_SwapBuffers(CGameCtnMacroBlockInfo@ a, CGameCtnMacroBlockInfo@ b) {
    //     Dev_SwapUint64At(a, b, O_MACROBLOCK_BLOCKSBUF);
    //     Dev_SwapUint64At(a, b, O_MACROBLOCK_BLOCKSBUF+8);
    //     Dev_SwapUint64At(a, b, O_MACROBLOCK_ITEMSBUF);
    //     Dev_SwapUint64At(a, b, O_MACROBLOCK_ITEMSBUF+8);
    //     Dev_SwapUint64At(a, b, O_MACROBLOCK_SKINSBUF);
    //     Dev_SwapUint64At(a, b, O_MACROBLOCK_SKINSBUF+8);
    // }

    void _ApplySaveMbPatch() {
        // if (_OnUpdateCopyPasteMbInfo_Hook.IsApplied()) return;
        dev_trace("MacroblockRecorder::_ApplySaveMbPatch();");
        // _Patcher_NopSetCopyPasteMbInfo.Apply();
        // _OnUpdateCopyPasteMbInfo_Hook.Apply();
        _Hook_CallSetCopyPasteMbInfo.Apply();
        _Patcher_AllowEmptyMacroblockCreation.Apply();
    }
    void _UnapplySaveMbPatch() {
        // if (!_OnUpdateCopyPasteMbInfo_Hook.IsApplied()) return;
        dev_trace("MacroblockRecorder::_UnapplySaveMbPatch();");
        // _Patcher_NopSetCopyPasteMbInfo.Unapply();
        // _OnUpdateCopyPasteMbInfo_Hook.Unapply();
        _Hook_CallSetCopyPasteMbInfo.Unapply();
        _Patcher_AllowEmptyMacroblockCreation.Unapply();
    }

    // MARK: Modify map objects for thumbnail

    Helper_ModifyMapObjCoords@ thumbnailMapCoordsHelper;

    // Modifies the map objects' block coord to be outside of the selection (start, end); ignoring objects in the mb spec.
    void ModifyMapObjects_SetCoordsOutside_Filtered(CGameCtnChallenge@ map, int3 start, int3 end, Editor::MacroblockSpecPriv@ filterMb) {
        @thumbnailMapCoordsHelper = Helper_ModifyMapObjCoords(map, start, end, filterMb);
        thumbnailMapCoordsHelper.Run();
    }

    void ModifyMapObjects_SetCoords_Reset() {
        if (thumbnailMapCoordsHelper !is null) {
            thumbnailMapCoordsHelper.Reset();
            @thumbnailMapCoordsHelper = null;
        }
    }
}


class Helper_ModifyMapObjCoords {
    CGameCtnChallenge@ map;
    int3 start;
    int3 end;
    // do not touch blocks/items referenced by the mb
    Editor::MacroblockSpecPriv@ mb;

    nat3 targetCoord;
    vec3 targetPos;

    Helper_ModifyMapObjCoords(CGameCtnChallenge@ map, int3 start, int3 end, Editor::MacroblockSpecPriv@ mb) {
        @this.map = map;
        map.MwAddRef();
        this.start = start;
        this.end = end;
        @this.mb = mb;
        FindSuitableTargets();
    }

    ~Helper_ModifyMapObjCoords() {
        Reset();
    }

    void FindSuitableTargets() {
        targetCoord = map.Size - nat3(4, 4, 4);
        targetPos = CoordToPos(targetCoord);
        // if (start.x > 4 && start.y > 4 && start.z > 4) {
        //     targetCoord = nat3();
        //     targetPos = vec3();
        // } else if (end.x < (map.Size.x - 5) && end.y < (map.Size.y - 5) && end.z < (map.Size.z - 5)) {
        //     targetCoord = map.Size - 1;
        //     targetPos = CoordToPos(targetCoord);
        // } else {
        // }
    }

    ModifiedMapObj@[] modified;
    uint64[] filteredBlocks;
    uint64[] filteredItems;

    void Run() {
        SetUpFiltered();
        MoveBlocks_Filtered();
        MoveItems_Filtered();
    }

    void Reset() {
        for (uint i = 0; i < modified.Length; i++) {
            modified[i].Restore();
        }
        modified.RemoveRange(0, modified.Length);
        if (map !is null) {
            map.MwRelease();
            @map = null;
        }
    }

    protected void SetUpFiltered() {
        filteredBlocks.Reserve(mb.Blocks.Length);
        filteredItems.Reserve(mb.Items.Length);
        // get all blocks/items in the mb
        for (uint i = 0; i < mb.Blocks.Length; i++) {
            filteredBlocks.InsertLast(cast<Editor::BlockSpecPriv>(mb.Blocks[i]).ObjPtr);
        }
        for (uint i = 0; i < mb.Items.Length; i++) {
            filteredItems.InsertLast(cast<Editor::ItemSpecPriv>(mb.Items[i]).ObjPtr);
        }
    }

    protected void MoveBlocks_Filtered() {
        auto nbBlocksInMap = map.Blocks.Length;
        auto grassMwIdValue = GetMwId("Grass");
        bool seenGrass = false;
        for (uint i = 0; i < map.Blocks.Length; i++) {
            auto block = map.Blocks[i];
            // skip grass
            if (!seenGrass && block.BlockInfo.Id.Value == grassMwIdValue) {
                seenGrass = true;
                auto testIx = map.Size.x * map.Size.z - 1 + i;
                if (testIx < nbBlocksInMap && map.Blocks[testIx].BlockInfo.Id.Value == grassMwIdValue) {
                    i = testIx;
                }
                continue;
            }
            auto blockPtr = Dev_GetPointerForNod(block);
            if (filteredBlocks.Find(blockPtr) != -1) {
                dev_trace("Skipping filtered block; ix: " + i + " / " + nbBlocksInMap);
                continue;
            }
            // otherwise, let's move it
            MoveBlock(block);
        }
        if (!seenGrass) {
            Dev_NotifyWarning("MacroblockRecorder: No grass found in map.  This is a bug.");
        }
    }

    protected void MoveItems_Filtered() {
        auto nbItemsInMap = map.AnchoredObjects.Length;
        for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
            auto item = map.AnchoredObjects[i];
            auto itemPtr = Dev_GetPointerForNod(item);
            if (filteredItems.Find(itemPtr) != -1) {
                dev_trace("Skipping filtered item; ix: " + i + " / " + nbItemsInMap);
                continue;
            }
            MoveItem(item);
        }
    }

    void MoveBlock(CGameCtnBlock@ block) {
        if (block is null) return;
        modified.InsertLast(MovedBlockInMap(block, targetCoord, targetPos));
    }

    void MoveItem(CGameCtnAnchoredObject@ item) {
        if (item is null) return;
        modified.InsertLast(MovedItemInMap(item, targetCoord, targetPos));
    }
}

class ModifiedMapObj {
    ModifiedMapObj() {}
    void Restore() {}
}

class MovedBlockInMap : ModifiedMapObj {
    CGameCtnBlock@ block;
    nat3 oldCoord;
    vec3 oldPos;

    MovedBlockInMap(CGameCtnBlock@ block, nat3 newCoord, vec3 newPos) {
        SetBlock(block);
        this.oldCoord = block.Coord;
        this.oldPos = Editor::GetBlockLocation(block, true);
        if (Editor::IsBlockFree(block)) {
            Editor::SetBlockLocation(block, oldPos + newPos);
        } else {
            Editor::SetBlockCoord(block, oldCoord + newCoord);
        }
    }

    ~MovedBlockInMap() {
        Restore();
    }

    void SetBlock(CGameCtnBlock@ block) {
        @this.block = block;
        block.MwAddRef();
    }

    void Restore() override {
        if (block is null) return;
        if (Editor::IsBlockFree(block)) {
            Editor::SetBlockLocation(block, oldPos);
        }
        Editor::SetBlockCoord(block, oldCoord);
        block.MwRelease();
        @block = null;
    }
}

class MovedItemInMap : ModifiedMapObj {
    CGameCtnAnchoredObject@ item;
    nat3 oldCoord;
    vec3 oldPos;

    MovedItemInMap(CGameCtnAnchoredObject@ item, nat3 newCoord, vec3 newPos) {
        SetItem(item);
        this.oldCoord = item.BlockUnitCoord;
        this.oldPos = item.AbsolutePositionInMap;
        item.BlockUnitCoord = nat3(-1);
        item.AbsolutePositionInMap = item.AbsolutePositionInMap + newPos;
    }

    ~MovedItemInMap() {
        Restore();
    }

    void SetItem(CGameCtnAnchoredObject@ item) {
        @this.item = item;
        item.MwAddRef();
    }

    void Restore() override {
        if (item is null) return;
        item.BlockUnitCoord = oldCoord;
        item.AbsolutePositionInMap = oldPos;
        item.MwRelease();
        @item = null;
    }
}


/*
Trackmania.exe.text+F91804 - E8 D75EE4FF           - call Trackmania.exe.text+DD76E0 { calls CGameCtnEditor::SetCopyPasteMbInfo

 }
Trackmania.exe.text+F91809 - 49 8B 85 28060000     - mov rax,[r13+00000628] { get cursor
 }
Trackmania.exe.text+F91810 - 33 D2                 - xor edx,edx
Trackmania.exe.text+F91812 - 49 8B CD              - mov rcx,r13
Trackmania.exe.text+F91815 - 89 B0 48010000        - mov [rax+00000148],esi
Trackmania.exe.text+F9181B - 89 B0 50010000        - mov [rax+00000150],esi

E8 D7 5E E4 FF 49 8B 85 28 06 00 00 33 D2 49 8B CD 89 B0 48 01 00 00 89 B0 50 01 00 00
E8 ?? ?? ?? ?? 49 8B 85 ?? 06 00 00 33 D2 49 8B CD 89 B0 48 01 00 00 89 B0 50 01 00 00
unique in TM: E8 ?? ?? ?? ?? 49 8B 85 ?? 06 00 00
unique gloabl: E8 ?? ?? ?? ?? 49 8B 85 ?? 06 00 00 33





hmm other ideas:
- replace buffers on mb info after instantiation (we can just shorten the buf later)
- replace the macroblocks on Editor:: once SetCopyPasteMbInfo is called -- worked


patch to allow creation of empty macroblocks (disables no valid blocks msg)

before:
8B 8D A8 00 00 00 - mov ecx,[rbp+000000A8]
pattern:
89 4d c0 45 85 ed 0f 85 0a 01 00 00
mov      test     jnz
patch to
89 4d c0 45 85 ed 90 E9 0a 01 00 00
mov      test    nop jmp
*/
;
