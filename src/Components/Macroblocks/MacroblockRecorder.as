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

	void DrawSettings() {
        MacroblockRecorder::S_RecordMB_ForceAir = UI::Checkbox("Set all Blocks to Air", MacroblockRecorder::S_RecordMB_ForceAir);
        MacroblockRecorder::S_RecordMB_ForceFree = UI::Checkbox("Convert all Blocks to Free", MacroblockRecorder::S_RecordMB_ForceFree);
        MacroblockRecorder::S_RecordMB_SaveAfterMbConstruction = UI::Checkbox("Save Macroblock after Construction", MacroblockRecorder::S_RecordMB_SaveAfterMbConstruction);
        MacroblockRecorder::S_RecordMB_Save_AutoNameAndSave = UI::Checkbox("Automate Save (to _epp_tmp.Macroblock.Gbx)", MacroblockRecorder::S_RecordMB_Save_AutoNameAndSave);
	}

	bool get_IsActive() {
		return recordingMB !is null;
	}

	bool get_HasExisting() {
		return recordedMB !is null || recordingMB !is null;
	}

	bool get_ActiveRecordingIsEmpty() {
		if (recordingMB is null) return true;
		return recordingMB.Blocks.Length == 0 && recordingMB.Items.Length == 0;
	}

	bool get_IsActiveAndNonEmpty() {
		return IsActive && (recordingMB.Blocks.Length > 0 || recordingMB.Items.Length > 0);
	}

	uint get_ActiveRec_NbBlocks() {
		if (recordingMB is null) return 0;
		return recordingMB.Blocks.Length;
	}

	uint get_ActiveRec_NbItems() {
		if (recordingMB is null) return 0;
		return recordingMB.Items.Length;
	}

	uint get_CompletedRec_NbBlocks() {
		if (recordedMB is null) return 0;
		return recordedMB.Blocks.Length;
	}

	uint get_CompletedRec_NbItems() {
		if (recordedMB is null) return 0;
		return recordedMB.Items.Length;
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

	void ResumeRecording() {
		if (recordingMB !is null) return;
		if (recordedMB is null) {
			NotifyWarning("No macroblock recording to resume.");
			return;
		}
		@recordingMB = recordedMB;
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
		_Log::Trace("MacroblockRecorder: Could not find block to remove: " + block.BlockInfo.Name + " at " + block.Coord.ToString());
	}

	void _RemoveMbItem(CGameCtnAnchoredObject@ item) {
		// assumes recordingMB is not null
		for (uint i = 0; i < recordingMB.Items.Length; i++) {
			if (recordingMB.Items[i].MatchesItem(item)) {
				recordingMB.Items.RemoveAt(i);
				return;
			}
		}
		_Log::Trace("MacroblockRecorder: Could not find item to remove: " + item.ItemModel.Name + " at " + item.AbsolutePositionInMap.ToString());
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
		TransferRecordedMbToEditorCopyPasteMb(cast<Editor::MacroblockSpecPriv>(recordedMB.Duplicate()));
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

		// update placement mode if not in copy paste already (though it will auto change it for us anyway)
		if (!Editor::IsInCopyPasteMode(editor, false)) {
			Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CopyPaste);
			yield();
		}
		// auto camState = Editor::CamState(editor.OrbitalCameraControl);

		// MAIN COPY - works for both copy/paste and saving MB
		_Log::Trace("MbRec: Move items in map if not in macroblock");
		// set selection coords then modify all blocks and items to
		// move coords/positions out of the way. After, move them back.
		auto selectedCoordBB = ModifyMapObjects_SetCoordsOutside_Filtered(editor.Challenge, mb);
		// if (mb.blocks.Length > 0) _Patcher_AllowEmptyMacroblockCreation.Apply();

		dev_trace("Set selection coords to: " + selectedCoordBB.start.ToString() + " / " + selectedCoordBB.end.ToString());
		pmt.CopyPaste_ResetSelection();
		pmt.CopyPaste_AddOrSubSelection(selectedCoordBB.start, selectedCoordBB.end);
		pmt.CopyPaste_Copy();
		// editor.ButtonSelectionBoxCopyOnClick();
		// CControl::Editor_FrameCopyPaste_Copy.OnAction();
		SetManipulatingMB(editor.CopyPasteMacroBlockInfo);

		if (S_RecordMB_SaveAfterMbConstruction) {
			try {
				yield();

				dev_trace("run click save macroblock (in copy paste toolbar)");
				// activates hook and sets up 3d scene for the macroblock
				CControl::Editor_FrameCopyPaste_SaveMacroblock.OnAction();
				yield();
				SetManipulatingMB(editor.CopyPasteMacroBlockInfo);

				dev_trace('set camera and rotate');
				// bug: thumbnail won't show :/
				// Editor::SetSnapCameraLocation(editor, camState.Loc);
				// Editor::SetSnapCameraPosition(editor, camState.CamPos);
				auto rotateCamBtn = CControl::Editor_FrameEditSnap_RotateCameraBtn;
				while (!rotateCamBtn.IsVisible || !rotateCamBtn.Parent.IsVisible) {
					dev_trace("yield: rotateBtnVisibility");
					yield();
				}
				// rotateCamBtn.OnAction();

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
				} else {
					// if we aren't autosaving, wait for the thumbnail view to go away before we set the copied macroblock (because we exit to copy mode)
					for (uint i = 0; i < 3; i++) {
						while (CControl::Editor_FrameEditSnap_SaveBtn.Parent.IsVisible) yield();
						while (app.ActiveMenus.Length > 0) yield();
						yield(3);
						while (app.ActiveMenus.Length > 0) yield();
					}
				}
				Editor::SetCopyPasteMacroBlockInfo(editor, _manipulating);
				Editor::SetSelectedMacroBlockInfo(editor, _manipulating);
			} catch {
				NotifyError("MacroblockRecorder: Failed to automate saving macroblock. " + getExceptionInfo());
			}
			// todo: unapply patch
			// _UnapplySaveMbPatch();
		}

		// reset blocks/items in map
		ModifyMapObjects_SetCoords_Reset();
		_Patcher_AllowEmptyMacroblockCreation.Unapply();

		CursorControl::ReleaseExclusiveControl(mbRecorderInputsControlName);

		// pmt.Cursor.Raise();
		// pmt.Cursor.Lower();

		if (_manipulating.GeneratedBlockInfo !is null) {
			// do this after we change placement mode too.
			if (_manipulating.GeneratedBlockInfo.VariantGround !is null) {
				_manipulating.GeneratedBlockInfo.VariantGround.AutoTerrainPlaceType = CGameCtnBlockInfoVariantGround::EnumAutoTerrainPlaceType::DoNotPlace;
			}
		} else {
			Dev_NotifyWarning("MacroblockRecorder: Generated block info is null");
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

	// const string Patch_NopSetCopyPasteMbInfo = "E8 ?? ?? ?? ?? 49 8B 85 ?? 06 00 00";
	// // MemPatcher@ _Patcher_NopSetCopyPasteMbInfo = MemPatcher(Patch_NopSetCopyPasteMbInfo, {0}, {"90 90 90 90 90"});
	// FunctionHookHelper@ _Hook_CallSetCopyPasteMbInfo = FunctionHookHelper(Patch_NopSetCopyPasteMbInfo, 0, 0, "MacroblockRecorder::_On_SetCopyPasteMbInfo", Dev::PushRegisters::Basic, true);

	// hooks CGameCtnMacroBlockInfo::GenerateBlockInfo(mbInfo)
	// const string Pattern_OnUpdateCopyPasteMbInfo = "40 53 48 83 EC 20 48 8B D9 E8 ?? ?? ?? ?? 33 D2 89 83 ?? 01 00 00";
	// HookHelper@ _OnUpdateCopyPasteMbInfo_Hook = HookHelper(Pattern_OnUpdateCopyPasteMbInfo, 0x0, 0x1, "MacroblockRecorder::_OnUpdateCopyPasteMbInfo", Dev::PushRegisters::Basic, false);

	const string Patch_AllowEmptyMacroblockCreation = "89 4d c0 45 85 ed 0f 85 ?? 01 00 00";
	MemPatcher@ _Patcher_AllowEmptyMacroblockCreation = MemPatcher(Patch_AllowEmptyMacroblockCreation, {6}, {"90 e9"});

	void _On_SetCopyPasteMbInfo() {
		auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
		Editor::SetCopyPasteMacroBlockInfo(editor, _manipulating);
		Editor::SetSelectedMacroBlockInfo(editor, _manipulating);
	}

	// not needed
	// void _OnUpdateCopyPasteMbInfo(CGameCtnMacroBlockInfo@ rcx) {
	// 	if (rcx is null) {
	// 		dev_warn("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; rcx is null");
	// 		return;
	// 	}
	// 	dev_trace("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; rcx: " + rcx.Name + " refcount: " + Reflection::GetRefCount(rcx));
	// 	if (_manipulating is null) {
	// 		dev_warn("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; _manipulating is null");
	// 		return;
	// 	}
	// 	/* for inner hook */
	// 	recordedMB._WriteDirectlyToMacroblock(rcx);
	// 	// dev_trace("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; _MacroblockInfo_SwapBuffers");
	// 	// _MacroblockInfo_SwapBuffers(rcx, _manipulating);
	// 	// for good luck
	// 	// rcx.MwAddRef();
	// 	// _manipulating.MwAddRef();
	// 	// SetManipulatingMB(rcx);
	// 	dev_trace("MacroblockRecorder::_OnUpdateCopyPasteMbInfo; _MacroblockInfo_SwapBuffers Done");
	// 	// unhook self, only called once
	// 	// _UnapplySaveMbPatch();
	// }

	// void _MacroblockInfo_SwapBuffers(CGameCtnMacroBlockInfo@ a, CGameCtnMacroBlockInfo@ b) {
	//     Dev_SwapUint64At(a, b, O_MACROBLOCK_BLOCKSBUF);
	//     Dev_SwapUint64At(a, b, O_MACROBLOCK_BLOCKSBUF+8);
	//     Dev_SwapUint64At(a, b, O_MACROBLOCK_ITEMSBUF);
	//     Dev_SwapUint64At(a, b, O_MACROBLOCK_ITEMSBUF+8);
	//     Dev_SwapUint64At(a, b, O_MACROBLOCK_SKINSBUF);
	//     Dev_SwapUint64At(a, b, O_MACROBLOCK_SKINSBUF+8);
	// }

	// void _ApplySaveMbPatch() {
	// 	// if (_OnUpdateCopyPasteMbInfo_Hook.IsApplied()) return;
	// 	dev_trace("MacroblockRecorder::_ApplySaveMbPatch();");
	// 	// _Patcher_NopSetCopyPasteMbInfo.Apply();
	// 	// _OnUpdateCopyPasteMbInfo_Hook.Apply();
	// 	_Hook_CallSetCopyPasteMbInfo.Apply();
	// 	_Patcher_AllowEmptyMacroblockCreation.Apply();
	// }
	// void _UnapplySaveMbPatch() {
	// 	// if (!_OnUpdateCopyPasteMbInfo_Hook.IsApplied()) return;
	// 	dev_trace("MacroblockRecorder::_UnapplySaveMbPatch();");
	// 	// _Patcher_NopSetCopyPasteMbInfo.Unapply();
	// 	// _OnUpdateCopyPasteMbInfo_Hook.Unapply();
	// 	_Hook_CallSetCopyPasteMbInfo.Unapply();
	// 	_Patcher_AllowEmptyMacroblockCreation.Unapply();
	// }

	// MARK: Modify map objects for thumbnail

	Helper_ModifyMapObjCoords@ thumbnailMapCoordsHelper;

	// Modifies the map objects' block coord to be outside of the selection (start, end); ignoring objects in the mb spec.
	CoordBoundingBox ModifyMapObjects_SetCoordsOutside_Filtered(CGameCtnChallenge@ map, Editor::MacroblockSpecPriv@ filterMb) {
		@thumbnailMapCoordsHelper = Helper_ModifyMapObjCoords(map, filterMb);
		return thumbnailMapCoordsHelper.Run();
	}

	void ModifyMapObjects_SetCoords_Reset() {
		if (thumbnailMapCoordsHelper !is null) {
			thumbnailMapCoordsHelper.Reset();
			@thumbnailMapCoordsHelper = null;
		}
	}
}

