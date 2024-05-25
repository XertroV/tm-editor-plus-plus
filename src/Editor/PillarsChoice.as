[Setting hidden]
bool S_LoadMapsWithOldPillars = false;

bool S_DebugBreakOnBlockNoSkin = false;

namespace PillarsChoice {
    void OnEditorStartingUp(bool editingElseNew) {
        if (S_LoadMapsWithOldPillars) {
            IsActive = true;
        }
    }

    void OnEditorLoad() {
        if (S_LoadMapsWithOldPillars) {
            auto map = GetApp().RootMap;
            Editor::SetMapFlags_UseNewPillars(map, false);
            CGameCtnBlock@ b;
            for (uint i = 0; i < map.Blocks.Length; i++) {
                @b = map.Blocks[i];
                if (b.BlockModel.IsPillar && b.Skin !is null) {
                    warn("Setting skin to null on pillar; " + b.BlockModel.Name);
                    Dev::SetOffset(b, O_CTNBLOCK_SKIN, uint64(0));
                }
            }
        }
    }

    bool _IsActive = false;
    bool IsActive {
        get {
            return _IsActive;
        }
        set {
            if (_IsActive == value) return;
            _IsActive = value;
            if (_IsActive) {
                AlwaysReadOldPillars.Apply();
                SkipUpdateAllPillarBlockSkinRemapFolders.Apply();
            } else {
                AlwaysReadOldPillars.Unapply();
                SkipUpdateAllPillarBlockSkinRemapFolders.Unapply();
            }
        }
    }

    void OnEditorUnload() {
        IsActive = false;
    }

    void WatchForEditorNull() {
        auto app = GetApp();
        while (!IsInAnyEditor && app.CurrentPlayground is null) yield();
        // did we load into a playground instead of editor?
        if (!IsInAnyEditor) {
            IsActive = false;
            return;
        }
        while (IsInAnyEditor) yield();
        IsActive = false;
    }

    // CGameCtnApp::InitChallengeData ; the `or` updates the map flags; then flags are read
    MemPatcher@ AlwaysReadOldPillars = MemPatcher(
        // v or dword ptr [rdi+2E8],04
        //                    v read map + 0x2e8                        v Global address for flag to load NoTrackWall skin
        "83 8F ?? ?? 00 00 04 8B 87 ?? ?? 00 00 C1 E8 02 F7 D0 83 E0 01 89 05 ?? ?? ?? ?? 48",
        //     v NOP update map     v MOV EAX, 1; NOP
        {0}, {"90 90 90 90 90 90 90 B8 01 00 00 00 90"}, {"83 8F E8 02 00 00 04 8B 87 E8 02 00 00"}
    );

    MemPatcher@ SkipUpdateAllPillarBlockSkinRemapFolders = MemPatcher(
        // v call UpdateAllPillarBlockSkinRemapFolders
        // v                     v Editor_CamMode+0x8  v then +0xA0
        "E8 ?? ?? ?? ?? 48 8B BB ?? ?? 00 00 48 8D 8F ?? 00 00 00",
        {0}, {"90 90 90 90 90"}
    );

    // // Hook CGameCtnApp::InitChallengeData when it checks map flags (Map +0x2e8)
    // HookHelper@ OnReadFlagsFromMapHook = HookHelper(
    //     //     v 0x2e8                                   v Global address for flag to load NoTrackWall skin
    //     "8B 87 ?? ?? 00 00 C1 E8 02 F7 D0 83 E0 01 89 05 ?? ?? ?? ??",
    //     0, 1, "InitChallengeData_OnReadMapFlags", Dev::PushRegisters::Basic
    // );



    // // rdi = CGameCtnChallenge, r14 = flag to skip `or dword ptr [rdi+000002E8],04`
    // void InitChallengeData_OnReadMapFlags(uint64 rdi, uint64 r14) {
    //     auto map = cast<CGameCtnChallenge>(Dev_GetNodFromPointer(rdi));
    //     auto flags = Dev::GetOffsetUint32(map, O_MAP_FLAGS);
    //     // print("Map flags: " + Text::Format("%08x", flags));
    //     // does the map have new pillars?
    //     if (S_LoadMapsWithOldPillars && flags & 0x4) {
    //         Dev::SetOffset(map, O_MAP_FLAGS, flags & ~0x4);
    //     }
    // }

    string[]@ structureObjNames;

