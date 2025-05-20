namespace SPlacement {
    // BlockInfo IDs that have been seen (not all get added)
    uint[] seenBlockInfoIds;
    // BI ID. Lookup: BlockInfos -> Mobils -> SPlacements[]
    uint[] blockInfoIds;
    // index(blockInfoId) -> [index(mobilPrefabId or placements)]
    uint[][] blockToMobilIxs;
    // Indentify each mobil; 1:1 with placements (mobils without placements are not included)
    uint[] mobilPrefabIds;
    SPlacementBlockData@[] placements;
    // mobils that we've seen
    uint[] seenMobilIds;

    bool initRunning = false;
    bool initDone = false;

    SPlacementBlockData@[] GetPlacements(const string &in name) { return GetPlacements(StrToMwIdValue(name)); }
    SPlacementBlockData@[] GetPlacements(MwId blockInfoId) { return GetPlacements(blockInfoId.Value); }
    SPlacementBlockData@[] GetPlacements(uint blockInfoIdValue) {
        SPlacementBlockData@[] val;
        auto blockIx = blockInfoIds.Find(blockInfoIdValue);
        if (blockIx == -1) return val;
        auto mobilIxs = blockToMobilIxs[blockIx];
        for (uint i = 0; i < mobilIxs.Length; i++) {
            auto mIx = mobilIxs[i];
            val.InsertLast(placements[mIx]);
        }
        return val;
    }

    uint CountPlacements(uint blockInfoIdValue) {
        auto blockIx = blockInfoIds.Find(blockInfoIdValue);
        if (blockIx == -1) return 0;
        auto mIxs = blockToMobilIxs[blockIx];
        auto count = 0;
        for (uint i = 0; i < mIxs.Length; i++) {
            count += placements[mIxs[i]].layouts.Length;
        }
        return count;
    }

    void InitCoro() {
        if (initRunning) return;
        initRunning = true;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto nbBlocks = map.Blocks.Length;
        for (uint i = 0; i < nbBlocks; i++) {
            IngestBlock(map.Blocks[i]);
            CheckPause();
        }
        initRunning = false;
        initDone = true;
    }

    string BlockIxToName(uint blockIx) {
        if (blockIx >= blockInfoIds.Length) return "Out of range";
        return MwIdValueToStr(blockInfoIds[blockIx]);
    }

    void IngestBlock(CGameCtnBlock& block) {
        // ignore seen
        if (seenBlockInfoIds.Find(block.DescId.Value) != -1) return;
#if DEV
        if (block.DescId.Value != block.BlockInfo.Id.Value) {
            Dev_NotifyWarning("Block ID mismatch: " + block.DescId.Value + " != " + block.BlockInfo.Id.Value);
            throw("Block ID mismatch: " + block.DescId.Value + " != " + block.BlockInfo.Id.Value);
        }
#endif
        seenBlockInfoIds.InsertLast(block.DescId.Value);
        auto blockIx = blockInfoIds.Length;
        auto placementsBefore = placements.Length;
        auto mobilPrefabIdsBefore = mobilPrefabIds.Length;
        blockInfoIds.InsertLast(block.DescId.Value);
        blockToMobilIxs.InsertLast({});
        IngestBlockInfo(block.BlockInfo, blockIx);
        if (placementsBefore == placements.Length) {
            // no placements added
            blockInfoIds.RemoveLast();
            blockToMobilIxs.RemoveLast();
            mobilPrefabIds.RemoveRange(mobilPrefabIdsBefore, mobilPrefabIds.Length - mobilPrefabIdsBefore);
        }
    }

    void IngestBlockInfo(CGameCtnBlockInfo@ blockInfo, uint blockIx) {
        nat2 mmpt = Dev::GetOffsetNat2(blockInfo, O_BLOCKINFO_MATMODPLACEMENTTAG);
        IngestVariant(blockInfo.VariantBaseAir, blockIx, mmpt);
        IngestVariant(blockInfo.VariantBaseGround, blockIx, mmpt);
        for (uint i = 0; i < blockInfo.AdditionalVariantsAir.Length; i++) {
            IngestVariant(blockInfo.AdditionalVariantsAir[i], blockIx, mmpt);
        }
        for (uint i = 0; i < blockInfo.AdditionalVariantsGround.Length; i++) {
            IngestVariant(blockInfo.AdditionalVariantsGround[i], blockIx, mmpt);
        }
    }

    void IngestVariant(CGameCtnBlockInfoVariant@ variant, uint blockIx, nat2 mmpt) {
        if (variant.Mobils00.Length > 0) IngestMobils(00, variant.Mobils00, blockIx, mmpt);
        if (variant.Mobils01.Length > 0) IngestMobils(01, variant.Mobils01, blockIx, mmpt);
        if (variant.Mobils02.Length > 0) IngestMobils(02, variant.Mobils02, blockIx, mmpt);
        if (variant.Mobils03.Length > 0) IngestMobils(03, variant.Mobils03, blockIx, mmpt);
        if (variant.Mobils04.Length > 0) IngestMobils(04, variant.Mobils04, blockIx, mmpt);
        if (variant.Mobils05.Length > 0) IngestMobils(05, variant.Mobils05, blockIx, mmpt);
        if (variant.Mobils06.Length > 0) IngestMobils(06, variant.Mobils06, blockIx, mmpt);
        if (variant.Mobils07.Length > 0) IngestMobils(07, variant.Mobils07, blockIx, mmpt);
        if (variant.Mobils08.Length > 0) IngestMobils(08, variant.Mobils08, blockIx, mmpt);
        if (variant.Mobils09.Length > 0) IngestMobils(09, variant.Mobils09, blockIx, mmpt);
        if (variant.Mobils10.Length > 0) IngestMobils(10, variant.Mobils10, blockIx, mmpt);
        if (variant.Mobils11.Length > 0) IngestMobils(11, variant.Mobils11, blockIx, mmpt);
        if (variant.Mobils12.Length > 0) IngestMobils(12, variant.Mobils12, blockIx, mmpt);
        if (variant.Mobils13.Length > 0) IngestMobils(13, variant.Mobils13, blockIx, mmpt);
        if (variant.Mobils14.Length > 0) IngestMobils(14, variant.Mobils14, blockIx, mmpt);
        if (variant.Mobils15.Length > 0) IngestMobils(15, variant.Mobils15, blockIx, mmpt);
    }

    bool[] seenMobils = array<bool>(16, false);

    void IngestMobils(uint mobilIx, MwFastBuffer<CMwNod@> &in mobils, uint blockIx, nat2 mmpt) {
        seenMobils[mobilIx] = true;
        for (uint i = 0; i < mobils.Length; i++) {
            IngestMobil(cast<CGameCtnBlockInfoMobil>(mobils[i]), blockIx, mmpt);
        }
    }

    void IngestMobil(CGameCtnBlockInfoMobil@ mobil, uint blockIx, nat2 mmpt) {
        if (mobil is null) {
            Dev_NotifyWarning("IngestMobil: mobil is null for block: " + BlockIxToName(blockIx));
            return;
        }
        auto fid = cast<CSystemFidFile>(mobil.PrefabFid);
        if (fid is null) {
            Dev_NotifyWarning("IngestMobil: fid is null for block: " + BlockIxToName(blockIx));
            return;
        }
        // calc the id
        auto mobilId = PrefabFid_Id(fid);
        // add to mobils if we haven't seen it.
        bool foundMobil = seenMobilIds.Find(mobilId.Value) != -1;
        if (!foundMobil) seenMobilIds.InsertLast(mobilId.Value);
        // even if we've seen it, we might need to add it to the block
        auto mobilIx = mobilPrefabIds.Find(mobilId.Value);
        if (foundMobil) {
            // if we have seen it, but it isn't in mobilPrefabIds, then it doesn't contain placements
            if (mobilIx == -1) return;
            // otherwise, add the mobil to the block
            blockToMobilIxs[blockIx].InsertLast(mobilIx);
            return;
        }
        // since we haven't seen it, then add it to the list
        mobilIx = IngestMobilPrefab(fid, mobilId, mmpt);
        if (mobilIx == -1) return;
        // and the block
        blockToMobilIxs[blockIx].InsertLast(mobilIx);
    }

    // returns index of the mobil in the list
    uint IngestMobilPrefab(CSystemFidFile@ fid, MwId mobilId, nat2 mmpt) {
        // add the mobil to the list
        auto mobilIx = mobilPrefabIds.Length;
        if (mobilPrefabIds.Length != placements.Length) throw("IngestMobilPrefab: mobilPrefabIds.Length != placements.Length");
        auto placementData = SPlacementBlockData_FromFid(fid, mobilIx, mmpt);
        if (placementData is null) {
            Dev_NotifyWarning("IngestMobilPrefab: placementData is null for mobilId: " + mobilId.Value);
            return -1;
        }
        if (placementData.layouts.Length == 0) return -1;
        mobilPrefabIds.InsertLast(mobilId.Value);
        placements.InsertLast(placementData);
        return mobilIx;
    }

    MwId PrefabFid_Id(CSystemFidFile@ fid) {
        // remove .Prefab.Gbx
        string name = fid.FileName.SubStr(0, fid.FileName.Length - 11);
        // e.g., "blah\Trackmania\GameData\Stadium\Media\Prefab\DecoPlatform\"  => "DecoPlatform\"
        string parent = StrArr_Last(string(fid.ParentFolder.FullDirName).Split("\\Stadium\\Media\\Prefab\\"));
        MwId id = MwId();
        id.SetName(parent + name);
        return id;
    }


    SPlacementBlockData@ SPlacementBlockData_FromFid(CSystemFidFile@ fid, uint mobilIx, nat2 mmpt) {
        auto prefab = cast<CPlugPrefab>(Fids::Preload(fid));
        if (prefab is null) return null;
        auto bimExtra = Blocks::BlockInfoMobilExtra(prefab);
        return SPlacementBlockData(bimExtra, mobilIx, mmpt);
    }


    class SPlacementBlockData {
        // index in main arrays (mobil and placements)
        uint ix;
        // each block has a number of patterns cycled through with RMB
        SP_Layout@[] layouts;
        /* tags are (name, value) pairs of properties (usually about whether items apply to this block).
           See ItemPlace_StringConsts::LookupJoined
        */
        nat2 MatModPlacementTag;
        Blocks::BlockInfoMobilExtra@ bim;

        SPlacementBlockData(Blocks::BlockInfoMobilExtra@ bimExtra, uint mobilIx, nat2 mmpt) {
            ix = mobilIx;
            // ItemPlace_StringConsts::Lookup(mmpt) => "Grass", "Snow", "Dirt" (terrain since from MatModPT)
            MatModPlacementTag = mmpt;
            @bim = bimExtra;
            for (uint i = 0; i < bimExtra.SPlacements.Length; i++) {
                AddPlacement(i, bimExtra.SPlacements[i]);
            }
            // // get the tags
            // auto nbPlacements = bimExtra.SPlacements.Length;
            // if (nbPlacements == 0) return;
            // for (uint i = 0; i < nbPlacements; i++) {
            //     AddPlacement(bimExtra.SPlacements[i]);
            // }
        }

        void AddPlacement(uint i, Blocks::ItemSPlacement& p) {
            while (p.iLayout >= layouts.Length) layouts.InsertLast(SP_Layout(layouts.Length));
            layouts[p.iLayout].Add(i, p);
        }
    }

    class SP_Layout {
        // layout index
        uint iLayout;
        uint[] sPlacementIx;
        // nat2[] tags;

        SP_Layout(uint layoutIx) {
            iLayout = layoutIx;
        }

        void Add(uint pIx, Blocks::ItemSPlacement& p) {
            iLayout = p.iLayout;
            sPlacementIx.InsertLast(pIx);
        }

        uint PlacementCount() {
            return sPlacementIx.Length;
        }

        Blocks::ItemSPlacement& GetPlacement(Blocks::BlockInfoMobilExtra& bim, uint i) {
            if (i >= sPlacementIx.Length) throw("GetPlacement: i out of range");
            return bim.SPlacements[sPlacementIx[i]];
        }
    }
}



string StrArr_Last(const string[] &in arr) {
    if (arr.Length == 0) return "";
    return arr[arr.Length - 1];
}
