enum BIListTabType {
    Blocks, BakedBlocks, Items
}

const string cpYesMark = "\\$8f0" + Icons::Check;
const string cpNoMark = "\\$c84" + Icons::Times;

class BlockItemListTab : Tab {
    bool useBakedBlocks = false;
    BIListTabType ty = BIListTabType::Blocks;
    bool IsAnyBlocksTab = true;

    BlockItemListTab(TabGroup@ p, const string &in title, const string &in icon, BIListTabType ty) {
        super(p, title, icon);
        this.ty = ty;
        if (ty == BIListTabType::BakedBlocks) {
            useBakedBlocks = true;
        }
        if (ty == BIListTabType::Items) {
            IsAnyBlocksTab = false;
        }
        RegisterOnEditorLoadCallback(CoroutineFunc(OnEditorLoad), this.tabName);
    }


    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    bool recheckSkip = true;
    void OnEditorLoad() {
        recheckSkip = true;
    }

    int GetNbObjects(CGameCtnChallenge@ map) {
        switch (ty) {
            case BIListTabType::Blocks: return map.Blocks.Length;
            case BIListTabType::BakedBlocks: return map.BakedBlocks.Length;
            case BIListTabType::Items: return map.AnchoredObjects.Length;
        }
        return 0;
    }

    CGameCtnBlock@ GetBlock(CGameCtnChallenge@ map, uint i) {
        if (i >= GetNbObjects(map)) {
            return null;
        }
        switch (ty) {
            case BIListTabType::Blocks: return map.Blocks[i];
            case BIListTabType::BakedBlocks: return map.BakedBlocks[i];
        }
        return null;
    }

    CGameCtnAnchoredObject@ GetItem(CGameCtnChallenge@ map, uint i) {
        if (i >= GetNbObjects(map)) {
            return null;
        }
        switch (ty) {
            case BIListTabType::Items: return map.AnchoredObjects[i];
        }
        return null;
    }

    bool wholeListShown = false;
    bool autoscroll = false;
    bool skipXZStarting = true;
    protected int nbCols = 9;
    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        auto sizeXZ = map.Size.x * map.Size.z - 4;
        auto nbBlocks = GetNbObjects(map);
        uint nbBlocksToSkip = Math::Min(nbBlocks - 4, sizeXZ);

        UI::AlignTextToFramePadding();
        UI::Text("Total: " + nbBlocks + "   |");
        UI::SameLine();

        autoscroll = UI::Checkbox("Autoscroll", autoscroll);

        if (IsAnyBlocksTab && nbBlocks > sizeXZ) {
            UI::SameLine();
            if (recheckSkip) {
                recheckSkip = false;
                skipXZStarting = GetBlock(map, 0).DescId.GetName() == "Grass";
            }
            skipXZStarting = UI::Checkbox("Skip first " + sizeXZ + " blocks", skipXZStarting);
            if (!skipXZStarting) {
                nbBlocksToSkip = 0;
            }
        } else {
            nbBlocksToSkip = 0;
        }

        uint nbBlocksToDraw = nbBlocks - nbBlocksToSkip;

        DrawColumnHeadersOnlyTable();

        wholeListShown = false;
        bool sawFirst = false, sawLast = false;

        // UI::PushStyleColor(UI::Col::TableRowBg, vec4(.2,.2,.2,.7));
        UI::PushStyleColor(UI::Col::TableRowBgAlt, vec4(.2,.2,.2,.5));
        if (UI::BeginTable("bi-list|"+tostring(ty), nbCols, UI::TableFlags::ScrollY | UI::TableFlags::RowBg)) {
            SetupMainTableColumns();

            if (autoscroll) {
                UI::SetScrollY(UI::GetScrollMaxY());
            }
            UI::ListClipper clip(nbBlocksToDraw);
            while (clip.Step()) {
                if (clip.DisplayStart == 1) sawFirst = true;
                if (clip.DisplayEnd == nbBlocksToDraw) sawLast = true;
                for (uint i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
                    UI::PushID(i);
                    DrawObjectInfo(map, nbBlocksToSkip + i);
                    UI::PopID();
                }
            }

            UI::EndTable();
        }
        UI::PopStyleColor(1);

        wholeListShown = sawFirst && sawLast;
    }

    void DrawColumnHeadersOnlyTable() {
        if (UI::BeginTable("bi-list-headings"+tostring(ty), nbCols, UI::TableFlags::None)) {
            SetupMainTableColumns(true && !wholeListShown);
            UI::TableHeadersRow();
            UI::EndTable();
        }
    }

    void SetupMainTableColumns(bool offsetScrollbar = false) {
        throw('override me');
        // float numberColWidth = 90;
        // float smlNumberColWidth = 70;
        // float exploreColWidth = smlNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        // UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50.);
        // UI::TableSetupColumn("Type", UI::TableColumnFlags::WidthStretch);
        // UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, numberColWidth);
        // UI::TableSetupColumn("Color", UI::TableColumnFlags::WidthFixed, numberColWidth);
        // UI::TableSetupColumn("LM Quality", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        // UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        // UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, numberColWidth);
        // UI::TableSetupColumn("", UI::TableColumnFlags::WidthFixed, smlNumberColWidth);
        // UI::TableSetupColumn("Tools", UI::TableColumnFlags::WidthFixed, exploreColWidth);
    }

    void DrawObjectInfo(CGameCtnChallenge@ map, int i) {
        throw('override me');
        auto block = GetBlock(map, i);
        auto item = GetItem(map, i);
    }
}
