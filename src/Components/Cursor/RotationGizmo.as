RotationTranslationGizmo@ testGizmo;

array<vec3>@[] axisDragArrows = {
    {vec3(.3, 0, 0), vec3(1, 0, 0), vec3(0.9, 0, 0.1), vec3(0.9, 0, -0.1), vec3(1, 0, 0), vec3(0.9, 0.1, 0), vec3(0.9, -0.1, 0), vec3(1, 0, 0)},
    {vec3(0, .3, 0), vec3(0, 1, 0), vec3(0.1, 0.9, 0), vec3(-0.1, 0.9, 0), vec3(0, 1, 0), vec3(0, 0.9, 0.1), vec3(0, 0.9, -0.1), vec3(0, 1, 0)},
    {vec3(0, 0, .3), vec3(0, 0, 1), vec3(0.1, 0, 0.9), vec3(-0.1, 0, 0.9), vec3(0, 0, 1), vec3(0, 0.1, 0.9), vec3(0, -0.1, 0.9), vec3(0, 0, 1)}
};

const int ARROW_SEGS = 14;
const int CIRCLE_SEGMENTS = 256; // 64;
vec3[] circleAroundY;
vec3[] circleAroundX;
vec3[] circleAroundZ;
array<vec3>@[] circlesAroundXYZ;
array<bool>[] circlesAroundIsNearSide;

void InitCirclesAround() {
    circleAroundY.Resize(CIRCLE_SEGMENTS);
    circleAroundX.Resize(CIRCLE_SEGMENTS);
    circleAroundZ.Resize(CIRCLE_SEGMENTS);
    float dtheta = TAU / CIRCLE_SEGMENTS;
    float theta = 0.;
    for (int i = 0; i < CIRCLE_SEGMENTS; i++) {
        circleAroundY[i] = vec3(Math::Cos(theta), 0, Math::Sin(theta));
        circleAroundX[i] = vec3(0, Math::Cos(theta), Math::Sin(theta));
        circleAroundZ[i] = vec3(Math::Cos(theta), Math::Sin(theta), 0);
        theta += dtheta;
    }
    circlesAroundXYZ.RemoveRange(0, circlesAroundXYZ.Length);
    circlesAroundXYZ.InsertLast(circleAroundX);
    circlesAroundXYZ.InsertLast(circleAroundY);
    circlesAroundXYZ.InsertLast(circleAroundZ);
    //--
    circlesAroundIsNearSide.RemoveRange(0, circlesAroundIsNearSide.Length);
    for (int i = 0; i < 3; i++) {
        circlesAroundIsNearSide.InsertLast(array<bool>(CIRCLE_SEGMENTS));
    }
    //--
    if (axisDragArrows[0].Length < 10) {
        for (int i = 0; i < 3; i++) {
            auto snd = axisDragArrows[i][1];
            for (float x = 0.9; x > 0.31; x -= 0.1) {
                axisDragArrows[i].InsertLast(snd * x);
            }
        }
    }
}

vec4[] circleColors = {
    vec4(1, 0, 0, 1),
    vec4(0, 1, 0, 1),
    vec4(0, 0, 1, 1)
};

const quat DEFAULT_QUAT = quat(0,0,0,1);

[Setting hidden]
float S_GizmoClickSensitivity = 400.;

class RotationTranslationGizmo {
    // drawing gizmo
    // click detection
    // drag detection
    // reading values out
    // updating cursor
    // clicking update

    // quat rot = quat(0,0,0,1);
    vec3 pos;
    vec3 tmpPos;
    mat4 rot = mat4::Identity();
    mat4 tmpRot = mat4::Identity();
    string name;
    Gizmo::Mode mode = Gizmo::Mode::Rotation;

    float stepDist = 0.25;
    float stepRot = PI/32.;

    // roughly: size in meters of target object. set via WithBoundingBox
    float scale = 1.0;
    // increase scale by this ratio so it's a bit bigger than the target
    float scaleExtraCoef = 1.2;

    CoroutineFunc@ onExit = function() {};
    CoroutineFunc@ onApply = function() {};

    RotationTranslationGizmo(const string &in name) {
        this.name = name;
        if (circleAroundX.Length == 0) {
            InitCirclesAround();
        }
    }

    RotationTranslationGizmo@ WithOnApplyF(CoroutineFunc@ f) {
        @onApply = f;
        return this;
    }

    RotationTranslationGizmo@ WithOnExitF(CoroutineFunc@ f) {
        @onExit = f;
        return this;
    }

