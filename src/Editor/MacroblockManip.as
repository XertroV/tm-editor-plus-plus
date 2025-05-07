namespace Editor {

    // MARK: Macroblock

    class MacroblockSpecPriv : MacroblockSpec {
        MacroblockSpecPriv() {
            super({}, {});
        }

        MacroblockSpecPriv(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) {
            super(blocks, items);
        }

        MacroblockSpecPriv(const BlockSpec@[]@ blocks, const ItemSpec@[]@ items) {
            super({}, {});
            for (uint i = 0; i < blocks.Length; i++) {
                this.blocks.InsertLast(blocks[i]);
            }
            for (uint i = 0; i < items.Length; i++) {
                this.items.InsertLast(items[i]);
            }
        }

        MacroblockSpecPriv(CGameCtnMacroBlockInfo@ mb) {
            super({}, {});
            auto dmb = DGameCtnMacroBlockInfo(mb);
            auto mbBlocks = dmb.Blocks;
            for (uint i = 0; i < mbBlocks.Length; i++) {
                blocks.InsertLast(BlockSpecPriv(mbBlocks[i]));
            }
            auto mbItems = dmb.Items;
            for (uint i = 0; i < mbItems.Length; i++) {
                items.InsertLast(ItemSpecPriv(mbItems[i]));
            }
        }

        MacroblockSpecPriv(MemoryBuffer@ buf) {
            super({}, {});
            ReadFromNetworkBuffer(buf);
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            uint32 magic = buf.ReadUInt32();
            if (magic != MAGIC_BLOCKS) {
                throw("Invalid magic for blocks: " + Text::Format("0x%08x", magic));
            }
            uint16 blockCount = buf.ReadUInt16();
            for (uint i = 0; i < blockCount; i++) {
                blocks.InsertLast(BlockSpecPriv(buf));
            }

            magic = buf.ReadUInt32();
            if (magic != MAGIC_SKINS) {
                throw("Invalid magic for skins: " + Text::Format("0x%08x", magic));
            }
            uint16 skinCount = buf.ReadUInt16();
            for (uint i = 0; i < skinCount; i++) {
                skins.InsertLast(SkinSpecPriv(buf));
            }

            magic = buf.ReadUInt32();
            if (magic != MAGIC_ITEMS) {
                throw("Invalid magic for items: " + Text::Format("0x%08x", magic));
            }
            uint16 itemCount = buf.ReadUInt16();
            for (uint i = 0; i < itemCount; i++) {
                items.InsertLast(ItemSpecPriv(buf));
            }
            return this;
        }

        NewMbParts@ AddMacroblock(CGameCtnMacroBlockInfo@ macroblock, const vec3 &in position, const vec3 &in rotation) override {
            auto rot = EulerToMat(rotation);
            auto mb = DGameCtnMacroBlockInfo(macroblock);
            auto newParts = NewMbParts();
            auto mbBlocks = mb.Blocks;
            for (uint i = 0; i < mbBlocks.Length; i++) {
                auto block = BlockSpecPriv(mbBlocks[i]);
                auto blockMat = block.GetTransform();
                auto transform = mat4::Translate(position) * rot * blockMat;
                block.pos = (transform * vec3()).xyz;
                // block.pos = (transform * block.pos).xyz;
                block.pyr = PitchYawRollFromRotationMatrix(mat4::Translate(block.pos * -1.) * transform);
                block.pos += vec3(0, 56, 0);
                blocks.InsertLast(block);
                newParts.blocks.InsertLast(block);
            }
            auto mbItems = mb.Items;
            for (uint i = 0; i < mbItems.Length; i++) {
                auto item = ItemSpecPriv(mbItems[i]);
                auto itemMat = item.GetTransform();
                auto transform = mat4::Translate(position) * rot * itemMat;
                item.pos = (transform * vec3()).xyz;
                // item.pos = (transform * item.pos).xyz;
                item.pyr = PitchYawRollFromRotationMatrix(mat4::Translate(item.pos * -1.) * transform);
                item.pos += vec3(0, 56, 0);
                items.InsertLast(item);
                newParts.items.InsertLast(item);
            }
            // todo: skins
            return newParts;
        }

        void AddBlock(CGameCtnBlock@ block) override {
            blocks.InsertLast(BlockSpecPriv(block));
        }

        void AddSkin(CGameCtnBlockSkin@ skin, uint ix) override {
            skins.InsertLast(SkinSpecPriv(skin, ix));
        }

        void AddItem(CGameCtnAnchoredObject@ item) override {
            items.InsertLast(ItemSpecPriv(item));
        }

        ItemSpec@ AddItem1(CGameCtnAnchoredObject@ item) override {
            auto itemSpec = ItemSpecPriv(item);
            items.InsertLast(itemSpec);
            return itemSpec;
        }

        protected DGameCtnMacroBlockInfo@ tmpMacroblock = null;
        protected uint64 tmpMacroblockBlocksBuf = 0;
        protected uint64 tmpMacroblockBlocksBufLenCap = 0;
        protected uint64 tmpMacroblockItemsBuf = 0;
        protected uint64 tmpMacroblockItemsBufLenCap = 0;
        protected uint64 tmpMacroblockSkinsBuf = 0;
        protected uint64 tmpMacroblockSkinsBufLenCap = 0;
        bool releaseTmpMacroblock = false;

        void _TempWriteToMacroblock(CGameCtnMacroBlockInfo@ macroblock) {
            @tmpMacroblock = DGameCtnMacroBlockInfo(macroblock);
            releaseTmpMacroblock = Reflection::GetRefCount(macroblock) > 1;
            if (releaseTmpMacroblock) {
                macroblock.MwAddRef();
            }

            auto mbBlocks = tmpMacroblock.Blocks;
            tmpMacroblockBlocksBuf = Dev::ReadUInt64(mbBlocks.Ptr);
            tmpMacroblockBlocksBufLenCap = Dev::ReadUInt64(mbBlocks.Ptr + 0x8);
            auto mbItems = tmpMacroblock.Items;
            tmpMacroblockItemsBuf = Dev::ReadUInt64(mbItems.Ptr);
            tmpMacroblockItemsBufLenCap = Dev::ReadUInt64(mbItems.Ptr + 0x8);
            auto mbSkins = tmpMacroblock.Skins;
            tmpMacroblockSkinsBuf = Dev::ReadUInt64(mbSkins.Ptr);
            tmpMacroblockSkinsBufLenCap = Dev::ReadUInt64(mbSkins.Ptr + 0x8);

            _AllocAndWriteMemory(true);
        }

        CustomBuffer@ tmpWriteBuf;

        void _AllocAndWriteMemory(bool writeToMb = false, CustomBuffer@ tmpWriteBuf = null) {
            // allow passing in a buffer for flexibility
            if (tmpWriteBuf is null) {
                @tmpWriteBuf = CustomBuffer(CalcRequiredMbBufSize());
            }
            // for each: get a window to a section of the memory, then write to it.
            auto blocksPtrs = tmpWriteBuf.GetPtrVAlloc(0x8 * blocks.Length);
            for (uint i = 0; i < blocks.Length; i++) {
                auto blockEl = tmpWriteBuf.GetPtrVAlloc(SZ_MACROBLOCK_BLOCKSBUFEL);
                blocksPtrs.Write(blockEl.ptr);
                cast<BlockSpecPriv>(blocks[i]).WriteToMemory(blockEl);
            }

            auto skinsPtrs = tmpWriteBuf.GetPtrVAlloc(0x8 * skins.Length);
            for (uint i = 0; i < skins.Length; i++) {
                auto skinEl = tmpWriteBuf.GetPtrVAlloc(SZ_MACROBLOCK_SKINSBUFEL);
                skinsPtrs.Write(skinEl.ptr);
                cast<SkinSpecPriv>(skins[i]).WriteToMemory(skinEl);
            }
            auto itemsPtrs = tmpWriteBuf.GetPtrVAlloc(0x8 * items.Length);
            for (uint i = 0; i < items.Length; i++) {
                auto itemEl = tmpWriteBuf.GetPtrVAlloc(SZ_MACROBLOCK_ITEMSBUFEL);
                itemsPtrs.Write(itemEl.ptr);
                cast<ItemSpecPriv>(items[i]).WriteToMemory(itemEl);
            }

            if (writeToMb) {
                Dev::Write(tmpMacroblock.Blocks.Ptr, blocksPtrs.ptr);
                Dev::Write(tmpMacroblock.Blocks.Ptr + 0x8, nat2(blocks.Length));
                Dev::Write(tmpMacroblock.Items.Ptr, itemsPtrs.ptr);
                Dev::Write(tmpMacroblock.Items.Ptr + 0x8, nat2(items.Length));
                Dev::Write(tmpMacroblock.Skins.Ptr, skinsPtrs.ptr);
                Dev::Write(tmpMacroblock.Skins.Ptr + 0x8, nat2(skins.Length));
            }
        }

        protected uint CalcRequiredMbBufSize() {
            uint size = 0;
            // each buffer is a list of pointers to structs, so we need 0x8 extra bytes per element.
            // we don't need to count skins b/c we'll instantiate those objects directly
            // need blocks * (0x8 + SZ_MACROBLOCK_BLOCKSBUFEL)
            size += blocks.Length * (0x8 + SZ_MACROBLOCK_BLOCKSBUFEL);
            // need items * (0x8 + SZ_MACROBLOCK_ITEMSBUFEL)
            size += items.Length * (0x8 + SZ_MACROBLOCK_ITEMSBUFEL);
            // need skins * (0x8 + SZ_MACROBLOCK_SKINSBUFEL)
            size += skins.Length * (0x8 + SZ_MACROBLOCK_SKINSBUFEL);

            return size;
        }


        // will throw if the macroblock does not have sufficient capcaity.
        void _WriteDirectlyToMacroblock(CGameCtnMacroBlockInfo@ macroblock) {
            auto @tmpMb = DGameCtnMacroBlockInfo(macroblock);
            if (tmpMb.Blocks.Length < blocks.Length) throw(".Blocks too small");
            if (tmpMb.Items.Length < items.Length) throw(".Items too small");
            if (tmpMb.Skins.Length < skins.Length) throw(".Skins too small");
            auto destBlocks = tmpMb.Blocks;
            auto destItems = tmpMb.Items;
            auto destSkins = tmpMb.Skins;
            for (uint i = 0; i < blocks.Length; i++) cast<BlockSpecPriv>(blocks[i]).WriteToMemory(CustomBuffer(destBlocks.GetBlock(i).Ptr, SZ_MACROBLOCK_BLOCKSBUFEL));
            for (uint i = 0; i < items.Length; i++) cast<ItemSpecPriv>(items[i]).WriteToMemory(CustomBuffer(destItems.GetItem(i).Ptr, SZ_MACROBLOCK_ITEMSBUFEL));
            for (uint i = 0; i < skins.Length; i++) cast<SkinSpecPriv>(skins[i]).WriteToMemory(CustomBuffer(destSkins.GetSkin(i).Ptr, SZ_MACROBLOCK_SKINSBUFEL));
            destBlocks.Length = blocks.Length;
            destItems.Length = items.Length;
            destSkins.Length = skins.Length;
            macroblock.Initialized = false;
        }


        void _UnallocMemory() {
            @tmpWriteBuf = null;
        }

        void _RestoreMacroblock() {
            if (tmpWriteBuf is null) {
                warn("_RestoreMacroblock called without _TempWriteToMacroblock");
                return;
            }
            _UnallocMemory();

            Dev::Write(tmpMacroblock.Blocks.Ptr, tmpMacroblockBlocksBuf);
            Dev::Write(tmpMacroblock.Blocks.Ptr + 0x8, tmpMacroblockBlocksBufLenCap);
            Dev::Write(tmpMacroblock.Items.Ptr, tmpMacroblockItemsBuf);
            Dev::Write(tmpMacroblock.Items.Ptr + 0x8, tmpMacroblockItemsBufLenCap);
            Dev::Write(tmpMacroblock.Skins.Ptr, tmpMacroblockSkinsBuf);
            Dev::Write(tmpMacroblock.Skins.Ptr + 0x8, tmpMacroblockSkinsBufLenCap);

            if (tmpMacroblock !is null && releaseTmpMacroblock) {
                tmpMacroblock.Nod.MwRelease();
            }
            @tmpMacroblock = null;
            releaseTmpMacroblock = false;
        }


        uint missingMBCapacityBlocks = 0, missingMBCapacityItems = 0;
        // true if this macroblock spec could fit in the provided mbInfo.
        // .missingMBCapacityBlocks and .missingMBCapacityItems record the amount short you are.
        bool MacroblockHasSufficientCapacity(CGameCtnMacroBlockInfo@ mbInfo) {
            if (mbInfo is null) return false;
            auto dest = DGameCtnMacroBlockInfo(mbInfo);
            missingMBCapacityBlocks = 0;
            missingMBCapacityItems = 0;
            if (dest.Blocks.Length < blocks.Length) missingMBCapacityBlocks = blocks.Length - dest.Blocks.Length;
            if (dest.Items.Length < items.Length) missingMBCapacityItems = items.Length - dest.Items.Length;
            if (missingMBCapacityBlocks > 0 || missingMBCapacityItems > 0) {
                dev_trace("Missing Blocks: " + missingMBCapacityBlocks + " | Items: " + missingMBCapacityItems);
                return false;
            }
            return missingMBCapacityBlocks == 0 && missingMBCapacityItems == 0;
        }

        // MARK: MBSpec::Chunking

        array<MacroblockSpec@>@ CreateChunks(int chunkSize) override {
            MacroblockSpec@[] chunks;
            auto chunk = MacroblockSpecPriv();
            nat3 lastCoord;
            for (uint i = 0; i < this.blocks.Length; i++) {
                if (!MathX::Nat3XZEq(lastCoord, this.blocks[i].coord) && chunk.Length >= chunkSize) {
                    chunks.InsertLast(chunk);
                    @chunk = MacroblockSpecPriv();
                }
                chunk.AddBlock(this.blocks[i]);
                lastCoord = this.blocks[i].coord;
            }
            for (uint i = 0; i < this.items.Length; i++) {
                if (chunk.Length >= chunkSize) {
                    chunks.InsertLast(chunk);
                    @chunk = MacroblockSpecPriv();
                }
                chunk.AddItem(this.items[i]);
            }
            if (chunk.Length > 0) {
                chunks.InsertLast(chunk);
            }
            return chunks;
        }

        int3 GetMinBlockCoords() override {
            int3 minCoord = int3(2147483647);
            for (uint i = 0; i < blocks.Length; i++) {
                auto @block = blocks[i];
                int3 coord = Nat3ToInt3(block.coord);
                if (block.isFree) coord = Nat3ToInt3(PosToCoord(block.pos));
                if (coord.x < minCoord.x) minCoord.x = coord.x;
                if (coord.y < minCoord.y) minCoord.y = coord.y;
                if (coord.z < minCoord.z) minCoord.z = coord.z;
            }
            for (uint i = 0; i < items.Length; i++) {
                auto @item = items[i];
                int3 coord = Nat3ToInt3(PosToCoord(item.pos));
                if (coord.x < minCoord.x) minCoord.x = coord.x;
                if (coord.y < minCoord.y) minCoord.y = coord.y;
                if (coord.z < minCoord.z) minCoord.z = coord.z;
            }
            return minCoord;
        }

        int3 GetMaxBlockCoords() override {
            int3 maxCoord = int3(-2147483647);
            for (uint i = 0; i < blocks.Length; i++) {
                auto @block = blocks[i];
                int3 coord = Nat3ToInt3(block.coord);
                if (block.isFree) coord = Nat3ToInt3(PosToCoord(block.pos));
                if (coord.x > maxCoord.x) maxCoord.x = coord.x;
                if (coord.y > maxCoord.y) maxCoord.y = coord.y;
                if (coord.z > maxCoord.z) maxCoord.z = coord.z;
            }
            for (uint i = 0; i < items.Length; i++) {
                auto @item = items[i];
                int3 coord = Nat3ToInt3(PosToCoord(item.pos));
                if (coord.x > maxCoord.x) maxCoord.x = coord.x;
                if (coord.y > maxCoord.y) maxCoord.y = coord.y;
                if (coord.z > maxCoord.z) maxCoord.z = coord.z;
            }
            return maxCoord;
        }

        nat3 GetCoordSize() override {
            if (blocks.Length == 0 && items.Length == 0) return nat3(0);
            auto min = GetMinBlockCoords();
            auto max = GetMaxBlockCoords();
            auto size = max - min + 1;
            if (size.x < 0 || size.y < 0 || size.z < 0) {
                Dev_NotifyWarning("Negative coord size for macroblock");
            }
            return Int3ToNat3(size);
        }

        void MoveAllToOrigin() override {
            auto minCoord = this.GetMinBlockCoords();
            for (uint i = 0; i < blocks.Length; i++) {
                cast<BlockSpecPriv>(blocks[i]).TranslateCoords(minCoord * -1);
            }
            for (uint i = 0; i < items.Length; i++) {
                cast<ItemSpecPriv>(items[i]).TranslateCoords(minCoord * -1);
            }
        }

        void UndoMacroblockHeightOffset() override {
            warn("todo: UndoMacroblockHeightOffset");
            return;

            for (uint i = 0; i < blocks.Length; i++) {
                auto block = blocks[i];
                if (block.isFree) {
                    // block.pos = block.pos; // - vec3(0, 56, 0);
                    block.pos.y += 8.0;
                } else {
                    block.coord = block.coord + nat3(0, 1, 0);
                }
            }
            for (uint i = 0; i < items.Length; i++) {
                auto item = cast<ItemSpecPriv>(items[i]);
                item.coord = item.coord + nat3(0, 1, 0);
                item.pos.y += 8.0;
                // hmm, don't need to move pos.y
                // item.pos.y -= 56.0;
            }
        }

        void AlignAll(Editor::AlignWithinBlock) override {
            warn("todo: AlignAllImpl");
        }

        // Create a complete copy of the macroblock
        MacroblockSpec@ Duplicate() override {
            auto newMb = MacroblockSpecPriv();
            for (uint i = 0; i < blocks.Length; i++) {
                newMb.blocks.InsertLast((blocks[i]).Duplicate());
            }
            for (uint i = 0; i < items.Length; i++) {
                newMb.items.InsertLast((items[i]).Duplicate());
            }
            for (uint i = 0; i < skins.Length; i++) {
                newMb.skins.InsertLast((skins[i]).Duplicate());
            }
            return newMb;
        }
    }

    const uint32 MAGIC_BLOCKS = 0x734b4c42;
    const uint32 MAGIC_SKINS = 0x734e4b53;
    const uint32 MAGIC_ITEMS = 0x734d5449;

    // MARK: BlockSpec

    class BlockSpecPriv : BlockSpec {
        uint64 ObjPtr;
        SetSkinSpec@ skin;
        // CGameCtnBlock@ GameBlock;

        BlockSpecPriv() {
            super();
        }

        ~BlockSpecPriv() {
            if (BlockInfo !is null) {
                BlockInfo.MwRelease();
                @BlockInfo = null;
            }
            // if (GameBlock !is null) {
            //     GameBlock.MwRelease();
            //     @GameBlock = null;
            // }
        }

        BlockSpecPriv(CGameCtnBlock@ block) {
            // @GameBlock = block;
            // block.MwAddRef();
            super();
            SetFrom(block);
            SetSkinsFrom(block);
        }

        BlockSpecPriv(CGameCtnBlockInfo@ block, const nat3 &in _coord, int dir) {
            super();
            SetBlockInfo(block);
            SetCoord_AlsoPosRot(_coord, block, dir);
        }

        BlockSpecPriv(CGameCtnBlockInfo@ block, const vec3 &in position, const vec3 &in pyrRotation) {
            super();
            SetBlockInfo(block);
            SetPosRot_AlsoCoordDir(position, pyrRotation);
            this.isFree = true;
            this.isGhost = false;
            this.isGround = false;
        }

        void SetCoord_AlsoPosRot(const nat3 &in _coord, CGameCtnBlockInfo@ block, int _dir) override {
            auto coordSize = Nat3ToVec3(MathX::Max(block.VariantBaseAir.Size, block.VariantBaseGround.Size));
            SetCoord_AlsoPosRot(_coord, coordSize, _dir);
        }

        // CoordSize is size of block in coord units (e.g., `Nat3ToVec3(blockInfo.VariantBaseAir.Size)`)
        void SetCoord_AlsoPosRot(const nat3 &in _coord, vec3 coordSize, int _dir) override {
            coord = _coord;
            pos = BlockCoordAndCoordSizeToPos(_coord, coordSize, _dir) + vec3(0, 56, 0);
            // pos = CoordToPos(_coord) + vec3(0, 56, 0);
            auto er = EditorRotation(0, 0, CGameCursorBlock::ECardinalDirEnum(_dir), CGameCursorBlock::EAdditionalDirEnum::P0deg);
            pyr = er.Euler;
            this.dir = CGameCtnBlock::ECardinalDirections(_dir);
            this.dir2 = this.dir;
            if (coord.y > 0) {
                coord.y -= 1;
            }
        }

        void SetPosRot_AlsoCoordDir(vec3 position, vec3 pyrRotation) override {
            pos = position + vec3(0, 56, 0);

            pyr = pyrRotation;
            dir = EditorRotation(pyrRotation).Dir2;
            dir2 = dir;

            coord = PosToCoord(position);
            if (coord.y > 0) {
                coord.y -= 1;
            }
        }

        void SetFrom(CGameCtnBlock@ block) override {
            ObjPtr = Dev_GetPointerForNod(block);
            name = block.BlockInfo.IdName;
            // collection = blah
            // author = GetMwIdName(block.BlockInfo.Author);
            author = block.BlockInfo.Author.GetName();
            coord = block.Coord;
            // correct for mb offset at min location 0,1,0
            if (coord.y > 0) {
                coord.y -= 1;
            }
            dir = block.Direction;
            dir2 = block.Direction;
            pos = Editor::GetBlockLocation(block) + vec3(0, 56, 0);
            pyr = Editor::GetBlockRotation(block);

            color = block.MapElemColor;
            lmQual = block.MapElemLmQuality;
            mobilIx = block.MobilIndex;
            mobilVariant = block.MobilVariantIndex;
            // warn("Block " + name + " has variant " + mobilVariant);
            // if (mobilVariant == 63) {
            //     warn("Block " + name + " has variant 63");
            //     // ExploreNod(block);
            // }
            variant = block.BlockInfoVariantIndex;
            flags = (block.IsGround ? BlockFlags::Ground : BlockFlags::None) |
                    (block.IsGhostBlock() ? BlockFlags::Ghost : BlockFlags::None) |
                    (Editor::IsBlockFree(block) ? BlockFlags::Free : BlockFlags::None);
            if (block.WaypointSpecialProperty !is null) {
                @waypoint = WaypointSpec(block.WaypointSpecialProperty);
            }
            SetBlockInfo(block.BlockInfo);
        }

        void SetSkinsFrom(CGameCtnBlock@ block) {
            if (block.Skin is null) return;
            string fg, bg;
            if (block.Skin.PackDesc !is null) {
                fg = block.Skin.PackDesc.Url.Length > 0 ? block.Skin.PackDesc.Url : string(block.Skin.PackDesc.Name);
            }
            if (block.Skin.ForegroundPackDesc !is null) {
                bg = block.Skin.ForegroundPackDesc.Url.Length > 0 ? block.Skin.ForegroundPackDesc.Url : string(block.Skin.ForegroundPackDesc.Name);
            }
            if (fg.Length == 0 && bg.Length == 0) {
                @skin = null;
            } else {
                BlockSpec@ b = null;
                @skin = SetSkinSpecPriv(b, fg, bg);
            }
        }

        void SetBlockInfo(CGameCtnBlockInfo@ _blockInfo) {
            if (BlockInfo !is null) {
                BlockInfo.MwRelease();
            }
            @BlockInfo = _blockInfo;
            if (BlockInfo !is null) {
                name = BlockInfo.IdName;
                author = BlockInfo.Author.GetName();
                BlockInfo.MwAddRef();
                EnsureValidVariant();
            }
        }

        BlockSpecPriv(DGameCtnMacroBlockInfo_Block@ block) {
            super();
            name = block.name;
            // collection = blah
            author = block.author;
            coord = block.coord;
            dir = block.dir;
            dir2 = block.dir2;
            pos = block.pos;
            pyr = block.pyr;
            color = block.color;
            lmQual = block.lmQual;
            mobilIx = block.mobilIndex;
            mobilVariant = block.mobilVariant;
            // if (mobilVariant == 63) {
            //     warn("DGameCtnMacroblockinfo Block " + name + " has variant 63");
            //     // ExploreNod(block);
            // }
            variant = block.variant;
            flags = block.flags;
            if (block.Waypoint !is null) {
                @waypoint = WaypointSpec(block.Waypoint);
            }
            SetBlockInfo(block.BlockInfo);
        }

        BlockSpecPriv(MemoryBuffer@ buf) {
            super();
            ReadFromNetworkBuffer(buf);
        }

        void WriteToMemory(CustomBuffer@ mem) {
            auto block = DGameCtnMacroBlockInfo_Block(mem.ptr);
            block.name = name;
            block.collection = collection;
            block.author = author;
            block.coord = coord;
            block.dir = dir;
            block.dir2 = dir2;
            block.pos = pos;
            block.pyr = pyr;
            block.color = color;
            block.lmQual = lmQual;
            block.mobilIndex = mobilIx;
            block.mobilVariant = mobilVariant;
            block.variant = variant;
            block.flags = flags;
            if (waypoint is null) {
                @block.Waypoint = null;
            } else {
                @block.Waypoint = CGameWaypointSpecialProperty();
                block.Waypoint.Order = waypoint.order;
                block.Waypoint.Tag = waypoint.tag;
            }
            // get model
            if (BlockInfo is null) {
                auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
                SetBlockInfo(editor.PluginMapType.GetBlockModelFromName(name));
                if (BlockInfo is null) {
                    SetBlockInfo(TryLoadingModelFromFid());
                }
            }
            @block.BlockInfo = BlockInfo;
            if (block.BlockInfo is null) {
                auto inv = Editor::GetInventoryCache();
                auto art = inv.GetBlockByName(name);
                if (art !is null) {
                    auto modelNod = art.GetCollectorNod();
                    auto model = cast<CGameCtnBlockInfo>(modelNod);
                    if (model !is null) {
                        @block.BlockInfo = model;
                        SetBlockInfo(model);
                    } else {
                        NotifyWarning("Failed to load block model for " + name + ".\nArticle: " + art.Name);
                    }
                } else {
                    NotifyWarning("Failed to load block article for " + name);
                }
            }
            // 2025-04-30 do we need to add a ref here?
            // if (block.BlockInfo !is null) {
            //     block.BlockInfo.MwAddRef();
            // }
        }

        CGameCtnBlockInfo@ TryLoadingModelFromFid() {
            CGameCtnBlockInfo@ block;
            @block = TryLoadBlockFromFidPath("GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoPillar\\", name);
            if (block !is null) return block;
            @block = TryLoadBlockFromFidPath("GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoPillar\\Theme\\", name);
            if (block !is null) return block;
            @block = TryLoadBlockFromFidPath("GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoClassic\\", name);
            if (block !is null) return block;
            @block = TryLoadBlockFromFidPath("GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoClassic\\Deprecated\\", name);
            if (block !is null) return block;
            @block = TryLoadBlockFromFidPath("GameData\\Stadium\\GameCtnBlockInfo\\GameCtnBlockInfoClassic\\Theme\\", name);
            if (block !is null) return block;

            // @fid = Fids::GetUser("Blocks\\Stadium\\" + name + ".EDClassic.Gbx");
            // if (fid !is null && fid.Nod !is null) {
            //     auto model = cast<CGameCtnBlockInfo>(fid.Nod);
            //     if (model !is null) {
            //         return model;
            //     }
            // }

            return null;
        }

        CGameCtnBlockInfo@ TryLoadBlockFromFidPath(const string &in path, const string &in name, const string &in ext = ".EDClassic.Gbx") {
            auto fid = Fids::GetGame(path + name + ext);
            CGameCtnBlockInfo@ info;
            if (fid !is null && (@info = cast<CGameCtnBlockInfo>(Fids::Preload(fid))) !is null) {
                return info;
            }
            return null;
        }

        bool MatchesBlock(CGameCtnBlock@ block) const override {
            // if (block.BlockInfo.IdName == "Grass") return false;
            // debug failed match
            // trace('name match: ' + (name == block.BlockInfo.IdName));
            // trace('collection match: ' + (collection == 26));
            // trace('author match: ' + (author == block.BlockInfo.Author.GetName()));
            // trace('coord match: ' + MathX::Nat3Eq(coord, block.Coord - nat3(0,1,0)));
            // trace('dir match: ' + (dir == block.Direction));
            // trace('dir2 match: ' + (dir2 == block.Direction));
            // trace('pos match: ' + MathX::Vec3Eq(pos, Editor::GetBlockLocation(block) + vec3(0, 56, 0)));
            // trace('pyr match: ' + MathX::Vec3Eq(pyr, Editor::GetBlockRotation(block)));
            // trace('color match: ' + (color == block.MapElemColor));
            // trace('lmQual match: ' + (lmQual == block.MapElemLmQuality));
            // trace('mobilIx match: ' + (mobilIx == block.MobilIndex) + ' ' + mobilIx + ' / ' + block.MobilIndex);
            // trace('mobilVariant match: ' + (mobilVariant == block.MobilVariantIndex) + ' ' + mobilVariant + ' / ' + block.MobilVariantIndex);
            // trace('variant match: ' + (variant == block.BlockInfoVariantIndex) + ' ' + variant + ' / ' + block.BlockInfoVariantIndex);
            // trace('flags match: ' + (flags == (block.IsGround ? BlockFlags::Ground : BlockFlags::None) | (block.IsGhostBlock() ? BlockFlags::Ghost : BlockFlags::None) | (Editor::IsBlockFree(block) ? BlockFlags::Free : BlockFlags::None)));

            return name == block.BlockInfo.IdName && collection == 26 && author == block.BlockInfo.Author.GetName() &&
                ((isFree && Editor::IsBlockFree(block)) || MathX::Nat3Eq(coord, block.Coord - nat3(0,1,0))) &&
                dir == block.Direction && dir2 == block.Direction &&
                MathX::Vec3Eq(pos, Editor::GetBlockLocation(block) + vec3(0, 56, 0)) &&
                // color == block.MapElemColor &&
                // lmQual == block.MapElemLmQuality &&
                mobilIx == block.MobilIndex &&
                (mobilVariant == block.MobilVariantIndex || mobilVariant == 63 || block.MobilVariantIndex == 63 || isNormal) &&
                // variant == block.BlockInfoVariantIndex &&
                flags == uint8((block.IsGround ? BlockFlags::Ground : BlockFlags::None) | (block.IsGhostBlock() ? BlockFlags::Ghost : BlockFlags::None) | (Editor::IsBlockFree(block) ? BlockFlags::Free : BlockFlags::None)) &&
                AnglesVeryClose(pyr, Editor::GetBlockRotation(block))
                ;
        }

        bool opEquals(const BlockSpec@ other) const override {
            if (other is null) return false;
            // debug failed match
            // trace("opEquals for: " + name + " and " + other.name);
            // trace('name match: ' + (name == other.name));
            // trace('collection match: ' + (collection == other.collection));
            // trace('author match: ' + (author == other.author));
            // trace('coord match: ' + MathX::Nat3Eq(coord, other.coord));
            // trace('dir match: ' + (dir == other.dir));
            // trace('dir2 match: ' + (dir2 == other.dir2));
            // trace('pos match: ' + MathX::Vec3Eq(pos, other.pos));
            // trace('pyr match: ' + MathX::Vec3Eq(pyr, other.pyr));
            // trace('color match: ' + (color == other.color));
            // trace('lmQual match: ' + (lmQual == other.lmQual));
            // trace('mobilIx match: ' + (mobilIx == other.mobilIx));
            // trace('mobilVariant match: ' + (mobilVariant == other.mobilVariant) + ' ' + mobilVariant + ' / ' + other.mobilVariant);
            // trace('variant match: ' + (variant == other.variant) + ' ' + variant + ' / ' + other.variant);
            // trace('flags match: ' + (flags == other.flags));

            auto o2 = cast <BlockSpecPriv>(other);
            if (ObjPtr > 0 && o2 !is null && o2.ObjPtr == ObjPtr && name == other.name) return true;

            return name == other.name && collection == other.collection && author == other.author &&
                MathX::Nat3Eq(coord, other.coord) && dir == other.dir && dir2 == other.dir2 &&
                MathX::Vec3Eq(pos, other.pos) &&
                // color == other.color && lmQual == other.lmQual &&
                mobilIx == other.mobilIx &&
                // mobilVariant not set when block is being placed
                (mobilVariant == other.mobilVariant || mobilVariant == 63 || other.mobilVariant == 63 || isNormal) &&
                // variant == other.variant && // ignore variant, can be wrong?
                flags == other.flags &&
                AnglesVeryClose(pyr, other.pyr)
                ;
        }

        ItemSpec@ ToItemSpec(CGameItemModel@ itemModel, vec3 &in pivotPos = vec3(0), uint16 variantIx = 0) override {
            auto spec = ItemSpecPriv(itemModel, pos, pyr);
            // spec.variantIx
            spec.color = CGameCtnAnchoredObject::EMapElemColor(int(this.color));
            spec.lmQual = CGameCtnAnchoredObject::EMapElemLightmapQuality(int(this.lmQual));
            spec.isFlying = 1;
            spec.pivotPos = pivotPos;
            spec.variantIx = variantIx;
            if (this.waypoint !is null) {
                @spec.waypoint = WaypointSpec(waypoint.tag, waypoint.order);
            }
            @spec.waypoint = waypoint;
            return spec;
        }

        bool EnsureValidVariant() override {
            if (BlockInfo !is null) {
                auto origVar = variant;
                auto origGround = isGround;
                if (Editor::GetBlockInfoVariant(BlockInfo, variant, isGround) is null) {
                    variant = 0;
                }
                if (Editor::GetBlockInfoVariant(BlockInfo, variant, isGround) is null) {
                    isGround = !isGround;
                }
                if (Editor::GetBlockInfoVariant(BlockInfo, variant, isGround) is null) {
                    variant = origVar;
                    isGround = origGround;
                    return false;
                }
            }
            return true;
        }

        void TranslateCoords(int3 coordDist, bool updateBoth = false) override {
            if (updateBoth || isFree) {
                vec3 posDiff = CoordDistToPos(coordDist);
                pos += posDiff;
            }
            if (updateBoth || !isFree) {
                coord = Int3ToNat3(Nat3ToInt3(coord) + coordDist);
            }
        }

        BlockSpec@ Duplicate() override {
            auto newBlock = BlockSpecPriv();
            newBlock.name = name;
            newBlock.collection = collection;
            newBlock.author = author;
            newBlock.coord = coord;
            newBlock.dir = dir;
            newBlock.dir2 = dir2;
            newBlock.pos = pos;
            newBlock.pyr = pyr;
            newBlock.color = color;
            newBlock.lmQual = lmQual;
            newBlock.mobilIx = mobilIx;
            newBlock.mobilVariant = mobilVariant;
            newBlock.variant = variant;
            newBlock.flags = flags;
            if (waypoint !is null) {
                @newBlock.waypoint = WaypointSpec(waypoint.tag, waypoint.order);
            }
            newBlock.SetBlockInfo(BlockInfo);
            @newBlock.skin = skin;
            newBlock.ObjPtr = ObjPtr;
            return newBlock;
        }

    }

    // MARK: SkinSpec

    class SkinSpecPriv : SkinSpec {
        SkinSpecPriv(CGameCtnBlockSkin@ skin, uint blockIx) {
            super(skin, blockIx);
        }

        SkinSpecPriv(MemoryBuffer@ buf) {
            super(null, 0);
            ReadFromNetworkBuffer(buf);
        }

        void WriteToMemory(CustomBuffer@ mem) {
            mem.Write(null); // skin ptr
            mem.SeekRelative(12); // skip unused 0x8 -> 0x14
            mem.Write(blockIx);
            // mem.WritePtr(rawSkin);
        }

        SkinSpecPriv@ Duplicate() {
            return SkinSpecPriv(this.rawSkin, blockIx);
        }
    }

    // MARK: ItemSpec

    class ItemSpecPriv : ItemSpec {
        uint64 ObjPtr;
        // CGameCtnAnchoredObject@ GameItem;

        CSystemPackDesc@ _rawFGSkin = null;
        CSystemPackDesc@ _rawBGSkin = null;

        ~ItemSpecPriv() {
            if (Model !is null) {
                Model.MwRelease();
                @Model = null;
            }
            // if (GameItem !is null) {
            //     GameItem.MwRelease();
            //     @GameItem = null;
            // }
        }

        ItemSpecPriv() {
            super();
        }

        ItemSpecPriv(CGameCtnAnchoredObject@ item) {
            ObjPtr = Dev_GetPointerForNod(item);
            // @GameItem = item;
            // item.MwAddRef();
            super();
            // collection = blah
            coord = item.BlockUnitCoord;
            SetCoordFromAssociatedBlock(Editor::GetItemsBlockAssociation(item));
            // need to offset coords by 0,1,0 and make height relative to that
            coord = coord - nat3(0, 1, 0);
            dir = CGameCtnAnchoredObject::ECardinalDirections(uint8(-1));
            pos = Editor::GetItemLocation(item) + vec3(0, 56, 0);
            pyr = Editor::GetItemRotation(item);
            //if (pyr.y < NegPI) pyr.y += TAU;
            scale = item.Scale;
            color = item.MapElemColor;
            lmQual = item.MapElemLmQuality;
            phase = item.AnimPhaseOffset;
            visualRot = mat3::Identity();
            pivotPos = Editor::GetItemPivot(item);
            isFlying = item.IsFlying ? 1 : 0;
            variantIx = item.IVariant;
            associatedBlockIx = uint(-1);
            itemGroupOnBlock = uint(-1);
            if (item.WaypointSpecialProperty !is null) {
                @waypoint = WaypointSpec(item.WaypointSpecialProperty);
            }
            @_rawBGSkin = Editor::GetItemBGSkin(item);
            @_rawFGSkin = Editor::GetItemFGSkin(item);
            SetModel(item.ItemModel);
        }

        ItemSpecPriv(CGameItemModel@ itemModel, const vec3 &in position, const vec3 &in pyrRotation) {
            super();
            // name and author are set by SetModel
            coord = PosToCoord(position) - nat3(0, 1, 0);
            dir = CGameCtnAnchoredObject::ECardinalDirections(uint8(-1));
            pos = position + vec3(0, 56, 0);
            pyr = pyrRotation;
            //if (pyr.y < NegPI) pyr.y += TAU;
            color = CGameCtnAnchoredObject::EMapElemColor::Default;
            visualRot = mat3::Identity();
            pivotPos = vec3(0, 0, 0);
            isFlying = 1;
            variantIx = 0;
            associatedBlockIx = uint(-1);
            itemGroupOnBlock = uint(-1);
            SetModel(itemModel);
        }

        ItemSpecPriv(DGameCtnMacroBlockInfo_Item@ item) {
            super();
            name = item.name;
            // collection = blah
            author = item.author;
            coord = item.coord;
            dir = item.dir;
            pos = item.pos;
            pyr = item.pyr;
            scale = item.scale;
            color = item.color;
            lmQual = item.lmQual;
            phase = item.phase;
            visualRot = item.visualRot;
            pivotPos = item.pivotPos;
            isFlying = item.isFlying ? 1 : 0;
            variantIx = item.variantIx;
            associatedBlockIx = 0xFFFFFFFF; // item.associatedBlockIx;
            itemGroupOnBlock = 0xFFFFFFFF; // item.itemGroupOnBlock;
            if (item.Waypoint !is null) {
                @waypoint = WaypointSpec(item.Waypoint);
            }
            @_rawBGSkin = item.BGSkin;
            @_rawFGSkin = item.FGSkin;
            // ignore skins for the moment
            SetModel(item.Model);
        }

        void SetCoordFromAssociatedBlock(CGameCtnBlock@ b) {
            if (b is null) return;
            coord = b.Coord;
        }

        ItemSpecPriv(MemoryBuffer@ buf) {
            super();
            ReadFromNetworkBuffer(buf);
        }

        bool MatchesItem(CGameCtnAnchoredObject@ item) const override {
            bool ret = name == item.ItemModel.IdName && collection == 26 && author == item.ItemModel.Author.GetName() &&
                MathX::Nat3Eq(coord, item.BlockUnitCoord - nat3(0, 1, 0)) &&
                // uint8(dir) == uint(-1) &&
                MathX::Vec3Within(pos, Editor::GetItemLocation(item) + vec3(0, 56, 0), 0.0001) &&
                scale == item.Scale &&
                // color == item.MapElemColor && lmQual == item.MapElemLmQuality &&
                phase == item.AnimPhaseOffset &&
                MathX::Vec3Eq(pivotPos, Editor::GetItemPivot(item)) &&
                isFlying == uint8(item.IsFlying ? 1 : 0) &&
                variantIx == item.IVariant;
            if (!ret) return false;
            vec3 itemRot = Editor::GetItemRotation(item);
            return AnglesVeryClose(pyr, itemRot);
        }

        bool MatchesItem(CGameCtnEditorScriptAnchoredObject@ item) const override {
            return name == item.ItemModel.IdName && MathX::Vec3Eq(pos, item.Position + vec3(0, 56, 0));
        }

        bool opEquals(const ItemSpec@ other) const override {
            // debug failed match
            // trace("opEquals for: " + name + " and " + other.name);
            // trace('name match: ' + (name == other.name));
            // trace('collection match: ' + (collection == other.collection));
            // trace('author match: ' + (author == other.author));
            // trace('coord match: ' + MathX::Nat3Eq(coord, other.coord));
            // trace('dir match: ' + (uint8(dir) == uint8(other.dir)) + ' ' + dir + ' ' + other.dir);
            // trace('pos match: ' + MathX::Vec3Eq(pos, other.pos));
            // trace('pyr match: ' + MathX::Vec3Eq(pyr, other.pyr));
            // trace('scale match: ' + (scale == other.scale));
            // trace('color match: ' + (color == other.color));
            // trace('lmQual match: ' + (lmQual == other.lmQual));
            // trace('phase match: ' + (phase == other.phase));
            // trace('pivotPos match: ' + MathX::Vec3Eq(pivotPos, other.pivotPos));
            // trace('isFlying match: ' + (isFlying == other.isFlying));
            // trace('variantIx match: ' + (variantIx == other.variantIx));

            if (other is null) return false;
            return other !is null && name == other.name && collection == other.collection && author == other.author &&
                MathX::Nat3Eq(coord, other.coord) &&
                // uint8(dir) == uint8(other.dir) && // maybe ignore dir, can be ff or other
                MathX::Vec3Eq(pos, other.pos) &&
                scale == other.scale &&
                color == other.color && lmQual == other.lmQual &&
                phase == other.phase && MathX::Vec3Eq(pivotPos, other.pivotPos) &&
                // isFlying == other.isFlying && // ignore isflying
                variantIx == other.variantIx &&
                AnglesVeryClose(pyr, other.pyr);
        }

        void WriteToMemory(CustomBuffer@ mem) {
            auto item = DGameCtnMacroBlockInfo_Item(mem.ptr);
            item.name = name;
            item.collection = collection;
            item.author = author;
            item.coord = coord;
            item.dir = dir;
            item.pos = pos;
            item.pyr = pyr;
            item.scale = scale;
            item.color = color;
            item.lmQual = lmQual;
            item.phase = phase;
            item.visualRot = visualRot;
            item.pivotPos = pivotPos;
            item.isFlying = isFlying > 0;
            item.variantIx = variantIx;
            item.associatedBlockIx = 0xFFFFFFFF;
            item.itemGroupOnBlock = 0xFFFFFFFF;
            item.unk94 = 0xFFFFFFFF;
            item.unk9C = 0xFFFFFFFF;
            if (waypoint is null) {
                @item.Waypoint = null;
            } else {
                @item.Waypoint = CGameWaypointSpecialProperty();
                item.Waypoint.Order = waypoint.order;
                item.Waypoint.Tag = waypoint.tag;
            }
            @item.FGSkin = _rawFGSkin;
            @item.BGSkin = _rawBGSkin;
            if (Model is null) {
                SetModel(TryLoadingModelFromFid());
            }
            @item.Model = Model;
            // get model
            if (item.Model is null) {
                auto inv = Editor::GetInventoryCache();
                while (inv.isRefreshing) yield();
                auto art = inv.GetItemByPath(name);
                if (art !is null) {
                    auto modelNod = art.GetCollectorNod();
                    auto model = cast<CGameItemModel>(modelNod);
                    if (model !is null) {
                        @item.Model = model;
                        SetModel(model);
                    } else {
                        NotifyWarning("Failed to load item model for " + name + ".\nArticle: " + art.Name);
                    }
                } else {
                    NotifyWarning("Failed to load item article for " + name);
                }
            }
        }

        void SetModel(CGameItemModel@ _model) {
            if (Model !is null) {
                Model.MwRelease();
            }
            @Model = _model;
            if (Model !is null) {
                name = _model.IdName;
                // during really heavy times, we get a null ptr exception
                // can get null ptr exception here
                author = _model.Author.GetName();
                Model.MwAddRef();
            }
        }

        CGameItemModel@ TryLoadingModelFromFid() {
            auto fid = Fids::GetUser("Items\\" + name);
            if (fid !is null && fid.Nod !is null) {
                auto model = cast<CGameItemModel>(fid.Nod);
                if (model !is null) {
                    return model;
                }
            }
            return null;
        }

        BlockSpec@ ToBlockSpec(CGameCtnBlockInfo@ model, uint blockVariant = 0, bool isGround = false) override {
            auto spec = BlockSpecPriv(model, pos, pyr);
            spec.color = CGameCtnBlock::EMapElemColor(int(color));
            spec.lmQual = CGameCtnBlock::EMapElemLightmapQuality(int(lmQual));
            spec.isFree = true;
            spec.isGhost = false;
            spec.isGround = isGround;
            spec.variant = blockVariant;
            if (!spec.EnsureValidVariant()) warn("Failed to find valid block variant for " + model.IdName);
            if (waypoint !is null) {
                @spec.waypoint = WaypointSpec(waypoint.tag, waypoint.order);
            }
            return spec;
        }

        void TranslateCoords(int3 coordDist) override {
            vec3 posDiff = CoordDistToPos(coordDist);
            pos += posDiff;
            coord = Int3ToNat3(Nat3ToInt3(coord) + coordDist);
        }

        ItemSpec@ SetCoordAndFlying() override {
            dev_trace("SetCoordAndFlying; coord before: " + coord.ToString());
            coord = PosToCoord(pos) - nat3(0, 7, 0);
            dev_trace("SetCoordAndFlying; coord after: " + coord.ToString());
            isFlying = 1;
            return this;
        }

        ItemSpec@ Duplicate() override {
            auto newItem = ItemSpecPriv();
            newItem.name = name;
            newItem.collection = collection;
            newItem.author = author;
            newItem.coord = coord;
            newItem.dir = dir;
            newItem.pos = pos;
            newItem.pyr = pyr;
            newItem.scale = scale;
            newItem.color = color;
            newItem.lmQual = lmQual;
            newItem.phase = phase;
            newItem.visualRot = visualRot;
            newItem.pivotPos = pivotPos;
            newItem.isFlying = isFlying > 0 ? 1 : 0;
            newItem.variantIx = variantIx;
            newItem.associatedBlockIx = associatedBlockIx;
            newItem.itemGroupOnBlock = itemGroupOnBlock;
            if (waypoint !is null) @newItem.waypoint = waypoint.Clone();
            if (skin !is null) @newItem.skin = SetSkinSpecPriv(newItem, skin.fgSkin, skin.bgSkin);
            newItem.SetModel(Model);

            newItem.ObjPtr = ObjPtr;
            @newItem._rawFGSkin = _rawFGSkin;
            @newItem._rawBGSkin = _rawBGSkin;
            return newItem;
        }
    }

    // MARK: SetSkinSpec

    class SetSkinSpecPriv : SetSkinSpec {
        SetSkinSpecPriv(BlockSpec@ block, const string &in fgSkin, const string &in bgSkin) {
            super(block, fgSkin, bgSkin);
        }

        SetSkinSpecPriv(ItemSpec@ item, const string &in skin, bool isForegroundElseBackground) {
            super(item, skin, isForegroundElseBackground);
        }
        SetSkinSpecPriv(ItemSpec@ item, const string &in fgSkin, const string &in bgSkin) {
            super(item, fgSkin, bgSkin);
        }
        SetSkinSpecPriv(MemoryBuffer@ buf) {
            super();
            ReadFromNetworkBuffer(buf);
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            fgSkin = ReadLPStringFromBuffer(buf);
            bgSkin = ReadLPStringFromBuffer(buf);
            @block = cast<BlockSpecPriv>(ReadNullableStructFromBuffer(buf, BlockSpecPriv()));
            @item = cast<ItemSpecPriv>(ReadNullableStructFromBuffer(buf, ItemSpecPriv()));
            return this;
        }
    }
}

