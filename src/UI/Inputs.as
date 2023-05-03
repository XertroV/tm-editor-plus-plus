namespace UX {
    vec3 InputAngles3(const string &in label, vec3 angles, vec3 _default = vec3()) {
        auto val = Math::ToRad(UI::InputFloat3(label, Math::ToDeg(angles)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    vec2 InputAngles2(const string &in label, vec2 angles, vec2 _default = vec2()) {
        auto val = Math::ToRad(UI::InputFloat2(label, Math::ToDeg(angles)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    vec3 SliderAngles3(const string &in label, vec3 angles, float min = -180.0, float max = 180.0, const string &in format = "%.1f", vec3 _default = vec3()) {
        auto val = Math::ToRad(UI::SliderFloat3(label, Math::ToDeg(angles), min, max, format));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    vec2 SliderAngles2(const string &in label, vec2 angles, float min = -180.0, float max = 180.0, const string &in format = "%.1f", vec2 _default = vec2()) {
        auto val = Math::ToRad(UI::SliderFloat2(label, Math::ToDeg(angles), min, max, format));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    nat3 InputNat3(const string &in label, nat3 val) {
        auto x = UI::InputInt("(X) " + label, val.x);
        auto y = UI::InputInt("(Y) " + label, val.y);
        auto z = UI::InputInt("(Z) " + label, val.z);
        return nat3(x, y, z);
    }
}