    RotationTranslationGizmo@ WithMatrix(const mat4 &in m) {
        pos = vec3(m.tx, m.ty, m.tz);
        // rot = mat4::Inverse(mat4::Translate(pos * -1.) * m);
        rot = (mat4::Translate(pos * -1.) * m);
        return this;
    }

    RotationTranslationGizmo@ WithBoundingBox(Editor::AABB@ bb) {
        WithMatrix(bb.mat);
        scale = MathX::Max(bb.halfDiag) * 2.0;
        return this;
    }

    // RotationTranslationGizmo@ SetRotation(const mat4 &in r) {
    //     rot = r;
    //     return this;
    // }

    RotationTranslationGizmo@ AddTmpRotation(Axis axis, float delta_theta) {
        tmpRot = mat4::Inverse(mat4::Rotate(delta_theta, AxisToVecForRot(axis))) * tmpRot;
        return this;
    }

    RotationTranslationGizmo@ AddTmpTranslation(const vec3 &in t) {
        tmpPos = tmpPos + t;
        return this;
    }

    RotationTranslationGizmo@ SetTmpRotation(Axis axis, float theta) {
        tmpRot = mat4::Inverse(mat4::Rotate(theta, AxisToVecForRot(axis)));
        return this;
    }

    RotationTranslationGizmo@ SetTmpTranslation(const vec3 &in t) {
        tmpPos = t;
        return this;
    }

    RotationTranslationGizmo@ ApplyTmpRotation() {
        rot = tmpRot * rot;
        tmpRot = mat4::Identity();
        return this;
    }

    RotationTranslationGizmo@ ApplyTmpTranslation() {
        pos = pos + tmpPos;
        tmpPos = vec3();
        return this;
    }

    mat4 GetCursorMat() {
        auto xyz_rot = tmpRot * rot;
        // auto pyr = EulerFromRotationMatrix(xyz_rot, EulerOrder_Openplanet);
        // * EulerToRotationMatrix(pyr, EulerOrder_Game);
        return mat4::Translate(pos + tmpPos) * xyz_rot;
    }

    Axis lastClosestAxis = Axis::X;
    float lastClosestMouseDist = 1000000.;

    bool isMouseDown = false;
    uint mouseDownStart = 0;
    vec2 mouseDownPos;
    // the direction from center of circle to this point -- used to take dot product of drag delta to decide how much to rotate
    vec2 radialDir;

    vec2 mousePos;
    mat4 withTmpRot;
    vec3 worldPos;
    vec3 lastWorldPos;
    vec3 lastScreenPos;
    // screen pos of 0,0,0 for item
    vec2 centerScreenPos;
    vec2 centerScreenPosWTmp;
    bool shouldDrawGizmo = true;

    bool _isCtrlDown = false;
    bool _wasCtrlDown = false;
    bool _ctrlPressed = false;

