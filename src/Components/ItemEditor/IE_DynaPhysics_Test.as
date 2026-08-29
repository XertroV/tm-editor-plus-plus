#if SIG_DEVELOPER

// Independent literals from research/2026-08-24-DynaObjectConstructors.md
// and research/2026-08-24-ItemAndGhostCollisions.md — not copied from the impl.

namespace Tests {
    [Test]
    void DynaPhysics_MovableItemTypeEIs0C(Tests::Context@ ctx) {
        ctx.AssertSame(int(DynaPhysics::ItemTypeEMovable), 12, "GenerateDestructibleSlots slots ItemTypeE 0x0C");
    }

    [Test]
    void DynaPhysics_CtorDefaultsFailRecipe(Tests::Context@ ctx) {
        ctx.AssertFalse(DynaPhysics::CtorDynamizeOnSpawn, "CPlugDynaObjectModel ctor DynamizeOnSpawn is 0");
        ctx.AssertFalse(DynaPhysics::CtorIsStatic, "ctor IsStatic is 0");
        ctx.AssertSame(int(DynaPhysics::CtorBreakSpeedKmh), 100, "ctor BreakSpeedKmh is 100");
        ctx.AssertTrue(DynaPhysics::CtorBreakSpeedKmh < DynaPhysics::DefaultBreakSpeedKmh,
            "default BreakSpeedKmh is raised above the ctor destroy-on-hit value");
    }

    [Test]
    void DynaPhysics_RecipeRejectsKinematicAndWrongType(Tests::Context@ ctx) {
        auto st = DynaPhysics::Status();
        st.itemTypeE = 1;
        st.hasShape = true;
        st.hasGmSurf = true;
        st.isStatic = false;
        st.dynamizeOnSpawn = true;
        st.hasKinematicConstraint = false;
        st.isKinematic = false;
        st.physicNotCollidable = false;
        st.entityIsPrefab = true;
        auto fails = DynaPhysics::RecipeFailures(st);
        ctx.AssertTrue(DynaPhysics::FailuresContain(fails, "ItemTypeE"), "type 1 is kinematic-obstacle path");

        st.itemTypeE = DynaPhysics::ItemTypeEMovable;
        st.isKinematic = true;
        @fails = DynaPhysics::RecipeFailures(st);
        ctx.AssertTrue(DynaPhysics::FailuresContain(fails, "IsKinematic"), "soccer ball must not be kinematic");

        st.isKinematic = false;
        st.hasKinematicConstraint = true;
        @fails = DynaPhysics::RecipeFailures(st);
        ctx.AssertTrue(DynaPhysics::FailuresContain(fails, "KinematicConstraint"), "omit constraint ent");
    }

    [Test]
    void DynaPhysics_RecipeRejectsPrefabPlus0C(Tests::Context@ ctx) {
        auto st = DynaPhysics::Status();
        st.itemTypeE = 0x0C;
        st.hasShape = true;
        st.hasGmSurf = true;
        st.isStatic = false;
        st.dynamizeOnSpawn = true;
        st.hasKinematicConstraint = false;
        st.isKinematic = false;
        st.physicNotCollidable = false;
        st.entityIsPrefab = true;
        st.entityIsDyna = false;
        auto fails = DynaPhysics::RecipeFailures(st);
        ctx.AssertTrue(DynaPhysics::FailuresContain(fails, "Prefab"),
            "0x0C+Prefab: GetEntityVisRoot returns 0, GenerateDestructibleSlots AVs");
    }

    [Test]
    void DynaPhysics_RecipeAcceptsBareDynaSoccerBall(Tests::Context@ ctx) {
        auto st = DynaPhysics::Status();
        st.itemTypeE = 0x0C;
        st.hasShape = true;
        st.hasGmSurf = true;
        st.isStatic = false;
        st.dynamizeOnSpawn = true;
        st.hasKinematicConstraint = false;
        st.isKinematic = false;
        st.physicNotCollidable = false;
        st.entityIsPrefab = false;
        st.entityIsDyna = true;
        auto fails = DynaPhysics::RecipeFailures(st);
        ctx.AssertSame(int(fails.Length), 0, "bare DynaObject + 0x0C is the movable slot");
    }

    [Test]
    void DynaPhysics_NotCollidableBlocksMotion(Tests::Context@ ctx) {
        ctx.AssertTrue(DynaPhysics::PhysicIdBlocksMotion(EPlugSurfaceMaterialId::NotCollidable),
            "NotCollidable is not a move hull");
        ctx.AssertFalse(DynaPhysics::PhysicIdBlocksMotion(EPlugSurfaceMaterialId::Rubber),
            "Rubber is an allowed contact id");
    }
}

#if DEV
Tester@ Test_DynaPhysics = Tester("DynaPhysics", generateDynaPhysicsTests());

TestCase@[]@ generateDynaPhysicsTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("movable ItemTypeE is 0x0C", dyna_phys_test_item_type));
    ret.InsertLast(TestCase("ctor DynamizeOnSpawn 0 fails recipe", dyna_phys_test_ctor_defaults));
    ret.InsertLast(TestCase("kinematic / type 1 / KC rejected", dyna_phys_test_rejects));
    ret.InsertLast(TestCase("0x0C+Prefab rejected", dyna_phys_test_rejects_prefab_0c));
    ret.InsertLast(TestCase("bare DynaObject soccer-ball status passes", dyna_phys_test_accepts));
    ret.InsertLast(TestCase("NotCollidable blocks, Rubber does not", dyna_phys_test_physic));
    return ret;
}

void dyna_phys_test_item_type() {
    assert_eq(int(DynaPhysics::ItemTypeEMovable), 12, "0x0C");
}

void dyna_phys_test_ctor_defaults() {
    assert(!DynaPhysics::CtorDynamizeOnSpawn, "ctor DynamizeOnSpawn");
    assert_eq(int(DynaPhysics::CtorBreakSpeedKmh), 100, "ctor break");
    assert(DynaPhysics::DefaultBreakSpeedKmh > DynaPhysics::CtorBreakSpeedKmh, "raised break");
}

void dyna_phys_test_rejects() {
    auto st = DynaPhysics::Status();
    st.itemTypeE = 4;
    st.hasShape = true;
    st.hasGmSurf = true;
    st.dynamizeOnSpawn = true;
    auto fails = DynaPhysics::RecipeFailures(st);
    assert(DynaPhysics::FailuresContain(fails, "ItemTypeE"), "ctor ItemTypeE 4 is not movable");
}

void dyna_phys_test_rejects_prefab_0c() {
    auto st = DynaPhysics::Status();
    st.itemTypeE = 0x0C;
    st.hasShape = true;
    st.hasGmSurf = true;
    st.dynamizeOnSpawn = true;
    st.entityIsPrefab = true;
    assert(DynaPhysics::FailuresContain(DynaPhysics::RecipeFailures(st), "Prefab"), "0x0C+Prefab");
}

void dyna_phys_test_accepts() {
    auto st = DynaPhysics::Status();
    st.itemTypeE = 0x0C;
    st.hasShape = true;
    st.hasGmSurf = true;
    st.isStatic = false;
    st.dynamizeOnSpawn = true;
    st.entityIsDyna = true;
    assert_eq(int(DynaPhysics::RecipeFailures(st).Length), 0, "clean recipe");
}

void dyna_phys_test_physic() {
    assert(DynaPhysics::PhysicIdBlocksMotion(EPlugSurfaceMaterialId::NotCollidable), "NotCollidable");
    assert(!DynaPhysics::PhysicIdBlocksMotion(EPlugSurfaceMaterialId::Rubber), "Rubber");
}
#endif

#endif
