namespace MeshDuplication {
    // VertexTween packed frames (flags): each CPlugVisualIndexedTriangles LOD has
    // its own verts-per-frame. Sharing LOD0's 0x09006005 stride / leaving AABB at
    // half.x=-1 makes LOD1+ noisy and frustum-cull off-angle.

    bool VertexTween_TryVertsPerFrame(uint vertexCount, uint frameCount, uint &out vpf) {
        vpf = 0;
        if (frameCount < 2 || vertexCount < frameCount) return false;
        if (vertexCount % frameCount != 0) return false;
        vpf = vertexCount / frameCount;
        return vpf > 0;
    }

    void VertexTween_AabbFromMinMax(const vec3 &in mn, const vec3 &in mx, vec3 &out center, vec3 &out half) {
        center = (mn + mx) * 0.5;
        half = (mx - mn) * 0.5;
        if (half.x < 0) half.x = 0;
        if (half.y < 0) half.y = 0;
        if (half.z < 0) half.z = 0;
    }

    void VertexTween_UnionAabb(const vec3 &in center, const vec3 &in half, const vec3 &in oc, const vec3 &in oh, vec3 &out outC, vec3 &out outH) {
        if (oh.x < 0) {
            outC = center;
            outH = half;
            return;
        }
        if (half.x < 0) {
            outC = oc;
            outH = oh;
            return;
        }
        VertexTween_AabbFromMinMax(
            MathX::Min(center - half, oc - oh),
            MathX::Max(center + half, oc + oh),
            outC, outH);
    }

    void VertexTween_WriteFrames(uint64 dst, uint frameCount, uint vpf, uint indexCount) {
        for (uint k = 0; k < frameCount; k++) {
            Dev::Write(dst + k * 12, uint(k * vpf));
            Dev::Write(dst + k * 12 + 4, uint(0));
            Dev::Write(dst + k * 12 + 8, uint(indexCount));
        }
    }

