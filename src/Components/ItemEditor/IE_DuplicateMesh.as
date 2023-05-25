
namespace MeshDuplication {

    bool SafetyCheck(CGameItemModel@ model) {
        if (model.EntityModelEdition !is null) {
            NotifyWarning("Item's EntityModelEdition !is null. It's probably a crystal. Not sure what to do.");
            return false;
        }
        return true;
    }

    CPlugGameSkinAndFolder@ matMod = null;
    void PushMaterialModifier(CPlugGameSkinAndFolder@ mm) {
        if (matMod !is null) throw('already have a material modifier');
        if (mm is null) return;
        @matMod = mm;
        matMod.MwAddRef();
    }

    void PopMaterialModifier() {
        if (matMod is null) return;
        matMod.MwRelease();
        @matMod = null;
    }

    void ZeroChildFids(CGameItemModel@ model) {
        // no need to change anything on the model itself,
        // but we want to zero all the fids and dependencies of children,
        // particularly under EntityModel
        auto em = model.EntityModel;
        if (em is null) throw('null EntityModel');

        auto ciEntity = cast<CGameCommonItemEntityModel>(model.EntityModel);
        auto varList = cast<NPlugItem_SVariantList>(model.EntityModel);
        auto prefab = cast<CPlugPrefab>(model.EntityModel);

        if (ciEntity !is null) {
            ZeroFids(ciEntity);
        } else if (varList !is null) {
            ZeroFids(varList);
        } else if (prefab !is null) {
            // prefabs can have fids in the model immediately after .EntityModel ptr
            // ignore for now, but maybe zero if need be
            ZeroFids(prefab);
        }

        if (model.MaterialModifier !is null) {
            ZeroFids(model.MaterialModifier);
        }
    }

    void ZeroFids(CGameCommonItemEntityModel@ ciModel) {
        AlertIfFid(ciModel);
        if (ciModel.StaticObject is null) return;
        auto staticObj = cast<CPlugStaticObjectModel>(ciModel.StaticObject);
        if (staticObj !is null) {
            ZeroFids(staticObj);
        } else {
            NotifyError("ciModel.StaticObject is not a CPlugStaticObjectModel.");
            NotifyError("ciModel.StaticObject type: " + Reflection::TypeOf(ciModel.StaticObject).Name);
        }

        if (ciModel.TriggerShape !is null) {
            ZeroFids(ciModel.TriggerShape);
        }
    }

    void ZeroFids(NPlugItem_SVariantList@ varList) {
        AlertIfFid(varList);
        trace('Zeroing fids for valist');
        for (uint i = 0; i < varList.Variants.Length; i++) {
            if (varList.Variants[i].EntityModel is null) continue;
            trace('Zeroing fid: variant ' + i);
            // ZeroFidsUnknownModelNod(varList.Variants[i].EntityModel);
            auto staticObj = cast<CPlugStaticObjectModel>(varList.Variants[i].EntityModel);
            auto prefab = cast<CPlugPrefab>(varList.Variants[i].EntityModel);
            auto vegetTree = cast<CPlugVegetTreeModel>(varList.Variants[i].EntityModel);
            if (staticObj !is null) {
                ZeroFids(staticObj);
            } else if (prefab !is null) {
                ZeroFids(prefab);
            } else if (vegetTree !is null) {
                ZeroFids(vegetTree);
            } else {
                NotifyError("varList.Variants["+i+"].EntityModel is unknown.");
                NotifyError("varList.Variants["+i+"].EntityModel type: " + Reflection::TypeOf(varList.Variants[i].EntityModel).Name);
            }


            trace('variant['+i+'] children fids zeroed');
            // todo: zero if need be
            if (varList.Variants[i].EntityModelFidForReload !is null) {
                trace('Zeroing fid: variant ' + i + '.EntityModelFidForReload');
                // NotifyWarning("varList.Variants["+i+"].EntityModelFidForReload !is null");
                auto variants = Dev::GetOffsetNod(varList, GetOffset("NPlugItem_SVariantList", "Variants"));
                // auto variantStruct = Dev::GetOffsetNod(variants, 0x28 * i);
                Dev::SetOffset(variants, 0x28 * i + GetOffset("NPlugItem_SVariant", "EntityModelFidForReload"), uint64(0));
                // NPlugItem_SVariant@ x;
                // Dev::SetOffset(varList.Variants[i], GetOffset("NPlugItem_SVariant", "EntityModelFidForReload"), uint64(0));
            }
        }
    }

