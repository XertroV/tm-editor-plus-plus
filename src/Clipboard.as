enum CBTypes {
    Float3, Angles3, Nat3, Quat
}

Clipboard@ cbFloat3 = Clipboard(CBTypes::Float3);
Clipboard@ cbAngles3 = Clipboard(CBTypes::Angles3);
Clipboard@ cbNat3 = Clipboard(CBTypes::Nat3);
Clipboard@ cbQuat = Clipboard(CBTypes::Quat);

[Setting hidden]
vec3 S_ClipboardFloat3;
[Setting hidden]
vec3 S_ClipboardAngles3;
[Setting hidden]
vec3 S_ClipboardNat3;
[Setting hidden]
vec4 S_ClipboardQuat;


class Clipboard {
    CBTypes type;
    string cbTypeStr;
    string cbPopupTitle;
    Clipboard(CBTypes type) {
        this.type = type;
        cbTypeStr = tostring(type);
        cbPopupTitle = "E++ Clipboard \\$aaa("+cbTypeStr+")";
        startnew(CoroutineFunc(this.LoadSavedValues));
    }

    void LoadSavedValues() {
        yield();
        yield();
        yield();
        if (type == CBTypes::Float3) {
            savedVec3 = S_ClipboardFloat3;
        } else if (type == CBTypes::Angles3) {
            savedVec3 = S_ClipboardAngles3;
        } else if (type == CBTypes::Nat3) {
            savedNat3 = Vec3ToNat3(S_ClipboardNat3);
        } else if (type == CBTypes::Quat) {
            savedQuat = Vec4ToQuat(S_ClipboardQuat);
        }
    }

	vec3 savedVec3;
	nat3 savedNat3;
	quat savedQuat;

    vec3 tmpVec3;
    quat tmpQuat;
    nat3 tmpNat3;

    Clipboard@ With(vec3 v) {
        tmpVec3 = v;
        return this;
    }

    Clipboard@ With(quat q) {
        tmpQuat = q;
        return this;
    }

    Clipboard@ With(nat3 n) {
        tmpNat3 = n;
        return this;
    }

    bool wasHovered;

    Clipboard@ DrawClipboard(const string &in label) {
        UI::SameLine();
        UI::PushID(cbTypeStr+"."+label);
        UI::AlignTextToFramePadding();
        if (UI::Button("CB")) {
            UI::OpenPopup("copy-rclick##"+label);
        }
        AddSimpleTooltip(cbPopupTitle);
        if (UI::BeginPopup("copy-rclick##"+label)) {
            UI::Text(cbPopupTitle);
            UI::Dummy(vec2());
            if (type == CBTypes::Float3) {
                tmpVec3 = AddCopyPasteFloat3(label, tmpVec3);
                CopiableLabeledValue("\\$aaaCopied", savedVec3.ToString());
            } else if (type == CBTypes::Angles3) {
                tmpVec3 = AddCopyPasteAngles3(label, tmpVec3);
                CopiableLabeledValue("\\$aaaCopied", savedVec3.ToString());
            } else if (type == CBTypes::Nat3) {
                tmpNat3 = AddCopyPasteNat3(label, tmpNat3);
                CopiableLabeledValue("\\$aaaCopied", savedNat3.ToString());
            } else if (type == CBTypes::Quat) {
                tmpQuat = AddCopyPasteQuat(label, tmpQuat);
                CopiableLabeledValue("\\$aaaCopied", savedQuat.ToString());
            }
            AddSimpleTooltip("Click to copy to system clipboard");
            if (!UI::IsWindowFocused()) {
                UI::CloseCurrentPopup();
            }
            UI::EndPopup();
        }
        UI::PopID();
        return this;
    }

    vec3 GetVec3() {
        return tmpVec3;
    }
    nat3 GetNat3() {
        return tmpNat3;
    }
    quat GetQuat() {
        return tmpQuat;
    }


    vec3 AddCopyPasteFloat3(const string &in label, vec3 val) {

        UI::PushID(label);
        UI::PushID("Float3");

        UI::SameLine();
        if (UI::Button("Copy")) {
            savedVec3 = val;
            S_ClipboardFloat3 = val;
        }
        UI::SameLine();
        if (UI::ButtonColored("pX", hueRed)) {
            val.x = savedVec3.x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            val.y = savedVec3.y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pZ", hueBlue)) {
            val.z = savedVec3.z;
        }

        UI::PopID();
        UI::PopID();

        return val;
    }

    vec3 AddCopyPasteAngles3(const string &in label, vec3 degrees) {

        UI::PushID(label);
        UI::PushID("Angles3");

        UI::SameLine();
        if (UI::Button("Copy")) {
            savedVec3 = degrees;
            S_ClipboardAngles3 = degrees;
        }
        UI::SameLine();
        if (UI::ButtonColored("pP", hueRed)) {
            degrees.x = savedVec3.x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            degrees.y = savedVec3.y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pR", hueBlue)) {
            degrees.z = savedVec3.z;
        }

        UI::PopID();
        UI::PopID();

        return degrees;
    }

    nat3 AddCopyPasteNat3(const string &in label, nat3 val) {

        UI::PushID(label);
        UI::PushID("Nat3");

        UI::SameLine();
        if (UI::Button("Copy")) {
            savedNat3 = val;
            S_ClipboardNat3 = Nat3ToVec3(val);
        }
        UI::SameLine();
        if (UI::ButtonColored("pX", hueRed)) {
            val.x = savedNat3.x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            val.y = savedNat3.y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pZ", hueBlue)) {
            val.z = savedNat3.z;
        }

        UI::PopID();
        UI::PopID();

        return val;
    }

    quat AddCopyPasteQuat(const string &in label, quat val) {

        UI::PushID(label);
        UI::PushID("Quat");

        UI::SameLine();
        if (UI::Button("Copy")) {
            savedQuat = val;
            S_ClipboardQuat = QuatToVec4(val);
        }
        UI::SameLine();
        if (UI::ButtonColored("pX", hueRed)) {
            val.x = savedQuat.x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            val.y = savedQuat.y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pZ", hueBlue)) {
            val.z = savedQuat.z;
        }
        UI::SameLine();
        if (UI::ButtonColored("pW", 0, 0, .2)) {
            val.w = savedQuat.w;
        }

        UI::PopID();
        UI::PopID();

        return val;
    }
}
