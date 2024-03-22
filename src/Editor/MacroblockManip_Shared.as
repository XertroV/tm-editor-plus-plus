namespace Editor {
    shared class NetworkSerializable {
        MemoryBuffer@ cached;

        void WriteToNetworkBuffer(MemoryBuffer@ buf) {
            if (cached is null) {
                @cached = MemoryBuffer();
                WriteToNetworkBufferInternal(cached);
            }
            cached.Seek(0);
            buf.WriteFromBuffer(cached, cached.GetSize());
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) {
            throw("Not implemented -- override me");
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) {
            throw("Not implemented -- override me");
            return null;
        }

        // calc size for network buffer, unused atm
        uint CalcSize() {
            throw("unimplemented");
            return 0;
        }

        void WriteLPStringToBuffer(MemoryBuffer@ buf, const string &in str) {
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
                obj.WriteToNetworkBufferInternal(buf);
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
        }
    }

    shared class MacroblockSpec : NetworkSerializable {
        BlockSpec@[] blocks;
        SkinSpec@[] skins;
        ItemSpec@[] items;

        BlockSpec@[]@ get_Blocks() {
            return blocks;
        }
        SkinSpec@[]@ get_Skins() {
            return skins;
        }
        ItemSpec@[]@ get_Items() {
            return items;
        }

        MacroblockSpec(CGameCtnBlock@[]@ blocks, CGameCtnAnchoredObject@[]@ items) {
            AddBlocks(blocks);
            // ignore skins atm
            // AddSkins(blocks);
            AddItems(items);
        }

        MacroblockSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        void DrawDebug() {
            UI::Text("Blocks: " + blocks.Length);
            UI::Indent();
            for (uint i = 0; i < blocks.Length; i++) {
                UI::Text("Block " + i + ": " + blocks[i].name + " (" + blocks[i].coord.ToString() + ")");
            }
            UI::Unindent();
            UI::Text("Items: " + items.Length);
            UI::Indent();
            for (uint i = 0; i < items.Length; i++) {
                UI::Text("Item " + i + ": " + items[i].name);
            }
            UI::Unindent();
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
            throw('override me');
        }
        void AddSkins(CGameCtnBlock@[]@ blocks) {
            for (uint i = 0; i < blocks.Length; i++) {
                if (blocks[i].Skin != null) {
                    AddSkin(blocks[i].Skin, i);
                }
            }
        }
        void AddSkin(CGameCtnBlockSkin@ skin, uint ix) {
            throw('override me');
        }
        void AddItems(CGameCtnAnchoredObject@[]@ items) {
            for (uint i = 0; i < items.Length; i++) {
                AddItem(items[i]);
            }
        }
        void AddItem(CGameCtnAnchoredObject@ item) {
            throw('override me');
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
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

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            throw("implemented elsewhere");
            return null;
        }
    }

    shared class MacroblockWithSetSkins : NetworkSerializable {
        MacroblockSpec@ macroblock;
        SetSkinSpec@[]@ setSkins;

        MacroblockWithSetSkins(MacroblockSpec@ macroblock, SetSkinSpec@[]@ setSkins) {
            @this.macroblock = macroblock;
            @this.setSkins = setSkins;
        }

        MacroblockWithSetSkins(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
            macroblock.WriteToNetworkBuffer(buf);
            buf.Write(uint16(setSkins.Length));
            for (uint i = 0; i < setSkins.Length; i++) {
                setSkins[i].WriteToNetworkBuffer(buf);
            }
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            @macroblock = MacroblockSpec(buf);
            uint16 setSkinCount = buf.ReadUInt16();
            for (uint i = 0; i < setSkinCount; i++) {
                setSkins.InsertLast(SetSkinSpec(buf));
            }
            return this;
        }
    }

    shared enum BlockFlags {
        None = 0,
        Ground = 1,
        Ghost = 2,
        Free = 4,
    }

    shared class BlockSpec : NetworkSerializable {
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

        BlockSpec() {}

        BlockSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
            if (collection != 26) {
                throw("Warning: block collection is not stadium");
            }
        }

        bool MatchesBlock(CGameCtnBlock@ block) const {
            throw("overridden elsewehre");
            return false;
        }

        bool opEquals(const BlockSpec@ other) const {
            throw("overridden elsewehre");
            return false;
        }

        bool get_isFree() {
            return flags & uint8(BlockFlags::Free) != 0;
        }
        bool get_isGround() {
            return flags & uint8(BlockFlags::Ground) != 0;
        }
        bool get_isGhost() {
            return flags & uint8(BlockFlags::Ghost) != 0;
        }
        bool get_isNormal() {
            return flags & 7 == 0;
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

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
            WriteLPStringToBuffer(buf, name);
            buf.Write(collection);
            WriteLPStringToBuffer(buf, author);
            WriteNat3ToBuffer(buf, coord);
            buf.Write(int8(dir));
            buf.Write(int8(dir2));
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
            dir = CGameCtnBlock::ECardinalDirections(buf.ReadInt8());
            dir2 = CGameCtnBlock::ECardinalDirections(buf.ReadInt8());
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

    shared class WaypointSpec : NetworkSerializable {
        string tag;
        uint order;

        WaypointSpec(CGameWaypointSpecialProperty@ waypoint) {
            tag = waypoint.Tag;
            order = waypoint.Order;
        }

        WaypointSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
            WriteLPStringToBuffer(buf, tag);
            buf.Write(order);
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            tag = ReadLPStringFromBuffer(buf);
            order = buf.ReadUInt32();
            return this;
        }
    }

    shared class SkinSpec : NetworkSerializable {
        CGameCtnBlockSkin@ rawSkin;
        uint blockIx;

        SkinSpec(CGameCtnBlockSkin@ skin, uint blockIx) {
            throw("skin spec not really implemented");
            @rawSkin = skin;
            this.blockIx = blockIx;
        }

        SkinSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
            buf.Write(blockIx);
            // buf.Write(rawSkin);
        }
    }

    shared class SetSkinSpec : NetworkSerializable {
        string fgSkin;
        string bgSkin;
        BlockSpec@ block;
        ItemSpec@ item;

        SetSkinSpec(BlockSpec@ block, const string &in fgSkin, const string &in bgSkin) {
            @this.block = block;
            this.fgSkin = fgSkin;
            this.bgSkin = bgSkin;
        }

        SetSkinSpec(ItemSpec@ item, const string &in skin, bool isForegroundElseBackground) {
            @this.item = item;
            if (isForegroundElseBackground) {
                this.fgSkin = skin;
            } else {
                this.bgSkin = skin;
            }
        }

        SetSkinSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
            // send the skins and the block/item
            if (!((block is null) ^^ (item is null))) {
                throw("Must specify exactly one of block or item");
            }
            WriteLPStringToBuffer(buf, fgSkin);
            WriteLPStringToBuffer(buf, bgSkin);
            WriteNullableStructToBuffer(buf, block);
            WriteNullableStructToBuffer(buf, item);
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            fgSkin = ReadLPStringFromBuffer(buf);
            bgSkin = ReadLPStringFromBuffer(buf);
            @block = cast<BlockSpec>(ReadNullableStructFromBuffer(buf, block));
            @item = cast<ItemSpec>(ReadNullableStructFromBuffer(buf, item));
            return this;
        }
    }

    shared class ItemSpec : NetworkSerializable {
        string name;
        // 26=stadium; 25=stadium256
        uint collection = 26;
        string author;
        nat3 coord;
        CGameCtnAnchoredObject::ECardinalDirections dir;
        vec3 pos;
        vec3 pyr;
        float scale;
        CGameCtnAnchoredObject::EMapElemColor color;
        CGameCtnAnchoredObject::EMapElemLightmapQuality lmQual;
        CGameCtnAnchoredObject::EPhaseOffset phase;
        mat3 visualRot = mat3::Identity();
        vec3 pivotPos;
        uint8 isFlying;
        uint16 variantIx;
        uint associatedBlockIx;
        uint itemGroupOnBlock;
        // ? refcounted
        WaypointSpec@ waypoint;
        // bg skin
        SetSkinSpec@ bgSkin;
        // fg skin
        SetSkinSpec@ fgSkin;
        // model

        ItemSpec() {}

        ItemSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
            if (collection != 26) {
                throw("Warning: item collection is not stadium");
            }
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
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
            WriteVec3ToBuffer(buf, vec3(1, 0, 0));
            WriteVec3ToBuffer(buf, vec3(0, 1, 0));
            WriteVec3ToBuffer(buf, vec3(0, 0, 1));
            WriteVec3ToBuffer(buf, pivotPos);
            buf.Write(isFlying);
            buf.Write(variantIx);
            buf.Write(associatedBlockIx);
            buf.Write(itemGroupOnBlock);
            WriteNullableStructToBuffer(buf, waypoint);
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            name = ReadLPStringFromBuffer(buf);
            collection = buf.ReadUInt32();
            author = ReadLPStringFromBuffer(buf);
            coord = ReadNat3FromBuffer(buf);
            dir = CGameCtnAnchoredObject::ECardinalDirections(buf.ReadUInt8());
            pos = ReadVec3FromBuffer(buf);
            pyr = ReadVec3FromBuffer(buf);
            scale = buf.ReadFloat();
            color = CGameCtnAnchoredObject::EMapElemColor(buf.ReadUInt8());
            lmQual = CGameCtnAnchoredObject::EMapElemLightmapQuality(buf.ReadUInt8());
            phase = CGameCtnAnchoredObject::EPhaseOffset(buf.ReadUInt8());
            // skip visualRot b/c it's always identity
            ReadVec3FromBuffer(buf);
            ReadVec3FromBuffer(buf);
            ReadVec3FromBuffer(buf);
            pivotPos = ReadVec3FromBuffer(buf);
            isFlying = buf.ReadUInt8();
            variantIx = buf.ReadUInt16();
            associatedBlockIx = buf.ReadUInt32();
            itemGroupOnBlock = buf.ReadUInt32();
            // nullable struct
            if (buf.ReadUInt8() == 1) {
                @waypoint = WaypointSpec(buf);
            }
            return this;
        }
    }
}

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
