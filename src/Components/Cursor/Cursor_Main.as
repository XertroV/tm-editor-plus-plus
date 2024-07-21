class CursorTab : Tab {
    CursorPropsTab@ cursorProps;
    CustomCursorTab@ cursorAdvFeatures;

    CursorTab(TabGroup@ parent) {
        super(parent, "Cursor Coords", Icons::HandPointerO);
        canPopOut = false;
        // child tabs
        @cursorProps = CursorPropsTab(Children, this);
        // @cursorAdvFeatures = CustomCursorTab(Children, this);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        auto itemCursor = editor.ItemCursor;
        if (cursor is null) return;
#if SIG_DEVELOPER
        // UI::AlignTextToFramePadding();
        if (UX::SmallButton(Icons::Cube + " Explore Cursor##c")) {
            ExploreNod("Editor Cursor", cursor);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(cursor)));
        if (UX::SmallButton(Icons::Cube + " Explore Item Cursor##c")) {
            ExploreNod("Editor Item Cursor", itemCursor);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(itemCursor)));
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
        if (S_AutoApplyFreeWaterBlocksPatch) CustomCursor::AllowFreeWaterBlocksPatchActive = true;
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

    bool DrawWindow() override {
        if (S_DrawFreeBlockClips) {
            DrawFreeBlockClips();
        }
        return Tab::DrawWindow();
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;
        auto itemCursor = editor.ItemCursor;
        if (itemCursor is null) return;
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

[Setting hidden]
#if DEV
bool S_DrawFreeBlockClips = true;
#else
bool S_DrawFreeBlockClips = false;
#endif

[Setting hidden]
bool S_DrawAnySnapRadiusOnHelpers = true;
[Setting hidden]
bool S_DrawFreeBlockClipsOnNearbyBlocks = true;

void DrawFreeBlockClips() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    if (editor is null) return;
    if (!Editor::IsInFreeBlockPlacementMode(editor)) return;
    auto bi = editor.CurrentGhostBlockInfo;
    if (bi is null) return;
    bool isAir = Editor::GetIsBlockAirModeActive(editor);
    auto cursor = editor.Cursor;
    auto varIx = Editor::GetCurrentBlockVariant(cursor);
    CGameCtnBlockInfoVariant@ var;
    @var = Editor::GetBlockInfoVariant(bi, varIx, !isAir);
    if (var is null) return;
    BlockClips@[] clips;

    auto pos = Editor::GetCursorPos(editor);
    auto rot = CustomCursorRotations::GetEditorCursorRotations(cursor);
    auto mat = rot.GetMatrix(pos);

    for (uint i = 0; i < var.BlockUnitInfos.Length; i++) {
        auto bui = var.BlockUnitInfos[i];
        clips.InsertLast(BlockClips(bui));
        clips[clips.Length - 1].Draw(mat, true);
    }

    if (S_DrawFreeBlockClipsOnNearbyBlocks) {
        auto size = CoordDistToPos(var.Size);
        DrawFreeBlockClipsForInMapBlocksNear(pos + size * .5, size.Length() * 2.0);
    }
}

void DrawFreeBlockClipsForInMapBlocksNear(vec3 pos, float blockRadius) {
    auto cache = Editor::GetMapCache();
    // auto mb = Editor::GetMapAsMacroblock();
    auto objs = cache.objsRoot.FindPointsWithin(pos, blockRadius);
    for (uint i = 0; i < objs.Length; i++) {
        auto blk = objs[i].block;
        if (blk is null) continue;
        if (!blk.isFree) continue;
        auto bi = blk.BlockInfo;
        auto varIx = (blk.isGround || blk.variant == 0) ? blk.variant : (blk.variant - bi.AdditionalVariantsGround.Length - 1);
        auto var = Editor::GetBlockInfoVariant(bi, varIx, blk.isGround);
        if (var is null) continue;
        auto pos = blk.pos -  vec3(0, 56, 0);
        auto rot = EditorRotation(blk.pyr);
        auto mat = rot.GetMatrix(pos);
        for (uint j = 0; j < var.BlockUnitInfos.Length; j++) {
            auto bui = var.BlockUnitInfos[j];
            BlockClips(bui).Draw(mat);
        }
    }

}


class BlockClips {
    CGameCtnBlockUnitInfo@ bui;
    bool isCursorBlock = false;

    BlockClips(CGameCtnBlockUnitInfo@ bui, bool isCursorBlock = false) {
        this.isCursorBlock = isCursorBlock;
        @this.bui = bui;
        bui.MwAddRef();
    }
    ~BlockClips() {
        bui.MwRelease();
    }

