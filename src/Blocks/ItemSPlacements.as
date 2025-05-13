namespace Blocks {
    dictionary BIMobilToItemSPlacements;

    void RegisterCallbacks() {
        RegisterOnEditorLoadCallback(OnEditorLoad, "Blocks::ItemSPlacements");
        RegisterOnEditorGoneNullCallback(OnEditorUnload, "Blocks::ItemSPlacements");
#if DEV
        ItemPlace_StringConsts::OnLoad();
#endif
    }

    void OnEditorLoad() {
        BIMobilToItemSPlacements.DeleteAll();
    }

    void OnEditorUnload() {
        BIMobilToItemSPlacements.DeleteAll();
    }

    BlockInfoMobilExtra@ GetPrefabSPlacements(CGameCtnBlockInfoMobil@ biMobil) {
        if (biMobil is null) {
            return null;
        }
        auto ptr = Dev_GetPointerForNod(biMobil);
        auto ptrKey = Text::FormatPointer(ptr);
        if (BIMobilToItemSPlacements.Exists(ptrKey)) {
            return cast<BlockInfoMobilExtra@>(BIMobilToItemSPlacements[ptrKey]);
        }
        return IngestBIMobil(ptrKey, biMobil);
    }

    BlockInfoMobilExtra@ IngestBIMobil(const string &in ptrKey, CGameCtnBlockInfoMobil@ biMobil) {
        if (biMobil is null) {
            return null;
        }
        if (BIMobilToItemSPlacements.Exists(ptrKey)) throw("IngestBIMobil: key exists: " + ptrKey);
        BlockInfoMobilExtra@ biExtra = BlockInfoMobilExtra(biMobil);
        @BIMobilToItemSPlacements[ptrKey] = biExtra;
        return biExtra;
    }

    class BlockInfoMobilExtra {
        ItemSPlacement[] SPlacements;
        // CGameCtnBlockInfoMobil@ biMobil;
        // CPlugPrefab@ prefab;
        BlockInfoMobilExtra(CGameCtnBlockInfoMobil@ biMobil) {
            // biMobil.MwAddRef();
            // @this.biMobil = biMobil;
            auto fid = cast<CSystemFidFile>(biMobil.PrefabFid);
            // nothing to do if prefab fid null
            if (fid is null) {
                dev_trace("Prefab fid is null: " + Text::FormatPointer(Dev_GetPointerForNod(biMobil)));
                return;
            }
            InitFromFid(fid);
        }

        BlockInfoMobilExtra(CSystemFidFile@ fid) {
            InitFromFid(fid);
        }

        BlockInfoMobilExtra(CPlugPrefab@ prefab) {
            InitFromPrefab(prefab);
        }

        protected void InitFromFid(CSystemFidFile@ fid) {
            // do we need to preload?
            if (fid.Nod is null) Fids::Preload(fid);
            if (fid.Nod is null) throw("BlockInfoMobilExtra: fid nod is null after preloading: " + Text::FormatPointer(Dev_GetPointerForNod(fid)));
            // get the prefab
            auto @prefab = cast<CPlugPrefab>(fid.Nod);
            if (prefab is null) throw("BlockInfoMobilExtra: prefab is null: " + Text::FormatPointer(Dev_GetPointerForNod(fid)));
            InitFromPrefab(prefab);
        }

        protected void InitFromPrefab(CPlugPrefab@ prefab) {
            // get the item placements
            auto nbEnts = prefab.Ents.Length;
            auto entPtr = Dev::GetOffsetUint64(prefab, O_PREFAB_ENTS);
            for (uint i = 0; i < nbEnts; ++i) {
                auto ptr1 = Dev::ReadUInt64(entPtr + i * SZ_ENT_REF + O_ENTREF_PARAMS);
                auto ptr2 = Dev::ReadUInt64(entPtr + i * SZ_ENT_REF + O_ENTREF_PARAMS + 0x8);
                // auto ptr2 = Dev::GetOffsetUint64(paramsFakeNod, 0x8);
                if (ptr2 > 0 && !Dev_PointerLooksBad(ptr2)) {
                    // type = Dev::ReadCString(Dev::ReadUInt64(ptr2));
                    auto paramsClsId = Dev::ReadUInt32(ptr2 + 0x10);
                    if (paramsClsId == CLSID_NPlugItemPlacement_SPlacement) {
                        SPlacements.InsertLast(ItemSPlacement(
                            prefab.Ents[i].Location,
                            DPlugItemPlacement_SPlacement(ptr1))
                        );
                    } else {
                        dev_trace("Miss on class id: " + FmtUintHex(paramsClsId));
                    }
                } else {
                    dev_trace("Bad pointer: " + Text::FormatPointer(ptr2) + " / " + Text::FormatPointer(ptr1));
                }
            }
        }

        ~BlockInfoMobilExtra() {
            // if (biMobil !is null) biMobil.MwRelease();
            // if (prefab !is null) prefab.MwRelease();
            // @biMobil = null;
            // @prefab = null;
        }
    }

    class ItemSPlacement {
        quat Quat;
        vec3 Pos;
        uint iLayout;
        // Contains tag
        SPlacementOpt[] Opts;

        ItemSPlacement() {}

        ItemSPlacement(GmTransQuat& loc, DPlugItemPlacement_SPlacement@ sp) {
            Quat = loc.Quat;
            Pos = loc.Trans;
            iLayout = sp.iLayout;
            auto nbOpts = sp.Options.Length;
            for (uint i = 0; i < nbOpts; i++) {
                Opts.InsertLast(SPlacementOpt(sp.Options.GetSPlacementOption(i)));
            }
        }

        string _toString;
        string ToString() {
            if (_toString.Length > 0) return _toString;
            string str = "ItemSPlacement: ";
            str += "Pos: " + Pos.ToString() + ", ";
            str += "Quat: " + Quat.ToString() + ", ";
            str += "iLayout: " + iLayout + ", ";
            if (Opts.Length > 0) {
                str += "RequiredTags: " + Opts[0].ToString();

            }
            _toString = str;
            return str;
        }

        bool HasTag(nat2 tag) {
            for (uint i = 0; i < Opts.Length; i++) {
                if (Opts[i].ReqTags.Find(tag) >= 0) return true;
            }
            return false;
        }
    }

    class SPlacementOpt {
        nat2[] ReqTags;
        SPlacementOpt() {}
        SPlacementOpt(DPlugItemPlacement_SPlacementOption@ opt) {
            auto rt = opt.RequiredTags;
            auto nbTags = rt.Length;
            ReqTags.Resize(nbTags);
            for (uint i = 0; i < nbTags; i++) {
                ReqTags[i] = rt.GetDRequiredTag(i).xy;
            }
        }

        string ToString() {
            string[] parts;
            for (uint i = 0; i < ReqTags.Length; i++) {
                // parts.InsertLast(ReqTags[i].ToString());
                parts.InsertLast(ItemPlace_StringConsts::LookupJoined(ReqTags[i]));
            }
            return "[ " + string::Join(parts, ", ") + " ]";
        }
    }
}