    void SetVariantModel(NPlugItem_SVariantList@ varList, int ix, CMwNod@ nod) {
        // length of a _SVariant: 0x28
        auto variants = Dev::GetOffsetNod(varList, GetOffset("NPlugItem_SVariantList", "Variants"));
        nod.MwAddRef();
        Dev::SetOffset(variants, 0x28 * ix + GetOffset("NPlugItem_SVariant", "EntityModelFidForReload"), nod);
    }

    void ZeroFids(CPlugVegetTreeModel@ tree) {
        ZeroNodFid(tree);
        // some fids do exist under tree.Data but we mb get lucky and don't need to zero them (materials / textures and stuff)
    }

    void ZeroFids(CPlugSurface@ surface) {
        ZeroNodFid(surface);
        // don't zero material Fids
        FixMatsOnShape(surface);
    }

    void ZeroFids(CPlugPrefab@ prefab) {
        ApplyMaterialMods(prefab);
        ZeroNodFid(prefab);
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            if (prefab.Ents[i].ModelFid !is null) {
                trace("Zeroing fid: prefab.Ents["+i+"].ModelFid");
                auto ents = Dev::GetOffsetNod(prefab, GetOffset("CPlugPrefab", "Ents"));
                // size: NPlugPrefab_SEntRef: 0x50
                // probs null b/c there are no bytes at the start
                // auto ent = Dev::GetOffsetNod(ents, 0x50 * i);
                if (ents !is null)
                    Dev::SetOffset(ents, 0x50 * i + GetOffset("NPlugPrefab_SEntRef", "ModelFid"), uint64(0));
                else {
                    NotifyWarning("ents was null!");
                }
            }
            trace('Zeroing fids for prefab.Ents['+i+'].Model');
            auto eh = cast<CPlugEditorHelper>(prefab.Ents[i].Model);
            if (eh !is null) {
                trace('zeroing editor helper model');
                /* zero out entity model -- cannot save it
                */
                // auto ents = Dev::GetOffsetNod(prefab, GetOffset("CPlugPrefab", "Ents"));
                // Dev::SetOffset(ents, 0x50 * i + GetOffset("NPlugPrefab_SEntRef", "Model"), uint64(0));
                SetEntRefModel(prefab, i, null);
                // eh.PrefabFid.Nod.MwAddRef();
                // ZeroFidsUnknownModelNod(eh.PrefabFid.Nod);
            } else {
                ZeroFidsUnknownModelNod(prefab.Ents[i].Model);
            }
        }
    }

    void SetEntRefModel(CPlugPrefab@ prefab, int entityIx, CMwNod@ nod) {
        // size: NPlugPrefab_SEntRef: 0x50
        auto ents = Dev::GetOffsetNod(prefab, GetOffset("CPlugPrefab", "Ents"));
        nod.MwAddRef();
        Dev::SetOffset(ents, 0x50 * entityIx + GetOffset("NPlugPrefab_SEntRef", "Model"), nod);
    }

    void ZeroFids(CPlugSpawnModel@ sm) {
        // nothing to do, no fids
    }

    void ZeroFids(CPlugEditorHelper@ eh) {
        // nothing to do? has PrefabFid as only prop...
        NotifyWarning("Unsure if CPlugEditorHelper's work or not.");
    }

    void ZeroFids(CPlugStaticObjectModel@ so) {
        ZeroNodFid(so);
        // todo: MeshFidForReload / ShapeFidForReload if need be
        if (so.MeshFidForReload !is null) {
            // NotifyWarning("so.MeshFidForReload not null!");
            Dev::SetOffset(so, GetOffset("CPlugStaticObjectModel", "MeshFidForReload"), uint64(0));
        }
        if (so.ShapeFidForReload !is null) {
            // NotifyWarning("so.ShapeFidForReload not null!");
            Dev::SetOffset(so, GetOffset("CPlugStaticObjectModel", "ShapeFidForReload"), uint64(0));
        }
        ZeroFids(so.Mesh);
        MeshDuplication::SyncUserMatsToShapeIfMissing(so.Mesh, so.Shape);
        ZeroFids(so.Shape);
    }

    void ZeroFids(CPlugSolid2Model@ mesh) {
        ApplyMaterialMods(mesh);
        ZeroNodFid(mesh);
        FixMatsOnMesh(mesh);
        FixLightsOnMesh(mesh);
    }

    void ZeroFids(NPlugTrigger_SWaypoint@ wp) {
        // todo: check memory
        AlertIfFid(wp);
        ZeroNodFid(wp);
        ZeroFids(wp.TriggerShape);
    }

    void ZeroFids(NPlugTrigger_SSpecial@ wp) {
        // todo: check memory
        AlertIfFid(wp);
        ZeroNodFid(wp);
        ZeroFids(wp.TriggerShape);
    }

    void ZeroFids(CPlugFxSystem@ fxSys) {
        ZeroNodFid(fxSys);
        // if need by there are more under
        auto rootNode = cast<CPlugFxSystemNode_Parallel>(fxSys.RootNode);
        if (rootNode !is null) {
            auto pe = cast<CPlugFxSystemNode_ParticleEmitter>(rootNode.Children[0]);
            if (pe !is null) {
                // pe.Model has an Fid
                NotifyWarning("Todo, support CPlugFxSystemNode_ParticleEmitter");
                ZeroFids(pe.Model);
            }
        }
    }

    void ZeroFids(CPlugParticleEmitterModel@ pem) {
        ZeroNodFid(pem);
        // todo, more?
    }

    void ZeroFids(CPlugDynaObjectModel@ dynaObj) {
        trace('zeroing fids for CPlugDynaObjectModel');
        ZeroNodFid(dynaObj);
        if (dynaObj.Mesh !is null && dynaObj.DynaShape !is null)
            MeshDuplication::SyncUserMatsToShapeIfMissing(dynaObj.Mesh, dynaObj.DynaShape);
        if (dynaObj.DynaShape !is null)
            ZeroFids(dynaObj.DynaShape);
        if (dynaObj.StaticShape !is null)
            ZeroFids(dynaObj.StaticShape);
        if (dynaObj.Mesh !is null)
            ZeroFids(dynaObj.Mesh);
    }

    void ZeroFids(NPlugDyna_SKinematicConstraint@ kc) {
        trace('zeroing fids for NPlugDyna_SKinematicConstraint');
        ZeroNodFid(kc);
    }

    void ZeroFids(CPlugGameSkinAndFolder@ gsaf) {
        ZeroNodFid(gsaf);
        // ZeroNodFid(gsaf.Remapping);
        // trace('zeroing game skin and folder');
        // Dev::SetOffset(gsaf, GetOffset("CPlugGameSkinAndFolder", "RemapFolder"), uint64(0));
        // trace('done zeroing game skin and folder');
    }


    void ZeroFidsUnknownModelNod(CMwNod@ nod) {
        if (nod is null) return;
        auto itemModel = cast<CGameItemModel>(nod);
        auto so = cast<CPlugStaticObjectModel>(nod);
        auto prefab = cast<CPlugPrefab>(nod);
        auto fxSys = cast<CPlugFxSystem>(nod);
        auto vegetTree = cast<CPlugVegetTreeModel>(nod);
        auto dynaObject = cast<CPlugDynaObjectModel>(nod);
        auto kenematicConstraint = cast<NPlugDyna_SKinematicConstraint>(nod);
        auto spawnModel = cast<CPlugSpawnModel>(nod);
        auto editorHelper = cast<CPlugEditorHelper>(nod);
        auto sWaypoint = cast<NPlugTrigger_SWaypoint>(nod);
        auto sSpecial = cast<NPlugTrigger_SSpecial>(nod);
        auto commonIe = cast<CGameCommonItemEntityModel>(nod);
        if (so !is null) {
            ZeroFids(so);
        } else if (itemModel !is null) {
            ZeroChildFids(itemModel);
        } else if (prefab !is null) {
            ZeroFids(prefab);
        } else if (fxSys !is null) {
            ZeroFids(fxSys);
        } else if (vegetTree !is null) {
            ZeroFids(vegetTree);
        } else if (dynaObject !is null) {
            ZeroFids(dynaObject);
        } else if (kenematicConstraint !is null) {
            ZeroFids(kenematicConstraint);
        } else if (spawnModel !is null) {
            ZeroFids(spawnModel);
        } else if (editorHelper !is null) {
            ZeroFids(editorHelper);
        } else if (sWaypoint !is null) {
            ZeroFids(sWaypoint);
        } else if (sSpecial !is null) {
            ZeroFids(sSpecial);
        } else if (commonIe !is null) {
            ZeroFids(commonIe);
        } else {
            NotifyError("ZeroFidsUnknownModelNod: nod is unknown.");
            NotifyError("ZeroFidsUnknownModelNod: nod type: " + Reflection::TypeOf(nod).Name);
        }
    }

    void ZeroNodFid(CMwNod@ nod) {
        if (nod is null) return;
        auto fidPtr = Dev::GetOffsetUint64(nod, 0x8);
        if (fidPtr > 0) {
            Dev::SetOffset(nod, 0x8, uint64(0));
        }
    }

    void AlertIfFid(CMwNod@ nod) {
        auto fidPtr = Dev::GetOffsetUint64(nod, 0x8);
        if (fidPtr > 0) {
            NotifyWarning("Unexpected fid on nod.");
            NotifyWarning("Nod type: " + Reflection::TypeOf(nod).Name);
        }
    }


    void FixMatsOnMesh(CPlugSolid2Model@ mesh) {
        if (mesh is null) return;
        // auto bufferPtr = Dev::GetOffsetUint64(mesh, 0xC8);
        // auto nbAndSize = Dev::GetOffsetUint64(mesh, 0xC8 + 0x8);
        auto nbMats = Dev::GetOffsetUint32(mesh, 0xC8 + 0x8);
        auto alloc = Dev::GetOffsetUint32(mesh, 0xC8 + 0xC);
        auto matBufFakeNod = Dev::GetOffsetNod(mesh, 0xC8);

        auto nbUserMats = Dev::GetOffsetUint32(mesh, 0xF8 + 0x8);
        auto nbCustomMats = Dev::GetOffsetUint32(mesh, 0x1F8 + 0x8);
        auto allocCustomMats = Dev::GetOffsetUint32(mesh, 0x1F8 + 0xC);

        // auto bufStructPtr = Dev::GetOffsetUint64(mesh, 0x138);
        // auto bufStructLenSize = Dev::GetOffsetUint64(mesh, 0x138 + 0x8);

        // shouldn't need to set anything here for custom items...
        // if (nbMats == 0 || matBufFakeNod is null) {
        //     @matBufFakeNod = Dev::GetOffsetNod(mesh, 0x1f8);
        // }

        trace('s2m materials: nbMats / nbUserMats: ' + nbMats + ' / ' + nbUserMats);

        if (nbMats > alloc) {
            NotifyWarning('nbMats > alloc, though this may be because it is not a vanilla item (safe to ignore this warning if it is already custom)');
        // } else if (nbMats != staticObj.Shape.Materials.Length) {
        //     NotifyWarning('nbMats != staticObj.Shape.Materials.Length');
        } else if (nbMats > 0 && nbUserMats == 0) {
            // create a MwBuffer<CPlugMaterialUserInst> and set in the mesh
            trace('Creating custom materials');
            if (matBufFakeNod is null) {
                NotifyError("material buffer null?");
                return;
            }
            trace('Allocating buffer');
            // this is something like a buffer of a struct of 0x18 length. If you have 2 custom materials, then the pointer to the 2nd is at 0x18.
            // todo: check 3+ materials
            auto userMatBufPtr = RequestMemory(0x18 * nbMats);
            trace('Setting buffer pointer and size / alloc');
            Dev::SetOffset(mesh, 0xF8, userMatBufPtr);
            Dev::SetOffset(mesh, 0xF8 + 0x8, uint32(nbMats));
            Dev::SetOffset(mesh, 0xF8 + 0xC, uint32(nbMats));
            trace('Getting fake nod for user mat buffer');
            auto userMatBufFakeNod = Dev::GetOffsetNod(mesh, 0xF8);
            for (uint i = 0; i < nbMats; i++) {
                trace('Getting material ' + (i + 1));
                auto origMat = cast<CPlugMaterial>(Dev::GetOffsetNod(matBufFakeNod, i * 0x8));
                auto origMatName = GetMaterialName(origMat);
                trace('Creating user mat ' + origMatName);
                auto matUserInst = CPlugMaterialUserInst();
                matUserInst.MwAddRef();
                // maybe needs to be called TM_xxx_asset or thats just a blender thing or something -- don't think it matters tho
                matUserInst._Name = CreateMwIdWithName("m" + i);
                matUserInst._Link_OldCompat = CreateMwIdWithName(origMatName);
                matUserInst.Link = CreateMwIdWithName(origMatName);
                // plastic
                matUserInst.PhysicsID = 77;

                // crashes the game:
                // matUserInst.MaterialId = 0;
                // seems to break vanilla items (probs needs full path)
                // matUserInst._LinkFull = GetMaterialName(origMat);
                // trace('Setting user mat props ' + (i + 1) + " (_LinkFull: "+matUserInst._LinkFull+")");
                trace('Setting user mat ptr in buffer ' + (i + 1));
                Dev::SetOffset(userMatBufFakeNod, 0x18 * i, matUserInst);
            }
            trace('Populated custom materials buffer');
        }
        Dev::SetOffset(mesh, 0xE8, "Stadium\\Media\\Material\\");
    }


    MwId CreateMwIdWithName(const string &in name) {
        // auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto itemModel = CGameItemModel();
        auto initIdName = itemModel.IdName;
        itemModel.IdName = name;
        auto retMwIdValue = itemModel.Id.Value;
        itemModel.IdName = initIdName;
        return MwId(retMwIdValue);
    }

    string GetMaterialName(CPlugMaterial@ mat) {
        auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(mat, 0x8));
        if (fid is null) {
            NotifyWarning("Tried getting material name but it had no fid");
            ExploreNod('material no fid', mat);
            return "";
        }
        return string(fid.ShortFileName);
    }

    void FixLightsOnMesh(CPlugSolid2Model@ mesh) {
        if (mesh is null) return;
        auto lightBuffer = Dev::GetOffsetNod(mesh, 0x168);
        auto lightBufferCount = Dev::GetOffsetUint32(mesh, 0x168 + 0x8);
        trace('lights: zeroing fids for ' + lightBufferCount);
        if (lightBufferCount > 0 && lightBuffer !is null) {
            trace('light buffer not null');

            trace('allocating user lights');
            auto userLightBufPtr = RequestMemory(0x8 * lightBufferCount);
            Dev::SetOffset(mesh, 0x178, userLightBufPtr);
            Dev::SetOffset(mesh, 0x178 + 0x8, lightBufferCount);
            Dev::SetOffset(mesh, 0x178 + 0xC, lightBufferCount);
            trace('set and init buffer');

            for (uint i = 0; i < lightBufferCount; i++) {
                trace('light: ' + i);
                auto light = cast<CPlugLight>(Dev::GetOffsetNod(lightBuffer, 0x60 * i + 0x58));
                if (light is null) {
                    trace('light null!?');
                } else {
                    trace('clear fid');
                    // clear fid
                    ZeroNodFid(light);
                    // Dev::SetOffset(light, 0x8, uint64(0));
                    // zero m_BitmapProjector
                    trace('clear bitmap projector');
                    Dev::SetOffset(light, GetOffset("CPlugLight", "m_BitmapProjector"), uint64(0));
                        // zero light.m_GxLightModel.PlugLight
                    auto lm = light.m_GxLightModel;
                    auto lmAmb = cast<GxLightAmbient>(light.m_GxLightModel);
                    auto lm2 = lmAmb;
                    if (lm !is null && lm.PlugLight !is null) {
                        trace('clear light.m_GxLightModel.PlugLight');
                        Dev::SetOffset(lm, GetOffset("GxLight", "PlugLight"), uint64(0));
                    }
                }
                // this seems to not be required, but works except for moving itmes (just ignored in that case)
                if (true) {
                    auto userLightBufNod = Dev::GetOffsetNod(mesh, 0x178);
                    trace('got user light buf ptrnod');
                    auto userLight = CPlugLightUserModel();
                    userLight.Intensity = light.m_GxLightModel.Intensity;
                    userLight.Color = light.m_GxLightModel.Color;
                    Dev::SetOffset(userLightBufNod, 0x8 * i, userLight);
                    trace('created CPlugLightUserModel ' + i);
                }
            }

            trace('done lights');

            if (false) {
                // zero the lights array
                Dev::SetOffset(mesh, 0x168, uint64(0));
                Dev::SetOffset(mesh, 0x168 + 8, uint64(0));
            }
        }
    }

    void FixMatsOnShape(CPlugSurface@ shape) {
        if (shape is null) return;
        trace('updating surf mat ids and mats to mat ids');
        // possibly required for rotating
        if (shape.Materials.Length > 0) {
            shape.UpdateSurfMaterialIdsFromMaterialIndexs();
            shape.TransformMaterialsToMatIds();
            trace('done updating surf mat ids and mat to mat ids');
        }
    }

    void SyncUserMatsToShapeIfMissing(CPlugSolid2Model@ mesh, CPlugSurface@ shape) {
        if (shape is null) return;
        if (shape.MaterialIds.Length != 0 || shape.Materials.Length != 0) {
            return;
        }

        auto nbUserMats = Dev::GetOffsetUint32(mesh, 0xF8 + 0x8);
        auto nbCustomMats = Dev::GetOffsetUint32(mesh, 0x1F8 + 0x8);
        auto allocCustomMats = Dev::GetOffsetUint32(mesh, 0x1F8 + 0xC);
        auto customMatsBuf = Dev::GetOffsetNod(mesh, 0x1F8);
        // todo: mb check regular mats too at 0xc8
        if (nbUserMats == nbCustomMats && nbCustomMats <= allocCustomMats) {
            for (uint i = 0; i < nbCustomMats; i++) {
                CPlugMaterial@ mat = cast<CPlugMaterial>(Dev::GetOffsetNod(customMatsBuf, 0x8 * i));
                shape.Materials.Add(mat);
                if (mat !is null) {
                    mat.MwAddRef();
                }
            }
        }
    }

    void FixItemModelProperties(CGameItemModel@ dest, CGameItemModel@ source) {
        trace('setting skin pointer if exists');

        dest.WaypointType = source.WaypointType;

        // CPlugGameSkin
        auto skinPtr = Dev::GetOffsetUint64(source, 0xa0);
        auto skin = Dev::GetOffsetNod(source, 0xa0);
        if (skin !is null) {
            trace('setting skin');
            skin.MwAddRef();
            Dev::SetOffset(dest, 0xa0, skinPtr);
            dest.SkinDirNameCustom = dest.SkinDirectory;
        }

        // not sure if material modifiers are possible on custom items, cannot save
        // if (source.MaterialModifier !is null) {
        //     trace('mat modifier !is null, setting');
        //     source.MaterialModifier.MwAddRef();
        //     Dev::SetOffset(dest, GetOffset("CGameItemModel", "MaterialModifier"), source.MaterialModifier);
        //     ZeroFids(dest.MaterialModifier);
        // } else {
        //     trace('no mat modifier');
        // }

        // // we can't use material modifiers it seems
        // // so the solution is to interpret the modifications and apply those
        // if (source.MaterialModifier !is null) {
        //     auto mm = source.MaterialModifier;
        //     auto remapSkin = mm.Remapping;
        //     auto mods = mm.RemapFolder;
        //     if (mods !is null) {
        //         for (uint i = 0; i < mods.Leaves.Length; i++) {
        //             auto item = mods.Leaves[i];
        //         }
        //     } else {
        //         trace('mm.RemapFolder is null');
        //     }
        // }
    }

    bool enableReplaceMatsViaMatMod = false;

    void ApplyMaterialMods(CPlugSolid2Model@ mesh) {
        if (!enableReplaceMatsViaMatMod) return;
        if (matMod is null) return;
        // check materials
        trace('applying mat mods to mesh');
        auto matBufFakeNod = Dev::GetOffsetNod(mesh, 0xC8);
        auto nbMats = Dev::GetOffsetUint32(mesh, 0xC8 + 0x8);
        auto alloc = Dev::GetOffsetUint32(mesh, 0xC8 + 0xC);
        for (uint i = 0; i < Math::Min(nbMats, alloc); i++) {
            auto mat = cast<CPlugMaterial>(Dev::GetOffsetNod(matBufFakeNod, i * 0x8));
            auto fid = cast<CSystemFidFile>(Dev::GetOffsetNod(mat, 0x8));
            auto newMat = MatMod_FidToReplacement(fid);
            if (newMat !is null) {
                trace('applying setting new mat ['+i+']: ' + string(newMat.FileName));
                Dev::SetOffset(matBufFakeNod, i * 0x8, newMat.Nod);
                newMat.Nod.MwAddRef();
            }
        }
        trace('applied mat mods to mesh');
    }

    void ApplyMaterialMods(CPlugPrefab@ prefab) {
        if (!enableReplaceMatsViaMatMod) return;
        if (matMod is null) return;
        // check materials
        trace('applying mat mods to prefab');
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            if (prefab.Ents[i].ModelFid is null) continue;
            auto newFid = MatMod_FidToReplacement(prefab.Ents[i].ModelFid);
            if (newFid is null) continue;
            if (newFid !is null) {
                trace('applying setting new model to  Ents['+i+']: ' + string(newFid.FileName));
                SetEntRefModel(prefab, i, newFid.Nod);
            }
        }
        trace('applied mat mods to prefab');
    }

    CSystemFidFile@ MatMod_FidToReplacement(CSystemFidFile@ fid) {
        if (fid is null) return null;
        auto skin = matMod.Remapping;
        auto fidBuf = Dev::GetOffsetNod(skin, 0x58);
        auto fidBufC = Dev::GetOffsetUint32(skin, 0x58 + 0x8);
        auto strBuf = Dev::GetOffsetNod(skin, 0x68);
        string replacementName = "";
        for (uint i = 0; i < fidBufC; i++) {
            auto skinFid = cast<CSystemFidFile>(Dev::GetOffsetNod(fidBuf, 0x8 * i));
            if (skinFid !is null && string(fid.FileName) == string(skinFid.FileName)) {
                // found index
                replacementName = Dev::GetOffsetString(strBuf, 0x10 * i);
                break;
            }
        }
        if (replacementName.Length == 0) return null;
        for (uint i = 0; i < matMod.RemapFolder.Leaves.Length; i++) {
            auto remapFid = matMod.RemapFolder.Leaves[i];
            if (replacementName == string(remapFid.ShortFileName)) {
                if (remapFid.Nod is null) {
                    NotifyWarning("Material Modifiers found null fid nod: " + remapFid.FileName + ". Loading...");
                    Fids::Preload(remapFid);
                }
                return remapFid;
            }
        }
        return null;
    }
}



// namespace Editor {
//     void SetItemModelSkinDir(CGameItemModel@ model, const string &in skinDir) {
//         Dev::SetOffset(model, GetOffset("CGameItemModel", "SkinDirectory"), skinDir);
//     }
// }
