namespace Editor {
    // CMwId_ResolveCString: AND EDX,0x3FFFFFFF / LEA R8,[g_CMwId_HashTables] / index decode.
    // research/2026-08-18-MwIds.md — 1 hit on this build (0x1402D47F0).
    const string Pattern_CMwId_HashTables =
        "81 E2 FF FF FF 3F 4C 8D 05 ?? ?? ?? ?? 8B C2 0F B7 CA 48 C1 E8 10";

    const uint16 O_CMwId_StringBlob = 0x10;      // HashTables - 0x10
    const uint16 O_CMwId_HashTableCount = 0x200; // 32-slot static array

    uint64 Ptr_CMwId_HashTablesCode = 0;
    uint64 Ptr_CMwId_HashTables = 0;

    void CheckInitCMwIdTables() {
        if (Ptr_CMwId_HashTables != 0) return;
        Ptr_CMwId_HashTablesCode = Dev::FindPattern(Pattern_CMwId_HashTables);
        if (Ptr_CMwId_HashTablesCode == 0) {
            trace("Could not find CMwId hash tables pattern!");
            return;
        }
        // LEA R8,[rip+disp32] at +6; disp32 at +9; RIP after 7-byte LEA is +13
        uint64 tables = Ptr_CMwId_HashTablesCode + 13 + uint64(int64(Dev::ReadInt32(Ptr_CMwId_HashTablesCode + 9)));
        if (tables <= Dev::BaseAddress() || tables >= BASE_ADDR_END) {
            trace("CMwId hash tables pointer out of range: " + Text::FormatPointer(tables));
            return;
        }
        auto slots0 = Dev::ReadUInt64(tables);
        auto buckets0 = Dev::ReadUInt32(tables + 8);
        auto nTables = Dev::ReadUInt32(tables + O_CMwId_HashTableCount);
        if (slots0 == 0 || buckets0 == 0 || buckets0 > 1000000 || nTables == 0 || nTables > 32) {
            trace("CMwId hash tables look invalid at " + Text::FormatPointer(tables)
                + " slots0=" + Text::FormatPointer(slots0)
                + " buckets0=" + buckets0
                + " nTables=" + nTables);
            return;
        }
        Ptr_CMwId_HashTables = tables;
        dev_trace("Found CMwId hash tables at " + Text::FormatPointer(Ptr_CMwId_HashTables)
            + " nTables=" + nTables + " buckets0=" + buckets0);
    }

    uint64 FindCMwIdHashTables() {
        CheckInitCMwIdTables();
        return Ptr_CMwId_HashTables;
    }

    uint64 get_CMwIdHashTables() {
        return FindCMwIdHashTables();
    }

    uint64 get_CMwIdStringBlob() {
        auto tables = FindCMwIdHashTables();
        if (tables == 0) return 0;
        return tables - O_CMwId_StringBlob;
    }

    uint get_CMwIdHashTableCount() {
        auto tables = FindCMwIdHashTables();
        if (tables == 0) return 0;
        return Dev::ReadUInt32(tables + O_CMwId_HashTableCount);
    }

    bool MwIdIsInterned(uint id) {
        if ((id & 0xC0000000) != 0x40000000) return false;
        auto tables = FindCMwIdHashTables();
        if (tables == 0) return false;
        uint payload = id & 0x3FFFFFFF;
        uint tableIx = payload >> 16;
        uint slot = payload & 0xFFFF;
        uint nTables = Dev::ReadUInt32(tables + O_CMwId_HashTableCount);
        if (tableIx >= nTables) return false;
        auto table = tables + uint64(tableIx) * 16;
        auto slots = Dev::ReadUInt64(table);
        uint buckets = Dev::ReadUInt32(table + 8);
        if (slots == 0 || slot >= buckets) return false;
        return Dev::ReadUInt32(slots + uint64(slot) * 4) != 0xFFFFFFFF;
    }

    bool MwIdIsInterned(const MwId &in id) {
        return MwIdIsInterned(id.Value);
    }

    bool MwIdIsDefined(uint id) {
        uint tag = id & 0xC0000000;
        if (tag == 0) return true;
        if (tag == 0x40000000) return MwIdIsInterned(id);
        return false;
    }

    bool MwIdIsDefined(const MwId &in id) {
        return MwIdIsDefined(id.Value);
    }

    // GetName / IdName / GetMwIdName crash Openplanet on a tag-01 id whose intern
    // slot is empty (e.g. 0x400249b5). Only stringify defined ids.
    string MwIdNameSafe(uint id) {
        if (!MwIdIsDefined(id)) return Text::Format("0x%08x", id);
        MwId tmp = MwId(id);
        return tmp.GetName();
    }

    string MwIdNameSafe(const MwId &in id) {
        return MwIdNameSafe(id.Value);
    }
}
