#if DEV
namespace Tests {
    [Test]
    void Solid2Model_WrapFreshHasEmptyMats(Tests::Context@ ctx) {
        auto nod = CPlugSolid2Model();
        ctx.AssertTrue(nod !is null, "nod");
        ItemEditor::ISolid2Model@ mesh = ItemEditor::WrapSolid2Model(nod);
        ctx.AssertTrue(mesh !is null, "wrap");
        ctx.AssertTrue(mesh.S2m is nod, "same nod");
        ctx.AssertSame(mesh.UserMaterials.Length, uint(0), "no user mats");
        ctx.AssertSame(mesh.CustomMaterials.Length, uint(0), "no custom mats");
        uint rc0 = Dev::GetOffsetUint32(nod, 0x10);
        {
            ItemEditor::ISolid2Model@ held = ItemEditor::WrapSolid2Model(nod);
            ctx.AssertTrue(Dev::GetOffsetUint32(nod, 0x10) > rc0, "AddRef");
        }
        mesh.SetAllUserMatPhysics(EPlugSurfaceMaterialId::NotCollidable);
        mesh.SetAllCustomMatPhysics(EPlugSurfaceMaterialId::NotCollidable);
    }
}
#endif
