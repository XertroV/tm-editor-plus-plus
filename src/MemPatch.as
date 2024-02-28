class MemPatcher {
    protected string pattern;
    protected string[]@ newBytes;
    protected string[] origBytes;
    protected string[]@ expected;
    protected uint16[]@ offsets;
    protected bool applied;
    uint64 ptr;

    MemPatcher(const string &in pattern, uint16[]@ offsets, string[]@ newBytes, string[]@ expected = {}) {
        this.pattern = pattern;
        @this.newBytes = newBytes;
        @this.offsets = offsets;
        @this.expected = expected;
        this.origBytes.Resize(newBytes.Length);
        ptr = Dev::FindPattern(pattern);
        applied = false;
        if (ptr == 0) {
            NotifyError("MemPatcher: Pattern not found: " + pattern);
        } else {
            trace('Found: ' + pattern + ' at ' + Text::FormatPointer(ptr));
        }
    }

    ~MemPatcher() {
        Unapply();
    }

    bool get_IsApplied() {
        return applied;
    }
    void set_IsApplied(bool value) {
        if (value) Apply();
        else Unapply();
    }

    void Apply() {
        if (applied || ptr == 0) return;
        applied = true;
        for (uint i = 0; i < newBytes.Length; i++) {
            // optional check for expected bytes
            if (expected.Length > i && expected[i] != "") {
                if (newBytes[i].Length == 0) {
                    throw("empty newBytes passed");
                }
                string orig = Dev::Read(ptr + offsets[i], (newBytes[i].Trim().Length + 1) / 3);
                if (orig != expected[i]) {
                    NotifyError("MemPatcher: Expected " + expected[i] + " at " + offsets[i] + " but found " + orig);
                    return;
                }
            }
            origBytes[i] = Dev::Patch(ptr + offsets[i], newBytes[i]);
            trace('Patched: ' + pattern + ' at ' + offsets[i] + ' with ' + newBytes[i] + ' (was ' + origBytes[i] + ')');
        }
    }

    void Unapply() {
        if (!applied || ptr == 0) return;
        applied = false;
        for (uint i = 0; i < newBytes.Length; i++) {
            Dev::Patch(ptr + offsets[i], origBytes[i]);
        }
    }
}
