#if DEV
// DEV-only forensics + RemoveItem/AnchorData prototype for item delete no-ops.
// Called from DeleteMacroblock via a single #if DEV site — no-op outside DEV.
namespace MacroblockItemDeleteDiag {
    const string LogFileName = "item-delete-forensics.log";

    void _Emit(const string &in line) {
        // Mirror to Openplanet.log (filter: item-delete-forensics / MB-ITEM-DEL)
        dev_trace("[MB-ITEM-DEL] " + line);
        try {
            auto path = IO::FromStorageFolder(LogFileName);
            IO::File f(path, IO::FileMode::Append);
            f.WriteLine(line);
            f.Close();
        } catch {
            // storage write is best-effort
        }
    }

    string _V3(const vec3 &in v) {
        return Text::Format("%.6f", v.x) + "," + Text::Format("%.6f", v.y) + "," + Text::Format("%.6f", v.z);
    }

    string _N3(const nat3 &in n) {
        return n.x + "," + n.y + "," + n.z;
    }

    string _SpecLine(Editor::ItemSpec@ s, const string &in tag) {
        if (s is null) return tag + ": <null spec>";
        auto priv = cast<Editor::ItemSpecPriv>(s);
        string ptr = priv !is null ? Text::FormatPointer(priv.ObjPtr) : "n/a";
        return tag
            + " name=" + s.name
            + " coll=" + s.collection
            + " author=" + s.author
            + " coord=" + _N3(s.coord)
            + " dir=" + int(s.dir)
            + " pos=" + _V3(s.pos)
            + " pyr=" + _V3(s.pyr)
            + " scale=" + s.scale
            + " flying=" + s.isFlying
            + " var=" + s.variantIx
            + " pivot=" + _V3(s.pivotPos)
            + " wp=" + (s.waypoint !is null ? ("order=" + s.waypoint.order + " tag=" + s.waypoint.tag) : "null")
            + " objPtr=" + ptr;
    }

    string _DonorItemLine(DGameCtnMacroBlockInfo_Item@ di, uint ix) {
        if (di is null) return "donor[" + ix + "]: <null>";
        string modelName = di.Model !is null ? string(di.Model.IdName) : "<null model>";
        string modelColl = di.Model !is null
            ? ("" + di.Model.CollectionId + "/" + di.Model.CollectionId_Text)
            : "n/a";
        return "donor[" + ix + "]"
            + " name=" + di.name
            + " nameId=" + Text::Format("0x%08x", di.nameId)
            + " collU32=" + di.collection
            + " author=" + di.author
            + " coord=" + _N3(di.coord)
            + " dir=" + int(di.dir)
            + " pos=" + _V3(di.pos)
            + " pyr=" + _V3(di.pyr)
            + " scale=" + di.scale
            + " flying=" + di.isFlying
            + " var=" + di.variantIx
            + " pivot=" + _V3(di.pivotPos)
            + " model=" + modelName
            + " modelColl=" + modelColl
            + " wp=" + (di.Waypoint !is null ? "set" : "null")
            + " assocBlk=" + Text::Format("0x%08x", di.associatedBlockIx)
            + " groupOnBlk=" + Text::Format("0x%08x", di.itemGroupOnBlock);
    }

    string _MapItemLine(CGameCtnAnchoredObject@ item, uint ix) {
        if (item is null) return "map[" + ix + "]: <null>";
        auto model = item.ItemModel;
        string modelName = model !is null ? string(model.IdName) : "<null>";
        uint collIx = model !is null ? Editor::CollectionIdToIx(model.CollectionId, model.CollectionId_Text) : 0;
        string author = model !is null ? model.Author.GetName() : "";
        vec3 loc = Editor::GetItemLocation(item);
        vec3 rot = Editor::GetItemRotation(item);
        vec3 pivot = Editor::GetItemPivot(item);
        vec3 mbOff = Editor::GetMacroblockPosOffset();
        int rc = -1;
        try { rc = Reflection::GetRefCount(item); } catch {}
        return "map[" + ix + "]"
            + " name=" + modelName
            + " collIx=" + collIx
            + " collId=" + (model !is null ? ("" + model.CollectionId) : "n/a")
            + " author=" + author
            + " buc=" + _N3(item.BlockUnitCoord)
            + " buc-010=" + _N3(item.BlockUnitCoord - nat3(0, 1, 0))
            + " absPos=" + _V3(item.AbsolutePositionInMap)
            + " loc=" + _V3(loc)
            + " loc+mbOff=" + _V3(loc + mbOff)
            + " pyr=" + _V3(rot)
            + " scale=" + item.Scale
            + " flying=" + item.IsFlying
            + " var=" + item.IVariant
            + " pivot=" + _V3(pivot)
            + " wp=" + (item.WaypointSpecialProperty !is null ? "set" : "null")
            + " rc=" + rc
            + " ptr=" + Text::FormatPointer(Dev_GetPointerForNod(item));
    }

