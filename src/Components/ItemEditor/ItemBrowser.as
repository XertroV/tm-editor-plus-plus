const uint16 IM_GameSkinOffset = 0xA0;
const uint16 IM_AuthorOffset = 0xA0;

class ItemModel {
    CGameItemModel@ item;
    bool drawProperties;
    bool isEditable;
    ItemModel(CGameItemModel@ item, bool drawProperties = true, bool isEditable = false) {
        @this.item = item;
        item.MwAddRef();
        this.drawProperties = drawProperties;
        this.isEditable = isEditable;
    }

    ~ItemModel() {
        item.MwRelease();
    }

    CPlugGameSkin@ get_Skin() {
        return cast<CPlugGameSkin>(Dev::GetOffsetNod(item, IM_GameSkinOffset));
    }

    void DrawTree() {
        // UI::TreeNodeFlags::OpenOnArrow
        if (UI::TreeNode(item.IdName, UI::TreeNodeFlags::DefaultOpen)) {
#if SIG_DEVELOPER
            if (UX::SmallButton(Icons::Cube + " Explore ItemModel")) {
                ExploreNod(item);
            }
            UI::SameLine();
            CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(item)));
#endif
            ClickableLabel("Author", item.Author.GetName());
            DrawSkin();
            DrawEMEdition();
            DrawEMTree();
            UI::TreePop();
        }
    }

    void DrawSkin() {
        auto skin = cast<CPlugGameSkin>(Dev::GetOffsetNod(item, 0xA0));
        if (skin !is null) {
            auto el = ItemModelTreeElement(null, -1, skin, "GameSkin", drawProperties, O_ITEM_MODEL_SKIN, isEditable);
            el.Draw();
        }
    }

    void DrawEMEdition() {
        auto eme = item.EntityModelEdition;
        if (eme is null) {
            UI::Text("No EntityModelEdition");
            return;
        }

        if (isEditable) {
            if (UX::SmallButton("Nullify EntityModelEdition")) {
                @item.EntityModelEdition = null;
            }
            AddSimpleTooltip("After nullifying, the item will fail to save if any CPlugSurfaces have materials -- to fix click TransformMaterialsToMatIds.");
        }

        auto emeCommon = cast<CGameCommonItemEntityModelEdition>(eme);
        auto emeBlock = cast<CGameBlockItem>(eme);
        bool isCrystal = emeCommon !is null && emeCommon.MeshCrystal !is null;

        if (emeCommon !is null) {
            UI::Text("Is a Crystal? " + isCrystal);
            if (isEditable && isCrystal) {
                UI::SameLine();
                if (UX::SmallButton("Nullify")) {
                    @emeCommon.MeshCrystal = null;
                }
            }
        } else if (emeBlock !is null) {
            Draw_EME_BlockItem(emeBlock);
        } else {
            UI::Text("EntityModelEdition is an unknown type: " + UnkType(eme));
            return;
        }
        // UI::Text("Todo: more?");
    }

    void DrawEMTree() {
        ItemModelTreeElement(null, -1, item.EntityModel, "EntityModel", drawProperties, GetOffset(item, "EntityModel"), isEditable).Draw();
    }

    void Draw_EME_BlockItem(CGameBlockItem@ eme) {
        ItemModelTreeElement(null, -1, eme, "EntityModelEdition", drawProperties, GetOffset(item, "EntityModelEdition"), isEditable).Draw();
    }
}

class ItemModelTreeElement {
    ItemModelTreeElement@ parent;
    int parentIx;
    CMwNod@ nod;
    uint16 nodOffset = 0xFFFF;
    string name;
    bool drawProperties = true;
    // set to true by subclasses to disable some things.
    bool isPicker = false;
    uint classId = 0x1001000; // CMwNod

    bool isEditable = false;

    int currentIndex = -1;
    bool hasElements = false;

    CPlugStaticObjectModel@ staticObj;
    CPlugPrefab@ prefab;
    NPlugItem_SVariantList@ varList;
    CPlugFxSystem@ fxSys;
    CPlugVegetTreeModel@ vegetTree;
    CPlugDynaObjectModel@ dynaObject;
    NPlugDyna_SKinematicConstraint@ kenematicConstraint;
    CPlugSpawnModel@ spawnModel;
    CPlugEditorHelper@ editorHelper;
    NPlugTrigger_SWaypoint@ sWaypoint;
    NPlugTrigger_SSpecial@ sSpecial;
    CGameCommonItemEntityModel@ cieModel;
    CPlugSurface@ surf;
    CPlugSolid2Model@ s2m;
    CPlugGameSkin@ skin;
    CPlugMaterial@ mat;
    CPlugLight@ light;
    CPlugLightUserModel@ userLight;
    CPlugMaterialUserInst@ userMat;
    GxLight@ gxLight;
    CGameItemModel@ itemModel;
    CSystemPackDesc@ sysPackDesc;
    CGameBlockItem@ blockItem;
    CPlugCrystal@ crystal;
    CGameCtnBlockInfo@ blockInfo;
    CGameCtnBlockInfoVariant@ infoVar;
    CSystemFidFile@ fid;
    CGameCtnBlockInfoMobil@ blockInfoMobil;
    CGameCtnBlockUnitInfo@ unitInfo;

    ItemModelTreeElement(ItemModelTreeElement@ parent, int parentIx, CMwNod@ nod, const string &in name, bool drawProperties = true, uint16 nodOffset = 0xFFFF, bool isEditable = false) {
        @this.parent = parent;
        this.parentIx = parentIx;
        @this.nod = nod;
        this.nodOffset = nodOffset;
        this.name = name;
        this.drawProperties = drawProperties;
        this.isEditable = isEditable;
        @this.itemModel = cast<CGameItemModel>(nod);
        @this.staticObj = cast<CPlugStaticObjectModel>(nod);
        @this.prefab = cast<CPlugPrefab>(nod);
        @this.varList = cast<NPlugItem_SVariantList>(nod);
        @this.fxSys = cast<CPlugFxSystem>(nod);
        @this.vegetTree = cast<CPlugVegetTreeModel>(nod);
        @this.dynaObject = cast<CPlugDynaObjectModel>(nod);
        @this.kenematicConstraint = cast<NPlugDyna_SKinematicConstraint>(nod);
        @this.spawnModel = cast<CPlugSpawnModel>(nod);
        @this.editorHelper = cast<CPlugEditorHelper>(nod);
        @this.sWaypoint = cast<NPlugTrigger_SWaypoint>(nod);
        @this.sSpecial = cast<NPlugTrigger_SSpecial>(nod);
        @this.cieModel = cast<CGameCommonItemEntityModel>(nod);
        @this.surf = cast<CPlugSurface>(nod);
        @this.s2m = cast<CPlugSolid2Model>(nod);
        @this.skin = cast<CPlugGameSkin>(nod);
        @this.mat = cast<CPlugMaterial>(nod);
        @this.light = cast<CPlugLight>(nod);
        @this.userLight = cast<CPlugLightUserModel>(nod);
        @this.userMat = cast<CPlugMaterialUserInst>(nod);
        @this.gxLight = cast<GxLight>(nod);
        @this.sysPackDesc = cast<CSystemPackDesc>(nod);
        @this.blockItem = cast<CGameBlockItem>(nod);
        @this.crystal = cast<CPlugCrystal>(nod);
        @this.blockInfo = cast<CGameCtnBlockInfo>(nod);
        @this.infoVar = cast<CGameCtnBlockInfoVariant>(nod);
        @this.fid = cast<CSystemFidFile>(nod);
        @this.blockInfoMobil = cast<CGameCtnBlockInfoMobil>(nod);
        @this.unitInfo = cast<CGameCtnBlockUnitInfo>(nod);
        UpdateNodOffset();
        if (nod is null) return;
        classId = Reflection::TypeOf(nod).ID;
    }

    protected void UpdateNodOffset() {
        if (nodOffset < 0xFFFF) return;
        if (parent !is null and parentIx < 0) {
            this.nodOffset = GetOffset(parent.nod, name);
        } else if (parent !is null) {
            if (cast<NPlugItem_SVariantList>(parent.nod) !is null) {
                nodOffset = GetOffset("NPlugItem_SVariant", name);
            } else if (cast<CPlugPrefab>(parent.nod) !is null) {
                nodOffset = GetOffset("NPlugPrefab_SEntRef", name);
            } else {
                NotifyError("unknown parent type and parentIx >= 0");
                NotifyError("parent type: " + UnkType(parent.nod));
                throw("unknown parent type and parentIx >= 0");
            }
        }
    }

    // to be overloaded
    void DrawPickable() {
    }

    // can be overloaded
    void MkAndDrawChildNode(CMwNod@ nod, const string &in name) {
        ItemModelTreeElement(this, currentIndex, nod, name, drawProperties, 0xFFFF, isEditable).Draw();
    }
    void MkAndDrawChildNode(CMwNod@ nod, uint16 offset, const string &in name) {
        ItemModelTreeElement(this, currentIndex, nod, name, drawProperties, offset, isEditable).Draw();
    }


    void ZeroFids() {
        MeshDuplication::ZeroFidsUnknownModelNod(nod);
    }

    void Draw() {
        currentIndex = -1;
        if (nod is null) {
            UI::Text(name + " :: \\$f8fnull");
#if SIG_DEVELOPER
            UI::SameLine();
            UI::TextDisabled(Text::Format("0x%03x", nodOffset));
#endif
            DrawPickable();
        } else if (staticObj !is null) {
            Draw(staticObj);
        } else if (itemModel !is null) {
            Draw(itemModel);
        } else if (prefab !is null) {
            Draw(prefab);
        } else if (varList !is null) {
            Draw(varList);
        } else if (fxSys !is null) {
            Draw(fxSys);
        } else if (vegetTree !is null) {
            Draw(vegetTree);
        } else if (dynaObject !is null) {
            Draw(dynaObject);
        } else if (kenematicConstraint !is null) {
            Draw(kenematicConstraint);
        } else if (spawnModel !is null) {
            Draw(spawnModel);
        } else if (editorHelper !is null) {
            Draw(editorHelper);
        } else if (sWaypoint !is null) {
            Draw(sWaypoint);
        } else if (sSpecial !is null) {
            Draw(sSpecial);
        } else if (cieModel !is null) {
            Draw(cieModel);
        } else if (s2m !is null) {
            Draw(s2m);
        } else if (surf !is null) {
            Draw(surf);
        } else if (skin !is null) {
            Draw(skin);
        } else if (userLight !is null) {
            Draw(userLight);
        } else if (userMat !is null) {
            Draw(userMat);
        } else if (mat !is null) {
            Draw(mat);
        } else if (light !is null) {
            Draw(light);
        } else if (gxLight !is null) {
            Draw(gxLight);
        } else if (sysPackDesc !is null) {
            Draw(sysPackDesc);
        } else if (blockItem !is null) {
            Draw(blockItem);
        } else if (crystal !is null) {
            Draw(crystal);
        } else if (blockInfo !is null) {
            Draw(blockInfo);
        } else if (infoVar !is null) {
            Draw(infoVar);
        } else if (fid !is null) {
            Draw(fid);
        } else if (blockInfoMobil !is null) {
            Draw(blockInfoMobil);
        } else if (unitInfo !is null) {
            Draw(unitInfo);
        } else {
            UI::Text("Unknown nod of type: " + UnkType(nod));
        }
    }