// MARK: CustomBuffer

class CustomBuffer {
    uint32 allocSize;
    uint64 ptr;
    uint32 cursor;
    bool freeOnDestroy = false;

    CustomBuffer(uint64 ptr, uint32 size) {
        this.ptr = ptr;
        allocSize = size;
        cursor = 0;
        freeOnDestroy = false;
    }

    CustomBuffer(uint32 size) {
        ptr = Dev_Allocate(Math::Max(int(8), size), false);
        if (ptr == 0) throw("Failed to allocate D:");
        allocSize = size;
        cursor = 0;
        freeOnDestroy = true;
    }

    ~CustomBuffer() {
        if (ptr > 0 && freeOnDestroy) {
            FreeAllocated(ptr);
        }
    }

    string[]@ DebugRead() {
        if (cursor > allocSize) {
            throw("Cursor out of bounds");
        }
        return {
            Dev::Read(ptr, cursor),
            Dev::Read(ptr + cursor, allocSize - cursor)
        };
    }

    CustomBuffer@ GetPtrVAlloc(uint32 size) {
        CheckSize(size);
        uint64 ret = ptr + cursor;
        cursor += size;
        return CustomBuffer(ret, size);
    }

    void CheckSize(uint32 size) {
        if (size + cursor > allocSize) {
            throw("Would buffer overflow: " + (size + cursor) + " > " + allocSize);
        }
    }

