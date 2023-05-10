
class BlockVariantBrowserTab : Tab {
    BlockVariantBrowserTab(TabGroup@ p) {
        super(p, "Block Info/Variants Browser", "");
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    // void OnNewSelectedBlock()

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        if (!Editor::IsInBlockPlacementMode(editor, false)) {
            UI::Text("Enter block placement mode");
            return;
        }

        auto bi = Editor::GetSelectedBlockInfo(editor);

        if (bi is null) {
            UI::Text("Select a block");
            return;
        }

        UI::AlignTextToFramePadding();
        LabeledValue("Currently Selected", bi.IdName);

#if SIG_DEVELOPER
        UI::SameLine();
        if (UI::Button(Icons::Cube + " Explore BlockInfo")) {
            ExploreNod(bi);
        }
#endif

        if (UI::CollapsingHeader("Legend##block-variants")) {
            UI::Text("VG: Variant Ground");
            UI::Text("VA: Variant Air");
            UI::Text("VBG: Variant Base Ground");
            UI::Text("VBA: Variant Base Air");
            UI::Text("AVG#: Additional Variant Ground (numbered)");
            UI::Text("AVA#: Additional Variant Air (numbered)");
        }

        UI::BeginTabBar("block variants");
        DrawBlockInfoTab("BlockInfo", bi);
        DrawVariantTab("BVG", bi.VariantBaseGround, true);
        DrawVariantTab("BVA", bi.VariantBaseAir, false);
        DrawVariantTab("VG", bi.VariantGround, true);
        DrawVariantTab("VA", bi.VariantAir, false);
        DrawAdditionalVariantsTabs("AVG", bi, true);
        DrawAdditionalVariantsTabs("AVA", bi, false);
        UI::EndTabBar();
    }

    void DrawBlockInfoTab(const string &in tabName, CGameCtnBlockInfo@ bi) {
        if (UI::BeginTabItem(tabName)) {
            DrawBlockInfoInfo(bi);
            UI::EndTabItem();
        }
    }

    void DrawVariantTab(const string &in tabName, CGameCtnBlockInfoVariant@ variant, bool isGroundElseAir) {
        UI::BeginDisabled(variant is null);
        if (UI::BeginTabItem(tabName)) {
            DrawVariantInfo(variant, isGroundElseAir);
            UI::EndTabItem();
        }
        UI::EndDisabled();
    }

    uint GetNbAdditionalVariants(CGameCtnBlockInfo@ bi, bool isGroundElseAir) {
        return isGroundElseAir
            ? bi.AdditionalVariantsGround.Length
            : bi.AdditionalVariantsAir.Length;
    }

