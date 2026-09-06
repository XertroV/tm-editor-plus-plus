#if DEV
namespace Tests {
    [Test]
    void PrefabParams_SPlacementOffsets(Tests::Context@ ctx) {
        ctx.AssertSame(uint(GetOffset("NPlugItemPlacement_SPlacement", "iLayout")), uint(0x00), "iLayout");
        ctx.AssertSame(uint(GetOffset("NPlugItemPlacement_SPlacement", "Options")), uint(0x08), "Options");
        auto ty = Reflection::GetType("NPlugItemPlacement_SPlacement");
        ctx.AssertTrue(ty !is null, "type");
        ctx.AssertSame(uint(ty.Size), uint(0x18), "SPlacement size");
        ctx.AssertSame(uint(ty.ID), CLSID_NPlugItemPlacement_SPlacement, "SPlacement class id");
    }

    [Test]
    void PrefabParams_SPrefabConstraintParamsOffsets(Tests::Context@ ctx) {
        ctx.AssertSame(uint(GetOffset("NPlugDyna_SPrefabConstraintParams", "Ent1")), uint(O_SPCP_Ent1), "Ent1");
        ctx.AssertSame(uint(GetOffset("NPlugDyna_SPrefabConstraintParams", "Ent2")), uint(O_SPCP_Ent2), "Ent2");
        ctx.AssertSame(uint(GetOffset("NPlugDyna_SPrefabConstraintParams", "Pos1")), uint(O_SPCP_Pos1), "Pos1");
        ctx.AssertSame(uint(GetOffset("NPlugDyna_SPrefabConstraintParams", "Pos2")), uint(O_SPCP_Pos2), "Pos2");
        auto ty = Reflection::GetType("NPlugDyna_SPrefabConstraintParams");
        ctx.AssertTrue(ty !is null, "type");
        ctx.AssertSame(uint(ty.Size), uint(0x20), "size 32");
        ctx.AssertSame(uint(ty.ID), uint(0x2F0C8000), "class id");
    }

    [Test]
    void PrefabParams_SPlacementGroupAndStaticInst(Tests::Context@ ctx) {
        ctx.AssertSame(uint(GetOffset("NPlugItemPlacement_SPlacementGroup", "Placements")), uint(O_SPG_Placements), "Placements");
        auto pg = Reflection::GetType("NPlugItemPlacement_SPlacementGroup");
        ctx.AssertTrue(pg !is null, "SPlacementGroup type");
        ctx.AssertSame(uint(pg.Size), uint(0x40), "SPlacementGroup size 64");
        ctx.AssertSame(uint(pg.ID), uint(0x2F0D8000), "SPlacementGroup class id");

        ctx.AssertSame(uint(GetOffset("NPlugStaticObjectModel_SInstanceParams", "Phase01")), uint(0), "static Phase01");
        auto st = Reflection::GetType("NPlugStaticObjectModel_SInstanceParams");
        ctx.AssertTrue(st !is null, "static inst type");
        ctx.AssertSame(uint(st.Size), uint(0x04), "static inst size 4");
        ctx.AssertSame(uint(st.ID), uint(0x2F0D9000), "static inst class id");
    }

    [Test]
    void PrefabParams_UnknownNameHeuristics(Tests::Context@ ctx) {
        ctx.AssertTrue(PrefabParams_NameLooksLikeBuffer("Options"), "Options");
        ctx.AssertTrue(PrefabParams_NameLooksLikeBuffer("Placements"), "Placements");
        ctx.AssertTrue(PrefabParams_NameLooksLikeBuffer("RequiredTags"), "Tags");
        ctx.AssertFalse(PrefabParams_NameLooksLikeBuffer("Ent1"), "Ent1");
        ctx.AssertTrue(PrefabParams_NameLooksLikeBool("IsKinematic"), "IsKinematic");
        ctx.AssertTrue(PrefabParams_NameLooksLikeBool("CastStaticShadow"), "CastStaticShadow");
        ctx.AssertFalse(PrefabParams_NameLooksLikeBool("Phase01"), "Phase01");
    }

    [Test]
    void ItemBrowser_ItemModelEditableOnlyWhenRequested(Tests::Context@ ctx) {
        auto item = CGameItemModel();
        ctx.AssertTrue(item !is null, "item");
        auto mapView = ItemModel(item);
        ctx.AssertTrue(!mapView.isEditable, "map Model Browser default");
        auto ieView = ItemModel(item, true, true);
        ctx.AssertTrue(ieView.isEditable, "IE Model Browser");
    }

