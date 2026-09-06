// CPlugVisual +0x24 flag bits (memory). gbx-py ChunkFlags + archive 0900600d/0e/0f.
// bit7 UseVertexNormal, bit8 UseVertexColor. Intern does not invent missing normals.
namespace VisualFlags {
    const uint16 O_FLAGS = 0x24;
    const uint32 SKIN_INDEX_MASK = 0x7;
    const uint32 BIT3 = 0x8;
    const uint32 BIT5 = 0x20;
    const uint32 USE_VERTEX_NORMAL = 0x80;
    const uint32 USE_VERTEX_COLOR = 0x100;
    const uint32 DIRTY_400 = 0x400;

    uint32 Read(CPlugVisual@ vis) {
        if (vis is null) return 0;
        return Dev::GetOffsetUint32(vis, O_FLAGS);
    }

    void Write(CPlugVisual@ vis, uint32 flags) {
        if (vis is null) return;
        Dev::SetOffset(vis, O_FLAGS, flags);
    }

    bool Bit(uint32 flags, uint32 mask) {
        return (flags & mask) != 0;
    }

    uint32 SetBit(uint32 flags, uint32 mask, bool on) {
        if (on) return flags | mask;
        return flags & ~mask;
    }
}

namespace VisualNormals {
    const uint VERTEX_STRIDE = 0x28;
    const uint16 O_VIS_VERTEXSTREAM = 0xC0;
    const uint16 O_VS_VERTEXCOUNT = 0x30;
    const uint16 O_VS_ALLOCATED_VERTEXCOUNT = 0x34;
    const uint16 O_VS_SHARED_SOURCE = 0x28;
    const uint16 O_VS_ATTRS = 0x40;
    const uint16 O_VS_NATTRS = 0x48;
    const uint16 O_VS_BLOB = 0x50;
    const uint SEM_POS = 0;
    const uint SEM_NORMAL = 5;
    const uint TYPE_FLOAT3 = 2;
    const uint TYPE_DEC3N = 14;
    const uint16 O_VIS_NSTREAMS = 0xB8;
    const uint MAX_COUNT_VERTS = 262144;
    const uint MAX_COUNT_INDICES = 1048575;
    const uint MAX_STREAM_ATTRS = 16;
    const float POSITION_GROUP_SCALE = 100000.0;
    const float POSITION_GROUP_MAX_ABS = 9.0e13;

    uint StreamElemSize(uint declType) {
        if (declType == TYPE_FLOAT3) return 12;
        if (declType == TYPE_DEC3N) return 4;
        return 0;
    }

    // D3D DECLTYPE_DEC3N / gbx-py GbxDec3N: 10-bit signed xyz, scale 0x1FF.
    uint PackDec3N(vec3 n) {
        return Tenb(n.x) | (Tenb(n.y) << 10) | (Tenb(n.z) << 20);
    }

    vec3 UnpackDec3N(uint packed) {
        return vec3(TenbToFloat(packed & 0x3FF), TenbToFloat((packed >> 10) & 0x3FF), TenbToFloat((packed >> 20) & 0x3FF));
    }

    uint Tenb(float x) {
        if (x < -1.0) x = -1.0;
        if (x > 1.0) x = 1.0;
        int v = int(x * 511.0);
        if (v < 0) v += 0x400;
        return uint(v) & 0x3FF;
    }

    float TenbToFloat(uint t) {
        int v = int(t);
        if (v >= 0x201) v -= 0x400;
        return float(v) / 511.0;
    }

    bool PtrOk(uint64 p) {
        return p != 0 && Dev_PtrUsable(p);
    }

    // Vertex/attr blobs: readable only. Do not Dev_PtrUsable — leftover
    // MwFastBuffer data ptrs are often unaligned and that logs `ptr % 8 != 0`
    // every Item Browser frame.
    bool BufOk(uint64 p) {
        return p != 0 && Dev_CanTouch(p);
    }

    bool TryReadStreamCounts(uint64 stream, uint &out logical, uint &out allocated) {
        logical = 0;
        allocated = 0;
        if (!BufOk(stream)) return false;
        if (!Dev_CanTouch(stream + O_VS_VERTEXCOUNT + 3)
            || !Dev_CanTouch(stream + O_VS_ALLOCATED_VERTEXCOUNT + 3)) return false;
        logical = Dev::ReadUInt32(stream + O_VS_VERTEXCOUNT);
        allocated = Dev::ReadUInt32(stream + O_VS_ALLOCATED_VERTEXCOUNT);
        if (logical == 0 || logical > MAX_COUNT_VERTS) return false;
        return allocated >= logical;
    }