    CGameCtnBlockInfoVariant@ GetAdditionalVariant(CGameCtnBlockInfo@ bi, bool isGroundElseAir, uint ix) {
        if (ix >= GetNbAdditionalVariants(bi, isGroundElseAir))
            return null;
        return isGroundElseAir
            ? cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsGround[ix])
            : cast<CGameCtnBlockInfoVariant>(bi.AdditionalVariantsAir[ix]);
    }

    void DrawAdditionalVariantsTabs(const string &in tabName, CGameCtnBlockInfo@ bi, bool isGroundElseAir) {
        auto nbVars = GetNbAdditionalVariants(bi, isGroundElseAir);
        for (uint i = 0; i < nbVars; i++) {
            DrawVariantTab(tabName + "#" + i, GetAdditionalVariant(bi, isGroundElseAir, i), isGroundElseAir);
        }
    }

    void DrawBlockInfoInfo(CGameCtnBlockInfo@ bi) {
        bi.IsPillar = UI::Checkbox("IsPillar", bi.IsPillar);
        bi.IsMultiHeightPillarOrVFC = UI::Checkbox("IsMultiHeightPillarOrVFC", bi.IsMultiHeightPillarOrVFC);
        bi.EdNoRespawn = UI::Checkbox("EdNoRespawn", bi.EdNoRespawn);
        bi.EdWaypointType = DrawComboEWayPointType("EdWaypointType", bi.EdWaypointType);
        // bi.Name = UI::Checkbox("Name", bi.Name);
        // bi.Name = UI::Checkbox("Name", bi.Name);
        // bi.Name = UI::Checkbox("Name", bi.Name);

        bi.PillarShapeMultiDir = DrawComboEMultiDirEnum("PillarShapeMultiDir", bi.PillarShapeMultiDir);
    }

    bool enableVariantOptions = false;
    void DrawVariantInfo(CGameCtnBlockInfoVariant@ variant, bool isGroundElseAir) {
        UI::TextWrapped("\\$f80Warning:\\$z These are reset when the game starts, and editing properties here has *unknown consequences*. You might be able to do new things, though. Caveat Emptor.");
        if (variant is null) {
            UI::Text("Variant is null.");
            return;
        }
        enableVariantOptions = UI::Checkbox("Enable Editing Variant Options", enableVariantOptions);
        UI::Separator();
        UI::BeginDisabled(!enableVariantOptions);

        UI::Columns(2);

        LabeledValue("Size", variant.Size, true);
        LabeledValue("OffsetBoundingBoxMin", variant.OffsetBoundingBoxMin, true);
        LabeledValue("OffsetBoundingBoxMax", variant.OffsetBoundingBoxMax, true);

        variant.AutoChangeVariantOff = UI::Checkbox("AutoChangeVariantOff", variant.AutoChangeVariantOff);
        variant.HasManualSymmetryD1 = UI::Checkbox("HasManualSymmetryD1", variant.HasManualSymmetryD1);
        variant.HasManualSymmetryD2 = UI::Checkbox("HasManualSymmetryD2", variant.HasManualSymmetryD2);
        variant.HasManualSymmetryH = UI::Checkbox("HasManualSymmetryH", variant.HasManualSymmetryH);
        variant.HasManualSymmetryV = UI::Checkbox("HasManualSymmetryV", variant.HasManualSymmetryV);
        variant.IsFakeReplacement = UI::Checkbox("IsFakeReplacement", variant.IsFakeReplacement);
        variant.IsNoPillarBelowVariant = UI::Checkbox("IsNoPillarBelowVariant", variant.IsNoPillarBelowVariant);
        variant.IsObsoleteVariant = UI::Checkbox("IsObsoleteVariant", variant.IsObsoleteVariant);

        UI::NextColumn();

        LabeledValue("HasFreeClips", variant.HasFreeClips);
        LabeledValue("HasVolumeSymmetryD1", variant.HasVolumeSymmetryD1);
        LabeledValue("HasVolumeSymmetryD2", variant.HasVolumeSymmetryD2);
        LabeledValue("HasVolumeSymmetryH", variant.HasVolumeSymmetryH);
        LabeledValue("HasVolumeSymmetryV", variant.HasVolumeSymmetryV);
        LabeledValue("IsAllUnderground", variant.IsAllUnderground);
        LabeledValue("IsPartUnderground", variant.IsPartUnderground);
        LabeledValue("ReplacedPillarBlockInfo_List.Length", variant.ReplacedPillarBlockInfo_List.Length);
        LabeledValue("ReplacedPillarOffset2D_List.Length", variant.ReplacedPillarOffset2D_List.Length);
        LabeledValue("ReplacedPillarMultiDir_List.Length", variant.ReplacedPillarMultiDir_List.Length);
        LabeledValue("ReplacedPillarIsOnFlyingBase_List.Length", variant.ReplacedPillarIsOnFlyingBase_List.Length);
        LabeledValue("IsNewPillarPlacedBelow_List.Length", variant.IsNewPillarPlacedBelow_List.Length);
        LabeledValue("PlacedPillarBlockInfo_List.Length", variant.PlacedPillarBlockInfo_List.Length);
        LabeledValue("PlacedPillarOffset_List.Length", variant.PlacedPillarOffset_List.Length);
        LabeledValue("PlacedPillarDir_List.Length", variant.PlacedPillarDir_List.Length);

        UI::Columns(1);

        auto vGround = cast<CGameCtnBlockInfoVariantGround>(variant);
        auto vAir = cast<CGameCtnBlockInfoVariantAir>(variant);

        if (vGround !is null) {
            UI::Separator();
            UI::Text("Ground variant properites:");
            vGround.AutoTerrainWithFrontiers = UI::Checkbox("AutoTerrainWithFrontiers", vGround.AutoTerrainWithFrontiers);
            vGround.AutoTerrainHeightOffset = UI::InputInt("AutoTerrainHeightOffset", vGround.AutoTerrainHeightOffset);
            vGround.AutoTerrainPlaceType = DrawComboEnumAutoTerrainPlaceType("AutoTerrainPlaceType", vGround.AutoTerrainPlaceType);
        }

        UI::EndDisabled();
    }
}
