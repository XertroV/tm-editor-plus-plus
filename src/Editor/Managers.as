
const uint16 GameSceneOffset = GetOffset("CGameCtnApp", "GameScene");
const uint16 O_ISceneVis_HackScene = GetOffset("ISceneVis", "HackScene");

ManagerDesc@ FindManager(uint wantedTypeId) {
	auto app = GetApp();
	if (app.GameScene is null) return null;
	auto mgrsListOff = O_ISceneVis_HackScene - 0x18;
	auto mgrs = FollowOffsets({GameSceneOffset, mgrsListOff});
    if (mgrs is null) return null;
	// auto mgrPtr = Dev::GetOffsetUint64(app.GameScene, mgrsListOff);
	auto mgrCount = Dev::GetOffsetUint32(app.GameScene, mgrsListOff + 0x8);
	for (uint i = 0; i < mgrCount; i++) {
		auto typeId = Dev::GetOffsetUint32(mgrs.nod, i * 0x18);
        if (typeId != wantedTypeId) continue;
		auto ptr = Dev::GetOffsetUint64(mgrs.nod, i * 0x18 + 0x8);
		auto mgrIx = Dev::GetOffsetUint32(mgrs.nod, i * 0x18 + 0x10);
        auto ty = Reflection::GetType(typeId);
        auto name = (ty is null ? "Unknown" : ty.Name) + " ("+Text::Format("%08x", typeId)+")";
        return ManagerDesc(name, typeId, ptr, mgrIx);
    }
    return null;
}

class ManagerDesc {
    string name;
    uint32 typeId;
    uint64 ptr;
    uint32 index;
    ManagerDesc(const string &in name, uint32 typeId, uint64 ptr, uint32 index) {
        this.name = name;
        this.typeId = typeId;
        this.ptr = ptr;
        this.index = index;
    }
}

NodWithPtr@ FollowOffsets(uint[]@ offsets, CMwNod@ startNod = null) {
	if (startNod is null) {
		@startNod = GetApp();
	}
	auto @retNod = NodWithPtr(startNod);
	for (uint i = 0; i < offsets.Length; i++) {
		auto offset = offsets[i];
		if (retNod is null || retNod.nod is null) return null;
		@retNod = NodWithPtr(retNod.nod, offset);
	}
    if (retNod.nod is null) return null;
	return retNod;
}


class NodWithPtr {
	CMwNod@ nod;
	uint64 ptr;

	NodWithPtr(CMwNod@ nod) {
		@this.nod = nod;
		ptr = Dev_GetPointerForNod(nod);
	}

	NodWithPtr(CMwNod@ nod, uint offset) {
		if (nod is null) return;
		@this.nod = Dev::GetOffsetNod(nod, offset);
		this.ptr = Dev::GetOffsetUint64(nod, offset);
	}

	NodWithPtr(ISceneVis@ nod, uint offset) {
		if (nod is null) return;
		@this.nod = Dev::GetOffsetNod(nod, offset);
		this.ptr = Dev::GetOffsetUint64(nod, offset);
	}

	// void DrawClickablePointer(const string &in name) {
	// 	UI::Text(name + ": ");
	// 	UI::SameLine();
	// 	::DrawClickablePointer(name, this.ptr);
	// }
}
