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
        autoscroll = UI::Checkbox("Autoscroll", autoscroll);
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;

        if (UI::BeginTable("dev items list", nbCols, UI::TableFlags::SizingStretchProp | UI::TableFlags::ScrollY)) {
            SetupMainTableColumns();
            UI::TableHeadersRow();

            if (autoscroll) {
                UI::SetScrollY(UI::GetScrollMaxY());
            }
            UI::ListClipper clip(map.AnchoredObjects.Length);
            while (clip.Step()) {
                for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    DrawDevItemInfo(map.AnchoredObjects[i]);
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
    }

    void SetupMainTableColumns() {
        UI::TableSetupColumn("Nod ID");
        UI::TableSetupColumn("Save ID", UI::TableColumnFlags::WidthFixed, 90.);
        UI::TableSetupColumn("Block ID");
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Ref Count");
        UI::TableSetupColumn("Explore");
    }

    private int nbCols = 6;
    void DrawDevItemInfo(CGameCtnAnchoredObject@ item) {
        auto blockId = Editor::GetItemUniqueBlockID(item);
        UI::TableNextRow();

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetItemUniqueNodID(item)));

        UI::TableNextColumn();
        UI::Text(tostring(Editor::GetItemUniqueSaveID(item)));

        UI::TableNextColumn();
        UI::Text(tostring(blockId));

        UI::TableNextColumn();
        UI::Text(item.ItemModel.IdName);

        UI::TableNextColumn();
        UI::Text(tostring(Reflection::GetRefCount(item)));

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
        autoscroll = UI::Checkbox("Autoscroll", autoscroll);
        UI::SameLine();

        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto sizeXZ = map.Size.x * map.Size.z - 4;
        uint nbBlocksToSkip = Math::Min(GetNbBlocks(map) - 4, sizeXZ);

        skipXZStarting = UI::Checkbox("Skip first " + sizeXZ + " blocks", skipXZStarting);
        if (!skipXZStarting) {
            nbBlocksToSkip = 0;
        }

        uint nbBlocksToDraw = GetNbBlocks(map) - nbBlocksToSkip;

        if (UI::BeginTable("dev blocks list", nbCols, UI::TableFlags::SizingStretchProp | UI::TableFlags::ScrollY)) {
            SetupMainTableColumns();
            UI::TableHeadersRow();

            if (autoscroll) {
                UI::SetScrollY(UI::GetScrollMaxY());
            }
            UI::ListClipper clip(nbBlocksToDraw);
            while (clip.Step()) {
                for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    DrawDevBlockInfo(GetBlock(map, nbBlocksToSkip + i));
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
    }

    void SetupMainTableColumns() {
        UI::TableSetupColumn(".Blocks Ix");
        UI::TableSetupColumn("Save ID", UI::TableColumnFlags::WidthFixed, 90.);
        UI::TableSetupColumn("Block ID");
        UI::TableSetupColumn("Block MwId");
        UI::TableSetupColumn("Placed Ix", UI::TableColumnFlags::WidthFixed, 90.);
        UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        UI::TableSetupColumn("Ref Count");
        UI::TableSetupColumn("Explore");
    }

    private int nbCols = 8;
    void DrawDevBlockInfo(CGameCtnBlock@ block) {
        auto blockId = Editor::GetBlockUniqueID(block);
        UI::TableNextRow();

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
        UI::Text(block.DescId.GetName());

        UI::TableNextColumn();
        UI::Text(tostring(Reflection::GetRefCount(block)));

        UI::TableNextColumn();
        if (UX::SmallButton(Icons::Cube + "##" + blockId)) {
            ExploreNod("Block " + blockId + ".", block);
        }
    }
}


#endif
