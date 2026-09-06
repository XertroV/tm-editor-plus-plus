#if DEV
// DEV-only cross-check of a compound ScriptTraits type id against the live
// descriptor table. This is a diagnostic, never a production gate: reaching the
// table needs Dev::FindPattern over the game image, and any Trackmania update
// can move or reshape that code, which would turn a working metadata reader
// into one that refuses every read. MapKV's production gate is structural
// instead (CompoundTypeIdIsPlausible plus the pairs-buffer check in ReadPair),
// and this file exists to confirm that gate against ground truth while
// developing, surfaced in the DEV Map Key Values tab.
//
// ScriptTraits compound type IDs contain a session-specific descriptor index.
// Trackmania.exe: GetType 0x1408b52a0, GetDescriptorByIndex 0x1408b4e10,
// InternArrayType 0x1408b52c0. See tm-control-mcp docs/editor-script-plugins.md.
namespace MapKV {
    uint64 g_TypeRegistryGlobal = 0;

    const uint DESCRIPTOR_STRIDE = 0x30;
    const uint DESCRIPTORS_PER_BLOCK = 4096;
    const uint MAX_DESCRIPTOR_BLOCKS = 32768;

    uint64 TypeRegistryGlobal() {
        if (g_TypeRegistryGlobal != 0) return g_TypeRegistryGlobal;
        // FormatTypeName's array branch. Unique across the complete mapped live
        // PE on 2026-09-06 (one hit at base+0x8b41df). RIP/call/branch offsets
        // wildcarded; resolves the registry global without a fixed image RVA.
        const string pattern = "4C 8B 0D ?? ?? ?? ?? 8B D3 49 8B C9 E8 ?? ?? ?? ?? 83 78 0C 00 0F 85 ?? ?? ?? ?? 85 F6 74 ?? C7 45 ?? 06 00 00 00";
        uint64 site = Dev::FindPattern(pattern);
        if (site == 0) throw("ScriptTraits type registry pattern unavailable");
        uint64 address = uint64(int64(site + 7) + int64(Dev::SafeReadInt32(site + 3)));
        if (!PointerValid(address)) throw("Invalid ScriptTraits registry global address");
        g_TypeRegistryGlobal = address;
        return address;
    }

    bool DevDescriptorIsTextDictionary(uint typeId) {
        if (!CompoundTypeIdIsPlausible(typeId)) return false;
        uint index = typeId >> TYPE_INDEX_SHIFT;
        uint64 registry = Dev::SafeReadUInt64(TypeRegistryGlobal());
        if (!PointerValid(registry)) throw("Invalid ScriptTraits registry pointer");
        uint64 blocks = Dev::SafeReadUInt64(registry);
        uint count = Dev::SafeReadUInt32(registry + 8);
        uint capacity = Dev::SafeReadUInt32(registry + 12);
        if (!PointerValid(blocks) || count == 0 || count > capacity || count > MAX_DESCRIPTOR_BLOCKS)
            throw("Invalid ScriptTraits descriptor block vector");
        uint blockIndex = index / DESCRIPTORS_PER_BLOCK;
        if (blockIndex >= count) return false;
        uint64 block = Dev::SafeReadUInt64(blocks + uint64(blockIndex) * 8);
        if (!PointerValid(block)) throw("Invalid ScriptTraits descriptor block");
        uint used = Dev::SafeReadUInt32(block);
        uint slot = index % DESCRIPTORS_PER_BLOCK;
        if (used > DESCRIPTORS_PER_BLOCK) throw("Invalid ScriptTraits descriptor count");
        if (slot >= used) return false;
        uint64 descriptor = block + 8 + uint64(slot) * DESCRIPTOR_STRIDE;
        // Both children must be the builtin Text type, not merely look like
        // string storage. This rejects arrays and differently typed dictionaries.
        return Dev::SafeReadUInt32(descriptor) == TYPE_KIND_COMPOUND
            && Dev::SafeReadUInt32(descriptor + 8) == TYPE_ID_TEXT
            && Dev::SafeReadUInt32(descriptor + 12) == TYPE_ID_TEXT;
    }

    // "" when the live descriptor confirms Text[Text], otherwise a readable
    // reason (including the reason the check itself could not run).
    string DevDescribeDictionaryType(CGameCtnChallenge@ map) {
        try {
            uint64 row = FindTrait(map, DICTIONARY_TRAIT);
            if (row == 0) return "no _EKV_ trait on this map";
            uint typeId = Dev::SafeReadUInt32(row + O_ROW_TYPE);
            if (DevDescriptorIsTextDictionary(typeId)) return "";
            return "type id 0x" + Text::Format("%x", typeId) + " is not Text[Text] in the descriptor table";
        } catch {
            return getExceptionInfo();
        }
    }
}
#endif