    void DrawCirclesManual(vec3 pos, float _scale = 2.0) {
        camPos = Camera::GetCurrentPosition();
        mousePos = UI::GetMousePos();
        float closestMouseDist = 1000000.;
        vec3 closestRotationPoint;
        Axis closestAxis;
        // withTmpRot = (tmpRot * rot);
        withTmpRot = mat4::Inverse(tmpRot * rot);
        float c2pLen2 = (pos - camPos).LengthSquared();
        float c2pLen = (pos - camPos).Length();
        shouldDrawGizmo = true || Camera::IsBehind(pos) || c2pLen < _scale;
        if (!shouldDrawGizmo) {
            if (c2pLen < _scale) trace('c2pLen < scale');
            else trace('Camera::IsBehind(pos)');
            return;
        }

        _wasCtrlDown = _isCtrlDown;
        _isCtrlDown = IsCtrlDown();
        _ctrlPressed = _wasCtrlDown != _isCtrlDown && _isCtrlDown;

        float tmpDist;
        centerScreenPos = Camera::ToScreen(pos).xy;
        centerScreenPosWTmp = Camera::ToScreen(pos + tmpPos).xy;
        bool isRotMode = mode == Gizmo::Mode::Rotation;
        int segSkip =  isRotMode ? 4 : 1; // c2pLen2 > 40. ? 4 : 2;
        bool isNearSide = false;

        int segments = isRotMode ? CIRCLE_SEGMENTS : ARROW_SEGS;

        vec2 translateRadialDir;
        bool mouseInClickRange = lastClosestMouseDist < S_GizmoClickSensitivity;

        nvg::Reset();
        nvg::BeginPath();
        nvg::FillColor(cWhite75);
        nvg::Circle(centerScreenPos, Math::Clamp(100. / c2pLen, 2., 10.));
        nvg::Fill();
        nvg::ClosePath();

        for (int c = 0; c < 3; c++) {
            bool thicken = lastClosestAxis == Axis(c) && mouseInClickRange;
            float colAdd = thicken ? 0.2 : 0.;
            float strokeWidth = thicken ? 5 : 2;
            nvg::LineCap(nvg::LineCapType::Round);
            nvg::LineJoin(nvg::LineCapType::Round);
            nvg::BeginPath();
            nvg::StrokeWidth(strokeWidth);
            // nvg::Circle(mousePos, 5.);
            auto @circle = isRotMode ? circlesAroundXYZ[c] : axisDragArrows[c];
            auto col = circleColors[c];
            auto col2 = col * vec4(.67, .67, .67, .5);
            int i = 0;
            int imod;
            worldPos = (withTmpRot * circle[i]).xyz * _scale + pos + tmpPos;
            if (Math::IsNaN(worldPos.LengthSquared())) {
                worldPos = circle[i] * _scale + pos + tmpPos;
            }
            if (isMouseDown) {
                isNearSide = circlesAroundIsNearSide[c][0];
            } else {
                isNearSide = (worldPos - camPos).LengthSquared() < c2pLen2;
            }
            bool wasNearSide = isNearSide;
            nvg::StrokeWidth(isNearSide ? strokeWidth * 1.5 : strokeWidth);
            nvg::StrokeColor((isNearSide ? col : col2) + colAdd);
            vec3 p1 = Camera::ToScreen(worldPos);
            nvg::MoveTo(p1.xy);
            translateRadialDir = centerScreenPos - p1.xy;
            for (i = 0; i <= segments; i += segSkip) {
                imod = i % segments;
                worldPos = (withTmpRot * circle[imod]).xyz * _scale + pos + tmpPos;
                // trace('imod: ' + imod);
                if (isMouseDown) {
                    isNearSide = circlesAroundIsNearSide[c][imod];
                } else {
                    isNearSide = (worldPos - camPos).LengthSquared() < c2pLen2;
                    circlesAroundIsNearSide[c][imod] = isNearSide;
                }
                if (isNearSide != wasNearSide) {
                    nvg::Stroke();
                    nvg::ClosePath();
                    nvg::BeginPath();
                    nvg::StrokeColor((isNearSide ? col : col2) + colAdd);
                    nvg::StrokeWidth(isNearSide ? strokeWidth * 1.5 : strokeWidth);
                    nvg::MoveTo(p1.xy);
                }
                p1 = Camera::ToScreen(worldPos);
                if (p1.z > 0) {
                    nvg::MoveTo(p1.xy);
                } else {
                    nvg::LineTo(p1.xy);
                }
                if (!isMouseDown && (tmpDist = (mousePos - p1.xy).LengthSquared()) <= closestMouseDist) {
                    closestMouseDist = tmpDist;
                    closestRotationPoint = worldPos;
                    closestAxis = Axis(c);
                    radialDir = isRotMode ? (p1.xy - lastScreenPos.xy).Normalized() : translateRadialDir.Normalized();
                }
                wasNearSide = isNearSide;
                lastWorldPos = worldPos;
                lastScreenPos = p1;
            }
            nvg::Stroke();
            nvg::ClosePath();
        }
        // MARK: hndl input
        if (!isMouseDown) {
            lastClosestAxis = closestAxis;
            lastClosestMouseDist = closestMouseDist;
            if (IsAltDown() || Editor::IsInFreeLookMode(cast<CGameCtnEditorFree>(GetApp().Editor))) {
                // do nothing: camera inputs
            } if (UI::IsMouseClicked(UI::MouseButton::Left)) {
                isMouseDown = true;
                mouseDownStart = Time::Now;
                mouseDownPos = mousePos;
                ResetTmp();
            } else if (UI::IsMouseClicked(UI::MouseButton::Right) && mouseInClickRange && !IsAltDown()) {
                mode = isRotMode ? Gizmo::Mode::Translation : Gizmo::Mode::Rotation;
                ResetTmp();
            }
        } else if (!IsLMBPressed()) {
            isMouseDown = false;
            ApplyTmpRotation();
            ApplyTmpTranslation();
        } else if (UI::IsMouseClicked(UI::MouseButton::Right)) {
            // RMB while mouse is down -> reset and disable mouse down mode
            // isMouseDown = false;
            mouseDownPos = vec2(-100);
            lastClosestMouseDist = 1000000.;
            ResetTmp();
        } else if (mouseInClickRange) {
            bool skipSetLastDD = false;
            if (_ctrlPressed) ResetTmp();
            dragDelta = UI::GetMouseDragDelta(UI::MouseButton::Left, 1);
            auto ddd = dragDelta - lastDragDelta;
            if (ddd.LengthSquared() > 0.) {
                auto mag = Math::Dot(ddd.Normalized(), radialDir) * ddd.Length() / g_screen.y * TAU * -1.;
                // trace('mag: ' + mag);
                if (IsShiftDown()) mag *= 0.1;
                if (!Math::IsNaN(mag)) {
                    if (isRotMode) {
                        d = mag;
                        if (_isCtrlDown) d = d - d % stepRot;
                        if (d == 0.) skipSetLastDD = true;
                        else AddTmpRotation(lastClosestAxis, d);
                    } else {
                        d = mag * c2pLen * 0.2;
                        if (_isCtrlDown) d = d - d % stepDist;
                        if (d == 0.) skipSetLastDD = true;
                        else AddTmpTranslation((mat4::Inverse(rot) * AxisToVec(lastClosestAxis)).xyz * d); // * (lastClosestAxis == Axis::Y ? 1 : -1));
                    }
                    // SetTmpRotation(lastClosestAxis, mag);
                    // trace('lastClosestAxis: ' + tostring(lastClosestAxis) + '; dd: ' + ((dd.x + dd.y) / g_screen.y * TAU));
                    // trace('mag: ' + mag);
                } else {
                    // warn('mag is NaN');
                }
            }
            DrawRadialLine();
            if (!skipSetLastDD) lastDragDelta = dragDelta;
        }
    }

