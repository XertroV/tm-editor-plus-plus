// implementation of wave function collapse for level generation

bool INCLUDE_CG1 = false;
bool INCLUDE_CG2 = false;
bool INCLUDE_SCG1 = false;
bool INCLUDE_SCG2 = false;
bool INCLUDE_SCID = true;
bool INCLUDE_ID = false;

namespace WFC {
    /*
        Each coord has a number of possible states.

        Each block has a BlockUnitInfo around it when it can be connected to other blocks.
        Below is (always?) pillars.

    */

    BlockInventory@ blockInv;
    MapVoxels@ mapVoxels;

    void Preload() {
        GetBlockInventory();
    }

    BlockInventory@ GetBlockInventory() {
        if (blockInv is null) @blockInv = BlockInventory().Start();
        return blockInv;
    }
}

class BlockFilter {
    BlockFilter() {}
    bool Matches(WFC_BlockInfo &in bi) {
        return true;
    }
}

// MARK: MapVoxels

class MapVoxels {
    CoordState[][] states;

}

class CoordState {
    uint64 inner;
    // list of state:
    // constraints on 6 faces
    // entropy = number of blocks that meet constraints
    // need easy lookup for compatible clips
    //

}

// MARK: WFC_ClipInfo

class WFC_ClipInfo {
    int cId = -1, symCID = -1, clipGroup1 = -1, clipGroup2 = -1, symClipGroup1 = -1, symClipGroup2 = -1;
    uint biIx = -1, buiIx = -1, clipIx = -1;
    CardinalDir dirFromParent;
    int3 buiOffset;
    int distFromTop = 0;
    WFC_ClipInfo(CGameCtnBlockInfoClip@ bic, CardinalDir dirFromParent, uint biIx, uint buiIx, uint clipIx, CGameCtnBlockUnitInfo@ bui, WFC_BlockInfo@ parent) {
        cId = bic.Id.Value;
        symCID = bic.SymmetricalClipId.Value;
        // if (symCID == -1) symCID = cId; // if no symmetrical clip, use the same id
        clipGroup1 = bic.ClipGroupId.Value;
        clipGroup2 = bic.ClipGroupId2.Value;
        symClipGroup1 = bic.SymmetricalClipGroupId.Value;
        symClipGroup2 = bic.SymmetricalClipGroupId2.Value;
        buiOffset = Nat3ToInt3(bui.Offset);
        distFromTop = parent.Size.y - bui.Offset.y - 1;
        this.biIx = biIx;
        this.buiIx = buiIx;
        this.clipIx = clipIx;
        this.dirFromParent = dirFromParent;
        if (!MathX::Nat3Eq(bui.Offset, bui.RelativeOffset)) {
            warn("BlockUnitInfo offset != relativeOffset: " + bui.Offset.ToString() + " != " + bui.RelativeOffset.ToString());
        }
    }

    void InsertSelfToLookups(IntLookup& groupIds, IntLookup& symGroupIds, IntLookup& symIds, IntLookup& clipIds) {
        if (clipGroup1 != -1) groupIds.Insert(clipGroup1, this);
        if (clipGroup2 != -1) groupIds.Insert(clipGroup2, this);
        if (symClipGroup1 != -1) symGroupIds.Insert(symClipGroup1, this);
        if (symClipGroup2 != -1) symGroupIds.Insert(symClipGroup2, this);
        if (symCID != -1) symIds.Insert(symCID, this);
        if (cId != -1) clipIds.Insert(cId, this);
    }

    string ToString() {
        return "ClipInfo: cIx: " + clipIx + ", buiIx: " + buiIx + ", biIx: " + biIx + ", offset: " + buiOffset.ToString() + ", distFT: " + distFromTop + " dirFP: " + tostring(dirFromParent) + ", clipGroup1: " + clipGroup1 + ", clipGroup2: " + clipGroup2 + ", symClipGroup1: " + symClipGroup1 + ", symClipGroup2: " + symClipGroup2 + ", symCID: " + symCID;
    }

