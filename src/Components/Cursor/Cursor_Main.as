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

        auto cursor = editor.Cursor;

        UI::Columns(2, "cursor-rot", false);
        UI::Text("Cursor:");
        cursor.Pitch = Math::ToRad(UI::InputFloat("Pitch (Deg)", Math::ToDeg(cursor.Pitch), Math::PI / 24.));
        cursor.Roll = Math::ToRad(UI::InputFloat("Roll (Deg)", Math::ToDeg(cursor.Roll), Math::PI / 24.));
        cursor.Dir = DrawComboCursorECardinalDir("Dir", cursor.Dir);
        cursor.AdditionalDir = DrawComboCursorEAdditionalDirEnum("AdditionalDir", cursor.AdditionalDir);
        UI::AlignTextToFramePadding();
        CopiableLabeledValue("Pos", cursor.FreePosInMap.ToString());

        UI::NextColumn();
        UI::Text("Snapped:");
        UI::BeginDisabled();
        cursor.UseSnappedLoc = UI::Checkbox("Use Snapped Location", cursor.UseSnappedLoc);
        cursor.SnappedLocInMap_Pitch = Math::ToRad(UI::InputFloat("S Pitch (Deg)", Math::ToDeg(cursor.SnappedLocInMap_Pitch), Math::PI / 24.));
        cursor.SnappedLocInMap_Roll = Math::ToRad(UI::InputFloat("S Roll (Deg)", Math::ToDeg(cursor.SnappedLocInMap_Roll), Math::PI / 24.));
        cursor.SnappedLocInMap_Yaw = Math::ToRad(UI::InputFloat("S Yaw (Deg)", Math::ToDeg(cursor.SnappedLocInMap_Yaw), Math::PI / 24.));
        UI::EndDisabled();
        UI::AlignTextToFramePadding();
        CopiableLabeledValue("Pos", cursor.SnappedLocInMap_Trans.ToString());

        UI::Columns(1);
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
        S_CursorWindowRotControls = UI::Checkbox("Cursor Window Includes Rotation Controls", S_CursorWindowRotControls);

        UI::Separator();

        CustomCursorRotations::ItemStappingEnabled = UI::Checkbox("Item-to-Block Snapping Enabled" + NewIndicator, CustomCursorRotations::ItemStappingEnabled);
        bool wasActive = CustomCursorRotations::Active;
        auto nextActive = UI::Checkbox("Enable Custom Cursor Rotation Amounts", wasActive);
        if (wasActive != nextActive) CustomCursorRotations::Active = nextActive;

        AddSimpleTooltip("Only works for Pitch and Roll");
        CustomCursorRotations::DrawSettings();
        // S_AutoActivateCustomRotations is checked in OnEditor for cursor window
        S_AutoActivateCustomRotations = UI::Checkbox("Auto-activate custom cursor rotations", S_AutoActivateCustomRotations);
        AddSimpleTooltip("Activates when entering the editor");

        S_EnablePromiscuousItemSnapping = UI::Checkbox("Enable Promiscuous Item Snapping", S_EnablePromiscuousItemSnapping);
        AddSimpleTooltip("Items that snap to blocks will be less picky about which blocks they snap to.\n\nNOTE: If you toggle this, it will only take effect for newly placed blocks, or when you reload the map.");
    }
}

void ResetCursor(CGameCursorBlock@ cursor) {
    cursor.Pitch = 0;
    cursor.Roll = 0;
    cursor.AdditionalDir = CGameCursorBlock::EAdditionalDirEnum::P0deg;
    cursor.Dir = CGameCursorBlock::ECardinalDirEnum::North;
}


[Setting hidden]
bool S_EnablePromiscuousItemSnapping = true;

namespace CustomCursorRotations {
    [Setting hidden]
    float customRot = TAU / 4. / 12.;

    vec3 cursorCustomPYR = vec3();

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

    bool ItemStappingEnabled {
        get {
            return !DisableItemSnapping.IsApplied;
        }
        set {
            DisableItemSnapping.IsApplied = !value;
        }
    }

    // just after rot1 is written to the stack
    HookHelper@ ccRot1 = HookHelper(
        "F3 0F 11 83 8C 00 00 00 EB 15 F3 0F 58 83 94 00 00 00 E8 ?? ?? ?? ?? F3 0F 11 83 94 00 00 00 48 8B 5C 24 30 48 8B 6C 24 38 48 8B 74 24 40",
        0, 3, "CustomCursorRotations::OnSetRot1"
    );
    // just after rot2 is written to the stack
    HookHelper@ ccRot2 = HookHelper(
        "EB 15 F3 0F 58 83 94 00 00 00 E8 ?? ?? ?? ?? F3 0F 11 83 94 00 00 00 48 8B 5C 24 30 48 8B 6C 24 38 48 8B 74 24 40",
        15, 3, "CustomCursorRotations::OnSetRot2"
    );

    // idea is to use this to overwrite cursor stuff right after it's been set
    HookHelper@ AfterCursorUpdateHook = HookHelper(
     // "FF 90 28 02 00 00 83 7D F4 00 74 23 48 8B 4F 68 BA 41 00 00 00 4C 8B 01 41 FF 90 08 01 00 00 85 C0",
        "FF 90 ?? ?? 00 00 83 7D F4 00 74 ?? 48 8B 4F ?? BA ?? 00 00 00 4C 8B 01 41 FF 90 ?? ?? 00 00 85 C0",
        0, 1, "CustomCursorRotations::AfterCursorUpdate"
    );

