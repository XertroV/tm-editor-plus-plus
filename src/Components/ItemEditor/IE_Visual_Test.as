#if DEV
namespace Tests {
    [Test]
    void VisualFlags_BitMasks(Tests::Context@ ctx) {
        ctx.AssertSame(VisualFlags::USE_VERTEX_NORMAL, uint32(0x80), "bit7");
        ctx.AssertSame(VisualFlags::USE_VERTEX_COLOR, uint32(0x100), "bit8");
        ctx.AssertSame(VisualFlags::SKIN_INDEX_MASK, uint32(0x7), "skin 0-2");
        ctx.AssertSame(VisualFlags::BIT3, uint32(0x8), "bit3");
        ctx.AssertSame(VisualFlags::BIT5, uint32(0x20), "bit5");
        ctx.AssertSame(VisualFlags::DIRTY_400, uint32(0x400), "dirty");
        uint32 f = 0;
        f = VisualFlags::SetBit(f, VisualFlags::USE_VERTEX_NORMAL, true);
        ctx.AssertTrue(VisualFlags::Bit(f, VisualFlags::USE_VERTEX_NORMAL), "set");
        f = VisualFlags::SetBit(f, VisualFlags::USE_VERTEX_NORMAL, false);
        ctx.AssertTrue(!VisualFlags::Bit(f, VisualFlags::USE_VERTEX_NORMAL), "clear");
    }

    [Test]
    void Visual_CPlugVisualMembers(Tests::Context@ ctx) {
        auto ty = Reflection::GetType("CPlugVisual");
        ctx.AssertTrue(ty !is null, "CPlugVisual type");
        ctx.AssertSame(uint(ty.Size), uint(0x130), "CPlugVisual size 304");
        ctx.AssertTrue(ty.GetMember("UseVertexNormal") !is null, "UseVertexNormal");
        ctx.AssertTrue(ty.GetMember("UseVertexColor") !is null, "UseVertexColor");
        ctx.AssertTrue(ty.GetMember("IsIndexationStatic") !is null, "IsIndexationStatic");
        auto s2 = Reflection::GetType("CPlugSolid2Model");
        ctx.AssertTrue(s2 !is null, "Solid2");
        ctx.AssertSame(uint(s2.Size), uint(0x390), "Solid2 size 912");
        auto v3 = Reflection::GetType("CPlugVisual3D");
        ctx.AssertTrue(v3 !is null && v3.GetMember("NegNormals") !is null, "NegNormals");
        ctx.AssertTrue(s2.GetMember("Visual 0") is null, "Visual 0 is not a Solid2 member");
    }

    [Test]
    void VisualNormals_EnsureCpuVertexesStealsGameHeap(Tests::Context@ ctx) {
        auto vis = CPlugVisualIndexedTriangles();
        ctx.AssertTrue(vis !is null, "vis");
        auto v3 = cast<CPlugVisual3D>(vis);
        ctx.AssertTrue(v3 !is null, "Visual3D");
        auto verts0 = DPlugVisual3D(v3).Vertexes;
        ctx.AssertTrue(verts0.Length == 0, "fresh empty");
        ctx.AssertTrue(VisualNormals::VertexDataPtr(verts0) == 0, "empty list does not read leftover data ptr");
        ctx.AssertTrue(VisualNormals::CountUsableNormals(vis) == 0, "empty usable");
        ctx.AssertTrue(VisualNormals::EnsureCpuVertexes(v3, 4), "ensure");
        auto verts = DPlugVisual3D(v3).Vertexes;
        ctx.AssertTrue(verts.Length == 4, "len 4");
        ctx.AssertTrue(verts.Capacity >= 4, "cap");
        ctx.AssertTrue(VisualNormals::VertexDataPtr(verts) != 0, "data ptr");
        verts.GetVertex(0).Normal = vec3(0, 1, 0);
        vec3 n = verts.GetVertex(0).Normal;
        ctx.AssertTrue(Math::Abs(n.y - 1.0) < 1e-5, "wrote Normal");
        ctx.AssertTrue(!VisualNormals::RecalcSmoothFromCpuVerts(vis), "no IndexBuffer");
        ctx.AssertTrue(VisualNormals::CountNonZeroCpuNormals(v3) == 1, "one nonzero normal");
        ctx.AssertTrue(VisualNormals::CountUsableNormals(vis) == 1, "usable 1");
        verts.GetVertex(0).Normal = vec3(0, 0, 0);
        ctx.AssertTrue(VisualNormals::CountUsableNormals(vis) == 0, "zeros unused");
    }

