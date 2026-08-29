#if DEV
// Persistent CreateVis scratch. Adapted from spike-live-add-kinematic-ao CallScratch
// (that one was CreateInst-sized). Spawn ParamsBytes must be >= ~0x90; we keep 0xA0.
namespace CallScratch {
    const uint OutBytes = 16;
    const uint ParamsBytes = 0xA0;
    const uint OffModel = 0x08;
    const uint OffPose = 0x18;
    const uint OffEntId = 0x48;

    uint64 outHandle;
    uint64 params;

    void Ensure() {
        if (outHandle == 0) outHandle = Dev::Allocate(OutBytes + ParamsBytes, false);
        params = outHandle + OutBytes;
    }

    void Shutdown() {
        if (outHandle != 0) Dev::Free(outHandle);
        outHandle = 0;
        params = 0;
    }

    void Zero(uint64 ptr, uint nbytes) {
        for (uint i = 0; i < nbytes; i += 8) {
            Dev::Write(ptr + i, uint64(0));
        }
    }

    void WriteIso4(uint64 ptr, const iso4 &in m) {
        Dev::Write(ptr + 0, vec3(m.xx, m.xy, m.xz));
        Dev::Write(ptr + 12, vec3(m.yx, m.yy, m.yz));
        Dev::Write(ptr + 24, vec3(m.zx, m.zy, m.zz));
        Dev::Write(ptr + 36, vec3(m.tx, m.ty, m.tz));
    }

    void FillCreateVis(uint64 model, uint entId, const iso4 &in pose) {
        Ensure();
        Zero(outHandle, OutBytes);
        Zero(params, ParamsBytes);
        Dev::Write(params + OffModel, model);
        WriteIso4(params + OffPose, pose);
        Dev::Write(params + OffEntId, entId);
    }
}
#endif