    // patches to always JMP like there was nothing to snap to
    MemPatcher@ DisableItemSnapping = MemPatcher(
        "0F 84 ?? ?? 00 00 48 8B 96 78 04 00 00 4C 8D 85 ?? ?? 00 00 48 8B 85 ?? ?? 00 00",
        {0}, {"90 E9"}, /* expected */ {"0F 84"}
        // turn JE into NOP, JMP
    );

    // todo: test placement layouts
    // Items are less picky about the blocks they snap to. Needs to be enabled before blocks are placed, or before they are loaded (i.e., before the map is loaded in the editor)
    MemPatcher@ PromiscuousItemToBlockSnapping = MemPatcher(
        // "48 8b 80 ?? ?? 00 00 0f 28 85 ?? ?? 00 00 48 8d 14 ba f2 0f 11 8d ?? ?? 00 00 0f 28 8d ?? ?? 00 00",
        "48 8b 80 ?? ?? 00 00 0f 28 85 ?? ?? 00 00 48 8d 14 ba",
        {0}, {"48 31 C0 48 FF C8 90"}, /* expected */ {"48 8B 80 30 02 00 00"}
    );

    void OnSetRot1(uint64 rbx) {
        dev_trace('rbx rot 1: ' + Text::FormatPointer(rbx));
        cursorCustomPYR.x = UpdateInferCustomRot(rbx, 0x8C);
    }
    void OnSetRot2(uint64 rbx) {
        dev_trace('rbx rot 2: ' + Text::FormatPointer(rbx));
        cursorCustomPYR.z = UpdateInferCustomRot(rbx, 0x94);
    }

    // after direction or additional dir is changed
    void AfterCursorYawUpdate() {

    }

    // overwrite cursor properties here if we want, after the whole cursor has been updated (I think...)
    void AfterCursorUpdate() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;
        // make sure we're in a good mode, any item takes precedence over any free mode
        if (Editor::IsInAnyItemPlacementMode(editor)) {
            auto @itemCursor = DGameCursorItem(editor.ItemCursor);
            auto pos = itemCursor.pos;
            // todo, this is weird with snapping items and seems to rotate things in the wrong direction (but correct axis)
            // auto pyr = EditorRotation(cursor).euler;
            auto pyr = cursorCustomPYR;
            pyr.y = EditorRotation(cursor).YawWithCustomExtra(pyr.y);
            // pyr.y =
            itemCursor.mat = iso4(mat4::Inverse(EulerToMat(cursorCustomPYR)));
            itemCursor.pos = pos;
        }
        // but we also want to set snapped location b/c that's used later on
        if (Editor::IsInAnyFreePlacementMode(editor)) {
            // this is false in item mode: if (!cursor.UseFreePos) return;
            // b/c snapping can be disabled
            if (cursor.UseSnappedLoc) return;

            // cursor.UseSnappedLoc = true;
            // cursor.SnappedLocInMap_Trans = cursor.FreePosInMap;
            // auto angle = float(Time::Now % 1000) / 1000.0f * TAU;
            // // cursor.SnappedLocInMap_Trans = ;
            // cursor.SnappedLocInMap_Pitch = NormalizeAngle(cursor.Pitch + angle);
            // cursor.SnappedLocInMap_Roll = NormalizeAngle(cursor.Roll - angle / 3.);

            // cursorCustomPYR.x = cursor.Pitch;
            // // cursorCustomPYR.y;
            // cursorCustomPYR.z = cursor.Roll;

            cursor.SnappedLocInMap_Pitch = NormalizeAngle(cursorCustomPYR.x);
            cursor.SnappedLocInMap_Roll = NormalizeAngle(cursorCustomPYR.z);
            cursor.SnappedLocInMap_Yaw = NormalizeAngle(cursorCustomPYR.y);
            cursor.SnappedLocInMap_Trans = cursor.FreePosInMap;
            cursor.UseSnappedLoc = true;
        }
    }

    // based on the prior and next rotations, infer the direction and overwrite new rotation
    float UpdateInferCustomRot(uint64 ptr, uint offset) {
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
        return new;
    }

    bool Active {
        get {
            return ccRot1.IsApplied() && ccRot2.IsApplied()
                && AfterCursorUpdateHook.IsApplied();
        }
        set {
            ccRot1.SetApplied(value);
            ccRot2.SetApplied(value);
            AfterCursorUpdateHook.SetApplied(value);
            if (value) {
                UpdateCachedCursorXZ();
            }
        }
    }

    void UpdateCachedCursorXZ() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        if (!Editor::IsInCustomRotPlacementMode(editor)) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;
        cursorCustomPYR.x = cursor.Pitch;
        cursorCustomPYR.z = cursor.Roll;
        cursorCustomPYR.y = cursorCustomPYR.y;
        dev_trace("Updated Cached Cursor PYR: " + cursorCustomPYR.ToString());
    }

    // offset may change, in which case pattern will not match (pattern in NewPlacementHooks.as)
    void OnGetCursorRotation_Rbp70(uint64 rbp) {
        dev_trace("OnGetCursorRotation! rbp: " + Text::FormatPointer(rbp));
        // quat at rbp + 0x70
        auto addr = rbp + 0x70;
        vec4 vq = Dev::ReadVec4(addr);
        quat q = quat(vq.x, vq.y, vq.z, vq.w);
        dev_trace("q: " + q.ToString());
        if (!IsInEditor) {
            warn_every_60_s("OnGetCursorRotation_Rbp70: called outside editor!");
        }
        // todo: check if active, if so, write quaternion
        // q = q * quat(vec3(0, Math::Sin(float(Time::Now) / 1000.0f) * PI, 0));
        // dev_trace("new q: " + q.ToString());
        // Dev::Write(addr, vec4(q.x, q.y, q.z, q.w));
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        // todo: custom yaw

        return false;
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        // todo: custom yaw

        return false;
    }
}
