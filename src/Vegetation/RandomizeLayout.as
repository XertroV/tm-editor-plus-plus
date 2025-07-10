
// MARK: RandomizeVegetationLayouts

[Setting hidden]
bool S_RandomizeVegetationLayouts = false;

namespace RandomizeVegetationLayouts {
	bool IsActive {
		get { return S_RandomizeVegetationLayouts; }
		set {
			S_RandomizeVegetationLayouts = value;
			Start_UpdateRunRVL();
		}
	}

	void Toggle() {
		IsActive = !IsActive;
	}

	void OnEditor() {
		Start_UpdateRunRVL();
	}

	void Start_UpdateRunRVL() {
		Hook_ItemCursor_SetPZoneId.SetApplied(IsActive);
		// Meta::StartWithRunContext(Meta::RunContext::AfterScripts, UpdateRunRVL);
	}

	DSceneItemPlacement_SMgr2@ GetItemPlacementMgr(CGameCtnApp@ app) {
		auto mgrPtr = FindPhyMgrPtr(app, CLSID_NSceneItemPlacement_SMgr);
		if (mgrPtr == 0) return null;
		return DSceneItemPlacement_SMgr2(mgrPtr);
	}

	class DSceneItemPlacement_SMgr2 : DSceneItemPlacement_SMgr {
		DSceneItemPlacement_SMgr2(uint64 ptr) {
			super(ptr);
		}

		MemoryIter@ GetZoneIdsIter() {
			auto bufAddr = Ptr + 0x18;
			// +0x8 is like the number of spare entries to use from the start or something?
			auto lenAddr = bufAddr + 0xC;
			auto capAddr = bufAddr + 0x10;
			auto len = Dev::ReadUInt32(lenAddr);
			auto cap = Dev::ReadUInt32(capAddr);
			auto elsAddr = Dev::ReadUInt64(bufAddr);
			return MemoryIter(elsAddr, len, cap).WithSpan(4);
		}

		// get the ID from zone ID list at a given index
		int GetZoneId(int idIx) {
			return GetZoneIdsIter().Skip(idIx).NextUint();
		}

		// find an ID in the list at 0x18
		int FindZoneIdIndex(int id) {
			if (id < 0) return -1;
			auto bufAddr = Ptr + 0x18;
			// +0x8 is like the number of spare entries to use from the start or something?
			auto lenAddr = bufAddr + 0xC;
			auto capAddr = bufAddr + 0x10;
			auto len = Dev::ReadUInt32(lenAddr);
			auto cap = Dev::ReadUInt32(capAddr);
			auto elsAddr = Dev::ReadUInt64(bufAddr);
			if (elsAddr == 0) {
				dev_warn('FindZoneIdIndex: elsAddr == 0');
				return -1;
			}
			if (len == 0) return -1;
			if (len > cap) {
				dev_warn('FindZoneIdIndex: len > cap: ' + len + ' > ' + cap);
				len = cap;
			}
			for (uint ix = 0; ix < len; ix++) {
				auto idAddr = elsAddr + ix * 0x4;
				auto idVal = Dev::ReadUInt32(idAddr);
				if (idVal == uint(id)) {
					return ix;
				}
			}
			dev_warn('FindZoneIdIndex: id not found: ' + id);
			return -1;
		}

		int lastSetPlacementIxRanomized = -1;
		void RandomizePlacement(int zoneIx) {
			if (zoneIx >= 0) {
				auto zone = Zones.GetSZone(zoneIx);
				auto lastSetIx = lastSetPlacementIxRanomized;
				auto nbPlacements = zone.PlacementNb;
				if (nbPlacements > 1) {
					auto ixWas = zone.PlacementIx;
					auto newIx = Math::Rand(0, nbPlacements);
					auto count = 0;
					while (count++ < 10 && (ixWas == newIx || (newIx == lastSetIx && count < 4))) {
						newIx = Math::Rand(0, nbPlacements);
					}
					if (count == 10) newIx = (ixWas + 1) % nbPlacements;
					zone.PlacementIx = newIx;
					lastSetPlacementIxRanomized = newIx;
					dev_trace('AfterItemCursorPlacementZoneIdUpdated block #'+GetZoneCtnBlockMwId(zone)+' : zoneIx: ' + zoneIx + ' zone.PlacementIx: ' + ixWas + ' -> ' + zone.PlacementIx);
				}
			} else {
				dev_trace('zoneIx < 0: ' + zoneIx);
			}
		}

		int GetZoneCtnBlockMwId(DSceneItemPlacement_SZone@ zone) {
			if (zone is null) return -1;
			auto block = zone.Block;
			if (block is null) return -1;
			return block.Id.Value;
		}
	}

