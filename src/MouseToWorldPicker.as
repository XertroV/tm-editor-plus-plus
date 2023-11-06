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
        screen = GetScreenVec2();
        if (screen.x == 0 || screen.y == 0) return;
        uv = lastMousePos / (screen - 1.) * 2. - 1.;

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
