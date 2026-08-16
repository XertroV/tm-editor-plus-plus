namespace Repeat {
    enum PolygonShape {
        Regular,
        Star,
        Circle
    }

    enum PolygonOrient {
        Keep,
        Tangent,
        Outward
    }

    enum PolygonPreset {
        Custom,
        Triangle,
        Square,
        Pentagon,
        Hexagon,
        Heptagon,
        Octagon,
        Decagon,
        Dodecagon,
        Pentagram,
        Hexagram,
        Heptagram,
        Octagram,
        Circle32
    }

    vec3 RegularPolygonVertex(int i, int n, float radius) {
        if (n <= 0) return vec3();
        float ang = float(TAU) * float(i) / float(n);
        return vec3(Math::Cos(ang) * radius, 0.0, Math::Sin(ang) * radius);
    }

    int PolygonEdgeEnd(int i, int n, int k) {
        if (n <= 0) return 0;
        int step = k < 1 ? 1 : k;
        int r = (i + step) % n;
        if (r < 0) r += n;
        return r;
    }

    int PolygonStepFor(PolygonShape shape, int k) {
        if (shape == PolygonShape::Star) return Math::Max(k, 2);
        return 1;
    }

    mat4 PolygonItemXf(const vec3 &in offset, const vec3 &in tangent, const mat4 &in layoutRot, PolygonOrient orient, const mat4 &in itemRot) {
        if (orient == PolygonOrient::Keep) return itemRot;

        vec3 y = (layoutRot * vec3(0, 1, 0)).xyz;
        if (y.LengthSquared() < 1e-12) y = vec3(0, 1, 0);
        y = y.Normalized();

        if (orient == PolygonOrient::Outward) {
            vec3 x = offset;
            x = x - y * Math::Dot(x, y);
            if (x.LengthSquared() < 1e-12) x = (layoutRot * vec3(1, 0, 0)).xyz;
            if (x.LengthSquared() < 1e-12) x = vec3(1, 0, 0);
            x = x.Normalized();
            vec3 z = Math::Cross(x, y);
            if (z.LengthSquared() < 1e-12) z = vec3(0, 0, 1);
            z = z.Normalized();
            return mat4(mat3(x, y, z)) * itemRot;
        }

        vec3 z = tangent;
        z = z - y * Math::Dot(z, y);
        if (z.LengthSquared() < 1e-12) z = (layoutRot * vec3(0, 0, 1)).xyz;
        if (z.LengthSquared() < 1e-12) z = vec3(0, 0, 1);
        z = z.Normalized();
        vec3 x = Math::Cross(y, z);
        if (x.LengthSquared() < 1e-12) x = vec3(1, 0, 0);
        x = x.Normalized();
        return mat4(mat3(x, y, z)) * itemRot;
    }

    void CalcPolygonMatrices(mat4[]@ mats, const vec3 &in center, float radius, int n, int k, int perEdge, PolygonShape shape, const mat4 &in layoutRot, PolygonOrient orient, const mat4 &in itemRot) {
        if (mats is null) return;
        mats.RemoveRange(0, mats.Length);
        if (n <= 0) return;

        bool withEdges = shape != PolygonShape::Circle;
        int step = PolygonStepFor(shape, k);
        int p = withEdges ? Math::Max(perEdge, 1) : 1;

        vec3[] offs;
        for (int i = 0; i < n; i++) {
            offs.InsertLast((layoutRot * RegularPolygonVertex(i, n, radius)).xyz);
        }

        for (int i = 0; i < n; i++) {
            vec3 tan;
            if (withEdges) {
                tan = offs[PolygonEdgeEnd(i, n, step)] - offs[i];
            } else {
                float ang = float(TAU) * float(i) / float(n);
                tan = (layoutRot * vec3(-Math::Sin(ang), 0.0, Math::Cos(ang))).xyz;
            }
            mats.InsertLast(mat4::Translate(center + offs[i]) * PolygonItemXf(offs[i], tan, layoutRot, orient, itemRot));
        }

        if (!withEdges || p <= 1) return;

        for (int i = 0; i < n; i++) {
            int j = PolygonEdgeEnd(i, n, step);
            vec3 a = offs[i];
            vec3 b = offs[j];
            vec3 tan = b - a;
            for (int s = 1; s < p; s++) {
                float t = float(s) / float(p);
                vec3 off = a + tan * t;
                mats.InsertLast(mat4::Translate(center + off) * PolygonItemXf(off, tan, layoutRot, orient, itemRot));
            }
        }
    }

    string PolygonShapeLabel(int v) {
        if (v == 0) return "Regular";
        if (v == 1) return "Star";
        if (v == 2) return "Circle";
        return "?";
    }

    string PolygonOrientLabel(int v) {
        if (v == 0) return "Keep";
        if (v == 1) return "Tangent (+Z along edge)";
        if (v == 2) return "Outward (+X = radial)";
        return "?";
    }

    string PolygonPresetLabel(int v) {
        if (v == 0) return "Custom";
        if (v == 1) return "Triangle";
        if (v == 2) return "Square";
        if (v == 3) return "Pentagon";
        if (v == 4) return "Hexagon";
        if (v == 5) return "Heptagon";
        if (v == 6) return "Octagon";
        if (v == 7) return "Decagon";
        if (v == 8) return "Dodecagon";
        if (v == 9) return "Pentagram {5/2}";
        if (v == 10) return "Hexagram {6/2}";
        if (v == 11) return "Heptagram {7/2}";
        if (v == 12) return "Octagram {8/3}";
        if (v == 13) return "Circle (32)";
        return "?";
    }

    void ApplyPolygonPreset(PolygonPreset preset, PolygonShape &out shape, int &out n, int &out k) {
        shape = PolygonShape::Regular;
        k = 1;
        if (preset == PolygonPreset::Triangle) { n = 3; }
        else if (preset == PolygonPreset::Square) { n = 4; }
        else if (preset == PolygonPreset::Pentagon) { n = 5; }
        else if (preset == PolygonPreset::Hexagon) { n = 6; }
        else if (preset == PolygonPreset::Heptagon) { n = 7; }
        else if (preset == PolygonPreset::Octagon) { n = 8; }
        else if (preset == PolygonPreset::Decagon) { n = 10; }
        else if (preset == PolygonPreset::Dodecagon) { n = 12; }
        else if (preset == PolygonPreset::Pentagram) { shape = PolygonShape::Star; n = 5; k = 2; }
        else if (preset == PolygonPreset::Hexagram) { shape = PolygonShape::Star; n = 6; k = 2; }
        else if (preset == PolygonPreset::Heptagram) { shape = PolygonShape::Star; n = 7; k = 2; }
        else if (preset == PolygonPreset::Octagram) { shape = PolygonShape::Star; n = 8; k = 3; }
        else if (preset == PolygonPreset::Circle32) { shape = PolygonShape::Circle; n = 32; k = 1; }
        else { n = n; }
    }

    PolygonPreset MatchPolygonPreset(PolygonShape shape, int n, int k) {
        if (shape == PolygonShape::Regular && k <= 1) {
            if (n == 3) return PolygonPreset::Triangle;
            if (n == 4) return PolygonPreset::Square;
            if (n == 5) return PolygonPreset::Pentagon;
            if (n == 6) return PolygonPreset::Hexagon;
            if (n == 7) return PolygonPreset::Heptagon;
            if (n == 8) return PolygonPreset::Octagon;
            if (n == 10) return PolygonPreset::Decagon;
            if (n == 12) return PolygonPreset::Dodecagon;
        }
        if (shape == PolygonShape::Star) {
            if (n == 5 && k == 2) return PolygonPreset::Pentagram;
            if (n == 6 && k == 2) return PolygonPreset::Hexagram;
            if (n == 7 && k == 2) return PolygonPreset::Heptagram;
            if (n == 8 && k == 3) return PolygonPreset::Octagram;
        }
        if (shape == PolygonShape::Circle && n == 32) return PolygonPreset::Circle32;
        return PolygonPreset::Custom;
    }

    [Setting hidden]
    PolygonShape poly_Shape = PolygonShape::Regular;
    [Setting hidden]
    PolygonPreset poly_Preset = PolygonPreset::Hexagon;
    [Setting hidden]
    int poly_N = 6;
    [Setting hidden]
    int poly_K = 2;
    [Setting hidden]
    float poly_Radius = 32.;
    [Setting hidden]
    int poly_PerEdge = 1;
    [Setting hidden]
    vec3 poly_Rot = vec3();
    [Setting hidden]
    bool poly_UseItemAlignment = false;
    [Setting hidden]
    PolygonOrient poly_Orient = PolygonOrient::Keep;

    class PolygonRepeat : RepeatMethod {
        PolygonRepeat(TabGroup@ p) {
            super(p, "Polygons");
        }

        void UpdateMatrices() override {
            RepeatMethod::UpdateMatrices();
            mat4 layoutRot = EulerToMat(poly_Rot);
            if (poly_UseItemAlignment) {
                layoutRot = itemOffsetRot * layoutRot;
            }
            mat4 itemRot = m_IgnoreItemRotation ? EulerToMat(item_RotCustom) : itemOffsetRot;
            int k = poly_Shape == PolygonShape::Star ? poly_K : 1;
            CalcPolygonMatrices(matricies, itw_Pos, poly_Radius, poly_N, k, poly_PerEdge, poly_Shape, layoutRot, poly_Orient, itemRot);
        }

        void DrawHelpers(bool withLinesBetween) override {
            RepeatMethod::DrawHelpers(withLinesBetween);
            if (!S_ShowRepeatHelpers) return;
            if (poly_Shape == PolygonShape::Circle) return;
            int n = poly_N;
            if (n <= 1) return;
            int step = PolygonStepFor(poly_Shape, poly_K);
            mat4 layoutRot = EulerToMat(poly_Rot);
            if (poly_UseItemAlignment) layoutRot = itemOffsetRot * layoutRot;
            nvg::Reset();
            nvg::BeginPath();
            nvg::StrokeWidth(2.0);
            for (int i = 0; i < n; i++) {
                vec3 a = itw_Pos + (layoutRot * RegularPolygonVertex(i, n, poly_Radius)).xyz;
                vec3 b = itw_Pos + (layoutRot * RegularPolygonVertex(PolygonEdgeEnd(i, n, step), n, poly_Radius)).xyz;
                nvgMoveToWorldPos(a);
                nvgToWorldPos(b, vec4(1, 0.55, 0.1, 0.85));
            }
        }

        void DrawControls(CGameCtnEditorFree@ editor) override {
            RepeatMethod::DrawControls(editor);

            UI::TextWrapped("Places items on a polygon around the picked item (center). Stars are self-intersecting {n/k}.");

            int presetI = DrawArbitraryEnum("Preset", int(poly_Preset), 14, function(int v) {
                return Repeat::PolygonPresetLabel(v);
            });
            if (presetI != int(poly_Preset)) {
                poly_Preset = PolygonPreset(presetI);
                if (poly_Preset != PolygonPreset::Custom) {
                    ApplyPolygonPreset(poly_Preset, poly_Shape, poly_N, poly_K);
                }
            }

            poly_Shape = PolygonShape(DrawArbitraryEnum("Shape", int(poly_Shape), 3, function(int v) {
                return Repeat::PolygonShapeLabel(v);
            }));

            poly_UseItemAlignment = UI::Checkbox("Start from Item Alignment", poly_UseItemAlignment);
            if (m_IgnoreItemRotation) {
                item_RotCustom = UX::SliderAngles3("Item Rot (Deg)##poly-custom", item_RotCustom);
            } else {
                UI::BeginDisabled();
                item_Rot = UX::SliderAngles3("Item Rot (Deg)##poly-main", item_Rot);
                UI::EndDisabled();
            }
            poly_Rot = UX::SliderAngles3("Polygon Rot (Deg)", poly_Rot);
            poly_Orient = PolygonOrient(DrawArbitraryEnum("Orient", int(poly_Orient), 3, function(int v) {
                return Repeat::PolygonOrientLabel(v);
            }));

            UI::Separator();
            poly_Radius = Math::Max(UI::InputFloat("Radius", poly_Radius, 1.0), 0.0);
            poly_N = Math::Clamp(UI::InputInt("n (sides / points)", poly_N, 1), 3, 256);
            if (poly_Shape == PolygonShape::Star) {
                int kMax = Math::Max(2, (poly_N - 1) / 2);
                poly_K = Math::Clamp(UI::InputInt("k (step)", poly_K, 1), 2, kMax);
            }
            if (poly_Shape != PolygonShape::Circle) {
                int pMax = Math::Max(1, 10000 / poly_N);
                poly_PerEdge = Math::Clamp(UI::InputInt("Per edge", poly_PerEdge, 1), 1, pMax);
                UI::TextWrapped("Per edge includes vertices. 1 = vertices only.");
            }

            poly_Preset = MatchPolygonPreset(poly_Shape, poly_N, poly_Shape == PolygonShape::Star ? poly_K : 1);

            UpdateMatrices();
            DrawHelpers(false);
            vec3 origWorld = vec3();
            if (lastPickedItem !is null && lastPickedItem.AsItem() !is null) {
                origWorld = lastPickedItem.AsItem().AbsolutePositionInMap;
            }
            int nbCreating = int(CountPlaceablePoses(matricies, origWorld));
            UI::AlignTextToFramePadding();
            UI::Text("Total Points: " + matricies.Length + "  (placing " + nbCreating + ", max 10,000)");
            UI::BeginDisabled(lastPickedItem is null);
            if (UI::Button(Text::Format("Create %d Items", nbCreating))) {
                RunItemCreation(editor, lastPickedItem.AsItem());
            }
            UI::EndDisabled();
        }
    }
}
