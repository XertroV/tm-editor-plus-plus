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

    // Signature for default-cell detection and target matching: dir + surface
    // height + current index + zone names/heights, all base-relative. The
    // surface height (TopHeight) is load-bearing: the Frontier carve and Flat
    // fill gestures produce identical zone stacks that differ only in it.
    string GenealogySignature(CGameCtnZoneGenealogy@ gen) {
        string sig = uint(gen.Dir) + "|" + (gen.TopHeight - gen.BaseHeight) + "|" + gen.CurrentIndex + "|";
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
                uint ix = _TerrainCellIx(x, z, size.z);
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

    // Every pass (air, ground, terrain, delete) shares ONE donor macroblock,
    // and terrain/ground passes restore it on a ~2s delay. Temp-writing while
    // a restore is pending snapshots the polluted variant state, and the
    // interleaved restores then re-leak variant AutoTerrains into a later
    // air-mode place — which crashes the game (observed live 2026-08-29).
    // Callers wait here before touching the donor.
    void WaitForDonorRestores() {
        while (_terrainPlaceRestoreQueue.Length > 0) yield();
    }

    // Place just the terrain of a macroblock spec: builds a terrain-only copy,
    // temp-writes the donor's AutoTerrains buffers (blocks/items stay empty so
    // nothing is double-placed), then ground-places the donor at the spec's min
    // terrain XZ. Donor restore is delayed (~2s) because the terrain apply is
    // async and reads mb+0x1F8 after the call.
    // sig of a TerrainSpec in GenealogySignature's format (base-relative), so
    // spec targets can be compared against live grid cells
    string TerrainSpecSignature(TerrainSpec@ ts) {
        string sig = ts.dir + "|" + (ts.topHeight - ts.baseHeight) + "|" + ts.currentIndex + "|";
        for (uint i = 0; i < ts.zoneNames.Length; i++) {
            sig += ts.zoneNames[i] + ":" + (ts.zoneHeights[i] - ts.baseHeight) + ",";
        }
        return sig;
    }

    bool PlaceMacroblockTerrain(MacroblockSpecPriv@ mbSpec) {
        WaitForDonorRestores();
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (mbSpec is null || editor is null || editor.PluginMapType is null || editor.Challenge is null) return false;
        if (mbSpec.terrains.Length == 0) return true;
        // Remote applies run under capture suppression: their grid changes are
        // already known to whoever sent them, so swallow them from the diff
        // snapshot. A LOCAL terrain apply (user placing a terrain-carrying
        // macroblock / API call) must broadcast, so leave the dirty flag to
        // settle into a diff.
        bool applyIsRemote = IsCaptureSuppressed();
        auto pmt = editor.PluginMapType;
        auto map = editor.Challenge;
        // Fast path: when every cell already matches its target (the common
        // case -- the ground-block replay preceding this diff terraformed the
        // same cells), there is nothing to peel, so no need to wait for the
        // engine job queue at all.
        bool anyWork = false;
        for (uint i = 0; i < mbSpec.terrains.Length; i++) {
            auto ts = mbSpec.terrains[i];
            string curSig = _CurrentCellSig(map, ts.offset.x, ts.offset.z);
            if (curSig != "" && curSig != TerrainSpecSignature(ts)) { anyWork = true; break; }
        }
        if (!anyWork) {
            dev_trace("PlaceMacroblockTerrain: " + mbSpec.terrains.Length + " cells all match; no-op @f" + Time::FrameCount);
            return true;
        }
        // never peel while an engine terraform job may still be in flight:
        // concurrent remove-vs-build has wedged the engine's terrain job
        // queue for the rest of the session (observed live 2026-08-29)
        uint quietWaitStart = Time::Now;
        while (Time::Now < _lastTerrainActivityAt + 300 && Time::Now < quietWaitStart + 8000) yield();

        // NATIVE-ONLY apply. In the vista editors terrain can only be RAISED
        // by three primitives (research/MacroblockTerrain.md +
        // research/2026-08-30-TerrainPlacementRE.md):
        //   - RemoveTerrainBlocks peels to any truncation of the current
        //     stack (block-made or tool-made lowers),
        //   - PlaceTerrainBlocks re-creates tool-made states: a genealogy's
        //     zone names ARE terrain block model names, and the script API
        //     reaches the terrain tool's own native routine (it type-gates
        //     on CGameCtnBlockInfoFrontier/Flat models and enforces minimum
        //     region sizes, e.g. 2x2 for the vista land/hill models) -- see
        //     _ReconstructTerrainViaNativePlace,
        //   - ground-block AutoTerrain raises are recreated by the
        //     ground-block replay that precedes this diff in the stream.
        string defaultSig = GetMapDefaultGenealogySignature(DGameCtnChallenge(map).TerrainGenealogies);
        uint nbMatched = 0, nbResetOnly = 0, nbPeelMatched = 0, nbDeferred = 0;
        array<TerrainSpec@> deferredCells;
        for (uint i = 0; i < mbSpec.terrains.Length; i++) {
            auto ts = mbSpec.terrains[i];
            string targetSig = TerrainSpecSignature(ts);
            int3 c = int3(ts.offset.x, 0, ts.offset.z);
            string curSig = _CurrentCellSig(map, c.x, c.z);
            if (curSig == "") continue;
            if (curSig == targetSig) { nbMatched++; continue; }
            if (targetSig == defaultSig) {
                ResetTerrainCoord(c);
                nbResetOnly++;
                continue;
            }
            // Peeling only TRUNCATES the live stack: a target that tops out
            // above the live cell, or that needs at least as many zones as the
            // live stack has (equal length = a dir/height-only mismatch), is
            // provably not peel-reachable. Bail before touching the cell --
            // attempting anyway strips it toward default (and burns ~40 frames
            // per attempt) before concluding deferred.
            auto curGen = _CurrentCellGen(map, c.x, c.z);
            if (curGen !is null && (ts.topHeight - ts.baseHeight > curGen.TopHeight - curGen.BaseHeight
                    || ts.zoneNames.Length >= curGen.ZoneIds.Length)) {
                nbDeferred++;
                deferredCells.InsertLast(ts);
                continue;
            }
            bool matched = false;
            for (uint attempt = 0; attempt < 8; attempt++) {
                if (!pmt.RemoveTerrainBlocks(int3(c.x, 0, c.z), int3(c.x, 40, c.z))) break;
                string newSig = curSig;
                for (uint w = 0; w < 40; w++) {
                    yield();
                    newSig = _CurrentCellSig(map, c.x, c.z);
                    if (newSig != curSig) break;
                }
                if (newSig == targetSig) { matched = true; break; }
                if (newSig == curSig) break; // fixed point; peeling does nothing more
                curSig = newSig;
            }
            if (matched) nbPeelMatched++;
            else {
                nbDeferred++;
                deferredCells.InsertLast(ts);
            }
        }
        uint nbNativeRaised = 0;
        if (deferredCells.Length > 0) {
            // let this apply's own peels/resets settle before placing
            uint reconWait = Time::Now;
            while (Time::Now < _lastTerrainActivityAt + 300 && Time::Now < reconWait + 8000) yield();
            nbNativeRaised = _ReconstructTerrainViaNativePlace(pmt, map, deferredCells);
        }
        dev_trace("PlaceMacroblockTerrain: " + mbSpec.terrains.Length + " cells -> "
            + nbMatched + " matched, " + nbResetOnly + " reset, " + nbPeelMatched
            + " peeled, " + nbNativeRaised + " native-placed, "
            + (nbDeferred > nbNativeRaised ? nbDeferred - nbNativeRaised : 0) + " deferred @f" + Time::FrameCount);
        // peels fired terrain-block hooks; for a remote apply make sure the
        // diff snapshot resyncs (scoped to these cells) instead of
        // broadcasting them back
        if (applyIsRemote) {
            for (uint i = 0; i < mbSpec.terrains.Length; i++) {
                MarkTerrainResyncCells(mbSpec.terrains[i].offset.x, mbSpec.terrains[i].offset.z);
            }
            ScheduleTerrainSnapshotResync();
        }
        return true;
    }

    // Native terrain reconstruction for targets peeling can't reach. A
    // genealogy's zone names are terrain block model names, so "base + one
    // zone" targets are re-created by the terrain tool's own native placement
    // (research/2026-08-30-TerrainPlacementRE.md). Most of a gesture's
    // footprint is engine-DERIVED from its neighbors rather than directly
    // placeable (support rings around hills, slope dirs around carves), so
    // the rebuild runs in ordered passes with a live recheck between each:
    //   1. hills (relTop >= 2), tallest first -- their smoothing recreates
    //      the 1-wide support rings that arrive as unplaceable thin strips;
    //   2. land-level fills (relTop == 1) with the Flat model, 1-wide rects
    //      widened into adjacent live land cells so the model's >= 2x2
    //      minimum is satisfiable (idempotent for the widened cells);
    //   3. carves: a pond dug into land leaves a patch of slope cells whose
    //      dirs no flat gesture can express; the original carve rect is the
    //      mismatch region's bounding box eroded by one, and re-carving it
    //      lets the engine re-derive the slopes.
    // A second round strips survivors to default and rebuilds from scratch.
    // Returns the number of work cells whose live state matches its target.
    uint _ReconstructTerrainViaNativePlace(CGameEditorPluginMap@ pmt, CGameCtnChallenge@ map, array<TerrainSpec@>@ cells) {
        CGameCtnBlockInfo@ flatModel = null;
        for (uint i = 0; i < pmt.TerrainBlockModels.Length; i++) {
            if (cast<CGameCtnBlockInfoFlat>(pmt.TerrainBlockModels[i]) !is null) {
                @flatModel = pmt.TerrainBlockModels[i];
                break;
            }
        }
        array<ReconCell@> work;
        for (uint i = 0; i < cells.Length; i++) {
            auto ts = cells[i];
            // phase 1: tool-gesture stacks -- the base zone alone (a fill's
            // interior cell) or base + one zone; deeper stacks stay deferred
            if (ts.zoneNames.Length < 1 || ts.zoneNames.Length > 2) continue;
            string zName = ts.zoneNames[ts.zoneNames.Length - 1];
            if (pmt.GetTerrainBlockModelFromName(zName) is null && flatModel is null) continue;
            auto rc = ReconCell();
            rc.x = ts.offset.x;
            rc.z = ts.offset.z;
            rc.zone = zName;
            rc.relTop = ts.topHeight - ts.baseHeight;
            rc.dir = int(ts.dir);
            rc.targetSig = TerrainSpecSignature(ts);
            work.InsertLast(rc);
        }
        if (work.Length == 0) return 0;
        uint remaining = _ReconRecheck(map, work);
        for (uint round = 0; round < 2 && remaining > 0; round++) {
            if (round == 1) {
                // last resort: strip survivors to default and rebuild from scratch
                for (uint i = 0; i < work.Length; i++) {
                    if (!work[i].done) ResetTerrainCoord(int3(work[i].x, 0, work[i].z));
                }
                _ReconAwaitSettle();
                remaining = _ReconRecheck(map, work);
                if (remaining == 0) break;
            }
            _ReconPassHills(pmt, map, work);
            remaining = _ReconRecheck(map, work);
            if (remaining == 0) break;
            _ReconPassFills(pmt, map, work, flatModel);
            remaining = _ReconRecheck(map, work);
            if (remaining == 0) break;
            _ReconPassCarves(pmt, map, work);
            remaining = _ReconRecheck(map, work);
        }
        dev_trace("[TerrainRecon] " + (work.Length - remaining) + "/" + work.Length
            + " cells reconstructed" + (remaining > 0 ? " (" + remaining + " unresolved)" : ""));
        return work.Length - remaining;
    }

    class ReconCell {
        int x, z;
        string zone;    // last zone name: the gesture's terrain model name
        int relTop;     // target surface height above base
        int dir;        // target slope dir (0 = flat)
        string targetSig;
        bool done = false;
    }

    // Re-verify not-done work cells against the live grid; returns how many
    // still mismatch. Passes claim cells only through this, never locally.
    uint _ReconRecheck(CGameCtnChallenge@ map, array<ReconCell@>@ work) {
        uint remaining = 0;
        for (uint i = 0; i < work.Length; i++) {
            if (work[i].done) continue;
            if (_CurrentCellSig(map, work[i].x, work[i].z) == work[i].targetSig) work[i].done = true;
            else remaining++;
        }
        return remaining;
    }

    void _ReconAwaitSettle() {
        uint start = Time::Now;
        while (Time::Now < _lastTerrainActivityAt + 250 && Time::Now < start + 4000) yield();
    }

    // pass 1: hill targets (relTop >= 2) via their zone-name model, tallest
    // first so a taller hill's smoothing settles before shorter neighbors.
    void _ReconPassHills(CGameEditorPluginMap@ pmt, CGameCtnChallenge@ map, array<ReconCell@>@ work) {
        array<string> names;
        array<int> tops;
        for (uint i = 0; i < work.Length; i++) {
            auto rc = work[i];
            if (rc.done || rc.relTop < 2) continue;
            bool seen = false;
            for (uint g = 0; g < names.Length; g++) {
                if (names[g] == rc.zone && tops[g] == rc.relTop) { seen = true; break; }
            }
            if (!seen) { names.InsertLast(rc.zone); tops.InsertLast(rc.relTop); }
        }
        for (uint g = 0; g < names.Length; g++) {
            uint best = g;
            for (uint j = g + 1; j < names.Length; j++) {
                if (tops[j] > tops[best]) best = j;
            }
            if (best != g) {
                string tn = names[g]; names[g] = names[best]; names[best] = tn;
                int tt = tops[g]; tops[g] = tops[best]; tops[best] = tt;
            }
            _ReconRecheck(map, work);
            _ReconPlaceGroupRects(pmt, map, work, names[g], tops[g], names[g], false);
        }
    }

    // pass 2: land-level fills, grouped by relTop ALONE -- one fill gesture
    // produces base-zone-only interior cells and shore-zone edge cells
    // together, and splitting them leaves an unplaceable ring. The zone name
    // of a fill edge is the Frontier shore (which as a MODEL is the carve
    // gesture), so place with the env's Flat model when there is one.
    void _ReconPassFills(CGameEditorPluginMap@ pmt, CGameCtnChallenge@ map, array<ReconCell@>@ work, CGameCtnBlockInfo@ flatModel) {
        string mName = "";
        if (flatModel !is null) mName = flatModel.IdName;
        else {
            for (uint i = 0; i < work.Length; i++) {
                if (work[i].done || work[i].relTop != 1) continue;
                if (pmt.GetTerrainBlockModelFromName(work[i].zone) !is null) { mName = work[i].zone; break; }
            }
        }
        if (mName == "") return;
        _ReconPlaceGroupRects(pmt, map, work, "", 1, mName, true);
    }

    // pass 3: surviving low cells are carve states (slope dirs / water
    // centers) no flat gesture expresses. Re-carve each connected mismatch
    // region's eroded bounding box with the zone's own (Frontier) model. A
    // rect that would land on live-raised terrain is a mis-inference (e.g.
    // the annulus around an unresolved hill erodes onto the hill): skip it.
    void _ReconPassCarves(CGameEditorPluginMap@ pmt, CGameCtnChallenge@ map, array<ReconCell@>@ work) {
        dictionary remain; // key -> 0 (unvisited) / 1 (claimed by a region)
        for (uint i = 0; i < work.Length; i++) {
            auto rc = work[i];
            // flat land-level mismatches are never carve evidence -- carving
            // them would sink terrain a fill pass failed to raise
            if (!rc.done && rc.relTop <= 1 && (rc.dir != 0 || rc.relTop == 0)) {
                remain.Set("" + (uint(rc.x) << 16 | uint(rc.z)), 0);
            }
        }
        for (uint i = 0; i < work.Length; i++) {
            auto rc = work[i];
            if (rc.done || rc.relTop > 1 || (rc.dir == 0 && rc.relTop != 0)) continue;
            if (!_ReconCellUnused(remain, rc.x, rc.z)) continue;
            // flood the 4-connected mismatch region, tracking its bounds
            array<uint> queue = { uint(rc.x) << 16 | uint(rc.z) };
            remain.Set("" + queue[0], 1);
            int x0 = rc.x, x1 = rc.x, z0 = rc.z, z1 = rc.z;
            while (queue.Length > 0) {
                int cx = int(queue[queue.Length - 1] >> 16), cz = int(queue[queue.Length - 1] & 0xFFFF);
                queue.RemoveLast();
                if (cx < x0) x0 = cx;
                if (cx > x1) x1 = cx;
                if (cz < z0) z0 = cz;
                if (cz > z1) z1 = cz;
                for (uint n = 0; n < 4; n++) {
                    int nx = cx + (n == 0 ? 1 : n == 1 ? -1 : 0);
                    int nz = cz + (n == 2 ? 1 : n == 3 ? -1 : 0);
                    if (!_ReconCellUnused(remain, nx, nz)) continue;
                    remain.Set("" + (uint(nx) << 16 | uint(nz)), 1);
                    queue.InsertLast(uint(nx) << 16 | uint(nz));
                }
            }
            int cx0 = x0, cx1 = x1, cz0 = z0, cz1 = z1;
            if (cx1 - cx0 >= 2) { cx0++; cx1--; }
            if (cz1 - cz0 >= 2) { cz0++; cz1--; }
            bool onRaised = false;
            for (int zz = cz0; zz <= cz1 && !onRaised; zz++) {
                for (int xx = cx0; xx <= cx1; xx++) {
                    auto gen = _CurrentCellGen(map, xx, zz);
                    if (gen !is null && gen.TopHeight - gen.BaseHeight >= 2) { onRaised = true; break; }
                }
            }
            if (onRaised) {
                dev_trace("[TerrainRecon] carve <" + cx0 + "," + cz0 + ">..<" + cx1 + "," + cz1
                    + "> skipped (rect sits on raised terrain)");
                continue;
            }
            string mName = rc.zone;
            if (pmt.GetTerrainBlockModelFromName(mName) is null) {
                for (uint j = 0; j < work.Length; j++) {
                    if (work[j].done || work[j].relTop > 1) continue;
                    if (pmt.GetTerrainBlockModelFromName(work[j].zone) !is null) { mName = work[j].zone; break; }
                }
            }
            _ReconPlaceRect(pmt, map, mName, cx0, cz0, cx1 - cx0 + 1, cz1 - cz0 + 1);
        }
    }

    // Greedy maximal rectangles over the not-done work cells of (zone,
    // relTop), placed with modelName. widenForMin grows 1-wide rects into an
    // adjacent row/col of live land-level cells (fill pass only).
    void _ReconPlaceGroupRects(CGameEditorPluginMap@ pmt, CGameCtnChallenge@ map,
            array<ReconCell@>@ work, const string &in zone, int relTop,
            const string &in modelName, bool widenForMin) {
        dictionary inSet;
        array<uint> keys;
        for (uint i = 0; i < work.Length; i++) {
            auto rc = work[i];
            if (rc.done || (zone != "" && rc.zone != zone) || rc.relTop != relTop) continue;
            uint k = uint(rc.x) << 16 | uint(rc.z);
            inSet.Set("" + k, 0);
            keys.InsertLast(k);
        }
        for (uint i = 0; i < keys.Length; i++) {
            int x = int(keys[i] >> 16), z = int(keys[i] & 0xFFFF);
            if (!_ReconCellUnused(inSet, x, z)) continue;
            int w = 1, h = 1;
            while (_ReconCellUnused(inSet, x + w, z)) w++;
            bool grow = true;
            while (grow) {
                for (int dx = 0; dx < w; dx++) {
                    if (!_ReconCellUnused(inSet, x + dx, z + h)) { grow = false; break; }
                }
                if (grow) h++;
            }
            for (int dz = 0; dz < h; dz++) {
                for (int dx = 0; dx < w; dx++) inSet.Set("" + (uint(x + dx) << 16 | uint(z + dz)), 1);
            }
            if (widenForMin && w == 1) {
                if (_ReconSpanIsLiveLand(map, x - 1, z, 1, h)) { x--; w = 2; }
                else if (_ReconSpanIsLiveLand(map, x + 1, z, 1, h)) w = 2;
            }
            if (widenForMin && h == 1) {
                if (_ReconSpanIsLiveLand(map, x, z - 1, w, 1)) { z--; h = 2; }
                else if (_ReconSpanIsLiveLand(map, x, z + 1, w, 1)) h = 2;
            }
            _ReconPlaceRect(pmt, map, modelName, x, z, w, h);
        }
    }

    // Place one terrain-model rect at the live base height and wait for the
    // async terraform to land. Success/failure of the CELLS is judged by the
    // caller's recheck, not here.
    bool _ReconPlaceRect(CGameEditorPluginMap@ pmt, CGameCtnChallenge@ map, const string &in mName, int x, int z, int w, int h) {
        auto model = pmt.GetTerrainBlockModelFromName(mName);
        if (model is null) return false;
        auto gen = _CurrentCellGen(map, x, z);
        int y = gen is null ? 0 : gen.BaseHeight;
        int3 lo = int3(x, y, z), hi = int3(x + w - 1, y, z + h - 1);
        if (!pmt.CanPlaceTerrainBlocks(model, lo, hi)) {
            dev_trace("[TerrainRecon] " + mName + " " + w + "x" + h + " @<" + x + "," + z
                + "> refused (below the model's minimum region?)");
            return false;
        }
        string before = _CurrentCellSig(map, x, z);
        if (!pmt.PlaceTerrainBlocks(model, lo, hi)) {
            dev_trace("[TerrainRecon] PlaceTerrainBlocks(" + mName + ") returned false @<" + x + "," + z + ">");
            return false;
        }
        for (uint i = 0; i < 60; i++) {
            yield();
            if (_CurrentCellSig(map, x, z) != before) break;
        }
        _ReconAwaitSettle();
        dev_trace("[TerrainRecon] placed " + mName + " " + w + "x" + h + " @<" + x + "," + z + "> y" + y);
        return true;
    }

    // All cells of the w x h span are live at land level with a gesture-made
    // stack: safe to include in a widened fill rect (the fill is idempotent
    // for them, and slope dirs re-derive from final geometry).
    bool _ReconSpanIsLiveLand(CGameCtnChallenge@ map, int x, int z, int w, int h) {
        for (int dz = 0; dz < h; dz++) {
            for (int dx = 0; dx < w; dx++) {
                auto gen = _CurrentCellGen(map, x + dx, z + dz);
                if (gen is null || gen.ZoneIds.Length > 2) return false;
                if (gen.TopHeight - gen.BaseHeight != 1) return false;
            }
        }
        return true;
    }

    bool _ReconCellUnused(dictionary@ s, int x, int z) {
        if (x < 0 || z < 0) return false;
        int64 v = 0;
        return s.Get("" + (uint(x) << 16 | uint(z)), v) && v == 0;
    }

    // True when the model's base ground variant carries AutoTerrains (i.e.
    // native placement of it terraforms).
    bool _GroundVariantHasAutoTerrains(CGameCtnBlockInfo@ info) {
        if (info is null || info.VariantBaseGround is null) return false;
        return DGameCtnBlockInfoVariantGround(info.VariantBaseGround).AutoTerrainsBuf.Length > 0;
    }

    // The genealogy grid is x-major: ix = z + x*size.z. Verified empirically:
    // a block placed at engine coord (30,·,35) changes the grid entries whose
    // x-major decode is (30±1, 35±1); the z-major decode mirrors them.
    uint _TerrainCellIx(int x, int z, int sizeZ) { return uint(z) + uint(x) * uint(sizeZ); }
    int3 _TerrainCellCoord(uint ix, int sizeZ) { return int3(int(ix) / sizeZ, 0, int(ix) % sizeZ); }

    // Live genealogy nod of the cell at (x, z), null when unreadable.
    CGameCtnZoneGenealogy@ _CurrentCellGen(CGameCtnChallenge@ map, int x, int z) {
        if (map is null || x < 0 || z < 0) return null;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
        int sizeZ = Nat3ToInt3(map.Size).z;
        if (sizeZ <= 0) return null;
        uint ix = _TerrainCellIx(x, z, sizeZ);
        if (ix >= cells.Length) return null;
        return cells.GetTerrainCell(ix).Nod;
    }

    // Base-relative signature of the live cell at (x, z), "" when unreadable.
    string _CurrentCellSig(CGameCtnChallenge@ map, int x, int z) {
        auto gen = _CurrentCellGen(map, x, z);
        return gen is null ? "" : GenealogySignature(gen);
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
        string defaultSig = "";
        bool defaultSigInit = false;
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
                // an identical block already there means this apply is already
                // satisfied (e.g. the echo of an API placement, which has no
                // undo point to rewind) — don't refuse into the donor fallback
                auto existing = pmt.GetBlock(c);
                if (existing is null) @existing = pmt.GetBlock(int3(c.x, c.y - 1, c.z));
                if (existing !is null && existing.BlockInfo !is null
                    && existing.BlockInfo.IdName == b.name && int(existing.Dir) == int(b.dir)) {
                    // Heal: an undo dance can kill a still-pending async
                    // terraform job after a block landed (the job takes ~1s;
                    // an echo can dance within ~100ms). The block survives the
                    // dance (API places have no undo entry) but the ground
                    // stays bald. If the model carries ground AutoTerrains and
                    // the cell under the block is still the map default,
                    // remove + re-place to re-trigger the terrain job.
                    bool healed = false;
                    if (_GroundVariantHasAutoTerrains(existing.BlockInfo)) {
                        if (!defaultSigInit) {
                            defaultSigInit = true;
                            defaultSig = GetMapDefaultGenealogySignature(
                                DGameCtnChallenge(editor.Challenge).TerrainGenealogies);
                        }
                        string cellSig = _CurrentCellSig(editor.Challenge, c.x, c.z);
                        if (cellSig != "" && cellSig == defaultSig) {
                            dev_trace("PlaceMacroblockGroundBlocks: " + b.name + " at " + c.ToString()
                                + " has no terraform under it; re-placing to re-trigger the terrain job");
                            auto exCoord = Nat3ToInt3(Editor::GetBlockCoord(existing));
                            try {
                                pmt.RemoveBlockSafe(existing.BlockInfo, exCoord,
                                    CGameEditorPluginMap::ECardinalDirections(int(existing.Dir)));
                                placed = pmt.PlaceBlock(info, c, dir);
                                healed = true;
                            } catch {
                                warn("PlaceMacroblockGroundBlocks: heal re-place threw for " + b.name + ": " + getExceptionInfo());
                            }
                        }
                    }
                    if (!healed) {
                        dev_trace("PlaceMacroblockGroundBlocks: " + b.name + " already at " + c.ToString() + "; skipping");
                        placed = true;
                    }
                } else {
                    try {
                        placed = pmt.PlaceBlock(info, c, dir);
                    } catch {
                        warn("PlaceMacroblockGroundBlocks: PlaceBlock threw for " + b.name + ": " + getExceptionInfo());
                    }
                    dev_trace("PlaceMacroblockGroundBlocks: native place " + b.name + " @ " + c.ToString() + " dir " + tostring(dir) + " -> " + placed + " @f" + Time::FrameCount);
                }
            }
            MarkTerrainResyncCells(int(b.coord.x), int(b.coord.z));
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
        WaitForDonorRestores();
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

    // set while the restore queue contains at least one REMOTE (capture-
    // suppressed) terrain apply: those must be swallowed from the diff
    // snapshot when the queue drains. Local applies leave it false so their
    // changes settle into a broadcastable diff.
    bool _terrainRestoreSwallow = false;

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
        // Remote applies' grid changes are already known to whoever sent them
        // -- resync the snapshot so GetTerrainDiffSpec does not echo them
        // back. (Local edits made during the ~2s window are folded in too;
        // callers diff on a dirty-flag debounce, so this is a bounded blind
        // spot.) Queues with only local applies skip the refresh so their
        // changes broadcast.
        bool swallow = _terrainRestoreSwallow;
        _terrainRestoreSwallow = false;
        if (swallow && _terrainSnapshotTaken) RefreshTerrainSnapshot();
    }

    bool _terrainResyncScheduled = false;
    // Cells a remote/API apply touched (grid indices), awaiting a SCOPED
    // snapshot resync. Only these are re-baselined, so a concurrent LOCAL
    // edit elsewhere on the map is not absorbed -- it settles into a
    // broadcast diff as soon as the pending window closes. A one-block
    // terraform changes cells up to 2 away from the block (blending ring),
    // hence the margin.
    dictionary _terrainResyncCellIxs;
    const int TERRAIN_RESYNC_MARGIN = 2;

    void MarkTerrainResyncCells(int bx, int bz) {
        auto map = GetApp().RootMap;
        if (map is null) return;
        int3 size = Nat3ToInt3(map.Size);
        if (size.z <= 0) return;
        for (int x = bx - TERRAIN_RESYNC_MARGIN; x <= bx + TERRAIN_RESYNC_MARGIN; x++) {
            for (int z = bz - TERRAIN_RESYNC_MARGIN; z <= bz + TERRAIN_RESYNC_MARGIN; z++) {
                if (x < 0 || z < 0 || x >= size.x || z >= size.z) continue;
                _terrainResyncCellIxs.Set("" + _TerrainCellIx(x, z, size.z), true);
            }
        }
    }

    // Coalesced scoped resync: after the remote/API apply's terraform lands,
    // re-baseline ONLY the marked cells so their churn is not diffed back to
    // the peer who sent them.
    void ScheduleTerrainSnapshotResync() {
        if (_terrainResyncScheduled) return;
        _terrainResyncScheduled = true;
        startnew(_TerrainSnapshotResyncSoon);
    }
    void _TerrainSnapshotResyncSoon() {
        // wait for terrain QUIET, not a fixed time: a burst of ground blocks
        // terraforms over several seconds, and refreshing mid-burst leaks the
        // late cells into the next diff (broadcast echo). An early refresh is
        // only an echo (peers no-op it via sig-match), so a short quiet
        // window with a hard cap is enough.
        sleep(300);
        uint capAt = Time::Now + 5000;
        while (Time::Now < _lastTerrainActivityAt + 500 && Time::Now < capAt) sleep(100);
        _terrainResyncScheduled = false;
        auto keys = _terrainResyncCellIxs.GetKeys();
        _terrainResyncCellIxs.DeleteAll();
        if (!_terrainSnapshotTaken) return;
        auto map = GetApp().RootMap;
        if (map is null) return;
        auto cells = DGameCtnChallenge(map).TerrainGenealogies;
        if (cells.Length != _terrainSnapshotSigs.Length) {
            RefreshTerrainSnapshot();
            return;
        }
        uint refreshed = 0;
        for (uint i = 0; i < keys.Length; i++) {
            uint ix = Text::ParseUInt(keys[i]);
            if (ix >= _terrainSnapshotSigs.Length) continue;
            _terrainSnapshotSigs[ix] = _TerrainCellSig(cells.GetTerrainCell(ix).Nod);
            refreshed++;
        }
        dev_trace("[TerrainResync] scoped refresh of " + refreshed + " cells @f" + Time::FrameCount);
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
    // last time a terrain block add/remove hook fired: engine terraform jobs
    // are async, so recent activity means a rebuild may still be in flight
    uint _lastTerrainActivityAt = 0;
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
        int sizeZ = Nat3ToInt3(map.Size).z;
        if (sizeZ <= 0) return null;
        for (uint i = 0; i < cells.Length; i++) {
            auto gen = cells.GetTerrainCell(i).Nod;
            string sig = _TerrainCellSig(gen);
            if (sig == _terrainSnapshotSigs[i]) continue;
            _terrainSnapshotSigs[i] = sig;
            if (gen is null) continue;
            auto ts = TerrainSpec();
            ts.offset = _TerrainCellCoord(i, sizeZ);
            SetTerrainSpecFromGenealogy(ts, gen, gen.BaseHeight);
            spec.terrains.InsertLast(ts);
        }
        _terrainDirty = false;
        return spec;
    }

    // MARK: Settled-terrain hook watcher
    //
    // When any extension registers onTerrainDirty/onTerrainChanged, E++ owns
    // the debounce + snapshot pipeline above and delivers the settled diff to
    // every subscriber (the snapshot is global, so only one consumer can ever
    // poll GetTerrainDiffSpec -- hooks fan the single diff out instead).
    // With no subscribers the watcher touches nothing, keeping the polling
    // exports usable. Ticked from ResetTrackMapChanges_Loop (BeforeScripts).
    // Frame-based settle: terraform commits in the SAME FRAME as its block
    // placement (measured: a 13-block replay wave landed all terrain as one
    // dirty tick that frame), so 2 quiet frames = 1 frame of straddle margin.
    // A premature settle self-heals via a follow-up diff. Beware re-measuring
    // this with spaced test calls: gaps then reflect call spacing, not engine
    // scheduling.
    const uint TERRAIN_SETTLE_QUIET_FRAMES = 2;
    uint _terrainQuietFrames = 0;
    bool _terrainHookArmed = false;

    bool _terrainHookWatcherAnnounced = false;
    void TerrainHookWatcher_Tick() {
        if (!Callbacks::Exts::HasTerrainSettleSubscribers()) return;
        if (!_terrainHookWatcherAnnounced) {
            _terrainHookWatcherAnnounced = true;
            trace("[TerrainHookWatcher] active: settled-terrain subscriber registered");
        }
        if (cast<CGameCtnEditorFree>(GetApp().Editor) is null || GetApp().RootMap is null) {
            _terrainHookArmed = false;
            _terrainSnapshotTaken = false;
            return;
        }
        // late-subscribe baseline: changes are reported from registration on
        if (!_terrainSnapshotTaken) RefreshTerrainSnapshot();
        if (_terrainDirty) {
            _terrainDirty = false;
            // fires every tick that edits land (not once per burst): sync
            // consumers re-cache their undo position on each ping so an
            // incoming update's undo dance can only rewind ~1 frame of
            // un-broadcast terraform
            if (!IsTerrainResyncPending()) {
                Callbacks::Exts::Run_OnTerrainDirty();
            }
            _terrainHookArmed = true;
            _terrainQuietFrames = 0;
        } else if (_terrainHookArmed) {
            _terrainQuietFrames++;
        }
        if (_terrainHookArmed && _terrainQuietFrames >= TERRAIN_SETTLE_QUIET_FRAMES) {
            if (IsTerrainResyncPending()) {
                // a remote/API apply is still settling; its grid churn must
                // land in the snapshot (via the restore-loop refresh), not in
                // a broadcast diff -- hold until quiet
                _terrainQuietFrames = 0;
                return;
            }
            _terrainHookArmed = false;
            auto diff = GetTerrainDiffSpec();
            dev_trace("[TerrainHookWatcher] settled @f" + Time::FrameCount + "; diff cells: " + (diff is null ? -1 : int(diff.Terrains.Length)));
            if (diff !is null && diff.Terrains.Length > 0) {
                Callbacks::Exts::Run_OnTerrainChanged(diff);
            }
        }
    }
}
