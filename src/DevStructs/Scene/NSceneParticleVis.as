/// ! This file is generated from ../../../codegen/Scene/NSceneParticleVis.xtoml !
/// ! Do not edit this file manually !

// const uint16 SZ_NSceneParticleVis_SMgr = 0x2E0;
class D_NSceneParticleVis_SMgr : RawBufferElem {
	D_NSceneParticleVis_SMgr(RawBufferElem@ el) {
		if (el.ElSize != 0x2E0) throw("invalid size for D_NSceneParticleVis_SMgr");
		super(el.Ptr, el.ElSize);
	}
	D_NSceneParticleVis_SMgr(uint64 ptr) {
		super(ptr, 0x2E0);
	}

	// GameScene = ISceneVis, 0x0, G
	uint64 get_GameScene() { return (this.GetUint64(0)); }
	CHmsZone@ get_Zone() { return cast<CHmsZone>(this.GetNod(0x8)); }
	// cannot cast to this
	// SoundMgr = NSceneSound_SMgr, 0x10, G
	uint64 get_SoundMgrPtr() { return (this.GetUint64(0x10)); }
	uint64 get_Unk1() { return (this.GetUint64(0x18)); }
	CHmsMgrVisDynaDecal2d@ get_mgrVisDynaDecal2d() { return cast<CHmsMgrVisDynaDecal2d>(this.GetNod(0x20)); }
	// has some refrences to Clouds_v.hlsli and common shaders
	uint64 get_Unk2() { return (this.GetUint64(0x28)); }
	CHmsMgrVisDyna@ get_mgrVisDyna() { return cast<CHmsMgrVisDyna>(this.GetNod(0x30)); }
	uint32 get_timer() { return (this.GetUint32(0x3C)); }
	// EmitterStructs are sorted backwards
	// Buffer: EmitterStructs = X, 0x40, 0x160, true
	// pointer to first element of EmitterStructs? (earliest pointer in memory of above, which are backwards)
	uint64 get_Unk3() { return (this.GetUint64(0x50)); }
	NSceneParticleVis_ActiveEmitters@ get_ActiveEmitters() { return NSceneParticleVis_ActiveEmitters(this.GetBuffer(0x118, 0xE8, true)); }
}

