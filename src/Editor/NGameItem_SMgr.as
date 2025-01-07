namespace Editor {
    // ix 46
    const uint16 O_GAMESCENE_NGameItem_SMgr_Offset = 0x180;

    NGameItem_SMgr@ GetNGameItem_SMgr() {
        throw("Unused atm. Remove this line to enable.");
        auto mgr = FindManager(Reflection::GetType("NGameItem_SMgr").ID);
        if (mgr is null) return null;
        if (mgr.ptr == 0) return null;
        auto mgrNwp = NodWithPtr(Dev_GetNodFromPointer(mgr.ptr));
        // auto @nGameItemMgr = Dev::GetOffsetNod(scene, O_GAMESCENE_NGameItem_SMgr_Offset);
        return Dev::ForceCast<NGameItem_SMgr@>(mgrNwp.nod).Get();
        return null;
    }

    uint64 GetNGameItem_SMgr_Ptr(ISceneVis@ scene) {
        if (scene is null) return 0;
        // We don't actually use the scene in this case. Maybe should refactor.
        auto mgr = FindManager(Reflection::GetType("NGameItem_SMgr").ID);
        if (mgr is null) return 0;
        return mgr.ptr;
    }

    RawBuffer@ Get_NGameItem_SMgr_Buffer() {
        auto app = GetApp();
        auto scene = app.GameScene;
        auto editor = cast<CGameCtnEditorFree>(app.Editor);
        if (scene is null || editor is null) return null;
        // if (!Editor::IsInAnyItemPlacementMode(editor)) return null;
        auto gameItemSMgrPtr = GetNGameItem_SMgr_Ptr(scene);
        if (gameItemSMgrPtr == 0) return null;
        return RawBuffer(gameItemSMgrPtr + 0x38, 0x130, false);
    }

    AABB@ GetSelectedItemAABB() {
        auto buf = Get_NGameItem_SMgr_Buffer();
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
        auto midPoint = last.GetVec3(0xFC);
        auto halfDiag = last.GetVec3(0x108);
        return AABB(last.GetIso4(0x8), midPoint, halfDiag);
    }

    AABB@ GetItemAABB(CGameItemModel@ model) {
        if (model is null) return null;
        auto modelPtr = Dev_GetPointerForNod(model);
        auto buf = Get_NGameItem_SMgr_Buffer();
        RawBufferElem@ el;
        for (int ix = buf.Length - 1; ix >= 0; ix--) {
            @el = buf.GetElement(ix, el);
            if (el.GetUint64(0) == modelPtr) {
                auto hasModel = el.GetBool(0xF8);
                if (!hasModel) continue;
                auto midPoint = el.GetVec3(0xFC);
                auto halfDiag = el.GetVec3(0x108);
                return AABB(el.GetIso4(0x8), midPoint, halfDiag);
            }
        }
        return null;
    }

    class AABB {
        vec3 midPoint;
        vec3 halfDiag;
        mat4 mat;

        mat4 rot;
        mat4 invRot;

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

        void InvertRotation() {
            vec3 _pos = this.pos;
            rot = mat4::Translate(_pos * -1.) * mat;
            invRot = mat4::Inverse(rot);
            mat = mat4::Translate(_pos) * invRot;
        }

        string ToString() {
            return "AABB: mp = " + midPoint.ToString() + " / hd = " + halfDiag.ToString();
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
    // 0x118 -> CPlugPrefab




    // 0x48: buffer of indexes?
}
