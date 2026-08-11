#if DEV
namespace Editor {
    // Shared across the plugin and written at the end of each Dev_RunRandomFuzz call.
    // Cross-plugin readers fetch counters via the getter exports below.
    uint _fuzzLastIterations = 0;
    uint _fuzzLastAttemptedBlock = 0;
    uint _fuzzLastAttemptedItem = 0;
    uint _fuzzLastPlacedBlock = 0;
    uint _fuzzLastPlacedItem = 0;
    uint _fuzzLastSkippedNoInv = 0;
    uint _fuzzLastSkippedBadModel = 0;
    uint _fuzzLastSkippedVariant = 0;
    uint _fuzzLastExceptions = 0;
    string _fuzzLastFirstException;
    string _fuzzLastCollection;
    uint _fuzzLastBlocksBefore = 0;
    uint _fuzzLastBlocksAfter = 0;
    uint _fuzzLastItemsBefore = 0;
    uint _fuzzLastItemsAfter = 0;

    // Collect block models from pmt.BlockModels that are usable for free placement.
    array<CGameCtnBlockInfo@>@ _CollectFuzzBlockModels(CGameEditorPluginMap@ pmt) {
        array<CGameCtnBlockInfo@> result;
        for (uint i = 0; i < pmt.BlockModels.Length; i++) {
            auto bm = cast<CGameCtnBlockInfo>(pmt.BlockModels[i]);
            if (bm is null) continue;
            if (bm.IsTerrain) continue;
            // Exclude waypoint/checkpoint-ish blocks; they inflate lag and mess up map state.
            if (bm.EdWaypointType != CGameCtnBlockInfo::EWayPointType::None) continue;
            result.InsertLast(bm);
        }
        return result;
    }

    // Collect item models from the inventory cache.
    array<CGameItemModel@>@ _CollectFuzzItemModels() {
        array<CGameItemModel@> result;
        auto invC = cast<Editor::InventoryCache>(Editor::GetInventoryCache());
        if (invC is null) return result;
        auto nodes = invC.ItemInvNodes;
        if (nodes is null) return result;
        for (uint i = 0; i < nodes.Length; i++) {
            auto node = nodes[i];
            if (node is null) continue;
            auto nod = node.GetCollectorNod();
            if (nod is null) continue;
            auto m = cast<CGameItemModel>(nod);
            if (m is null) continue;
            result.InsertLast(m);
        }
        return result;
    }

    vec3 _RandPosInBox(const vec3 &in mn, const vec3 &in mx) {
        return vec3(Math::Rand(mn.x, mx.x), Math::Rand(mn.y, mx.y), Math::Rand(mn.z, mx.z));
    }

    vec3 _RandPyr() {
        // Full unrestricted pyr; pitch/yaw/roll each in [-PI, PI].
        return vec3(Math::Rand(-Math::PI, Math::PI), Math::Rand(-Math::PI, Math::PI), Math::Rand(-Math::PI, Math::PI));
    }

    // Run a random-fuzz placement sweep in the current editor.
    //   bbMin/bbMax    - bounding box for random positions
    //   iterations     - number of placements to attempt
    //   blockRatio     - 0..1, fraction of attempts that target blocks (rest are items)
    // Writes per-run counters into _fuzzLast* state; returns the number of successful placements.
    uint Dev_RunRandomFuzz(const vec3 &in bbMin, const vec3 &in bbMax, uint iterations, float blockRatio) {
        _fuzzLastIterations = iterations;
        _fuzzLastAttemptedBlock = 0;
        _fuzzLastAttemptedItem = 0;
        _fuzzLastPlacedBlock = 0;
        _fuzzLastPlacedItem = 0;
        _fuzzLastSkippedNoInv = 0;
        _fuzzLastSkippedBadModel = 0;
        _fuzzLastSkippedVariant = 0;
        _fuzzLastExceptions = 0;
        _fuzzLastFirstException = "";
        _fuzzLastCollection = "";
        _fuzzLastBlocksBefore = 0;
        _fuzzLastBlocksAfter = 0;
        _fuzzLastItemsBefore = 0;
        _fuzzLastItemsAfter = 0;

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.PluginMapType is null || editor.Challenge is null) {
            warn("[RandomFuzz] no editor");
            return 0;
        }
        auto pmt = editor.PluginMapType;
        auto map = editor.Challenge;
        _fuzzLastCollection = string(map.CollectionName);
        _fuzzLastBlocksBefore = map.Blocks.Length;
        _fuzzLastItemsBefore = map.AnchoredObjects.Length;

        auto blocks = _CollectFuzzBlockModels(pmt);
        auto items = _CollectFuzzItemModels();
        trace("[RandomFuzz] collection=" + _fuzzLastCollection
            + " blockInvN=" + blocks.Length + " itemInvN=" + items.Length
            + " iters=" + iterations + " blockRatio=" + blockRatio);

        if (blockRatio < 0.0) blockRatio = 0.0;
        if (blockRatio > 1.0) blockRatio = 1.0;