    mat4 GetBlockMatrix(PlacedBlock@ pb) {
        CardinalDir dir;
        auto coord = pb.CalcClipConnectingCoord(this, dir);
        coord.y -= buiOffset.y;
        // auto blockInfo = pb.BlockInfo;
        // auto clipOffset = buiOffset;
        // // rotate according to this block's direction
        // clipOffset = RotateOffset(clipOffset, pb.Dir, blockInfo.Size);
        // // move in the direction of the clip
        // clipOffset = MoveOffset(clipOffset, RotateDir(pb.Dir, dirFromParent));
        // auto coord = pb.Coord + clipOffset;
        return Editor::GetBlockMatrix(Int3ToNat3(coord), int(dir), Int3ToNat3(pb.BlockInfo.Size));
    }

    mat4 GetBlockMatrix(int3 placedCoord, int placedDir, int3 blockSize) {
        auto clipOffset = buiOffset;
        // rotate according to this block's direction
        clipOffset = RotateOffset(clipOffset, CardinalDir(placedDir), blockSize);
        // move in the direction of the clip
        clipOffset = MoveOffset(clipOffset, RotateDir(CardinalDir(placedDir), dirFromParent));
        auto coord = placedCoord + clipOffset * int3(1, -1, 1);
        return Editor::GetBlockMatrix(Int3ToNat3(coord), int(placedDir), Int3ToNat3(blockSize));
    }

    nat2 get_SymGroups() {
        return nat2(symClipGroup1, symClipGroup2);
    }

    nat2 get_ClipGroups() {
        return nat2(clipGroup1, clipGroup2);
    }

    bool CanSnapTo(WFC_ClipInfo@ other) {
        return DoClipsSnap(this, other);
    }
}


// replicates logic from the game (I called the function `CGameCtnBlockInfoClip::CanSnapTo(CGameCtnBlockInfoClip*, CGameCtnBlockInfoClip*))`)
bool DoClipsSnap(WFC_ClipInfo@ left, WFC_ClipInfo@ right) {
    auto gLeft = left.SymGroups;
    // no left sym groups
    if (gLeft.x == -1) {
        gLeft = left.ClipGroups;
        // we have left clip groups
        if (gLeft.x != -1) {
            // return right clip groups overlap
            auto gRight = right.ClipGroups;
            return ClipsOverlap(gLeft, gRight);
        }
        // otherwise: no left clip groups
        // if we have no sym ID
        if (left.symCID == -1) {
            // return direct clip
            return left.cId == right.cId;
        }
        // otherwise, are this two clips matched (sym-norm)?
        return left.symCID == right.cId;
    }
    // if we have left sym groups, check them against right clip groups
    auto gRight = right.ClipGroups;
    return ClipsOverlap(gLeft, gRight);
}

// check if two groups overlap, but only if they are not -1
bool ClipsOverlap(nat2 left, nat2 right) {
    // check if left and right groups overlap
    if (left.x == -1 || right.x == -1) return false;
    if (left.x == right.x || left.x == right.y || left.y == right.x) return true;
    if (left.y == -1 || right.y == -1) return false;
    return left.y == right.y;
}

WFC_ClipInfo@[]@ JoinMatches(const ref@[]@[] &in toJoin) {
    WFC_ClipInfo@[]@ joined = {};
    for (uint i = 0; i < toJoin.Length; i++) {
        auto group = toJoin[i];
        if (group is null) continue;
        for (uint j = 0; j < group.Length; j++) {
            auto clip = cast<WFC_ClipInfo@>(group[j]);
            if (clip is null) continue;
            joined.InsertLast(clip);
        }
    }
    return joined;
}

enum CardinalDir {
    North = 0,
    East = 1,
    South = 2,
    West = 3
}

// MARK: WFC_BlockInfo

class WFC_BlockInfo {
    ReferencedNod@ refBlockInfo;
    WFC_ClipInfo@[] clips;
    MwId nameId;
    uint VarIx;
    uint BiIx;
    int3 Size = int3(1);

    WFC_BlockInfo(CGameCtnBlockInfo@ bi, uint biIx) {
        @refBlockInfo = ReferencedNod(bi);
        nameId.Value = bi.Id.Value;
        BiIx = biIx;

        auto biv = bi.VariantBaseAir;
        Size = Nat3ToInt3(biv.Size);
        VarIx = 0;
        AddBlockUnitInfos(biv, biIx);
    }
    CGameCtnBlockInfo@ get_BlockInfo() {
        return refBlockInfo.AsBlockInfo();
    }