class NSceneParticleVis_ActiveEmitters : RawBuffer {
	NSceneParticleVis_ActiveEmitters(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	NSceneParticleVis_ActiveEmitter@ GetActiveEmitter(uint i) {
		return NSceneParticleVis_ActiveEmitter(this[i]);
	}
}

// const uint16 SZ_NSceneParticleVis_ActiveEmitter = 0xE8;
class NSceneParticleVis_ActiveEmitter : RawBufferElem {
	NSceneParticleVis_ActiveEmitter(RawBufferElem@ el) {
		if (el.ElSize != 0xE8) throw("invalid size for NSceneParticleVis_ActiveEmitter");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_ActiveEmitter(uint64 ptr) {
		super(ptr, 0xE8);
	}

	CPlugParticleEmitterSubModel@ get_EmitterSubModel() { return cast<CPlugParticleEmitterSubModel>(this.GetNod(0x0)); }
	// switch in this order: 0 = Visual_Sprite, 1 = Visual_Beam, 2 = Visual_Triangle, 3 = Visual_Quad, 4 = Visual_Mesh, 5 = Visual_Mark, 6 = RingTrail, 7 = ?, 8 = RingChain, default: return, 13 (0xD) =?
	uint32 get_emitterType() { return (this.GetUint32(0x8)); }
	void set_emitterType(uint32 value) { this.SetUint32(0x8, value); }
	// only set when emitterType == 0 and == currIndex
	uint32 get_indexWhenType0() { return (this.GetUint32(0xC)); }
	void set_indexWhenType0(uint32 value) { this.SetUint32(0xC, value); }
	// use by all active emitters
	uint32 get_currIndex() { return (this.GetUint32(0x10)); }
	void set_currIndex(uint32 value) { this.SetUint32(0x10, value); }
	uint32 get_capacity() { return (this.GetUint32(0x14)); }
	void set_capacity(uint32 value) { this.SetUint32(0x14, value); }
	uint32 get_u1() { return (this.GetUint32(0x18)); }
	void set_u1(uint32 value) { this.SetUint32(0x18, value); }
	uint32 get_limit() { return (this.GetUint32(0x1C)); }
	void set_limit(uint32 value) { this.SetUint32(0x1C, value); }
	// Buffer: SkidsPoints = NSceneParticleVis_ActiveEmitter_Points, 0x48, 0x58, false
	// This is valid for skids (type 5 = VisualMark)
	NSceneParticleVis_ActiveEmitter_PointsStruct@ get_PointsStruct() { auto _ptr = this.GetUint64(0x48); if (_ptr == 0) return null; return NSceneParticleVis_ActiveEmitter_PointsStruct(_ptr); }
	// this is valid for LightTrail (type 6 = RingTrail)
	NSceneParticleVis_ActiveEmitter_Points2Struct@ get_LightRingPoints() { auto _ptr = this.GetUint64(0x50); if (_ptr == 0) return null; return NSceneParticleVis_ActiveEmitter_Points2Struct(_ptr); }
	CPlugVisualIndexedTriangles@ get_Triangles1() { return cast<CPlugVisualIndexedTriangles>(this.GetNod(0x78)); }
	CPlugVisualIndexedTriangles@ get_Triangles2() { return cast<CPlugVisualIndexedTriangles>(this.GetNod(0x80)); }
	CPlugShaderApply@ get_Shader() { return cast<CPlugShaderApply>(this.GetNod(0x88)); }
	// something at 0x90, a pointer, not sure to what. Mb a struct with a buffer at 0x18
	uint64 get_UnkPtr0x90() { return (this.GetUint64(0x90)); }
	// 0x98: FFFFFFFF
	uint32 get_Unk98() { return (this.GetUint32(0x98)); }
	// set by game each frame
	uint32 get_GameTimeOfLastPoint() { return (this.GetUint32(0x9C)); }
	void set_GameTimeOfLastPoint(uint32 value) { this.SetUint32(0x9C, value); }
	// 0xA8: FFFFFFFFFFFFFFFF
	uint64 get_UnkA8() { return (this.GetUint64(0xA8)); }
	// Source structs, note they're reverse order in memory
	NSceneParticleVis_ActiveEmitter_Sources@ get_WheelsStruct() { auto _ptr = this.GetUint64(0xB0); if (_ptr == 0) return null; return NSceneParticleVis_ActiveEmitter_Sources(_ptr); }
	// 5
	uint32 get_UnkB8() { return (this.GetUint32(0xB8)); }
	// random bytes? updated each frame, LSB always ends in 0 tho
	uint32 get_UnkBC() { return (this.GetUint32(0xBC)); }
	// 23.2839, 2.89831, not accessed each frame and changing it doesn't seem to do anything
	vec2 get_UnkC0() { return (this.GetVec2(0xC0)); }
	// 4 uints of 0
	uint32 get_UnkC8() { return (this.GetUint32(0xC8)); }
	uint32 get_UnkCC() { return (this.GetUint32(0xCC)); }
	uint32 get_UnkD0() { return (this.GetUint32(0xD0)); }
	uint32 get_UnkD4() { return (this.GetUint32(0xD4)); }
	// 0x21, 0.137745, not accessed each frame
	uint get_UnkD8() { return (this.GetUint32(0xD8)); }
	float get_UnkDC() { return (this.GetFloat(0xDC)); }
}


// when entityType == 6
class NSceneParticleVis_ActiveEmitter_Points2Struct : RawBufferElem {
	NSceneParticleVis_ActiveEmitter_Points2Struct(RawBufferElem@ el) {
		if (el.ElSize != 0x10) throw("invalid size for NSceneParticleVis_ActiveEmitter_Points2Struct");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_ActiveEmitter_Points2Struct(uint64 ptr) {
		super(ptr, 0x10);
	}

	// Length = uint32, 0x8, G
	// Capacity = uint32, 0xC, G
	// Buffer: Inner = NSceneParticleVis_ActiveEmitter_Points2InnerStruct, 0x0, G
	NSceneParticleVis_ActiveEmitter_TrailPoints@ get_TrailPoints() { return NSceneParticleVis_ActiveEmitter_TrailPoints(this.GetBuffer(0x0, 0x78, false)); }
}

class NSceneParticleVis_ActiveEmitter_TrailPoints : RawBuffer {
	NSceneParticleVis_ActiveEmitter_TrailPoints(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	NSceneParticleVis_ActiveEmitter_TrailPoint@ GetTrailPoint(uint i) {
		return NSceneParticleVis_ActiveEmitter_TrailPoint(this[i]);
	}
}

// [NSceneParticleVis_ActiveEmitter_Points2InnerStruct: 0x10]
// Buffer: TrailPoints = NSceneParticleVis_ActiveEmitter_TrailPoints, 0x0, 0x78, false
// when entityType == 5
class NSceneParticleVis_ActiveEmitter_PointsStruct : RawBufferElem {
	NSceneParticleVis_ActiveEmitter_PointsStruct(RawBufferElem@ el) {
		if (el.ElSize != 0x10) throw("invalid size for NSceneParticleVis_ActiveEmitter_PointsStruct");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_ActiveEmitter_PointsStruct(uint64 ptr) {
		super(ptr, 0x10);
	}

	NSceneParticleVis_ActiveEmitter_Points@ get_SkidsPoints() { return NSceneParticleVis_ActiveEmitter_Points(this.GetBuffer(0x0, 0x58, false)); }
}

class NSceneParticleVis_ActiveEmitter_Points : RawBuffer {
	NSceneParticleVis_ActiveEmitter_Points(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	NSceneParticleVis_ActiveEmitter_Point@ GetPoint(uint i) {
		return NSceneParticleVis_ActiveEmitter_Point(this[i]);
	}
}

class NSceneParticleVis_ActiveEmitter_Point : RawBufferElem {
	NSceneParticleVis_ActiveEmitter_Point(RawBufferElem@ el) {
		if (el.ElSize != 0x58) throw("invalid size for NSceneParticleVis_ActiveEmitter_Point");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_ActiveEmitter_Point(uint64 ptr) {
		super(ptr, 0x58);
	}

	vec3 get_Pos() { return (this.GetVec3(0x0)); }
	void set_Pos(vec3 value) { this.SetVec3(0x0, value); }
	// crash on change
	uint get_NextIdMb() { return (this.GetUint32(0xC)); }
	// crash on change
	uint get_PrevIdMb() { return (this.GetUint32(0x10)); }
	uint16 InvisibleOffset = 0x14;
	bool get_Invisible() { return (this.GetBool(0x14)); }
	void set_Invisible(bool value) { this.SetBool(0x14, value); }
}


class NSceneParticleVis_ActiveEmitter_Sources : RawBufferElem {
	NSceneParticleVis_ActiveEmitter_Sources(RawBufferElem@ el) {
		if (el.ElSize != 0x10) throw("invalid size for NSceneParticleVis_ActiveEmitter_Sources");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_ActiveEmitter_Sources(uint64 ptr) {
		super(ptr, 0x10);
	}

	NSceneParticleVis_ActiveEmitter_Sources_Els@ get_Sources() { return NSceneParticleVis_ActiveEmitter_Sources_Els(this.GetBuffer(0x0, 0x48, true)); }
}

class NSceneParticleVis_ActiveEmitter_Sources_Els : RawBuffer {
	NSceneParticleVis_ActiveEmitter_Sources_Els(RawBuffer@ buf) {
		super(buf.Ptr, buf.ElSize, buf.StructBehindPtr);
	}
	NSceneParticleVis_ActiveEmitter_Sources_El@ GetEl(uint i) {
		return NSceneParticleVis_ActiveEmitter_Sources_El(this[i]);
	}
}

class NSceneParticleVis_ActiveEmitter_Sources_El : RawBufferElem {
	NSceneParticleVis_ActiveEmitter_Sources_El(RawBufferElem@ el) {
		if (el.ElSize != 0x48) throw("invalid size for NSceneParticleVis_ActiveEmitter_Sources_El");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_ActiveEmitter_Sources_El(uint64 ptr) {
		super(ptr, 0x48);
	}

	// EmitterModel = todo
	// 
	NSceneParticleVis_ActiveEmitter@ get_ActiveEmitter() { auto _ptr = this.GetUint64(0x0); if (_ptr == 0) return null; return NSceneParticleVis_ActiveEmitter(_ptr); }
	NSceneParticleVis_EmitterSource@ get_EmitterSource() { auto _ptr = this.GetUint64(0x8); if (_ptr == 0) return null; return NSceneParticleVis_EmitterSource(_ptr); }
	vec3 get_Pos() { return (this.GetVec3(0x10)); }
	void set_Pos(vec3 value) { this.SetVec3(0x10, value); }
	uint get_GameTime() { return (this.GetUint32(0x1C)); }
	void set_GameTime(uint value) { this.SetUint32(0x1C, value); }
	bool get_IsActive() { return (this.GetBool(0x20)); }
	void set_IsActive(bool value) { this.SetBool(0x20, value); }
	// Less than FFFFFFFF
	uint get_PointToUpdate() { return (this.GetUint32(0x24)); }
	void set_PointToUpdate(uint value) { this.SetUint32(0x24, value); }
	// 0x28 should be 0 to draw
	bool get_SkipDrawing() { return (this.GetBool(0x28)); }
	void set_SkipDrawing(bool value) { this.SetBool(0x28, value); }
}


class NSceneParticleVis_EmitterSource : RawBufferElem {
	NSceneParticleVis_EmitterSource(RawBufferElem@ el) {
		if (el.ElSize != 0x160) throw("invalid size for NSceneParticleVis_EmitterSource");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_EmitterSource(uint64 ptr) {
		super(ptr, 0x160);
	}

	CPlugParticleEmitterModel@ get_ParticleEmitterModel() { return cast<CPlugParticleEmitterModel>(this.GetNod(0x0)); }
	// Unsure of 0x8-0x28: FFFFFFFF, 0, FFFFFFBF, 0, vec4(0)
	// mat for the next point?
	iso4 get_Loc() { return (this.GetIso4(0x28)); }
	void set_Loc(iso4 value) { this.SetIso4(0x28, value); }
	// lots of unknown floats
	// Set to FFFFFFFF when light trail disabled
	uint get_GameTimeStarted() { return (this.GetUint32(0xD0)); }
	void set_GameTimeStarted(uint value) { this.SetUint32(0xD0, value); }
	// 0xD4: unused?
	// 0xD8: FFFFFFFF
	// pointer back to sources element
	NSceneParticleVis_ActiveEmitter_Sources_El@ get_SourceStruct() { auto _ptr = this.GetUint64(0xE8); if (_ptr == 0) return null; return NSceneParticleVis_ActiveEmitter_Sources_El(_ptr); }
	// 0xF0: unk, zeroed array?
	CHmsItem@ get_HmsItem() { return cast<CHmsItem>(this.GetNod(0x128)); }
	// 0x8 before the start of one of these structs
	uint64 get_LinkedNextPrevPtrMb() { return (this.GetUint64(0x158)); }
}


// 
class NSceneParticleVis_ActiveEmitter_TrailPoint : RawBufferElem {
	NSceneParticleVis_ActiveEmitter_TrailPoint(RawBufferElem@ el) {
		if (el.ElSize != 0x78) throw("invalid size for NSceneParticleVis_ActiveEmitter_TrailPoint");
		super(el.Ptr, el.ElSize);
	}
	NSceneParticleVis_ActiveEmitter_TrailPoint(uint64 ptr) {
		super(ptr, 0x78);
	}

