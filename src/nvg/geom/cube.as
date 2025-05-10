const vec3[] cubeVertices = {
    vec3(0, 0, 0),
    vec3(1, 0, 0),
    vec3(1, 1, 0),
    vec3(0, 1, 0),
    vec3(0, 0, 1),
    vec3(1, 0, 1),
    vec3(1, 1, 1),
    vec3(0, 1, 1)
};

const int2[] cubeEdges = {
    int2(0, 1),
    int2(1, 2),
    int2(2, 3),
    int2(3, 0),
    int2(4, 5),
    int2(5, 6),
    int2(6, 7),
    int2(7, 4),
    int2(0, 4),
    int2(1, 5),
    int2(2, 6),
    int2(3, 7)
};

const uint[][] cubeFaces = {
    {0, 1, 2, 3},
    {4, 5, 6, 7},
    {0, 1, 5, 4},
    {2, 3, 7, 6},
    {1, 2, 6, 5},
    {0, 3, 7, 4}
};

const vec3[] cubeNormals = {
    vec3(0, 0, -1),
    vec3(0, 0, 1),
    vec3(0, -1, 0),
    vec3(0, 1, 0),
    vec3(1, 0, 0),
    vec3(-1, 0, 0)
};

const vec3[] faceMidpoints = {
    vec3(0.5, 0.5, 0),
    vec3(0.5, 0.5, 1),
    vec3(0.5, 0, 0.5),
    vec3(0.5, 1, 0.5),
    vec3(1, 0.5, 0.5),
    vec3(0, 0.5, 0.5)
};

void drawCubeFace(const mat4 &in m, uint faceIx, const vec4 &in strokeCol = cWhite, bool shadeFace = false) {
    vec3 p0 = (m * cubeVertices[cubeFaces[faceIx][0]]).xyz;
    auto rot = mat4::Translate((m * vec3()).xyz * -1.) * m;
    auto camPos = Camera::GetCurrentPosition();
    vec3 dirToCam = (camPos - p0).Normalized();
    auto camDot = Math::Dot((rot * cubeNormals[faceIx]).xyz, dirToCam);
    bool facingCam = camDot >= 0;

    nvg::Reset();
    nvg::LineCap(nvg::LineCapType::Round);
    nvg::LineJoin(nvg::LineCapType::Round);
    nvg::BeginPath();
    nvg::StrokeWidth(facingCam ? 2.0 : 1.0);
    nvg::StrokeColor(facingCam ? strokeCol : cBlack25);
    // if (facingCam) nvg::FillColor(Math::Lerp(cLimeGreen50, cSkyBlue50, camDot * .5 + .5) * vec4(1, 1, 1, .44));
    // else
    nvg::FillColor(cBlack50);
    // trace("camDot: " + camDot);
    nvgMoveToWorldPos(p0);
    for (uint i = 1; i < 4; i++) {
        vec3 p = (m * cubeVertices[cubeFaces[faceIx][i]]).xyz;
        nvgLineToWorldPos(p);
    }
    nvgLineToWorldPos(p0);
    if (shadeFace) {
        nvg::Fill();
    }
    nvg::Stroke();
    nvg::ClosePath();

    nvg::BeginPath();

    // return;

    // nvg::StrokeWidth(facingCam ? 2.0 : 0.0);
    // auto midpoint = (m * getFaceMidpoint(faceIx)).xyz;
    // nvgMoveToWorldPos(midpoint);
    // nvgLineToWorldPos(midpoint + cubeNormals[faceIx] * 8.);
    // nvg::Stroke();
    // nvg::ClosePath();
}

enum DrawFaces {
    All,
    Visible,
    NotVisible
}

uint[]@ getCubeFaceBackToFront(const mat4 &in m, DrawFaces drawFaces = DrawFaces::All) {
    uint[] faceOrder = {0, 1, 2, 3, 4, 5};
    vec3 camPos = Camera::GetCurrentPosition();
    // vec3 dirToCam = (camPos - (m * vec3(.5)).xyz).Normalized();
    auto rot = mat4::Translate((m * vec3()).xyz * -1.) * m;

    float[] faceDists = {
        Math::Dot((rot * cubeNormals[0]).xyz, (camPos - (m * faceMidpoints[0]).xyz)),
        Math::Dot((rot * cubeNormals[1]).xyz, (camPos - (m * faceMidpoints[1]).xyz)),
        Math::Dot((rot * cubeNormals[2]).xyz, (camPos - (m * faceMidpoints[2]).xyz)),
        Math::Dot((rot * cubeNormals[3]).xyz, (camPos - (m * faceMidpoints[3]).xyz)),
        Math::Dot((rot * cubeNormals[4]).xyz, (camPos - (m * faceMidpoints[4]).xyz)),
        Math::Dot((rot * cubeNormals[5]).xyz, (camPos - (m * faceMidpoints[5]).xyz))
    };

    float tf;
    uint tu;
    for (uint i = 0; i < 6; i++) {
        for (uint j = i + 1; j < 6; j++) {
            if (faceDists[i] < faceDists[j]) {
                tf = faceDists[i];
                faceDists[i] = faceDists[j];
                faceDists[j] = tf;
                tu = faceOrder[i];
                faceOrder[i] = faceOrder[j];
                faceOrder[j] = tu;
            }
        }
    }

    if (drawFaces != DrawFaces::All) {
        for (int i = 5; i >= 0; i--) {
            if (faceDists[i] > 0 ^^ (drawFaces == DrawFaces::Visible)) {
                faceDists.RemoveAt(i);
                faceOrder.RemoveAt(i);
            }
        }
    }

    return faceOrder;
}


vec3 getFaceMidpoint(uint faceIx) {
    vec3 sum = vec3();
    for (uint i = 0; i < 4; i++) {
        sum += cubeVertices[cubeFaces[faceIx][i]];
    }
    return sum / 4.;
}

void nvgDrawRect3d(const mat4 &in m, vec3 size, const vec4 &in col = cWhite, DrawFaces drawFaces = DrawFaces::All, bool shadeFrontFace = false) {
    mat4 smat = m * mat4::Scale(size);
    auto faceOrder = getCubeFaceBackToFront(smat, drawFaces);
    for (uint i = 0; i < faceOrder.Length; i++) {
        drawCubeFace(smat, faceOrder[i], col, shadeFrontFace && faceOrder[i] == 1);
    }
}
void nvgDrawRect3d(vec3 pos, vec3 size, const vec4 &in col = cWhite, DrawFaces drawFaces = DrawFaces::All) {
    nvgDrawRect3d(mat4::Translate(pos), size, col, drawFaces);
}