    void Draw(CGameItemModel@ itemModel) {
        if (StartTreeNode(name + " ::\\$f8f CGameItemModel", UI::TreeNodeFlags::DefaultOpen)) {
            MkAndDrawChildNode(itemModel.EntityModel, "EntityModel");
            EndTreeNode();
        }
    }

    void Draw(CGameCtnBlockInfo@ blockInfo) {
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockInfo", UI::TreeNodeFlags::DefaultOpen)) {
            MkAndDrawChildNode(blockInfo.VariantBaseGround, "VariantBaseGround");
            MkAndDrawChildNode(blockInfo.VariantBaseAir, "VariantBaseAir");
            for (uint i = 0; i < blockInfo.AdditionalVariantsGround.Length; i++) {
                MkAndDrawChildNode(blockInfo.AdditionalVariantsGround[i], 0x8 * i, "AdditionalVariantsGround["+i+"]");
            }
            for (uint i = 0; i < blockInfo.AdditionalVariantsAir.Length; i++) {
                MkAndDrawChildNode(blockInfo.AdditionalVariantsAir[i], 0x8 * i, "AdditionalVariantsAir["+i+"]");
            }
            EndTreeNode();
        }
    }

    void Draw(CGameCtnBlockInfoVariant@ infoVar) {
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockInfoVariant", UI::TreeNodeFlags::None)) {
            for (uint i = 0; i < infoVar.BlockUnitInfos.Length; i++) {
                MkAndDrawChildNode(infoVar.BlockUnitInfos[i], 0x8 * i, "BlockUnitInfos["+i+"]");
            }
            for (uint i = 0; i < infoVar.Mobils00.Length; i++) {
                MkAndDrawChildNode(infoVar.Mobils00[i], 0x8 * i, "Mobils00["+i+"]");
            }
            EndTreeNode();
        }
    }

    void Draw(CGameCtnBlockUnitInfo@ unitInfo) {
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockUnitInfo", UI::TreeNodeFlags::None)) {
            for (uint i = 0; i < unitInfo.AllClips.Length; i++) {
                MkAndDrawChildNode(unitInfo.AllClips[i], 0x8 * i, "AllClips["+i+"]");
            }
            EndTreeNode();
        }

    }

    void Draw(CGameCtnBlockInfoMobil@ blockInfoMobil) {
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockInfoMobil", UI::TreeNodeFlags::None)) {
            MkAndDrawChildNode(blockInfoMobil.PrefabFid, GetOffset(blockInfoMobil, "PrefabFid"), "PrefabFid");
            MkAndDrawChildNode(blockInfoMobil.Solid2FromBlockItem, GetOffset(blockInfoMobil, "Solid2FromBlockItem"), "Solid2FromBlockItem");
            MkAndDrawChildNode(blockInfoMobil.SurfaceFromBlockItem, GetOffset(blockInfoMobil, "SurfaceFromBlockItem"), "SurfaceFromBlockItem");
            // MkAndDrawChildNode(blockInfoMobil.PrefabFid, GetOffset(blockInfoMobil, "PrefabFid"), "PrefabFid");
            // MkAndDrawChildNode(blockInfoMobil.PrefabFid, GetOffset(blockInfoMobil, "PrefabFid"), "PrefabFid");
            auto PlacementPatchesBuf = Dev::GetOffsetNod(blockInfoMobil, 0x118);
            auto nbPlacementPatches = Dev::GetOffsetUint32(blockInfoMobil, 0x120);
            UI::Text("nbPlacementPatches: " + nbPlacementPatches);
            // prefab pointer at 0x130
            EndTreeNode();
        }
    }

    void Draw(CSystemFidFile@ fid) {
        if (StartTreeNode(name + " ::\\$f8f CSystemFidFile", UI::TreeNodeFlags::DefaultOpen)) {
            if (fid.Nod is null && UI::Button("Load Nod")) {
                Fids::Preload(fid);
            } else {
                MkAndDrawChildNode(fid.Nod, GetOffset(fid, "Nod"), "Nod");
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugStaticObjectModel@ so) {
        if (StartTreeNode(name + " :: \\$f8fCPlugStaticObjectModel", UI::TreeNodeFlags::DefaultOpen)) {
            MkAndDrawChildNode(so.Mesh, "Mesh");
            MkAndDrawChildNode(so.Shape, "Shape");
            EndTreeNode();
        }
    }
    void Draw(CPlugPrefab@ prefab) {
        hasElements = true;
        if (StartTreeNode(name + " :: \\$f8fCPlugPrefab", UI::TreeNodeFlags::DefaultOpen)) {
            UI::Text("nbEnts: " + prefab.Ents.Length);
#if SIG_DEVELOPER
            UI::SameLine();
            UI::TextDisabled(Text::Format("0x%03x", GetOffset("CPlugPrefab", "Ents")));
#endif
            for (uint i = 0; i < prefab.Ents.Length; i++) {
                currentIndex = i;
                if (StartTreeNode(".Ents["+i+"]:", true)) {
                    if (drawProperties) {
                        if (isEditable) {
                            prefab.Ents[i].Location.Quat = UX::InputQuat(".Location.Quat", prefab.Ents[i].Location.Quat);
                            prefab.Ents[i].Location.Trans = UI::InputFloat3(".Location.Trans", prefab.Ents[i].Location.Trans);
                        } else {
                            CopiableLabeledValue(".Location.Quat", prefab.Ents[i].Location.Quat.ToString());
                            CopiableLabeledValue(".Location.Trans", prefab.Ents[i].Location.Trans.ToString());
                        }
                        DrawPrefabEntParams(prefab, i);
                    }
                    MkAndDrawChildNode(prefab.Ents[i].Model, "Model");
                    if (prefab.Ents[i].Model is null && prefab.Ents[i].ModelFid !is null) {
                        UI::Text("\\$f80ModelFid without a Model: " + prefab.Ents[i].ModelFid.FileName);
                    }
                    EndTreeNode();
                }
            }
            EndTreeNode();
        }
    }
    void Draw(NPlugItem_SVariantList@ varList) {
        hasElements = true;
        if (StartTreeNode(name + " :: \\$f8fNPlugItem_SVariantList", UI::TreeNodeFlags::DefaultOpen)) {
            UI::Text("nbVariants: " + varList.Variants.Length);
#if SIG_DEVELOPER
            UI::SameLine();
            UI::TextDisabled(Text::Format("0x%03x", GetOffset("NPlugItem_SVariantList", "Variants")));
#endif
            for (uint i = 0; i < varList.Variants.Length; i++) {
                currentIndex = i;
                if (StartTreeNode(".Variant["+i+"]:", true)) {
                    if (drawProperties) {
                        UI::Text("nbPlacementTags: " + varList.Variants[i].Tags.Length + "  { " + GetVariantTagsStr(varList, i) + " }");
                        LabeledValue("HiddenInManualCycle", varList.Variants[i].HiddenInManualCycle);
                    }
                    MkAndDrawChildNode(varList.Variants[i].EntityModel, "EntityModel");
                    EndTreeNode();
                }
            }
            EndTreeNode();
        }
    }

    string GetVariantTagsStr(NPlugItem_SVariantList@ varList, uint i) {
        string ret;
        auto vars = Dev::GetOffsetNod(varList, GetOffset(varList, "Variants"));
        auto tagsPtr = Dev::GetOffsetUint64(vars, 0x28 * i + GetOffset("NPlugItem_SVariant", "Tags"));
        for (uint t = 0; t < varList.Variants[i].Tags.Length; t++) {
            if (t > 0) ret += ", ";
            ret += "<" + tostring(Dev::ReadUInt32(tagsPtr + 0x8 * t))
                + ", " + tostring(Dev::ReadUInt32(tagsPtr + 0x8 * t + 0x4)) + ">";
        }
        return ret;
    }

    void Draw(CPlugFxSystem@ fxSys) {
        if (StartTreeNode(name + " :: \\$f8fCPlugFxSystem", UI::TreeNodeFlags::DefaultOpen)) {
            // fxSys. /*todo -- check variable declaration below.*/;
            auto tmp = fxSys;
            if (drawProperties) {
                UI::Text("ContextClassId: " + Text::Format("%08x", tmp.ContextClassId.ClassId));
                UI::Text("ExtraContextClassId: " + Text::Format("%08x", tmp.ExtraContextClassId.ClassId));
                UI::Text("nbVars: " + tostring(tmp.Vars.Length));
            }
            if (StartTreeNode("RootNode", true, UI::TreeNodeFlags::None)) {
                MkAndDrawChildNode(fxSys.RootNode, "RootNode");
                EndTreeNode();
            }
            EndTreeNode();
        }
    }
    void Draw(CPlugVegetTreeModel@ vegetTree) {
        if (StartTreeNode(name + " :: \\$f8fCPlugVegetTreeModel", UI::TreeNodeFlags::DefaultOpen)) {
            if (drawProperties) {
                auto tmp = vegetTree.Data;
                UI::Text("Impostor_Lod_Dist: " + tostring(tmp.Impostor_Lod_Dist));
                UI::Text("Impostor_Plane_Mode: " + tostring(tmp.Impostor_Plane_Mode));
                UI::Text("ReductionRatio01: " + tostring(tmp.ReductionRatio01)); /* Pourcentage max du scale random par instance. 0 = 100%, 0.3 = 70% (soyez raisonnable) */
                UI::Text("Params_AngleMax_RotXZ_Deg: " + tostring(tmp.Params_AngleMax_RotXZ_Deg));
                UI::Text("Params_EnableRandomRotationY: " + tostring(tmp.Params_EnableRandomRotationY));
                UI::TextDisabled("LodModels: UnknownType");// + tostring(tmp.LodModels));
                UI::TextDisabled("LodMaxDists: UnknownType");// + tostring(tmp.LodMaxDists));
                UI::TextDisabled("Materials: UnknownType");// + tostring(tmp.Materials));
                UI::Text("Params_Force_No_Collision: " + tostring(tmp.Params_Force_No_Collision));
                UI::Text("Params_Impostor_AllPlanesVisible: " + tostring(tmp.Params_Impostor_AllPlanesVisible));
                UI::Text("Params_ReceivesPSSM: " + tostring(tmp.Params_ReceivesPSSM));
                if (StartTreeNode("Propagation", true, UI::TreeNodeFlags::None)) {
                    UI::Text("Propagation.Render_BaseColor?: " + tostring(tmp.Propagation.Render_BaseColor !is null));
                    UI::Text("Propagation.Render_Normal?: " + tostring(tmp.Propagation.Render_Normal !is null));
                    UI::Text("Propagation.Render_c2AtlasGrid: " + tostring(tmp.Propagation.Render_c2AtlasGrid));
                    UI::Text("Propagation.Render_LeafSize: " + tostring(tmp.Propagation.Render_LeafSize));
                    UI::Text("Propagation.Phy_cGroundGenPoint: " + tostring(tmp.Propagation.Phy_cGroundGenPoint));
                    UI::Text("Propagation.Phy_cLeafPerSecond: " + tostring(tmp.Propagation.Phy_cLeafPerSecond));
                    UI::Text("Propagation.Phy_ConeHalfAngleDeg: " + tostring(tmp.Propagation.Phy_ConeHalfAngleDeg));
                    UI::Text("Propagation.Phy_EmissionSpawnRadius: " + tostring(tmp.Propagation.Phy_EmissionSpawnRadius));
                    UI::Text("Propagation.Phy_Enable: " + tostring(tmp.Propagation.Phy_Enable));
                    UI::TextDisabled("Propagation.EmissionPoss: Unknown Type");// + tostring(tmp.Propagation.EmissionPoss));
                    EndTreeNode();
                }
            }
            EndTreeNode();
        }
    }
    void Draw(CPlugDynaObjectModel@ dynaObject) {
        if (StartTreeNode(name + " :: \\$f8fCPlugDynaObjectModel", UI::TreeNodeFlags::DefaultOpen)) {
            MkAndDrawChildNode(dynaObject.Mesh, "Mesh");
            MkAndDrawChildNode(dynaObject.StaticShape, "StaticShape");
            MkAndDrawChildNode(dynaObject.DynaShape, "DynaShape");
            EndTreeNode();
        }
    }
    void Draw(NPlugDyna_SKinematicConstraint@ kc) {
        if (StartTreeNode(name + " :: \\$f8fNPlugDyna_SKinematicConstraint", UI::TreeNodeFlags::DefaultOpen)) {
            if (drawProperties) {
                if (isEditable) {
                    DrawKinematicConstraint(kc);
                } else {
                    auto tmp = kc;
                    UI::Text("TransAxis: " + tostring(tmp.TransAxis));
                    UI::Text("TransMin: " + tostring(tmp.TransMin));
                    UI::Text("TransMax: " + tostring(tmp.TransMax));
                    UI::Text("RotAxis: " + tostring(tmp.RotAxis));
                    UI::Text("AngleMinDeg: " + tostring(tmp.AngleMinDeg));
                    UI::Text("AngleMaxDeg: " + tostring(tmp.AngleMaxDeg));
                    UI::Text("ShaderTcType: " + tostring(tmp.ShaderTcType));
                    // print("ShaderTcAnimFunc: " + tostring(tmp.ShaderTcAnimFunc));
                    // print("ShaderTcData_TransSub: " + tostring(tmp.ShaderTcData_TransSub));
                    if (StartTreeNode("TransAnimFunc", true, UI::TreeNodeFlags::None)) {
                        Draw_NPlugDyna_SAnimFunc01(kc, GetOffset(kc, "TransAnimFunc"));
                        EndTreeNode();
                    }
                    if (StartTreeNode("RotAnimFunc", true, UI::TreeNodeFlags::None)) {
                        Draw_NPlugDyna_SAnimFunc01(kc, GetOffset(kc, "RotAnimFunc"));
                        EndTreeNode();
                    }
                }
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugSpawnModel@ spawnModel) {
        if (StartTreeNode(name + " :: \\$f8fCPlugSpawnModel", UI::TreeNodeFlags::DefaultOpen)) {
            if (drawProperties) {
                UI::Text("DefaultGravitySpawn: " + spawnModel.DefaultGravitySpawn.ToString());
                UI::Text("Loc: " + FormatX::Iso4(spawnModel.Loc));
                UI::Text("TorqueDuration: " + spawnModel.TorqueDuration);
                UI::Text("TorqueX: " + spawnModel.TorqueX);
            }
            EndTreeNode();
        }
    }
    void Draw(CPlugEditorHelper@ editorHelper) {
        if (StartTreeNode(name + " :: \\$f8fCPlugEditorHelper", UI::TreeNodeFlags::DefaultOpen)) {
            auto nod = editorHelper.PrefabFid is null ? null : editorHelper.PrefabFid.Nod;
            MkAndDrawChildNode(nod, "PrefabFid");
            EndTreeNode();
        }
    }
    void Draw(NPlugTrigger_SWaypoint@ sWaypoint) {
        if (StartTreeNode(name + " :: \\$f8fNPlugTrigger_SWaypoint", UI::TreeNodeFlags::DefaultOpen)) {
            if (drawProperties) {
                LabeledValue("NoRespawn", sWaypoint.NoRespawn);
                LabeledValue("sWaypoint.Type", tostring(sWaypoint.Type));
            }
            MkAndDrawChildNode(sWaypoint.TriggerShape, "TriggerShape");
            EndTreeNode();
        }
    }
    void Draw(NPlugTrigger_SSpecial@ sSpecial) {
        if (StartTreeNode(name + " :: \\$f8fNPlugTrigger_SSpecial", UI::TreeNodeFlags::DefaultOpen)) {
            MkAndDrawChildNode(sSpecial.TriggerShape, "TriggerShape");
            EndTreeNode();
        }
    }
    void Draw(CGameCommonItemEntityModel@ cieModel) {
        if (StartTreeNode(name + " :: \\$f8fCGameCommonItemEntityModel", UI::TreeNodeFlags::DefaultOpen)) {
            MkAndDrawChildNode(cieModel.StaticObject, "StaticObject");
            MkAndDrawChildNode(cieModel.TriggerShape, "TriggerShape");
            MkAndDrawChildNode(cieModel.PhyModel, "PhyModel");
            EndTreeNode();
        }
    }
    void Draw(CPlugSolid2Model@ s2m) {
        if (StartTreeNode(name + " :: \\$f8fCPlugSolid2Model", UI::TreeNodeFlags::DefaultOpen)) {
            CPlugSkel@ skel = cast<CPlugSkel>(Dev::GetOffsetNod(s2m, 0x78));
            if (drawProperties) {
                uint nbVisualIndexedTriangles = Dev::GetOffsetUint32(s2m, 0xA8 + 0x8);
                uint nbMaterials = Dev::GetOffsetUint32(s2m, 0xC8 + 0x8);
                uint nbMaterialUserInsts = Dev::GetOffsetUint32(s2m, 0xF8 + 0x8);
                uint nbLights = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_LIGHTS_BUF + 0x8);
                uint nbLightUserModels = Dev::GetOffsetUint32(s2m, 0x178 + 0x8);
                uint nbCustomMaterials = Dev::GetOffsetUint32(s2m, 0x1F8 + 0x8);
                UI::Text("nbVisualIndexedTriangles: " + nbVisualIndexedTriangles);
                DrawLightsAt("nbLights: " + nbLights, nod, O_SOLID2MODEL_LIGHTS_BUF);
                DrawUserLightsAt("nbLightUserModels: " + nbLightUserModels, nod, 0x178);
                DrawMaterialsAt("nbMaterials: " + nbMaterials, nod, 0xc8);
                DrawMaterialsAt("nbCustomMaterials: " + nbCustomMaterials, nod, 0x1F8);
                DrawUserMatIntsAt("nbMaterialUserInsts: " + nbMaterialUserInsts, nod, 0xF8);
            }
            MkAndDrawChildNode(skel, 0x78, "Skel");
            EndTreeNode();
        }
    }

    void DrawLightsAt(const string &in title, CMwNod@ nod, uint16 offset) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            for (uint i = 0; i < len; i++) {
                UI::PushID("light"+i);
                auto _offset = O_SOLID2MODEL_LIGHTS_BUF_STRUCT_SIZE * i + O_SOLID2MODEL_LIGHTS_BUF_STRUCT_LIGHT;
                auto light = cast<CPlugLight>(Dev::GetOffsetNod(buf, _offset));
                if (light is null) {
                    UI::Text("Light " + i + ". null");
                } else {
                    MkAndDrawChildNode(light, _offset, "Light " + i);
                }
                UI::PopID();
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugLight@ light) {
        if (StartTreeNode(name + " :: \\$f8fCPlugLight###" + Dev_GetPointerForNod(nod), UI::TreeNodeFlags::None)) {
            if (isEditable) {
                CopiableLabeledValue("m_DualCenterToLight", light.m_DualCenterToLight.ToString());
                CopiableLabeledValue("AnimTimerName", light.AnimTimerName.GetName());
                light.NightOnly = UI::Checkbox("NightOnly", light.NightOnly);
                light.ReflectByGround = UI::Checkbox("ReflectByGround", light.ReflectByGround);
                light.DuplicateGxLight = UI::Checkbox("DuplicateGxLight", light.DuplicateGxLight);
                light.SceneLightOnlyWhenTreeVisible = UI::Checkbox("SceneLightOnlyWhenTreeVisible", light.SceneLightOnlyWhenTreeVisible);
                light.SceneLightAlwaysActive = UI::Checkbox("SceneLightAlwaysActive", light.SceneLightAlwaysActive);
            } else {
                CopiableLabeledValue("m_DualCenterToLight", light.m_DualCenterToLight.ToString());
                CopiableLabeledValue("AnimTimerName", light.AnimTimerName.GetName());
                CopiableLabeledValue("NightOnly", tostring(light.NightOnly));
                CopiableLabeledValue("ReflectByGround", tostring(light.ReflectByGround));
                CopiableLabeledValue("DuplicateGxLight", tostring(light.DuplicateGxLight));
                CopiableLabeledValue("SceneLightOnlyWhenTreeVisible", tostring(light.SceneLightOnlyWhenTreeVisible));
                CopiableLabeledValue("SceneLightAlwaysActive", tostring(light.SceneLightAlwaysActive));
            }
            MkAndDrawChildNode(light.m_GxLightModel, GetOffset(light, "m_GxLightModel"), "m_GxLightModel");
            EndTreeNode();
        }
    }

    void Draw(GxLight@ gxLight) {
        if (StartTreeNode(name + " :: \\$f8fGxLight###" + Dev_GetPointerForNod(nod))) {
            if (isEditable) {
                gxLight.Color = UI::InputColor3("Color", gxLight.Color);
                gxLight.ShadowRGB = UI::InputColor3("ShadowRGB", gxLight.ShadowRGB);
                gxLight.Intensity = UI::InputFloat("Intensity", gxLight.Intensity);
                gxLight.DiffuseIntensity = UI::InputFloat("DiffuseIntensity", gxLight.DiffuseIntensity);
                gxLight.ShadowIntensity = UI::InputFloat("ShadowIntensity", gxLight.ShadowIntensity);
                gxLight.FlareIntensity = UI::InputFloat("FlareIntensity", gxLight.FlareIntensity);
                gxLight.DoLighting = UI::Checkbox("DoLighting", gxLight.DoLighting);
                gxLight.LightMapOnly = UI::Checkbox("LightMapOnly", gxLight.LightMapOnly);
                gxLight.IsInversed = UI::Checkbox("IsInversed", gxLight.IsInversed);
                gxLight.IsShadowGen = UI::Checkbox("IsShadowGen", gxLight.IsShadowGen);
                gxLight.DoSpecular = UI::Checkbox("DoSpecular", gxLight.DoSpecular);
                gxLight.HasLensFlare = UI::Checkbox("HasLensFlare", gxLight.HasLensFlare);
                gxLight.HasSprite = UI::Checkbox("HasSprite", gxLight.HasSprite);
                gxLight.IgnoreLocalScale = UI::Checkbox("IgnoreLocalScale", gxLight.IgnoreLocalScale);
                gxLight.EnableGroup0 = UI::Checkbox("EnableGroup0", gxLight.EnableGroup0);
                gxLight.EnableGroup1 = UI::Checkbox("EnableGroup1", gxLight.EnableGroup1);
                gxLight.EnableGroup2 = UI::Checkbox("EnableGroup2", gxLight.EnableGroup2);
                gxLight.EnableGroup3 = UI::Checkbox("EnableGroup3", gxLight.EnableGroup3);
            } else {
                UI::BeginDisabled();
                gxLight.Color = UI::InputColor3("Color", gxLight.Color);
                gxLight.ShadowRGB = UI::InputColor3("ShadowRGB", gxLight.ShadowRGB);
                UI::EndDisabled();
                LabeledValue("Intensity", gxLight.Intensity);
                LabeledValue("DiffuseIntensity", gxLight.DiffuseIntensity);
                LabeledValue("ShadowIntensity", gxLight.ShadowIntensity);
                LabeledValue("FlareIntensity", gxLight.FlareIntensity);
                LabeledValue("DoLighting", gxLight.DoLighting);
                LabeledValue("LightMapOnly", gxLight.LightMapOnly);
                LabeledValue("IsInversed", gxLight.IsInversed);
                LabeledValue("IsShadowGen", gxLight.IsShadowGen);
                LabeledValue("DoSpecular", gxLight.DoSpecular);
                LabeledValue("HasLensFlare", gxLight.HasLensFlare);
                LabeledValue("HasSprite", gxLight.HasSprite);
                LabeledValue("IgnoreLocalScale", gxLight.IgnoreLocalScale);
                LabeledValue("EnableGroup0", gxLight.EnableGroup0);
                LabeledValue("EnableGroup1", gxLight.EnableGroup1);
                LabeledValue("EnableGroup2", gxLight.EnableGroup2);
                LabeledValue("EnableGroup3", gxLight.EnableGroup3);
            }
//             UI::Text("PlugLight null? " + tostring(gxLight.PlugLight is null));
// #if SIG_DEVELOPER
//             if (gxLight.PlugLight !is null) {
//                 UI::SameLine();
//                 if (UI::Button(Icons::Cube + " Explore PlugLight")) {
//                     ExploreNod("PlugLight", gxLight.PlugLight);
//                 }
//             }
// #endif

            auto gxLightAmb = cast<GxLightAmbient>(gxLight);
            if (gxLightAmb !is null) {
                if (isEditable) {
                    gxLightAmb.ShadeMinY = UI::InputFloat("ShadeMinY", gxLightAmb.ShadeMinY);
                    gxLightAmb.ShadeMaxY = UI::InputFloat("ShadeMaxY", gxLightAmb.ShadeMaxY);
                } else {
                    CopiableLabeledValue("ShadeMinY", tostring(gxLightAmb.ShadeMinY));
                    CopiableLabeledValue("ShadeMaxY", tostring(gxLightAmb.ShadeMaxY));
                }
            }
            auto gxLightNotAmb = cast<GxLightNotAmbient>(gxLight);
            auto gxLDir = cast<GxLightDirectional>(gxLightNotAmb);
            if (gxLDir !is null) {
                UI::Text("\\$aaa  GxLightDirectional:");
                if (isEditable) {
                    gxLDir.DblSidedRGB = UI::InputFloat3("DblSidedRGB", gxLDir.DblSidedRGB);
                    gxLDir.ReverseRGB = UI::InputFloat3("ReverseRGB", gxLDir.ReverseRGB);
                    gxLDir.BoundaryHintPos = UI::InputFloat3("BoundaryHintPos", gxLDir.BoundaryHintPos);
                    gxLDir.ReverseIntens = UI::InputFloat("ReverseIntens", gxLDir.ReverseIntens);
                    gxLDir.EmittAngularSize = UI::InputFloat("EmittAngularSize", gxLDir.EmittAngularSize);
                    gxLDir.FlareAngularSize = UI::InputFloat("FlareAngularSize", gxLDir.FlareAngularSize);
                    gxLDir.FlareIntensPower = UI::InputFloat("FlareIntensPower", gxLDir.FlareIntensPower);
                    gxLDir.DazzleAngleMax = UI::InputFloat("DazzleAngleMax", gxLDir.DazzleAngleMax);
                    gxLDir.DazzleIntensity = UI::InputFloat("DazzleIntensity", gxLDir.DazzleIntensity);
                    gxLDir.UseBoundaryHint = UI::Checkbox("UseBoundaryHint", gxLDir.UseBoundaryHint);
                } else {
                    LabeledValue("DblSidedRGB", gxLDir.DblSidedRGB);
                    LabeledValue("ReverseRGB", gxLDir.ReverseRGB);
                    LabeledValue("BoundaryHintPos", gxLDir.BoundaryHintPos);
                    LabeledValue("ReverseIntens", gxLDir.ReverseIntens);
                    LabeledValue("EmittAngularSize", gxLDir.EmittAngularSize);
                    LabeledValue("FlareAngularSize", gxLDir.FlareAngularSize);
                    LabeledValue("FlareIntensPower", gxLDir.FlareIntensPower);
                    LabeledValue("DazzleAngleMax", gxLDir.DazzleAngleMax);
                    LabeledValue("DazzleIntensity", gxLDir.DazzleIntensity);
                    LabeledValue("UseBoundaryHint", gxLDir.UseBoundaryHint);
                }
            }

            auto gxLPoint = cast<GxLightPoint>(gxLightNotAmb);
            if (gxLPoint !is null) {
                UI::Text("\\$aaa  GxLightPoint:");
                if (isEditable) {
                    gxLPoint.FlareSize = UI::InputFloat("FlareSize", gxLPoint.FlareSize);
                    gxLPoint.FlareBiasZ = UI::InputFloat("FlareBiasZ", gxLPoint.FlareBiasZ);
                } else {
                    LabeledValue("FlareSize", gxLPoint.FlareSize);
                    LabeledValue("FlareBiasZ", gxLPoint.FlareBiasZ);
                }
            }

            auto gxLBall = cast<CGxLightBall>(gxLPoint);
            if (gxLBall !is null) {
                UI::Text("\\$aaa  CGxLightBall:");
                // LabeledValue("StaticShadow", gxLBall.StaticShadow)
                if (isEditable) {
                    gxLBall.StaticShadow = DrawComboEStaticShadow("StaticShadow", gxLBall.StaticShadow);
                    gxLBall.AmbientRGB = UI::InputColor3("AmbientRGB", gxLBall.AmbientRGB);
                    gxLBall.Radius = UI::InputFloat("Radius", gxLBall.Radius);
                    gxLBall.RadiusSpecular = UI::InputFloat("RadiusSpecular", gxLBall.RadiusSpecular);
                    gxLBall.RadiusIndex = UI::InputFloat("RadiusIndex", gxLBall.RadiusIndex);
                    gxLBall.RadiusShadow = UI::InputFloat("RadiusShadow", gxLBall.RadiusShadow);
                    gxLBall.RadiusFlare = UI::InputFloat("RadiusFlare", gxLBall.RadiusFlare);
                    gxLBall.EmittingRadius = UI::InputFloat("EmittingRadius", gxLBall.EmittingRadius);
                    gxLBall.EmittingCylinderLenZ = UI::InputFloat("EmittingCylinderLenZ", gxLBall.EmittingCylinderLenZ);
                    gxLBall.CustomRadiusSpecular = UI::Checkbox("CustomRadiusSpecular", gxLBall.CustomRadiusSpecular);
                    gxLBall.CustomRadiusIndex = UI::Checkbox("CustomRadiusIndex", gxLBall.CustomRadiusIndex);
                    gxLBall.CustomRadiusShadow = UI::Checkbox("CustomRadiusShadow", gxLBall.CustomRadiusShadow);
                    gxLBall.CustomRadiusFlare = UI::Checkbox("CustomRadiusFlare", gxLBall.CustomRadiusFlare);
                } else {
                    LabeledValue("StaticShadow", tostring(gxLBall.StaticShadow));
                    LabeledValue("AmbientRGB", gxLBall.AmbientRGB);
                    LabeledValue("Radius", gxLBall.Radius);
                    LabeledValue("RadiusSpecular", gxLBall.RadiusSpecular);
                    LabeledValue("RadiusIndex", gxLBall.RadiusIndex);
                    LabeledValue("RadiusShadow", gxLBall.RadiusShadow);
                    LabeledValue("RadiusFlare", gxLBall.RadiusFlare);
                    LabeledValue("EmittingRadius", gxLBall.EmittingRadius);
                    LabeledValue("EmittingCylinderLenZ", gxLBall.EmittingCylinderLenZ);
                    LabeledValue("CustomRadiusSpecular", gxLBall.CustomRadiusSpecular);
                    LabeledValue("CustomRadiusIndex", gxLBall.CustomRadiusIndex);
                    LabeledValue("CustomRadiusShadow", gxLBall.CustomRadiusShadow);
                    LabeledValue("CustomRadiusFlare", gxLBall.CustomRadiusFlare);
                }
            }

            auto gxLFrustum = cast<CGxLightFrustum>(gxLBall);
            if (gxLFrustum !is null) {
                UI::Text("\\$aaa  CGxLightFrustum:");
                UI::Text("todo");
            }

            auto gxLSpot = cast<CGxLightSpot>(gxLBall);
            if (gxLSpot !is null) {
                UI::Text("\\$aaa  CGxLightSpot:");
                UI::Text("todo");
            }

            EndTreeNode();
        }
    }

    void DrawUserLightsAt(const string &in title, CMwNod@ nod, uint16 offset) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            for (uint i = 0; i < len; i++) {
                UI::PushID("userlight"+i);
                auto userLight = cast<CPlugLightUserModel>(Dev::GetOffsetNod(buf, 0x8 * i));
                if (userLight is null) {
                    UI::Text("UserLight " + i + ". null");
                } else {
                    MkAndDrawChildNode(userLight, 0x8 * i, "UserLight " + i);
                }
                UI::PopID();
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugLightUserModel@ userLight) {
        if (StartTreeNode(name + " :: \\$f8fCPlugLightUserModel###" + Dev_GetPointerForNod(nod), UI::TreeNodeFlags::None)) {
            if (isEditable) {
                userLight.Color = UI::InputColor3("Color", userLight.Color);
                userLight.Intensity = UI::InputFloat("Intensity", userLight.Intensity);
                userLight.Distance = UI::InputFloat("Distance", userLight.Distance);
                userLight.PointEmissionRadius = UI::InputFloat("PointEmissionRadius", userLight.PointEmissionRadius);
                userLight.PointEmissionLength = UI::InputFloat("PointEmissionLength", userLight.PointEmissionLength);
                userLight.SpotInnerAngle = UI::InputFloat("SpotInnerAngle", userLight.SpotInnerAngle);
                userLight.SpotOuterAngle = UI::InputFloat("SpotOuterAngle", userLight.SpotOuterAngle);
                userLight.SpotEmissionSizeX = UI::InputFloat("SpotEmissionSizeX", userLight.SpotEmissionSizeX);
                userLight.SpotEmissionSizeY = UI::InputFloat("SpotEmissionSizeY", userLight.SpotEmissionSizeY);
                userLight.NightOnly = UI::Checkbox("NightOnly", userLight.NightOnly);
            } else {
                UI::BeginDisabled();
                userLight.Color = UI::InputColor3("Color", userLight.Color);
                UI::EndDisabled();
                UI::Text("Intensity: " + userLight.Intensity);
                UI::Text("Distance: " + userLight.Distance);
                UI::Text("PointEmissionRadius: " + userLight.PointEmissionRadius);
                UI::Text("PointEmissionLength: " + userLight.PointEmissionLength);
                UI::Text("SpotInnerAngle: " + userLight.SpotInnerAngle);
                UI::Text("SpotOuterAngle: " + userLight.SpotOuterAngle);
                UI::Text("SpotEmissionSizeX: " + userLight.SpotEmissionSizeX);
                UI::Text("SpotEmissionSizeY: " + userLight.SpotEmissionSizeY);
                UI::Text("NightOnly: " + userLight.NightOnly);
            }
            EndTreeNode();
        }
    }

    void DrawMaterialsAt(const string &in title, CMwNod@ nod, uint16 offset, uint16 elSize = 0x8, uint16 elOffset = 0x0) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            // operations for surfaces
            auto surf = cast<CPlugSurface>(nod);
            if (isEditable && surf !is null && len > 0) {
                if (UI::Button("TransformMaterialsToMatIds")) {
                    surf.TransformMaterialsToMatIds();
                }
            }
            // always show material name if we can
            for (uint i = 0; i < len; i++) {
                auto mat = cast<CPlugMaterial>(Dev::GetOffsetNod(buf, elSize * i + elOffset));
                if (mat is null) {
                    UI::Text("" + i + ". null");
                } else {
                    auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(mat, 0x8));
                    auto matTitle = "" + i + ". Unknown material.";
                    if (fid !is null) {
                        matTitle = "" + i + ". " + fid.FileName;
                    }
                    MkAndDrawChildNode(mat, 0x8 * i, matTitle);
                }
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugMaterial@ mat) {
        if (StartTreeNode(name + " :: \\$f8fCPlugMaterial###" + Dev_GetPointerForNod(nod), UI::TreeNodeFlags::None)) {
            auto physId = EPlugSurfaceMaterialId(Dev::GetOffsetUint8(mat, O_MATERIAL_PHYSICS_ID));
            auto gameplayId = EPlugSurfaceGameplayId(Dev::GetOffsetUint8(mat, O_MATERIAL_GAMEPLAY_ID));
            if (isEditable) {
                Dev::SetOffset(mat, O_MATERIAL_PHYSICS_ID, uint8(DrawComboEPlugSurfaceMaterialId("PhysicsID", physId)));
                Dev::SetOffset(mat, O_MATERIAL_GAMEPLAY_ID, uint8(DrawComboEPlugSurfaceGameplayId("GameplayID", gameplayId)));
            } else {
                CopiableLabeledValue("PhysicsID", tostring(physId));
                CopiableLabeledValue("GameplayID", tostring(gameplayId));
            }
            EndTreeNode();
        }
    }

    void DrawUserMatIntsAt(const string &in title, CMwNod@ nod, uint16 offset, uint16 elSize = 0x18, uint16 elOffset = 0x0) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            // auto elSize = 0x18;
            for (uint i = 0; i < len; i++) {
                auto mat = cast<CPlugMaterialUserInst>(Dev::GetOffsetNod(buf, elSize * i + elOffset));
                // auto u1 = Dev::GetOffsetUint64(buf, elSize * i + 0x8);
                // auto u2 = Dev::GetOffsetUint64(buf, elSize * i + 0x10);
                // these seem to do/mean nothing
                // string suffix = " / " + u1 + " / " + Text::Format("0x%x", u2);
                string suffix = "";
                if (mat is null) {
                    UI::Text("" + i + ". null" + suffix);
                } else {
                    string name = mat._Name.GetName();
                    if (mat._LinkFull.Length > 0) {
                        name = mat._LinkFull;
                    }
                    auto title = "" + i + ". " + name + suffix;
                    MkAndDrawChildNode(mat, elSize * i, title);
                }
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugMaterialUserInst@ userMat) {
// #if SIG_DEVELOPER
//                     UI::SameLine();
//                     if (UX::SmallButton(Icons::Cube + " Explore##matUserInst" + i)) {
//                         ExploreNod("MaterialUserInst " + i + ".", mat);
//                     }
// #endif
        if (StartTreeNode(name + " :: \\$f8fCPlugMaterialUserInst###" + Dev_GetPointerForNod(nod), false, UI::TreeNodeFlags::None)) {
            auto colorPtr = Dev::GetOffsetUint64(nod, O_USERMATINST_COLORBUF);
            auto colorLen = Dev::GetOffsetUint32(nod, O_USERMATINST_COLORBUF + 0x8);
            if (isEditable) {
                auto origGPID = userMat.GameplayID;
                userMat._LinkFull = UI::InputText("LinkFull", userMat._LinkFull);

                // For some reason, setting userMat.GameplayID / PhysicsID does not work for 'None' (or some values), so we need to write the memory offset instead (which works)
                Dev::SetOffset(userMat, O_USERMATINST_PHYSID, uint8(DrawComboEPlugSurfaceMaterialId("PhysicsID", EPlugSurfaceMaterialId(userMat.PhysicsID))));
                auto newGameplayID = uint8(DrawComboEPlugSurfaceGameplayId("GameplayID", EPlugSurfaceGameplayId(origGPID)));
                Dev::SetOffset(userMat, O_USERMATINST_GAMEPLAY_ID, newGameplayID);
                if (colorLen == 3) {
                    auto r = Dev::ReadUInt32(colorPtr + 0x0),
                        g = Dev::ReadUInt32(colorPtr + 0x4),
                        b = Dev::ReadUInt32(colorPtr + 0x8);
                    auto col = vec3(r, g, b) / vec3(255);
                    col = UI::InputColor3("Color", col) * 255;
                    Dev::Write(colorPtr + 0x0, uint8(Math::Clamp(uint32(Math::Round(col.x)), 0, 255)));
                    Dev::Write(colorPtr + 0x4, uint8(Math::Clamp(uint32(Math::Round(col.y)), 0, 255)));
                    Dev::Write(colorPtr + 0x8, uint8(Math::Clamp(uint32(Math::Round(col.z)), 0, 255)));
                } else {
                    UI::TextDisabled("unsupported color buffer length: " + colorLen);
                    UI::SameLine();
                    if (UI::Button("Instantiate Color")) {
                        auto newColorPtr = Dev::Allocate(0x10);
                        Dev::SetOffset(nod, O_USERMATINST_COLORBUF, newColorPtr);
                        Dev::SetOffset(nod, O_USERMATINST_COLORBUF + 0x8, uint32(0x3));
                        Dev::SetOffset(nod, O_USERMATINST_COLORBUF + 0xC, uint32(0x3));
                        auto tyid = MwId();
                        tyid.SetName("Real");
                        auto targetid = MwId();
                        targetid.SetName("TargetColor");
                        Dev::SetOffset(nod, O_USERMATINST_PARAM_EXISTS, 1);
                        Dev::SetOffset(nod, O_USERMATINST_PARAM_MWID_NAME, targetid.Value);
                        Dev::SetOffset(nod, O_USERMATINST_PARAM_MWID_TYPE, tyid.Value);
                        Dev::SetOffset(nod, O_USERMATINST_PARAM_LEN, 3);
                    }
                    AddSimpleTooltip("\\$f80Warning!\\$z The game will crash at some point (leaving editor, etc) after clicking this button. Be sure to save etc.");
                }
            } else {
                CopiableLabeledValue("LinkFull", userMat._LinkFull);
                CopiableLabeledValue("PhysicsID", tostring(EPlugSurfaceMaterialId(userMat.PhysicsID)));
                CopiableLabeledValue("GameplayID", tostring(EPlugSurfaceGameplayId(userMat.GameplayID)));
            }
            EndTreeNode();
        }
    }

    void DrawMaterialIdsAt(const string &in title, CMwNod@ nod, uint16 offset) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto surf = cast<CPlugSurface>(nod);
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            auto objSize = 0x2;
            for (uint i = 0; i < len; i++) {
                EPlugSurfaceMaterialId PhysicId = EPlugSurfaceMaterialId(Dev::GetOffsetUint8(buf, objSize * i));
                EPlugSurfaceGameplayId GameplayId = EPlugSurfaceGameplayId(Dev::GetOffsetUint8(buf, objSize * i + 0x1));
                if (StartTreeNode("Material " + i + ".", true, UI::TreeNodeFlags::DefaultOpen)) {
                    if (isEditable) {
                        auto newPhysicId = DrawComboEPlugSurfaceMaterialId("PhysicId", PhysicId);
                        auto newGameplayId = DrawComboEPlugSurfaceGameplayId("GameplayId", GameplayId);
                        Dev::SetOffset(buf, objSize * i, uint8(newPhysicId));
                        Dev::SetOffset(buf, objSize * i + 0x1, uint8(newGameplayId));
                        if (surf !is null && (newPhysicId != PhysicId || newGameplayId != GameplayId)) {
                            surf.UpdateSurfMaterialIdsFromMaterialIndexs();
                        }
                    } else {
                        UI::Text("PhysicId: " + tostring(PhysicId));
                        UI::Text("GameplayId: " + tostring(GameplayId));
                    }
                    EndTreeNode();
                }
            }
            EndTreeNode();
        }
    }


    void Draw(CPlugSurface@ surf) {
        if (StartTreeNode(name + " :: \\$f8fCPlugSurface", UI::TreeNodeFlags::DefaultOpen)) {
            if (drawProperties) {
                DrawMaterialsAt("nbMaterials: " + surf.Materials.Length, surf, GetOffset(surf, "Materials"));
                DrawMaterialIdsAt("nbMaterialIds: " + surf.MaterialIds.Length, surf, GetOffset(surf, "MaterialIds"));
                if (isEditable) {
                    if (UI::Button("UpdateSurfMaterialIdsFromMaterialIndexs")) {
                        surf.UpdateSurfMaterialIdsFromMaterialIndexs();
                    }
                    AddSimpleTooltip("This will update the material IDs on the surface itself. It should be run automatically after changing one of the surface's MaterialIds.");
                }
                Draw("m_GmSurf", surf.m_GmSurf);
                MkAndDrawChildNode(surf.Skel, GetOffset(surf, "Skel"), "Skel");
            }
            EndTreeNode();
        }
    }

    void Draw(const string &in _name, GmSurf@ gmSurf) {
        if (StartTreeNode(_name + " :: \\$f8fGmSurf", true, UI::TreeNodeFlags::DefaultOpen)) {
            if (isEditable) {
                gmSurf.GmSurfType = DrawComboEGmSurfType("GmSurfType", gmSurf.GmSurfType);
                AddSimpleTooltip("Almost always mesh? Unknown effects. Seems to crash the game for other values.");
                gmSurf.GameplayMainDir = UI::InputFloat3("GameplayMainDir", gmSurf.GameplayMainDir);
                AddSimpleTooltip("Allows customizing bumper and booster parameters");
#if SIG_DEVELOPER
                // UI::SameLine();
                // if (UI::Button("Y=NaN")) {
                //     Dev::SetOffset(gmSurf, GetOffset("GmSurf", "GameplayMainDir") + 0x4, uint32(0x7fc00000));
                // }
#endif
            } else {
                UI::Text("GmSurfType: " + tostring(gmSurf.GmSurfType));
                UI::Text("GameplayMainDir: " + tostring(gmSurf.GameplayMainDir));
            }
            EndTreeNode();
        }
    }


    void Draw(CPlugGameSkin@ skin) {
        if (StartTreeNode(name + " :: \\$f8fCPlugGameSkin", UI::TreeNodeFlags::None)) {
            string path1 = Dev::GetOffsetString(skin, O_GAMESKIN_PATH1);
            string path2 = Dev::GetOffsetString(skin, O_GAMESKIN_PATH2);
            if (isEditable) {
                Dev::SetOffset(skin, O_GAMESKIN_PATH1, UI::InputText("Path1", path1));
                Dev::SetOffset(skin, O_GAMESKIN_PATH2, UI::InputText("Path2", path2));
            } else {
                CopiableLabeledValue("Path1", path1);
                CopiableLabeledValue("Path2", path2);
            }
            auto buf = Dev::GetOffsetNod(skin, O_GAMESKIN_FID_BUF);
            auto len = Dev::GetOffsetUint32(skin, O_GAMESKIN_FID_BUF + 0x8);
            for (uint i = 0; i < len; i++) {
                if (buf is null) continue;
                auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(buf, 0x8 * i));
                UI::Text("FID " + i +". " + (fid is null ? "Unknown" : string(fid.FileName)));
#if SIG_DEVELOPER
                if (fid !is null) {
                    UI::SameLine();
                    if (UI::Button(Icons::Cube + " Explore FID##" + i)) {
                        ExploreNod(fid);
                    }
                }
#endif
            }
            auto buf2 = Dev::GetOffsetNod(skin, O_GAMESKIN_FILENAME_BUF);
            len = Dev::GetOffsetUint32(skin, O_GAMESKIN_FILENAME_BUF + 0x8);
            for (uint i = 0; i < len; i++) {
                if (buf2 is null) continue;
                auto filename = Dev::GetOffsetString(buf2, 0x10 * i);
                CopiableLabeledValue("Filename " + i, filename);
            }
            auto buf3 = Dev::GetOffsetNod(skin, O_GAMESKIN_FID_CLASSID_BUF);
            len = Dev::GetOffsetUint32(skin, O_GAMESKIN_FID_CLASSID_BUF + 0x8);
            for (uint i = 0; i < len; i++) {
                auto classId = Dev::GetOffsetUint32(buf3, 0x4 * i);
                CopiableLabeledValue("Class ID " + i, Reflection::GetType(classId).Name); // Text::Format("0x%08x", classId));
            }
            EndTreeNode();
        }
    }


    void Draw(CSystemPackDesc@ sysPackDesc) {
        if (StartTreeNode(name + " :: \\$f8fCSystemPackDesc", UI::TreeNodeFlags::None)) {
            CopiableLabeledValue("Url", sysPackDesc.Url);
            CopiableLabeledValue("Name", sysPackDesc.Name);
            CopiableLabeledValue("IdName", sysPackDesc.IdName);
            CopiableLabeledValue("FileName", sysPackDesc.FileName);
            CopiableLabeledValue("AutoUpdate", tostring(sysPackDesc.AutoUpdate));
            CopiableLabeledValue("LocatorFileName", sysPackDesc.LocatorFileName);
            EndTreeNode();
        }
    }

    void Draw(CGameBlockItem@ blockItem) {
        if (StartTreeNode(name + " ::\\$f8f CGameBlockItem", UI::TreeNodeFlags::DefaultOpen)) {

            CopiableLabeledValue("ArchetypeBlockInfoId", blockItem.ArchetypeBlockInfoId.GetName());

            auto nbCrystals = blockItem.BlockInfoMobilSkins_Crystals.Length;
            if (StartTreeNode("BlockInfoMobilSkins_Crystals (" + nbCrystals + ")###" + Dev_GetPointerForNod(nod), true, UI::TreeNodeFlags::None)) {
                auto elSize = 0x68;
                auto crystalsPtr = Dev::GetOffsetUint64(blockItem, 0x20);
                for (uint i = 0; i < nbCrystals; i++) {
                    auto offset = elSize * i + 0x8;
                    // CopiableLabeledValue("PtrPtr", Text::FormatPointer(crystalsPtr + offset));
                    MkAndDrawChildNode(Dev_GetNodFromPointer(Dev::ReadUInt64(crystalsPtr + offset)), offset, "Crystal " + i + ".");
                }
                EndTreeNode();
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugCrystal@ crystal) {
        if (StartTreeNode(name + " ::\\$f8f CPlugCrystal", UI::TreeNodeFlags::DefaultOpen)) {
            auto nbMats = Dev::GetOffsetUint32(crystal, 0x50);
            DrawMaterialsAt("Materials ("+nbMats+")##" + Dev_GetPointerForNod(crystal), crystal, 0x48, 0x20, 0x18);
            DrawUserMatIntsAt("UserMatInts ("+nbMats+")##" + Dev_GetPointerForNod(crystal), crystal, 0x48, 0x20, 0x0);
            EndTreeNode();
        }
    }

    void Draw(CTrackMania@ asdf) {
        if (StartTreeNode(name + " ::\\$f8f CTrackMania", UI::TreeNodeFlags::DefaultOpen)) {
            UI::Text("\\$f80todo");
            EndTreeNode();
        }
    }

    bool StartTreeNode(const string &in title, UI::TreeNodeFlags flags = UI::TreeNodeFlags::DefaultOpen) {
        return StartTreeNode(title, false, flags);
    }

    bool StartTreeNode(const string &in title, bool suppressDev, UI::TreeNodeFlags flags = UI::TreeNodeFlags::DefaultOpen) {
        bool open = UI::TreeNode(title, flags);
        if (open) {
            UI::PushID(title);
            UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        }
        if (open && nod !is null) {
            DrawPickable();
        }
        if (open && !suppressDev && !isPicker && nod !is null) {
            auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(nod, 0x8));
#if SIG_DEVELOPER
            Draw_IB_DevBtnPtr(title, nod, nodOffset);
            if (fid !is null) UI::SameLine();
#endif
            if (fid !is null) {
                UI::Text("\\$8f8Fid: " + fid.FileName);
            }
        }
        return open;
    }

    void EndTreeNode() {
        UI::PopStyleVar();
        UI::PopID();
        UI::TreePop();
    }



    void DrawPrefabEntParams(CPlugPrefab@ prefab, uint i) {
        auto ents = Dev::GetOffsetNod(prefab, GetOffset("CPlugPrefab", "Ents"));
        // size: NPlugPrefab_SEntRef: 0x50
        auto ptr1 = Dev::GetOffsetUint64(ents, 0x50 * i + GetOffset("NPlugPrefab_SEntRef", "Params"));
        auto ptr2 = Dev::GetOffsetUint64(ents, 0x50 * i + GetOffset("NPlugPrefab_SEntRef", "Params") + 0x8);
        string type = "Unknown";
        uint32 paramsClsId;
        if (ptr2 > 0 && ptr2 % 8 == 0) {
            type = Dev::ReadCString(Dev::ReadUInt64(ptr2));
            paramsClsId = Dev::ReadUInt32(ptr2 + 0x10);
            if (StartTreeNode("\\$888Params: ClsId / Type: " + Text::Format("%08x / " + type, paramsClsId),
                true, UI::TreeNodeFlags::None
            )) {
                DrawSMetaPtr(ptr1, paramsClsId, type, isEditable);
                EndTreeNode();
            }
            // uint nextTypeMetadataEntry = Dev::ReadUInt64(ptr2 + 0x20);
            // if (entInfoPtr > 0 && entInfoPtr % 8 == 0) {
            //     entType = Dev::ReadCString(Dev::ReadUInt64(entInfoPtr + 0x8));
            //     entClsId = Dev::ReadUInt32(entInfoPtr + 0x18);
            //     UI::TextDisabled("ClsId / Type: " + Text::Format("%08x / " + entType, entClsId));
            // }
        }
    }
}


