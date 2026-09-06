// Generic, read-only access to map metadata. Layout/SSO handling follows the
// public-domain tm-metadata-gateway/src/MetadataReader.as and research/ScriptMetadata.txt.
// No retained pointers: reacquire the current metadata buffer on every read.
//
// Openplanet exposes no read API for CScriptTraitsMetadata, so every read here
// is a memory walk over hard-coded offsets. Two things keep that honest:
// structural validation of every buffer and pointer before it is followed
// (below), and MapKVHealth's fail-closed supervision of the walk as a whole.
namespace MapKV {
    const string PREFIX = "_EKV_";
    // The single ManiaScript dictionary trait every key lives in.
    const string DICTIONARY_TRAIT = "_EKV_";
    const uint MAX_VALUE_BYTES = 8 * 1024 * 1024;
    const uint MAX_ENTRIES = 65536;

    // A ScriptTraits type id packs the kind in its low 5 bits and an index into
    // the session's interned descriptor table above them. Kind 7 covers every
    // compound type, arrays and dictionaries alike (observed live on
    // 2026-09-06: Text[] = 0x227, Text[Text] = 0x467), and a real compound type
    // always carries a nonzero interned index. That is the whole of what the id
    // itself is asked to prove here; separating an array from a dictionary is
    // done structurally in ReadPair, because the id cannot
    // do it. MapKV_Types_Dev.as keeps the descriptor-table cross-check as a DEV
    // diagnostic: it depends on a byte pattern that any game update can break,
    // which is not something a production read path should rest on.
    const uint TYPE_KIND_MASK = 0x1F;
    const uint TYPE_KIND_COMPOUND = 7;
    const uint TYPE_INDEX_SHIFT = 5;

    // Scalar type ids, whole ids rather than kind bits: a scalar interns no
    // descriptor, so its index is zero and the id equals its kind. They are
    // named separately from the TYPE_KIND_ constants above because the two are
    // only numerically interchangeable for scalars, and comparing a full id
    // against a kind is exactly the confusion that hides a compound type.
    const uint TYPE_ID_BOOLEAN = 1;
    const uint TYPE_ID_INTEGER = 2;
    const uint TYPE_ID_REAL = 3;
    const uint TYPE_ID_TEXT = 5;
    const uint TYPE_ID_VEC2 = 9;
    const uint TYPE_ID_VEC3 = 10;
    const uint TYPE_ID_INT2 = 14;
    const uint TYPE_ID_INT3 = 15;

    // Metadata row and dictionary-pair layout (research/ScriptMetadata.txt).
    const uint64 ROW_STRIDE = 0x88;
    const uint64 PAIR_STRIDE = 0x10;
    const uint O_ROW_TYPE = 0x10;
    const uint O_ROW_SCALAR_VALUE = 0x18;
    const uint O_ROW_SCALAR_STRING = 0x28;
    const uint O_ROW_PAIRS_PTR = 0x68;
    const uint O_ROW_PAIRS_LEN = 0x70;
    const uint O_ROW_PAIRS_CAP = 0x74;
    const uint O_META_BUFFER_PTR = 0x28;
    const uint O_META_BUFFER_LEN = 0x30;
    const uint O_META_BUFFER_CAP = 0x34;
    // Strings are SSO: flag bit 0 at +0xB selects heap storage, length at +0xC.
    const uint O_STRING_FLAGS = 0xB;
    const uint O_STRING_LENGTH = 0xC;
    const uint MAX_INLINE_STRING_BYTES = 11;
    // Inner structs place their string 0x10 bytes in.
    const uint64 O_PAIR_STRING = 0x10;

    string NormalizeKey(const string &in key) {
        string suffix = key.StartsWith(PREFIX) ? key.SubStr(PREFIX.Length) : key;
        if (suffix.Length == 0) throw("Map metadata key must not be empty");
        for (uint i = 0; i < suffix.Length; i++) {
            uint8 c = suffix[i];
            if (!((c >= 48 && c <= 57) || (c >= 65 && c <= 90)
                || (c >= 97 && c <= 122) || c == 95 || c == 45 || c == 46 || c == 58))
                throw("Map metadata keys allow only letters, digits, _, -, . and :");
        }
        return PREFIX + suffix;
    }

    bool BytePointerValid(uint64 ptr) {
        return ptr > 0xFFFF && ptr < 0x0000800000000000;
    }

    bool PointerValid(uint64 ptr) {
        return BytePointerValid(ptr) && ptr % 8 == 0;
    }

    // Structural gate for a compound trait's type id: the right kind, and an
    // interned descriptor index that exists. Deliberately weak on its own; see
    // the TYPE_* comment above.
    bool CompoundTypeIdIsPlausible(uint typeId) {
        return (typeId & TYPE_KIND_MASK) == TYPE_KIND_COMPOUND
            && (typeId >> TYPE_INDEX_SHIFT) != 0;
    }

