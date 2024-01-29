class CursorTab : Tab {
    CursorPropsTab@ cursorProps;
    CursorFavTab@ cursorFavs;

    CursorTab(TabGroup@ parent) {
        super(parent, "Cursor Coords", Icons::HandPointerO);
        canPopOut = false;
        // child tabs
        @cursorProps = CursorPropsTab(Children, this);
        @cursorFavs = CursorFavTab(Children, this);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;
#if SIG_DEVELOPER
        // UI::AlignTextToFramePadding();
        if (UX::SmallButton(Icons::Cube + " Explore Cursor##c")) {
            ExploreNod("Editor Cursor", cursor);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(cursor)));
#endif
        Children.DrawTabsAsList();
    }
}

[Setting hidden]
bool S_CursorWindowOpen = false;

[Setting hidden]
bool S_CursorWindowRotControls = true;

[Setting hidden]
bool S_AutoActivateCustomRotations = false;

// activated from the tools menu, see UI_Main
class CursorPosition : Tab {
    CursorPosition(TabGroup@ parent) {
        this.addRandWindowExtraId = false;
        super(parent, "Cursor Coords", Icons::HandPointerO);
        this.windowExtraId = 0;
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditor), this.tabName);
    }

    void OnEditor() {
        this.windowOpen = S_CursorWindowOpen;
        if (S_AutoActivateCustomRotations) CustomCursorRotations::Active = true;
    }

    bool get_windowOpen() override property {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor !is null && Tab::get_windowOpen();
    }

    void set_windowOpen(bool value) override property {
        S_CursorWindowOpen = value;
        Tab::set_windowOpen(value);
    }

    int get_WindowFlags() override {
        return UI::WindowFlags::AlwaysAutoResize | UI::WindowFlags::NoCollapse | UI::WindowFlags::NoTitleBar;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;

        UI::PushFont(g_BigFont);
        UI::Text("Cursor   ");
        auto width = UI::GetWindowContentRegionWidth();
        DrawLabledCoord("X", Text::Format("% 3d", cursor.Coord.x));
        DrawLabledCoord("Y", Text::Format("% 3d", cursor.Coord.y));
        DrawLabledCoord("Z", Text::Format("% 3d", cursor.Coord.z));
        UI::Text(tostring(cursor.Dir));
        UI::Text("Pivot: " + Editor::GetCurrentPivot(editor));
        UI::PopFont();
        DrawCursorControls(cursor);
    }

    void DrawCursorControls(CGameCursorBlock@ cursor) {
        if (!S_CursorWindowRotControls) return;
        auto rot = Editor::GetCursorRot(cursor);
        UI::AlignTextToFramePadding();
        // UI::SetNextItemWidth(30.);
        bool addPitch = UI::Button("P+", vec2(30., 0.)); UI::SameLine();
        // UI::SetNextItemWidth(30.);
        bool subPitch = UI::Button("P-", vec2(30., 0.));
        UI::SameLine(); UI::Text(Text::Format("%.1f", rot.PitchD));
        UI::AlignTextToFramePadding();
        // UI::SetNextItemWidth(30.);
        bool addYaw = UI::Button("Y+", vec2(30., 0.));
        UI::SameLine();
        // UI::SetNextItemWidth(30.);
        bool subYaw = UI::Button("Y-", vec2(30., 0.));
        UI::SameLine(); UI::Text(Text::Format("%.1f", rot.YawD));
        UI::AlignTextToFramePadding();
        // UI::SetNextItemWidth(30.);
        bool addRoll = UI::Button("R+", vec2(30., 0.));
        UI::SameLine();
        // UI::SetNextItemWidth(30.);
        bool subRoll = UI::Button("R-", vec2(30., 0.));
        UI::SameLine(); UI::Text(Text::Format("%.1f", rot.RollD));
        bool reset = UI::Button("Reset");

        if (reset) {
            ResetCursor(cursor);
            return;
        }

        if (!(addPitch || subPitch || addYaw || subYaw || addRoll || subRoll)) {
            return;
        }

        vec3 mod = vec3();
        mod += addPitch ? vec3(Math::ToRad(15), 0, 0) : vec3();
        mod += subPitch ? vec3(Math::ToRad(-15), 0, 0) : vec3();
        mod += addYaw ? vec3(0, Math::ToRad(15.001), 0) : vec3();
        mod += subYaw ? vec3(0, Math::ToRad(-15), 0) : vec3();
        mod += addRoll ? vec3(0, 0, Math::ToRad(15)) : vec3();
        mod += subRoll ? vec3(0, 0, Math::ToRad(-15)) : vec3();

        rot.euler += mod;
        rot.UpdateDirFromPry();
        rot.SetCursor(cursor);
    }

    void DrawLabledCoord(const string &in axis, const string &in value) {
        auto pos = UI::GetCursorPos();
        UI::Text(axis);
        UI::SetCursorPos(pos + vec2(32, 0));
        UI::Text(value);
    }
}

