#if DEV
const string FindPatternCached_NoHit = "DE AD BE EF 01 23 45 67 89 AB CD EF FE DC BA 98 76 54 32 10 CA FE BA BE";
const string FindPatternCached_SentinelKey = "__epp_findpattern_cache_roundtrip__";

void FindPatternCached_CheckUnknown() {
    uint64 direct = Dev::FindPattern(FindPatternCached_NoHit);
    uint64 cached = Dev_FindPatternCached(FindPatternCached_NoHit);
    assert(direct == 0, "FindPattern miss is 0");
    assert(cached == 0, "cached miss is 0");
    assert(cached == direct, "wrapper matches FindPattern");
}

void FindPatternCached_CheckRoundtrip() {
    uint64 sent = 0x123456789ABCDEF0;
    PatternCache::Set(FindPatternCached_SentinelKey, sent);
    uint64 got = PatternCache::Get(FindPatternCached_SentinelKey);
    assert(got == sent, "dictionary uint64 roundtrip");
    assert(Dev_FindPatternCached(FindPatternCached_SentinelKey) == sent, "wrapper reads Set value");
    PatternCache::_cache.Delete(FindPatternCached_SentinelKey);
}

void FindPatternCached_CheckKnown() {
    string pat = GmSurfReplace::ConstructPattern(EGmSurfType::Sphere);
    assert(pat.Length > 0, "Sphere construct pattern");
    uint64 direct = Dev::FindPattern(pat);
    assert(direct != 0, "FindPattern hit");
    uint64 first = Dev_FindPatternCached(pat);
    uint64 second = Dev_FindPatternCached(pat);
    assert(first == direct, "first cached call matches FindPattern");
    assert(second == first, "second call is a cache hit");
    assert(PatternCache::Get(pat) == first, "Get matches wrapper");
}

namespace Tests {
    [Test]
    void FindPatternCached_UnknownPatternIsZero(Tests::Context@ ctx) {
        FindPatternCached_CheckUnknown();
    }

    [Test]
    void FindPatternCached_SetGetRoundtrip(Tests::Context@ ctx) {
        FindPatternCached_CheckRoundtrip();
    }

    [Test]
    void FindPatternCached_KnownPatternMatchesFindPattern(Tests::Context@ ctx) {
        FindPatternCached_CheckKnown();
    }
}

Tester@ Test_FindPatternCached = Tester("FindPatternCached", generateFindPatternCachedTests());

TestCase@[]@ generateFindPatternCachedTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("unknown pattern is zero", FindPatternCached_CheckUnknown));
    ret.InsertLast(TestCase("set/get uint64 roundtrip", FindPatternCached_CheckRoundtrip));
    ret.InsertLast(TestCase("known pattern matches FindPattern", FindPatternCached_CheckKnown));
    return ret;
}
#endif
