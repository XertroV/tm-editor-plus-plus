// DEV-only #35 tooling: MCP JSON helpers (Spike* exports via Exports_Dev.as) and
// spawn-field dumps. Not compiled into release builds.
#if DEV
namespace Editor {
namespace DevTest {
    // Native PMT helpers (GetStartBlockCount/GetStartLineBlock) cover the common
    // single-start case; the backwards scan remains only as a dev-tooling fallback
    // for maps with multiple starts (native API has no indexed start accessor).
    CGameCtnBlock@ FindLatestStartBlock(CGameCtnEditorFree@ editor) {
        if (editor is null || editor.PluginMapType is null) return null;
        auto pmt = editor.PluginMapType;
        if (pmt.GetStartBlockCount(true) == 1) {
            return pmt.GetStartLineBlock();
        }
        auto map = editor.Challenge;
        if (map is null) return null;
        for (int i = int(map.Blocks.Length) - 1; i >= 0; i--) {
            auto b = map.Blocks[i];
            if (b is null || b.BlockInfo is null) continue;
            auto wt = b.BlockInfo.EdWaypointType;
            if (wt == CGameCtnBlockInfo::EWayPointType::Start
                || wt == CGameCtnBlockInfo::EWayPointType::StartFinish) {
                return b;
            }
        }
        return null;
    }
    bool IsStartLikeBlock(CGameCtnBlock@ b) {
        if (b is null || b.BlockInfo is null) return false;
        auto wt = b.BlockInfo.EdWaypointType;
        return wt == CGameCtnBlockInfo::EWayPointType::Start
            || wt == CGameCtnBlockInfo::EWayPointType::StartFinish
            || wt == CGameCtnBlockInfo::EWayPointType::Checkpoint;
    }

    string SpikeDumpTestVehicleCursor() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.ItemCursor is null) throw("no ItemCursor");
        auto ic = DGameCursorItem(editor.ItemCursor);
        Json::Value report = Json::Object();
        report["placeMode"] = int(editor.PluginMapType.PlaceMode);
        report["inTest"] = IsInTestPlacementMode(editor);
        report["isFreeMode"] = ic.isFreeMode;
        report["pos"] = ic.pos.ToString();
        report["x"] = ic.pos.x;
        report["y"] = ic.pos.y;
        report["z"] = ic.pos.z;
        report["magnetYawDeg"] = ic.MagnetSnapping_LocalRotation_Deg;
        report["snappedGlobalIx"] = int(ic.snappedGlobalIx);
        report["snappedBlockIx"] = int(ic.snappedBlockIx);
        report["isSnapped"] = ic.snappedGlobalIx != uint(-1);
        report["snappedBlockNull"] = ic.snappedBlock is null;
        if (ic.snappedBlock !is null && ic.snappedBlock.BlockInfo !is null) {
            report["snappedBlockName"] = ic.snappedBlock.BlockInfo.IdName;
        }
        report["mouseInWorld"] = ic.mouseInWorld.ToString();
        report["isAutoRotate"] = ic.isAutoRotate;
        report["itemModelNull"] = ic.itemModel is null;
        if (ic.itemModel !is null) {
            report["itemModel"] = ic.itemModel.IdName;
        }
        report["helperMobilNull"] = ic.helperMobil is null;
        auto descs = ic.displayedItems;
        report["displayedLen"] = int(descs.Length);
        Json::Value cars = Json::Array();
        for (uint i = 0; i < descs.Length && i < 8; i++) {
            auto d = descs.GetItemDesc(i);
            Json::Value row = Json::Object();
            row["i"] = int(i);
            row["u1"] = int(d.u1);
            row["drawn"] = d.u1 != uint(-1);
            row["isCar"] = d.u1 == 3;
            row["modelNull"] = d.itemModel is null;
            if (d.itemModel !is null) row["model"] = d.itemModel.IdName;
            auto m = d.matrix;
            row["mtxTx"] = m.tx;
            row["mtxTy"] = m.ty;
            row["mtxTz"] = m.tz;
            cars.Add(row);
        }
        report["displayed"] = cars;

