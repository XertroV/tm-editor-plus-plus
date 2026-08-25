#if SIG_DEVELOPER
// OP-thread native call via dummy CControlButton vtable+0x200.
// Adapted from spike-live-add-kinematic-ao (Win64-aligned stub).
// Do not Dev::Hook this stub — ApplyHookAfterEnsure must stay false
// (log-only OnStub still killed TM 2026-08-23 07:28).
// research/2026-08-23-CControlButton-OnAction.md
namespace AsCall {
    const uint OnActionVtableOff = 0x200;
    const uint VtCopyBytes = 0x280;
    const uint64 GhidraOnActionThunk = 0x140143F84;
    const uint ClassIdButton = 0x07007000;
    const string OnActionThunkHex = "48 8B 01 FF A0 00 02 00 00";

    const uint OffFn = 0x80;
    const uint OffRcx = 0x88;
    const uint OffRdx = 0x90;
    const uint OffR8 = 0x98;
    const uint OffR9 = 0xA0;
    const uint OffRet = 0xA8;
    // After xor rax, reload rcx=carrier. Native this left in rcx is
    // OP.dll write +0x240 class 0x0A018000 (LogCrash_EA180000007EDC20).
    // Keep this comment outside CodeHex — // inside the concat dropped
    // the mov (same crash 20:12:28 after a RemoteBuild).
    const uint OffThis = 0xD0;
    const uint OffPing = 0xB0;
    const uint OffRetOnly = 0xB6;
    const uint OffRetRcx = 0xB8;
    const uint OffRetRdx = 0xBC;
    const uint OffRetR8 = 0xC0;
    const uint OffAlign = 0xC4;
    const uint StubSize = 0xE0;
    const uint HookNopLen = 16;
    const int HookPadding = 11;
    const string HookFn = "AsCall_OnStub";
    const bool ApplyHookAfterEnsure = false;
    const uint ExpectPing = 0xA0A0;
    const uint ExpectAlign = 8;
    const uint64 ProbeRcx = 0x1111111111111111;
    const uint64 ProbeRdx = 0x2222222222222222;
    const uint64 ProbeR8 = 0x3333333333333333;

    const string NopSledHex =
        "90 90 90 90 90 90 90 90 90 90 90 90 90 90 90 90 ";
    // Save OnAction this to OffThis on the stub page (InitVis writes [rbp-8];
    // rbx also clobbered). xor rax, restore rcx from OffThis.
    // LogCrash_EA180000007EDC20 2026-08-26 01:20 second Add after PoolPop.
    const string CodeHex =
        NopSledHex +
        "55 " +
        "48 89 E5 " +
        "48 83 E4 F0 " +
        "48 83 EC 40 " +
        "53 " +
        "56 " +
        "57 " +
        "41 54 " +
        "41 55 " +
        "41 56 " +
        "41 57 " +
        "48 83 EC 08 " +
        "48 89 0D 9E 00 00 00 " +
        "48 8B 05 47 00 00 00 " +
        "48 8B 0D 48 00 00 00 " +
        "48 8B 15 49 00 00 00 " +
        "4C 8B 05 4A 00 00 00 " +
        "4C 8B 0D 4B 00 00 00 " +
        "FF D0 " +
        "48 89 05 4A 00 00 00 " +
        "48 31 C0 " +
        "48 8B 0D 68 00 00 00 " +
        "48 83 C4 08 " +
        "41 5F " +
        "41 5E " +
        "41 5D " +
        "41 5C " +
        "5F " +
        "5E " +
        "5B " +
        "48 89 EC " +
        "5D " +
        "C3";
    const string PingHex = "B8 A0 A0 00 00 C3";
    const string RetOnlyHex = "C3";
    const string RetRcxHex = "48 89 C8 C3";
    const string RetRdxHex = "48 89 D0 C3";
    const string RetR8Hex = "4C 89 C0 C3";
    const string AlignHex = "48 89 E0 83 E0 0F C3";

    CControlButton@ carrier;
    uint64 origVt;
    uint64 fakeVt;
    uint64 stub;
    bool ready;
    bool inCall;
    string lastErr;
    uint hookHits;
    Json::Value@ lastHookRegs;
    string hookErr;
    string hookSite;
    string hookExec;
    string ourPluginId;
    bool pumpRunning;
    bool wantHook;
    bool pendingFire;
    bool pendingDone;
    bool pendingThrew;
    uint64 pendingRet;

    string ExecPluginId() {
        auto p = Meta::ExecutingPlugin();
        if (p is null) return "null";
        return p.ID;
    }

    bool InOurModule() {
        auto p = Meta::ExecutingPlugin();
        return p !is null && ourPluginId.Length > 0 && p.ID == ourPluginId;
    }

    void StartPump() {
        auto p = Meta::ExecutingPlugin();
        if (p !is null) ourPluginId = p.ID;
    }

    void OnUpdate() {
        if (wantHook && stub != 0) {
            wantHook = false;
            HookStub();
        }
        if (pendingFire && !pendingDone) {
            pendingFire = false;
            pendingThrew = false;
            try {
                pendingRet = Fire();
            } catch {
                pendingThrew = true;
            }
            pendingDone = true;
        }
    }