    // Dev::SafeReadCString(ptr, length) is the bounds-safe primitive here.
    // Openplanet's Dev:: readers split three ways, and only this one does what
    // a metadata value needs. Characterised live against Trackmania with
    // Openplanet 1.29.14 on 2026-09-06, by an isolated plugin writing
    // "hello\0A" into its own Dev::Allocate buffer:
    //
    //   Dev::Read / Dev::SafeRead(ptr, n) return a *hex pattern* string, the
    //     inverse of Dev::Write(ptr, pattern): 7 bytes came back as the
    //     20-character text "68 65 6C 6C 6F 00 41". Not a byte reader at all.
    //   Dev::ReadCString(ptr, n) returns the raw n bytes but dereferences
    //     blindly, so a bad address takes the process down.
    //   Dev::SafeReadCString(ptr, n) returns the same raw n bytes and raises a
    //     catchable AngelScript exception ("Unable to read memory") instead of
    //     faulting.
    //
    // Three properties of SafeReadCString were confirmed in that run and are
    // what the code below relies on. It does not stop at a NUL: the 7-byte read
    // came back 7 bytes long with the NUL at index 5 intact, so a successful
    // read is exactly `length` bytes and the exact length is a usable
    // postcondition. It validates the whole range, not just its start: a 0x40
    // byte read starting 0x10 before the end of a 0x1000 byte allocation threw,
    // while the allocation's own last byte read fine, so no page-boundary
    // probing is needed here. And it is not slow enough to matter: 1 MiB read
    // in 2 ms, against the documented warning of "significant overhead".
    string ReadBytes(uint64 ptr, uint len) {
        if (len == 0) return "";
        if (len > MAX_VALUE_BYTES) throw("Metadata string is too large");
        string data = Dev::SafeReadCString(ptr, len);
        if (uint(data.Length) != len)
            throw("Metadata string read returned " + data.Length + " of " + len + " bytes");
        return data;
    }

    string ReadString(uint64 ptr) {
        if (!PointerValid(ptr)) throw("Invalid metadata string pointer");
        uint len = Dev::SafeReadUInt32(ptr + O_STRING_LENGTH);
        if (len == 0) return "";
        if (len > MAX_VALUE_BYTES) throw("Metadata string is too large");
        if ((Dev::SafeReadUInt8(ptr + O_STRING_FLAGS) & 1) != 0) {
            uint64 data = Dev::SafeReadUInt64(ptr);
            // Character data is byte-aligned, unlike metadata rows. Live map
            // names can start at addresses ending in 0x21 (SSO heap storage).
            if (!BytePointerValid(data)) throw("Invalid metadata string data");
            return ReadBytes(data, len);
        }
        if (len > MAX_INLINE_STRING_BYTES) throw("Invalid inline metadata string length");
        return ReadBytes(ptr, len);
    }

    uint64 FindTrait(CGameCtnChallenge@ map, const string &in key) {
        return FindTraitInMetadata(map is null ? null : map.ScriptMetadata, key);
    }

    uint64 FindTraitInMetadata(CScriptTraitsMetadata@ meta, const string &in key) {
        if (meta is null) return 0;
        uint len = Dev::GetOffsetUint32(meta, O_META_BUFFER_LEN);
        uint cap = Dev::GetOffsetUint32(meta, O_META_BUFFER_CAP);
        if (len == 0) return 0;
        if (len > cap || cap > MAX_ENTRIES) throw("Invalid map metadata buffer");
        uint64 ptr = Dev::GetOffsetUint64(meta, O_META_BUFFER_PTR);
        if (!PointerValid(ptr)) throw("Invalid map metadata pointer");
        for (uint i = 0; i < len; i++) {
            uint64 row = ptr + uint64(i) * ROW_STRIDE;
            if (ReadString(row) == key) return row;
        }
        return 0;
    }

    // Arrays and dictionaries share compound kind 7, so the type id cannot tell
    // them apart. research/ScriptMetadata.txt records where they do differ: an
    // ordinary Text[] leaves the first slot of every 0x10-byte pair null and
    // keeps its element in the second, while a Text[Text] dictionary stores a
    // real key pointer in the first slot. Rejecting a null first slot therefore
    // rejects an array, with a message that says so.
    void ReadPair(uint64 pairs, uint index, uint64 &out keyPtr, uint64 &out valuePtr) {
        uint64 pair = pairs + uint64(index) * PAIR_STRIDE;
        keyPtr = Dev::SafeReadUInt64(pair);
        valuePtr = Dev::SafeReadUInt64(pair + 8);
        if (keyPtr == 0)
            throw("_EKV_ metadata is an array, not a Text[Text] dictionary");
        if (!PointerValid(keyPtr) || !PointerValid(valuePtr))
            throw("Invalid _EKV_ entry pointer");
    }