    [Test]
    void ItemBrowser_EntNllTreeTitle_DefaultsAreBare(Tests::Context@ ctx) {
        auto t = ItemBrowser_EntNllTreeTitle("", quat(0, 0, 0, 1), vec3(0), -1);
        ctx.AssertSame(t, "Name/Location/LodGroupId \\$888\\$i all defaults");
        ctx.AssertTrue(ItemBrowser_QuatIsDefault(quat(0, 0, 0, 1)), "xyzw identity");
        ctx.AssertTrue(ItemBrowser_QuatIsDefault(quat(vec3(0))), "euler zero quat");
        ctx.AssertTrue(ItemBrowser_QuatIsDefault(quat(0, 0, 0, -1)), "negative w same rot");
    }

    [Test]
    void ItemBrowser_EntNllTreeTitle_ListsNonDefaults(Tests::Context@ ctx) {
        auto t = ItemBrowser_EntNllTreeTitle("foo", quat(0, 0, 0, 1), vec3(1, 2, 3), 0);
        ctx.AssertTrue(t.StartsWith("Name/Location/LodGroupId"), "prefix");
        ctx.AssertTrue(t.Contains("Name=\"foo\""), "name");
        ctx.AssertTrue(t.Contains("Trans="), "trans");
        ctx.AssertTrue(t.Contains("LodGroupId=0"), "lod");
        ctx.AssertTrue(!t.Contains("Quat="), "zero-euler quat omitted");
        ctx.AssertTrue(!t.Contains("all defaults"), "not all-default");
    }

    [Test]
    void ItemBrowser_QuatIsDefault_OnlyZeroEuler(Tests::Context@ ctx) {
        ctx.AssertTrue(!ItemBrowser_QuatIsDefault(quat(0, 0, 0.7071, 0.7071)), "90 deg yaw");
        auto qX = quat(1, 0, 0, 0);
        auto e = qX.Euler();
        bool zeroE = Math::Abs(e.x) < 1e-4 && Math::Abs(e.y) < 1e-4 && Math::Abs(e.z) < 1e-4;
        ctx.AssertTrue(ItemBrowser_QuatIsDefault(qX) == zeroE, "quat(1,0,0,0) matches euler-zero only");
    }

    [Test]
    void ItemBrowser_EntNllTreeTitle_UnnormalizedQuatShows(Tests::Context@ ctx) {
        auto t = ItemBrowser_EntNllTreeTitle("", quat(1, 0.2, 0, 0), vec3(0), -1);
        ctx.AssertTrue(t.Contains("Quat="), "component change is not identity");
    }

    [Test]
    void ItemBrowser_EntNllTreeTitle_NonIdentityQuat(Tests::Context@ ctx) {
        auto t = ItemBrowser_EntNllTreeTitle("", quat(0, 0, 0.7071, 0.7071), vec3(0), -1);
        ctx.AssertTrue(t.Contains("Quat="), "quat");
        ctx.AssertTrue(!t.Contains("Trans="), "zero trans omitted");
        ctx.AssertTrue(!t.Contains("LodGroupId="), "default lod omitted");
    }

    [Test]
    void ItemBrowser_ShaderTcAnimFuncTreeTitle_TypeAlwaysAndNbIfNotOne(Tests::Context@ ctx) {
        auto none = ItemBrowser_ShaderTcAnimFuncTreeTitle(NPlugDyna::EShaderTcType::None, 0, 1, 1, 1);
        ctx.AssertSame(none, "ShaderTcAnimFunc (0) None");
        auto t = ItemBrowser_ShaderTcAnimFuncTreeTitle(NPlugDyna::EShaderTcType::TransSubTexture, 3, 4, 1, 2);
        ctx.AssertTrue(t.Contains("ShaderTcAnimFunc (3)"), "len");
        ctx.AssertTrue(t.Contains("TransSubTexture"), "type");
        ctx.AssertTrue(t.Contains("NbSubTexture=4"), "nb");
        ctx.AssertTrue(!t.Contains("NbSubTexturePerLine"), "perLine default");
        ctx.AssertTrue(t.Contains("NbSubTexturePerColumn=2"), "perCol");
    }