    void OnStub(uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
        try {
            hookHits++;
            auto o = Json::Object();
            o["hit"] = int(hookHits);
            o["site"] = hookSite;
            o["rcx"] = Text::FormatPointer(rcx);
            o["rdx"] = Text::FormatPointer(rdx);
            o["r8"] = Text::FormatPointer(r8);
            o["r9"] = Text::FormatPointer(r9);
            o["rcxIsCarrier"] = rcx == CarrierPtr();
            o["rax"] = "omitted: openplanet-nl/issues#739";
            @lastHookRegs = o;
            trace("[AsCall] OnStub hit=" + int(hookHits)
                + " rcx=" + Text::FormatPointer(rcx)
                + " rdx=" + Text::FormatPointer(rdx)
                + " r8=" + Text::FormatPointer(r8)
                + " r9=" + Text::FormatPointer(r9));
        } catch {
        }
    }

    bool Ready() { return ready && carrier !is null && stub != 0 && fakeVt != 0; }

    void CopyVt(uint64 dst, uint64 src, uint nbytes) {
        uint n = nbytes / 8;
        for (uint i = 0; i < n; i++) {
            Dev::Write(dst + i * 8, Dev::ReadUInt64(src + i * 8));
        }
    }

    // E++ HookHelper is pattern-based; do not Dev::Hook this stub.
    void UnhookStub() {
        wantHook = false;
        hookSite = "";
        hookExec = "";
    }

    void HookStub() {
        hookErr = "disabled: Dev::Hook on this stub crashes TM (ApplyHookAfterEnsure=false)";
        warn("AsCall: " + hookErr);
    }

    void Drop() {
        if (carrier !is null && origVt != 0) {
            try {
                Dev::SetOffset(carrier, 0, origVt);
            } catch {
                trace("AsCall: Dev::SetOffset(carrier, 0, origVt) failed: " + getExceptionInfo());
            }
        }
        @carrier = null;
        origVt = 0;
        UnhookStub();
        if (fakeVt != 0) {
            Dev::Free(fakeVt);
            fakeVt = 0;
        }
        if (stub != 0) {
            Dev::Free(stub);
            stub = 0;
        }
        ready = false;
        @lastHookRegs = null;
    }

    string Ensure() {
        if (Ready()) {
            if (ApplyHookAfterEnsure && stub != 0) {
                wantHook = true;
                if (InOurModule()) HookStub();
            }
            return "";
        }
        lastErr = "";
        Drop();
        stub = Dev::Allocate(StubSize, true);
        if (stub == 0) {
            lastErr = "Dev::Allocate(exec stub) failed";
            return lastErr;
        }
        for (uint z = 0; z < StubSize; z++) {
            Dev::Write(stub + z, uint8(0x90));
        }
        Hex::Write(stub, CodeHex);
        if (Dev::SafeReadUInt8(stub + 0x2B) != 0x48 || Dev::SafeReadUInt8(stub + 0x2D) != 0x0D
            || Dev::SafeReadUInt8(stub + 0x5E) != 0x48 || Dev::SafeReadUInt8(stub + 0x60) != 0xC0
            || Dev::SafeReadUInt8(stub + 0x61) != 0x48 || Dev::SafeReadUInt8(stub + 0x63) != 0x0D) {
            lastErr = "stub missing OffThis carrier save/restore";
            Drop();
            return lastErr;
        }
        Hex::Write(stub + OffPing, PingHex);
        Hex::Write(stub + OffRetOnly, RetOnlyHex);
        Hex::Write(stub + OffRetRcx, RetRcxHex);
        Hex::Write(stub + OffRetRdx, RetRdxHex);
        Hex::Write(stub + OffRetR8, RetR8Hex);
        Hex::Write(stub + OffAlign, AlignHex);
        Dev::Write(stub + OffFn, uint64(0));
        Dev::Write(stub + OffRcx, uint64(0));
        Dev::Write(stub + OffRdx, uint64(0));
        Dev::Write(stub + OffR8, uint64(0));
        Dev::Write(stub + OffR9, uint64(0));
        Dev::Write(stub + OffRet, uint64(0));
        Dev::Write(stub + OffThis, uint64(0));
        wantHook = ApplyHookAfterEnsure;
        @carrier = CControlButton();
        if (carrier is null) {
            lastErr = "CControlButton() returned null";
            Drop();
            return lastErr;
        }
        origVt = Dev::GetOffsetUint64(carrier, 0);
        if (origVt == 0) {
            lastErr = "carrier vtable is 0";
            Drop();
            return lastErr;
        }
        fakeVt = Dev::Allocate(VtCopyBytes, false);
        if (fakeVt == 0) {
            lastErr = "Dev::Allocate(vtable copy) failed";
            Drop();
            return lastErr;
        }
        CopyVt(fakeVt, origVt, VtCopyBytes);
        Dev::Write(fakeVt + OnActionVtableOff, stub);
        Dev::SetOffset(carrier, 0, fakeVt);
        ready = true;
        if (ApplyHookAfterEnsure && InOurModule()) {
            HookStub();
        }
        return "";
    }

