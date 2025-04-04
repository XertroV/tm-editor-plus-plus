class CheckpointsTab : MultiEffectTab {
    CheckpointsTab(TabGroup@ parent) {
        super(parent, "Checkpoints", Icons::Magic + Icons::ClockO);
        SetLinkedCheckpointsTab(Children);
        AutolinkCpsTab(Children);
        SetAllCheckpointsTab(Children);
        CpPatchesTab(Children);
        canPopOut = false;
    }

    void DrawInner() override {
        Children.DrawTabsAsList();
    }
}

[Setting hidden]
bool S_ShowAutolinkCPsWindowWhenPlacingCPs = true;

class AutolinkCpsTab : EffectTab {
    AutolinkCpsTab(TabGroup@ parent) {
        super(parent, "Auto-link Checkpoints", Icons::Link);
        RegisterNewBlockCallback(ProcessBlock(this.OnNewBlock), "AutoLinkCPs");
        RegisterNewItemCallback(ProcessItem(this.OnNewItem), "AutoLinkCPs");
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        if (!_IsActive) return false;
        if (block.WaypointSpecialProperty is null) return false;
        if (block.BlockInfo.WayPointType != CGameCtnBlockInfo::EWayPointType::Checkpoint) return false;
        auto cache = Editor::GetMapCache();
        auto closeObjs = cache.objsRoot.FindPointsWithin(Editor::GetBlockLocation(block), linkDistance);
        Editor::SetCheckpointLinked(block, true, AutoLink_ProcessExistingCPs(closeObjs));
        return false;
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (!_IsActive) return false;
        if (item.WaypointSpecialProperty is null) return false;
        if (!item.ItemModel.IsCheckpoint) return false;
        auto cache = Editor::GetMapCache();
        auto closeObjs = cache.objsRoot.FindPointsWithin(Editor::GetItemLocation(item), linkDistance);
        Editor::SetCheckpointLinked(item, true, AutoLink_ProcessExistingCPs(closeObjs));
        return false;
    }

    uint AutoLink_ProcessExistingCPs(OctTreePoint@[]@ closeObjs) {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        OctTreePoint@[] closeCPs;
        CGameCtnAnchoredObject@[] closeItemCps;
        CGameCtnBlock@[] closeBlockCps;
        for (uint i = 0; i < closeObjs.Length; i++) {
            if (!closeObjs[i].HasCheckpoint()) continue;
            closeCPs.InsertLast(closeObjs[i]);
            auto itemSpec = closeObjs[i].item;
            auto blockSpec = closeObjs[i].block;
            if (itemSpec !is null) {
                for (uint j = 0; j < map.AnchoredObjects.Length; j++) {
                    auto item = map.AnchoredObjects[j];
                    if (itemSpec.MatchesItem(item)) {
                        closeItemCps.InsertLast(item);
                    }
                }
            } else if (blockSpec !is null) {
                for (uint j = 0; j < map.Blocks.Length; j++) {
                    auto block = map.Blocks[j];
                    if (blockSpec.MatchesBlock(block)) {
                        closeBlockCps.InsertLast(block);
                    }
                }
            }
        }

        for (int i = closeBlockCps.Length - 1; i >= 0; i--) {
            if (closeBlockCps[i] is null || closeBlockCps[i].WaypointSpecialProperty is null) {
                closeBlockCps.RemoveAt(i);
                dev_trace("Removed null closeBlockCps[" + i + "]");
            }
        }

        int linkOrder = -1;
        for (uint i = 0; i < closeBlockCps.Length; i++) {
            if (closeBlockCps[i].WaypointSpecialProperty.Tag == "LinkedCheckpoint") {
                linkOrder = closeBlockCps[i].WaypointSpecialProperty.Order;
                break;
            }
        }
        if (linkOrder < 0) {
            for (uint i = 0; i < closeItemCps.Length; i++) {
                if (closeItemCps[i].WaypointSpecialProperty.Tag == "LinkedCheckpoint") {
                    linkOrder = closeItemCps[i].WaypointSpecialProperty.Order;
                    break;
                }
            }
        }
        if (linkOrder < 0) {
            linkOrder = linkOrderAutoNext;
            linkOrderAutoNext++;
        }
        for (uint i = 0; i < closeBlockCps.Length; i++) {
            if (!Editor::IsCheckpointLinked(closeBlockCps[i], linkOrder)) {
                Editor::SetCheckpointLinked(closeBlockCps[i], true, linkOrder);
            }
        }
        for (uint i = 0; i < closeItemCps.Length; i++) {
            if (!Editor::IsCheckpointLinked(closeItemCps[i], linkOrder)) {
                Editor::SetCheckpointLinked(closeItemCps[i], true, linkOrder);
            }
        }
        return linkOrder;
    }

    uint linkOrderAutoNext = 333;
    float linkDistance = 72.;

    void DrawInner() override {
        UI::TextWrapped("Automatically link checkpoints when placing them near other checkpoints.");
        S_ShowAutolinkCPsWindowWhenPlacingCPs = UI::Checkbox("Show window when placing CPs", S_ShowAutolinkCPsWindowWhenPlacingCPs);
        _IsActive = UI::Checkbox("Enable auto-linking", _IsActive);
        linkDistance = UI::SliderFloat("Link distance", linkDistance, 0, 200, "%.1f");
    }

    bool get_windowOpen() override property {
        if (!S_ShowAutolinkCPsWindowWhenPlacingCPs) return false;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor is null) return false;
        bool hasBlock = editor.CurrentBlockInfo !is null && Editor::IsInNormBlockPlacementMode(editor, true);
        bool hasGhost = editor.CurrentGhostBlockInfo !is null && Editor::IsInGhostOrFreeBlockPlacementMode(editor, true);
        bool hasItem = editor.CurrentItemModel !is null && Editor::IsInAnyItemPlacementMode(editor, true);
        if (!(hasBlock || hasGhost || hasItem)) return false;
        if (hasBlock && editor.CurrentBlockInfo.WayPointType != CGameCtnBlockInfo::EWayPointType::Checkpoint) return false;
        if (hasGhost && editor.CurrentGhostBlockInfo.WayPointType != CGameCtnBlockInfo::EWayPointType::Checkpoint) return false;
        if (hasItem && !editor.CurrentItemModel.IsCheckpoint) return false;
        return true;
    }
    void set_windowOpen(bool value) override property {
        S_ShowAutolinkCPsWindowWhenPlacingCPs = value;
    }
}

class CpPatchesTab : EffectTab {
    CpPatchesTab(TabGroup@ parent) {
        super(parent, "Patches", Icons::Hashtag);
    }

    bool get__IsActive() override property {
        return Patch_CpCanStandingResapwnCheck.IsApplied;
    }
    void set__IsActive(bool v) override property {
        Patch_CpCanStandingResapwnCheck.IsApplied = v;
    }

    void DrawInner() override {
        _IsActive = UI::Checkbox("Enable testing from Circle CPs", _IsActive);
        UI::Text("Must be manually enabled and auto-disabled when leaving editor.");
    }
}