void Draw_IB_DevBtnPtr(const string &in title, CMwNod@ nod, uint16 nodOffset) {
// safer to put preprocessor statements inside incase this is accidentally called without a SIG_DEVELOPER check
#if SIG_DEVELOPER
        UI::TextDisabled(Text::Format("0x%03x", nodOffset));
        UI::SameLine();
        if (UX::SmallButton(Icons::Cube + " Explore Nod")) {
            ExploreNod(title, nod);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(nod)));
#endif
}

uint64 Dev_GetPointerForNod(CMwNod@ nod) {
    if (nod is null) throw('nod was null');
    auto tmpNod = CMwNod();
    uint64 tmp = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, nod);
    uint64 ptr = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, tmp);
    return ptr;
}

CMwNod@ Dev_GetNodFromPointer(uint64 ptr) {
    if (ptr < 0xFFFFFFFF || ptr % 8 != 0 || ptr >> 48 > 0) {
        return null;
    }
    auto tmpNod = CMwNod();
    uint64 tmp = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, ptr);
    auto nod = Dev::GetOffsetNod(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, tmp);
    return nod;
}




string UnkType(CMwNod@ nod) {
    if (nod is null) return "null";
    return Reflection::TypeOf(nod).Name;
}



void DrawSMetaPtr(uint64 ptr, uint32 clsId, const string &in type, bool isEditable = false) {
    if (clsId == 0) return;
    auto ty = Reflection::GetType(clsId);
    if (ty is null) return;
    uint16 maxOffset = 0;
    for (uint i = 0; i < ty.Members.Length; i++) {
        auto mem = ty.Members[i];
        if (mem.Offset < 0xFFFF && mem.Offset > maxOffset) {
            maxOffset = mem.Offset;
        }
    }
    // add a bit, unlikely to get into unallocated memory.
    maxOffset += 0x8;
#if SIG_DEVELOPER
    CopiableLabeledValue("\\$888Ptr", Text::FormatPointer(ptr));
#endif
    CopiableLabeledValue("\\$888Data", Dev::Read(ptr, maxOffset));

    if (clsId == 0x2f0b6000 || type == "NPlugDynaObjectModel::SInstanceParams") {
        auto offsetCSS = GetOffset("NPlugDynaObjectModel_SInstanceParams", "CastStaticShadow");
        auto offsetIK = GetOffset("NPlugDynaObjectModel_SInstanceParams", "IsKinematic");
        bool castsShadow = Dev::ReadUInt8(ptr + offsetCSS) > 0;
        bool IsKinematic = Dev::ReadUInt8(ptr + offsetIK) > 0;
        if (isEditable) {
            castsShadow = UI::Checkbox("CastStaticShadow", castsShadow);
            Dev::Write(ptr + offsetCSS, castsShadow ? 0x1 : 0x0);
            IsKinematic = UI::Checkbox("IsKinematic", IsKinematic);
            Dev::Write(ptr + offsetIK, IsKinematic ? 0x1 : 0x0);
        } else {
            LabeledValue("CastStaticShadow", castsShadow);
            LabeledValue("IsKinematic", IsKinematic);
        }
    } else if (clsId == 0x2f0d8000 || type == "NPlugItemPlacement::SPlacementGroup") {
        DrawSPlacementGroup(ptr, isEditable);
    } else if (clsId == 0x2f0c8000 || type == "NPlugDyna::SPrefabConstraintParams") {
        Draw_SPrefabConstraintParams(ptr, isEditable);
    }
}