    bool TryReadSharedSource(uint64 stream, uint64 &out sharedSource) {
        sharedSource = 0;
        if (!BufOk(stream) || !Dev_CanTouch(stream + O_VS_SHARED_SOURCE + 7)) return false;
        sharedSource = Dev::ReadUInt64(stream + O_VS_SHARED_SOURCE);
        return true;
    }

    bool IsSharedVertexStream(CPlugVisual@ vis) {
        uint64 stream = VertexStreamBase(vis);
        uint64 sharedSource = 0;
        return stream != 0 && TryReadSharedSource(stream, sharedSource) && sharedSource != 0;
    }

    uint64 ResolveAttrData(uint64 dataPtr, uint64 blob, uint packedExtra) {
        if (BufOk(dataPtr)) return dataPtr;
        if (!BufOk(blob)) return 0;
        uint byteOff = (packedExtra >> 2) & 0x3FF;
        uint64 d = blob + byteOff;
        if (!BufOk(d)) return 0;
        return d;
    }

    uint CountNonZeroVec3(uint64 data, uint n, uint stride, uint off) {
        if (!BufOk(data) || n == 0 || stride < 12) return 0;
        if (n > MAX_COUNT_VERTS) n = MAX_COUNT_VERTS;
        if (!Dev_CanTouch(data + off) || !Dev_CanTouch(data + off + 11)) return 0;
        if (n > 1 && !Dev_CanTouch(data + (n - 1) * stride + off + 11)) return 0;
        uint c = 0;
        for (uint i = 0; i < n; i++) {
            vec3 nm = Dev::ReadVec3(data + i * stride + off);
            if (nm.x * nm.x + nm.y * nm.y + nm.z * nm.z > 1e-12) c++;
        }
        return c;
    }

    uint CountNonZeroCpuNormals(CPlugVisual3D@ vis) {
        if (vis is null) return 0;
        auto verts = DPlugVisual3D(vis).Vertexes;
        if (verts.Length == 0) return 0;
        uint64 data = VertexDataPtr(verts);
        uint n = verts.Length;
        uint cap = verts.Capacity;
        if (cap > 0 && n > cap) n = cap;
        return CountNonZeroVec3(data, n, VERTEX_STRIDE, 0xC);
    }

    uint CountStreamNormalAttr(CPlugVisual@ vis) {
        uint64 data = 0;
        uint stride = 0;
        uint nv = 0;
        uint declType = 0;
        if (!FindStreamAttr(vis, SEM_NORMAL, data, stride, nv, declType)) return 0;
        uint el = StreamElemSize(declType);
        if (el == 0) return 0;
        if (stride < el) stride = el;
        if (declType == TYPE_DEC3N) return CountNonZeroDec3N(data, nv, stride);
        return CountNonZeroVec3(data, nv, stride, 0);
    }

    uint CountNonZeroDec3N(uint64 data, uint n, uint stride) {
        if (!BufOk(data) || n == 0 || stride < 4) return 0;
        if (n > MAX_COUNT_VERTS) n = MAX_COUNT_VERTS;
        if (!Dev_CanTouch(data) || !Dev_CanTouch(data + (n - 1) * stride + 3)) return 0;
        uint c = 0;
        for (uint i = 0; i < n; i++) {
            vec3 nm = UnpackDec3N(Dev::ReadUInt32(data + i * stride));
            if (nm.x * nm.x + nm.y * nm.y + nm.z * nm.z > 1e-12) c++;
        }
        return c;
    }

    uint CountUsableNormals(CPlugVisual@ vis) {
        uint cpu = CountNonZeroCpuNormals(cast<CPlugVisual3D>(vis));
        if (cpu > 0) return cpu;
        return CountStreamNormalAttr(vis);
    }

