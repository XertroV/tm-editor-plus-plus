#if COMPILE_WFC
// alt: if FALSE || DEV


// implementation of wave function collapse for level generation

bool INCLUDE_CG1 = false;
bool INCLUDE_CG2 = false;
bool INCLUDE_SCG1 = false;
bool INCLUDE_SCG2 = false;
bool INCLUDE_SCID = true;
bool INCLUDE_ID = false;

SimpleRNG simpleRng;

namespace WFC {
    /*
        Each coord has a number of possible states.

        Each block has a BlockUnitInfo around it when it can be connected to other blocks.
        Below is (always?) pillars.
    */

    void RegisterCallbacks() {
        RegisterOnEditorLoadCallback(OnEditorLoad, "WFC::MapVoxels");
        RegisterOnEditorUnloadCallback(OnEditorUnload, "WFC::MapVoxels");
    }

    BlockInventory@ blockInv;
    MapVoxels mapVoxels;
    ClipFilter@ clipFilter = ClipFilter();

    void Preload() {
        GetBlockInventory();
    }

    void OnEditorLoad() {
        mapVoxels.InitializeForMapSize(GetApp().RootMap.Size);
    }

    void OnEditorUnload() {
        mapVoxels.Reset(false);
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

const uint GRASS_ID_VAL = StrToMwIdValue_NoDep("Grass");

class MapVoxels {
    int3 mapSize;
    CoordState@[][] states;
    bool DrawDebug = false;

    void Reset(bool andScrapeMap = true) {
        auto mapSize = nat3(48, 48, 48);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor !is null) mapSize = editor.Challenge.Size;
        InitializeForMapSize(mapSize);
        if (editor is null) return;

        if (andScrapeMap and editor !is null) {
            auto map = editor.Challenge;
            auto nbBlocks = map.Blocks.Length;
            bool foundGrass = false;
            for (uint i = 0; i < nbBlocks; i++) {
                auto block = map.Blocks[i];
                if (block is null) continue;
                if (!foundGrass && block.DescId.Value == GRASS_ID_VAL) {
                    i += mapSize.x * mapSize.z - 1;
                    foundGrass = true;
                    continue;
                }
                auto wfcBlock = WFC::blockInv.FindBlockById(block.DescId.Value);
                if (wfcBlock is null) continue;
                RegisterBlock(wfcBlock, Nat3ToInt3(block.Coord), CardinalDir(int(block.Dir)));
            }
        }
    }

    void InitializeForMapSize(nat3 &in size) {
        for (uint i = 0; i < states.Length; i++) {
            for (uint j = 0; j < states[i].Length; j++) {
                if (states[i][j] !is null) {
                    @states[i][j] = null;
                }
            }
        }
        EntropyNextList.RemoveRange(0, EntropyNextList.Length);
        CoordsToRefresh.RemoveRange(0, CoordsToRefresh.Length);
        states.RemoveRange(0, states.Length);
        mapSize = Nat3ToInt3(size);
        states.Resize(size.x * size.z);
    }

    int GetXZIx(int3 &in coord) {
        return coord.x * mapSize.z + coord.z;
    }

    int3 IxToXZ(int ix) {
        return int3(ix / mapSize.z, 0, ix % mapSize.z);
    }

    CoordState@ GetCoordState(const int3 &in coord) {
        uint ix = GetXZIx(coord);
        if (ix > states.Length) {
            throw("GetCoordState: index out of bounds: " + ix + " / " + states.Length);
        }
        auto top = coord.y;
        if (states[ix].Length <= top) {
            states[ix].Resize(top >= mapSize.y / 2 ? mapSize.y : mapSize.y / 2 + 1);
        }
        if (states[ix][top] is null) {
            @states[ix][top] = CoordState();
        }
        return states[ix][top];
    }

    CoordState_AndCoord GetCoordState_AndCoord(const int3 &in coord) {
        return CoordState_AndCoord(GetCoordState(coord), coord);
    }

    bool IsCoordOccupied(const int3 &in coord) {
        if (coord.x < 0 || coord.y < 0 || coord.z < 0) return true;
        if (coord.x >= mapSize.x || coord.y >= mapSize.y || coord.z >= mapSize.z) return true;
        return GetCoordState(coord).IsOccupied;
    }

    bool CanPlaceBlock(WFC_BlockInfo@ blockInfo, int3 coord, CardinalDir dir) {
        // check if the block can be placed at the given coord
        // todo elsewhere: check if the block is compatible with the existing blocks
        // todo elsewhere: check if the block is compatible with the existing constraints
        auto bi = blockInfo.refBlockInfoVariant.AsBlockInfoVariant();
        auto nbBUIs = bi.BlockUnitInfos.Length;
        for (uint i = 0; i < nbBUIs; i++) {
            auto bui = bi.BlockUnitInfos[i];
            auto newOffset = RotateOffset(Nat3ToInt3(bui.Offset), dir, blockInfo.Size);
            if (IsCoordOccupied(coord + newOffset)) return false;
        }
        return true;
    }

    bool RegisterBlock(WFC_BlockInfo& blockInfo, int3 coord, CardinalDir dir) {
        // register the block at the given coord
        auto bi = blockInfo.refBlockInfoVariant.AsBlockInfoVariant();
        auto nbBUIs = bi.BlockUnitInfos.Length;
        auto size = blockInfo.Size;
        // holds count and minimum y offset
        int2[] xzCount = array<int2>(size.x * size.z, int2(0, 0xffff));
        for (uint i = 0; i < nbBUIs; i++) {
            auto o = bi.BlockUnitInfos[i].Offset;
            auto ix = size.z * o.x + o.z;
            xzCount[ix].x++;
            xzCount[ix].y = Math::Min(xzCount[ix].y, o.y);
        }
        for (uint i = 0; i < nbBUIs; i++) {
            auto bui = bi.BlockUnitInfos[i];
            // auto o = bui.Offset;
            // auto ix = size.z * o.x + o.z;
            // if (bui.Offset.y != xzCount[ix].y) continue;
            auto newOffset = RotateOffset(Nat3ToInt3(bui.Offset), dir, size);
            RegisterBlockUnit(bui, coord + newOffset, dir, blockInfo.GetClipsByBlockUnitInfoIx(i));
        }
        return true;
    }

    // register the block unit at the given coord
    void RegisterBlockUnit(CGameCtnBlockUnitInfo@ bui, int3 coord, CardinalDir dir, WFC_ClipInfo@[] &in clips) {
        // if (nbBlocksGoingUp > 255) throw("Too many blocks going up: " + nbBlocksGoingUp);
        // auto ix = GetXZIx(coord);
        // if (ix >= states.Length) {
        //     warn("Index out of bounds: " + ix + " / " + states.Length);
        //     return;
        // }
        // auto top = coord.y; // + nbBlocksGoingUp;
        // if (states[ix].Length <= top) {
        //     states[ix].Resize(top >= mapSize.y / 2 ? mapSize.y : mapSize.y / 2 + 1);
        // }
        GetCoordState(coord).SetOccupied(this, coord, bui, dir, clips);
        // for (uint i = 0; i < nbBlocksGoingUp; i++) {}
        // clipsBySourceUnit[ix][coord.y].SetOccupied(bui, dir, clips);
    }

    void RenderDebug() {
        if (!DrawDebug) return;
        auto nbCoords = states.Length;
        for (uint i = 0; i < nbCoords; i++) {
            if (states[i].Length == 0) continue;
            auto coordXZ = IxToXZ(i);
            for (uint y = 0; y < states[i].Length; y++) {
                if (!states[i][y].IsOccupied) continue;
                // draw the coord
                nvgDrawBlockBox(Editor::GetBlockMatrix(coordXZ + int3(0, y, 0)), Editor::DEFAULT_COORD_SIZE);
                // auto coord = int3(coordXZ.x, y, coordXZ.z);
                // auto state = states[i][y];
                // if (state.IsOccupied) {
                //     // draw the coord
                //     auto pos = Editor::GetBlockPosition(Int3ToNat3(coord));
                //     UI::Text(pos.ToString());
                //     UI::SetCursorPos(pos);
                //     UI::Text("X");
                // }
            }
        }
    }

    int3[] CoordsToRefresh;
    bool RefreshCoroInitiated = false;

    void OnOccupy_QueueCoordStateRefresh(const int3 &in coord) {
        CoordsToRefresh.InsertLast(coord);
        auto existingIx = FindInEntropyList(coord);
        if (existingIx != -1) EntropyNextList.RemoveAt(existingIx);
        if (!RefreshCoroInitiated) {
            RefreshCoroInitiated = true;
            startnew(CoroutineFunc(_RunRefreshCoordState));
        }
    }

    void _RunRefreshCoordState() {
        bool firstRun = true;
        while (CoordsToRefresh.Length > 0) {
            _RunRefreshCoords_Iter(firstRun);
            firstRun = false;
            yield();
        }
        if (_entropyListUnsorted) SortEntropyList();
        RefreshCoroInitiated = false;
    }

    void _RunRefreshCoords_Iter(bool firstRun) {
        // copy coords so we can empty it
        int3[] coords = CoordsToRefresh;
        CoordsToRefresh.RemoveRange(0, CoordsToRefresh.Length);
        for (int i = coords.Length - 1; i >= 0; i--) {
            auto coord = coords[i];
            dev_trace("Refreshing coord: " + coord.ToString());
            auto cs = this.GetCoordState(coord);

            if (cs.IsOccupied) {
                // we need to invalidate the surrounding coords, but only on the first run since the only time the state of this coord changes is before now (unless we undo).
                if (firstRun) {
                    for (uint cx = 0; cx < 6; cx++) {
                        CoordsToRefresh.InsertLast(coord + ClipFaceToOffset1(cx));
                    }
                }
                // we always continue here for occupied (nothing to do)
                continue;
            }

            // if we're not occupied, we need to update the list of available blocks.
            // we only trigger further invalidations if the set of blocks changed.
            // note: we don't need to propagate here actually; because we're not adding any more clips
            auto availableNb = cs.availableBlockIxsAndRots.Length;
            if (availableNb == 0) {
                // search all blocks based on constraints
                InitializeAvailableBlocks(cs, coord);
                availableNb = cs.availableBlockIxsAndRots.Length;
                // If we have no available blocks

            }

            if (availableNb == 0 && cs.Entropy == -2) {
                // we have no available blocks, but entropy is max; which means anything can match.
                continue;
            }

            // we are only going to be reducing the list
            // we run this after initializing too so we can be a bit lazier during initialization
            uint[] toRem;
            uint entropy = 0;
            for (uint i = 0; i < availableNb; i++) {
                auto blockIxAndDirs = cs.availableBlockIxsAndRots[i];
                auto dirs = blockIxAndDirs.dirs;
                auto ix = blockIxAndDirs.ci.biIx;
                if (ix >= WFC::blockInv.blockInfos.Length) {
                    Dev_NotifyWarning("Invalid block index: " + ix);
                    continue;
                }
                auto blockInfo = WFC::blockInv.blockInfos[ix];
                // need to get constraints from neighboring blocks...
                auto matchingDirs = blockInfo.SolveCardinalDirections(this, coord);
                if (matchingDirs == dirs) {
                    entropy += CountDirsInPacked(matchingDirs);
                    continue;
                }
                if (matchingDirs == 0) {
                    // remove this block from the list
                    toRem.InsertLast(i);
                } else {
                    // update the list of available blocks
                    cs.availableBlockIxsAndRots[i].dirs = matchingDirs;
                    entropy += CountDirsInPacked(matchingDirs);
                }
            }
            // remove the blocks that are not compatible
            for (int i = toRem.Length - 1; i >= 0; i--) {
                cs.availableBlockIxsAndRots.RemoveAt(toRem[i]);
            }
            // update the entropy
            bool entropyChanged = cs.Entropy != entropy;
            cs.Entropy = entropy;
            if (entropyChanged) {
                // we need to make sure we are in the list and it gets re-sorted
                NotifyEntropyChanged(cs, coord);
            }
        }
    }

    // void dbg_GotFaceConstraints(FaceClipConstraint@ northCs, FaceClipConstraint@ eastCs, FaceClipConstraint@ southCs, FaceClipConstraint@ westCs) {
    //     string msg = "Got face constraints: ";
    //     msg += (northCs !is null ? "N=null" : "N=<"+northCs.ToString()+">");
    //     msg += (eastCs is null ? "E=null" : "E=<"+eastCs.ToString()+">");
    //     msg += (southCs is null ? "S=null" : "S=<"+southCs.ToString()+">");
    //     msg += (westCs is null ? "W=null" : "W=<"+westCs.ToString()+">");
    //     _Log::Info(msg);
    // }

    // void dbg_FoundBlockIxs(const uint[] &in northR, const uint[] &in eastR, const uint[] &in southR, const uint[] &in westR) {
    //     string msg = "Found block ixs: ";
    //     msg += (northR.Length == 0 ? "N=null" : "N=< "+UintArrToString(northR, false)+" >");
    //     msg += (eastR.Length == 0 ? "E=null" : "E=< "+UintArrToString(eastR, false)+" >");
    //     msg += (southR.Length == 0 ? "S=null" : "S=< "+UintArrToString(southR, false)+" >");
    //     msg += (westR.Length == 0 ? "W=null" : "W=< "+UintArrToString(westR, false)+" >");
    //     _Log::Info(msg);
    // }

    // void dbg_Intersection(const string &in name, const uint[] &in arr) {
    //     string msg = "Intersection: " + name + ": ";
    //     if (arr.Length == 0) {
    //         msg += "empty";
    //     } else {
    //         msg += "<" + UintArrToString(arr, false) + ">";
    //     }
    //     _Log::Info(msg);
    // }

    void InitializeAvailableBlocks(CoordState@ cs, const int3 &in coord) {
        // search all blocks based on constraints; note: we won't solve them here, just filtere down blocks to a reasonable list.
        cs.availableBlockIxsAndRots.RemoveRange(0, cs.availableBlockIxsAndRots.Length);
        auto northCs = GetConstraintsForFaceInMap(coord, ClipFace::North);
        auto eastCs = GetConstraintsForFaceInMap(coord, ClipFace::East);
        auto southCs = GetConstraintsForFaceInMap(coord, ClipFace::South);
        auto westCs = GetConstraintsForFaceInMap(coord, ClipFace::West);
        // dbg_GotFaceConstraints(northCs, eastCs, southCs, westCs);
        auto northR = WFC::blockInv.FindOkClipsByClipIds(northCs.allowedClipIds);
        auto eastR = WFC::blockInv.FindOkClipsByClipIds(eastCs.allowedClipIds);
        auto southR = WFC::blockInv.FindOkClipsByClipIds(southCs.allowedClipIds);
        auto westR = WFC::blockInv.FindOkClipsByClipIds(westCs.allowedClipIds);
        // dbg_FoundBlockIxs(northR, eastR, southR, westR);
        auto intersectNE = northR.Length > 0 ? eastR.Length > 0 ? Intersection(northR, eastR) : northR : eastR;
        auto intersectSW = southR.Length > 0 ? westR.Length > 0 ? Intersection(southR, westR) : southR : westR;
        WFC_ClipInfo@[] intersect = intersectNE.Length > 0 ? intersectSW.Length > 0 ? Intersection(intersectNE, intersectSW) : intersectNE : intersectSW;
        // dbg_Intersection("intersectNE", intersectNE);
        // dbg_Intersection("intersectSW", intersectSW);
        // dbg_Intersection("intersect", intersect);

        if (intersect.Length == 1 and intersect[0] is null) {
            _Log::Info("No constraints, any block is valid");
            // we can match any
            cs.Entropy = uint(-2);
            NotifyEntropyChanged(cs, coord);
            return;
        }

        // now we have a list of blocks that are compatible with the constraints
        for (uint i = 0; i < intersect.Length; i++) {
            if (intersect[i] is null) {
                // shouldn't get this here
                Dev_NotifyWarning("Invalid blockIx at i=" + i);
                PrintActiveContextStack(true);
                continue;
            }
            // assume everything is valid because we're about to filter them down as per non-initializaiton procedure.
            cs.availableBlockIxsAndRots.InsertLast(BlockIxCoordDir(intersect[i], 0xF));
        }
        cs.Entropy = 4 * cs.availableBlockIxsAndRots.Length;
        NotifyEntropyChanged(cs, coord);
    }

    EntropyEntry[] EntropyNextList;
    protected bool _entropyListUnsorted = false;

    // When entropy changes, we need to make sure the coord is in the list, and
    // that the list is resorted.
    void NotifyEntropyChanged(CoordState@ cs, const int3 &in coord) {
        if (cs.Entropy != -2) _Log::Debug("NotifyEntropyChanged", coord.ToString() + " -> " + cs.Entropy);
        int existingIx = FindInEntropyList(coord);
        _entropyListUnsorted = true;
        // don't store entries that can match anything or nothing
        if (cs.Entropy == -2 || cs.Entropy == 0) {
            if (existingIx == -1) return;
            EntropyNextList.RemoveAt(existingIx);
            return;
        }
        if (existingIx == -1) {
            EntropyNextList.InsertLast(EntropyEntry(cs.Entropy, coord.x, coord.y, coord.z));
            return;
        }
        EntropyNextList[existingIx].entropy = cs.Entropy;
    }

    int FindInEntropyList(const int3 &in coord) {
        for (uint i = 0; i < EntropyNextList.Length; i++) {
            if (EntropyNextList[i].IsCoord(coord)) return i;
        }
        return -1;
    }

    void SortEntropyList() {
        // sort the list by entropy
        EntropyQuicksort(EntropyNextList);
        _entropyListUnsorted = false;

    }


    CoordState_AndCoord[]@ GetNextLowestEtropyCoords() {
        uint lowestE = 0;
        return GetNextLowestEtropyCoords(lowestE);
    }
    CoordState_AndCoord[]@ GetNextLowestEtropyCoords(uint &out lowestE) {
        CoordState_AndCoord[]@ list = {};
        if (EntropyNextList.Length == 0) return list;
        lowestE = EntropyNextList[0].entropy;
        for (uint i = 0; i < EntropyNextList.Length && EntropyNextList[i].entropy == lowestE; i++) {
            if (EntropyNextList[i].entropy == lowestE) {
                list.InsertLast(GetCoordState_AndCoord(EntropyNextList[i].GetCoord()));
            } else {
                break;
            }
        }
        return list;
    }


    void DrawEntropy() {
        auto listLen = EntropyNextList.Length;
        auto nbToDraw = Math::Min(50, listLen);
        string asText = "Entropies: ";
        for (uint i = 0; i < nbToDraw; i++) {
            asText += (i > 0 ? ", " : "") + EntropyNextList[i].ToString();
        }
        UI::TextWrapped(asText);
        int hoverEntry = -1;
        vec2 hoverXY;
        vec4 hoverCol;
        float hoverRadius;
        // auto mouseCoords = g_lastMousePos;
        auto mousePos = UI::GetMousePos();
        for (int i = nbToDraw - 1; i >= 0; i--) {
            auto entropy = EntropyNextList[i].entropy;
            if (entropy == -2) continue;
            auto coord = EntropyNextList[i].GetCoord();
            vec4 col = vec4(1.0);
            col.x = 1.0 - Math::Clamp(float(entropy) / 64.0, 0.0, 1.0);
            col.y = Math::Clamp(float(entropy) / 64.0, 0.0, 1.0);
            col.z = col.y * 0.5;
            col.w = Math::Pow(Math::Lerp(0.1, 1.0, col.x), 1.5);
            auto radius = Math::Lerp(7.0, 1.0, col.x) ** 2 + 3.0;
            vec3 uv;
            auto worldPos = CoordToPos(coord) + HALF_COORD;
            auto camDist = MathX::Abs(Camera::GetCurrentPosition() - worldPos).Length();
            nvgCircleWorldPos(worldPos, uv, col, radius);
            if (uv.z > 0.0) continue;

            if ((mousePos - uv.xy).LengthSquared() <= radius*radius) {
                hoverEntry = i;
                hoverXY = uv.xy;
                hoverCol = col;
                hoverRadius = radius;
                hoverCol.w = 1.0;
            }

            auto fontDistScale = Math::Clamp(1.0 - camDist / 1000.0, 0.0, 1.0);
            auto fontSize = g_screen.y * 0.035 * fontDistScale;
            if (fontSize < 2.0) continue;
            nvg::FontSize(fontSize);

            string t = tostring(entropy);
            auto bounds = nvg::TextBounds(t);
            nvgDrawTextWithShadow(uv.xy - bounds * 0.5, t);
            // auto cs = GetCoordState(coord);
            // if (cs.IsOccupied) continue;
            // draw the coord
            // nvgDrawBlockBox(Editor::GetBlockMatrix(coord), Editor::DEFAULT_COORD_SIZE);
            // // draw the entropy
            // UI::Text("Entropy: " + entry.entropy);
        }

        if (hoverEntry != -1) {
            nvgRingScreenPos(hoverXY, hoverCol, hoverRadius, 2.0);
            nvg::FontSize(20.0 * g_screen.y / 1440.0);
            nvg::TextAlign(0x1 | 0x4);
            nvgDrawTextWithShadow(hoverXY, EntropyNextList[hoverEntry].ToString());
        }
    }

    // FaceClipConstraint& GetConstraintsForFaceInMap(const int3 &in coord, const ClipFace &in face) {
    FaceClipConstraint@ GetConstraintsForFaceInMap(int3 coord, ClipFace face) {
        return GetCoordState(coord + ClipFaceToOffset1(face)).faceConstraints[ClipFace_Opposite(face)];
    }


}

class EntropyEntry {
    uint entropy, cx, cy, cz;
    EntropyEntry() {}
    EntropyEntry(int entropy, int cx, int cy, int cz) {
        this.entropy = entropy;
        this.cx = cx;
        this.cy = cy;
        this.cz = cz;
    }
    int3 GetCoord() {
        return int3(cx, cy, cz);
    }
    bool IsCoord(const int3 &in coord) {
        return cx == coord.x && cy == coord.y && cz == coord.z;
    }
    string ToString() {
        return tostring(entropy) + "@(" + cx + ", " + cy + ", " + cz + ")";
    }
}

void EntropyQuicksort(EntropyEntry[] &inout arr, int left = 0, int right = -1) {
    if (arr.Length < 2) return;
    if (right < 0) right = arr.Length - 1;
    int i = left;
    int j = right;
    uint pivot = arr[(left + right) / 2].entropy;
    while (i <= j) {
        while (arr[i].entropy < pivot) i++;
        while (arr[j].entropy > pivot) j--;
        if (i <= j) {
            EntropyEntry temp = arr[i];
            arr[i] = arr[j];
            arr[j] = temp;
            i++;
            j--;
        }
    }
    if (left < j) EntropyQuicksort(arr, left, j);
    if (i < right) EntropyQuicksort(arr, i, right);
}



void ExtendArray(ref@[] &inout arr1, const ref@[] &in arr2) {
    for (uint i = 0; i < arr2.Length; i++) {
        if (arr2[i] is null) continue;
        arr1.InsertLast(arr2[i]);
    }
}

// Note: {-1} means any match, and is handled as a special case.
uint[] Intersection(const uint[] &in arr1, const uint[] &in arr2) {
    // special case: {-1} means any match, and should only be propagated if arr1 is also -1.
    // similarly, if arr1 is {-1} and arr2 is not, we should return arr2.
    bool arr1_isAny = arr1.Length == 1 && arr1[0] == -1;
    bool arr2_isAny = arr2.Length == 1 && arr2[0] == -1;
    // if both any => return any
    if (arr1_isAny && arr2_isAny) return {-1};
    // if arr1 is any => return copy of arr2
    if (arr1_isAny) {
        return arr2;
    } else if (arr2_isAny) {
        // if arr2 is any => just return arr1
        return arr1;
    }

    uint[] ret = {};
    for (uint i = 0; i < arr1.Length; i++) {
        if (arr2.Find(arr1[i]) != -1 && ret.Find(arr1[i]) == -1) {
            ret.InsertLast(arr1[i]);
        }
    }
    return ret;
}

WFC_ClipInfo@[] Intersection(const WFC_ClipInfo@[] &in arr1, const WFC_ClipInfo@[] &in arr2) {
    // special case: {null} means any match, and should only be propagated if arr1 is also null.
    // similarly, if arr1 is {null} and arr2 is not, we should return arr2.
    bool arr1_isAny = arr1.Length == 1 && arr1[0] is null;
    bool arr2_isAny = arr2.Length == 1 && arr2[0] is null;
    // if both any => return any
    if (arr1_isAny && arr2_isAny) return {null};
    // if arr1 is any => return copy of arr2
    if (arr1_isAny) {
        return arr2;
    } else if (arr2_isAny) {
        // if arr2 is any => just return arr1
        return arr1;
    }

    WFC_ClipInfo@[] ret = {};
    for (uint i = 0; i < arr1.Length; i++) {
        ret.InsertLast(arr1[i]);
        // if (arr2.Find(arr1[i]) != -1 && ret.Find(arr1[i]) == -1) {
        // }
    }
    return ret;
}

class CoordState_AndCoord {
    CoordState@ cs;
    int3 coord;

