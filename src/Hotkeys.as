funcdef UI::InputBlocking HotkeyFunction();


UI::InputBlocking CheckHotkey(VirtualKey key) {
    bool ctrlDown = IsCtrlDown();
    bool altDown = IsAltDown();
    bool shiftDown = IsShiftDown();
    dev_trace('ctrl: ' + ctrlDown + ", alt: " + altDown + ", shift: " + shiftDown);
    auto f = GetHotkeyFunction(key, ctrlDown, altDown, shiftDown);
    if (f is null) {
        dev_trace('null hotkey function');
        return UI::InputBlocking::DoNothing;
    }
    trace('running hotkey f');
    return f();
}

dictionary@ hotkeys = dictionary();
HotkeyFunction@ GetHotkeyFunction(VirtualKey key, bool ctrl, bool alt, bool shift) {
    return cast<HotkeyFunction>(hotkeys[HotkeyKey(key, ctrl, alt, shift)]);
}

// index for the hotkey
string HotkeyKey(VirtualKey key, bool ctrl, bool alt, bool shift) {
    return tostring(key) + (ctrl ? ".c" : ".x") + (alt ? "a" : "x") + (shift ? "s" : "x");
}

// register hotkey in the dict
void AddHotkey(VirtualKey key, bool ctrl, bool alt, bool shift, HotkeyFunction@ f) {
    @hotkeys[HotkeyKey(key, ctrl, alt, shift)] = f;
    hotkeysFlags[int(key)] = true;
}
