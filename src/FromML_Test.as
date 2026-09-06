#if DEV
namespace Tests {
    [Test]
    void MapKV_PrefixAndInvalidKeys(Tests::Context@ ctx) {
        MapKVCheck((MapKV::NormalizeKey("Plugin.value-1")) == ("_EKV_Plugin.value-1"), "values match");
        MapKVCheck((MapKV::NormalizeKey("_EKV_Plugin:value")) == ("_EKV_Plugin:value"), "values match");
        string[] invalid = {"", "_EKV_", "bad key", "bad\"key", "bad\\key", "/*EVENTS*/"};
        for (uint i = 0; i < invalid.Length; i++) {
            bool rejected = false;
            try { MapKV::NormalizeKey(invalid[i]); } catch { rejected = true; }
            MapKVCheck(rejected, "reject invalid key: " + invalid[i]);
        }
    }

    [Test]
    void MapKV_WholeRawValueRoundTrip(Tests::Context@ ctx) {
        string raw = "quotes \"\\\n\r\t Unicode: café 😀";
        // Larger than the old 16 KiB chunks; still exactly one complete message.
        string unit = raw;
        for (uint i = 1; i < 1024; i++) raw += unit;
        auto message = ToML::MakeMapKVMessage("Plugin.spec", raw);
        auto wire = Json::Parse(message.ToMLEventString());
        MapKVCheck((wire.Length) == (uint(3)), "one type, one key, one whole value");
        MapKVCheck((string(wire[0])) == ("SetMapKV"), "values match");
        MapKVCheck((string(wire[1])) == ("_EKV_Plugin.spec"), "values match");
        MapKVCheck((string(wire[2])) == (raw), "values match");
        MapKVCheck(!(message.ToMLEventString().Contains("/*EVENTS*/")), "payload cannot corrupt splice markers");
        MapKVCheck(!(message.ToMLEventString().Contains("-->")), "payload cannot close the XML comment");
        auto delimiters = ToML::MakeMapKVMessage("Plugin.spec", "<!-- --> </script> /*EVENTS*/ /*TIMENOW*/");
        MapKVCheck(!delimiters.ToMLEventString().Contains("-->"), "XML comment terminator must be split");
        MapKVCheck(!delimiters.ToMLEventString().Contains("/*EVENTS*/"), "event splice marker must be split");
        MapKVCheck(!delimiters.ToMLEventString().Contains("/*TIMENOW*/"), "nonce splice marker must be split");
        bool rejected = false;
        try { ToML::MakeMapKVMessage("Plugin.spec", Text::DecodeBase64("AAE=")); }
        catch { rejected = true; }
        MapKVCheck(rejected, "NUL and unsupported controls are rejected before enqueue");
        auto empty = ToML::MakeMapKVMessage("Plugin.spec", "");
        MapKVCheck((empty.data[1]) == (""), "empty value is a write");
    }

    [Test]
    void MapKV_CoalescesOnlyMatchingKey(Tests::Context@ ctx) {
        ML_Event@[] messages;
        auto other = ML_Event("ResyncPlease", {});
        messages.InsertLast(other);
        ToML::CoalesceMapKVMessage(messages, ToML::MakeMapKVMessage("Plugin.a", "old"));
        ToML::CoalesceMapKVMessage(messages, ToML::MakeMapKVMessage("Plugin.b", "keep"));
        ToML::CoalesceMapKVMessage(messages, ToML::MakeMapKVMessage("_EKV_Plugin.a", "new"));
        MapKVCheck((messages.Length) == (uint(3)), "values match");
        MapKVCheck(messages[0] is other, "unrelated message retained");
        MapKVCheck((messages[1].data[0]) == ("_EKV_Plugin.b"), "other key retained");
        MapKVCheck((messages[1].data[1]) == ("keep"), "values match");
        MapKVCheck((messages[2].data[1]) == ("new"), "latest value wins");
    }
}
#endif
