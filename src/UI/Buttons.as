namespace UX {
    bool ControlButton(const string &in label, CoroutineFunc@ onClick, vec2 size = vec2()) {
        bool ret = UI::Button(label, size);
        if (ret) startnew(onClick);
        UI::SameLine();
        return ret;
    }

    bool SmallButton(const string &in label, const string &in tooltip = "") {
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        bool ret = UI::Button(label);
        if (tooltip.Length > 0) AddSimpleTooltip(tooltip);
        UI::PopStyleVar();
        return ret;
    }

    bool SmallButtonMbDisabled(const string &in label, const string &in tooltip = "", bool disabled = false) {
        UI::BeginDisabled(disabled);
        UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        bool ret = UI::Button(label);
        UI::PopStyleVar();
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