        // VehicleState: real vis poses (test-mode snap may not touch ItemCursor.snapped*)
        Json::Value visArr = Json::Array();
        auto scene = GetApp().GameScene;
        report["gameSceneNull"] = scene is null;
        if (scene !is null) {
            auto viss = VehicleState::GetAllVis(scene);
            report["visCount"] = int(viss.Length);
            for (uint i = 0; i < viss.Length && i < 16; i++) {
                auto vis = viss[i];
                Json::Value row = Json::Object();
                row["i"] = int(i);
                row["visNull"] = vis is null;
                if (vis !is null && vis.AsyncState !is null) {
                    auto mat = Dev::GetOffsetIso4(vis.AsyncState, O_VISSTATE_Mat);
                    row["x"] = mat.tx;
                    row["y"] = mat.ty;
                    row["z"] = mat.tz;
                    row["pos"] = vec3(mat.tx, mat.ty, mat.tz).ToString();
                    row["iso4"] = Iso4ToJson(mat);
                }
                visArr.Add(row);
            }
        }
        report["vehicles"] = visArr;

        // also ItemCursor iso4 (pos field can lag / be camera-ish)
        auto cmat = ic.mat;
        report["cursorMat"] = vec3(cmat.tx, cmat.ty, cmat.tz).ToString();
        report["cursorMatX"] = cmat.tx;
        report["cursorMatY"] = cmat.ty;
        report["cursorMatZ"] = cmat.tz;
        report["gizmoActive"] = Gizmo::IsActive;
        report["placeModeName"] = tostring(editor.PluginMapType.PlaceMode);
        if (editor.Challenge !is null) {
            report["startSpawns"] = DumpStartBlockSpawns(editor.Challenge);
            report["spawnItems"] = DumpSpawnItems(editor.Challenge);
        }

