// Issue #35: vehicle preview while gizmoing blocks/items with a spawn point.
// Spawn source: CGameCtnBlockInfoVariant.SpawnTrans (+SpawnPitch/Yaw/Roll) for blocks,
// CGameCommonItemEntityModel.SpawnLoc for items, item origin for gate-style items.
// Mechanics: the keep-vehicle patch (VehicleKeepState) parks a test-mode vehicle vis
// at the spawn pose; Follow() re-poses it from the gizmo cursor every tick.
namespace Editor {
namespace VehiclePreview {
    bool g_haveSpawnLocal = false;
    mat4 g_spawnLocal = mat4::Identity();

    // Free-block cursor Y is stored on CGameCursorBlock (default 0.25) and is not
    // reliably zeroable. Match it so the car sits with the preview, not SpawnTrans.
    float FreeBlockCursorLocalUp() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null || editor.Cursor is null) return 0.25;
        return Dev::GetOffsetFloat(editor.Cursor, O_BLOCKCURSOR_FreeBlockCursorOffset);
    }

    mat4 SpawnLocalMatFromVariant(CGameCtnBlockInfoVariant@ biv) {
        float up = FreeBlockCursorLocalUp();
        if (biv is null) return mat4::Translate(vec3(16, 2 + up, 16));
        return mat4::Translate(biv.SpawnTrans + vec3(0, up, 0))
            * EulerToMat(vec3(biv.SpawnPitch, biv.SpawnYaw, biv.SpawnRoll));
    }

    mat4 SpawnLocalMat(CGameCtnBlock@ b) {
        if (b is null) return SpawnLocalMatFromVariant(null);
        auto biv = Editor::GetBlockInfoVariant(b);
        if (biv is null && b.BlockInfo !is null) @biv = Editor::GetBlockVariantAny(b.BlockInfo);
        return SpawnLocalMatFromVariant(biv);
    }

    bool HasSpawn(CGameCtnBlockInfo@ bi) {
        if (bi is null) return false;
        auto wt = bi.EdWaypointType;
        // Finish-only is not a vehicle spawn; multilap StartFinish is.
        if (wt == CGameCtnBlockInfo::EWayPointType::Finish) return false;
        // No-respawn (EdNoRespawn): flying respawn only — test mode doesn't snap,
        // so there is no meaningful spawn pose to preview. Custom blocks inherit
        // this flag from their donor; authors must clear it to get a SpawnTrans car.
        if (bi.EdNoRespawn) return false;
        if (wt == CGameCtnBlockInfo::EWayPointType::Start
            || wt == CGameCtnBlockInfo::EWayPointType::StartFinish
            || wt == CGameCtnBlockInfo::EWayPointType::Checkpoint) return true;
        auto biv = Editor::GetBlockVariantAny(bi);
        if (biv is null) return false;
        if (biv.SpawnModel !is null) return true;
        return biv.SpawnTrans.LengthSquared() > 0.0001;
    }

    mat4 SpawnLocalMat(CGameCtnBlockInfo@ bi) {
        if (bi is null) return SpawnLocalMatFromVariant(null);
        return SpawnLocalMatFromVariant(Editor::GetBlockVariantAny(bi));
    }

    bool HasSpawn(CGameItemModel@ im) {
        if (im is null) return false;
        auto wt = im.WaypointType;
        if (wt == EGameItemWaypointType::Start
            || wt == EGameItemWaypointType::StartFinish
            || wt == EGameItemWaypointType::Checkpoint) return true;
        if (wt == EGameItemWaypointType::Finish) return false;
        auto cie = cast<CGameCommonItemEntityModel>(im.EntityModel);
        if (cie is null) return false;
        vec3 t = vec3(cie.SpawnLoc.tx, cie.SpawnLoc.ty, cie.SpawnLoc.tz);
        return t.LengthSquared() > 0.0001;
    }

    // Official gate items have no EntityModel; the vehicle spawns at the item origin.
    mat4 SpawnLocalMat(CGameItemModel@ im) {
        if (im is null) return mat4::Identity();
        auto cie = cast<CGameCommonItemEntityModel>(im.EntityModel);
        if (cie is null) return mat4::Identity();
        return mat4(cie.SpawnLoc);
    }


    // Most recently added vis — test mode appends, so the kept car is last.
    CSceneVehicleVis@ GetMostRecentVis() {
        auto scene = GetApp().GameScene;
        if (scene is null) return null;
        auto viss = VehicleState::GetAllVis(scene);
        for (int i = int(viss.Length) - 1; i >= 0; i--) {
            if (viss[i] !is null && viss[i].AsyncState !is null) return viss[i];
        }
        return null;
    }

    // Nearest non-hidden vis to nearPos; ties resolve to the most recent.
    CSceneVehicleVis@ PickPreviewVis(vec3 nearPos) {
        auto scene = GetApp().GameScene;
        if (scene is null) return null;
        auto viss = VehicleState::GetAllVis(scene);
        CSceneVehicleVis@ best = null;
        float bestD = 1e20;
        for (int i = int(viss.Length) - 1; i >= 0; i--) {
            auto vis = viss[i];
            if (vis is null || vis.AsyncState is null) continue;
            auto mat = Dev::GetOffsetIso4(vis.AsyncState, O_VISSTATE_Mat);
            if (mat.ty < -1000.0) continue;
            float d = (vec3(mat.tx, mat.ty, mat.tz) - nearPos).LengthSquared();
            if (d <= bestD) {
                bestD = d;
                @best = vis;
            }
        }
        return best;
    }

    void WriteVisWorld(const mat4 &in world) {
        auto vis = PickPreviewVis(vec3(world.tx, world.ty, world.tz));
        if (vis is null || vis.AsyncState is null) return;
        Dev::SetOffset(vis.AsyncState, O_VISSTATE_Mat, iso4(world));
    }

    void Follow(const mat4 &in cursorMat) {
        if (!S_Gizmo_ShowVehiclePreview) return;
        if (!g_haveSpawnLocal) return;
        // Cursor rot is Inverse(blockRot) (AABB / SetAllCursorMat). SpawnTrans is in
        // block-local (GetBlockMatrix) space. Rotation follows the cursor; translation
        // uses Inverse(cursorRot)*SpawnTrans so world pos is blockOrigin + blockRot*spawn.
        vec3 cpos = vec3(cursorMat.tx, cursorMat.ty, cursorMat.tz);
        mat4 crot = mat4::Translate(cpos * -1.) * cursorMat;
        vec3 spawn = vec3(g_spawnLocal.tx, g_spawnLocal.ty, g_spawnLocal.tz);
        mat4 spawnRot = mat4::Translate(spawn * -1.) * g_spawnLocal;
        vec3 visPos = cpos + (mat4::Inverse(crot) * spawn).xyz;
        WriteVisWorld(mat4::Translate(visPos) * crot * spawnRot);
    }

    void HideAllVis() {
        auto scene = GetApp().GameScene;
        if (scene is null) return;
        auto viss = VehicleState::GetAllVis(scene);
        iso4 hidden = iso4(mat4::Translate(vec3(0, -10000, 0)));
        for (uint i = 0; i < viss.Length; i++) {
            if (viss[i] is null || viss[i].AsyncState is null) continue;
            Dev::SetOffset(viss[i].AsyncState, O_VISSTATE_Mat, hidden);
        }
    }

    void Clear() {
        g_haveSpawnLocal = false;
        VehicleKeepState::Applied = false;
        HideAllVis();
    }

    bool ParkAt(const mat4 &in spawnWorld) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return false;
        VehicleKeepState::Applied = true;
        HideAllVis();
        vec3 guess = vec3(spawnWorld.tx, spawnWorld.ty, spawnWorld.tz);
        dev_trace("VP: ParkAt enter test @ " + guess.ToString());

        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::Test);
        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
        Editor::SetAllCursorPos(guess);
        for (uint i = 0; i < 8; i++) yield();

        auto vis = PickPreviewVis(guess);
        if (vis is null) {
            @vis = GetMostRecentVis();
            dev_trace("VP: ParkAt pick=null, recent=" + (vis is null ? "null" : "found"));
        } else {
            dev_trace("VP: ParkAt pick found vis");
        }
        if (vis !is null && vis.AsyncState !is null) {
            Dev::SetOffset(vis.AsyncState, O_VISSTATE_Mat, iso4(spawnWorld));
        }

        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Place);
        return true;
    }

    bool EnsureAt(const mat4 &in spawnWorld, const mat4 &in spawnLocal) {
        g_spawnLocal = spawnLocal;
        g_haveSpawnLocal = true;
        return ParkAt(spawnWorld);
    }

    bool EnsureForBlock(CGameCtnBlock@ b) {
        dev_trace("VP: EnsureForBlock " + (b is null || b.BlockInfo is null ? "null" : b.BlockInfo.IdName));
        if (b is null || b.BlockInfo is null || !HasSpawn(b.BlockInfo)) { dev_trace("VP: no spawn -> skip"); return false; }
        auto local = SpawnLocalMat(b);
        g_spawnLocal = local;
        g_haveSpawnLocal = true;
        bool ok = ParkAt(Editor::GetBlockMatrix(b) * local);
        dev_trace("VP: ParkAt -> " + ok);
        return ok;
    }
}
}