    uint64 DictionaryPairs(CScriptTraitsMetadata@ meta, uint &out len) {
        len = 0;
        uint64 row = FindTraitInMetadata(meta, DICTIONARY_TRAIT);
        if (row == 0) return 0;
        uint typeId = Dev::SafeReadUInt32(row + O_ROW_TYPE);
        if (!CompoundTypeIdIsPlausible(typeId))
            throw("_EKV_ metadata is not a Text[Text] dictionary (type id 0x"
                + Text::Format("%x", typeId) + ")");
        len = Dev::SafeReadUInt32(row + O_ROW_PAIRS_LEN);
        uint cap = Dev::SafeReadUInt32(row + O_ROW_PAIRS_CAP);
        if (len == 0) return 0;
        if (len > cap || cap > MAX_ENTRIES) throw("Invalid _EKV_ dictionary buffer");
        uint64 pairs = Dev::SafeReadUInt64(row + O_ROW_PAIRS_PTR);
        if (!PointerValid(pairs)) throw("Invalid _EKV_ dictionary pointer");
        // One pair settles array-versus-dictionary; every pair is rechecked as
        // it is actually read below.
        uint64 firstKey, firstValue;
        ReadPair(pairs, 0, firstKey, firstValue);
        return pairs;
    }

    string[]@ ListKeys(CGameCtnChallenge@ map) {
        return ListMetadataKeys(map is null ? null : map.ScriptMetadata);
    }

    string[]@ ListMetadataKeys(CScriptTraitsMetadata@ meta) {
        string[] keys;
        uint len;
        uint64 pairs = DictionaryPairs(meta, len);
        for (uint i = 0; i < len; i++) {
            uint64 keyPtr, valuePtr;
            ReadPair(pairs, i, keyPtr, valuePtr);
            keys.InsertLast(ReadString(keyPtr + O_PAIR_STRING));
        }
        keys.SortAsc();
        return keys;
    }

    bool TryReadValue(CGameCtnChallenge@ map, const string &in key, string &out value) {
        return TryReadMetadataValue(map is null ? null : map.ScriptMetadata, key, value);
    }

    bool TryReadMetadataValue(CScriptTraitsMetadata@ meta, const string &in key, string &out value) {
        value = "";
        uint len;
        uint64 pairs = DictionaryPairs(meta, len);
        for (uint i = 0; i < len; i++) {
            uint64 keyPtr, valuePtr;
            ReadPair(pairs, i, keyPtr, valuePtr);
            if (ReadString(keyPtr + O_PAIR_STRING) != key) continue;
            value = ReadString(valuePtr + O_PAIR_STRING);
            return true;
        }
        return false;
    }

    bool TryReadScalar(CGameCtnChallenge@ map, const string &in key, string &out value) {
        value = "";
        uint64 row = FindTrait(map, key);
        if (row == 0) return false;
        uint type = Dev::SafeReadUInt32(row + O_ROW_TYPE);
        uint64 ptr = row + O_ROW_SCALAR_VALUE;
        switch (type) {
            case TYPE_ID_BOOLEAN: value = tostring(Dev::SafeReadInt32(ptr) != 0); break;
            case TYPE_ID_INTEGER: value = tostring(Dev::SafeReadInt32(ptr)); break;
            case TYPE_ID_REAL: value = tostring(Dev::SafeReadFloat(ptr)); break;
            case TYPE_ID_TEXT: value = ReadString(row + O_ROW_SCALAR_STRING); break;
            case TYPE_ID_VEC2: value = Dev::SafeReadVec2(ptr).ToString(); break;
            case TYPE_ID_VEC3: value = Dev::SafeReadVec3(ptr).ToString(); break;
            case TYPE_ID_INT2: value = int2(Dev::SafeReadInt32(ptr), Dev::SafeReadInt32(ptr + 4)).ToString(); break;
            case TYPE_ID_INT3: value = int3(Dev::SafeReadInt32(ptr), Dev::SafeReadInt32(ptr + 4), Dev::SafeReadInt32(ptr + 8)).ToString(); break;
            default: return false;
        }
        return true;
    }

