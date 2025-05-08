bool PLACE_IN_GHOST_MODE = false;

uint nbToPlaceRandomly = 10;

uint S_SleepMsBetweenRandPlace = 500;

class SceneryGenTab : Tab {
    SceneryGenTab(TabGroup@ parent) {
        super(parent, "Scenery Gen" + NewIndicator, Icons::Tree + Icons::Magic);
    }

    void DrawInner() override {
        auto blockInv = WFC::GetBlockInventory();
        UI::Text("Count: " + blockInv.count);
        if (blockInv.IngestionDone) {
            UI::Text("Block inventory loaded.");
            UI::Text("Duration ms: " + blockInv.ingestionDuration);
            UI::Text("SymIdsToClips: " + blockInv.SymIdsToClips.Count().ToString());
            UI::Text("GroupIdsToClips: " + blockInv.GroupIdsToClips.Count().ToString());
            UI::Text("SymGroupIdsToClips: " + blockInv.SymGroupIdsToClips.Count().ToString());
            nbToPlaceRandomly = UI::SliderInt("Blocks to place", nbToPlaceRandomly, 1, 100);
            S_SleepMsBetweenRandPlace = UI::SliderInt("Sleep (ms) between blocks", S_SleepMsBetweenRandPlace, 1, 2000);
            if (UI::Button("Start new (" + nbToPlaceRandomly + ")")) {
                startnew(CoroutineFunc(this.PlaceRandomBlocks));
            }
            UI::SameLine();
            if (UI::Button("New from cursor (" + nbToPlaceRandomly + ")")) {
                startnew(CoroutineFunc(this.PlaceRandomBlocksStartFromCursor));
            }
            if (UI::Button("Continue for " + nbToPlaceRandomly + " blocks")) {
                startnew(CoroutineFunc(this.PlaceNextRandomBlocksContinue));
            }
            INCLUDE_CG1 = UI::Checkbox("Include CG1", INCLUDE_CG1);
            INCLUDE_CG2 = UI::Checkbox("Include CG2", INCLUDE_CG2);
            INCLUDE_SCG1 = UI::Checkbox("Include SCG1", INCLUDE_SCG1);
            INCLUDE_SCG2 = UI::Checkbox("Include SCG2", INCLUDE_SCG2);
            INCLUDE_SCID = UI::Checkbox("Include SCID", INCLUDE_SCID);
            INCLUDE_ID = UI::Checkbox("Include ID", INCLUDE_ID);
            PLACE_IN_GHOST_MODE = UI::Checkbox("Place in Ghost Mode", PLACE_IN_GHOST_MODE);

            DrawPlaceBlockDebug(blockInv);
        } else {
            UI::Text("Block inventory not loaded.");
        }

        DrawBlockInv(blockInv);
    }