    void _LogSpecVsMapMatches(Editor::MacroblockSpecPriv@ mbSpec, CGameCtnEditorFree@ editor) {
        if (mbSpec is null || editor is null || editor.Challenge is null) return;
        auto map = editor.Challenge;
        uint nMap = map.AnchoredObjects.Length;
        _Emit("map.AnchoredObjects.Length=" + nMap
            + " mbHeightOff=" + Editor::GetMacroblockHeightOffset()
            + " mbPosOff=" + _V3(Editor::GetMacroblockPosOffset())
            + " collectorId=" + Editor::GetMapCollectorId());

        for (uint si = 0; si < mbSpec.Items.Length; si++) {
            auto spec = cast<Editor::ItemSpecPriv>(mbSpec.Items[si]);
            if (spec is null) {
                _Emit(_SpecLine(mbSpec.Items[si], "spec[" + si + "]"));
                continue;
            }
            _Emit(_SpecLine(spec, "spec[" + si + "]"));
            int matchCount = 0;
            // Scan all map items; log nearest few by name + any MatchesItem hits
            for (uint mi = 0; mi < nMap; mi++) {
                auto item = map.AnchoredObjects[mi];
                if (item is null || item.ItemModel is null) continue;
                bool nameMatch = string(item.ItemModel.IdName) == spec.name;
                bool fullMatch = false;
                try { fullMatch = spec.MatchesItem(item); } catch {
                    _Emit("  MatchesItem exception vs map[" + mi + "]: " + getExceptionInfo());
                    continue;
                }
                if (fullMatch) {
                    matchCount++;
                    _Emit("  MATCH full map[" + mi + "] " + _MapItemLine(item, mi));
                } else if (nameMatch) {
                    // field-level delta for same-name candidates
                    vec3 loc = Editor::GetItemLocation(item);
                    vec3 expectPos = loc + Editor::GetMacroblockPosOffset();
                    vec3 rot = Editor::GetItemRotation(item);
                    uint collIx = Editor::CollectionIdToIx(item.ItemModel.CollectionId, item.ItemModel.CollectionId_Text);
                    string author = item.ItemModel.Author.GetName();
                    _Emit("  name-hit map[" + mi + "] full=false"
                        + " collSpec=" + spec.collection + " collMap=" + collIx + " collEq=" + (spec.collection == collIx)
                        + " authorEq=" + (spec.author == author)
                        + " coordSpec=" + _N3(spec.coord) + " coordMap-010=" + _N3(item.BlockUnitCoord - nat3(0, 1, 0))
                        + " coordEq=" + MathX::Nat3Eq(spec.coord, item.BlockUnitCoord - nat3(0, 1, 0))
                        + " posSpec=" + _V3(spec.pos) + " posExpect=" + _V3(expectPos)
                        + " posNear=" + MathX::Vec3Within(spec.pos, expectPos, 0.0001)
                        + " posDist2=" + (spec.pos - expectPos).LengthSquared()
                        + " pyrSpec=" + _V3(spec.pyr) + " pyrMap=" + _V3(rot)
                        + " angClose=" + Editor::AnglesVeryClose(spec.pyr, rot)
                        + " scaleEq=" + (spec.scale == item.Scale)
                        + " flySpec=" + spec.isFlying + " flyMap=" + (item.IsFlying ? 1 : 0)
                        + " varEq=" + (spec.variantIx == item.IVariant)
                        + " pivotEq=" + MathX::Vec3Eq(spec.pivotPos, Editor::GetItemPivot(item)));
                    _Emit("    " + _MapItemLine(item, mi));
                }
            }
            _Emit("  spec[" + si + "] fullMatchCount=" + matchCount);
        }
    }

    void _LogDonorItems(CGameCtnMacroBlockInfo@ mb) {
        if (mb is null) {
            _Emit("donor: null");
            return;
        }
        auto dmb = DGameCtnMacroBlockInfo(mb);
        _Emit("donor id=" + mb.IdName
            + " init=" + mb.Initialized
            + " connected=" + mb.Connected
            + " isGround=" + mb.IsGround
            + " coll=" + mb.CollectionId + "/" + mb.CollectionId_Text
            + " rc=" + Reflection::GetRefCount(mb)
            + " nb=" + dmb.Blocks.Length + "/" + dmb.Items.Length + "/" + dmb.Skins.Length);
        uint n = dmb.Items.Length;
        if (n > 8) n = 8;
        for (uint i = 0; i < n; i++) {
            _Emit(_DonorItemLine(dmb.Items.GetItem(i), i));
        }
        if (dmb.Items.Length > n) {
            _Emit("donor items truncated; total=" + dmb.Items.Length);
        }
    }

