

void Notify(const string &in msg, int time = 5000) {
    UI::ShowNotification(Meta::ExecutingPlugin().Name, msg, time);
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
void NotifyWarning(const string &in title, const string &in msg, bool log = true) {
    if (log) warn(msg);
    UI::ShowNotification(Meta::ExecutingPlugin().Name + ": " + title, msg, vec4(.9, .6, .2, .3), 15000);
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
        UI::SetNextWindowPos(g_lastMousePos.x + 8, g_lastMousePos.y + 8);
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


void LabeledValue(const string &in label, bool value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, tostring(value));
}
void LabeledValue(const string &in label, uint value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, tostring(value));
}
void LabeledValue(const string &in label, float value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, tostring(value));
}
void LabeledValue(const string &in label, int value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, tostring(value));
}
void LabeledValue(const string &in label, const string &in value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, value);
}
void LabeledValue(const string &in label, vec2 &in value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, FormatX::Vec2(value));
}
void LabeledValue(const string &in label, nat3 &in value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, FormatX::Nat3(value));
}
void LabeledValue(const string &in label, vec3 &in value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, FormatX::Vec3(value));
}
void LabeledValue(const string &in label, vec4 &in value, bool clickToCopy = true) {
    (clickToCopy ? (CopiableLabeledValue) : LabeledValueF(ClickableLabel))(label, value.ToString());
}
void LabeledValue(const string &in label, int3 &in value, bool clickToCopy = true) {
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
    bool IsItemRightClicked() {
        return UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Right);
    }
    bool IsItemMiddleClicked() {
        return UI::IsItemHovered() && UI::IsMouseClicked(UI::MouseButton::Middle);
    }
    // set closeAnyway=true to close it regardless. call this before you end the popup.
    void CloseCurrentPopupIfMouseFarAway(bool closeAnyway = false, float pad_ScreenYProp = 0.25) {
        auto wPos = UI::GetWindowPos();
        auto wSize = UI::GetWindowSize();
        auto wMid = wPos + (wSize * 0.5);
        float radius = Math::Max(wSize.x, wSize.y) * 0.5 + Math::Max(pad_ScreenYProp, 1e-5) * g_screen.y;
        // vec2 areaPad = vec2(g_screen.y * Math::Clamp(pad_ScreenYProp, 0.0, 1.0));
        // auto showBoundsRect = vec4(wPos - areaPad, wSize + (areaPad * 2.));
        // closeAnyway = closeAnyway || !MathX::Within(UI::GetMousePos(), showBoundsRect);
        if ((UI::GetMousePos() - wMid).LengthSquared() > radius * radius) {
            closeAnyway = true;
        }
        // trace(UI::GetMousePos().ToString() + " " + showBoundsRect.ToString());
        if (closeAnyway) UI::CloseCurrentPopup();
    }

    // returns true if pressed; i.e., true => toggled
    bool Toggler(const string &in id, bool state) {
        return UI::Button((state ? Icons::ToggleOn : Icons::ToggleOff) + "##" + id);
    }

    bool ButtonSameLine(const string &in label) {
        bool ret = UI::Button(label);
        UI::SameLine();
        return ret;
    }

    void DrawMat4SameLine(const mat4 &in mat) {
        UI::PushFont(g_MonoFont);
        auto posInit = UI::GetCursorPos();
        UI::SameLine();
        auto posStart = UI::GetCursorPos();
        // UI::Text("[");
        // UI::SameLine();
        auto posMatStart = UI::GetCursorPos();
        float lineHeight = posMatStart.y - posInit.y;
        UI::Text("[ " + Text::Format("%3.2f", mat.xx)
            + ", " + Text::Format("%3.2f", mat.xy)
            + ", " + Text::Format("%3.2f", mat.xz)
            + ", " + Text::Format("%3.2f", mat.xw) + "");
        UI::SetCursorPos(vec2(posMatStart.x, UI::GetCursorPos().y));
        UI::Text(", " + Text::Format("%3.2f", mat.yx)
            + ", " + Text::Format("%3.2f", mat.yy)
            + ", " + Text::Format("%3.2f", mat.yz)
            + ", " + Text::Format("%3.2f", mat.yw) + "");
        UI::SetCursorPos(vec2(posMatStart.x, UI::GetCursorPos().y));
        UI::Text(", " + Text::Format("%3.2f", mat.zx)
            + ", " + Text::Format("%3.2f", mat.zy)
            + ", " + Text::Format("%3.2f", mat.zz)
            + ", " + Text::Format("%3.2f", mat.zw) + "");
        UI::SetCursorPos(vec2(posMatStart.x, UI::GetCursorPos().y));
        UI::Text(", " + Text::Format("%3.2f", mat.tx)
            + ", " + Text::Format("%3.2f", mat.ty)
            + ", " + Text::Format("%3.2f", mat.tz)
            + ", " + Text::Format("%3.2f", mat.tw) + " ]");
        // UI::SameLine();
        // UI::Text("]");
        UI::PopFont();
    }
}


void TextSameLine(const string &in text) {
    UI::Text(text);
    UI::SameLine();
}

void SameLineText(const string &in text) {
    UI::SameLine();
    UI::Text(text);
}