    bool FindStreamAttr(CPlugVisual@ vis, uint semantic, uint64 &out data, uint &out stride, uint &out nv, uint &out declType) {
        data = 0;
        stride = 0;
        nv = 0;
        declType = 0;
        if (vis is null) return false;
        uint64 stream = VertexStreamBase(vis);
        if (!BufOk(stream)) return false;
        if (!Dev_CanTouch(stream + O_VS_NATTRS + 3) || !Dev_CanTouch(stream + O_VS_VERTEXCOUNT + 3)) return false;
        uint allocated = 0;
        if (!TryReadStreamCounts(stream, nv, allocated)) return false;
        uint nAttr = Dev::ReadUInt32(stream + O_VS_NATTRS);
        if (nAttr == 0 || nAttr > MAX_STREAM_ATTRS) return false;
        if (!Dev_CanTouch(stream + O_VS_ATTRS + 7) || !Dev_CanTouch(stream + O_VS_BLOB + 7)) return false;
        uint64 attrs = Dev::ReadUInt64(stream + O_VS_ATTRS);
        uint64 blob = Dev::ReadUInt64(stream + O_VS_BLOB);
        if (!BufOk(attrs)) return false;
        for (uint i = 0; i < nAttr; i++) {
            uint64 ap = attrs + i * 0x10;
            if (!Dev_CanTouch(ap) || !Dev_CanTouch(ap + 0xF)) return false;
            uint packed = Dev::ReadUInt32(ap + 8);
            if ((packed & 0x1FF) != semantic) continue;
            declType = (packed >> 9) & 0x1FF;
            stride = (packed >> 18) & 0x3FF;
            data = ResolveAttrData(Dev::ReadUInt64(ap), blob, Dev::ReadUInt32(ap + 0xC));
            return data != 0;
        }
        return false;
    }

    uint64 VertexDataPtr(DPV_Vertexs@ verts) {
        if (verts is null || verts.Ptr == 0) return 0;
        // Empty/uninitialized MwFastBuffer: Length 0, data ptr may be leftover garbage
        // (unaligned → Dev_PtrUsable logs ptr%8!=0). Do not touch it.
        if (verts.Length == 0) return 0;
        if (!PtrOk(verts.Ptr)) return 0;
        uint64 data = Dev::ReadUInt64(verts.Ptr);
        if (data == 0) return 0;
        if (!PtrOk(data)) return 0;
        return data;
    }

    // Game-heap MwFastBuffer via CPlugCloudsParam.PointDists.Add then steal
    // (same as BufferAlloc / DrawLines::ResizeBuffer). Never Dev::Allocate.
    bool EnsureCpuVertexes(CPlugVisual3D@ vis, uint nv) {
        if (vis is null || nv == 0) return false;
        auto verts = DPlugVisual3D(vis).Vertexes;
        uint64 oldData = VertexDataPtr(verts);
        uint oldLen = verts.Length;
        if (oldData != 0 && verts.Capacity >= nv) {
            if (verts.Length < nv) verts.Length = nv;
            return true;
        }
        auto allocd = BufferAlloc::Alloc(nv, VERTEX_STRIDE);
        if (allocd is null || allocd.ptr == 0) return false;
        uint copyN = oldLen;
        if (copyN > nv) copyN = nv;
        if (oldData != 0 && copyN > 0) {
            for (uint i = 0; i < copyN; i++) {
                for (uint o = 0; o < VERTEX_STRIDE; o += 8) {
                    Dev::Write(allocd.ptr + i * VERTEX_STRIDE + o, Dev::ReadUInt64(oldData + i * VERTEX_STRIDE + o));
                }
            }
        }
        allocd.WriteToRawBuf(verts, nv);
        return VertexDataPtr(verts) != 0 && verts.Length == nv;
    }

    uint64 VertexStreamBase(CPlugVisual@ vis) {
        if (vis is null) return 0;
        uint64 visPtr = Dev_GetPointerForNod(vis);
        if (!PtrOk(visPtr)) return 0;
        uint nStreams = Dev::GetOffsetUint32(vis, O_VIS_NSTREAMS);
        if (nStreams == 0 || nStreams > 8) return 0;
        uint64 slot = Dev::ReadUInt64(visPtr + O_VIS_VERTEXSTREAM);
        if (slot == 0) return 0;
        // Inline CPlugVertexStream has a vtable in the exe; a heap nod is a pointer.
        if (slot >= 0x140000000 && slot < 0x150000000) {
            return visPtr + O_VIS_VERTEXSTREAM;
        }
        if (BufOk(slot) && (slot % 8 == 0)) return slot;
        return 0;
    }

