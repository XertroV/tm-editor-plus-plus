
namespace MeshDuplication {

    bool SafetyCheck(CGameItemModel@ model) {
        if (model.EntityModelEdition !is null) {
            NotifyWarning("Item's EntityModelEdition !is null. It's probably a crystal. Not sure what to do.");
            return false;
        }
        return true;
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
        for (uint i = 0; i < varList.Variants.Length; i++) {
            // todo: zero if need be
            if (varList.Variants[i].EntityModelFidForReload !is null) {
                NotifyWarning("varList.Variants["+i+"].EntityModelFidForReload !is null");
                // auto variants = Dev::GetOffsetNod(varList, GetOffset("NPlugItem_SVariantList", "Variants"));
                // NPlugItem_SVariant@ x;
                // Dev::SetOffset(varList.Variants[i], GetOffset("NPlugItem_SVariant", "EntityModelFidForReload"), uint64(0));
            }
            if (varList.Variants[i].EntityModel is null) continue;
            // ZeroFidsUnknownModelNod(varList.Variants[i].EntityModel);
            auto staticObj = cast<CPlugStaticObjectModel>(varList.Variants[i].EntityModel);
            auto prefab = cast<CPlugPrefab>(varList.Variants[i].EntityModel);
            if (staticObj !is null) {
                ZeroFids(staticObj);
            } else if (prefab !is null) {
                ZeroFids(prefab);
            } else {
                NotifyError("varList.Variants["+i+"].EntityModel is unknown.");
                NotifyError("varList.Variants["+i+"].EntityModel type: " + Reflection::TypeOf(varList.Variants[i].EntityModel).Name);
            }
        }
    }

    void ZeroFids(CPlugSurface@ surface) {
        AlertIfFid(surface);
        // don't zero material Fids
        return;
    }

    void ZeroFids(CPlugPrefab@ prefab) {
        ZeroNodFid(prefab);
        for (uint i = 0; i < prefab.Ents.Length; i++) {
            if (prefab.Ents[i].ModelFid !is null) {
                NotifyWarning("prefab.Ents["+i+"].ModelFid is not null!");
                // todo: zero if need be
                // @prefab.Ents[i].ModelFid = null;
            }
            ZeroFidsUnknownModelNod(prefab.Ents[i].Model);
        }
    }

    void ZeroFids(CPlugStaticObjectModel@ so) {
        AlertIfFid(so);
        // todo: MeshFidForReload / ShapeFidForReload if need be
        if (so.MeshFidForReload !is null) {
            NotifyWarning("so.MeshFidForReload not null!");
        }
        if (so.ShapeFidForReload !is null) {
            NotifyWarning("so.ShapeFidForReload not null!");
        }
        ZeroFids(so.Mesh);
        ZeroFids(so.Shape);
    }

    void ZeroFids(CPlugSolid2Model@ mesh) {
        AlertIfFid(mesh);

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
                    Dev::SetOffset(light, 0x8, uint64(0));
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

    void ZeroFidsUnknownModelNod(CMwNod@ nod) {
        if (nod is null) return;
        auto so = cast<CPlugStaticObjectModel>(nod);
        auto prefab = cast<CPlugPrefab>(nod);
        if (so !is null) {
            ZeroFids(so);
        } else if (prefab !is null) {
            ZeroFids(prefab);
        } else {
            NotifyError("ZeroFidsUnknownModelNod: nod is unknown.");
            NotifyError("ZeroFidsUnknownModelNod: nod type: " + Reflection::TypeOf(nod).Name);
        }
    }

    void ZeroNodFid(CMwNod@ nod) {
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
}