    void InsertClipsToLookups(IntLookup& groupIds, IntLookup& symGroupIds, IntLookup& symIds, IntLookup& clipIds) {
        auto nbClips = clips.Length;
        for (uint i = 0; i < nbClips; i++) {
            clips[i].InsertSelfToLookups(groupIds, symGroupIds, symIds, clipIds);
            // if (clip is null) continue;
            // if (clip.clipGroup1 != -1) groupIds.Insert(clip.clipGroup1, clip);
            // if (clip.clipGroup2 != -1) groupIds.Insert(clip.clipGroup2, clip);
            // if (clip.symClipGroup1 != -1) symGroupIds.Insert(clip.symClipGroup1, clip);
            // if (clip.symClipGroup2 != -1) symGroupIds.Insert(clip.symClipGroup2, clip);
            // if (clip.symCID != -1) symIds.Insert(clip.symCID, clip);
        }
    }

    void AddBlockUnitInfos(CGameCtnBlockInfoVariant@ biv, uint biIx) {
        if (biv is null) {
            warn("BlockInfoVariant is null for " + BlockInfo.IdName);
            return;
        }
        auto nbBUIs = biv.BlockUnitInfos.Length;
        if (nbBUIs == 0) {
            // warn("BlockInfoVariant has no BlockUnitInfos for " + BlockInfo.IdName);
            return;
        }
        for (uint i = 0; i < nbBUIs; i++) {
            auto bui = biv.BlockUnitInfos[i];
            if (bui is null) {
                warn("BlockUnitInfo is null for " + BlockInfo.IdName);
                continue;
            }
            // many internal block unit infos are empty
            if (bui.AllClips.Length == 0) continue;
            AddClips(bui, i, biv, biIx);
        }
        // auto westLt = biv.
        // auto nbClips = biv.BlockUnitInfos.Length;
        // for (uint i = 0; i < nbClips; i++) {
        //     auto clip = biv.BlockUnitInfos[i];
        //     AddClipInfo(WFC_ClipInfo(clip));
        // }
    }

    void AddClips(CGameCtnBlockUnitInfo@ bui, uint buiIx, CGameCtnBlockInfoVariant@ biv, uint biIx) {
        auto nbClips = bui.AllClips.Length;
        auto northLt = bui.ClipCount_North, eastLt = bui.ClipCount_East + northLt, southLt = bui.ClipCount_South + eastLt, westLt = bui.ClipCount_West + southLt;
        // print("North: " + northLt + ", East: " + eastLt + ", South: " + southLt + ", West: " + westLt);
        CardinalDir dir = CardinalDir::North;

        for (uint i = 0; i < nbClips; i++) {
            if (i >= westLt) break;
            // if (i < northLt) {
            //     dir = CardinalDir::North;
            // } else if (i < eastLt) {
            //     dir = CardinalDir::East;
            // } else if (i < southLt) {
            //     dir = CardinalDir::South;
            // } else if (i < westLt) {
            //     dir = CardinalDir::West;
            // } else break;
            dir = i < southLt ? i < eastLt ? i < northLt ? CardinalDir::North : CardinalDir::East : CardinalDir::South : CardinalDir::West;
            auto clip = bui.AllClips[i];
            if (clip is null) {
                warn("Clip is null for " + BlockInfo.IdName);
                continue;
            }
            if (clip.ClipGroupId.Value == -1
                && clip.SymmetricalClipGroupId.Value == -1
                && clip.SymmetricalClipId.Value == -1
                && clip.ClipGroupId2.Value == -1
                && clip.SymmetricalClipGroupId2.Value == -1) {
                // warn("Clip has no group ids for " + BlockInfo.IdName);
                continue;
            }
            AddClipInfo(WFC_ClipInfo(clip, dir, biIx, buiIx, i, bui, this));
        }
    }

    void AddClipInfo(WFC_ClipInfo@ clip) {
        clips.InsertLast(clip);
    }

    // void GetClipInfo(CardinalDir dir) {

    // }

    WFC_ClipInfo@ GetRandomClip() {
        if (clips.Length == 0) return null;
        uint ix = Math::Rand(0, clips.Length);
        return clips[ix];
    }
}

