namespace Editor {
    import const array<BlockSpec@>@ ThisFrameBlocksDeleted() from "Editor";
    import const array<BlockSpec@>@ ThisFrameBlocksDeletedByAPI() from "Editor";
    import const array<ItemSpec@>@ ThisFrameItemsDeleted() from "Editor";
    import const array<BlockSpec@>@ ThisFrameBlocksPlaced() from "Editor";
    import const array<ItemSpec@>@ ThisFrameItemsPlaced() from "Editor";
    import const array<SetSkinSpec@>@ ThisFrameSkinsSet() from "Editor";
    import const array<SetSkinSpec@>@ ThisFrameSkinsSetByAPI() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksDeleted() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksDeletedByAPI() from "Editor";
    import const array<ItemSpec@>@ LastFrameItemsDeleted() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksPlaced() from "Editor";
    import const array<ItemSpec@>@ LastFrameItemsPlaced() from "Editor";
    import const array<SetSkinSpec@>@ LastFrameSkinsSet() from "Editor";
    import const array<SetSkinSpec@>@ LastFrameSkinsSetByAPI() from "Editor";
    import MacroblockWithSetSkins@ GetMapAsMacroblock() from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec() from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) from "Editor";
    import MacroblockSpec@ MacroblockSpecFromBuf(MemoryBuffer@ buf) from "Editor";
    import BlockSpec@ MakeBlockSpec(CGameCtnBlock@ block) from "Editor";
    import ItemSpec@ MakeItemSpec(CGameCtnAnchoredObject@ item) from "Editor";
    import SetSkinSpec@ SetSkinSpecFromBuf(MemoryBuffer@ buf) from "Editor";
    import bool PlaceBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteBlocks(CGameCtnBlock@[]@ blocks, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteItems(CGameCtnAnchoredObject@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool PlaceMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) from "Editor";
    import bool SetSkins(SetSkinSpec@[]@ skins) from "Editor";
    // import void SetAirblockMode(bool airBlockEnabled) from "Editor";
    // Running this in the wrong context can crash the game
    import void RunDeleteFreeBlockDetection() from "Editor";
    import bool HasPendingFreeBlocksToDelete() from "Editor";
    import CGameEditorPluginMap::EPlaceMode GetPlacementMode(CGameCtnEditorFree@ editor) from "Editor";
    import CGameEditorPluginMap::EditMode GetEditMode(CGameCtnEditorFree@ editor) from "Editor";
    // Some camera things
    import bool SetCamAnimationGoTo(vec2 lookAngleHV, vec3 position, float targetDist) from "Editor";
    import vec2 DirToLookUvFromCamera(vec3 target) from "Editor";
    import vec2 DirToLookUv(vec3 dir) from "Editor";

    // returns a const version of the cached octree for all blocks/items in the map
    import const OctTreeNode@ GetCachedMapOctTree() from "Editor";
    // returns all blocks and items in mainMacroblock that are not in removeSource
    import MacroblockSpec@ SubtractMacroblocks(MacroblockSpec@ mainMacroblock, MacroblockSpec@ removeSource) from "Editor";
    // returns all blocks/items in map that are not in removeSource
    import MacroblockSpec@ SubtractMacroblockFromMap(MacroblockSpec@ removeSource) from "Editor";
    // returns all blocks/items in map that are not in removeSource
    import MacroblockSpec@ SubtractMacroblockFromMapCache(MacroblockSpec@ removeSource) from "Editor";
    // returns all blocks/items in map that are not in removeSource
    import MacroblockSpec@ SubtractTreeFromMapCache(OctTreeNode@ removeSource) from "Editor";

}

namespace Editor {
    import bool IsCtrlDown() from "Editor";
    import bool IsAltDown() from "Editor";
    import bool IsShiftDown() from "Editor";


    import vec3 PitchYawRollFromRotationMatrix(mat4 m) from "Editor";
    import mat4 EulerToMat(vec3 euler) from "Editor";

    import vec3 CoordDistToPos(int3 coord) from "Editor";
    import vec3 CoordDistToPos(vec3 coord) from "Editor";
    import vec3 CoordToPos(nat3 coord) from "Editor";
    import vec3 CoordToPos(vec3 coord) from "Editor";
    import vec3 Nat3ToVec3(nat3 coord) from "Editor";
    import nat3 Vec3ToNat3(vec3 v) from "Editor";
    import int3 Nat3ToInt3(nat3 coord) from "Editor";
    import vec3 Int3ToVec3(int3 coord) from "Editor";
    import nat3 Int3ToNat3(int3 coord) from "Editor";
    import vec2 Nat2ToVec2(nat2 coord) from "Editor";
    import nat2 Vec2ToNat2(vec2 v) from "Editor";
    import nat3 PosToCoord(vec3 pos) from "Editor";
    import int3 PosToCoordDist(vec3 pos) from "Editor";
    import vec3 MTCoordToPos(int3 mtCoord, vec3 mtBlockSize = vec3(10.66666, 8., 10.66666)) from "Editor";
    import vec3 MTCoordToPos(nat3 mtCoord, vec3 mtBlockSize = vec3(10.66666, 8., 10.66666)) from "Editor";
    import vec3 MTCoordToPos(vec3 mtCoord, vec3 mtBlockSize = vec3(10.66666, 8., 10.66666)) from "Editor";
}
