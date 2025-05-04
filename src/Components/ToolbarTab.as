
class ToolbarTab : Tab {
	ToolbarTab(TabGroup@ parent, const string &in name, const string &in icon, const string &in idNonce) {
		super(parent, name, icon);
		// don't forget window position; needs to be singleton instance
		this.idNonce = idNonce;
	}

	int get_WindowFlags() override {
		return UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar;
	}

	bool get_windowOpen() override property {
		auto app = GetApp();
		auto editor = cast<CGameCtnEditorFree>(app.Editor);
		return editor !is null
			&& ShouldShowWindow(editor)
			&& app.CurrentPlayground is null
			&& Tab::get_windowOpen();
	}

	bool ShouldShowWindow(CGameCtnEditorFree@ editor) {
		// override me
		return true;
	}

	void _BeforeBeginWindow() override {
		UI::SetNextWindowPos(0, 400, UI::Cond::FirstUseEver);
		UI::SetNextWindowSize(d_ToolbarBtnSize.x, d_ToolbarBtnSize.y, UI::Cond::Appearing);
	}

	void DrawInner() override {
		UI::BeginDisabled(Gizmo::IsActive);
		DrawInner_MainToolbar();
		UI::EndDisabled();
	}

	void DrawInner_MainToolbar() {
		// override me
	}

	bool BtnToolbar(const string &in label, const string &in desc, BtnStatus status, vec2 size = vec2()) {
		if (size.LengthSquared() == 0) size = d_ToolbarBtnSize * g_scale;
		auto fp = UI::GetStyleVarVec2(UI::StyleVar::FramePadding);

		UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(1, fp.y));
		bool click = false;
		bool disabled = status == BtnStatus::Disabled;
		float hue = BtnStatusHue(status);
		float sat = disabled ? 0.0 : .6;
		float lightness = disabled ? 0.3 : .6;
		click = UI::ButtonColored(label, hue, sat, lightness, size) && !disabled;
		UI::PopStyleVar();