// MARK: BlockInventory

class BlockInventory {
    protected bool started = false;
    protected bool ingestionComplete = false;
    // BlockFilter@ filter;
    // CGameCtnBlockInfo@
    uint count, ingestionStart, ingestionDuration;
    WFC_BlockInfo@[] blockInfos;
    IntLookup GroupIdsToClips;
    IntLookup SymGroupIdsToClips;
    IntLookup SymIdsToClips;
    IntLookup ClipIdsToClips;
    IntLookup BlocksById;

    BlockInventory() {
    }

    protected void IngestBlockInfo(CGameCtnBlockInfo@ bi) {
        // if (!filter.Matches(bi)) return;
        auto wfcBi = WFC_BlockInfo(bi, blockInfos.Length);
        wfcBi.InsertClipsToLookups(GroupIdsToClips, SymGroupIdsToClips, SymIdsToClips, ClipIdsToClips);
        blockInfos.InsertLast(wfcBi);
        BlocksById.Insert(bi.Id.Value, wfcBi);
        count += 1;
    }

    WFC_BlockInfo@ FindBlockById(MwId &in id) {
        if (BlocksById is null) return null;
        auto blockInfos = BlocksById.Get(id.Value);
        if (blockInfos is null || blockInfos.Length == 0) {
            NotifyError("Failed to find block by id: " + id.GetName() + " / Lookup has id? " + BlocksById.Has(id.Value));
            return FindBlockByName(id.GetName());
        }
#if DEV
        if (blockInfos.Length != 1) {
            _Log::Error("Found multiple (" +blockInfos.Length+ ") blocks with the same id: " + id.GetName());
            for (uint i = 0; i < blockInfos.Length; i++) {
                auto bi = cast<WFC_BlockInfo@>(blockInfos[i]).refBlockInfo.AsBlockInfo();
                auto fid = GetFidFromNod(bi);
                _Log::Error("Block: " + fid.ParentFolder.FullDirName + "/" + fid.FileName);
            }
            // return null;
        }
#endif
        return cast<WFC_BlockInfo@>(blockInfos[0]);
    }

    WFC_BlockInfo@ FindBlockByName(const string &in name) {
        MwId id;
        id.SetName(name);
        for (uint i = 0; i < blockInfos.Length; i++) {
            if (blockInfos[i].nameId.Value == id.Value) {
                return blockInfos[i];
            }
        }
        return null;
    }

