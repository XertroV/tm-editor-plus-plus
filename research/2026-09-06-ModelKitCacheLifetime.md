# ModelKit cache lifetime and gender caching

Follow-up to [pilot gender research](2026-09-03-CharacterPilotGender.md).
Verified 2026-09-06 against Trackmania.exe native decompiles in Ghidra;
addresses below use image base 0x140000000.

## Native ownership evidence

| Function | Evidence |
| --- | --- |
| 0x14059DF60 NPlugVehicleVis_SharedDataPackCacheGet | Lazily loads DB, searches global registry by DB pointer; increments an existing cache's registry reference count or creates cache with refs=1. |
| 0x14059E430 NPlugModelKit_CreateCache | Cache retains DB through its CMwNod reference count. |
| 0x14059E010 NPlugModelKit_ReleaseSharedCache | Decrements registry references; at zero destroys cache and removes registry row. |
| 0x14059E500 NPlugModelKit_DestroyCache | Releases DB reference and frees the 0x58-byte cache. Other owners may retain the DB. |
| 0x1405D5EB0 CPlugCharVisModel_Destruct | Releases entry handle at model +0xF28, releases shared cache at +0xF20, then zeroes cache pointer. |
| 0x1405A12A0 NPlugModelKit_CacheRegistryRemoveSwap | Removes a registry row by moving the last row into its slot; row indices/addresses are not stable identities. |

The registry is process-global, but its caches are reference-counted, not
immortal. There is no inherent map-only scope or requirement to decode the
mapping on every map entry if the relevant DB/cache remains alive. There is
also no guarantee of cache residency at startup or in every main-menu state.
Acquire mappings lazily from the relevant loaded model. Broad map teardown and
live main-menu residency were not tested in this follow-up.

The release, destroy, CharVisModel destructor, and remove-swap functions were
renamed/plate-commented, and save_all_programs succeeded (one saved, no errors).

## The gender byte

The byte is not a direct CharVis field. It is an option-value index in the
cache entry's FullOptionVals signature:

```text
CharVis +8 -> model
model +F20/+F28 -> cache / entry handle
cache handle map -> dense entry
entry +20 -> FullOptionVals
FullOptionVals[genderOptionIndex] -> value index in DB.Options[i].Vals
```

For the observed Stadium pilot DB, i=0, and values 0/1 mean Male/Female.
Neither the entry handle nor arbitrary signature indices are universal gender
enums. Caching the DB mapping eliminates string parsing, not the pointer walk:
from CharVis, the minimal walk still needs about eight dependent reads including
the final byte, before DB identity and validity checks.

Copy option/value mappings into plugin-owned data rather than keeping raw
registry-row, DB, or signature addresses indefinitely. A DB pointer alone is
not an eternal identity after destruction/reallocation.

For the user's stated scope (skin fixed once loaded for a live CharVis), a
successfully resolved gender can instead be memoized for that CharVis lifetime.
Discard per-character results on removal/recreation and scene teardown; handle
pointer/entity-ID reuse. Retry temporary Unknown results while loading. This
is a proposed optimization, not an implemented change to tm-char-vis.
