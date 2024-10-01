RotationTranslationGizmo@ testGizmo;

array<vec3>@[] axisDragArrows = {
    {vec3(.3, 0, 0), vec3(1, 0, 0), vec3(0.9, 0, 0.1), vec3(0.9, 0, -0.1), vec3(1, 0, 0), vec3(0.9, 0.1, 0), vec3(0.9, -0.1, 0), vec3(1, 0, 0)},
    {vec3(0, .3, 0), vec3(0, 1, 0), vec3(0.1, 0.9, 0), vec3(-0.1, 0.9, 0), vec3(0, 1, 0), vec3(0, 0.9, 0.1), vec3(0, 0.9, -0.1), vec3(0, 1, 0)},
    {vec3(0, 0, .3), vec3(0, 0, 1), vec3(0.1, 0, 0.9), vec3(-0.1, 0, 0.9), vec3(0, 0, 1), vec3(0, 0.1, 0.9), vec3(0, -0.1, 0.9), vec3(0, 0, 1)}
};

// XZ, XY, YZ
const float PLANE_DRAG_OFFSET = 0.67;
const float PLANE_DRAG_END = 0.80;
const array<vec3>[] planeDragSquares = {
    {vec3(0, PLANE_DRAG_OFFSET, PLANE_DRAG_OFFSET), vec3(0, PLANE_DRAG_END, PLANE_DRAG_OFFSET), vec3(0, PLANE_DRAG_END, PLANE_DRAG_END), vec3(0, PLANE_DRAG_OFFSET, PLANE_DRAG_END), vec3(0, PLANE_DRAG_OFFSET, PLANE_DRAG_OFFSET)},
    {vec3(PLANE_DRAG_OFFSET, 0, PLANE_DRAG_OFFSET), vec3(PLANE_DRAG_END, 0, PLANE_DRAG_OFFSET), vec3(PLANE_DRAG_END, 0, PLANE_DRAG_END), vec3(PLANE_DRAG_OFFSET, 0, PLANE_DRAG_END), vec3(PLANE_DRAG_OFFSET, 0, PLANE_DRAG_OFFSET)},
    {vec3(PLANE_DRAG_OFFSET, PLANE_DRAG_OFFSET, 0), vec3(PLANE_DRAG_END, PLANE_DRAG_OFFSET, 0), vec3(PLANE_DRAG_END, PLANE_DRAG_END, 0), vec3(PLANE_DRAG_OFFSET, PLANE_DRAG_END, 0), vec3(PLANE_DRAG_OFFSET, PLANE_DRAG_OFFSET, 0)}
};

const int ARROW_SEGS = 8;
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
    // if (axisDragArrows[0].Length < 10) {
    //     for (int i = 0; i < 3; i++) {
    //         auto snd = axisDragArrows[i][1];
    //         for (float x = 0.9; x > 0.31; x -= 0.1) {
    //             axisDragArrows[i].InsertLast(snd * x);
    //         }
    //     }
    // }
}

vec4[] circleColors = {
    vec4(1, 0, 0, 1),
    vec4(0, 1, 0, 1),
    vec4(0, 0, 1, 1)
};

const quat DEFAULT_QUAT = quat(0,0,0,1);

[Setting hidden]
float S_GizmoClickSensitivity = 400.;

