enum BIListTabType {
    Blocks, BakedBlocks, Items
}

const string BI_LIST_COLS_SETTINGS_WINDOW_ID = "bi-list-cols";

const string cpYesMark = "\\$88f" + Icons::Check + " CP";
const string cpNoMark = "\\$b86" + Icons::Times;
const string cpStartMark = "\\$8f0Start";
const string cpFinMark = "\\$f40Finish";
const string cpMultilapMark = "\\$ff0Multilap";

const string GetCpMark(int wpType) {
    if (wpType == 0) return cpStartMark;
    if (wpType == 1) return cpFinMark;
    if (wpType == 2) return cpYesMark;
    if (wpType == 3) return cpNoMark;
    if (wpType == 4) return cpMultilapMark;
    return "\\$ccf??";
}

namespace BIL_Settings {
    [Setting hidden]
    bool Col_Type = true;
    [Setting hidden]
    bool Col_Pos = true;
    [Setting hidden]
    bool Col_Rot = true;
    [Setting hidden]
    bool Col_Coord = true;
    [Setting hidden]
    bool Col_Dir = true;
    [Setting hidden]
    bool Col_Color = true;
    [Setting hidden]
    bool Col_LM = false;
    [Setting hidden]
    bool Col_IsCP = true;
    [Setting hidden]
    bool Col_Size = true;

    void DrawSettings() {
        UI::SeparatorText("Columns Visibility");
        Col_Type = UI::Checkbox("Type", Col_Type);
        Col_Pos = UI::Checkbox("Position", Col_Pos);
        Col_Rot = UI::Checkbox("Rotation", Col_Rot);
        Col_Coord = UI::Checkbox("Coord", Col_Coord);
        Col_Dir = UI::Checkbox("Dir", Col_Dir);
        Col_Color = UI::Checkbox("Color", Col_Color);
        Col_LM = UI::Checkbox("LM Quality", Col_LM);
        Col_IsCP = UI::Checkbox("Is CP", Col_IsCP);
        Col_Size = UI::Checkbox("Size", Col_Size);
    }
}

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
        SetupOnLoad();
    }

    // can be overridden for in map
    void SetupOnLoad() {
        RegisterOnEditorLoadCallback(CoroutineFunc(OnEditorLoad), this.tabName);
    }


    int get_WindowFlags() override property {
        return UI::WindowFlags::None;
    }

    bool recheckSkip = true;
    void OnEditorLoad() {
        recheckSkip = true;
    }

    uint GetNbObjects(CGameCtnChallenge@ map) {
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

    // empty for overriding
    void DrawInnerEarly() {}

    CGameCtnChallenge@ GetMap() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        return editor.Challenge;
    }

    // Should be overridden
    void UpdateNbCols() {
        nbCols = 9;
    }

    void CopyCSV(CGameCtnChallenge@ map, uint nbBlocks) {
        string csv = "";
        CGameCtnBlock@ block;
        CGameCtnAnchoredObject@ item;
        for (uint i = 0; i < nbBlocks; i++) {
            if (IsAnyBlocksTab) {
                @block = GetBlock(map, i);
                if (block.BlockInfo.Name == "Grass") {
                    continue;
                }
                csv += GetBlockCsvLine(block);
            } else {
                @item = GetItem(map, i);
                csv += GetItemCsvLine(item);
            }
        }
        SetClipboard(csv);
    }

    bool wholeListShown = false;
    bool autoscroll = false;
    bool skipXZStarting = true;
    protected int nbCols = 9;

    void DrawInner() override {
        DrawSettingsPopup();

        auto map = GetMap();
        auto sizeXZ = map.Size.x * map.Size.z - 4;
        auto nbBlocks = GetNbObjects(map);
        uint nbBlocksToSkip = Math::Min(nbBlocks - 4, sizeXZ);
        UpdateNbCols();

        DrawInnerEarly();

        UI::AlignTextToFramePadding();
        UI::Text("Total: " + nbBlocks + "   |");
        UI::SameLine();

        autoscroll = UI::Checkbox("Autoscroll", autoscroll);

        if (IsAnyBlocksTab && nbBlocks > sizeXZ) {
            UI::SameLine();
            if (recheckSkip) {
                recheckSkip = false;
                auto block = map !is null ? GetBlock(map, 0) : null;
                skipXZStarting = block !is null && block.BlockInfo.IdName == "Grass";
            }
            skipXZStarting = UI::Checkbox("Skip first " + sizeXZ + " blocks", skipXZStarting);
            if (!skipXZStarting) {
                nbBlocksToSkip = 0;
            }
        } else {
            nbBlocksToSkip = 0;
        }

        UI::SameLine();
        if (UI::Button("Copy CSV (excl grass)")) {
            CopyCSV(map, nbBlocks);
        }

        UI::SameLine();
        if (UI::Button("Columns " + Icons::Cogs)) {
            UI::OpenPopup(BI_LIST_COLS_SETTINGS_WINDOW_ID);
        }

        int nbBlocksToDraw = nbBlocks - nbBlocksToSkip;

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
                for (int i = clip.DisplayStart; i < clip.DisplayEnd; i++) {
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
        // float numberColWidth = 90 * g_scale;
        // float smlNumberColWidth = 70 * g_scale;
        // float exploreColWidth = smlNumberColWidth + (offsetScrollbar ? UI::GetStyleVarFloat(UI::StyleVar::ScrollbarSize) : 0.);
        // UI::TableSetupColumn("#", UI::TableColumnFlags::WidthFixed, 50. * g_scale);
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

    void DrawSettingsPopup() {
        if (UI::BeginPopup(BI_LIST_COLS_SETTINGS_WINDOW_ID)) {
            BIL_Settings::DrawSettings();
            UX::CloseCurrentPopupIfMouseFarAway(false);
            UI::EndPopup();
        }
    }
}



string GetBlockCsvLine(CGameCtnBlock@ block) {
    string csv = "";
    csv += block.BlockInfo.Name;
    csv += "," + Editor::GetBlockLocation(block).ToString();
    csv += "," + Nat3ToInt3(Editor::GetBlockCoord(block)).ToString();
    csv += "," + tostring(block.Dir);
    csv += "," + tostring(block.MapElemColor);
    return csv + "\n";
}

string GetItemCsvLine(CGameCtnAnchoredObject@ item) {
    string csv = "";
    csv += item.ItemModel.Name;
    csv += "," + item.AbsolutePositionInMap.ToString();
    csv += "," + Editor::GetItemRotation(item).ToString();
    csv += "," + tostring(item.MapElemColor);
    return csv + "\n";
}
