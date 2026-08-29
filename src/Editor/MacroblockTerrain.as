namespace Editor {
    // Terrain support for macroblocks. See research/MacroblockTerrain.md for the
    // mechanism: mb+0x1F8 is a buffer of CGameCtnAutoTerrain@ (authoritative for
    // placement); a variant copy lives at GeneratedBlockInfo.VariantGround+0x250
    // (used by removal / ground-block placement). Map terrain state is one
    // CGameCtnZoneGenealogy@ per XZ cell at CGameCtnChallenge+0x390.

    // MARK: Terrain capture

    // Build a TerrainSpec from a live CGameCtnAutoTerrain (e.g. an entry of a
    // native macroblock's mb+0x1F8 buffer). Macroblock storage is already
    // normalized to base 0, so no renormalization happens here.
    TerrainSpec@ TerrainSpecFromAutoTerrain(CGameCtnAutoTerrain@ atNod) {
        if (atNod is null || atNod.Genealogy is null) return null;
        auto ts = TerrainSpec();
        ts.offset = int3(atNod.OffsetX, atNod.OffsetY, atNod.OffsetZ);
        SetTerrainSpecFromGenealogy(ts, atNod.Genealogy, 0);
        return ts;
    }

    // Fill zone names/heights + genealogy scalars into ts. normBase is
    // subtracted from all heights (pass the cell's BaseHeight when capturing
    // from the map grid; 0 when reading an already-normalized macroblock entry).
    void SetTerrainSpecFromGenealogy(TerrainSpec@ ts, CGameCtnZoneGenealogy@ gen, int normBase) {
        uint nb = gen.ZoneIds.Length;
        ts.zoneNames.Resize(nb);
        ts.zoneHeights.Resize(nb);
        for (uint i = 0; i < nb; i++) {
            ts.zoneNames[i] = gen.ZoneIds[i].GetName();
            ts.zoneHeights[i] = gen.ZoneHeights[i] - normBase;
        }
        ts.currentIndex = gen.CurrentIndex;
        ts.dir = uint(gen.Dir);
        ts.baseHeight = gen.BaseHeight - normBase;
        ts.bottomHeight = gen.BottomHeight - normBase;
        ts.topHeight = gen.TopHeight - normBase;
    }

    // Signature for default-cell detection: zone names + base-relative heights + dir.
    string GenealogySignature(CGameCtnZoneGenealogy@ gen) {
        string sig = uint(gen.Dir) + "|";
        for (uint i = 0; i < gen.ZoneIds.Length; i++) {
            sig += gen.ZoneIds[i].GetName() + ":" + (gen.ZoneHeights[i] - gen.BaseHeight) + ",";
        }
        return sig;
    }

    // The map's most common genealogy signature = the default (flat) terrain.
    string GetMapDefaultGenealogySignature(DGameCtnChallenge_TerrainCells@ cells) {
        dictionary sigCounts;
        string bestSig = "";
        int64 bestCount = 0;
        for (uint i = 0; i < cells.Length; i++) {
            auto gen = cells.GetTerrainCell(i).Nod;
            if (gen is null) continue;
            string sig = GenealogySignature(gen);
            int64 count = sigCounts.Exists(sig) ? int64(sigCounts[sig]) + 1 : 1;
            sigCounts[sig] = count;
            if (count > bestCount) {
                bestCount = count;
                bestSig = sig;
            }
        }
        return bestSig;
    }

    // Capture terrain cells inside the spec's block/item XZ bounding box from
    // the map's genealogy grid into spec.terrains. Offsets are stored absolute;
    // they are normalized to min XZ at place time. Only cells that differ from
    // the map's default genealogy are captured (matching native macroblocks,
    // which also only store non-default cells).
    void CaptureTerrainIntoSpec(MacroblockSpecPriv@ spec) {
        if (spec is null) return;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Challenge is null) return;
        auto map = editor.Challenge;
        auto minCoord = spec.GetMinBlockCoords();
        auto maxCoord = spec.GetMaxBlockCoords();
        if (maxCoord.x < minCoord.x || maxCoord.z < minCoord.z) return;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
        int3 size = Nat3ToInt3(map.Size);
        string defaultSig = GetMapDefaultGenealogySignature(cells);
        uint captured = 0;
        for (int z = minCoord.z; z <= maxCoord.z; z++) {
            for (int x = minCoord.x; x <= maxCoord.x; x++) {
                if (x < 0 || z < 0 || x >= size.x || z >= size.z) continue;
                uint ix = uint(x) + uint(z) * uint(size.x);
                if (ix >= cells.Length) continue;
                auto gen = cells.GetTerrainCell(ix).Nod;
                if (gen is null) continue;
                if (GenealogySignature(gen) == defaultSig) continue;
                auto ts = TerrainSpec();
                ts.offset = int3(x, 0, z);
                SetTerrainSpecFromGenealogy(ts, gen, gen.BaseHeight);
                spec.terrains.InsertLast(ts);
                captured++;
            }
        }
        dev_trace("CaptureTerrainIntoSpec: captured " + captured + " terrain cells in "
            + minCoord.ToString() + " .. " + maxCoord.ToString());
    }

    // MARK: Zone resolution + fake nod templates

    // Resolves zone id names to live zone nods. Zone nods are shared per
    // collection; the map's genealogy grid is the reliable name source
    // (CompleteZoneList zone ids did not resolve names like "VoidToDirt"
    // on RedIsland, so it is only a fallback).
    class ZoneNodResolver {
        protected dictionary@ byName = dictionary();
        bool ok = false;

        ZoneNodResolver() {
            auto map = GetApp().RootMap;
            if (map is null) return;
            auto cells = DGameCtnChallenge(map).TerrainGenealogies;
            for (uint i = 0; i < cells.Length; i++) {
                auto gen = cells.GetTerrainCell(i).Nod;
                if (gen is null) continue;
                for (uint j = 0; j < gen.Zones.Length; j++) {
                    auto zone = gen.Zones[j];
                    if (zone is null) continue;
                    string name = zone.ZoneId.GetName();
                    if (name.Length > 0 && !byName.Exists(name)) byName.Set(name, @zone);
                }
            }
            if (map.Collection !is null) {
                auto zones = map.Collection.CompleteZoneList;
                for (uint i = 0; i < zones.Length; i++) {
                    auto zone = zones[i];
                    if (zone is null) continue;
                    string name = zone.ZoneId.GetName();
                    if (name.Length > 0 && !byName.Exists(name)) byName.Set(name, @zone);
                }
            }
            ok = true;
        }

        CGameCtnZone@ Find(const string &in name) {
            if (!byName.Exists(name)) return null;
            CGameCtnZone@ zone;
            byName.Get(name, @zone);
            return zone;
        }
    }

    // Any live map-grid genealogy works as a memory template (vtable etc.).
    uint64 GetLiveGenealogyTemplatePtr() {
        auto map = GetApp().RootMap;
        if (map is null) return 0;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
        for (uint i = 0; i < cells.Length; i++) {
            auto cellPtr = cells.GetTerrainCell(i).Ptr;
            if (cellPtr > 0) return cellPtr;
        }
        return 0;
    }

    // Find a live CGameCtnAutoTerrain to use as a memory template. Ground
    // block variants carry AutoTerrains (that's how placing ground blocks
    // terraforms), so scan map blocks first, then inventory block articles.
    uint64 FindLiveAutoTerrainTemplatePtr() {
        auto map = GetApp().RootMap;
        if (map !is null) {
            for (uint i = 0; i < map.Blocks.Length; i++) {
                auto bi = map.Blocks[i].BlockInfo;
                if (bi is null) continue;
                auto vg = bi.VariantBaseGround;
                if (vg is null || vg.AutoTerrains.Length == 0) continue;
                return Dev_GetPointerForNod(vg.AutoTerrains[0]);
            }
        }
        auto inv = Editor::GetInventoryCache();
        if (inv !is null) {
            auto arts = inv.BlockInvNodes;
            for (uint i = 0; i < arts.Length; i++) {
                auto bi = cast<CGameCtnBlockInfo>(arts[i].GetCollectorNod());
                if (bi is null) continue;
                auto vg = bi.VariantBaseGround;
                if (vg is null || vg.AutoTerrains.Length == 0) continue;
                return Dev_GetPointerForNod(vg.AutoTerrains[0]);
            }
        }
        return 0;
    }

    void WriteMwFastBufferHeader(uint64 hdrPtr, uint64 elemsPtr, uint len) {
        Dev::Write(hdrPtr, elemsPtr);
        Dev::Write(hdrPtr + 0x8, uint(len));
        Dev::Write(hdrPtr + 0xC, uint(len));
    }

    // Write one fake CGameCtnAutoTerrain + CGameCtnZoneGenealogy pair.
    // Templates are copied first (vtable + unknown fields), then refcounts are
    // pinned high and all known fields overwritten. The game clones genealogies
    // during apply, so these fakes only need to survive the (async) apply; the
    // owning tmpWriteBuf is intentionally leaked (see LeakTerrainWriteBuf).
    void WriteTerrainEntryToMemory(TerrainSpec@ ts, uint64 atElPtr, uint64 genElPtr,
            uint64 zonesBufPtr, uint64 heightsBufPtr, uint64 idsBufPtr,
            ZoneNodResolver@ resolver, uint64 atTemplatePtr, uint64 genTemplatePtr) {
        Dev_WriteBytes(atElPtr, Dev_ReadBytes(atTemplatePtr, SZ_CTNAUTOTERRAIN));
        Dev_WriteBytes(genElPtr, Dev_ReadBytes(genTemplatePtr, SZ_CTNZONEGENEALOGY));
        Dev::Write(atElPtr + 0x10, uint(0x00010000));
        Dev::Write(genElPtr + 0x10, uint(0x00010000));
        // real macroblock genealogies have zeros at 0x68..0x78; the map-cell
        // template can carry map-specific data there
        Dev::Write(genElPtr + 0x68, uint64(0));
        Dev::Write(genElPtr + 0x70, uint64(0));
        // CGameCtnAutoTerrain: OffsetX/Y/Z @ 0x18/0x1C/0x20, Genealogy @ 0x28
        Dev::Write(atElPtr + 0x18, uint(ts.offset.x));
        Dev::Write(atElPtr + 0x1C, uint(ts.offset.y));
        Dev::Write(atElPtr + 0x20, uint(ts.offset.z));
        Dev::Write(atElPtr + 0x28, genElPtr);
        // CGameCtnZoneGenealogy: zones/heights/ids + scalars
        uint nb = ts.zoneNames.Length;
        CGameCtnZone@ curZone = null;
        for (uint i = 0; i < nb; i++) {
            auto zone = resolver.Find(ts.zoneNames[i]);
            if (zone is null) throw("zone not found in collection: " + ts.zoneNames[i]);
            Dev::Write(zonesBufPtr + i * 0x8, Dev_GetPointerForNod(zone));
            Dev::Write(heightsBufPtr + i * 0x4, uint(ts.zoneHeights[i]));
            Dev::Write(idsBufPtr + i * 0x4, zone.ZoneId.Value);
            if (i == nb - 1) @curZone = zone;
        }
        // CurrentZone is the top zone of the stack (verified on a real
        // macroblock entry: CurrentZone == zones[1] with CurrentIndex == 0)
        Dev::Write(genElPtr + 0x18, Dev_GetPointerForNod(curZone));
        WriteMwFastBufferHeader(genElPtr + 0x20, zonesBufPtr, nb);
        WriteMwFastBufferHeader(genElPtr + 0x30, heightsBufPtr, nb);
        Dev::Write(genElPtr + 0x40, uint(ts.currentIndex));
        Dev::Write(genElPtr + 0x44, uint(ts.dir));
        WriteMwFastBufferHeader(genElPtr + 0x48, idsBufPtr, nb);
        Dev::Write(genElPtr + 0x58, curZone.ZoneId.Value);
        Dev::Write(genElPtr + 0x5C, uint(ts.baseHeight));
        Dev::Write(genElPtr + 0x60, uint(ts.bottomHeight));
        Dev::Write(genElPtr + 0x64, uint(ts.topHeight));
    }

    // MARK: Ground-mode donor placement (terrain pass)

    // Terrain write buffers must outlive the async terrain apply (~1s), so we
    // leak them intentionally (bounded).
    CustomBuffer@[] leakedTerrainWriteBufs;
    void LeakTerrainWriteBuf(CustomBuffer@ buf) {
        if (buf is null) return;
        leakedTerrainWriteBufs.InsertLast(buf);
        while (leakedTerrainWriteBufs.Length > 16) leakedTerrainWriteBufs.RemoveAt(0);
    }

    // The most common cell BaseHeight across the map grid = ground base.
    // Native ground macroblocks only place at placementY = groundBase - 1.
    // Returns -1 when the grid can't be read (callers must abort placement).
    int GetMapGroundBaseHeight() {
        auto map = GetApp().RootMap;
        if (map is null) return -1;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
        if (cells.Length == 0) return -1;
        dictionary counts;
        int64 bestCount = 0;
        int best = 1;
        for (uint i = 0; i < cells.Length; i++) {
            auto gen = cells.GetTerrainCell(i).Nod;
            if (gen is null) continue;
            string k = tostring(gen.BaseHeight);
            int64 count = counts.Exists(k) ? int64(counts[k]) + 1 : 1;
            counts[k] = count;
            if (count > bestCount) {
                bestCount = count;
                best = gen.BaseHeight;
            }
        }
        return best;
    }

    MacroblockSpecPriv@[] _terrainPlaceRestoreQueue;

    // Place just the terrain of a macroblock spec: builds a terrain-only copy,
    // temp-writes the donor's AutoTerrains buffers (blocks/items stay empty so
    // nothing is double-placed), then ground-places the donor at the spec's min
    // terrain XZ. Donor restore is delayed (~2s) because the terrain apply is
    // async and reads mb+0x1F8 after the call.
    bool PlaceMacroblockTerrain(MacroblockSpecPriv@ mbSpec) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (mbSpec is null || editor is null || editor.PluginMapType is null) return false;
        if (mbSpec.terrains.Length == 0) return true;
        auto pmt = editor.PluginMapType;
        CGameCtnMacroBlockInfo@ mb = Editor::ResolveDonorMacroblock(editor, "PlaceMacroblockTerrain");
        if (mb is null) return false;
        auto tspec = MacroblockSpecPriv();
        int3 minCoord = mbSpec.GetMinTerrainCoords();
        tspec.terrainWriteOrigin = minCoord;
        for (uint i = 0; i < mbSpec.terrains.Length; i++) {
            tspec.terrains.InsertLast(mbSpec.terrains[i].Duplicate());
        }
        try {
            tspec._TempWriteToMacroblock(mb, true);
        } catch {
            NotifyWarning("PlaceMacroblockTerrain: exception temp-writing donor macroblock: " + getExceptionInfo());
            try {
                tspec._RestoreMacroblock();
            } catch {
                warn("PlaceMacroblockTerrain: exception restoring donor after temp-write failure: " + getExceptionInfo());
            }
            return false;
        }
        if (tspec.lastTerrainsWritten == 0) {
            // nothing was written (missing templates/zones); do NOT ground-place
            // an empty donor — native ground placement with a stale/empty donor
            // crashed the game on 2026-08-18 (Openplanet.dll AV)
            NotifyWarning("PlaceMacroblockTerrain: 0 terrain entries written; aborting ground placement");
            try {
                tspec._RestoreMacroblock();
            } catch {
                warn("PlaceMacroblockTerrain: exception restoring donor after empty write: " + getExceptionInfo());
            }
            return false;
        }
        int groundBase = GetMapGroundBaseHeight();
        if (groundBase < 1) {
            NotifyWarning("PlaceMacroblockTerrain: could not determine map ground base height; aborting ground placement");
            try {
                tspec._RestoreMacroblock();
            } catch {
                warn("PlaceMacroblockTerrain: exception restoring donor after ground-base failure: " + getExceptionInfo());
            }
            return false;
        }
        // mirror the DeleteMacroblock finding: ground-mode calls no-op while
        // Initialized/Connected are false (temp-write clears them)
        mb.Initialized = true;
        mb.Connected = true;
        int3 placeCoord = int3(minCoord.x, groundBase - 1, minCoord.z);
        bool placed = false;
        auto gbi = mb.GeneratedBlockInfo;
        dev_trace("PlaceMacroblockTerrain: donor GeneratedBlockInfo=" + (gbi !is null)
            + " VariantBaseGround=" + (gbi !is null && gbi.VariantBaseGround !is null)
            + " mbAutoTerrainsLen=" + DGameCtnMacroBlockInfo(mb).AutoTerrains.Length);
        bool canPlace = false;
        try {
            canPlace = pmt.CanPlaceMacroblock(mb, placeCoord, CGameEditorPluginMap::ECardinalDirections::North);
        } catch {
            warn("PlaceMacroblockTerrain: CanPlaceMacroblock exception: " + getExceptionInfo());
        }
        dev_trace("PlaceMacroblockTerrain: ground-placing donor at " + placeCoord.ToString()
            + " with " + tspec.terrains.Length + " terrain cells; canPlace=" + canPlace);
        try {
            placed = pmt.PlaceMacroblock(mb, placeCoord, CGameEditorPluginMap::ECardinalDirections::North);
        } catch {
            NotifyWarning("PlaceMacroblockTerrain: exception placing donor macroblock: " + getExceptionInfo());
        }
        dev_trace("PlaceMacroblockTerrain: PlaceMacroblock returned " + placed);
        // terrain apply is async (~1s) and reads mb+0x1F8; delay the restore
        _terrainPlaceRestoreQueue.InsertLast(tspec);
        if (_terrainPlaceRestoreQueue.Length == 1) startnew(TerrainDonorRestoreLoop);
        return placed;
    }

    // Place ground grid blocks. The air-mode donor refuses any isGround block
    // outright (verified on RedIsland: even a plain OpenTechRoadStraight spec
    // with isGround=true returns placed=false), and a ground-mode donor places
    // them WITHOUT their auto-terrain (mb+0x1F8 is authoritative for donor
    // terraform and carries no per-model entries) — a replayed ground block
    // then lost its terraform and desynced the grid vs the sender. So place
    // natively per block (runs the model's own ground-variant AutoTerrains,
    // reproducing the sender's result); blocks the engine refuses (occupied
    // etc.) fall back to the ground-mode donor, which at least places them.
    bool PlaceMacroblockGroundBlocks(MacroblockSpecPriv@ gspec) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (gspec is null || editor is null || editor.PluginMapType is null) return false;
        if (gspec.Blocks.Length == 0) return true;
        auto pmt = editor.PluginMapType;
        array<BlockSpec@> failedBlocks;
        for (uint i = 0; i < gspec.blocks.Length; i++) {
            auto b = gspec.blocks[i];
            auto info = pmt.GetBlockModelFromName(b.name);
            bool placed = false;
            if (info is null) {
                warn("PlaceMacroblockGroundBlocks: unknown block model: " + b.name);
            } else {
                // spec coords store y-1 (same convention the air pass offsets
                // with its <0,1,0> placement coord)
                int3 c = int3(int(b.coord.x), int(b.coord.y) + 1, int(b.coord.z));
                auto dir = CGameEditorPluginMap::ECardinalDirections(int(b.dir));
                try {
                    placed = pmt.PlaceBlock(info, c, dir);
                } catch {
                    warn("PlaceMacroblockGroundBlocks: PlaceBlock threw for " + b.name + ": " + getExceptionInfo());
                }
                dev_trace("PlaceMacroblockGroundBlocks: native place " + b.name + " @ " + c.ToString() + " dir " + tostring(dir) + " -> " + placed);
            }
            if (!placed) failedBlocks.InsertLast(b);
        }
        // native placement terraforms; resync the diff snapshot once it lands
        ScheduleTerrainSnapshotResync();
        if (failedBlocks.Length == 0) return true;
        dev_trace("PlaceMacroblockGroundBlocks: " + failedBlocks.Length + " native refusals; donor fallback");
        return _PlaceGroundBlocksViaDonor(MacroblockSpecPriv(failedBlocks, array<ItemSpec@> = {}));
    }

    // Ground-mode donor fallback: places the blocks but NOT their terraform.
    bool _PlaceGroundBlocksViaDonor(MacroblockSpecPriv@ gspec) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (gspec is null || editor is null || editor.PluginMapType is null) return false;
        if (gspec.Blocks.Length == 0) return true;
        auto pmt = editor.PluginMapType;
        CGameCtnMacroBlockInfo@ mb = Editor::ResolveDonorMacroblock(editor, "PlaceMacroblockGroundBlocks");
        if (mb is null) return false;
        int groundBase = GetMapGroundBaseHeight();
        if (groundBase < 1) {
            NotifyWarning("PlaceMacroblockGroundBlocks: could not determine map ground base height; aborting");
            return false;
        }
        // the engine adds placeCoord to each block coord, and ground placement
        // only accepts placeCoord.y = groundBase - 1 — so block Y must be
        // stored relative to that (X/Z stay absolute; placeCoord XZ is 0).
        // Duplicate the specs: the handles are shared with the caller's spec.
        for (uint i = 0; i < gspec.blocks.Length; i++) {
            auto b = gspec.blocks[i].Duplicate();
            int by = int(b.coord.y) - (groundBase - 1);
            b.coord.y = by < 0 ? 0 : uint(by);
            @gspec.blocks[i] = b;
        }
        try {
            gspec._TempWriteToMacroblock(mb, true);
        } catch {
            NotifyWarning("PlaceMacroblockGroundBlocks: exception temp-writing donor: " + getExceptionInfo());
            try { gspec._RestoreMacroblock(); } catch { warn("PlaceMacroblockGroundBlocks: restore after temp-write failure: " + getExceptionInfo()); }
            return false;
        }
        // ground-mode calls no-op while Initialized/Connected are false
        // (temp-write clears them)
        mb.Initialized = true;
        mb.Connected = true;
        int3 placeCoord = int3(0, groundBase - 1, 0);
        bool canPlace = false;
        try {
            canPlace = pmt.CanPlaceMacroblock(mb, placeCoord, CGameEditorPluginMap::ECardinalDirections::North);
        } catch {
            warn("PlaceMacroblockGroundBlocks: CanPlaceMacroblock exception: " + getExceptionInfo());
        }
        dev_trace("PlaceMacroblockGroundBlocks: ground-placing " + gspec.Blocks.Length
            + " blocks at " + placeCoord.ToString() + "; canPlace=" + canPlace);
        bool placed = false;
        try {
            placed = pmt.PlaceMacroblock(mb, placeCoord, CGameEditorPluginMap::ECardinalDirections::North);
        } catch {
            NotifyWarning("PlaceMacroblockGroundBlocks: exception placing donor: " + getExceptionInfo());
        }
        dev_trace("PlaceMacroblockGroundBlocks: PlaceMacroblock returned " + placed);
        // ground placement can terraform via the blocks' own ground variants,
        // and that apply is async — delay the donor restore like the terrain pass
        _terrainPlaceRestoreQueue.InsertLast(gspec);
        if (_terrainPlaceRestoreQueue.Length == 1) startnew(TerrainDonorRestoreLoop);
        return placed;
    }

    // Reset a terrain rect to the collection default (WaterHill on RedIsland).
    // Script API: PluginMapType.RemoveTerrainBlocks. RE: wrapper at 0x140f9a2e0
    // calls PlaceTerraformRect with no block model, which writes the map's
    // default genealogy. y may be 0 (script coord convert clamps neg Y).
    bool ResetTerrainRect(int3 start, int3 end) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null) return false;
        return editor.PluginMapType.RemoveTerrainBlocks(start, end);
    }

    bool IsCollectionDefaultTerrainName(const string &in name) {
        // todo: other envs (stadium has grass, etc)
        return name == "WaterHill" || name == "Water" || name == "Grass" || name == "Lake" || name == "Sea";
    }

    // RemoveTerrainBlocks peels one genealogy layer per call (cliff -> dirt ->
    // WaterHill). Repeat until the collection default.
    bool ResetTerrainCoord(int3 c) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null) return false;
        auto pmt = editor.PluginMapType;
        bool any = false;
        for (uint i = 0; i < 16; i++) {
            if (!pmt.RemoveTerrainBlocks(c, c)) return any;
            any = true;
            auto b = pmt.GetBlock(c);
            if (b is null) @b = pmt.GetBlock(int3(c.x, 0, c.z));
            if (b is null || b.BlockInfo is null) return true;
            if (IsCollectionDefaultTerrainName(b.BlockInfo.IdName)) return true;
            c = Nat3ToInt3(Editor::GetBlockCoord(b));
        }
        return any;
    }

    bool ResetTerrainCell(CGameCtnBlock@ block) {
        if (block is null) return false;
        return ResetTerrainCoord(Nat3ToInt3(Editor::GetBlockCoord(block)));
    }

    // Reset every captured (non-default) cell in a macroblock spec.
    bool ResetTerrainFromSpec(MacroblockSpec@ spec) {
        auto mbSpec = cast<MacroblockSpecPriv>(spec);
        if (mbSpec is null) return false;
        if (mbSpec.terrains.Length == 0) return true;
        bool ok = true;
        for (uint i = 0; i < mbSpec.terrains.Length; i++) {
            if (!ResetTerrainCoord(mbSpec.terrains[i].offset)) ok = false;
        }
        return ok;
    }

    void TerrainDonorRestoreLoop() {
        while (_terrainPlaceRestoreQueue.Length > 0) {
            sleep(2000);
            auto spec = _terrainPlaceRestoreQueue[0];
            try {
                spec._RestoreMacroblock();
            } catch {
                warn("TerrainDonorRestoreLoop: exception restoring donor: " + getExceptionInfo());
            }
            _terrainPlaceRestoreQueue.RemoveAt(0);
        }
        // The applies this loop waited on came from remote/API specs, so the
        // grid changes they caused are already known to whoever sent them --
        // resync the snapshot so GetTerrainDiffSpec does not echo them back.
        // (Local edits made during the ~2s window are folded in too; callers
        // diff on a dirty-flag debounce, so this is a bounded blind spot.)
        if (_terrainSnapshotTaken) RefreshTerrainSnapshot();
    }

    bool _terrainResyncScheduled = false;
    // Coalesced "refresh the diff snapshot in ~2s": used after native ground-
    // block replays, whose terraform lands async and must not be diffed back
    // to the peer who sent them.
    void ScheduleTerrainSnapshotResync() {
        if (_terrainResyncScheduled) return;
        _terrainResyncScheduled = true;
        startnew(_TerrainSnapshotResyncSoon);
    }
    void _TerrainSnapshotResyncSoon() {
        sleep(2000);
        _terrainResyncScheduled = false;
        if (_terrainSnapshotTaken) RefreshTerrainSnapshot();
    }

    // MARK: Terrain change tracking (for sync plugins, e.g. map-together)
    //
    // The genealogy grid changes asynchronously (terraform lands ~1s after
    // placement) and terrain "blocks" are invisible to the placement trackers
    // (IsTerrain models are skipped, but set _terrainDirty). Sync flow:
    //   RefreshTerrainSnapshot() on editor/map entry;
    //   poll IsTerrainDirty(), debounce past the async apply, then
    //   GetTerrainDiffSpec() -> terrain-only MacroblockSpec to broadcast.

    bool _terrainDirty = false;
    bool _terrainSnapshotTaken = false;
    array<string> _terrainSnapshotSigs;

    bool IsTerrainDirty() { return _terrainDirty; }
    void ClearTerrainDirty() { _terrainDirty = false; }

    // True while a remote/API terrain apply is still settling (donor restore
    // queue or a scheduled snapshot resync): grid changes seen in this window
    // are someone else's edit landing, not something to broadcast.
    bool IsTerrainResyncPending() {
        return _terrainResyncScheduled || _terrainPlaceRestoreQueue.Length > 0;
    }

    // Full per-cell state, absolute heights (unlike GenealogySignature, which
    // is base-relative for default-cell detection).
    string _TerrainCellSig(CGameCtnZoneGenealogy@ gen) {
        if (gen is null) return "";
        string sig = uint(gen.Dir) + "|" + gen.CurrentIndex + "|" + gen.BaseHeight
            + "|" + gen.BottomHeight + "|" + gen.TopHeight + "|";
        for (uint i = 0; i < gen.ZoneIds.Length; i++) {
            sig += gen.ZoneIds[i].GetName() + ":" + gen.ZoneHeights[i] + ",";
        }
        return sig;
    }

    void RefreshTerrainSnapshot() {
        _terrainSnapshotTaken = false;
        _terrainSnapshotSigs.Resize(0);
        auto map = GetApp().RootMap;
        if (map is null) return;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
        _terrainSnapshotSigs.Resize(cells.Length);
        for (uint i = 0; i < cells.Length; i++) {
            _terrainSnapshotSigs[i] = _TerrainCellSig(cells.GetTerrainCell(i).Nod);
        }
        _terrainSnapshotTaken = true;
        _terrainDirty = false;
    }

    // Cells that differ from the snapshot, as a terrain-only MacroblockSpec
    // (same conventions as CaptureTerrainIntoSpec: absolute XZ offsets,
    // heights normalized by each cell's BaseHeight). Updates the snapshot to
    // the current grid. Returns null when no snapshot was taken or the map is
    // gone; an empty spec when nothing changed.
    MacroblockSpec@ GetTerrainDiffSpec() {
        if (!_terrainSnapshotTaken) return null;
        auto map = GetApp().RootMap;
        if (map is null) return null;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
        auto spec = MacroblockSpecPriv();
        if (cells.Length != _terrainSnapshotSigs.Length) {
            // map changed shape under us; resync rather than diff garbage
            RefreshTerrainSnapshot();
            return spec;
        }
        int sizeX = Nat3ToInt3(map.Size).x;
        if (sizeX <= 0) return null;
        for (uint i = 0; i < cells.Length; i++) {
            auto gen = cells.GetTerrainCell(i).Nod;
            string sig = _TerrainCellSig(gen);
            if (sig == _terrainSnapshotSigs[i]) continue;
            _terrainSnapshotSigs[i] = sig;
            if (gen is null) continue;
            auto ts = TerrainSpec();
            ts.offset = int3(int(i) % sizeX, 0, int(i) / sizeX);
            SetTerrainSpecFromGenealogy(ts, gen, gen.BaseHeight);
            spec.terrains.InsertLast(ts);
        }
        _terrainDirty = false;
        return spec;
    }
}