    [Test]
    void VisualNormals_BufferAllocStrideFits(Tests::Context@ ctx) {
        ctx.AssertSame(VisualNormals::VERTEX_STRIDE, uint(0x28), "stride 0x28");
        ctx.AssertTrue((3 * VisualNormals::VERTEX_STRIDE) % 4 == 0, "PointDists size % 4");
    }

    [Test]
    void VisualNormals_ResolveAttrDataSkipsUnalignedLeftover(Tests::Context@ ctx) {
        ctx.AssertTrue(VisualNormals::ResolveAttrData(0, 0, 0) == 0, "both empty");
        ctx.AssertTrue(VisualNormals::ResolveAttrData(1, 0, 0) == 0, "unaligned leftover is not used");
        ctx.AssertTrue(VisualNormals::ResolveAttrData(7, 0, 12) == 0, "ptr%8 leftover is not used");
    }

    [Test]
    void VisualNormals_Dec3NPackRoundtrip(Tests::Context@ ctx) {
        ctx.AssertSame(VisualNormals::TYPE_DEC3N, uint(14), "D3D Dec3N");
        ctx.AssertSame(VisualNormals::StreamElemSize(VisualNormals::TYPE_DEC3N), uint(4), "4 bytes");
        ctx.AssertSame(VisualNormals::StreamElemSize(VisualNormals::TYPE_FLOAT3), uint(12), "12 bytes");
        uint py = VisualNormals::PackDec3N(vec3(0, 1, 0));
        ctx.AssertSame(py, uint(0x1FF << 10), "+Y");
        vec3 u = VisualNormals::UnpackDec3N(py);
        ctx.AssertTrue(Math::Abs(u.x) < 0.01 && Math::Abs(u.y - 1.0) < 0.01 && Math::Abs(u.z) < 0.01, "unpack +Y");
        vec3 src = vec3(-1, 0, 0);
        vec3 back = VisualNormals::UnpackDec3N(VisualNormals::PackDec3N(src));
        ctx.AssertTrue(Math::Abs(back.x + 1.0) < 0.01 && Math::Abs(back.y) < 0.01 && Math::Abs(back.z) < 0.01, "unpack -X");
    }

    [Test]
    void VisualNormals_StreamCountUsesLogicalNotCapacity(Tests::Context@ ctx) {
        auto vs = CPlugVertexStream();
        ctx.AssertTrue(vs !is null, "stream");
        Dev::SetOffset(vs, VisualNormals::O_VS_VERTEXCOUNT, uint(3));
        Dev::SetOffset(vs, VisualNormals::O_VS_ALLOCATED_VERTEXCOUNT, uint(8));
        uint logical = 0;
        uint allocated = 0;
        ctx.AssertTrue(VisualNormals::TryReadStreamCounts(Dev_GetPointerForNod(vs), logical, allocated), "read counts");
        ctx.AssertSame(logical, uint(3), "logical count is +0x30");
        ctx.AssertSame(allocated, uint(8), "allocated count is +0x34");
        Dev::SetOffset(vs, VisualNormals::O_VS_ALLOCATED_VERTEXCOUNT, uint(0));
        ctx.AssertTrue(!VisualNormals::TryReadStreamCounts(Dev_GetPointerForNod(vs), logical, allocated), "zero capacity rejected for nonzero logical count");
        Dev::SetOffset(vs, VisualNormals::O_VS_ALLOCATED_VERTEXCOUNT, uint(2));
        ctx.AssertTrue(!VisualNormals::TryReadStreamCounts(Dev_GetPointerForNod(vs), logical, allocated), "logical count cannot exceed capacity");
    }

