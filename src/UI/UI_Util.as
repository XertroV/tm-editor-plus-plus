

void Notify(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg);
    trace("Notified: " + msg);
}

void NotifySuccess(const string &in msg) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg, vec4(.4, .7, .1, .3), 10000);
    trace("Notified: " + msg);
}

shared void NotifyError(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Error", msg, vec4(.9, .3, .1, .3), 15000);
}

void NotifyWarning(const string &in msg) {
    warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": Warning", msg, vec4(.9, .6, .2, .3), 15000);
}

void Dev_NotifyWarning(const string &in msg) {
#if DEV
    warn(msg);
    UI::ShowNotification("Dev: Warning", msg, vec4(.9, .6, .2, .3), 15000);
#endif
}


void AddSimpleTooltip(const string &in msg, bool pushFont = false) {
    if (UI::IsItemHovered()) {
        if (pushFont) UI::PushFont(g_NormFont);
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::TextWrapped(msg);
        UI::EndTooltip();
        if (pushFont) UI::PopFont();
    }
}

void AddMarkdownTooltip(const string &in msg) {
    if (UI::IsItemHovered()) {
        UI::SetNextWindowSize(400, 0, UI::Cond::Appearing);
        UI::BeginTooltip();
        UI::Markdown(msg);
        UI::EndTooltip();
    }
}


void SetClipboard(const string &in msg) {
    IO::SetClipboard(msg);
    Notify("Copied: " + msg.SubStr(0, 300));
}

funcdef bool LabeledValueF(const string &in l, const string &in v);

bool ClickableLabel(const string &in label, const string &in value) {
    return ClickableLabel(label, value, ": ");
}
bool ClickableLabel(const string &in label, const string &in value, const string &in between) {
    UI::Text(label.Length > 0 ? label + between + value : value);
    if (UI::IsItemHovered(UI::HoveredFlags::None)) {
        UI::SetMouseCursor(UI::MouseCursor::Hand);
    }
    return UI::IsItemClicked();
}

bool CopiableLabeledPtr(CMwNod@ nod) {
    return CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(nod)));
}
bool CopiableLabeledPtr(const uint64 ptr) {
    return CopiableLabeledValue("ptr", Text::FormatPointer(ptr));
}

bool CopiableLabeledValue(const string &in label, const string &in value) {
    if (ClickableLabel(label, value)) {
        SetClipboard(value);
        return true;
    }
    return false;
}

bool CopiableValue(const string &in value) {
    if (ClickableLabel("", value)) {
        SetClipboard(value);
        return true;
    }
    return false;
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
void LabeledValue(const string &in label, const string &in value) {
    ClickableLabel(label, value);
}
void LabeledValue(const string &in label, vec2 &in value, bool clickToCopy = false) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, FormatX::Vec2(value));
}
void LabeledValue(const string &in label, nat3 &in value, bool clickToCopy = false) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, FormatX::Nat3(value));
}
void LabeledValue(const string &in label, vec3 &in value, bool clickToCopy = false) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, FormatX::Vec3(value));
}
void LabeledValue(const string &in label, vec4 &in value, bool clickToCopy = false) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, value.ToString());
}
void LabeledValue(const string &in label, int3 &in value, bool clickToCopy = false) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, FormatX::Int3(value));
}



bool CopiableLabeledValueTooltip(const string &in label, const string &in value) {
    bool clicked = ClickableLabel(label, "", "");
    AddSimpleTooltip(value);
    if (clicked) {
        SetClipboard(value);
    }
    return clicked;
}


float G_GetSmallerInputWidth() {
    return Math::Max(400.0, UI::GetWindowContentRegionWidth() * 0.5);
}


namespace UX {
    // call this before you end the popup
    void CloseCurrentPopupIfMouseFarAway(bool closeAnyway = false) {
        auto wPos = UI::GetWindowPos();
        auto wSize = UI::GetWindowSize();
        auto showBoundsRect = vec4(wPos + vec2(-50), wSize + vec2(100));

        closeAnyway = closeAnyway || !MathX::Within(UI::GetMousePos(), showBoundsRect);
        // trace(UI::GetMousePos().ToString() + " " + showBoundsRect.ToString());
        if (closeAnyway) UI::CloseCurrentPopup();
    }
}