    WFC_BlockInfo@ testBlock;
    PlacedBlock@ testPlaced;
    WFC_BlockInfo@ adjoining;
    WFC_ClipInfo@ clipToPlace;
    WFC_BlockInfo@ blockInfoToPlace;
    int m_dir = 0;
    void DrawPlaceBlockDebug(BlockInventory@ blockInv) {
        DrawNvgDebug();
        if (testBlock is null) @testBlock = blockInv.FindBlockByName("OpenTechHillsShortCurve1Out");
        if (testBlock is null) return;

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = cast<CSmEditorPluginMapType>(editor.PluginMapType);

        UI::SetNextItemWidth(200);
        m_dir = UI::SliderInt("Direction", m_dir, 0, 3);
        UI::SameLine();
        UI::Text(": " + tostring(CardinalDir(m_dir)));

        if (UI::Button("1. Place Block")) {
            @testPlaced = null;
            _drawCoord = false;
            auto coord = Nat3ToInt3(editor.Challenge.Size / 2);
            auto dir = CGameEditorPluginMap::ECardinalDirections(m_dir);
            pmt.RemoveBlock(coord);
            if (!pmt.PlaceBlock(testBlock.BlockInfo, coord, dir)) {
                Dev_NotifyWarning("Failed to place block");
                return;
            }
            Editor::SetCamAnimationGoTo(Editor::GetCurrentCamState(editor).withPos(CoordToPos(coord) + HALF_COORD));
            @testPlaced = PlacedBlock(testBlock, coord, CardinalDir(dir));
        }

        fakeClipSize = UX::InputInt3("3. Clip Size##c", fakeClipSize);
        fakeClipOffset = UX::InputInt3("3. Clip Offset##c", fakeClipOffset);
        UI::Text("3. Dir From P: " + tostring(fakeClipDirFromP));
        UI::SameLine();
        if (UI::Button("<-")) fakeClipDirFromP = RotateDir(fakeClipDirFromP, -1);
        UI::SameLine();
        if (UI::Button("->")) fakeClipDirFromP = RotateDir(fakeClipDirFromP, 1);
        UI::Text("refOffset: " + refOffset.ToString());

        if (testPlaced is null) return;
        auto @clips = testPlaced.BlockInfo.clips;
        for (uint i = 0; i < clips.Length; i++) {
            if (UI::TreeNode("Clip[" + i + "]: ", UI::TreeNodeFlags::DefaultOpen)) {
                UI::TextWrapped(clips[i].ToString());
                if (UI::Button("Draw 1##c" + i)) {
                    SetDrawnClip(testPlaced, clips[i], 1);
                }
                if (UI::Button("Draw 2##c" + i)) {
                    SetDrawnClip(testPlaced, clips[i], 2);
                }
                if (UI::Button("Draw 3##c" + i)) {
                    SetDrawnClip(testPlaced, clips[i], 3);
                }
                UI::SameLine();
                if (UI::Button("<-##" + i)) {
                    fakeClipDirFromP = RotateDir(fakeClipDirFromP, -1);
                    FixFakeClipOffset();
                    SetDrawnClip(testPlaced, clips[i], 3);
                }
                UI::SameLine();
                if (UI::Button("->##" + i)) {
                    fakeClipDirFromP = RotateDir(fakeClipDirFromP, 1);
                    FixFakeClipOffset();
                    SetDrawnClip(testPlaced, clips[i], 3);
                }

                if (UI::Button("Find Matching##c" + i)) {
                    OnClickFindMatchingClip(blockInv, testPlaced, clips[i]);
                }
                UI::TreePop();
            }
        }



        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // auto pmt = editor.PluginMapType;
        // auto mapSize = Nat3ToInt3(editor.Challenge.Size);
        // UI::Text("Map Size: " + mapSize.ToString());
        // UI::Separator();
        // if (UI::Button("Place Random Block")) {
        //     startnew(CoroutineFunc(this.PlaceRandomBlocks, 1));
        // }
        // if (UI::Button("Place Random Blocks")) {
        //     startnew(CoroutineFunc(this.PlaceRandomBlocks));
        // }
    }

    void OnClickFindMatchingClip(BlockInventory@ blockInv, PlacedBlock@ pb, WFC_ClipInfo@ clip) {
        CardinalDir dirFromBlock;
        int3 clipCoord = testPlaced.CalcClipConnectingCoord(clip, dirFromBlock);
        @clipToPlace = blockInv.GetRandomConnectingClipFromClip(clip);
        if (clipToPlace is null) {
            Dev_NotifyWarning("No clip found");
            return;
        }
        @blockInfoToPlace = blockInv.blockInfos[clipToPlace.biIx];

        auto newBlockDir = RotateDir(dirFromBlock, 2 - clipToPlace.dirFromParent);
        auto revOffset = RotateOffset(clipToPlace.buiOffset, newBlockDir, blockInfoToPlace.Size);
        clipCoord = clipCoord - revOffset;

        _drawClipMats.InsertLast(Editor::GetBlockMatrix(clipCoord, newBlockDir, blockInfoToPlace.Size));
        _drawClipSizes.InsertLast(Int3ToVec3(blockInfoToPlace.Size) * Editor::DEFAULT_COORD_SIZE);
    }

