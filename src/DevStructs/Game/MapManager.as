/// ! This file is generated from ../../../codegen/Game/MapManager.xtoml !
/// ! Do not edit this file manually !

class DGameMgrMap_SMgr : RawBufferElem {
	DGameMgrMap_SMgr(RawBufferElem@ el) {
		if (el.ElSize != 0x370) throw("invalid size for DGameMgrMap_SMgr");
		super(el.Ptr, el.ElSize);
	}
	DGameMgrMap_SMgr(uint64 ptr) {
		super(ptr, 0x370);
	}

	// mwnod pool at 0x140
	DMgrMap_SMgr_ObjStruct@ get_ObjStruct() { return DMgrMap_SMgr_ObjStruct(this.GetUint64(0x90)); }
}


class DMgrMap_SMgr_ObjStruct : RawBufferElem {
	DMgrMap_SMgr_ObjStruct(RawBufferElem@ el) {
		if (el.ElSize != 0x50) throw("invalid size for DMgrMap_SMgr_ObjStruct");
		super(el.Ptr, el.ElSize);
	}
	DMgrMap_SMgr_ObjStruct(uint64 ptr) {
		super(ptr, 0x50);
	}

	// size of this struct unknown
	uint64 get_u01_zero() { return (this.GetUint64(0x0)); }
	CGameCtnChallenge@ get_Challenge() { return cast<CGameCtnChallenge>(this.GetNod(0x8)); }
	uint32 get_cumulativeAddedOrRemoved() { return (this.GetUint32(0x10)); }
	// zero at 0x14
	// 1, 1
	DMgrMap_MapObjects@ get_MapObjects() { return DMgrMap_MapObjects(this.GetBuffer(0x40, 0x278, true)); }
}

class DMgrMap_MapObjects : RawBuffer {
	DMgrMap_MapObjects(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DMgrMap_MapObject@ GetMapObject(uint i) {
		return DMgrMap_MapObject(this[i]);
	}
}

class DMgrMap_MapObject : RawBufferElem {
	DMgrMap_MapObject(RawBufferElem@ el) {
		if (el.ElSize != 0x278) throw("invalid size for DMgrMap_MapObject");
		super(el.Ptr, el.ElSize);
	}
	DMgrMap_MapObject(uint64 ptr) {
		super(ptr, 0x278);
	}

	uint32 get_ix() { return (this.GetUint32(0x0)); }
	// FFFFFFFF
	uint32 get_u1() { return (this.GetUint32(0x4)); }
	uint32 get_ix2() { return (this.GetUint32(0x8)); }
	// 0
	uint32 get_u2() { return (this.GetUint32(0xC)); }
	CGameCtnBlockInfo@ get_BlockInfo() { return cast<CGameCtnBlockInfo>(this.GetNod(0x10)); }
	CGameCtnBlockInfoVariant@ get_BlockInfoVariant() { return cast<CGameCtnBlockInfoVariant>(this.GetNod(0x18)); }
	CGameCtnBlock@ get_Block() { return cast<CGameCtnBlock>(this.GetNod(0x20)); }
}

