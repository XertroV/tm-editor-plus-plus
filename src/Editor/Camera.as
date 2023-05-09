namespace Editor {
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

    void SetTargetedPosition(vec3 pos) {
        cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType.CameraTargetPosition = pos;
    }

    void SetTargetedDistance(float dist) {
        cast<CGameCtnEditorFree>(GetApp().Editor).PluginMapType.CameraToTargetDistance = dist;
    }

    void SetOrbitalAngle(float h, float v) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        editor.PluginMapType.CameraHAngle = h;
        editor.PluginMapType.CameraVAngle = v;
    }

    bool SetAnimationGoTo(vec2 lookAngleHV, vec3 position, float targetDist) {
        Editor::EnableCustomCameraInputs();
        @CameraAnimMgr = AnimMgr(false, S_AnimationDuration);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto cam = editor.OrbitalCameraControl;
        g_StartingHAngle = cam.m_CurrentHAngle;
        g_StartingVAngle = cam.m_CurrentVAngle;
        g_StartingPos = cam.m_TargetedPosition;
        g_StartingTargetDist = cam.m_CameraToTargetDistance;
        g_EndingHAngle = lookAngleHV.x; // * TAU / 4.0;
        g_EndingVAngle = lookAngleHV.y; // * TAU / 4.0;
        g_EndingPos = position;
        g_EndingTargetDist = targetDist;
        return true;
    }
}

AnimMgr@ CameraAnimMgr = AnimMgr(true);

float g_StartingHAngle = 0;
float g_StartingVAngle = 0;
float g_EndingHAngle = 0;
float g_EndingVAngle = 0;
float g_StartingTargetDist = 0;
float g_EndingTargetDist = 0;
vec3 g_StartingPos();
vec3 g_EndingPos();


void UpdateAnimAndCamera() {
    if (IsInEditor && CameraAnimMgr !is null && !CameraAnimMgr.IsDone && CameraAnimMgr.Update(true)) {
        UpdateCameraProgress(CameraAnimMgr.Progress);
        if (CameraAnimMgr.IsDone) Editor::DisableCustomCameraInputs();
    }
}

void UpdateCameraProgress(float t) {
    Editor::SetTargetedDistance(Math::Lerp(g_StartingTargetDist, g_EndingTargetDist, t));
    Editor::SetTargetedPosition(Math::Lerp(g_StartingPos, g_EndingPos, t));
    Editor::SetOrbitalAngle(
        MathX::SimplifyRadians(MathX::AngleLerp(g_StartingHAngle, g_EndingHAngle, t)),
        MathX::SimplifyRadians(MathX::AngleLerp(g_StartingVAngle, g_EndingVAngle, t))
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
