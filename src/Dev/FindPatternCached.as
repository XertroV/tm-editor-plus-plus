namespace PatternCache {
    dictionary _cache;

    uint64 Get(const string &in pat) {
        uint64 cached = 0;
        if (_cache.Get(pat, cached)) {
            return cached;
        }
        uint64 fn = Dev::FindPattern(pat);
        if (fn != 0) {
            Set(pat, fn);
        }
        return fn;
    }

    void Set(const string &in pat, uint64 fn) {
        _cache[pat] = fn;
    }
}

uint64 Dev_FindPatternCached(const string &in pat) {
    return PatternCache::Get(pat);
}
