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
                bool setDACS = UI::Checkbox("DisableAutoCreateSound", disableAutoCreateSound);
                if (setDACS != disableAutoCreateSound) {
                    Editor::SetItemModel_DisableAutoCreateSound(item, setDACS);
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
            if (UX::SmallButton("Nullify EntityModelEdition")) {
                Dev::SetOffset(item, O_ITEM_MODEL_EntityModelEdition, uint64(0));
                trace('Nullified itemModel.EME');
            }
            AddSimpleTooltip("After nullifying, the item will fail to save if any CPlugSurfaces have materials -- to fix click TransformMaterialsToMatIds.");
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
            MkAndDrawChildNode(blockInfo.MaterialModifier, O_BLOCKINFO_MATERIALMOD, "MaterialModifier");
            auto mmOffset = O_BLOCKINFO_MATERIALMOD;
            auto mmPlacementTag = Dev::GetOffsetNat2(blockInfo, mmOffset);
            string mmPlacementTagsStr = ItemPlace_StringConsts::LookupJoined(mmPlacementTag);
            DrawMwId("Name", blockInfo.Id);
            // CopiableLabeledValue("Name MwID", toHex(blockInfo.Id.Value) + " > " + blockInfo.Id.GetName());
            if (isEditable) {
                Dev::SetOffset(blockInfo, mmOffset, UX::InputNat2("MatModifierPlacementTag", mmPlacementTag));
            } else {
                CopiableLabeledValue("PageName", blockInfo.PageName);
                CopiableLabeledValue("CatalogPosition", tostring(blockInfo.CatalogPosition));
                // works, but only returns the first type of label
                // try { extra = string(blockInfo.MatModifierPlacementTag.Type); } catch {}
                UI::Text("MatModiferPlacementTag: " + mmPlacementTag.ToString() + " / " + mmPlacementTagsStr);
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

#if SIG_DEVELOPER
        clip.IsFullFreeClip = UI::Checkbox("IsFullFreeClip", clip.IsFullFreeClip);
        UI::SameLine();
        clip.IsExclusiveFreeClip = UI::Checkbox("IsExclusiveFreeClip", clip.IsExclusiveFreeClip);
        clip.CanBeDeletedByFullFreeClip = UI::Checkbox("CanBeDeletedByFullFreeClip", clip.CanBeDeletedByFullFreeClip);
        UI::SameLine();
        clip.IsAlwaysVisibleFreeClip = UI::Checkbox("IsAlwaysVisibleFreeClip", clip.IsAlwaysVisibleFreeClip);
        clip.IsFCTOrFCBIgnoredByVFC = UI::Checkbox("IsFCTOrFCBIgnoredByVFC", clip.IsFCTOrFCBIgnoredByVFC);
        UI::SameLine();
        clip.IsAntiClip = UI::Checkbox("IsAntiClip", clip.IsAntiClip);
#else
        LabeledValue("IsFullFreeClip", tostring(clip.IsFullFreeClip));
        UI::SameLine();
        LabeledValue("IsExclusiveFreeClip", tostring(clip.IsExclusiveFreeClip));
        LabeledValue("CanBeDeletedByFullFreeClip", tostring(clip.CanBeDeletedByFullFreeClip));
        UI::SameLine();
        LabeledValue("IsAlwaysVisibleFreeClip", tostring(clip.IsAlwaysVisibleFreeClip));
        LabeledValue("IsFCTOrFCBIgnoredByVFC", tostring(clip.IsFCTOrFCBIgnoredByVFC));
        UI::SameLine();
        LabeledValue("IsAntiClip", tostring(clip.IsAntiClip));
#endif

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
            LabeledValue("Container", fid.Container.FileName);
            UI::SameLine();
            if (UI::Button(Icons::Cube + "##fid-container")) {
                ExploreNod("Container", fid.Container);
            }
#endif
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
                            CopiableLabeledValue(".Name", string(prefab.Ents[i].Name));
                            if (isEditable) {
                                prefab.Ents[i].Location.Quat = UX::InputQuat(".Location.Quat", prefab.Ents[i].Location.Quat);
                                prefab.Ents[i].Location.Trans = UI::InputFloat3(".Location.Trans", prefab.Ents[i].Location.Trans);
                                prefab.Ents[i].LodGroupId = UI::InputInt(".LodGroupId", prefab.Ents[i].LodGroupId);
                            } else {
                                CopiableLabeledValue(".Location.Quat", prefab.Ents[i].Location.Quat.ToString());
                                CopiableLabeledValue(".Location.Trans", prefab.Ents[i].Location.Trans.ToString());
                                CopiableLabeledValue(".LodGroupId", tostring(prefab.Ents[i].LodGroupId));
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
                        varList.Variants[i].HiddenInManualCycle = UI::Checkbox("HiddenInManualCycle", varList.Variants[i].HiddenInManualCycle);
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
        if (StartTreeNode(name + " :: \\$f8fCPlugDynaObjectModel", DEFAULT_OPEN)) {
            MkAndDrawChildNode(dynaObject.Mesh, "Mesh");
            MkAndDrawChildNode(dynaObject.StaticShape, "StaticShape");
            MkAndDrawChildNode(dynaObject.DynaShape, "DynaShape");
            EndTreeNode();
        }
    }
    void Draw(NPlugDyna_SKinematicConstraint@ kc) {
        if (StartTreeNode(name + " :: \\$f8fNPlugDyna_SKinematicConstraint", DEFAULT_OPEN)) {
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
                        auto newColorPtr = RequestMemory(0x10);
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
        if (StartTreeNode(name + " :: \\$f8fCPlugSurface", DEFAULT_OPEN)) {
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
                }
                Draw("m_GmSurf", surf.m_GmSurf);
                MkAndDrawChildNode(surf.Skel, GetOffset(surf, "Skel"), "Skel");
            }
            EndTreeNode();
        }
    }

    void Draw(const string &in _name, GmSurf@ gmSurf) {
        if (StartTreeNode(_name + " :: \\$f8fGmSurf", true, DEFAULT_OPEN)) {
            if (isEditable) {
                gmSurf.GmSurfType = DrawComboEGmSurfType("GmSurfType", gmSurf.GmSurfType);
                AddSimpleTooltip("MUST match the type of this surface -- do not touch if you don't know what you're doing. Game will crash for incorrect values.");
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

            if (gmSurf.GmSurfType == EGmSurfType::Mesh) {
                auto nbVerts = Dev::GetOffsetUint32(gmSurf, 0x28);
                auto nbTris = Dev::GetOffsetUint32(gmSurf, 0x38);
                LabeledValue("Nb Verts", nbVerts);
                LabeledValue("Nb Tris", nbTris);
                if (isEditable && UI::Button("Zero Vert/Tris Buffers")) {
                    // ManipPtrs::Replace(gmSurf, 0x28, 0, false);
                    // ManipPtrs::Replace(gmSurf, 0x38, 0, false);
                    Dev::SetOffset(gmSurf, 0x28, uint(0));
                    Dev::SetOffset(gmSurf, 0x38, uint(0));
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
    } else if (clsId == CLSID_NPlugItemPlacement_SPlacement || type == "NPlugItemPlacement::SPlacement") {
        Draw_SPlacement(ptr, isEditable);
    }
}

void Draw_SPlacement(uint64 ptr, bool isEditable) {
    auto placement = DPlugItemPlacement_SPlacement(ptr);
    if (isEditable && false) {

    } else {
        LabeledValue("iLayout", placement.iLayout);
        auto opts = placement.Options;
        auto nbOpts = opts.Length;
        if (UI::TreeNode("Options (" + nbOpts + ")##" + ptr, UI::TreeNodeFlags::DefaultOpen)) {
            for (uint i = 0; i < nbOpts; i++) {
                auto opt = opts.GetSPlacementOption(i);
                if (opt is null) continue;
                auto optPtr = opt.Ptr;
                auto reqTags = opt.RequiredTags;
                auto nbReqTags = reqTags.Length;
                if (UI::TreeNode("RequiredTags (" + nbReqTags + ")##" + optPtr, UI::TreeNodeFlags::DefaultOpen)) {
                    for (uint j = 0; j < nbReqTags; j++) {
                        auto tag = reqTags.GetDRequiredTag(j);
                        if (tag is null) continue;
                        auto tagPtr = tag.Ptr;
                        UI::Text(ItemPlace_StringConsts::LookupJoined(tag.xy));
                        // LabeledValue("Tag["+j+"]", Text::FormatPointer(tagPtr));
                        // LabeledValue("Tag["+j+"]<x, y>", "" + tag.x + ", " + tag.y);
                        // LabeledValue("TagType##" + j, tag.Type);
                    }
                    UI::TreePop();
                }
            }
            UI::TreePop();
        }
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
    LabeledValue("Placements Type", Text::Format("0x%02x", GetPlacementGroupType(ptr)));
    uint elSize = SZ_SPLACEMENTOPTION;
    for (int i = 0; i < Math::Min(5, len); i++) {
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
    // auto tqs = Dev_GetNodFromPointer(tqsPtr);
    // LabeledValue("TQs is null", tqs is null);
    auto nbTqs = Dev::ReadUInt32(ptr + 0x18);
    auto newNb = Draw_SPlacementGroup_TQs(tqsPtr, nbTqs, isEditable, ptr);
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
uint Draw_SPlacementGroup_TQs(uint64 tqsPtr, uint nbTqs, bool isEditable, uint64 placementGroupPtr) {
    auto ret = nbTqs;
    UI::Text("TQs.Length: " + nbTqs);
    if (IsPlacementGroupForSpectators(placementGroupPtr)) {
        // UI::SameLine();
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
        auto type = SubFuncEasings(Dev::GetOffsetUint8(nod, sfOffset));
        auto reverse = Dev::GetOffsetUint8(nod, sfOffset + 0x1) == 1;
        auto duration = Dev::GetOffsetUint32(nod, sfOffset + 0x4);
        UI::Text(tostring(type) + ", Rev: " + reverse + ", Duration: " + duration);
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
