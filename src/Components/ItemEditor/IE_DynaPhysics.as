#if SIG_DEVELOPER

// Free rigid-body DynaObject (soccer-ball path). Research:
// research/2026-08-24-DynaObjectConstructors.md
// research/2026-08-24-ItemAndGhostCollisions.md

namespace DynaPhysics {
    const uint ItemTypeEMovable = 0x0C;
    const bool CtorDynamizeOnSpawn = false;
    const bool CtorIsStatic = false;
    const float CtorMass = 10.0;
    const float CtorBreakSpeedKmh = 100.0;
    const float DefaultMass = 10.0;
    const float DefaultBreakSpeedKmh = 200.0;
    const uint16 O_ItemTypeE = GetOffset("CGameItemModel", "ItemTypeE");
    const uint Solid2VisCstDynamic = 2;

    const string NextStep = "Save as a bare DynaObject (no Prefab wrap). ItemTypeE 0x0C is required for collision but vanilla map embed refuses it (\"unhandled type\"). Enable Fixes → Embed ItemTypeE 0x0C, then save the map. Do not Prefab-wrap: GetEntityVisRoot returns 0 and GenerateDestructibleSlots AVs.";

    class Status {
        string entityKind;
        uint itemTypeE;
        bool hasMesh;
        bool hasShape;
        bool hasGmSurf;
        bool isStatic;
        bool dynamizeOnSpawn;
        bool hasKinematicConstraint;
        bool isKinematic;
        bool physicNotCollidable;
        bool entityIsPrefab;
        bool entityIsDyna;
        float mass;
        float breakSpeedKmh;
        string detail;
    }

    class Sources {
        CPlugSolid2Model@ mesh;
        CPlugSurface@ shape;
        CPlugDynaObjectModel@ dyna;
        CPlugPrefab@ prefab;
        string entityKind;
        string fail;
    }

    bool PhysicIdBlocksMotion(EPlugSurfaceMaterialId id) {
        return id == EPlugSurfaceMaterialId::NotCollidable;
    }

    bool FailuresContain(string[]@ fails, const string &in needle) {
        if (fails is null) return false;
        for (uint i = 0; i < fails.Length; i++) {
            if (fails[i].IndexOf(needle) >= 0) return true;
        }
        return false;
    }

    string[]@ RecipeFailures(Status@ st) {
        string[] fails;
        if (st is null) {
            fails.InsertLast("status is null");
            return fails;
        }
        if (st.itemTypeE != ItemTypeEMovable) {
            fails.InsertLast("ItemTypeE is " + Text::Format("0x%02x", st.itemTypeE) + " (need 0x0C)");
        }
        if (!st.hasShape) fails.InsertLast("no DynaShape");
        if (!st.hasGmSurf) fails.InsertLast("DynaShape has no m_GmSurf hull");
        if (st.isStatic) fails.InsertLast("IsStatic (must be 0)");
        if (!st.dynamizeOnSpawn) fails.InsertLast("DynamizeOnSpawn (must be 1)");
        if (st.hasKinematicConstraint) fails.InsertLast("has KinematicConstraint ent (omit it)");
        if (st.isKinematic) fails.InsertLast("IsKinematic (must be 0)");
        if (st.physicNotCollidable) fails.InsertLast("PhysicId is NotCollidable");
        if (st.entityIsPrefab) {
            fails.InsertLast("Prefab EntityModel + ItemTypeE 0x0C: GetEntityVisRoot returns 0, GenerateDestructibleSlots AVs (use bare DynaObject)");
        } else if (!st.entityIsDyna) {
            fails.InsertLast("EntityModel is not a bare CPlugDynaObjectModel");
        }
        return fails;
    }

    uint ReadItemTypeE(CGameItemModel@ im) {
        if (im is null) return 0;
        return Dev::GetOffsetUint32(im, O_ItemTypeE);
    }

    void WriteItemTypeE(CGameItemModel@ im, uint ty) {
        if (im is null) throw("WriteItemTypeE: item is null");
        Dev::SetOffset(im, O_ItemTypeE, ty);
    }

