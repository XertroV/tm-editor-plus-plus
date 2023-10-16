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

    vec3 groundPoint;

    void RenderEarly() {
        auto pos = lastMousePos;
        screen = GetScreenVec2();
        if (screen.x == 0 || screen.y == 0) return;
        uv = pos / (screen - 1.) * 2. - 1.;

        auto cam = Camera::GetCurrent();
        if (cam !is null) {
            camPos = Camera::GetCurrentPosition();
            projMat = Camera::GetProjectionMatrix();
            invProj = mat4::Inverse(projMat);

            // smaller value is better! is not distance but more like 1/dist -- you get errors when it's too big
            invUv = invProj * vec3(uv, 0.01);
            normalizedPoint = invUv.xyz / invUv.w;
            // normToScreen = Camera::ToScreen(normalizedPoint);
            pickDirection = (camPos - normalizedPoint).Normalized();
            // normExtended = normalizedPoint + pickDirection * 10.;
            // normExtendedToScreen = Camera::ToScreen(normExtended);

            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            float height = editor is null ? 8. : 8. * (int(editor.Cursor.Coord.y) - 8);
            // groundPoint = camPos - pickDirection * (camPos.y - 8.) / pickDirection.y;
            groundPoint = GetMouseToWorldAtHeight(height);
        }

        // DrawDebugWindow();
        // DrawTestPoints();
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
            LabeledValue("groundPoint", groundPoint.ToString());
        }
        UI::End();
    }

    void DrawTestPoints() {
        nvgDrawHorizGridHelper(groundPoint, vec4(1), 2);
        nvgCircleScreenPos(normExtendedToScreen.xy, vec4(1, .5, 1, 1), 10);
        nvgCircleWorldPos(groundPoint, vec4(1, .5, 0, 1));
        nvgCircleScreenPos(normToScreen.xy, vec4(.5, .5, 1, 1), 4);
        // uv, on top
        nvgCircleScreenPos(UVToScreen(uv), vec4(.5, 1, .5, 1), 2);
    }

    vec2 UVToScreen(vec2 uv) {
        return screen * (uv * .5 + .5);
    }
}


vec2 GetScreenVec2() {
    return vec2(Draw::GetWidth(), Draw::GetHeight());
}
