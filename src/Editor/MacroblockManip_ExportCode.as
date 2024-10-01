namespace Editor {
    import const array<BlockSpec@>@ ThisFrameBlocksDeleted() from "Editor";
    import const array<BlockSpec@>@ ThisFrameBlocksDeletedByAPI() from "Editor";
    import const array<ItemSpec@>@ ThisFrameItemsDeleted() from "Editor";
    import const array<BlockSpec@>@ ThisFrameBlocksPlaced() from "Editor";
    import const array<ItemSpec@>@ ThisFrameItemsPlaced() from "Editor";
    import const array<SetSkinSpec@>@ ThisFrameSkinsSet() from "Editor";
    import const array<SetSkinSpec@>@ ThisFrameSkinsSetByAPI() from "Editor";
    import const array<BlockSpec@>@ ThisFrameBlocksColorsChanged() from "Editor";
    import const array<ItemSpec@>@ ThisFrameItemsColorsChanged() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksDeleted() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksDeletedByAPI() from "Editor";
    import const array<ItemSpec@>@ LastFrameItemsDeleted() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksPlaced() from "Editor";
    import const array<ItemSpec@>@ LastFrameItemsPlaced() from "Editor";
    import const array<SetSkinSpec@>@ LastFrameSkinsSet() from "Editor";
    import const array<SetSkinSpec@>@ LastFrameSkinsSetByAPI() from "Editor";
    import const array<BlockSpec@>@ LastFrameBlocksColorsChanged() from "Editor";
    import const array<ItemSpec@>@ LastFrameItemsColorsChanged() from "Editor";
    import MacroblockWithSetSkins@ GetMapAsMacroblock() from "Editor";

    import MacroblockSpec@ MakeMacroblockSpec() from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) from "Editor";
    import MacroblockSpec@ MakeMacroblockSpec(CGameCtnMacroBlockInfo@ mb) from "Editor";
    import MacroblockSpec@ MacroblockSpecFromBuf(MemoryBuffer@ buf) from "Editor";

    import BlockSpec@ MakeBlockSpec(CGameCtnBlock@ block) from "Editor";
    import BlockSpec@ MakeBlockSpec(CGameCtnBlockInfo@ blockInfo, const nat3 &in _coord, int dir) from "Editor";
    import BlockSpec@ MakeBlockSpec(CGameCtnBlockInfo@ blockInfo, const vec3 &in position, const vec3 &in pyrRotation) from "Editor";

    import ItemSpec@ MakeItemSpec(CGameCtnAnchoredObject@ item) from "Editor";
    import ItemSpec@ MakeItemSpec(CGameItemModel@ itemModel, const vec3 &in position, const vec3 &in pyrRotation) from "Editor";

    import SetSkinSpec@ SetSkinSpecFromBuf(MemoryBuffer@ buf) from "Editor";
    import bool PlaceBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteBlocksAndItems(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteBlocks(CGameCtnBlock@[]@ blocks, bool addUndoRedoPoint = false) from "Editor";
    import bool PlaceBlocks(BlockSpec@[]@ blocks, bool addUndoRedoPoint = false) from "Editor";
    // returns the newly placed replacement block
    import CGameCtnBlock@ ConvertBlockToFree(CGameCtnBlock@ block) from "Editor";
    import bool DeleteItems(CGameCtnAnchoredObject@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool PlaceItems(ItemSpec@[]@ items, bool addUndoRedoPoint = false) from "Editor";
    import bool PlaceMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) from "Editor";
    import bool DeleteMacroblock(MacroblockSpec@ macroblock, bool addUndoRedoPoint = false) from "Editor";
    import bool SetSkins(SetSkinSpec@[]@ skins) from "Editor";
    // import void SetAirblockMode(bool airBlockEnabled) from "Editor";
    // WARNING Running this in the wrong context can crash the game, use GameLoop or MainLoop
    import void RunDeleteFreeBlockDetection() from "Editor";
    import bool HasPendingFreeBlocksToDelete() from "Editor";
    // (Safe alt: Use DeleteBlocks instead) WARNING run this in GameLoop or MainLoop
    import uint DeleteFreeblocks(CGameCtnBlock@[]@ blocks) from "Editor";
    // (Safe alt: Use DeleteBlocks instead) WARNING run this in GameLoop or MainLoop
    import uint DeleteFreeblocks(BlockSpec@[]@ blocks) from "Editor";
    // WARNING use this to start an intercept-gather for freeblocks queued for deletion by macroblock deletion functions -- EndInterceptFreeblockQueueAndGather MUST be called later.
    import void BeginInterceptFreeblockQueueAndGather() from "Editor";
    // WARNING use this to end an intercept-gather for freeblocks queued for deletion by macroblock deletion functions
    import BlockSpec@[]@ EndInterceptFreeblockQueueAndGather() from "Editor";

    // get CSystemPackDescs for skin purposes
    import CSystemPackDesc@[]@ GetPackDescs(const string[]@ fileOrUrls) from "Editor";

    import CGameEditorPluginMap::EPlaceMode GetPlacementMode(CGameCtnEditorFree@ editor) from "Editor";
    import CGameEditorPluginMap::EditMode GetEditMode(CGameCtnEditorFree@ editor) from "Editor";
    // Some camera things
    // Easy way to set the editor camera to some target
    import bool SetCamAnimationGoTo(vec2 lookAngleHV, vec3 position, float targetDist) from "Editor";
    import vec2 DirToLookUvFromCamera(vec3 target) from "Editor";
    // returns lookAngleHV suitable for SetCamAnimationGoTo
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

    import bool IsMapCacheStale() from "Editor";
    import void RefreshMapCacheSoon() from "Editor";

    import void Set_Map_EmbeddedCustomColorsEncoded(const string &in raw) from "Editor";
    import string Get_Map_EmbeddedCustomColorsEncoded() from "Editor";

    // pass in paths relative to `Trackmania/Items/` folder
    import void ReloadItemsAsync(string[]@ paths) from "Editor";
}

namespace Editor {
    import bool IsCtrlDown() from "Editor";
    import bool IsAltDown() from "Editor";
    import bool IsShiftDown() from "Editor";


    import vec3 PitchYawRollFromRotationMatrix(mat4 m) from "Editor";
    import mat4 EulerToMat(vec3 euler) from "Editor";

    import vec3 CoordDistToPos(int3 coord) from "Editor";
    import vec3 CoordDistToPos(nat3 coord) from "Editor";
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
