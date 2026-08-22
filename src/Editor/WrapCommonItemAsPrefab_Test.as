#if DEV
namespace Editor {
    Tester@ Test_WrapCommonItemAsPrefab = Tester("WrapCommonItemAsPrefab", generateWrapCommonItemAsPrefabTests());

    TestCase@[]@ generateWrapCommonItemAsPrefabTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("wrap null ItemModel throws", wrap_null_throws));
        ret.InsertLast(TestCase("wrap already-prefab throws", wrap_already_prefab_throws));
        ret.InsertLast(TestCase("wrap non-CommonItem throws", wrap_wrong_entity_throws));
        ret.InsertLast(TestCase("wrap CommonItem without StaticObject throws", wrap_no_static_throws));
        ret.InsertLast(TestCase("wrap CommonItem becomes 1-ent prefab", wrap_common_becomes_prefab));
        ret.InsertLast(TestCase("WriteEntRef identity has no ModelFid", write_ent_ref_identity_no_fid));
        return ret;
    }

    void write_ent_ref_identity_no_fid() {
        auto prefab = CPlugPrefab();
        prefab.MwAddRef();
        auto so = CPlugStaticObjectModel();
        so.MwAddRef();
        auto allocd = BufferAlloc::Alloc(1, SZ_ENT_REF);
        allocd.WriteToNod(prefab, O_PREFAB_ENTS, 1);
        MeshDuplication::WriteEntRef(prefab, 0, so, quat(1, 0, 0, 0), vec3(0), 0);
        assert(prefab.Ents[0].Model is so, "WriteEntRef sets Model");
        assert(prefab.Ents[0].ModelFid is null, "WriteEntRef leaves ModelFid null");
        assert(prefab.Ents[0].Location.Trans.LengthSquared() == 0, "WriteEntRef identity trans");
        auto ents = Dev::GetOffsetNod(prefab, O_PREFAB_ENTS);
        assert(Dev::GetOffsetUint64(ents, O_ENTREF_PARAMS) == 0
            && Dev::GetOffsetUint64(ents, O_ENTREF_PARAMS + 8) == 0, "WriteEntRef zeros Params");
    }

    bool wrapThrew(CGameItemModel@ model) {
        try {
            WrapCommonItemEntityAsPrefab(model);
            return false;
        } catch {
            return true;
        }
    }

    CGameItemModel@ MakeBareItemModel(CMwNod@ entityModel) {
        auto model = CGameItemModel();
        model.MwAddRef();
        if (entityModel !is null) {
            entityModel.MwAddRef();
            Dev::SetOffset(model, O_ITEM_MODEL_EntityModel, entityModel);
        }
        return model;
    }

    CGameItemModel@ MakeCommonItemModel(bool withStatic) {
        auto common = CGameCommonItemEntityModel();
        auto model = MakeBareItemModel(common);
        if (withStatic) {
            auto so = CPlugStaticObjectModel();
            so.MwAddRef();
            Dev::SetOffset(common, GetOffset(common, "StaticObject"), so);
        }
        return model;
    }

    void wrap_null_throws() {
        assert(wrapThrew(null), "null ItemModel must throw");
    }

    void wrap_already_prefab_throws() {
        auto model = MakeBareItemModel(CPlugPrefab());
        assert(wrapThrew(model), "already-prefab EntityModel must throw");
    }

    void wrap_wrong_entity_throws() {
        auto model = MakeBareItemModel(CPlugStaticObjectModel());
        assert(wrapThrew(model), "non-CommonItem EntityModel must throw");
    }

    void wrap_no_static_throws() {
        auto model = MakeCommonItemModel(false);
        assert(wrapThrew(model), "CommonItem with no StaticObject must throw");
    }

    void wrap_common_becomes_prefab() {
        auto model = MakeCommonItemModel(true);
        auto so = cast<CPlugStaticObjectModel>(cast<CGameCommonItemEntityModel>(model.EntityModel).StaticObject);
        auto prefab = WrapCommonItemEntityAsPrefab(model);
        assert(prefab !is null, "wrap returns the prefab");
        assert(cast<CPlugPrefab>(model.EntityModel) !is null, "EntityModel is CPlugPrefab");
        assert(prefab is model.EntityModel, "returned prefab is ItemModel.EntityModel");
        assert(prefab.Ents.Length == 1, "official-style prefab has one ent");
        assert(prefab.Ents[0].Model is so, "Ents[0].Model is the prior StaticObject");
        assert(prefab.Ents[0].ModelFid is null, "Ents[0] has no ModelFid");
        assert(prefab.Ents[0].Location.Trans.LengthSquared() == 0, "identity translation");
        quat id = quat(1, 0, 0, 0);
        assert(prefab.Ents[0].Location.Quat.x == id.x
            && prefab.Ents[0].Location.Quat.y == id.y
            && prefab.Ents[0].Location.Quat.z == id.z
            && prefab.Ents[0].Location.Quat.w == id.w, "identity rotation");
        auto ents = Dev::GetOffsetNod(prefab, O_PREFAB_ENTS);
        uint16 paramsOff = GetOffset("NPlugPrefab_SEntRef", "Params");
        assert(Dev::GetOffsetUint64(ents, paramsOff) == 0
            && Dev::GetOffsetUint64(ents, paramsOff + 8) == 0, "Ents[0].Params is zero");
        assert(wrapThrew(model), "second wrap must refuse an already-prefab model");
    }
}