    int3 refOffset = int3(0, 0, 0);
    bool _drawCoord = false;
    mat4 _drawClipMat = mat4::Identity();
    vec3 _drawClipSize = Editor::DEFAULT_COORD_SIZE;
    mat4[] _drawClipMats = {};
    vec3[] _drawClipSizes = {};
    vec4[] cMatColors = {
        cYellow, cRed, cGreen, cCyan, cBlue, cMagenta, cOrange
    };

    void DrawNvgDebug() {
        if (_drawCoord) {
            nvgDrawBlockBox(_drawClipMat, _drawClipSize, cWhite, DrawFaces::All, true);
        }
        if (_drawClipMats.Length > 0) {
            for (uint i = 0; i < _drawClipMats.Length; i++) {
                nvgDrawBlockBox(_drawClipMats[i], _drawClipSizes[i], cMatColors[i % cMatColors.Length], DrawFaces::All, true);
            }
        }
    }

    void SetDrawnClip(PlacedBlock@ pb, WFC_ClipInfo@ clip, int step = 1) {
        _drawClipMats.RemoveRange(0, _drawClipMats.Length);
        _drawClipSizes.RemoveRange(0, _drawClipSizes.Length);
        if (clip is null) return;
        _drawCoord = true;
        _drawClipMat = clip.GetBlockMatrix(pb);
        _drawClipSize = Int3ToVec3(pb.BlockInfo.Size) * Editor::DEFAULT_COORD_SIZE;
        if (step <= 1) return;
        // CardinalDir dir;
        // auto coord = pb.CalcClipConnectingCoord(clip, dir);
        auto dir = (pb.Dir);
        auto clipOffset = clip.buiOffset;
        clipOffset = RotateOffset(clipOffset, dir, pb.BlockInfo.Size);
        auto dirFromBlock = RotateDir(dir, clip.dirFromParent);
        clipOffset = MoveOffset(clipOffset, dirFromBlock);
        auto coord = pb.Coord + clipOffset;
        // placing dir
        auto newDir = RotateDir(dirFromBlock, 2);
        _drawClipMat = Editor::GetBlockMatrix(Int3ToNat3(coord), int(newDir), nat3(1, 1, 1));
        _drawClipSize = Editor::DEFAULT_COORD_SIZE;

        if (step <= 2) return;

        newDir = RotateDir(newDir, -1 * fakeClipDirFromP);
        refOffset = RotateOffset(fakeClipOffset, newDir, fakeClipSize);
        coord = coord - refOffset * GetBlockCoordMaskForDir(newDir);
        // coord = coord + GetBlockCoordOffsetForDir(fakeClipSize, newDir);
        _drawClipMats.InsertLast(Editor::GetBlockMatrix(coord, int(newDir), fakeClipSize));
        _drawClipSizes.InsertLast(Int3ToVec3(fakeClipSize) * Editor::DEFAULT_COORD_SIZE);


    }

    int3 fakeClipSize = int3(2, 2, 2);
    int3 fakeClipOffset = int3(1, 1, 1);
    CardinalDir fakeClipDirFromP = CardinalDir::South;

    void FixFakeClipOffset() {
        if (fakeClipDirFromP == CardinalDir::South) {
            fakeClipOffset.z = 0;
        } else if (fakeClipDirFromP == CardinalDir::West) {
            fakeClipOffset.x = fakeClipSize.x - 1;
        } else if (fakeClipDirFromP == CardinalDir::North) {
            fakeClipOffset.z = fakeClipSize.z - 1;
        } else if (fakeClipDirFromP == CardinalDir::East) {
            fakeClipOffset.x = 0;
        }
    }

    void PlaceRandomBlocks() {
        PlaceRandomBlocks(nbToPlaceRandomly, false);
    }

    void PlaceNextRandomBlocksContinue() {
        PlaceRandomBlocks(nbToPlaceRandomly, true);
    }

