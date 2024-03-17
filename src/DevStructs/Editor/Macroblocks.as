/// ! This file is generated from ../../../codegen/Editor/Macroblocks.xtoml !
/// ! Do not edit this file manually !

class DGameCtnMacroBlockInfo_Block : RawBufferElem {
	DGameCtnMacroBlockInfo_Block(RawBufferElem@ el) {
		if (el.ElSize != SZ_MACROBLOCK_BLOCKSBUFEL) throw("invalid size for DGameCtnMacroBlockInfo_Block");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnMacroBlockInfo_Block(uint64 ptr) {
		super(ptr, SZ_MACROBLOCK_BLOCKSBUFEL);
	}

	string get_name() { return (this.GetMwIdValue(0)); }
	void set_name(const string &in value) { this.SetMwIdValue(0, value); }
	uint get_nameId() { return (this.GetUint32(0)); }
	void set_nameId(uint value) { this.SetUint32(0, value); }
	uint get_collection() { return (this.GetUint32(4)); }
	void set_collection(uint value) { this.SetUint32(4, value); }
	string get_author() { return (this.GetMwIdValue(8)); }
	void set_author(const string &in value) { this.SetMwIdValue(8, value); }
	uint get_authorId() { return (this.GetUint32(8)); }
	void set_authorId(uint value) { this.SetUint32(8, value); }
	nat3 get_coord() { return (this.GetNat3(0xC)); }
	void set_coord(nat3 value) { this.SetNat3(0xC, value); }
	CGameCtnBlock::ECardinalDirections get_dir2() { return CGameCtnBlock::ECardinalDirections(this.GetUint32(0x18)); }
	void set_dir2(CGameCtnBlock::ECardinalDirections value) { this.SetUint32(0x18, value); }
	CGameCtnBlock::ECardinalDirections get_dir() { return CGameCtnBlock::ECardinalDirections(this.GetUint32(0x58)); }
	void set_dir(CGameCtnBlock::ECardinalDirections value) { this.SetUint32(0x58, value); }
	vec3 get_pos() { return (this.GetVec3(0x1C)); }
	void set_pos(vec3 value) { this.SetVec3(0x1C, value); }
	vec3 get_pyr() { return (this.GetVec3(0x28)); }
	void set_pyr(vec3 value) { this.SetVec3(0x28, value); }
	CGameCtnBlock::EMapElemColor get_color() { return CGameCtnBlock::EMapElemColor(this.GetUint8(0x34)); }
	void set_color(CGameCtnBlock::EMapElemColor value) { this.SetUint8(0x34, value); }
	CGameCtnBlock::EMapElemLightmapQuality get_lmQual() { return CGameCtnBlock::EMapElemLightmapQuality(this.GetUint8(0x35)); }
	void set_lmQual(CGameCtnBlock::EMapElemLightmapQuality value) { this.SetUint8(0x35, value); }
	uint get_mobilIndex() { return (this.GetUint32(0x38)); }
	void set_mobilIndex(uint value) { this.SetUint32(0x38, value); }
	uint get_mobilVariant() { return (this.GetUint32(0x3C)); }
	void set_mobilVariant(uint value) { this.SetUint32(0x3C, value); }
	uint get_variant() { return (this.GetUint32(0x40)); }
	void set_variant(uint value) { this.SetUint32(0x40, value); }
	uint8 get_flags() { return (this.GetUint8(0x44)); }
	void set_flags(uint8 value) { this.SetUint8(0x44, value); }
	bool get_isGround() { return flags & 1 == 1; }
	void set_isGround(bool value) { flags = value ? flags | 1 : flags & (0xFF ^ 1); }
	bool get_isNorm() { return flags < 2; }
	void makeNorm() { flags = flags & (0xFF ^ 6); }
	bool get_isGhost() { return flags & 2 == 2; }
	void set_isGhost(bool value) { flags = value ? flags | 2 : flags & (0xFF ^ 2); }
	bool get_isFree() { return flags & 4 == 4; }
	void set_isFree(bool value) { flags = value ? flags | 4 : flags & (0xFF ^ 4); }
	CGameWaypointSpecialProperty@ get_Waypoint() { return cast<CGameWaypointSpecialProperty>(this.GetNod(0x48)); }
	void set_Waypoint(CGameWaypointSpecialProperty@ value) { this.SetNod(0x48, value); }
	CGameCtnBlockInfoClassic@ get_BlockInfo() { return cast<CGameCtnBlockInfoClassic>(this.GetNod(0x50)); }
	void set_BlockInfo(CGameCtnBlockInfoClassic@ value) { this.SetNod(0x50, value); }
}


// 58 moved into based on free?
class DGameCtnMacroBlockInfo : RawBufferElem {
	DGameCtnMacroBlockInfo(RawBufferElem@ el) {
		if (el.ElSize != SZ_CTNMACROBLOCK) throw("invalid size for DGameCtnMacroBlockInfo");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnMacroBlockInfo(uint64 ptr) {
		super(ptr, SZ_CTNMACROBLOCK);
	}
	DGameCtnMacroBlockInfo(CGameCtnMacroBlockInfo@ nod) {
		if (nod is null) throw("not a CGameCtnMacroBlockInfo");
		super(Dev_GetPointerForNod(nod), SZ_CTNMACROBLOCK);
	}
	CGameCtnMacroBlockInfo@ get_Nod() {
		return cast<CGameCtnMacroBlockInfo>(Dev_GetNodFromPointer(ptr));
	}

	// offset: 0x150
	DGameCtnMacroBlockInfo_Blocks@ get_Blocks() { return DGameCtnMacroBlockInfo_Blocks(this.GetBuffer(O_MACROBLOCK_BLOCKSBUF, SZ_MACROBLOCK_BLOCKSBUFEL, true)); }
	DGameCtnMacroBlockInfo_Skins@ get_Skins() { return DGameCtnMacroBlockInfo_Skins(this.GetBuffer(O_MACROBLOCK_SKINSBUF, SZ_MACROBLOCK_SKINSBUFEL, true)); }
	// 
	DGameCtnMacroBlockInfo_Items@ get_Items() { return DGameCtnMacroBlockInfo_Items(this.GetBuffer(O_MACROBLOCK_ITEMSBUF, SZ_MACROBLOCK_ITEMSBUFEL, true)); }
}

class DGameCtnMacroBlockInfo_Blocks : RawBuffer {
	DGameCtnMacroBlockInfo_Blocks(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DGameCtnMacroBlockInfo_Block@ GetBlock(uint i) {
		return DGameCtnMacroBlockInfo_Block(this[i]);
	}
}


class DGameCtnMacroBlockInfo_Skins : RawBuffer {
	DGameCtnMacroBlockInfo_Skins(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DGameCtnMacroBlockInfo_Skin@ GetSkin(uint i) {
		return DGameCtnMacroBlockInfo_Skin(this[i]);
	}
}


class DGameCtnMacroBlockInfo_Items : RawBuffer {
	DGameCtnMacroBlockInfo_Items(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DGameCtnMacroBlockInfo_Item@ GetItem(uint i) {
		return DGameCtnMacroBlockInfo_Item(this[i]);
	}
}

class DGameCtnMacroBlockInfo_Skin : RawBufferElem {
	DGameCtnMacroBlockInfo_Skin(RawBufferElem@ el) {
		if (el.ElSize != SZ_MACROBLOCK_SKINSBUFEL) throw("invalid size for DGameCtnMacroBlockInfo_Skin");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnMacroBlockInfo_Skin(uint64 ptr) {
		super(ptr, SZ_MACROBLOCK_SKINSBUFEL);
	}

	CGameCtnBlockSkin@ get_Skin() { return cast<CGameCtnBlockSkin>(this.GetNod(0x0)); }
	void set_Skin(CGameCtnBlockSkin@ value) { this.SetNod(0x0, value); }
	// 0x8 to 0x14 appears unused (changes each time you press save MB when copy pasting)
	uint get_BlockIx() { return (this.GetUint32(0x14)); }
	void set_BlockIx(uint value) { this.SetUint32(0x14, value); }
}


class DGameCtnMacroBlockInfo_Item : RawBufferElem {
	DGameCtnMacroBlockInfo_Item(RawBufferElem@ el) {
		if (el.ElSize != SZ_MACROBLOCK_ITEMSBUFEL) throw("invalid size for DGameCtnMacroBlockInfo_Item");
		super(el.Ptr, el.ElSize);
	}
	DGameCtnMacroBlockInfo_Item(uint64 ptr) {
		super(ptr, SZ_MACROBLOCK_ITEMSBUFEL);
	}