    // Prototype B: pmt.RemoveItem via AnchorData SpecialProperty wrappers.
    // Returns true if at least one requested item left the map.
    bool TryRemoveViaAnchorData(Editor::MacroblockSpecPriv@ mbSpec, CGameCtnEditorFree@ editor) {
        if (mbSpec is null || editor is null || editor.PluginMapType is null || editor.Challenge is null) {
            return false;
        }
        auto pmt = editor.PluginMapType;
        auto map = editor.Challenge;
        uint itemsBefore = map.AnchoredObjects.Length;
        uint nAnchor = 0;
        try { nAnchor = pmt.AnchorData.Length; } catch {
            _Emit("AnchorData access exception: " + getExceptionInfo());
            return false;
        }
        uint nPmtItems = 0;
        try { nPmtItems = pmt.Items.Length; } catch {}
        _Emit("TryRemoveViaAnchorData: AnchorData.len=" + nAnchor
            + " pmt.Items.len=" + nPmtItems
            + " mapItems=" + itemsBefore
            + " specs=" + mbSpec.Items.Length);

        if (nAnchor == 0) {
            _Emit("TryRemoveViaAnchorData: AnchorData empty — RemoveItem unavailable without script wrappers");
            return false;
        }

        int removedN = 0;
        for (uint si = 0; si < mbSpec.Items.Length; si++) {
            auto spec = cast<Editor::ItemSpecPriv>(mbSpec.Items[si]);
            if (spec is null) continue;
            bool gotOne = false;
            for (uint ai = 0; ai < nAnchor; ai++) {
                CGameCtnEditorScriptSpecialProperty@ sp = null;
                try { @sp = pmt.AnchorData[ai]; } catch { continue; }
                if (sp is null) continue;
                auto scriptItem = sp.Item;
                if (scriptItem is null) continue;
                // Match by model name + position (script wrapper only exposes those)
                bool nameOk = scriptItem.ItemModel !is null
                    && string(scriptItem.ItemModel.IdName) == spec.name;
                bool posOk = false;
                try {
                    // Spec pos includes macroblock offset; script Position is world abs
                    vec3 expectWorld = spec.pos - Editor::GetMacroblockPosOffset();
                    posOk = (scriptItem.Position - expectWorld).LengthSquared() < 0.01
                        || MathX::Vec3Within(scriptItem.Position + Editor::GetMacroblockPosOffset(), spec.pos, 0.05);
                } catch {}
                if (!nameOk && !posOk) continue;
                if (!nameOk) {
                    _Emit("  anchor[" + ai + "] pos-near but name mismatch; skip");
                    continue;
                }
                bool ok = false;
                try {
                    ok = pmt.RemoveItem(sp);
                } catch {
                    _Emit("  RemoveItem exception anchor[" + ai + "]: " + getExceptionInfo());
                    continue;
                }
                _Emit("  RemoveItem(anchor[" + ai + "] name=" + spec.name
                    + " scriptPos=" + _V3(scriptItem.Position)
                    + ") -> " + ok);
                if (ok) {
                    removedN++;
                    gotOne = true;
                    break;
                }
            }
            if (!gotOne) {
                _Emit("  no AnchorData hit for spec[" + si + "] name=" + spec.name);
            }
        }
        uint itemsAfter = map.AnchoredObjects.Length;
        _Emit("TryRemoveViaAnchorData done: removedN=" + removedN
            + " items " + itemsBefore + "->" + itemsAfter);
        return itemsAfter < itemsBefore;
    }

    // Single entry from DeleteMacroblock. Logs forensics; may try RemoveItem.
    // Returns possibly-updated `removed`.
    bool OnDeleteMacroblockResult(
        Editor::MacroblockSpecPriv@ mbSpec,
        CGameCtnMacroBlockInfo@ mb,
        CGameCtnEditorFree@ editor,
        bool removed
    ) {
        if (mbSpec is null) return removed;
        // Only interesting when there are items (block-only deletes already work)
        if (mbSpec.Items.Length == 0) return removed;

        _Emit("======== item-delete forensics ========");
        _Emit("RemoveMacroblock returned=" + removed
            + " specs blocks/items=" + mbSpec.Blocks.Length + "/" + mbSpec.Items.Length
            + " donorPath=" + Editor::GetDonorMacroblockPath());
        _LogDonorItems(mb);
        _LogSpecVsMapMatches(mbSpec, editor);

        if (!removed) {
            _Emit("engine RemoveMacroblock missed — trying AnchorData RemoveItem prototype");
            bool viaAnchor = TryRemoveViaAnchorData(mbSpec, editor);
            if (viaAnchor) {
                _Emit("AnchorData RemoveItem SUCCEEDED (prototype B)");
                removed = true;
            } else {
                _Emit("AnchorData RemoveItem did not remove any items");
            }
        } else {
            _Emit("engine remove succeeded; skipping AnchorData prototype");
        }
        _Emit("======== end forensics removed=" + removed + " ========");
        return removed;
    }
}
#endif
