namespace Editor {
    namespace OffzonePatch {

        const string OffzoneBtnPattern = "0F 84 ?? ?? ?? ?? 4C 8D 45 ?? BA 13 00 00 00";
        const string OffzoneNops       = "90 90 90 90 90 90";
        string offzoneOrigBytes = "";
        uint64 offzonePatternPtr = 0;
        bool patchActive = false;

        void Apply() {
            if (patchActive) return;
            offzonePatternPtr = Dev::FindPattern(OffzoneBtnPattern);
            if (offzonePatternPtr == 0) {
                dev_trace("Could not find offzone code ptr");
                return;
            }
            offzoneOrigBytes = Dev::Patch(offzonePatternPtr, OffzoneNops);
            patchActive = true;
            dev_trace("Applied offzone patch");
        }

        void Unapply() {
            if (!patchActive) return;
            if (offzonePatternPtr == 0) throw('offzone pattern ptr is zero!');
            Dev::Patch(offzonePatternPtr, offzoneOrigBytes);
            patchActive = false;
            dev_trace("Unapplied offzone patch");
        }
    }
}