    [Test]
    void VisualNormals_FullySmoothsDuplicatePositions(Tests::Context@ ctx) {
        array<vec3> pos = {
            vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0),
            vec3(0, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1)
        };
        array<uint> indices = {0, 1, 2, 3, 4, 5};
        array<vec3> normals;
        string err;
        ctx.AssertTrue(VisualNormals::CalculateFullySmoothNormals(pos, indices, normals, err), err);
        vec3 want = vec3(0.70710678, 0, 0.70710678);
        ctx.AssertTrue((normals[0] - want).LengthSquared() < 1e-6, "first duplicate averages both faces");
        ctx.AssertTrue((normals[3] - want).LengthSquared() < 1e-6, "second duplicate gets identical normal");
        ctx.AssertTrue((normals[2] - want).LengthSquared() < 1e-6, "duplicated edge position is smooth too");
        ctx.AssertTrue((normals[4] - want).LengthSquared() < 1e-6, "duplicated edge partner matches");
    }

    [Test]
    void VisualNormals_RejectsInvalidTriangleIndex(Tests::Context@ ctx) {
        array<vec3> pos = {vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0)};
        array<uint> indices = {0, 1, 3};
        array<vec3> normals;
        string err;
        ctx.AssertTrue(!VisualNormals::CalculateFullySmoothNormals(pos, indices, normals, err), "invalid index rejected");
        ctx.AssertTrue(err.Contains("out of range"), "useful error");
    }

    [Test]
    void VisualNormals_NormalizesLargeFiniteAccumulator(Tests::Context@ ctx) {
        vec3 normalized;
        ctx.AssertTrue(VisualNormals::TryNormalizeNormalSum(vec3(1e30, 2e30, 0), normalized), "large finite accumulator");
        ctx.AssertTrue(!MathX::IsNanInf(normalized), "normalized result stays finite");
        ctx.AssertTrue(Math::Abs(normalized.Length() - 1.0) < 1e-5, "normalized result has unit length");
    }

    [Test]
    void VisualNormals_DetectsSharedVertexStream(Tests::Context@ ctx) {
        auto vis = CPlugVisualIndexedTriangles();
        auto vs = CPlugVertexStream();
        Dev::SetOffset(vis, VisualNormals::O_VIS_NSTREAMS, uint(1));
        Dev::SetOffset(vis, VisualNormals::O_VIS_VERTEXSTREAM, Dev_GetPointerForNod(vs));
        ctx.AssertTrue(!VisualNormals::IsSharedVertexStream(vis), "fresh stream is unshared");
        Dev::SetOffset(vs, VisualNormals::O_VS_SHARED_SOURCE, Dev_GetPointerForNod(vs));
        bool detected = VisualNormals::IsSharedVertexStream(vis);
        Dev::SetOffset(vs, VisualNormals::O_VS_SHARED_SOURCE, uint64(0));
        ctx.AssertTrue(detected, "shared source pointer is detected");
    }

    [Test]
    void VisualNormals_RejectsOversizedIndexCount(Tests::Context@ ctx) {
        ctx.AssertTrue(VisualNormals::IsTriangleIndexCountValid(3), "one triangle");
        ctx.AssertTrue(!VisualNormals::IsTriangleIndexCountValid(4), "must be triangles");
        ctx.AssertTrue(!VisualNormals::IsTriangleIndexCountValid(VisualNormals::MAX_COUNT_INDICES + 3), "bounded before allocation");
    }

    [Test]
    void VisualNormals_RejectsUnquantizableFinitePosition(Tests::Context@ ctx) {
        string key;
        ctx.AssertTrue(!VisualNormals::TryPositionGroupKey(vec3(1e20, 0, 0), key), "key conversion rejects overflow");
        array<vec3> pos = {vec3(1e20, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0)};
        array<uint> indices = {0, 1, 2};
        array<vec3> normals;
        string err;
        ctx.AssertTrue(!VisualNormals::CalculateFullySmoothNormals(pos, indices, normals, err), "out-of-range finite position rejected");
        ctx.AssertTrue(err.Contains("quantization range"), "useful range error");
    }

    [Test]
    void VisualNormals_Solid2CollectorDeduplicatesNodes(Tests::Context@ ctx) {
        auto solid = CPlugSolid2Model();
        dictionary seen;
        array<CPlugSolid2Model@> solids;
        auto state = ItemEditor::SmoothNormalsCollectState();
        ctx.AssertTrue(ItemEditor::CollectSolid2Models(solid, 0, seen, solids, state), state.err);
        ctx.AssertTrue(ItemEditor::CollectSolid2Models(solid, 0, seen, solids, state), state.err);
        ctx.AssertSame(solids.Length, uint(1), "same Solid2 is collected once");
        ctx.AssertSame(state.visited, uint(1), "same nod is visited once");
    }

    [Test]
    void VisualNormals_Solid2CollectorBoundsExaminedEdges(Tests::Context@ ctx) {
        auto state = ItemEditor::SmoothNormalsCollectState();
        state.edges = ItemEditor::SMOOTH_NORMALS_MAX_ENTITY_EDGES;
        ctx.AssertTrue(!state.TakeEdge(), "edge after the limit is rejected");
        ctx.AssertTrue(state.err.Contains("edge limit"), "useful edge-limit error");
    }

    [Test]
    void VisualNormals_GpuStreamMustNotFillCpuVertexes(Tests::Context@ ctx) {
        auto vis = CPlugVisualIndexedTriangles();
        ctx.AssertTrue(vis !is null, "vis");
        auto v3 = cast<CPlugVisual3D>(vis);
        ctx.AssertTrue(v3 !is null, "Visual3D");
        ctx.AssertTrue(!VisualNormals::HasGpuVertexStream(vis), "fresh has no stream");
        auto vs = CPlugVertexStream();
        ctx.AssertTrue(vs !is null, "vs");
        Dev::SetOffset(vis, VisualNormals::O_VIS_NSTREAMS, uint(1));
        Dev::SetOffset(vis, VisualNormals::O_VIS_VERTEXSTREAM, Dev_GetPointerForNod(vs));
        ctx.AssertTrue(VisualNormals::HasGpuVertexStream(vis), "attached stream");
        ctx.AssertTrue(!VisualNormals::RecalcSmoothFromCpuVerts(vis), "no pos/ib");
        ctx.AssertTrue(DPlugVisual3D(v3).Vertexes.Length == 0, "must not steal CPU Vertexes when a VertexStream exists (0902C004 intern crash)");
    }

    [Test]
    void VisualNormals_RejectsMixedCpuAndStreamVertexRepresentations(Tests::Context@ ctx) {
        auto vis = CPlugVisualIndexedTriangles();
        auto v3 = cast<CPlugVisual3D>(vis);
        ctx.AssertTrue(VisualNormals::EnsureCpuVertexes(v3, 3), "CPU fixture");
        auto vs = CPlugVertexStream();
        Dev::SetOffset(vis, VisualNormals::O_VIS_NSTREAMS, uint(1));
        Dev::SetOffset(vis, VisualNormals::O_VIS_VERTEXSTREAM, Dev_GetPointerForNod(vs));
        string err;
        ctx.AssertTrue(!VisualNormals::RecalcSmoothFromCpuVerts(vis, err), "mixed representation rejected");
        ctx.AssertTrue(err.Contains("both CPU Vertexes and a VertexStream"), "specific mixed-representation error");
        ctx.AssertSame(DPlugVisual3D(v3).Vertexes.Length, uint(3), "CPU Vertexes length remains unchanged");
    }

    void CheckVisualNormalsStreamCountUsesLogicalNotCapacity() {
        auto vs = CPlugVertexStream();
        assert(vs !is null, "stream");
        Dev::SetOffset(vs, VisualNormals::O_VS_VERTEXCOUNT, uint(3));
        Dev::SetOffset(vs, VisualNormals::O_VS_ALLOCATED_VERTEXCOUNT, uint(8));
        uint logical = 0;
        uint allocated = 0;
        assert(VisualNormals::TryReadStreamCounts(Dev_GetPointerForNod(vs), logical, allocated), "read counts");
        assert(logical == 3, "logical count is +0x30");
        assert(allocated == 8, "allocated count is +0x34");
        Dev::SetOffset(vs, VisualNormals::O_VS_ALLOCATED_VERTEXCOUNT, uint(0));
        assert(!VisualNormals::TryReadStreamCounts(Dev_GetPointerForNod(vs), logical, allocated), "zero capacity rejected for nonzero logical count");
        Dev::SetOffset(vs, VisualNormals::O_VS_ALLOCATED_VERTEXCOUNT, uint(2));
        assert(!VisualNormals::TryReadStreamCounts(Dev_GetPointerForNod(vs), logical, allocated), "logical count cannot exceed capacity");
    }

    void CheckVisualNormalsFullySmoothsDuplicatePositions() {
        array<vec3> pos = {
            vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0),
            vec3(0, 0, 0), vec3(0, 1, 0), vec3(0, 0, 1)
        };
        array<uint> indices = {0, 1, 2, 3, 4, 5};
        array<vec3> normals;
        string err;
        assert(VisualNormals::CalculateFullySmoothNormals(pos, indices, normals, err), err);
        vec3 want = vec3(0.70710678, 0, 0.70710678);
        assert((normals[0] - want).LengthSquared() < 1e-6, "first duplicate averages both faces");
        assert((normals[3] - want).LengthSquared() < 1e-6, "second duplicate gets identical normal");
        assert((normals[2] - want).LengthSquared() < 1e-6, "duplicated edge position is smooth too");
        assert((normals[4] - want).LengthSquared() < 1e-6, "duplicated edge partner matches");
    }

    void CheckVisualNormalsRejectsInvalidTriangleIndex() {
        array<vec3> pos = {vec3(0, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0)};
        array<uint> indices = {0, 1, 3};
        array<vec3> normals;
        string err;
        assert(!VisualNormals::CalculateFullySmoothNormals(pos, indices, normals, err), "invalid index rejected");
        assert(err.Contains("out of range"), "useful error");
    }

    void CheckVisualNormalsNormalizesLargeFiniteAccumulator() {
        vec3 normalized;
        assert(VisualNormals::TryNormalizeNormalSum(vec3(1e30, 2e30, 0), normalized), "large finite accumulator");
        assert(!MathX::IsNanInf(normalized), "normalized result stays finite");
        assert(Math::Abs(normalized.Length() - 1.0) < 1e-5, "normalized result has unit length");
    }

    void CheckVisualNormalsDetectsSharedVertexStream() {
        auto vis = CPlugVisualIndexedTriangles();
        auto vs = CPlugVertexStream();
        Dev::SetOffset(vis, VisualNormals::O_VIS_NSTREAMS, uint(1));
        Dev::SetOffset(vis, VisualNormals::O_VIS_VERTEXSTREAM, Dev_GetPointerForNod(vs));
        assert(!VisualNormals::IsSharedVertexStream(vis), "fresh stream is unshared");
        Dev::SetOffset(vs, VisualNormals::O_VS_SHARED_SOURCE, Dev_GetPointerForNod(vs));
        bool detected = VisualNormals::IsSharedVertexStream(vis);
        Dev::SetOffset(vs, VisualNormals::O_VS_SHARED_SOURCE, uint64(0));
        assert(detected, "shared source pointer is detected");
    }

    void CheckVisualNormalsRejectsOversizedIndexCount() {
        assert(VisualNormals::IsTriangleIndexCountValid(3), "one triangle");
        assert(!VisualNormals::IsTriangleIndexCountValid(4), "must be triangles");
        assert(!VisualNormals::IsTriangleIndexCountValid(VisualNormals::MAX_COUNT_INDICES + 3), "bounded before allocation");
    }

    void CheckVisualNormalsRejectsUnquantizableFinitePosition() {
        string key;
        assert(!VisualNormals::TryPositionGroupKey(vec3(1e20, 0, 0), key), "key conversion rejects overflow");
        array<vec3> pos = {vec3(1e20, 0, 0), vec3(1, 0, 0), vec3(0, 1, 0)};
        array<uint> indices = {0, 1, 2};
        array<vec3> normals;
        string err;
        assert(!VisualNormals::CalculateFullySmoothNormals(pos, indices, normals, err), "out-of-range finite position rejected");
        assert(err.Contains("quantization range"), "useful range error");
    }

    void CheckVisualNormalsSolid2CollectorDeduplicatesNodes() {
        auto solid = CPlugSolid2Model();
        dictionary seen;
        array<CPlugSolid2Model@> solids;
        auto state = ItemEditor::SmoothNormalsCollectState();
        assert(ItemEditor::CollectSolid2Models(solid, 0, seen, solids, state), state.err);
        assert(ItemEditor::CollectSolid2Models(solid, 0, seen, solids, state), state.err);
        assert(solids.Length == 1, "same Solid2 is collected once");
        assert(state.visited == 1, "same nod is visited once");
    }

    void CheckVisualNormalsRejectsMixedCpuAndStreamVertexRepresentations() {
        auto vis = CPlugVisualIndexedTriangles();
        auto v3 = cast<CPlugVisual3D>(vis);
        assert(VisualNormals::EnsureCpuVertexes(v3, 3), "CPU fixture");
        auto vs = CPlugVertexStream();
        Dev::SetOffset(vis, VisualNormals::O_VIS_NSTREAMS, uint(1));
        Dev::SetOffset(vis, VisualNormals::O_VIS_VERTEXSTREAM, Dev_GetPointerForNod(vs));
        string err;
        assert(!VisualNormals::RecalcSmoothFromCpuVerts(vis, err), "mixed representation rejected");
        assert(err.Contains("both CPU Vertexes and a VertexStream"), "specific mixed-representation error");
        assert(DPlugVisual3D(v3).Vertexes.Length == 3, "CPU Vertexes length remains unchanged");
    }

    void CheckVisualNormalsSolid2CollectorBoundsExaminedEdges() {
        auto state = ItemEditor::SmoothNormalsCollectState();
        state.edges = ItemEditor::SMOOTH_NORMALS_MAX_ENTITY_EDGES;
        assert(!state.TakeEdge(), "edge after the limit is rejected");
        assert(state.err.Contains("edge limit"), "useful edge-limit error");
    }
}

