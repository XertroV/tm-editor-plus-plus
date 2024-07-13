namespace Editor {
    // ix 46
    const uint16 O_GAMESCENE_NGameItem_SMgr_Offset = 0x180;

    NGameItem_SMgr@ GetNGameItem_SMgr(ISceneVis@ scene) {
        if (scene is null) return null;
        auto @nGameItemMgr = Dev::GetOffsetNod(scene, O_GAMESCENE_NGameItem_SMgr_Offset);
        if (nGameItemMgr !is null) Dev::ForceCast<NGameItem_SMgr@>(nGameItemMgr).Get();
        return null;
    }

    uint64 GetNGameItem_SMgr_Ptr(ISceneVis@ scene) {
        if (scene is null) return 0;
        return Dev::GetOffsetUint64(scene, O_GAMESCENE_NGameItem_SMgr_Offset);
    }

    AABB@ GetSelectedItemAABB() {
        auto app = GetApp();
        auto scene = app.GameScene;
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (scene is null || editor is null) return null;
        if (!Editor::IsInAnyItemPlacementMode(editor)) return null;
        auto gameItemSMgrPtr = GetNGameItem_SMgr_Ptr(scene);
        if (gameItemSMgrPtr == 0) return null;
        auto buf = RawBuffer(gameItemSMgrPtr + 0x38, 0x130, false);
        auto len = buf.Length;
        // the cursor item is usually the last in the buffer, but not if you've placed an item of that type recently
        while(len > 0) {
            auto item = buf[len - 1];
            // 0x98 - class ID of NGamePrefabPhy_SInst?
            // 0x9C - 0xFFFFFFFF for item in cursor; counter/ix otherwise
            // 0xA0 - 0 for item in cursor; counter/ix otherwise
            if (item.GetUint32(0x98) == 0 &&
                item.GetInt32(0x9C) == -1 &&
                item.GetInt32(0xA0) == 0) break;
            len--;
        }
        if (len == 0) return null;
        auto last = buf[len - 1];
        auto hasModel = last.GetBool(0xF8);
        if (!hasModel) return null;
        // auto midPoint = last.GetVec3(0xFC);
        // auto halfDiag = last.GetVec3(0x108);
        return AABB(last.GetIso4(0x8), last.GetVec3(0xFC), last.GetVec3(0x108));
    }

    class AABB {
        vec3 midPoint;
        vec3 halfDiag;
        mat4 mat;
        AABB(const iso4 &in mat, const vec3 &in midPoint, const vec3 &in halfDiag) {
            this.mat = mat;
            this.midPoint = midPoint;
            this.halfDiag = halfDiag;
        }
        AABB(const mat4 &in mat, const vec3 &in midPoint, const vec3 &in halfDiag) {
            this.mat = mat;
            this.midPoint = midPoint;
            this.halfDiag = halfDiag;
        }

        vec3 get_pos() {
            return vec3(mat.tx, mat.ty, mat.tz);
        }

        void set_pos(const vec3 &in newPos) {
            mat = mat4::Translate(newPos) * mat4::Translate(this.pos * -1.) * mat;
        }

        vec3 get_min() {
            return midPoint - halfDiag;
        }

        vec3 get_max() {
            return midPoint + halfDiag;
        }
    }

    // buffer of items in map: 0x38
    // element size: 0x130 (not behind pointer)
    // 0x0 => CGameItemModel
    // 0x8 => iso4
    // 0x2c => pos
    // 0x70 -> CGameCtnAnchoredObject
    // 0xD0 => cplugprefab
    // 0xf8 -> bool HasBoundingBox (or HasMesh or something)
    // 0xfc -> vec3 midPoint
    // 0x108 -> vec3 halfDiagonal
}