    CGameCtnChallenge@ CurrentMap() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor is null ? GetApp().RootMap : editor.Challenge;
    }

    // Fail closed: a walk that has been shown to disagree with the editor
    // plugin must refuse to answer rather than hand back a plausible wrong
    // value. Per-key callers consult the echo cache before reaching here.
    void RequireReaderUsable(CGameCtnChallenge@ map) {
        string reason;
        if (MapKVHealth::Evaluate(map, reason) == MapKVHealth::STATE_BROKEN)
            throw(MapKVHealth::BLOCKED_PREFIX + reason);
    }

    // Seam for the dictionary read, mirroring MapKVHealth::TraitSource, so the
    // guarded-read path below can be exercised without a live map.
    class ValueSource {
        bool TryRead(CGameCtnChallenge@ map, const string &in normalizedKey, string &out value) {
            return TryReadValue(map, normalizedKey, value);
        }
    }

    ValueSource@ g_ValueSource = ValueSource();

    void SetValueSource(ValueSource@ source) {
        @g_ValueSource = source is null ? ValueSource() : source;
    }

    // The single place that decides where one key's value comes from. The
    // decision itself lives in MapKVHealth::ResolveRead, which touches no
    // memory; this only supplies it with the health verdict and the memory
    // read, then applies any mismatch it reports.
    MapKVHealth::KVRead@ ResolveKey(CGameCtnChallenge@ map, const string &in normalizedKey) {
        return ResolveKeyIn(MapKVHealth::ScopeFor(map), map, normalizedKey);
    }

    MapKVHealth::KVRead@ ResolveKeyIn(MapKVHealth::Scope@ scope, CGameCtnChallenge@ map,
                                      const string &in normalizedKey) {
        string reason;
        bool usable = MapKVHealth::EvaluateFor(scope, map, reason) != MapKVHealth::STATE_BROKEN;
        bool present = false;
        string value;
        if (usable) {
            // A walk that throws is a fenced reader that has not been told yet.
            // Catching here keeps the echo fallback reachable, which letting the
            // exception escape would not, and records the failure so later reads
            // fail closed for the same reason instead of throwing one at a time.
            try {
                present = g_ValueSource.TryRead(map, normalizedKey, value);
            } catch {
                reason = "reading " + normalizedKey + " threw: " + getExceptionInfo();
                MapKVHealth::MarkBrokenIn(scope, reason);
                usable = false;
                present = false;
                value = "";
            }
        }
        auto read = MapKVHealth::ResolveRead(scope, normalizedKey, usable, reason, present, value);
        if (read.mismatchReason.Length > 0) MapKVHealth::MarkBrokenIn(scope, read.mismatchReason);
        return read;
    }
}

namespace Editor {
    string[]@ Get_Map_KVKeys(CGameCtnChallenge@ map = null) {
        if (map is null) @map = MapKV::CurrentMap();
        MapKV::RequireReaderUsable(map);
        return MapKV::ListKeys(map);
    }

    bool TryGet_Map_KVRaw(const string &in key, string &out value, CGameCtnChallenge@ map = null) {
        value = "";
        string normalized = MapKV::NormalizeKey(key);
        if (map is null) @map = MapKV::CurrentMap();
        auto read = MapKV::ResolveKey(map, normalized);
        if (read.blockedReason.Length > 0) throw(MapKVHealth::BLOCKED_PREFIX + read.blockedReason);
        value = read.value;
        return read.present;
    }

    string Get_Map_KVRaw(const string &in key, CGameCtnChallenge@ map = null) {
        string value;
        TryGet_Map_KVRaw(key, value, map);
        return value;
    }

    string Get_Map_MetadataRaw(const string &in key, CGameCtnChallenge@ map = null) {
        string value;
        TryGet_Map_MetadataRaw(key, value, map);
        return value;
    }

    bool TryGet_Map_MetadataRaw(const string &in key, string &out value, CGameCtnChallenge@ map = null) {
        if (map is null) @map = MapKV::CurrentMap();
        MapKV::RequireReaderUsable(map);
        return MapKV::TryReadScalar(map, key, value);
    }

    // Where a read of this key gets its answer, for a consumer that wants to
    // know how much the value is worth: "memory-verified" (memory agreed with
    // the value the editor plugin reported storing), "memory" (nothing to check
    // it against), "ml-cache" (the memory reader is fenced off and the editor
    // plugin's echo answered instead) or "unavailable" (no map, or nothing
    // trustworthy to answer with). Never throws.
    string Get_Map_KVReadSource(const string &in key) {
        try {
            auto map = MapKV::CurrentMap();
            if (map is null) return "unavailable";
            return MapKV::ResolveKey(map, MapKV::NormalizeKey(key)).source;
        } catch {
            return "unavailable";
        }
    }

    // false once the metadata memory reader has been fenced off for the current
    // map, with `reason` saying what disagreed. A true return with a nonempty
    // reason means the reader is usable but has not yet been able to check
    // itself, because the E++ editor plugin has reported nothing for this map.
    bool Get_Map_KVReaderHealthy(string &out reason) {
        reason = "";
        return MapKVHealth::Evaluate(MapKV::CurrentMap(), reason) != MapKVHealth::STATE_BROKEN;
    }
}
