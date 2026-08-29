// Arm only while overlay bitmaps are bound. Site is CControlLabel_Draw's
// hide-bit test (unique). We do not leave this on for every label forever.
// A mid-Draw MOV [rbx+0x1C8] hook (00:44) AVd on first present — do not retry
// that site without a proven rbx capture.
#if SIG_DEVELOPER

namespace LMComputePreviewSpike {
    const string DrawHideBitPattern =
        "83 89 30 01 00 00 02 48 8B D9 F7 81 30 01 00 00 00 40 00 00";

    HookHelper@ g_DrawHideBitHook = HookHelper(
        DrawHideBitPattern,
        0, 2, "LMComputePreviewSpike::OnLabelDraw_MaybeHide_Rcx",
        Dev::PushRegisters(0)
    );

    void SetupHooks() {}

    void ArmPreviewDrawHook() {
        if (g_DrawHideBitHook.IsApplied()) return;
        if (g_DrawHideBitHook.Apply()) {
            Log("Draw hide-bit hook armed (bake only)");
        } else {
            warn("[LMPreviewSpike] Draw hide-bit pattern not found");
        }
    }

    void DisarmPreviewDrawHook() {
        if (g_DrawHideBitHook.Unapply()) {
            Log("Draw hide-bit hook disarmed");
        }
    }

    void UnloadHooks() {
        DisarmPreviewDrawHook();
    }

    // rcx = CControlLabel this. Only reached while hook is armed (we have overlays).
    void OnLabelDraw_MaybeHide_Rcx(uint64 rcx) {
        if (rcx == 0) return;
        if (!OwnsDrawnLabel(rcx)) return;
        uint64 bmp = Dev::ReadUInt64(rcx + 0x1c8);
        if (bmp == 0) return;
        if (Dev::ReadUInt64(bmp + 0x178) != 0 && DialogBakeLock() != 0) return;
        Dev::Write(rcx + 0x130, Dev::ReadUInt32(rcx + 0x130) | 0x4000);
    }

    bool OwnsDrawnLabel(uint64 p) {
        if (g_Board !is null && g_Board.OwnsLabelPtr(p)) return true;
        auto nod = Dev_GetNodFromPointer(p);
        if (nod is null) return false;
        auto lab = cast<CControlLabel>(nod);
        if (lab is null) return false;
        string id = lab.IdName;
        return id == LegacyControlId || id.StartsWith(ControlIdPrefix);
    }
}

#endif
