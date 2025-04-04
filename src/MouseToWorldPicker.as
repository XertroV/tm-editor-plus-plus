namespace Picker {
    vec2 screen;
    vec2 uv;
    vec3 camPos;
    mat4 projMat;
    mat4 invProj;
    vec4 invUv;
    vec3 normalizedPoint;
    vec3 normToScreen;
    vec3 pickDirection;
    vec3 normExtended;
    vec3 normExtendedToScreen;

    void RenderEarly() {
        screen = g_screen;
        if (screen.x == 0 || screen.y == 0) return;
        uv = g_lastMousePos / (screen - 1.) * 2. - 1.;

        auto cam = Camera::GetCurrent();
        if (cam !is null) {
            camPos = Camera::GetCurrentPosition();
            projMat = Camera::GetProjectionMatrix();
            invProj = mat4::Inverse(projMat);

            // smaller value is better! is not distance but more like 1/dist -- you get errors when it's too big
            invUv = invProj * vec3(uv, 0.01);
            normalizedPoint = invUv.xyz / invUv.w;
            pickDirection = (camPos - normalizedPoint).Normalized();
            // normToScreen = Camera::ToScreen(normalizedPoint);
            // normExtended = normalizedPoint + pickDirection * 10.;
            // normExtendedToScreen = Camera::ToScreen(normExtended);

            // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            // if (editor !is null) DrawTestPoints();
        }

        // DrawDebugWindow();
    }

    vec3 GetMouseToWorldAtHeight(float height) {
        return camPos - pickDirection * (camPos.y - height) / pickDirection.y;
    }

    vec3 GetMouseToWorldAtDist(float dist) {
        return camPos - pickDirection * dist;
    }

    vec2 lastMouseToWorldOnPlaneQuantizedUV;

    vec3 GetMouseToWorldOnPlane(vec3 planeNormal, vec3 planePos, float quantize = 0) {
        auto d = Math::Dot(pickDirection, planeNormal);
        if (Math::Abs(d) < 1e-5) return vec3(0);
        auto t = Math::Dot((camPos-planePos), planeNormal) / d;
        auto mouseWorldPosOnPlane = camPos - pickDirection * t;

        float u, v;
        vec3 uDir, vDir;
        // calculate UV and update lastMouseToWorldOnPlaneQuantizedUV. Not technically required if quantize = 0.
        {
            // Find two directions that are not parallel to the plane normal:
            vec3 anyVecNotParallel = Math::Abs(planeNormal.x) < 0.9 ? RIGHT : UP;

            // Construct a vector that’s guaranteed to be on the plane:
            uDir = Math::Cross(planeNormal, anyVecNotParallel).Normalized();

            // Construct the second direction vector in the plane:
            vDir = Math::Cross(planeNormal, uDir).Normalized();

            // Project the point onto the plane:
            vec3 planeVector = (mouseWorldPosOnPlane - planePos);
            u = Math::Dot(planeVector, uDir);
            v = Math::Dot(planeVector, vDir);

            lastMouseToWorldOnPlaneQuantizedUV.x = u;
            lastMouseToWorldOnPlaneQuantizedUV.y = v;
        }

        // return now if not quantized
        if (Math::Abs(quantize) < 1e-5) {
            return mouseWorldPosOnPlane;
        }

        // quantize
        u = Math::Round(u / quantize) * quantize;
        v = Math::Round(v / quantize) * quantize;

        lastMouseToWorldOnPlaneQuantizedUV.x = u;
        lastMouseToWorldOnPlaneQuantizedUV.y = v;

        // uv back to 3d space
        mouseWorldPosOnPlane = planePos + uDir*u + vDir*v;
        return mouseWorldPosOnPlane;
    }

    vec3 QuantizePointInGrid(vec3 targetPoint, vec3 eulerAngles, float quantize) {
        auto gridMat = (EulerToMat(eulerAngles));
        vec3 pos = (mat4::Inverse(gridMat) * targetPoint).xyz;
        pos.x = Math::Round(pos.x / quantize) * quantize;
        pos.y = Math::Round(pos.y / quantize) * quantize;
        pos.z = Math::Round(pos.z / quantize) * quantize;
        pos = ((gridMat) * pos).xyz;
        return GetMouseToWorldOnPlane((gridMat * UP).xyz, pos, quantize);
        return pos;
    }

    void DrawDebugWindow() {
        if (UI::Begin("mouse to world debug")) {
            LabeledValue("Screen", screen);
            LabeledValue("camPos", camPos.ToString());
            LabeledValue("uv", uv.ToString());
            LabeledValue("invUv", invUv.ToString());
            LabeledValue("normalizedPoint", normalizedPoint.ToString());
            // LabeledValue("normPlusCam", normPlusCam.ToString());
            LabeledValue("normToScreen", normToScreen.ToString());
            // LabeledValue("normPlusCamToScreen", normPlusCamToScreen.ToString());
            LabeledValue("pickDirection", pickDirection.ToString());
            LabeledValue("normExtended", normExtended.ToString());
            LabeledValue("normExtendedToScreen", normExtendedToScreen.ToString());
            // LabeledValue("groundPoint", groundPoint.ToString());
        }
        UI::End();
    }

    void DrawTestPoints() {
        // nvgDrawHorizGridHelper(groundPoint, vec4(1), 2, 32., 3);
        // nvgCircleScreenPos(normExtendedToScreen.xy, vec4(1, .5, 1, 1), 10);
        // nvgCircleWorldPos(groundPoint, vec4(1, .5, 0, 1));
        // nvgCircleScreenPos(normToScreen.xy, vec4(.5, .5, 1, 1), 4);
        // // uv, on top
        // nvgCircleScreenPos(UVToScreen(uv), vec4(.5, 1, .5, 1), 2);
    }

    vec2 UVToScreen(vec2 uv) {
        return screen * (uv * .5 + .5);
    }
}


vec2 GetScreenVec2() {
    return vec2(Draw::GetWidth(), Draw::GetHeight());
}