    WFC_BlockInfo@ GetCursorBlock() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        if (selectedBlockInfoAny is null) return null;
        auto bi = selectedBlockInfoAny.AsBlockInfo();
        if (bi is null) return null;
        return FindBlockById(bi.Id);
    }

    WFC_BlockInfo@ GetRandomBlock(int minClips = -1) {
        auto nbBlocks = blockInfos.Length;
        if (nbBlocks == 0) return null;
        WFC_BlockInfo@ blockInfo;
        uint ix;
        uint loopCount = 0;
        while ((blockInfo is null || blockInfo.clips.Length < minClips) && (++loopCount < 10)) {
            ix = Math::Rand(0, nbBlocks);
            @blockInfo = blockInfos[ix];
        }
        return blockInfo;
    }

    WFC_BlockInfo@ GetRandomAdjoiningBlock(int minClips, PlacedBlock@ clipSource, int3 &out coord, CGameEditorPluginMap::ECardinalDirections &out dir) {
        if (clipSource.BlockInfo.clips.Length == 0) return null;
        WFC_ClipInfo@ placedClip = clipSource.GetRandomClip();
        if (placedClip is null) return null;
        int3 c;
        // dir = ChooseCompatibleDirection(clip, clipSource);
        WFC_BlockInfo@ blockInfo;
        WFC_ClipInfo@ clipToPlace;
        uint loopCount = 0;
        //  || blockInfo.clips.Length < minClips
        CardinalDir dirAtCoordOfConnectingClip;
        while (clipToPlace is null || blockInfo is null || blockInfo.clips.Length < minClips) {
            loopCount++;
            if (loopCount > 20) break;
            @placedClip = clipSource.GetRandomClip();
            // @clipToPlace = GetRandomConnectingClipFromClip(placedClip);
            @clipToPlace = FindRandomSnappableClips(placedClip);
            if (clipToPlace is null) continue;

            CardinalDir dir;
            c = clipSource.CalcClipConnectingCoord(placedClip, dir);
            dirAtCoordOfConnectingClip = dir;
            @blockInfo = blockInfos[clipToPlace.biIx];
        }

        if (clipToPlace is null) return null;

        // calc updated coord given rotation
        // if symmetric: flip dir?
        auto _dir = RotateDir(dirAtCoordOfConnectingClip, -clipToPlace.dirFromParent);
        auto revOffset = RotateOffset(clipToPlace.buiOffset, _dir, blockInfo.Size);
        auto newCoord = c - revOffset;
        _Log::Trace("New direction: " + tostring(_dir));
        _Log::Trace("Clip offset: " + clipToPlace.buiOffset.ToString());
        _Log::Trace("Block size: " + blockInfo.Size.ToString());
        _Log::Trace("Coord: " + newCoord.ToString());

        // coord = c + int3(1, -1, 1) * RotateOffset(clipToPlace.buiOffset, _dir, blockInfo.Size);

        coord = newCoord;
        dir = CGameEditorPluginMap::ECardinalDirections(_dir);
        return blockInfo;
    }

    WFC_ClipInfo@[]@ FindSnappableClips(WFC_ClipInfo@ clip, bool expandedMatch = false) {
        ref@[]@[] toJoin;
        // sym groups match to clip groups
        // clip groups match to clip groups
        // no sym id => match `symId <|> cId` to clip id
        auto symGroups = clip.SymGroups;
        if (symGroups.x != -1) {
            toJoin.InsertLast(GroupIdsToClips.Get(symGroups.x));
            toJoin.InsertLast(GroupIdsToClips.Get(symGroups.y));
            if (!expandedMatch) return JoinMatches(toJoin);
        }
        auto clipGroups = clip.ClipGroups;
        if (clipGroups.x != -1) {
            toJoin.InsertLast(GroupIdsToClips.Get(clipGroups.x));
            toJoin.InsertLast(GroupIdsToClips.Get(clipGroups.y));
            if (!expandedMatch) return JoinMatches(toJoin);
        }
        toJoin.InsertLast(clip.symCID != -1 ? SymIdsToClips.Get(clip.symCID) : ClipIdsToClips.Get(clip.cId));
        return JoinMatches(toJoin);
    }

    WFC_ClipInfo@ FindRandomSnappableClips(WFC_ClipInfo@ clip) {
        auto snappableClips = FindSnappableClips(clip);
        if (snappableClips.Length == 0) return null;
        uint ix = Math::Rand(0, snappableClips.Length);
        return snappableClips[ix];
    }

    WFC_ClipInfo@ GetRandomConnectingClipFromClip(WFC_ClipInfo@ clip) {
        auto cg1 = INCLUDE_CG1 ? GroupIdsToClips.Get(clip.symClipGroup1) : null;
        auto cg2 = INCLUDE_CG2 ? GroupIdsToClips.Get(clip.symClipGroup2) : null;
        auto scg1 = INCLUDE_SCG1 ? SymGroupIdsToClips.Get(clip.clipGroup1) : null;
        auto scg2 = INCLUDE_SCG2 ? SymGroupIdsToClips.Get(clip.clipGroup2) : null;
        auto c2scid = INCLUDE_SCID ? ClipIdsToClips.Get(clip.symCID) : null;
        auto s2cid = INCLUDE_ID ? ClipIdsToClips.Get(clip.cId) : null;
        auto cg1Len = cg1 is null ? 0 : cg1.Length;
        auto cg2Len = cg2 is null ? 0 : cg2.Length;
        auto scg1Len = scg1 is null ? 0 : scg1.Length;
        auto scg2Len = scg2 is null ? 0 : scg2.Length;
        auto c2scidLen = c2scid is null ? 0 : c2scid.Length;
        auto s2cidLen = s2cid is null ? 0 : s2cid.Length;
        auto total = cg1Len + cg2Len + scg1Len + scg2Len + c2scidLen + s2cidLen;
        if (total == 0) return null;
        auto cg1Lt = cg1Len, cg2Lt = cg1Lt + cg2Len, scg1Lt = cg2Lt + scg1Len, scg2Lt = scg1Lt + scg2Len, c2scidLt = scg2Lt + c2scidLen, s2cidLt = c2scidLt + s2cidLen;
        // trace("cg1Lt: " + cg1Lt + ", cg2Lt: " + cg2Lt + ", scg1Lt: " + scg1Lt + ", scg2Lt: " + scg2Lt + ", c2scidLt: " + c2scidLt + ", s2cidLt: " + s2cidLt);
        WFC_ClipInfo@ clipInfo;
        uint loopCount = 0;
        while (loopCount < 30) {
            loopCount++;
            uint ix = Math::Rand(0, total);
            trace("Rand block ix: " + ix);
            if (ix < cg1Lt) {
                @clipInfo = cast<WFC_ClipInfo@>(cg1[ix]);
            } else if (ix < cg2Lt) {
                @clipInfo = cast<WFC_ClipInfo@>(cg2[ix - cg1Lt]);
            } else if (ix < scg1Lt) {
                @clipInfo = cast<WFC_ClipInfo@>(scg1[ix - cg2Lt]);
            } else if (ix < scg2Lt) {
                @clipInfo = cast<WFC_ClipInfo@>(scg2[ix - scg1Lt]);
            } else if (ix < c2scidLt) {
                @clipInfo = cast<WFC_ClipInfo@>(c2scid[ix - scg2Lt]);
            } else if (ix < s2cidLt) {
                @clipInfo = cast<WFC_ClipInfo@>(s2cid[ix - c2scidLt]);
            } else {
                warn("Failed to get clip info from index: " + ix);
                continue;
            }
            // if (clipInfo.buiOffset.y == clip.buiOffset.y || clipInfo.distFromTop == clip.distFromTop) {
            //     break;
            // }
            if (clipInfo !is null) break;
        }
        return clipInfo;
        // if (clipInfo is null) return null;
        // auto bi = blockInfos[clipInfo.biIx];
        // trace("Found block info: " + bi.nameId.GetName() + ", Clip: " + clipInfo.biIx + ", " + clipInfo.clipIx);
        // return bi;
    }

    // Initialization

    bool get_IsLoading() { return !ingestionComplete; }
    bool get_IngestionDone() { return ingestionComplete; }

    // Start ingestion. Does nothing after first call.
    BlockInventory@ Start() {
        if (started) return this;
        started = true;
        startnew(CoroutineFunc(LoadBlockInfos));
        return this;
    }

    protected void LoadBlockInfos() {
        auto fidBIC = Fids::GetGameFolder("GameData/Stadium/GameCtnBlockInfo/GameCtnBlockInfoClassic");
        if (fidBIC is null) {
            NotifyWarning("Wave Function Collapse: Failed to load block inventory");
            return;
        }
        ingestionStart = Time::Now;
        IngestFidFolder(fidBIC);
        ingestionDuration = Time::Now - ingestionStart;
        ingestionComplete = true;
    }

    protected void IngestFidFolder(CSystemFidsFolder@ folder) {
        auto nbFiles = folder.Leaves.Length;
        for (uint i = 0; i < nbFiles; i++) {
            auto file = folder.Leaves[i];
            auto bi = cast<CGameCtnBlockInfo>(Fids::Preload(file));
            if (bi is null) _Log::Info("Failed to load block info: " + file.FileName);
            else IngestBlockInfo(bi);
            if (!CheckPause()) return;
        }
        auto nbFolders = folder.Trees.Length;
        for (uint i = 0; i < nbFolders; i++) {
            IngestFidFolder(folder.Trees[i]);
            if (!CheckPause()) return;
        }
    }

    protected uint64 lastSearchPause = 0;
    // return true to keep going; false to break/return
    protected bool CheckPause() {
        if (Time::Now - lastSearchPause > 15) {
            OnProcessPaused();
            yield();
            AfterProcessPaused();
            lastSearchPause = Time::Now;
        }
        return true;
    }
}

