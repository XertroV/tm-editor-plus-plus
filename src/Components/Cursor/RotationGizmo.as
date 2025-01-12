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

[Setting hidden]
float S_Gizmo_TranslateCtrlStepDist = 0.25;

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


class GizmoState {
    vec3 pos;
    mat4 rot;
    vec3 pivotPoint;
    uint nbPlaced = 0;
    GizmoState(const vec3 &in pos, const mat4 &in rot, const vec3 &in pivotPoint) {
        this.pos = pos;
        this.rot = rot;
        this.pivotPoint = pivotPoint;
    }
    GizmoState() {}

    string ToString() {
        return "GizmoState(pos: " + pos.ToString() + "rot: mat4, " + " pivot: " + pivotPoint.ToString() + ")";
    }

    mat4 GetMatrix() {
        return mat4::Translate(pos) * mat4::Inverse(rot) * mat4::Translate(pivotPoint * -1.);
    }
}

[Setting hidden]
float S_Gizmo_StepRot = PI/48.;

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
    // UV for moving object on plane
    vec2 altMoveUV;

    GizmoState[] history;

    // roughly: size in meters of target object. set via WithBoundingBox. used to scale gizmo
    float scale = 1.0;
    // increase scale by this ratio so it's a bit bigger than the target
    float scaleExtraCoef = 1.2;

    CoroutineFunc@ onExit = function() {};
    CoroutineFunc@ onApply = function() {};
    CoroutineFunc@ onApplyAndCont = function() {};

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

    RotationTranslationGizmo@ WithOnApplyAndContinueF(CoroutineFunc@ f) {
        @onApplyAndCont = f;
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

    ~RotationTranslationGizmo() {}

    void CleanUp() {
        if (placementParams !is null) {
            @placementParams = null;
        }
    }

    void Undo() {
        if (history.Length == 0) {
            dev_trace("Gizmo: no history to undo");
            return;
        }
        auto last = history[history.Length - 1];
        while (last.nbPlaced > 0) {
            cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType.Undo();
            last.nbPlaced--;
        }
        pos = last.pos;
        rot = last.rot;
        pivotPoint = last.pivotPoint;
        FocusCameraOn(pos, false);
        dev_trace("Gizmo: undo: " + last.ToString());
        history.RemoveLast();
    }

    mat4 GetMatrix() {
        // return mat4::Translate(pos + tmpPos + GetRotatedPivotPoint(-1.)) * mat4::Inverse(tmpRot * rot)
        //     * mat4::Translate(pivotPoint * -1.);
        return mat4::Translate(pos + tmpPos) * mat4::Inverse(tmpRot * rot)
            * mat4::Translate(pivotPoint * -1.
                + modelOffset
                - GetItemCursorPivot()
            );
    }

    vec3 GetItemCursorPivot() {
        if (itemPivots.Length == 0) return vec3();
        auto cur = Editor::GetCurrentPivot(cast<CGameCtnEditorFree>(GetApp().Editor));
        return itemPivots[cur % itemPivots.Length];
    }

    vec3 bbHalfDiag;
    vec3 bbMidPoint;
    vec3 modelOffset;

    RotationTranslationGizmo@ WithBoundingBox(Editor::AABB@ bb) {
        WithMatrix(bb.mat);
        scale = bb.halfDiag.Length() * 1.333;
        bbHalfDiag = bb.halfDiag;
        bbMidPoint = bb.midPoint;
        this.modelOffset = bbMidPoint - bbHalfDiag; // + pivot;
        return this;
    }

    ReferencedNod@ placementParams;
    CGameItemPlacementParam@ get_PlacementParams() {
        if (placementParams !is null && placementParams.AsPlacementParam() !is null) {
            return placementParams.AsPlacementParam();
        }
        return null;
    }

    RotationTranslationGizmo@ WithPlacementParams(CGameItemPlacementParam@ pp) {
        placementParamOffset = vec3(pp.GridSnap_HOffset, pp.GridSnap_VOffset, pp.GridSnap_HOffset);
        @placementParams = ReferencedNod(pp);
        pp.SwitchPivotManually = true;
        CopyPivotPositions(pp);
        return this;
    }

    vec3[] itemPivots;
    void CopyPivotPositions(CGameItemPlacementParam@ pp) {
        itemPivots.RemoveRange(0, itemPivots.Length);
        for (uint i = 0; i < pp.PivotPositions.Length; i++) {
            itemPivots.InsertLast(pp.PivotPositions[i]);
        }
    }

    vec3 GetPivot(int ix) {
        if (ix < 0 || ix >= itemPivots.Length) return vec3();
        return itemPivots[ix];
    }

    bool blockOffsetApplied = false;

    void OffsetBlockOnStart() {
        if (blockOffsetApplied) return;
        blockOffsetApplied = true;
        AddTmpTranslation(DOWN * .25, true);
        ApplyTmpTranslation();
    }

    void OffsetBlockOnApply() {
        if (!blockOffsetApplied) return;
        blockOffsetApplied = false;
        AddTmpTranslation(DOWN * -.25, true);
        ApplyTmpTranslation();
    }

    // RotationTranslationGizmo@ SetRotation(const mat4 &in r) {
    //     rot = r;
    //     return this;
    // }

    float tmpRotationAngle = 0.;

    RotationTranslationGizmo@ AddTmpRotation(Axis axis, float delta_theta, bool rotateToLocal = true) {
        tmpRotationAngle += delta_theta;
        // tmpRot = mat4::Inverse(mat4::Rotate(delta_theta, AxisToVecForRot(axis))) * tmpRot;
        // accounting for pivotPoint:
        if (rotateToLocal) {
            auto rp = EulerToMat(rotPivot);
            tmpRot = mat4::Translate(pivotPoint * -1.) * mat4::Inverse(rp) * mat4::Inverse(mat4::Rotate(delta_theta, AxisToVecForRot(axis))) * rp * mat4::Translate(pivotPoint) * tmpRot;

        } else {
            // rotate about global axes
            tmpRot = tmpRot * mat4::Translate(pivotPoint * -1.) * mat4::Rotate(delta_theta * -1., ((tmpRot * rot) * AxisToVecForRot(axis)).xyz) * mat4::Translate(pivotPoint);
        }
        auto p = vec3(tmpRot.tx, tmpRot.ty, tmpRot.tz);
        tmpRot = mat4::Translate(p * -1) * tmpRot;
        // tmpPos -= p;
        return this;
    }

    RotationTranslationGizmo@ AddTmpRotation(const mat4 &in m) {
        tmpRot = m * tmpRot;
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
        tmpRotationAngle = theta;
        tmpRot = mat4::Inverse(mat4::Rotate(theta, AxisToVecForRot(axis)));
        return this;
    }

    RotationTranslationGizmo@ SetTmpTranslation(const vec3 &in t) {
        tmpPos = t;
        return this;
    }

    RotationTranslationGizmo@ ApplyTmpRotation(bool addUndoState = true) {
        if (addUndoState && tmpRotationAngle != 0.) history.InsertLast(GetState());
        rot = tmpRot * rot;
        tmpRot = mat4::Identity();
        tmpRotationAngle = 0.;
        ApplyTmpTranslation();
        return this;
    }

    RotationTranslationGizmo@ ApplyTmpTranslation(bool addUndoState = true) {
        if (addUndoState && tmpPos.LengthSquared() > 0) history.InsertLast(GetState());
        pos = pos + tmpPos;
        tmpPos = vec3();
        return this;
    }

    GizmoState GetState() {
        return GizmoState(pos, rot, PivotPointOrDest);
    }

    void CyclePivot() {
        Gizmo::CyclePivot();
    }

    AnimMgr@ pivotAnimator;

    void SetPivotPoint(vec3 newPivot, bool animate = true, bool addToUndo = true) {
        if (addToUndo) history.InsertLast(GetState());
        auto dist = newPivot - pivotPoint;
        if (animate) {
            destinationPivotPoint = newPivot;
            if (pivotAnimator !is null) {
                // Dev_NotifyWarning("Gizmo: pivotAnimator already running!?");
                // pivotAnimator.SetAt(1.0);
            }
            @pivotAnimator = AnimMgr(false, S_AnimationDuration);
            startnew(CoroutineFunc(RunPivotAnim)).WithRunContext(Meta::RunContext::AfterMainLoop);
            AddTmpTranslation(dist, true);
            FocusCameraOn(pos + tmpPos, false);
            AddTmpTranslation(dist * -1., true);
            return;
        }
        // dev_trace("Gizmo: set pivot point: " + newPivot.ToString());
        AddTmpTranslation(dist, true);
        ApplyTmpTranslation(false);
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
            SetPivotPoint(Math::Lerp(fromPos, toPos, anim.Progress), false, false);
            if (anim.IsDone) break;
            yield();
        }
        SetPivotPoint(toPos, false, false);
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

    vec3 GetRotatedPivotPoint(float pivotCoef = -1.) {
        return (mat4::Inverse(tmpRot * rot) * (pivotPoint * pivotCoef)).xyz;
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
        if (MathX::IsNanInf(objOriginPos)) return;
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
        withTmpRot = useGlobal ? mat4::Identity() : mat4::Inverse(EulerToMat(rotPivot) * tmpRot * rot);
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
                SwapMode(); // calls ResetTmp()
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
                        float quantize = _isCtrlDown ? S_Gizmo_TranslateCtrlStepDist : 0.0;

                        auto pickedPos = Picker::GetMouseToWorldOnPlane(normal, planePos, quantize);
                        altMoveUV = Picker::lastMouseToWorldOnPlaneQuantizedUV;

                        vec3 d = pickedPos - planePos;
                        if (IsShiftDown()) d *= 0.1;
                        SetTmpTranslation(d);
                    }
                } else {
                    // we drag along axis
                    auto mag = Math::Dot(ddd.Normalized(), radialDir) * ddd.Length() / g_screen.y * TAU * -1.;
                    // trace('mag: ' + mag);
                    if (IsShiftDown()) mag *= 0.1;
                    if (!Math::IsNaN(mag)) {
                        if (isRotMode) {
                            d = mag;
                            if (_isCtrlDown) {
                                d = LockToAngles(tmpRotationAngle + d, S_Gizmo_StepRot) - tmpRotationAngle;
                            }
                            if (d == 0.) skipSetLastDD = true;
                            else AddTmpRotation(lastClosestAxis, d, !useGlobal);
                        } else {
                            d = mag * c2pLen * 0.2;
                            if (_isCtrlDown) {
                                auto step = S_Gizmo_TranslateCtrlStepDist;
                                if (Math::Abs(step) < 0.01) step = 0.25;
                                d = d - d % step;
                            }
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
            if (!hoveringAlt) {
                DrawRadialLine();
            }
            DrawAmountText();
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
        tmpRotationAngle = 0.;
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

    void DrawAmountText() {
        vec2 bottomLeft = mouseDownPos; // mousePos + vec2(25, -25) * g_scale;
        float fontSize = 36.0 * g_stdPxToScreenPx * g_scale;
        nvg::Reset();
        nvg::FontSize(fontSize);
        vec4 color = cWhite;
        if (_isCtrlDown && IsCloseToSpecialAngle(tmpRotationAngle)) {
            color = cLimeGreen;
        } else if (_isCtrlDown) {
            // color = cCyan;
        }
        nvgDrawTextWithStroke(bottomLeft, GetCurrentTmpAmountStr(0), color);
        // draw above because axes uv are reversed from normal order
        if (hoveringAlt) {
            nvgDrawTextWithStroke(bottomLeft - vec2(0, fontSize*1.2), GetCurrentTmpAmountStr(1), color);
        }
    }

    // componentIx = 0 mostly, except for alt move line 2, where it =1
    string GetCurrentTmpAmountStr(int componentIx = 0) {
        if (!hoveringAlt && componentIx != 0) {
            return "UNKNOWN componentIx == " + componentIx;
        }
        if (mode == Gizmo::Mode::Rotation) {
            bool veryCloseToSteppedRotation = ((Math::Abs(tmpRotationAngle) + 0.005) % S_Gizmo_StepRot) < 0.01;
            string ret = tostring(Math::Round(Math::ToDeg(tmpRotationAngle), 1)) + " °";
            if (_isCtrlDown && veryCloseToSteppedRotation) {
                auto revolutionParts = int(Math::Round(TAU / S_Gizmo_StepRot));
                auto part = int(Math::Round(tmpRotationAngle / S_Gizmo_StepRot));
                int2 frac = SimplifyFraction(part, revolutionParts);
                ret += " = " + part + " / " + revolutionParts + " revs = " + frac.x + " / " + frac.y;
            } else if (_isCtrlDown && IsCloseToSpecialAngle(tmpRotationAngle)) {
                ret += " = " + GetSpecialAngleName(tmpRotationAngle);
            }
            return ret;
        } else if (hoveringAlt){
            auto uv = this.altMoveUV * -1;
            auto bd1 = lastClosestAxis == Axis::Z ? 8. : 32.;
            auto bd2 = lastClosestAxis == Axis::X ? 8. : 32.;
            string ax1 = lastClosestAxis != Axis::Z ? "Z" : "Y";
            string ax2 = lastClosestAxis != Axis::X ? "X" : "Y";
            if (componentIx == 0) return ax1 + ": " + FmtMoveMeters((uv.x), bd1);
            else if (componentIx == 1) return ax2 + ": " + FmtMoveMeters((uv.y), bd2);
            return "UNKNOWN componentIx == " + componentIx;
        }
        auto len = tmpPos.Length();
        auto blockDimension = lastClosestAxis == Axis::Y ? 8. : 32.;
        return FmtMoveMeters(len, blockDimension);
    }

    string FmtMoveMeters(float dist, float blockDim) {
        string ret = tostring(Math::Round(dist, 2)) + " m";
        if (Math::Abs(dist) >= blockDim - 0.0001) {
            ret += " = " + tostring(Math::Round(dist / blockDim, 3)) + " blocks";
        }
        return ret;
    }

    vec2 dragDelta;
    vec2 lastDragDelta;

    vec3 camPos;
    mat4 camLoc;
    vec4 pwrPos;
    mat4 camTranslate;
    mat4 camRotation;
    mat4 camTR;
    mat4 camPersp;
    mat4 camProj;

    vec3 pivotPoint;
    // euler angles of rotation to apply to local coords
    vec3 rotPivot;

    vec3 get_PivotPointOrDest() {
        return pivotAnimator !is null ? destinationPivotPoint : pivotPoint;
    }


    void IncrStep() {
        if (mode == Gizmo::Mode::Rotation) {
            if (S_Gizmo_StepRot > PI / 49.) return;
            S_Gizmo_StepRot *= 2.0;
            ShowRotStepStatusMsg();
        } else if (mode == Gizmo::Mode::Translation) {
            if (S_Gizmo_TranslateCtrlStepDist > 33) return;
            S_Gizmo_TranslateCtrlStepDist *= 2.0;
            ShowMoveStepStatusMsg();
        }
    }

    void DecrStep() {
        if (mode == Gizmo::Mode::Rotation) {
            if (S_Gizmo_StepRot < PI / 1000.) return;
            S_Gizmo_StepRot /= 2.0;
            ShowRotStepStatusMsg();
        } else if (mode == Gizmo::Mode::Translation) {
            if (S_Gizmo_TranslateCtrlStepDist < 0.05) return;
            S_Gizmo_TranslateCtrlStepDist /= 2.0;
            ShowMoveStepStatusMsg();
        }
    }

    void ShowRotStepStatusMsg() {
        ShowStatusMsg("Rot Step: " + Math::Round(Math::ToDeg(S_Gizmo_StepRot), 2) + " °");
    }

    void ShowMoveStepStatusMsg() {
        ShowStatusMsg("Move Step: " + Math::Round(S_Gizmo_TranslateCtrlStepDist, 2) + " m");
    }

    TempNvgText@ statusMsg;

    void ShowStatusMsg(const string &in msg) {
        if (statusMsg !is null) statusMsg.Destroy();
        @statusMsg = TempNvgText(msg);
    }


    void SwapMode() {
        mode = mode == Gizmo::Mode::Rotation ? Gizmo::Mode::Translation : Gizmo::Mode::Rotation;
        ResetTmp();
    }


    // MARK: Draw All

    void DrawAll() {
        auto cam = Camera::GetCurrent();
        if (cam is null) return;
        camLoc = mat4(cam.Location);
        camPos = vec3(camLoc.tx, camLoc.ty, camLoc.tz);
        camRotation = mat4::Translate(camPos * -1.) * camLoc;
        camRotation = mat4::Inverse(camRotation);

        DrawWindow();
#if DEV
        DrawDebugWindow();
#endif

        // don't draw if behind camera, or gizmo outside screen bounds
        auto posToScreen = Camera::ToScreen(pos);
        if (posToScreen.z >= 0) return;
        if (posToScreen.x < 20 || posToScreen.x > g_screen.x - 20 || posToScreen.y < 20 || posToScreen.y > g_screen.y - 20) return;

        DrawCirclesManual(pos, scale * scaleExtraCoef);
#if DEV
        DrawBoundingBox();
        DrawNextApplicationPreview();
#endif
    }

    void Render() {
        DrawAll();
    }

    bool useGlobal = false;

    void DrawWindow() {
        bool isRotMode = mode == Gizmo::Mode::Rotation;
        auto btnSize = Math::Max(64.0, g_screen.y * .05) * g_scale;
        auto btnSize2 = vec2(btnSize);
        auto btnSize2Thinner = btnSize2 * vec2(0.75, 1.);
        auto nbBtns = 8.5;
        auto itemSpacing = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        UI::SetNextWindowPos(.5 * (g_screen.x - (btnSize + itemSpacing.x) * nbBtns) / g_scale, 24 * g_scale, UI::Cond::Appearing);

        if (UI::Begin("###gz-tlbr-"+name, UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize)) {
            // UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(g_screen.y * 0.005));
            UI::PushFont(g_BigFont);
            if (UI::Button(isRotMode ? Icons::Dribbble : Icons::ArrowsAlt, btnSize2)) {
                SwapMode();
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
                UI::OpenPopup("gizmo-toolbar-edit-pivot");
            }
            if (UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right)) {
                CyclePivot();
            }
            AddSimpleTooltip("Edit Pivot (RMB to cycle)" + NewIndicator);

            UI::SameLine();
            if (UI::Button(Icons::Camera, btnSize2)) {
                FocusCameraOn(pos);
            }
            AddSimpleTooltip("Reset Camera");

            UI::SameLine();
            UI::BeginDisabled(!CanRepeatAppDiff);
            if (UI::Button(Icons::Repeat, btnSize2Thinner)) {
                RepeatLastApplicationDiff();
            }
            AddSimpleTooltip("Repeat Last Difference" + NewIndicator);
            UI::EndDisabled();

            UI::SameLine();
            if (UI::Button(Icons::Cog, btnSize2)) {
                UI::OpenPopup("gizmo-toolbar-settings");
            }
            AddSimpleTooltip("Settings" + NewIndicator);

            UI::SameLine();
            if (UI::Button(Icons::Undo, btnSize2Thinner)) {
                Undo();
            }
            AddSimpleTooltip("Undo");

            UI::SameLine();
            if (UI::Button(Icons::Check, btnSize2)) {
                RunApply(false);
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
            /*
            [L][M][R]
            [B][M][T]
            [B][M][F]
             */
            UI::SeparatorText("Corners etc.");
            UI::AlignTextToFramePadding();
            TextSameLine("X");
            SetPivotAxisButton(Axis::X, "L##gzPvX", -1.);
            SetPivotAxisButton(Axis::X, "M##gzPvX", 0.);
            SetPivotAxisButton(Axis::X, "R##gzPvX", 1., true);
            UI::AlignTextToFramePadding();
            TextSameLine("Y");
            SetPivotAxisButton(Axis::Y, "B##gzPvY", -1.);
            SetPivotAxisButton(Axis::Y, "M##gzPvY", 0.);
            SetPivotAxisButton(Axis::Y, "T##gzPvY", 1., true);
            UI::AlignTextToFramePadding();
            TextSameLine("Z");
            SetPivotAxisButton(Axis::Z, "B##gzPvZ", -1.);
            SetPivotAxisButton(Axis::Z, "M##gzPvZ", 0.);
            SetPivotAxisButton(Axis::Z, "F##gzPvZ", 1., true);

            // for slope platform, pivot should be 2/3 up, maybe + 2m, and normal height is 3*8.
            UI::SeparatorText("Slopes & Curves");
            SetPivotAxisButtonAbs(Axis::Y, "Y=2", 2.);
            SetPivotAxisButtonAbs(Axis::Y, "Y=8", 8.);
            AddSimpleTooltip("BiSlope");
            SetPivotAxisButtonAbs(Axis::Y, "Y=16", 16.);
            AddSimpleTooltip("Slope2");
            SetPivotAxisButtonAbs(Axis::Y, "Y=18", 18.);
            AddSimpleTooltip("Slope2 + 2m");
            SetPivotAxisButtonAbs(Axis::Y, "Y=24", 24., true);
            AddSimpleTooltip("Slope3");

            UI::SeparatorText("Pivot Point");
            vec3 newPivot = UI::InputFloat3("##gizmo-pivot", pivotPoint);
            if (newPivot != pivotPoint) {
                SetPivotPoint(newPivot, false);
                FocusCameraOn(pos, false);
            }

            UI::SeparatorText("Rotation Pivot");

            if (UI::Button("Yaw 45°")) {
                rotPivot.y = Math::ToRad(45.);
            }

            vec3 newRotPivot = UX::InputAngles3("##gizmo-rot-pivot", rotPivot);
            if (newRotPivot != rotPivot) {
                rotPivot = newRotPivot;
            }

            UX::CloseCurrentPopupIfMouseFarAway();
            UI::EndPopup();

        }

        if (UI::BeginPopup("gizmo-toolbar-settings")) {
            // UI::Text("Gizmo Settings");
            UI::SeparatorText("Gizmo Startup Settings");
            // S_Gizmo_ApplyBlockOffset = UI::Checkbox("Apply Block Offset of 0.25", S_Gizmo_ApplyBlockOffset);
            // AddSimpleTooltip("The cursor for freeblocks is raised up 0.25, so this will apply a -0.25 offset when starting the gizmo. \\$<\\$i\\$f80HOWEVER,\\$> this is somewhat inconsistent. This setting allows you to disable the feature.");
            S_Gizmo_MoveCameraOnStart = UI::Checkbox("Move Camera when Starting Gizmo", S_Gizmo_MoveCameraOnStart);

#if DEV
            UI::SeparatorText("Debug");
            D_Gizmo_DrawBoundingBox = UI::Checkbox("Draw Bounding Box", D_Gizmo_DrawBoundingBox);
#endif

            UI::SeparatorText("Translate");
            UI::SetNextItemWidth(100);
            S_Gizmo_TranslateCtrlStepDist = UI::InputFloat("Step Size (Holding Ctrl)", S_Gizmo_TranslateCtrlStepDist, 0.25);
            AddSimpleTooltip("Default: 0.25.\nHow much to move (step size) when holding Ctrl while dragging (translation).");
            if (UX::ButtonSameLine("0.25##gzts")) S_Gizmo_TranslateCtrlStepDist = 0.25;
            if (UX::ButtonSameLine("1.0##gzts")) S_Gizmo_TranslateCtrlStepDist = 1.0;
            if (UX::ButtonSameLine("2.0##gzts")) S_Gizmo_TranslateCtrlStepDist = 2.0;
            if (UX::ButtonSameLine("4.0##gzts")) S_Gizmo_TranslateCtrlStepDist = 4.0;
            if (UI::Button("8.0##gzts")) S_Gizmo_TranslateCtrlStepDist = 8.0;

            UI::SeparatorText("Rotate");
            UI::Text("Current Rotation Step: " + Text::Format("%.2f", Math::ToDeg(S_Gizmo_StepRot)) + " ° (" + (Math::Round(TAU  / S_Gizmo_StepRot, 1)) + " steps per revolution)");

            UI::BeginDisabled(S_Gizmo_StepRot > PI / 49.);
            if (UX::ButtonSameLine("Increase Step Size")) {
                IncrStep();
            }
            UI::EndDisabled();
            UI::BeginDisabled(S_Gizmo_StepRot < PI / 1000.);
            if (UX::ButtonSameLine("Decrease Step Size")) {
                DecrStep();
            }
            UI::EndDisabled();
            if (UI::Button("Reset##stepRot")) {
                S_Gizmo_StepRot = PI / 48.;
            }

            UI::SeparatorText("Initialization");
            UI::Text("Ctrl + Shift + LMB: Edit picked block/item.");
            UI::TextWrapped("Ctrl + Shift + RMB: Place current block/item at picked block/item in gizmo." + NewIndicator);

            UI::SeparatorText("Controls");
            UI::Text("Escape: cancel and exit gizmo.");
            UI::Text("Hold Shift to slow down rotation speed.");
            UI::Text("Hold Ctrl: Snap translation and rotation.");
            UI::Text("Hold Alt: Move camera.");
            UI::Text("Right click (on gizmo): Cycle between Translate and Rotate.");
            UI::Text("Right click (while dragging): Reset.");
            UI::Text("Right click Pivot button: Edit pivot." + NewIndicator);

            UI::SeparatorText("Hotkeys" + NewIndicator);
            S_Gizmo_InvertApplyModifier = UI::Checkbox("Invert Apply Modifier", S_Gizmo_InvertApplyModifier);
            AddSimpleTooltip("When true: pressing Apply hotkey (default Space) will Apply and Continue; and holding shift will Apply and exit gizmo.");
            Gizmo::DrawHotkeysTable();

            UI::SeparatorText("Help");
            UI::Text("Problem: \\$iBlocks appear 25cm too high");
            UI::Indent();
            UI::TextWrapped("Solution: Exit gizmo. Under the \\$<\\$8f8Custom Cursor\\$> tab: Enable \"Do Not Offset Block in Cursor Preview\" (might reset if done from gizmo mode), and set \"FreeBlock Vertical Offset\" to 0. Then select a new block in ghost mode to refresh cursor and try again.");
            UI::Unindent();

            UX::CloseCurrentPopupIfMouseFarAway();
            UI::EndPopup();
        }

        // end window
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

    void DrawBoundingBox() {
        if (!D_Gizmo_DrawBoundingBox) return;
        nvg::StrokeWidth(2);
        // vec3 p1 = pos + bbMidPoint;
        // nvgDrawPointRing(p1, 5., cBlack75);
        // vec3 p2 = p1 + bbHalfDiag;
        // nvgDrawPointRing(p2, 5., cBlack75);
        // nvgDrawPath({p1, p2}, cMagenta);
        nvgDrawBlockBox(GetMatrix(), bbHalfDiag*2, cSkyBlue);
        // nvgDrawBlockBox(GetCursorMat(), bbHalfDiag*2, cLimeGreen50);
    }

    float d;

    void FocusCameraOn(vec3 p, bool setDist = true) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto camState = Editor::GetCurrentCamState(editor);
        camState.Pos = p;
        if (setDist) camState.TargetDist = this.scale * 4.5;
        Editor::SetCamAnimationGoTo(camState);
    }

    void SetPivotAxisButton(Axis axis, const string &in label, float relPos, bool isLast = false) {
        if (UI::Button(label)) {
            MovePivotTo(axis, relPos);
        }
        if (!isLast) UI::SameLine();
    }

    void SetPivotAxisButtonAbs(Axis axis, const string &in label, float absPos, bool isLast = false) {
        if (UI::Button(label)) {
            SetPivotPoint(AxisToVec(axis) * absPos + AxisToAntiVec(axis) * PivotPointOrDest);
        }
        if (!isLast) UI::SameLine();
    }


    void MovePivotTo(Axis axis, float uvAmt, bool animate = true, bool addToUndo = true) {
        SetPivotPoint(
            AxisToVec(axis) * (uvAmt * bbHalfDiag + bbMidPoint - GetItemCursorPivot()) + AxisToAntiVec(axis) * PivotPointOrDest,
            animate, addToUndo
        );
    }

    void MovePivotToVisual(Axis axis, float uvAmt) {
        // based on camera, find closest local axis, and move pivot in that direction
        auto m = GetMatrix();
        auto axisSign = ClosestMatchingAxesRelativeToCamera()[axis];
        MovePivotTo(Axis(axisSign.x), uvAmt * float(axisSign.y));
    }

    vec2[][] _camLocAngleSign_Last;

    // returns (localAxis, sign)[] where the index is a camera's axis
    int3[] ClosestMatchingAxesRelativeToCamera() {
        auto m = mat4::Inverse(rot);
        // for each camera axis:
        //   for each local axis:
        //     find the angle between the two
        // for each output axis:
        //   find the local axis with the smallest angle
        //   store the local axis and the sign of the angle
        //   set the angel in all axes so it won't be chosen again
        // return the array

        // camLocAngleSign[camAxis][localAxis] = vec2(angle, sign)
        vec2[][] camLocAngleSign;
        camLocAngleSign.Resize(3);
        for (uint i = 0; i < 3; i++) {
            camLocAngleSign[i].Resize(3);
        }
        for (uint i = 0; i < 3; i++) {
            vec3 v1 = (m * AxisToVec(Axis(i))).xyz; // - (m * vec3()).xyz;
            for (uint j = 0; j < 3; j++) {
                auto dot = Math::Dot(v1, (camRotation * AxisToVec(Axis(j)) * (j == 0 ? -1. : 1.)).xyz);
                camLocAngleSign[j][i] = vec2(Math::Abs(dot), Sign(dot));
            }
        }
        _camLocAngleSign_Last = camLocAngleSign;

        int3[] ret;
        ret.Resize(3);
        int[] remaining = {0, 1, 2};
        while (remaining.Length > 0) {
            float maxDot = 0.;
            int bestLocAxis = -1;
            int bestCamAxis = -1;
            for (uint i = 0; i < 3; i++) {
                for (uint j = 0; j < 3; j++) {
                    if (camLocAngleSign[i][j].x > maxDot) {
                        maxDot = camLocAngleSign[i][j].x;
                        bestLocAxis = j;
                        bestCamAxis = i;
                    }
                }
            }
            // ret[i] = int2(minAxis, int(camLocAngleSign[i][minAxis].y));
            // for (uint j = 0; j < 3; j++) {
            //     camLocAngleSign[j][minAxis].x = -1.;
            // }
            ret[bestCamAxis] = int3(bestLocAxis, int(camLocAngleSign[bestCamAxis][bestLocAxis].y), int(camLocAngleSign[bestCamAxis][bestLocAxis].x * 10000));
            // camLocAngleSign[bestOutAxis][bestInAxes].x = -1.;
            for (uint j = 0; j < 3; j++) {
                camLocAngleSign[bestCamAxis][j].x = -1.;
                camLocAngleSign[j][bestLocAxis].x = -1.;
            }
            remaining.RemoveAt(remaining.Find(bestCamAxis));
        }


        return ret;
    }

    void DrawDebugClosestMatchingAxes() {
        auto axesSign = ClosestMatchingAxesRelativeToCamera();
        for (uint i = 0; i < 3; i++) {
            UI::Text(tostring(Axis(i)) + " -> " + tostring(Axis(axesSign[i].x)) + " * " + axesSign[i].y + " (dot: " + (float(axesSign[i].z) / 10000.0 * axesSign[i].y) + ")");
        }

        // _camLocAngleSign_Last
        for (uint i = 0; i < 3; i++) {
            for (uint j = 0; j < 3; j++) {
                UI::Text(tostring(Axis(i)) + " -> " + tostring(Axis(j)) + " = " + _camLocAngleSign_Last[i][j].x + " * " + _camLocAngleSign_Last[i][j].y);
            }
        }

        if (UI::Button("Update Cam")) {
            _camRotation = camRotation;
        }
        mat4 camHelperMat = mat4::Translate(pos) * _camRotation;
        nvg::StrokeWidth(2);
        nvgDrawCoordHelpers(camHelperMat, 5.0);
    }

    mat4 _camRotation;

    float Sign(float v) {
        return v < 0. ? -1. : 1.;
    }

    // MARK: $store Macros

    GizmoState@ appliedL;
    GizmoState@ appliedL2;

    void SaveAppliedPosition() {
        if (appliedL2 is null) {
            @appliedL2 = GetState();
        } else if (appliedL is null) {
            @appliedL = GetState();
        } else {
            @appliedL2 = appliedL;
            @appliedL = GetState();
        }
    }

    bool get_CanRepeatAppDiff() {
        return appliedL !is null && appliedL2 !is null;
    }

    void RepeatLastApplicationDiff() {
        if (!CanRepeatAppDiff) return;
        auto next = GetNextApplicationMat();
        auto unPivoted = next * mat4::Translate(pivotPoint);
        auto newPos = vec3(unPivoted.tx, unPivoted.ty, unPivoted.tz);
        auto newRot = mat4::Inverse(mat4::Translate(newPos * -1.) * unPivoted);
        pos = newPos;
        rot = newRot;
        history.InsertLast(GetState());
        RunApply(true);
        FocusCameraOn(pos, false);
    }

    mat4 GetNextApplicationMat() {
        if (!CanRepeatAppDiff) return mat4::Identity();
        // each matrix is made up of a translation, a rotation, and a pivot point
        // note: we need to rotate the change in position by the rotation so twisting repetitions work.
        // get lPos relative to l2Pos in local space
        auto aLMat = appliedL.GetMatrix();
        // return (aLMat * mat4::Inverse(appliedL2.GetMatrix())) * aLMat;
        return aLMat * mat4::Inverse(appliedL2.GetMatrix()) * aLMat;
    }

    void DrawNextApplicationPreview() {
        if (!D_Gizmo_DrawBoundingBox) return;
        if (appliedL2 is null) return;
        nvgDrawBlockBox(appliedL2.GetMatrix(), bbHalfDiag*2, cLimeGreen50);
        if (appliedL is null) return;
        nvgDrawBlockBox(appliedL.GetMatrix(), bbHalfDiag*2, cOrange);
        auto mDelta = appliedL.GetMatrix() * mat4::Inverse(appliedL2.GetMatrix());

        auto next1 = mDelta * appliedL.GetMatrix();
        nvgDrawBlockBox(next1, bbHalfDiag*2, cRed);
        auto next2 = mDelta * next1;
        nvgDrawBlockBox(next2, bbHalfDiag*2, cBlue);
        nvgDrawBlockBox(GetNextApplicationMat() * mat4::Translate(-1.), bbHalfDiag*2, cYellow);

        auto n1Pos = vec3(next1.tx, next1.ty, next1.tz);
        auto unPivoted = next1 * mat4::Translate(pivotPoint);
        auto newPos = vec3(unPivoted.tx, unPivoted.ty, unPivoted.tz);
        nvgDrawPointRing(n1Pos, 5., cRed);
        nvgDrawPointRing(newPos, 5., cYellow);
        auto newRot = (mat4::Translate(newPos * -1.) * unPivoted);

    }

    void RunApply(bool andCont = false) {
        ApplyTmpRotation();
        ApplyTmpTranslation();
        SaveAppliedPosition();
        if (history.Length > 0) {
            history[history.Length - 1].nbPlaced++;
        }
        if (andCont) {
            onApplyAndCont();
        } else {
            onApply();
        }
    }

#if DEV
    void DrawDebugWindow() {
        if (UI::Begin("Gizmo Debug", UI::WindowFlags::NoTitleBar | UI::WindowFlags::AlwaysAutoResize)) {
            UI::Text("Gizmo Debug");
            UI::SeparatorText("Data");
            UI::Text("Rot: ");
            UX::DrawMat4SameLine(rot);
            UI::Text("Pos: " + pos.ToString());
            UI::Text("tmpPos: " + tmpPos.ToString());
            UI::Text("tmpRot: ");
            UX::DrawMat4SameLine(tmpRot);
            UI::Text("Pivot: " + pivotPoint.ToString());


            UI::SeparatorText("Camera");
            UI::Text("CamLoc: ");
            UX::DrawMat4SameLine(camLoc);

            // DrawDebugClosestMatchingAxes();

            UI::SeparatorText("BB");
            UI::Text("bbMidPoint: " + bbMidPoint.ToString());
            UI::Text("bbHalfDiag: " + bbHalfDiag.ToString());
            UI::Text("modelOffset: " + modelOffset.ToString());

            UI::SeparatorText("Rendering");
            UI::Text("scale: " + scale);

            UI::SeparatorText("Repeat");
            UI::Text(appliedL !is null ? "AppliedL: " + appliedL.ToString() : "AppliedL: null");
            UI::Text(appliedL2 !is null ? "AppliedL2: " + appliedL2.ToString() : "AppliedL2: null");
        }
        UI::End();
    }
#endif
}

const quat ROT_Q_AROUND_UP = quat(UP, HALF_PI);
const quat ROT_Q_AROUND_FWD = quat(BACKWARD, HALF_PI);

// atan(4/32);
const double ANGLE_HALF_BI_SLOPE = 0.12435499454676;
// atan(8/32);
const double ANGLE_BI_SLOPE = 0.24497866312686;
// atan(16/32);
const double ANGLE_SLOPE2 = 0.4636476090008;
// atan(24/32);
const double ANGLE_SLOPE3 = 0.6435011087933;

bool IsCloseToSpecialAngle(float rad) {
    float tolerance = 0.00001;
    rad = Math::Abs(rad);
    return Math::Abs(rad - ANGLE_HALF_BI_SLOPE) < tolerance || Math::Abs(rad - ANGLE_BI_SLOPE) < tolerance || Math::Abs(rad - ANGLE_SLOPE2) < tolerance || Math::Abs(rad - ANGLE_SLOPE3) < tolerance;
}

string GetSpecialAngleName(float rad) {
    rad = Math::Abs(rad);
    if (Math::Abs(rad - ANGLE_HALF_BI_SLOPE) < 0.00001) return "Half Bi-Slope";
    if (Math::Abs(rad - ANGLE_BI_SLOPE) < 0.00001) return "Bi-Slope";
    if (Math::Abs(rad - ANGLE_SLOPE2) < 0.00001) return "Slope2";
    if (Math::Abs(rad - ANGLE_SLOPE3) < 0.00001) return "Slope3";
    return "Unknown";
}

float LockToAngles(float rad, float step) {
    float sign = rad < 0. ? -1. : 1.;
    rad = Math::Abs(rad);
    float dToStep = rad % step;
    float closest = rad - dToStep;
    if (dToStep > step * .5) {
        closest += step;
    }
    if (IsCloserToAThanB(rad, ANGLE_HALF_BI_SLOPE, closest)) {
        return ANGLE_HALF_BI_SLOPE * sign;
    } else if (IsCloserToAThanB(rad, ANGLE_BI_SLOPE, closest)) {
        return ANGLE_BI_SLOPE * sign;
    } else if (IsCloserToAThanB(rad, ANGLE_SLOPE2, closest)) {
        return ANGLE_SLOPE2 * sign;
    } else if (IsCloserToAThanB(rad, ANGLE_SLOPE3, closest)) {
        return ANGLE_SLOPE3 * sign;
    }
    return closest * sign;
}

bool IsCloserToAThanB(float val, float a, float b) {
    return Math::Abs(val - a) < Math::Abs(val - b);
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

int2 SimplifyFraction(int num, int denom) {
    // int sign = (num >= 0 ? 1 : -1) * (denom >= 0 ? 1 : -1);
    int gcd = GCD(Math::Abs(num), Math::Abs(denom));
    return int2(num / gcd, denom / gcd);
}

int GCD(int a, int b) {
    while (b != 0) {
        int t = b;
        b = a % b;
        a = t;
    }
    return a;
}
