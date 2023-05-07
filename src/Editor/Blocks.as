namespace Editor {

    uint16 FreeBlockPosOffset = GetOffset("CGameCtnBlock", "Dir") + 0x8;
    uint16 FreeBlockRotOffset = FreeBlockPosOffset + 0xC;

    vec3 GetBlockLocation(CGameCtnBlock@ block) {
        if (IsBlockFree(block)) {
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
        // auto desc = BlockDesc(block);
        // @block = null;
        Editor::RefreshBlocksAndItems(editor);
        return Editor::FindReplacementBlockAfterUpdate(editor, desc);
        // return block;
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

    CGameCtnBlock@[] FindBakedBlocksMatching(CGameCtnEditorFree@ editor, BlockDesc@ desc) {
        // todo
        return {};
    }

    // the index of the block in the main blocks array
    uint GetBlockMapBlocksIndex(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, 0x8c);
    }

    // set on save, similar to items
    uint GetBlockUniqueSaveID(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, 0x90);
    }

    // Block ID -- incremented by items and blocks
    uint GetBlockUniqueID(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, 0x98);
    }

    // unknown ID, increments with block ID
    uint GetBlockMwIDRaw(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, 0xA4);
    }

    // Count of *placed* blocks (excludes grass), starts at 0 and increments
    uint GetBlockPlacedCountIndex(CGameCtnBlock@ block) {
        return Dev::GetOffsetUint32(block, 0xAC);
    }
}


class BlockDesc {
    nat3 Coord;
    vec3 Pos;
    vec3 Rot;
    bool IsGhost;
    bool IsGround;
    CGameCtnBlock::ECardinalDirections Dir;
    uint DescIdVal;
    uint VariantIndex;
    uint _BlockId;

    BlockDesc(CGameCtnBlock@ block) {
        Coord = block.Coord;
        Pos = Editor::GetBlockLocation(block);
        Rot = Editor::GetBlockRotation(block);
        IsGhost = block.IsGhostBlock();
        IsGround = block.IsGround;
        Dir = block.BlockDir;
        DescIdVal = block.DescId.Value;
        VariantIndex = block.BlockInfoVariantIndex;
        _BlockId = Editor::GetBlockUniqueID(block);
    }

    bool Matches(CGameCtnBlock@ block) {
        if (block is null) return false;

        return DescIdVal == block.DescId.Value
            && Math::Vec3Eq(Pos, Editor::GetBlockLocation(block))
            && Math::Nat3Eq(Coord, block.Coord)
            && IsGhost == block.IsGhostBlock()
            && IsGround == block.IsGround
            && Dir == block.Dir
            && VariantIndex == block.BlockInfoVariantIndex
            && Math::Vec3Eq(Rot, Editor::GetBlockRotation(block))
            ;
    }
}
