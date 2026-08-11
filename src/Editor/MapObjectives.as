namespace Editor {
    // TMObjective_NbClones is const on CGameCtnChallengeInfo. Write via offset.
    // Prefer GetOffset(liveNod, member) — class-name lookup can fail for some members.

    int16 g_MapNbClonesRelOff = -1;
    uint16 g_OffMapInfoNbClones = 0xFFFF;
    uint16 g_OffMapAuthorTime = 0xFFFF;
    uint16 g_OffMapNbLaps = 0xFFFF;
    uint16 g_OffMapIsLapRace = 0xFFFF;

    uint16 SafeMemberOff(CMwNod@ nod, const string &in member) {
        if (nod is null) return 0xFFFF;
        try {
            return GetOffset(nod, member);
        } catch {
            return 0xFFFF;
        }
    }

    uint16 SafeClassOff(const string &in cls, const string &in member) {
        try {
            return GetOffset(cls, member);
        } catch {
            return 0xFFFF;
        }
    }

    void ResolveMapObjectiveOffsets(CGameCtnChallenge@ map) {
        // Challenge medals/laps (class lookup usually works for Challenge).
        if (g_OffMapAuthorTime == 0xFFFF)
            g_OffMapAuthorTime = SafeClassOff("CGameCtnChallenge", "TMObjective_AuthorTime");
        if (g_OffMapNbLaps == 0xFFFF)
            g_OffMapNbLaps = SafeClassOff("CGameCtnChallenge", "TMObjective_NbLaps");
        if (g_OffMapIsLapRace == 0xFFFF)
            g_OffMapIsLapRace = SafeClassOff("CGameCtnChallenge", "TMObjective_IsLapRace");

        // MapInfo NbClones: try live nod first, then class.
        if (g_OffMapInfoNbClones == 0xFFFF && map !is null && map.MapInfo !is null) {
            g_OffMapInfoNbClones = SafeMemberOff(map.MapInfo, "TMObjective_NbClones");
        }
        if (g_OffMapInfoNbClones == 0xFFFF)
            g_OffMapInfoNbClones = SafeClassOff("CGameCtnChallengeInfo", "TMObjective_NbClones");

        // Fallback: relative to MapInfo AuthorTime (members are consecutive u32s + bool packing).
        // Layout from OP typedb: Author, Gold, Silver, Bronze, NbLaps, IsLapRace, NbClones
        if (g_OffMapInfoNbClones == 0xFFFF && map !is null && map.MapInfo !is null) {
            uint16 oAT = SafeMemberOff(map.MapInfo, "TMObjective_AuthorTime");
            if (oAT == 0xFFFF) oAT = SafeClassOff("CGameCtnChallengeInfo", "TMObjective_AuthorTime");
            if (oAT != 0xFFFF) {
                // Prefer verifying by reading current API value at candidate offsets.
                uint want = map.MapInfo.TMObjective_NbClones;
                // Candidate: Author + 0x18 (6*4) if all uint, or after IsLapRace packing.
                uint16[] cands = { uint16(oAT + 0x18), uint16(oAT + 0x1C), uint16(oAT + 0x20), uint16(oAT + 0x14) };
                for (uint i = 0; i < cands.Length; i++) {
                    try {
                        uint v = Dev::GetOffsetUint32(map.MapInfo, cands[i]);
                        if (v == want) {
                            g_OffMapInfoNbClones = cands[i];
                            break;
                        }
                    } catch {}
                }
                // If still unknown and want==0, many zeros — use oAT+0x18 as best guess only after
                // we can write-probe safely with try/catch + restore.
                if (g_OffMapInfoNbClones == 0xFFFF && want == 0) {
                    g_OffMapInfoNbClones = uint16(oAT + 0x18);
                }
            }
        }

        dev_trace("MapObjectives resolve: infoNbClones=0x" + Text::Format("%x", g_OffMapInfoNbClones)
            + " chAT=0x" + Text::Format("%x", g_OffMapAuthorTime)
            + " chNbLaps=0x" + Text::Format("%x", g_OffMapNbLaps)
            + " chIsLap=0x" + Text::Format("%x", g_OffMapIsLapRace));
    }

    uint16 get_O_MAP_TMObjective_AuthorTime() {
        if (g_OffMapAuthorTime == 0xFFFF)
            g_OffMapAuthorTime = SafeClassOff("CGameCtnChallenge", "TMObjective_AuthorTime");
        return g_OffMapAuthorTime;
    }

    uint GetMapNbClones(CGameCtnChallenge@ map) {
        if (map is null || map.MapInfo is null) return 0;
        return map.MapInfo.TMObjective_NbClones;
    }

    bool SetMapNbClones(CGameCtnChallenge@ map, uint nbClones) {
        if (map is null || map.MapInfo is null) return false;
        ResolveMapObjectiveOffsets(map);
        if (g_OffMapInfoNbClones == 0xFFFF) {
            warn("SetMapNbClones: could not resolve MapInfo.NbClones offset");
            return false;
        }
        if (nbClones > 64) nbClones = 64;

        auto info = map.MapInfo;
        uint apiBefore = info.TMObjective_NbClones;
        uint memBefore = 0;
        try {
            memBefore = Dev::GetOffsetUint32(info, g_OffMapInfoNbClones);
        } catch {
            warn("SetMapNbClones: read failed: " + getExceptionInfo());
            return false;
        }

        // If API says 0 and mem is non-zero at guessed offset, don't clobber.
        if (apiBefore == 0 && memBefore != 0 && memBefore > 64) {
            // try next candidates relative to this bad guess
            warn("SetMapNbClones: suspected bad offset 0x" + Text::Format("%x", g_OffMapInfoNbClones)
                + " mem=" + memBefore + " — abort");
            g_OffMapInfoNbClones = 0xFFFF;
            return false;
        }
        if (memBefore != apiBefore && !(apiBefore == 0 && memBefore == 0)) {
            warn("SetMapNbClones: offset mismatch api=" + apiBefore + " mem=" + memBefore);
            return false;
        }

        try {
            Dev::SetOffset(info, g_OffMapInfoNbClones, nbClones);
        } catch {
            warn("SetMapNbClones: write failed: " + getExceptionInfo());
            return false;
        }

        uint after = info.TMObjective_NbClones;
        if (after != nbClones) {
            try { after = Dev::GetOffsetUint32(info, g_OffMapInfoNbClones); } catch {}
        }
        // If API didn't update but memory did, still report failure — game may not honor mem-only.
        return after == nbClones;
    }

    uint GetMapNbLaps(CGameCtnChallenge@ map) {
        if (map is null) return 0;
        return map.TMObjective_NbLaps;
    }

    bool GetMapIsLapRace(CGameCtnChallenge@ map) {
        if (map is null) return false;
        return map.TMObjective_IsLapRace;
    }

    bool SetMapNbLaps(CGameCtnChallenge@ map, uint nbLaps) {
        if (map is null) return false;
        ResolveMapObjectiveOffsets(map);
        if (g_OffMapNbLaps == 0xFFFF) return false;
        if (nbLaps < 1) nbLaps = 1;
        if (nbLaps > 99) nbLaps = 99;
        try {
            Dev::SetOffset(map, g_OffMapNbLaps, nbLaps);
        } catch {
            warn("SetMapNbLaps: " + getExceptionInfo());
            return false;
        }
        return map.TMObjective_NbLaps == nbLaps;
    }

    bool SetMapIsLapRace(CGameCtnChallenge@ map, bool isLap) {
        if (map is null) return false;
        ResolveMapObjectiveOffsets(map);
        if (g_OffMapIsLapRace == 0xFFFF) return false;
        try {
            Dev::SetOffset(map, g_OffMapIsLapRace, isLap ? uint8(1) : uint8(0));
        } catch {
            warn("SetMapIsLapRace: " + getExceptionInfo());
            return false;
        }
        return map.TMObjective_IsLapRace == isLap;
    }
}
