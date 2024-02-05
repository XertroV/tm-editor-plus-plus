namespace Editor {
    CamState@ GetCurrentCamState(CGameCtnEditorFree@ editor) {
        return CamState(editor.OrbitalCameraControl);
    }

    void UnlockCamera(CGameControlCameraEditorOrbital@ occ) {
        Dev::SetOffset(occ, GetOffset(occ, "m_TargetedPosition") + 0x18, vec2(-90000000)); // occ_MinXZ
        Dev::SetOffset(occ, GetOffset(occ, "m_TargetedPosition") + 0x20, vec2(90000000)); // occ_MaxXZ
        Dev::SetOffset(occ, GetOffset(occ, "m_TargetedPosition") + 0x28, vec2(-90000000, 90000000)); // occ_YBounds
        occ.m_MinDistance = 0.1;
    }

    void EnableCustomCameraInputs() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        editor.PluginMapType.EnableEditorInputsCustomProcessing = true;
        editor.PluginMapType.Camera.IgnoreCameraCollisions(true);
        editor.OrbitalCameraControl.m_MaxVAngle = TAU * 100;
        editor.OrbitalCameraControl.m_MinVAngle = -TAU * 100;
        startnew(Editor::DisableCustomCameraInputs);
    }

    void DisableCustomCameraInputs() {
        cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType.EnableEditorInputsCustomProcessing = false;
    }

    void SetCamTargetedPosition(vec3 pos) {
        cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType.CameraTargetPosition = pos;
        // if (MathX::Within(pos, vec3(0), g_MapBounds)) {
        // } else {
        //     cast<CGameCtnEditorFree>(GetApp().Editor).OrbitalCameraControl.m_TargetedPosition = pos;
        // }
    }

    void SetCamTargetedDistance(float dist) {
        cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType.CameraToTargetDistance = dist;
    }

    void SetCamOrbitalAngle(float h, float v) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return;
        editor.PluginMapType.CameraHAngle = h;
        editor.PluginMapType.CameraVAngle = v;
    }

    bool SetCamAnimationGoTo(vec2 lookAngleHV, vec3 position, float targetDist) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return false;
        Editor::EnableCustomCameraInputs();
        @CameraAnimMgr = AnimMgr(false, S_AnimationDuration);
        auto cam = editor.OrbitalCameraControl;
        @g_startCamState = CamState(cam);
        @g_endCamState = CamState(lookAngleHV.x, lookAngleHV.y, targetDist, position);
        return true;
    }

    bool SetCamAnimationGoTo(CamState@ cam) {
        return SetCamAnimationGoTo(cam.LookUV, cam.Pos, cam.TargetDist);
    }

    void FinalizeAnimationNow() {
        if (CameraAnimMgr is null) return;
        CameraAnimMgr.SetAt(1.0);
    }

    // via Miss
    void SetEditorOrbitalTarget(const vec3 &in pos) {
        auto editor = cast<CGameCtnEditorCommon>(GetApp().Editor);
        if (editor is null) {
            throw("Not in editor");
            return;
        }

        auto orbital = editor.OrbitalCameraControl;
        if (orbital is null) {
            throw("No orbital camera");
            return;
        }

        float h = (orbital.m_CurrentHAngle + Math::PI / 2) * -1;
        float v = orbital.m_CurrentVAngle;

        vec4 axis(1, 0, 0, 0);
        axis = axis * mat4::Rotate(v, vec3(0, 0, -1));
        axis = axis * mat4::Rotate(h, vec3(0, 1, 0));

        orbital.m_TargetedPosition = pos;

        vec3 newCameraPos = pos + axis.xyz * orbital.m_CameraToTargetDistance;
#if TMNEXT
        orbital.Pos = newCameraPos;
#else
        //TODO: This is correct for Maniaplanet, but probably not for Turbo
        Dev::SetOffset(orbital, 0x44, newCameraPos);
#endif
    }
}

AnimMgr@ CameraAnimMgr = AnimMgr(true);

Editor::CamState@ g_startCamState = Editor::CamState();
Editor::CamState@ g_endCamState = Editor::CamState();


void UpdateAnimAndCamera() {
    if (IsInEditor && CameraAnimMgr !is null && !CameraAnimMgr.IsDone && CameraAnimMgr.Update(true)) {
        UpdateCameraProgress(CameraAnimMgr.Progress);
        if (CameraAnimMgr.IsDone) Editor::DisableCustomCameraInputs();
    }
}

void UpdateCameraProgress(float t) {
    Editor::SetCamTargetedDistance(Math::Lerp(g_startCamState.TargetDist, g_endCamState.TargetDist, t));
    Editor::SetCamTargetedPosition(Math::Lerp(g_startCamState.Pos, g_endCamState.Pos, t));
    Editor::SetCamOrbitalAngle(
        MathX::SimplifyRadians(MathX::AngleLerp(g_startCamState.HAngle, g_endCamState.HAngle, t)),
        MathX::SimplifyRadians(MathX::AngleLerp(g_startCamState.VAngle, g_endCamState.VAngle, t))
    );
}


class AnimMgr {
    float t = 0.0;
    float animOut = 0.0;
    float animDuration;
    bool lastGrowing = false;
    uint lastGrowingChange = 0;
    uint lastGrowingCheck = 0;

    AnimMgr(bool startOpen = false, float duration = 250.0) {
        t = startOpen ? 1.0 : 0.0;
        animOut = t;
        animDuration = duration;
    }

    void SetAt(float newT) {
        t = newT;
        lastGrowingChange = Time::Now;
    }

    // return true if
    bool Update(bool growing, float clampMax = 1.0) {
        if (lastGrowingChange == 0) lastGrowingChange = Time::Now;
        if (lastGrowingCheck == 0) lastGrowingCheck = Time::Now;

        float delta = float(int(Time::Now) - int(lastGrowingCheck)) / animDuration;
        delta = Math::Min(delta, 0.2);
        lastGrowingCheck = Time::Now;

        float sign = growing ? 1.0 : -1.0;
        t = Math::Clamp(t + sign * delta, 0.0, 1.0);
        if (lastGrowing != growing) {
            lastGrowing = growing;
            lastGrowingChange = Time::Now;
        }

        // QuadOut
        animOut = -(t * (t - 2.));
        animOut = Math::Min(clampMax, animOut);
        return animOut > 0.;
    }

    float Progress {
        get {
            return animOut;
        }
    }

    bool IsDone {
        get {
            return animOut >= 1.0;
        }
    }
}