	uint64 FindPhyMgrPtr(CGameCtnApp@ app, uint classId) {
		auto iPhy = Dev::GetOffsetNod(app, O_APP_GAMESCENE + 0x8);
		auto nb = Dev::GetOffsetUint32(iPhy, O_ISCENEVIS_METAMGR);
		// trace("FindMgrPtr: nb = " + nb);
		auto startOffset = O_ISCENEVIS_METAMGR + 0x8;
		auto endOffset = O_ISCENEVIS_METAMGR + 0x8 + nb * 0x10;
		for (uint o = startOffset; o < endOffset; o += 0x10) {
			// auto mgrPtr = Dev::GetOffsetUint64(iPhy, o);
			auto ptr = Dev::GetOffsetUint64(iPhy, o + 0x8);
			if (ptr == 0) continue;
			if (Dev_PointerLooksBad(ptr)) {
				Dev_NotifyWarning("FindMgrPtr: bad pointer " + Text::FormatPointer(ptr));
				continue;
			}
			auto clsId = Dev::ReadUInt32(ptr + 0x10);
			if (clsId == classId) {
				return Dev::GetOffsetUint64(iPhy, o);
			}
		}
		return 0;
	}

	// // offset = 7
	// const string Pattern_SetPZoneId = "0F 29 95 ?? 00 00 00 E8 ?? ?? ?? ?? 48 8D 8D ?? 01 00 00 E8";
	// FunctionHookHelper@ Hook_ItemCursor_SetPZoneId = FunctionHookHelper(
	//     Pattern_SetPZoneId, 7, 0, "RandomizeVegetationLayouts::AfterItemCursorPlacementZoneIdUpdated", Dev::PushRegisters::SSE, false
	// );
	// offset = 0; padding = 1
	const string Pattern_SetPZoneId = "89 9F 88 00 00 00 0F 28 00";
	HookHelper@ Hook_ItemCursor_SetPZoneId = HookHelper(
		Pattern_SetPZoneId, 0, 1, "RandomizeVegetationLayouts::AfterItemCursorPlacementZoneIdUpdated", Dev::PushRegisters::SSE, false
	);


	int lastSbpZoneId = -1;
	// rdi is ItemCursor
	void AfterItemCursorPlacementZoneIdUpdated(uint64 rdi) {
		if (!S_RandomizeVegetationLayouts) {
			dev_warn('AfterItemCursorPlacementZoneIdUpdated but S_RandomizeVegetationLayouts not active');
			return;
		}

		auto app = GetApp();
		auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (editor is null) return;
        if (editor.CurrentItemModel is null) return;
        if (!Veget::DoesItemModelHaveVeget(editor.CurrentItemModel, false)) return;

		// auto sbpZoneId = Editor::GetItemCursorSnappedBlockPlacementZoneId(editor.ItemCursor);
		auto sbpZoneId = Dev::ReadInt32(rdi + O_ITEMCURSOR_SnappedBlockPlacementZoneId);
		if (sbpZoneId >= 0 && sbpZoneId != lastSbpZoneId) {
			lastSbpZoneId = sbpZoneId;
			auto itemPlacementMgr = GetItemPlacementMgr(app);
			auto zoneIx = itemPlacementMgr.GetZoneId(sbpZoneId);
			itemPlacementMgr.RandomizePlacement(zoneIx);
		} else if (sbpZoneId < 0) {
			dev_warn("AfterItemCursorPlacementZoneIdUpdated: sbpZoneId < 0: " + sbpZoneId + " -- but hook only happens after updating with id >= 0");
		}
	}
}


/*

idea: hook the function that writes the placementZoneId to ItemCursor so we can randomize things before the cursor is updated.

Trackmania.exe.text+DE3D5F - F2 0F11 8D E0000000   - movsd [rbp+000000E0],xmm1
Trackmania.exe.text+DE3D67 - 0F29 95 80000000      - movaps [rbp+00000080],xmm2
Trackmania.exe.text+DE3D6E - E8 AD503100           - call Trackmania.exe.text+10F8E20 { set placementZoneId to value
 }
Trackmania.exe.text+DE3D73 - 48 8D 8D D0010000     - lea rcx,[rbp+000001D0]
Trackmania.exe.text+DE3D7A - E8 B17633FF           - call Trackmania.exe.text+11B430
Trackmania.exe.text+DE3D7F - E9 80FCFFFF           - jmp Trackmania.exe.text+DE3A04


F2 0F 11 8D E0 00 00 00
0F 29 95 80 00 00 00
E8 AD 50 31 00
48 8D 8D D0 01 00 00
E8 B1 76 33 FF


0F 29 95 ?? 00 00 00 E8 ?? ?? ?? ?? 48 8D 8D ?? 01 00 00 E8

hmm, this is too late in execution (and the models shown are updated before this)

hook just after the index is updated:
(still sometimes shows an old one for 1 frame, but rare)


Trackmania.exe.text+10F8F3A - 89 9F 88000000        - mov [rdi+00000088],ebx { SET PLACEMENT ZONE ID
 }
Trackmania.exe.text+10F8F40 - 0F28 00               - movaps xmm0,[rax]
Trackmania.exe.text+10F8F43 - F2 0F10 48 10         - movsd xmm1,[rax+10]
Trackmania.exe.text+10F8F48 - 0F11 47 70            - movups [rdi+70],xmm0
Trackmania.exe.text+10F8F4C - F2 0F11 8F 80000000   - movsd [rdi+00000080],xmm1

89 9F 88 00 00 00
0F 28 00
F2 0F 10 48 10
0F 11 47 70
F2 0F 11 8F 80 00 00 00

89 9F 88 00 00 00 0F 28 00
F2 0F 10 48 10
0F 11 47 70
F2 0F 11 8F 80 00 00 00

*/