    [Test]
    void ItemBrowser_NamedChildTreeFlags_StaticShapeClosed(Tests::Context@ ctx) {
        ctx.AssertTrue(ItemBrowser_NamedChildTreeFlags("StaticShape") == TREE_F_NONE, "StaticShape closed");
        ctx.AssertTrue(ItemBrowser_NamedChildTreeFlags("DynaShape") == DEFAULT_OPEN, "DynaShape default");
        ctx.AssertTrue(ItemBrowser_NamedChildTreeFlags("Mesh") == DEFAULT_OPEN, "Mesh default");
        ctx.AssertTrue(ItemBrowser_NamedChildTreeFlags("Shape") == DEFAULT_OPEN, "static Shape default");
    }

    [Test]
    void ItemBrowser_ApplyEntLocRot_QuatWinsOverEuler(Tests::Context@ ctx) {
        quat qOut;
        bool lastWasQuat = false;
        ItemBrowser_ApplyEntLocRot(qOut, lastWasQuat, quat(1, 0, 0, 0), quat(1, 0.25, 0, 0), vec3(0), vec3(0, 1, 0), false);
        ctx.AssertTrue(lastWasQuat, "quat source");
        ctx.AssertTrue(ItemBrowser_QuatComponentsClose(qOut, quat(1, 0.25, 0, 0)), "kept quat edit");
    }

    [Test]
    void ItemBrowser_ApplyEntLocRot_EulerWhenQuatUnchanged(Tests::Context@ ctx) {
        quat qOut;
        bool lastWasQuat = true;
        vec3 euler = vec3(0, Math::PI * 0.5, 0);
        ItemBrowser_ApplyEntLocRot(qOut, lastWasQuat, quat(1, 0, 0, 0), quat(1, 0, 0, 0), vec3(0), euler, true);
        ctx.AssertTrue(!lastWasQuat, "euler source");
        ctx.AssertTrue(ItemBrowser_QuatComponentsClose(qOut, quat(euler)), "quat from euler");
    }

    [Test]
    void ItemBrowser_ApplyEntLocRot_NoEditKeepsSource(Tests::Context@ ctx) {
        quat qOut;
        bool lastWasQuat = false;
        ItemBrowser_ApplyEntLocRot(qOut, lastWasQuat, quat(1, 0, 0, 0), quat(1, 0, 0, 0), vec3(0), vec3(0), false);
        ctx.AssertTrue(!lastWasQuat, "source unchanged");
        ctx.AssertTrue(ItemBrowser_QuatComponentsClose(qOut, quat(1, 0, 0, 0)), "quat unchanged");
    }

    [Test]
    void ItemBrowser_SInstParamsTags_EmptyWhenDefaults(Tests::Context@ ctx) {
        ctx.AssertSame(ItemBrowser_SInstParamsTags(false, false, 0, 0, 0, 0, 0), "");
    }

    [Test]
    void ItemBrowser_SInstParamsTags_KAndSOnlyWhenSet(Tests::Context@ ctx) {
        auto k = ItemBrowser_SInstParamsTags(true, false, 0, 0, 0, 0, 0);
        ctx.AssertTrue(k.Contains("[K]"), "K");
        ctx.AssertTrue(!k.Contains("[S]"), "no S");
        auto both = ItemBrowser_SInstParamsTags(true, true, 0, 0, 0, 0, 0);
        ctx.AssertTrue(both.Contains("[K]"), "K both");
        ctx.AssertTrue(both.Contains("[S]"), "S both");
    }

    [Test]
    void ItemBrowser_SInstParamsTags_TexturePeriodPhase(Tests::Context@ ctx) {
        auto t = ItemBrowser_SInstParamsTags(false, false, 3, 0, 0, 0, 0);
        ctx.AssertTrue(t.Contains("[T3]"), "texture id");
        auto pe = ItemBrowser_SInstParamsTags(false, false, 0, 1, 0, 0, 0);
        ctx.AssertTrue(pe.Contains("[Pe]"), "period");
        auto ph = ItemBrowser_SInstParamsTags(false, false, 0, 0, 0, 0.5, 0);
        ctx.AssertTrue(ph.Contains("[Ph]"), "phase");
    }