    CoordState_AndCoord() {}

    CoordState_AndCoord(CoordState@ cs, const int3 &in coord) {
        @this.cs = cs;
        this.coord = coord;
    }
}

class CoordState {
    // -1 = done. 0 = no options. -2 = very big uint (for sorting)
    uint Entropy = -2;
    bool IsOccupied = false;

    // // 64 bits used: [occupied 1][55 unused][8 entropy]
    // //               0                      0x38
    // uint64 inner = 0;
    // list of state:
    // constraints on 6 faces
    // entropy = number of blocks that meet constraints
    // need easy lookup for compatible clips
    FaceClipConstraint@[] faceConstraints = DefaultFaceConstraints();
    // list of (id(u16), packedCardinals(u8))
    BlockIxCoordDir[] availableBlockIxsAndRots;

    // bool get_IsOccupied() { return (inner & 0x1) != 0; }
    // void set_IsOccupied(bool value) {
    //     if (value) inner |= 0x1;
    //     else inner &= ~0x1;
    // }
    // int get_Entropy() { return int(inner >> 0x38) - 1; }
    // void set_Entropy(int value) {
    //     value = Math::Clamp(value, -1, 254);
    //     inner = (inner & ((0x1 << 0x38) - 1)) | (uint64(value + 1) << 0x38);
    // }

