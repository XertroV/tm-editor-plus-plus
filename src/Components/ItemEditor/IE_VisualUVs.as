// UV (TexCoordN) inspection and in-place translation on CPlugVisual vertex streams.
// Layout: research/2026-09-03-MeshUVs.md. Uses VisualNormals::FindStreamAttr (IE_Visual.as).
// Semantics 10..17 = TexCoord0..7; format 1 = Float2. TexCoord1 is usually the lightmap set.
namespace VisualUVs {
    const uint SEM_TEXCOORD0 = 10;
    const uint SEM_TEXCOORD_LAST = 17;
    const uint FMT_FLOAT2 = 1;

    class UvAttr {
        uint semantic;
        uint declType;
        uint stride;
        uint nv;
        uint64 data;
        vec2 uvMin;
        vec2 uvMax;
        vec2 first;
        string SemName() { return "TexCoord" + (semantic - SEM_TEXCOORD0); }
        bool IsFloat2() { return declType == FMT_FLOAT2; }
    }

    // Every TexCoord attribute on the visual's stream (ranges computed for Float2 only).
    array<UvAttr@>@ Scan(CPlugVisual@ vis) {
        array<UvAttr@> ret;
        if (vis is null) return ret;
        for (uint sem = SEM_TEXCOORD0; sem <= SEM_TEXCOORD_LAST; sem++) {
            uint64 data; uint stride; uint nv; uint declType;
            if (!VisualNormals::FindStreamAttr(vis, sem, data, stride, nv, declType)) continue;
            UvAttr a;
            a.semantic = sem; a.declType = declType; a.stride = stride; a.nv = nv; a.data = data;
            if (a.IsFloat2() && nv > 0 && stride > 0) {
                a.uvMin = vec2(1e30, 1e30); a.uvMax = vec2(-1e30, -1e30);
                for (uint i = 0; i < nv; i++) {
                    uint64 p = data + i * stride;
                    vec2 uv = vec2(Dev::ReadFloat(p), Dev::ReadFloat(p + 4));
                    if (i == 0) a.first = uv;
                    a.uvMin.x = Math::Min(a.uvMin.x, uv.x); a.uvMin.y = Math::Min(a.uvMin.y, uv.y);
                    a.uvMax.x = Math::Max(a.uvMax.x, uv.x); a.uvMax.y = Math::Max(a.uvMax.y, uv.y);
                }
            }
            ret.InsertLast(a);
        }
        return ret;
    }

    // Add (du, dv) to every vertex of a Float2 TexCoord attribute. Returns vertices touched.
    // Persistent once the item is saved; the GPU copy is only refreshed by save + reopen.
    uint Shift(CPlugVisual@ vis, uint semantic, float du, float dv) {
        uint64 data; uint stride; uint nv; uint declType;
        if (!VisualNormals::FindStreamAttr(vis, semantic, data, stride, nv, declType)) return 0;
        if (declType != FMT_FLOAT2 || stride == 0) return 0;
        for (uint i = 0; i < nv; i++) {
            uint64 p = data + i * stride;
            Dev::Write(p, Dev::ReadFloat(p) + du);
            Dev::Write(p + 4, Dev::ReadFloat(p + 4) + dv);
        }
        return nv;
    }

    // ---- Solid2: visual -> material (ShadedGeoms at +0x158, stride 16: visIdx, matIdx, lodMask, flags)
    const uint16 O_S2M_SHADEDGEOMS = 0x158;

    int MaterialIndexOfVisual(CPlugSolid2Model@ s2m, uint visIdx) {
        uint n = Dev::GetOffsetUint32(s2m, O_S2M_SHADEDGEOMS + 8);
        uint64 buf = Dev::GetOffsetUint64(s2m, O_S2M_SHADEDGEOMS);
        for (uint i = 0; i < n && buf != 0; i++) {
            if (uint(Dev::ReadInt32(buf + i * 16)) == visIdx) return Dev::ReadInt32(buf + i * 16 + 4);
        }
        return -1;
    }

    string MaterialName(CPlugSolid2Model@ s2m, int matIdx) {
        if (matIdx < 0) return "";
        uint nUser = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_USERMAT_BUF + 8);
        if (nUser > 0) {
            if (uint(matIdx) >= nUser) return "";
            auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_USERMAT_BUF);
            auto mat = cast<CPlugMaterialUserInst>(Dev::GetOffsetNod(buf, matIdx * 0x18));
            if (mat is null) return "";
            return mat._LinkFull.Length > 0 ? mat._LinkFull : mat._Name.GetName();
        }
        uint nMat = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_MATERIALS_BUF + 8);
        if (uint(matIdx) >= nMat) return "";
        auto mbuf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_MATERIALS_BUF);
        auto m = Dev::GetOffsetNod(mbuf, matIdx * 8);
        return m is null ? "" : m.IdName;
    }
}
