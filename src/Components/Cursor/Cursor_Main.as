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

[Setting hidden]
bool S_AutoActivateCustomYaw = false;

[Setting hidden]
bool S_CursorWindowShowDetailed = false;

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
        if (S_AutoActivateCustomYaw) CustomCursorRotations::CustomYawActive = true;
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

    void _BeforeBeginWindow() override {
        UI::SetNextWindowSize(130, 0, UI::Cond::Always);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;
        auto itemCursor = editor.ItemCursor;
        UI::PushFont(g_BigFont);
        UI::Text("Cursor   ");
        auto width = UI::GetWindowContentRegionWidth();
        DrawLabledCoord("X", Text::Format("% 3d", cursor.Coord.x));
        DrawLabledCoord("Y", Text::Format("% 3d", cursor.Coord.y));
        DrawLabledCoord("Z", Text::Format("% 3d", cursor.Coord.z));
        UI::Text(tostring(cursor.Dir));
        UI::PopFont();
        bool isPlacingItem = Editor::IsInAnyItemPlacementMode(editor);
        if (S_CursorWindowShowDetailed) {
            if (isPlacingItem) {
                CopiableLabeledValue("Pos", FormatX::Vec3_NewLines(itemCursor.CurrentPos));
            } else {
                CopiableLabeledValue("Pos", FormatX::Vec3_NewLines(cursor.FreePosInMap));
            }
        }
        UI::Text("Pivot: " + Editor::GetCurrentPivot(editor));
        DrawCursorControls(cursor);
        if (cursor.UseSnappedLoc && S_CursorWindowShowDetailed) {
            UI::Text("\\$aaa -- Snapped -- ");
            CopiableLabeledValue("Pos", FormatX::Vec3_NewLines(cursor.SnappedLocInMap_Trans));
            vec3 snappedRot = MathX::ToDeg(vec3(cursor.SnappedLocInMap_Pitch, cursor.SnappedLocInMap_Yaw, cursor.SnappedLocInMap_Roll));
            CopiableLabeledValue("Rot", FormatX::Vec3_NewLines(snappedRot, 3));
        }
    }

    void DrawCursorControls(CGameCursorBlock@ cursor) {
        if (!S_CursorWindowRotControls) return;
        auto rot = Editor::GetCursorRot(cursor);
        if (cursor.UseSnappedLoc) {
            rot.Euler = vec3(cursor.SnappedLocInMap_Pitch, cursor.SnappedLocInMap_Yaw, cursor.SnappedLocInMap_Roll);
        }
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
        bool customPR = CustomCursorRotations::Active;
        bool customYaw = CustomCursorRotations::CustomYawActive;
        float toAdd = Math::ToRad(15);
        float toAddYaw = Math::ToRad(15);
        if (customPR) toAdd = CustomCursorRotations::GetCustomCursorRot();
        if (customYaw) toAddYaw = 0.0;
        mod += addPitch ? vec3((toAdd), 0, 0) : vec3();
        mod += subPitch ? vec3((-toAdd), 0, 0) : vec3();
        mod += addYaw ? vec3(0, (toAddYaw), 0) : vec3();
        mod += subYaw ? vec3(0, (-toAddYaw), 0) : vec3();
        mod += addRoll ? vec3(0, 0, (toAdd)) : vec3();
        mod += subRoll ? vec3(0, 0, (-toAdd)) : vec3();

        rot.Euler += mod;
        rot.SetCursor(cursor);
        auto customPYR = CustomCursorRotations::cursorCustomPYR;
        if (customYaw) {
            float deltaYaw = addYaw ? toAdd : subYaw ? -toAdd : 0.0;
            customPYR.y += deltaYaw;
            CustomCursorRotations::NormalizeCustomYaw(cursor, cursor.Dir);
            if (cursor.UseSnappedLoc) {
                cursor.SnappedLocInMap_Yaw = EditorRotation(cursor).YawWithCustomExtra(customPYR.y);
            }
            CustomCursorRotations::cursorCustomPYR.y = customPYR.y;
        }
        if (customPR) {
            customPYR.x = rot.Pitch;
            customPYR.z = rot.Roll;
            if (cursor.UseSnappedLoc) {
                cursor.SnappedLocInMap_Pitch = NormalizeAngle(customPYR.x);
                cursor.SnappedLocInMap_Roll = NormalizeAngle(customPYR.z);
            }
        }
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
        float step = Math::PI / 24.;
        if (CustomCursorRotations::Active) step = Math::ToDeg(CustomCursorRotations::customRot);
        cursor.Pitch = Math::ToRad(UI::InputFloat("Pitch (Deg)", Math::ToDeg(cursor.Pitch), step));
        cursor.Roll = Math::ToRad(UI::InputFloat("Roll (Deg)", Math::ToDeg(cursor.Roll), step));
        cursor.Dir = DrawComboCursorECardinalDir("Dir", cursor.Dir);
        if (CustomCursorRotations::CustomYawActive) {
            CustomCursorRotations::cursorCustomPYR.y = Math::ToRad(UI::InputFloat("Add. Yaw (Deg)", Math::ToDeg(CustomCursorRotations::cursorCustomPYR.y), step));
            CustomCursorRotations::NormalizeCustomYaw(cursor, cursor.Dir);
        } else {
            cursor.AdditionalDir = DrawComboCursorEAdditionalDirEnum("AdditionalDir", cursor.AdditionalDir);
        }
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
        S_CursorWindowShowDetailed = UI::Checkbox("Show Details: exact position and snapping", S_CursorWindowShowDetailed);

        UI::Separator();

        CustomCursorRotations::ItemStappingEnabled = UI::Checkbox("Item-to-Block Snapping Enabled" + NewIndicator, CustomCursorRotations::ItemStappingEnabled);
        bool wasActive = CustomCursorRotations::Active;
        auto nextActive = UI::Checkbox("Enable Custom Cursor Rotation Amounts", wasActive);
        if (wasActive != nextActive) CustomCursorRotations::Active = nextActive;
        AddSimpleTooltip("Only works for Pitch and Roll");

        wasActive = CustomCursorRotations::CustomYawActive;
        nextActive = UI::Checkbox("Enable Custom Yaw \\$f80BETA!" + NewIndicator, wasActive);
        if (wasActive != nextActive) CustomCursorRotations::CustomYawActive = nextActive;
        AddSimpleTooltip("Note: this currently does not work correctly with item-to-block snapping.");

        CustomCursorRotations::DrawSettings();
        // S_AutoActivateCustomRotations is checked in OnEditor for cursor window
        S_AutoActivateCustomRotations = UI::Checkbox("Auto-activate custom cursor rotations (Pitch, Roll)", S_AutoActivateCustomRotations);
        AddSimpleTooltip("Activates when entering the editor");
        S_AutoActivateCustomYaw = UI::Checkbox("Auto-activate custom cursor rotations (Yaw)", S_AutoActivateCustomYaw);
        AddSimpleTooltip("Activates when entering the editor");

        wasActive = S_EnablePromiscuousItemSnapping;
        S_EnablePromiscuousItemSnapping = UI::Checkbox("Enable Promiscuous Item Snapping" + NewIndicator, S_EnablePromiscuousItemSnapping);
        AddSimpleTooltip("Items that snap to blocks will be less picky about which blocks they snap to. Example: trees will now snap to all terrain.\n\nNOTE: If you toggle this, it will only take effect for newly placed blocks, or when you reload the map.");
        if (wasActive != S_EnablePromiscuousItemSnapping) {
            CustomCursorRotations::PromiscuousItemToBlockSnapping.IsApplied = S_EnablePromiscuousItemSnapping;
        }
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

    // yaw tracks extra direction only (between 0 and 90deg), but pitch and roll are full rotations
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

    bool Active {
        get {
            return ccRot1.IsApplied()
                && ccRot2.IsApplied()
                ;
        }
        set {
            ccRot1.SetApplied(value);
            ccRot2.SetApplied(value);
            if (value) {
                UpdateCachedCursorXZ();
            }
        }
    }

    bool CustomYawActive {
        get {
            return AfterCursorUpdateHook.IsApplied()
                && AfterSetCursorRotationHook.IsApplied()
                ;
        }
        set {
            AfterCursorUpdateHook.SetApplied(value);
            AfterSetCursorRotationHook.SetApplied(value);
        }
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

    // this gives access to the stack values that update the cursor rotations
    HookHelper@ AfterSetCursorRotationHook = HookHelper(
        "8B 87 8C 00 00 00 89 81 ?? ?? 00 00 48 8B 8B ?? ?? 00 00 8B 87 94 00 00 00",
        19, 1, "CustomCursorRotations::AfterSetCursorRotation_Rdi_7C"
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

    // rotation is written to the stack, and then we can overwrite it before it's written to the cursor
    void OnSetRot1(uint64 rbx) {
        dev_trace('rbx rot 1: ' + Text::FormatPointer(rbx));
        cursorCustomPYR.x = UpdateInferCustomRot(rbx, 0x8C);
    }
    // rotation is written to the stack, and then we can overwrite it before it's written to the cursor
    void OnSetRot2(uint64 rbx) {
        dev_trace('rbx rot 2: ' + Text::FormatPointer(rbx));
        cursorCustomPYR.z = UpdateInferCustomRot(rbx, 0x94);
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
            itemCursor.mat = iso4(mat4::Inverse(EulerToMat(pyr)));
            itemCursor.pos = pos;
        }
        // but we also want to set snapped location b/c that's used later on
        if (Editor::IsInCustomRotPlacementMode(editor)) {
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
            cursor.SnappedLocInMap_Yaw = EditorRotation(cursor).YawWithCustomExtra(cursorCustomPYR.y);
            cursor.SnappedLocInMap_Trans = cursor.FreePosInMap;
            cursor.UseSnappedLoc = true;
            dev_trace("After Cursor Update: " + cursor.UseSnappedLoc);
        }
    }

    // based on the prior and next rotations, infer the direction and overwrite new rotation (pitch/roll only)
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


    // after direction or additional dir is changed. rbx = editor, rdi = stack
    void AfterSetCursorRotation_Rdi_7C(uint64 rbx, uint64 rdi) {
        dev_trace('editor pointer: ' + Text::FormatPointer(rbx));
        dev_trace('rdi: ' + Text::FormatPointer(rdi));
        // 0x78: last dir, 0x7C: next dir
        // 0x80: last additional dir, 0x84: next additional dir
        // 0x88: last pitch, 0x8C: next pitch
        // 0x90: last roll, 0x94: next roll
        // 0xB8: last use snapped, 0xBC: next use snapped loc
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto cursor = editor.Cursor;

        // infer direction
        auto lastDir = Dev::ReadInt32(rdi + 0x78);
        auto nextDir = Dev::ReadInt32(rdi + 0x7C);
        auto lastAddDir = Dev::ReadInt32(rdi + 0x80);
        auto nextAddDir = Dev::ReadInt32(rdi + 0x84);
        dev_trace("lastDir: " + lastDir + ", nextDir: " + nextDir);
        dev_trace("lastAddDir: " + lastAddDir + ", nextAddDir: " + nextAddDir);
        auto dirChanged = lastDir != nextDir;
        auto addDirChanged = lastAddDir != nextAddDir;
        // rmb with nonzero addDir: reset addDir
        // rmb with no addDir: +1 to dir
        // pg up with addDir < 5: +1 to addDir
        // pg up with addDir == 5: -1 to dir, reset addDir
        // pg down with addDir > 0: -1 to addDir
        // pg down with addDir == 0: +1 to dir, addDir = 5

        // will be 0 unless game is setting it to true. We check it before the game does, so it will still set this value.
        // I guess we could set it here, but we set it later anyway.
        int lastUseSnapPos = Dev::ReadInt32(rdi + 0xB8);
        dev_trace("lastUseSnapPos: " + lastUseSnapPos);
        int nextUseSnapPos = Dev::ReadInt32(rdi + 0xBC);
        dev_trace("nextUseSnapPos: " + nextUseSnapPos);
        Dev::Write(rdi + 0xBC, 0); // force no use snaped loc (we set it later if needed)

        // do nothing if rotation wasn't changed.
        if (!dirChanged && !addDirChanged) {
            return;
        }

        bool rmbPressed = Dev::ReadUInt8(rbx + O_EDITOR_RMB_PRESSED1) != 0;
        dev_trace("rmbPressed: " + rmbPressed);
        // if (dirChanged) {
        //     dev_trace("Direction changed: " + lastDir + " -> " + nextDir);
        // }
        // if (addDirChanged) {
        //     dev_trace("Additional direction changed: " + lastAddDir + " -> " + nextAddDir);
        // }

        if (rmbPressed) {
            bool yawWasNonzero = cursorCustomPYR.y != 0.0;
            dev_trace("RMB pressed, resetting custom yaw. yaw was nonZero: " + yawWasNonzero);
            cursorCustomPYR.y = 0;
            if (yawWasNonzero) {
                // need to undo cursor rotation b/c we might have been at 0 additional dir
                cursor.Dir = CGameCursorBlock::ECardinalDirEnum(lastDir);
            }
            return;
        }

        bool dirDecr = lastAddDir == 5 && nextAddDir == 0;
        bool dirIncr = lastAddDir == 0 && nextAddDir == 5;
        bool addDirIncr = (lastAddDir < nextAddDir && !dirIncr) || dirDecr;
        bool addDirDecr = (lastAddDir > nextAddDir && !dirDecr) || dirIncr;
        dev_trace("dirIncr: " + dirDecr + ", dirDecr: " + dirIncr);
        dev_trace("addDirIncr: " + addDirIncr + ", addDirDecr: " + addDirDecr);

        // reset direction change because we adjust it later if needed
        cursor.Dir = CGameCursorBlock::ECardinalDirEnum(lastDir);

        dev_trace("1. Custom Yaw: " + cursorCustomPYR.y + " (Dir: " + cursor.Dir + ")");
        if (addDirIncr) {
            cursorCustomPYR.y += customRot;

        } else if (addDirDecr) {
            cursorCustomPYR.y -= customRot;
        }
        dev_trace("2. Custom Yaw: " + cursorCustomPYR.y + " (Dir: " + cursor.Dir + ")");
        NormalizeCustomYaw(cursor, lastDir);
        dev_trace("3. Custom Yaw: " + cursorCustomPYR.y + " (Dir: " + cursor.Dir + ")");
        cursor.AdditionalDir = YawToAdditionalDir(cursorCustomPYR.y);
        dev_trace("UseSnappedLoc: " + nextUseSnapPos + " (return early if true)");
        if (nextUseSnapPos > 0) return;
    }


    void NormalizeCustomYaw(CGameCursorBlock@ cursor, int lastDir) {
        if (cursorCustomPYR.y > HALF_PI - 0.000) {
            cursorCustomPYR.y -= HALF_PI;
            cursor.Dir = CGameCursorBlock::ECardinalDirEnum((lastDir + 3) % 4);
        } else if (cursorCustomPYR.y < 0.000) {
            cursorCustomPYR.y += HALF_PI;
            cursor.Dir = CGameCursorBlock::ECardinalDirEnum((lastDir + 1) % 4);
        }
        cursorCustomPYR.y = Math::Clamp(cursorCustomPYR.y, 0.0, HALF_PI);
    }


    void UpdateCachedCursorXZ() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        if (!Editor::IsInCustomRotPlacementMode(editor)) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;
        cursorCustomPYR.x = cursor.Pitch;
        cursorCustomPYR.z = cursor.Roll;
        // cursorCustomPYR.y = (cursorCustomPYR.y);
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
        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // auto cursor = editor.Cursor;
        // auto rots = EditorRotation(cursorCustomPYR);
        // rots.Dir = cursor.Dir;
        // float yaw = rots.YawWithCustomExtra(cursorCustomPYR.y);

        // rots.euler
        // q = q * quat(vec3(0, Math::Sin(float(Time::Now) / 1000.0f) * PI, 0));
        // dev_trace("new q: " + q.ToString());
        // Dev::Write(addr, vec4(q.x, q.y, q.z, q.w));
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        // todo: custom yaw
        // nothing to do: snapped loc takes care of it
        return false;
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        // todo: custom yaw
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto cursor = editor.Cursor;
        if (CustomYawActive) {
            item.Yaw += cursorCustomPYR.y - AdditionalDirToYaw(cursor.AdditionalDir);
        }
        return false;
    }
}