    void ResetTmp() {
        tmpRot = mat4::Identity();
        tmpPos = vec3();
        lastDragDelta = vec2();
    }

    void DrawRadialLine() {
        nvg::Reset();
        nvg::BeginPath();
        // nvg::StrokeColor(vec4(1, 1, 1, 1));
        nvg::StrokeWidth(2);
        vec2 start = mouseDownPos - radialDir * g_screen.y * .5;
        vec2 end = mouseDownPos + radialDir * g_screen.y * .5;
        nvg::MoveTo(start);
        nvg::LineTo(mouseDownPos);
        nvg::StrokePaint(nvg::LinearGradient(start, mouseDownPos, vec4(1, 1, 1, 0), vec4(1, 1, 1, 1)));
        nvg::Stroke();
        nvg::ClosePath();
        nvg::BeginPath();
        nvg::MoveTo(mouseDownPos);
        nvg::LineTo(end);
        nvg::StrokePaint(nvg::LinearGradient(end, mouseDownPos, vec4(1, 1, 1, 0), vec4(1, 1, 1, 1)));
        nvg::Stroke();
        nvg::ClosePath();
    }

    vec2 dragDelta;
    vec2 lastDragDelta;

    vec3 camPos;
    vec4 pwrPos;
    mat4 camTranslate;
    mat4 camRotation;
    mat4 camTR;
    mat4 camPersp;
    mat4 camProj;

    void DrawAll() {
        auto cam = Camera::GetCurrent();
        if (cam is null) return;
        auto camLoc = mat4(cam.Location);
        camPos = vec3(camLoc.tx, camLoc.ty, camLoc.tz);

#if DEV
        if (pos.LengthSquared() == 0) {
            pos = camPos - vec3(4.);
            try {
                auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
                pos = editor.OrbitalCameraControl.m_TargetedPosition;
            } catch {}
        }
#endif

        DrawCirclesManual(pos, scale * scaleExtraCoef);
        DrawWindow();
    }

    void Render() {
        DrawAll();
    }

    bool useGlobal = false;

    vec3 lastAppliedPivot;

    void DrawWindow() {
        bool isRotMode = mode == Gizmo::Mode::Rotation;
        auto nbBtns = 3.;
        auto btnSize = g_screen.y * .05;
        auto btnSize2 = vec2(btnSize);
        auto itemSpacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
        UI::SetNextWindowPos(.5 * g_screen.x, 24 * g_scale, UI::Cond::Appearing);
        if (UI::Begin("###gz-tlbr-"+name, UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize)) {
            // UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(g_screen.y * 0.005));
            UI::PushFont(g_BigFont);
            if (UI::Button(isRotMode ? Icons::Dribbble : Icons::ArrowsAlt, btnSize2)) {
                mode = isRotMode ? Gizmo::Mode::Translation : Gizmo::Mode::Rotation;
            }
            AddSimpleTooltip("Rotation or Translation?");

            // UI::SameLine();
            // if (UI::Button(isRotMode ? Icons::Dribbble : Icons::ArrowsAlt, btnSize2)) {
            //     mode = isRotMode ? Gizmo::Mode::Translation : Gizmo::Mode::Rotation;
            // }

            UI::SameLine();
            if (UI::Button(useGlobal ? "Glb" : "Loc", btnSize2)) {
                onApply();
            }
            AddSimpleTooltip("Global or Local space? (Local will move along object's axes)");

            UI::SameLine();
            if (UI::Button("Piv", btnSize2)) {
                onApply();
            }
            if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right)) {
                UI::OpenPopup("gizmo-toolbar-edit-pivot");
            }
            AddSimpleTooltip("Cycle Pivot (RMB to edit)");

