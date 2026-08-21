#if DEV
namespace Editor {
    Tester@ Test_ForceCollectorSkinnable = Tester("ForceCollectorSkinnable", generateForceCollectorSkinnableTests());

    TestCase@[]@ generateForceCollectorSkinnableTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("IsCollectorModelSkinnable pattern found", forceCollectorSkinnable_pattern_found));
        return ret;
    }

    void forceCollectorSkinnable_pattern_found() {
        auto p = Dev::FindPattern(ForceCollectorSkinnable::Pattern);
        assert(p != 0, "ForceCollectorSkinnable pattern not found — game update moved IsCollectorModelSkinnable");
    }
}

namespace Tests {
    [Test]
    void ForceCollectorSkinnable_PatternFound(Tests::Context@ ctx) {
        auto p = Dev::FindPattern(Editor::ForceCollectorSkinnable::Pattern);
        ctx.AssertFalse(p == 0, "IsCollectorModelSkinnable pattern found in live exe");
    }
}
#endif
