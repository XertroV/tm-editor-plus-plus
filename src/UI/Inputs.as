namespace UX {
    shared vec3 InputAngles3(const string &in label, vec3 angles, vec3 _default = vec3()) {
        auto d1 = MathX::ToDeg(angles);
        auto d2 = UI::InputFloat3(label, d1);
        auto val = MathX::ToRad(d2);
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        // check if we actually changed anything
        if (MathX::Vec3Eq(d1, d2)) return angles;
        return val;
    }

    shared vec3 InputAngles3Raw(const string &in label, vec3 angles, vec3 _default = vec3()) {
        auto val = MathX::ToRad(UI::InputFloat3(label, MathX::ToDeg(angles)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    shared vec3 InputFloat3(const string &in label, vec3 val, vec3 _default = vec3()) {
        auto ret = UI::InputFloat3(label, val);
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return ret;
    }

    shared vec3 SliderFloat3(const string &in label, vec3 val, float min, float max, vec3 _default) {
        return SliderFloat3(label, val, min, max, "%.3f", _default);
    }

    shared vec3 SliderFloat3(const string &in label, vec3 val, float min, float max, const string &in fmt = "%.3f", vec3 _default = vec3()) {
        auto ret = UI::SliderFloat3(label, val, min, max, fmt);
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return ret;
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
    }

    shared nat2 InputNat2(const string &in label, nat2 val) {
        UI::SetNextItemWidth(100.);
        auto newX = UI::InputText("##" + label + "n2x", tostring(val.x));
        UI::SameLine();
        UI::SetNextItemWidth(100.);
        auto newY = UI::InputText(label + "##n2y", tostring(val.y));
        try {
            val.x = Text::ParseUInt(newX);
        } catch {}
        try {
            val.y = Text::ParseUInt(newY);
        } catch {}
        return val;
    }

    shared quat InputQuat(const string &in label, quat val, quat _default = quat(0., 0., 0., 1.)) {
        auto ret = Vec4ToQuat(UI::InputFloat4(label, QuatToVec4(val)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return ret;
    }
}
