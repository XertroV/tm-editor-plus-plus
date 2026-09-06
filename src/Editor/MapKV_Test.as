#if DEV
// Throw-style, as in tm-char-vis: executable both by [Test] and an isolated
// smoke driver passing null; no game/map mutation is needed. Registered as a
// Tester suite as well (as FindPatternCached_Test.as does), so the suite runs
// on plugin load and its pass/fail lines land in Openplanet.log.
//
// Nothing here reads or writes real map metadata. The memory tests build their
// own buffers with Dev::Allocate, and the supervisor tests drive it with
// invented map pointers behind MapKVHealth's snapshot/restore.

// Stands in for MapKV::TryReadScalar so the drift check can be exercised with
// no live map: whatever is put in `values` is what the "metadata" holds.
class FakeTraitSource : MapKVHealth::TraitSource {
    dictionary values;
    bool TryRead(CGameCtnChallenge@ map, const string &in trait, string &out value) override {
        value = "";
        string stored;
        if (!values.Get(trait, stored)) return false;
        value = stored;
        return true;
    }
}

namespace Tests {
    void MapKVCheck(bool ok, const string &in message) {
        if (!ok) throw(message);
    }

    // Two map pointers that no real map can collide with: aligned, in range,
    // and far from anything the game maps.
    const uint64 MAPKV_TEST_MAP_A = 0x0000123456789000;
    const uint64 MAPKV_TEST_MAP_B = 0x00001234567AB000;
    const uint64 MAPKV_TEST_PLUGIN = 0x0000123456700000;
    // Verified live on 2026-09-06: a Dev::Safe* read here reports
    // "Unable to read memory" rather than returning zero.
    const uint64 MAPKV_TEST_UNMAPPED = 0x0000700000000000;

    void MapKV_CheckNullMapDoesNotCreateMetadata() {
        MapKVCheck(MapKV::ListKeys(null).Length == 0, "absent map has no keys");
        string value = "old";
        MapKVCheck(!(MapKV::TryReadValue(null, "_EKV_missing", value)), "expected false");
        MapKVCheck((value) == (""), "values match");
        value = "old";
        MapKVCheck(!(MapKV::TryReadScalar(null, "MissingTrait", value)), "expected false");
        MapKVCheck((value) == (""), "values match");
    }

    void MapKV_CheckStringDataMayBeUnaligned() {
        MapKVCheck(MapKV::BytePointerValid(0x0000000317876E21), "observed heap string address is valid");
        MapKVCheck(!MapKV::PointerValid(0x0000000317876E21), "metadata rows still require alignment");
        MapKVCheck(!MapKV::BytePointerValid(0), "null byte pointer rejected");
    }

    void MapKV_CheckRejectsInvalidPointers() {
        MapKVCheck(!(MapKV::PointerValid(0)), "expected false");
        MapKVCheck(!(MapKV::PointerValid(0x10001)), "expected false");
        MapKVCheck(!(MapKV::PointerValid(0x0000800000000000)), "expected false");
    }

    // The production gate is only the kind bits plus a nonzero interned index.
    // Text[] passes it on purpose: arrays and dictionaries share compound kind
    // 7, and only the pairs buffer can separate them.
    void MapKV_CheckCompoundTypeIdGate() {
        MapKVCheck(MapKV::CompoundTypeIdIsPlausible(0x467), "observed Text[Text] id accepted");
        MapKVCheck(MapKV::CompoundTypeIdIsPlausible(0x227), "observed Text[] id also has compound kind bits");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(5), "scalar Text id rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(1), "scalar Boolean id rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(0), "zero id rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(7), "compound kind with no interned index rejected");
        MapKVCheck(!MapKV::CompoundTypeIdIsPlausible(0x226), "non-compound kind bits rejected");
    }

