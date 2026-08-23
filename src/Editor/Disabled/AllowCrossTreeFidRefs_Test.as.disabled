#if DEV
namespace Editor {
    Tester@ Test_AllowCrossTreeFidRefs = Tester("AllowCrossTreeFidRefs", generateAllowCrossTreeFidRefsTests());

    TestCase@[]@ generateAllowCrossTreeFidRefsTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("AllowCrossTreeFidRefs reject pattern found", allow_cross_tree_pattern_found));
        ret.InsertLast(TestCase("AllowCrossTreeFidRefs build pattern found", allow_cross_tree_build_pattern_found));
        ret.InsertLast(TestCase("AllowCrossTreeFidRefs patch off by default", allow_cross_tree_patch_off_by_default));
        return ret;
    }

    void allow_cross_tree_pattern_found() {
        auto p = Dev::FindPattern(AllowCrossTreeFidRefs::Pattern);
        assert(p != 0, "AllowCrossTreeFidRefs reject pattern not found — game update moved GbxArchive_BuildBodyRefTreeOrRejectCrossTree");
    }

    void allow_cross_tree_build_pattern_found() {
        auto p = Dev::FindPattern(AllowCrossTreeFidRefs::PatternBuild);
        assert(p != 0, "AllowCrossTreeFidRefs build pattern not found — game update moved the FUN_140901b40 / ae0 JZ");
    }

    void allow_cross_tree_patch_off_by_default() {
        assert(!AllowCrossTreeFidRefs::IsActive, "cross-tree fid-ref patch must stay off until toggled");
    }
}

namespace Tests {
    [Test]
    void AllowCrossTreeFidRefs_PatternFound(Tests::Context@ ctx) {
        auto p = Dev::FindPattern(Editor::AllowCrossTreeFidRefs::Pattern);
        ctx.AssertFalse(p == 0, "AllowCrossTreeFidRefs reject pattern found in live exe");
    }

    [Test]
    void AllowCrossTreeFidRefs_BuildPatternFound(Tests::Context@ ctx) {
        auto p = Dev::FindPattern(Editor::AllowCrossTreeFidRefs::PatternBuild);
        ctx.AssertFalse(p == 0, "AllowCrossTreeFidRefs build pattern found in live exe");
    }

    [Test]
    void AllowCrossTreeFidRefs_PatchOffByDefault(Tests::Context@ ctx) {
        ctx.AssertFalse(Editor::GetAllowCrossTreeFidRefsPatch(), "AllowCrossTreeFidRefs inactive by default");
    }
}
#endif
