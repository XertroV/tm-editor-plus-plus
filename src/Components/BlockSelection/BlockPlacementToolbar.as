[Setting hidden]
bool S_ShowBlockPlacementToolbar = true;

class CurrentBlock_PlacementToolbar : ToolbarTab {
	ReferencedNod@ currBlockModel;

	CurrentBlock_PlacementToolbar(TabGroup@ parent) {
		super(parent, "Block Placement Toolbar", Icons::Wrench, "bptb");
		RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
		RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
		RegisterSelectedBlockChangedCallback(ProcessNewSelectedBlock(this.OnBlockChanged), this.tabName);
		RegisterPlacementModeChangedCallback(ProcessNewPlacementMode(this.OnPModeChanged), this.tabName);
	}

	~CurrentBlock_PlacementToolbar() {}

	void OnEditor() {
		this.windowOpen = S_ShowBlockPlacementToolbar;
	}

	void ResetCached() {
		@this.currBlockModel = null;
	}

	void OnBlockChanged(CGameCtnBlockInfo@ bi) {
		@currBlockModel = ReferencedNod(bi);
	}

	CGameCtnBlockInfo@ get_BlockInfo() {
		if (currBlockModel is null) return null;
		return currBlockModel.AsBlockInfo();
	}

	void OnPModeChanged(CGameEditorPluginMap::EPlaceMode newMode) {
		switch (newMode) {
			case CGameEditorPluginMap::EPlaceMode::Block:
			case CGameEditorPluginMap::EPlaceMode::GhostBlock:
			case CGameEditorPluginMap::EPlaceMode::FreeBlock: {
				// do nothing
				break;
			}
			default: {
				ResetBigSnap();
			}
		}
	}

	void DrawMenuItem() override {
		if (UI::MenuItem(DisplayIconAndName, "", windowOpen)) {
			windowOpen = !windowOpen;
			S_ShowBlockPlacementToolbar = !S_ShowBlockPlacementToolbar;
		}
	}

	bool ShouldShowWindow(CGameCtnEditorFree@ editor) override {
		return S_ShowBlockPlacementToolbar && Editor::IsInBlockPlacementMode(editor, false);
	}

	void DrawInner_MainToolbar() override {
		auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
		auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);
		DrawCopyRotationsButton(editor);
		UI::Separator();
		DrawPlaceModeButtons(editor);
		UI::Separator();
		DrawForcedVariantButtons(editor);
		UI::Separator();
		DrawBigSnapButton();
		DrawInfPrecisionButtons();
		DrawLocalRotateButtons();