    // Builds the 0x10-byte pair records by hand: a Text[] leaves the key slot
    // null, a Text[Text] fills it.
    void MapKV_CheckArrayPairsRejected() {
        uint64 buffer = Dev::Allocate(0x40);
        MapKVCheck(buffer != 0, "test buffer allocated");
        uint64 keyPtr, valuePtr;
        bool rejectedArray = false;
        bool rejectedUnaligned = false;
        bool acceptedDictionary = false;
        string failure;
        // A plausible, aligned target inside our own buffer.
        uint64 target = buffer + 0x20;
        Dev::Write(buffer + 0, uint64(0));
        Dev::Write(buffer + 8, target);
        try { MapKV::ReadPair(buffer, 0, keyPtr, valuePtr); }
        catch { rejectedArray = getExceptionInfo().Contains("array"); }
        Dev::Write(buffer + 0, target + 1);
        try { MapKV::ReadPair(buffer, 0, keyPtr, valuePtr); }
        catch { rejectedUnaligned = getExceptionInfo().Contains("Invalid _EKV_ entry pointer"); }
        Dev::Write(buffer + 0, target);
        try {
            MapKV::ReadPair(buffer, 0, keyPtr, valuePtr);
            acceptedDictionary = keyPtr == target && valuePtr == target;
        } catch { failure = getExceptionInfo(); }
        Dev::Free(buffer);
        MapKVCheck(rejectedArray, "a null key slot is reported as an array, not a dictionary");
        MapKVCheck(rejectedUnaligned, "an unaligned key pointer is rejected");
        MapKVCheck(acceptedDictionary, "two real pointers are accepted: " + failure);
    }

    // ReadBytes must return exactly the requested bytes or throw. It must never
    // stop at a NUL (that would silently truncate) and never read unmapped
    // memory (that would take the process down).
    void MapKV_CheckBoundsSafeStringRead() {
        uint64 buffer = Dev::Allocate(0x40);
        MapKVCheck(buffer != 0, "test buffer allocated");
        string exact;
        string withNul;
        bool refusedUnmapped = false;
        bool refusedOversize = false;
        string failure;
        try {
            for (uint i = 0; i < 5; i++) Dev::Write(buffer + i, uint8("hello"[i]));
            Dev::Write(buffer + 5, uint8(0));
            Dev::Write(buffer + 6, uint8(65));
            exact = MapKV::ReadBytes(buffer, 5);
            withNul = MapKV::ReadBytes(buffer, 7);
            MapKVCheck(MapKV::ReadBytes(buffer, 0) == "", "a zero-length read is the empty string");
        } catch { failure = getExceptionInfo(); }
        Dev::Free(buffer);
        MapKVCheck(failure.Length == 0, "reading our own buffer must not throw: " + failure);
        MapKVCheck(exact == "hello", "exactly the requested bytes are returned");
        MapKVCheck(withNul.Length == 7, "an embedded NUL does not truncate the read");
        MapKVCheck(withNul[5] == 0 && withNul[6] == 65, "bytes after an embedded NUL survive");
        try { MapKV::ReadBytes(MAPKV_TEST_UNMAPPED, 4); }
        catch { refusedUnmapped = true; }
        MapKVCheck(refusedUnmapped, "an unmapped address throws instead of faulting");
        try { MapKV::ReadBytes(MAPKV_TEST_UNMAPPED, MapKV::MAX_VALUE_BYTES + 1); }
        catch { refusedOversize = getExceptionInfo().Contains("too large"); }
        MapKVCheck(refusedOversize, "a length past MAX_VALUE_BYTES is refused before any read");
    }

    // --- health state machine ---------------------------------------------

    void MapKV_CheckHealthUnverifiedUntilObservation() {
        auto saved = MapKVHealth::Snapshot();
        string reason;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(FakeTraitSource());
        uint state = MapKVHealth::EvaluateFor(MAPKV_TEST_MAP_A, null, reason);
        MapKVHealth::Restore(saved);
        MapKVCheck(state == MapKVHealth::STATE_UNVERIFIED, "no observation yet means unverified");
        MapKVCheck(reason.Contains("unverified"), "unverified says why: " + reason);
    }

