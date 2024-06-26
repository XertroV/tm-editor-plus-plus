/// ! This file is generated from ../../../codegen/Editor/CPlugStatic2Model.xtoml !
/// ! Do not edit this file manually !

class DPlugSolid2Model : RawBufferElem {
	DPlugSolid2Model(RawBufferElem@ el) {
		if (el.ElSize != SZ_SOLID2MODEL) throw("invalid size for DPlugSolid2Model");
		super(el.Ptr, el.ElSize);
	}
	DPlugSolid2Model(uint64 ptr) {
		super(ptr, SZ_SOLID2MODEL);
	}
	DPlugSolid2Model(CPlugSolid2Model@ nod) {
		if (nod is null) throw("not a CPlugSolid2Model");
		super(Dev_GetPointerForNod(nod), SZ_SOLID2MODEL);
	}
	CPlugSolid2Model@ get_Nod() {
		return cast<CPlugSolid2Model>(Dev_GetNodFromPointer(ptr));
	}

	DPlugSolid2ModelPreLightGenerator@ get_PreLightGenerator() { return DPlugSolid2ModelPreLightGenerator(this.GetUint64(0x298)); }
}


class DPlugSolid2ModelPreLightGenerator : RawBufferElem {
	DPlugSolid2ModelPreLightGenerator(RawBufferElem@ el) {
		if (el.ElSize != 0x24) throw("invalid size for DPlugSolid2ModelPreLightGenerator");
		super(el.Ptr, el.ElSize);
	}
	DPlugSolid2ModelPreLightGenerator(uint64 ptr) {
		super(ptr, 0x24);
	}

	float get_LMSideLengthMeters() { return (this.GetFloat(0x0)); }
	void set_LMSideLengthMeters(float value) { this.SetFloat(0x0, value); }
	float get_u03() { return (this.GetFloat(0x4)); }
	void set_u03(float value) { this.SetFloat(0x4, value); }
	float get_u04() { return (this.GetFloat(0x8)); }
	void set_u04(float value) { this.SetFloat(0x8, value); }
	float get_u05() { return (this.GetFloat(0xC)); }
	void set_u05(float value) { this.SetFloat(0xC, value); }
	float get_u06() { return (this.GetFloat(0x10)); }
	void set_u06(float value) { this.SetFloat(0x10, value); }
	float get_u07() { return (this.GetFloat(0x14)); }
	void set_u07(float value) { this.SetFloat(0x14, value); }
	float get_u08() { return (this.GetFloat(0x18)); }
	void set_u08(float value) { this.SetFloat(0x18, value); }
	float get_u09() { return (this.GetFloat(0x1C)); }
	void set_u09(float value) { this.SetFloat(0x1C, value); }
	float get_u10() { return (this.GetFloat(0x20)); }
	void set_u10(float value) { this.SetFloat(0x20, value); }
}


