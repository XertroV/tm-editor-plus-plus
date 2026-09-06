const uint16 IM_GameSkinOffset = 0xA0;
// const uint16 IM_AuthorOffset = 0xA0;

// used for expanding/contracting entity lists
uint g_NewNbEnts = 10;

#if DEBUG_BROWSER
const UI::TreeNodeFlags DEFAULT_OPEN = UI::TreeNodeFlags::None;
#else
const UI::TreeNodeFlags DEFAULT_OPEN = UI::TreeNodeFlags::DefaultOpen;
#endif

const UI::TreeNodeFlags TREE_F_NONE = UI::TreeNodeFlags::None;

class ItemBrowser_KinDynaEnt {
    CPlugPrefab@ owner;
    uint localIx;
}

class ItemBrowser_KinDynaMap {
    CPlugPrefab@ root;
    array<ItemBrowser_KinDynaEnt@> ents;

    void Add(CPlugPrefab@ owner, uint localIx) {
        auto e = ItemBrowser_KinDynaEnt();
        @e.owner = owner;
        e.localIx = localIx;
        ents.InsertLast(e);
    }

    int IxForEnt(CPlugPrefab@ owner, uint localIx) {
        if (owner is null) return -1;
        for (uint i = 0; i < ents.Length; i++) {
            if (ents[i].owner is owner && ents[i].localIx == localIx) return int(i);
        }
        return -1;
    }
}

ItemBrowser_KinDynaMap@ g_IB_ActiveKinMap;
int g_IB_KinHoverDraw = -1;
int g_IB_KinHoverAcc = -1;
uint64 g_IB_KinHoverRootDraw = 0;
uint64 g_IB_KinHoverRootAcc = 0;

UI::TreeNodeFlags ItemBrowser_NamedChildTreeFlags(const string &in childName) {
    if (childName == "StaticShape") return TREE_F_NONE;
    return DEFAULT_OPEN;
}

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
        ItemBrowser_KinHoverBeginFrame();
        // UI::TreeNodeFlags::OpenOnArrow
        if (UI::TreeNode(item.IdName, DEFAULT_OPEN)) {
            UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
#if SIG_DEVELOPER
            if (UX::SmallButton(Icons::Cube + " Explore ItemModel")) {
                ExploreNod(item);
            }
            UI::SameLine();
            CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(item)));