    void Draw(const mat4 &in cursorMat, bool drawSnapRadius = false) {
        auto _cursorPos = (cursorMat * vec3()).xyz;
        auto uv = Camera::ToScreen(_cursorPos);
        if (uv.z > 0) return;
        // trace("drawing at " + _cursorPos.ToString());
        nvg::Reset();
        auto offsetPos = CoordDistToPos(bui.RelativeOffset)
            + CoordDistToPos(vec3(.5));
        auto mat = cursorMat * mat4::Translate(offsetPos);
        auto clipPlaces = Editor::GetBlockUnitClips(bui);
        // ResetColors();
        uint[] seekingClipIds;
        uint[] hasClipIds;
        vec4[] seekingColors;
        vec4[] hasColors;
        for (uint i = 0; i < bui.AllClips.Length; i++) {
            auto clip = bui.AllClips[i];
            bool isDone;
            auto clipPlace = FindNonzeroEntryAndDecrement(clipPlaces, isDone);
            if (int(clip.ClipType) == 0) continue;
            auto faceOffset = GetClipPlaceOffset(clipPlace);
            GetSeekingClipIds(clip, seekingClipIds);
            GetHasClipIds(clip, hasClipIds);
            GetColorsFor(seekingClipIds, seekingColors);
            GetColorsFor(hasClipIds, hasColors);

            if (!isDone) continue;

            int nbToDraw = Math::Max(seekingClipIds.Length, hasClipIds.Length);
            auto faceSideDir = GetDrawAxisBaseForClipPlace(clipPlace);
            auto perpFaceDir = GetDrawAxisPerpendicularBaseForClipPlace(clipPlace);
            // auto faceNorm = Math::Cross(faceSideDir, perpFaceDir);

            // draw hit radius for snapping
            if (drawSnapRadius && S_DrawAnySnapRadiusOnHelpers) {
                // DrawSnapPlug(mat * mat4::Translate(faceOffset), CustomCursor::GetCurrentSnapRadius(), vec4(1, 1, 1, 0.5), faceSideDir, perpFaceDir, 24, false);
                DrawSnapPlug(mat * mat4::Translate(faceOffset) * mat4::Rotate(HALF_PI, faceSideDir), CustomCursor::GetCurrentSnapRadius(), vec4(1, 1, 1, 0.5), faceSideDir, perpFaceDir, 24, false);
            }

            // draw the plug shapes
            auto incrPos = faceSideDir * (16. / (nbToDraw + 1));
            auto pos = faceSideDir * -8. + incrPos;
            for (int j = 0; j < nbToDraw; j++) {
                auto drawMat = mat * mat4::Translate(faceOffset + pos);
                if (j < int(seekingClipIds.Length)) {
                    DrawSeeking(drawMat, 2.0, seekingColors[j], faceSideDir, perpFaceDir);
                }
                if (j < int(hasClipIds.Length)) {
                    DrawHasPlugs(drawMat, 1.0, hasColors[j], faceSideDir, perpFaceDir);
                }
                pos += incrPos;
            }
            seekingClipIds.RemoveRange(0, seekingClipIds.Length);
            hasClipIds.RemoveRange(0, hasClipIds.Length);
            seekingColors.RemoveRange(0, seekingColors.Length);
            hasColors.RemoveRange(0, hasColors.Length);
        }
    }

    void DrawSeeking(const mat4 &in mat, float radius, const vec4 &in color, const vec3 &in alongFaceDir, const vec3 &in perpAlongFaceDir) {
        DrawSnapPlug(mat, radius, color, alongFaceDir, perpAlongFaceDir, 6);
    }

    void DrawHasPlugs(const mat4 &in mat, float radius, const vec4 &in color, const vec3 &in alongFaceDir, const vec3 &in perpAlongFaceDir) {
        DrawSnapPlug(mat, radius, color, alongFaceDir, perpAlongFaceDir, 15, true);
    }

    void DrawSnapPlug(const mat4 &in mat, float radius, const vec4 &in color, const vec3 &in alongFaceDir, const vec3 &in perpAlongFaceDir, uint nbPoints, bool fill = false) {
        nvg::BeginPath();
        nvg::StrokeWidth(4.0);
        auto increment = TAU / float(nbPoints);
        vec2 firstUv;
        for (uint i = 0; i < nbPoints; i++) {
            auto angle = increment * i;
            auto x = Math::Cos(angle) * radius;
            auto y = Math::Sin(angle) * radius;
            auto pos = (mat * (alongFaceDir * x + perpAlongFaceDir * y)).xyz;
            auto uv = Camera::ToScreen(pos);
            if (i == 0) {
                firstUv = uv.xy;
                nvg::MoveTo(uv.xy);
            } else {
                nvg::LineTo(uv.xy);
            }
        }
        nvg::LineTo(firstUv);
        if (fill) {
            nvg::FillColor(color);
            nvg::Fill();
        } else {
            nvg::StrokeColor(color);
            nvg::Stroke();
        }
        nvg::ClosePath();
    }

    // clip MwIds to map to color
    uint[] mwIds;
    vec4[] colors;

    void ResetColors() {
        mwIds.RemoveRange(0, mwIds.Length);
    }

