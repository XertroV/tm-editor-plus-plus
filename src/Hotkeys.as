funcdef UI::InputBlocking HotkeyFunction();

class Hotkey {
    VirtualKey key;
    bool ctrl;
    bool alt;
    bool shift;
    HotkeyFunction@ f;
    string name;
    string _id;
    bool editorOnly = true;
    bool anyModifier = false;

    bool disabled = false;

    string formatted;
    string keyStr = "";

    Hotkey(VirtualKey key, bool ctrl, bool alt, bool shift, HotkeyFunction@ f, const string &in name, bool anyModifier = false, bool editorOnly = true) {
        this.key = key;
        this.ctrl = ctrl;
        this.alt = alt;
        this.shift = shift;
        @this.f = f;
        this.name = name;
        this.anyModifier = anyModifier;
        this.editorOnly = editorOnly;
        _id = tostring(Math::Rand(-2000000, 20000000));
        GenKeyStr();
    }

    bool isDown = false;
    UI::InputBlocking onDownResp = UI::InputBlocking::DoNothing;
    bool allowRepeat = false;

    UI::InputBlocking Signal(bool down) {
        if (down and isDown) {
            return onDownResp;
        }
        if (down && (allowRepeat || !isDown)) {
            isDown = true;
            onDownResp = f();
            return onDownResp;
        } else if (!down) {
            isDown = false;
        }
        return UI::InputBlocking::DoNothing;
    }

    void GenKeyStr() {
        keyStr = HotkeyKey(key, ctrl, alt, shift);
        formatted = "";
        if (ctrl) formatted += "Ctrl + ";
        if (alt) formatted += "Alt + ";
        if (shift) formatted += "Shift + ";
        formatted += VirtualKeyToStr(key);
    }

    void UnregisterBeforeChange() {
        hotkeysFlags[int(key)] = false;
        hotkeys.Delete(keyStr);
    }

    void UpdateKey(VirtualKey newKey, bool andSave = true) {
        UnregisterBeforeChange();
        key = newKey;
        GenKeyStr();
        UpdateHotkey(this);
        if (andSave) SaveHotkeyDb();
    }

    void UpdateDisabled(bool disabled, bool andSave = true) {
        this.disabled = disabled;
        if (andSave) SaveHotkeyDb();
    }

    void UpdateCtrl(bool ctrl, bool andSave = true) {
        UnregisterBeforeChange();
        this.ctrl = ctrl;
        GenKeyStr();
        UpdateHotkey(this);
        if (andSave) SaveHotkeyDb();
    }

    void UpdateAlt(bool alt, bool andSave = true) {
        UnregisterBeforeChange();
        this.alt = alt;
        GenKeyStr();
        UpdateHotkey(this);
        if (andSave) SaveHotkeyDb();
    }

    void UpdateShift(bool shift, bool andSave = true) {
        UnregisterBeforeChange();
        this.shift = shift;
        GenKeyStr();
        UpdateHotkey(this);
        if (andSave) SaveHotkeyDb();
    }

    void StartRebind() {
        Bind::StartRebind(this);
    }

    void SaveInJsonObj(Json::Value@ j) {
        Json::Value@ jk = Json::Object();
        jk["key"] = int(key);
        jk["ctrl"] = ctrl;
        jk["alt"] = alt;
        jk["shift"] = shift;
        jk["name"] = name;
        jk["editorOnly"] = editorOnly;
        jk["disabled"] = disabled;
        j[name] = jk;
    }

    void LoadFromJsonObj(Json::Value@ j) {
        if (!j.HasKey(name)) return;
        Json::Value@ jk = j[name];
        if (jk is null || jk.GetType() != Json::Type::Object) {
            warn("Failed to load hotkey: " + name + " from json: " + (jk is null ? "<null>" : Json::Write(jk)));
            return;
        }
        UpdateKey(VirtualKey(int(jk["key"])), false);
        UpdateDisabled(jk.Get("disabled", false), false);
        editorOnly = jk.Get("editorOnly", true);
        UpdateCtrl(jk.Get("ctrl", false), false);
        UpdateAlt(jk.Get("alt", false), false);
        UpdateShift(jk.Get("shift", false), false);

        // key = VirtualKey(int(jk["key"]));
        // ctrl = bool(jk["ctrl"]);
        // alt = bool(jk["alt"]);
        // shift = bool(jk["shift"]);
        // name = string(jk["name"]);
        // editorOnly = bool(jk["editorOnly"]);
        // GenKeyStr();
        // UpdateHotkey(this);
    }

    void UI_DisabledCheckbox() {
        if (UX::Toggler(_id, !disabled)) {
            UpdateDisabled(!disabled);
        }
    }

    void UI_CtrlCheckbox() {
        bool newV = UI::Checkbox("##ctrl" + _id, ctrl);
        if (newV != ctrl) {
            UpdateCtrl(newV);
        }
    }

    void UI_AltCheckbox() {
        bool newV = UI::Checkbox("##alt" + _id, alt);
        if (newV != alt) {
            UpdateAlt(newV);
        }
    }

