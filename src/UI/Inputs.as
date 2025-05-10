namespace UX {

    vec3 InputAngles3(const string &in label, vec3 angles, vec3 _default = vec3()) {
        auto d1 = MathX::ToDeg(angles);
        auto d2 = UI::InputFloat3(label, d1);
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }

        d2 = cbAngles3.With(d2).DrawClipboard(label).GetVec3();

        // check if we actually changed anything
        if (MathX::Vec3Eq(d1, d2)) return angles;

        return MathX::ToRad(d2);
    }

    vec3 InputAngles3Raw(const string &in label, vec3 angles, vec3 _default = vec3()) {
        auto d1 = MathX::ToDeg(angles);
        auto d2 = UI::InputFloat3(label, d1);
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }

        d2 = cbAngles3.With(d2).DrawClipboard(label).GetVec3();

        return MathX::ToRad(d2);
    }

    vec3 InputFloat3(const string &in label, vec3 val, vec3 _default = vec3()) {
        auto ret = UI::InputFloat3(label, val);
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }

        ret = cbFloat3.With(ret).DrawClipboard(label).GetVec3();

        return ret;
    }

    vec3 SliderFloat3(const string &in label, vec3 val, float min, float max, vec3 _default) {
        return SliderFloat3(label, val, min, max, "%.3f", _default);
    }

    vec3 SliderFloat3(const string &in label, vec3 val, float min, float max, const string &in fmt = "%.3f", vec3 _default = vec3()) {
        auto ret = UI::SliderFloat3(label, val, min, max, fmt);
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }

        ret = cbFloat3.With(ret).DrawClipboard(label).GetVec3();

        return ret;
    }

    vec2 InputAngles2(const string &in label, vec2 angles, vec2 _default = vec2()) {
        auto val = MathX::ToRad(UI::InputFloat2(label, MathX::ToDeg(angles)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    vec3 SliderAngles3(const string &in label, vec3 angles, float min = -180.0, float max = 180.0, const string &in format = "%.1f", vec3 _default = vec3()) {
        auto d1 = MathX::ToDeg(angles);
        auto d2 = UI::SliderFloat3(label, d1, min, max, format);

        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }

        d2 = cbAngles3.With(d2).DrawClipboard(label).GetVec3();

        return MathX::ToRad(d2);
    }

    vec2 SliderAngles2(const string &in label, vec2 angles, float min = -180.0, float max = 180.0, const string &in format = "%.1f", vec2 _default = vec2()) {
        auto val = MathX::ToRad(UI::SliderFloat2(label, MathX::ToDeg(angles), min, max, format));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }
        return val;
    }

    int2 InputInt2XYZ(const string &in label, int2 val) {
        auto x = UI::InputInt("(X) " + label, val.x);
        auto y = UI::InputInt("(Y) " + label, val.y);
        return int2(x, y);
    }

    int3 InputInt3XYZ(const string &in label, int3 val) {
        auto x = UI::InputInt("(X) " + label, val.x);
        auto y = UI::InputInt("(Y) " + label, val.y);
        auto z = UI::InputInt("(Z) " + label, val.z);
        return int3(x, y, z);
    }

    nat3 InputNat3XYZ(const string &in label, nat3 val) {
        auto x = UI::InputInt("(X) " + label, val.x);
        auto y = UI::InputInt("(Y) " + label, val.y);
        auto z = UI::InputInt("(Z) " + label, val.z);
        auto ret = nat3(x, y, z);

        ret = cbNat3.With(ret).DrawClipboard(label).GetNat3();

        return ret;
    }

    nat3 InputNat3(const string &in label, nat3 val, float width = -1.0) {
        auto availR = UI::GetContentRegionAvail();
        auto cur = UI::GetCursorPos();
        auto itemSp = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
        auto setSp = vec2(3);

        auto w = ((width <= 0.0 ? (availR.x + cur.x) * 0.715 : width) - setSp.x * 2.0) / 3.0;
        UI::PushItemWidth(w);
        UI::PushID(label);
        UI::PushStyleVar(UI::StyleVar::ItemSpacing, setSp);

        auto ret = val;

        // auto ret = Vec3ToNat3(UI::InputFloat3(label, Nat3ToVec3(val)));
        ret.x = UI::InputInt("##x", val.x, -1);
        UI::SameLine();
        ret.y = UI::InputInt("##y", val.y, -1);
        UI::SameLine();
        ret.z = UI::InputInt(label + "##z", val.z, -1);

        UI::PopStyleVar();
        UI::PopID();
        UI::PopItemWidth();

        ret = cbNat3.With(ret).DrawClipboard(label).GetNat3();

        return ret;
    }

    int3 InputInt3(const string &in label, int3 val, float width = -1.0) {
        return Nat3ToInt3(InputNat3(label, Int3ToNat3(val), width));
    }

    nat2 InputNat2(const string &in label, nat2 val) {
        UI::SetNextItemWidth(100.);
        auto newX = UI::InputText("##" + label + "n2x", tostring(val.x));
        UI::SameLine();
        UI::SetNextItemWidth(100.);
        auto newY = UI::InputText(label + "##n2y", tostring(val.y));
        Text::TryParseUInt(newX, val.x);
        Text::TryParseUInt(newY, val.y);
        // try {
        //     val.x = Text::ParseUInt(newX);
        // } catch {}
        // try {
        //     val.y = Text::ParseUInt(newY);
        // } catch {}
        return val;
    }

    quat InputQuat(const string &in label, quat val, quat _default = quat(0., 0., 0., 1.)) {
        auto ret = Vec4ToQuat(UI::InputFloat4(label, QuatToVec4(val)));
        UI::SameLine();
        if (UI::Button("Reset##"+label)) {
            return _default;
        }

        ret = cbQuat.With(ret).DrawClipboard(label).GetQuat();

        return ret;
    }

    // draw a checkbox that is directly linked to an offset bool of 4 bytes
    void CheckboxDevUint32(const string &in label, CMwNod@ nod, uint16 offset) {
        auto val = Dev::GetOffsetUint32(nod, offset) == 1;
        val = UI::Checkbox(label, val);
        Dev::SetOffset(nod, offset, uint32(val ? 1 : 0));
    }

    void InputIntDevUint32(const string &in label, CMwNod@ nod, uint16 offset, uint clampMin = 0, uint clampMax = 0xFFFFFFFF) {
        auto val = Dev::GetOffsetUint32(nod, offset);
        val = UI::InputInt(label, val);
        if (val < clampMin) val = clampMin;
        if (val > clampMax) val = clampMax;
        Dev::SetOffset(nod, offset, val);
    }

    bool InputIntSliderDevUint16(const string &in label, CMwNod@ nod, uint16 offset, uint16 min = 0, uint16 max = 0xFFFF, const string &in format = "%d") {
        auto val = Dev::GetOffsetUint16(nod, offset);
        uint16 val2 = UI::SliderInt(label, val, min, max, format, UI::SliderFlags::AlwaysClamp);
        Dev::SetOffset(nod, offset, val2);
        return val2 != val;
    }
}



