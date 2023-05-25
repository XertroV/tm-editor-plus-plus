namespace UX {
    shared vec3 InputAngles3(const string &in label, vec3 angles, vec3 _default = vec3()) {
        auto val = MathX::ToRad(UI::InputFloat3(label, MathX::ToDeg(angles)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    shared vec2 InputAngles2(const string &in label, vec2 angles, vec2 _default = vec2()) {
        auto val = MathX::ToRad(UI::InputFloat2(label, MathX::ToDeg(angles)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    shared vec3 SliderAngles3(const string &in label, vec3 angles, float min = -180.0, float max = 180.0, const string &in format = "%.1f", vec3 _default = vec3()) {
        auto val = MathX::ToRad(UI::SliderFloat3(label, MathX::ToDeg(angles), min, max, format));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    shared vec2 SliderAngles2(const string &in label, vec2 angles, float min = -180.0, float max = 180.0, const string &in format = "%.1f", vec2 _default = vec2()) {
        auto val = MathX::ToRad(UI::SliderFloat2(label, MathX::ToDeg(angles), min, max, format));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    shared nat3 InputNat3XYZ(const string &in label, nat3 val) {
        auto x = UI::InputInt("(X) " + label, val.x);
        auto y = UI::InputInt("(Y) " + label, val.y);
        auto z = UI::InputInt("(Z) " + label, val.z);
        return nat3(x, y, z);
    }

    shared nat3 InputNat3(const string &in label, nat3 val) {
        return Vec3ToNat3(UI::InputFloat3(label, Nat3ToVec3(val)));
        // auto x = UI::InputInt("(X) " + label, val.x);
        // auto y = UI::InputInt("(Y) " + label, val.y);
        // auto z = UI::InputInt("(Z) " + label, val.z);
        // return nat3(x, y, z);
    }

    shared quat InputQuat(const string &in label, quat val) {
        return Vec4ToQuat(UI::InputFloat4(label, QuatToVec4(val)));
    }
}