#endif
            ClickableLabel("Author", item.Author.GetName());
            LabeledValue("CollectionId", int(item.CollectionId));
            if (!isEditable) {
                LabeledValue("CollectionId_Text", item.CollectionId_Text);
            } else {
                item.CollectionId_Text = UI::InputText("CollectionId_Text", item.CollectionId_Text);
            }
            if (TmGameVersion >= "2024-06-28_13_46") {
                bool disableAutoCreateSound = Editor::GetItemModel_DisableAutoCreateSound(item);
                if (isEditable) {
                    bool setDACS = UI::Checkbox("DisableAutoCreateSound", disableAutoCreateSound);
                    if (setDACS != disableAutoCreateSound) {
                        Editor::SetItemModel_DisableAutoCreateSound(item, setDACS);
                    }
                } else {
                    LabeledValue("DisableAutoCreateSound", disableAutoCreateSound);
                }
            }
            DrawSkin();
            DrawMatModifier();
            DrawEMEdition();
            DrawEMTree();

            UI::PopStyleVar();
            UI::TreePop();
        }
    }

    void DrawMatModifier() {
        ItemModelTreeElement(null, -1, item.MaterialModifier, "MaterialModifier", drawProperties, GetOffset(item, "MaterialModifier"), isEditable).Draw();
    }

    void DrawSkin() {
        auto skin = cast<CPlugGameSkin>(Dev::GetOffsetNod(item, O_ITEM_MODEL_SKIN));
        if (skin !is null) {
            auto el = ItemModelTreeElement(null, -1, skin, "GameSkin", drawProperties, O_ITEM_MODEL_SKIN, isEditable);
            el.Draw();
        }
    }

    void DrawEMEdition() {
        if (isEditable) {
            if (UX::DangerSmallButton("Nullify EntityModelEdition", "nullify-eme",
                "Runs TransformMaterialsToMatIds on all surfaces first, then nulls the EME.\n"
                + "After nullifying, the item will fail to save if any CPlugSurfaces still have materials.")) {
                startnew(CoroutineFunc(NullifyEMEAndTransformSurfaces));
            }
            AddSimpleTooltip("Nullifies the EntityModelEdition. Materials are transformed to MatIds where possible to keep the item saveable.");
        }

        auto eme = item.EntityModelEdition;
        if (eme is null) {
            UI::Text("No EntityModelEdition");
            return;
        }

        auto emeCommon = cast<CGameCommonItemEntityModelEdition>(eme);
        auto emeBlock = cast<CGameBlockItem>(eme);
        bool isCrystal = emeCommon !is null && emeCommon.MeshCrystal !is null;

        if (emeCommon !is null) {
            UI::Text("Is a Crystal? " + isCrystal);
            if (isEditable && isCrystal) {
                UI::SameLine();
                if (UX::SmallButton("Nullify")) {
                    Dev::SetOffset(emeCommon, GetOffset(emeCommon, "MeshCrystal"), uint64(0));
                }
            }
        }
        Draw_EME_Tree(eme);
    }

    // Issue #28: raw-zeroing EntityModelEdition leaves surfaces with materials,
    // which crashes the game on save/placement. Transform Materials -> MatIds on
    // every surface reachable from EntityModel (default + variants) first, then
    // null the EME via handle assignment so the old nod is released properly.
    void NullifyEMEAndTransformSurfaces() {
        if (item is null) return;
        Editor::NullifyItemModelEME(item, /*notify=*/true);
    }

    void DrawEMTree() {
        ItemModelTreeElement(null, -1, item.EntityModel, "EntityModel", drawProperties, GetOffset(item, "EntityModel"), isEditable).Draw();
    }

    void Draw_EME_Tree(CMwNod@ eme) {
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
    int AuxInfo_ClipFace = -1;

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
    CPlugVisual@ visual;
    CPlugVisualIndexedTriangles@ visIxTris;
    vec2 uvShift = vec2(0.1, 0.0);
    int uvShiftSem = int(VisualUVs::SEM_TEXCOORD0);
    CPlugGameSkin@ skin;
    CPlugMaterial@ mat;
    CPlugLight@ light;
    CPlugLightUserModel@ userLight;
    CPlugMaterialUserInst@ userMat;
    GxLight@ gxLight;
    CGameItemModel@ itemModel;
    CSystemPackDesc@ sysPackDesc;
    CGameCtnBlockSkin@ blockSkin;
    CGameBlockItem@ blockItem;
    CPlugCrystal@ crystal;
    CGameCtnBlockInfo@ blockInfo;
    CGameCtnBlockInfoVariant@ infoVar;
    CSystemFidFile@ fid;
    CGameCtnBlockInfoMobil@ blockInfoMobil;
    CGameCtnBlockUnitInfo@ unitInfo;
    CGameCommonItemEntityModelEdition@ commonEME;
    CPlugGameSkinAndFolder@ matMod;
    CHmsLightMapCache@ lmCache;
    CHmsLightMap@ lm;
    CPlugFxSystemNode_Parallel@ fxNodeParallel;
    CPlugFxSystemNode@ fxNode;
    CPlugFxSystemNode_ParticleEmitter@ fxNodeParticle;
    CPlugParticleGpuModel@ particleGpuModel;
    CPlugParticleEmitterModel@ particleEmitterModel;
    CPlugTurret@ turret;
    CGameSaveLaunchedCheckpoints@ gslcps;
    CPlugSkel@ skel;

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
        @this.visIxTris = cast<CPlugVisualIndexedTriangles>(nod);
        @this.visual = cast<CPlugVisual>(nod);
        @this.skin = cast<CPlugGameSkin>(nod);
        @this.mat = cast<CPlugMaterial>(nod);
        @this.light = cast<CPlugLight>(nod);
        @this.userLight = cast<CPlugLightUserModel>(nod);
        @this.userMat = cast<CPlugMaterialUserInst>(nod);
        @this.gxLight = cast<GxLight>(nod);
        @this.sysPackDesc = cast<CSystemPackDesc>(nod);
        @this.blockSkin = cast<CGameCtnBlockSkin>(nod);
        @this.blockItem = cast<CGameBlockItem>(nod);
        @this.crystal = cast<CPlugCrystal>(nod);
        @this.blockInfo = cast<CGameCtnBlockInfo>(nod);
        @this.infoVar = cast<CGameCtnBlockInfoVariant>(nod);
        @this.fid = cast<CSystemFidFile>(nod);
        @this.blockInfoMobil = cast<CGameCtnBlockInfoMobil>(nod);
        @this.unitInfo = cast<CGameCtnBlockUnitInfo>(nod);
        @this.commonEME = cast<CGameCommonItemEntityModelEdition>(nod);
        @this.matMod = cast<CPlugGameSkinAndFolder>(nod);
        @this.lmCache = cast<CHmsLightMapCache>(nod);
        @this.lm = cast<CHmsLightMap>(nod);
        @this.fxNodeParallel = cast<CPlugFxSystemNode_Parallel>(nod);
        @this.fxNode = cast<CPlugFxSystemNode>(nod);
        @this.fxNodeParticle = cast<CPlugFxSystemNode_ParticleEmitter>(nod);
        @this.particleEmitterModel = cast<CPlugParticleEmitterModel>(nod);
        @this.particleGpuModel = cast<CPlugParticleGpuModel>(nod);
        @this.turret = cast<CPlugTurret>(nod);
        @this.gslcps = cast<CGameSaveLaunchedCheckpoints>(nod);
        @this.skel = cast<CPlugSkel>(nod);
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

    bool ReplaceThisModel(CMwNod@ dst) {
        if (dst is null) return false;
        if (parent is null) {
            NotifyError("Clone to New: no parent to attach the new nod");
            return false;
        }
        auto prefab = cast<CPlugPrefab>(parent.nod);
        if (prefab !is null && parentIx >= 0) {
            MeshDuplication::SetEntRefModel(prefab, parentIx, dst);
            return true;
        }
        if (parent.nod !is null && nodOffset < 0xFFFF) {
            ManipPtrs::Replace(parent.nod, nodOffset, dst, true);
            return true;
        }
        NotifyError("Clone to New: cannot replace parent Model pointer");
        return false;
    }

    void CloneKcToNew() {
        if (kenematicConstraint is null) return;
        auto dst = ItemEditor::CloneKinematicConstraint(kenematicConstraint);
        if (!ReplaceThisModel(dst)) return;
        @nod = dst;
        @kenematicConstraint = dst;
        NotifySuccess("Cloned kinematic constraint to a new nod");
    }

    void CloneDynaToNew() {
        if (dynaObject is null) return;
        auto dst = MeshDuplication::CloneDynaObjectModel(dynaObject);
        if (!ReplaceThisModel(dst)) return;
        @nod = dst;
        @dynaObject = dst;
        NotifySuccess("Cloned dyna object to a new nod (Mesh/Shape shared)");
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
        } else if (visIxTris !is null) {
            Draw(visIxTris);
        } else if (visual !is null) {
            Draw(visual);
        } else if (surf !is null) {
            Draw(surf);
        } else if (skin !is null) {
            Draw(skin);
        } else if (blockSkin !is null) {
            Draw(blockSkin);
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
        } else if (commonEME !is null) {
            Draw(commonEME);
        } else if (matMod !is null) {
            Draw(matMod);
        } else if (lmCache !is null) {
            Draw(lmCache);
        } else if (lm !is null) {
            Draw(lm);
        } else if (fxNodeParallel !is null) {
            Draw(fxNodeParallel);
        } else if (fxNodeParticle !is null) {
            Draw(fxNodeParticle);
        } else if (fxNode !is null) {
            Draw(fxNode);
        } else if (particleGpuModel !is null) {
            Draw(particleGpuModel);
        } else if (particleEmitterModel !is null) {
            Draw(particleEmitterModel);
        } else if (turret !is null) {
            Draw(turret);
        } else if (gslcps !is null) {
            Draw(gslcps);
        } else if (skel !is null) {
            Draw(skel);
        } else {
            UI::Text("Unknown nod of type: " + UnkType(nod));
        }
    }

    void Draw(CGameItemModel@ itemModel) {
        if (StartTreeNode(name + " ::\\$f8f CGameItemModel", DEFAULT_OPEN)) {
            MkAndDrawChildNode(itemModel.EntityModelEdition, "EntityModelEdition");
            MkAndDrawChildNode(itemModel.EntityModel, "EntityModel");
            EndTreeNode();
        }
    }

    void Draw(CGameCommonItemEntityModelEdition@ commonEME) {
        if (StartTreeNode(name + " ::\\$f8f CGameCommonItemEntityModelEdition", DEFAULT_OPEN)) {
            // if (isEditable) {
            // } else {
            // }
            MkAndDrawChildNode(commonEME.MeshCrystal, GetOffset(commonEME, "MeshCrystal"), "MeshCrystal");
            // print("CGameCommonItemEntityModelEdition.Triggers: " + tostring(commonEME.Triggers));
            // print("CGameCommonItemEntityModelEdition.InventoryName: " + tostring(commonEME.InventoryName));
            // print("CGameCommonItemEntityModelEdition.InventoryDescription: " + tostring(commonEME.InventoryDescription));
            // print("CGameCommonItemEntityModelEdition.InventoryOccupation: " + tostring(commonEME.InventoryOccupation));
            // print("CGameCommonItemEntityModelEdition.IdName: " + tostring(commonEME.IdName));
            // print("CGameCommonItemEntityModelEdition.Id: " + tostring(commonEME.Id));
            EndTreeNode();
        }
    }

    void Draw(CPlugSkel@ skel) {
        if (StartTreeNode(name + " :: \\$f8f CPlugSkel", DEFAULT_OPEN)) {
            if (StartTreeNode("Joints (" + skel.JointNames.Length + ")", UI::TreeNodeFlags::Framed)) {
                for (uint i = 0; i < skel.JointNames.Length; i++) {
                    DrawSkelJoint(skel, i);
                }
                EndTreeNode();
            }
            EndTreeNode();
        }
    }

    vec3 DrawSkelJoint(CPlugSkel@ skel, uint i) {
        if (i > skel.JointNames.Length) {
            UI::Text("No Joint");
            return vec3();
        }
        auto name = skel.JointNames[i].GetName();
        // UI::Text(FmtUintHex(skel.JointNames[i].Value) + " : " + skel.JointNames[i].GetName());
        if (StartTreeNode("Joint " + (i+1) + ". " + name, true, UI::TreeNodeFlags::None)) {
            auto parentIx = skel.JointParentIndexs[i];
            UI::Text("RefGlobalJoints(Iso4).Pos: " + Iso4_GetPos(skel.RefGlobalJoints[i]).ToString());
            UI::Text("RefGlobalJointsTQ.Pos: " + skel.RefGlobalJointsTQ[i].Trans.ToString());
            UI::Text("RefGlobalJointsTQ.Quat: " + skel.RefGlobalJointsTQ[i].Quat.ToString());
            UI::Text("JointFixedTrans: " + skel.JointFixedTranss[i]);
            UI::Text("RefLocJointTrans: " + skel.RefLocalJointsTranss[i].ToString());
            UI::Text("Parent: " + parentIx);
            auto parentPos = DrawSkelJoint(skel, parentIx);
            EndTreeNode();
        }
        return vec3();
    }


    void Draw(CPlugParticleGpuModel@ particleGpuModel) {
        if (StartTreeNode(name + " :: \\$f8f CPlugParticleGpuModel", DEFAULT_OPEN)) {
            UI::Text("todo: particleGpuModel");
            EndTreeNode();
        }
    }
    void Draw(CPlugParticleEmitterModel@ particleEmitterModel) {
        if (StartTreeNode(name + " :: \\$f8f CPlugParticleEmitterModel", DEFAULT_OPEN)) {
            // particleEmitterModel.ParticleEmitterSubModels
            UI::Text("todo: particleEmitterModel");
            EndTreeNode();
        }
    }
    void Draw(CPlugFxSystemNode_Parallel@ fxNodeParallel) {
        if (StartTreeNode(name + " :: \\$f8f CPlugFxSystemNode_Parallel", DEFAULT_OPEN)) {
            if (StartTreeNode("Children", true)) {
                for (uint i = 0; i < fxNodeParallel.Children.Length; i++) {
                    MkAndDrawChildNode(fxNodeParallel.Children[i], 0x8 * i, "Child " + i);
                }
                EndTreeNode();
            }
            // UI::TextDisabled("CPlugFxSystemNode");
            DrawFxNodeInner(cast<CPlugFxSystemNode>(fxNodeParallel));
            EndTreeNode();
        }
    }

    void Draw(CPlugFxSystemNode_ParticleEmitter@ fxNodeParticle) {
        if (StartTreeNode(name + " :: \\$f8f CPlugFxSystemNode_ParticleEmitter", DEFAULT_OPEN)) {
            MkAndDrawChildNode(fxNodeParticle.Model, GetOffset(fxNodeParticle, "Model"), "Model");
            // UI::TextDisabled("CPlugFxSystemNode");
            DrawFxNodeInner(cast<CPlugFxSystemNode>(fxNodeParticle));
            EndTreeNode();
        }
    }

    void Draw(CPlugFxSystemNode@ fxNode) {
        UI::Text("Todo: CPlugFxSystemNode");
    }

    void DrawFxNodeInner(CPlugFxSystemNode@ fxNode) {
        CopiableLabeledValue("Name", fxNode.Name.GetName());
    }

    void Draw(CGameCtnBlockInfo@ blockInfo) {
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockInfo", AuxInfo_ClipFace >= 0 ? TREE_F_NONE : DEFAULT_OPEN)) {
            auto biClip = cast<CGameCtnBlockInfoClip>(blockInfo);
            if (biClip !is null) {
                DrawBiClipExtra(biClip);
            }

            auto mmPlacementTag = Dev::GetOffsetNat2(blockInfo, O_BLOCKINFO_MATMODPLACEMENTTAG);
            string mmPlacementTagsStr = ItemPlace_StringConsts::LookupJoined(mmPlacementTag);
            DrawMwId("Name", blockInfo.Id);

            CopiableLabeledValue("Collection", blockInfo.CollectionId_Text + Text::Format(" (%d)", int(blockInfo.CollectionId)));
            // flags; note: some have no set accessor
            UI::BeginDisabled(!isEditable);
            blockInfo.IsAdvanced = UI::Checkbox("IsAdvanced", blockInfo.IsAdvanced);
            UI::SameLine();
            UI::Checkbox("IsClip", blockInfo.IsClip);
            UI::SameLine();
            blockInfo.IsInternal = UI::Checkbox("IsInternal", blockInfo.IsInternal);

            blockInfo.IsMultiHeightPillarOrVFC = UI::Checkbox("IsMultiHeightPillarOrVFC", blockInfo.IsMultiHeightPillarOrVFC);
            UI::SameLine();
            blockInfo.IsPillar = UI::Checkbox("IsPillar", blockInfo.IsPillar);

            UI::Checkbox("IsPodium", blockInfo.IsPodium);
            UI::SameLine();
            UI::Checkbox("IsRoad", blockInfo.IsRoad);
            UI::SameLine();
            UI::Checkbox("IsTerrain", blockInfo.IsTerrain);
            UI::EndDisabled();

            // mat modifier
            MkAndDrawChildNode(blockInfo.MaterialModifier, O_BLOCKINFO_MATERIALMOD, "MaterialModifier");

            if (isEditable) {
                Dev::SetOffset(blockInfo, O_BLOCKINFO_MATMODPLACEMENTTAG, UX::InputNat2("MatModifierPlacementTag", mmPlacementTag));
            } else {
                CopiableLabeledValue("PageName", blockInfo.PageName);
                CopiableLabeledValue("CatalogPosition", tostring(blockInfo.CatalogPosition));
                // works, but only returns the first type of label
                // try { extra = string(blockInfo.MatModifierPlacementTag.Type); } catch {}
                UI::Text("MatModifierPlacementTag: " + mmPlacementTag.ToString() + " / " + mmPlacementTagsStr);
            }

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

    void DrawBiClipExtra(CGameCtnBlockInfoClip@ clip) {
        LabeledValue("Clip Face: ", ClipFaceStr(AuxInfo_ClipFace));
        DrawMwId("ClipId", clip.Id);
        UI::SameLine();
        DrawMwId("SymmetricalClipId", clip.SymmetricalClipId);

        DrawMwId("ClipGroupId", clip.ClipGroupId);
        UI::SameLine();
        DrawMwId("SymmetricalClipGroupId", clip.SymmetricalClipGroupId);

        DrawMwId("ClipGroupId2", clip.ClipGroupId2);
        UI::SameLine();
        DrawMwId("SymmetricalClipGroupId2", clip.SymmetricalClipGroupId2);

        CopiableLabeledValue("ClipType", tostring(clip.ClipType));
        UI::SameLine();
        CopiableLabeledValue("TopBottomMultiDir", tostring(clip.TopBottomMultiDir));

        if (isEditable) {
            clip.IsFullFreeClip = UI::Checkbox("IsFullFreeClip", clip.IsFullFreeClip);
            UI::SameLine();
            clip.IsExclusiveFreeClip = UI::Checkbox("IsExclusiveFreeClip", clip.IsExclusiveFreeClip);
            clip.CanBeDeletedByFullFreeClip = UI::Checkbox("CanBeDeletedByFullFreeClip", clip.CanBeDeletedByFullFreeClip);
            UI::SameLine();
            clip.IsAlwaysVisibleFreeClip = UI::Checkbox("IsAlwaysVisibleFreeClip", clip.IsAlwaysVisibleFreeClip);
            clip.IsFCTOrFCBIgnoredByVFC = UI::Checkbox("IsFCTOrFCBIgnoredByVFC", clip.IsFCTOrFCBIgnoredByVFC);
            UI::SameLine();
            clip.IsAntiClip = UI::Checkbox("IsAntiClip", clip.IsAntiClip);
        } else {
            LabeledValue("IsFullFreeClip", tostring(clip.IsFullFreeClip));
            UI::SameLine();
            LabeledValue("IsExclusiveFreeClip", tostring(clip.IsExclusiveFreeClip));
            LabeledValue("CanBeDeletedByFullFreeClip", tostring(clip.CanBeDeletedByFullFreeClip));
            UI::SameLine();
            LabeledValue("IsAlwaysVisibleFreeClip", tostring(clip.IsAlwaysVisibleFreeClip));
            LabeledValue("IsFCTOrFCBIgnoredByVFC", tostring(clip.IsFCTOrFCBIgnoredByVFC));
            UI::SameLine();
            LabeledValue("IsAntiClip", tostring(clip.IsAntiClip));
        }

        LabeledValue("HasMesh", Editor::DoesBlockInfoHaveMesh(clip));

        auto bicv = cast<CGameCtnBlockInfoClipVertical@>(clip);
        auto bich = cast<CGameCtnBlockInfoClipHorizontal@>(clip);
        if (bicv !is null) {
            UI::AlignTextToFramePadding();
            DrawMwId("VerticalClipGroupId", bicv.VerticalClipGroupId);
        } else if (bich !is null) {
            UI::AlignTextToFramePadding();
            DrawMwId("HorizontalClipGroupId", bich.HorizontalClipGroupId);
        }
    }

    void DrawMwId(const string &in name, const MwId &in id) {
        string val;
        if (id.Value == uint(-1)) val = "\\$888\\$i";
        CopiableLabeledValue(val + name, toHex(id.Value) + " > " + id.GetName());
    }

    void Draw(CGameCtnBlockInfoVariant@ infoVar) {
        // disable editing info vars and below
        isEditable = false;
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockInfoVariant", UI::TreeNodeFlags::None)) {
            for (uint i = 0; i < infoVar.BlockUnitInfos.Length; i++) {
                MkAndDrawChildNode(infoVar.BlockUnitInfos[i], 0x8 * i, "BlockUnitInfos["+i+"]");
            }
            for (uint i = 0; i < infoVar.Mobils00.Length; i++) {
                MkAndDrawChildNode(infoVar.Mobils00[i], 0x8 * i, "Mobils00["+i+"]");
            }
            auto waterNb = Dev::GetOffsetUint32(infoVar, O_BLOCKVAR_WATER_BUF + 0x8);
            auto waterBufNod = Dev::GetOffsetNod(infoVar, O_BLOCKVAR_WATER_BUF);
            for (uint i = 0; i < waterNb; i++) {
                auto waterNod = Dev::GetOffsetNod(waterBufNod, 0x8 * i);
                DrawWaterArchiveNod(i, waterNod);
            }

            EndTreeNode();
        }
    }

    void DrawWaterArchiveNod(uint i, CMwNod@ water) {
        if (StartTreeNode("Water["+i+"]", true, UI::TreeNodeFlags::None)) {
            // gamedata at 0x0
            // buffer at 0x8 of (int3, int3)
            // 7 floats
            // 0x4 gap
            // 0x38: possible string?
            auto coordPairsBuf = Dev::GetOffsetNod(water, 0x8);
            auto nbCoordPairs = Dev::GetOffsetUint32(water, 0x10);

            for (uint j = 0; j < nbCoordPairs; j++) {
                auto cp1 = Dev::GetOffsetInt3(coordPairsBuf, 0x18 * j);
                auto cp2 = Dev::GetOffsetInt3(coordPairsBuf, 0x18 * j + 0xC);
                LabeledValue("CoordPair["+j+"]", cp1.ToString() + " / " + cp2.ToString());
            }

            auto u02to05 = Dev::GetOffsetVec4(water, 0x18);
            LabeledValue("u02to05", u02to05.ToString());
            auto u06to08 = Dev::GetOffsetVec3(water, 0x28);
            LabeledValue("u06to08", u06to08.ToString());
            auto strPtr = Dev::GetOffsetUint64(water, 0x38);
            LabeledValue("u09 str ptr", Text::FormatPointer(strPtr));
            EndTreeNode();
        }
    }

    void Draw(CGameCtnBlockUnitInfo@ unitInfo) {
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockUnitInfo", UI::TreeNodeFlags::None)) {
            LabeledValue("Offset", unitInfo.Offset.ToString());
            LabeledValue("ClipBakedMobilIndexesForPreview", MwFastBuffer_uint_ToString(unitInfo.ClipBakedMobilIndexesForPreview));
            auto nbClips = unitInfo.AllClips.Length;
            auto northLt = unitInfo.ClipCount_North, eastLt = unitInfo.ClipCount_East + northLt,
                southLt = unitInfo.ClipCount_South + eastLt, westLt = unitInfo.ClipCount_West + southLt,
                topLt = unitInfo.ClipCount_Top + westLt, bottomLt = unitInfo.ClipCount_Bottom + topLt;
            // print("North: " + northLt + ", East: " + eastLt + ", South: " + southLt + ", West: " + westLt);
            int dir = 0; // north

            for (uint i = 0; i < nbClips; i++) {
                dir = i < topLt ? i < westLt ? i < southLt ? i < eastLt ? i < northLt ? 0 : 1 : 2 : 3 : 4 : 5;
                auto treeEl = ItemModelTreeElement(this, currentIndex, unitInfo.AllClips[i], "Clip["+i+"]: " + ClipFaceStr(dir), drawProperties, 0x8 * i, isEditable);
                treeEl.AuxInfo_ClipFace = dir;
                treeEl.Draw();
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
            auto PlacementPatchesBuf = Dev::GetOffsetNod(blockInfoMobil, O_BLOCKINFOMOBIL_PlacementPatches);
            auto nbPlacementPatches = Dev::GetOffsetUint32(blockInfoMobil, O_BLOCKINFOMOBIL_PlacementPatches + 0x8);
            auto buf = RawBuffer(blockInfoMobil, O_BLOCKINFOMOBIL_PlacementPatches, SZ_PLACEMENTPATCH, true);
            if (StartTreeNode("nbPlacementPatches: " + nbPlacementPatches, true)) {
                for (uint i = 0; i < nbPlacementPatches; i++) {
                    if (buf[i].Ptr == 0) {
                        UI::Text("PlacementPatch["+i+"]: <null>");
                        continue;
                    }
                    auto pp = cast<CPlugPlacementPatch>(Dev_GetNodFromPointer(buf[i].Ptr));
                    UI::Text("PlacementPatch["+i+"]: " + pp.Params.GroupId.GetName() + " / LeftVerts: " + pp.LeftVerts.Length + " / CenterVerts: " + pp.CenterVerts.Length + " / RightVerts: " + pp.RightVerts.Length);
                    // UI::Indent();
                    // if (StartTreeNode("Verts", true)) {
                    //     UI::Text("LeftVerts: " + pp.LeftVerts.Length);
                    //     UI::Text("CenterVerts: " + pp.CenterVerts.Length);
                    //     UI::Text("RightVerts: " + pp.RightVerts.Length);
                    //     EndTreeNode();
                    // }
                    // UI::Unindent();
#if SIG_DEVELOPER
                    UI::SameLine();
                    if (UX::SmallButton(Icons::Cube + "##"+i)) {
                        ExploreNod(pp);
                    }
#endif
                }
                EndTreeNode();
            }
            // prefab pointer at 0x130
            EndTreeNode();
        }
    }

    void Draw(CSystemFidFile@ fid) {
        if (StartTreeNode(name + " ::\\$f8f CSystemFidFile \\$8f8" + fid.FileName, DEFAULT_OPEN)) {
            LabeledValue("Size (KB)", fid.ByteSizeEd);
#if SIG_DEVELOPER
            // class id and helper
            auto clsId = Dev_GetFidClassId(fid);
            LabeledValue("Class ID", Text::Format("\\$fa8%08X", clsId));
            if (UI::IsItemHovered()) {
                auto ty = Reflection::GetType(clsId);
                AddSimpleTooltip(ty is null ? "Unknown Type" : ty.Name);
            }
            // container
            LabeledValue("Container", fid.Container.FileName);
            UI::SameLine();
            if (UI::Button(Icons::Cube + "##fid-container")) {
                ExploreNod("Container", fid.Container);
            }
#endif
            // load nod
            if (fid.Nod is null && UI::Button("Load Nod")) {
                Fids::Preload(fid);
            } else {
                MkAndDrawChildNode(fid.Nod, GetOffset(fid, "Nod"), "Nod");
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugStaticObjectModel@ so) {
        if (StartTreeNode(name + " :: \\$f8fCPlugStaticObjectModel", DEFAULT_OPEN)) {
            if (isEditable) {
                UX::CheckboxDevUint32("Generate Shape from Mesh", so, O_STATICOBJMODEL_GENSHAPE);
            } else {
                LabeledValue("Generate Shape from Mesh", Dev::GetOffsetUint32(so, O_STATICOBJMODEL_GENSHAPE) == 1);
            }
            MkAndDrawChildNode(so.Mesh, "Mesh");
            MkAndDrawChildNode(so.Shape, "Shape");
            EndTreeNode();
        }
    }
    void Draw(CPlugPrefab@ prefab) {
        hasElements = true;
        if (StartTreeNode(name + " :: \\$f8fCPlugPrefab", DEFAULT_OPEN)) {
            ItemBrowser_KinDynaMap@ prevKinMap = g_IB_ActiveKinMap;
            if (parent is null || parent.prefab is null) {
                @g_IB_ActiveKinMap = ItemBrowser_BuildKinDynaMap(prefab);
            }
            if (parent !is null && parent.parent !is null) {
                // for BIMobil, parent is CGameCtnBlockInfoMobil::PrefabFid
                auto pp = parent.parent;
                auto biMobil = cast<CGameCtnBlockInfoMobil>(pp.nod);
                if (biMobil !is null) {
                    auto biExtra = Blocks::GetPrefabSPlacements(biMobil);
                    auto nbSPlacements = biExtra.SPlacements.Length;
                    if (StartTreeNode("SPlacements ("+nbSPlacements+")", true, UI::TreeNodeFlags::DefaultOpen)) {
                        for (uint i = 0; i < nbSPlacements; i++) {
                            LabeledValue("SPlacement " + i, biExtra.SPlacements[i].ToString());
                        }
                        EndTreeNode();
                    }
                }
            }

            auto nbEnts = prefab.Ents.Length;
            if (StartTreeNode("Ents ("+nbEnts+")", true, UI::TreeNodeFlags::DefaultOpen)) {
                UI::Text("nbEnts: " + prefab.Ents.Length);
                if (isEditable) {
                    UI::SameLine();
                    UI::SetNextItemWidth(UI::GetWindowContentRegionWidth() * 0.3);
                    g_NewNbEnts = UI::InputInt("New Capacity", g_NewNbEnts);
                    UI::SameLine();
                    if (UI::Button("Update")) {
                        auto editor = cast<CGameCtnEditorFree>(GetApp().Switcher.ModuleStack[0]);
                        // left or right shift key held
                        bool fromFront = editor !is null && (editor.PluginMapType.Input.IsKeyPressed(68) || editor.PluginMapType.Input.IsKeyPressed(112));
                        Dev_UpdateMwSArrayCapacity(Dev_GetPointerForNod(prefab) + O_PREFAB_ENTS, g_NewNbEnts, SZ_ENT_REF, fromFront);
                        ManipPtrs::AddSignalEntry();
                    }
                }
#if SIG_DEVELOPER
                UI::SameLine();
                UI::TextDisabled(Text::Format("0x%03x", GetOffset("CPlugPrefab", "Ents")));
#endif
                UI::TreeNodeFlags entFlags = prefab.Ents.Length < 50 ? DEFAULT_OPEN : UI::TreeNodeFlags::None;
                auto entsBuf = Dev::GetOffsetNod(prefab, GetOffset(prefab, "Ents"));
                auto elSize = 0x50;
                for (uint i = 0; i < prefab.Ents.Length; i++) {
                    currentIndex = i;
                    if (StartTreeNode(".Ents["+i+"]:", true, entFlags)) {
                        if (drawProperties) {
                            auto nameNod = Dev::GetOffsetNod(entsBuf, elSize * i + 0x40);
                            string nameBytes = ""; // nameNod is null ? "<null>" : Dev::GetOffsetString(nameNod, 0x0);
                            auto nameLen = Dev::GetOffsetUint32(entsBuf, elSize * i + 0x48);
                            string nllTitle = ItemBrowser_EntNllTreeTitle(string(prefab.Ents[i].Name), prefab.Ents[i].Location.Quat, prefab.Ents[i].Location.Trans, int(prefab.Ents[i].LodGroupId));
                            if (StartTreeNode(nllTitle + "###ent-nll-" + i, true, TREE_F_NONE)) {
                                CopiableLabeledValue(".Name", string(prefab.Ents[i].Name));
                                if (isEditable) {
                                    ItemBrowser_DrawEntLocationQuatEuler(prefab, i, true);
                                    prefab.Ents[i].Location.Trans = UI::InputFloat3(".Location.Trans", prefab.Ents[i].Location.Trans);
                                    prefab.Ents[i].LodGroupId = UI::InputInt(".LodGroupId", prefab.Ents[i].LodGroupId);
                                } else {
                                    ItemBrowser_DrawEntLocationQuatEuler(prefab, i, false);
                                    CopiableLabeledValue(".Location.Trans", prefab.Ents[i].Location.Trans.ToString());
                                    CopiableLabeledValue(".LodGroupId", tostring(prefab.Ents[i].LodGroupId));
                                }
                                EndTreeNode();
                            }
                            // name always len 0?
                            // CopiableLabeledValue(".Name.Length / bytes", tostring(nameLen) + " / " + nameBytes);
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
            EndTreeNode();
            @g_IB_ActiveKinMap = prevKinMap;
        }
    }
    void Draw(NPlugItem_SVariantList@ varList) {
        hasElements = true;
        if (StartTreeNode(name + " :: \\$f8fNPlugItem_SVariantList", DEFAULT_OPEN)) {
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
                        if (isEditable) {
                            varList.Variants[i].HiddenInManualCycle = UI::Checkbox("HiddenInManualCycle", varList.Variants[i].HiddenInManualCycle);
                        } else {
                            LabeledValue("HiddenInManualCycle", varList.Variants[i].HiddenInManualCycle);
                        }
                    }
                    MkAndDrawChildNode(varList.Variants[i].EntityModel, "EntityModel");
                    EndTreeNode();
                }
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugFxSystem@ fxSys) {
        if (StartTreeNode(name + " :: \\$f8fCPlugFxSystem", DEFAULT_OPEN)) {
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
        if (StartTreeNode(name + " :: \\$f8fCPlugVegetTreeModel", DEFAULT_OPEN)) {
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
        int kix = -1;
        int hoverKix = ItemBrowser_KinHoverIxFor(g_IB_ActiveKinMap);
        if (g_IB_ActiveKinMap !is null && parent !is null && parent.prefab !is null && parentIx >= 0) {
            kix = g_IB_ActiveKinMap.IxForEnt(parent.prefab, uint(parentIx));
        }
        string extra = ItemBrowser_KinDynaLabelExtra(kix, hoverKix);
        if (StartTreeNode(name + " :: \\$f8fCPlugDynaObjectModel" + extra + "###dyna", ItemBrowser_KinDynaTreeFlags(kix, hoverKix))) {
            MkAndDrawChildNode(dynaObject.Mesh, "Mesh");
            MkAndDrawChildNode(dynaObject.StaticShape, "StaticShape");
            MkAndDrawChildNode(dynaObject.DynaShape, "DynaShape");
            EndTreeNode();
        }
    }
    void Draw(NPlugDyna_SKinematicConstraint@ kc) {
        if (StartTreeNode(name + " :: \\$f8fNPlugDyna_SKinematicConstraint", DEFAULT_OPEN)) {
            if (drawProperties) {
                Draw_NPlugDyna_SKinematicConstraint_Props(kc, isEditable);
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugSpawnModel@ spawnModel) {
        if (StartTreeNode(name + " :: \\$f8fCPlugSpawnModel", DEFAULT_OPEN)) {
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
        if (StartTreeNode(name + " :: \\$f8fCPlugEditorHelper", DEFAULT_OPEN)) {
            auto nod = editorHelper.PrefabFid is null ? null : editorHelper.PrefabFid.Nod;
            MkAndDrawChildNode(editorHelper.PrefabFid, 0x18, "PrefabFid");
            auto prefabNod = Dev::GetOffsetNod(editorHelper, 0x20);
            MkAndDrawChildNode(prefabNod, 0x20, "Prefab");
            EndTreeNode();
        }
    }
    void Draw(NPlugTrigger_SWaypoint@ sWaypoint) {
        if (StartTreeNode(name + " :: \\$f8fNPlugTrigger_SWaypoint", DEFAULT_OPEN)) {
            if (drawProperties) {
                if (isEditable) {
                    sWaypoint.NoRespawn = UI::Checkbox("NoRespawn", sWaypoint.NoRespawn);
                    sWaypoint.Type = DrawComboEGameItemWaypointType("Type", sWaypoint.Type);
                } else {
                    LabeledValue("NoRespawn", sWaypoint.NoRespawn);
                    LabeledValue("sWaypoint.Type", tostring(sWaypoint.Type));
                }
            }
            MkAndDrawChildNode(sWaypoint.TriggerShape, "TriggerShape");
            EndTreeNode();
        }
    }
    void Draw(NPlugTrigger_SSpecial@ sSpecial) {
        if (StartTreeNode(name + " :: \\$f8fNPlugTrigger_SSpecial", DEFAULT_OPEN)) {
            MkAndDrawChildNode(sSpecial.TriggerShape, "TriggerShape");
            EndTreeNode();
        }
    }
    void Draw(CGameCommonItemEntityModel@ cieModel) {
        if (StartTreeNode(name + " :: \\$f8fCGameCommonItemEntityModel", DEFAULT_OPEN)) {
            MkAndDrawChildNode(cieModel.StaticObject, "StaticObject");
            MkAndDrawChildNode(cieModel.TriggerShape, "TriggerShape");
            MkAndDrawChildNode(cieModel.PhyModel, "PhyModel");
            auto spawnLoc = vec3(cieModel.SpawnLoc.tx, cieModel.SpawnLoc.ty, cieModel.SpawnLoc.tz);
            auto spawnRot = mat4::Inverse(mat4::Translate(spawnLoc)) * mat4(cieModel.SpawnLoc);
            auto pyr = PitchYawRollFromRotationMatrix(spawnRot);
            // todo: test update check thing to avoid oscillating matrix calcs from rotation
            if (isEditable) {
                UI::PushItemWidth(UI::GetContentRegionAvail().x * .5 * g_scale);
                auto spawnLocOut = UX::InputFloat3("Spawn Pos", spawnLoc, vec3(16, 0, 11.2));
                auto pyrOut = UX::InputAngles3("Spawn Rot", pyr, vec3(0, 0, 0));
                UI::PopItemWidth();
                if (!MathX::Vec3Eq(spawnLoc, spawnLocOut) || !MathX::Vec3Eq(pyr, pyrOut)) {
                    cieModel.SpawnLoc = iso4(mat4::Translate(spawnLoc) * EulerToMat(pyr));
                }
            } else {
                LabeledValue("Spawn Pos", spawnLoc);
                LabeledValue("Spawn Rot", pyr);
            }
            EndTreeNode();
        }
    }

    void Draw(CPlugSolid2Model@ s2m) {
        if (StartTreeNode(name + " :: \\$f8fCPlugSolid2Model", DEFAULT_OPEN)) {
            CPlugSkel@ skel = cast<CPlugSkel>(Dev::GetOffsetNod(s2m, O_SOLID2MODEL_SKEL));
            if (drawProperties) {
                uint nbVisualIndexedTriangles = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 0x8);
                uint nbMaterials = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_MATERIALS_BUF + 0x8);
                uint nbMaterialUserInsts = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_USERMAT_BUF + 0x8);
                uint nbLights = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_LIGHTS_BUF + 0x8);
                uint nbLightUserModels = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_USERLIGHTS_BUF + 0x8);
                uint nbCustomMaterials = Dev::GetOffsetUint32(s2m, O_SOLID2MODEL_CUSTMAT_BUF + 0x8);
                UI::Text("nbVisualIndexedTriangles: " + nbVisualIndexedTriangles);
                auto ds2mFlags = DPlugSolid2Model(s2m);
                if (isEditable) {
                    UI::PushItemWidth(PREFAB_PARAMS_W);
                    int vt = UI::InputInt("VisCstType", int(ds2mFlags.VisCstType), 0);
                    if (vt < 0) vt = 0;
                    ds2mFlags.VisCstType = uint(vt);
                    AddSimpleTooltip("0/1 static-ish, 2=Dynamic (cloth/tween), 3=car, 4=sm body.");
                    int fl = UI::InputInt("Flags+0x34", int(ds2mFlags.Flags), 0);
                    ds2mFlags.Flags = uint(fl);
                    UI::PopItemWidth();
                } else {
                    LabeledValue("VisCstType", ds2mFlags.VisCstType);
                    LabeledValue("Flags+0x34", ds2mFlags.Flags);
                }
                LabeledValue("AABB center", Dev::GetOffsetVec3(s2m, O_SOLID2MODEL_AABB_CENTER).ToString());
                LabeledValue("AABB half", Dev::GetOffsetVec3(s2m, O_SOLID2MODEL_AABB_HALF).ToString());
                DrawVisualsAt("Visuals (" + nbVisualIndexedTriangles + ")", s2m);
                DrawShadedGeomsAt(s2m, nbVisualIndexedTriangles);
                DrawLightsAt("nbLights: " + nbLights, nod, O_SOLID2MODEL_LIGHTS_BUF);
                DrawUserLightsAt("nbLightUserModels: " + nbLightUserModels, nod, O_SOLID2MODEL_USERLIGHTS_BUF);
                DrawMaterialsAt("nbMaterials: " + nbMaterials, nod, O_SOLID2MODEL_MATERIALS_BUF);
                DrawMaterialsAt("nbCustomMaterials: " + nbCustomMaterials, nod, O_SOLID2MODEL_CUSTMAT_BUF);
                DrawUserMatIntsAt("nbMaterialUserInsts: " + nbMaterialUserInsts, nod, O_SOLID2MODEL_USERMAT_BUF);
            }
            MkAndDrawChildNode(skel, O_SOLID2MODEL_SKEL, "Skel");
            auto ds2m = DPlugSolid2Model(s2m);
            DPlugSolid2ModelPreLightGenerator@ plg = ds2m.PreLightGenerator; // ds2m.PreLightGeneratorPtr > 0 ? ds2m.PreLightGenerator : null;
            if (plg !is null) {
                if (isEditable) {
                    UI::SetNextItemWidth(130.0);
                    plg.LMSideLengthMeters = UI::InputFloat("LMSideLengthMeters", plg.LMSideLengthMeters);
                    AddSimpleTooltip("Some value that is proportional to surface area.");
                } else {
                    CopiableLabeledValue("LMSideLengthMeters", tostring(plg.LMSideLengthMeters));
                }
            } else {
                UI::Text("PreLightGenerator is null");
            }
            EndTreeNode();
        }
    }

    // ShadedGeoms (+0x158): which material each visual is drawn with, plus its TexCoord0 range.
    void DrawShadedGeomsAt(CPlugSolid2Model@ mesh, uint nbVis) {
        if (!StartTreeNode("Visual -> Material / UVs (" + nbVis + ")", true, UI::TreeNodeFlags::None)) return;
        auto visBuf = Dev::GetOffsetNod(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        if (UI::BeginTable("shgeo##" + Text::FormatPointer(Dev_GetPointerForNod(mesh)), 4, UI::TableFlags::SizingStretchProp | UI::TableFlags::NoSavedSettings | UI::TableFlags::RowBg)) {
            UI::TableSetupColumn("Vis", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Mat", UI::TableColumnFlags::WidthFixed, 40.);
            UI::TableSetupColumn("Material");
            UI::TableSetupColumn("TexCoord0 u / v range");
            UI::TableHeadersRow();
            for (uint i = 0; i < nbVis && visBuf !is null; i++) {
                auto vis = cast<CPlugVisual>(Dev::GetOffsetNod(visBuf, i * 0x8));
                int mi = VisualUVs::MaterialIndexOfVisual(mesh, i);
                UI::TableNextRow();
                UI::TableNextColumn(); UI::Text(tostring(i));
                UI::TableNextColumn(); UI::Text(mi < 0 ? "-" : tostring(mi));
                UI::TableNextColumn(); UI::Text(VisualUVs::MaterialName(mesh, mi));
                UI::TableNextColumn();
                string uvs = "-";
                auto attrs = VisualUVs::Scan(vis);
                for (uint a = 0; a < attrs.Length; a++) {
                    if (attrs[a].semantic != VisualUVs::SEM_TEXCOORD0) continue;
                    uvs = attrs[a].IsFloat2()
                        ? Text::Format("%.3f", attrs[a].uvMin.x) + ".." + Text::Format("%.3f", attrs[a].uvMax.x) + " / " + Text::Format("%.3f", attrs[a].uvMin.y) + ".." + Text::Format("%.3f", attrs[a].uvMax.y)
                        : "fmt " + attrs[a].declType;
                }
                UI::Text(uvs);
            }
            UI::EndTable();
        }
        EndTreeNode();
    }

    // TexCoord attributes of one visual, with an optional in-place shift (persisted on save).
    void DrawVisualUVs(CPlugVisual@ vis) {
        auto attrs = VisualUVs::Scan(vis);
        if (attrs.Length == 0) { UI::TextDisabled("UVs: no TexCoord attribute on the vertex stream"); return; }
        string id = Text::FormatPointer(Dev_GetPointerForNod(vis));
        if (UI::BeginTable("uvs##" + id, 5, UI::TableFlags::SizingStretchProp | UI::TableFlags::NoSavedSettings | UI::TableFlags::RowBg)) {
            UI::TableSetupColumn("UV set"); UI::TableSetupColumn("Format"); UI::TableSetupColumn("Verts");
            UI::TableSetupColumn("u min..max"); UI::TableSetupColumn("v min..max");
            UI::TableHeadersRow();
            for (uint a = 0; a < attrs.Length; a++) {
                auto at = attrs[a];
                UI::TableNextRow();
                UI::TableNextColumn(); UI::Text(at.SemName() + (at.semantic == 11 ? " \\$888(lightmap)" : ""));
                UI::TableNextColumn(); UI::Text(at.IsFloat2() ? "Float2" : "fmt " + at.declType);
                UI::TableNextColumn(); UI::Text(tostring(at.nv));
                UI::TableNextColumn(); UI::Text(at.IsFloat2() ? Text::Format("%.4f", at.uvMin.x) + " .. " + Text::Format("%.4f", at.uvMax.x) : "-");
                UI::TableNextColumn(); UI::Text(at.IsFloat2() ? Text::Format("%.4f", at.uvMin.y) + " .. " + Text::Format("%.4f", at.uvMax.y) : "-");
            }
            UI::EndTable();
        }
        if (isEditable) {
            UI::PushItemWidth(PREFAB_PARAMS_W);
            uvShiftSem = Math::Clamp(UI::InputInt("UV set (10=TexCoord0)", uvShiftSem, 0), int(VisualUVs::SEM_TEXCOORD0), int(VisualUVs::SEM_TEXCOORD_LAST));
            uvShift = UI::InputFloat2("Shift du, dv", uvShift);
            UI::PopItemWidth();
            UI::SameLine();
            if (UX::SmallButton("Apply UV shift")) {
                uint n = VisualUVs::Shift(vis, uint(uvShiftSem), uvShift.x, uvShift.y);
                if (n == 0) NotifyWarning("No Float2 TexCoord" + (uvShiftSem - 10) + " attribute on this visual.");
                else NotifySuccess("Shifted " + n + " UVs by " + uvShift.ToString() + ". Save and reopen the item to see it.");
            }
            AddSimpleTooltip("Adds du/dv to every vertex of that UV set in the CPU vertex stream. Persistent after Save; the GPU buffer only refreshes on Save and Reopen. TexCoord1 is normally the lightmap set - leave it alone.");
        }
    }

    void DrawVisualsAt(const string &in title, CPlugSolid2Model@ mesh) {
        if (mesh is null) return;
        auto visBuf = Dev::GetOffsetNod(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF);
        uint nb = Dev::GetOffsetUint32(mesh, O_SOLID2MODEL_VIS_IDX_TRIS_BUF + 0x8);
        if (!StartTreeNode(title, true, UI::TreeNodeFlags::None)) return;
        if (visBuf is null || nb == 0) {
            UI::TextDisabled("no visuals");
        } else {
            UI::BeginDisabled(VisualNormals::IsRecalcRunning());
            if (isEditable && UX::SmallButton("Recalc all fully smooth normals")) {
                array<CPlugVisualIndexedTriangles@> visuals;
                for (uint i = 0; i < nb; i++) {
                    auto vis = cast<CPlugVisualIndexedTriangles>(Dev::GetOffsetNod(visBuf, i * 0x8));
                    if (vis !is null) visuals.InsertLast(vis);
                }
                VisualNormals::StartRecalc(visuals);
            }
            UI::EndDisabled();
            if (isEditable) {
                AddSimpleTooltip("Groups duplicate local positions before averaging face normals. This replaces populated-but-flat normals too. Save and reopen after running it: the saved CPU stream is persistent, while the already-created GPU buffer is not refreshed by this button.");
                UI::TextDisabled("Next: click once for each Solid2, wait for the green success notification, then Advanced > Save and Reopen Item. Do not click NegNormals or toggle UseVertexNormal.");
            }
            for (uint i = 0; i < nb; i++) {
                auto vis = cast<CPlugVisual>(Dev::GetOffsetNod(visBuf, i * 0x8));
                if (vis is null) {
                    UI::Text("Visual " + i + ". null");
                } else {
                    MkAndDrawChildNode(vis, uint16(i * 0x8), "Visual " + i);
                }
            }
        }
        EndTreeNode();
    }

    void DrawVisualFlagProps(CPlugVisual@ vis) {
        if (vis is null) return;
        uint32 raw = VisualFlags::Read(vis);
        string id = Text::FormatPointer(Dev_GetPointerForNod(vis));
        auto v3 = cast<CPlugVisual3D>(vis);
        uint nNorm = VisualNormals::CountUsableNormals(vis);
        if (UI::BeginTable("visFlags##" + id, 2, UI::TableFlags::SizingStretchSame | UI::TableFlags::NoSavedSettings)) {
            if (isEditable) {
                UI::TableNextColumn();
                vis.IsGeometryStatic = UI::Checkbox("IsGeometryStatic", vis.IsGeometryStatic);
                UI::TableNextColumn();
                vis.IsIndexationStatic = UI::Checkbox("IsIndexationStatic", vis.IsIndexationStatic);
                UI::TableNextColumn();
                vis.OptimizeInVision = UI::Checkbox("OptimizeInVision", vis.OptimizeInVision);
                UI::TableNextColumn();
                vis.UseVertexNormal = UI::Checkbox("UseVertexNormal \\$888\\$i(uses stored normals)", vis.UseVertexNormal);
                AddSimpleTooltip("This flag only tells the shader to use the stored normals. It does not mean those normals are smooth or correct.");
                AddSimpleTooltip("flags+0x24 bit7. Lighting uses per-vertex normals. Off = faceted (no vertex normals). Does not generate missing normals.");
                DrawMissingNormalsWarn(vis, nNorm);
                UI::TableNextColumn();
                vis.UseVertexColor = UI::Checkbox("UseVertexColor", vis.UseVertexColor);
                AddSimpleTooltip("flags+0x24 bit8. Shader uses per-vertex color (CPU Vertexes[+0x18], semantic 8). Off = ignore vertex colors. Does not invent missing colors.");
                if (v3 !is null) {
                    UI::TableNextColumn();
                    v3.UseTgtU = UI::Checkbox("UseTgtU", v3.UseTgtU);
                    UI::TableNextColumn();
                    v3.UseTgtV = UI::Checkbox("UseTgtV", v3.UseTgtV);
                }
            } else {
                UI::TableNextColumn();
                LabeledValue("IsGeometryStatic", vis.IsGeometryStatic);
                UI::TableNextColumn();
                LabeledValue("IsIndexationStatic", vis.IsIndexationStatic);
                UI::TableNextColumn();
                LabeledValue("OptimizeInVision", vis.OptimizeInVision);
                UI::TableNextColumn();
                LabeledValue("UseVertexNormal \\$888\\$i(uses stored normals)", vis.UseVertexNormal);
                DrawMissingNormalsWarn(vis, nNorm);
                UI::TableNextColumn();
                LabeledValue("UseVertexColor", vis.UseVertexColor);
                if (v3 !is null) {
                    UI::TableNextColumn();
                    LabeledValue("UseTgtU", v3.UseTgtU);
                    UI::TableNextColumn();
                    LabeledValue("UseTgtV", v3.UseTgtV);
                }
            }
            UI::TableNextColumn();
            LabeledValue("IsGeometryDynaPart", vis.IsGeometryDynaPart);
            UI::TableNextColumn();
            LabeledValue("UseUvGroup", vis.UseUvGroup);
            UI::TableNextColumn();
            LabeledValue("flags+0x24", Text::Format("0x%x", raw));
            UI::TableNextColumn();
            LabeledValue("SkinIndexCount", raw & VisualFlags::SKIN_INDEX_MASK);
            UI::TableNextColumn();
            LabeledValue("AABB center", Dev::GetOffsetVec3(vis, O_CPLUGVISUAL_AABB_CENTER).ToString());
            UI::TableNextColumn();
            LabeledValue("AABB half", Dev::GetOffsetVec3(vis, O_CPLUGVISUAL_AABB_HALF).ToString());
            UI::TableNextColumn();
            uint nSub = Dev::GetOffsetUint32(vis, O_CPLUGVISUAL_SUBVISUALS_BUF + 0x8);
            LabeledValue("SubVisuals (frames)", nSub);
            UI::TableNextColumn();
            LabeledValue("Nonzero stored normals", nNorm);
            UI::EndTable();
        }
    }

    void DrawMissingNormalsWarn(CPlugVisual@ vis, uint nNorm) {
        if (vis is null) return;
        if (!vis.UseVertexNormal) return;
        if (nNorm > 0) return;
        UI::SameLine();
        UI::Text("\\$f80" + Icons::ExclamationTriangle);
        if (isEditable) {
            AddSimpleTooltip("UseVertexNormal is on but this visual has 0 stored normals (CPU Vertexes[+0xC] and VertexStream semantic 5 are empty/zero). Press Recalc fully smooth normals below.");
        } else {
            AddSimpleTooltip("UseVertexNormal is on but this visual has 0 normals. Open the item in the Item Editor and press RecalcSmoothNormals.");
        }
    }

    void Draw(CPlugVisual@ vis) {
        if (StartTreeNode(name + " :: \\$f8fCPlugVisual", DEFAULT_OPEN)) {
            if (drawProperties) { DrawVisualFlagProps(vis); DrawVisualUVs(vis); }
            EndTreeNode();
        }
    }

    void Draw(CPlugVisualIndexedTriangles@ vis) {
        if (StartTreeNode(name + " :: \\$f8fCPlugVisualIndexedTriangles", DEFAULT_OPEN)) {
            if (drawProperties) {
                DrawVisualFlagProps(vis);
                string id = Text::FormatPointer(Dev_GetPointerForNod(vis));
                auto dIx = DPlugVisualIndexedTriangles(vis);
                auto ib = dIx.IndexBuffer;
                auto d3 = DPlugVisual3D(cast<CPlugVisual3D>(vis));
                if (UI::BeginTable("visIx##" + id, 2, UI::TableFlags::SizingStretchSame | UI::TableFlags::NoSavedSettings)) {
                    if (ib !is null) {
                        UI::TableNextColumn();
                        LabeledValue("IndexCount", ib.GetUint32(0x30));
                        UI::TableNextColumn();
                        LabeledValue("IndexType", ib.get_IndexType());
                    } else {
                        UI::TableNextColumn();
                        UI::TextDisabled("IndexBuffer null");
                        UI::TableNextColumn();
                    }
                    UI::TableNextColumn();
                    LabeledValue("CpuVertexes", d3.Vertexes.Length);
                    UI::EndTable();
                }
                DrawVisualUVs(vis);
                if (isEditable) {
                    auto v3 = cast<CPlugVisual3D>(vis);
                    if (v3 !is null) {
                        if (UX::SmallButton("NegNormals")) v3.NegNormals();
                        if (UX::SmallButton("ComputeOccBox")) v3.ComputeOccBox();
                        if (UX::SmallButton("ComputeFaceCull")) v3.ComputeFaceCull();
                    }
                    UI::BeginDisabled(VisualNormals::IsRecalcRunning());
                    if (UX::SmallButton("Recalc fully smooth normals")) VisualNormals::StartRecalc(vis);
                    UI::EndDisabled();
                    AddSimpleTooltip("Groups duplicate local positions and averages their incident face normals into the persistent VertexStream Normal slot (Dec3N or Float3). Save and reopen to upload the changed CPU stream. Never creates CPU Vertexes beside the stream.");
                }
            }
            EndTreeNode();
        }
    }

    void CopyLightUserColorToSiblings(CMwNod@ inNod, vec3 col) {
        auto host = cast<CPlugSolid2Model>(inNod);
        if (host is null) {
            NotifyError("CopyLightUserColorToSiblings expected Solid2Model but got " + Reflection::TypeOf(inNod).Name);
            return;
        }
        auto LightUserModels = Dev::GetOffsetNod(host, 0x178);
        uint nbLightUserModels = Dev::GetOffsetUint32(host, 0x178 + 0x8);
        for (uint i = 0; i < nbLightUserModels; i++) {
            auto light = cast<CPlugLightUserModel>(Dev::GetOffsetNod(LightUserModels, 0x8 * i));
            if (light is null) continue;
            light.Color = col;
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
                gxLight.Intensity = UI::InputFloat("Intensity##gxl", gxLight.Intensity);
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
                if (isEditable) {
                    // gxLFrustum. /*todo -- check variable declaration below.*/;
                    auto tmp = gxLFrustum;
                    gxLFrustum.IsOrtho = UI::Checkbox("IsOrtho", gxLFrustum.IsOrtho);
                    gxLFrustum.NearZ = UI::InputFloat("NearZ", gxLFrustum.NearZ, 0);
                    gxLFrustum.FarZ = UI::InputFloat("FarZ", gxLFrustum.FarZ, 0);
                    gxLFrustum.FovY = UI::InputFloat("FovY", gxLFrustum.FovY, 0);
                    gxLFrustum.RatioXY = UI::InputFloat("RatioXY", gxLFrustum.RatioXY, 0);
                    gxLFrustum.SizeX = UI::InputFloat("SizeX", gxLFrustum.SizeX, 0);
                    gxLFrustum.SizeY = UI::InputFloat("SizeY", gxLFrustum.SizeY, 0);
                    gxLFrustum.DoAttenuation = UI::Checkbox("DoAttenuation", gxLFrustum.DoAttenuation);
                    gxLFrustum.Apply = DrawComboEApply("Apply", gxLFrustum.Apply);
                    gxLFrustum.Technique = DrawComboETechnique("Technique", gxLFrustum.Technique);
                    gxLFrustum.iShadowGroup = UI::InputInt("iShadowGroup", gxLFrustum.iShadowGroup);
                    gxLFrustum.DoFadeZ = UI::Checkbox("DoFadeZ", gxLFrustum.DoFadeZ);
                    gxLFrustum.RatioFadeZ = UI::InputFloat("RatioFadeZ", gxLFrustum.RatioFadeZ, 0);
                    gxLFrustum.UseFacePosX = UI::Checkbox("UseFacePosX", gxLFrustum.UseFacePosX);
                    gxLFrustum.UseFaceNegX = UI::Checkbox("UseFaceNegX", gxLFrustum.UseFaceNegX);
                    gxLFrustum.UseFacePosY = UI::Checkbox("UseFacePosY", gxLFrustum.UseFacePosY);
                    gxLFrustum.UseFaceNegY = UI::Checkbox("UseFaceNegY", gxLFrustum.UseFaceNegY);
                    gxLFrustum.UseFacePosZ = UI::Checkbox("UseFacePosZ", gxLFrustum.UseFacePosZ);
                    gxLFrustum.UseFaceNegZ = UI::Checkbox("UseFaceNegZ", gxLFrustum.UseFaceNegZ);
                } else {
                    LabeledValue("IsOrtho", gxLFrustum.IsOrtho);
                    LabeledValue("NearZ", gxLFrustum.NearZ);
                    LabeledValue("FarZ", gxLFrustum.FarZ);
                    LabeledValue("FovY", gxLFrustum.FovY);
                    LabeledValue("RatioXY", gxLFrustum.RatioXY);
                    LabeledValue("SizeX", gxLFrustum.SizeX);
                    LabeledValue("SizeY", gxLFrustum.SizeY);
                    LabeledValue("DoAttenuation", gxLFrustum.DoAttenuation);
                    LabeledValue("Apply", tostring(gxLFrustum.Apply));
                    LabeledValue("Technique", tostring(gxLFrustum.Technique));
                    LabeledValue("iShadowGroup", gxLFrustum.iShadowGroup);
                    LabeledValue("DoFadeZ", gxLFrustum.DoFadeZ);
                    LabeledValue("RatioFadeZ", gxLFrustum.RatioFadeZ);
                    LabeledValue("UseFacePosX", gxLFrustum.UseFacePosX);
                    LabeledValue("UseFaceNegX", gxLFrustum.UseFaceNegX);
                    LabeledValue("UseFacePosY", gxLFrustum.UseFacePosY);
                    LabeledValue("UseFaceNegY", gxLFrustum.UseFaceNegY);
                    LabeledValue("UseFacePosZ", gxLFrustum.UseFacePosZ);
                    LabeledValue("UseFaceNegZ", gxLFrustum.UseFaceNegZ);
                }
            }

            auto gxLSpot = cast<CGxLightSpot>(gxLBall);
            if (gxLSpot !is null) {
                UI::Text("\\$aaa  CGxLightSpot:");
                if (isEditable) {
                    gxLSpot.AngleInner = UI::InputFloat("AngleInner", gxLSpot.AngleInner);
                    gxLSpot.AngleOuter = UI::InputFloat("AngleOuter", gxLSpot.AngleOuter);
                    gxLSpot.SubLightCountX = uint8(UI::InputInt("SubLightCountX", gxLSpot.SubLightCountX));
                    gxLSpot.SubLightCountY = uint8(UI::InputInt("SubLightCountY", gxLSpot.SubLightCountY));
                } else {
                    LabeledValue("AngleInner", gxLSpot.AngleInner);
                    LabeledValue("AngleOuter", gxLSpot.AngleOuter);
                    LabeledValue("SubLightCountX", gxLSpot.SubLightCountX);
                    LabeledValue("SubLightCountY", gxLSpot.SubLightCountY);
                }
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
        if (StartTreeNode(name + " :: \\$f8fCPlugLightUserModel###" + Dev_GetPointerForNod(userLight), UI::TreeNodeFlags::None)) {
            if (isEditable) {
                if (UI::Button("Copy Light Color to Siblings")) {
                    CopyLightUserColorToSiblings(this.parent.nod, userLight.Color);
                }
                userLight.Color = UI::InputColor3("Color", userLight.Color);
                userLight.Intensity = UI::InputFloat("Intensity##ul", userLight.Intensity);
                userLight.Distance = UI::InputFloat("Distance##ul", userLight.Distance);
                userLight.PointEmissionRadius = UI::InputFloat("PointEmissionRadius", userLight.PointEmissionRadius);
                userLight.PointEmissionLength = UI::InputFloat("PointEmissionLength", userLight.PointEmissionLength);
                userLight.SpotInnerAngle = UI::InputFloat("SpotInnerAngle", userLight.SpotInnerAngle);
                userLight.SpotOuterAngle = UI::InputFloat("SpotOuterAngle", userLight.SpotOuterAngle);
                userLight.SpotEmissionSizeX = UI::InputFloat("SpotEmissionSizeX", userLight.SpotEmissionSizeX);
                userLight.SpotEmissionSizeY = UI::InputFloat("SpotEmissionSizeY", userLight.SpotEmissionSizeY);
                userLight.NightOnly = UI::Checkbox("NightOnly##ul", userLight.NightOnly);
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
                    Editor::TransformMaterialsToMatIds(surf);
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
        // editing the in-game material physics properties can affect vanilla blocks, so disable editing if an FID exists for this material
        if (GetFidFromNod(mat) !is null) {
            isEditable = false;
        }
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
                    MkAndDrawChildNode(mat, elSize * i, "" + i + ". " + name + suffix);
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
                if (colorLen == 3 && colorPtr != 0) {
                    auto col = UserMatInstColor::ReadColor(colorPtr);
                    col = UI::InputColor3("Color", col);
                    UserMatInstColor::WriteColor(colorPtr, col);
                    UI::SameLine();
                    if (UX::SmallButton(Icons::Times + "##rmUserMatColor" + Dev_GetPointerForNod(nod), "Remove custom color")) {
                        UserMatInstColor::Clear(nod);
                    }
                } else {
                    UI::TextDisabled("unsupported color buffer length: " + colorLen);
                    UI::SameLine();
                    if (UI::Button("Instantiate Color")) {
                        UserMatInstColor::Instantiate(nod);
                    }
                }
            } else {
                CopiableLabeledValue("LinkFull", userMat._LinkFull);
                CopiableLabeledValue("PhysicsID", tostring(EPlugSurfaceMaterialId(userMat.PhysicsID)));
                CopiableLabeledValue("GameplayID", tostring(EPlugSurfaceGameplayId(userMat.GameplayID)));
                if (colorLen == 3 && colorPtr != 0) {
                    auto col = UserMatInstColor::ReadColor(colorPtr);
                    UI::BeginDisabled();
                    UI::InputColor3("Color", col);
                    UI::EndDisabled();
                } else {
                    UI::TextDisabled("no custom color");
                }
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
                if (StartTreeNode("Material " + i + ".", true, DEFAULT_OPEN)) {
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
        if (StartTreeNode(name + " :: \\$f8fCPlugSurface", ItemBrowser_NamedChildTreeFlags(name))) {
            if (drawProperties) {
                DrawMaterialsAt("nbMaterials: " + surf.Materials.Length, surf, GetOffset(surf, "Materials"));
                DrawMaterialIdsAt("nbMaterialIds: " + surf.MaterialIds.Length, surf, GetOffset(surf, "MaterialIds"));
                if (isEditable) {
                    UI::BeginDisabled(surf.Materials.Length == 0);
                    if (UI::Button("TransformMaterialsToMatIds")) {
                        Editor::TransformMaterialsToMatIds(surf);
                    }
                    UI::EndDisabled();
                    if (UI::Button("UpdateSurfMaterialIdsFromMaterialIndexs")) {
                        surf.UpdateSurfMaterialIdsFromMaterialIndexs();
                    }
                    AddSimpleTooltip("This will update the material IDs on the surface itself. It should be run automatically after changing one of the surface's MaterialIds.");
                    GmSurfUi::DrawReplace(surf);
                }
                Draw("m_GmSurf", surf.m_GmSurf);
                MkAndDrawChildNode(surf.Skel, GetOffset(surf, "Skel"), "Skel");
            }
            EndTreeNode();
        }
    }

    void Draw(const string &in _name, GmSurf@ gmSurf) {
        if (StartTreeNode(_name + " :: \\$f8fGmSurf", true, DEFAULT_OPEN)) {
            if (gmSurf is null) {
                UI::Text("null");
            } else {
                if (isEditable) {
                    gmSurf.GmSurfType = DrawComboEGmSurfType("GmSurfType", gmSurf.GmSurfType);
                    AddSimpleTooltip("MUST match the runtime class (see 'class' below). Game will crash for incorrect values. To convert to a sphere/box/capsule/etc, use Replace GmSurf on the CPlugSurface.");
                    gmSurf.GameplayMainDir = UI::InputFloat3("GameplayMainDir", gmSurf.GameplayMainDir);
                    AddSimpleTooltip("Allows customizing bumper and booster parameters");
                } else {
                    UI::Text("GmSurfType: " + tostring(gmSurf.GmSurfType));
                    UI::Text("GameplayMainDir: " + tostring(gmSurf.GameplayMainDir));
                }
                GmSurfUi::DrawFields(gmSurf, isEditable, _name);

                auto compound = cast<GmSurfCompound>(gmSurf);
                if (compound !is null) {
                    for (uint i = 0; i < compound.Surfs.Length; i++) {
                        Draw("Surfs[" + i + "]", compound.Surfs[i]);
                    }
                }
                auto inst = cast<GmSurfCompoundInstance>(gmSurf);
                if (inst !is null && inst.Compound !is null) {
                    Draw("Compound", inst.Compound);
                }
            }
            EndTreeNode();
        }
    }


    void Draw(CGameCtnBlockSkin@ blockSkin) {
        if (StartTreeNode(name + " ::\\$f8f CGameCtnBlockSkin", UI::TreeNodeFlags::None)) {
            MkAndDrawChildNode(blockSkin.PackDesc, GetOffset(blockSkin, "PackDesc"), "PackDesc");
            MkAndDrawChildNode(blockSkin.ForegroundPackDesc, GetOffset(blockSkin, "ForegroundPackDesc"), "ForegroundPackDesc");
            MkAndDrawChildNode(blockSkin.ParentPackDesc, GetOffset(blockSkin, "ParentPackDesc"), "ParentPackDesc");
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
            CopiableLabeledValue("Checksum", sysPackDesc.Checksum);
            CopiableLabeledValue("AutoUpdate", tostring(sysPackDesc.AutoUpdate));
            CopiableLabeledValue("LocatorFileName", sysPackDesc.LocatorFileName);
            MkAndDrawChildNode(sysPackDesc.Fid, GetOffset(sysPackDesc, "Fid"), "Fid");
            EndTreeNode();
        }
    }

    void Draw(CGameBlockItem@ blockItem) {
        if (StartTreeNode(name + " ::\\$f8f CGameBlockItem", DEFAULT_OPEN)) {

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
        if (StartTreeNode(name + " ::\\$f8f CPlugCrystal", DEFAULT_OPEN)) {
            auto nbMats = Dev::GetOffsetUint32(crystal, 0x50);
            DrawMaterialsAt("Materials ("+nbMats+")##" + Dev_GetPointerForNod(crystal), crystal, 0x48, 0x20, 0x18);
            DrawUserMatIntsAt("UserMatInts ("+nbMats+")##" + Dev_GetPointerForNod(crystal), crystal, 0x48, 0x20, 0x0);
            EndTreeNode();
        }
    }

    void Draw(CPlugGameSkinAndFolder@ matMod) {
        if (StartTreeNode(name + " ::\\$f8f CPlugGameSkinAndFolder", UI::TreeNodeFlags::None)) {
            DrawMaterialModifier(matMod);
            EndTreeNode();
        }
    }

    void DrawLMBuffer2At(const string &in title, uint64 bufPtr) {
        if (StartTreeNode(title, true, UI::TreeNodeFlags::None)) {
            auto bufLen = Dev::ReadUInt32(bufPtr + 0x8);
            auto startPtr = Dev::ReadUInt64(bufPtr);
            auto objSize = SZ_LM_SPIMP_Buf2_EL;
            UI::ListClipper clip(bufLen);
            while (clip.Step()) {
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);

                    auto ptr = startPtr + i * objSize;

                    // Solid2Model
                    auto s2mPtr = Dev::ReadUInt64(ptr);
                    auto ix1 = Dev::ReadUInt32(ptr + 0x8);
                    auto unk1 = Dev::ReadUInt32(ptr + 0xC);
                    auto ix2 = Dev::ReadUInt32(ptr + 0x10);
                    auto unk2 = Dev::ReadUInt32(ptr + 0x14);
                    // an empty cmwnod
                    auto cmwnodPtr = Dev::ReadUInt64(ptr + 0x18);
                    // struct 1: unknown
                    auto struct1Ptr = Dev::ReadUInt64(ptr + 0x20);
                    // struct 2: LM coordinates
                    auto struct2Ptr = Dev::ReadUInt64(ptr + 0x28);
                    // source object FID
                    auto fidPtr = Dev::ReadUInt64(ptr + 0x30);
                    auto fid = cast<CSystemFidFile>(Dev_GetNodFromPointer(fidPtr));
                    auto pos = Dev::ReadVec3(ptr + 0x38);
                    auto size = Dev::ReadVec3(ptr + 0x44);

                    uint16 x = Dev::ReadUInt16(struct2Ptr + 0x00);
                    uint16 y = Dev::ReadUInt16(struct2Ptr + 0x02);

                    uint16 sizeX = Dev::ReadUInt16(struct2Ptr + 0x04);
                    uint16 sizeY = Dev::ReadUInt16(struct2Ptr + 0x06);

                    // float2 UV-size
                    auto f12 = Dev::ReadVec2(struct2Ptr + 0x8);
                    // float2 UV-pos (note: X is scaled to 1536 px instead of 1024, so all x values are between 0 and 0.66666 (2/3), and all y values are between 0 and 1)
                    vec2 f34 = Dev::ReadVec2(struct2Ptr + 0x10);

                    UI::Text(tostring(i) + ". " + (fid is null ? "\\$f80Unknown" : "\\$8f8" + fid.FileName)
                        + "\\$z at " + pos.ToString() + ", size: " + size.ToString()
                        + "\\$8f4 =>\\$z at " + nat2(x, y).ToString() + ", size: " + nat2(sizeX, sizeY).ToString() + " px "
                        + "(UVs: at "+FormatX::Vec2_4DPS(f34)+", size: "+FormatX::Vec2_4DPS(f12)+")"
                    );

                    UI::PopID();
                }
            }
            EndTreeNode();
        }
    }

    void Draw(CHmsLightMap@ lm) {
        if (StartTreeNode(name + " ::\\$f8f CHmsLightMap", DEFAULT_OPEN)) {
            auto pimp = lm.m_PImp;
            auto pimpPtr = Dev::GetOffsetUint64(lm, GetOffset(lm, "m_PImp"));
            LabeledValue("Objects in LM", (pimp.cBlock));
            LabeledValue("LM Decoration", (pimp.CacheId_IdDecoration.GetName()));
            LabeledValue("ChallengeJoinId", pimp.ChallengeJointId);
            LabeledValue("Cache Size", tostring(pimp.CacheSize));
            LabeledValue("Objects Buffer Length", Dev::GetOffsetUint32(pimp, O_LM_PIMP_Buf2 + 0x8));
            DrawLMBuffer2At("Objects Buffer", pimpPtr + O_LM_PIMP_Buf2);
            MkAndDrawChildNode(pimp.Cache, GetOffset("NHmsLightMap_SPImp", "Cache"), "Cache");
            MkAndDrawChildNode(pimp.CacheSmall, 0x0, "CacheSmall");
            MkAndDrawChildNode(pimp.CachePackDesc, GetOffset("NHmsLightMap_SPImp", "CachePackDesc"), "CachePackDesc");
            MkAndDrawChildNode(pimp.CachePackDescBumpAvg, GetOffset("NHmsLightMap_SPImp", "CachePackDescBumpAvg"), "CachePackDescBumpAvg");
            // MkAndDrawChildNode(Editor::GetCurrentLightMapParam(lm), 0x150, "LightMapParam");
            EndTreeNode();
        }
    }

    void Draw(CHmsLightMapParam@ lmParam) {
        if (StartTreeNode(name + " ::\\$f8f CHmsLightMapParam", DEFAULT_OPEN)) {
            if (!isEditable) {
                UI::Text("\\$f80Todo!");
                LabeledValue("LightAmbSampleCount", Dev::GetOffsetUint32(lmParam, 0xA8));
                LabeledValue("LightDirSampleCount", Dev::GetOffsetUint32(lmParam, 0xAC));
                LabeledValue("LightPntSampleCount", Dev::GetOffsetUint32(lmParam, 0xB0));
                LabeledValue("DepthPeelGroupMaxPerAxe", Dev::GetOffsetUint32(lmParam, 0xB4));
            } else {
                UI::Text("\\$f80Todo!");
            }
            EndTreeNode();
        }
    }

    void Draw(CHmsLightMapCache@ lmCache) {
        if (StartTreeNode(name + " ::\\$f8f CHmsLightMapCache", UI::TreeNodeFlags::None)) {
            LabeledValue("m_Id_IdCollection", lmCache.m_Id_IdCollection.GetName());
            LabeledValue("m_Id_IdDecoration", lmCache.m_Id_IdDecoration.GetName());
            LabeledValue("Challenge", lmCache.Challenge);
            LabeledValue("MostRecentSolid", lmCache.MostRecentSolid);
            LabeledValue("MostRecentBlock", lmCache.MostRecentBlock);
            LabeledValue("m_MapperTexelCountX", lmCache.m_MapperTexelCountX);
            LabeledValue("m_SortMode", tostring(lmCache.m_SortMode));
            LabeledValue("m_AllocMode", tostring(lmCache.m_AllocMode));
            LabeledValue("m_GpuPlatform", tostring(lmCache.m_GpuPlatform));
            LabeledValue("AmbSamples", lmCache.AmbSamples);
            LabeledValue("DirSamples", lmCache.DirSamples);
            LabeledValue("PntSamples", lmCache.PntSamples);
            LabeledValue("m_CompressMode", tostring(lmCache.m_CompressMode));
            LabeledValue("m_Version", tostring(lmCache.m_Version));
            LabeledValue("m_Quality", tostring(lmCache.m_Quality));
            LabeledValue("m_QualityVer", tostring(lmCache.m_QualityVer));
            LabeledValue("m_Bump", tostring(lmCache.m_Bump));
            LabeledValue("m_AllocatedTexelByMeter", lmCache.m_AllocatedTexelByMeter);
            LabeledValue("m_SpriteOriginY_WasWronglyTop", lmCache.m_SpriteOriginY_WasWronglyTop);
            LabeledValue("cDecal2d", lmCache.cDecal2d);
            LabeledValue("cDecal3d", lmCache.cDecal3d);
            LabeledValue("IdName", lmCache.IdName);
            LabeledValue("NbFrames", lmCache.Frames.Length);
            // todo: NHmsLightMapCache_SFrame
            EndTreeNode();
        }
    }


    void Draw(CPlugTurret@ turret) {
        if (StartTreeNode(name + " ::\\$f8f CPlugTurret", DEFAULT_OPEN)) {

            // turret. /*todo -- check variable declaration below.*/;
            auto tmp = turret;
            LabeledValue("CPlugTurret.AimEnabled", turret.AimEnabled);
            LabeledValue("CPlugTurret.AimDetectRadius", turret.AimDetectRadius);
            LabeledValue("CPlugTurret.AimDetectFOVDeg", turret.AimDetectFOVDeg);
            LabeledValue("CPlugTurret.AimMaxTrackDist", turret.AimMaxTrackDist);
            LabeledValue("CPlugTurret.AimAnticipation", turret.AimAnticipation);
            LabeledValue("CPlugTurret.AimKeepAimingDurationMs", turret.AimKeepAimingDurationMs);
            LabeledValue("CPlugTurret.AimFireTargetChangeDelayMs", turret.AimFireTargetChangeDelayMs);
            LabeledValue("CPlugTurret.AimFireMaxAngleDeg", turret.AimFireMaxAngleDeg);
            LabeledValue("CPlugTurret.AimFireMaxDist", turret.AimFireMaxDist);
            LabeledValue("CPlugTurret.FixedAngleSignal", turret.FixedAngleSignal);
            LabeledValue("CPlugTurret.FixedAnglePeriodMs", turret.FixedAnglePeriodMs);
            LabeledValue("CPlugTurret.FixedAngleMinDeg", turret.FixedAngleMinDeg);
            LabeledValue("CPlugTurret.FixedAngleMaxDeg", turret.FixedAngleMaxDeg);
            LabeledValue("CPlugTurret.LifeArmorMax", turret.LifeArmorMax);
            LabeledValue("CPlugTurret.LifeDisabledDuration", turret.LifeDisabledDuration);
            LabeledValue("CPlugTurret.LifeOnArmorEmtpy", turret.LifeOnArmorEmtpy);
            LabeledValue("CPlugTurret.IsControllable", turret.IsControllable);
            LabeledValue("CPlugTurret.FirePeriodMs", turret.FirePeriodMs);
            LabeledValue("CPlugTurret.Joint0Name", turret.Joint0Name.GetName());
            LabeledValue("CPlugTurret.Joint0LocalAxis", turret.Joint0LocalAxis);
            LabeledValue("CPlugTurret.Joint0MinAngleDeg", turret.Joint0MinAngleDeg);
            LabeledValue("CPlugTurret.Joint0MaxAngleDeg", turret.Joint0MaxAngleDeg);
            LabeledValue("CPlugTurret.Joint0SpeedDegPerS", turret.Joint0SpeedDegPerS);
            LabeledValue("CPlugTurret.Joint0NextJointUpdateAngleMaxDeg", turret.Joint0NextJointUpdateAngleMaxDeg);
            LabeledValue("CPlugTurret.Joint1Name", turret.Joint1Name.GetName());
            LabeledValue("CPlugTurret.Joint1LocalAxis", turret.Joint1LocalAxis);
            LabeledValue("CPlugTurret.Joint1MinAngleDeg", turret.Joint1MinAngleDeg);
            LabeledValue("CPlugTurret.Joint1MaxAngleDeg", turret.Joint1MaxAngleDeg);
            LabeledValue("CPlugTurret.Joint1SpeedDegPerS", turret.Joint1SpeedDegPerS);
            LabeledValue("CPlugTurret.Joint1NextJointUpdateAngleMaxDeg", turret.Joint1NextJointUpdateAngleMaxDeg);
            LabeledValue("CPlugTurret.JointFireName", turret.JointFireName.GetName());
            LabeledValue("CPlugTurret.JointFireLocalAxis", turret.JointFireLocalAxis);
            LabeledValue("CPlugTurret.JointRadarName", turret.JointRadarName.GetName());
            LabeledValue("CPlugTurret.IsDyna", turret.IsDyna);

            MkAndDrawChildNode(turret.DynaModel, GetOffset(turret, "DynaModel"), "DynaModel");
            MkAndDrawChildNode(turret.OnFireParticle, GetOffset(turret, "OnFireParticle"), "OnFireParticle");

            DrawDataRef(turret, GetOffset(turret, "Skel"), "Skel");
            DrawDataRef(turret, GetOffset(turret, "Shape"), "Shape");
            DrawDataRef(turret, GetOffset(turret, "BulletModel"), "BulletModel");
            DrawDataRef(turret, GetOffset(turret, "Mesh"), "Mesh");
            DrawDataRef(turret, GetOffset(turret, "RotateSound1"), "RotateSound1");
            DrawDataRef(turret, GetOffset(turret, "VisEntFx"), "VisEntFx");

            EndTreeNode();
        }
    }

    void DrawDataRef(CMwNod@ nod, uint16 offset, const string &in name) {
        auto inner = Dev_GetOffsetNodSafe(nod, offset);
        auto filename = nod !is null ? Dev::GetOffsetString(nod, offset+0x8) : "(null)";
        LabeledValue(name+".Filename", filename);
        MkAndDrawChildNode(inner, offset, name);
    }

    void Draw(CGameSaveLaunchedCheckpoints@ gslcps) {
        if (StartTreeNode(name + " ::\\$f8f CGameSaveLaunchedCheckpoints", DEFAULT_OPEN)) {
            auto cps = _GameSaveLaunchedCheckpoints(gslcps);
            auto ptr = Dev_GetPointerForNod(gslcps);
            auto cpsIndex = cps.GetCPsIndex();
            auto launchStates = cps.GetLaunchStates();
            if (StartTreeNode("Nb CPs: " + cpsIndex.Length + "###lcps-index-" + ptr, true, DEFAULT_OPEN)) {
                DrawLaunchedCPsIndex(cpsIndex);
                EndTreeNode();
            }
            if (StartTreeNode("Nb States: " + launchStates.Length + "###states-" + ptr, true, UI::TreeNodeFlags::None)) {
                DrawLaunchedCPsStates(launchStates);
                EndTreeNode();
            }
            EndTreeNode();
        }
    }

    void DrawLaunchedCPsIndex(RawBuffer@ buf) {
        auto len = buf.Length;
        for (uint i = 0; i < len; i++) {
            auto item = buf[i];
            if (StartTreeNode("CP " + (i + 1.) + "##launched", true, UI::TreeNodeFlags::None)) {
                DrawLaunchedCPsIndexElement(item);
                EndTreeNode();
            }
        }
    }

    void DrawLaunchedCPsIndexElement(RawBufferElem@ elem) {
        elem.DrawResearchView();
    }

    void DrawLaunchedCPsStates(RawBuffer@ buf) {
        auto len = buf.Length;
        for (uint i = 0; i < len; i++) {
            auto item = buf[i];
            if (StartTreeNode("State " + (i + 1.) + "##states", true, UI::TreeNodeFlags::None)) {
                DrawLaunchedCPsStateElement(item);
                EndTreeNode();
            }
        }
    }

    void DrawLaunchedCPsStateElement(RawBufferElem@ elem) {
        elem.DrawResearchView();
    }


    void Draw(CTrackMania@ asdf) {
        if (StartTreeNode(name + " ::\\$f8f CTrackMania", DEFAULT_OPEN)) {
            UI::Text("\\$f80todo");
            EndTreeNode();
        }
    }

    bool StartTreeNode(const string &in title, UI::TreeNodeFlags flags = DEFAULT_OPEN) {
        return StartTreeNode(title, false, flags);
    }

    bool StartTreeNode(const string &in title, bool suppressDev, UI::TreeNodeFlags flags = DEFAULT_OPEN) {
        bool open = UI::TreeNode(title, flags);
        if (open) {
            UI::PushID(title);
            UI::PushStyleVar(UI::StyleVar::FramePadding, vec2(2, 0));
        }
        if (open && nod !is null) {
            UI::PushID(this.nodOffset);
            UI::PushID(this.name);
            DrawPickable();
            UI::PopID();
            UI::PopID();
        }
        if (open && !suppressDev && !isPicker && nod !is null) {
            auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(nod, 0x8));
#if SIG_DEVELOPER
            Draw_IB_DevBtnPtr(title, nod, nodOffset);
#endif
            if (isEditable && kenematicConstraint !is null) {
#if SIG_DEVELOPER
                UI::SameLine();
#endif
                if (UX::SmallButton("Clone to New", "New NPlugDyna_SKinematicConstraint; copies all fields (anim keys, axes, ShaderTc). Replaces this Model so the original catalog nod is left alone.")) {
                    CloneKcToNew();
                }
            } else if (isEditable && dynaObject !is null) {
#if SIG_DEVELOPER
                UI::SameLine();
#endif
                if (UX::SmallButton("Clone to New", "New CPlugDynaObjectModel; copies flags/mass/etc and AddRefs Mesh/StaticShape/DynaShape/LocAnim/WaterModel (shared, not deep-copied). Replaces this Model so the catalog dyna nod is left alone.")) {
                    CloneDynaToNew();
                }
            }
#if SIG_DEVELOPER
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
        auto ents = Dev::GetOffsetNod(prefab, O_PREFAB_ENTS);
        // size: NPlugPrefab_SEntRef: 0x50
        auto ptr1 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * i + O_ENTREF_PARAMS);
        auto ptr2 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * i + O_ENTREF_PARAMS + 0x8);
        string type = "Unknown";
        uint32 paramsClsId;
        if (ptr2 > 0 && ptr2 % 8 == 0) {
            type = Dev::ReadCString(Dev::ReadUInt64(ptr2));
            paramsClsId = Dev::ReadUInt32(ptr2 + 0x10);
            string tags = ItemBrowser_ParamsTagsFor(paramsClsId, type, ptr1);
            if (g_IB_ActiveKinMap !is null) {
                tags += ItemBrowser_KinIndexTag(g_IB_ActiveKinMap.IxForEnt(prefab, i));
            }
            string title = ItemBrowser_ParamsTreeTitle(tags, ItemBrowser_ParamsShortType(paramsClsId, type));
            if (StartTreeNode(title + "###ent-params-" + i, true, UI::TreeNodeFlags::None)) {
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


string GetVariantTagsStr(NPlugItem_SVariantList@ varList, uint i) {
    string ret;
    auto vars = Dev::GetOffsetNod(varList, GetOffset(varList, "Variants"));
    auto tagsPtr = Dev::GetOffsetUint64(vars, 0x28 * i + GetOffset("NPlugItem_SVariant", "Tags"));
    for (uint t = 0; t < varList.Variants[i].Tags.Length; t++) {
        if (t > 0) ret += ", ";
        ret += ItemPlace_StringConsts::LookupJoined(Dev::ReadNat2(tagsPtr + 0x8 * t));
    }
    return ret;
}


void Draw_IB_DevBtnPtr(const string &in title, CMwNod@ nod, uint16 nodOffset) {
// safer to put preprocessor statements inside incase this is accidentally called without a SIG_DEVELOPER check
#if SIG_DEVELOPER
        UI::TextDisabled(Text::Format("0x%03x", nodOffset));
        UI::SameLine();
        if (UX::SmallButton(Icons::Cube + " Explore Nod")) {
            auto splitAt = title.IndexOf("::");
            if (splitAt == -1) splitAt = title.Length;
            else splitAt += 8;
            ExploreNod(title.SubStr(0, splitAt), nod);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(nod)));
#endif
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
        Draw_NPlugDynaObjectModel_SInstanceParams(ptr, isEditable);
    } else if (clsId == 0x2f0d9000 || type == "NPlugStaticObjectModel::SInstanceParams") {
        Draw_NPlugStaticObjectModel_SInstanceParams(ptr, isEditable);
    } else if (clsId == 0x2f0d8000 || type == "NPlugItemPlacement::SPlacementGroup") {
        DrawSPlacementGroup(ptr, isEditable);
    } else if (clsId == 0x2f0c8000 || type == "NPlugDyna::SPrefabConstraintParams") {
        Draw_SPrefabConstraintParams(ptr, isEditable);
    } else if (clsId == CLSID_NPlugItemPlacement_SPlacement || type == "NPlugItemPlacement::SPlacement") {
        Draw_SPlacement(ptr, isEditable);
    } else {
        DrawSMetaPtr_UnknownScalars(ptr, ty, isEditable);
    }
}

// Memory layout (not RTTI order): PeriodSc, PeriodScMax, Phase01, Phase01Max,
// TextureId, IsKinematic, CastStaticShadow. Size 0x1C. Bools are u32.
const uint16 O_SINSTPARAMS_PeriodSc = 0x00;
const uint16 O_SINSTPARAMS_PeriodScMax = 0x04;
const uint16 O_SINSTPARAMS_Phase01 = 0x08;
const uint16 O_SINSTPARAMS_Phase01Max = 0x0C;
const uint16 O_SINSTPARAMS_TextureId = 0x10;
const uint16 O_SINSTPARAMS_IsKinematic = 0x14;
const uint16 O_SINSTPARAMS_CastStaticShadow = 0x18;

const uint16 O_SPCP_Ent1 = 0x00;
const uint16 O_SPCP_Ent2 = 0x04;
const uint16 O_SPCP_Pos1 = 0x08;
const uint16 O_SPCP_Pos2 = 0x14;

const uint16 O_SPG_Placements = 0x00;
const uint16 O_SPG_TQs = 0x10;
const uint16 O_SPG_U16s = 0x20;
const uint16 O_SPG_PlacementsDup = 0x30;
const uint PREFAB_PARAMS_LIST_CAP = 24;
const float PREFAB_PARAMS_W = 72.;
const float PREFAB_PARAMS_W3 = 180.;

const string TIP_PERIOD_SC = "PeriodSc: vertex-tween / cloth wave period in seconds (min). With PeriodScMax, each placed instance picks a random period in [PeriodSc, PeriodScMax]. Official Flag8m cloth uses 8..16. Not LocAnim.";
const string TIP_PERIOD_SC_MAX = "PeriodScMax: upper bound of the per-instance period range (seconds). Same as PeriodSc → every instance uses that period.";
const string TIP_PHASE01 = "Phase01: vertex-tween phase in 0..1 (where in the wave this instance starts). With Phase01Max, randomized per instance.";
const string TIP_PHASE01_MAX = "Phase01Max: upper bound of the per-instance phase range (0..1). Same as Phase01 → every instance shares that phase.";
const string TIP_TEXTURE_ID = "TextureId: per-instance texture/shader id (Int32, not EShaderTcType). Official flags use 0.";
const string TIP_IS_KINEMATIC = "IsKinematic: on = kinematic (KC / scripted motion). Off = free rigid body.";
const string TIP_CAST_STATIC_SHADOW = "CastStaticShadow: distant static shadow. It does not animate.";

// Params tree tags (ManiaLink colors): K $0f8, S $fd0, T $6cf, Pe $c8f, Ph $af8.
// Constraint: T $f80, P $88f (gray $888 when -1). kin# $888. Hover uses TreeNode Selected.

void ItemBrowser_KinHoverBeginFrame() {
    g_IB_KinHoverDraw = g_IB_KinHoverAcc;
    g_IB_KinHoverRootDraw = g_IB_KinHoverRootAcc;
    g_IB_KinHoverAcc = -1;
    g_IB_KinHoverRootAcc = 0;
}

void ItemBrowser_KinHover(int kix) {
    if (g_IB_ActiveKinMap is null || g_IB_ActiveKinMap.root is null || kix < 0) return;
    g_IB_KinHoverAcc = kix;
    g_IB_KinHoverRootAcc = Dev_GetPointerForNod(g_IB_ActiveKinMap.root);
}

int ItemBrowser_KinHoverIxFor(ItemBrowser_KinDynaMap@ map) {
    if (map is null || map.root is null) return -1;
    if (Dev_GetPointerForNod(map.root) != g_IB_KinHoverRootDraw) return -1;
    return g_IB_KinHoverDraw;
}

void ItemBrowser_MaybeKinHover(int kix) {
    if (UI::IsItemHovered()) ItemBrowser_KinHover(kix);
}

string ItemBrowser_TreeTag(const string &in color, const string &in body) {
    return "\\$" + color + "[" + body + "]";
}

string ItemBrowser_KinIndexTag(int kix) {
    if (kix < 0) return "";
    return ItemBrowser_TreeTag("888", "kin#" + tostring(kix));
}

string ItemBrowser_KinDynaLabelExtra(int kix, int hoverKix) {
    string t = ItemBrowser_KinIndexTag(kix);
    if (t.Length == 0) return "";
    return "  " + t;
}

UI::TreeNodeFlags ItemBrowser_KinDynaTreeFlags(int kix, int hoverKix) {
    UI::TreeNodeFlags f = DEFAULT_OPEN;
    if (kix >= 0 && kix == hoverKix) {
        f = UI::TreeNodeFlags(int(f) | int(UI::TreeNodeFlags::Selected));
    }
    return f;
}

bool ItemBrowser_FloatNonZero(float v) {
    return Math::Abs(v) > 1e-6;
}

string ItemBrowser_SInstParamsTags(bool isKinematic, bool castStaticShadow, uint textureId, float periodSc, float periodScMax, float phase01, float phase01Max) {
    string t;
    if (isKinematic) t += ItemBrowser_TreeTag("0f8", "K");
    if (castStaticShadow) t += ItemBrowser_TreeTag("fd0", "S");
    if (textureId != 0) t += ItemBrowser_TreeTag("6cf", "T" + tostring(textureId));
    if (ItemBrowser_FloatNonZero(periodSc) || ItemBrowser_FloatNonZero(periodScMax)) t += ItemBrowser_TreeTag("c8f", "Pe");
    if (ItemBrowser_FloatNonZero(phase01) || ItemBrowser_FloatNonZero(phase01Max)) t += ItemBrowser_TreeTag("af8", "Ph");
    return t;
}

string ItemBrowser_SStaticInstParamsTags(float phase01) {
    if (!ItemBrowser_FloatNonZero(phase01)) return "";
    return ItemBrowser_TreeTag("af8", "Ph");
}

string ItemBrowser_SPrefabConstraintParamsTags(int parentEntIx, int targetEntIx) {
    string t = ItemBrowser_TreeTag("f80", "T" + tostring(targetEntIx));
    string pCol = parentEntIx < 0 ? "888" : "88f";
    t += ItemBrowser_TreeTag(pCol, "P" + tostring(parentEntIx));
    return t;
}

string ItemBrowser_ParamsShortType(uint32 clsId, const string &in type) {
    if (clsId == 0x2f0b6000) return "SInstanceParams";
    if (clsId == 0x2f0c8000) return "SPrefabConstraintParams";
    if (clsId == 0x2f0d9000) return "SStaticInstanceParams";
    if (clsId == 0x2f0d8000) return "SPlacementGroup";
    if (clsId == CLSID_NPlugItemPlacement_SPlacement) return "SPlacement";
    int sep = type.IndexOf("::");
    if (sep >= 0) return type.SubStr(sep + 2);
    if (type.Length > 0) return type;
    return Text::Format("%08x", clsId);
}

string ItemBrowser_ParamsTreeTitle(const string &in tags, const string &in shortType) {
    string t = "\\$888Params";
    if (tags.Length > 0) t += "  " + tags;
    t += "  \\$888" + shortType;
    return t;
}

string ItemBrowser_ParamsTagsFor(uint32 clsId, const string &in type, uint64 ptr) {
    if (ptr == 0) return "";
    if (clsId == 0x2f0b6000 || type == "NPlugDynaObjectModel::SInstanceParams") {
        return ItemBrowser_SInstParamsTags(
            Dev::ReadUInt32(ptr + O_SINSTPARAMS_IsKinematic) != 0,
            Dev::ReadUInt32(ptr + O_SINSTPARAMS_CastStaticShadow) != 0,
            Dev::ReadUInt32(ptr + O_SINSTPARAMS_TextureId),
            Dev::ReadFloat(ptr + O_SINSTPARAMS_PeriodSc),
            Dev::ReadFloat(ptr + O_SINSTPARAMS_PeriodScMax),
            Dev::ReadFloat(ptr + O_SINSTPARAMS_Phase01),
            Dev::ReadFloat(ptr + O_SINSTPARAMS_Phase01Max)
        );
    }
    if (clsId == 0x2f0c8000 || type == "NPlugDyna::SPrefabConstraintParams") {
        return ItemBrowser_SPrefabConstraintParamsTags(Dev::ReadInt32(ptr + O_SPCP_Ent1), Dev::ReadInt32(ptr + O_SPCP_Ent2));
    }
    if (clsId == 0x2f0d9000 || type == "NPlugStaticObjectModel::SInstanceParams") {
        return ItemBrowser_SStaticInstParamsTags(Dev::ReadFloat(ptr));
    }
    return "";
}

bool ItemBrowser_IsKinematicDynaCandidate(CMwNod@ model, uint32 paramsClsId, bool isKinematic) {
    if (cast<CPlugPrefab>(model) !is null) return false;
    if (cast<CPlugDynaObjectModel>(model) is null) return false;
    if (paramsClsId != 0x2f0b6000) return false;
    return isKinematic;
}

bool ItemBrowser_EntIsKinematicDyna(CPlugPrefab@ prefab, uint i) {
    if (prefab is null || i >= prefab.Ents.Length) return false;
    auto ents = Dev::GetOffsetNod(prefab, O_PREFAB_ENTS);
    if (ents is null) return false;
    uint64 ptr = Dev::GetOffsetUint64(ents, SZ_ENT_REF * i + O_ENTREF_PARAMS);
    uint64 ptr2 = Dev::GetOffsetUint64(ents, SZ_ENT_REF * i + O_ENTREF_PARAMS + 0x8);
    uint32 clsId = 0;
    bool kin = false;
    if (ptr2 > 0 && ptr2 % 8 == 0) {
        clsId = Dev::ReadUInt32(ptr2 + 0x10);
        if (ptr != 0 && clsId == 0x2f0b6000) {
            kin = Dev::ReadUInt32(ptr + O_SINSTPARAMS_IsKinematic) != 0;
        }
    }
    return ItemBrowser_IsKinematicDynaCandidate(prefab.Ents[i].Model, clsId, kin);
}

// Matches Populate Ent1/Ent2: flatten nested prefabs, then index IsKinematic CPlugDynaObjectModel ents.
// Game FlattenNestedPrefabs (0x140598cf0) is one-level splice; we recurse so 2-deep authoring still lists inner dynas.
void ItemBrowser_FlattenKinDynas(CPlugPrefab@ prefab, ItemBrowser_KinDynaMap@ map, uint depth) {
    if (prefab is null || map is null || depth > 8) return;
    for (uint i = 0; i < prefab.Ents.Length; i++) {
        auto inner = cast<CPlugPrefab>(prefab.Ents[i].Model);
        if (inner !is null) {
            ItemBrowser_FlattenKinDynas(inner, map, depth + 1);
            continue;
        }
        if (ItemBrowser_EntIsKinematicDyna(prefab, i)) {
            map.Add(prefab, i);
        }
    }
}

ItemBrowser_KinDynaMap@ ItemBrowser_BuildKinDynaMap(CPlugPrefab@ root) {
    auto map = ItemBrowser_KinDynaMap();
    @map.root = root;
    ItemBrowser_FlattenKinDynas(root, map, 0);
    return map;
}

void Draw_NPlugDynaObjectModel_SInstanceParams(uint64 ptr, bool isEditable) {
    if (ptr == 0) return;
    float periodSc = Dev::ReadFloat(ptr + O_SINSTPARAMS_PeriodSc);
    float periodScMax = Dev::ReadFloat(ptr + O_SINSTPARAMS_PeriodScMax);
    float phase01 = Dev::ReadFloat(ptr + O_SINSTPARAMS_Phase01);
    float phase01Max = Dev::ReadFloat(ptr + O_SINSTPARAMS_Phase01Max);
    uint textureId = Dev::ReadUInt32(ptr + O_SINSTPARAMS_TextureId);
    bool isKinematic = Dev::ReadUInt32(ptr + O_SINSTPARAMS_IsKinematic) != 0;
    bool castStaticShadow = Dev::ReadUInt32(ptr + O_SINSTPARAMS_CastStaticShadow) != 0;

    if (isEditable) {
        string id = Text::FormatPointer(ptr);
        UI::PushID(id);
        isKinematic = UI::Checkbox("IsKinematic", isKinematic);
        AddSimpleTooltip(TIP_IS_KINEMATIC);
        UI::SameLine();
        castStaticShadow = UI::Checkbox("CastStaticShadow", castStaticShadow);
        AddSimpleTooltip(TIP_CAST_STATIC_SHADOW);
        UI::PushItemWidth(PREFAB_PARAMS_W);
        if (UI::BeginTable("sinstEq##" + id, 2, UI::TableFlags::SizingStretchSame | UI::TableFlags::NoSavedSettings)) {
            UI::TableNextColumn();
            periodSc = UI::InputFloat("PeriodSc", periodSc);
            AddSimpleTooltip(TIP_PERIOD_SC);
            UI::TableNextColumn();
            periodScMax = UI::InputFloat("PeriodScMax", periodScMax);
            AddSimpleTooltip(TIP_PERIOD_SC_MAX);
            UI::TableNextColumn();
            phase01 = UI::InputFloat("Phase01", phase01);
            AddSimpleTooltip(TIP_PHASE01);
            UI::TableNextColumn();
            phase01Max = UI::InputFloat("Phase01Max", phase01Max);
            AddSimpleTooltip(TIP_PHASE01_MAX);
            UI::TableNextColumn();
            textureId = uint(Math::Max(0, UI::InputInt("TextureId", int(textureId), 0)));
            AddSimpleTooltip(TIP_TEXTURE_ID);
            UI::EndTable();
        }
        UI::PopItemWidth();
        UI::PopID();

        Dev::Write(ptr + O_SINSTPARAMS_PeriodSc, periodSc);
        Dev::Write(ptr + O_SINSTPARAMS_PeriodScMax, periodScMax);
        Dev::Write(ptr + O_SINSTPARAMS_Phase01, phase01);
        Dev::Write(ptr + O_SINSTPARAMS_Phase01Max, phase01Max);
        Dev::Write(ptr + O_SINSTPARAMS_TextureId, textureId);
        Dev::Write(ptr + O_SINSTPARAMS_IsKinematic, isKinematic ? uint(1) : uint(0));
        Dev::Write(ptr + O_SINSTPARAMS_CastStaticShadow, castStaticShadow ? uint(1) : uint(0));
    } else {
        LabeledValue("IsKinematic", isKinematic);
        AddSimpleTooltip(TIP_IS_KINEMATIC);
        LabeledValue("CastStaticShadow", castStaticShadow);
        AddSimpleTooltip(TIP_CAST_STATIC_SHADOW);
        LabeledValue("PeriodSc", periodSc);
        AddSimpleTooltip(TIP_PERIOD_SC);
        LabeledValue("PeriodScMax", periodScMax);
        AddSimpleTooltip(TIP_PERIOD_SC_MAX);
        LabeledValue("Phase01", phase01);
        AddSimpleTooltip(TIP_PHASE01);
        LabeledValue("Phase01Max", phase01Max);
        AddSimpleTooltip(TIP_PHASE01_MAX);
        LabeledValue("TextureId", textureId);
        AddSimpleTooltip(TIP_TEXTURE_ID);
    }
}

void Draw_NPlugStaticObjectModel_SInstanceParams(uint64 ptr, bool isEditable) {
    if (ptr == 0) return;
    float phase01 = Dev::ReadFloat(ptr);
    if (isEditable) {
        UI::PushItemWidth(PREFAB_PARAMS_W);
        phase01 = UI::InputFloat("Phase01", phase01);
        AddSimpleTooltip(TIP_PHASE01);
        UI::PopItemWidth();
        Dev::Write(ptr, phase01);
    } else {
        LabeledValue("Phase01", phase01);
        AddSimpleTooltip(TIP_PHASE01);
    }
}

void Draw_SPlacement(uint64 ptr, bool isEditable) {
    if (ptr == 0) return;
    auto placement = DPlugItemPlacement_SPlacement(ptr);
    string id = Text::FormatPointer(ptr);
    UI::PushID(id);
    if (isEditable) {
        UI::PushItemWidth(72);
        int layout = UI::InputInt("iLayout", int(placement.iLayout), 0);
        if (layout < 0) layout = 0;
        placement.iLayout = uint(layout);
        UI::PopItemWidth();
    } else {
        LabeledValue("iLayout", placement.iLayout);
    }
    auto opts = placement.Options;
    auto nbOpts = opts.Length;
    auto optFlags = nbOpts <= 4 ? UI::TreeNodeFlags::DefaultOpen : UI::TreeNodeFlags::None;
    if (UI::TreeNode("Options (" + nbOpts + ")##" + id, optFlags)) {
        uint showN = Math::Min(nbOpts, PREFAB_PARAMS_LIST_CAP);
        for (uint i = 0; i < showN; i++) {
            auto opt = opts.GetSPlacementOption(i);
            if (opt is null) continue;
            auto reqTags = opt.RequiredTags;
            auto nbReqTags = reqTags.Length;
            if (UI::TreeNode("RequiredTags (" + nbReqTags + ")##" + i, UI::TreeNodeFlags::DefaultOpen)) {
                for (uint j = 0; j < nbReqTags; j++) {
                    auto tag = reqTags.GetDRequiredTag(j);
                    if (tag is null) continue;
                    if (isEditable) {
                        UI::PushItemWidth(48);
                        uint x = uint(Math::Max(0, UI::InputInt("x##" + j, int(tag.x), 0)));
                        UI::SameLine();
                        uint y = uint(Math::Max(0, UI::InputInt("y##" + j, int(tag.y), 0)));
                        UI::PopItemWidth();
                        UI::SameLine();
                        UI::TextDisabled(ItemPlace_StringConsts::LookupJoined(nat2(x, y)));
                        tag.x = x;
                        tag.y = y;
                    } else {
                        UI::Text(ItemPlace_StringConsts::LookupJoined(tag.xy));
                    }
                }
                UI::TreePop();
            }
        }
        if (nbOpts > showN) UI::TextDisabled("... " + (nbOpts - showN) + " more");
        UI::TreePop();
    }
    UI::PopID();
}

const string TIP_PARENT_ENT_IX = "ParentEntIx (native Ent1): index into the flattened kinematic-dyna list (CPlugDynaObjectModel ents with SInstanceParams.IsKinematic, after nested prefabs are flattened). Not a raw Ents[i] index. -1 = no parent (root of the chain). Compound motion is this parent chain.";
const string TIP_TARGET_ENT_IX = "TargetEntIx (native Ent2): same kinematic-dyna list as ParentEntIx (kin# on the CPlugDynaObjectModel label). The dyna this KC drives, not Ents[n].";
const string TIP_PARENT_POS = "ParentPos (Pos1): point on the parent dyna (ParentEntIx), paired with ParentEntIx the same way TargetPos pairs with TargetEntIx. Rest offset of the child is usually the KC/dyna SEntRef.Location; this is the extra constraint point on the parent. Official items often leave it at 0.";
const string TIP_TARGET_POS = "TargetPos (Pos2): point on the target dyna (TargetEntIx). Extra constraint point on the driven mesh; rest pose is usually SEntRef.Location. Official items often leave it at 0.";

void Draw_SPrefabConstraintParams(uint64 ptr, bool isEditable) {
    if (ptr == 0) return;
    // ParentEntIx is often -1 (no parent). Do not clamp to >= 0.
    int ent1 = Dev::ReadInt32(ptr + O_SPCP_Ent1);
    int ent2 = Dev::ReadInt32(ptr + O_SPCP_Ent2);
    vec3 pos1 = Dev::ReadVec3(ptr + O_SPCP_Pos1);
    vec3 pos2 = Dev::ReadVec3(ptr + O_SPCP_Pos2);
    if (isEditable) {
        string id = Text::FormatPointer(ptr);
        UI::PushID(id);
        if (UI::BeginTable("pcpEq##" + id, 2, UI::TableFlags::SizingStretchSame | UI::TableFlags::NoSavedSettings)) {
            // do target first, intuitive
            UI::TableNextColumn();
            UI::Text("\\$iTarget (This/Self)");
            UI::PushItemWidth(-1);
            ent2 = UI::InputInt("##TargetEntIx", ent2);
            ItemBrowser_MaybeKinHover(ent2);
            AddSimpleTooltip(TIP_TARGET_ENT_IX);
            pos2 = UI::InputFloat3("##TargetPos", pos2);
            AddSimpleTooltip(TIP_TARGET_POS);
            UI::PopItemWidth();
            // do parent 2nd, gray out if ix is -1
            UI::TableNextColumn();
            UI::BeginDisabled(ent1 == -1);
            UI::Text("\\$iParent");
            UI::PushItemWidth(-1);
            ent1 = UI::InputInt("##ParentEntIx", ent1);
            ItemBrowser_MaybeKinHover(ent1);
            AddSimpleTooltip(TIP_PARENT_ENT_IX);
            pos1 = UI::InputFloat3("##ParentPos", pos1);
            AddSimpleTooltip(TIP_PARENT_POS);
            UI::PopItemWidth();
            UI::EndDisabled();
            UI::EndTable();
        }
        UI::PopID();
        Dev::Write(ptr + O_SPCP_Ent1, uint(ent1));
        Dev::Write(ptr + O_SPCP_Ent2, uint(ent2));
        Dev::Write(ptr + O_SPCP_Pos1, pos1);
        Dev::Write(ptr + O_SPCP_Pos2, pos2);
    } else {
        if (UI::BeginTable("pcpRo##" + Text::FormatPointer(ptr), 2, UI::TableFlags::SizingStretchSame | UI::TableFlags::NoSavedSettings)) {
            UI::TableNextColumn();
            LabeledValue("ParentEntIx", ent1);
            ItemBrowser_MaybeKinHover(ent1);
            AddSimpleTooltip(TIP_PARENT_ENT_IX);
            LabeledValue("ParentPos", pos1.ToString());
            AddSimpleTooltip(TIP_PARENT_POS);
            UI::TableNextColumn();
            LabeledValue("TargetEntIx", ent2);
            ItemBrowser_MaybeKinHover(ent2);
            AddSimpleTooltip(TIP_TARGET_ENT_IX);
            LabeledValue("TargetPos", pos2.ToString());
            AddSimpleTooltip(TIP_TARGET_POS);
            UI::EndTable();
        }
    }
}

void DrawSPlacementGroup(uint64 ptr, bool isEditable = false) {
    // RTTI only exposes Placements. Extra arrays from save/double-spectator:
    // +0x00 MwSArray<SPlacement> stride 0x18; +0x10 MwSArray<GmQuatTrans> 0x1C;
    // +0x20 MwSArray<u16>; +0x30 SPlacement dup. Size 0x40.
    auto placementsPtr = Dev::ReadUInt64(ptr + O_SPG_Placements);
    auto len = Dev::ReadUInt32(ptr + O_SPG_Placements + 0x8);
    uint8 pgType = GetPlacementGroupType(ptr);
    LabeledValue("Placements.Length", len);
    LabeledValue("Placements Type", Text::Format("0x%02x", pgType) + " " + PlacementTypeToString(pgType));

    uint showN = Math::Min(len, PREFAB_PARAMS_LIST_CAP);
    if (placementsPtr != 0 && showN > 0) {
        auto plFlags = len <= 4 ? UI::TreeNodeFlags::DefaultOpen : UI::TreeNodeFlags::None;
        if (UI::TreeNode("Placements##" + Text::FormatPointer(ptr), plFlags)) {
            for (uint i = 0; i < showN; i++) {
                if (UI::TreeNode("[" + i + "]##pl" + i)) {
                    Draw_SPlacement(placementsPtr + i * SZ_SPLACEMENTOPTION, isEditable);
                    UI::TreePop();
                }
            }
            if (len > showN) UI::TextDisabled("... " + (len - showN) + " more");
            UI::TreePop();
        }
    }

    auto tqsPtr = Dev::ReadUInt64(ptr + O_SPG_TQs);
    auto nbTqs = Dev::ReadUInt32(ptr + O_SPG_TQs + 0x8);
    auto newNb = Draw_SPlacementGroup_TQs(tqsPtr, nbTqs, isEditable, ptr);
    if (isEditable && newNb < nbTqs && newNb < len) {
        Dev::Write(ptr + O_SPG_Placements + 0x8, newNb);
        Dev::Write(ptr + O_SPG_TQs + 0x8, newNb);
        NotifySuccess("Updated item spectator count, please save the item");
    }

    Draw_SPlacementGroup_U16s(ptr, isEditable);
    Draw_SPlacementGroup_PlacementsDup(ptr, isEditable);
}

void Draw_SPlacementGroup_U16s(uint64 ptr, bool isEditable) {
    auto buf = Dev::ReadUInt64(ptr + O_SPG_U16s);
    auto n = Dev::ReadUInt32(ptr + O_SPG_U16s + 0x8);
    LabeledValue("U16s.Length", n);
    if (buf == 0 || n == 0) return;
    uint showN = Math::Min(n, PREFAB_PARAMS_LIST_CAP);
    if (UI::TreeNode("U16s##" + Text::FormatPointer(ptr))) {
        UI::PushItemWidth(64);
        for (uint i = 0; i < showN; i++) {
            uint16 v = Dev::ReadUInt16(buf + i * 2);
            if (isEditable) {
                int nv = UI::InputInt("[" + i + "]", int(v), 0);
                if (nv < 0) nv = 0;
                if (nv > 0xFFFF) nv = 0xFFFF;
                Dev::Write(buf + i * 2, uint8(nv & 0xFF));
                Dev::Write(buf + i * 2 + 1, uint8((nv >> 8) & 0xFF));
            } else {
                LabeledValue("[" + i + "]", v);
            }
        }
        UI::PopItemWidth();
        if (n > showN) UI::TextDisabled("... " + (n - showN) + " more");
        UI::TreePop();
    }
}

void Draw_SPlacementGroup_PlacementsDup(uint64 ptr, bool isEditable) {
    auto buf = Dev::ReadUInt64(ptr + O_SPG_PlacementsDup);
    auto n = Dev::ReadUInt32(ptr + O_SPG_PlacementsDup + 0x8);
    LabeledValue("PlacementsDup.Length", n);
    if (buf == 0 || n == 0) return;
    uint showN = Math::Min(n, PREFAB_PARAMS_LIST_CAP);
    if (UI::TreeNode("PlacementsDup##" + Text::FormatPointer(ptr))) {
        for (uint i = 0; i < showN; i++) {
            if (UI::TreeNode("[" + i + "]##dup" + i)) {
                Draw_SPlacement(buf + i * SZ_SPLACEMENTOPTION, isEditable);
                UI::TreePop();
            }
        }
        if (n > showN) UI::TextDisabled("... " + (n - showN) + " more");
        UI::TreePop();
    }
}

void Draw_GmQuatTrans(uint64 ptr, bool isEditable, uint i) {
    if (ptr == 0) return;
    vec4 q = Dev::ReadVec4(ptr);
    vec3 t = Dev::ReadVec3(ptr + 0x10);
    UI::PushID("tq" + i);
    if (isEditable) {
        UI::PushItemWidth(220);
        q = UI::InputFloat4("Q", q);
        t = UI::InputFloat3("T", t);
        UI::PopItemWidth();
        Dev::Write(ptr, q);
        Dev::Write(ptr + 0x10, t);
    } else {
        LabeledValue("Q", q.ToString());
        LabeledValue("T", t.ToString());
    }
    UI::PopID();
}

bool PrefabParams_NameLooksLikeBuffer(const string &in n) {
    return n.Contains("Array") || n.Contains("Buf") || n.Contains("Options")
        || n.Contains("Placements") || n.Contains("Tags");
}

bool PrefabParams_NameLooksLikeBool(const string &in n) {
    return n.StartsWith("Is") || n.StartsWith("Has") || n.StartsWith("Can")
        || n.StartsWith("Cast") || n.StartsWith("Use");
}

void DrawSMetaPtr_UnknownScalars(uint64 ptr, const Reflection::MwClassInfo@ ty, bool isEditable) {
    if (ptr == 0 || ty is null) return;
    UI::TextDisabled("Unhandled Params class; scalar members:");
    UI::PushItemWidth(72);
    for (uint i = 0; i < ty.Members.Length; i++) {
        auto mem = ty.Members[i];
        if (mem.Offset >= 0xFFFF) continue;
        string n = mem.Name;
        uint16 o = mem.Offset;
        if (PrefabParams_NameLooksLikeBuffer(n)) {
            LabeledValue(n + " @+" + Text::Format("%x", o), "(buffer)");
            continue;
        }
        if (PrefabParams_NameLooksLikeBool(n)) {
            bool b = Dev::ReadUInt32(ptr + o) != 0;
            if (isEditable) {
                b = UI::Checkbox(n, b);
                Dev::Write(ptr + o, b ? uint(1) : uint(0));
            } else {
                LabeledValue(n, b);
            }
            continue;
        }
        float f0 = Dev::ReadFloat(ptr + o);
        int i0 = Dev::ReadInt32(ptr + o);
        if (isEditable) {
            UI::PushID(n + o);
            float f1 = UI::InputFloat("f32 " + n, f0);
            UI::SameLine();
            int i1 = UI::InputInt("i32 " + n, i0, 0);
            UI::PopID();
            if (f1 != f0) Dev::Write(ptr + o, f1);
            else if (i1 != i0) Dev::Write(ptr + o, uint(i1));
        } else {
            LabeledValue(n + " f32", f0);
            LabeledValue(n + " i32", i0);
        }
    }
    UI::PopItemWidth();
}

void DrawSPlacementOption(uint i, uint layout, CMwNod@ buf, uint len) {
    UI::Text("" + i + ". Layout: " + layout + " / PlacecementOptions.Length: " + len);
}

// returns the number of elements so an update can be detected
uint Draw_SPlacementGroup_TQs(uint64 tqsPtr, uint nbTqs, bool isEditable, uint64 placementGroupPtr) {
    auto ret = nbTqs;
    UI::Text("TQs.Length: " + nbTqs);
    if (IsPlacementGroupForSpectators(placementGroupPtr)) {
        UI::Indent();
        if (UI::Button("Export Spectators")) {
            ExportItemSpectators(tqsPtr, nbTqs);
        }
        if (isEditable) {
            UI::SameLine();
            if (UI::Button("Import Spectators")) {
                ret = ImportItemSpectators(tqsPtr, nbTqs);
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
    } else if (tqsPtr != 0 && nbTqs > 0) {
        uint showN = Math::Min(nbTqs, PREFAB_PARAMS_LIST_CAP);
        auto tqFlags = nbTqs <= 4 ? UI::TreeNodeFlags::DefaultOpen : UI::TreeNodeFlags::None;
        if (UI::TreeNode("TQs##" + Text::FormatPointer(tqsPtr), tqFlags)) {
            for (uint i = 0; i < showN; i++) {
                if (UI::TreeNode("[" + i + "]##tq" + i, nbTqs <= 4 ? UI::TreeNodeFlags::DefaultOpen : UI::TreeNodeFlags::None)) {
                    Draw_GmQuatTrans(tqsPtr + i * SZ_GMQUATTRANS, isEditable, i);
                    UI::TreePop();
                }
            }
            if (nbTqs > showN) UI::TextDisabled("... " + (nbTqs - showN) + " more");
            UI::TreePop();
        }
    }
    return ret;
}

bool IsPlacementGroupForSpectators(uint64 placementGroupPtr) {
    return GetPlacementGroupType(placementGroupPtr) == 0x21
        || GetPlacementGroupType(placementGroupPtr) == 0x22
        ;
}


string PlacementTypeToString(uint8 type) {
    switch (type) {
        case 0x20: return "Attachment Point (?)";
        case 0x21: return "Spectator";
        case 0x22: return "Podium Position";
    }
    return "Unknown";
}


uint8 GetPlacementGroupType(uint64 placementGroupPtr) {
    auto len = Dev::ReadUInt32(placementGroupPtr + 0x8);
    if (len == 0) return 0;
    auto bufPtr = Dev::ReadUInt64(placementGroupPtr + 0x0);
    if (bufPtr == 0) return 0;
    // RequiredTags length
    if (Dev::ReadUInt32(bufPtr + 0x10) < 1) return 0;
    auto innerPtr = Dev::ReadUInt64(bufPtr + 0x8);
    if (innerPtr == 0) return 0;
    // todo, look for first tag with .x=0, read .y
    return Dev::ReadUInt8(innerPtr + 0x14);
}

void Draw_NPlugDyna_SAnimFunc01(CMwNod@ nod, uint16 offset) {
    auto len = Dev::GetOffsetUint32(nod, offset);
    auto startOffset = offset + 0x4;
    for (uint i = 0; i < len; i++) {
        // each subfunc is 0x8 long
        auto sfOffset = startOffset + 0x8 * i;
        auto type = ItemEditor::SubFuncEasings(Dev::GetOffsetUint8(nod, sfOffset));
        auto reverse = Dev::GetOffsetUint8(nod, sfOffset + 0x1) == 1;
        auto duration = Dev::GetOffsetUint32(nod, sfOffset + 0x4);
        UI::Text(tostring(type) + ", Rev: " + reverse + ", Duration: " + duration);
    }
}

const quat ITEM_BROWSER_ENT_IDENTITY_QUAT = quat(0, 0, 0, 1);
const int ITEM_BROWSER_ENT_LODGROUPID_DEFAULT = -1;
const string ITEM_BROWSER_ENT_NLL_ALL_DEFAULTS = " \\$888\\$i all defaults";

bool ItemBrowser_QuatComponentsClose(const quat &in a, const quat &in b, float eps = 1e-4) {
    return Math::Abs(a.x - b.x) < eps && Math::Abs(a.y - b.y) < eps && Math::Abs(a.z - b.z) < eps && Math::Abs(a.w - b.w) < eps;
}

bool ItemBrowser_EulerIsZero(const vec3 &in e, float eps = 1e-4) {
    return Math::Abs(e.x) < eps && Math::Abs(e.y) < eps && Math::Abs(e.z) < eps;
}

bool ItemBrowser_QuatIsDefault(const quat &in q) {
    return ItemBrowser_EulerIsZero(q.Euler());
}

void ItemBrowser_ApplyEntLocRot(quat &out q, bool &out lastWasQuat, const quat &in qBefore, const quat &in qAfter, const vec3 &in eulerBefore, const vec3 &in eulerAfter, bool lastWasQuatIn) {
    if (!ItemBrowser_QuatComponentsClose(qBefore, qAfter)) {
        q = qAfter;
        lastWasQuat = true;
        return;
    }
    if (!MathX::Vec3Eq(eulerBefore, eulerAfter)) {
        q = quat(eulerAfter);
        lastWasQuat = false;
        return;
    }
    q = qBefore;
    lastWasQuat = lastWasQuatIn;
}

class ItemBrowser_EntLocEulerCache {
    vec3 euler;
    bool lastWasQuat = true;
}

dictionary g_IB_EntLocEulerCache;

ItemBrowser_EntLocEulerCache@ ItemBrowser_GetEntLocEulerCache(const string &in key) {
    ItemBrowser_EntLocEulerCache@ cache;
    if (!g_IB_EntLocEulerCache.Get(key, @cache) || cache is null) {
        @cache = ItemBrowser_EntLocEulerCache();
        @g_IB_EntLocEulerCache[key] = cache;
    }
    return cache;
}

void ItemBrowser_DrawEntLocationQuatEuler(CPlugPrefab@ prefab, uint i, bool isEditable) {
    quat q0 = prefab.Ents[i].Location.Quat;
    if (!isEditable) {
        CopiableLabeledValue(".Location.Quat", q0.ToString());
        CopiableLabeledValue(".Location.Euler (deg)", MathX::ToDeg(q0.Euler()).ToString());
        return;
    }
    string key = Text::FormatPointer(Dev_GetPointerForNod(prefab)) + "/" + i;
    auto cache = ItemBrowser_GetEntLocEulerCache(key);
    quat q1 = UX::InputQuat(".Location.Quat", q0, ITEM_BROWSER_ENT_IDENTITY_QUAT);
    vec3 euler0 = cache.lastWasQuat ? q0.Euler() : cache.euler;
    vec3 euler1 = UX::InputAngles3(".Location.Euler (deg)", euler0);
    quat qOut;
    bool lastWasQuat;
    ItemBrowser_ApplyEntLocRot(qOut, lastWasQuat, q0, q1, euler0, euler1, cache.lastWasQuat);
    prefab.Ents[i].Location.Quat = qOut;
    cache.lastWasQuat = lastWasQuat;
    if (!lastWasQuat) cache.euler = euler1;
}

string ItemBrowser_EntNllTreeTitle(const string &in name, const quat &in q, const vec3 &in trans, int lodGroupId) {
    array<string> parts;
    if (name.Length > 0) parts.InsertLast("Name=\"" + name + "\"");
    if (!ItemBrowser_QuatIsDefault(q)) parts.InsertLast("Quat=" + q.ToString());
    if (trans.LengthSquared() > 1e-10) parts.InsertLast("Trans=" + trans.ToString());
    if (lodGroupId != ITEM_BROWSER_ENT_LODGROUPID_DEFAULT) parts.InsertLast("LodGroupId=" + tostring(lodGroupId));
    string t = "Name/Location/LodGroupId";
    if (parts.Length > 0) t += "  " + Text::Join(parts, "  ");
    else t += ITEM_BROWSER_ENT_NLL_ALL_DEFAULTS;
    return t;
}

void ItemBrowser_ReadShaderTcData(NPlugDyna_SKinematicConstraint@ kc, uint &out nb, uint &out perLine, uint &out perCol) {
    uint16 off = GetOffset(kc, "ShaderTcData_TransSub");
    nb = Dev::GetOffsetUint32(kc, off);
    perLine = Dev::GetOffsetUint32(kc, off + 0x4);
    perCol = Dev::GetOffsetUint32(kc, off + 0x8);
}

string ItemBrowser_ShaderTcAnimFuncTreeTitle(NPlugDyna::EShaderTcType ty, uint len, uint nb, uint perLine, uint perCol) {
    string t = "ShaderTcAnimFunc (" + len + ") " + tostring(ty);
    if (nb != 1) t += "  NbSubTexture=" + nb;
    if (perLine != 1) t += "  NbSubTexturePerLine=" + perLine;
    if (perCol != 1) t += "  NbSubTexturePerColumn=" + perCol;
    return t;
}

void Draw_NPlugDyna_SKinematicConstraint_Props(NPlugDyna_SKinematicConstraint@ kc, bool isEditable) {
    if (kc is null) return;
    string id = Text::FormatPointer(Dev_GetPointerForNod(kc));
    UI::PushID(id);

    if (isEditable) {
        UI::PushItemWidth(72);
        if (UI::BeginTable("kc##" + id, 3, UI::TableFlags::SizingStretchProp)) {
            UI::TableNextColumn();
            kc.TransAxis = DrawComboEAxis("TransAxis", kc.TransAxis);
            UI::TableNextColumn();
            kc.TransMin = UI::InputFloat("TransMin", kc.TransMin);
            UI::TableNextColumn();
            kc.TransMax = UI::InputFloat("TransMax", kc.TransMax);
            UI::TableNextColumn();
            kc.RotAxis = DrawComboEAxis("RotAxis", kc.RotAxis);
            UI::TableNextColumn();
            kc.AngleMinDeg = UI::InputFloat("AngleMinDeg", kc.AngleMinDeg);
            UI::TableNextColumn();
            kc.AngleMaxDeg = UI::InputFloat("AngleMaxDeg", kc.AngleMaxDeg);
            UI::EndTable();
        }
        UI::PopItemWidth();
        Draw_NPlugDyna_SAnimFunc01_Inputs(kc, GetOffset(kc, "TransAnimFunc"), "TransAnimFunc", 4);
        Draw_NPlugDyna_SAnimFunc01_Inputs(kc, GetOffset(kc, "RotAnimFunc"), "RotAnimFunc", 4);
        Draw_NPlugDyna_SAnimFuncNat_Inputs(kc, GetOffset(kc, "ShaderTcAnimFunc"), "ShaderTcAnimFunc", 12, true);
    } else {
        LabeledValue("TransAxis", tostring(kc.TransAxis));
        LabeledValue("TransMin", kc.TransMin);
        LabeledValue("TransMax", kc.TransMax);
        LabeledValue("RotAxis", tostring(kc.RotAxis));
        LabeledValue("AngleMinDeg", kc.AngleMinDeg);
        LabeledValue("AngleMaxDeg", kc.AngleMaxDeg);
        if (UI::TreeNode("TransAnimFunc")) {
            Draw_NPlugDyna_SAnimFunc01(kc, GetOffset(kc, "TransAnimFunc"));
            UI::TreePop();
        }
        if (UI::TreeNode("RotAnimFunc")) {
            Draw_NPlugDyna_SAnimFunc01(kc, GetOffset(kc, "RotAnimFunc"));
            UI::TreePop();
        }
        uint nb, perLine, perCol;
        ItemBrowser_ReadShaderTcData(kc, nb, perLine, perCol);
        uint8 stcLen = Dev::GetOffsetUint8(kc, GetOffset(kc, "ShaderTcAnimFunc"));
        if (UI::TreeNode(ItemBrowser_ShaderTcAnimFuncTreeTitle(kc.ShaderTcType, stcLen, nb, perLine, perCol) + "###stcaf-ro")) {
            LabeledValue("ShaderTcType", tostring(kc.ShaderTcType));
            Draw_NPlugDyna_SAnimFuncNat_Read(kc, GetOffset(kc, "ShaderTcAnimFunc"));
            Draw_NPlugDyna_ShaderTcData_Inputs(kc, false);
            UI::TreePop();
        }
    }

    UI::PopID();
}

void Draw_NPlugDyna_SAnimFunc01_Inputs(NPlugDyna_SKinematicConstraint@ nod, uint16 offset, const string &in label, uint8 maxLen) {
    uint8 len = Dev::GetOffsetUint8(nod, offset);
    if (UI::TreeNode(label + " (" + len + ")##" + offset, UI::TreeNodeFlags::DefaultOpen)) {
        if (len < maxLen && UX::SmallButton("+##add" + label + offset)) {
            _SAnimFunc_IncrementEasingCountSetDefaults(nod, offset);
            len = Dev::GetOffsetUint8(nod, offset);
        }
        if (len > 1) {
            UI::SameLine();
            if (UX::SmallButton("-##rm" + label + offset)) {
                _SAnimFunc_DecrementEasingCount(nod, offset);
                len = Dev::GetOffsetUint8(nod, offset);
            }
        }
        auto arrStart = offset + 0x4;
        for (uint i = 0; i < len; i++) {
            auto sf = arrStart + i * 0x8;
            auto type = ItemEditor::SubFuncEasings(Dev::GetOffsetUint8(nod, sf));
            bool reverse = Dev::GetOffsetUint8(nod, sf + 0x1) != 0;
            uint duration = Dev::GetOffsetUint32(nod, sf + 0x4);
            UI::PushItemWidth(110);
            type = DrawComboSubFuncEasings("##e" + i + label, type);
            UI::PopItemWidth();
            UI::SameLine();
            reverse = UI::Checkbox("Rev##" + i + label, reverse);
            UI::SameLine();
            UI::PushItemWidth(64);
            duration = Math::Clamp(UI::InputInt("ms##" + i + label, duration, 0), 0, 2000000000);
            UI::PopItemWidth();
            Dev::SetOffset(nod, sf + 0x0, uint8(type));
            Dev::SetOffset(nod, sf + 0x1, reverse ? 0x1 : 0x0);
            Dev::SetOffset(nod, sf + 0x4, duration);
        }
        UI::TreePop();
    }
}

void Draw_NPlugDyna_SAnimFuncNat_Read(CMwNod@ nod, uint16 offset) {
    uint8 len = Dev::GetOffsetUint8(nod, offset);
    auto arrStart = offset + 0x4;
    for (uint i = 0; i < len; i++) {
        auto sf = arrStart + i * 0x8;
        UI::Text("[" + i + "] DurationMs: " + Dev::GetOffsetUint32(nod, sf) + ", Value: " + Dev::GetOffsetUint32(nod, sf + 0x4));
    }
}

void Draw_NPlugDyna_SAnimFuncNat_Inputs(NPlugDyna_SKinematicConstraint@ nod, uint16 offset, const string &in label, uint8 maxLen, bool withShaderTc = false) {
    uint8 len = Dev::GetOffsetUint8(nod, offset);
    string title = label + " (" + len + ")";
    if (withShaderTc) {
        uint nb, perLine, perCol;
        ItemBrowser_ReadShaderTcData(nod, nb, perLine, perCol);
        title = ItemBrowser_ShaderTcAnimFuncTreeTitle(nod.ShaderTcType, len, nb, perLine, perCol);
    }
    if (UI::TreeNode(title + "###stcaf-" + offset)) {
        if (withShaderTc) {
            UI::PushItemWidth(140);
            nod.ShaderTcType = DrawComboEShaderTcType("ShaderTcType", nod.ShaderTcType);
            UI::PopItemWidth();
        }
        if (len < maxLen && UX::SmallButton("+##add" + label + offset)) {
            auto sf = offset + 0x4 + len * 0x8;
            Dev::SetOffset(nod, sf, uint32(1000));
            Dev::SetOffset(nod, sf + 0x4, uint32(0));
            Dev::SetOffset(nod, offset, uint32(len + 1));
            len = len + 1;
        }
        if (len > 0) {
            UI::SameLine();
            if (UX::SmallButton("-##rm" + label + offset)) {
                Dev::SetOffset(nod, offset, uint32(len - 1));
                len = len - 1;
            }
        }
        auto arrStart = offset + 0x4;
        for (uint i = 0; i < len; i++) {
            auto sf = arrStart + i * 0x8;
            uint duration = Dev::GetOffsetUint32(nod, sf);
            uint value = Dev::GetOffsetUint32(nod, sf + 0x4);
            UI::PushItemWidth(64);
            duration = Math::Clamp(UI::InputInt("ms##" + i + label, duration, 0), 0, 2000000000);
            UI::SameLine();
            value = UI::InputInt("val##" + i + label, value, 0);
            UI::PopItemWidth();
            Dev::SetOffset(nod, sf, duration);
            Dev::SetOffset(nod, sf + 0x4, value);
        }
        if (withShaderTc) {
            Draw_NPlugDyna_ShaderTcData_Inputs(nod, true);
        }
        UI::TreePop();
    }
}

void Draw_NPlugDyna_ShaderTcData_Inputs(NPlugDyna_SKinematicConstraint@ kc, bool isEditable) {
    uint16 off = GetOffset(kc, "ShaderTcData_TransSub");
    uint nb = Dev::GetOffsetUint32(kc, off);
    uint perLine = Dev::GetOffsetUint32(kc, off + 0x4);
    uint perCol = Dev::GetOffsetUint32(kc, off + 0x8);
    if (isEditable) {
        UI::PushItemWidth(PREFAB_PARAMS_W);
        nb = Math::Max(0, UI::InputInt("NbSubTexture", nb, 0));
        perLine = Math::Max(0, UI::InputInt("NbSubTexturePerLine", perLine, 0));
        perCol = Math::Max(0, UI::InputInt("NbSubTexturePerColumn", perCol, 0));
        UI::PopItemWidth();
        Dev::SetOffset(kc, off, nb);
        Dev::SetOffset(kc, off + 0x4, perLine);
        Dev::SetOffset(kc, off + 0x8, perCol);
    } else {
        LabeledValue("NbSubTexture", nb);
        LabeledValue("NbSubTexturePerLine", perLine);
        LabeledValue("NbSubTexturePerColumn", perCol);
    }
}

// class SAnimFunc01 {
//     SAnimFunc01(SubFuncEasings easing, bool reverse, uint duration)
// }


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
    CMwNod@ GetNodForZeroing() {
        if (parent !is null) return parent.nod;
        if (child !is null) return child.nod;
        return null;
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

    string get_pickDirectChildLabel() { return "This Nod (Direct)##"+this.name+this.nodOffset+this.currentIndex+this.parentIx; }
    string get_pickIndirectChildLabel() { return "This Nod (Indirect)##"+this.name+this.nodOffset+this.currentIndex+this.parentIx; }
    string get_pickArrayElementLabel() { return "This Element##"+this.name+this.nodOffset+this.currentIndex+this.parentIx; }
    string get_pickAllChildrenLabel() { return "All Children##"+this.name+this.nodOffset+this.currentIndex+this.parentIx; }

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

class TerrainBlockModelBrowserTab : BlockModelBrowserTab {
    TerrainBlockModelBrowserTab(TabGroup@ p) {
        super(p, "Terrain Block Browser");
    }

    CGameCtnBlockInfo@ GetBlockInfo() override {
        if (selectedTerrainBlockInfo is null) return null;
        return selectedTerrainBlockInfo.AsBlockInfo();
    }
}




void DrawMaterialModifier(CPlugGameSkinAndFolder@ matMod, const string &in label = "Material Modifier") {
    if (matMod is null) {
        UI::Text("No " + label);
        return;
    }
    UI::AlignTextToFramePadding();
    UI::Text(label + ":");
    UI::Text("Skin:");
    UI::Indent();
    DrawMMSkin(matMod);
    UI::Unindent();
    // UI::Separator();
    UI::Text("RemapFolder: " + (matMod.RemapFolder is null ? "null" : string(matMod.RemapFolder.DirName)));
    UI::Indent();
    DrawMMFids(matMod);
    UI::Unindent();
}

void DrawMMSkin(CPlugGameSkinAndFolder@ mm) {
    auto skin = mm.Remapping;
    if (skin is null) {
        UI::Text("No skin");
        return;
    }
    string p1 = Dev::GetOffsetString(skin, 0x18);
    string p2 = Dev::GetOffsetString(skin, 0x28);
    auto fidBuf = Dev::GetOffsetNod(skin, 0x58);
    auto fidBufC = Dev::GetOffsetUint32(skin, 0x58 + 0x8);
    auto strBuf = Dev::GetOffsetNod(skin, 0x68);
    auto strBufC = Dev::GetOffsetUint32(skin, 0x68 + 0x8);
    auto clsBuf = Dev::GetOffsetNod(skin, 0x78);
    auto unkBuf = Dev::GetOffsetNod(skin, 0x88);
    CopiableLabeledValue("Pri Path", p1);
    CopiableLabeledValue("Sec Path", p2);
    if (UI::BeginTable("skintable", 4, UI::TableFlags::SizingStretchProp)) {
        UI::TableSetupColumn("Use");
        UI::TableSetupColumn("To Replace");
        UI::TableSetupColumn("ClassID");
        UI::TableSetupColumn("Unk");
        UI::TableHeadersRow();
        for (uint i = 0; i < fidBufC; i++) {
            auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(fidBuf, 0x8 * i));
            auto str = Dev::GetOffsetString(strBuf, 0x10 * i);
            auto cls = Dev::GetOffsetUint32(clsBuf, 0x4 * i);
            auto unk = Dev::GetOffsetUint32(unkBuf, 0x4 * i);
            UI::TableNextRow();
            UI::TableNextColumn();
            UI::Text(str);
            UI::TableNextColumn();
            UI::Text(fid.FileName + "  " + (fid.Nod !is null ? Icons::Check : Icons::Times));
#if SIG_DEVELOPER
            // if (UI::IsItemClicked()) {
            //     ExploreNod(fid);
            // }
#endif
            UI::TableNextColumn();
            UI::Text(Text::Format("0x%08x", cls));
            UI::TableNextColumn();
            UI::Text(Text::Format("0x%08x", unk));
        }

        UI::EndTable();
    }
}

void DrawMMFids(CPlugGameSkinAndFolder@ mm) {
    if (mm.RemapFolder is null) return;
    for (uint i = 0; i < mm.RemapFolder.Leaves.Length; i++) {
        auto fid = mm.RemapFolder.Leaves[i];
        CopiableLabeledValue("Name", fid.FileName);
        UI::SameLine();
        LabeledValue("Loaded", fid.Nod !is null);
#if SIG_DEVELOPER
        UI::SameLine();
        if (UX::SmallButton(Icons::Cube + " Explore##mmfid" + i)) {
            ExploreNod(fid);
        }
#endif
    }
}


string ClipFaceStr(int clipFace) {
    switch (clipFace) {
        case -1: return "--";
        case 0: return "North";
        case 1: return "East";
        case 2: return "South";
        case 3: return "West";
        case 4: return "Top";
        case 5: return "Bottom";
    }
    return "Unk(" + clipFace + ")";
}


string MwFastBuffer_uint_ToString(MwFastBuffer<uint>&in buf) {
    string ret = "Len=" + buf.Length + ": [ ";
    for (uint i = 0; i < buf.Length; i++) {
        if (i > 0) ret += ", ";
        ret += Text::Format("0x%08x", buf[i]);
    }
    return ret + " ]";
}
