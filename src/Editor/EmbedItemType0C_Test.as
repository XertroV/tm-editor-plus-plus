#if DEV
namespace Editor {
    Tester@ Test_EmbedItemType0C = Tester("EmbedItemType0C", generateEmbedItemType0CTests());

    TestCase@[]@ generateEmbedItemType0CTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("0x683e does not allow ItemTypeE 0x0C", embedItemType0C_vanilla_mask));
        ret.InsertLast(TestCase("0x783e allows ItemTypeE 0x0C and keeps type 1", embedItemType0C_patched_mask));
        ret.InsertLast(TestCase("CollectAndEmbedItems type-mask pattern found", embedItemType0C_pattern_found));
        return ret;
    }

    bool MaskAllows(uint mask, uint ty) {
        return ty < 15 && ((mask >> ty) & 1) != 0;
    }

    void embedItemType0C_vanilla_mask() {
        assert(!MaskAllows(EmbedItemType0C::VanillaMask, 0x0C), "vanilla 0x683e rejects 0x0C");
        assert(MaskAllows(EmbedItemType0C::VanillaMask, 1), "vanilla still allows Decoration");
    }

    void embedItemType0C_patched_mask() {
        assert_eq(int(EmbedItemType0C::VanillaMask | (1 << 12)), int(EmbedItemType0C::WithType0C), "0x683e|bit12=0x783e");
        assert(MaskAllows(EmbedItemType0C::WithType0C, 0x0C), "patched mask allows 0x0C");
        assert(MaskAllows(EmbedItemType0C::WithType0C, 1), "patched mask still allows type 1");
    }

    void embedItemType0C_pattern_found() {
        auto p = Dev::FindPattern(EmbedItemType0C::Pattern);
        assert(p != 0, "EmbedItemType0C pattern not found — game update moved CollectAndEmbedItems mask");
    }
}

namespace Tests {
    [Test]
    void EmbedItemType0C_VanillaMaskRejects0C(Tests::Context@ ctx) {
        ctx.AssertFalse(Editor::MaskAllows(Editor::EmbedItemType0C::VanillaMask, 0x0C), "0x683e rejects 0x0C");
    }

    [Test]
    void EmbedItemType0C_PatchedMaskAllows0C(Tests::Context@ ctx) {
        ctx.AssertSame(int(Editor::EmbedItemType0C::VanillaMask | (1 << 12)), int(Editor::EmbedItemType0C::WithType0C), "OR bit12");
        ctx.AssertTrue(Editor::MaskAllows(Editor::EmbedItemType0C::WithType0C, 0x0C), "0x783e allows 0x0C");
    }

    [Test]
    void EmbedItemType0C_PatternFound(Tests::Context@ ctx) {
        auto p = Dev::FindPattern(Editor::EmbedItemType0C::Pattern);
        ctx.AssertFalse(p == 0, "type-mask site found in live exe");
    }
}
#endif
