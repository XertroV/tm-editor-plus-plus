// full function: "48 83 ec 28 83 b9 30 01 00 00 00 75 19 8b 89 50 01 00 00 e8 08 7e bc ff 85 c0 74 0a b8 01 00 00 00 48 83 c4 28 c3 33 c0 48 83 c4 28 c3"
// nop first 2 bytes: "75 19 8B 89 50 01 00 00 E8 08 7E BC FF 85 C0 74 0A B8 01 00 00 00 48 83 C4 28 C3 33 C0 48 83 C4 28 C3"

const string Pattern_CpCanStandingResapwnCheck =
    //           vv block+0x150    vv call inner           vv Return 1
    "75 19 8B 89 50 01 00 00 E8 ?? ?? ?? ?? 85 C0 74 0A B8 01 00 00 00"; // 48 83 C4 28 C3 33 C0 48 83 C4 28 C3";

// This patch lets us choose circle CPs in the editor for starting a test run from.
// It also allows standing respawn at these CPs but only in test mode (not validation, not solo campaign, not online TA)
MemPatcher@ Patch_CpCanStandingResapwnCheck = MemPatcher(
    Pattern_CpCanStandingResapwnCheck,
    {0}, {"90 90"}
);

void RegisterEditorLeaveUndoStandingRespawnCheck() {
    RegisterOnEditorUnloadCallback(CpCanStandingRespawn_OnEditorUnload, "CpCanStandingRespawn");
}

void CpCanStandingRespawn_OnEditorUnload() {
    if (Patch_CpCanStandingResapwnCheck is null) return;
    Patch_CpCanStandingResapwnCheck.Unapply();
}