    void SetOccupied(MapVoxels& parent, const int3 &in MyCoord, CGameCtnBlockUnitInfo@ bui, CardinalDir dir, WFC_ClipInfo@[] &in clips) {
        // set the state to occupied
        IsOccupied = true;
        // set the block unit info
        // set the direction
        // set the clips
        for (uint i = 0; i < clips.Length; i++) {
            auto clip = clips[i];
            // set the clip
            auto allowedIds = clip.GetSnapIDs();
            auto newClipDir = RotateDir(dir, int(clip.clipFace));
            faceConstraints[newClipDir].allowedClipIds.InsertLast(allowedIds.x);
            if (allowedIds.y != -1)
                faceConstraints[newClipDir].allowedClipIds.InsertLast(allowedIds.y);
        }
        parent.OnOccupy_QueueCoordStateRefresh(MyCoord);
        Entropy = -1;
        availableBlockIxsAndRots.RemoveRange(0, availableBlockIxsAndRots.Length);
    }

    bool GetAnyAvailableBlockAndDir(BlockIxCoordDir &out deets, ClipFace &out dir) {
        if (availableBlockIxsAndRots.Length == 0) {
            deets = BlockIxCoordDir(null, 0);
            dir = ClipFace::North;
            return false;
        }
        deets = availableBlockIxsAndRots[Math::Rand(0, availableBlockIxsAndRots.Length)];
        ClipFace[] dirs = {};
        for (uint i = 0; i < 4; i++) {
            if ((deets.dirs & (1 << i)) != 0) {
                dirs.InsertLast(ClipFace(i));
            }
        }
        dir = dirs[Math::Rand(0, dirs.Length)];
        return true;
    }
}

// MARK: ClipFilter

class ClipFilter {
    uint[] bannedBlockIds;
    uint[] bannedClipIds;
    uint[] preferredIds;

