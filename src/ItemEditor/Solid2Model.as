namespace ItemEditor {
    ISolid2Model@ WrapSolid2Model(CPlugSolid2Model@ s2m) {
        return Solid2Model(s2m);
    }

    class Solid2Model : ISolid2Model {
        CPlugSolid2Model@ s2m;

        Solid2Model(CPlugSolid2Model@ s2m) {
            if (s2m is null) throw("CPlugSolid2Model null");
            @this.s2m = s2m;
            s2m.MwAddRef();
        }

        ~Solid2Model() {
            if (s2m !is null) s2m.MwRelease();
        }

        CPlugSolid2Model@ get_S2m() {
            return s2m;
        }

        array<CPlugMaterialUserInst@>@ get_UserMaterials() {
            array<CPlugMaterialUserInst@> ret;
            uint len = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_USERMAT_BUF + 0x8);
            auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_USERMAT_BUF);
            uint elSize = 0x18;
            uint16 elOffset = 0x0;
            for (uint i = 0; i < len; i++) {
                ret.InsertLast(cast<CPlugMaterialUserInst>(Dev::GetOffsetNod(buf, elSize * i + elOffset)));
            }
            return ret;
        }

        array<CPlugMaterial@>@ get_CustomMaterials() {
            array<CPlugMaterial@> ret;
            uint len = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_CUSTMAT_BUF + 0x8);
            auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_CUSTMAT_BUF);
            uint elSize = 0x8;
            uint16 elOffset = 0x0;
            for (uint i = 0; i < len; i++) {
                ret.InsertLast(cast<CPlugMaterial>(Dev::GetOffsetNod(buf, elSize * i + elOffset)));
            }
            return ret;
        }

        void SetAllUserMatPhysics(EPlugSurfaceMaterialId id) {
            auto mats = UserMaterials;
            for (uint i = 0; i < mats.Length; i++) {
                Dev::SetOffset(mats[i], O_USERMATINST_PHYSID, uint8(id));
            }
        }

        void SetAllCustomMatPhysics(EPlugSurfaceMaterialId id) {
            auto mats = CustomMaterials;
            for (uint i = 0; i < mats.Length; i++) {
                if (GetFidFromNod(mats[i]) is null) {
                    Dev::SetOffset(mats[i], O_MATERIAL_PHYSICS_ID, uint8(id));
                } else {
                    NotifyWarning("Skipping material with FID at " + i);
                }
            }
        }
    }
}
