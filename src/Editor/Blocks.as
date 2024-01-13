namespace Editor {
    const uint16 O_CGameCtnBlock_DirOffset = GetOffset("CGameCtnBlock", "Dir");
    const uint16 FreeBlockPosOffset = O_CGameCtnBlock_DirOffset + 0x8;
    const uint16 FreeBlockRotOffset = FreeBlockPosOffset + 0xC;
    const uint16 O_CGameCtnBlock_BlockUnitsEOffset = GetOffset("CGameCtnBlock", "BlockUnitsE");
    const uint16 O_CGameCtnBlock_CoordOffset = GetOffset("CGameCtnBlock", "Coord");
    const uint16 O_CGameCtnBlock_ = GetOffset("CGameCtnBlock", "Coord");

const uint16 O_CGameCtnBlock_BlockMapBlocksIndex   = O_CGameCtnBlock_DirOffset + (0x8c - 0x64) ; // (0x8c + 0x8 - 0x6c)
const uint16 O_CGameCtnBlock_BlockUniqueSaveID     = O_CGameCtnBlock_DirOffset + (0x90 - 0x64) ; // (0x90 + 0x8 - 0x6c)
const uint16 O_CGameCtnBlock_BlockUniqueID         = O_CGameCtnBlock_DirOffset + (0x98 - 0x64) ; // (0x98 + 0x8 - 0x6c)
const uint16 O_CGameCtnBlock_BlockMwIDRaw          = O_CGameCtnBlock_DirOffset + (0xA4 - 0x64) ; // (0xA4 + 0x8 - 0x6c)
const uint16 O_CGameCtnBlock_BlockPlacedCountIndex = O_CGameCtnBlock_DirOffset + (0xAC - 0x64) ; // (0xAC + 0x8 - 0x6c)

    vec3 GetBlockLocation(CGameCtnBlock@ block, bool forceFree = false) {
        if (IsBlockFree(block) || forceFree) {
            // free block mode
            return Dev::GetOffsetVec3(block, FreeBlockPosOffset);
        }
        // using the coord will not give you a consistent corner of the block (i.e., after rotation),
        // pre-adjust the coordinates to account for this based on cardinal dir
        // rclick in editor always rotates around BL (min x/z);
        auto coord = Nat3ToVec3(block.Coord);
        auto coordSize = GetBlockCoordSize(block);
        if (int(block.Dir) == 1) {
            coord.x += coordSize.z - 1;
        }
        if (int(block.Dir) == 2) {
            coord.x += coordSize.x - 1;
            coord.z += coordSize.z - 1;
        }
        if (int(block.Dir) == 3) {
            coord.z += coordSize.x - 1;
        }
        auto pos = CoordToPos(coord);
        auto sqSize = vec3(32, 8, 32);
        auto rot = GetBlockRotation(block);
        return (mat4::Translate(pos) * mat4::Translate(sqSize / 2.) * EulerToMat(rot) * (sqSize / -2.)).xyz;
    }

    void SetBlockLocation(CGameCtnBlock@ block, vec3 pos) {
        if (IsBlockFree(block)) {
            Dev::SetOffset(block, FreeBlockPosOffset, pos);
        } else {
            // not supported
            warn('not yet supported: set block location for non-free block');
        }
    }

    nat3 GetBlockCoord(CGameCtnBlock@ block) {
        if (Editor::IsBlockFree(block)) {
            return PosToCoord(Editor::GetBlockLocation(block));
        }
        return block.Coord;
    }

    void SetBlockCoord(CGameCtnBlock@ block, nat3 coord) {
        block.CoordX = coord.x;
        block.CoordY = coord.y;
        block.CoordZ = coord.z;
    }

    vec3 GetBlockRotation(CGameCtnBlock@ block) {
        if (IsBlockFree(block)) {
            // free block mode
            auto ypr = Dev::GetOffsetVec3(block, FreeBlockRotOffset);
            return vec3(ypr.y, ypr.x, ypr.z);
        }
        return vec3(0, CardinalDirectionToYaw(int(block.Dir)), 0);
    }

    void SetBlockRotation(CGameCtnBlock@ block, vec3 euler) {
        if (int(block.CoordX) < 0) {
            // free block mode
            auto ypr = vec3(euler.y, euler.x, euler.z);
            Dev::SetOffset(block, FreeBlockRotOffset, ypr);
        } else {
            block.BlockDir = CGameCtnBlock::ECardinalDirections(YawToCardinalDirection(euler.y));
        }
    }

    bool IsBlockFree(CGameCtnBlock@ block) {
        return int(block.CoordX) < 0;
    }

    vec3 GetBlockSize(CGameCtnBlock@ block) {
        return GetBlockCoordSize(block) * vec3(32, 8, 32);
    }

    vec3 GetBlockCoordSize(CGameCtnBlock@ block) {
        auto @biv = GetBlockInfoVariant(block);
        return Nat3ToVec3(biv.Size);
    }

    CGameCtnBlockInfoVariant@ GetBlockInfoVariant(CGameCtnBlock@ block) {
        auto bivIx = block.BlockInfoVariantIndex;
        auto bi = block.BlockInfo;
        CGameCtnBlockInfoVariant@ biv;
        if (bivIx > 0) {
            @biv = block.IsGround ? cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsGround[bivIx - 1]) : cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsAir[bivIx - 1]);
        } else {
            @biv = block.IsGround ? cast<CGameCtnBlockInfoVariant>(bi.VariantGround) : cast<CGameCtnBlockInfoVariant>(bi.VariantAir);
            if (biv is null) {
                @biv = block.IsGround ? cast<CGameCtnBlockInfoVariant>(bi.VariantBaseGround) : cast<CGameCtnBlockInfoVariant>(bi.VariantBaseAir);
            }
        }
        return biv;
    }

    vec3 GetCtnBlockMidpoint(CGameCtnBlock@ block) {
        return (GetBlockMatrix(block) * (GetBlockSize(block) / 2.)).xyz;
    }

    mat4 GetBlockMatrix(CGameCtnBlock@ block) {
        return mat4::Translate(GetBlockLocation(block)) * EulerToMat(GetBlockRotation(block));
    }

    /* for normal/ghost blocks, ensure you have no references to the block in questiton!
       Additionally: take a block desc object before hand and use the replicate props function
    */
    CGameCtnBlock@ RefreshSingleBlockAfterModified(CGameCtnEditorFree@ editor, BlockDesc@ desc) {
        Editor::RefreshBlocksAndItems(editor);
        // Editor::RefreshBlocksAndItems(editor);
        return Editor::FindReplacementBlockAfterUpdate(editor, desc);
    }

    CGameCtnBlock@ FindReplacementBlockAfterUpdate(CGameCtnEditorFree@ editor, BlockDesc@ desc) {
        auto map = editor.Challenge;
        if (map is null || map.Blocks.Length == 0) return null;
        for (int i = map.Blocks.Length - 1; i >= 0; i--) {
            if (!desc.Matches(map.Blocks[i])) continue;
            // match!?
            trace('found match: ' + i + " / " + (map.Blocks.Length - 1));
            return map.Blocks[i];
        }
        trace('did not find block (checked: ' + map.Blocks.Length + ")");
        return null;
    }

    // may not work tthat well
    CGameCtnBlock@[]@ FindBakedBlocksMatching(CGameCtnEditorFree@ editor, BlockDesc@ desc) {
        CGameCtnBlock@[] blocks;
        auto origBlockId = desc._BlockId;
        // auto nextBlockId = origBlockId + 1;
        int nextBlockId = -1;

        auto map = editor.Challenge;
        if (map is null || map.BakedBlocks.Length == 0) return null;
        for (uint i = 0; i < map.BakedBlocks.Length; i++) {
            auto _bid = Editor::GetBlockUniqueID(map.BakedBlocks[i]);
            if (nextBlockId < 0 && desc.MatchesBB(map.BakedBlocks[i])) {
                nextBlockId = _bid;
            }
            if (int(_bid) == nextBlockId) {
                blocks.InsertLast(map.BakedBlocks[i]);
                nextBlockId++;
            } else if (nextBlockId >= 0) {
                break;
            }
            // if (!desc.Matches(map.BakedBlocks[i])) continue;
        }
        trace('found baked block matches: ' + blocks.Length + " / " + (map.BakedBlocks.Length - 1));
        return blocks;
    }

    void UpdateBakedBlocksMatching(CGameCtnEditorFree@ editor, BlockDesc@ desc, BlockDesc@ newDesc) {
        auto @blocks = FindBakedBlocksMatching(editor, desc);
        for (uint i = 0; i < blocks.Length; i++) {
            newDesc.SetBakedBlockProps(blocks[i]);
        }
    }



    // the index of the block in the main blocks array
    uint GetBlockMapBlocksIndex(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, O_CGameCtnBlock_BlockMapBlocksIndex);
    }

    // set on save, similar to items
    uint GetBlockUniqueSaveID(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, O_CGameCtnBlock_BlockUniqueSaveID);
    }

    // Block ID -- incremented by items and blocks
    uint GetBlockUniqueID(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, O_CGameCtnBlock_BlockUniqueID);
    }

    // unknown ID, increments with block ID
    uint GetBlockMwIDRaw(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, O_CGameCtnBlock_BlockMwIDRaw);
    }

    // Count of *placed* blocks (excludes grass), starts at 0 and increments
    uint GetBlockPlacedCountIndex(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, O_CGameCtnBlock_BlockPlacedCountIndex);
    }

    void ConvertNormalToFree(CGameCtnBlock@ block, vec3 pos, vec3 rot) {
        // zero block uints at 0x50
        Dev::SetOffset(block, O_CGameCtnBlock_BlockUnitsEOffset, uint64(0));
        Dev::SetOffset(block, O_CGameCtnBlock_BlockUnitsEOffset + 0x8, uint64(0));
        Dev::SetOffset(block, O_CGameCtnBlock_CoordOffset, nat3(-1, 0, -1));
        Dev::SetOffset(block, FreeBlockPosOffset, pos);
        Dev::SetOffset(block, FreeBlockRotOffset, rot);
    }
}


