namespace Repeat {
    enum SphereOrient {
        Keep,
        Outward,
        Inward
    }

    // i in [0, n). Golden angle = pi * (3 - sqrt(5)).
    vec3 FibonacciSphereUnit(int i, int n) {
        if (n <= 1) return vec3(0, 1, 0);
        float y = 1.0 - (float(i) / float(n - 1)) * 2.0;
        float r = Math::Sqrt(Math::Max(0.0, 1.0 - y * y));
        float theta = Math::PI * (3.0 - Math::Sqrt(5.0)) * float(i);
        return vec3(Math::Cos(theta) * r, y, Math::Sin(theta) * r);
    }

    // Rotation that maps local +Y onto `normal`.
    mat4 BasisYAlong(const vec3 &in normal) {
        vec3 y = normal;
        if (y.LengthSquared() < 1e-12) y = vec3(0, 1, 0);
        y = y.Normalized();
        vec3 ref = Math::Abs(y.y) < 0.999 ? vec3(0, 1, 0) : vec3(0, 0, 1);
        vec3 x = Math::Cross(y, ref);
        if (x.LengthSquared() < 1e-12) {
            ref = vec3(1, 0, 0);
            x = Math::Cross(y, ref);
        }
        x = x.Normalized();
        vec3 z = Math::Cross(x, y).Normalized();
        return mat4(mat3(x, y, z));
    }

    void CalcSphereMatrices(mat4[]@ mats, const vec3 &in center, float radius, int n, const mat4 &in sphereRot, SphereOrient orient, const mat4 &in itemRot) {
        if (mats is null) return;
        mats.RemoveRange(0, mats.Length);
        if (n <= 0) return;
        for (int i = 0; i < n; i++) {
            vec3 offset = (sphereRot * (FibonacciSphereUnit(i, n) * radius)).xyz;
            vec3 worldPos = center + offset;
            mat4 itemXf = itemRot;
            if (orient == SphereOrient::Outward || orient == SphereOrient::Inward) {
                vec3 nrm = offset;
                if (nrm.LengthSquared() < 1e-12) nrm = vec3(0, 1, 0);
                if (orient == SphereOrient::Inward) nrm = nrm * -1.;
                itemXf = BasisYAlong(nrm) * itemRot;
            }
            mats.InsertLast(mat4::Translate(worldPos) * itemXf);
        }
    }

    bool ShouldSkipRepeatPose(const vec3 &in worldPos, const vec3 &in origWorld) {
        return MathX::Vec3Within(worldPos, origWorld, 0.0001);
    }

    uint CountPlaceablePoses(const mat4[]@ poses, const vec3 &in origWorld) {
        if (poses is null) return 0;
        uint n = 0;
        for (uint i = 0; i < poses.Length; i++) {
            if (!ShouldSkipRepeatPose((poses[i] * vec3()).xyz, origWorld)) n++;
        }
        return n;
    }

    string SphereOrientLabel(int v) {
        if (v == 0) return "Keep";
        if (v == 1) return "Outward (+Y = normal)";
        if (v == 2) return "Inward (+Y = -normal)";
        return "?";
    }

    [Setting hidden]
    float sphere_Radius = 32.;
    [Setting hidden]
    int sphere_Count = 64;
    [Setting hidden]
    vec3 sphere_Rot = vec3();
    [Setting hidden]
    SphereOrient sphere_Orient = SphereOrient::Keep;
    [Setting hidden]
    bool sphere_UseItemAlignment = false;

    class SphereRepeat : RepeatMethod {
        SphereRepeat(TabGroup@ p) {
            super(p, "Sphere");
        }

        void UpdateMatrices() override {
            RepeatMethod::UpdateMatrices();
            mat4 sphereRot = EulerToMat(sphere_Rot);
            if (sphere_UseItemAlignment) {
                sphereRot = itemOffsetRot * sphereRot;
            }
            mat4 itemRot = m_IgnoreItemRotation ? EulerToMat(item_RotCustom) : itemOffsetRot;
            CalcSphereMatrices(matricies, itw_Pos, sphere_Radius, sphere_Count, sphereRot, sphere_Orient, itemRot);
        }

        void DrawControls(CGameCtnEditorFree@ editor) override {
            RepeatMethod::DrawControls(editor);

            UI::TextWrapped("Places items on a sphere around the picked item (center). Fibonacci distribution.");

            sphere_UseItemAlignment = UI::Checkbox("Start from Item Alignment", sphere_UseItemAlignment);
            if (m_IgnoreItemRotation) {
                item_RotCustom = UX::SliderAngles3("Item Rot (Deg)##sphere-custom", item_RotCustom);
            } else {
                UI::BeginDisabled();
                item_Rot = UX::SliderAngles3("Item Rot (Deg)##sphere-main", item_Rot);
                UI::EndDisabled();
            }
            sphere_Rot = UX::SliderAngles3("Sphere Rot (Deg)", sphere_Rot);
            sphere_Orient = SphereOrient(DrawArbitraryEnum("Orient", int(sphere_Orient), 3, function(int v) {
                return Repeat::SphereOrientLabel(v);
            }));

            UI::Separator();
            sphere_Radius = Math::Max(UI::InputFloat("Radius", sphere_Radius, 1.0), 0.0);
            sphere_Count = Math::Clamp(UI::InputInt("Count", sphere_Count, 1), 1, 10000);

            UI::AlignTextToFramePadding();
            UI::Text("Total Points: " + sphere_Count + " (Maximum: 10,000)");

            UpdateMatrices();
            DrawHelpers(false);
            vec3 origWorld = vec3();
            if (lastPickedItem !is null && lastPickedItem.AsItem() !is null) {
                origWorld = lastPickedItem.AsItem().AbsolutePositionInMap;
            }
            int nbCreating = int(CountPlaceablePoses(matricies, origWorld));
            UI::BeginDisabled(lastPickedItem is null);
            if (UI::Button(Text::Format("Create %d Items", nbCreating))) {
                RunItemCreation(editor, lastPickedItem.AsItem());
            }
            UI::EndDisabled();
        }
    }
}