    void MapKV_CheckHealthyWhenObservationsMatch() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_METADATA_DISABLED] = "false";
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "abc";
        string reason;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        // ManiaScript spells a Boolean True/False; the reader spells it
        // true/false. Agreement must survive that.
        MapKVHealth::NoteTraitObservationFor(MAPKV_TEST_MAP_A, MapKVHealth::TRAIT_METADATA_DISABLED, "False");
        MapKVHealth::NoteTraitObservationFor(MAPKV_TEST_MAP_A, MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "abc");
        uint state = MapKVHealth::EvaluateFor(MAPKV_TEST_MAP_A, null, reason);
        MapKVHealth::Restore(saved);
        MapKVCheck(state == MapKVHealth::STATE_HEALTHY, "matching observations are healthy: " + reason);
        MapKVCheck(reason == "", "a healthy reader has nothing to report");
    }

    void MapKV_CheckBrokenOnDrift() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "what memory says";
        string reason;
        string absentReason;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        MapKVHealth::NoteTraitObservationFor(MAPKV_TEST_MAP_A, MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "what the plugin says");
        uint state = MapKVHealth::EvaluateFor(MAPKV_TEST_MAP_A, null, reason);
        // Sticky: a later matching observation does not rehabilitate the walk.
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "what the plugin says";
        uint again = MapKVHealth::EvaluateFor(MAPKV_TEST_MAP_A, null, reason);
        // An observed trait that memory cannot find at all is also drift.
        MapKVHealth::Reset();
        auto empty = FakeTraitSource();
        MapKVHealth::SetTraitSource(empty);
        MapKVHealth::NoteTraitObservationFor(MAPKV_TEST_MAP_A, MapKVHealth::TRAIT_METADATA_DISABLED, "False");
        uint absent = MapKVHealth::EvaluateFor(MAPKV_TEST_MAP_A, null, absentReason);
        MapKVHealth::Restore(saved);
        MapKVCheck(state == MapKVHealth::STATE_BROKEN, "a disagreeing trait fences the reader off");
        MapKVCheck(reason.Contains(MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES), "the reason names the trait: " + reason);
        MapKVCheck(again == MapKVHealth::STATE_BROKEN, "broken is sticky for its map");
        MapKVCheck(absent == MapKVHealth::STATE_BROKEN, "an observed trait missing from memory is drift");
        MapKVCheck(absentReason.Contains("absent"), "the reason says it is absent: " + absentReason);
    }

    // FromML's plugin globals go stale across a map change, so an observation
    // must only ever be compared against the map it arrived with.
    void MapKV_CheckObservationsArePerMap() {
        auto saved = MapKVHealth::Snapshot();
        auto source = FakeTraitSource();
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "map A value";
        string reasonA;
        string reasonB;
        MapKVHealth::Reset();
        MapKVHealth::SetTraitSource(source);
        MapKVHealth::NoteTraitObservationFor(MAPKV_TEST_MAP_A, MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES, "map A value");
        uint stateA = MapKVHealth::EvaluateFor(MAPKV_TEST_MAP_A, null, reasonA);
        // Same observation, different map: it must not be compared at all,
        // even though memory now reports a value that disagrees with it.
        source.values[MapKVHealth::TRAIT_CUSTOM_COLOR_TABLES] = "map B value";
        uint stateB = MapKVHealth::EvaluateFor(MAPKV_TEST_MAP_B, null, reasonB);
        MapKVHealth::Restore(saved);
        MapKVCheck(stateA == MapKVHealth::STATE_HEALTHY, "map A verified against its own observation");
        MapKVCheck(stateB == MapKVHealth::STATE_UNVERIFIED, "map B has no observation of its own: " + reasonB);
    }

    // --- echo cache and read resolution ------------------------------------

    void MapKV_CheckEchoVerifiesMemory() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::StoreEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a", MapKVHealth::MLEcho("stored"));
        auto agreed = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a",
            true, "", true, "stored");
        auto unchecked = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.other",
            true, "", true, "whatever");
        MapKVHealth::Restore(saved);
        MapKVCheck(agreed.source == MapKVHealth::SOURCE_MEMORY_VERIFIED, "memory matching the echo is verified");
        MapKVCheck(agreed.value == "stored" && agreed.present, "the verified read returns the value");
        MapKVCheck(agreed.mismatchReason == "", "a matching read reports no mismatch");
        MapKVCheck(unchecked.source == MapKVHealth::SOURCE_MEMORY, "a key with no echo is plain memory");
    }

    void MapKV_CheckEchoMismatchServesCache() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::StoreEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a", MapKVHealth::MLEcho("stored"));
        auto differs = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a",
            true, "", true, "something else");
        auto missing = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a",
            true, "", false, "");
        MapKVHealth::Restore(saved);
        MapKVCheck(differs.source == MapKVHealth::SOURCE_ML_CACHE, "a disagreeing read falls back to the echo");
        MapKVCheck(differs.value == "stored" && differs.present, "the echoed value is authoritative");
        MapKVCheck(differs.mismatchReason.Contains("_EKV_Plugin.a"), "the mismatch names the key: " + differs.mismatchReason);
        MapKVCheck(differs.blockedReason == "", "a cached answer is not blocked");
        MapKVCheck(missing.source == MapKVHealth::SOURCE_ML_CACHE, "a key memory cannot find is also drift");
        MapKVCheck(missing.mismatchReason.Contains("absent"), "the reason says memory lost it: " + missing.mismatchReason);
    }

    // ManiaScript TL::Length counts characters, AngelScript string.Length counts
    // UTF-8 bytes. They agree for ASCII and only for ASCII, so a length-only
    // echo is compared only over ASCII.
    void MapKV_CheckLargeEchoComparesLengthOnlyForAscii() {
        MapKVCheck("abc".Length == 3, "ASCII: one byte per character");
        MapKVCheck("café".Length == 5, "non-ASCII: string.Length counts UTF-8 bytes, not characters");
        MapKVCheck(MapKVHealth::IsAscii("abc"), "plain ASCII is comparable");
        MapKVCheck(!MapKVHealth::IsAscii("café"), "anything above U+007F is not");
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::StoreEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.big", MapKVHealth::MLEcho(uint(4)));
        auto sameLength = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.big",
            true, "", true, "abcd");
        auto wrongLength = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.big",
            true, "", true, "abcde");
        // "café" is 4 characters but 5 bytes: the units disagree, so no verdict.
        auto notComparable = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.big",
            true, "", true, "café");
        MapKVHealth::Restore(saved);
        MapKVCheck(sameLength.source == MapKVHealth::SOURCE_MEMORY, "a length-only echo never verifies content");
        MapKVCheck(sameLength.mismatchReason == "", "a matching ASCII length is not drift");
        MapKVCheck(wrongLength.mismatchReason.Length > 0, "a differing ASCII length is drift");
        MapKVCheck(wrongLength.blockedReason.Length > 0, "a length-only echo cannot answer the read");
        MapKVCheck(wrongLength.source == MapKVHealth::SOURCE_UNAVAILABLE, "so the source is unavailable");
        MapKVCheck(notComparable.mismatchReason == "", "mismatched length units are not compared");
        MapKVCheck(notComparable.value == "café", "the memory value is still returned");
    }

    void MapKV_CheckEchoCacheInvalidatedOnMapChange() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::StoreEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a", MapKVHealth::MLEcho("A"));
        bool foundOnA = MapKVHealth::LookupEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a") !is null;
        bool foundOnB = MapKVHealth::LookupEchoFor(MAPKV_TEST_MAP_B, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a") !is null;
        bool foundOtherPlugin = MapKVHealth::LookupEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN + 8, "_EKV_Plugin.a") !is null;
        // A write against a different map drops everything the old one cached.
        MapKVHealth::StoreEchoFor(MAPKV_TEST_MAP_B, MAPKV_TEST_PLUGIN, "_EKV_Plugin.b", MapKVHealth::MLEcho("B"));
        uint sizeAfterSwitch = MapKVHealth::EchoCount();
        bool staleSurvived = MapKVHealth::LookupEchoFor(MAPKV_TEST_MAP_B, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a") !is null;
        MapKVHealth::Restore(saved);
        MapKVCheck(foundOnA, "the echo is found for the map it arrived with");
        MapKVCheck(!foundOnB, "and not for another map");
        MapKVCheck(!foundOtherPlugin, "and not after the supporting plugin changed");
        MapKVCheck(sizeAfterSwitch == 1, "a map change clears the cache");
        MapKVCheck(!staleSurvived, "no entry outlives its map");
    }

    void MapKV_CheckBrokenReaderBlocksWithoutCache() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        MapKVHealth::StoreEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.small", MapKVHealth::MLEcho("cached"));
        MapKVHealth::StoreEchoFor(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.big", MapKVHealth::MLEcho(uint(9999)));
        auto served = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.small",
            false, "row stride drifted", false, "");
        auto blockedLarge = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.big",
            false, "row stride drifted", false, "");
        auto blockedUnknown = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.unknown",
            false, "row stride drifted", false, "");
        MapKVHealth::Restore(saved);
        MapKVCheck(served.source == MapKVHealth::SOURCE_ML_CACHE, "a cached key survives a fenced-off reader");
        MapKVCheck(served.value == "cached" && served.present, "and answers from the echo");
        MapKVCheck(served.blockedReason == "", "so it is not blocked");
        MapKVCheck(blockedLarge.blockedReason == "row stride drifted", "a length-only echo cannot answer");
        MapKVCheck(blockedUnknown.blockedReason == "row stride drifted", "an unknown key is blocked, with the reason");
        MapKVCheck(blockedUnknown.source == MapKVHealth::SOURCE_UNAVAILABLE, "and reports no source");
    }

    // A read of a key nothing knows about must be plain, unblocked memory.
    void MapKV_CheckHealthyReaderNeedsNoCache() {
        auto saved = MapKVHealth::Snapshot();
        MapKVHealth::Reset();
        auto read = MapKVHealth::ResolveRead(MAPKV_TEST_MAP_A, MAPKV_TEST_PLUGIN, "_EKV_Plugin.a",
            true, "", false, "");
        MapKVHealth::Restore(saved);
        MapKVCheck(read.source == MapKVHealth::SOURCE_MEMORY, "an unwitnessed key reads from memory");
        MapKVCheck(!read.present && read.value == "", "and is simply absent");
        MapKVCheck(read.blockedReason == "" && read.mismatchReason == "", "with nothing to report");
    }

    [Test]
    void MapKV_NullMapDoesNotCreateMetadata(Tests::Context@ ctx) { MapKV_CheckNullMapDoesNotCreateMetadata(); }

    [Test]
    void MapKV_StringDataMayBeUnaligned(Tests::Context@ ctx) { MapKV_CheckStringDataMayBeUnaligned(); }

    [Test]
    void MapKV_RejectsInvalidPointers(Tests::Context@ ctx) { MapKV_CheckRejectsInvalidPointers(); }

    [Test]
    void MapKV_CompoundTypeIdGate(Tests::Context@ ctx) { MapKV_CheckCompoundTypeIdGate(); }

    [Test]
    void MapKV_ArrayPairsRejected(Tests::Context@ ctx) { MapKV_CheckArrayPairsRejected(); }

    [Test]
    void MapKV_BoundsSafeStringRead(Tests::Context@ ctx) { MapKV_CheckBoundsSafeStringRead(); }

    [Test]
    void MapKV_HealthUnverifiedUntilObservation(Tests::Context@ ctx) { MapKV_CheckHealthUnverifiedUntilObservation(); }

    [Test]
    void MapKV_HealthyWhenObservationsMatch(Tests::Context@ ctx) { MapKV_CheckHealthyWhenObservationsMatch(); }

    [Test]
    void MapKV_BrokenOnDrift(Tests::Context@ ctx) { MapKV_CheckBrokenOnDrift(); }

    [Test]
    void MapKV_ObservationsArePerMap(Tests::Context@ ctx) { MapKV_CheckObservationsArePerMap(); }

    [Test]
    void MapKV_EchoVerifiesMemory(Tests::Context@ ctx) { MapKV_CheckEchoVerifiesMemory(); }

    [Test]
    void MapKV_EchoMismatchServesCache(Tests::Context@ ctx) { MapKV_CheckEchoMismatchServesCache(); }

    [Test]
    void MapKV_LargeEchoComparesLengthOnlyForAscii(Tests::Context@ ctx) { MapKV_CheckLargeEchoComparesLengthOnlyForAscii(); }

    [Test]
    void MapKV_EchoCacheInvalidatedOnMapChange(Tests::Context@ ctx) { MapKV_CheckEchoCacheInvalidatedOnMapChange(); }

    [Test]
    void MapKV_BrokenReaderBlocksWithoutCache(Tests::Context@ ctx) { MapKV_CheckBrokenReaderBlocksWithoutCache(); }

    [Test]
    void MapKV_HealthyReaderNeedsNoCache(Tests::Context@ ctx) { MapKV_CheckHealthyReaderNeedsNoCache(); }
}