    bool ReadPositionsFromVertexStream(CPlugVisual@ vis, array<vec3>@ outPos) {
        if (vis is null || outPos is null) return false;
        uint64 data = 0;
        uint stride = 0;
        uint nv = 0;
        uint declType = 0;
        if (!FindStreamAttr(vis, SEM_POS, data, stride, nv, declType) || nv < 3) return false;
        if (declType != TYPE_FLOAT3) return false;
        if (stride < 12) stride = 12;
        if (nv > MAX_COUNT_VERTS) nv = MAX_COUNT_VERTS;
        if (!Dev_CanTouch(data) || !Dev_CanTouch(data + 11)
            || !Dev_CanTouch(data + (nv - 1) * stride + 11)) return false;
        outPos.Resize(nv);
        for (uint i = 0; i < nv; i++) {
            outPos[i] = Dev::ReadVec3(data + i * stride);
        }
        return true;
    }

    bool HasGpuVertexStream(CPlugVisual@ vis) {
        return VertexStreamBase(vis) != 0;
    }

    bool WriteStreamNormals(CPlugVisual@ vis, array<vec3>@ nrm, bool &out rollbackIncomplete) {
        rollbackIncomplete = false;
        if (vis is null || nrm is null || nrm.Length < 3) return false;
        uint64 data = 0;
        uint stride = 0;
        uint nv = 0;
        uint declType = 0;
        if (!FindStreamAttr(vis, SEM_NORMAL, data, stride, nv, declType)) return false;
        uint el = StreamElemSize(declType);
        if (el == 0) return false;
        if (stride < el) stride = el;
        if (nv < 3 || nv != nrm.Length) return false;
        if (!Dev_CanTouch(data) || !Dev_CanTouch(data + (nv - 1) * stride + (el - 1))) return false;
        array<uint> oldPacked;
        array<vec3> oldFloat;
        if (declType == TYPE_DEC3N) oldPacked.Resize(nv);
        else oldFloat.Resize(nv);
        for (uint i = 0; i < nv; i++) {
            if (MathX::IsNanInf(nrm[i])) return false;
            uint64 p = data + i * stride;
            if (!Dev_CanTouch(p) || !Dev_CanTouch(p + el - 1)) return false;
            if (declType == TYPE_DEC3N) oldPacked[i] = Dev::ReadUInt32(p);
            else oldFloat[i] = Dev::ReadVec3(p);
        }
        for (uint i = 0; i < nv; i++) {
            uint64 p = data + i * stride;
            bool wrote = false;
            if (declType == TYPE_DEC3N) {
                wrote = Dev_SafeWriteUInt32(p, PackDec3N(nrm[i]));
            } else {
                wrote = Dev_SafeWriteVec3(p, nrm[i]);
            }
            if (!wrote) {
                for (uint j = 0; j < i; j++) {
                    uint64 oldP = data + j * stride;
                    bool restored = declType == TYPE_DEC3N
                        ? Dev_SafeWriteUInt32(oldP, oldPacked[j])
                        : Dev_SafeWriteVec3(oldP, oldFloat[j]);
                    if (!restored) rollbackIncomplete = true;
                }
                return false;
            }
        }
        return true;
    }

    bool TryPositionGroupKey(const vec3 &in pos, string &out key) {
        key = "";
        if (MathX::IsNanInf(pos)
            || Math::Abs(pos.x) > POSITION_GROUP_MAX_ABS
            || Math::Abs(pos.y) > POSITION_GROUP_MAX_ABS
            || Math::Abs(pos.z) > POSITION_GROUP_MAX_ABS) return false;
        key = tostring(int64(Math::Round(pos.x * POSITION_GROUP_SCALE))) + "|"
            + tostring(int64(Math::Round(pos.y * POSITION_GROUP_SCALE))) + "|"
            + tostring(int64(Math::Round(pos.z * POSITION_GROUP_SCALE)));
        return true;
    }

    bool TryNormalizeNormalSum(const vec3 &in sum, vec3 &out normalized) {
        normalized = vec3();
        if (MathX::IsNanInf(sum)) return false;
        float scale = Math::Max(Math::Abs(sum.x), Math::Max(Math::Abs(sum.y), Math::Abs(sum.z)));
        if (scale <= 1e-20 || Math::IsNaN(scale) || Math::IsInf(scale)) return false;
        vec3 scaled = sum / scale;
        float ls = scaled.LengthSquared();
        if (ls <= 1e-20 || Math::IsNaN(ls) || Math::IsInf(ls)) return false;
        normalized = scaled / Math::Sqrt(ls);
        return !MathX::IsNanInf(normalized);
    }