CursorPosition@ g_CursorPositionWindow;

class CursorFavTab : Tab {
    CursorTab@ cursorTab;

    CursorFavTab(TabGroup@ parent, CursorTab@ ct) {
        super(parent, "Favorites", "");
        @cursorTab = ct;
    }

    void SaveFavorite(CGameCursorBlock@ cursor) {

    }
}


class CursorPropsTab : Tab {
    CursorTab@ cursorTab;

    CursorPropsTab(TabGroup@ parent, CursorTab@ ct) {
        super(parent, "Cursor Properties", "");
        @cursorTab = ct;
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        S_CopyPickedItemRotation = UI::Checkbox("Copy Rotations from Picked Items (ctrl+hover)", S_CopyPickedItemRotation);
        S_CopyPickedBlockRotation = UI::Checkbox("Copy Rotations from Picked Blocks (ctrl+hover)", S_CopyPickedBlockRotation);
        UI::Text("Cursor:");
        // this only works for blocks and is to do with freeblock positioning i think
        // g_UseSnappedLoc = UI::Checkbox("Force Snapped Location", g_UseSnappedLoc);
        auto cursor = editor.Cursor;
        cursor.Pitch = Math::ToRad(UI::InputFloat("Pitch (Deg)", Math::ToDeg(cursor.Pitch), Math::PI / 24.));
        cursor.Roll = Math::ToRad(UI::InputFloat("Roll (Deg)", Math::ToDeg(cursor.Roll), Math::PI / 24.));

        if (UI::BeginCombo("Dir", tostring(cursor.Dir))) {
            for (uint i = 0; i < 4; i++) {
                auto d = CGameCursorBlock::ECardinalDirEnum(i);
                if (UI::Selectable(tostring(d), d == cursor.Dir)) {
                    cursor.Dir = d;
                }
            }
            UI::EndCombo();
        }
        if (UI::BeginCombo("AdditionalDir", tostring(cursor.AdditionalDir))) {
            for (uint i = 0; i < 6; i++) {
                auto d = CGameCursorBlock::EAdditionalDirEnum(i);
                if (UI::Selectable(tostring(d), d == cursor.AdditionalDir)) {
                    cursor.AdditionalDir = d;
                }
            }
            UI::EndCombo();
        }

        // if (UI::Button(Icons::StarO + "##add-fav-cursor")) {
            // cursorTab.cursorFavs.SaveFavorite(cursor);
        // }
        // UI::SameLine();

        UI::SetCursorPos(UI::GetCursorPos() + vec2(10, 0));

        if (UI::Button("Reset##cursor")) {
            ResetCursor(cursor);
        }

        UI::Separator();
        if (g_CursorPositionWindow !is null) {
            g_CursorPositionWindow.windowOpen = UI::Checkbox("Show Cursor Info Window", g_CursorPositionWindow.windowOpen);
        }
        S_CursorWindowRotControls = UI::Checkbox("Cursor Window Includes Rotation Controls" + NewIndicator, S_CursorWindowRotControls);

        UI::Separator();
        CustomCursorRotations::Active = UI::Checkbox("Enable Custom Cursor Rotation Amounts", CustomCursorRotations::Active);
        AddSimpleTooltip("Only works for Pitch and Roll");
        CustomCursorRotations::DrawSettings();
        // S_AutoActivateCustomRotations is checked in OnEditor for cursor window
        S_AutoActivateCustomRotations = UI::Checkbox("Auto-activate custom cursor rotations", S_AutoActivateCustomRotations);
        AddSimpleTooltip("Activates when entering the editor");

    }
}

