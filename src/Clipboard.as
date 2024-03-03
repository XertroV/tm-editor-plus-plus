namespace Clipboard {

    const float hueRed = 0.0;
    const float hueGreen = 0.33;
    const float hueBlue = 0.67;

	vec3 clipboardFloat3;
	vec3 clipboardAngles3;
	nat3 clipboardNat3;
	quat clipboardQuat;

    void SetFloat3(vec3 pos) {
    	clipboardFloat3 = pos;
        // print(pos);
    }

    vec3 GetFloat3() {
    	return clipboardFloat3;
    }

    void SetAngles3(vec3 degrees) {
    	clipboardAngles3 = degrees;
        // print(degrees);
    }

    vec3 GetAngles3() {
    	return clipboardAngles3;
    }

    void SetNat3(nat3 pos) {
    	clipboardNat3 = pos;
        // print(pos);
    }

    nat3 GetNat3() {
    	return clipboardNat3;
    }

    void SetQuat(quat rot) {
    	clipboardQuat = rot;
        // print(rot);
    }

    quat GetQuat() {
    	return clipboardQuat;
    }

    vec3 AddCopyPasteFloat3(const string &in label, vec3 val) {

        UI::PushID(label);
        UI::PushID("Float3");

        UI::SameLine();
        if (UI::Button("Copy")) {
            Clipboard::SetFloat3(val);
        }
        UI::SameLine();
        if (UI::ButtonColored("pX", hueRed)) {
            val.x = Clipboard::GetFloat3().x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            val.y = Clipboard::GetFloat3().y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pZ", hueBlue)) {
            val.z = Clipboard::GetFloat3().z;
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
            Clipboard::SetAngles3(degrees);
        }
        UI::SameLine();
        if (UI::ButtonColored("pP", hueRed)) {
            degrees.x = Clipboard::GetAngles3().x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            degrees.y = Clipboard::GetAngles3().y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pR", hueBlue)) {
            degrees.z = Clipboard::GetAngles3().z;
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
            Clipboard::SetNat3(val);
        }
        UI::SameLine();
        if (UI::ButtonColored("pX", hueRed)) {
            val.x = Clipboard::GetNat3().x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            val.y = Clipboard::GetNat3().y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pZ", hueBlue)) {
            val.z = Clipboard::GetNat3().z;
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
            Clipboard::SetQuat(val);
        }
        UI::SameLine();
        if (UI::ButtonColored("pX", hueRed)) {
            val.x = Clipboard::GetQuat().x;
        }
        UI::SameLine();
        if (UI::ButtonColored("pY", hueGreen)) {
            val.y = Clipboard::GetQuat().y;
        }
        UI::SameLine();
        if (UI::ButtonColored("pZ", hueBlue)) {
            val.z = Clipboard::GetQuat().z;
        }
        UI::SameLine();
        if (UI::ButtonColored("pW", 0, 0, .2)) {
            val.w = Clipboard::GetQuat().w;
        }

        UI::PopID();
        UI::PopID();

        return val;
    }
}