	vec3 get_Pos() { return (this.GetVec3(0x0)); }
	void set_Pos(vec3 value) { this.SetVec3(0x0, value); }
	uint get_NextId() { return (this.GetUint32(0xC)); }
	void set_NextId(uint value) { this.SetUint32(0xC, value); }
	uint get_PrevId() { return (this.GetUint32(0x10)); }
	void set_PrevId(uint value) { this.SetUint32(0x10, value); }
	uint16 InvisibleOffset = 0x14;
	bool get_Invisible() { return (this.GetBool(0x14)); }
	void set_Invisible(bool value) { this.SetBool(0x14, value); }
	// -- a pointer when going backwards?! goes to the struct with a pointer to destination submodel and source submodel (the one with fid like LightTrail.ParticleModel.Gbx)
	// often null. i think this is mb this trail's source entry in the LightTrail equiv of wheel structs
	uint64 get_PtrToSourceStruct() { return (this.GetUint64(0x18)); }
	void set_PtrToSourceStruct(uint64 value) { this.SetUint64(0x18, value); }
	// set to 0.0 if PrevId == -1 (or float -NAN)
	float get_Unk3() { return (this.GetFloat(0x20)); }
	void set_Unk3(float value) { this.SetFloat(0x20, value); }
	// color? unknown? 43 bf 71 93, same for both 1st entries, tho
	uint get_Unk4() { return (this.GetUint32(0x24)); }
	void set_Unk4(uint value) { this.SetUint32(0x24, value); }
	// time set (no offset)
	uint get_GameTimeWhenSet() { return (this.GetUint32(0x28)); }
	void set_GameTimeWhenSet(uint value) { this.SetUint32(0x28, value); }
	// 20000 - time + 20000 (in mediatracker, it is 20k + timeline ms)
	uint get_GameTimeWhenSet_Plus20000() { return (this.GetUint32(0x2C)); }
	void set_GameTimeWhenSet_Plus20000(uint value) { this.SetUint32(0x2C, value); }
	// 0.09 -- start of 28 bytes of floats (7 total), could be a qaternion and vec3 (first 4 are normalized, and last 3 are normalized), vec3 looks like Dir
	// okay, neither quat nor dir. might be bounding boxes? the vec3 part seems to alter what gets drawn at what viewing angels
	// the first 4 floats can make the trail a lot bigger (dimensions, mb) -- not actually normalized, but close to. example value: vec4(0.09, -0.420252, 0.20176, 0.884693)
	vec4 get_Unk7() { return (this.GetVec4(0x30)); }
	void set_Unk7(vec4 value) { this.SetVec4(0x30, value); }
	// appears to be normalized, example: 0.444, 0.896, 0.007
	vec3 get_Unk11() { return (this.GetVec3(0x40)); }
	void set_Unk11(vec3 value) { this.SetVec3(0x40, value); }
	// 0 -- 0x4C to 0x60, all 0s
	// (if local, x = fwd, y = up, z = right)
	vec3 get_PosOffset() { return (this.GetVec3(0x4C)); }
	void set_PosOffset(vec3 value) { this.SetVec3(0x4C, value); }
	vec3 get_MinorPosOffset() { return (this.GetVec3(0x58)); }
	void set_MinorPosOffset(vec3 value) { this.SetVec3(0x58, value); }
	// 2.97; 0x67 byte always 40, but changing it to D0+ makes it disappear. setting to all 0s does nothing
	// float, seems like a damening effect on offsets, smoothing mb?
	float get_Unk21() { return (this.GetFloat(0x64)); }
	void set_Unk21(float value) { this.SetFloat(0x64, value); }
	uint16 ColorOffset = 0x68;
	vec4 get_Color() { return (this.GetVec4(0x68)); }
	void set_Color(vec4 value) { this.SetVec4(0x68, value); }
}