    vec4 GetColorFor(uint mwId, int ix = -1) {
        if (ix == -1) ix = mwIds.Find(mwId);
        if (ix == -1) {
            ix = mwIds.Length;
            mwIds.InsertLast(mwId);
            while (int(colors.Length) <= ix) AddNextColor();
        }
        return colors[ix];
    }

    vec4[]@ GetColorsFor(uint[]@ mwIds, vec4[]@ outColors = {}) {
        for (uint i = 0; i < mwIds.Length; i++) {
            outColors.InsertLast(GetColorFor(mwIds[i]));
        }
        return outColors;
    }

    void AddNextColor() {
        auto n = float(colors.Length);
        if (n < 3.) {
            colors.InsertLast(UI::HSV(n * 0.3333, .85, .75));
        } else if (n < 9.) {
            colors.InsertLast(UI::HSV((n - 2.) * 0.142857, .85, .75));
        } else {
            colors.InsertLast(vec4(RandVec3Norm(), 1.));
        }
    }
}

uint[]@ GetSeekingClipIds(CGameCtnBlockInfoClip@ clip, uint[]@ ids = {}) {
    if (clip.ClipType != CGameCtnBlockInfoClip::EnumClipType::ClassicClip
        // && clip.TopBottomMultiDir == CGameCtnBlockInfoClip::EMultiDirEnum::SymmetricalDirs
    ) {
        if (clip.SymmetricalClipId.Value < uint(-1))
            ids.InsertLast(clip.SymmetricalClipId.Value);
        if (clip.SymmetricalBlockInfoId.Value < uint(-1))
            ids.InsertLast(clip.SymmetricalBlockInfoId.Value);
        if (clip.SymmetricalClipGroupId.Value < uint(-1))
            ids.InsertLast(clip.SymmetricalClipGroupId.Value);
        if (clip.SymmetricalClipGroupId2.Value < uint(-1))
            ids.InsertLast(clip.SymmetricalClipGroupId2.Value);
        if (clip.ClipGroupId.Value < uint(-1) && ids.Find(clip.ClipGroupId.Value) == -1)
            ids.InsertLast(clip.ClipGroupId.Value);
    }
    return ids;
}

uint[]@ GetHasClipIds(CGameCtnBlockInfoClip@ clip, uint[]@ ids = {}) {
    if (clip.ClipType != CGameCtnBlockInfoClip::EnumClipType::ClassicClip
        // && clip.TopBottomMultiDir == CGameCtnBlockInfoClip::EMultiDirEnum::SymmetricalDirs
    ) {
        if (clip.Id.Value < uint(-1))
            ids.InsertLast(clip.Id.Value);
        if (clip.ClipGroupId.Value < uint(-1))
            ids.InsertLast(clip.ClipGroupId.Value);
        if (clip.ClipGroupId2.Value < uint(-1))
            ids.InsertLast(clip.ClipGroupId2.Value);
    }
    return ids;
}

const float HOffsetClipPlace = 0.0;

vec3 GetClipPlaceOffset(uint clipPlace) {
    switch (clipPlace) {
        // North
        case 0: return CoordDistToPos(vec3(0., HOffsetClipPlace, .5));
        // East
        case 1: return CoordDistToPos(vec3(-.5, HOffsetClipPlace, 0.));
        // South
        case 2: return CoordDistToPos(vec3(0., HOffsetClipPlace, -.5));
        // West
        case 3: return CoordDistToPos(vec3(.5,  HOffsetClipPlace, 0.));
        // Top
        case 4: return CoordDistToPos(vec3(0., .5, 0.));
        // Bottom
        case 5: return CoordDistToPos(vec3(0., -.5, 0.));
    }
    return CoordDistToPos(vec3(-1.));
}

// When we draw shapes for the clip, we want to be able to go left and right along the face. This function returns a Right direction.
vec3 GetDrawAxisBaseForClipPlace(uint clipPlace) {
    switch (clipPlace) {
        // North
        case 0: return (vec3(1, 0, 0));
        // East
        case 1: return (vec3(0, 0, 1));
        // South
        case 2: return (vec3(-1, 0, 0));
        // West
        case 3: return (vec3(0, 0, -1));
        // Top
        case 4: return (vec3(0, 0, 1));
        // Bottom
        case 5: return (vec3(0, 0, -1));
    }
    return vec3(-1);
}

vec3 GetDrawAxisPerpendicularBaseForClipPlace(uint clipPlace) {
    switch (clipPlace) {
        // North
        case 0: return (vec3(0, 1, 0));
        // East
        case 1: return (vec3(0, 1, 0));
        // South
        case 2: return (vec3(0, 1, 0));
        // West
        case 3: return (vec3(0, 1, 0));
        // Top
        case 4: return (vec3(1, 0, 0));
        // Bottom
        case 5: return (vec3(1, 0, 0));
    }
    return vec3(-1);
}

uint FindNonzeroEntryAndDecrement(uint8[]@ arr, bool &out isDone) {
    for (uint i = 0; i < arr.Length; i++) {
        if (arr[i] > 0) {
            arr[i]--;
            isDone = arr[i] == 0;
            return i;
        }
    }
    isDone = true;
    return uint(-1);
}


