class TerrainAffinityTab : Tab {
    TerrainAffinityTab(TabGroup@ parent) {
        super(parent, "Terrain Affinity", "");
    }

    TerrainAffinityTab(TabGroup@ parent, const string &in name, const string &in icon) {
        super(parent, name, icon);
    }

    CGameItemModel@ GetItemModel() {
        if (selectedItemModel is null) {
            return null;
        }
        return selectedItemModel.AsItemModel();
    }

    string missingItemError = "No item selcted.";

    void DrawInner() override {
        auto item = GetItemModel();
        if (item is null) {
            UI::Text(missingItemError);
            return;
        }
        auto varList = cast<NPlugItem_SVariantList>(item.EntityModel);
        if (varList is null) {
            UI::Text("Variant List is null.");
            return;
        }
        int[] variantsWithTags = {};
        for (uint i = 0; i < varList.Variants.Length; i++) {
            if (varList.Variants[i].Tags.Length > 0) {
                variantsWithTags.InsertLast(i);
            }
        }
        if (variantsWithTags.Length == 0) {
            UI::Text("No variants with placement tags");
            return;
        }

        UI::Text("Variants with placement tags: " + variantsWithTags.Length);

        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("Set variants' affinity to:");
        m_AffinityAll = DrawComboTerrainAffinity("Affinity", m_AffinityAll);
        if (UI::Button("Apply Affinity")) {
            OnClickApplyAffinity(varList, variantsWithTags);
        }
        UI::TextWrapped("Note: you may need to alter placement tag 0's 2nd value (typically 0, 1, 2, 4, or 15) if no terrain placements appear on hover.");

        UI::Separator();
        UI::AlignTextToFramePadding();
        UI::Text("Variant Placement Tags:");

        if (UI::CollapsingHeader("Guide")) {
        UI::Indent();
            UI::Markdown("""- Each placement tag has 2 numbers: (x, y).
- it appears that only variant's tags apply at any one time -- this might not be variant 0! (so check the others, too)
- `x` seems to be a kind of index / type, changing it will change the behavior of that placement tag.
- the `y` value's meaning depends on which tag it is
- tag 0.y seems to be some kind of pattern thing, and might need to be changed to get placements to appear on terrain. (typically 0-4 but other values like 15 (summer trees), 24 (flag), 25 (lamp), 26 (road sign), 27 (screen) have also been seen)
  - 0,8 -> can place on platform tech
- tag 1.y is related to the position in the pattern expressed by that entity
- tag 2.y seems to relate to patterns, changing it between 0 and 1 changes the type of layout on terrain
- tag 3.y is the terrain it is placed on: 0=grass, 1=dirt, 2=snow
            """);
        UI::Unindent();
        }

        for (uint i = 0; i < variantsWithTags.Length; i++) {
            // auto item = varList.Variants[variantsWithTags[i]];
            DrawEditableVariantListVariantTags(varList, variantsWithTags[i]);
        }

    }

    TerrainAffinity m_AffinityAll = TerrainAffinity::Grass;

    void OnClickApplyAffinity(NPlugItem_SVariantList@ varList, int[]@ ixs) {
        auto vars = Dev::GetOffsetNod(varList, GetOffset(varList, "Variants"));
        for (uint i = 0; i < ixs.Length; i++) {
            auto ix = ixs[i];
            if (varList.Variants[ix].Tags.Length != 4) {
                trace('skipping variant ' + ix + ' that does not have 4 tags');
                continue;
            }
            auto tagsPtr = Dev::GetOffsetUint64(vars, 0x28 * ix + GetOffset("NPlugItem_SVariant", "Tags"));
            Dev::Write(tagsPtr + 0x8 * 3 + 0x4, uint32(m_AffinityAll));
        }
    }

    void DrawEditableVariantListVariantTags(NPlugItem_SVariantList@ varList, uint i) {
        auto vars = Dev::GetOffsetNod(varList, GetOffset(varList, "Variants"));
        auto tagsPtr = Dev::GetOffsetUint64(vars, 0x28 * i + GetOffset("NPlugItem_SVariant", "Tags"));
        auto nbTags = varList.Variants[i].Tags.Length;
        if (UI::CollapsingHeader("Variant " + i + " Tags")) {
            UI::PushID("variant"+i+"tags");
            for (uint t = 0; t < nbTags; t++) {
                auto tag = Dev::ReadNat2(tagsPtr + 0x8 * t);
                Dev::Write(tagsPtr + 0x8 * t, UX::InputNat2("Tag " + t, tag));
                UI::SameLine();
                UI::Text(ItemPlace_StringConsts::LookupName(tag.x) + ":");
                UI::SameLine();
                UI::Text(ItemPlace_StringConsts::Lookup(tag));
            }
            UI::PopID();
        }
    }
}

enum TerrainAffinity {
    Grass = 0, Dirt = 1, Snow = 2
}


TerrainAffinity DrawComboTerrainAffinity(const string &in label, TerrainAffinity val) {
    return TerrainAffinity(
        DrawArbitraryEnum(label, int(val), 3, function(int v) {
            return tostring(TerrainAffinity(v));
        })
    );
}