    void Shutdown() {
        if (inCall) warn("AsCall: Shutdown while inCall");
        inCall = false;
        pumpRunning = false;
        wantHook = false;
        Drop();
        lastErr = "";
    }

    uint64 Fire() {
        inCall = true;
        bool threw = false;
        try {
            carrier.OnAction();
        } catch {
            threw = true;
        }
        inCall = false;
        if (threw) throw("AsCall OnAction threw");
        return Dev::ReadUInt64(stub + OffRet);
    }

    uint64 Invoke(uint64 fn, uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
        string err = Ensure();
        if (err.Length > 0) throw(err);
        if (fn == 0) throw("AsCall fn is 0");
        try {
            Dev::SafeReadUInt8(fn);
        } catch {
            throw("AsCall fn not readable " + Text::FormatPointer(fn));
        }
        Dev::Write(stub + OffFn, fn);
        Dev::Write(stub + OffRcx, rcx);
        Dev::Write(stub + OffRdx, rdx);
        Dev::Write(stub + OffR8, r8);
        Dev::Write(stub + OffR9, r9);
        Dev::Write(stub + OffRet, uint64(0));
        Dev::Write(stub + OffThis, CarrierPtr());
        return Fire();
    }

    uint64 Call2(uint64 fn, uint64 rcx, uint edx) {
        return Invoke(fn, rcx, uint64(edx), 0, 0);
    }

    uint64 Call3(uint64 fn, uint64 rcx, uint64 rdx, uint64 r8) {
        return Invoke(fn, rcx, rdx, r8, 0);
    }

    uint64 Call4(uint64 fn, uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
        return Invoke(fn, rcx, rdx, r8, r9);
    }

    uint Ping() {
        uint64 r = Invoke(stub + OffPing, 0, 0, 0, 0);
        return uint(r);
    }

    uint Align() {
        uint64 r = Invoke(stub + OffAlign, 0, 0, 0, 0);
        return uint(r);
    }

    uint64 ProbeReg(const string &in which) {
        if (which == "rcx") return Invoke(stub + OffRetRcx, ProbeRcx, ProbeRdx, ProbeR8, 0);
        if (which == "rdx") return Invoke(stub + OffRetRdx, ProbeRcx, ProbeRdx, ProbeR8, 0);
        if (which == "r8") return Invoke(stub + OffRetR8, ProbeRcx, ProbeRdx, ProbeR8, 0);
        throw("AsCall ProbeReg: " + which);
        return 0;
    }

    uint64 CarrierPtr() {
        return carrier !is null ? Dev_GetPointerForNod(carrier) : 0;
    }

    bool CarrierRcxRestoreDispOk() {
        auto b = Hex::Parse(CodeHex);
        if (b.Length < 0x68) return false;
        if (b[0x2B] != 0x48 || b[0x2C] != 0x89 || b[0x2D] != 0x0D) return false;
        if (b[0x5E] != 0x48 || b[0x5F] != 0x31 || b[0x60] != 0xC0) return false;
        if (b[0x61] != 0x48 || b[0x62] != 0x8B || b[0x63] != 0x0D) return false;
        return true;
    }

    uint64 IsAFn() {
        if (origVt == 0) return 0;
        return Dev::ReadUInt64(origVt + 0x20);
    }

    uint64 IsA() {
        uint64 fn = IsAFn();
        if (fn == 0) throw("AsCall IsA fn is 0");
        return Invoke(fn, CarrierPtr(), uint64(ClassIdButton), 0, 0);
    }

    Json::Value@ StateJson() {
        auto o = Json::Object();
        o["ready"] = Ready();
        o["inCall"] = inCall;
        o["err"] = lastErr;
        o["stub"] = Text::FormatPointer(stub);
        o["fakeVt"] = Text::FormatPointer(fakeVt);
        o["origVt"] = Text::FormatPointer(origVt);
        o["carrier"] = carrier !is null ? Text::FormatPointer(Dev_GetPointerForNod(carrier)) : "0x0";
        if (Ready()) {
            o["slot200"] = Text::FormatPointer(Dev::ReadUInt64(fakeVt + OnActionVtableOff));
            o["fn"] = Text::FormatPointer(Dev::ReadUInt64(stub + OffFn));
            o["ret"] = Text::FormatPointer(Dev::ReadUInt64(stub + OffRet));
            o["isaFn"] = Text::FormatPointer(IsAFn());
        }
        o["hook"] = false;
        o["hookSite"] = hookSite;
        o["hookErr"] = hookErr;
        o["hookExec"] = hookExec;
        o["hookHits"] = int(hookHits);
        if (lastHookRegs !is null) {
            o["regs"] = lastHookRegs;
        }
        return o;
    }
}

void AsCall_OnStub(uint64 rcx, uint64 rdx, uint64 r8, uint64 r9) {
    AsCall::OnStub(rcx, rdx, r8, r9);
}
#endif