class CursorFavTab : Tab {
    CursorTab@ cursorTab;

    CursorFavTab(TabGroup@ parent, CursorTab@ ct) {
        super(parent, "Favorites", "");
        @cursorTab = ct;
    }

    void SaveFavorite(CGameCursorBlock@ cursor) {

    }
}


class CustomCursorTab : EffectTab {

    CustomCursorTab(TabGroup@ parent) {
        super(parent, "Custom Cursor", Icons::HandPointerO + Icons::ExclamationTriangle);
    }

    bool get__IsActive() override property {
        return CustomCursorRotations::Active
            || CustomCursorRotations::ItemSnappingEnabled
            || CustomCursorRotations::CustomYawActive
            || CustomCursorRotations::IsPromiscuousItemSnappingEnabled;
    }

    void DrawInner() override {
        CustomCursorRotations::ItemSnappingEnabled = UI::Checkbox("Item-to-Block Snapping Enabled (Default: On)", CustomCursorRotations::ItemSnappingEnabled);
        AddSimpleTooltip("Use this to disable default game item-to-block snapping (mostly). Normal game behavior is when this is *true*.");

        CustomCursor::AllowFreeWaterBlocksPatchActive = UI::Checkbox("Allow Placing Rotated Free Water Blocks" + NewIndicator, CustomCursor::AllowFreeWaterBlocksPatchActive);
        AddSimpleTooltip("Allows placing water blocks with pitch and roll in free block and free macroblock mode.");
        UI::SameLine();
        S_AutoApplyFreeWaterBlocksPatch = UI::Checkbox("Auto-apply##fwbp", S_AutoApplyFreeWaterBlocksPatch);

        DrawFreeBlockSnapRadiusSettings();

        bool wasActive = CustomCursorRotations::Active;
        auto nextActive = UI::Checkbox("Enable Custom Cursor Rotation Amounts", wasActive);
        if (wasActive != nextActive) CustomCursorRotations::Active = nextActive;
        AddSimpleTooltip("Only works for Pitch and Roll");

        wasActive = CustomCursorRotations::CustomYawActive;
        nextActive = UI::Checkbox("Enable Custom Yaw" + BetaIndicator, wasActive);
        if (wasActive != nextActive) CustomCursorRotations::CustomYawActive = nextActive;
        AddSimpleTooltip("Note: this currently does not work correctly with item-to-block snapping.");

        CustomCursorRotations::DrawSettings();

        // S_AutoActivateCustomRotations is checked in OnEditor for cursor window
        S_AutoActivateCustomRotations = UI::Checkbox("Auto-activate custom cursor rotations (Pitch, Roll)", S_AutoActivateCustomRotations);
        AddSimpleTooltip("Activates when entering the editor");
        S_AutoActivateCustomYaw = UI::Checkbox("Auto-activate custom cursor rotations (Yaw)", S_AutoActivateCustomYaw);
        AddSimpleTooltip("Activates when entering the editor");

        DrawInfinitePrecisionSetting();

        wasActive = S_EnablePromiscuousItemSnapping;
        S_EnablePromiscuousItemSnapping = UI::Checkbox("Enable Promiscuous Item Snapping", S_EnablePromiscuousItemSnapping);
        AddSimpleTooltip("Items that snap to blocks will be less picky about which blocks they snap to. Example: trees will now snap to all terrain.\n\nNOTE: If you toggle this, it will only take effect for newly placed blocks, or when you reload the map.");
        if (wasActive != S_EnablePromiscuousItemSnapping) {
            CustomCursorRotations::PromiscuousItemToBlockSnapping.IsApplied = S_EnablePromiscuousItemSnapping;
        }
    }