    // for ints: -1 = any, 0 = must be false, 1 = must be true
    int IsAlwaysVisibleFreeClip = 0;
    int Suffix_VFC = 0;
    int cardinalOnly = 1;

    // 0x3F = 63 = b111111
    // 0x0F = 15 = b001111 - only NESW
    uint allowedFaces = 0x0F;

    int3 offset = int3(-1);

    ClipFilter() {}

    bool IsFaceOk(ClipFace face) {
        return (allowedFaces & (1 << int(face))) != 0;
    }

    void SetFaceOk(ClipFace face, bool ok) {
        if (ok) allowedFaces |= 1 << int(face);
        else allowedFaces &= ~(1 << int(face));
    }

    void SetAllowedFaces(ClipFace[] &in faces) {
        allowedFaces = 0;
        for (uint i = 0; i < faces.Length; i++) {
            SetFaceOk(faces[i], true);
        }
    }

    void SetDeniedFaces(ClipFace[] &in faces) {
        allowedFaces = 0x3F;
        for (uint i = 0; i < faces.Length; i++) {
            SetFaceOk(faces[i], false);
        }
    }

    void SetDefaults() {
        // AddBanned("DecoCliff");
    }

    void DrawAsSettings() {
        IsAlwaysVisibleFreeClip = Tribox("IsAlwaysVisibleFreeClip", IsAlwaysVisibleFreeClip);
        Suffix_VFC = Tribox("ID Matches: ___VFC (Vert Front Clip)", Suffix_VFC);
        cardinalOnly = Tribox("Cardinal Only", cardinalOnly);
    }

    bool IsClipOkay(WFC_ClipInfo@ clip) {
        if (clip is null) return false;
        if (!IsFaceOk(clip.clipFace)) return false;
        if (IsAlwaysVisibleFreeClip >= 0 && IsAlwaysVisibleFreeClip != (clip.IsAlwaysVisibleFreeClip ? 1 : 0)) return false;
        if (Suffix_VFC >= 0 && Suffix_VFC != (clip.cId.GetName().EndsWith("VFC") ? 1 : 0)) return false;
        if (bannedClipIds.Length > 0 && bannedClipIds.Find(clip.cId.Value) != -1) return false;
        return true;
    }
}

class BlockIxCoordDir {
    // uint16 blockIx;
    int16 dirs;
    // int3 offset;
    WFC_ClipInfo@ ci;
    BlockIxCoordDir() {}
    BlockIxCoordDir(WFC_ClipInfo@ ci, int16 dirs) {
        @this.ci = ci;
        this.dirs = dirs;
    }
}

class FaceClipConstraint {
    uint[] allowedClipIds;
    ClipFace requiredFaceDir;
    FaceClipConstraint() {}
    FaceClipConstraint(int face) {
        requiredFaceDir = ClipFace(face);
    }

    string ToString() {
        string ret = "FaceClipConstraint(reqFace=" + tostring(requiredFaceDir) + ", allowedClipIds = { ";
        for (uint i = 0; i < allowedClipIds.Length; i++) {
            ret += (i > 0 ? ", " : "") + FmtUintHex(allowedClipIds[i]);
        }
        return ret + " } )";

    }
}

FaceClipConstraint@[] DefaultFaceConstraints() {
    FaceClipConstraint@[] constraints = array<FaceClipConstraint@>(6);
    for (uint i = 0; i < 6; i++) {
        @constraints[i] = FaceClipConstraint(i);
    }
    return constraints;
}

// MARK: WFC_ClipInfo

class WFC_ClipInfo {
    MwId cId = MwId(-1);
    int symCID = -1, clipGroup1 = -1, clipGroup2 = -1, symClipGroup1 = -1, symClipGroup2 = -1;
    uint biIx = -1, buiIx = -1, clipIx = -1;
    ClipFace clipFace;
    int3 buiOffset;
    int distFromTop = 0;
    uint flags = 0;
    WFC_ClipInfo@[]@ snappableClips;

    WFC_ClipInfo(CGameCtnBlockInfoClip@ bic, ClipFace clipFace, uint biIx, uint buiIx, uint clipIx, CGameCtnBlockUnitInfo@ bui, WFC_BlockInfo@ parent) {
        cId.Value = bic.Id.Value;
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
        this.clipFace = clipFace;
        IsAlwaysVisibleFreeClip = bic.IsAlwaysVisibleFreeClip;
        // never happens
        // if (!MathX::Nat3Eq(bui.Offset, bui.RelativeOffset)) {
        //     warn("BlockUnitInfo offset != relativeOffset: " + bui.Offset.ToString() + " != " + bui.RelativeOffset.ToString());
        // }
    }

    bool opEquals(const WFC_ClipInfo &in other) {
        // if (other is null) return false;
        return cId.Value == other.cId.Value && clipFace == other.clipFace && buiIx == other.buiIx && biIx == other.biIx && clipIx == other.clipIx;
    }

    bool get_IsAlwaysVisibleFreeClip() { return flags & 0x1 != 0; }
    void set_IsAlwaysVisibleFreeClip(bool value) {
        if (value) flags |= 0x1;
        else flags &= ~0x1;
    }


    CardinalDir get_dirFromParent() {
        if (clipFace < ClipFace::North || clipFace > ClipFace::West) return CardinalDir::North;
        return CardinalDir(int(clipFace));
    }

