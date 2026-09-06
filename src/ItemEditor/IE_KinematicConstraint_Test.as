#if DEV
namespace Tests {
    [Test]
    void KinematicConstraint_CloneCopiesPacked(Tests::Context@ ctx) {
        auto src = NPlugDyna_SKinematicConstraint();
        ctx.AssertTrue(src !is null, "src constructed");
        src.TransMin = 1.25;
        src.TransMax = 9.5;
        src.TransAxis = NPlugDyna::EAxis::y;
        src.AngleMinDeg = -10.;
        src.AngleMaxDeg = 20.;
        src.RotAxis = NPlugDyna::EAxis::z;
        src.ShaderTcType = NPlugDyna::EShaderTcType::TransSubTexture;
        if (ItemEditor::SAnimFunc_GetLength(src, ItemEditor::DynaKC_SubFuncType::Trans) < 1) {
            ItemEditor::SAnimFunc_IncrementEasingCountSetDefaults(src, ItemEditor::DynaKC_SubFuncType::Trans);
        }
        ItemEditor::SAnimFunc_SetIx(src, ItemEditor::DynaKC_SubFuncType::Trans, 0, ItemEditor::SubFuncEasings::Linear, true, 1234);

        auto dst = ItemEditor::CloneKinematicConstraint(src);
        ctx.AssertTrue(dst !is null, "dst");
        ctx.AssertTrue(dst !is src, "new nod");
        ctx.AssertTrue(Math::Abs(dst.TransMin - 1.25) < 1e-5, "TransMin");
        ctx.AssertTrue(Math::Abs(dst.TransMax - 9.5) < 1e-5, "TransMax");
        ctx.AssertTrue(dst.TransAxis == NPlugDyna::EAxis::y, "TransAxis");
        ctx.AssertTrue(Math::Abs(dst.AngleMinDeg + 10.) < 1e-5, "AngleMin");
        ctx.AssertTrue(Math::Abs(dst.AngleMaxDeg - 20.) < 1e-5, "AngleMax");
        ctx.AssertTrue(dst.RotAxis == NPlugDyna::EAxis::z, "RotAxis");
        ctx.AssertTrue(dst.ShaderTcType == NPlugDyna::EShaderTcType::TransSubTexture, "ShaderTcType");
        auto sf = ItemEditor::SAnimFunc_GetIx(dst, ItemEditor::DynaKC_SubFuncType::Trans, 0);
        ctx.AssertTrue(sf.type == ItemEditor::SubFuncEasings::Linear, "easing");
        ctx.AssertTrue(sf.reverse, "rev");
        ctx.AssertSame(sf.duration, uint(1234), "dur");
        ctx.AssertTrue(Math::Abs(src.TransMin - 1.25) < 1e-5, "src unchanged");
    }

    [Test]
    void KinematicConstraint_FluentViaInterface(Tests::Context@ ctx) {
        auto nod = NPlugDyna_SKinematicConstraint();
        ItemEditor::IKinematicConstraint@ kc = ItemEditor::WrapKinematicConstraint(nod)
            .Trans(NPlugDyna::EAxis::y).PosMM(1.5, 7.5)
            .Rot(NPlugDyna::EAxis::z).AnglesMM(-20., 40.)
            .SimpleOscilate(false, 2000)
            .AnimDoNothing(true);
        ctx.AssertTrue(kc.TransAxis == NPlugDyna::EAxis::y, "TransAxis");
        ctx.AssertTrue(kc.RotAxis == NPlugDyna::EAxis::z, "RotAxis");
        ctx.AssertTrue(Math::Abs(kc.TransMin - 1.5) < 1e-5, "TransMin");
        ctx.AssertTrue(Math::Abs(kc.TransMax - 7.5) < 1e-5, "TransMax");
        ctx.AssertTrue(Math::Abs(kc.AngleMinDeg + 20.) < 1e-5, "AngleMin");
        ctx.AssertTrue(Math::Abs(kc.AngleMaxDeg - 40.) < 1e-5, "AngleMax");
        ctx.AssertTrue(kc.Kc is nod, "same nod");
        auto sf = kc.GetSubFunc(ItemEditor::DynaKC_SubFuncType::Trans, 0);
        ctx.AssertTrue(sf.type == ItemEditor::SubFuncEasings::QuadInOut, "osc easing");
        ctx.AssertSame(sf.duration, uint(1000), "osc half-period");
        auto cloned = kc.Clone();
        ctx.AssertTrue(cloned.Kc !is nod, "clone new nod");
        ctx.AssertTrue(Math::Abs(cloned.TransMax - 7.5) < 1e-5, "clone TransMax");
        ctx.AssertTrue(cloned.GetSubFunc(ItemEditor::DynaKC_SubFuncType::Trans, 0).type == ItemEditor::SubFuncEasings::QuadInOut, "clone anim");
    }