    string[]@ GetStructureObjNames() {
        if (structureObjNames !is null) return structureObjNames;
        @structureObjNames = {};
        structureObjNames.InsertLast("StructureDeadend");
        structureObjNames.InsertLast("StructureBase");
        structureObjNames.InsertLast("StructureStraight");
        structureObjNames.InsertLast("StructureCorner");
        structureObjNames.InsertLast("StructureTShaped");
        structureObjNames.InsertLast("StructureCross");
        structureObjNames.InsertLast("StructureStraightInTrackWallStraight");
        structureObjNames.InsertLast("StructureDeadendInTrackWallStraight");
        structureObjNames.InsertLast("StructureSupportDeadend");
        structureObjNames.InsertLast("StructureSupportStraight");
        structureObjNames.InsertLast("StructureSupportCorner");
        structureObjNames.InsertLast("StructureSupportTShaped");
        structureObjNames.InsertLast("StructureSupportCross");
        structureObjNames.InsertLast("StructureSupportCurve1In");
        structureObjNames.InsertLast("StructureSupportCurve2In");
        structureObjNames.InsertLast("StructureSupportCurve3In");
        structureObjNames.InsertLast("StructureSupportCurve1Out");
        structureObjNames.InsertLast("StructureSupportCurve2Out");
        structureObjNames.InsertLast("StructureSupportCurve3Out");
        structureObjNames.InsertLast("StructureSupportCurve0Out");
        structureObjNames.InsertLast("StructureSupportCornerSmall");
        structureObjNames.InsertLast("StructureSupportCornerSmallDiag");
        return structureObjNames;
    }

