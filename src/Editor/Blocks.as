namespace Editor {
    const uint16 O_CGameCtnBlock_DirOffset = GetOffset("CGameCtnBlock", "Dir");
    const uint16 FreeBlockPosOffset = O_CGameCtnBlock_DirOffset + 0x8;
    const uint16 FreeBlockRotOffset = FreeBlockPosOffset + 0xC;
    const uint16 O_CGameCtnBlock_BlockUnitsEOffset = GetOffset("CGameCtnBlock", "BlockUnitsE");
    const uint16 O_CGameCtnBlock_CoordOffset = GetOffset("CGameCtnBlock", "Coord");
    // const uint16 O_CGameCtnBlock_ = GetOffset("CGameCtnBlock", "Coord");

    // 0x1000 = skip for macroblock
    const uint16 O_CGameCtnBlock_MacroblockFlags       = O_CGameCtnBlock_DirOffset + (0x88 - 0x64) ; // (0x88 + 0x8 - 0x6c)

    // flag before this, too. checked by MB thing
    const uint16 O_CGameCtnBlock_BlockMapBlocksIndex   = O_CGameCtnBlock_DirOffset + (0x8c - 0x64) ; // (0x8c + 0x8 - 0x6c)
    const uint16 O_CGameCtnBlock_BlockUniqueSaveID     = O_CGameCtnBlock_DirOffset + (0x90 - 0x64) ; // (0x90 + 0x8 - 0x6c)
    const uint16 O_CGameCtnBlock_BlockUniqueID         = O_CGameCtnBlock_DirOffset + (0x98 - 0x64) ; // (0x98 + 0x8 - 0x6c)
    // macrobloc inst id
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
        auto coordSize = GetBlockCoordSize(block);
        return BlockCoordAndCoordSizeToPos(block.Coord, coordSize, int(block.Dir));
    }

    vec3 GetBlockLocation(BlockSpec@ block) {
        if (block.isFree) {
            return block.pos - vec3(0, 56, 0);
        }
        auto coordSize = GetBlockCoordSize(block);
        return BlockCoordAndCoordSizeToPos(block.coord, coordSize, int(block.dir2)) - vec3(0, 56, 0);
    }

    vec3 BlockCoordAndCoordSizeToPos(nat3 bCoord, vec3 coordSize, int dir) {
        auto coord = Nat3ToVec3(bCoord);
        if (dir == 1) {
            coord.x += coordSize.z - 1;
        }
        if (dir == 2) {
            coord.x += coordSize.x - 1;
            coord.z += coordSize.z - 1;
        }
        if (dir == 3) {
            coord.z += coordSize.x - 1;
        }
        auto pos = CoordToPos(coord);
        return (mat4::Translate(pos) * mat4::Translate(HALF_COORD) * EulerToMat(vec3(0, CardinalDirectionToYaw(dir), 0)) * mat4::Translate(HALF_COORD * -1.) * vec3()).xyz;
    }

    // nat3 BlockPosAndCoordSizeToCoord(vec3 pos, vec3 coordSize, int dir) {
    //     pos = (mat4::Translate(pos + HALF_COORD) * EulerToMat(vec3(0, -1. * CardinalDirectionToYaw(dir), 0)) * mat4::Translate(HALF_COORD * -1.) * vec3()).xyz;
    //     auto coord = PosToCoord(pos);
    //     if (dir == 0) {
    //         coord.z += coordSize.x - 1;
    //     }
    //     if (dir == 1) {
    //         // coord.y += 1;
    //     }
    //     if (dir == 2) {
    //         // coord.x -= coordSize.x - 1;
    //     }
    //     if (dir == 3) {
    //         // coord.x -= coordSize.z - 1;
    //         // coord.z += coordSize.x - 1;
    //     }
    //     return coord;
    // }

    void SetBlockLocation(CGameCtnBlock@ block, vec3 pos) {
        if (IsBlockFree(block)) {
            Dev::SetOffset(block, FreeBlockPosOffset, pos);
        } else {
            // auto coord = BlockPosAndCoordSizeToCoord(pos, GetBlockCoordSize(block), int(block.Dir));
            // block.CoordX = coord.x;
            // block.CoordY = coord.y;
            // block.CoordZ = coord.z;
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

    vec3 GetBlockSize(CGameCtnBlockInfo@ bi) {
        auto biv = GetBlockVariantAny(bi);
        return Nat3ToVec3(biv !is null ? biv.Size : nat3(1)) * vec3(32, 8, 32);
    }

    // coord size as vec3 (not distance, so <1, 1, 1> is a 1x1x1 block)
    vec3 GetBlockCoordSize(CGameCtnBlock@ block) {
        auto @biv = GetBlockInfoVariant(block);
        if (biv is null) return vec3(1);
        return Nat3ToVec3(biv.Size);
    }

    vec3 GetBlockCoordSize(BlockSpec@ block) {
        auto @biv = GetBlockSpecVariant(block);
        return Nat3ToVec3(biv.Size);
    }


    bool DoesBlockInfoHaveMesh(CGameCtnBlockInfo@ bi) {
        if (bi is null) throw("block info is null");
        if (DoesBlockInfoVariantHaveMesh(bi.VariantBaseGround)) return true;
        if (DoesBlockInfoVariantHaveMesh(bi.VariantBaseAir)) return true;
        if (bi.AdditionalVariantsGround.Length > 0) {
            for (uint i = 0; i < bi.AdditionalVariantsGround.Length; i++) {
                auto @biv = bi.AdditionalVariantsGround[i];
                if (biv is null) continue;
                if (DoesBlockInfoVariantHaveMesh(biv)) return true;
            }
        }
        if (bi.AdditionalVariantsAir.Length > 0) {
            for (uint i = 0; i < bi.AdditionalVariantsAir.Length; i++) {
                auto @biv = bi.AdditionalVariantsAir[i];
                if (biv is null) continue;
                if (DoesBlockInfoVariantHaveMesh(biv)) return true;
            }
        }
        return false;
    }

    bool DoesBlockInfoVariantHaveMesh(CGameCtnBlockInfoVariant@ biv) {
        if (biv is null) return false;
        if (biv.Mobils00.Length > 0 && DoesBlockInfoMobilsHaveMesh(biv.Mobils00)) return true;
        if (biv.Mobils01.Length > 0 && DoesBlockInfoMobilsHaveMesh(biv.Mobils01)) return true;
        if (biv.Mobils02.Length > 0 && DoesBlockInfoMobilsHaveMesh(biv.Mobils02)) return true;
        if (biv.Mobils03.Length > 0 && DoesBlockInfoMobilsHaveMesh(biv.Mobils03)) return true;
        if (biv.Mobils04.Length > 0 && DoesBlockInfoMobilsHaveMesh(biv.Mobils04)) return true;
        if (biv.Mobils05.Length > 0 && DoesBlockInfoMobilsHaveMesh(biv.Mobils05)) return true;
        return false;
    }

    bool DoesBlockInfoMobilsHaveMesh(MwFastBuffer<CMwNod@> &in mobils) {
        for (uint i = 0; i < mobils.Length; i++) {
            auto @mobil = cast<CGameCtnBlockInfoMobil>(mobils[i]);
            if (mobil is null) continue;
            if (mobil.PrefabFid !is null) return true;
        }
        return false;
    }


    int GetNbBlockVariants(CGameCtnBlockInfo@ bi, bool isGround) {
        if (bi is null) throw("block info is null");
        auto baseVar = GetBlockBaseVariant(bi, isGround);
        int nbBase = baseVar !is null ? 1 : 0;
        return (isGround ? bi.AdditionalVariantsGround.Length : bi.AdditionalVariantsAir.Length) + nbBase;
    }

    CGameCtnBlockInfoVariant@ GetBlockZerothVariant(CGameCtnBlockInfo@ bi, bool isGround) {
        return isGround ? cast<CGameCtnBlockInfoVariant>(bi.VariantGround) : cast<CGameCtnBlockInfoVariant>(bi.VariantAir);
    }

    CGameCtnBlockInfoVariant@ GetBlockBaseVariant(CGameCtnBlockInfo@ bi, bool isGround) {
        auto r = isGround ? cast<CGameCtnBlockInfoVariant>(bi.VariantBaseGround) : cast<CGameCtnBlockInfoVariant>(bi.VariantBaseAir);
        if (r is null) {
            return GetBlockZerothVariant(bi, isGround);
        }
        return r;
    }


    CGameCtnBlockInfoVariant@ GetBlockBestVariant(CGameCtnBlockInfo@ bi, bool isGround, uint &out varIx) {
        if (isGround) {
            if (bi.AdditionalVariantsGround.Length > 0) {
                for (int i = bi.AdditionalVariantsGround.Length - 1; i >= 0; i--) {
                    auto @biv = bi.AdditionalVariantsGround[i];
                    if (biv is null) continue;
                    if (biv.IsObsoleteVariant) continue;
                    if (!biv.IsNoPillarBelowVariant) continue;
                    // guess: the pillar versions have ReplacedPillarBlockInfo, not PlacedPillarBlockInfo
                    if (biv.ReplacedPillarBlockInfo_List.Length > 0) continue;
                    varIx = i + 1;
                    return biv;
                }
            }
            varIx = 0;
            return bi.VariantBaseGround;
        }
        if (bi.AdditionalVariantsAir.Length > 0) {
            for (int i = bi.AdditionalVariantsAir.Length - 1; i >= 0; i--) {
                auto @biv = bi.AdditionalVariantsAir[i];
                if (biv is null) continue;
                if (biv.IsObsoleteVariant) continue;
                if (!biv.IsNoPillarBelowVariant) continue;
                if (biv.ReplacedPillarBlockInfo_List.Length > 0) continue;
                varIx = i + 1;
                return biv;
            }
        }
        varIx = 0;
        return bi.VariantBaseAir;
    }

    CGameCtnBlockInfoVariant@ GetBlockInfoVariant(CGameCtnBlock@ block) {
        // auto bivIx = block.BlockInfoVariantIndex;
        return GetBlockInfoVariant(block.BlockInfo, block.BlockInfoVariantIndex, block.IsGround);
    }

    CGameCtnBlockInfoVariant@ GetBlockVariantAny(CGameCtnBlockInfo@ bi) {
        auto biv = GetBlockInfoVariant(bi, 0, false);
        if (biv !is null) return biv;
        return GetBlockInfoVariant(bi, 0, true);
    }

    CGameCtnBlockInfoVariant@ GetBlockInfoVariant(CGameCtnBlockInfo@ bi, uint bivIx, bool isGround) {
        if (bi is null) return null;
        CGameCtnBlockInfoVariant@ biv;
        // trace('bi is null: ' + (bi is null));
        // trace('bi name: ' + bi.Name);
        // trace('bivIx: ' + bivIx + ' / ' + block.IsGround + ' / ');
        // trace('lengths: ' + bi.AdditionalVariantsGround.Length + ' / ');
        // trace('bi.AdditionalVariantsAir.Length: ' + bi.AdditionalVariantsAir.Length);
        if (int(bivIx) < 0) bivIx = 0;
        if (bivIx > 0) {
            auto maxIx = isGround ? bi.AdditionalVariantsGround.Length : bi.AdditionalVariantsAir.Length;
            if (bivIx - 1 >= maxIx) {
                warn("bivIx out of range: " + bivIx + " / " + bi.AdditionalVariantsGround.Length);
                return null;
            }
            @biv = isGround ? cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsGround[bivIx - 1]) : cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsAir[bivIx - 1]);
        } else {
            @biv = GetBlockInfo0thVariant(bi, isGround);
        }
        return biv;
    }

    CGameCtnBlockInfoVariant@ GetBlockSpecVariant(BlockSpec@ block) {
        auto bivIx = block.variant;
        auto bi = block.BlockInfo;
        if (bivIx > 0) {
            auto maxIx = block.isGround ? bi.AdditionalVariantsGround.Length : bi.AdditionalVariantsAir.Length;
            if (bivIx > maxIx) {
                warn("bivIx out of range: " + bivIx + " / " + bi.AdditionalVariantsGround.Length);
                return null;
            }
            return block.isGround ? cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsGround[bivIx - 1]) : cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsAir[bivIx - 1]);
        } else {
            return GetBlockInfo0thVariant(bi, block.isGround); // block.isGround ? cast<CGameCtnBlockInfoVariant>(bi.VariantGround) : cast<CGameCtnBlockInfoVariant>(bi.VariantAir);
        }
    }

    CGameCtnBlockInfoVariant@ GetBlockInfo0thVariant(CGameCtnBlockInfo@ bi, bool isGround) {
        auto @biv = isGround ? cast<CGameCtnBlockInfoVariant>(bi.VariantGround) : cast<CGameCtnBlockInfoVariant>(bi.VariantAir);
        if (biv is null) {
            @biv = isGround ? cast<CGameCtnBlockInfoVariant>(bi.VariantBaseGround) : cast<CGameCtnBlockInfoVariant>(bi.VariantBaseAir);
        }
        return biv;
    }

    // shifted by 5 bits, limited to 0b111111 (6 bits)
    uint8 GetBlockInfoVariantIndex(CGameCtnBlock@ block) {
        return uint8(Dev::GetOffsetUint16(block, O_CTNBLOCK_VARIANT) >> 5) & 63;
    }

    /*
    WARNING: will crash the game if this is out of bounds (except 63, which is a special case that might cause it to be updated)
    range: 0-63
    */
    void SetBlockInfoVariantIndex(CGameCtnBlock@ block, uint8 index, bool safer = false) {
        if (safer) {
            auto biv = GetBlockInfoVariant(block.BlockInfo, index, block.IsGround);
            if (biv is null) {
                NotifyWarning("Block variant index out of range: " + index);
                index = 0;
            }
        }
        auto val = Dev::GetOffsetUint16(block, O_CTNBLOCK_VARIANT);
        val &= 0b1111100000011111;
        val |= uint16(index & 63) << 5;
        Dev::SetOffset(block, O_CTNBLOCK_VARIANT, val);
    }


    void SetBlock_BlockInfo(CGameCtnBlock@ block, CGameCtnBlockInfo@ bi) {
        if (bi is null) throw("refusing to set null block info");
        // todo: handle refcounting
        if (block.BlockInfo !is null) {
            block.BlockInfo.MwRelease();
        }
        bi.MwAddRef();
        Dev::SetOffset(block, GetOffset(block, "BlockInfo"), bi);
        SetBlock_BlockInfoMwId(block, bi.Id.Value);
    }

    void SetBlock_BlockInfoMwId(CGameCtnBlock@ block, uint mwId) {
        Dev::SetOffset(block, 0x18, mwId);
    }


    vec3 GetCtnBlockMidpoint(CGameCtnBlock@ block) {
        return (GetBlockMatrix(block) * (GetBlockSize(block) / 2.)).xyz;
    }

    mat4 GetBlockMatrix(CGameCtnBlock@ block) {
        return mat4::Translate(GetBlockLocation(block)) * GetBlockRotationMatrix(block);
    }

    mat4 GetBlockMatrix(nat3 coord, int dir, nat3 coordSize) {
        auto pos = BlockCoordAndCoordSizeToPos(coord, Nat3ToVec3(coordSize), dir);
        return mat4::Translate(pos) * EulerToMat(vec3(0, CardinalDirectionToYaw(dir), 0));
    }

    mat4 GetBlockMatrix(int3 coord, int dir, int3 coordSize) {
        return GetBlockMatrix(Int3ToNat3(coord), dir, Int3ToNat3(coordSize));
    }

    mat4 GetBlockMatrix(int3 coord) {
        return mat4::Translate(CoordToPos(coord));
    }

    mat4 GetBlockRotationMatrix(CGameCtnBlock@ block) {
        return EulerToMat(GetBlockRotation(block));
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
        Dev::SetOffset(block, O_CGameCtnBlock_CoordOffset, nat3(uint(-1), 0, uint(-1)));
        Dev::SetOffset(block, FreeBlockPosOffset, pos);
        Dev::SetOffset(block, FreeBlockRotOffset, rot);
    }

    int GetBlockMbInstId(CGameCtnBlock@ block) {
        return Dev::GetOffsetInt32(block, O_CTNBLOCK_MACROBLOCK_INST_NB);
    }

    void SetBlockMbInstId(CGameCtnBlock@ block, int id) {
        Dev::SetOffset(block, O_CTNBLOCK_MACROBLOCK_INST_NB, id);
    }

    uint8[]@ GetBlockUnitClips(CGameCtnBlockUnitInfo@ bui) {
        // 0x24
        // up to 7 clips per direction
        // takes 2 bytes
        // example: 40 80 = 1 south, 1 bottom
        //          49 90 = 1 N, 1E, 1 S, 1 B
        //          20 80 = 4 E, 1 B
        //          29 80 = 1 N, 5 E, 1 B
        //          27 C0 = 7 N, 4 E, 4 T, 1 B
        //          27 C3 = 7 N, 4 E, 4 S, 1 W, 4 T, 1 B
        //          0F 00 = 7 N, 1 E
        //          04 00 = 4 N
        //          10 00 = 2 E
        //          18 00 = 3 E
        //          1C 00 = 4 N, 3 E
        auto flags = Dev::GetOffsetUint32(bui, 0x24);
        uint8[] clipsByDir;
        for (int i = 0; i < 6; i++) {
            clipsByDir.InsertLast(flags & 0x7);
            flags >>= 3;
        }
        return clipsByDir;
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
