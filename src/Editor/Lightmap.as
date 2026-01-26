namespace Editor {
    CHmsLightMap@ GetCurrentLightMap(CGameCtnEditorFree@ editor) {
        if (editor is null) return null;
        return GetCurrentLightMapFromMap(editor.Challenge);
    }

    CHmsLightMap@ GetCurrentLightMapFromMap(CGameCtnChallenge@ map) {
        if (map is null || map.Decoration is null) return null;
        auto mood = map.Decoration.DecoMood;
        if (mood is null || mood.HmsLightMap is null) return null;
        // nod explorer says it's an FID not a CHmsLightMap
        CSystemFidFile@ lmFid = cast<CSystemFidFile>(mood.HmsLightMap);
        if (lmFid is null) return null;
        // if the fid Nod is null, then we are probably using a different lightmap loaded due to the environment / mod
        if (lmFid.Nod is null) {
            auto lmFolder = Fids::GetGameFolder("GameData/LightMap/HmsPackLightMap");
            for (uint i = 0; i < lmFolder.Leaves.Length; i++) {
                auto lm = cast<CHmsLightMap>(lmFolder.Leaves[i].Nod);
                if (lm !is null)
                    return lm;
            }
            trace('Could not find loaded LM in folder: ' + lmFolder.FullDirName);
        }
        return cast<CHmsLightMap>(lmFid.Nod);
    }

    NHmsLightMap_SPImp@ GetCurrentLightMapDetails(CGameCtnEditorFree@ editor) {
        CHmsLightMap@ lm = GetCurrentLightMap(editor);
        if (lm is null) return null;
        return lm.m_PImp;
    }

    CHmsLightMapParam@ GetCurrentLightMapParam(CGameCtnEditorFree@ editor) {
        return GetCurrentLightMapParam(GetCurrentLightMap(editor));
    }
    CHmsLightMapParam@ GetCurrentLightMapParam(CHmsLightMap@ lm) {
        if (lm is null) return null;
        auto pimpPtr = Dev::GetOffsetUint64(lm, O_LIGHTMAPCACHE_PIMP);
        auto lmParamPtr = pimpPtr + 0x100; // (0x80 /* Cache Size */ + 0x70)
        return cast<CHmsLightMapParam>(Dev_GetNodFromPointer(lmParamPtr));
    }

    // cacheSmall goes null on place block/item


    /*
        Debug flag for extra LM output:

        Trackmania.exe.text+C51108 - 83 B9 BC000000 00     - cmp dword ptr [rcx+000000BC],00 { 0 }
        Trackmania.exe.text+C5110F - 0F86 68030000         - jbe Trackmania.exe.text+C5147D
        Trackmania.exe.text+C51115 - 48 83 C1 48           - add rcx,48 { 72 }
        Trackmania.exe.text+C51119 - 83 3D D09C3401 00     - cmp dword ptr [Trackmania.exe+1F9BDF0],00 { extra shadows debug flag (1 for debug)
        }
        Trackmania.exe.text+C51120 - 0F84 E3020000         - je Trackmania.exe.text+C51409

        only main flag offset changed between 2024 and 2026:

        83 B9 BC 00 00 00 00
        0F 86 68 03 00 00
        48 83 C1 48
        83 3D D0 9C 34 01 00
        0F 84 E3 02 00 00

        83 B9 BC 00 00 00 00
        0F 86 68 03 00 00
        48 83 C1 48 83 3D ?? ?? ?? ?? 00 0F 84 E3 02 00 00
    */

    const string Pattern_LMDebugFlagOffset = "48 83 C1 48 83 3D ?? ?? ?? ?? 00 0F 84 E3 02 00 00";
    uint64 Ptr_LMDebugFlagCode = 0;
    uint64 Ptr_LMDebugFlag = 0;

    void CheckInitLMDebugFlag() {
        if (Ptr_LMDebugFlag != 0) return;
        Ptr_LMDebugFlagCode = Dev::FindPattern(Pattern_LMDebugFlagOffset);
        if (Ptr_LMDebugFlagCode == 0) {
            trace("Could not find LM debug flag pattern!");
            return;
        }
        Ptr_LMDebugFlagCode += 6;
        // calculate flag address from instruction
        int32 relOffset = Dev::ReadInt32(Ptr_LMDebugFlagCode);
        Ptr_LMDebugFlag = Ptr_LMDebugFlagCode + 5 + relOffset;
        trace("Found LM debug flag at " + Text::FormatPointer(Ptr_LMDebugFlag));
    }

    void SetLMDebugFlag(bool enabled) {
        CheckInitLMDebugFlag();
        if (Ptr_LMDebugFlag == 0) return;
        Dev::Write(Ptr_LMDebugFlag, uint32(enabled ? 1 : 0));
    }

    uint GetLMDebugFlag() {
        CheckInitLMDebugFlag();
        if (Ptr_LMDebugFlag == 0) return uint(-1);
        return Dev::ReadUInt32(Ptr_LMDebugFlag);
    }

    [Setting hidden]
    bool S_EnableLMDebugStatus = true;

    void UpdateLMDebugFlagFromSetting() {
        SetLMDebugFlag(S_EnableLMDebugStatus);
    }
}
