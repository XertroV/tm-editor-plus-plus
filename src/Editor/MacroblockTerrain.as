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
        int3 size = map.Size;
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

    // Resolves zone id names to live zone nods of the map's collection
    // (zone nods are shared per collection; CompleteZoneList has them all).
    class ZoneNodResolver {
        protected dictionary@ byName = dictionary();
        bool ok = false;

        ZoneNodResolver() {
            auto map = GetApp().RootMap;
            if (map is null || map.Collection is null) return;
            auto zones = map.Collection.CompleteZoneList;
            for (uint i = 0; i < zones.Length; i++) {
                auto zone = zones[i];
                if (zone is null) continue;
                byName.Set(zone.ZoneId.GetName(), @zone);
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
        // CGameCtnAutoTerrain: OffsetX/Y/Z @ 0x18/0x1C/0x20, Genealogy @ 0x28
        Dev::Write(atElPtr + 0x18, uint(ts.offset.x));
        Dev::Write(atElPtr + 0x1C, uint(ts.offset.y));
        Dev::Write(atElPtr + 0x20, uint(ts.offset.z));
        Dev::Write(atElPtr + 0x28, genElPtr);
        // CGameCtnZoneGenealogy: zones/heights/ids + scalars
        uint nb = ts.zoneNames.Length;
        uint curIx = Math::Min(ts.currentIndex, nb - 1);
        CGameCtnZone@ curZone = null;
        for (uint i = 0; i < nb; i++) {
            auto zone = resolver.Find(ts.zoneNames[i]);
            if (zone is null) throw("zone not found in collection: " + ts.zoneNames[i]);
            Dev::Write(zonesBufPtr + i * 0x8, Dev_GetPointerForNod(zone));
            Dev::Write(heightsBufPtr + i * 0x4, uint(ts.zoneHeights[i]));
            Dev::Write(idsBufPtr + i * 0x4, zone.ZoneId.Value);
            if (i == curIx) @curZone = zone;
        }
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
    int GetMapGroundBaseHeight() {
        auto map = GetApp().RootMap;
        if (map is null) return 1;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
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
        // mirror the DeleteMacroblock finding: ground-mode calls no-op while
        // Initialized/Connected are false (temp-write clears them)
        mb.Initialized = true;
        mb.Connected = true;
        int3 placeCoord = int3(minCoord.x, GetMapGroundBaseHeight() - 1, minCoord.z);
        bool placed = false;
        dev_trace("PlaceMacroblockTerrain: ground-placing donor at " + placeCoord.ToString()
            + " with " + tspec.terrains.Length + " terrain cells");
        try {
            placed = pmt.PlaceMacroblock(mb, placeCoord, CGameEditorPluginMap::ECardinalDirections::North);
        } catch {
            NotifyWarning("PlaceMacroblockTerrain: exception placing donor macroblock: " + getExceptionInfo());
        }
        // terrain apply is async (~1s) and reads mb+0x1F8; delay the restore
        _terrainPlaceRestoreQueue.InsertLast(tspec);
        if (_terrainPlaceRestoreQueue.Length == 1) startnew(TerrainDonorRestoreLoop);
        return placed;
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
    }
}
