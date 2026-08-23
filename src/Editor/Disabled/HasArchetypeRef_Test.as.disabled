#if DEV
namespace Editor {
    Tester@ Test_HasArchetypeRef = Tester("HasArchetypeRef", generateHasArchetypeRefTests());

    TestCase@[]@ generateHasArchetypeRefTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("HasArchetypeRef pattern found", hasArchetypeRef_pattern_found));
        ret.InsertLast(TestCase("HasArchetypeRef patch off by default", hasArchetypeRef_patch_off_by_default));
        ret.InsertLast(TestCase("O_ITEM_MODEL_SKIN is DefaultSkinFileRef-0x18", item_model_skin_offset_matches_recipe));
        ret.InsertLast(TestCase("Solid2 materials buffers are 0xC8 / 0x1F8 / 0x208", solid2_material_buffer_offsets));
        ret.InsertLast(TestCase("KeepMaterials ZeroFids refuses outside item editor", keep_materials_zero_requires_item_editor));
        ret.InsertLast(TestCase("O_ITEM_MODEL_Id is collector MwId 0x28", collector_mwid_offset));
        return ret;
    }

    void hasArchetypeRef_pattern_found() {
        auto p = Dev::FindPattern(HasArchetypeRef::Pattern);
        assert(p != 0, "HasArchetypeRef pattern not found — game update moved CGameItemModel_HasArchetypeRef");
    }

    void hasArchetypeRef_patch_off_by_default() {
        assert(!HasArchetypeRef::IsActive, "no-patch URL-skin recipe requires HasArchetypeRef MemPatcher inactive");
    }

    void item_model_skin_offset_matches_recipe() {
        uint16 defRef = GetOffset("CGameItemModel", "DefaultSkinFileRef");
        assert(O_ITEM_MODEL_SKIN == defRef - 0x18, "O_ITEM_MODEL_SKIN must be DefaultSkinFileRef-0x18 (collector GameSkin +0xA0)");
    }

    void solid2_material_buffer_offsets() {
        assert(O_SOLID2MODEL_MATERIALS_BUF == 0xC8, "TVScreen vis walks materials at 0xC8");
        assert(O_SOLID2MODEL_CUSTMAT_BUF == 0x1F8, "ZeroFids custom items keep CPlugMaterial at 0x1F8");
        assert(O_SOLID2MODEL_CUSTMAT_BUF_COPY == 0x208, "Solid2 custom-mat copy buffer is 0x208");
    }

    void collector_mwid_offset() {
        assert(O_ITEM_MODEL_Id == 0x28, "catalog FindArticle uses collector MwId at +0x28");
        assert(GetMwId("ScreenDemo1x1") != GetMwId("Screen1x1"), "custom collector id must differ from catalog Screen1x1");
    }

    void keep_materials_zero_requires_item_editor() {
        assert(!MeshDuplication::g_KeepMaterials, "g_KeepMaterials stays off unless KeepMaterials zero is running");
        if (cast<CGameEditorItem>(GetApp().Editor) !is null) return;
        bool threw = false;
        try { ZeroCurrentItemModelFidsKeepMaterials(); } catch { threw = true; }
        assert(threw, "ZeroCurrentItemModelFidsKeepMaterials must refuse outside the item editor");
    }
}

namespace Tests {
    [Test]
    void HasArchetypeRef_PatternFound(Tests::Context@ ctx) {
        auto p = Dev::FindPattern(Editor::HasArchetypeRef::Pattern);
        ctx.AssertFalse(p == 0, "HasArchetypeRef pattern found in live exe");
    }

    [Test]
    void HasArchetypeRef_PatchOffByDefault(Tests::Context@ ctx) {
        ctx.AssertFalse(Editor::GetHasArchetypeRefPatch(), "HasArchetypeRef patch inactive (no-patch recipe)");
    }

    [Test]
    void ItemModelSkinOffset_IsDefaultSkinFileRefMinus18(Tests::Context@ ctx) {
        uint16 defRef = GetOffset("CGameItemModel", "DefaultSkinFileRef");
        ctx.AssertTrue(O_ITEM_MODEL_SKIN == defRef - 0x18, "O_ITEM_MODEL_SKIN == DefaultSkinFileRef-0x18");
    }

    [Test]
    void Solid2MaterialBuffers_MatchRecipeOffsets(Tests::Context@ ctx) {
        ctx.AssertTrue(O_SOLID2MODEL_MATERIALS_BUF == 0xC8, "materials 0xC8");
        ctx.AssertTrue(O_SOLID2MODEL_CUSTMAT_BUF == 0x1F8, "customMaterials 0x1F8");
        ctx.AssertTrue(O_SOLID2MODEL_CUSTMAT_BUF_COPY == 0x208, "customMaterials copy 0x208");
    }

    [Test]
    void ItemModelId_IsCollectorMwId28(Tests::Context@ ctx) {
        ctx.AssertTrue(O_ITEM_MODEL_Id == 0x28, "O_ITEM_MODEL_Id == 0x28");
        ctx.AssertFalse(GetMwId("ScreenDemo1x1") == GetMwId("Screen1x1"), "custom MwId must differ from catalog Screen1x1");
    }

    [Test]
    void KeepMaterialsZero_RefusesOutsideItemEditor(Tests::Context@ ctx) {
        ctx.AssertFalse(MeshDuplication::g_KeepMaterials, "keep-materials flag off by default");
        if (cast<CGameEditorItem>(GetApp().Editor) !is null) return;
        bool threw = false;
        try { Editor::ZeroCurrentItemModelFidsKeepMaterials(); } catch { threw = true; }
        ctx.AssertTrue(threw, "KeepMaterials zero refuses outside item editor");
    }
}
#endif