void Draw_SPrefabConstraintParams(uint64 ptr, bool isEditable) {
    uint dynaObjIx = Dev::ReadUInt32(ptr + 0x4);
    if (isEditable) {
        dynaObjIx = UI::InputInt("DynaObject Ix", dynaObjIx);
        Dev::Write(ptr + 0x4, dynaObjIx);
    } else {
        LabeledValue("DynaObject Ix", dynaObjIx);
    }
}

void DrawSPlacementGroup(uint64 ptr, bool isEditable = false) {
    // Placements MmSArray<NPlugItemPlacement_SPlacementOption> at 0x0
    // MmSArray at 0x10: GmTransQuat?; Struct of [quat, vec3] i think (0.71, 0.0, -0.71, 0.0, x, y, z); length 0x1C
    // Total size might be 0x40 bytes (gets updated on save if main placements group length is shortened)

    // Read placement options
    auto placementsPtr = Dev::ReadUInt64(ptr);
    // CopiableLabeledValue("placementsPtr", Text::FormatPointer(placementsPtr));
    auto buf = Dev_GetNodFromPointer(placementsPtr);
    // LabeledValue("buf is null", buf is null);
    auto len = Dev::ReadUInt32(ptr + 0x8);
    // LabeledValue("Placements ptr", Text::FormatPointer(ptr));
    LabeledValue("Placements.Length", len);
    uint elSize = SZ_SPLACEMENTOPTION;
    for (uint i = 0; i < Math::Min(5, len); i++) {
        uint layout = Dev::GetOffsetUint32(buf, elSize * i + 0x0);
        // MwSArray<NPlugItemPlacement_SPlacementOption>
        auto placementOpts = Dev::GetOffsetNod(buf, elSize * i + 0x8);
        auto placementOptsNb = Dev::GetOffsetUint32(buf, elSize * i + 0x10);
        // works but useless atm
        if (false) {
            DrawSPlacementOption(i, layout, placementOpts, placementOptsNb);
        }
    }

    // Read MwSArray<GmTransQuat>
    auto tqsPtr = Dev::ReadUInt64(ptr + 0x10);
    // CopiableLabeledValue("TQs Ptr", Text::FormatPointer(tqsPtr));
    auto tqs = Dev_GetNodFromPointer(tqsPtr);
    // LabeledValue("TQs is null", tqs is null);
    auto nbTqs = Dev::ReadUInt32(ptr + 0x18);
    auto newNb = Draw_SPlacementGroup_TQs(tqs, nbTqs, isEditable, ptr);
    // check if we need to alter array lengths
    if (isEditable && newNb < nbTqs && newNb < len) {
        // update first 2 arrays -- updating first one will update the rest on save, but not the second one
        Dev::Write(ptr + 0x8, newNb);
        Dev::Write(ptr + 0x18, newNb);
        NotifySuccess("Updated item spectator count, please save the item");
    }
}