    void DrawFreeBlockSnapRadiusSettings() {
        float currSnapRadius = CustomCursor::GetCurrentSnapRadius();
        UI::SetNextItemWidth(60.);
        UI::InputText("##fb-snap-r", Text::Format("%.2f", currSnapRadius), int(UI::InputTextFlags::ReadOnly));
        float btnWidth = UI::GetFrameHeight() * 1.5;
        UI::SameLine();
        bool decr_radius = UI::Button(Icons::Minus + "##fb-snap-r", vec2(btnWidth, 0)); //  || UI::IsItemClicked()
        UI::SameLine();
        bool incr_radius = UI::Button(Icons::Plus + "##fb-snap-r", vec2(btnWidth, 0)); //  || UI::IsItemClicked()
        UI::SameLine();
        bool incr_radius_lots = UI::Button(Icons::FastForward + "##fb-snap-r", vec2(btnWidth, 0)); //  || UI::IsItemClicked()
        UI::SameLine();
        bool reset_radius = UI::Button(Icons::Refresh + "##fb-snap-rst", vec2(btnWidth, 0)); //  || UI::IsItemClicked()
        UI::SameLine();
        UI::Text("Free Block Snap Radius" + NewIndicator);
        if (decr_radius) {
            CustomCursor::StepFreeBlockSnapRadius(false);
        } else if (incr_radius) {
            CustomCursor::StepFreeBlockSnapRadius(true);
        } else if (incr_radius_lots) {
            float newRadiusMin = CustomCursor::GetCurrentSnapRadius() + 1.;
            while (newRadiusMin > CustomCursor::GetCurrentSnapRadius()) {
                CustomCursor::StepFreeBlockSnapRadius(true);
            }
        } else if (reset_radius) {
            CustomCursor::ResetSnapRadius();
        }

        UI::Indent();
        S_DrawFreeBlockClips = UI::Checkbox("Draw Block Clip Helpers" + NewIndicator, S_DrawFreeBlockClips);
        S_DrawAnySnapRadiusOnHelpers = UI::Checkbox("Draw Snap Radius on Helpers" + NewIndicator, S_DrawAnySnapRadiusOnHelpers);
        S_DrawFreeBlockClipsOnNearbyBlocks = UI::Checkbox("Draw Block Clip Helpers on Nearby Blocks" + NewIndicator, S_DrawFreeBlockClipsOnNearbyBlocks);
        UI::Unindent();
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
        cursor.FreePosInMap = UX::InputFloat3("Free Pos", cursor.FreePosInMap, vec3(784, 84, 784));
        // CopiableLabeledValue("Pos", cursor.FreePosInMap.ToString());

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
    }
}

void ResetCursor(CGameCursorBlock@ cursor) {
    cursor.Pitch = 0;
    cursor.Roll = 0;
    cursor.AdditionalDir = CGameCursorBlock::EAdditionalDirEnum::P0deg;
    cursor.Dir = CGameCursorBlock::ECardinalDirEnum::North;
    CustomCursorRotations::cursorCustomPYR = vec3();
}

[Setting hidden]
bool S_AutoApplyFreeWaterBlocksPatch = true;

[Setting hidden]
bool S_EnablePromiscuousItemSnapping = true;

namespace CustomCursorRotations {
    [Setting hidden]
    float customRot = TAU / 4. / 12.;

    // check this when overwriting SnappedLoc to avoid overwriting in-game snapping
    bool HasCustomCursorSnappedPos = false;

    // yaw tracks extra direction only (between 0 and 90deg), but pitch and roll are full rotations
    vec3 cursorCustomPYR = vec3();

    void DrawSettings() {
        UI::PushItemWidth(120.);
        if (customRot <= 0.0005) customRot = 0.0005;
        int origParts = int(Math::Round(TAU / 4. / customRot));
        int newParts = Math::Clamp(UI::InputInt("Taps per 90 degrees", origParts), 2, 360);
        if (origParts != newParts) customRot = TAU / 4. / float(newParts);
        float crDeg = Math::ToDeg(customRot);
        float crNewDec = UI::InputFloat("Rotation (Deg)", crDeg);
        if (crNewDec != crDeg) customRot = Math::ToRad(crNewDec);
        UI::PopItemWidth();
    }

    void SetCustomCursorRot(float _customRot) {
        customRot = _customRot;
    }

    float GetCustomCursorRot() {
        return customRot;
    }