Tester@ Test_VisualNormals = Tester("VisualNormals", {
    TestCase("stream count uses logical not capacity", CoroutineFunc(Tests::CheckVisualNormalsStreamCountUsesLogicalNotCapacity)),
    TestCase("fully smooths duplicate positions", CoroutineFunc(Tests::CheckVisualNormalsFullySmoothsDuplicatePositions)),
    TestCase("rejects invalid triangle index", CoroutineFunc(Tests::CheckVisualNormalsRejectsInvalidTriangleIndex)),
    TestCase("normalizes large finite accumulator", CoroutineFunc(Tests::CheckVisualNormalsNormalizesLargeFiniteAccumulator)),
    TestCase("detects shared vertex stream", CoroutineFunc(Tests::CheckVisualNormalsDetectsSharedVertexStream)),
    TestCase("rejects oversized index count", CoroutineFunc(Tests::CheckVisualNormalsRejectsOversizedIndexCount)),
    TestCase("rejects unquantizable finite position", CoroutineFunc(Tests::CheckVisualNormalsRejectsUnquantizableFinitePosition)),
    TestCase("Solid2 collector deduplicates nodes", CoroutineFunc(Tests::CheckVisualNormalsSolid2CollectorDeduplicatesNodes)),
    TestCase("rejects mixed CPU and stream vertex representations", CoroutineFunc(Tests::CheckVisualNormalsRejectsMixedCpuAndStreamVertexRepresentations)),
    TestCase("Solid2 collector bounds examined edges", CoroutineFunc(Tests::CheckVisualNormalsSolid2CollectorBoundsExaminedEdges))
});
#endif