namespace ItemPlace_StringConsts {
    // we want the offset after the 05, but can't include ?? as last part of pattern
    const string Pattern_IP_SCs = "48 8B F2 48 8D 0C 40 48 8B 05"; // "?? ?? ?? ??"

    // ptr to somewhere in Trackmania.exe
    uint64 _labelStructArrayPtr = 0;

    uint64 get_LabelStructArrayPtr() {
        if (_labelStructArrayPtr == 0) {
            auto codePtr = Dev::FindPattern(Pattern_IP_SCs);
            if (codePtr == 0) throw("LabelStructArray not found");
            codePtr += 0xA;
            int32 offset = Dev::ReadInt32(codePtr);
            _labelStructArrayPtr = codePtr + offset + 4;
            dev_trace("LSAPtr 1: " + Text::FormatPointer(_labelStructArrayPtr));
        }
        return _labelStructArrayPtr;
    }

    void OnLoad() {
        dev_trace("\\$4f4get_LSAPtr: " + Text::FormatPointer(LabelStructArrayPtr));
    }

    void DrawLabelStructArray() {
        auto ptr = LabelStructArrayPtr;
        if (ptr == 0) {
            UI::Text("LabelStructArray not found");
            return;
        }
        auto lsaAddr = Dev::ReadUInt64(ptr);
        auto labelStructArrayLen = Dev::ReadUInt32(ptr + 0x8);
        if (lsaAddr == 0) {
            UI::Text("LabelStructArray is null");
            return;
        }
        UI::Text("LabelStructCount: " + labelStructArrayLen);
        for (uint i = 0; i < labelStructArrayLen; i++) {
            DrawLSAElem(i, lsaAddr + i * 0x30);
        }
    }