class CoordBoundingBox {
	int3 start;
	int3 end;

	CoordBoundingBox() {}

	CoordBoundingBox(int3 start, int3 end) {
		this.start = start;
		this.end = end;
	}

	void Set(int3 start, int3 end) {
		this.start = start;
		this.end = end;
	}

	void Reset() {
		start = int3(-1);
		end = int3(-1);
	}

	void Include(int3 coord) {
		if (start == int3(-1) && end == int3(-1)) {
			start = coord;
			end = coord;
		} else {
			start = MathX::Min(start, coord);
			end = MathX::Max(end, coord);
		}
	}
	void Include(const nat3 &in coord) {
		Include(Nat3ToInt3(coord));
	}
}

class Helper_ModifyMapObjCoords {
	CGameCtnChallenge@ map;
	// do not touch blocks/items referenced by the mb
	Editor::MacroblockSpecPriv@ mb;

	nat3 targetCoord;
	vec3 targetPos;

	Helper_ModifyMapObjCoords(CGameCtnChallenge@ map, Editor::MacroblockSpecPriv@ mb) {
		@this.map = map;
		map.MwAddRef();
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
	CoordBoundingBox coordBB;

	CoordBoundingBox Run() {
		coordBB.Reset();
		SetUpFiltered();
		MoveBlocks_Filtered();
		MoveItems_Filtered();
		return coordBB;
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
				coordBB.Include(Editor::GetBlockCoord(block));
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
			auto found = filteredItems.Find(itemPtr) != -1;
			if (found) {
				dev_trace("Skipping filtered item; ix: " + i + " / " + nbItemsInMap + " @ " + item.AbsolutePositionInMap.ToString());
				coordBB.Include(item.BlockUnitCoord);
			}
			MoveItem(item, found);
		}
	}

