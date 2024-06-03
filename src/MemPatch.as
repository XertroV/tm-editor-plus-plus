class MemPatcher {
    string patternDisplay;
    protected string[]@ patterns;
    protected string[]@ newBytes;
    protected string[] origBytes;
    protected string[]@ expected;
    protected uint16[]@ offsets;
    protected bool applied;
    uint64 ptr;

    MemPatcher(const string &in pattern, uint16[]@ offsets, string[]@ newBytes, string[]@ expected = {}) {
        Setup({pattern}, offsets, newBytes, expected);

    }

    // multiple patterns are for incompatible game updates
    MemPatcher(string[]@ patterns, uint16[]@ offsets, string[]@ newBytes, string[]@ expected = {}) {
        Setup(patterns, offsets, newBytes, expected);
    }

    protected void Setup(string[]@ patterns, uint16[]@ offsets, string[]@ newBytes, string[]@ expected = {}) {
        @this.patterns = patterns;
        patternDisplay = Json::Write(patterns.ToJson());
        @this.newBytes = newBytes;
        @this.offsets = offsets;
        @this.expected = expected;
        this.origBytes.Resize(newBytes.Length);
        FindPatternSetPtr();
        applied = false;
        if (ptr == 0) {
            NotifyError("MemPatcher: Pattern(s) not found: " + Json::Write(patterns.ToJson()));
        }
    }

    ~MemPatcher() {
        Unapply();
    }

    protected void FindPatternSetPtr() {
        origBytes.Resize(newBytes.Length);
        for (uint i = 0; i < patterns.Length; i++) {
            ptr = Dev::FindPattern(patterns[i]);
            if (ptr != 0) {
                trace('Found: ' + patterns[i] + ' at ' + Text::FormatPointer(ptr));
                for (uint i = 0; i < newBytes.Length; i++) {
                    origBytes[i] = Dev::Read(ptr + offsets[i], (newBytes[i].Trim().Length + 1) / 3);
                }
                break;
            }
        }
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
            // we already read origBytes on initialization (prevents restoring a patched value if multiple plugins touch the same thing);
            auto expectedOrig = Dev::Patch(ptr + offsets[i], newBytes[i]);
            if (i >= origBytes.Length || origBytes[i] != expectedOrig) {
                warn("MemPatcher: Patching failed at " + offsets[i] + " with " + newBytes[i] + " (was " + expectedOrig + ", expected " + (origBytes.Length > i ? origBytes[i] : "UNKNOWN") + ")");
            }
            // origBytes[i] = Dev::Patch(ptr + offsets[i], newBytes[i]);
            trace('Patched: ' + patternDisplay + ' at ' + offsets[i] + ' with ' + newBytes[i] + ' (was ' + origBytes[i] + ')');
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
