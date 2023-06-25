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
            DrawEMEdition();
            DrawEMTree();
            UI::TreePop();
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
        }

        auto emeCommon = cast<CGameCommonItemEntityModelEdition>(eme);
        bool isCrystal = emeCommon !is null && emeCommon.MeshCrystal !is null;

        if (emeCommon !is null) {
            UI::Text("Is a Crystal? " + isCrystal);
            if (isEditable && isCrystal) {
                UI::SameLine();
                if (UX::SmallButton("Nullify")) {
                    @emeCommon.MeshCrystal = null;
                }
            }
        }

        if (emeCommon is null) {
            UI::Text("EntityModelEdition is an unknown type: " + UnkType(eme));
            return;
        }
        // UI::Text("Todo: more?");
    }

    void DrawEMTree() {
        ItemModelTreeElement(null, -1, item.EntityModel, "EntityModel", drawProperties, GetOffset(item, "EntityModel"), isEditable).Draw();
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
    CGameItemModel@ itemModel;

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
        } else {
            UI::Text("Unknown nod of type: " + UnkType(nod));
        }
    }

    void Draw(CGameItemModel@ itemModel) {
        if (StartTreeNode(name + " :: CGameItemModel", UI::TreeNodeFlags::DefaultOpen)) {
            MkAndDrawChildNode(itemModel.EntityModel, "EntityModel");
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
                        LabeledValue("HiddenInManualCycle: ", varList.Variants[i].HiddenInManualCycle);
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
            MkAndDrawChildNode(nod, "PrefabFid.Nod");
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
                uint nbLights = Dev::GetOffsetUint32(s2m, 0x168 + 0x8);
                uint nbLightUserModels = Dev::GetOffsetUint32(s2m, 0x178 + 0x8);
                uint nbCustomMaterials = Dev::GetOffsetUint32(s2m, 0x1F8 + 0x8);
                UI::Text("nbVisualIndexedTriangles: " + nbVisualIndexedTriangles);
                UI::Text("nbLights: " + nbLights);
                DrawUserLightsAt("nbLightUserModels: " + nbLightUserModels, nod, 0x178);
                DrawMaterialsAt("nbMaterials: " + nbMaterials, nod, 0xc8);
                DrawMaterialsAt("nbCustomMaterials: " + nbCustomMaterials, nod, 0x1F8);
                DrawUserMatIntsAt("nbMaterialUserInsts: " + nbMaterialUserInsts, nod, 0xF8);
            }
            MkAndDrawChildNode(skel, 0x78, "Skel");
            EndTreeNode();
        }
    }

    void DrawUserLightsAt(const string &in title, CMwNod@ nod, uint16 offset) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            for (uint i = 0; i < len; i++) {
                UI::PushID("userlight"+i);
                auto light = cast<CPlugLightUserModel>(Dev::GetOffsetNod(buf, 0x8 * i));
                if (light is null) {
                    UI::Text("Light " + i + ". null");
                } else {
                    UI::Text("Light " + i + ":");
                    UI::Indent();
                    if (isEditable) {
                        light.Color = UI::InputColor3("Color", light.Color);
                        light.Intensity = UI::InputFloat("Intensity", light.Intensity);
                        light.Distance = UI::InputFloat("Distance", light.Distance);
                        light.PointEmissionRadius = UI::InputFloat("PointEmissionRadius", light.PointEmissionRadius);
                        light.PointEmissionLength = UI::InputFloat("PointEmissionLength", light.PointEmissionLength);
                        light.SpotInnerAngle = UI::InputFloat("SpotInnerAngle", light.SpotInnerAngle);
                        light.SpotOuterAngle = UI::InputFloat("SpotOuterAngle", light.SpotOuterAngle);
                        light.SpotEmissionSizeX = UI::InputFloat("SpotEmissionSizeX", light.SpotEmissionSizeX);
                        light.SpotEmissionSizeY = UI::InputFloat("SpotEmissionSizeY", light.SpotEmissionSizeY);
                        light.NightOnly = UI::Checkbox("NightOnly", light.NightOnly);
                    } else {
                        UI::BeginDisabled();
                        light.Color = UI::InputColor3("Color", light.Color);
                        UI::EndDisabled();
                        UI::Text("Intensity: " + light.Intensity);
                        UI::Text("Distance: " + light.Distance);
                        UI::Text("PointEmissionRadius: " + light.PointEmissionRadius);
                        UI::Text("PointEmissionLength: " + light.PointEmissionLength);
                        UI::Text("SpotInnerAngle: " + light.SpotInnerAngle);
                        UI::Text("SpotOuterAngle: " + light.SpotOuterAngle);
                        UI::Text("SpotEmissionSizeX: " + light.SpotEmissionSizeX);
                        UI::Text("SpotEmissionSizeY: " + light.SpotEmissionSizeY);
                        UI::Text("NightOnly: " + light.NightOnly);
                    }
                    UI::Unindent();
                }
                UI::PopID();
            }
            EndTreeNode();
        }
    }

    void DrawMaterialsAt(const string &in title, CMwNod@ nod, uint16 offset) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            for (uint i = 0; i < len; i++) {
                auto mat = cast<CPlugMaterial>(Dev::GetOffsetNod(buf, 0x8 * i));
                if (mat is null) {
                    UI::Text("" + i + ". null");
                } else {
                    auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(mat, 0x8));
                    if (fid is null) {
                        UI::Text("" + i + ". Unknown material.");
                    } else {
                        UI::Text("" + i + ". " + fid.FileName);
                    }
                }
            }
            EndTreeNode();
        }
    }

    void DrawUserMatIntsAt(const string &in title, CMwNod@ nod, uint16 offset) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            auto elSize = 0x18;
            for (uint i = 0; i < len; i++) {
                auto mat = cast<CPlugMaterialUserInst>(Dev::GetOffsetNod(buf, elSize * i));
                auto u1 = Dev::GetOffsetUint64(buf, elSize * i + 0x8);
                auto u2 = Dev::GetOffsetUint64(buf, elSize * i + 0x10);
                // these seem to do/mean nothing
                // string suffix = " / " + u1 + " / " + Text::Format("0x%x", u2);
                string suffix = "";
                if (mat is null) {
                    UI::Text("" + i + ". null" + suffix);
                } else {
                    UI::Text("" + i + ". " + mat._Name.GetName() + suffix);
                    // UI::Indent();
#if SIG_DEVELOPER
                    UI::SameLine();
                    if (UX::SmallButton(Icons::Cube + " Explore##matUserInst" + i)) {
                        ExploreNod("MaterialUserInst " + i + ".", mat);
                    }
#endif
                    // UI::SameLine();
                    // UI::Text(mat.Link.GetName());
                }
            }
            EndTreeNode();
        }
    }

    void DrawMaterialIdsAt(const string &in title, CMwNod@ nod, uint16 offset) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto buf = Dev::GetOffsetNod(nod, offset);
            auto len = Dev::GetOffsetUint32(nod, offset + 0x8);
            auto objSize = 0x2;
            for (uint i = 0; i < len; i++) {
                EPlugSurfaceMaterialId PhysicId = EPlugSurfaceMaterialId(Dev::GetOffsetUint8(buf, objSize * i));
                EPlugSurfaceGameplayId GameplayId = EPlugSurfaceGameplayId(Dev::GetOffsetUint8(buf, objSize * i + 0x1));
                if (StartTreeNode("Material " + i + ".", true, UI::TreeNodeFlags::DefaultOpen)) {
                    if (isEditable) {
                        PhysicId = DrawComboEPlugSurfaceMaterialId("PhysicId", PhysicId);
                        GameplayId = DrawComboEPlugSurfaceGameplayId("GameplayId", GameplayId);
                        Dev::SetOffset(buf, objSize * i, uint8(PhysicId));
                        Dev::SetOffset(buf, objSize * i + 0x1, uint8(GameplayId));
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


    void Draw(CTrackMania@ asdf) {
        if (StartTreeNode(name + " :: \\$f8fCTrackMania", UI::TreeNodeFlags::DefaultOpen)) {
            UI::Text("\\$f80todo");
            EndTreeNode();
        }
    }

    bool StartTreeNode(const string &in title, UI::TreeNodeFlags flags = UI::TreeNodeFlags::DefaultOpen) {
        return StartTreeNode(title, false, flags);
    }

    bool StartTreeNode(const string &in title, bool suppressDev = false, UI::TreeNodeFlags flags = UI::TreeNodeFlags::DefaultOpen) {
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
            UI::TextDisabled(Text::Format("0x%03x", nodOffset));
            UI::SameLine();
            if (UX::SmallButton(Icons::Cube + " Explore Nod")) {
                ExploreNod(title, nod);
            }
//#if DEV
            UI::SameLine();
            CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(nod)));
//#endif
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




uint64 Dev_GetPointerForNod(CMwNod@ nod) {
    if (nod is null) throw('nod was null');
    auto tmpNod = CMwNod();
    uint64 tmp = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, nod);
    uint64 ptr = Dev::GetOffsetUint64(tmpNod, 0);
    Dev::SetOffset(tmpNod, 0, tmp);
    return ptr;
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
    }
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