// MARK: PlacedBlock

class PlacedBlock {
    WFC_BlockInfo@ BlockInfo;
    int3 Coord;
    CardinalDir Dir;
    private string _asString;

    PlacedBlock(WFC_BlockInfo@ blockInfo, int3 coord, CardinalDir direction) {
        @this.BlockInfo = blockInfo;
        this.Coord = coord;
        this.Dir = direction;
    }

    WFC_ClipInfo@ GetRandomClip() {
        return BlockInfo.GetRandomClip();
    }

    int3 CalcClipConnectingCoord(WFC_ClipInfo@ clip, CardinalDir &out dir) {
        int3 offset = clip.buiOffset;
        // rotate according to this block's direction
        offset = RotateOffset(offset, Dir, BlockInfo.Size);
        // move in the direction of the clip
        auto _dir = RotateDir(Dir, clip.dirFromParent);
        dir = RotateDir(_dir, 2);
        offset = MoveOffset(offset, _dir);
        return Coord + offset;
    }

    string ToString() {
        if (_asString.Length == 0) {
            _asString = "PlacedBlock: " + BlockInfo.nameId.GetName() + ", Coord: " + Coord.ToString() + ", Direction: " + tostring(Dir);
        }
        return _asString;
    }
}


int3 RotateOffset(int3 offset, int dir, int3 blockSize = int3(1)) {
    auto _dir = CardinalDir((dir + 4) % 4);
    if (MathX::Int3Eq(blockSize, int3(1))) {
        switch (_dir) {
            case CardinalDir::North: return offset;
            case CardinalDir::East: return int3(-offset.z, offset.y, offset.x);
            case CardinalDir::South: return int3(-offset.x, offset.y, -offset.z);
            case CardinalDir::West: return int3(offset.z, offset.y, -offset.x);
        }
        return offset;
    }
    // we should treat the offset as *inside* the block and rotate it as though the whole block was rotated on the spot (around its midpoint)
    blockSize = blockSize - int3(1, 0, 1);
    switch (_dir) {
        case CardinalDir::North: return offset;
        case CardinalDir::East: return int3(-offset.z + blockSize.z, offset.y, offset.x);
        case CardinalDir::South: return int3(-offset.x + blockSize.x, offset.y, -offset.z + blockSize.z);
        case CardinalDir::West: return int3(offset.z, offset.y, -offset.x + blockSize.x);
    }
    return offset;
}

