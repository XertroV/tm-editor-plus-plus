#if FALSE

namespace Test_Euler {
    const string patternEulerToQuat = "F3 0F 10 49 0C 48 8D 4C 24 20 E8 57 A8 46 FF 0F 28 44 24 20";
    HookHelper@ before_e2q = HookHelper(patternEulerToQuat, 0, 0, "Test_Euler::beforeE2Q", Dev::PushRegisters::SSE, true);
    HookHelper@ before2_e2q = HookHelper(patternEulerToQuat, 5, 0, "Test_Euler::beforeE2Q2", Dev::PushRegisters::SSE, true);
    HookHelper@ after_e2q = HookHelper(patternEulerToQuat, 15, 0, "Test_Euler::afterE2Q", Dev::PushRegisters::SSE, true);


    void Hook() {
        // before_e2q.Apply();
        // before2_e2q.Apply();
        // after_e2q.Apply();
    }

    void beforeE2Q(uint64 rcx) {
        dev_trace("-- before e2q --");
        // dev_trace("rcx: " + Text::FormatPointer(rcx));
        // dev_trace("YPR: " + Dev::ReadVec3(rcx + 0xC).ToString());
        string s = "YPR: <";
        s += Text::Format("%.12f, ", Dev::ReadFloat(rcx + 0xC));
        s += Text::Format("%.12f, ", Dev::ReadFloat(rcx + 0x10));
        s += Text::Format("%.12f>", Dev::ReadFloat(rcx + 0x14));
        dev_trace(s);
    }

    uint64 stackPtrEuler;
    void beforeE2Q2(uint64 rcx) {
        dev_trace("-- before e2q2 --");
        dev_trace("rcx: " + Text::FormatPointer(rcx));
        stackPtrEuler = rcx;
        // dev_trace("YPR: " + Dev::ReadVec3(rcx + 0xC).ToString());
    }

    void afterE2Q() {
        dev_trace("-- after e2q --");
        // dev_trace("rsp: " + Text::FormatPointer(rsp));
        string s = "Q: <";
        s += Text::Format("%.12f, ", Dev::ReadFloat(stackPtrEuler));
        s += Text::Format("%.12f, ", Dev::ReadFloat(stackPtrEuler+4));
        s += Text::Format("%.12f, ", Dev::ReadFloat(stackPtrEuler+8));
        s += Text::Format("%.12f>", Dev::ReadFloat(stackPtrEuler+12));
        dev_trace(s);
    }
}
/**
Trackmania.exe+D23ECF - 48 8D 4C 24 20        - lea rcx,[rsp+20]
Trackmania.exe+D23ED4 - E8 57A846FF           - call Trackmania.exe.text+18D730 { loaded up YPR; calls eulerToQuat
 }
Trackmania.exe+D23ED9 - 0F28 44 24 20         - movaps xmm0,[rsp+20]
48 8D 4C 24 20 E8 57 A8 46 FF 0F 28 44 24 20
 */


#endif