    void UI_ShiftCheckbox() {
        bool newV = UI::Checkbox("##shift" + _id, shift);
        if (newV != shift) {
            UpdateShift(newV);
        }
    }
}

UI::InputBlocking CheckHotkey(bool down, VirtualKey key, bool isEditor = true) {
    bool ctrlDown = IsCtrlDown();
    bool altDown = IsAltDown();
    bool shiftDown = IsShiftDown();
    dev_trace('ctrl: ' + ctrlDown + ", alt: " + altDown + ", shift: " + shiftDown);
    auto h = GetHotkey(key, ctrlDown, altDown, shiftDown);
    // if no hotkey + shift down, check for anyModifer
    if (h is null && (shiftDown || altDown || ctrlDown)) {
        @h = GetHotkey(key, false, false, false);
        if (h !is null && !h.anyModifier) {
            return UI::InputBlocking::DoNothing;
        }
    }

    if (h is null || h.disabled) return UI::InputBlocking::DoNothing;
    if (h.editorOnly && !isEditor) return UI::InputBlocking::DoNothing;
    // trace('running hotkey: ' + h.name);
    return h.Signal(down);
}

dictionary@ hotkeys = dictionary();
Hotkey@[] hotkeyList;
Hotkey@ GetHotkey(VirtualKey key, bool ctrl, bool alt, bool shift) {
    return cast<Hotkey>(hotkeys[HotkeyKey(key, ctrl, alt, shift)]);
}

Hotkey@ GetHotkey(const string &in ixKey) {
    return cast<Hotkey>(hotkeys[ixKey]);
}

// index for the hotkey
string HotkeyKey(VirtualKey key, bool ctrl, bool alt, bool shift) {
    string r = tostring(int(key)) + ".";
    if (ctrl) {
        if (alt) {
            if (shift) return r + "cas";
            return r + "cax";
        } else if (shift) return r + "cxs";
        return r + "cxx";
    } else {
        if (alt) {
            if (shift) return r + "xas";
            return r + "xax";
        } else if (shift) return r + "xxs";
        return r + "xxx";
    }
    // return tostring(key) + "." + (ctrl ? "c" : "x") + (alt ? "a" : "x") + (shift ? "s" : "x");
}

// register hotkey in the dict
Hotkey@ AddHotkey(VirtualKey key, bool ctrl, bool alt, bool shift, HotkeyFunction@ f, const string &in name, bool anyModifier = false, bool editorOnly = true) {
    auto @h = Hotkey(key, ctrl, alt, shift, f, name, anyModifier, editorOnly);
    if (hotkeys.Exists(h.keyStr)) {
        auto h2 = GetHotkey(h.keyStr);
        NotifyWarning("Hotkey already exists; might clobber: " + h.keyStr + " | h2: " + h2.name);
    }
    hotkeyList.InsertLast(h);
    @hotkeys[h.keyStr] = h;
    hotkeysFlags[int(key)] = true;
    return h;
}

void UpdateHotkey(Hotkey@ h) {
    if (hotkeys.Exists(h.keyStr)) {
        auto h2 = GetHotkey(h.keyStr);
        NotifyWarning("Hotkey already exists; might clobber: " + h.keyStr + " | h2: " + h2.name);
    }
    @hotkeys[h.keyStr] = h;
    hotkeysFlags[int(h.key)] = true;
}

uint _hotkeysLastVisible = 0;
VirtualKey _lastKeyPressed = VirtualKey(-1);

void _ShowLastKeyPressed(VirtualKey k) {
    _lastKeyPressed = k;
}


void UI_DrawHotkeyList() {
    // keep track of when this is visible so we can show key-presses to the user.
    _hotkeysLastVisible = Time::Now;
    UI::Text("Last key pressed: " + VirtualKeyToStr(_lastKeyPressed));

    UI::SeparatorText("Hotkeys");

    if (Bind::IsRebinding) {
        UI::PushFont(g_MidFont);
        UI::TextWrapped("\\$8f0\\$i "+Icons::InfoCircle+" Press a key to rebind " + Bind::currHotkey.name + " or press ESC to cancel. " + Icons::InfoCircle);
        UI::PopFont();
    }

    UI::BeginDisabled(Bind::IsRebinding);
    if (UI::BeginTable("hotkeys", 7, UI::TableFlags::SizingStretchSame)) {
        auto _scale = g_scale;
        UI::TableSetupColumn("Name", UI::TableColumnFlags::WidthStretch, 2.);
        UI::TableSetupColumn("Key", UI::TableColumnFlags::WidthStretch, 1.);
        UI::TableSetupColumn("Rebind", UI::TableColumnFlags::WidthFixed, 70 * _scale);
        UI::TableSetupColumn("Disabled", UI::TableColumnFlags::WidthFixed, 50 * _scale);
        UI::TableSetupColumn("Ctrl", UI::TableColumnFlags::WidthFixed, 30 * _scale);
        UI::TableSetupColumn("Alt", UI::TableColumnFlags::WidthFixed, 30 * _scale);
        UI::TableSetupColumn("Shift", UI::TableColumnFlags::WidthFixed, 40 * _scale);
        UI::TableHeadersRow();
        UI::TableNextRow();
        for (uint i = 0; i < hotkeyList.Length; i++) {
            auto h = hotkeyList[i];
            UI::TableNextColumn();
            UI::Text((h.disabled ? "\\$999" : "") + h.name);
            UI::TableNextColumn();
            UI::Text(h.formatted);
            UI::TableNextColumn();
            if (UI::Button("Rebind##" + h._id)) {
                h.StartRebind();
            }
            UI::TableNextColumn();
            h.UI_DisabledCheckbox();
            UI::TableNextColumn();
            h.UI_CtrlCheckbox();
            UI::TableNextColumn();
            h.UI_AltCheckbox();
            UI::TableNextColumn();
            h.UI_ShiftCheckbox();
        }
        UI::EndTable();
    }
    UI::EndDisabled();
}



