[Setting hidden]
bool S_ShowMbPlacementToolbar = true;

const string RightClickable = "\n\\$888\\$iRight Clickable";

class CurrentMacroblock_PlacementToolbar : ToolbarTab {
    ReferencedNod@ currMbModel;

    CurrentMacroblock_PlacementToolbar(TabGroup@ parent) {
        super(parent, "Macroblock Placement Toolbar", Icons::Wrench, "mbptb");
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.ResetCached), this.tabName);
        RegisterSelectedMacroblockChangedCallback(ProcessNewSelectedMacroblock(this.OnMbChanged), this.tabName);
        RegisterCopyPasteMacroblockChangedCallback(ProcessNewSelectedMacroblock(this.OnMbChanged), this.tabName);
        RegisterPlacementModeChangedCallback(ProcessNewPlacementMode(this.OnPModeChanged), this.tabName);
    }

    ~CurrentMacroblock_PlacementToolbar() {}

    void OnEditor() {
        this.windowOpen = S_ShowMbPlacementToolbar;
    }

    void ResetCached() {
        @this.currMbModel = null;
    }

    void OnMbChanged(CGameCtnMacroBlockInfo@ mbi) {
        if (mbi is null) return;
        @currMbModel = ReferencedNod(mbi);
        if (IsMbShowGhostFreeApplied && !mbi.Description.EndsWith(".") && GetFidFromNod(mbi) !is null) {
            mbi.Description = wstring(string(mbi.Description) + ".");
            mbi.Initialized = false;
        }
    }

    CGameCtnMacroBlockInfo@ get_MacroblockInfo() {
        if (currMbModel is null) return null;
        return currMbModel.AsMacroBlockInfo();
        // return Editor::GetCursorMacroBlockInfo(cast<CGameCtnEditorFree>(GetApp().Editor));
    }

    void OnPModeChanged(CGameEditorPluginMap::EPlaceMode newMode) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        switch (newMode) {
            case CGameEditorPluginMap::EPlaceMode::CopyPaste: {
                OnMbChanged(editor.CopyPasteMacroBlockInfo);
                break;
            }
            case CGameEditorPluginMap::EPlaceMode::Macroblock:
            case CGameEditorPluginMap::EPlaceMode::FreeMacroblock: {
                OnMbChanged(editor.CurrentMacroBlockInfo);
                break;
            }
            default: {
                // also nothing
            }
        }
    }

    bool ShouldShowWindow(CGameCtnEditorFree@ editor) override {
        return S_ShowMbPlacementToolbar && (
            Editor::IsInMacroblockPlacementMode(editor, false)
            || Editor::IsInCopyPasteMode(editor, false)
        );
    }

    void DrawInner_MainToolbar() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);

        DrawPlaceModeButtons(editor);
        DrawConvertToGroundAirButtons();

        UI::Separator();

        DrawLargeMacroblocksButton();
        DrawReinitMacroblockButton();

        UI::Separator();

        DrawMbRecordingButtons();

        UI::Separator();

        DrawBigSnapButton();
        DrawInfPrecisionButtons();
        DrawLocalRotateButtons();

        // end after all buttons
        DrawPopups();
    }

    bool isAir = false;
    bool isCopyPaste = false;

    void DrawPlaceModeButtons(CGameCtnEditorFree@ editor) {
		auto mode = Editor::GetPlacementMode(editor);
		isNorm = mode == CGameEditorPluginMap::EPlaceMode::Macroblock;
		isFree = mode == CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
		isCopyPaste = mode == CGameEditorPluginMap::EPlaceMode::CopyPaste;
		isAir = IsMbPlaceInAirActive;

		bool cNorm = this.BtnToolbarHalfV(Icons::Cube, "Normal Macroblock Mode", isNorm ? BtnStatus::FeatureActive : BtnStatus::Default);
		bool cFree = this.BtnToolbarHalfV(Icons::Refresh, "Free Macroblock Mode", isFree ? BtnStatus::FeatureActive : BtnStatus::Default);
		bool cCopy = this.BtnToolbarHalfV(Icons::FilesO + Icons::Clipboard, "Copy/Paste Mode", isCopyPaste ? BtnStatus::FeatureActive : BtnStatus::Default);
        UI::Separator();
		bool cAir = this.BtnToolbarHalfV(BtnNameDynamic(isAir ? Icons::Cloud : Icons::Download, "bpt-air"), "Place MB as Air Mode [E++]", BtnStatus_NotFreeActive(isAir));

        if (cNorm) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Macroblock);
        if (cFree) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeMacroblock);
        if (cCopy) Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::CopyPaste);
        if (cAir) IsMbPlaceInAirActive = !isAir;
        if (cNorm || cFree) {
            SelectCurrentMacroblock(editor);
        }
    }

    void DrawConvertToGroundAirButtons() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);

        auto mbi = MacroblockInfo;
        bool hasGroundV, hasAirV;
        if (mbi !is null && mbi.GeneratedBlockInfo !is null) {
            hasGroundV = mbi.GeneratedBlockInfo.VariantGround !is null;
            hasAirV = mbi.GeneratedBlockInfo.VariantAir !is null;
        }

        bool cAir = this.BtnToolbarQ(Icons::Cloud + "##toair", "Convert to Air Mode", hasAirV ? BtnStatus::Disabled : BtnStatus::Default);
        bool cGround = this.BtnToolbarQ(Icons::Download + "##toground", "Convert to Ground Mode", hasGroundV ? BtnStatus::Disabled : BtnStatus::Default, true);

        if (cAir) editor.TurnIntoAirMb_Unsafe();
        else if (cGround) editor.TurnIntoGroundMb_Unsafe();

        // if (cAir || cGround) {
        //     OnMbChanged(Editor::GetCursorMacroBlockInfo(editor));
        // }
    }

    void DrawMbRecordingButtons() {
        bool cStartRec, cResumeRec, cStopRec, cCancelRec;
        string recColor = "\\$f88";
        string resumeColor = "\\$8f8";
        string statusBlocks, statusItems;
        bool showOptions = false;

        statusBlocks = tostring(MacroblockRecorder::ActiveRec_NbBlocks);
        statusItems = tostring(MacroblockRecorder::ActiveRec_NbItems);
        if (MacroblockRecorder::IsActive) {
            cStopRec = this.BtnToolbarHalfV(resumeColor + Icons::Stop + Icons::FloppyO + "##stoprec", "Stop Macroblock Recording" + RightClickable, BtnStatus_MbRecording_Stop());
            showOptions = UI::IsItemClicked(UI::MouseButton::Right);
            cCancelRec = this.BtnToolbarHalfV(recColor + Icons::Undo + Icons::Times + "##cancelrec", "Cancel Macroblock Recording" + RightClickable, BtnStatus::Default);
        } else if (MacroblockRecorder::HasExisting) {
            cResumeRec = this.BtnToolbarHalfV(resumeColor + Icons::Play + Icons::VideoCamera + "##resumerec", "Resume Macroblock Recording" + RightClickable, BtnStatus::Default);
            showOptions = UI::IsItemClicked(UI::MouseButton::Right);
            cStartRec = this.BtnToolbarHalfV(recColor + Icons::Circle + Icons::VideoCamera + "##startrec", "New Macroblock Recording" + RightClickable, BtnStatus::Default);
        } else {
            cStartRec = this.BtnToolbar(Icons::Circle + Icons::VideoCamera + "##startrec", "Start Macroblock Recording" + RightClickable, BtnStatus::Default);
            statusBlocks = ("\\$888--");
            statusItems = ("\\$888--");
        }
        // handle last button right click
        showOptions = showOptions || UI::IsItemClicked(UI::MouseButton::Right);

        string statusText = statusBlocks + "/" + statusItems;
        UI::PushFont(g_MonoFont);
        UI::BeginChild("##mbcount", vec2(-1, 18.0 * g_scale));
        UI::Text(statusText); showOptions = showOptions || UI::IsItemClicked(UI::MouseButton::Right);
        UI::SetItemTooltip(statusText);
        UI::EndChild();
        UI::PopFont();

        if (cStartRec) MacroblockRecorder::StartRecording();
        else if (cResumeRec) MacroblockRecorder::ResumeRecording();
        else if (cStopRec) MacroblockRecorder::StopRecording(false);
        else if (cCancelRec) MacroblockRecorder::StopRecording(true);

        if (showOptions) UI::OpenPopup("Macroblock Recording Options");
    }

    BtnStatus BtnStatus_MbRecording_Stop() {
        return MacroblockRecorder::IsActiveAndNonEmpty ? BtnStatus::Default : BtnStatus::Disabled;
    }

    void DrawLargeMacroblocksButton() {
        string icon = LargeMacroblocks::IsApplied ? Icons::Eye : Icons::EyeSlash;
        bool cToggle = this.BtnToolbar("Big\n" + icon, "Large Macroblocks Visible?\nIncreases default from limits from 350 blocks / 600 items to ~131,000 each.", BtnStatus_Active(LargeMacroblocks::IsApplied));
        if (cToggle) LargeMacroblocks::IsApplied = !LargeMacroblocks::IsApplied;
    }

    void DrawReinitMacroblockButton() {
        bool cReinit = this.BtnToolbarHalfV(Icons::Eye + Icons::Refresh + "##reinit", "Reinitialize Macroblock", BtnStatus::Default);
        if (cReinit) {
            auto mbi = MacroblockInfo;
            if (mbi !is null) {
                mbi.Initialized = false;
            }
        }
    }


    bool get_IsMbPlaceInAirActive() {
        return g_PlaceMacroblockAirModeActive;
    }
    void set_IsMbPlaceInAirActive(bool value) {
        g_PlaceMacroblockAirModeActive = value;
    }

    void SelectCurrentMacroblock(CGameCtnEditorFree@ editor) {
        auto mbi = MacroblockInfo;
        if (mbi is null) return;
        Editor::SetSelectedMacroBlockInfo(editor, mbi);
    }

    BtnStatus BtnStatus_NotFreeActive(bool active) {
        if (isFree) return BtnStatus::Disabled;
        return active ? BtnStatus::FeatureActive : BtnStatus::Default;
    }


    void DrawPopups() {
        DrawMacroblockRecOptsPopup();
    }
}
