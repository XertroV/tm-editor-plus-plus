#if DEV && SIG_DEVELOPER

namespace LMComputePreviewSpike {
    Tester@ Test_LmPreviewBoard = Tester("LmPreviewBoard", generateLmPreviewBoardTests());

    TestCase@[]@ generateLmPreviewBoardTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("boring defaults to Mask only", test_boring_defaults));
        ret.InsertLast(TestCase("pack 2x2 known cells", test_pack_grid_2x2));
        ret.InsertLast(TestCase("fill interesting skips boring", test_fill_skips_mask));
        ret.InsertLast(TestCase("choose cols near square for 14", test_choose_cols_14));
        ret.InsertLast(TestCase("letterbox wide cell", test_letterbox_wide_cell));
        ret.InsertLast(TestCase("hero stack half + atlas under", test_hero_stack));
        ret.InsertLast(TestCase("control ids are unique", test_control_ids_unique));
        ret.InsertLast(TestCase("hide at 1.0 not 0.99", test_hide_at_progress));
        ret.InsertLast(TestCase("image color from gain", test_image_color_from_gain));
        ret.InsertLast(TestCase("gpu desc resource rejects null", test_gpu_desc_resource_null));
        ret.InsertLast(TestCase("depthcmp is vis-shadow not label diffuse", test_depthcmp_not_label_diffuse));
        return ret;
    }

    void test_boring_defaults() {
        LmPreviewBoringSet b;
        assert(b.Contains("BitmapLM_Mask"), "Mask is boring by default");
        assert(b.Contains("BitmapLM_LightWeight"), "LightWeight is boring by default");
        assert(!b.Contains("BitmapSM_DepthToPeel"), "DepthToPeel is not boring");
        assert(!b.Contains("BitmapLM_MDiffuse"), "MDiffuse is not boring");
        assert(!b.Contains("BitmapSM_ColorPeeled"), "ColorPeeled is not boring");
        assert_eq(int(b.names.Length), 2, "Mask + LightWeight");
        b.Add("BitmapLM_LListUV");
        assert(b.Contains("BitmapLM_LListUV"), "Add");
        b.Toggle("BitmapLM_Mask");
        assert(!b.Contains("BitmapLM_Mask"), "Toggle removes");
        b.Toggle("BitmapLM_Mask");
        assert(b.Contains("BitmapLM_Mask"), "Toggle adds back");
    }

    void test_pack_grid_2x2() {
        // cover (-1.6,-0.9)..(1.6,0.9), gap 0.08, 2x2
        LmPreviewRect@ cover = LmPreviewRect(0.0, 0.0, 1.60, 0.90);
        auto cells = PackGrid(4, 2, cover, 0.08);
        assert_eq(int(cells.Length), 4, "4 cells");
        assert_nearly_eq(cells[0].halfW, 0.78, 1e-5, "halfW");
        assert_nearly_eq(cells[0].halfH, 0.43, 1e-5, "halfH");
        assert_nearly_eq(cells[0].cx, -0.82, 1e-5, "top-left cx");
        assert_nearly_eq(cells[0].cy, 0.47, 1e-5, "top-left cy");
        assert_nearly_eq(cells[1].cx, 0.82, 1e-5, "top-right cx");
        assert_nearly_eq(cells[1].cy, 0.47, 1e-5, "top-right cy");
        assert_nearly_eq(cells[2].cx, -0.82, 1e-5, "bot-left cx");
        assert_nearly_eq(cells[2].cy, -0.47, 1e-5, "bot-left cy");
        assert_nearly_eq(cells[3].cx, 0.82, 1e-5, "bot-right cx");
        assert_nearly_eq(cells[3].cy, -0.47, 1e-5, "bot-right cy");
        assert(!cells[0].Overlaps(cells[1]), "no horiz overlap");
        assert(!cells[0].Overlaps(cells[2]), "no vert overlap");
    }

    void test_fill_skips_mask() {
        auto board = LmPreviewBoard();
        board.FillInteresting();
        assert(board.Find("BitmapLM_Mask") is null, "Mask not assembled");
        assert(board.Find("BitmapSM_ColorPeeled") !is null, "ColorPeeled assembled");
        assert(board.Find("BitmapLM_MDiffuse") !is null, "MDiffuse assembled");
        assert(board.Find("BitmapLM_LightWeight") is null, "LightWeight not assembled");
        assert(board.Find("BitmapSM_DepthToPeel") is null, "DepthToPeel needs VisShadow");
        assert(board.Find("BitmapShadow") is null, "Shadow needs VisShadow");
        assert_eq(int(board.slots.Length), int(CatalogNames.Length) - 4, "boring + depthcmp");
        board.boring.Add("BitmapLM_LListUV");
        board.FillInteresting();
        assert(board.Find("BitmapLM_LListUV") is null, "newly boring dropped");
        assert_eq(int(board.slots.Length), int(CatalogNames.Length) - 5, "four boring-or-depth");
    }

    void test_choose_cols_14() {
        LmPreviewRect@ cover = LmPreviewRect(0.0, 0.0, 1.60, 0.90);
        assert_eq(int(ChooseCols(14, cover, 0.04, 1.0)), 5, "5x3 is nearest square on 3.2x1.8");
        assert_eq(int(ChooseCols(1, cover, 0.04, 1.0)), 1, "single tile");
    }

    void test_letterbox_wide_cell() {
        // cell 1.04 x 0.12 (the old 9:1 strip); square image must use height
        LmPreviewRect@ cell = LmPreviewRect(0.0, 0.0, 0.52, 0.06);
        float hw = 0.0;
        float hh = 0.0;
        FitAspect(cell, 1.0, hw, hh);
        assert_nearly_eq(hh, 0.06, 1e-5, "uses cell height");
        assert_nearly_eq(hw, 0.06, 1e-5, "square so width matches height");
        assert(hw < cell.halfW - 0.01, "pillarboxed inside the wide cell");
    }

    void test_hero_stack() {
        auto board = LmPreviewBoard();
        board.WithCover(1.60, 0.90).WithCols(0).WithGap(0.04)
            .WithHero("BitmapSM_ColorPeeled").WithSecondary("BitmapLM_MDiffuse");
        board.ClearSlots();
        board.Add("BitmapSM_ColorPeeled");
        board.Add("BitmapLM_MDiffuse");
        board.Add("BitmapLM_Temp_Accum");
        board.Relayout();
        auto hero = board.Find("BitmapSM_ColorPeeled");
        auto under = board.Find("BitmapLM_MDiffuse");
        auto rest = board.Find("BitmapLM_Temp_Accum");
        assert(hero !is null && under !is null && rest !is null, "slots present");
        assert_nearly_eq(hero.rect.halfW, hero.rect.halfH, 1e-3, "hero square");
        assert_nearly_eq(under.rect.halfW, hero.rect.halfW, 1e-3, "under same size");
        // old hero half was 0.90; half dims ≈ 0.44 after gap
        assert(hero.rect.halfW < 0.50 && hero.rect.halfW > 0.40, "hero is half the old 0.90");
        assert(hero.rect.cy > under.rect.cy, "atlas sits under hero");
        assert(hero.rect.cx < rest.rect.cx, "stack is on the left");
        assert(!hero.rect.Overlaps(under.rect), "hero vs under");
        assert(!hero.rect.Overlaps(rest.rect), "hero vs rest");
        assert(!under.rect.Overlaps(rest.rect), "under vs rest");
    }

    void test_control_ids_unique() {
        dictionary seen;
        for (uint i = 0; i < CatalogNames.Length; i++) {
            string id = ControlIdFor(CatalogNames[i]);
            assert(!seen.Exists(id), "unique " + id);
            seen[id] = true;
        }
        assert(ControlIdFor("BitmapLM_ILightDir") != ControlIdFor("BitmapSprite_ILightDir"),
            "LM vs Sprite ILightDir");
    }

    void test_hide_at_progress() {
        assert(!ShouldHideAtProgress(0.99), "99% still visible");
        assert(!ShouldHideAtProgress(0.999), "just under 100 still visible");
        assert(ShouldHideAtProgress(1.0), "100% hides");
        assert(ShouldHideAtProgress(1.01), "past 100 hides");
        assert(!ShouldHideAtProgress(0.0), "start of bake visible");
    }

    void test_image_color_from_gain() {
        vec3 id = ImageColorFromGain(1.0);
        assert_nearly_eq(id.x, 1.0, 1e-5, "identity x");
        assert_nearly_eq(id.y, 1.0, 1e-5, "identity y");
        assert_nearly_eq(id.z, 1.0, 1e-5, "identity z");
        vec3 bright = ImageColorFromGain(8.0);
        assert_nearly_eq(bright.x, 8.0, 1e-5, "gain 8 x");
        assert_nearly_eq(bright.y, 8.0, 1e-5, "gain 8 y");
        assert_nearly_eq(bright.z, 8.0, 1e-5, "gain 8 z");
        vec3 clamped = ImageColorFromGain(-2.0);
        assert_nearly_eq(clamped.x, 0.0, 1e-5, "neg gain x");
        assert_nearly_eq(clamped.y, 0.0, 1e-5, "neg gain y");
        assert_nearly_eq(clamped.z, 0.0, 1e-5, "neg gain z");
    }

    void test_gpu_desc_resource_null() {
        assert(!GpuDescHasResource(null), "null bmp is not live");
    }

    void test_depthcmp_not_label_diffuse() {
        assert(CatalogNeedsVisShadowPresent("BitmapShadow"), "Shadow");
        assert(CatalogNeedsVisShadowPresent("BitmapSM_DepthToPeel"), "DepthToPeel");
        assert(!CatalogNeedsVisShadowPresent("BitmapSM_ColorPeeled"), "ColorPeeled is the peel color");
        assert(!CatalogNeedsVisShadowPresent("BitmapLM_MDiffuse"), "MDiffuse is Diffuse");
        assert(!UsageIsLabelDiffuse("DepthCmp"), "DepthCmp");
        assert(!UsageIsLabelDiffuse("Depth"), "Depth");
        assert(UsageIsLabelDiffuse("Render"), "Render");
        assert(UsageIsLabelDiffuse("RenderFloat"), "RenderFloat");
        assert(UsageIsLabelDiffuse("Light"), "Light");
        assert(UsageIsLabelDiffuse("Color16b"), "Color16b");
    }
}

#endif
