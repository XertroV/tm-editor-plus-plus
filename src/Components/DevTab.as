#if SIG_DEVELOPER

class DevMainTab : Tab {
    bool drawStuff = true;

    DevMainTab(TabGroup@ p) {
        super(p, "Dev Info", Icons::ExclamationTriangle);
        canPopOut = false;
        DevBlockTab(Children);
        DevBlockTab(Children, true);
        DevItemsTab(Children);
        DevCallbacksTab(Children);
        DevMiscTab(Children);
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        drawStuff = UI::Checkbox("Enable Dev Info", drawStuff);
        if (editor !is null) {
            UI::SameLine();
            CopiableLabeledValue("editor ptr", Text::FormatPointer(Dev_GetPointerForNod(editor)));
        }

        if (!drawStuff) return;
        Children.DrawTabs();
        return;
    }
}

class DevCallbacksTab : Tab {
    DevCallbacksTab(TabGroup@ p) {
        super(p, "Callbacks", "");
    }

    void DrawInner() override {
        DrawCBs("On Editor Load", onEditorLoadCbNames);
        DrawCBs("On Editor Unload", onEditorUnloadCbNames);
        DrawCBs("On New Item", itemCallbackNames);
        DrawCBs("Block Callback", blockCallbackNames);
        DrawCBs("Selected Item Changed", selectedItemChangedCbNames);
    }

    void DrawCBs(const string &in type, string[]@ names) {
        if (UI::CollapsingHeader(type)) {
            for (uint i = 0; i < names.Length; i++) {
                UI::Text(names[i]);
            }
        }
    }
}

class DevMiscTab : Tab {
    DevMiscTab(TabGroup@ p) {
        super(p, "Misc Dev", "");
    }

    void DrawInner() override {
        if (UI::Button("Remove 50% of items")) {
            startnew(CoroutineFunc(Remove50PctItemsTest));
        }
    }

    void Remove50PctItemsTest() {
        CGameCtnAnchoredObject@[] items;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);;
        auto map = editor.Challenge;
        for (uint i = 0; i < map.AnchoredObjects.Length; i += 2) {
            items.InsertLast(map.AnchoredObjects[i]);
        }
        for (uint i = 1; i < map.AnchoredObjects.Length; i += 2) {
            items.InsertLast(map.AnchoredObjects[i]);
        }
        auto keepTo = items.Length / 2;

        auto bufPtr = Dev::GetOffsetNod(map, GetOffset(map, "AnchoredObjects"));
        for (uint i = 0; i < items.Length; i++) {
            Dev::SetOffset(bufPtr, 0x8 * i, items[i]);
        }
        Dev::SetOffset(map, GetOffset(map, "AnchoredObjects") + 0x8, uint32(keepTo));
        Editor::SaveAndReloadMap();
    }
}

class DevItemsTab : BlockItemListTab {
    DevItemsTab(TabGroup@ p) {
        super(p, "Items (Dev)", Icons::Tree, BIListTabType::Items);
        nbCols = 7;
    }

    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
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

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        auto item = GetItem(map, i);

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

class DevBlockTab : BlockItemListTab {
    DevBlockTab(TabGroup@ p, bool baked = false) {
        super(p, baked ? "Baked Blocks (Dev)" : "Blocks (Dev)", Icons::Cube, baked ? BIListTabType::BakedBlocks : BIListTabType::Blocks);
        nbCols = 9;
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) override {
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

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) override {
        auto block = GetBlock(map, i);
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
