/// ! This file is generated from ../../../codegen/Plug/CPlugGameSkin.xtoml !
/// ! Do not edit this file manually !

class DPlugGameSkin : RawBufferElem {
	DPlugGameSkin(RawBufferElem@ el) {
		if (el.ElSize != SZ_GAMESKIN) throw("invalid size for DPlugGameSkin");
		super(el.Ptr, el.ElSize);
	}
	DPlugGameSkin(uint64 ptr) {
		super(ptr, SZ_GAMESKIN);
	}
	DPlugGameSkin(CPlugGameSkin@ nod) {
		if (nod is null) throw("not a CPlugGameSkin");
		super(Dev_GetPointerForNod(nod), SZ_GAMESKIN);
	}
	CPlugGameSkin@ get_Nod() {
		return cast<CPlugGameSkin>(Dev_GetNodFromPointer(ptr));
	}

	string get_Path1() { return (this.GetString(O_GAMESKIN_PATH1)); }
	void set_Path1(const string &in value) { this.SetString(O_GAMESKIN_PATH1, value); }
	string get_Path2() { return (this.GetString(O_GAMESKIN_PATH2)); }
	void set_Path2(const string &in value) { this.SetString(O_GAMESKIN_PATH2, value); }
	// Buffer: UnkBuf = DUints, O_GAMESKIN_UNK_BUF, 0x4, false
	string get_Path3() { return (this.GetString(O_GAMESKIN_PATH3)); }
	void set_Path3(const string &in value) { this.SetString(O_GAMESKIN_PATH3, value); }
	DSystemFidFiles@ get_Fids() { return DSystemFidFiles(this.GetBuffer(O_GAMESKIN_FID_BUF, SZ_FID_FILE, true)); }
	DStrings@ get_Filenames() { return DStrings(this.GetBuffer(O_GAMESKIN_FILENAME_BUF, 0x10, false)); }
	DUints@ get_ClassIds() { return DUints(this.GetBuffer(O_GAMESKIN_FID_CLASSID_BUF, 0x4, false)); }
}

class DSystemFidFiles : RawBuffer {
	DSystemFidFiles(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DSystemFidFile@ GetDSystemFidFile(uint i) {
		return DSystemFidFile(this[i]);
	}
}


class DStrings : RawBuffer {
	DStrings(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DString@ GetDString(uint i) {
		return DString(this[i]);
	}
}


class DUints : RawBuffer {
	DUints(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	DUint@ GetDUint(uint i) {
		return DUint(this[i]);
	}
}

class DString : RawBufferElem {
	DString(RawBufferElem@ el) {
		if (el.ElSize != 0x10) throw("invalid size for DString");
		super(el.Ptr, el.ElSize);
	}
	DString(uint64 ptr) {
		super(ptr, 0x10);
	}

	string get_Value() { return (this.GetString(0x0)); }
	void set_Value(const string &in value) { this.SetString(0x0, value); }
	uint32 get_Length() { return (this.GetUint32(0xC)); }
	bool get_NotNull() { return this.GetUint8(0xB) != 0; }
}


class DUint : RawBufferElem {
	DUint(RawBufferElem@ el) {
		if (el.ElSize != 0x4) throw("invalid size for DUint");
		super(el.Ptr, el.ElSize);
	}
	DUint(uint64 ptr) {
		super(ptr, 0x4);
	}

	uint get_Value() { return (this.GetUint32(0x0)); }
	void set_Value(uint value) { this.SetUint32(0x0, value); }
}


