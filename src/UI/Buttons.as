namespace UX {
    bool ControlButton(const string &in label, CoroutineFunc@ onClick, vec2 size = vec2()) {
        bool ret = UI::Button(label, size);
        if (ret) startnew(onClick);
        UI::SameLine();
        return ret;
    }

    void PushSmall() {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
    }
    void PopSmall() {
        UI::PopStyleVar();
    }

    bool SmallButton(const string &in label, const string &in tooltip = "") {
        PushSmall();
        bool ret = UI::Button(label);
        if (tooltip.Length > 0) AddSimpleTooltip(tooltip);
        PopSmall();
        return ret;
    }

    bool SmallButtonMbDisabled(const string &in label, const string &in tooltip = "", bool disabled = false) {
        UI::BeginDisabled(disabled);
        PushSmall();
        bool ret = UI::Button(label);
        PopSmall();
        UI::EndDisabled();
        if (tooltip.Length > 0) AddSimpleTooltip(tooltip);
        return ret;
    }

    bool ButtonMbDisabled(const string &in label, bool disabled = false) {
        UI::BeginDisabled(disabled);
        bool ret = UI::Button(label);
        UI::EndDisabled();
        return ret;
    }

    // Danger-confirm buttons: first click arms (button turns red, tooltip asks to
    // confirm); second click within the timeout fires. Any other danger button
    // re-arms itself instead. Auto-resets after timeoutMs.
    string g_DangerConfirmId = "";
    uint g_DangerConfirmTime = 0;

    bool DangerButtonInner(const string &in label, const string &in id, const string &in tooltip, bool small, uint timeoutMs) {
        if (g_DangerConfirmId.Length > 0 && Time::Now - g_DangerConfirmTime > timeoutMs) {
            g_DangerConfirmId = "";
        }
        bool armed = g_DangerConfirmId == id;
        if (armed) {
            UI::PushStyleColor(UI::Col::Button, vec4(0.78, 0.16, 0.16, 1.0));
            UI::PushStyleColor(UI::Col::ButtonHovered, vec4(0.88, 0.22, 0.22, 1.0));
            UI::PushStyleColor(UI::Col::ButtonActive, vec4(0.62, 0.12, 0.12, 1.0));
        }
        if (small) PushSmall();
        bool clicked = UI::Button(label);
        if (small) PopSmall();
        if (armed) UI::PopStyleColor(3);
        AddSimpleTooltip(tooltip.Length > 0
            ? (armed ? "Click again to confirm. " + tooltip : tooltip)
            : (armed ? "Click again to confirm." : ""));
        if (clicked) {
            if (armed) {
                g_DangerConfirmId = "";
                return true;
            }
            g_DangerConfirmId = id;
            g_DangerConfirmTime = Time::Now;
        }
        return false;
    }

    bool DangerButton(const string &in label, const string &in id, const string &in tooltip = "", uint timeoutMs = 5000) {
        return DangerButtonInner(label, id, tooltip, false, timeoutMs);
    }

    bool DangerSmallButton(const string &in label, const string &in id, const string &in tooltip = "", uint timeoutMs = 5000) {
        return DangerButtonInner(label, id, tooltip, true, timeoutMs);
    }
}
