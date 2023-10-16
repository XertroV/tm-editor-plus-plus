

void nvgCircleWorldPos(vec3 pos, vec4 col = vec4(1, .5, 0, 1)) {
    auto uv = Camera::ToScreen(pos);
    if (uv.z < 0) {
        nvg::Reset();
        nvg::BeginPath();
        nvg::FillColor(col);
        nvg::Circle(uv.xy, 5);
        nvg::Fill();
        nvg::ClosePath();
    }
}

void nvgCircleScreenPos(vec2 xy, vec4 col = vec4(1, .5, 0, 1), float radius = 5.) {
    nvg::Reset();
    nvg::BeginPath();
    nvg::FillColor(col);
    nvg::Circle(xy, radius);
    nvg::Fill();
    nvg::ClosePath();
}

void nvgDrawHorizGridHelper(vec3 worldPos, vec4 col, float strokeWidth, float gridSize = 32.) {
    nvg::Reset();
    nvg::BeginPath();
    nvg::StrokeWidth(strokeWidth);
    nvg::StrokeColor(col);
    auto origin = worldPos;
    vec3 stepV = vec3(gridSize, 0, gridSize);
    float step = gridSize / 2.;
    for (int i = -1; i < 2; i++) {
        auto top = worldPos - vec3(-step, 0, step * i);
        auto bottom = worldPos - vec3(step, 0, step * i);
        auto left = worldPos - vec3(step * i, 0, -step);
        auto right = worldPos - vec3(step * i, 0, step);
        nvgMoveToWorldPos(top);
        nvgToWorldPos(bottom, col);
        nvgMoveToWorldPos(left);
        nvgToWorldPos(right, col);
    }
}

// void nvgCircleWorldPos(vec3 pos, vec4 col, vec4 strokeCol) {
//     auto uv = Camera::ToScreen(pos);
//     if (uv.z < 0) {
//         nvg::BeginPath();
//         nvg::FillColor(col);
//         nvg::Circle(uv.xy, 8);
//         nvg::Fill();
//         nvg::ClosePath();
        // nvg::StrokeColor(strokeCol);
        // nvg::StrokeWidth(3);
        // nvg::Stroke();
//     }
// }

bool nvgWorldPosLastVisible = false;
vec3 nvgLastWorldPos = vec3();

void nvgWorldPosReset() {
    nvgWorldPosLastVisible = false;
}

void nvgToWorldPos(vec3 &in pos, vec4 &in col = vec4(1)) {
    nvgLastWorldPos = pos;
    auto uv = Camera::ToScreen(pos);
    if (uv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    if (nvgWorldPosLastVisible)
        nvg::LineTo(uv.xy);
    else
        nvg::MoveTo(uv.xy);
    nvgWorldPosLastVisible = true;
    nvg::StrokeColor(col);
    nvg::Stroke();
    nvg::ClosePath();
    nvg::BeginPath();
    nvg::MoveTo(uv.xy);
}

void nvgMoveToWorldPos(vec3 pos) {
    nvgLastWorldPos = pos;
    auto uv = Camera::ToScreen(pos);
    if (uv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    nvg::MoveTo(uv.xy);
    nvgWorldPosLastVisible = true;
}

void nvgDrawCoordHelpers(mat4 &in m, float size = 10.) {
    nvg::Reset();
    nvg::StrokeWidth(3.0);
    vec3 beforePos = nvgLastWorldPos;
    vec3 pos =  (m * vec3()).xyz;
    vec3 up =   (m * (vec3(0,1,0) * size)).xyz;
    vec3 left = (m * (vec3(1,0,0) * size)).xyz;
    vec3 dir =  (m * (vec3(0,0,1) * size)).xyz;
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(up, cGreen);
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(dir, cBlue);
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(left, cRed);
    nvgMoveToWorldPos(beforePos);
}

void nvgDrawBlockBox(mat4 &in m, vec3 size) {
    nvg::Reset();
    nvg::StrokeWidth(2.0);
    vec3 prePos = nvgLastWorldPos;
    vec3 pos = (m * vec3()).xyz;
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(pos);
    nvgToWorldPos((m * (size * vec3(1, 0, 0))).xyz);
    nvgToWorldPos((m * (size * vec3(1, 0, 1))).xyz);
    nvgToWorldPos((m * (size * vec3(0, 0, 1))).xyz);
    nvgToWorldPos(pos);
    nvgToWorldPos((m * (size * vec3(0, 1, 0))).xyz);
    nvgToWorldPos((m * (size * vec3(1, 1, 0))).xyz);
    nvgToWorldPos((m * (size * vec3(1, 1, 1))).xyz);
    nvgToWorldPos((m * (size * vec3(0, 1, 1))).xyz);
    nvgToWorldPos((m * (size * vec3(0, 1, 0))).xyz);
    nvgMoveToWorldPos((m * (size * vec3(1, 0, 0))).xyz);
    nvgToWorldPos((m * (size * vec3(1, 1, 0))).xyz);
    nvgMoveToWorldPos((m * (size * vec3(1, 0, 1))).xyz);
    nvgToWorldPos((m * (size * vec3(1, 1, 1))).xyz);
    nvgMoveToWorldPos((m * (size * vec3(0, 0, 1))).xyz);
    nvgToWorldPos((m * (size * vec3(0, 1, 1))).xyz);
    nvgMoveToWorldPos(prePos);
}



// this does not seem to be expensive
const float nTextStrokeCopies = 32;

void DrawTextWithStroke(const vec2 &in pos, const string &in text, vec4 textColor, float strokeWidth, vec4 strokeColor = vec4(0, 0, 0, 1)) {
    nvg::FillColor(strokeColor);
    for (float i = 0; i < nTextStrokeCopies; i++) {
        float angle = TAU * float(i) / nTextStrokeCopies;
        vec2 offs = vec2(Math::Sin(angle), Math::Cos(angle)) * strokeWidth;
        nvg::Text(pos + offs, text);
    }
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
}