    bool CalculateFullySmoothNormals(array<vec3>@ pos, array<uint>@ indices, array<vec3>@ acc, string &out err) {
        err = "";
        if (pos is null || indices is null || acc is null || pos.Length < 3) {
            err = "need at least 3 positions";
            return false;
        }
        if (indices.Length < 3 || indices.Length % 3 != 0) {
            err = "index count must be a nonzero multiple of 3";
            return false;
        }
        uint nv = pos.Length;
        dictionary groupByPosition;
        array<uint> vertexGroup(nv);
        array<vec3> groupAcc;
        for (uint i = 0; i < nv; i++) {
            if (MathX::IsNanInf(pos[i])) {
                err = "position " + i + " is not finite";
                return false;
            }
            string key;
            if (!TryPositionGroupKey(pos[i], key)) {
                err = "position " + i + " is outside the weld-key quantization range";
                return false;
            }
            uint group = 0;
            if (!groupByPosition.Get(key, group)) {
                group = groupAcc.Length;
                groupByPosition.Set(key, group);
                groupAcc.InsertLast(vec3());
            }
            vertexGroup[i] = group;
        }

        for (uint t = 0; t < indices.Length; t += 3) {
            uint i0 = indices[t];
            uint i1 = indices[t + 1];
            uint i2 = indices[t + 2];
            if (i0 >= nv || i1 >= nv || i2 >= nv) {
                err = "triangle " + (t / 3) + " index out of range";
                return false;
            }
            vec3 fn = Math::Cross(pos[i1] - pos[i0], pos[i2] - pos[i0]);
            if (MathX::IsNanInf(fn)) {
                err = "triangle " + (t / 3) + " produced a non-finite normal";
                return false;
            }
            if (fn.LengthSquared() <= 1e-20) continue;
            uint g0 = vertexGroup[i0];
            uint g1 = vertexGroup[i1];
            uint g2 = vertexGroup[i2];
            groupAcc[g0] += fn;
            if (g1 != g0) groupAcc[g1] += fn;
            if (g2 != g0 && g2 != g1) groupAcc[g2] += fn;
        }

        acc.Resize(nv);
        for (uint i = 0; i < nv; i++) {
            vec3 n = groupAcc[vertexGroup[i]];
            if (MathX::IsNanInf(n)) {
                err = "normal accumulator " + i + " is not finite";
                return false;
            }
            if (!TryNormalizeNormalSum(n, n)) n = vec3(0, 1, 0);
            if (MathX::IsNanInf(n)) {
                err = "normal " + i + " is not finite";
                return false;
            }
            acc[i] = n;
        }
        return true;
    }

    bool IsTriangleIndexCountValid(uint nIdx) {
        return nIdx >= 3 && nIdx <= MAX_COUNT_INDICES && nIdx % 3 == 0;
    }

    bool SnapshotTriangleIndices(DPlugIndexBuffer@ ib, uint nv, array<uint>@ indices, string &out err) {
        err = "";
        if (ib is null || indices is null) {
            err = "IndexBuffer null";
            return false;
        }
        uint nIdx = ib.GetUint32(0x30);
        uint64 idxPtr = ib.GetUint64(0x28);
        if (idxPtr == 0 || !IsTriangleIndexCountValid(nIdx)) {
            err = "IndexBuffer count must be a nonzero multiple of 3 and <= " + MAX_COUNT_INDICES + ": " + nIdx;
            return false;
        }
        uint indexType = ib.GetUint32(0x20) >> 2;
        if (indexType > 1) {
            err = "unsupported IndexBuffer type " + indexType;
            return false;
        }
        uint elemSize = indexType == 0 ? 2 : 4;
        if (!Dev_CanTouch(idxPtr) || !Dev_CanTouch(idxPtr + (nIdx - 1) * elemSize + elemSize - 1)) {
            err = "IndexBuffer CPU data is not readable";
            return false;
        }
        indices.Resize(nIdx);
        for (uint i = 0; i < nIdx; i++) {
            uint ix = indexType == 0 ? Dev::ReadUInt16(idxPtr + i * 2) : Dev::ReadUInt32(idxPtr + i * 4);
            if (ix >= nv) {
                err = "triangle " + (i / 3) + " index out of range: " + ix + " >= " + nv;
                return false;
            }
            indices[i] = ix;
        }
        return true;
    }

    // Item editor always initializes a CPlugVertexStream. Recalc writes that
    // Normal attr (Dec3N or Float3). Never steal CPU Vertexes: intern would
    // emit a 0902C004 blob load skips, then crash (LogCrash RIP 0x1418D74FB).
    bool RecalcSmoothFromCpuVerts(CPlugVisualIndexedTriangles@ vis) {
        string err;
        bool partialWrite;
        bool ok = RecalcSmoothFromCpuVerts(vis, err, partialWrite);
        if (!ok && err.Length > 0) NotifyWarning("Recalc: " + err);
        return ok;
    }