int3 MoveOffset(int3 offset, CardinalDir dir, int dist = 1) {
    switch (dir) {
        case CardinalDir::North: return offset + int3(0, 0, dist);
        case CardinalDir::East: return offset + int3(-dist, 0, 0);
        case CardinalDir::South: return offset + int3(0, 0, -dist);
        case CardinalDir::West: return offset + int3(dist, 0, 0);
    }
    return offset;
}

CardinalDir RotateDir(CardinalDir dir, int rot) {
    return CardinalDir((int(dir) + rot + 4) % 4);
}

// MARK: IntLookup


// 4 (2^4 = 16)
const uint INT_LOOKUP_CHILDREN_SHL = 4;
// 16
const uint INT_LOOKUP_CHILDREN = 2 ** INT_LOOKUP_CHILDREN_SHL;


class IntLookup {
    IntLookup@[] children;
    ref@[] values;
    // x = values, y = nodes, z = total
    int2 cachedCount = int2(-1);
    uint nodeKey = -1, nodeId = -1;

    IntLookup() {}

    bool Has(uint key) {
        if (key == -1) return false;
        return Get(key) !is null;
    }

    // Get from the root node.
    ref@[]@ Get(uint key) {
        if (key == -1) return null;
        key = key & 0x00FFFFFF;
        return Get(key, key);
    }

    // Internal get for children.
    ref@[]@ Get(uint key, uint id) {
        if (id == -1) return null;
        // mask out the top 8 bits (mwids)
        id = id & 0x00FFFFFF;
        key = key & 0x00FFFFFF;
        if (id == 0 && nodeKey == key) {
            if (values.Length == 0) return null;
            return values;
        }

        if (children.Length == 0) return null;
        uint childIx = id % INT_LOOKUP_CHILDREN;
        if (children[childIx] is null) return null;
        return children[childIx].Get(key, id >> INT_LOOKUP_CHILDREN_SHL);
    }

