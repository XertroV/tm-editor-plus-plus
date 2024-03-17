namespace Editor {
    class NetworkSerializable {
        void WriteToNetworkBuffer(MemoryBuffer@ buf) {
            throw("Not implemented -- override me");
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) {
            throw("Not implemented -- override me");
        }

        // calc size for network buffer, unused atm
        uint CalcSize() {
            throw("unimplemented");
            return 0;
        }

        void WriteLPStringToBuffer(MemoryBuffer@ buf, string str) {
            if (str.Length > 0xFFFF) {
                throw("String too long");
            }
            buf.Write(uint16(str.Length));
            buf.Write(str);
        }

        string ReadLPStringFromBuffer(MemoryBuffer@ buf) {
            uint16 len = buf.ReadUInt16();
            return buf.ReadString(len);
        }

        void WriteNullableStructToBuffer(MemoryBuffer@ buf, NetworkSerializable@ obj) {
            if (obj is null) {
                buf.Write(uint8(0));
            } else {
                buf.Write(uint8(1));
                obj.WriteToNetworkBuffer(buf);
            }
        }

        NetworkSerializable@ ReadNullableStructFromBuffer(MemoryBuffer@ buf, NetworkSerializable@ obj) {
            uint8 hasValue = buf.ReadUInt8();
            if (hasValue == 0) {
                return null;
            } else {
                obj.ReadFromNetworkBuffer(buf);
                return obj;
            }
        }

        void WriteVec3ToBuffer(MemoryBuffer@ buf, vec3 v) {
            buf.Write(v.x);
            buf.Write(v.y);
            buf.Write(v.z);
        }

        vec3 ReadVec3FromBuffer(MemoryBuffer@ buf) {
            return vec3(buf.ReadFloat(), buf.ReadFloat(), buf.ReadFloat());
        }

        void WriteNat3ToBuffer(MemoryBuffer@ buf, nat3 v) {
            buf.Write(v.x);
            buf.Write(v.y);
            buf.Write(v.z);
        }

        nat3 ReadNat3FromBuffer(MemoryBuffer@ buf) {
            return nat3(buf.ReadUInt32(), buf.ReadUInt32(), buf.ReadUInt32());
        }
    }

    class MacroblockSpec : NetworkSerializable {
        BlockSpec@[] blocks;
        SkinSpec@[] skins;
        ItemSpec@[] items;

        MacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) {
            AddBlocks(blocks);
            // ignore skins atm
            // AddSkins(blocks);
            AddItems(items);
        }

        MacroblockSpec(CGameCtnMacroBlockInfo@ mb) {
            auto dmb = DGameCtnMacroBlockInfo(mb);

        }

        uint CalcSize() override {
            uint size = 0;
            size += 4; // magic
            size += 2; // block count
            for (uint i = 0; i < blocks.Length; i++) {
                size += blocks[i].CalcSize();
            }
            size += 4; // magic
            size += 2; // skin count
            for (uint i = 0; i < skins.Length; i++) {
                size += skins[i].CalcSize();
            }
            size += 4; // magic
            size += 2; // item count
            for (uint i = 0; i < items.Length; i++) {
                size += items[i].CalcSize();
            }
            return size;
        }

        void AddBlocks(CGameCtnBlock@[]@ blocks) {
            for (uint i = 0; i < blocks.Length; i++) {
                AddBlock(blocks[i]);
            }
        }
        void AddBlock(CGameCtnBlock@ block) {
            blocks.InsertLast(BlockSpec(block));
        }
        void AddSkins(CGameCtnBlock@[]@ blocks) {
            for (uint i = 0; i < blocks.Length; i++) {
                if (blocks[i].Skin != null) {
                    AddSkin(blocks[i].Skin, i);
                }
            }
        }
        void AddSkin(CGameCtnBlockSkin@ skin, uint ix) {
            skins.InsertLast(SkinSpec(skin, ix));
        }
        void AddItems(CGameCtnAnchoredObject@[]@ items) {
            for (uint i = 0; i < items.Length; i++) {
                AddItem(items[i]);
            }
        }
        void AddItem(CGameCtnAnchoredObject@ item) {
            items.InsertLast(ItemSpec(item));
        }

        protected DGameCtnMacroBlockInfo@ tmpMacroblock = null;
        protected uint64 tmpMacroblockBlocksBuf = 0;
        protected uint64 tmpMacroblockBlocksBufLenCap = 0;
        protected uint64 tmpMacroblockItemsBuf = 0;
        protected uint64 tmpMacroblockItemsBufLenCap = 0;
        protected uint64 tmpMacroblockSkinsBuf = 0;
        protected uint64 tmpMacroblockSkinsBufLenCap = 0;
        bool releaseTmpMacroblock = false;

        protected void TempWriteToMacroblock(CGameCtnMacroBlockInfo@ macroblock) {
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

            AllocAndWriteMemory();
        }

        CustomBuffer@ tmpWriteBuf;

        protected void AllocAndWriteMemory() {
            @tmpWriteBuf = CustomBuffer(CalcRequiredMbBufSize());
            auto blocksPtrs = tmpWriteBuf.GetPtrVAlloc(0x8 * blocks.Length);
            for (uint i = 0; i < blocks.Length; i++) {
                auto blockEl = tmpWriteBuf.GetPtrVAlloc(SZ_MACROBLOCK_BLOCKSBUFEL);
                blocksPtrs.Write(blockEl.ptr);
                blocks[i].WriteToMemory(blockEl);
            }
            auto skinsPtrs = tmpWriteBuf.GetPtrVAlloc(0x8 * skins.Length);
            for (uint i = 0; i < skins.Length; i++) {
                auto skinEl = tmpWriteBuf.GetPtrVAlloc(SZ_MACROBLOCK_SKINSBUFEL);
                skinsPtrs.Write(skinEl.ptr);
                skins[i].WriteToMemory(skinEl);
            }
            auto itemsPtrs = tmpWriteBuf.GetPtrVAlloc(0x8 * items.Length);
            for (uint i = 0; i < items.Length; i++) {
                auto itemEl = tmpWriteBuf.GetPtrVAlloc(SZ_MACROBLOCK_ITEMSBUFEL);
                itemsPtrs.Write(itemEl.ptr);
                items[i].WriteToMemory(itemEl);
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

        protected void RestoreMacroblock() {
            Dev::Write(tmpMacroblock.Blocks.Ptr, tmpMacroblockBlocksBuf);
            Dev::Write(tmpMacroblock.Blocks.Ptr + 0x8, tmpMacroblockBlocksBufLenCap);
            Dev::Write(tmpMacroblock.Items.Ptr, tmpMacroblockItemsBuf);
            Dev::Write(tmpMacroblock.Items.Ptr + 0x8, tmpMacroblockItemsBufLenCap);
            Dev::Write(tmpMacroblock.Skins.Ptr, tmpMacroblockSkinsBuf);
            Dev::Write(tmpMacroblock.Skins.Ptr + 0x8, tmpMacroblockSkinsBufLenCap);

            @tmpWriteBuf = null;

            if (tmpMacroblock !is null && releaseTmpMacroblock) {
                tmpMacroblock.Nod.MwRelease();
            }
            @tmpMacroblock = null;
            releaseTmpMacroblock = false;
        }

        void WriteToNetworkBuffer(MemoryBuffer@ buf) override {
            // 0x734b4c42 = "BLKs"
            buf.Write(MAGIC_BLOCKS);
            buf.Write(uint16(blocks.Length));
            for (uint i = 0; i < blocks.Length; i++) {
                blocks[i].WriteToNetworkBuffer(buf);
            }

            // 0x734e4b53 = "SKNs"
            buf.Write(MAGIC_SKINS);
            // todo: leave skins for later, can replicate with API anyway
            buf.Write(uint16(0));
            // buf.Write(uint16(skins.Length));
            // for (uint i = 0; i < skins.Length; i++) {
            //     skins[i].WriteToNetworkBuffer(buf);
            // }

            // 0x734d5449 = "ITMs"
            buf.Write(MAGIC_ITEMS);
            buf.Write(uint16(items.Length));
            for (uint i = 0; i < items.Length; i++) {
                items[i].WriteToNetworkBuffer(buf);
            }
        }
    }

    const uint32 MAGIC_BLOCKS = 0x734b4c42;
    const uint32 MAGIC_SKINS = 0x734e4b53;
    const uint32 MAGIC_ITEMS = 0x734d5449;

    enum BlockFlags {
        None = 0,
        Ground = 1,
        Ghost = 2,
        Free = 4,
    }

    class BlockSpec : NetworkSerializable {
        string name;
        // 26=stadium; 25=stadium256
        uint collection = 26;
        string author;
        nat3 coord;
        CGameCtnBlock::ECardinalDirections dir;
        CGameCtnBlock::ECardinalDirections dir2;
        vec3 pos;
        vec3 pyr;
        CGameCtnBlock::EMapElemColor color;
        CGameCtnBlock::EMapElemLightmapQuality lmQual;
        uint mobilIx;
        uint mobilVariant;
        uint variant;
        uint8 flags;
        // refcounted
        WaypointSpec@ waypoint;
        // block model not refcounted in this case
        // block model -- get from name

        BlockSpec(CGameCtnBlock@ block) {
            name = block.BlockInfo.IdName;
            // collection = blah
            author = block.BlockInfo.Author.GetName();
            coord = block.Coord;
            dir = block.Dir;
            dir2 = block.Dir;
            pos = Editor::GetBlockLocation(block);
            pyr = Editor::GetBlockRotation(block);
            color = block.MapElemColor;
            lmQual = block.MapElemLmQuality;
            mobilIx = block.MobilIndex;
            mobilVariant = block.MobilVariantIndex;
            variant = block.BlockInfoVariantIndex;
            flags = (block.IsGround ? BlockFlags::Ground : BlockFlags::None) |
                    (block.IsGhostBlock() ? BlockFlags::Ghost : BlockFlags::None) |
                    (Editor::IsBlockFree(block) ? BlockFlags::Free : BlockFlags::None);
            if (block.WaypointSpecialProperty !is null) {
                @waypoint = WaypointSpec(block.WaypointSpecialProperty);
            }
        }

        BlockSpec(DGameCtnMacroBlockInfo_Block@ block) {
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
            variant = block.variant;
            flags = block.flags;
            if (block.Waypoint !is null) {
                @waypoint = WaypointSpec(block.Waypoint);
            }
        }

        BlockSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
            if (collection != 26) {
                throw("Warning: block collection is not stadium");
            }
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
            @block.BlockInfo = null;
            auto inv = Editor::GetInventoryCache();
            auto art = inv.GetBlockByName(name);
            if (art !is null) {
                auto modelNod = art.GetCollectorNod();
                auto model = cast<CGameCtnBlockInfo>(modelNod);
                if (model !is null) {
                    @block.BlockInfo = model;
                } else {
                    NotifyWarning("Failed to load block model for " + name + ".\nArticle: " + art.Name);
                }
            } else {
                NotifyWarning("Failed to load block article for " + name);
            }
        }

        uint CalcSize() override {
            uint size = 0;
            size += 2; // name length
            size += name.Length;
            size += 4; // collection
            size += 2; // author length
            size += author.Length;
            size += 12; // coord
            size += 1; // dir
            size += 1; // dir2
            size += 12; // pos
            size += 12; // pyr
            size += 1; // color
            size += 1; // lmQual
            size += 4; // mobilIx
            size += 4; // mobilVariant
            size += 4; // variant
            size += 1; // flags
            size += 1; // waypoint present
            if (waypoint !is null) {
                size += waypoint.CalcSize();
            }
            return size;
        }

        void WriteToNetworkBuffer(MemoryBuffer@ buf) override {
            WriteLPStringToBuffer(buf, name);
            buf.Write(collection);
            WriteLPStringToBuffer(buf, author);
            WriteNat3ToBuffer(buf, coord);
            buf.Write(uint8(dir));
            buf.Write(uint8(dir2));
            WriteVec3ToBuffer(buf, pos);
            WriteVec3ToBuffer(buf, pyr);
            buf.Write(uint8(color));
            buf.Write(uint8(lmQual));
            buf.Write(mobilIx);
            buf.Write(mobilVariant);
            buf.Write(variant);
            buf.Write(flags);
            WriteNullableStructToBuffer(buf, waypoint);
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            name = ReadLPStringFromBuffer(buf);
            collection = buf.ReadUInt32();
            author = ReadLPStringFromBuffer(buf);
            coord = ReadNat3FromBuffer(buf);
            dir = CGameCtnBlock::ECardinalDirections(buf.ReadUInt8());
            dir2 = CGameCtnBlock::ECardinalDirections(buf.ReadUInt8());
            pos = ReadVec3FromBuffer(buf);
            pyr = ReadVec3FromBuffer(buf);
            color = CGameCtnBlock::EMapElemColor(buf.ReadUInt8());
            lmQual = CGameCtnBlock::EMapElemLightmapQuality(buf.ReadUInt8());
            mobilIx = buf.ReadUInt32();
            mobilVariant = buf.ReadUInt32();
            variant = buf.ReadUInt32();
            flags = buf.ReadUInt8();
            // nullable struct
            if (buf.ReadUInt8() == 1) {
                @waypoint = WaypointSpec(buf);
            }
            return this;
        }
    }

    class WaypointSpec : NetworkSerializable {
        string tag;
        uint order;

        WaypointSpec(CGameWaypointSpecialProperty@ waypoint) {
            tag = waypoint.Tag;
            order = waypoint.Order;
        }

        WaypointSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        void WriteToNetworkBuffer(MemoryBuffer@ buf) override {
            WriteLPStringToBuffer(buf, tag);
            buf.Write(order);
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            tag = ReadLPStringFromBuffer(buf);
            order = buf.ReadUInt32();
            return this;
        }
    }

    class SkinSpec : NetworkSerializable {
        CGameCtnBlockSkin@ rawSkin;
        uint blockIx;

        SkinSpec(CGameCtnBlockSkin@ skin, uint blockIx) {
            @rawSkin = skin;
            this.blockIx = blockIx;
        }

        void WriteToNetworkBuffer(MemoryBuffer@ buf) override {
            buf.Write(blockIx);
            // buf.Write(rawSkin);
        }

        void WriteToMemory(CustomBuffer@ mem) {
            mem.Write(null); // skin ptr
            mem.SeekRelative(12); // skip unused 0x8 -> 0x14
            mem.Write(blockIx);
            // mem.WritePtr(rawSkin);
        }
    }

    class ItemSpec : NetworkSerializable {
        string name;
        // 26=stadium; 25=stadium256
        uint collection = 26;
        string author;
        nat3 coord;
        CGameCtnBlock::ECardinalDirections dir;
        vec3 pos;
        vec3 pyr;
        float scale;
        CGameCtnAnchoredObject::EMapElemColor color;
        CGameCtnAnchoredObject::EMapElemLightmapQuality lmQual;
        CGameCtnAnchoredObject::EPhaseOffset phase;
        mat3 visualRot;
        vec3 pivotPos;
        uint8 isFlying;
        uint16 variantIx;
        uint associatedBlockIx;
        uint itemGroupOnBlock;
        // ? refcounted
        WaypointSpec@ waypoint;
        // bg skin
        // fg skin
        // model

        ItemSpec(CGameCtnAnchoredObject@ item) {
            name = item.ItemModel.IdName;
            // collection = blah
            author = item.ItemModel.Author.GetName();
            coord = item.BlockUnitCoord;
            dir = -1;
            pos = Editor::GetItemLocation(item);
            pyr = Editor::GetItemRotation(item);
            scale = item.Scale;
            color = item.MapElemColor;
            lmQual = item.MapElemLmQuality;
            phase = item.AnimPhaseOffset;
            visualRot = mat3::Identity();
            pivotPos = Editor::GetItemPivot(item);
            isFlying = item.IsFlying ? 1 : 0;
            variantIx = item.IVariant;
            associatedBlockIx = -1;
            itemGroupOnBlock = -1;
            if (item.WaypointSpecialProperty !is null) {
                @waypoint = WaypointSpec(item.WaypointSpecialProperty);
            }
            // ignore skins for the moment
        }

        ItemSpec(DGameCtnMacroBlockInfo_Item@ item) {
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
            isFlying = item.isFlying;
            variantIx = item.variantIx;
            associatedBlockIx = 0xFFFFFFFF; // item.associatedBlockIx;
            itemGroupOnBlock = 0xFFFFFFFF; // item.itemGroupOnBlock;
            if (item.Waypoint !is null) {
                @waypoint = WaypointSpec(item.Waypoint);
            }
            // ignore skins for the moment
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
            item.isFlying = isFlying;
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
            @item.BGSkin = null;
            @item.FGSkin = null;
            @item.Model = null;
            // get model
            auto inv = Editor::GetInventoryCache();
            auto art = inv.GetItemByPath(name);
            if (art !is null) {
                auto modelNod = art.GetCollectorNod();
                auto model = cast<CGameItemModel>(modelNod);
                if (model !is null) {
                    @item.Model = model;
                } else {
                    NotifyWarning("Failed to load item model for " + name + ".\nArticle: " + art.Name);
                }
            } else {
                NotifyWarning("Failed to load item article for " + name);
            }
        }

        void WriteToNetworkBuffer(MemoryBuffer@ buf) override {
            WriteLPStringToBuffer(buf, name);
            buf.Write(collection);
            WriteLPStringToBuffer(buf, author);
            WriteNat3ToBuffer(buf, coord);
            buf.Write(uint8(dir));
            WriteVec3ToBuffer(buf, pos);
            WriteVec3ToBuffer(buf, pyr);
            buf.Write(scale);
            buf.Write(uint8(color));
            buf.Write(uint8(lmQual));
            buf.Write(uint8(phase));
            // skip visualRot b/c it's always identity
            WriteVec3ToBuffer(buf, pivotPos);
            buf.Write(isFlying);
            buf.Write(variantIx);
            buf.Write(associatedBlockIx);
            buf.Write(itemGroupOnBlock);
            WriteNullableStructToBuffer(buf, waypoint);
        }
    }
}

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
        ptr = Dev::Allocate(size, false);
        if (ptr == 0) throw("Failed to allocate D:");
        allocSize = size;
        cursor = 0;
        freeOnDestroy = true;
    }

    ~CustomBuffer() {
        if (ptr > 0 && freeOnDestroy) {
            Dev::Free(ptr);
        }
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

    void CheckAdvSize(uint32 size) {
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