        for (uint i = 0; i < iterations; i++) {
            bool doBlock = Math::Rand(0.0, 1.0) < blockRatio;
            if (doBlock && blocks.Length == 0) doBlock = false;
            if (!doBlock && items.Length == 0) doBlock = blocks.Length > 0;
            if (doBlock && blocks.Length == 0) {
                _fuzzLastSkippedNoInv++;
                continue;
            }
            if (!doBlock && items.Length == 0) {
                _fuzzLastSkippedNoInv++;
                continue;
            }

            vec3 pos = _RandPosInBox(bbMin, bbMax);
            vec3 pyr = _RandPyr();

            if (doBlock) {
                _fuzzLastAttemptedBlock++;
                auto bm = blocks[Math::Rand(0, blocks.Length)];
                auto spec = Editor::BlockSpecPriv(bm, pos, pyr);
                spec.isFree = true;
                spec.isGhost = false;
                spec.isGround = false;
                spec.color = CGameCtnBlock::EMapElemColor::Default;
                if (!spec.EnsureValidVariant()) {
                    _fuzzLastSkippedVariant++;
                    continue;
                }
                bool placed = false;
                try {
                    placed = Editor::PlaceBlocks({ spec }, false);
                } catch {
                    _fuzzLastExceptions++;
                    if (_fuzzLastFirstException.Length == 0) _fuzzLastFirstException = getExceptionInfo();
                    warn("[RandomFuzz] block exception: " + getExceptionInfo());
                }
                if (placed) _fuzzLastPlacedBlock++;
            } else {
                _fuzzLastAttemptedItem++;
                auto im = items[Math::Rand(0, items.Length)];
                if (im is null) {
                    _fuzzLastSkippedBadModel++;
                    continue;
                }
                auto spec = Editor::MakeItemSpec(im, pos, pyr);
                if (spec is null) {
                    _fuzzLastSkippedBadModel++;
                    continue;
                }
                bool placed = false;
                try {
                    placed = Editor::PlaceItems({ spec }, false);
                } catch {
                    _fuzzLastExceptions++;
                    if (_fuzzLastFirstException.Length == 0) _fuzzLastFirstException = getExceptionInfo();
                    warn("[RandomFuzz] item exception: " + getExceptionInfo());
                }
                if (placed) _fuzzLastPlacedItem++;
            }

            if (i % 8 == 7) yield();
            if (i % 64 == 63) {
                for (uint j = 0; j < 3; j++) yield();
            }
        }

        for (uint j = 0; j < 4; j++) yield();
        _fuzzLastBlocksAfter = map.Blocks.Length;
        _fuzzLastItemsAfter = map.AnchoredObjects.Length;
        trace("[RandomFuzz] done collection=" + _fuzzLastCollection
            + " placedBlocks=" + _fuzzLastPlacedBlock + "/" + _fuzzLastAttemptedBlock
            + " placedItems=" + _fuzzLastPlacedItem + "/" + _fuzzLastAttemptedItem
            + " exceptions=" + _fuzzLastExceptions
            + " mapBlocks=" + _fuzzLastBlocksBefore + "->" + _fuzzLastBlocksAfter
            + " mapItems=" + _fuzzLastItemsBefore + "->" + _fuzzLastItemsAfter);
        return _fuzzLastPlacedBlock + _fuzzLastPlacedItem;
    }

    // Cross-plugin getters for the last fuzz run's counters/state.
    uint Dev_RandomFuzz_GetIterations()       { return _fuzzLastIterations; }
    uint Dev_RandomFuzz_GetAttemptedBlock()   { return _fuzzLastAttemptedBlock; }
    uint Dev_RandomFuzz_GetAttemptedItem()    { return _fuzzLastAttemptedItem; }
    uint Dev_RandomFuzz_GetPlacedBlock()      { return _fuzzLastPlacedBlock; }
    uint Dev_RandomFuzz_GetPlacedItem()       { return _fuzzLastPlacedItem; }
    uint Dev_RandomFuzz_GetSkippedNoInv()     { return _fuzzLastSkippedNoInv; }
    uint Dev_RandomFuzz_GetSkippedBadModel()  { return _fuzzLastSkippedBadModel; }
    uint Dev_RandomFuzz_GetSkippedVariant()   { return _fuzzLastSkippedVariant; }
    uint Dev_RandomFuzz_GetExceptions()       { return _fuzzLastExceptions; }
    string Dev_RandomFuzz_GetFirstException() { return _fuzzLastFirstException; }
    string Dev_RandomFuzz_GetCollection()     { return _fuzzLastCollection; }
    uint Dev_RandomFuzz_GetBlocksBefore()     { return _fuzzLastBlocksBefore; }
    uint Dev_RandomFuzz_GetBlocksAfter()      { return _fuzzLastBlocksAfter; }
    uint Dev_RandomFuzz_GetItemsBefore()      { return _fuzzLastItemsBefore; }
    uint Dev_RandomFuzz_GetItemsAfter()       { return _fuzzLastItemsAfter; }
}
#else
// RELEASE stubs: same export surface as DEV so importers (tm-control-mcp) bind,
// but fuzz is a no-op outside DEV builds.
namespace Editor {
    uint Dev_RunRandomFuzz(const vec3 &in bbMin, const vec3 &in bbMax, uint iterations, float blockRatio) {
        return 0;
    }
    uint Dev_RandomFuzz_GetIterations()       { return 0; }
    uint Dev_RandomFuzz_GetAttemptedBlock()   { return 0; }
    uint Dev_RandomFuzz_GetAttemptedItem()    { return 0; }
    uint Dev_RandomFuzz_GetPlacedBlock()      { return 0; }
    uint Dev_RandomFuzz_GetPlacedItem()       { return 0; }
    uint Dev_RandomFuzz_GetSkippedNoInv()     { return 0; }
    uint Dev_RandomFuzz_GetSkippedBadModel()  { return 0; }
    uint Dev_RandomFuzz_GetSkippedVariant()   { return 0; }
    uint Dev_RandomFuzz_GetExceptions()       { return 0; }
    string Dev_RandomFuzz_GetFirstException() { return ""; }
    string Dev_RandomFuzz_GetCollection()     { return ""; }
    uint Dev_RandomFuzz_GetBlocksBefore()     { return 0; }
    uint Dev_RandomFuzz_GetBlocksAfter()      { return 0; }
    uint Dev_RandomFuzz_GetItemsBefore()      { return 0; }
    uint Dev_RandomFuzz_GetItemsAfter()       { return 0; }
}
#endif
