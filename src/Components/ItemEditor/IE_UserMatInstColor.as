// CPlugMaterialUserInst custom TargetColor (Item Browser).
// Layout from CPlugMaterialUserInst_TryAddTargetColorParam / SerializeArchiveChunk:
//   +0x14C uint32 nParams (max 8)
//   +0x150 slot {MwId name, MwId type, uint32 nValues, uint32 valueOffset} stride 0x10
//   +0x1D0 MwFastBuffer stride-4 (ptr, count, cap) of Real values
// On GBX load, integer bits 1..255 are converted to unit floats (v/255). Runtime is 0..1 floats.

namespace UserMatInstColor {
    float BitsToFloat(uint bits) {
        auto mb = MemoryBuffer();
        mb.Write(bits);
        mb.Seek(0);
        return mb.ReadFloat();
    }

    // Same conversion CPlugMaterialUserInst_SerializeArchiveChunk applies on load.
    float DecodeRealBits(uint bits) {
        if (bits >= 1 && bits <= 255) {
            return float(bits) / 255.0;
        }
        return BitsToFloat(bits);
    }

    vec3 ReadColor(uint64 colorPtr) {
        return vec3(
            DecodeRealBits(Dev::ReadUInt32(colorPtr + 0x0)),
            DecodeRealBits(Dev::ReadUInt32(colorPtr + 0x4)),
            DecodeRealBits(Dev::ReadUInt32(colorPtr + 0x8))
        );
    }

    void WriteColor(uint64 colorPtr, const vec3 &in col) {
        Dev::Write(colorPtr + 0x0, col.x);
        Dev::Write(colorPtr + 0x4, col.y);
        Dev::Write(colorPtr + 0x8, col.z);
    }

    void Clear(CMwNod@ nod) {
        if (nod is null) return;
        Dev::SetOffset(nod, O_USERMATINST_PARAM_EXISTS, uint32(0));
        Dev::SetOffset(nod, O_USERMATINST_PARAM_MWID_NAME, uint32(0xFFFFFFFF));
        Dev::SetOffset(nod, O_USERMATINST_PARAM_MWID_TYPE, uint32(0xFFFFFFFF));
        Dev::SetOffset(nod, O_USERMATINST_PARAM_LEN, uint32(0xFFFFFFFF));
        Dev::SetOffset(nod, O_USERMATINST_PARAM_VALOFF, uint32(0xFFFFFFFF));
        // Keep +0x1D0 ptr so Destroy's MwFastBuffer free still runs.
        Dev::SetOffset(nod, O_USERMATINST_COLORBUF + 0x8, uint32(0));
    }

    void Instantiate(CMwNod@ nod) {
        if (nod is null) return;
        auto colorPtr = Dev::GetOffsetUint64(nod, O_USERMATINST_COLORBUF);
        if (colorPtr == 0) {
            colorPtr = RequestMemory(0x10);
            Dev::SetOffset(nod, O_USERMATINST_COLORBUF, colorPtr);
            Dev::SetOffset(nod, O_USERMATINST_COLORBUF + 0xC, uint32(3));
        }
        Dev::SetOffset(nod, O_USERMATINST_COLORBUF + 0x8, uint32(3));
        WriteColor(colorPtr, vec3(1, 1, 1));
        auto tyid = MwId();
        tyid.SetName("Real");
        auto targetid = MwId();
        targetid.SetName("TargetColor");
        Dev::SetOffset(nod, O_USERMATINST_PARAM_EXISTS, uint32(1));
        Dev::SetOffset(nod, O_USERMATINST_PARAM_MWID_NAME, targetid.Value);
        Dev::SetOffset(nod, O_USERMATINST_PARAM_MWID_TYPE, tyid.Value);
        Dev::SetOffset(nod, O_USERMATINST_PARAM_LEN, uint32(3));
        Dev::SetOffset(nod, O_USERMATINST_PARAM_VALOFF, uint32(0));
    }
}