void DrawSPlacementOption(uint i, uint layout, CMwNod@ buf, uint len) {
    UI::Text("" + i + ". Layout: " + layout + " / PlacecementOptions.Length: " + len);
}

// returns the number of elements so an update can be detected
uint Draw_SPlacementGroup_TQs(CMwNod@ tqs, uint nbTqs, bool isEditable, uint64 placementGroupPtr) {
    auto ret = nbTqs;
    UI::Text("TQs.Length: " + nbTqs);
    if (IsPlacementGroupForSpectators(placementGroupPtr)) {
        // UI::SameLine();
        UI::Indent();
        if (UI::Button("Export Spectators")) {
            ExportItemSpectators(tqs, nbTqs);
        }
        if (isEditable) {
            UI::SameLine();
            if (UI::Button("Import Spectators")) {
                ret = ImportItemSpectators(tqs, nbTqs);
                NotifySuccess("Successfully imported spectator locations! Please save the item.");
            }
            UI::SameLine();
            if (UI::Button("2x Spectator Count")) {
                DoubleItemSpectators(placementGroupPtr);
            }
            AddSimpleTooltip("\\$f80Warning!\\$z The game might crash leaving the editor or if E++ is unloaded/updated. At the very least, the game will crash on shutdown. (Safe to use for item creation). Be sure to save regularly.");

            if (UI::Button("-10% Spectator Count")) {
                ReduceItemSpectators(placementGroupPtr, 0.9);
            }
            UI::SameLine();
            if (UI::Button("-25% Spectator Count")) {
                ReduceItemSpectators(placementGroupPtr, 0.75);
            }
            UI::SameLine();
            if (UI::Button("-50% Spectator Count")) {
                ReduceItemSpectators(placementGroupPtr, 0.5);
            }
        }
        UI::Unindent();
    }
    return ret;
}

