#if DEV
namespace Tests {
    [Test]
    void BlocksItems_HasTerrainSubtab(Tests::Context@ ctx) {
        auto tab = FindTerrainBlocksTab();
        ctx.AssertFalse(tab is null, "Terrain subtab registered");
        ctx.AssertFalse(tab.allowSkipTerrainPrefix, "Terrain does not skip the default fill");
        ctx.AssertFalse(tab.excludeTerrainFromCsv, "Terrain CSV includes terrain rows");
    }

    [Test]
    void TerrainList_ReadsPluginMapTypeTerrainBlocks(Tests::Context@ ctx) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        ctx.AssertFalse(editor is null, "in editor");
        ctx.AssertFalse(editor.PluginMapType is null, "PluginMapType exists");
        auto tab = FindTerrainBlocksTab();
        ctx.AssertFalse(tab is null, "Terrain tab");
        auto map = GetApp().RootMap;
        uint nb = tab.GetNbObjects(map);
        ctx.AssertSame(nb, editor.PluginMapType.TerrainBlocks.Length, "count is PluginMapType.TerrainBlocks");
        if (nb == 0) return;
        ctx.AssertTrue(tab.GetBlock(map, 0) is editor.PluginMapType.TerrainBlocks[0], "row 0 is TerrainBlocks[0]");
        uint last = nb - 1;
        ctx.AssertTrue(tab.GetBlock(map, last) is editor.PluginMapType.TerrainBlocks[last], "last row is TerrainBlocks[last]");
    }
}

ViewTerrainBlocksTab@ FindTerrainBlocksTab() {
    if (g_BlocksItemsTab is null) return null;
    auto children = g_BlocksItemsTab.Children;
    for (uint i = 0; i < children.tabs.Length; i++) {
        auto tab = cast<ViewTerrainBlocksTab>(children.tabs[i]);
        if (tab !is null) return tab;
    }
    return null;
}

Tester@ Test_TerrainList = Tester("TerrainList", generateTerrainListTests());

TestCase@[]@ generateTerrainListTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("Blocks & Items has Terrain subtab", terrain_test_subtab));
    ret.InsertLast(TestCase("Terrain list is PluginMapType.TerrainBlocks", terrain_test_reads_pmt));
    ret.InsertLast(TestCase("RemoveTerrainBlocks resets cell to default", terrain_test_reset_to_default));
    return ret;
}

void terrain_test_subtab() {
    auto tab = FindTerrainBlocksTab();
    assert(tab !is null, "Terrain subtab registered");
    assert(!tab.allowSkipTerrainPrefix, "Terrain does not skip the default fill");
    assert(!tab.excludeTerrainFromCsv, "Terrain CSV includes terrain rows");
}

void terrain_test_reads_pmt() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    assert(editor !is null, "in editor");
    assert(editor.PluginMapType !is null, "PluginMapType exists");
    auto tab = FindTerrainBlocksTab();
    assert(tab !is null, "Terrain tab");
    auto map = GetApp().RootMap;
    uint nb = tab.GetNbObjects(map);
    assert_eq(int(nb), int(editor.PluginMapType.TerrainBlocks.Length), "count is PluginMapType.TerrainBlocks");
    if (nb == 0) return;
    assert(tab.GetBlock(map, 0) is editor.PluginMapType.TerrainBlocks[0], "row 0 is TerrainBlocks[0]");
    uint last = nb - 1;
    assert(tab.GetBlock(map, last) is editor.PluginMapType.TerrainBlocks[last], "last row is TerrainBlocks[last]");
}

void terrain_test_reset_to_default() {
    auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    assert(editor !is null && editor.PluginMapType !is null, "editor+pmt");
    auto pmt = editor.PluginMapType;
    assert(pmt.TerrainBlocks.Length > 0, "has terrain cells");
    CGameCtnBlock@ raisedBlk = null;
    for (uint i = 0; i < pmt.TerrainBlocks.Length; i++) {
        auto b = pmt.TerrainBlocks[i];
        if (b is null || b.BlockInfo is null) continue;
        string n = b.BlockInfo.IdName;
        if (n == "Water" || n == "WaterHill") continue;
        @raisedBlk = b;
        break;
    }
    assert(raisedBlk !is null, "map has a dirt/cliff terrain cell to reset");
    string raisedName = raisedBlk.BlockInfo.IdName;
    auto c = Nat3ToInt3(Editor::GetBlockCoord(raisedBlk));
    bool reset = Editor::ResetTerrainCell(raisedBlk);
    assert(reset, "RemoveTerrainBlocks returned true at " + c.ToString());
    auto afterReset = pmt.GetBlock(c);
    if (afterReset is null) @afterReset = pmt.GetBlock(int3(c.x, 0, c.z));
    assert(afterReset !is null && afterReset.BlockInfo !is null, "cell after reset");
    string got = afterReset.BlockInfo.IdName;
    assert(got != raisedName, "raised " + raisedName + " changed, still " + got);
    assert(got == "WaterHill" || got == "Water", "engine default is WaterHill/Water, got " + got);
}
#endif