	string get_name() { return (this.GetMwIdValue(0)); }
	void set_name(const string &in value) { this.SetMwIdValue(0, value); }
	uint get_nameId() { return (this.GetUint32(0)); }
	void set_nameId(uint value) { this.SetUint32(0, value); }
	uint get_collection() { return (this.GetUint32(4)); }
	void set_collection(uint value) { this.SetUint32(4, value); }
	string get_author() { return (this.GetMwIdValue(8)); }
	void set_author(const string &in value) { this.SetMwIdValue(8, value); }
	uint get_authorId() { return (this.GetUint32(8)); }
	void set_authorId(uint value) { this.SetUint32(8, value); }
	nat3 get_coord() { return (this.GetNat3(0xC)); }
	void set_coord(nat3 value) { this.SetNat3(0xC, value); }
	CGameCtnAnchoredObject::ECardinalDirections get_dir() { return CGameCtnAnchoredObject::ECardinalDirections(this.GetUint32(0x18)); }
	void set_dir(CGameCtnAnchoredObject::ECardinalDirections value) { this.SetUint32(0x18, value); }
	vec3 get_pos() { return (this.GetVec3(0x1C)); }
	void set_pos(vec3 value) { this.SetVec3(0x1C, value); }
	vec3 get_pyr() { return (this.GetVec3(0x28)); }
	void set_pyr(vec3 value) { this.SetVec3(0x28, value); }
	float get_scale() { return (this.GetFloat(0x34)); }
	void set_scale(float value) { this.SetFloat(0x34, value); }
	CGameCtnAnchoredObject::EMapElemColor get_color() { return CGameCtnAnchoredObject::EMapElemColor(this.GetUint8(0x34)); }
	void set_color(CGameCtnAnchoredObject::EMapElemColor value) { this.SetUint8(0x34, value); }
	CGameCtnAnchoredObject::EMapElemLightmapQuality get_lmQual() { return CGameCtnAnchoredObject::EMapElemLightmapQuality(this.GetUint8(0x35)); }
	void set_lmQual(CGameCtnAnchoredObject::EMapElemLightmapQuality value) { this.SetUint8(0x35, value); }
	CGameCtnAnchoredObject::EPhaseOffset get_phase() { return CGameCtnAnchoredObject::EPhaseOffset(this.GetUint8(0x36)); }
	void set_phase(CGameCtnAnchoredObject::EPhaseOffset value) { this.SetUint8(0x36, value); }
	mat3 get_visualRot() { return (this.GetMat3(0x54)); }
	vec3 get_pivotPos() { return (this.GetVec3(0x78)); }
	void set_pivotPos(vec3 value) { this.SetVec3(0x78, value); }
	bool get_isFlying() { return this.GetUint8(0x84) & 1 == 1; }
	void set_isFlying(bool value) { this.SetUint8(0x84, (variantIx << 1) + (value ? 1 : 0)); }
	uint16 get_variantIx() { return this.GetUint16(0x84) >> 1; }
	void set_variantIx(uint16 value) { this.SetUint8(0x84, (value << 1) + (isFlying ? 1 : 0)); }
	CGameWaypointSpecialProperty@ get_Waypoint() { return cast<CGameWaypointSpecialProperty>(this.GetNod(0x88)); }
	void set_Waypoint(CGameWaypointSpecialProperty@ value) { this.SetNod(0x88, value); }
	uint get_associatedBlockIx() { return (this.GetUint32(0x90)); }
	void set_associatedBlockIx(uint value) { this.SetUint32(0x90, value); }
	// FFFFFFFF
	uint get_unk94() { return (this.GetUint32(0x94)); }
	void set_unk94(uint value) { this.SetUint32(0x94, value); }
	uint get_itemGroupOnBlock() { return (this.GetUint32(0x98)); }
	void set_itemGroupOnBlock(uint value) { this.SetUint32(0x98, value); }
	// FFFFFFFF
	uint get_unk9C() { return (this.GetUint32(0x9C)); }
	void set_unk9C(uint value) { this.SetUint32(0x9C, value); }
	CSystemPackDesc@ get_BGSkin() { return cast<CSystemPackDesc>(this.GetNod(0xA0)); }
	void set_BGSkin(CSystemPackDesc@ value) { this.SetNod(0xA0, value); }
	CSystemPackDesc@ get_FGSkin() { return cast<CSystemPackDesc>(this.GetNod(0xA8)); }
	void set_FGSkin(CSystemPackDesc@ value) { this.SetNod(0xA8, value); }
	CGameItemModel@ get_Model() { return cast<CGameItemModel>(this.GetNod(0xB0)); }
	void set_Model(CGameItemModel@ value) { this.SetNod(0xB0, value); }
}