    // Compatible with custom yaw
    EditorRotation@ GetEditorCursorRotations(CGameCursorBlock@ cursor) {
        auto rot = EditorRotation(cursor);
        if (Active) {
            rot.Pitch = cursorCustomPYR.x;
            rot.Roll = cursorCustomPYR.z;
        }
        if (CustomYawActive) {
            rot.Yaw = rot.YawWithCustomExtra(cursorCustomPYR.y);
        }
        return rot;
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
            return AfterSetCursorRotationHook.IsApplied();
        }
        set {
            AfterSetCursorRotationHook.SetApplied(value);
        }
    }

    bool ItemSnappingEnabled {
        get {
            return !DisableItemSnapping.IsApplied;
        }
        set {
            DisableItemSnapping.IsApplied = !value;
        }
    }

    bool IsPromiscuousItemSnappingEnabled {
        get {
            return PromiscuousItemToBlockSnapping.IsApplied;
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
    // hooks before and on call to CGameCursorBlock::UpdateCursor (0x228)
    MultiHookHelper@ BeforeAfterCursorUpdateHook = MultiHookHelper(
     // after only: "FF 90 28 02 00 00 83 7D F4 00 74 23 48 8B 4F 68 BA 41 00 00 00 4C 8B 01 41 FF 90 08 01 00 00 85 C0",
     // "48 8D 55 00 48 8B CF FF 90 28 02 00 00 83 7D F4 00 74 23 48 8B 4F 68 BA 41 00 00 00 4C 8B 01 41 FF 90 08 01 00 00 85 C0",
     // "48 8D 55 E0 48 8B CF FF 90 28 02 00 00 83 7D D4 00 74 23"
        "48 8D 55 ?? 48 8B CF FF 90 ?? 02 00 00 83 7D ?? 00 74 23", // 48 8B 4F ?? BA ?? 00 00 00 4C 8B 01 41 FF 90 ?? ?? 00 00 85 C0",
        {0, 7}, {2, 1}, {"CustomCursorRotations::BeforeCursorUpdate", "CustomCursorRotations::AfterCursorUpdate"}
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
    // 48 8B 80 30 02 00 00 -- load 0x230 from CGameCtnBlockInfo into rax (MatModifierPlacementTag)
    // patch to xor rax,rax; dec rax; nop
    MemPatcher@ PromiscuousItemToBlockSnapping = MemPatcher(
        // "48 8b 80 ?? ?? 00 00 0f 28 85 ?? ?? 00 00 48 8d 14 ba f2 0f 11 8d ?? ?? 00 00 0f 28 8d ?? ?? 00 00",
        "48 8b 80 ?? 02 00 00 0f 28 85 ?? ?? 00 00 48 8d 14 ba",
        {0}, {"48 31 C0 48 FF C8 90"} /* expected , {"48 8B 80 38 02 00 00"} */
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

    void BeforeCursorUpdate() {
        Event::OnBeforeCursorUpdate();
    }

    // overwrite cursor properties here if we want, after the whole cursor has been updated
    void AfterCursorUpdate() {
        Event::OnAfterCursorUpdate();
    }

    void CustomYaw_AfterCursorUpdate() {
        if (!CustomYawActive) return;

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        auto cursor = editor.Cursor;
        if (cursor is null) return;

        // make sure we're in a good mode, any item takes precedence over any free mode
        if (Editor::IsInAnyItemPlacementMode(editor)) {
            auto @itemCursor = DGameCursorItem(editor.ItemCursor);
            auto cursorRot = EditorRotation(cursor);
            auto pyr = cursorCustomPYR;
            pyr.y = cursorRot.YawWithCustomExtra(pyr.y);
            auto newRot = EulerToMat(pyr);
            bool isSnapping = itemCursor.snappedGlobalIx != uint(-1);
            bool autoRotating = !isSnapping && itemCursor.isAutoRotate;
            if (!autoRotating) {
                auto pos = itemCursor.pos;
                // todo, this is weird with snapping items and seems to rotate things in the wrong direction (but correct axis)
                // pyr.y =
                itemCursor.mat = iso4(mat4::Inverse(newRot));
                // part of the mat, need to update after
                itemCursor.pos = pos;
            } else {
                // todo
                auto pos = itemCursor.pos;
                auto itemMat = itemCursor.mat;
                auto translate = mat4::Translate(pos);
                auto rotation = mat4::Inverse(translate) * itemMat;
                auto origRotation = EulerToMat(cursorRot.Euler);
                // auto invOrigRot = origRotation;
                auto extraRot = (origRotation) * rotation;
                auto newFinalRot = mat4::Inverse(newRot) * extraRot;
                // test -- scale works for preview but not for item (as expected)
                // newFinalRot *= mat4::Scale(2.0);
                // auto origYaw = cursorRot.Yaw;
                // auto newYaw = cursorRot.YawWithCustomExtra(pyr.y);
                itemCursor.mat = iso4(newFinalRot);
                itemCursor.pos = pos;
            }
        }
        // but we also want to set snapped location b/c that's used later on
        if (Editor::IsInCustomRotPlacementMode(editor)) {
            // this is false in item mode: if (!cursor.UseFreePos) return;

            HasCustomCursorSnappedPos = !cursor.UseSnappedLoc;
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
            // dev_trace("After Cursor Update: " + cursor.UseSnappedLoc);
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
    // we use this to keep the cursor in sync and read the new direction
    void AfterSetCursorRotation_Rdi_7C(uint64 rbx, uint64 rdi) {
        // dev_trace('editor pointer: ' + Text::FormatPointer(rbx));
        // dev_trace('rdi: ' + Text::FormatPointer(rdi));
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
        // dev_trace("lastDir: " + lastDir + ", nextDir: " + nextDir);
        // dev_trace("lastAddDir: " + lastAddDir + ", nextAddDir: " + nextAddDir);
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
        // dev_trace("lastUseSnapPos: " + lastUseSnapPos);
        int nextUseSnapPos = Dev::ReadInt32(rdi + 0xBC);
        // dev_trace("nextUseSnapPos: " + nextUseSnapPos);
        Dev::Write(rdi + 0xBC, 0); // force no use snaped loc (we set it later if needed)

        // do nothing if rotation wasn't changed.
        if (!dirChanged && !addDirChanged) {
            return;
        }

        bool rmbPressed = Dev::ReadUInt8(rbx + O_EDITOR_RMB_PRESSED1) != 0;
        // dev_trace("rmbPressed: " + rmbPressed);
        // if (dirChanged) {
        //     dev_trace("Direction changed: " + lastDir + " -> " + nextDir);
        // }
        // if (addDirChanged) {
        //     dev_trace("Additional direction changed: " + lastAddDir + " -> " + nextAddDir);
        // }

        if (rmbPressed) {
            bool yawWasNonzero = cursorCustomPYR.y != 0.0;
            // dev_trace("RMB pressed, resetting custom yaw. yaw was nonZero: " + yawWasNonzero);
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
        // dev_trace("dirIncr: " + dirDecr + ", dirDecr: " + dirIncr);
        // dev_trace("addDirIncr: " + addDirIncr + ", addDirDecr: " + addDirDecr);

        // reset direction change because we adjust it later if needed
        cursor.Dir = CGameCursorBlock::ECardinalDirEnum(lastDir);

        // dev_trace("1. Custom Yaw: " + cursorCustomPYR.y + " (Dir: " + cursor.Dir + ")");
        if (addDirIncr) {
            cursorCustomPYR.y += customRot;

        } else if (addDirDecr) {
            cursorCustomPYR.y -= customRot;
        }
        // dev_trace("2. Custom Yaw: " + cursorCustomPYR.y + " (Dir: " + cursor.Dir + ")");
        NormalizeCustomYaw(cursor, lastDir);
        // dev_trace("3. Custom Yaw: " + cursorCustomPYR.y + " (Dir: " + cursor.Dir + ")");
        cursor.AdditionalDir = YawToAdditionalDir(cursorCustomPYR.y);
        // dev_trace("UseSnappedLoc: " + nextUseSnapPos + " (return early if true)");
        if (nextUseSnapPos > 0) return;
    }

    void SetCustomPYRAndCursor(vec3 pyr, CGameCursorBlock@ cursor) {
        cursorCustomPYR = pyr;
        auto rots = EditorRotation(cursorCustomPYR);
        cursor.Pitch = rots.Pitch;
        cursor.Roll = rots.Roll;
        cursor.Dir = CGameCursorBlock::ECardinalDirEnum(rots.Dir);
        cursorCustomPYR.y = rots.additionalYaw;
        cursor.AdditionalDir = rots.AdditionalDir;
        if (true || cursor.UseSnappedLoc) {
            cursor.SnappedLocInMap_Pitch = cursorCustomPYR.x;
            cursor.SnappedLocInMap_Roll = cursorCustomPYR.z;
            cursor.SnappedLocInMap_Yaw = rots.YawWithCustomExtra(cursorCustomPYR.y);
        }
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
        // dev_trace("Updated Cached Cursor PYR: " + cursorCustomPYR.ToString());
    }


    // offset may change, in which case pattern will not match (pattern in NewPlacementHooks.as)
    // don't think we need this hook anymore
    void OnGetCursorRotation_Rbp70(uint64 rbp) {
        // dev_trace("OnGetCursorRotation! rbp: " + Text::FormatPointer(rbp));
        // quat at rbp + 0x70
        auto addr = rbp + 0x70;
        vec4 vq = Dev::ReadVec4(addr);
        quat q = quat(vq.x, vq.y, vq.z, vq.w);
        // dev_trace("q: " + q.ToString());
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
        if (!CustomYawActive) return false;
        // todo: custom yaw
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto cursor = editor.Cursor;
        auto itemCursor = DGameCursorItem(editor.ItemCursor);
        bool autoRotating = itemCursor.snappedGlobalIx == uint(-1) && itemCursor.isAutoRotate;
        if (!autoRotating && Editor::IsInAnyItemPlacementMode(editor)) {
            item.Yaw += cursorCustomPYR.y - AdditionalDirToYaw(cursor.AdditionalDir);
        } else {
            // we must be in macroblock mode, or autorotate (probably)
            // so do nothing
        }
        return false;
    }
}

namespace CustomCursor {
    MemPatcher@ Patch_AllowFreeWaterBlocks = MemPatcher(
      // v cmp water len   v jbe             v mov
        "39 87 ?? ?? 00 00 0F 86 ?? ?? 00 00 48 8B 4C 24 30",
        {6}, {"90 E9"},  {"0F 86"} // patch jbe -> jmp
    );

    MemPatcher@ Patch_AllowFreeWaterMacroBlocks = MemPatcher(
        // v cmp           v jbe             v start of movss
        "39 83 ?? ?? 00 00 0F 86 ?? 00 00 00 F3",
        {6}, {"90 E9"},  {"0F 86"} // patch jbe -> jmp
    );

    bool AllowFreeWaterBlocksPatchActive {
        get {
            return Patch_AllowFreeWaterBlocks.IsApplied
                && Patch_AllowFreeWaterMacroBlocks.IsApplied;
        }
        set {
            Patch_AllowFreeWaterBlocks.IsApplied = value;
            Patch_AllowFreeWaterMacroBlocks.IsApplied = value;
        }
    }

    MemPatcher@ Patch_DoNotSetCursorVisibleFlag = MemPatcher(
        // [rdx] to xmm0 to [rcx+1f8], then next 16 bytes
        // v      v                    v           v
        "0F 10 02 0F 11 81 F8 01 00 00 0F 10 4A 10 0F 11 89 08 02 00 00",
        {3}, {"90 90 90 90 90 90 90"}
    );

    bool NoSetCursorVisFlagPatchActive {
        get {
            return Patch_DoNotSetCursorVisibleFlag.IsApplied;
        }
        set {
            Patch_DoNotSetCursorVisibleFlag.IsApplied = value;
        }
    }

    // warning: if used when changing out of test mode, the vehicle will stick around and leaving the editor will crash the game.
    MemPatcher@ Patch_DoNotHideCursorItemModels = MemPatcher(
        //                                   v call function that hides cursor item models
        "90 83 3B FF 74 0B 48 8B D3 48 8B CE E8",
        {12}, {"90 90 90 90 90"}
    );

    bool NoHideCursorItemModelsPatchActive {
        get {
            return Patch_DoNotHideCursorItemModels.IsApplied;
        }
        set {
            Patch_DoNotHideCursorItemModels.IsApplied = value;
        }
    }

    const string fbSnapRadiusPattern =
        // v loads block x,y size to later be multiplied    v mulss xmm11 by (.25 by default)
        "F3 45 0F 10 04 24 8B 4B 20 45 0F 28 D8 48 8B 43 18 F3 44 0F 59 1D"; // " ?? ?? ?? ??"
        //                 ^ mov    ^movaps     ^ mov
        // offset: 22

    uint64 _fbSnapRadiusAddr = 0;

    uint64 GetSnapRadiusCodeAddr() {
        if (_fbSnapRadiusAddr == 0) _fbSnapRadiusAddr = Dev::FindPattern(fbSnapRadiusPattern);
        if (_fbSnapRadiusAddr == 0) {
            throw("Failed to find snap radius pattern");
        }
        return _fbSnapRadiusAddr + 22;
    }

    void ResetSnapRadius() {
        if (_fbSnapRadiusAddr == 0) return;
        auto ptr = GetSnapRadiusCodeAddr();
        if (origSnapRadiusBytes.Length > 0 && origSnapRadiusBytes != Dev::Read(ptr, 4)) {
            Dev::Patch(ptr, origSnapRadiusBytes);
        }
    }

    string origSnapRadiusBytes;

    float GetCurrentSnapRadius() {
        auto multPtr = GetSnapRadiusCodeAddr();
        auto offset = Dev::ReadInt32(multPtr);
        if (origSnapRadiusBytes.Length == 0) {
            origSnapRadiusBytes = Dev::Read(multPtr, 4);
        }
        auto floatPtr = multPtr + 4 + offset;
        auto mult = Dev::ReadFloat(floatPtr);
        return 32. * mult;
    }

    uint64 GetFloatPtr() {
        auto multPtr = GetSnapRadiusCodeAddr();
        dev_trace("Current mult ptr: " + Text::FormatPointer(multPtr));
        auto offset = Dev::ReadInt32(multPtr);
        dev_trace("Current offset: " + offset);
        return multPtr + 4 + offset;
    }

    void StepFreeBlockSnapRadius(bool increment) {
        dev_trace("Stepping free block snap radius");
        int step = increment ? 4 : -4;
        auto floatPtr = GetFloatPtr();
        dev_trace("Current float ptr: " + Text::FormatPointer(floatPtr));
        float mult = Dev::ReadFloat(floatPtr);
        dev_trace("Current mult: " + mult);
        // don't go outside these bounds
        if (mult >= 100. && increment) return;
        if (mult <= 0.01 && !increment) return;
        float origMult = mult;
        int offsetDelta = 0;
        dev_trace("Scanning for new mult...");
        if (increment) {
            while ((mult = Dev::ReadFloat(floatPtr)) < 0.00001 || (mult <= origMult && mult <= 100.0) || mult > 9999.0) {
                // keep going
                floatPtr += step;
                offsetDelta += step;
            }
        } else {
            while ((mult = Dev::ReadFloat(floatPtr)) < 0.00001 || (mult >= origMult && mult >= 0.01) || mult > 9999.0) {
                // keep going
                floatPtr += step;
                offsetDelta += step;
            }
        }
        dev_trace("Found new mult: " + mult);
        if (mult < 0.01 || mult > 100.0) {
            throw("mult got outside range! " + mult);
            return;
        }
        if (Math::Abs(offsetDelta) > 0x1000) {
            throw("moving too much, are there even floats there?");
        }
        auto multPtr = GetSnapRadiusCodeAddr();
        auto offset = Dev::ReadInt32(multPtr);
        dev_trace("Current offset: " + offset);
        dev_trace("Offset delta: " + offsetDelta);
        Dev::Patch(multPtr, UintToBytes(offset + offsetDelta));
        // Dev::Write(multPtr, offset + offsetDelta);
        dev_trace("Updated float offset by " + offsetDelta + ". Getting radius...");
        dev_trace("Snap radius: " + GetCurrentSnapRadius());
    }
}