    bool Solid2HasVertexTween(CPlugSolid2Model@ mesh) {
        if (mesh is null) return false;
        auto visBuf = Dev::GetOffsetNod(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        uint nbVis = Dev::GetOffsetUint32(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 0x8);
        if (visBuf is null) return false;
        for (uint i = 0; i < nbVis; i++) {
            auto vis = cast<CPlugVisualIndexedTriangles>(Dev::GetOffsetNod(visBuf, i * 0x8));
            if (vis is null) continue;
            if (Dev::GetOffsetUint32(vis, O_CPLUGVISUAL_SUBVISUALS_BUF + 0x8) > 1) return true;
        }
        return false;
    }

    void Solid2FillAabbFromVisuals(CPlugSolid2Model@ mesh) {
        if (mesh is null) return;
        auto visBuf = Dev::GetOffsetNod(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        uint nbVis = Dev::GetOffsetUint32(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 0x8);
        if (visBuf is null || nbVis == 0) return;
        vec3 solidC, solidH = vec3(-1, -1, -1);
        for (uint i = 0; i < nbVis; i++) {
            auto vis = cast<CPlugVisualIndexedTriangles>(Dev::GetOffsetNod(visBuf, i * 0x8));
            if (vis is null) continue;
            vec3 h = Dev::GetOffsetVec3(vis, O_CPLUGVISUAL_AABB_HALF);
            if (h.x < 0) continue;
            vec3 c = Dev::GetOffsetVec3(vis, O_CPLUGVISUAL_AABB_CENTER);
            vec3 nc, nh;
            VertexTween_UnionAabb(solidC, solidH, c, h, nc, nh);
            solidC = nc;
            solidH = nh;
        }
        if (solidH.x >= 0) {
            Dev::SetOffset(mesh, O_SOLID2MODEL_AABB_CENTER, solidC);
            Dev::SetOffset(mesh, O_SOLID2MODEL_AABB_HALF, solidH);
        }
    }

    void Solid2AliasCustomMatsIfEmpty(CPlugSolid2Model@ mesh) {
        if (mesh is null) return;
        uint nbMats = Dev::GetOffsetUint32(mesh, O_SOLID2MODEL_MATERIALS_BUF + 0x8);
        uint nbCust = Dev::GetOffsetUint32(mesh, O_SOLID2MODEL_CUSTMAT_BUF + 0x8);
        if (nbMats > 0 || nbCust == 0) return;
        uint64 ptr = Dev::GetOffsetUint64(mesh, O_SOLID2MODEL_CUSTMAT_BUF);
        uint64 len = Dev::GetOffsetUint64(mesh, O_SOLID2MODEL_CUSTMAT_BUF + 0x8);
        if (ptr == 0) return;
        Dev::SetOffset(mesh, O_SOLID2MODEL_MATERIALS_BUF, ptr);
        Dev::SetOffset(mesh, O_SOLID2MODEL_MATERIALS_BUF + 0x8, len);
        if (Dev::GetOffsetUint32(mesh, O_SOLID2MODEL_CUSTMAT_BUF_COPY + 0x8) == 0) {
            Dev::SetOffset(mesh, O_SOLID2MODEL_CUSTMAT_BUF_COPY, ptr);
            Dev::SetOffset(mesh, O_SOLID2MODEL_CUSTMAT_BUF_COPY + 0x8, len);
        }
    }

    void RepairSolid2VertexTween(CPlugSolid2Model@ mesh) {
        if (mesh is null || !Solid2HasVertexTween(mesh)) return;
        Solid2FillAabbFromVisuals(mesh);
        Solid2AliasCustomMatsIfEmpty(mesh);
    }

    void RepairVertexTweenInNod(CMwNod@ nod, uint depth = 0) {
        if (nod is null || depth > 8) return;
        auto s2m = cast<CPlugSolid2Model>(nod);
        if (s2m !is null) {
            RepairSolid2VertexTween(s2m);
            return;
        }
        auto so = cast<CPlugStaticObjectModel>(nod);
        if (so !is null) {
            RepairVertexTweenInNod(so.Mesh, depth + 1);
            return;
        }
        auto dyna = cast<CPlugDynaObjectModel>(nod);
        if (dyna !is null) {
            RepairVertexTweenInNod(dyna.Mesh, depth + 1);
            return;
        }
        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) {
            for (uint i = 0; i < prefab.Ents.Length; i++) {
                RepairVertexTweenInNod(prefab.Ents[i].Model, depth + 1);
            }
            return;
        }
        auto vars = cast<NPlugItem_SVariantList>(nod);
        if (vars !is null) {
            for (uint i = 0; i < vars.Variants.Length; i++) {
                RepairVertexTweenInNod(vars.Variants[i].EntityModel, depth + 1);
            }
        }
    }

    void FixSolid2VertexTweenLods(CPlugSolid2Model@ mesh) {
        if (mesh is null) return;
        auto visBuf = Dev::GetOffsetNod(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        uint nbVis = Dev::GetOffsetUint32(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 0x8);
        if (visBuf is null || nbVis == 0) return;

        uint64[] seenSubvis;
        vec3 solidC, solidH = vec3(-1, -1, -1);
        bool anyTween = false;

        for (uint i = 0; i < nbVis; i++) {
            auto vis = cast<CPlugVisualIndexedTriangles>(Dev::GetOffsetNod(visBuf, i * 0x8));
            if (vis is null) continue;

            uint frameCount = Dev::GetOffsetUint32(vis, O_CPLUGVISUAL_SUBVISUALS_BUF + 0x8);
            auto dvis = DPlugVisual3D(Dev_GetPointerForNod(vis));
            auto verts = dvis.Vertexes;
            uint vertexCount = verts.Length;

            uint indexCount = 0;
            auto ib = DPlugVisualIndexedTriangles(vis).IndexBuffer;
            if (ib !is null) indexCount = ib.GetUint32(O_CPLUGINDEXBUFFER_COUNT);

            uint64 subPtr = Dev::GetOffsetUint64(vis, O_CPLUGVISUAL_SUBVISUALS_BUF);
            if (frameCount > 1 && indexCount == 0 && subPtr != 0) {
                indexCount = Dev::ReadUInt32(subPtr + 8);
            }

            uint vpf = 0;
            if (VertexTween_TryVertsPerFrame(vertexCount, frameCount, vpf) && indexCount > 0) {
                anyTween = true;
                bool aliased = subPtr == 0;
                for (uint s = 0; s < seenSubvis.Length; s++) {
                    if (seenSubvis[s] == subPtr) { aliased = true; break; }
                }
                // 0x11C is not a reliable cap after GBX load; only replace a missing/shared table.
                if (aliased) {
                    subPtr = RequestMemory(12 * frameCount);
                    Dev::SetOffset(vis, O_CPLUGVISUAL_SUBVISUALS_BUF, uint64(subPtr));
                    Dev::SetOffset(vis, O_CPLUGVISUAL_SUBVISUALS_BUF + 0x8, uint64(frameCount));
                }
                VertexTween_WriteFrames(subPtr, frameCount, vpf, indexCount);
                seenSubvis.InsertLast(subPtr);
                trace('VertexTween LOD vis ' + i + ': ' + frameCount + ' frames x ' + vpf + ' verts, idx ' + indexCount);

                if (vertexCount > 0) {
                    vec3 mn = verts.GetVertex(0).Pos;
                    vec3 mx = mn;
                    for (uint v = 1; v < vertexCount; v++) {
                        vec3 p = verts.GetVertex(v).Pos;
                        mn = MathX::Min(mn, p);
                        mx = MathX::Max(mx, p);
                    }
                    vec3 c, h;
                    VertexTween_AabbFromMinMax(mn, mx, c, h);
                    if (!MathX::IsNanInf(c) && !MathX::IsNanInf(h)) {
                        Dev::SetOffset(vis, O_CPLUGVISUAL_AABB_CENTER, c);
                        Dev::SetOffset(vis, O_CPLUGVISUAL_AABB_HALF, h);
                        vec3 nc, nh;
                        VertexTween_UnionAabb(solidC, solidH, c, h, nc, nh);
                        solidC = nc;
                        solidH = nh;
                    }
                }
            } else if (subPtr != 0) {
                seenSubvis.InsertLast(subPtr);
            }
        }

        if (anyTween && solidH.x >= 0) {
            Dev::SetOffset(mesh, O_SOLID2MODEL_AABB_CENTER, solidC);
            Dev::SetOffset(mesh, O_SOLID2MODEL_AABB_HALF, solidH);
        }
        RepairSolid2VertexTween(mesh);
    }
}
