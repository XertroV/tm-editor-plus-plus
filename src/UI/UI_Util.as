

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}


void AddSimpleTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::TextWrapped(msg);
        UI::EndTooltip();
    }
}


void SetClipboard(const string &in msg) {
    IO::SetClipboard(msg);
    Notify("Copied: " + msg);
}

bool ClickableLabel(const string &in label, const string &in value, const string &in between = ": ") {
    UI::Text(label + between + value);
    return UI::IsItemClicked();
}

void CopiableLabeledValue(const string &in label, const string &in value) {
    if (ClickableLabel(label, value)) {
        SetClipboard(value);
    }
}


void LabeledValue(const string &in label, bool value) {
    ClickableLabel(label, tostring(value));
}
void LabeledValue(const string &in label, uint value) {
    ClickableLabel(label, tostring(value));
}
void LabeledValue(const string &in label, float value) {
    ClickableLabel(label, tostring(value));
}
void LabeledValue(const string &in label, int value) {
    ClickableLabel(label, tostring(value));
}
