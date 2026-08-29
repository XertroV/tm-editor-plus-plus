#if DEV
namespace Tests {
    // Pin: BlockStock+0xC8 used to resolve to 0x388 and silently skip terrain
    // writes. MapInfo+0x80 must stay 0x390 (research/MacroblockTerrain.md).
    [Test]
    void MapTerrainGenealogyGridOffset(Tests::Context@ ctx) {
        ctx.AssertSame(uint(O_MAP_TERRAIN_GENEALOGY_GRID), uint(0x390), "O_MAP_TERRAIN_GENEALOGY_GRID == 0x390");
    }
}
#endif
