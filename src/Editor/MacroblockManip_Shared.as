namespace Editor {
    // support class
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

        void _throwUnimpl() {
            throw("This method is implemented elsewhere. Instantiate using Editor::Make*() functions.");
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

        uint get_Length() {
            return blocks.Length + items.Length;
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
        void AddBlocks(BlockSpec@[]@ blocks) {
            for (uint i = 0; i < blocks.Length; i++) {
                blocks.InsertLast(blocks[i]);
            }
        }
        void AddBlock(CGameCtnBlock@ block) {
            throw('override me');
        }
        void AddBlock(BlockSpec@ block) {
            blocks.InsertLast(block);
        }
        void AddSkins(CGameCtnBlock@[]@ blocks) {
            for (uint i = 0; i < blocks.Length; i++) {
                if (blocks[i].Skin !is null) {
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
        void AddItems(ItemSpec@[]@ items) {
            for (uint i = 0; i < items.Length; i++) {
                items.InsertLast(items[i]);
            }
        }
        void AddItem(CGameCtnAnchoredObject@ item) {
            throw('override me');
        }
        void AddItem(ItemSpec@ item) {
            items.InsertLast(item);
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

        // Turn this macroblock into chunks of <= chunkSize (except blocks with the same XZ coord like pillars)
        MacroblockSpec@[]@ CreateChunks(int chunkSize) {
            throw("CreateChunks implemented elsewhere");
            return {this};
        }

        // Does not clone block and item specs! This will add all blocks and items from the other macroblock to this one.
        void AddMacroblock(MacroblockSpec@ macroblock) {
            // todo: handle skins
            AddBlocks(macroblock.blocks);
            AddItems(macroblock.items);
        }

        NewMbParts@ AddMacroblock(CGameCtnMacroBlockInfo@ macroblock, const vec3 &in position, const vec3 &in rotation) {
            throw("AddMacroblock for MacroBlockInfo not implemented here");
            return null;
        }
    }

    // 2 bits for each axis: 0=None, 1=Left, 2=Mid, 3=Right
    shared enum AlignWithinBlock {
        None = 0,
        X_Left = 1,
        X_Mid = 2,
        X_Right = 3,
        Y_Bottom = 4,// 1 << 2,
        Y_Mid = 8,// 2 << 2,
        Y_Top = 12,// 3 << 2,
        Z_Back = 16,// 1 << 4,
        Z_Mid = 32,// 2 << 4,
        Z_Forward = 48,// 3 << 4,
        Center = 42, // 2 + 8 + 32
    }

    shared class NewMbParts {
        BlockSpec@[] blocks;
        ItemSpec@[] items;
        SetSkinSpec@[] setSkins;
        NewMbParts() {}
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

    // use Editor::MakeBlockSpec isntead
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
        uint mobilVariant = 63;
        uint variant;
        // Set via Editor::BlockFlags enum values
        uint8 flags;
        // refcounted
        WaypointSpec@ waypoint;
        // block model not refcounted in this case
        // block model -- get from name -- note: this is done in BlockSpecPriv
        CGameCtnBlockInfo@ BlockInfo;

        // protected string _key;
        // string get_Key() const {
        //     return _key;
        // }

        BlockSpec() {}

        BlockSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
            if (collection != 26) {
                throw("Warning: block collection is not stadium");
            }
        }

        void SetFrom(CGameCtnBlock@ block) {
            throw("implemented elsewhere");
        }

        bool MatchesBlock(CGameCtnBlock@ block) const {
            throw("overridden elsewehre");
            return false;
        }

        bool opEquals(const BlockSpec@ other) const {
            throw("overridden elsewehre");
            return false;
        }

        bool get_isFree() const {
            return flags & uint8(BlockFlags::Free) != 0;
        }
        void set_isFree(bool value) {
            if (value) {
                flags |= uint8(BlockFlags::Free);
            } else {
                flags &= ~uint8(BlockFlags::Free);
            }
        }

        bool get_isGround() const {
            return flags & uint8(BlockFlags::Ground) != 0;
        }
        void set_isGround(bool value) {
            if (value) {
                flags |= uint8(BlockFlags::Ground);
            } else {
                flags &= ~uint8(BlockFlags::Ground) & 0x7;
            }
        }

        bool get_isGhost() const {
            return flags & uint8(BlockFlags::Ghost) != 0;
        }
        void set_isGhost(bool value) {
            if (value) {
                flags |= uint8(BlockFlags::Ghost);
            } else {
                flags &= ~uint8(BlockFlags::Ghost) & 0x7;
            }
        }

        bool get_isNormal() const {
            return flags & 6 == 0;
        }
        void SetToNormal() {
            flags &= uint8(BlockFlags::Ground);
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

        void SetCoord_AlsoPosRot(const nat3 &in _coord, CGameCtnBlockInfo@ block, int _dir) { _throwUnimpl(); }
        void SetCoord_AlsoPosRot(const nat3 &in _coord, vec3 coordSize, int _dir) { _throwUnimpl(); }
        void SetPosRot_AlsoCoordDir(vec3 position, vec3 pyrRotation) { _throwUnimpl(); }

        void SetColor(CGameCtnBlock::EMapElemColor _color) {
            color = _color;
        }

        void SetLmQual(CGameCtnBlock::EMapElemLightmapQuality _lmQual) {
            lmQual = _lmQual;
        }

        void SetMobilIx(uint _mobilIx) {
            mobilIx = _mobilIx;
        }

        void SetMobilVariant(uint _mobilVariant) {
            mobilVariant = _mobilVariant;
        }

        // void SetAirVariant() {
        //     if (BlockInfo is null) {
        //         warn("BlockInfo is null");
        //         return;
        //     }
        //     auto nbGroundVars = BlockInfo.AdditionalVariantsGround.Length + 1;
        //     if (variant < nbGroundVars) {
        //         variant = nbGroundVars;
        //     }
        //     // fix air variant ix
        //     if (BlockInfo.VariantBaseAir.IsObsoleteVariant) variant++;
        //     else return;
        //     for (int i = 0; i < int(BlockInfo.AdditionalVariantsAir.Length) - 1; i++) {
        //         if (BlockInfo.AdditionalVariantsGround[i].IsObsoleteVariant) variant++;
        //         else return;
        //     }
        // }

        // void SetGroundVariant() {
        //     if (BlockInfo is null) {
        //         warn("BlockInfo is null");
        //         return;
        //     }
        //     variant = 0;
        //     // fix variant ix
        //     if (BlockInfo.VariantBaseGround.IsObsoleteVariant) variant++;
        //     else return;
        //     for (int i = 0; i < int(BlockInfo.AdditionalVariantsGround.Length) - 1; i++) {
        //         if (BlockInfo.AdditionalVariantsGround[i].IsObsoleteVariant) variant++;
        //         else return;
        //     }
        // }

        mat4 GetTransform() {
            return mat4::Translate(pos) * EulerToMat_Shared(pyr);
        }

        ItemSpec@ ToItemSpec(CGameItemModel@ itemModel, vec3 &in pivotPos = vec3(0), uint16 variantIx = 0) {
            throw("implemented elsewhere");
            return null;
        }

        // call this to ensure the variant is valid. If it can't be found, different parameters will be tried. If not found, first set variant to 0. if still not found, swap isGround. otherwise return false.
        bool EnsureValidVariant() {
            throw("implemented elsewhere");
            return true;
        }
    }

    shared class WaypointSpec : NetworkSerializable {
        string tag;
        uint order;

        WaypointSpec(CGameWaypointSpecialProperty@ waypoint) {
            tag = waypoint.Tag;
            order = waypoint.Order;
        }

        WaypointSpec(const string &in tag, uint order) {
            this.tag = tag;
            this.order = order;
        }

        WaypointSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        void WriteToNetworkBufferInternal(MemoryBuffer@ buf) override {
            WriteLPStringToBuffer(buf, tag);
            buf.Write(order);
        }

        uint CalcSize() override {
            return 2 + tag.Length + 4;
        }

        NetworkSerializable@ ReadFromNetworkBuffer(MemoryBuffer@ buf) override {
            tag = ReadLPStringFromBuffer(buf);
            order = buf.ReadUInt32();
            return this;
        }

        bool opEquals(const WaypointSpec@ other) const {
            return tag == other.tag && order == other.order;
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

        bool opEquals(const SkinSpec@ other) const {
            return blockIx == other.blockIx;
            // todo: compare skins
        }
    }

    shared class SetSkinSpec : NetworkSerializable {
        string fgSkin;
        string bgSkin;
        BlockSpec@ block;
        ItemSpec@ item;

        SetSkinSpec() {}

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

        SetSkinSpec(ItemSpec@ item, const string &in fgSkin, const string &in bgSkin) {
            @this.item = item;
            this.fgSkin = fgSkin;
            this.bgSkin = bgSkin;
        }

        SetSkinSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
        }

        bool opEquals(const SetSkinSpec@ other) const {
            if (block !is null) {
                return block.opEquals(other.block)
                    && fgSkin == other.fgSkin
                    && bgSkin == other.bgSkin;
            } else {
                // item !is null
                return item.opEquals(other.item)
                    && fgSkin == other.fgSkin
                    && bgSkin == other.bgSkin;
            }
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
            // throw("implemented elsewhere"); // atm it is the same in the Priv class
            fgSkin = ReadLPStringFromBuffer(buf);
            bgSkin = ReadLPStringFromBuffer(buf);
            @block = cast<BlockSpec>(ReadNullableStructFromBuffer(buf, BlockSpec()));
            @item = cast<ItemSpec>(ReadNullableStructFromBuffer(buf, ItemSpec()));
            return this;
        }
    }

    // use Editor::MakeItemSpec instead
    shared class ItemSpec : NetworkSerializable {
        string name;
        // 26=stadium; 25=stadium256
        uint collection = 26;
        string author;
        nat3 coord;
        CGameCtnAnchoredObject::ECardinalDirections dir;
        vec3 pos;
        vec3 pyr;
        float scale = 1.0;
        CGameCtnAnchoredObject::EMapElemColor color;
        CGameCtnAnchoredObject::EMapElemLightmapQuality lmQual;
        CGameCtnAnchoredObject::EPhaseOffset phase;
        // note: always identity
        mat3 visualRot = mat3::Identity();
        vec3 pivotPos;
        uint8 isFlying;
        uint16 variantIx;
        uint associatedBlockIx;
        uint itemGroupOnBlock;
        // ? refcounted
        WaypointSpec@ waypoint;
        // bg & fg skin
        SetSkinSpec@ skin;
        // model -- set in ItemSpecPriv
        CGameItemModel@ Model;

        ItemSpec() {}

        ItemSpec(MemoryBuffer@ buf) {
            ReadFromNetworkBuffer(buf);
            if (collection != 26) {
                throw("Warning: item collection is not stadium");
            }
        }

        bool MatchesItem(CGameCtnAnchoredObject@ item) const {
            throw("overridden elsewhere");
            return false;
        }

        bool MatchesItem(CGameCtnEditorScriptAnchoredObject@ item) const {
            throw("overridden elsewhere");
            return false;
        }

        bool opEquals(const ItemSpec@ other) const {
            throw("overridden elsewehre");
            return false;
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
            size += 12; // pos
            size += 12; // pyr
            size += 4; // scale
            size += 1; // color
            size += 1; // lmQual
            size += 1; // phase
            size += 36; // visualRot
            size += 12; // pivotPos
            size += 1; // isFlying
            size += 2; // variantIx
            size += 4; // associatedBlockIx
            size += 4; // itemGroupOnBlock
            size += 1; // waypoint present
            if (waypoint !is null) {
                size += waypoint.CalcSize();
            }
            // always null atm
            // if (bgSkin !is null) {
            //     size += bgSkin.CalcSize();
            // }
            // if (fgSkin !is null) {
            //     size += fgSkin.CalcSize();
            // }
            return size;
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
            // leave skins null
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
            // ignore skins don't write them
            return this;
        }

        mat4 GetTransform() {
            return mat4::Translate(pos) * EulerToMat_Shared(pyr);
        }

        BlockSpec@ ToBlockSpec(CGameCtnBlockInfo@ model, uint blockVariant = 0, bool isGround = false) {
            throw("implemented elsewhere");
            return null;
        }
    }

    // todo:
    // to add for override:

    // ItemSpec:
    // void SetModel(CGameItemModel@ _model)
    // void TranslateCoords(int3 coordDist)
    // ItemSpec@ SetCoordAndFlying()
    // ItemSpec@ Duplicate()

    // MacroblockSpec:
    // MacroblockSpec@ Duplicate()
    // int3 GetMinBlockCoords()
    // int3 GetMaxBlockCoords()
    // nat3 GetCoordSize()
    // bool HasGround()
    // void SetAllBlocksFree()
    // void SetAllItemsFlying()
    // void MoveAllToOrigin()
    // void UndoMacroblockHeightOffset()
    // void AlignAll(Editor::AlignWithinBlock)


}