    void SetAllStructureObjectsNoColor() {

    }
}



    /*
    // void ApplyOldPillars() {
    //     if (OldPillarsApplied) return;
    //     // FromParent sorta works but new pillars don't get skinned which isn't ideal.
    //     // better to patch the parents so that we have more control.
    //     // FindAndProcessRemapFolder("GameData/Stadium/Media/Modifier/TrackWallFromParent.Gbx", true);
    //     auto paths = GetModifierPaths();
    //     for (uint i = 0; i < paths.Length; i++) {
    //         FindAndProcessRemapFolder(paths[i], true);
    //     }
    //     OldPillarsApplied = true;
    // }

    // void UnapplyOldPillars() {
    //     if (!OldPillarsApplied) return;
    //     // FindAndProcessRemapFolder("GameData/Stadium/Media/Modifier/TrackWallFromParent.Gbx", false);
    //     auto paths = GetModifierPaths();
    //     for (uint i = 0; i < paths.Length; i++) {
    //         FindAndProcessRemapFolder(paths[i], false);
    //     }
    //     OldPillarsApplied = false;
    // }

    // PillarMod@[] appliedPillars;

    // void FindAndProcessRemapFolder(const string &in path, bool applyElseUnapply) {
    //     if (applyElseUnapply) {
    //         auto fid = Fids::GetGame(path);
    //         auto nod = cast<CPlugGameSkinAndFolder>(Fids::Preload(fid));
    //         if (nod is null) return;
    //         appliedPillars.InsertLast(PillarMod(nod, path));
    //     } else {
    //         for (uint i = 0; i < appliedPillars.Length; i++) {
    //             if (appliedPillars[i].path == path) {
    //                 appliedPillars[i].UnpatchRemap();
    //                 appliedPillars.RemoveAt(i);
    //                 break;
    //             }
    //         }
    //     }
    // }


    // class PillarMod {
    //     uint64 remappingPtr;
    //     uint64 remapFolderPtr;
    //     CPlugGameSkinAndFolder@ materialModifier;
    //     DPlugGameSkin@ skin;
    //     string path;
    //     string fileName;
    //     string origTrackWallName;
    //     int origTrackWallIx = -1;

    //     PillarMod(CPlugGameSkinAndFolder@ materialModifier, const string &in path) {
    //         if (materialModifier is null) throw("PillarMod: materialModifier is null");
    //         @this.materialModifier = materialModifier;
    //         this.path = path;
    //         this.fileName = GetFidFromNod(materialModifier).FileName;
    //         materialModifier.MwAddRef();
    //         if (materialModifier.Remapping !is null) {
    //             @skin = DPlugGameSkin(materialModifier.Remapping);
    //             PatchRemap();
    //             // trace("Patched MaterialModifier: " + (GetFidFromNod(materialModifier).FileName));
    //         } else {
    //             warn("Patch MatMod ("+fileName+"): No Skin!!");
    //         }
    //     }

    //     ~PillarMod() {
    //         UnpatchRemap();
    //     }


    //     void UnpatchRemap() {
    //         if (materialModifier is null) return;
    //         if (origTrackWallIx != -1) {
    //             // auto str = skin.Filenames.GetDString(origTrackWallIx);
    //             // str.Value = str.Value.Replace("XxxxxXxxx", "TrackWall");
    //             skin.SetUint32(O_GAMESKIN_FID_BUF + 0x8, origTrackWallIx + 1);
    //             skin.SetUint32(O_GAMESKIN_FID_CLASSID_BUF + 0x8, origTrackWallIx + 1);
    //             skin.SetUint32(O_GAMESKIN_FILENAME_BUF + 0x8, origTrackWallIx + 1);
    //             skin.SetUint32(O_GAMESKIN_UNK_BUF + 0x8, origTrackWallIx + 1);
    //         }
    //         // Dev::SetOffset(materialModifier, O_MATMOD_REMAPPING, remappingPtr);
    //         // Dev::SetOffset(materialModifier, O_MATMOD_REMAPFOLDER, remapFolderPtr);
    //         materialModifier.MwRelease();
    //         @materialModifier = null;
    //         trace("Unpatched MaterialModifier: " + path);
    //     }

    //     protected void PatchRemap() {
    //         auto fids = skin.Fids;
    //         auto nbFids = fids.Length;
    //         if (nbFids == 0) return;
    //         trace("Patching: " + fileName + " / has " + nbFids + " fids");
    //         DSystemFidFile@ item = fids.GetDSystemFidFile(nbFids - 1);
    //         CSystemFidFile@ fid = item.Nod;
    //         if (fid is null) return;
    //         if (fid.FileName.Contains("TrackWall.Material.Gbx")) {
    //             origTrackWallIx = nbFids - 1;
    //             skin.SetUint32(O_GAMESKIN_FID_BUF + 0x8, origTrackWallIx);
    //             skin.SetUint32(O_GAMESKIN_FID_CLASSID_BUF + 0x8, origTrackWallIx);
    //             skin.SetUint32(O_GAMESKIN_FILENAME_BUF + 0x8, origTrackWallIx);
    //             skin.SetUint32(O_GAMESKIN_UNK_BUF + 0x8, origTrackWallIx);
    //             // auto str = skin.Filenames.GetDString(i);
    //             // origTrackWallName = str.Value;
    //             // str.Value = origTrackWallName.Replace("TrackWall", "XxxxxXxxx");
    //             // print(" "+i+" " + fid.FileName + " / " + str.Value);
    //             // break;
    //         } else {
    //             // trace(" - " + fid.FileName);
    //         }
    //     }
    // }

    // const string ModifierPathsJson = '["GameData/Stadium/Media/Modifier/PlatformDirtDecal.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/TurboRoulette.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Turbo2.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Turbo.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/SlowMotion.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Reset.TerrainModifier .Gbx","GameData/Stadium/Media/Modifier/NoSteering.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/NoEngine.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/NoBrake.TerrainModifier .Gbx","GameData/Stadium/Media/Modifier/Fragile.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Cruise.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Boost2.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/Boost.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PenaltyIce.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PenaltyDirt.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PlatformIce.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/PlatformDirt.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/TrackWallToDecoCliff.Gbx","GameData/Stadium/Media/Modifier/PlatformGrass.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/TrackWallToDecoCliffIce.Gbx","GameData/Stadium/Media/Modifier/TrackWallToDecoCliffDirt.Gbx","GameData/Stadium/Media/Modifier/PlatformPlastic.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/GateGamePlaySnow.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/GateGamePlayRally.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/GateGameplayDesert.TerrainModifier.Gbx","GameData/Stadium/Media/Modifier/InvisibleDecalPlatform.Gbx"]';
    // const string ModifierIdsJson = '["Unassigned","TurboRoulette","Turbo2","Turbo","SlowMotion","Reset","NoSteering","NoEngine","NoBrake","Fragile","Cruise","Boost2","Boost","Unassigned","Unassigned","PlatformIce","Unassigned","Unassigned","PlatformGrass","Unassigned","Unassigned","PlatformPlastic","GateGameplaySnow","GateGameplayRally","GateGameplayDesert","InvisibleDecal"]';

    // string[]@ ModifierPaths;
    // string[]@ ModifierIds;

    // string[]@ GetModifierPaths() {
    //     if (ModifierPaths is null) {
    //         auto ar = Json::Parse(ModifierPathsJson);
    //         @ModifierPaths = {};
    //         for (uint i = 0; i < ar.Length; i++) {
    //             ModifierPaths.InsertLast(ar[i]);
    //         }
    //     }
    //     return ModifierPaths;
    // }

//     bool OnBlockPlaced(CGameCtnBlock@ block) {
//         if (_IsActive || true) {
//             if (block.Skin !is null) {
//                 auto fid = GetFidFromNod(block.Skin);
//                 if (fid !is null) {
//                     // print("Block (\\$999"+block.BlockModel.Name+"\\$z) with skin: " + fid.FileName);
//                 } else {
//                     // print("Block (\\$999"+block.BlockModel.Name+"\\$z) with skin (null FID)");
//                 }
//             } else {
// #if DEV
//                 // print("Block (\\$999"+block.BlockModel.Name+"\\$z) with no skin");
//                 if (S_DebugBreakOnBlockNoSkin) {
//                     SetClipboard(Text::FormatPointer(Dev_GetPointerForNod(block)));
//                     Dev::DebugBreak();
//                 }
// #endif
//             }
//         }
//         return false;
//     }

    */