    void PlaceRandomBlocksStartFromCursor() {
        PlaceRandomBlocks(nbToPlaceRandomly, false, true);
    }

    void PlaceRandomBlocks(int nbToPlace, bool continueFromPrev = true, bool startFromCursor = false) {
        auto blockInv = WFC::GetBlockInventory();
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;
        auto mapSize = Nat3ToInt3(editor.Challenge.Size);
        PlacedBlock@ clipSource = continueFromPrev ? lastPlacedRandBlock : null;
        auto _nbToPlace = nbToPlace;
        while (_nbToPlace > 0) {
            sleep(S_SleepMsBetweenRandPlace);
            @clipSource = FindAndPlaceRandomBlock(editor, blockInv, mapSize, clipSource, startFromCursor);
            @lastPlacedRandBlock = clipSource;
            _nbToPlace--;
        }
        print("Placed " + nbToPlace + " blocks");
        // WFC_BlockInfo@ startBlock;
        // int3 startingCoord;
        // CGameEditorPluginMap::ECardinalDirections randDir;
        // bool placed;
        // uint loopCount = 0;
        // _Log::Trace("Placing block...");
        // while (!placed) {
        //     @startBlock = blockInv.GetRandomBlock(2);
        //     startingCoord = GetRandomCoord(int3(0, 12, 0), mapSize);
        //     // randDir = GetRandomDirection();
        //     randDir = GetRandomDirection();
        //     _Log::Trace("Random Direction: " + tostring(randDir));
        //     // canPlace = pmt.CanPlaceBlock_NoDestruction(startBlock.BlockInfo, startingCoord, randDir, false, startBlock.VarIx);
        //     placed = pmt.PlaceBlock_NoDestruction(startBlock.BlockInfo, startingCoord, randDir);
        //     loopCount++;
        // }
        // _Log::Trace("Starting Block: " + startBlock.nameId.GetName());
        // _Log::Trace("Starting Coord: " + startingCoord.ToString());
        // _Log::Trace("Starting Direction: " + tostring(randDir));
        // _Log::Trace("Loop Count: " + loopCount);
        // _Log::Trace("Placed block");
        // Editor::SetCamAnimationGoTo(Editor::GetCurrentCamState(editor).withPos(CoordToPos(startingCoord)));
        // auto pb = PlacedBlock(startBlock, startingCoord, randDir);
        // _Log::Trace("Placed Block: " + pb.ToString());
        // nbToPlace--;

        // while (nbToPlace > 0) {
        //     @startBlock = blockInv.GetRandomBlock(2);
        //     startingCoord = GetRandomCoord(int3(0, 12, 0), mapSize);
        //     randDir = GetRandomDirection();
        //     placed = pmt.PlaceBlock_NoDestruction(startBlock.BlockInfo, startingCoord, randDir);
        //     loopCount++;
        //     _Log::Trace("Placed Block: " + startBlock.nameId.GetName());
        //     _Log::Trace("Starting Coord: " + startingCoord.ToString());
        //     _Log::Trace("Starting Direction: " + tostring(randDir));
        //     _Log::Trace("Loop Count: " + loopCount);
        //     nbToPlace--;
        // }
    }

    PlacedBlock@ lastPlacedRandBlock = null;
    uint placeFailures = 0;