            UI::SameLine();
            if (UI::Button(Icons::Check, btnSize2)) {
                onApply();
            }
            AddSimpleTooltip("Apply");

            UI::SameLine();
            if (UI::Button(Icons::Times, btnSize2)) {
                onExit();
            }
            AddSimpleTooltip("Cancel");
            UI::PopFont();
            // UI::PopStyleVar();
        }
        UI::End();

        if (UI::BeginPopup("gizmo-toolbar-edit-pivot")) {
            UI::Text("Edit Pivot");
            UI::Separator();
            UI::Text("Pivot: " + pos.ToString());
            UI::Text("Scale: " + scale);
            UI::Separator();
            UI::Text("Set Pivot to:");
            UI::PushItemWidth(100);
            UI::InputFloat3("##gizmo-pivot", pos);
            UI::InputFloat("##gizmo-pivot-scale", scale);
            UI::PopItemWidth();
            UI::Separator();
            if (UI::Button("Apply")) {
                onApply();
                UI::CloseCurrentPopup();
            }
            UI::SameLine();
            if (UI::Button("Cancel")) {
                UI::CloseCurrentPopup();
            }

            UX::CloseCurrentPopupIfMouseFarAway();
            UI::EndPopup();
        }


        // // UX::PushInvisibleWindowStyle();
        // if (UI::Begin("###rgz"+name)) {
        //     vec2 wp = UI::GetWindowPos() / g_scale;
        //     UI::Text("test window");
        //     UI::Text("cam pos: " + camPos.ToString());
        //     UI::Text("pos pos: " + pos.ToString());
        //     UI::Text("center pos" + centerScreenPos.ToString());
        //     UI::Text("mouse pos: " + mousePos.ToString());
        //     UI::Text("last mouse pos: " + lastScreenPos.ToString());
        //     UI::Text("last closest axis: " + tostring(lastClosestAxis));
        //     UI::Text("last closest mouse dist: " + lastClosestMouseDist);
        //     UI::Text("isMouseDown: " + isMouseDown);
        //     UI::Text("IsShiftDown(): " + IsShiftDown());
        //     UI::Text("IsCtrlDown(): " + IsCtrlDown());
        //     UI::Text("IsAltDown(): " + IsAltDown());
        //     // UI::Text("rot: " + rot.ToString());
        //     // UI::Text("tmpRot: " + tmpRot.ToString());
        //     // UI::Text("withTmpRot: " + withTmpRot.ToString());
        //     UI::Text("radialDir: " + radialDir.ToString());
        //     UI::Text("shouldDrawGizmo: " + shouldDrawGizmo);
        // }
        // UI::End();
        // // UX::PopInvisibleWindowStyle();
    }

    float d;
}

const quat ROT_Q_AROUND_UP = quat(UP, HALF_PI);
const quat ROT_Q_AROUND_FWD = quat(FORWARD, HALF_PI);


void Mat4_GetEllipseData(const mat4 &in m, vec3 &out r1_r2_theta, float scale = 1.0) {
    auto c1 = vec2(m.xx, m.yx);
    auto c2 = vec2(m.xy, m.yy);
    auto c1Len = c1.Length();
    auto c2Len = c2.Length();
    vec2 c;
    if (c1Len < c2Len) {
        c = c2;
        r1_r2_theta.y = c1Len;
    } else {
        c = c1;
        r1_r2_theta.y = c2Len;
    }
    r1_r2_theta.x = scale;
    r1_r2_theta.y *= scale;
    r1_r2_theta.z = Math::Atan2(c.y, c.x);
}


namespace UX {
    void PushInvisibleWindowStyle() {
        UI::PushStyleColor(UI::Col::WindowBg, vec4(0, 0, 0, 0));
        UI::PushStyleColor(UI::Col::Border, vec4(0, 0, 0, 0));
        UI::PushStyleColor(UI::Col::TitleBg, vec4(0, 0, 0, 0));
        UI::PushStyleColor(UI::Col::TitleBgActive, vec4(0, 0, 0, 0));
    }

    void PopInvisibleWindowStyle() {
        UI::PopStyleColor(4);
    }
}