    [Test]
    void KinematicConstraint_CopyViaInterface(Tests::Context@ ctx) {
        auto srcNod = NPlugDyna_SKinematicConstraint();
        srcNod.TransMin = 3.5;
        srcNod.TransMax = 8.25;
        auto dstNod = NPlugDyna_SKinematicConstraint();
        ItemEditor::IKinematicConstraint@ src = ItemEditor::WrapKinematicConstraint(srcNod);
        ItemEditor::IKinematicConstraint@ dst = ItemEditor::WrapKinematicConstraint(dstNod);
        dst.Copy(src);
        ctx.AssertTrue(Math::Abs(dst.Kc.TransMin - 3.5) < 1e-5, "Copy TransMin");
        ctx.AssertTrue(Math::Abs(dst.Kc.TransMax - 8.25) < 1e-5, "Copy TransMax");
        ctx.AssertTrue(Math::Abs(srcNod.TransMin - 3.5) < 1e-5, "src unchanged");
    }

    [Test]
    void KinematicConstraint_WrapDoesNotResetAnim(Tests::Context@ ctx) {
        auto nod = NPlugDyna_SKinematicConstraint();
        ctx.AssertTrue(nod !is null, "nod");
        nod.TransMin = 2.25;
        if (ItemEditor::SAnimFunc_GetLength(nod, ItemEditor::DynaKC_SubFuncType::Trans) < 1) {
            ItemEditor::SAnimFunc_IncrementEasingCountSetDefaults(nod, ItemEditor::DynaKC_SubFuncType::Trans);
        }
        ItemEditor::SAnimFunc_SetIx(nod, ItemEditor::DynaKC_SubFuncType::Trans, 0, ItemEditor::SubFuncEasings::Linear, true, 1234);
        uint8 nTrans = ItemEditor::SAnimFunc_GetLength(nod, ItemEditor::DynaKC_SubFuncType::Trans);
        uint8 nRot = ItemEditor::SAnimFunc_GetLength(nod, ItemEditor::DynaKC_SubFuncType::Rot);

        ItemEditor::IKinematicConstraint@ kc = ItemEditor::WrapKinematicConstraint(nod);
        ctx.AssertTrue(kc.Kc is nod, "same nod");
        ctx.AssertTrue(Math::Abs(kc.TransMin - 2.25) < 1e-5, "TransMin");
        ctx.AssertSame(uint(kc.SubFuncCount(ItemEditor::DynaKC_SubFuncType::Trans)), uint(nTrans), "trans count");
        ctx.AssertSame(uint(kc.SubFuncCount(ItemEditor::DynaKC_SubFuncType::Rot)), uint(nRot), "rot count");
        auto sf = kc.GetSubFunc(ItemEditor::DynaKC_SubFuncType::Trans, 0);
        ctx.AssertTrue(sf.type == ItemEditor::SubFuncEasings::Linear, "easing kept");
        ctx.AssertTrue(sf.reverse, "rev kept");
        ctx.AssertSame(sf.duration, uint(1234), "dur kept");
    }

    [Test]
    void DynaObject_CloneCopiesScalarsAndSharesMesh(Tests::Context@ ctx) {
        auto src = CPlugDynaObjectModel();
        ctx.AssertTrue(src !is null, "src constructed");
        src.IsStatic = true;
        src.DynamizeOnSpawn = true;
        src.Mass = 42.5;
        src.BreakSpeedKmh = 17.;
        auto dst = MeshDuplication::CloneDynaObjectModel(src);
        ctx.AssertTrue(dst !is null, "dst");
        ctx.AssertTrue(dst !is src, "new nod");
        ctx.AssertTrue(dst.IsStatic, "IsStatic");
        ctx.AssertTrue(dst.DynamizeOnSpawn, "DynamizeOnSpawn");
        ctx.AssertTrue(Math::Abs(dst.Mass - 42.5) < 1e-5, "Mass");
        ctx.AssertTrue(Math::Abs(dst.BreakSpeedKmh - 17.) < 1e-5, "BreakSpeed");
        ctx.AssertTrue(dst.Mesh is src.Mesh, "Mesh shared");
        ctx.AssertTrue(dst.StaticShape is src.StaticShape, "StaticShape shared");
        ctx.AssertTrue(dst.DynaShape is src.DynaShape, "DynaShape shared");
        ctx.AssertTrue(src.IsStatic, "src unchanged");
    }
}
#endif