bool IsPlacementGroupForSpectators(uint64 placementGroupPtr) {
    auto len = Dev::ReadUInt32(placementGroupPtr + 0x38);
    if (len == 0) return false;
    auto buf = Dev_GetNodFromPointer(Dev::ReadUInt64(placementGroupPtr + 0x30));
    if (buf is null) return false;
    if (Dev::GetOffsetUint32(buf, 0x10) < 1) return false;
    auto inner = Dev::GetOffsetNod(buf, 0x8);
    if (inner is null) return false;
    return Dev::GetOffsetUint8(inner, 0x14) == 0x21;
}

void Draw_NPlugDyna_SAnimFunc01(CMwNod@ nod, uint16 offset) {
    auto len = Dev::GetOffsetUint32(nod, offset);
    auto startOffset = offset + 0x4;
    for (uint i = 0; i < len; i++) {
        // each subfunc is 0x8 long
        auto sfOffset = startOffset + 0x8 * i;
        auto type = SubFuncEasings(Dev::GetOffsetUint8(nod, sfOffset));
        auto reverse = Dev::GetOffsetUint8(nod, sfOffset + 0x1) == 1;
        auto duration = Dev::GetOffsetUint32(nod, sfOffset + 0x4);
        UI::Text(tostring(type) + ", Rev: " + reverse + ", Duration: " + duration);
    }
}