        return Json::Write(report);
    }

    Json::Value DumpSpawnItems(CGameCtnChallenge@ map) {
        Json::Value arr = Json::Array();
        if (map is null) return arr;
        uint n = 0;
        for (int i = int(map.AnchoredObjects.Length) - 1; i >= 0 && n < 8; i--) {
            auto ao = map.AnchoredObjects[i];
            if (ao is null || ao.ItemModel is null) continue;
            Json::Value row = Json::Object();
            row["name"] = ao.ItemModel.IdName;
            row["pos"] = ao.AbsolutePositionInMap.ToString();
            row["waypointType"] = tostring(ao.ItemModel.WaypointType);
            auto cie = cast<CGameCommonItemEntityModel>(ao.ItemModel.EntityModel);
            row["cieNull"] = cie is null;
            if (cie !is null) {
                row["spawnLoc"] = vec3(cie.SpawnLoc.tx, cie.SpawnLoc.ty, cie.SpawnLoc.tz).ToString();
            }
            arr.Add(row);
            n++;
        }
        return arr;
    }

    Json::Value DumpStartBlockSpawns(CGameCtnChallenge@ map) {
        Json::Value arr = Json::Array();
        if (map is null) return arr;
        uint n = 0;
        for (int i = int(map.Blocks.Length) - 1; i >= 0 && n < 8; i--) {
            auto b = map.Blocks[i];
            if (!IsStartLikeBlock(b)) continue;
            Json::Value row = Json::Object();
            row["name"] = b.BlockInfo.IdName;
            row["pos"] = Editor::GetBlockLocation(b).ToString();
            row["isGround"] = b.IsGround;
            row["varIx"] = int(b.BlockInfoVariantIndex);
            row["edNoRespawn"] = b.BlockInfo.EdNoRespawn;
            row["variants"] = DumpBlockInfoSpawns(b.BlockInfo);
            arr.Add(row);
            n++;
        }
        return arr;
    }

    Json::Value DumpBlockInfoSpawns(CGameCtnBlockInfo@ bi) {
        Json::Value arr = Json::Array();
        if (bi is null) return arr;
        AddVariantSpawn(arr, "VariantGround", bi.VariantGround);
        AddVariantSpawn(arr, "VariantAir", bi.VariantAir);
        AddVariantSpawn(arr, "VariantBaseGround", bi.VariantBaseGround);
        AddVariantSpawn(arr, "VariantBaseAir", bi.VariantBaseAir);
        for (uint i = 0; i < bi.AdditionalVariantsGround.Length; i++) {
            AddVariantSpawn(arr, "AddG[" + i + "]", bi.AdditionalVariantsGround[i]);
        }
        for (uint i = 0; i < bi.AdditionalVariantsAir.Length; i++) {
            AddVariantSpawn(arr, "AddA[" + i + "]", bi.AdditionalVariantsAir[i]);
        }
        return arr;
    }

    void AddVariantSpawn(Json::Value@ arr, const string &in label, CGameCtnBlockInfoVariant@ biv) {
        Json::Value o = Json::Object();
        o["k"] = label;
        o["null"] = biv is null;
        if (biv !is null) {
            o["size"] = biv.Size.ToString();
            auto sm = biv.SpawnModel;
            if (sm is null) @sm = cast<CPlugSpawnModel>(Dev::GetOffsetNod(biv, O_BLOCKINFOVAR_SPAWNMODEL));
            o["smNull"] = sm is null;
            if (sm !is null) {
                o["tx"] = sm.Loc.tx;
                o["ty"] = sm.Loc.ty;
                o["tz"] = sm.Loc.tz;
                o["gravity"] = sm.DefaultGravitySpawn.ToString();
            }
            o["spawnTrans"] = biv.SpawnTrans.ToString();
            o["spawnTransX"] = biv.SpawnTransX;
            o["spawnTransY"] = biv.SpawnTransY;
            o["spawnTransZ"] = biv.SpawnTransZ;
            o["spawnYaw"] = biv.SpawnYaw;
            o["spawnPitch"] = biv.SpawnPitch;
            o["spawnRoll"] = biv.SpawnRoll;
        }
        arr.Add(o);
    }
    string SpikeEnterTestAtLatestStart() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Challenge is null) throw("not in map editor");
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Test);
        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
        auto start = FindLatestStartBlock(editor);
        vec3 pos = vec3();
        if (start !is null) pos = (Editor::GetBlockMatrix(start) * GetStartSpawnLocal(start)).xyz;
        Editor::SetAllCursorPos(pos);
        Json::Value report = Json::Object();
        report["inTest"] = Editor::IsInTestPlacementMode(editor);
        report["cursorPos"] = pos.ToString();
        auto scene = GetApp().GameScene;
        report["visCount"] = scene is null ? 0 : int(VehicleState::GetAllVis(scene).Length);
        return Json::Write(report);
    }

    string SpikeNudgeKeptVehicle(float dy) {
        auto scene = GetApp().GameScene;
        if (scene is null) throw("no GameScene");
        auto viss = VehicleState::GetAllVis(scene);
        if (viss.Length == 0) throw("no vehicle vis");
        auto vis = viss[0];
        if (vis is null || vis.AsyncState is null) throw("vis/async null");
        auto mat = Dev::GetOffsetIso4(vis.AsyncState, O_VISSTATE_Mat);
        iso4 next = iso4(mat4::Translate(vec3(0, dy, 0)) * mat4(mat));
        Dev::SetOffset(vis.AsyncState, O_VISSTATE_Mat, next);
        Json::Value report = Json::Object();
        report["x"] = next.tx;
        report["y"] = next.ty;
        report["z"] = next.tz;
        report["pos"] = vec3(next.tx, next.ty, next.tz).ToString();
        report["visCount"] = int(viss.Length);
        return Json::Write(report);
    }

    string SpikeSetKeepVehiclePatch(bool on) {
        VehicleKeepState::Applied = on;
        Json::Value report = Json::Object();
        report["keepVehiclePatch"] = VehicleKeepState::Applied;
        return Json::Write(report);
    }

    string SpikeLeaveTestMode() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) throw("not in map editor");
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
        Json::Value report = Json::Object();
        report["placeMode"] = int(editor.PluginMapType.PlaceMode);
        report["inTest"] = Editor::IsInTestPlacementMode(editor);
        report["gizmoActive"] = Gizmo::IsActive;
        report["keepVehiclePatch"] = VehicleKeepState::Applied;
        auto scene = GetApp().GameScene;
        report["visCount"] = scene is null ? 0 : int(VehicleState::GetAllVis(scene).Length);
        return Json::Write(report);
    }

    string SpikeEnterGizmoOnLatestStart(int blockIndex = -1, int itemIndex = -1) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Challenge is null) throw("not in map editor");
        if (Gizmo::IsActive) Gizmo::IsActive = false;

        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);

        CGameCtnBlock@ start;
        if (blockIndex >= 0 && uint(blockIndex) < editor.Challenge.Blocks.Length) {
            @start = editor.Challenge.Blocks[blockIndex];
        } else {
            @start = FindLatestStartBlock(editor);
        }
        if (itemIndex >= 0) {
            if (uint(itemIndex) >= editor.Challenge.AnchoredObjects.Length) throw("item index out of range");
            auto ao = editor.Challenge.AnchoredObjects[itemIndex];
            @lastPickedItem = ReferencedNod(ao);
            lastPickedType = BlockOrItem::Item;
            @lastPickedItemBB = null;
            UpdatePickedItemCachedValues();
            Gizmo::shouldReplaceTarget = true;
            Gizmo::IsActive = true;
            Json::Value ir = Json::Object();
            ir["requested"] = true;
            ir["gizmoActive"] = Gizmo::IsActive;
            ir["picked"] = ao.ItemModel !is null ? ao.ItemModel.IdName : "?";
            ir["pickedPos"] = ao.AbsolutePositionInMap.ToString();
            ir["inTest"] = Editor::IsInTestPlacementMode(editor);
            ir["placeMode"] = int(editor.PluginMapType.PlaceMode);
            return Json::Write(ir);
        }
        if (start is null) throw("no Start/StartFinish block");
        @lastPickedBlock = ReferencedNod(start);
        UpdatePickedBlockCachedValues();
        lastPickedType = BlockOrItem::Block;
        // LMB: gizmo the start itself so Ensure runs (RMB place-at skips vehicle)
        Gizmo::shouldReplaceTarget = true;
        Gizmo::IsActive = true;

        Json::Value report = Json::Object();
        report["requested"] = true;
        report["gizmoActive"] = Gizmo::IsActive;
        report["picked"] = start.BlockInfo.IdName;
        report["pickedPos"] = Editor::GetBlockLocation(start).ToString();
        report["inTest"] = Editor::IsInTestPlacementMode(editor);
        report["placeMode"] = int(editor.PluginMapType.PlaceMode);
        return Json::Write(report);
    }

    string SpikeExitGizmo() {
        if (Gizmo::IsActive) Gizmo::IsActive = false;
        Json::Value report = Json::Object();
        report["gizmoActive"] = Gizmo::IsActive;
        return Json::Write(report);
    }

    Json::Value Iso4ToJson(const iso4 &in m) {
        Json::Value o = Json::Object();
        o["xx"] = m.xx; o["xy"] = m.xy; o["xz"] = m.xz;
        o["yx"] = m.yx; o["yy"] = m.yy; o["yz"] = m.yz;
        o["zx"] = m.zx; o["zy"] = m.zy; o["zz"] = m.zz;
        o["tx"] = m.tx; o["ty"] = m.ty; o["tz"] = m.tz;
        return o;
    }
    // Official starts store spawn on the variant even when SpawnModel is null.
    vec3 GetStartSpawnLocal(CGameCtnBlock@ b) {
        if (b is null) return vec3(16, 2, 16);
        auto biv = Editor::GetBlockInfoVariant(b);
        if (biv is null && b.BlockInfo !is null) @biv = Editor::GetBlockVariantAny(b.BlockInfo);
        if (biv is null) return vec3(16, 2, 16);
        return biv.SpawnTrans;
    }

    }
}
#endif