void ResetCursor(CGameCursorBlock@ cursor) {
    cursor.Pitch = 0;
    cursor.Roll = 0;
    cursor.AdditionalDir = CGameCursorBlock::EAdditionalDirEnum::P0deg;
    cursor.Dir = CGameCursorBlock::ECardinalDirEnum::North;
}





namespace CustomCursorRotations {
    [Setting hidden]
    float customRot = TAU / 4. / 12.;

    void DrawSettings() {
        int origParts = Math::Round(TAU / 4. / customRot);
        int newParts = Math::Clamp(UI::InputInt("Taps per 90 degrees", origParts), 2, 128);
        if (origParts != newParts) customRot = TAU / 4. / float(newParts);
        float crDeg = Math::ToDeg(customRot);
        float crNewDec = UI::InputFloat("Rotation (Deg)", crDeg);
        if (crNewDec != crDeg) customRot = Math::ToRad(crNewDec);
    }

    void SetCustomCursorRot(float _customRot) {
        customRot = _customRot;
    }

    float GetCustomCursorRot() {
        return customRot;
    }

    HookHelper@ ccRot1 = HookHelper(
        "F3 0F 11 83 8C 00 00 00 EB 15 F3 0F 58 83 94 00 00 00 E8 ?? ?? ?? ?? F3 0F 11 83 94 00 00 00 48 8B 5C 24 30 48 8B 6C 24 38 48 8B 74 24 40",
        0, 3, "CustomCursorRotations::OnSetRot1"
    );
    HookHelper@ ccRot2 = HookHelper(
        "EB 15 F3 0F 58 83 94 00 00 00 E8 ?? ?? ?? ?? F3 0F 11 83 94 00 00 00 48 8B 5C 24 30 48 8B 6C 24 38 48 8B 74 24 40",
        15, 3, "CustomCursorRotations::OnSetRot2"
    );

    void OnSetRot1(uint64 rbx) {
        dev_trace('rbx rot 1: ' + Text::FormatPointer(rbx));
        UpdateInferCustomRot(rbx, 0x8C);
    }
    void OnSetRot2(uint64 rbx) {
        dev_trace('rbx rot 2: ' + Text::FormatPointer(rbx));
        UpdateInferCustomRot(rbx, 0x94);
    }

    void UpdateInferCustomRot(uint64 ptr, uint offset) {
        // before and after
        vec2 ba = Dev::ReadVec2(ptr + offset - 0x4);
        // trace("got BA: " + ba.ToString());
        float diff = Math::Abs(ba.y - ba.x);
        float sign = ba.y > ba.x ? 1.0 : -1.0;
        if (diff > PI) sign = ba.y > 0.0 ? -1.0 : 1.0;
        float new = ba.x + sign * customRot;
        if (new > PI) new -= TAU;
        if (new < NegPI) new += TAU;
        Dev::Write(ptr + offset, new);
    }
    bool Active {
        get {
            return ccRot1.IsApplied() && ccRot2.IsApplied();
        }
        set {
            ccRot1.SetApplied(value);
            ccRot2.SetApplied(value);
        }
    }
}