    bool ShapeHasGmSurf(CPlugSurface@ shape) {
        return shape !is null && shape.m_GmSurf !is null;
    }

    bool ShapePhysicNotCollidable(CPlugSurface@ shape) {
        if (shape is null) return false;
        for (uint i = 0; i < shape.MaterialIds.Length; i++) {
            if (PhysicIdBlocksMotion(shape.MaterialIds[i].PhysicId)) return true;
        }
        return false;
    }

    bool PrefabHasKinematicConstraint(CPlugPrefab@ prefab) {
        if (prefab is null) return false;
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            if (cast<NPlugDyna_SKinematicConstraint>(prefab.Ents[i].Model) !is null) return true;
        }
        return false;
    }

    bool PrefabEntIsKinematic(CPlugPrefab@ prefab, uint ix) {
        if (prefab is null || ix >= prefab.Ents.Length) return false;
        auto ents = Dev::GetOffsetNod(prefab, O_PREFAB_ENTS);
        if (ents is null) return false;
        uint64 ptr1 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + O_ENTREF_PARAMS);
        uint64 ptr2 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * ix + O_ENTREF_PARAMS + 0x8);
        if (ptr1 == 0 || ptr2 == 0 || ptr2 % 8 != 0) return false;
        uint clsId = Dev::ReadUInt32(ptr2 + 0x10);
        if (clsId != 0x2f0b6000) return false;
        uint16 offsetIK = GetOffset("NPlugDynaObjectModel_SInstanceParams", "IsKinematic");
        return Dev::ReadUInt32(ptr1 + offsetIK) != 0;
    }

    CPlugDynaObjectModel@ FirstDynaInPrefab(CPlugPrefab@ prefab) {
        if (prefab is null) return null;
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            auto dyna = cast<CPlugDynaObjectModel>(prefab.Ents[i].Model);
            if (dyna !is null) return dyna;
        }
        return null;
    }

    CPlugStaticObjectModel@ FirstStaticInPrefab(CPlugPrefab@ prefab) {
        if (prefab is null) return null;
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            auto so = cast<CPlugStaticObjectModel>(prefab.Ents[i].Model);
            if (so !is null) return so;
        }
        return null;
    }

    void FillFromDyna(Sources@ src, CPlugDynaObjectModel@ dyna) {
        @src.dyna = dyna;
        if (dyna is null) return;
        if (src.mesh is null) @src.mesh = dyna.Mesh;
        if (src.shape is null) {
            @src.shape = dyna.DynaShape;
            if (src.shape is null) @src.shape = dyna.StaticShape;
        }
    }

    void FillFromStatic(Sources@ src, CPlugStaticObjectModel@ so) {
        if (so is null) return;
        if (src.mesh is null) @src.mesh = so.Mesh;
        if (src.shape is null) @src.shape = so.Shape;
    }

    void FillFromEntity(Sources@ src, CMwNod@ nod, uint depth) {
        if (nod is null || depth > 4) return;
        auto dyna = cast<CPlugDynaObjectModel>(nod);
        if (dyna !is null) {
            src.entityKind = "CPlugDynaObjectModel";
            FillFromDyna(src, dyna);
            return;
        }
        auto prefab = cast<CPlugPrefab>(nod);
        if (prefab !is null) {
            src.entityKind = "CPlugPrefab";
            @src.prefab = prefab;
            FillFromDyna(src, FirstDynaInPrefab(prefab));
            if (src.mesh is null || src.shape is null) FillFromStatic(src, FirstStaticInPrefab(prefab));
            return;
        }
        auto common = cast<CGameCommonItemEntityModel>(nod);
        if (common !is null) {
            src.entityKind = "CGameCommonItemEntityModel";
            FillFromStatic(src, cast<CPlugStaticObjectModel>(common.StaticObject));
            return;
        }
        auto so = cast<CPlugStaticObjectModel>(nod);
        if (so !is null) {
            src.entityKind = "CPlugStaticObjectModel";
            FillFromStatic(src, so);
            return;
        }
        auto vl = cast<NPlugItem_SVariantList>(nod);
        if (vl !is null) {
            src.entityKind = "NPlugItem_SVariantList";
            src.fail = "variant lists are not supported — open a single-entity item";
            return;
        }
        auto ty = Reflection::TypeOf(nod);
        src.entityKind = ty is null ? "unknown" : ty.Name;
        src.fail = "unsupported EntityModel " + src.entityKind;
    }

    Sources@ ExtractSources(CGameItemModel@ im) {
        auto src = Sources();
        if (im is null || im.EntityModel is null) {
            src.fail = "no ItemModel.EntityModel";
            src.entityKind = "none";
            return src;
        }
        FillFromEntity(src, im.EntityModel, 0);
        if (src.fail.Length == 0 && src.shape is null) {
            src.fail = "no CPlugSurface to use as DynaShape";
        }
        return src;
    }

    Status@ Inspect(CGameItemModel@ im) {
        auto st = Status();
        if (im is null) {
            st.entityKind = "none";
            st.detail = "no item";
            return st;
        }
        st.itemTypeE = ReadItemTypeE(im);
        auto src = ExtractSources(im);
        st.entityKind = src.entityKind;
        st.hasMesh = src.mesh !is null;
        st.hasShape = src.shape !is null;
        st.hasGmSurf = ShapeHasGmSurf(src.shape);
        st.physicNotCollidable = ShapePhysicNotCollidable(src.shape);
        st.entityIsDyna = src.dyna !is null && src.prefab is null;
        st.entityIsPrefab = src.prefab !is null && src.dyna !is null;
        st.hasKinematicConstraint = PrefabHasKinematicConstraint(src.prefab);
        if (src.prefab !is null) {
            for (uint i = 0; i < src.prefab.Ents.Length; i++) {
                if (cast<CPlugDynaObjectModel>(src.prefab.Ents[i].Model) !is null) {
                    st.isKinematic = PrefabEntIsKinematic(src.prefab, i);
                    break;
                }
            }
        }
        if (src.dyna !is null) {
            st.isStatic = src.dyna.IsStatic;
            st.dynamizeOnSpawn = src.dyna.DynamizeOnSpawn;
            st.mass = src.dyna.Mass;
            st.breakSpeedKmh = src.dyna.BreakSpeedKmh;
        }
        if (src.fail.Length > 0) st.detail = src.fail;
        auto fails = RecipeFailures(st);
        if (fails.Length == 0) {
            st.detail = "recipe ok";
        } else if (st.detail.Length == 0) {
            st.detail = fails[0];
        }
        return st;
    }

    void EnsurePhysicIds(CPlugSurface@ shape, EPlugSurfaceMaterialId id) {
        if (shape is null) return;
        if (shape.MaterialIds.Length == 0 && shape.Materials.Length > 0) {
            shape.TransformMaterialsToMatIds();
        }
        for (uint i = 0; i < shape.MaterialIds.Length; i++) {
            shape.MaterialIds[i].PhysicId = id;
        }
        if (shape.MaterialIds.Length > 0) {
            shape.UpdateSurfMaterialIdsFromMaterialIndexs();
        }
    }

    void ApplyFlags(CPlugDynaObjectModel@ dyna, float mass, float breakSpeedKmh) {
        if (dyna is null) throw("ApplyFlags: dyna is null");
        dyna.IsStatic = false;
        dyna.DynamizeOnSpawn = true;
        dyna.LocAnimIsPhysical = false;
        dyna.Mass = mass;
        dyna.BreakSpeedKmh = breakSpeedKmh;
        if (dyna.LocAnim !is null) {
            ManipPtrs::Replace(dyna, GetOffset(dyna, "LocAnim"), uint64(0), false);
        }
    }

    void AttachMeshShape(CPlugDynaObjectModel@ dyna, CPlugSolid2Model@ mesh, CPlugSurface@ shape) {
        if (dyna is null) throw("AttachMeshShape: dyna is null");
        if (shape is null) throw("AttachMeshShape: shape is null");
        ManipPtrs::Replace(dyna, GetOffset(dyna, "Mesh"), mesh, true);
        ManipPtrs::Replace(dyna, GetOffset(dyna, "DynaShape"), shape, true);
        ManipPtrs::Replace(dyna, GetOffset(dyna, "StaticShape"), shape, true);
        if (dyna.Mesh !is null) dyna.Mesh.MwAddRef();
        if (dyna.DynaShape !is null) dyna.DynaShape.MwAddRef();
        if (dyna.StaticShape !is null) dyna.StaticShape.MwAddRef();
    }

    CPlugPrefab@ WrapDynaInPrefab(CPlugDynaObjectModel@ dyna) {
        if (dyna is null) throw("WrapDynaInPrefab: dyna is null");
        auto prefab = CPlugPrefab();
        if (prefab is null) throw("CPlugPrefab() returned null");
        prefab.MwAddRef();
        auto buf = BufferAlloc::Alloc(1, SZ_ENT_REF);
        buf.WriteToNod(prefab, O_PREFAB_ENTS, 1);
        if (prefab.Ents.Length < 1) throw("prefab Ents stayed empty after alloc");
        MeshDuplication::WriteEntRef(prefab, 0, dyna, quat(1, 0, 0, 0), vec3(), -1);
        return prefab;
    }

    void ApplyToItem(CGameItemModel@ im, float mass, float breakSpeedKmh, EPlugSurfaceMaterialId physicId, bool wrapPrefab) {
        if (im is null) throw("no item");
        auto src = ExtractSources(im);
        if (src.fail.Length > 0) throw(src.fail);
        if (src.shape is null) throw("no CPlugSurface for DynaShape");
        if (!ShapeHasGmSurf(src.shape)) throw("DynaShape m_GmSurf is null — item has no move hull");

        if (src.mesh !is null) src.mesh.MwAddRef();
        src.shape.MwAddRef();

        auto dyna = CPlugDynaObjectModel();
        if (dyna is null) throw("CPlugDynaObjectModel() returned null");
        dyna.MwAddRef();
        ApplyFlags(dyna, mass, breakSpeedKmh);
        AttachMeshShape(dyna, src.mesh, src.shape);

        CMwNod@ entity = dyna;
        if (wrapPrefab) {
            @entity = WrapDynaInPrefab(dyna);
        }
        EnsurePhysicIds(src.shape, physicId);
        entity.MwAddRef();
        ManipPtrs::Replace(im, O_ITEM_MODEL_EntityModel, entity, true);
        WriteItemTypeE(im, ItemTypeEMovable);
        MeshDuplication::ZeroFidsUnknownModelNod(entity);
        if (src.mesh !is null && GetFidFromNod(src.mesh) is null) {
            DPlugSolid2Model(src.mesh).VisCstType = Solid2VisCstDynamic;
        }
    }
}