    uint64 CheckAdvSize(uint32 size) {
        CheckSize(size);
        auto ret = ptr + cursor;
        cursor += size;
        return ret;
    }

    void SeekRelative(int32 posDelta) {
        cursor += posDelta;
    }

    void Write(uint64 val) {
        Dev::Write(CheckAdvSize(8), val);
    }

    void Write(uint32 val) {
        Dev::Write(CheckAdvSize(4), val);
    }

    void Write(uint16 val) {
        Dev::Write(CheckAdvSize(2), val);
    }

    void Write(uint8 val) {
        Dev::Write(CheckAdvSize(1), val);
    }

    void Write(float val) {
        Dev::Write(CheckAdvSize(4), val);
    }

    void Write(vec3 val) {
        Dev::Write(CheckAdvSize(12), val);
    }

    void Write(nat3 val) {
        Dev::Write(CheckAdvSize(12), val);
    }

    void Write(CMwNod@ nod) {
        Dev::Write(CheckAdvSize(8), Dev_GetPointerForNod(nod));
    }
}



namespace TestNetworkBufMacroblockStuff {

    void WriteVec3ToBuffer(MemoryBuffer@ buf, vec3 v) {
        buf.Write(v.x);
        buf.Write(v.y);
        buf.Write(v.z);
    }

