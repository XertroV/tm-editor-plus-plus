#if SIG_DEVELOPER

class DevMainTab : Tab {
    bool drawStuff = false;

    DevMainTab(TabGroup@ p) {
        super(p, "Dev Info", Icons::ExclamationTriangle);
        canPopOut = false;
        DevBlockTab(Children);
        DevBlockTab(Children, true);
        DevItemsTab(Children);
    }

    void DrawInner() override {
        drawStuff = UI::Checkbox("Enable Dev Info", drawStuff);
        if (!drawStuff) return;

        Children.DrawTabs();
        return;
    }
}



class DevItemsTab : Tab {
    DevItemsTab(TabGroup@ p) {
        super(p, "Items (Dev)", Icons::Tree);
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    bool autoscroll = false;
    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;

        UI::AlignTextToFramePadding();
        UI::Text("Total: " + map.AnchoredObjects.Length + "   |");
        UI::SameLine();

        autoscroll = UI::Checkbox("Autoscroll", autoscroll);

        DrawColumnHeadersOnlyTable();
        if (UI::BeginTable("dev items list", nbCols, UI::TableFlags::SizingStretchProp | UI::TableFlags::ScrollY)) {
            SetupMainTableColumns();
            // UI::TableHeadersRow();

            if (autoscroll) {
                UI::SetScrollY(UI::GetScrollMaxY());
            }
            UI::ListClipper clip(map.AnchoredObjects.Length);
            while (clip.Step()) {
                for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    DrawDevItemInfo(i, map.AnchoredObjects[i]);
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
    }

    void DrawColumnHeadersOnlyTable() {
        if (UI::BeginTable("dev-items-headings", nbCols, UI::TableFlags::None)) {
            SetupMainTableColumns(true);
            UI::TableHeadersRow();
            UI::EndTable();
        }
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) {
        float bigNumberColWidth = 90;
        float smlNumberColWidth = 65;
        float exploreColWidth = smlNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        UI::TableSetupColumn("Nod ID", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Save ID", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Block ID", UI::TableColumnFlags::WidthFixed, bigNumberColWidth);
        UI::TableSetupColumn("Ref Count", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Explore", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    private int nbCols = 7;
    void DrawDevItemInfo(int i, CGameCtnAnchoredObject@ item) {
        auto blockId = Editor::GetItemUniqueBlockID(item);
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetItemUniqueNodID(item)));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetItemUniqueSaveID(item)));

        UI::TableNextColumn();
        UI::Text(tostring(blockId));

        UI::TableNextColumn();
        UI::Text(tostring(Reflection::GetRefCount(item)));

        UI::TableNextColumn();
        UI::Text(item.ItemModel.IdName);

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Cube + "##" + blockId)) {
            ExploreNod("Item " + blockId + ".", item);
        }
    }
}

class DevBlockTab : Tab {
    bool useBakedBlocks = false;
    DevBlockTab(TabGroup@ p, bool baked = false) {
        super(p, baked ? "Baked Blocks (Dev)" : "Blocks (Dev)", Icons::Cube);
        useBakedBlocks = baked;
        RegisterOnEditorLoadCallback(CoroutineFunc(OnEditorLoad));
    }

    bool recheckSkip = true;
    void OnEditorLoad() {
        recheckSkip = true;
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    int GetNbBlocks(CGameCtnChallenge@ map) {
        if (useBakedBlocks) {
            return map.BakedBlocks.Length;
        }
        return map.Blocks.Length;
    }

    CGameCtnBlock@ GetBlock(CGameCtnChallenge@ map, uint i) {
        if (i >= GetNbBlocks(map)) {
            return null;
        }
        if (useBakedBlocks) {
            return map.BakedBlocks[i];
        }
        return map.Blocks[i];
    }

    bool autoscroll = false;
    bool skipXZStarting = true;
    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto sizeXZ = map.Size.x * map.Size.z - 4;
        auto nbBlocks = GetNbBlocks(map);
        uint nbBlocksToSkip = Math::Min(nbBlocks - 4, sizeXZ);

        UI::AlignTextToFramePadding();
        UI::Text("Total: " + nbBlocks + "   |");
        UI::SameLine();

        autoscroll = UI::Checkbox("Autoscroll", autoscroll);
        UI::SameLine();

        if (recheckSkip) {
            recheckSkip = false;
            skipXZStarting = GetBlock(map, 0).DescId.GetName() == "Grass";
        }
        skipXZStarting = UI::Checkbox("Skip first " + sizeXZ + " blocks", skipXZStarting);
        if (!skipXZStarting) {
            nbBlocksToSkip = 0;
        }

        uint nbBlocksToDraw = nbBlocks - nbBlocksToSkip;

        DrawColumnHeadersOnlyTable();
        if (UI::BeginTable("dev blocks list|bb:"+tostring(useBakedBlocks), nbCols, UI::TableFlags::ScrollY)) {
            SetupMainTableColumns();
            // UI::TableHeadersRow();

            if (autoscroll) {
                UI::SetScrollY(UI::GetScrollMaxY());
            }
            UI::ListClipper clip(nbBlocksToDraw);
            while (clip.Step()) {
                for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    DrawDevBlockInfo(nbBlocksToSkip + i, GetBlock(map, nbBlocksToSkip + i));
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
    }

    void DrawColumnHeadersOnlyTable() {
        if (UI::BeginTable("dev-blocks-headings", nbCols, UI::TableFlags::None)) {
            SetupMainTableColumns(true);
            UI::TableHeadersRow();
            UI::EndTable();
        }
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) {
        float numberColWidth = 90;
        float smlNumberColWidth = 70;
        float exploreColWidth = smlNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        UI::TableSetupColumn(".Blocks Ix", UI::TableColumnFlags::WidthFixed, numberColWidth);
        UI::TableSetupColumn("Save ID", UI::TableColumnFlags::WidthFixed, numberColWidth);
        UI::TableSetupColumn("Block ID", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Block MwId", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Placed Ix", UI::TableColumnFlags::WidthFixed, numberColWidth);
        UI::TableSetupColumn("Ref Count", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Explore", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    private int nbCols = 9;
    void DrawDevBlockInfo(int i, CGameCtnBlock@ block) {
        auto blockId = Editor::GetBlockUniqueID(block);
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(i));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockMapBlocksIndex(block)));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockUniqueSaveID(block)));

        UI::TableNextColumn();
        UI::Text(tostring(blockId));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockMwIDRaw(block)));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetBlockPlacedCountIndex(block)));

        UI::TableNextColumn();
        UI::Text(tostring(Reflection::GetRefCount(block)));

        UI::TableNextColumn();
        UI::Text(block.DescId.GetName());

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Cube + "##" + blockId)) {
            ExploreNod("Block " + blockId + ".", block);
        }
    }
}


#endif
