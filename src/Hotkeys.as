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

    string formatted;
    string keyStr = "";

    Hotkey(VirtualKey key, bool ctrl, bool alt, bool shift, HotkeyFunction@ f, const string &in name) {
        this.key = key;
        this.ctrl = ctrl;
        this.alt = alt;
        this.shift = shift;
        @this.f = f;
        this.name = name;
        _id = tostring(Math::Rand(-2000000, 20000000));
        GenKeyStr();
    }

    void GenKeyStr() {
        keyStr = HotkeyKey(key, ctrl, alt, shift);
        formatted = "";
        if (ctrl) formatted += "Ctrl + ";
        if (alt) formatted += "Alt + ";
        if (shift) formatted += "Shift + ";
        formatted += tostring(key);
    }

    void UpdateKey(VirtualKey newKey, bool andSave = true) {
        hotkeysFlags[int(key)] = false;
        hotkeys.Delete(keyStr);
        key = newKey;
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
        j[name] = jk;
    }

    void LoadFromJsonObj(Json::Value@ j) {
        Json::Value@ jk = j[name];
        if (jk is null || jk.GetType() != Json::Type::Object) return;
        UpdateKey(VirtualKey(int(jk["key"])), false);

        // key = VirtualKey(int(jk["key"]));
        // ctrl = bool(jk["ctrl"]);
        // alt = bool(jk["alt"]);
        // shift = bool(jk["shift"]);
        // name = string(jk["name"]);
        // editorOnly = bool(jk["editorOnly"]);
        // GenKeyStr();
        // UpdateHotkey(this);
    }
}

UI::InputBlocking CheckHotkey(VirtualKey key, bool isEditor = true) {
    bool ctrlDown = IsCtrlDown();
    bool altDown = IsAltDown();
    bool shiftDown = IsShiftDown();
    dev_trace('ctrl: ' + ctrlDown + ", alt: " + altDown + ", shift: " + shiftDown);
    auto h = GetHotkey(key, ctrlDown, altDown, shiftDown);
    if (h is null) return UI::InputBlocking::DoNothing;
    if (h.editorOnly && !isEditor) return UI::InputBlocking::DoNothing;
    trace('running hotkey: ' + h.name);
    return h.f();
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
Hotkey@ AddHotkey(VirtualKey key, bool ctrl, bool alt, bool shift, HotkeyFunction@ f, const string &in name) {
    auto @h = Hotkey(key, ctrl, alt, shift, f, name);
    hotkeyList.InsertLast(h);
    @hotkeys[h.keyStr] = h;
    hotkeysFlags[int(key)] = true;
    return h;
}

void UpdateHotkey(Hotkey@ h) {
    @hotkeys[h.keyStr] = h;
    hotkeysFlags[int(h.key)] = true;
}


void UI_DrawHotkeyList() {
    UI::SeparatorText("Hotkeys");

    if (Bind::IsRebinding) {
        UI::Text("Press a key to rebind " + Bind::currHotkey.name + " or press ESC to cancel.");
    }

    UI::BeginDisabled(Bind::IsRebinding);
    if (UI::BeginTable("hotkeys", 3, UI::TableFlags::SizingStretchSame)) {
        UI::TableNextRow();
        for (uint i = 0; i < hotkeyList.Length; i++) {
            auto h = hotkeyList[i];
            UI::TableNextColumn();
            UI::Text(h.name);
            UI::TableNextColumn();
            UI::Text(tostring(h.key));
            UI::TableNextColumn();
            if (UI::Button("Rebind##" + h._id)) {
                h.StartRebind();
            }
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
    auto @setTestResapwnHK = AddHotkey(VirtualKey::Home, false, false, false, _SetEditorTestModeRespawnHotkeyF, "[TestMode] Set Respawn Position");
    setTestResapwnHK.editorOnly = false;

    sleep(500);
    LoadHotkeyDb();
}

Meta::PluginCoroutine@ addHotkeysCoro = startnew(_InitAddHotkeys);

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