    bool RecalcSmoothFromCpuVerts(CPlugVisualIndexedTriangles@ vis, string &out err) {
        bool partialWrite;
        return RecalcSmoothFromCpuVerts(vis, err, partialWrite);
    }

    bool RecalcSmoothFromCpuVerts(CPlugVisualIndexedTriangles@ vis, string &out err, bool &out partialWrite) {
        err = "";
        partialWrite = false;
        if (vis is null) return false;
        auto v3 = cast<CPlugVisual3D>(vis);
        if (v3 is null) return false;
        auto d3 = DPlugVisual3D(v3);
        auto verts = d3.Vertexes;
        uint nv = verts.Length;
        array<vec3> pos;
        bool fromStream = HasGpuVertexStream(vis);
        if (fromStream) {
            if (nv != 0) {
                err = "visual has both CPU Vertexes and a VertexStream; refusing ambiguous representation";
                return false;
            }
            uint64 sharedSource = 0;
            uint64 stream = VertexStreamBase(vis);
            if (!TryReadSharedSource(stream, sharedSource)) {
                err = "could not validate VertexStream ownership";
                return false;
            }
            if (sharedSource != 0) {
                err = "shared VertexStream source is not mutated safely; make the visual stream unique first";
                return false;
            }
            if (!ReadPositionsFromVertexStream(vis, pos) || pos.Length < 3) {
                err = "no safe Position stream attr (requires logical count +0x30 and readable Float3 data)";
                return false;
            }
            nv = pos.Length;
        } else if (nv < 3) {
            err = "no VertexStream and CPU Vertexes.Length=" + nv;
            return false;
        } else {
            pos.Resize(nv);
            for (uint i = 0; i < nv; i++) {
                pos[i] = verts.GetVertex(i).Pos;
            }
        }
        auto dIx = DPlugVisualIndexedTriangles(vis);
        auto ib = dIx.IndexBuffer;
        array<uint> indices;
        if (!SnapshotTriangleIndices(ib, nv, indices, err)) return false;

        array<vec3> acc;
        if (!CalculateFullySmoothNormals(pos, indices, acc, err)) return false;
        if (fromStream) {
            if (!WriteStreamNormals(vis, acc, partialWrite)) {
                err = partialWrite
                    ? "Normal attr write failed and rollback was incomplete; visual may be partially mutated"
                    : "no writable Normal attr matching logical vertex count (need Float3 or Dec3N)";
                return false;
            }
        } else {
            for (uint i = 0; i < nv; i++) {
                verts.GetVertex(i).Normal = acc[i];
            }
        }
        vis.UseVertexNormal = true;
        return true;
    }

    class RecalcJob {
        array<CPlugVisualIndexedTriangles@> visuals;
        CGameEditorItem@ editor;
        CGameItemModel@ item;
        bool batch;

        RecalcJob(array<CPlugVisualIndexedTriangles@>@ src) {
            if (src !is null) {
                for (uint i = 0; i < src.Length; i++) visuals.InsertLast(src[i]);
            }
            @editor = cast<CGameEditorItem>(GetApp().Editor);
            if (editor !is null) @item = editor.ItemModel;
            batch = visuals.Length > 1;
        }

        bool IsStillCurrent() {
            auto current = cast<CGameEditorItem>(GetApp().Editor);
            return editor !is null && current is editor && item !is null && editor.ItemModel is item;
        }

        void Start() {
            g_recalcRunning = true;
            @g_recalcJob = this;
            startnew(CoroutineFunc(this.Run));
        }

        void Run() {
            string fatal;
            try {
                RunInner();
            } catch {
                fatal = getExceptionInfo();
            }
            if (fatal.Length > 0) {
                error("Smooth-normal recalculation exception: " + fatal);
                NotifyError("Smooth-normal recalculation failed safely; see log.");
            }
            g_recalcRunning = false;
            @g_recalcJob = null;
        }

