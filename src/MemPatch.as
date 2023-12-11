class MemPatcher {
    protected string pattern;
    protected string[] newBytes;
    protected string[] origBytes;
    protected uint16[] offsets;
    protected bool applied;
    uint64 ptr;

    MemPatcher(const string &in pattern, uint16[] offsets, string[] newBytes) {
        this.pattern = pattern;
        this.newBytes = newBytes;
        this.offsets = offsets;
        this.origBytes.Resize(newBytes.Length);
        ptr = Dev::FindPattern(pattern);
        applied = false;
    }

    ~MemPatcher() {
        Unapply();
    }

    bool get_IsApplied() {
        return applied;
    }

    void Apply() {
        if (applied || ptr == 0) return;
        applied = true;
        for (uint i = 0; i < newBytes.Length; i++) {
            origBytes[i] = Dev::Patch(ptr + offsets[i], newBytes[i]);
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