		if (desc.Length > 0) AddSimpleTooltip(desc, true);
		return click;
	}

	bool BtnToolbarHalfH(const string &in label, const string &in desc, BtnStatus status) {
		float framePad = UI::GetStyleVarVec2(UI::StyleVar::FramePadding).x;
		return BtnToolbar(label, desc, status, vec2(d_ToolbarBtnSize.x * .5, d_ToolbarBtnSize.y) * g_scale - vec2(framePad, 0));
	}

	bool BtnToolbarHalfV(const string &in label, const string &in desc, BtnStatus status) {
		return BtnToolbar(label, desc, status, vec2(d_ToolbarBtnSize.x, d_ToolbarBtnSize.y * .5) * g_scale);
	}

	bool BtnToolbarQ(const string &in label, const string &in desc, BtnStatus status, bool isLast = false) {
		float framePad = UI::GetStyleVarVec2(UI::StyleVar::FramePadding).x;
		auto itemSpacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
		UI::PushStyleVar(UI::StyleVar::ItemSpacing, vec2(0, itemSpacing.y));
		auto r = BtnToolbar(label, desc, status, d_ToolbarBtnSize * .5 * g_scale); //  - vec2(framePad, 0)
		if (!isLast) UI::SameLine();
		UI::PopStyleVar();
		return r;

	}

	string BtnNameDynamic(const string &in icon, const string &in id) {
		return icon + "###" + id;
	}

	bool isFree;

	void DrawInfPrecisionButtons() {
		bool active = S_EnableInfinitePrecisionFreeBlocks;
		bool toggleInfPrec = this.BtnToolbarHalfV("∞" + Icons::MousePointer, "Place Anywhere / Infinite Precision", isFree ? (active ? BtnStatus::FeatureActive : BtnStatus::Default) : BtnStatus::Disabled);
		if (toggleInfPrec) {
			S_EnableInfinitePrecisionFreeBlocks = !active;
			if (!S_EnableInfinitePrecisionFreeBlocks) {
				S_EnableFreeGrid = false;
			}
		}
		string gridLabel = !S_EnableFreeGrid ? "Grid" : S_FreeGridLocal ? "Local" : "Global";
		bool toggleFreeGrid = this.BtnToolbarHalfV(gridLabel + "###grid-cycle", "Free Grid.\n Local = Rotate grid to match cursor rotations.\n Global = axis aligned." + RMBIcon, isFree ? (S_EnableFreeGrid ? BtnStatus::FeatureActive : BtnStatus::Default) : BtnStatus::Disabled);
		bool freeGridRMB = UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
		if (freeGridRMB) {
			UI::OpenPopup("FreeGridOpts");
		}

		if (toggleFreeGrid) {
			if (!S_EnableInfinitePrecisionFreeBlocks) S_EnableInfinitePrecisionFreeBlocks = true;
			if (!S_EnableFreeGrid) {
				S_EnableFreeGrid = true;
				S_FreeGridLocal = true;
			}
			else if (S_FreeGridLocal) S_FreeGridLocal = !S_FreeGridLocal;
			else S_EnableFreeGrid = false;
		}

		DrawFreeGridPopup();
	}

	void DrawFreeGridPopup() {
		bool closePopup = false;
		UI::PushFont(g_NormFont);
		if (UI::BeginPopup("FreeGridOpts")) {
			UI::SetNextItemWidth(100.0);
			auto newSize = UI::InputFloat("Grid Size", S_FreeGridSize, 1.0);
			bool sizeChanged = newSize != S_FreeGridSize;
			bool sizeIncr = newSize > S_FreeGridSize;
			if (sizeChanged) {
				if (sizeIncr) {
					S_FreeGridSize *= 2.;
				} else {
					S_FreeGridSize /= 2.;
				}
				S_FreeGridSize = Math::Clamp(S_FreeGridSize, 0.03125, 64.0);
			}
			UX::CloseCurrentPopupIfMouseFarAway(closePopup);
			UI::EndPopup();
		}
		UI::PopFont();
	}

	void DrawLocalRotateButtons() {
		auto btnStatus = FreeButtonStatusActive(S_CursorSmartRotate);
		bool toggleSmartRot = this.BtnToolbarHalfV("S 90" + DEGREES_CHAR, "Cursor Smart Rotate.\n Rotations are applied locally to current axes (like gizmo).\n Note: these need to fit into the existing cursor rotations, so aren't perfect.", btnStatus);
		if (toggleSmartRot) {
			S_CursorSmartRotate = !S_CursorSmartRotate;
		}
	}

	BtnStatus FreeButtonStatusActive(bool active) {
		return isFree ? (active ? BtnStatus::FeatureActive : BtnStatus::Default) : BtnStatus::Disabled;
	}

	void DrawBigSnapButton() {
		auto btnStatus = isFree ? (_bigSnapActive ? BtnStatus::FeatureActive : BtnStatus::Default) : BtnStatus::Disabled;
		bool bigSnap = this.BtnToolbar(Icons::Expand + Icons::Magnet, "Big Snap for free blocks", btnStatus);
		if (bigSnap) ToggleBigSnap();
	}

	bool _bigSnapActive = false;
	void ResetBigSnap() {
		CustomCursor::ResetSnapRadius();
		_bigSnapActive = false;
	}
	void ToggleBigSnap() {
		_bigSnapActive = !_bigSnapActive;
		if (_bigSnapActive) {
			float sr;
			while ((sr = CustomCursor::GetCurrentSnapRadius()) < 32.0) {
				CustomCursor::StepFreeBlockSnapRadius(true, sr < 31.5);
			}
		} else {
			ResetBigSnap();
		}
	}
}

const string RMBIcon = "\\$i\\$999 Right-clickable";

enum BtnStatus {
	Default,
	FeatureActive,
	FeatureBlocked,
	Disabled,
}

float BtnStatusHue(BtnStatus status) {
	switch (status) {
		case BtnStatus::Disabled:
		case BtnStatus::Default: {
			auto d = UI::GetStyleColor(UI::Col::Button);
			return UI::ToHSV(d.x, d.y, d.z).x;
		}
		case BtnStatus::FeatureActive: return 0.3;
		case BtnStatus::FeatureBlocked: return 0.1;
	}
	return 0.5;
}

const vec2 d_ToolbarBtnSize = vec2(52);