    vec3 ReadVec3FromBuffer(MemoryBuffer@ buf) {
        auto x = buf.ReadFloat();
        auto y = buf.ReadFloat();
        auto z = buf.ReadFloat();
        return vec3(x, y, z);
    }

    void WriteNat3ToBuffer(MemoryBuffer@ buf, nat3 v) {
        buf.Write(v.x);
        buf.Write(v.y);
        buf.Write(v.z);
    }

    nat3 ReadNat3FromBuffer(MemoryBuffer@ buf) {
        auto x = buf.ReadUInt32();
        auto y = buf.ReadUInt32();
        auto z = buf.ReadUInt32();
        return nat3(x, y, z);
        // return nat3(buf.ReadUInt32(), buf.ReadUInt32(), buf.ReadUInt32());
    }

#if DEV

    Tester@ Test_RWBuf = Tester("ReadWriteBuffer", genRWBufTests());

    TestCase@[]@ genRWBufTests() {
        TestCase@[]@ ret = {};
        ret.InsertLast(TestCase("buf vec3 wr", test_vec3_buf_wr));
        ret.InsertLast(TestCase("buf nat3 wr", test_nat3_buf_rw));
        return ret;
    }

    void test_vec3_buf_wr() {
        auto buf = MemoryBuffer(100, 0);
        auto i = vec3(1, 2, 3);
        WriteVec3ToBuffer(buf, i);
        buf.Seek(0);
        auto v = ReadVec3FromBuffer(buf);
        print("V: " + v.ToString());
        assert_eq(v.x, i.x, "x");
        assert_eq(v.y, i.y, "y");
        assert_eq(v.z, i.z, "z");

        Editor::NetworkSerializable@ netSz = Editor::NetworkSerializable();
        buf.Seek(0);
        netSz.WriteVec3ToBuffer(buf, i);
        buf.Seek(0);
        v = netSz.ReadVec3FromBuffer(buf);
        print("V: " + v.ToString());
        assert_eq(v.x, i.x, "x");
        assert_eq(v.y, i.y, "y");
        assert_eq(v.z, i.z, "z");
    }

    void test_nat3_buf_rw() {
        auto buf = MemoryBuffer(100, 0);
        auto i = nat3(1, 2, 3);
        WriteNat3ToBuffer(buf, i);
        buf.Seek(0);
        auto v = ReadNat3FromBuffer(buf);
        print("V: " + v.ToString());
        assert_eq(v.x, i.x, "x");
        assert_eq(v.y, i.y, "y");
        assert_eq(v.z, i.z, "z");

        Editor::NetworkSerializable@ netSz = Editor::NetworkSerializable();
        buf.Seek(0);
        netSz.WriteNat3ToBuffer(buf, i);
        buf.Seek(0);
        v = netSz.ReadNat3FromBuffer(buf);
        print("V: " + v.ToString());
        assert_eq(v.x, i.x, "x");
        assert_eq(v.y, i.y, "y");
        assert_eq(v.z, i.z, "z");
    }
#endif

}