    void Insert(uint itemKey, ref@ thing) {
        Insert(itemKey, itemKey, thing);
    }

    // key stays the same, id is manipulated to find the right child
    void Insert(uint itemKey, uint id, ref@ thing) {
        if (id == -1 || itemKey == -1) throw("id/itemKey is -1");
        cachedCount = int2(-1);
        // mask out the top 8 bits (mwids)
        id = id & 0x00FFFFFF;
        itemKey = itemKey & 0x00FFFFFF;

        // if this node matches the item key, we insert it here.
        // we want to double check this because if we insert 0x111 and then 0x11, the latter would have an id of 0 at this point.
        if (id == 0 && nodeKey == itemKey) {
            // no duplicates
            if (values.FindByRef(thing) != -1) return;
            // insert
            values.InsertLast(thing);
            // sets this since it's stable in these conditions.
            nodeKey = itemKey;
            nodeId = id;
            return;
        }

        bool noKids = children.Length == 0;
        bool noValues = values.Length == 0;

        // is this the first item?
        if (noKids && noValues) {
            nodeKey = itemKey;
            nodeId = id;
            values.InsertLast(thing);
            return;
        }

        // after this point, we must insert the item into a child.

        if (noKids) {
            children.Resize(INT_LOOKUP_CHILDREN);
            // when we create children, check to see if we should reset this node's key and id.
            // if we have a key, then we need to move the values to the child.
            // if the nodeKey is -1 then we don't have a key, so we're reset or empty.
            // if our nodeId is 0 then the values belong here. >0 tests for a moveable id.
            if (nodeId > 0 && nodeKey != -1) {
                // move values to children
                auto childIx = nodeId % INT_LOOKUP_CHILDREN;
                @children[childIx] = IntLookup();
                children[childIx].InsertMany(nodeKey, nodeId >> INT_LOOKUP_CHILDREN_SHL, values);
                // clear values
                values.Resize(0);
                nodeId = nodeKey = -1;
            }
        }

        uint childIx = id % INT_LOOKUP_CHILDREN;
        if (children[childIx] is null) {
            @children[childIx] = IntLookup();
        }
        children[childIx].Insert(itemKey, id >> INT_LOOKUP_CHILDREN_SHL, thing);
    }

    void InsertMany(uint itemKey, uint id, ref@[]@ things) {
        for (uint i = 0; i < things.Length; i++) {
            Insert(itemKey, id, things[i]);
        }
    }

    // returns (totalValues, totalNodes)
    int2 Count() {
        if (cachedCount.x != -1) return cachedCount;
        int2 count = int2(0);
        count.x += values.Length;
        count.y = 1;
        if (children.Length > 0) {
            for (uint i = 0; i < INT_LOOKUP_CHILDREN; i++) {
                if (children[i] is null) continue;
                count += children[i].Count();
            }
        }
        cachedCount = count;
        return count;
    }

    // void InitializeChildren(bool force = false) {
    //     if (children.Length > 0 && !force) return;
    //     children.Resize(INT_LOOKUP_CHILDREN);
    //     // for (uint i = 0; i < INT_LOOKUP_CHILDREN; i++) {
    //     //     @children[i] = IntLookup();
    //     // }
    // }
}







#if DEV


void Test_RotateOffset() {
    auto offset = int3(1, 0, 1);
    auto blockSize = int3(2, 0, 2);
    auto dir = CardinalDir::North;
    auto newOffset = RotateOffset(offset, dir, blockSize);
    assert_eq(newOffset, offset, "North = no rotation");
    dir = CardinalDir::East;
    newOffset = RotateOffset(offset, dir, blockSize);
    assert_eq(newOffset, int3(0, 0, 1), "East = -z, +x");
    dir = CardinalDir::South;
    newOffset = RotateOffset(offset, dir, blockSize);
    assert_eq(newOffset, int3(0, 0, 0), "South = -x, -z");
    dir = CardinalDir::West;
    newOffset = RotateOffset(offset, dir, blockSize);
    assert_eq(newOffset, int3(1, 0, 0), "West = +z, -x");
    print("\\$4f4 Test_RotateOffset: Test Passed");
}
Meta::PluginCoroutine@ PC_Test_RotateOffset = startnew(Test_RotateOffset);


#endif