    void InsertSelfToLookups(IntLookup& groupIds, IntLookup& clipIds) { // IntLookup& symGroupIds, IntLookup& symIds
        if (clipGroup1 != -1) groupIds.Insert(clipGroup1, this);
        if (clipGroup2 != -1) groupIds.Insert(clipGroup2, this);
        // if (symClipGroup1 != -1) symGroupIds.Insert(symClipGroup1, this);
        // if (symClipGroup2 != -1) symGroupIds.Insert(symClipGroup2, this);
        // if (symCID != -1) symIds.Insert(symCID, this);
        if (cId.Value != -1) clipIds.Insert(cId.Value, this);
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

    WFC_ClipInfo@[]@ SetSnappable_JoinMatches(const ref@[]@[] &in toJoin) {
        if (toJoin.Length == 0) return null;
        auto joined = JoinMatches(toJoin);
        if (joined.Length == 0) return null;
        @snappableClips = joined;
        return snappableClips;
    }

    int2 GetSnapIDs() {
        if (symClipGroup1 != -1) return int2(symClipGroup1, symClipGroup2);
        if (clipGroup1 != -1) return int2(clipGroup1, clipGroup2);
        if (symCID != -1) return int2(symCID, -1);
        if (cId.Value != -1) return int2(cId.Value, -1);
        return int2(-1, -1);
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
            return left.cId.Value == right.cId.Value;
        }
        // otherwise, are this two clips matched (sym-norm)?
        return left.symCID == right.cId.Value;
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

enum ClipFace {
    North = 0,
    East = 1,
    South = 2,
    West = 3,
    Top = 4,
    Bottom = 5
}

int3 ClipFaceToOffset1(ClipFace cf) { return ClipFaceToOffset1(int(cf)); }
int3 ClipFaceToOffset1(int face) {
    switch (face) {
        case 0: return int3(0, 0, 1);
        case 1: return int3(-1, 0, 0);
        case 2: return int3(0, 0, -1);
        case 3: return int3(1, 0, 0);
        case 4: return int3(0, 1, 0);
        case 5: return int3(0, -1, 0);
    }
    return int3(0);
}

uint[] _cardinalPackedSum = {0, 1, 1, 2, 1, 2, 2, 3, 1, 2, 2, 3, 2, 3, 3, 4};

uint CountDirsInPacked(uint packed) {
    return _cardinalPackedSum[packed & 0x0F];
}

ClipFace ClipFace_Opposite(ClipFace cf) {
    switch (cf) {
        case ClipFace::North: return ClipFace::South;
        case ClipFace::East: return ClipFace::West;
        case ClipFace::South: return ClipFace::North;
        case ClipFace::West: return ClipFace::East;
        case ClipFace::Top: return ClipFace::Bottom;
        case ClipFace::Bottom: return ClipFace::Top;
    }
    return cf;
}

// MARK: WFC_BlockInfo

class WFC_BlockInfo {
    ReferencedNod@ refBlockInfo;
    ReferencedNod@ refBlockInfoVariant;
    WFC_ClipInfo@[] clips;
    MwId nameId;
    uint VarIx;
    uint BiIx;
    uint nbCardinalClips;
    int3 Size = int3(1);

    WFC_BlockInfo(CGameCtnBlockInfo@ bi, uint biIx) {
        @refBlockInfo = ReferencedNod(bi);
        nameId.Value = bi.Id.Value;
        BiIx = biIx;

        uint _varIx;
        auto biv = Editor::GetBlockBestVariant(bi, false, _varIx);
        // auto biv = bi.VariantBaseAir;
        Size = Nat3ToInt3(biv.Size);
        VarIx = _varIx;
        AddBlockUnitInfos(biv, biIx);
        @refBlockInfoVariant = ReferencedNod(biv);
    }

    CGameCtnBlockInfo@ get_BlockInfo() {
        return refBlockInfo.AsBlockInfo();
    }

    // int3 FindAnyOffsetSatisfying(CoordState_AndCoord& csac, ClipFace blockDir) {
    //     // find any offset that satisfies the constraints
    //     for (uint i = 0; i < clips.Length; i++) {
    //     }
    // }

    // returns in [0, 15], packed cardinal directions
    uint SolveCardinalDirections(MapVoxels& map, const int3 &in coord) {
        auto northCs = map.GetConstraintsForFaceInMap(coord, ClipFace::North);
        auto eastCs = map.GetConstraintsForFaceInMap(coord, ClipFace::East);
        auto southCs = map.GetConstraintsForFaceInMap(coord, ClipFace::South);
        auto westCs = map.GetConstraintsForFaceInMap(coord, ClipFace::West);
        uint packed = 0;
        if (MeetsConstraints(northCs, eastCs, southCs, westCs)) packed |= 1 << 0;
        if (MeetsConstraints(eastCs, southCs, westCs, northCs)) packed |= 1 << 1;
        if (MeetsConstraints(southCs, westCs, northCs, eastCs)) packed |= 1 << 2;
        if (MeetsConstraints(westCs, northCs, eastCs, southCs)) packed |= 1 << 3;
        return packed;
    }

    bool MeetsConstraints(FaceClipConstraint@ northCs, FaceClipConstraint@ eastCs, FaceClipConstraint@ southCs, FaceClipConstraint@ westCs) {
        if (!FaceMeetsConstraints(northCs, ClipFace::North)) return false;
        if (!FaceMeetsConstraints(eastCs, ClipFace::East)) return false;
        if (!FaceMeetsConstraints(southCs, ClipFace::South)) return false;
        if (!FaceMeetsConstraints(westCs, ClipFace::West)) return false;
        return true;
    }

    bool FaceMeetsConstraints(FaceClipConstraint@ fc, ClipFace face) {
        if (fc.allowedClipIds.Length == 0) return true;
        // check if the clip is in the allowed list
        uint i = 0;
        auto nbClips = clips.Length;
        while (i < nbClips and clips[i].clipFace != face) i++;
        while (i < nbClips and clips[i].clipFace == face) {
            auto ids = clips[i].GetSnapIDs();
            if (ids.x != -1 && fc.allowedClipIds.Find(ids.x) != -1) return true;
            if (ids.y != -1 && fc.allowedClipIds.Find(ids.y) != -1) return true;
            i++;
        }
        return false;
    }

    void InsertClipsToLookups(IntLookup& groupIds, IntLookup& clipIds) { // IntLookup& symGroupIds, IntLookup& symIds
        auto nbClips = clips.Length;
        for (uint i = 0; i < nbClips; i++) {
            clips[i].InsertSelfToLookups(groupIds, clipIds); // symGroupIds, symIds
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
        auto northLt = bui.ClipCount_North, eastLt = bui.ClipCount_East + northLt, southLt = bui.ClipCount_South + eastLt, westLt = bui.ClipCount_West + southLt, topLt = bui.ClipCount_Top + westLt, bottomLt = bui.ClipCount_Bottom + topLt;
        // print("North: " + northLt + ", East: " + eastLt + ", South: " + southLt + ", West: " + westLt);
        ClipFace dir = ClipFace::North;

        for (uint i = 0; i < nbClips; i++) {
            if (i < westLt) nbCardinalClips++;
            // if (i < northLt) {
            //     dir = CardinalDir::North;
            // } else if (i < eastLt) {
            //     dir = CardinalDir::East;
            // } else if (i < southLt) {
            //     dir = CardinalDir::South;
            // } else if (i < westLt) {
            //     dir = CardinalDir::West;
            // } else break;
            dir = i < topLt ? i < westLt ? i < southLt ? i < eastLt ? i < northLt ? ClipFace::North : ClipFace::East : ClipFace::South : ClipFace::West : ClipFace::Top : ClipFace::Bottom;
            auto clip = bui.AllClips[i];
            if (clip is null) {
                warn("Clip is null for " + BlockInfo.IdName);
                continue;
            }
            if (clip.ClipGroupId.Value == -1
                && clip.SymmetricalClipGroupId.Value == -1
                && clip.SymmetricalClipId.Value == -1
                && clip.ClipGroupId2.Value == -1
                && clip.SymmetricalClipGroupId2.Value == -1
                && clip.Id.Value == -1) {
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

    WFC_ClipInfo@ GetRandomClip(bool cardinal) {
        auto okClips = GetClipsSatisfying(WFC::clipFilter);
        if (okClips.Length == 0) return null;
        auto ix = Math::Rand(0, okClips.Length);
        return okClips[ix];
        // if (clips.Length == 0) return null;
        // uint ix = Math::Rand(0, cardinal ? nbCardinalClips : clips.Length);
        // uint loopCount = 0;
        // while (!WFC::clipFilter.IsClipOkay(clips[ix]) && ++loopCount < 100) {
        //     ix = Math::Rand(0, cardinal ? nbCardinalClips : clips.Length);
        // }
        // return loopCount < 100 ? clips[ix] : null;
    }

    WFC_ClipInfo@[] GetClipsSatisfying(ClipFilter@ filter) {
        WFC_ClipInfo@[] filteredClips = {};
        for (uint i = 0; i < clips.Length; i++) {
            if (filter.IsClipOkay(clips[i])) {
                filteredClips.InsertLast(clips[i]);
            }
        }
        return filteredClips;
    }

    WFC_ClipInfo@[] GetClipsByBlockUnitInfoIx(uint buiIx) {
        WFC_ClipInfo@[] clipsByBuiIx = {};
        for (uint i = 0; i < clips.Length; i++) {
            if (clips[i].buiIx == buiIx) {
                clipsByBuiIx.InsertLast(clips[i]);
            }
        }
        return clipsByBuiIx;
    }

    void DumpToFile(ThinLazyFile& file) {
        file.WriteLine("BlockInfo:" + BlockInfo.IdName);
        file.WriteLine("Clips: " + Json::Write(GetClipsJsonCount()));
    }

    Json::Value GetClipsJsonCount() {
        Json::Value j = Json::Object();
        for (uint i = 0; i < clips.Length; i++) {
            string k = clips[i].cId.GetName();
            int prev = j.Get(k, int(0));
            j[k] = prev + 1;
        }
        return j;
    }
}

[Setting hidden]
bool S_WFC_Blocks_ExcludeBigDecoCliff = true;
[Setting hidden]
bool S_WFC_Blocks_ExcludeDecoWall = true;
[Setting hidden]
bool S_WFC_Blocks_ExcludeWater = false;

bool ShouldExcludeBlockFromIngestion(CGameCtnBlockInfo@ bi) {
    if (S_WFC_Blocks_ExcludeBigDecoCliff && bi.IdName.StartsWith("DecoCliff")) {
        return bi.IdName.StartsWith("DecoCliff10") || bi.IdName.StartsWith("DecoCliff8");
    }
    if (S_WFC_Blocks_ExcludeDecoWall && bi.IdName.StartsWith("DecoWall")) {
        return true;
    }
    if (S_WFC_Blocks_ExcludeWater && bi.IdName.Contains("Water")) {
        return true;
    }
    return false;
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
    // IntLookup SymGroupIdsToClips;
    // IntLookup SymIdsToClips;
    IntLookup ClipIdsToClips;
    IntLookup BlocksById;

    BlockInventory() {
        blockInfos.Reserve(4096);
    }

    protected void IngestBlockInfo(CGameCtnBlockInfo@ bi) {
        if (ShouldExcludeBlockFromIngestion(bi)) return;
        // if (!filter.Matches(bi)) return;
        auto wfcBi = WFC_BlockInfo(bi, blockInfos.Length);
        if (!CheckPause("IngestBlockInfo")) return;
        wfcBi.InsertClipsToLookups(GroupIdsToClips, ClipIdsToClips); // SymGroupIdsToClips, SymIdsToClips
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

    WFC_BlockInfo@ FindBlockFromClip(WFC_ClipInfo@ clip) {
        if (clip is null) return null;
        return blockInfos[clip.biIx];
    }

    // returns {-1} if we can match any block (no clips)
    WFC_ClipInfo@[] FindOkClipsByClipIds(const uint[] &in clipIds) {
        ref@[] foundClips = {};
        bool anyFound = false;
        for (uint i = 0; i < clipIds.Length; i++) {
            auto cFromIds = ClipIdsToClips.Get(clipIds[i]);
            auto cFromGroups = GroupIdsToClips.Get(clipIds[i]);
            if (cFromIds !is null) {
                ExtendArray(foundClips, cFromIds);
                anyFound = cFromIds.Length > 0;
            }
            if (cFromGroups !is null) {
                ExtendArray(foundClips, cFromGroups);
                anyFound = cFromGroups.Length > 0;
            }
        }
        WFC_ClipInfo@[] foundClips2 = {};
        if (anyFound) {
            anyFound = false;
            for (uint i = 0; i < foundClips.Length; i++) {
                auto clip = cast<WFC_ClipInfo@>(foundClips[i]);
                if (clip is null) continue;
                if (!WFC::clipFilter.IsClipOkay(clip)) continue;
                if (foundClips2.FindByRef(clip) != -1) continue;
                foundClips2.InsertLast(clip);
                anyFound = true;
            }
        }
        // SanityCheckFoundBlocks(foundBlockIxs);
        return anyFound ? foundClips2 : ({null});
    }

    // returns {-1} if we can match any block (no clips)
    uint[] FindBlockIxsByClipIds(const uint[] &in clipIds) {
        ref@[] foundClips = {};
        bool anyFound = false;
        for (uint i = 0; i < clipIds.Length; i++) {
            auto cFromIds = ClipIdsToClips.Get(clipIds[i]);
            auto cFromGroups = GroupIdsToClips.Get(clipIds[i]);
            if (cFromIds !is null) {
                ExtendArray(foundClips, cFromIds);
                anyFound = cFromIds.Length > 0;
            }
            if (cFromGroups !is null) {
                ExtendArray(foundClips, cFromGroups);
                anyFound = cFromGroups.Length > 0;
            }
        }
        uint[] foundClips2 = {};
        if (anyFound) {
            anyFound = false;
            for (uint i = 0; i < foundClips.Length; i++) {
                auto clip = cast<WFC_ClipInfo@>(foundClips[i]);
                if (clip is null) continue;
                if (!WFC::clipFilter.IsClipOkay(clip)) continue;
                if (foundClips2.Find(clip.biIx) != -1) continue;
                foundClips2.InsertLast(clip.biIx);
                anyFound = true;
            }
        }
        // SanityCheckFoundBlocks(foundBlockIxs);
        return anyFound ? foundClips2 : ({-1});
    }

    WFC_BlockInfo@ GetCursorBlock() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return null;
        CGameCtnBlockInfo@ bi;
        if (selectedBlockInfoAny is null || (@bi = selectedBlockInfoAny.AsBlockInfo()) is null)
            @bi = Editor::GetSelectedBlockInfo(editor);
        if (bi is null) return null;
        return FindBlockById(bi.Id);
    }

    WFC_BlockInfo@ GetRandomBlock(int minClips = -1) {
        auto nbBlocks = blockInfos.Length;
        if (nbBlocks == 0) return null;
        WFC_BlockInfo@ blockInfo;
        uint ix;
        uint loopCount = 0;
        while ((blockInfo is null || blockInfo.clips.Length < minClips || ShouldExcludeBlockFromIngestion(blockInfo.BlockInfo)) && (++loopCount < 10)) {
            ix = Math::Rand(0, nbBlocks);
            @blockInfo = blockInfos[ix];
        }
        return blockInfo;
    }

    PlacedBlock@ dbg_ClipSource;
    WFC_ClipInfo@ dbg_BaseClip;
    WFC_ClipInfo@ dbg_ClipToPlace;
    int dbg_Dir1_AtCoordConnecting;
    WFC_BlockInfo@ dbg_BlockInfo;
    int dbg_Dir2_BlockDir;
    int3 dbg_NextClipCoord;
    int3 dbg_NextClipOffset;

    WFC_BlockInfo@ GetRandomAdjoiningBlock(int minClips, PlacedBlock@ clipSource, int3 &out coord, CGameEditorPluginMap::ECardinalDirections &out dir, bool expandedMatch = false) {
        if (clipSource is null || clipSource.BlockInfo.clips.Length == 0) return null;

        @dbg_ClipSource = clipSource;
        @dbg_BaseClip = null;
        @dbg_ClipToPlace = null;
        @dbg_BlockInfo = null;
        dbg_Dir1_AtCoordConnecting = -1;
        dbg_Dir2_BlockDir = -1;


        WFC_ClipInfo@ placedClip = clipSource.GetRandomClip(true);
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
            @placedClip = clipSource.GetRandomClip(true);
            if (placedClip is null) continue;
            @dbg_BaseClip = placedClip;
            // @clipToPlace = GetRandomConnectingClipFromClip(placedClip);
            @clipToPlace = FindRandomSnappableClip(placedClip, expandedMatch);
            @dbg_ClipToPlace = clipToPlace;
            if (clipToPlace is null) continue;

            CardinalDir dir;
            c = clipSource.CalcClipConnectingCoord(placedClip, dir);
            dbg_Dir1_AtCoordConnecting = dirAtCoordOfConnectingClip = dir;
            @blockInfo = blockInfos[clipToPlace.biIx];
            @dbg_BlockInfo = blockInfo;
        }

        if (clipToPlace is null) return null;

        // CardinalDir _blockDir;
        // int3 revOffset, newCoord;
        // CalcCoord_ClipToBlock(dirAtCoordOfConnectingClip, clipToPlace.dirFromParent, clipToPlace.buiOffset, blockInfo.Size, _blockDir, revOffset, newCoord);

        // calc updated coord given rotation
        // if symmetric: flip dir?
        auto _blockDir = RotateDir(dirAtCoordOfConnectingClip, -clipToPlace.dirFromParent);
        dbg_Dir2_BlockDir = _blockDir;
        auto revOffset = RotateOffset(clipToPlace.buiOffset, _blockDir, blockInfo.Size);
        dbg_NextClipOffset = revOffset;
        auto newCoord = c - revOffset;
        dbg_NextClipCoord = newCoord;
        // --
        coord = newCoord;
        dir = CGameEditorPluginMap::ECardinalDirections(_blockDir);
        return blockInfo;
    }

    WFC_ClipInfo@[]@ FindSnappableClips(WFC_ClipInfo@ clip, bool expandedMatch = false) {
        // if (clip.snappableClips !is null) return clip.snappableClips;
        ref@[]@[] toJoin;
        // sym groups match to clip groups
        // clip groups match to clip groups
        // no sym id => match `symId <|> cId` to clip id
        auto symGroups = clip.SymGroups;
        if (symGroups.x != -1) {
            toJoin.InsertLast(GroupIdsToClips.Get(symGroups.x));
            toJoin.InsertLast(GroupIdsToClips.Get(symGroups.y));
            if (!expandedMatch) return JoinMatches(toJoin);
            // auto ret = clip.SetSnappable_JoinMatches(toJoin);
            // if (!expandedMatch && ret !is null && ret.Length > 0) return ret;
        }
        auto clipGroups = clip.ClipGroups;
        if (clipGroups.x != -1) {
            toJoin.InsertLast(GroupIdsToClips.Get(clipGroups.x));
            toJoin.InsertLast(GroupIdsToClips.Get(clipGroups.y));
            if (!expandedMatch) return JoinMatches(toJoin);
            // auto ret = clip.SetSnappable_JoinMatches(toJoin);
            // if (!expandedMatch && ret !is null && ret.Length > 0) return ret;
        }
        toJoin.InsertLast(clip.symCID != -1 ? ClipIdsToClips.Get(clip.symCID) : ClipIdsToClips.Get(clip.cId.Value));
        return JoinMatches(toJoin);
        // return clip.SetSnappable_JoinMatches(toJoin);
    }

    WFC_ClipInfo@ FindRandomSnappableClip(WFC_ClipInfo@ clip, bool expandedMatch = false) {
        // todo: select only empty coords
        auto @snappableClips = FindSnappableClips(clip, expandedMatch);
        if (snappableClips is null) {
            warn("Unexpected: snappableClips is null for clip: " + clip.ToString());
            return null;
        }
        if (snappableClips.Length == 0) return null;
        uint ix = Math::Rand(0, snappableClips.Length);
        return snappableClips[ix];
    }

    WFC_ClipInfo@ GetRandomConnectingClipFromClip(WFC_ClipInfo@ clip) {
        auto cg1 = INCLUDE_CG1 ? GroupIdsToClips.Get(clip.symClipGroup1) : null;
        auto cg2 = INCLUDE_CG2 ? GroupIdsToClips.Get(clip.symClipGroup2) : null;
        // auto scg1 = INCLUDE_SCG1 ? SymGroupIdsToClips.Get(clip.clipGroup1) : null;
        // auto scg2 = INCLUDE_SCG2 ? SymGroupIdsToClips.Get(clip.clipGroup2) : null;
        auto c2scid = INCLUDE_SCID ? ClipIdsToClips.Get(clip.symCID) : null;
        auto s2cid = INCLUDE_ID ? ClipIdsToClips.Get(clip.cId.Value) : null;
        auto cg1Len = cg1 is null ? 0 : cg1.Length;
        auto cg2Len = cg2 is null ? 0 : cg2.Length;
        // auto scg1Len = scg1 is null ? 0 : scg1.Length;
        // auto scg2Len = scg2 is null ? 0 : scg2.Length;
        auto c2scidLen = c2scid is null ? 0 : c2scid.Length;
        auto s2cidLen = s2cid is null ? 0 : s2cid.Length;
        auto total = cg1Len + cg2Len + c2scidLen + s2cidLen; // scg1Len + scg2Len
        if (total == 0) return null;
        auto cg1Lt = cg1Len, cg2Lt = cg1Lt + cg2Len, c2scidLt = cg2Lt + c2scidLen, s2cidLt = c2scidLt + s2cidLen;
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
            // } else if (ix < scg1Lt) {
            //     @clipInfo = cast<WFC_ClipInfo@>(scg1[ix - cg2Lt]);
            // } else if (ix < scg2Lt) {
            //     @clipInfo = cast<WFC_ClipInfo@>(scg2[ix - scg1Lt]);
            } else if (ix < c2scidLt) {
                @clipInfo = cast<WFC_ClipInfo@>(c2scid[ix - cg2Lt]);
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
            if (!CheckPause("IngestFidFolder")) return;
        }
        auto nbFolders = folder.Trees.Length;
        for (uint i = 0; i < nbFolders; i++) {
            IngestFidFolder(folder.Trees[i]);
            if (!CheckPause("IngestFidFolder")) return;
        }
    }

    protected uint64 lastSearchPause = 0;
    // return true to keep going; false to break/return
    protected bool CheckPause(const string &in part) {
        if (Time::Now - lastSearchPause > 15) {
            OnProcessPaused("BlockInventory" + (part.Length > 0 ? "::" + part : ""));
            yield();
            AfterProcessPaused();
            lastSearchPause = Time::Now;
        }
        return true;
    }

    void DumpClipInfo(const string &in path, IO::FileMode mode = IO::FileMode::Write) {
        if (path.Length == 0) throw("Path is empty");
        _dumpCIPath = path;
        _dumpCIMode = mode;
        startnew(CoroutineFunc(_DumpCI_MainCoro));

    }

    string _dumpCIPath;
    IO::FileMode _dumpCIMode;
    void _DumpCI_MainCoro() {

        auto path = _dumpCIPath;
        auto mode = _dumpCIMode;
        // IO::File file(path, mode);
        ThinLazyFile@ file = ThinLazyFile(path, mode);
        _DumpCI_BlockIDs(file);
        _DumpCI_Blocks(file);
        yield();
        _DumpCI_AllIDs(file);
        file.Close();
        yield();
        OpenExplorerPath(Path::GetDirectoryName(path));
    }

    void _DumpCI_BlockIDs(ThinLazyFile& file) {
        file.WriteLine("# [START:BlockIDs]");
        for (uint i = 0; i < blockInfos.Length; i++) {
            file.WriteLine(blockInfos[i].nameId.GetName());
            if ((i+1) % 50 == 0 && !CheckPause("_DumpCI_BlockIDs")) return;
        }
        file.WriteLine("# [END:BlockIDs]");

    }

    void _DumpCI_Blocks(ThinLazyFile& file) {
        file.WriteLine("# [START:Blocks]");
        for (uint i = 0; i < blockInfos.Length; i++) {
            blockInfos[i].DumpToFile(file);
            if ((i+1) % 20 == 0 && !CheckPause("_DumpCI_Blocks")) return;
        }
        file.WriteLine("# [END:Blocks]");
    }

    void _DumpCI_AllIDs(ThinLazyFile& file) {
        file.WriteLine("# [START:IDs]");
        _DumpCI_IDs(file, ClipIdsToClips, "ClipIdsToClips");
        _DumpCI_IDs(file, GroupIdsToClips, "GroupIdsToClips");
        // _DumpCI_IDs(file, SymGroupIdsToClips, "SymGroupIdsToClips");
        // _DumpCI_IDs(file, SymIdsToClips, "SymIdsToClips");
        // _DumpCI_IDs(file, BlocksById, "BlocksById");
        file.WriteLine("# [END:IDs]");
    }

    void _DumpCI_IDs(ThinLazyFile& file, IntLookup& lookup, const string &in name) {
        file.WriteLine("## [START:IDs_" + name + "]");
        uint next = -1, count = 0;
        while (lookup.KeyIterGetNext(next, next)) {
            if (next == 0xFFFFFFFF) throw("Unexpected id = -1");
            file.WriteLine(MwIdValueToStr(next | 0x40000000));
            if (++count % 50 == 0 && !CheckPause("_DumpCI_IDs")) return;
        }
        file.WriteLine("## [END:IDs_" + name + "]");
    }
}


void SanityCheckFoundBlocks(uint[] &in foundBlockIxs) {
    if (foundBlockIxs.Length == 0) return;
    if (foundBlockIxs.Find(-1) != -1) {
        Dev_NotifyWarning("Found -1 in foundBlockIxs");
        throw("Found -1 in foundBlockIxs");
        return;
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

    WFC_ClipInfo@ GetRandomClip(bool cardinal = true) {
        return BlockInfo.GetRandomClip(cardinal);
    }

    int3 CalcClipConnectingCoord(WFC_ClipInfo@ clip, CardinalDir &out dir) {
        int3 offset = clip.buiOffset;
        // rotate according to this block's direction
        offset = RotateOffset(offset, Dir, BlockInfo.Size);
        // move in the direction of the clip
        auto _dir = RotateDir(Dir, clip.dirFromParent);
        dir = RotateDir(_dir, 2);
        // dir = _dir;
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
ClipFace RotateDir(int dir, int rot) {
    if (dir >= 4) return ClipFace(dir);
    return ClipFace((int(dir) + rot + 4) % 4);
}

// MARK: IntLookup


// 4 (2^4 = 16)
const uint INT_LOOKUP_CHILDREN_SHL = 4;
// 16
const uint INT_LOOKUP_CHILDREN = 2 ** INT_LOOKUP_CHILDREN_SHL;


class IntLookup {
    IntLookup@[] children;
    ref@[]@ values;
    // x = values, y = nodes, z = total
    int2 cachedCount = int2(-1);
    uint nodeKey = 0xFFFFFFFF, nodeId = 0xFFFFFFFF; // Use 0xFFFFFFFF as uninitialized/invalid

    IntLookup() {
        @values = {};
    }

    bool Has(uint key) {
        if (key == 0xFFFFFFFF) return false;
        return Get(key) !is null;
    }

    // Get from the root node.
    ref@[]@ Get(uint key) {
        if (key == 0xFFFFFFFF) return null;
        key = key & 0x00FFFFFF;
        return Get(key, key);
    }

    // Internal get for children.
    ref@[]@ Get(uint key, uint id) {
        if (id == 0xFFFFFFFF) return null; // Check against actual invalid marker
        // mask out the top 8 bits (mwids)
        id = id & 0x00FFFFFF;
        key = key & 0x00FFFFFF;

        if (nodeKey == key) {
            if (values.Length == 0) return null;
            return values;
        }

        if (children.Length == 0) return null;
        uint childIx = id % INT_LOOKUP_CHILDREN;
        if (childIx >= children.Length || children[childIx] is null) return null; // Bounds check
        return children[childIx].Get(key, id >> INT_LOOKUP_CHILDREN_SHL);
    }

    void Insert(uint itemKey, ref@ thing) {
        Insert(itemKey, itemKey, thing);
    }

    // key stays the same, id is manipulated to find the right child
    void Insert(uint itemKey, uint id, ref@ thing) {
        string logPrefix = "IntLookup2::Insert[" + Text::Format("0x%X", nodeKey) + " / " + Text::Format("0x%X", itemKey) + "]: ";
        if (thing is null) {
            // warn(logPrefix + "Attempted to insert null reference for key: " + itemKey);
            return;
        }
        if (id | itemKey == 0xFFFFFFFF) {
            // warn(logPrefix + "id/itemKey is invalid (0xFFFFFFFF)");
            return;
        }
        cachedCount = int2(-1);
        // mask out the top 8 bits (mwids)
        id = id & 0x00FFFFFF;
        itemKey = itemKey & 0x00FFFFFF;

        if (nodeKey == itemKey) {
            // if (values.FindByRef(thing) != -1) {
            //     print(logPrefix + "Duplicate itemKey " + itemKey + " for id " + id + " already exists.");
            //     return;
            // }
            // print(logPrefix + "Adding itemKey " + itemKey + " for id " + id + " to existing node.");
            values.InsertLast(thing);
            return;
        }

        bool noKids = children.Length == 0;
        bool noValues = values.Length == 0;

        if (noKids && noValues && nodeKey == 0xFFFFFFFF) { // && id < 0x40) { // Ensure nodeKey is unassigned and don't insert too much at the top
            // print(logPrefix + "First itemKey " + itemKey + " for id " + id + " in empty node.");
            nodeKey = itemKey;
            nodeId = id; // This 'id' is the original (shifted) id for itemKey at this point in tree
            values.InsertLast(thing);
            return;
        }

        if (noKids) {
            // print(logPrefix + "No children, creating new children array.");
            children.Resize(INT_LOOKUP_CHILDREN);
            if (nodeId != 0xFFFFFFFF && nodeKey != 0xFFFFFFFF) { // Check if nodeKey/nodeId were set
                // print(logPrefix + "Inner test.");
                if (this.nodeId != 0 && this.nodeKey != 0xFFFFFFFF) { // Using this.nodeId, the one stored in the node
                    // print(logPrefix + "Migrating values ("+values.Length+") from nodeKey " + this.nodeKey + " to children.");

                    uint childIxForOldValues = this.nodeId % INT_LOOKUP_CHILDREN;
                    if (children[childIxForOldValues] !is null) throw("Child already exists for old values.");
                    auto @next = IntLookup();
                    @(children[childIxForOldValues]) = next;
                    // Pass the original nodeKey and the *next level* of nodeId
                    @next.values = values;
                    next.nodeKey = this.nodeKey;
                    next.nodeId = this.nodeId >> INT_LOOKUP_CHILDREN_SHL;
                    // children[childIxForOldValues].InsertMany(this.nodeKey, this.nodeId >> INT_LOOKUP_CHILDREN_SHL, values);
                    // Clear the values from this node
                    @values = {};

                    this.nodeKey = 0xFFFFFFFF; // This node becomes an internal node
                    this.nodeId = 0xFFFFFFFF;
                    // print(logPrefix + "Reset nodeKey and nodeId after migration.");
                    if (id == 0) {
                        this.Insert(itemKey, id, thing); // Re-insert the new itemKey
                        return;
                    }
                } else {
                    // print(logPrefix + "No migration needed, just adding to values.");
                }
            }
        }

        uint childIx = id % INT_LOOKUP_CHILDREN;
        if (childIx >= children.Length) { // Should not happen if resized properly
            //  warn(logPrefix + "Child index out of bounds before insert.");
             children.Resize(INT_LOOKUP_CHILDREN); // Ensure it's sized
        }

        if (children[childIx] is null) {
            @children[childIx] = IntLookup();
        }
        // print(logPrefix + "Adding itemKey " + itemKey + " for id " + id + " to child[" + childIx + "].");
        children[childIx].Insert(itemKey, id >> INT_LOOKUP_CHILDREN_SHL, thing);
    }

    // for use at the root
    void InsertMany(uint itemKey, ref@[]@ things) {
        for (uint i = 0; i < things.Length; i++) {
            Insert(itemKey, things[i]);
        }
    }

    // for internal use
    void InsertMany(uint itemKey, uint id, ref@[]@ things) {
        for (uint i = 0; i < things.Length; i++) {
            Insert(itemKey, id, things[i]);
        }
    }

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

    // Helper for debugging
    string GetStructure(const string &in indent = "") {
        string s = indent + "Node: key=" + Text::Format("0x%X", nodeKey) + ", id=" + Text::Format("0x%X", nodeId) + ", values=" + values.Length + "\n";
        if (children.Length > 0) {
            s += indent + " Children:\n";
            for (uint i = 0; i < children.Length; i++) {
                if (children[i] !is null) {
                    s += indent + "  [" + i + "]:\n";
                    s += children[i].GetStructure(indent + "    ");
                }
            }
        }
        return s;
    }

    // returns true while there are more keys to iterate
    bool KeyIterGetNext(uint &out nextKey, uint priorKey) {
        return KeyIterGetNext(nextKey, priorKey, priorKey);
    }

    // returns true while there are more keys to iterate
    bool KeyIterGetNext(uint &out nextKey, uint priorKey, uint priorId) {
        /* We want to get the key after priorKey.
        - Is priorKey under this node? id == 0 -> next child
        -                              id > 0 -> call appropriate child, then next if false
        - Is priorKey the last key under this node? if yes: return false (handled by parent caller)
        - priorId == -1 => the prior key is before this node. So we get the first entry in our node that we can.
        - priorId other than -1 => prior key is in this node.
        -   - if 0 => return first child.
        -   - if nonzero, call corresponding child.
        -     - if true, return.
        -     - if false, call next or return false.
        */

        // if we have no values nor children, we can't iterate from here.
        bool hasKids = children.Length > 0;
        bool hasValues = values.Length > 0;
        if (!hasValues and !hasKids) {
            nextKey = -1;
            return false;
        }
        // check for if prior was before this node.
        if (priorId == -1) {
            // if something lives here
            if (nodeId != -1) {
                nextKey = nodeKey;
                return true;
            }
            return hasKids && _KeyIterGetNext_FromFirstChild(nextKey, priorKey);
        }

        // was prior this node?
        if (nodeId == priorId) {
            return hasKids && _KeyIterGetNext_FromFirstChild(nextKey, priorKey);
        }

        // otherwise, it's in a child.
        if (!hasKids) {
            nextKey = -1;
            return false;
        }
        auto childIx = priorId % INT_LOOKUP_CHILDREN;
        return _KeyIterGetNext_FromFirstChild(nextKey, priorId, childIx, priorId >> INT_LOOKUP_CHILDREN_SHL);

    }

    // assumes children exist
    bool _KeyIterGetNext_FromFirstChild(uint&out nextKey, uint priorKey, uint startIx = 0, uint priorId = -1) {
        for (uint i = startIx; i < INT_LOOKUP_CHILDREN; i++) {
            if (children[i] !is null) {
                // did we find nextKey?
                bool ret = children[i].KeyIterGetNext(nextKey, priorKey, priorId);
                if (ret) { return ret; }
                // otherwise continue
                // reset priorId: if we are given a startIx and a priorId, we can only use that for the first child we check (since that's where the id leads).
                priorId = -1;
            }
        }
        nextKey = -1;
        return false;
    }

    // bool KIGN_Notes() {
    //     // if the prior key was -1, then we're at the start of iter and we need to get the first key.
    //     if (priorKey == 0xFFFFFFFF) {
    //         // this node is always before children
    //         if (nodeKey != 0xFFFFFFFF) {
    //             nextKey = nodeKey;
    //             return true;
    //         }
    //         if (children.Length > 0) {
    //             for (uint i = 0; i < INT_LOOKUP_CHILDREN; i++) {
    //                 if (children[i] is null) continue;
    //                 return children[i].KeyIterGetNext(nextKey, nodeId);
    //             }
    //         }
    //         nextKey = 0xFFFFFFFF;
    //         return false;
    //     }

    //     // if the prior key was our key, then id == 0 or we're a shortcut node so we go to children.
    //     if (priorKey == nodeKey) {
    //         if (children.Length > 0) {
    //             for (uint i = 0; i < INT_LOOKUP_CHILDREN; i++) {
    //                 if (children[i] is null) continue;
    //                 return children[i].KeyIterGetNext(nextKey, nodeId);
    //             }
    //         }
    //         nextKey = 0xFFFFFFFF;
    //         return false;

    //     }
    // }
}




string UintArrToString(const uint[] &in arr, bool withSurroundingBrackets = true) {
    string s = (withSurroundingBrackets ? "[" : "");
    for (uint i = 0; i < arr.Length; i++) {
        s += Text::Format("0x%X", arr[i]);
        if (i != arr.Length - 1) s += ", ";
    }
    if (withSurroundingBrackets) s += "]";
    return s;
}



#endif

// MARK: ^ IF COMPILE_WFC



#if DEV && COMPILE_WFC

Tester@ T_RotOffset = Tester("Test_RotateOffset", {
    TestCase("2x1x2a", Test_RotateOffset::_2x1x2_1_1),
    TestCase("2x3x3a", Test_RotateOffset::_2x3x3_1_2),
    TestCase("2x3x3b", Test_RotateOffset::_2x3x3_1_1),
    TestCase("2x3x3c", Test_RotateOffset::_2x3x3_0_1)
});

namespace Test_RotateOffset {
    void _2x1x2_1_1() { Test_RotateOffset_Inner(int3(1, 0, 1), int3(2, 1, 2), int3(0, 0, 1), int3(0, 0, 0), int3(1, 0, 0)); }
    void _2x3x3_1_2() { Test_RotateOffset_Inner(int3(1, 2, 2), int3(2, 3, 3), int3(0, 2, 1), int3(0, 2, 0), int3(2, 2, 0)); }
    void _2x3x3_1_1() { Test_RotateOffset_Inner(int3(1, 1, 1), int3(2, 3, 3), int3(1, 1, 1), int3(0, 1, 1), int3(1, 1, 0)); }
    void _2x3x3_0_1() { Test_RotateOffset_Inner(int3(0, 0, 1), int3(2, 3, 3), int3(1, 0, 0), int3(1, 0, 1), int3(1, 0, 1)); }

    void Test_RotateOffset_Inner(int3 offset, int3 blockSize, int3 expEast, int3 expSout, int3 expWest) {
        auto dir = CardinalDir::North;
        auto newOffset = RotateOffset(offset, dir + 4, blockSize);
        assert_eq(newOffset, offset, "North = no rotation");

        dir = CardinalDir::East;
        newOffset = RotateOffset(offset, dir, blockSize);
        assert_eq(expEast, newOffset, "East = -z, +x");

        dir = CardinalDir::South;
        newOffset = RotateOffset(offset, dir, blockSize);
        assert_eq(expSout, newOffset, "South = -x, -z");

        dir = CardinalDir::West;
        newOffset = RotateOffset(offset, dir, blockSize);
        assert_eq(expWest, newOffset, "West = +z, -x");
        // print("\\$4f4 Test_RotateOffset: Test Passed");


    }
}

void Test_RotateOffset() {


}

awaitable@ PC_Test_RotateOffset = startnew(Test_RotateOffset);


#endif