        void RunInner() {
            if (visuals.Length == 0) {
                NotifyWarning("No visuals were queued for smooth-normal recalculation.");
                return;
            }
            uint written = 0;
            uint failed = 0;
            for (uint i = 0; i < visuals.Length; i++) {
                if (!IsStillCurrent()) {
                    NotifyWarning("Smooth-normal recalculation stopped because the current Item Editor item changed.");
                    return;
                }
                string err;
                if (visuals[i] !is null && RecalcSmoothFromCpuVerts(visuals[i], err)) {
                    written++;
                } else {
                    failed++;
                    warn("Visual " + i + " smooth-normal recalc failed: " + err);
                }
                yield();
            }
            if (written > 0) {
                NotifySuccess("Recalculated fully smooth normals for " + written
                    + " visual(s). Save and reopen the item to upload and verify them."
                    + (failed > 0 ? " " + failed + " failed; see log." : ""));
            } else {
                NotifyWarning("No visual normals were recalculated; see log.");
            }
        }
    }

    bool g_recalcRunning = false;
    RecalcJob@ g_recalcJob;

    bool IsRecalcRunning() {
        return g_recalcRunning;
    }

    void StartRecalc(array<CPlugVisualIndexedTriangles@>@ visuals) {
        if (g_recalcRunning) {
            NotifyWarning("A smooth-normal recalculation is already running.");
            return;
        }
        auto job = RecalcJob(visuals);
        job.Start();
    }

    void StartRecalc(CPlugVisualIndexedTriangles@ visual) {
        array<CPlugVisualIndexedTriangles@> visuals;
        if (visual !is null) visuals.InsertLast(visual);
        StartRecalc(visuals);
    }
}

namespace ItemEditor {
    const uint SMOOTH_NORMALS_MAX_ENTITY_DEPTH = 16;
    const uint SMOOTH_NORMALS_MAX_ENTITY_NODES = 4096;
    const uint SMOOTH_NORMALS_MAX_ENTITY_CHILDREN = 4096;
    const uint SMOOTH_NORMALS_MAX_ENTITY_EDGES = 16384;
    const uint SMOOTH_NORMALS_MAX_SOLID2 = 512;
    const uint SMOOTH_NORMALS_MAX_VISUALS_PER_SOLID2 = 1024;
    const uint SMOOTH_NORMALS_MAX_TOTAL_VISUALS = 4096;

    class SmoothNormalsCollectState {
        uint visited = 0;
        uint edges = 0;
        string err;

        bool TakeEdge() {
            edges++;
            if (edges <= SMOOTH_NORMALS_MAX_ENTITY_EDGES) return true;
            err = "item entity graph exceeds edge limit " + SMOOTH_NORMALS_MAX_ENTITY_EDGES;
            return false;
        }
    }

    bool CollectSolid2Models(
        CMwNod@ nod,
        uint depth,
        dictionary@ seen,
        array<CPlugSolid2Model@>@ solid2s,
        SmoothNormalsCollectState@ state
    ) {
        if (nod is null) return true;
        if (seen is null || solid2s is null || state is null) {
            if (state !is null) state.err = "internal collector state is null";
            return false;
        }
        string key = Text::FormatPointer(Dev_GetPointerForNod(nod));
        if (seen.Exists(key)) return true;
        if (depth > SMOOTH_NORMALS_MAX_ENTITY_DEPTH) {
            state.err = "item entity graph exceeds depth limit " + SMOOTH_NORMALS_MAX_ENTITY_DEPTH;
            return false;
        }
        seen.Set(key, true);
        state.visited++;
        if (state.visited > SMOOTH_NORMALS_MAX_ENTITY_NODES) {
            state.err = "item entity graph exceeds node limit " + SMOOTH_NORMALS_MAX_ENTITY_NODES;
            return false;
        }

        auto s2m = cast<CPlugSolid2Model>(nod);
        if (s2m !is null) {
            if (solid2s.Length >= SMOOTH_NORMALS_MAX_SOLID2) {
                state.err = "item exceeds Solid2 limit " + SMOOTH_NORMALS_MAX_SOLID2;
                return false;
            }
            solid2s.InsertLast(s2m);
            return true;
        }

        auto staticObj = cast<CPlugStaticObjectModel>(nod);
        if (staticObj !is null) {
            return CollectSolid2Models(staticObj.Mesh, depth + 1, seen, solid2s, state);
        }

        auto dyna = cast<CPlugDynaObjectModel>(nod);
        if (dyna !is null) {
            return CollectSolid2Models(dyna.Mesh, depth + 1, seen, solid2s, state);
        }

        auto common = cast<CGameCommonItemEntityModel>(nod);
        if (common !is null) {
            return CollectSolid2Models(common.StaticObject, depth + 1, seen, solid2s, state);
        }

        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) {
            if (prefab.Ents.Length > SMOOTH_NORMALS_MAX_ENTITY_CHILDREN) {
                state.err = "prefab exceeds child limit " + SMOOTH_NORMALS_MAX_ENTITY_CHILDREN;
                return false;
            }
            for (uint i = 0; i < prefab.Ents.Length; i++) {
                if (!state.TakeEdge()) return false;
                if (!CollectSolid2Models(prefab.Ents[i].Model, depth + 1, seen, solid2s, state)) return false;
            }
            return true;
        }

