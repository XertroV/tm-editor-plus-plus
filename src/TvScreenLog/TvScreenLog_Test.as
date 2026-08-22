#if DEV
namespace TvScreenLog {
    Tester@ Test_TvScreenLog = Tester("TvScreenLog", generateTvScreenLogTests());

    TestCase@[]@ generateTvScreenLogTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("TvScreenLog sites resolved", sites_resolved));
        return ret;
    }

    void sites_resolved() {
        TvScreenLog::OnPluginLoad();
        assert(TvScreenLog::g_Sites.Length >= 7, "expected 7 hook sites");
        for (uint i = 0; i < TvScreenLog::g_Sites.Length; i++) {
            auto@ s = TvScreenLog::g_Sites[i];
            assert(s.hook !is null, s.name + " hook helper missing");
            assert(s.hook.PatternPtr != 0, s.name + " pattern not found");
        }
    }
}

namespace Tests {
    [Test]
    void TvScreenLog_SitesResolved(Tests::Context@ ctx) {
        TvScreenLog::OnPluginLoad();
        ctx.AssertTrue(TvScreenLog::g_Sites.Length >= 7, "7 hook sites");
        for (uint i = 0; i < TvScreenLog::g_Sites.Length; i++) {
            auto@ s = TvScreenLog::g_Sites[i];
            ctx.AssertTrue(s.hook !is null && s.hook.PatternPtr != 0, s.name);
        }
    }
}
#endif
