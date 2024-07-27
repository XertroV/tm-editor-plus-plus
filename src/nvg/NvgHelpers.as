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

void nvgDrawHorizGridHelper(vec3 worldPos, vec4 col, float strokeWidth, float gridSize = 32., int gridStepsOut = 1) {
    gridStepsOut = Math::Abs(gridStepsOut);
    nvg::Reset();
    nvg::BeginPath();
    nvg::StrokeWidth(strokeWidth);
    nvg::StrokeColor(col);
    float step = gridSize / 2.;
    float maxStep = step * gridStepsOut;
    for (int i = -gridStepsOut; i <= gridStepsOut; i++) {
        auto top = worldPos - vec3(-maxStep, 0, step * i);
        auto bottom = worldPos - vec3(maxStep, 0, step * i);
        auto left = worldPos - vec3(step * i, 0, -maxStep);
        auto right = worldPos - vec3(step * i, 0, maxStep);
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
vec3 nvgLastUv = vec3();

void nvgWorldPosReset() {
    nvgWorldPosLastVisible = false;
}

void nvgToWorldPos(vec3 &in pos, vec4 &in col = vec4(1)) {
    nvgLastWorldPos = pos;
    nvgLastUv = Camera::ToScreen(pos);
    if (nvgLastUv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    if (nvgWorldPosLastVisible)
        nvg::LineTo(nvgLastUv.xy);
    else
        nvg::MoveTo(nvgLastUv.xy);
    nvgWorldPosLastVisible = true;
    nvg::StrokeColor(col);
    nvg::Stroke();
    nvg::ClosePath();
    nvg::BeginPath();
    nvg::MoveTo(nvgLastUv.xy);
}

void nvgMoveToWorldPos(vec3 pos) {
    nvgLastWorldPos = pos;
    nvgLastUv = Camera::ToScreen(pos);
    if (nvgLastUv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    nvg::MoveTo(nvgLastUv.xy);
    nvgWorldPosLastVisible = true;
}

void nvgLineToWorldPos(vec3 pos) {
    nvgLastWorldPos = pos;
    nvgLastUv = Camera::ToScreen(pos);
    if (nvgLastUv.z > 0) {
        nvgWorldPosLastVisible = false;
        return;
    }
    nvg::LineTo(nvgLastUv.xy);
    nvgWorldPosLastVisible = true;
}


// left, up, dir are already translated and rotated! they are the end points
void nvgDrawCoordHelpers(vec3 &in pos, vec3 &in left, vec3 &in up, vec3 &in dir) {
    nvg::BeginPath();
    vec3 beforePos = nvgLastWorldPos;
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(up, cGreen);
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(dir, cBlue);
    nvgMoveToWorldPos(pos);
    nvgToWorldPos(left, cRed);
    nvgMoveToWorldPos(beforePos);
    nvg::ClosePath();
}

void nvgDrawCoordHelpers(mat4 &in m, float size = 10.) {
    vec3 pos =  (m * vec3()).xyz;
    vec3 up =   (m * (vec3(0,1,0) * size)).xyz;
    vec3 left = (m * (vec3(1,0,0) * size)).xyz;
    vec3 dir =  (m * (vec3(0,0,1) * size)).xyz;
    nvgDrawCoordHelpers(pos, left, up, dir);
}

void nvgDrawBlockBox(const mat4 &in m, const vec3 &in size, const vec4 &in strokeCol = cWhite, DrawFaces drawFaces = DrawFaces::All) {
    nvgDrawRect3d(m, size, strokeCol, drawFaces);
}

vec3[] lastFacePoints;

void nvgDrawPath(const array<vec3> &in path, const vec4 &in color = cWhite) {
    nvg::Reset();
    nvg::StrokeColor(color);
    nvg::StrokeWidth(2.0);
    vec3 prePos = nvgLastWorldPos;
    for (uint i = 0; i < path.Length; i++) {
        nvgToWorldPos(path[i], color);
    }
    nvgMoveToWorldPos(prePos);
}

void nvgDrawPointRing(const vec3 &in pos, float radius, const vec4 &in color = cWhite) {
    nvgMoveToWorldPos(pos);
    if (!nvgWorldPosLastVisible)
        return;
    nvg::BeginPath();
    nvg::Reset();
    nvg::StrokeColor(color);
    nvg::StrokeWidth(2.0);
    nvg::Circle(nvgLastUv.xy, radius);
    nvg::Stroke();
    nvg::ClosePath();
}




// this does not seem to be expensive
const float nTextStrokeCopies = 12;

vec2 nvgDrawTextWithStroke(const vec2 &in pos, const string &in text, vec4 textColor = vec4(1), float strokeWidth = 2., vec4 strokeColor = cBlack75) {
    nvg::FontBlur(1.0);
    if (strokeWidth > 0.1) {
        nvg::FillColor(strokeColor);
        for (float i = 0; i < nTextStrokeCopies; i++) {
            float angle = TAU * float(i) / nTextStrokeCopies;
            vec2 offs = vec2(Math::Sin(angle), Math::Cos(angle)) * strokeWidth;
            nvg::Text(pos + offs, text);
        }
    }
    nvg::FontBlur(0.0);
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
    // don't return with +strokeWidth b/c it means we can't turn stroke on/off without causing readjustments in the UI
    return nvg::TextBounds(text);
}

vec2 nvgDrawTextWithShadow(const vec2 &in pos, const string &in text, vec4 textColor = vec4(1), float strokeWidth = 2., vec4 strokeColor = vec4(0, 0, 0, 1)) {
    nvg::FontBlur(1.0);
    if (strokeWidth > 0.0) {
        nvg::FillColor(strokeColor);
        float i = 1;
        float angle = TAU * float(i) / nTextStrokeCopies;
        vec2 offs = vec2(Math::Sin(angle), Math::Cos(angle)) * strokeWidth;
        nvg::Text(pos + offs, text);
    }
    nvg::FontBlur(0.0);
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
    // don't return with +strokeWidth b/c it means we can't turn stroke on/off without causing readjustments in the UI
    return nvg::TextBounds(text);
}

vec2 nvgDrawText(const vec2 &in pos, const string &in text, vec4 textColor = vec4(1)) {
    nvg::FontBlur(0.0);
    nvg::FillColor(textColor);
    nvg::Text(pos, text);
    // don't return with +strokeWidth b/c it means we can't turn stroke on/off without causing readjustments in the UI
    return nvg::TextBounds(text);
}
