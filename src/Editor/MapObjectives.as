namespace Editor {
    // TMObjective_NbClones is const on CGameCtnChallengeInfo. Write via offset.
    // Laps: write Challenge (verified) + MapInfo only when member offset resolves
    // and pre-write mem matches API (no guessed relatives — those crashed).

    int16 g_MapNbClonesRelOff = -1;
    uint16 g_OffMapInfoNbClones = 0xFFFF;
    uint16 g_OffMapInfoNbLaps = 0xFFFF;
    uint16 g_OffMapInfoIsLapRace = 0xFFFF;
    uint16 g_OffMapAuthorTime = 0xFFFF;
    uint16 g_OffMapNbLaps = 0xFFFF;
    uint16 g_OffMapIsLapRace = 0xFFFF;

    uint16 SafeMemberOff(CMwNod@ nod, const string &in member) {
        if (nod is null) return 0xFFFF;
        try { return GetOffset(nod, member); } catch { return 0xFFFF; }
    }

    uint16 SafeClassOff(const string &in cls, const string &in member) {
        try { return GetOffset(cls, member); } catch { return 0xFFFF; }
    }

    void ResolveMapObjectiveOffsets(CGameCtnChallenge@ map) {
        if (g_OffMapAuthorTime == 0xFFFF)
            g_OffMapAuthorTime = SafeClassOff("CGameCtnChallenge", "TMObjective_AuthorTime");
        if (g_OffMapNbLaps == 0xFFFF)
            g_OffMapNbLaps = SafeClassOff("CGameCtnChallenge", "TMObjective_NbLaps");
        if (g_OffMapIsLapRace == 0xFFFF)
            g_OffMapIsLapRace = SafeClassOff("CGameCtnChallenge", "TMObjective_IsLapRace");

        if (map !is null && map.MapInfo !is null) {
            if (g_OffMapInfoNbClones == 0xFFFF)
                g_OffMapInfoNbClones = SafeMemberOff(map.MapInfo, "TMObjective_NbClones");
            if (g_OffMapInfoNbLaps == 0xFFFF)
                g_OffMapInfoNbLaps = SafeMemberOff(map.MapInfo, "TMObjective_NbLaps");
            if (g_OffMapInfoIsLapRace == 0xFFFF)
                g_OffMapInfoIsLapRace = SafeMemberOff(map.MapInfo, "TMObjective_IsLapRace");
        }
        if (g_OffMapInfoNbClones == 0xFFFF)
            g_OffMapInfoNbClones = SafeClassOff("CGameCtnChallengeInfo", "TMObjective_NbClones");
        if (g_OffMapInfoNbLaps == 0xFFFF)
            g_OffMapInfoNbLaps = SafeClassOff("CGameCtnChallengeInfo", "TMObjective_NbLaps");
        if (g_OffMapInfoIsLapRace == 0xFFFF)
            g_OffMapInfoIsLapRace = SafeClassOff("CGameCtnChallengeInfo", "TMObjective_IsLapRace");

        // NbClones fallback only (proven path): relative to MapInfo AuthorTime
        if (g_OffMapInfoNbClones == 0xFFFF && map !is null && map.MapInfo !is null) {
            uint16 oAT = SafeMemberOff(map.MapInfo, "TMObjective_AuthorTime");
            if (oAT == 0xFFFF) oAT = SafeClassOff("CGameCtnChallengeInfo", "TMObjective_AuthorTime");
            if (oAT != 0xFFFF) {
                uint want = map.MapInfo.TMObjective_NbClones;
                uint16[] cands = { uint16(oAT + 0x18), uint16(oAT + 0x1C), uint16(oAT + 0x20), uint16(oAT + 0x14) };
                for (uint i = 0; i < cands.Length; i++) {
                    try {
                        if (Dev::GetOffsetUint32(map.MapInfo, cands[i]) == want) {
                            g_OffMapInfoNbClones = cands[i];
                            break;
                        }
                    } catch {}
                }
                if (g_OffMapInfoNbClones == 0xFFFF && want == 0)
                    g_OffMapInfoNbClones = uint16(oAT + 0x18);
            }
        }
        // Do NOT invent MapInfo lap offsets from NbClones — unverified relatives crashed TM.
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
        if (apiBefore == 0 && memBefore != 0 && memBefore > 64) {
            warn("SetMapNbClones: bad offset guess — abort");
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
        return after == nbClones;
    }

    uint GetMapNbLaps(CGameCtnChallenge@ map) {
        if (map is null) return 0;
        // Prefer MapInfo when present (stock editor UI / HasClones family); else Challenge.
        if (map.MapInfo !is null) return map.MapInfo.TMObjective_NbLaps;
        return map.TMObjective_NbLaps;
    }

    bool GetMapIsLapRace(CGameCtnChallenge@ map) {
        if (map is null) return false;
        // Challenge.TMObjective_IsLapRace often does not reflect offset writes;
        // MapInfo is what tracks enable/disable consistently with stock UI data.
        if (map.MapInfo !is null) return map.MapInfo.TMObjective_IsLapRace;
        return map.TMObjective_IsLapRace;
    }

    bool _WriteU32IfMatches(CMwNod@ nod, uint16 off, uint apiVal, uint newVal, const string &in tag) {
        if (nod is null || off == 0xFFFF) return false;
        try {
            uint mem = Dev::GetOffsetUint32(nod, off);
            if (mem != apiVal && apiVal != newVal) {
                warn(tag + ": skip write off=0x" + Text::Format("%x", off) + " api=" + apiVal + " mem=" + mem);
                return false;
            }
            Dev::SetOffset(nod, off, newVal);
            return true;
        } catch {
            warn(tag + ": " + getExceptionInfo());
            return false;
        }
    }

    bool _WriteU8Flag(CMwNod@ nod, uint16 off, bool apiVal, bool newVal, const string &in tag) {
        if (nod is null || off == 0xFFFF) return false;
        try {
            uint8 mem = Dev::GetOffsetUint8(nod, off);
            bool memB = mem != 0;
            if (memB != apiVal && apiVal != newVal) {
                warn(tag + ": skip write off=0x" + Text::Format("%x", off) + " api=" + apiVal + " mem=" + mem);
                return false;
            }
            Dev::SetOffset(nod, off, newVal ? uint8(1) : uint8(0));
            return true;
        } catch {
            warn(tag + ": " + getExceptionInfo());
            return false;
        }
    }

    bool SetMapNbLaps(CGameCtnChallenge@ map, uint nbLaps) {
        if (map is null) return false;
        ResolveMapObjectiveOffsets(map);
        if (nbLaps > 99) nbLaps = 99;

        bool any = false;
        // Challenge (gameplay path)
        if (g_OffMapNbLaps != 0xFFFF) {
            any = _WriteU32IfMatches(map, g_OffMapNbLaps, map.TMObjective_NbLaps, nbLaps, "SetMapNbLaps/ch") || any;
        }
        // MapInfo (editor UI / listing path)
        if (map.MapInfo !is null && g_OffMapInfoNbLaps != 0xFFFF) {
            any = _WriteU32IfMatches(map.MapInfo, g_OffMapInfoNbLaps, map.MapInfo.TMObjective_NbLaps, nbLaps, "SetMapNbLaps/mi") || any;
        }
        return any && GetMapNbLaps(map) == nbLaps;
    }

    bool SetMapIsLapRace(CGameCtnChallenge@ map, bool isLap) {
        if (map is null) return false;
        ResolveMapObjectiveOffsets(map);
        bool any = false;
        // Best-effort Challenge write (often does not stick on API readback).
        if (g_OffMapIsLapRace != 0xFFFF) {
            any = _WriteU8Flag(map, g_OffMapIsLapRace, map.TMObjective_IsLapRace, isLap, "SetMapIsLapRace/ch") || any;
        }
        // MapInfo is the reliable enable/disable bit.
        if (map.MapInfo !is null && g_OffMapInfoIsLapRace != 0xFFFF) {
            any = _WriteU8Flag(map.MapInfo, g_OffMapInfoIsLapRace, map.MapInfo.TMObjective_IsLapRace, isLap, "SetMapIsLapRace/mi") || any;
        }
        return any && GetMapIsLapRace(map) == isLap;
    }

    // Apply lap mode. NbLaps first when enabling, then IsLapRace flag.
    // isLap=false → disabled. isLap=true + nbLaps 0..99 (0 = multilap, hide counter).
    bool SetMapLapMode(CGameCtnChallenge@ map, bool isLap, uint nbLaps = 0) {
        if (map is null) return false;
        bool ok = true;
        if (isLap) {
            ok = SetMapNbLaps(map, nbLaps) && ok;
            ok = SetMapIsLapRace(map, true) && ok;
        } else {
            ok = SetMapIsLapRace(map, false) && ok;
        }
        return ok;
    }
}