int Tribox(const string &in label, int val) {
    UI::PushID(label);
    bool isAny = val < 0;
    bool isFalse = val == 0;
    bool isTrue = val == 1;
    auto isp = UI::GetStyleVarVec2(UI::StyleVar::ItemSpacing);
    if (TriboxBtn(Icons::Asterisk, isAny, -1, val))
        val = -1;
    UI::SameLine();
    UI::SetCursorPos(UI::GetCursorPos() - vec2(isp.x + 0.51, 0));
    if (TriboxBtn(Icons::Times, isFalse, 0, val))
        val = 0;
    UI::SameLine();
    UI::SetCursorPos(UI::GetCursorPos() - vec2(isp.x + 0.51, 0));
    if (TriboxBtn(Icons::Check, isTrue, 1, val))
        val = 1;
    UI::SameLine();
    UI::Text(label);
    UI::PopID();
    return val;
}

bool TriboxBtn(const string &in label, bool isDisabled, int forVal, int val) {
    UI::BeginDisabled(isDisabled);
    float h = 0.6;
    if (forVal == val) {
        h = forVal >= 0 ? forVal == 0 ? 0.1 : 0.3 : 0.56;
    }
    auto r = UI::ButtonColored(label, h);
    UI::EndDisabled();
    return r;
}