class BlockDesc {
    nat3 Coord;
    vec3 Pos;
    vec3 Rot;
    bool IsGhost;
    bool IsGround;
    CGameCtnBlock::ECardinalDirections Dir;
    CGameCtnBlock::EMapElemColor Color;
    CGameCtnBlock::EMapElemLightmapQuality LMQuality;
    uint DescIdVal;
    uint VariantIndex;
    uint _BlockId;
    bool IsFree;

    BlockDesc(CGameCtnBlock@ block) {
        Coord = block.Coord;
        Pos = Editor::GetBlockLocation(block);
        Rot = Editor::GetBlockRotation(block);
        IsGhost = block.IsGhostBlock();
        IsGround = block.IsGround;
        Dir = block.BlockDir;
        DescIdVal = block.DescId.Value;
        VariantIndex = block.BlockInfoVariantIndex;
        IsFree = Editor::IsBlockFree(block);
        Color = block.MapElemColor;
        LMQuality = block.MapElemLmQuality;
        _BlockId = Editor::GetBlockUniqueID(block);
    }

    bool Matches(CGameCtnBlock@ block) {
        if (block is null) return false;

        return DescIdVal == block.DescId.Value
            && MathX::Vec3Eq(Pos, Editor::GetBlockLocation(block))
            && MathX::Nat3Eq(Coord, block.Coord)
            && IsGhost == block.IsGhostBlock()
            && IsGround == block.IsGround
            && Dir == block.Dir
            && VariantIndex == block.BlockInfoVariantIndex
            && MathX::Vec3Eq(Rot, Editor::GetBlockRotation(block))
            ;
    }

    bool MatchesBB(CGameCtnBlock@ block) {
        if (block is null) return false;

        return true
            && MathX::Nat3Eq(Coord, block.Coord)
            && MathX::Vec3Eq(Pos, Editor::GetBlockLocation(block))
            && IsGhost == block.IsGhostBlock()
            && IsGround == block.IsGround
            && Dir == block.Dir
            && MathX::Vec3Eq(Rot, Editor::GetBlockRotation(block))
            ;
    }

    void SetBakedBlockProps(CGameCtnBlock@ block) {
        if (block is null) return;
        // can set: pos, coord, rot, dir, color, lm
        // don't set: variant, ghost, ground, descid
        if (IsFree) {
            Editor::SetBlockLocation(block, Pos);
        } else {
            Editor::SetBlockCoord(block, Coord);
        }
        Editor::SetBlockRotation(block, Rot);
        block.MapElemColor = Color;
        block.MapElemLmQuality = LMQuality;
    }
}