	void MoveBlock(CGameCtnBlock@ block) {
		if (block is null) return;
		modified.InsertLast(MovedBlockInMap(block, targetPos)); // start.y - 1,
	}

	void MoveItem(CGameCtnAnchoredObject@ item, bool keepInPlace) {
		if (item is null) return;
		modified.InsertLast(MovedItemInMap(item, keepInPlace));
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
	uint orig0x90;

	MovedBlockInMap(CGameCtnBlock@ block, vec3 newPos) {
		SetBlock(block);
		this.oldCoord = block.Coord;
		this.oldPos = Editor::GetBlockLocation(block, true);
		if (Editor::IsBlockFree(block)) {
			Editor::SetBlockLocation(block, oldPos + vec3(0.,111.0,0.) * newPos);
		} else {
			// block.CoordX = 0;
			// block.CoordZ = 0;
			// block.CoordY = yCoord;
			// setting y to -1 creates infinite loop (well, probs just like a 4 billion loop)
			// block.CoordY = -1;
			// block.CoordY = 0;
		}
		// set block 0x90 |= 0x1000
		// if ((ctnBlock != (CGameCtnBlock *)0x0) && ((*(uint *)&ctnBlock->field_0x90 & 0x1000) == 0))
		orig0x90 = Dev::GetOffsetUint32(block, Editor::O_CGameCtnBlock_MacroblockFlags);
		Dev::SetOffset(block, Editor::O_CGameCtnBlock_MacroblockFlags, orig0x90 | 0x1000);
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
		// Editor::SetBlockCoord(block, oldCoord);
		Dev::SetOffset(block, 0x90, orig0x90);
		block.MwRelease();
		@block = null;
	}
}

class MovedItemInMap : ModifiedMapObj {
	CGameCtnAnchoredObject@ item;
	nat3 oldCoord;
	vec3 oldPos;
	bool wasFlying;

	MovedItemInMap(CGameCtnAnchoredObject@ item, bool keepInPlace) {
		SetItem(item);
		this.oldCoord = item.BlockUnitCoord;
		this.oldPos = item.AbsolutePositionInMap;
		wasFlying = item.IsFlying;
		if (!keepInPlace) {
			item.BlockUnitCoord = nat3(uint(-1));
		}
		item.IsFlying = true;
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
		item.IsFlying = wasFlying;
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