Tester@ Test_MapKV = Tester("MapKV", generateMapKVTests());

TestCase@[]@ generateMapKVTests() {
    TestCase@[]@ ret = {};
    ret.InsertLast(TestCase("null map creates no metadata", Tests::MapKV_CheckNullMapDoesNotCreateMetadata));
    ret.InsertLast(TestCase("string data may be unaligned", Tests::MapKV_CheckStringDataMayBeUnaligned));
    ret.InsertLast(TestCase("invalid pointers rejected", Tests::MapKV_CheckRejectsInvalidPointers));
    ret.InsertLast(TestCase("compound type id gate", Tests::MapKV_CheckCompoundTypeIdGate));
    ret.InsertLast(TestCase("array pairs rejected", Tests::MapKV_CheckArrayPairsRejected));
    ret.InsertLast(TestCase("bounds-safe string read", Tests::MapKV_CheckBoundsSafeStringRead));
    ret.InsertLast(TestCase("health unverified until observation", Tests::MapKV_CheckHealthUnverifiedUntilObservation));
    ret.InsertLast(TestCase("healthy when observations match", Tests::MapKV_CheckHealthyWhenObservationsMatch));
    ret.InsertLast(TestCase("broken on drift", Tests::MapKV_CheckBrokenOnDrift));
    ret.InsertLast(TestCase("observations are per map", Tests::MapKV_CheckObservationsArePerMap));
    ret.InsertLast(TestCase("echo verifies memory", Tests::MapKV_CheckEchoVerifiesMemory));
    ret.InsertLast(TestCase("echo mismatch serves cache", Tests::MapKV_CheckEchoMismatchServesCache));
    ret.InsertLast(TestCase("large echo compares length only for ascii", Tests::MapKV_CheckLargeEchoComparesLengthOnlyForAscii));
    ret.InsertLast(TestCase("echo cache invalidated on map change", Tests::MapKV_CheckEchoCacheInvalidatedOnMapChange));
    ret.InsertLast(TestCase("broken reader blocks without cache", Tests::MapKV_CheckBrokenReaderBlocksWithoutCache));
    ret.InsertLast(TestCase("healthy reader needs no cache", Tests::MapKV_CheckHealthyReaderNeedsNoCache));
    return ret;
}
#endif