		// Last
		OptDrawMacroblockRecordMini();
	}

	void DrawCopyRotationsButton(CGameCtnEditorFree@ editor) {
		bool active = S_CopyPickedBlockRotation;
		bool toggleCopyRot = this.BtnToolbarHalfV(Icons::FilesO + Icons::Dribbble, "Copy rotations from picked blocks to the cursor", active ? BtnStatus::FeatureActive : BtnStatus::Default);
		if (toggleCopyRot) {
			S_CopyPickedBlockRotation = !active;
		}
	}

	bool isGhost;
	bool isAir;

	void DrawPlaceModeButtons(CGameCtnEditorFree@ editor) {
		auto mode = Editor::GetPlacementMode(editor);
		isNorm = mode == CGameEditorPluginMap::EPlaceMode::Block;
		isGhost = mode == CGameEditorPluginMap::EPlaceMode::GhostBlock;
		isFree = mode == CGameEditorPluginMap::EPlaceMode::FreeBlock;
		isAir = Editor::GetIsBlockAirModeActive(editor);

		bool cNorm = this.BtnToolbarHalfV(Icons::Cube, "Normal Block Mode", isNorm ? BtnStatus::FeatureActive : BtnStatus::Default);
		bool cGhost = this.BtnToolbarHalfV(Icons::SnapchatGhost, "Ghost Block Mode", isGhost ? BtnStatus::FeatureActive : BtnStatus::Default);
		bool cFree = this.BtnToolbarHalfV(Icons::Refresh, "Free Block Mode", isFree ? BtnStatus::FeatureActive : BtnStatus::Default);
		bool cAir = this.BtnToolbarHalfV(BtnNameDynamic(isAir ? Icons::Cloud : Icons::Download, "bpt-air"), "Air Block Mode", isAir ? BtnStatus::FeatureActive : BtnStatus::Default);


		if (cNorm) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Block);
		if (cGhost) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::GhostBlock);
		if (cFree) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
		if (cAir) Editor::SetIsBlockAirModeActive(editor, !isAir);
		if (cNorm || cGhost || cFree) {
			SelectCurrentBlock(editor);
		}
	}

	bool _forcedVarEnabled = false;
	int _forcedVarIndex = -1;
	bool _forcedGround = false;
	void DrawForcedVariantButtons(CGameCtnEditorFree@ editor) {
		_forcedVarEnabled = int(editor.GhostBlockForcedVariantIndex) >= 0;
		auto gVar = _forcedVarEnabled && _forcedGround ? _forcedVarIndex : -1;
		auto aVar = _forcedVarEnabled && !_forcedGround ? _forcedVarIndex : -1;
		// bool modeValid = Editor::IsInGhostOrFreeBlockPlacementMode(editor);
		auto gLabel = gVar > -1 ? "G:"+gVar+"###cy-gv" : "G###cy-gv";
		auto aLabel = aVar > -1 ? "A:"+aVar+"###cy-av" : "A###cy-av";

		bool toggleForcedV = this.BtnToolbarHalfV(Icons::ExclamationTriangle + Icons::ListUl, "Force variant for the current block. Ghost/Free only.", ForcedVarBtnStatus(editor));
		bool cycleGroundVar = this.BtnToolbarQ(gLabel, "Cycle Ground Variant", ForcedVarCycleBtnStatus(editor, true));
		bool cycleAirVar = this.BtnToolbarQ(aLabel, "Cycle Air Variant", ForcedVarCycleBtnStatus(editor, false), true);

		if (toggleForcedV) ToggleForcedVar(editor);
		if (cycleAirVar) SetForcedVar(editor, false, aVar + 1);
		if (cycleGroundVar) SetForcedVar(editor, true, gVar + 1);
	}

	void ToggleForcedVar(CGameCtnEditorFree@ editor) {
		_Log::Trace("Toggling forced variant");
		// if we're in normal mode, switch to ghost
		if (Editor::GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::Block) {
			_Log::Trace("Switching to ghost mode to set forced variant");
			Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::GhostBlock);
			_forcedVarEnabled = false;
			// need to reselect before setting forced variant
			SelectCurrentBlock(editor);
			ToggleForcedVarSoon();
			return;
		}

		_forcedVarEnabled = !_forcedVarEnabled;
		if (_forcedVarEnabled) {
			editor.GhostBlockForcedVariantIndex = 0;
			editor.GhostBlockForcedGroundElseAir = _forcedGround;
		} else {
			editor.GhostBlockForcedVariantIndex = uint(-1);
			// reselect current block to reset
			SelectCurrentBlock(editor);
		}
	}

	void SelectCurrentBlock(CGameCtnEditorFree@ editor) {
		if (BlockInfo is null) return;
		_Log::Trace("Setting selected block to " + BlockInfo.Name);
		auto inv = Editor::GetInventoryCache();
		auto article = inv.GetBlockByName(BlockInfo.IdName);
		if (article !is null) {
			Editor::SetSelectedInventoryNode(editor, article, false);
		}
	}

	void SetForcedVar(CGameCtnEditorFree@ editor, bool ground, int index) {
		if (BlockInfo is null) return;

		if (Editor::GetPlacementMode(editor) == CGameEditorPluginMap::EPlaceMode::Block) {
			_Log::Trace("Switching to ghost mode to set forced variant");
			// if we clicked in normal mode, switch to ghost
			Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::GhostBlock);
			SelectCurrentBlock(editor);
			SetForcedVarSoon(ground, index);
			return;
		}

		auto bi = BlockInfo;
		auto nbVars = Editor::GetNbBlockVariants(bi, ground);
		if (nbVars <= 0) {
			NotifyWarning("No " +(ground ? "ground" : "air")+ " variants for block " + bi.Name);
			return;
		}
		_forcedVarEnabled = true;
		_forcedVarIndex = index % nbVars;
		_forcedGround = ground;
		editor.GhostBlockForcedVariantIndex = _forcedVarIndex;
		editor.GhostBlockForcedGroundElseAir = ground;
	}

	// UI safe
	void ToggleForcedVarSoon() {
		startnew(CoroutineFunc(_ToggleForcedVarSoon));
	}
	protected void _ToggleForcedVarSoon() {
		yield();
		auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
		ToggleForcedVar(editor);

	}
	// UI safe
	void SetForcedVarSoon(bool ground, int index) {
		_sfvsGround = ground;
		_sfvsIndex = index;
		startnew(CoroutineFunc(_SetForcedVarSoon));
	}

	bool _sfvsGround;
	int _sfvsIndex;
	protected void _SetForcedVarSoon() {
		yield();
		auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
		SetForcedVar(editor, _sfvsGround, _sfvsIndex);
	}

	BtnStatus ForcedVarBtnStatus(CGameCtnEditorFree@ editor) {
		if (Editor::IsInGhostOrFreeBlockPlacementMode(editor, false))
			return _forcedVarEnabled ? BtnStatus::FeatureActive : BtnStatus::Default;
		return BtnStatus::DefaultHalf;
	}

	BtnStatus ForcedVarCycleBtnStatus(CGameCtnEditorFree@ editor, bool ground) {
		if (Editor::IsInGhostOrFreeBlockPlacementMode(editor, false))
			return _forcedVarEnabled && _forcedGround == ground ? BtnStatus::FeatureActive : BtnStatus::Default;
		return BtnStatus::DefaultHalf;
	}


	/*
	- Ghost/free - force variant
	- Rotate free block in cursor 90 degrees

	*/

	/*
	- macroblock: to air/ground, reinit model
	*/
}