enum ModelTargetType {
    None = 0,
    // like itemModel.EntityModel, or StaticObj.Mesh
    DirectChild = 1,
    // like variantList.Variant[i].Model
    IndirectChild = 2,
    AnyChild_AndTest = 3,
    // like variantList.Variant[i]
    ArrayElement = 4,
    // for replacing Mesh+Shape
    AllChildren = 8,
    Any_AndTest = 15,
}

class ItemModelTarget {
    /**
     * Entity: Prefab + Index
     * Entity.Model: Prefab + Index + Model
     * VarList: ItemModel + VarList
     * Variant: VarList + Index
     * Variant.Model: VarList + Index + Model
     * DynaObj: VarList + Index + DynaObj
     * DynaObj Children: DynaObj
     */
    bool usePIndex = false;
    bool useCIndex = false;
    bool useChild;
    int pIndex = -1;
    int cIndex = -1;
    ReferencedNod@ parent;
    ReferencedNod@ child;
    uint16 childOffset;
    ModelTargetType ty;
    ItemModelTarget() {
        ty == ModelTargetType::None;
    }
    ItemModelTarget(CMwNod@ parent) {
        ty = ModelTargetType::AllChildren;
        @this.parent = ReferencedNod(parent);
    }
    ItemModelTarget(CMwNod@ parent, int parentIx) {
        ty = ModelTargetType::ArrayElement;
        @this.parent = ReferencedNod(parent);
        pIndex = parentIx;
    }
    ItemModelTarget(CMwNod@ parent, int parentIx, CMwNod@ child, uint16 offset) {
        ty = ModelTargetType::IndirectChild;
        @this.parent = ReferencedNod(parent);
        pIndex = parentIx;
        @this.child = ReferencedNod(child);
        childOffset = offset;
    }
    ItemModelTarget(CMwNod@ parent, CMwNod@ child, uint16 offset) {
        ty = ModelTargetType::DirectChild;
        @this.parent = ReferencedNod(parent);
        @this.child = ReferencedNod(child);
        childOffset = offset;
    }
    ~ItemModelTarget() {
    }
    bool get_IsNull() {
        return ty == ModelTargetType::None;
    }
    bool get_IsAnyChild() {
        return ty & ModelTargetType::AnyChild_AndTest != ModelTargetType::None;
    }
    CMwNod@ GetChildNod() {
        if (child is null) return null;
        return child.nod;
    }
    CMwNod@ GetParentNod() {
        if (parent is null) return null;
        return parent.nod;
    }
    const string get_TypeName() {
        if (child !is null) {
            return child.TypeName;
        }
        if (parent is null || parent.nod is null) return "None";
        if (pIndex >= 0) {
            if (parent.TypeName == "NPlugItem_SVariantList") {
                return "NPlugItem_SVariant";
            } else if (parent.TypeName == "CPlugPrefab") {
                return "NPlugPrefab_SEntRef";
            }
            return "Element of " + parent.TypeName;
        }
        return parent.TypeName;
    }
    const string ToString() const {
        if (parent is null || parent.nod is null) return "None";
        if (ty == ModelTargetType::AllChildren) return parent.TypeName + " (All Children)";
        if (ty == ModelTargetType::DirectChild) return child.TypeName + " (Direct)";
        if (ty == ModelTargetType::IndirectChild) return child.TypeName + " (Indirect @ "+pIndex+")";
        if (ty == ModelTargetType::ArrayElement) {
            if (parent.TypeName == "NPlugItem_SVariantList") {
                return "NPlugItem_SVariant @ " + pIndex;
            } else if (parent.TypeName == "CPlugPrefab") {
                return "NPlugPrefab_SEntRef @ " + pIndex;
            }
            return "Element " + pIndex + " of " + parent.TypeName;
        }
        return "Unknown? " + tostring(ty);
    }
}