        auto variants = cast<NPlugItem_SVariantList>(nod);
        if (variants !is null) {
            if (variants.Variants.Length > SMOOTH_NORMALS_MAX_ENTITY_CHILDREN) {
                state.err = "variant list exceeds child limit " + SMOOTH_NORMALS_MAX_ENTITY_CHILDREN;
                return false;
            }
            for (uint i = 0; i < variants.Variants.Length; i++) {
                if (!state.TakeEdge()) return false;
                if (!CollectSolid2Models(variants.Variants[i].EntityModel, depth + 1, seen, solid2s, state)) return false;
            }
            return true;
        }

        auto edition = cast<CGameCommonItemEntityModelEdition>(nod);
        if (edition !is null) {
            return CollectSolid2Models(edition.MeshCrystal, depth + 1, seen, solid2s, state);
        }

        return true;
    }

    bool RecalcCurrentItemFullySmoothNormals(
        uint &out solid2Count,
        uint &out visualCount,
        uint &out writtenCount,
        uint &out failedCount,
        uint &out partialWriteCount,
        string &out firstError
    ) {
        solid2Count = 0;
        visualCount = 0;
        writtenCount = 0;
        failedCount = 0;
        partialWriteCount = 0;
        firstError = "";

        auto editor = cast<CGameEditorItem>(GetApp().Editor);
        if (editor is null || editor.ItemModel is null) {
            firstError = "not in Item Editor or no current item";
            return false;
        }

        auto item = editor.ItemModel;
        dictionary seen;
        array<CPlugSolid2Model@> solid2s;
        auto state = SmoothNormalsCollectState();
        if (!CollectSolid2Models(item.EntityModel, 0, seen, solid2s, state)
            || !CollectSolid2Models(item.EntityModelEdition, 0, seen, solid2s, state)) {
            firstError = state.err;
            return false;
        }
        solid2Count = solid2s.Length;
        if (solid2Count == 0) {
            firstError = "current item contains no CPlugSolid2Model";
            return false;
        }

        array<CPlugVisualIndexedTriangles@> visuals;
        for (uint s = 0; s < solid2s.Length; s++) {
            uint nb = Dev::GetOffsetUint32(solid2s[s], O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 0x8);
            if (nb > SMOOTH_NORMALS_MAX_VISUALS_PER_SOLID2
                || visualCount + nb > SMOOTH_NORMALS_MAX_TOTAL_VISUALS) {
                failedCount = 1;
                firstError = "visual count exceeds safety limit at Solid2 " + s + ": " + nb;
                return false;
            }
            auto visBuf = Dev::GetOffsetNod(solid2s[s], O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
            if (nb > 0 && visBuf is null) {
                failedCount = 1;
                firstError = "Solid2 " + s + " has a null visual buffer with count " + nb;
                return false;
            }
            for (uint v = 0; v < nb; v++) {
                auto visual = cast<CPlugVisualIndexedTriangles>(Dev::GetOffsetNod(visBuf, v * 0x8));
                if (visual is null) {
                    failedCount = 1;
                    firstError = "Solid2 " + s + " visual " + v + " is null or not indexed triangles";
                    return false;
                }
                visuals.InsertLast(visual);
            }
            visualCount += nb;
        }
        if (visualCount == 0) {
            firstError = "current item's Solid2 models contain no visuals";
            return false;
        }

        for (uint i = 0; i < visuals.Length; i++) {
            string err;
            bool partialWrite;
            if (VisualNormals::RecalcSmoothFromCpuVerts(visuals[i], err, partialWrite)) {
                writtenCount++;
            } else {
                failedCount++;
                if (partialWrite) partialWriteCount++;
                if (firstError.Length == 0) firstError = "visual " + i + ": " + err;
            }
        }
        return writtenCount == visualCount && failedCount == 0 && partialWriteCount == 0;
    }
}