    void DrawLSAElem(uint ls_ix, uint64 ptr) {
        auto name = Dev::ReadCString(Dev::ReadUInt64(ptr + 0x0));
        auto buf = RawBuffer(ptr + 0x10, 0x10, false);
        UI::Text("LSA[" + ls_ix + "]: " + name);
        UI::Indent();
            DrawLSAElemNames(name, buf);
        UI::Unindent();
    }

    void DrawLSAElemNames(const string &in grpName, RawBuffer@ buf) {
        auto nbNames = buf.Length;
        UI::Text("Names: " + nbNames);
        UI::SameLine();
        bool copyAll = UX::SmallButton("Copy All##"+grpName);
        string toCopy = grpName + ": ";
        UI::Indent();
        for (uint i = 0; i < nbNames; i++) {
            // auto strPtr = buf[i].GetUint64(0x0);
            // LabeledValue("Name[" + i + "]", Text::FormatPointer(strPtr), true);
            auto value = buf[i].GetCStringWithLen(0x0);
            LabeledValue("Name[" + i + "]", value);
            if (copyAll) {
                if (i > 0) toCopy += ", ";
                toCopy += value;
            }
        }
        UI::Unindent();
        if (copyAll) {
            SetClipboard(toCopy);
        }
    }

    LSA_Lookup@ lookup = null;

    string LookupJoined(nat2 kIx_elIx) {
        return LookupName(kIx_elIx.x) + ": " + Lookup(kIx_elIx);
    }

    string Lookup(nat2 kindIx_ElIx) {
        if (lookup is null) {
            @lookup = LSA_Lookup();
        }
        return lookup.Get(kindIx_ElIx);
    }

    string LookupName(uint kindIx) {
        if (lookup is null) {
            @lookup = LSA_Lookup();
        }
        return lookup.GetName(kindIx);
    }

    class LSA_Lookup {
        protected uint64 ptr, lsaAddr;
        protected uint32 lsaLen;

        string[]@[] cache;
        string[] kindCache;

        LSA_Lookup() {
            ptr = LabelStructArrayPtr;
            lsaAddr = Dev::ReadUInt64(ptr);
            lsaLen = Dev::ReadUInt32(ptr + 0x8);
            kindCache.Resize(lsaLen);
            cache.Resize(lsaLen);
            CacheAll();
#if DEV
            print("Cached LSA: " + Json::Write(GetCacheAsJson()));
#endif
        }