funcdef void EntityPickerCB(ItemModelTarget@ target);

class MatchModelType {
    ModelTargetType ty;
    uint[]@ classIds;
    MatchModelType(ModelTargetType ty, uint[]@ classIds) {
        this.ty = ty;
        @this.classIds = classIds;
    }

    bool Match(CMwNod@ parent, int index) {
        if (index < 0 || parent is null) return false;
        return ty & ModelTargetType::ArrayElement != ModelTargetType::None
            && classIds is null || classIds.Find(Reflection::TypeOf(parent).ID) >= 0;
    }
    bool Match(CMwNod@ parent, int index, CMwNod@ child) {
        if (index < 0 || parent is null || child is null) return false;
        return ty & ModelTargetType::IndirectChild != ModelTargetType::None
            && classIds is null || classIds.Find(Reflection::TypeOf(child).ID) >= 0;
    }
    bool Match(CMwNod@ parent, CMwNod@ child) {
        if (parent is null || child is null) return false;
        return ty & ModelTargetType::DirectChild != ModelTargetType::None
            && classIds is null || classIds.Find(Reflection::TypeOf(child).ID) >= 0;
    }
    bool Match(CMwNod@ parent) {
        if (parent is null) return false;
        return ty & ModelTargetType::AllChildren != ModelTargetType::None
            && classIds is null || classIds.Find(Reflection::TypeOf(parent).ID) >= 0;
    }
    bool Match(CMwNod@ parent, uint16 offset) {
        return classIds is null && ty & ModelTargetType::AnyChild_AndTest != ModelTargetType::None;
    }
}


class ItemModelTreePicker : ItemModelTreeElement {
    EntityPickerCB@ callback;
    // bool allowIndexed;
    // class IDs
    MatchModelType@ matcher;

    ItemModelTreePicker(ItemModelTreePicker@ parent, int parentIx, CMwNod@ nod, const string &in name, EntityPickerCB@ cb, MatchModelType@ matcher, uint16 nodOffset = 0xFFFF, bool isEditable = false) {
        super(parent, parentIx, nod, name, false, nodOffset, isEditable);
        isPicker = true;
        drawProperties = false;
        @callback = cb;
        @this.matcher = matcher;
        // allowIndexed = allowIndexed;
    }

    void MkAndDrawChildNode(CMwNod@ nod, const string&in name) override {
        ItemModelTreePicker(this, currentIndex, nod, name, callback, matcher).Draw();
    }

    void MkAndDrawChildNode(CMwNod@ nod, uint16 offset, const string&in name) override {
        ItemModelTreePicker(this, currentIndex, nod, name, callback, matcher, offset).Draw();
    }

    string get_pickDirectChildLabel() { return "This Nod (Direct)"; }
    string get_pickIndirectChildLabel() { return "This Nod (Indirect)"; }
    string get_pickArrayElementLabel() { return "This Element"; }
    string get_pickAllChildrenLabel() { return "All Children"; }

    void DrawPickable() override {
        bool matchDirectChild = MyNodClassMatches(ModelTargetType::DirectChild);
        bool matchIndirectChild = MyNodClassMatches(ModelTargetType::IndirectChild);
        bool matchArrayElement = MyNodClassMatches(ModelTargetType::ArrayElement);
        bool matchAllChildren = MyNodClassMatches(ModelTargetType::AllChildren);

        bool sameLine = false;
        if (matchDirectChild && UX::SmallButton(pickDirectChildLabel)) {
            if (sameLine) UI::SameLine();
            callback(ItemModelTarget(parent.nod, nod, nodOffset));
        }
        sameLine = sameLine || matchDirectChild;
        if (matchIndirectChild && UX::SmallButton(pickIndirectChildLabel)) {
            if (sameLine) UI::SameLine();
            callback(ItemModelTarget(parent.nod, parent.currentIndex, nod, nodOffset));
        }
        sameLine = sameLine || matchIndirectChild;
        if (matchArrayElement && UX::SmallButton(pickArrayElementLabel)) {
            if (sameLine) UI::SameLine();
            callback(ItemModelTarget(nod, currentIndex));
        }
        sameLine = sameLine || matchArrayElement;
        if (matchAllChildren && UX::SmallButton(pickAllChildrenLabel)) {
            if (sameLine) UI::SameLine();
            callback(ItemModelTarget(nod));
        }
        sameLine = sameLine || matchAllChildren;
    }

    bool MyNodClassMatches(ModelTargetType ty) {
        if (matcher.ty & ty == ModelTargetType::None) return false;
        if (ty == ModelTargetType::ArrayElement) {
            return matcher.Match(nod, currentIndex);
        } else if (ty == ModelTargetType::DirectChild) {
            if (currentIndex >= 0 || parent is null || parent.currentIndex >= 0) return false;
            return matcher.Match(parent.nod, nod)
                || matcher.Match(parent.nod, nodOffset);
        } else if (ty == ModelTargetType::IndirectChild) {
            if (currentIndex >= 0 || parent is null || parent.currentIndex < 0) return false;
            return matcher.Match(parent.nod, parent.currentIndex, nod);
        } else if (ty == ModelTargetType::AllChildren) {
            if (hasElements) return false;
            if (!SupportsAllChildren) return false;
            return matcher.Match(nod);
        }
        return false;
    }

    bool get_SupportsAllChildren() {
        return dynaObject !is null || staticObj !is null;
    }
}

// class ItemModelTreePickerSource : ItemModelTreePicker {
//     ItemModelTreePickerSource(ItemModelTreePicker@ parent, int parentIx, CMwNod@ nod, const string &in name, EntityPickerCB@ cb, ) {
//         super(parent, parentIx, nod, name, cb, matcher, allowIndexed);
//     }

//     void MkAndDrawChildNode(CMwNod@ nod, const string&in name) override {
//         ItemModelTreePickerSource(this, currentIndex, nod, name, callback, matcher, allowIndexed).Draw();
//     }
// }



class ItemModelBrowserTab : Tab {
    ItemModelBrowserTab(TabGroup@ p) {
        super(p, "Model Browser", "");
    }

    CGameItemModel@ GetItemModel() {
        if (selectedItemModel is null) return null;
        return selectedItemModel.AsItemModel();
    }

    void DrawInner() override {
        auto item = GetItemModel();
        if (item is null) {
            UI::Text("No item.");
            return;
        }
        DrawItem(item);
    }

    void DrawItem(CGameItemModel@ item) {
        ItemModel(item).DrawTree();
    }
}

class IE_ItemModelBrowserTab : ItemModelBrowserTab {
    IE_ItemModelBrowserTab(TabGroup@ p) {
        super(p);
    }

    CGameItemModel@ GetItemModel() override {
        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        return ieditor.ItemModel;
    }

    void DrawItem(CGameItemModel@ item) override {
        ItemModel(item, true, true).DrawTree();
    }
}

class BlockModelBrowserTab : Tab {
    BlockModelBrowserTab(TabGroup@ p, const string &in name) {
        super(p, name, "");
    }

    CGameCtnBlockInfo@ GetBlockInfo() {
        if (selectedBlockInfo is null) return null;
        return selectedBlockInfo.AsBlockInfo();
    }

    void DrawInner() override {
        auto block = GetBlockInfo();
        if (block is null) {
            UI::Text("No block.");
            return;
        }
        DrawBlock(block);
    }

    void DrawBlock(CGameCtnBlockInfo@ block) {
        ItemModelTreeElement(null, -1, block, "BlockInfo").Draw();
    }
}

class NormalBlockModelBrowserTab : BlockModelBrowserTab {
    NormalBlockModelBrowserTab(TabGroup@ p) {
        super(p, "Norm. Block Browser");
    }
}
class GhostBlockModelBrowserTab : BlockModelBrowserTab {
    GhostBlockModelBrowserTab(TabGroup@ p) {
        super(p, "Ghost/Free Block Browser");
    }

    CGameCtnBlockInfo@ GetBlockInfo() override {
        if (selectedGhostBlockInfo is null) return null;
        return selectedGhostBlockInfo.AsBlockInfo();
    }
}
