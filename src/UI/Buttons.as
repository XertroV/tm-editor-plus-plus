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
}
