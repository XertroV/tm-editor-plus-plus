
class IE_AdvancedTab : Tab {
    bool m_PushMatMod = true;

    IE_AdvancedTab(TabGroup@ p) {
        super(p, "Advanced", Icons::ExclamationTriangle + Icons::Cogs);
    }

    void DrawInner() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;

        if (UI::Button("Open Item")) {
            Editor::DoItemEditorAction(ieditor, Editor::ItemEditorAction::OpenItem);
        }
        if (UI::Button("Save and Reopen Item")) {
            startnew(ItemEditor::SaveAndReloadItem);
        }

        UI::Separator();

        if (UI::Button("Add empty PodiumListClip")) {
            @cast<CGameEditorItem>(GetApp().Editor).ItemModel.PodiumClipList = CPlugMediaClipList();
        }

        UI::Separator();

        if (UI::Button("Change all physics to non-collidable")) {
            SetAllItemPhysicsNoCollide();
        }

        if (UI::Button("Load shape from file and set (For blender exports only)")) {
            if (IE_LoadAndSetCurrentItemsShape()) {
                NotifySuccess("Done, please save the item");
            } else {
                NotifyError("Failed to replace shape on item");
            }
        }

        UI::Separator();

        m_PushMatMod = UI::Checkbox("Apply Materials Modifier before Zeroing?", m_PushMatMod);

        if (UI::Button("Zero ItemModel Fids")) {
            try {
                MeshDuplication::ZeroFidsOfItemModel_Wrapper(im, m_PushMatMod);
                NotifySuccess("Zeroed ItemModel FIDs");
            } catch {
                NotifyError("Exception zeroing fids: " + getExceptionInfo());
            }
        }
        if (UI::Button("Zero ItemModel.EntityModel Fids")) {
            try {
                MeshDuplication::ZeroFidsUnknownModelNod(im.EntityModel);
                NotifySuccess("Zeroed ItemModel.EntityModel FIDs");
            } catch {
                NotifyError("Exception zeroing fids: " + getExceptionInfo());
            }
        }

        UI::Separator();

        UI::Text("Zeroed Fids / Manipulated Pointers: " + ManipPtrs::recentlyModifiedPtrs.Length);
        if (UI::Button("Unzero Fids & Undo ptr manip")) {
            ManipPtrs::RunUnzero();
        }
    }
}

bool IE_LoadAndSetCurrentItemsShape() {
    auto shape = IE_LoadCurrentItemsShape();
    if (shape is null) return false;
    try {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;
        auto staticObj = cast<CPlugStaticObjectModel>(cast<CGameCommonItemEntityModel>(im.EntityModel).StaticObject);
        ManipPtrs::ZeroFid(shape);
        ManipPtrs::Replace(staticObj, GetOffset(staticObj, "Shape"), shape, true);
        // and more refs so it isn't unloaded
        if (staticObj.Shape !is null) staticObj.Shape.MwAddRef();
        if (staticObj.Shape !is null) staticObj.Shape.MwAddRef();
        // turn off shape generation if it's on
        Dev::SetOffset(staticObj, O_STATICOBJMODEL_GENSHAPE, uint32(0));
        return true;
    } catch {
        NotifyWarning("Error: " + getExceptionInfo());
    }
    return false;
}

CPlugSurface@ IE_LoadCurrentItemsShape() {
    try {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto im = ieditor.ItemModel;
        string path = im.IdName;
        if (path == "Unassigned") throw("Cannot do this for an item without a path");
        auto fid = cast<CSystemFidFile>(GetFidFromNod(im));
        if (fid is null) throw("fid null");
        auto parent = fid.ParentFolder;
        string fname = fid.FileName;
        string sname = fname.Replace(".Item.Gbx", ".Shape.Gbx");
        auto shapeFid = Fids::GetFidsFile(parent, sname);
        if (shapeFid.Nod is null) Fids::Preload(shapeFid);
        if (shapeFid.Nod is null) throw("shape fid nod null");
        auto shape = cast<CPlugSurface>(shapeFid.Nod);
        if (shape is null) throw("shape file is not a CPlugSurface");
        return shape;
    } catch {
        NotifyWarning("Something went wrong: " + getExceptionInfo());
    }
    return null;
}

void SetAllItemPhysicsNoCollide(CGameItemModel@ im = null) {
    if (im is null) {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        @im = ieditor.ItemModel;
    }
    if (im.EntityModelEdition !is null) {
        NotifyWarning("make noncollidable: Items with an EntityModelEdition probably won't work.");
    }
    try {
        auto staticObj = cast<CPlugStaticObjectModel>(cast<CGameCommonItemEntityModel>(im.EntityModel).StaticObject);
        if (staticObj !is null) {
            if (staticObj.Shape !is null) {
                if (staticObj.Shape.MaterialIds.Length == 0 && staticObj.Shape.Materials.Length > 0) {
                    staticObj.Shape.TransformMaterialsToMatIds();
                }
                for (uint i = 0; i < staticObj.Shape.MaterialIds.Length; i++) {
                    staticObj.Shape.MaterialIds[i].PhysicId = EPlugSurfaceMaterialId::NotCollidable;
                }
                staticObj.Shape.UpdateSurfMaterialIdsFromMaterialIndexs();
            }
            if (staticObj.Mesh !is null) {
                auto mesh = Solid2Model(staticObj.Mesh);
                mesh.SetAllUserMatPhysics(EPlugSurfaceMaterialId::NotCollidable);
                mesh.SetAllCustomMatPhysics(EPlugSurfaceMaterialId::NotCollidable);
            }
            NotifySuccess("Updated all physics to non-collidable");
        } else {
            NotifyWarning("Only CPlugStaticObjectModel atm");
        }
    } catch {
        NotifyWarning("Something went wrong: " + getExceptionInfo());
    }
}


class Solid2Model {
    CPlugSolid2Model@ s2m;
    Solid2Model(CPlugSolid2Model@ s2m) {
        @this.s2m = s2m;
    }

    CPlugMaterialUserInst@[]@ get_UserMaterials() {
        CPlugMaterialUserInst@[] ret;
        uint len = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_USERMAT_BUF + 0x8);
        auto buf = Dev::GetOffsetNod(s2m, O_SOLID2MODEL_USERMAT_BUF);
        uint elSize = 0x18;
        uint16 elOffset = 0x0;
        for (uint i = 0; i < len; i++) {
            ret.InsertLast(cast<CPlugMaterialUserInst>(Dev::GetOffsetNod(buf, elSize * i + elOffset)));
        }
        return ret;
    }

    CPlugMaterial@[]@ get_CustomMaterials() {
        CPlugMaterial@[] ret;
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