// rebinding logic

namespace Bind {
    VirtualKey tmpKey;
    bool gotNextKey = false;
    bool rebindInProgress = false;
    bool rebindAborted = false;
    Hotkey@ currHotkey = null;

    bool IsRebinding {
        get { return rebindInProgress && currHotkey !is null; }
    }

    void ResetBindingState() {
        rebindInProgress = false;
        gotNextKey = false;
        rebindAborted = false;
        tmpKey = VirtualKey(-1);
        @currHotkey = null;
    }

    void StartRebind(Hotkey@ h) {
        if (rebindInProgress) return;
        rebindInProgress = true;
        gotNextKey = false;
        rebindAborted = false;
        tmpKey = VirtualKey(-1);
        @currHotkey = h;
    }

    void ReportRebindKey(VirtualKey key) {
        if (!rebindInProgress) return;
        tmpKey = key;
        if (key == VirtualKey::Escape) {
            rebindInProgress = false;
            rebindAborted = true;
            gotNextKey = false;
        } else {
            rebindInProgress = false;
            rebindAborted = false;
            gotNextKey = true;
            currHotkey.UpdateKey(key);
        }
    }

    UI::InputBlocking OnKeyPress(bool down, VirtualKey key) {
        if (!down) return UI::InputBlocking::DoNothing;
        // rebind has priority if active
        if (rebindInProgress) {
            ReportRebindKey(key);
            return UI::InputBlocking::Block;
        }
        return UI::InputBlocking::DoNothing;
    }
}



UI::InputBlocking _SetEditorTestModeRespawnHotkeyF() {
    if (GetApp().CurrentPlayground is null) return UI::InputBlocking::DoNothing;
    Editor::SetEditorTestModeRespawnPositionFromCurrentVis();
    return UI::InputBlocking::Block;
}

// note: not all hotkeys are added here, just general ones
void _InitAddHotkeys() {
    yield(5);
    auto @setTestResapwnHK = AddHotkey(VirtualKey::Home, false, false, false, _SetEditorTestModeRespawnHotkeyF, "[TestMode] Set Respawn Position");
    setTestResapwnHK.editorOnly = false;
    // gets called in Main() after initialization of things that add hotkeys.
    // LoadHotkeyDb();
}

awaitable@ addHotkeysCoro = startnew(_InitAddHotkeys);

const string HOTKEYS_JSON_PATH = IO::FromStorageFolder("hotkeys.json");

void SaveHotkeyDb() {
    Json::Value@ j = Json::Object();
    for (uint i = 0; i < hotkeyList.Length; i++) {
        hotkeyList[i].SaveInJsonObj(j);
    }
    Json::ToFile(HOTKEYS_JSON_PATH, j);
}

void LoadHotkeyDb() {
    if (!IO::FileExists(HOTKEYS_JSON_PATH)) return;
    Json::Value@ j = Json::FromFile(HOTKEYS_JSON_PATH);
    if (j is null) return;
    for (uint i = 0; i < hotkeyList.Length; i++) {
        hotkeyList[i].LoadFromJsonObj(j);
    }
}

string VirtualKeyToStr(VirtualKey k) {
    switch (k) {
        case VirtualKey::Next: return "PgDn";
        case VirtualKey::Prior: return "PgUp";
        case VirtualKey::Back: return "Backspace";
        case VirtualKey::Snapshot: return "PrintScreen";
        case VirtualKey::Menu: return "Alt";
        case VirtualKey::OemPlus: return "=";
        case VirtualKey::OemMinus: return "-";
        case VirtualKey::OemComma: return ",";
        case VirtualKey::OemPeriod: return ".";
        case VirtualKey::Oem1: return ";";
        case VirtualKey::Oem2: return "/";
        case VirtualKey::Oem3: return "` (~)";
        case VirtualKey::Oem4: return "[";
        case VirtualKey::Oem5: return "\\";
        case VirtualKey::Oem6: return "]";
        case VirtualKey::Oem7: return "'";
    }
    return tostring(k);
}
