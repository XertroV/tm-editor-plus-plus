namespace ExtraUndoFix {
    // we are interested in manipulating the function called via E8 ?? ?? ?? ??
    const string AutosavePattern = "48 8B BB 78 04 00 00 48 8D 8F A0 00 00 00 E8 ?? ?? ?? ?? 85 C0 74 13";
    uint64 patternPtr = 0;
    const uint64 callOffset = 14;

    void OnLoad() {
        patternPtr = Dev::FindPattern(AutosavePattern);
    }

    bool isDisabled = false;
    string backupBytes;

    void DisableUndo() {
        if (isDisabled) {
            throw("Attempted to disable while already disabled.");
        }
        if (patternPtr == 0) {
            warn('[DisableUndo] Failed to find AddUndo pattern, please report this to the plugin support thread.');
            return;
        }
        backupBytes = Dev::Patch(patternPtr + callOffset, "90 90 90 90 90");
        isDisabled = true;
    }

    void EnableUndo() {
        if (!isDisabled) {
            throw("Attempted to enable undo when patch was not applied!");
        }
        if (patternPtr == 0) {
            warn('[EnableUndo] Failed to find AddUndo pattern, please report this to the plugin support thread.');
            return;
        }
        // discard nops
        Dev::Patch(patternPtr + callOffset, backupBytes);
        isDisabled = false;
    }
}
