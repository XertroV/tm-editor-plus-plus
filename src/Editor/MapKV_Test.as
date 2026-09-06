#if DEV
namespace Tests {
    // Throw-style, as in tm-char-vis: executable both by [Test] and an isolated
    // smoke driver passing null; no game/map mutation is needed.
    void MapKVCheck(bool ok, const string &in message) {
        if (!ok) throw(message);
    }

    [Test]
    void MapKV_NullMapDoesNotCreateMetadata(Tests::Context@ ctx) {
        MapKVCheck(MapKV::ListKeys(null).Length == 0, "absent map has no keys");
        string value = "old";
        MapKVCheck(!(MapKV::TryReadValue(null, "_EKV_missing", value)), "expected false");
        MapKVCheck((value) == (""), "values match");
        value = "old";
        MapKVCheck(!(MapKV::TryReadScalar(null, "MissingTrait", value)), "expected false");
        MapKVCheck((value) == (""), "values match");
    }

    [Test]
    void MapKV_StringDataMayBeUnaligned(Tests::Context@ ctx) {
        MapKVCheck(MapKV::BytePointerValid(0x0000000317876E21), "observed heap string address is valid");
        MapKVCheck(!MapKV::PointerValid(0x0000000317876E21), "metadata rows still require alignment");
        MapKVCheck(!MapKV::BytePointerValid(0), "null byte pointer rejected");
    }

    [Test]
    void MapKV_RejectsInvalidPointers(Tests::Context@ ctx) {
        MapKVCheck(!(MapKV::PointerValid(0)), "expected false");
        MapKVCheck(!(MapKV::PointerValid(0x10001)), "expected false");
        MapKVCheck(!(MapKV::PointerValid(0x0000800000000000)), "expected false");
    }
}
#endif