const float GIZMO_MAX_SCALE_COEF = .45;

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

    vec3 bbHalfDiag;
    vec3 bbMidPoint;

    RotationTranslationGizmo@ WithBoundingBox(Editor::AABB@ bb) {
        WithMatrix(bb.mat);
        scale = bb.halfDiag.Length() * 1.333;
        bbHalfDiag = bb.halfDiag;
        bbMidPoint = bb.midPoint;
        return this;
    }

    RotationTranslationGizmo@ WithPlacementParams(CGameItemPlacementParam@ pp) {
        placementParamOffset = vec3(pp.GridSnap_HOffset, pp.GridSnap_VOffset, pp.GridSnap_HOffset);
        return this;
    }

    // RotationTranslationGizmo@ SetRotation(const mat4 &in r) {
    //     rot = r;
    //     return this;
    // }

    RotationTranslationGizmo@ AddTmpRotation(Axis axis, float delta_theta, bool rotateToLocal = true) {
        // tmpRot = mat4::Inverse(mat4::Rotate(delta_theta, AxisToVecForRot(axis))) * tmpRot;
        // accounting for pivotPoint:
        if (rotateToLocal) {
            tmpRot = mat4::Translate(pivotPoint * -1.) * mat4::Inverse(mat4::Rotate(delta_theta, AxisToVecForRot(axis))) * mat4::Translate(pivotPoint) * tmpRot;
        } else {
            // rotate about global axes
            tmpRot = tmpRot * mat4::Translate(pivotPoint * -1.) * mat4::Rotate(delta_theta * -1., ((tmpRot * rot) * AxisToVecForRot(axis)).xyz) * mat4::Translate(pivotPoint);
        }
        auto p = vec3(tmpRot.tx, tmpRot.ty, tmpRot.tz);
        tmpRot = mat4::Translate(p * -1) * tmpRot;
        // tmpPos -= p;
        return this;
    }

    RotationTranslationGizmo@ AddTmpTranslation(const vec3 &in t, bool rotateToLocal = false) {
        if (rotateToLocal) {
            tmpPos += (mat4::Inverse(rot) * t).xyz;
        } else {
            tmpPos += t;
        }
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
        ApplyTmpTranslation();
        return this;
    }

    RotationTranslationGizmo@ ApplyTmpTranslation() {
        pos = pos + tmpPos;
        tmpPos = vec3();
        return this;
    }

    void CyclePivot() {
        Gizmo::CyclePivot();
    }

    AnimMgr@ pivotAnimator;

    void SetPivotPoint(vec3 newPivot, bool animate = true) {
        if (animate) {
            destinationPivotPoint = newPivot;
            if (pivotAnimator !is null) {
                // Dev_NotifyWarning("Gizmo: pivotAnimator already running!?");
                // pivotAnimator.SetAt(1.0);
            }
            @pivotAnimator = AnimMgr(false, S_AnimationDuration);
            startnew(CoroutineFunc(RunPivotAnim));
            AddTmpTranslation(newPivot - pivotPoint, true);
            FocusCameraOn(pos + tmpPos);
            AddTmpTranslation(pivotPoint - newPivot, true);
            return;
        }
        // dev_trace("Gizmo: set pivot point: " + newPivot.ToString());
        AddTmpTranslation(newPivot - pivotPoint, true);
        ApplyTmpTranslation();
        pivotPoint = newPivot;
    }

    vec3 destinationPivotPoint;
    void RunPivotAnim() {
        auto toPos = destinationPivotPoint;
        auto fromPos = pivotPoint;
        auto @anim = pivotAnimator;
        // dev_trace("[Before] Gizmo: pivotAnimator done? " + anim.IsDone + " / progress: " + anim.Progress);
        while (anim.Update(true)) {
            // dev_trace("[Update] Gizmo: pivotAnimator done? " + anim.IsDone + " / progress: " + anim.Progress);
            SetPivotPoint(Math::Lerp(fromPos, toPos, anim.Progress), false);
            if (anim.IsDone) break;
            yield();
        }
        // dev_trace("Gizmo: pivotAnimator done? " + anim.IsDone + " / progress: " + anim.Progress);
        if (anim is pivotAnimator) {
            @pivotAnimator = null;
        }
    }

    mat4 GetCursorMat() {
        auto xyz_rot = tmpRot * rot;
        auto pivotRotated = (mat4::Inverse(xyz_rot) * ((pivotPoint) * -1.)).xyz;
        // auto pyr = EulerFromRotationMatrix(xyz_rot, EulerOrder_Openplanet);
        // * EulerToRotationMatrix(pyr, EulerOrder_Game);
        return mat4::Translate(pos + tmpPos + pivotRotated) * xyz_rot;
    }

    vec3 GetRotatedPivotPoint() {
        return (mat4::Inverse(tmpRot * rot) * (pivotPoint * -1.)).xyz;
    }

    vec3 placementParamOffset = vec3();

    Axis lastClosestAxis = Axis::X;
    float lastClosestMouseDist = 1000000.;
    bool hoveringAlt = false;

    bool isMouseDown = false;
    bool mouseInClickRange = false;
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
    vec3 planePos;

    bool _isCtrlDown = false;
    bool _wasCtrlDown = false;
    bool _ctrlPressed = false;

    vec3 _closestRotationPoint;
    Axis _closestAxis;
    float _closestMouseDist;
    bool _hoveringAlt;

    void DrawCirclesManual(vec3 objOriginPos, float _scale = 2.0) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto cam = Camera::GetCurrent();
        auto camState = Editor::GetCurrentCamState(editor);

        camPos = Camera::GetCurrentPosition();
        mousePos = UI::GetMousePos();
        float c2pLen2 = (objOriginPos - camPos).LengthSquared();
        float c2pLen = (objOriginPos - camPos).Length();

        auto maxScale = GIZMO_MAX_SCALE_COEF * c2pLen * Math::Tan(Math::ToRad(cam.Fov * .5));
        _scale = Math::Min(_scale, maxScale);
        _closestRotationPoint = vec3();
        // objOriginPos -= pivotPoint;
        _closestMouseDist = 1000000.;
        // withTmpRot = (tmpRot * rot);
        withTmpRot = useGlobal ? mat4::Identity() : mat4::Inverse(tmpRot * rot);
        shouldDrawGizmo = true || Camera::IsBehind(objOriginPos) || c2pLen < _scale;
        if (!shouldDrawGizmo) {
            if (c2pLen < _scale) trace('c2pLen < scale');
            else trace('Camera::IsBehind(pos)');
            return;
        }

        _wasCtrlDown = _isCtrlDown;
        _isCtrlDown = IsCtrlDown();
        _ctrlPressed = _wasCtrlDown != _isCtrlDown && _isCtrlDown;

        float tmpDist;
        centerScreenPos = Camera::ToScreen(objOriginPos).xy;
        centerScreenPosWTmp = Camera::ToScreen(objOriginPos + tmpPos).xy;
        bool isRotMode = mode == Gizmo::Mode::Rotation;
        int segSkip =  isRotMode ? 4 : 1; // c2pLen2 > 40. ? 4 : 2;
        bool isNearSide = false;

        int segments = isRotMode ? CIRCLE_SEGMENTS : ARROW_SEGS;

        vec2 translateRadialDir;
        mouseInClickRange = lastClosestMouseDist < S_GizmoClickSensitivity;

        nvg::Reset();
        nvg::BeginPath();
        nvg::FillColor(cWhite75);
        nvg::Circle(centerScreenPosWTmp, Math::Clamp(100. / c2pLen, 2., 10.));
        nvg::Fill();
        nvg::ClosePath();

        // MARK: Rings/Arrows

        for (int c = 0; c < 3; c++) {
            bool thicken = lastClosestAxis == Axis(c) && mouseInClickRange && !hoveringAlt;
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
            worldPos = (withTmpRot * circle[i]).xyz * _scale + objOriginPos + tmpPos;
            auto worldPos2 = (withTmpRot * circle[1]).xyz * _scale + objOriginPos + tmpPos;
            if (Math::IsNaN(worldPos.LengthSquared())) {
                worldPos = circle[i] * _scale + objOriginPos + tmpPos;
                worldPos2 = circle[1] * _scale + objOriginPos + tmpPos;
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
            lastWorldPos = worldPos;
            lastScreenPos = p1;
            nvg::MoveTo(p1.xy);
            translateRadialDir = centerScreenPos - p1.xy;
            for (i = 0; i <= segments; i += segSkip) {
                imod = i % segments;
                worldPos = (withTmpRot * circle[imod]).xyz * _scale + objOriginPos + tmpPos;
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
                // if we're not dragging and mouse is closest to this segment, set it as the closest axis
                if (!isMouseDown && (tmpDist = sdSegment(mousePos, lastScreenPos.xy, p1.xy)) <= _closestMouseDist) {
                    _closestMouseDist = tmpDist;
                    _closestRotationPoint = worldPos;
                    _closestAxis = Axis(c);
                    radialDir = isRotMode ? (p1.xy - lastScreenPos.xy).Normalized() : translateRadialDir.Normalized();
                    _hoveringAlt = false;
                }
                wasNearSide = isNearSide;
                lastWorldPos = worldPos;
                lastScreenPos = p1;
            }
            nvg::Stroke();
            nvg::ClosePath();
        }

        if (mode == Gizmo::Mode::Translation) {
            DrawPlaneDraggers(_scale);
        }

        // MARK: hndl input
        if (!isMouseDown) {
            lastClosestAxis = _closestAxis;
            lastClosestMouseDist = _closestMouseDist;
            hoveringAlt = _hoveringAlt;
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
            ResetGizmoRMB();
        } else if (mouseInClickRange) {
            bool skipSetLastDD = false;
            if (_ctrlPressed) ResetTmp();
            dragDelta = UI::GetMouseDragDelta(UI::MouseButton::Left, 1);
            auto ddd = dragDelta - lastDragDelta;
            if (ddd.LengthSquared() > 0.) {
                if (hoveringAlt) {
                    // we drag in plane rather than axis
                    if (isRotMode) {
                        warn("hoveringAlt while in rot mode");
                        ResetGizmoRMB();
                    } else {
                        auto normal = (withTmpRot * AxisToVec(lastClosestAxis)).xyz;
                        auto pickedPos = Picker::GetMouseToWorldOnPlane(normal, planePos);
                        SetTmpTranslation(pickedPos - planePos);
                    }
                } else {
                    // we drag along axis
                    auto mag = Math::Dot(ddd.Normalized(), radialDir) * ddd.Length() / g_screen.y * TAU * -1.;
                    // trace('mag: ' + mag);
                    if (IsShiftDown()) mag *= 0.1;
                    if (!Math::IsNaN(mag)) {
                        if (isRotMode) {
                            d = mag;
                            if (_isCtrlDown) d = d - d % stepRot;
                            if (d == 0.) skipSetLastDD = true;
                            else AddTmpRotation(lastClosestAxis, d, !useGlobal);
                        } else {
                            d = mag * c2pLen * 0.2;
                            if (_isCtrlDown) d = d - d % stepDist;
                            if (d == 0.) skipSetLastDD = true;
                            else {
                                // AddTmpTranslation((mat4::Inverse(rot) * AxisToVec(lastClosestAxis)).xyz * d); // * (lastClosestAxis == Axis::Y ? 1 : -1));
                                AddTmpTranslation(AxisToVec(lastClosestAxis) * d, !useGlobal); // * (lastClosestAxis == Axis::Y ? 1 : -1));
                            }
                        }
                        // SetTmpRotation(lastClosestAxis, mag);
                        // trace('lastClosestAxis: ' + tostring(lastClosestAxis) + '; dd: ' + ((dd.x + dd.y) / g_screen.y * TAU));
                        // trace('mag: ' + mag);
                    } else {
                        // warn('mag is NaN');
                    }
                }
            }
            if (!hoveringAlt) DrawRadialLine();
            if (!skipSetLastDD) lastDragDelta = dragDelta;
        }
    }

    void ResetGizmoRMB() {
        mouseDownPos = vec2(-100);
        lastClosestMouseDist = 1000000.;
        hoveringAlt = false;
        ResetTmp();
    }

    // MARK: Plane Draggers
    void DrawPlaneDraggers(float _scale) {
        for (uint c = 0; c < 3; c++) {
            bool thicken = lastClosestAxis == Axis(c) && mouseInClickRange && hoveringAlt;
            auto col = circleColors[c];
            auto col2 = col * vec4(.67, .67, .67, .5);
            nvg::BeginPath();
            nvg::FillColor((thicken ? col : col2));
            nvg::StrokeColor((thicken ? col : col2));
            nvg::StrokeColor(vec4());
            nvg::StrokeWidth(0);
            auto @square = planeDragSquares[c];
            auto worldPos = (withTmpRot * square[0]).xyz * _scale + pos + tmpPos;
            auto p1 = Camera::ToScreen(worldPos);
            vec2[] points = {p1.xy, p1.xy, p1.xy, p1.xy};
            nvg::MoveTo(p1.xy);
            for (uint i = 1; i < square.Length; i++) {
                worldPos = (withTmpRot * square[i]).xyz * _scale + pos + tmpPos;
                p1 = Camera::ToScreen(worldPos);
                points[i - 1] = p1.xy;
                if (p1.z > 0) {
                    nvg::MoveTo(p1.xy);
                } else {
                    nvg::LineTo(p1.xy);
                }
            }
            nvg::ClosePath();
            nvg::Fill();
            // nvg::Stroke();
            if (!isMouseDown && _closestMouseDist > 0 && pointInQuad(mousePos, points)) {
                _closestMouseDist = 0;
                _closestAxis = Axis(c);
                _hoveringAlt = true;
                planePos = worldPos;
                planePos = Picker::GetMouseToWorldOnPlane((withTmpRot * AxisToVec(_closestAxis)).xyz, planePos);
            }
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

    vec3 pivotPoint;

    void DrawAll() {
        auto cam = Camera::GetCurrent();
        if (cam is null) return;
        auto camLoc = mat4(cam.Location);
        camPos = vec3(camLoc.tx, camLoc.ty, camLoc.tz);

        DrawWindow();

        // don't draw if behind camera, or gizmo outside screen bounds
        auto posToScreen = Camera::ToScreen(pos);
        if (posToScreen.z >= 0) return;
        if (posToScreen.x < -3.1 || posToScreen.x > g_screen.x + 3.1 || posToScreen.y < -3.1 || posToScreen.y > g_screen.y + 3.1) return;

        DrawCirclesManual(pos, scale * scaleExtraCoef);
    }

    void Render() {
        DrawAll();
    }

    bool useGlobal = false;

    // vec3 lastAppliedPivot;

    void DrawWindow() {
        bool isRotMode = mode == Gizmo::Mode::Rotation;
        auto btnSize = g_screen.y * .05;
        auto btnSize2 = vec2(btnSize);
        auto nbBtns = 6.;
        auto itemSpacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        UI::SetNextWindowPos(.5 * (g_screen.x - (btnSize + itemSpacing.x) * nbBtns) / g_scale, 24 * g_scale, UI::Cond::Appearing);

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
            if (UI::Button(useGlobal ? "World" : "Local", btnSize2)) {
                useGlobal = !useGlobal;
            }
            AddSimpleTooltip("Global or Local space? (Local will move along object's axes)");

            UI::SameLine();
            if (UI::Button("Pivot\n   "+Icons::Refresh, btnSize2)) {
                CyclePivot();
            }
            if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right)) {
                UI::OpenPopup("gizmo-toolbar-edit-pivot");
            }
            AddSimpleTooltip("Cycle Pivot (RMB to edit)");

            UI::SameLine();
            if (UI::Button(Icons::Camera, btnSize2)) {
                FocusCameraOn(pos);
            }
            AddSimpleTooltip("Reset Camera");

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
        if (UI::BeginPopup("gizmo-toolbar-edit-pivot")) {
            UI::Text("Edit Pivot");
            UI::SeparatorText("Edit Pivot");
            UI::Text("\\$iTodo");
            // UI::Text("Pivot: " + pos.ToString());
            // UI::Text("Scale: " + scale);
            // UI::Separator();
            // UI::Text("Set Pivot to:");
            // UI::PushItemWidth(100);
            // UI::InputFloat3("##gizmo-pivot", pos);
            // UI::InputFloat("##gizmo-pivot-scale", scale);
            // UI::PopItemWidth();
            // UI::Separator();
            // if (UI::Button("Apply")) {
            //     onApply();
            //     UI::CloseCurrentPopup();
            // }
            // UI::SameLine();
            // if (UI::Button("Cancel")) {
            //     UI::CloseCurrentPopup();
            // }

            UX::CloseCurrentPopupIfMouseFarAway();
            UI::EndPopup();
        }
        UI::End();



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

    void FocusCameraOn(vec3 p) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto camState = Editor::GetCurrentCamState(editor);
        camState.Pos = p;
        camState.TargetDist = this.scale * 4.5;
        Editor::SetCamAnimationGoTo(camState);
    }
}

const quat ROT_Q_AROUND_UP = quat(UP, HALF_PI);
const quat ROT_Q_AROUND_FWD = quat(BACKWARD, HALF_PI);



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