    PlacedBlock@ FindAndPlaceRandomBlock(CGameCtnEditorFree@ editor, BlockInventory@ blockInv, const int3 &in mapSize, PlacedBlock@ clipSource = null, bool startFromCursor = false) {
        // if clipSource is empty, we choose a random coord.
        bool noClips = clipSource is null;
        auto pmt = editor.PluginMapType;
        WFC_BlockInfo@ startBlock = null;
        int3 startingCoord = int3(0, 0, 0);
        CGameEditorPluginMap::ECardinalDirections randDir;
        bool placed = false;
        uint loopCount = 0, loopLimit = 50;
        _Log::Warn("Placing block...");

        while (!placed && loopCount < loopLimit) {
            loopCount++;
            if (noClips) {
                if (startFromCursor) {
                    @startBlock = blockInv.GetCursorBlock();
                } else {
                    @startBlock = blockInv.GetRandomBlock(2);
                }
                startingCoord = GetRandomCoord(int3(0, 12, 0), mapSize);
                // randDir = GetRandomDirection();
                randDir = GetRandomDirection();
            } else {
                @startBlock = blockInv.GetRandomAdjoiningBlock(1, clipSource, startingCoord, randDir);
                if (startBlock is null) {
                    _Log::Warn("No adjoining block found");
                    noClips = loopCount > loopLimit - 5;
                    continue;
                }
            }
            _Log::Trace("Rand Block: " + startBlock.nameId.GetName());
            _Log::Trace("Rand Coord: " + startingCoord.ToString());
            _Log::Trace("Random Direction: " + tostring(randDir));
            // canPlace = pmt.CanPlaceBlock_NoDestruction(startBlock.BlockInfo, startingCoord, randDir, false, startBlock.VarIx);
            if (PLACE_IN_GHOST_MODE) {
                placed = pmt.PlaceGhostBlock(startBlock.BlockInfo, startingCoord, randDir);
            } else {
                placed = pmt.PlaceBlock(startBlock.BlockInfo, startingCoord, randDir);
            }
            if (!placed) {
                placeFailures++;
                _Log::Trace("Failed to place block; consecutive failures: " + placeFailures);
            } else {
                placeFailures = 0;
            }
        }
        _Log::Trace("Placed block:");
        _Log::Trace("Block: " + startBlock.nameId.GetName());
        _Log::Trace("Coord: " + startingCoord.ToString());
        _Log::Trace("Direction: " + tostring(randDir));
        _Log::Trace("Loop Count: " + loopCount);
        auto cs = Editor::GetCurrentCamState(editor);
        Editor::SetCamAnimationGoTo(cs.withPos(CoordToPos(startingCoord) + HALF_COORD));
        auto @pb = PlacedBlock(startBlock, startingCoord, CardinalDir(randDir));
        _Log::Trace("PlacedBlock: " + pb.ToString());
        pmt.AutoSave();
        return pb;
    }


    uint m_BlockInvBlock = 0;
    void DrawBlockInv(BlockInventory@ blockInv) {
        if (blockInv is null) return;
        auto nbBlockInfos = blockInv.blockInfos.Length;
        if (nbBlockInfos == 0) {
            UI::Text("No BlockInfo found");
            return;
        }

        m_BlockInvBlock = UI::SliderInt("Block Inventory", m_BlockInvBlock, 0, nbBlockInfos - 1);
        m_BlockInvBlock = Math::Clamp(m_BlockInvBlock, 0, nbBlockInfos - 1);
        UI::Text("Viewing BlockInfo[" + m_BlockInvBlock + "] / " + (nbBlockInfos - 1));

        UI::Separator();

        auto blockInfo = blockInv.blockInfos[m_BlockInvBlock];
        Draw_WFC_BlockInfo(blockInfo);
    }


    void Draw_WFC_BlockInfo(WFC_BlockInfo@ blockInfo) {
        if (blockInfo is null) return;
        UI::Text("nameId: " + blockInfo.nameId.GetName());
        UI::Text("clips.Length: " + blockInfo.clips.Length);
    }
}

int3 GetRandomCoord(int3 min, int3 max) {
    return int3(Math::Rand(min.x, max.x), Math::Rand(min.y, max.y), Math::Rand(min.z, max.z));
}

CGameEditorPluginMap::ECardinalDirections GetRandomDirection() {
    return CGameEditorPluginMap::ECardinalDirections(Math::Rand(0, 3));
}

int3 GetBlockCoordMaskForDir(CardinalDir dir) {
    // switch (dir) {
    //     case CardinalDir::South: return int3(1, -1, 0);
    // }
    return int3(1, 1, 1);
}
