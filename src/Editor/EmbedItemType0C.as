// CollectAndEmbedItems treats ItemTypeE 0x0C (soccer-ball / movable DynaObject)
// as "unhandled type" and refuses to embed. Mask at 0x140b90484 is 0x683e
// (bits 1-5, 0xB, 0xD, 0xE). OR bit 12 → 0x783e.
//
// Site unique 2026-08-27: 1 Ghidra hit (bare 0x683e has a second unrelated hit
// in FUN_1413eaed0 — do not use the imm alone).
namespace Editor {
    namespace EmbedItemType0C {
        const uint VanillaMask = 0x683e;
        const uint WithType0C = 0x783e;

        // MOV EAX,[R15+0xF0]; XOR EBX,EBX; MOV [RBP+disp8],EBX; CMP EAX,0xE; JA; MOV ECX,0x683e
        const string Pattern =
            "41 8B 87 F0 00 00 00 33 DB 89 5D ?? 83 F8 0E 77 ?? B9 3E 68 00 00";

        MemPatcher@ Patch = MemPatcher(
            "EmbedItemType0C",
            Pattern,
            {17},
            {"B9 3E 78 00 00"},
            {"B9 3E 68 00 00"}
        );

        bool get_IsActive() { return Patch.IsApplied; }
        void set_IsActive(bool value) { Patch.IsApplied = value; }
    }
}
