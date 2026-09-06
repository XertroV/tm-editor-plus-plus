#if DEV
namespace Tests {
    [Test]
    void VertexTween_OfficialFlagStrides(Tests::Context@ ctx) {
        uint vpf;
        ctx.AssertTrue(MeshDuplication::VertexTween_TryVertsPerFrame(12384, 86, vpf), "LOD0 divides");
        ctx.AssertSame(vpf, uint(144), "LOD0 verts/frame");
        ctx.AssertTrue(MeshDuplication::VertexTween_TryVertsPerFrame(4214, 86, vpf), "LOD1 divides");
        ctx.AssertSame(vpf, uint(49), "LOD1 verts/frame");
        ctx.AssertTrue(MeshDuplication::VertexTween_TryVertsPerFrame(1376, 86, vpf), "LOD2 divides");
        ctx.AssertSame(vpf, uint(16), "LOD2 verts/frame");
        ctx.AssertTrue(MeshDuplication::VertexTween_TryVertsPerFrame(774, 86, vpf), "LOD3 divides");
        ctx.AssertSame(vpf, uint(9), "LOD3 verts/frame");
        ctx.AssertFalse(MeshDuplication::VertexTween_TryVertsPerFrame(100, 86, vpf), "non-multiple rejected");
        ctx.AssertFalse(MeshDuplication::VertexTween_TryVertsPerFrame(144, 1, vpf), "single frame is not tween");
    }

    [Test]
    void VertexTween_AabbAndUnion(Tests::Context@ ctx) {
        vec3 c, h;
        MeshDuplication::VertexTween_AabbFromMinMax(vec3(0, 0, 0), vec3(2, 4, 6), c, h);
        ctx.AssertTrue((c - vec3(1, 2, 3)).LengthSquared() < 1e-8, "center");
        ctx.AssertTrue((h - vec3(1, 2, 3)).LengthSquared() < 1e-8, "half");

        vec3 uc = vec3(0), uh = vec3(-1, -1, -1);
        vec3 n0c, n0h;
        MeshDuplication::VertexTween_UnionAabb(uc, uh, c, h, n0c, n0h);
        ctx.AssertTrue((n0c - c).LengthSquared() < 1e-8, "union into empty");
        vec3 n1c, n1h;
        MeshDuplication::VertexTween_UnionAabb(n0c, n0h, vec3(10, 2, 3), vec3(1, 1, 1), n1c, n1h);
        ctx.AssertTrue(n1c.x > 1 && n1h.x > 1, "union expands");
        vec3 n2c, n2h;
        MeshDuplication::VertexTween_UnionAabb(n1c, n1h, vec3(0), vec3(-1, 0, 0), n2c, n2h);
        ctx.AssertTrue((n2c - n1c).LengthSquared() < 1e-8, "empty src skipped");
    }
}
#endif