        protected void CacheAll() {
            // dev_trace("CacheAll");
            for (uint k = 0; k < lsaLen; k++) {
                kindCache[k] = _GetName(k);
                // dev_trace("kindCache[" + k + "]: " + kindCache[k]);
                auto nbValues = _GetValuesLen(k);
                // dev_trace("kindCache[" + k + "].Length: " + nbValues);
                @cache[k] = array<string>(nbValues);
                // dev_trace("kindCache[" + k + "].Length: " + cache[k].Length);
                for (uint i = 0; i < nbValues; i++) {
                    auto listPtr = GetListPtr(k);
                    // dev_trace("listPtr: " + Text::FormatPointer(listPtr));
                    auto elPtr = Dev::ReadUInt64(listPtr + 0x10) + i * 0x10;
                    // dev_trace("elPtr: " + Text::FormatPointer(elPtr));
                    auto elAddr = Dev::ReadUInt64(elPtr);
                    // dev_trace("elAddr: " + Text::FormatPointer(elAddr));
                    auto strLen = Dev::ReadUInt32(elPtr + 0x8);
                    // dev_trace("strLen: " + strLen);
                    cache[k][i] = Dev::ReadCString(elAddr, strLen);
                    // dev_trace("cache[" + k + "][" + i + "]: " + cache[k][i]);
                }
            }
        }

        protected uint64 GetListPtr(uint kindIx) {
            if (kindIx >= lsaLen) throw("LSA_Lookup: kindIx out of range: " + kindIx);
            return lsaAddr + kindIx * 0x30;
        }

        string GetName(uint kindIx) {
            if (kindIx >= cache.Length) return "UnknownKind(" + kindIx + ")";
            return kindCache[kindIx];
        }

        string _GetName(uint kindIx) {
            if (kindIx >= lsaLen) throw("LSA_Lookup: kindIx out of range: " + kindIx);
            auto listPtr = GetListPtr(kindIx);
            auto strPtr = Dev::ReadUInt64(listPtr + 0x0);
            return Dev::ReadCString(strPtr);
        }

        uint _GetValuesLen(uint kindIx) {
            if (kindIx >= lsaLen) throw("LSA_Lookup: kindIx out of range: " + kindIx);
            auto listPtr = GetListPtr(kindIx);
            return Dev::ReadUInt32(listPtr + 0x18);
        }

        string Get(nat2 kindIx_ElIx) {
            if (kindIx_ElIx.x >= cache.Length) return "UnknownKind(" + kindIx_ElIx.x + ")";
            if (cache[kindIx_ElIx.x] is null) return "UncachedKind(" + kindIx_ElIx.x + ")";
            if (kindIx_ElIx.y >= cache[kindIx_ElIx.x].Length) return "UnknownEl(" + kindIx_ElIx.y + ")";
            return cache[kindIx_ElIx.x][kindIx_ElIx.y];
        }

        // string _Get(nat2 kindIx_ElIx) {
        //     if (cache.Length > kindIx_ElIx.x && cache[kindIx_ElIx.x] !is null)
        //     if (kindIx_ElIx.x >= lsaLen) throw("LSA_Lookup: kindIx out of range: " + kindIx_ElIx.x);
        //     auto listPtr = GetListPtr(kindIx_ElIx.x);
        //     auto elPtr = Dev::ReadUInt64(listPtr + 0x10) + kindIx_ElIx.y * 0x10;
        //     auto elAddr = Dev::ReadUInt64(elPtr);
        //     auto strLen = Dev::ReadUInt32(elPtr + 0x8);
        //     return Dev::ReadCString(elAddr, strLen);
        //     // return Text::FormatPointer(elAddr);
        //     // return InsertAndReturn(kindIx_ElIx, Dev::ReadCString(elAddr, strLen));
        // }

        Json::Value@ GetCacheAsJson() {
            auto j = Json::Object();
            j['types'] = StrArrayToJson(kindCache);
            auto j2 = Json::Array();
            for (uint k = 0; k < cache.Length; k++) {
                j2.Add(StrArrayToJson(cache[k]));
            }
            j['typeValues'] = j2;
            return j;
        }
    }
}


Json::Value@ StrArrayToJson(string[]&in arr) {
    auto j = Json::Array();
    for (uint i = 0; i < arr.Length; i++) {
        j.Add(arr[i]);
    }
    return j;
}