namespace Tests {
    [Test]
    void WrapCommonItem_NullThrows(Tests::Context@ ctx) {
        ctx.AssertTrue(Editor::wrapThrew(null), "null ItemModel throws");
    }

    [Test]
    void WrapCommonItem_AlreadyPrefabThrows(Tests::Context@ ctx) {
        ctx.AssertTrue(Editor::wrapThrew(Editor::MakeBareItemModel(CPlugPrefab())), "already-prefab throws");
    }

    [Test]
    void WrapCommonItem_WrongEntityThrows(Tests::Context@ ctx) {
        ctx.AssertTrue(Editor::wrapThrew(Editor::MakeBareItemModel(CPlugStaticObjectModel())), "non-CommonItem throws");
    }

    [Test]
    void WrapCommonItem_NoStaticThrows(Tests::Context@ ctx) {
        ctx.AssertTrue(Editor::wrapThrew(Editor::MakeCommonItemModel(false)), "missing StaticObject throws");
    }

    [Test]
    void WrapCommonItem_BecomesOneEntPrefab(Tests::Context@ ctx) {
        auto model = Editor::MakeCommonItemModel(true);
        auto so = cast<CPlugStaticObjectModel>(cast<CGameCommonItemEntityModel>(model.EntityModel).StaticObject);
        auto prefab = Editor::WrapCommonItemEntityAsPrefab(model);
        ctx.AssertFalse(prefab is null, "returns prefab");
        ctx.AssertFalse(cast<CPlugPrefab>(model.EntityModel) is null, "EntityModel is CPlugPrefab");
        ctx.AssertTrue(prefab is model.EntityModel, "same nod");
        ctx.AssertTrue(prefab.Ents.Length == 1, "one ent");
        ctx.AssertTrue(prefab.Ents[0].Model is so, "ent model is prior StaticObject");
        ctx.AssertTrue(prefab.Ents[0].ModelFid is null, "no ModelFid");
        ctx.AssertTrue(prefab.Ents[0].Location.Trans.LengthSquared() == 0, "identity trans");
        quat id = quat(1, 0, 0, 0);
        ctx.AssertTrue(prefab.Ents[0].Location.Quat.x == id.x
            && prefab.Ents[0].Location.Quat.y == id.y
            && prefab.Ents[0].Location.Quat.z == id.z
            && prefab.Ents[0].Location.Quat.w == id.w, "identity quat");
        ctx.AssertTrue(Editor::wrapThrew(model), "second wrap throws");
    }
}
#endif