    [Test]
    void ItemBrowser_SPrefabConstraintParamsTags_TargetAndParent(Tests::Context@ ctx) {
        auto t = ItemBrowser_SPrefabConstraintParamsTags(-1, 2);
        ctx.AssertTrue(t.Contains("[T2]"), "target");
        ctx.AssertTrue(t.Contains("[P-1]"), "no parent");
        auto p = ItemBrowser_SPrefabConstraintParamsTags(0, 1);
        ctx.AssertTrue(p.Contains("[T1]"), "target 1");
        ctx.AssertTrue(p.Contains("[P0]"), "parent 0");
    }

    [Test]
    void ItemBrowser_ParamsTreeTitle_TagsThenShortType(Tests::Context@ ctx) {
        auto t = ItemBrowser_ParamsTreeTitle("\\$0f8[K]", "SInstanceParams");
        ctx.AssertTrue(t.Contains("Params"), "prefix");
        ctx.AssertTrue(t.Contains("[K]"), "tags");
        ctx.AssertTrue(t.Contains("SInstanceParams"), "type");
        ctx.AssertSame(ItemBrowser_ParamsShortType(0x2f0b6000, ""), "SInstanceParams");
        ctx.AssertSame(ItemBrowser_ParamsShortType(0x2f0c8000, ""), "SPrefabConstraintParams");
    }

    [Test]
    void ItemBrowser_IsKinematicDynaCandidate_OnlyKinDynaWithSInst(Tests::Context@ ctx) {
        auto dyna = CPlugDynaObjectModel();
        auto prefab = CPlugPrefab();
        auto kc = NPlugDyna_SKinematicConstraint();
        ctx.AssertTrue(ItemBrowser_IsKinematicDynaCandidate(dyna, 0x2f0b6000, true), "kin dyna");
        ctx.AssertTrue(!ItemBrowser_IsKinematicDynaCandidate(dyna, 0x2f0b6000, false), "non-kin");
        ctx.AssertTrue(!ItemBrowser_IsKinematicDynaCandidate(dyna, 0x2f0c8000, true), "wrong params");
        ctx.AssertTrue(!ItemBrowser_IsKinematicDynaCandidate(prefab, 0x2f0b6000, true), "nested prefab");
        ctx.AssertTrue(!ItemBrowser_IsKinematicDynaCandidate(kc, 0x2f0c8000, true), "kc");
    }

    [Test]
    void ItemBrowser_KinDynaMap_IndexesFilteredListNotRawEnts(Tests::Context@ ctx) {
        auto root = CPlugPrefab();
        auto inner = CPlugPrefab();
        auto map = ItemBrowser_KinDynaMap();
        @map.root = root;
        map.Add(inner, 0);
        map.Add(root, 3);
        ctx.AssertTrue(map.IxForEnt(inner, 0) == 0, "first kin is nested ent 0");
        ctx.AssertTrue(map.IxForEnt(root, 3) == 1, "second kin is root ent 3");
        ctx.AssertTrue(map.IxForEnt(root, 0) == -1, "raw Ents[0] is not kin#0");
        ctx.AssertTrue(map.IxForEnt(root, 1) == -1, "unlisted");
    }

    [Test]
    void ItemBrowser_KinDynaLabelExtra_HoverTint(Tests::Context@ ctx) {
        ctx.AssertSame(ItemBrowser_KinDynaLabelExtra(-1, 0), "");
        auto idle = ItemBrowser_KinDynaLabelExtra(1, 0);
        ctx.AssertTrue(idle.Contains("[kin#1]"), "idle tag");
        ctx.AssertTrue(idle.Contains("\\$888"), "idle gray");
        auto hov = ItemBrowser_KinDynaLabelExtra(1, 1);
        ctx.AssertTrue(hov.Contains("[kin#1]"), "label stable on hover");
        ctx.AssertTrue(hov.Contains("\\$888"), "no color churn");
        ctx.AssertTrue(ItemBrowser_KinDynaTreeFlags(1, 1) != DEFAULT_OPEN, "selected on hover");
        ctx.AssertTrue(ItemBrowser_KinDynaTreeFlags(1, 0) == DEFAULT_OPEN, "not selected");
        ctx.AssertTrue(ItemBrowser_KinDynaTreeFlags(-1, -1) == DEFAULT_OPEN, "no kin not selected");
    }
}
#endif