class DynaPhysicsCapability {
    string lastError;
    string lastOk;
    float mass = DynaPhysics::DefaultMass;
    float breakSpeedKmh = DynaPhysics::DefaultBreakSpeedKmh;
    EPlugSurfaceMaterialId physicId = EPlugSurfaceMaterialId::Rubber;
    bool wrapPrefab = false;

    void Draw() {
        UI::Separator();
        UI::SeparatorText(Icons::Car + " Interactive physics DynaObject");
        UI::TextWrapped("Soccer-ball path: ItemTypeE=0x0C + bare CPlugDynaObjectModel, DynamizeOnSpawn, DynaShape with a real hull, no kinematic constraint. Do not Prefab-wrap: GetEntityVisRoot ignores Prefab on type 0x0C and GenerateDestructibleSlots AVs (LogCrash 0xDCE0C3). Ctor defaults that fail: DynamizeOnSpawn="
            + tostring(DynaPhysics::CtorDynamizeOnSpawn) + ", BreakSpeedKmh="
            + Text::Format("%.0f", DynaPhysics::CtorBreakSpeedKmh)
            + ", Mass=" + Text::Format("%.0f", DynaPhysics::CtorMass)
            + ", IsStatic=" + tostring(DynaPhysics::CtorIsStatic) + ".");

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        if (ieditor is null || ieditor.ItemModel is null) {
            UI::Text("\\$f80No item open.");
            return;
        }
        auto im = ieditor.ItemModel;

        auto st = DynaPhysics::Inspect(im);
        CopiableLabeledValue("EntityModel", st.entityKind);
        CopiableLabeledValue("ItemTypeE", Text::Format("0x%02x", st.itemTypeE));
        UI::Text("mesh " + (st.hasMesh ? "\\$8f8yes" : "\\$f80no")
            + "  shape " + (st.hasShape ? "\\$8f8yes" : "\\$f80no")
            + "  GmSurf " + (st.hasGmSurf ? "\\$8f8yes" : "\\$f80no")
            + "  KC " + (st.hasKinematicConstraint ? "\\$f80yes" : "\\$8f8no"));
        if (st.entityIsDyna || st.entityIsPrefab) {
            UI::Text("IsStatic=" + tostring(st.isStatic)
                + "  DynamizeOnSpawn=" + tostring(st.dynamizeOnSpawn)
                + "  IsKinematic=" + tostring(st.isKinematic)
                + "  Mass=" + Text::Format("%.1f", st.mass)
                + "  Break=" + Text::Format("%.0f", st.breakSpeedKmh));
        }
        auto fails = DynaPhysics::RecipeFailures(st);
        if (fails.Length == 0) {
            UI::Text("\\$8f8recipe ok");
        } else {
            UI::Text("\\$f80recipe gaps:");
            for (uint i = 0; i < fails.Length; i++) {
                UI::Text("  - " + fails[i]);
            }
        }
        if (im.EntityModelEdition !is null) {
            UI::TextWrapped("\\$f80EntityModelEdition is set (crystal). Conversion still writes EntityModel; save/bake after.");
        }

        mass = Math::Clamp(UI::InputFloat("Mass", mass), 1.0, 1000.0);
        breakSpeedKmh = Math::Max(UI::InputFloat("BreakSpeedKmh", breakSpeedKmh), 1.0);
        AddSimpleTooltip("Ctor default 100 destroys the object the first time a race car hits it. 200 is the usual slider max; higher is written raw.");
        physicId = DrawComboEPlugSurfaceMaterialId("DynaShape PhysicId", physicId);
        wrapPrefab = UI::Checkbox("Wrap in CPlugPrefab (crashes 0x0C place)", wrapPrefab);
        AddSimpleTooltip("Leave off. ItemTypeE 0x0C + Prefab: NSceneItem_GetEntityVisRoot returns 0, then GenerateDestructibleSlots IsA on null (LogCrash 0xDCE0C3). Bare DynaObject is the movable slot.");

        if (UI::Button(Icons::Cogs + " Construct interactive DynaObject")) {
            startnew(CoroutineFunc(ApplyAsync));
        }
        AddSimpleTooltip(DynaPhysics::NextStep);

        UI::TextWrapped("\\$888Next: " + DynaPhysics::NextStep);

        if (lastError.Length > 0) UI::TextWrapped("\\$f80" + lastError);
        if (lastOk.Length > 0) UI::TextWrapped("\\$8f8" + lastOk);
    }

    void ApplyAsync() {
        lastError = "";
        lastOk = "";
        try {
            auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
            if (ieditor is null || ieditor.ItemModel is null) throw("no item open");
            DynaPhysics::ApplyToItem(ieditor.ItemModel, mass, breakSpeedKmh, physicId, wrapPrefab);
            lastOk = "Applied. " + DynaPhysics::NextStep;
            NotifySuccess(lastOk);
        } catch {
            lastError = getExceptionInfo();
            NotifyError("Dyna physics construct failed: " + lastError);
        }
    }
}

#endif
