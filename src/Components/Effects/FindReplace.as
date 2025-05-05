
class FindReplaceTab : GenericApplyTab {
    ReferencedNod@ sourceItemModel;
    ReferencedNod@ sourceBlockModel;
    CGameCtnAnchoredObject::EMapElemColor sourceItemColor;
    CGameCtnBlock::EMapElemColor sourceBlockColor;
    uint sourceBlockVarIx;

    bool applyToItems = true;
    bool applyToBlocks = true;
    bool awaitingPickedItem = false;
    bool awaitingPickedBlock = false;

    FindReplaceTab(TabGroup@ p) {
        super(p, "Find/Replace", Icons::Magic + Icons::Search + Icons::LevelDown);
        RegisterNewItemCallback(ProcessItem(this.OnNewItem), this.tabName);
        RegisterNewBlockCallback(ProcessBlock(this.OnNewBlock), this.tabName);
        RegisterOnEditorLoadCallback(CoroutineFunc(this.OnEditorLoad), this.tabName);
        RegisterOnEditorUnloadCallback(CoroutineFunc(this.OnEditorLoad), this.tabName);
    }

    array<Editor::BlockSpec@> newblockSpecs;
    array<Editor::ItemSpec@> newitemSpecs;

    // override this to clear picked block/item b/c we can get a crash if we picked one we're going to modify
    void BeforeApply() override {
        @lastPickedBlock = null;
        @lastPickedItem = null;
    }

    void OnEditorLoad() {
        @sourceBlockModel = null;
        @sourceItemModel = null;
        sourceBlockColor = CGameCtnBlock::EMapElemColor::Default;
        sourceItemColor = CGameCtnAnchoredObject::EMapElemColor::Default;
    }

    private void ClearSpecs() {
        newblockSpecs.RemoveRange(0, newblockSpecs.Length);
        newitemSpecs.RemoveRange(0, newitemSpecs.Length);
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (!_IsActive) return false;
        bool success = RunReplace(item);
        if (success && AddWithoutReplace) {
            // check the source item isn't one we're placing to avoid repeating until script timeout
            bool isValidTarget = filteredObjectNames.Length > 0 && filteredObjectNames.Find(sourceItemModel.AsItemModel().IdName) < 0;
            if (isValidTarget) Editor::PlaceMacroblock(Editor::MakeMacroblockSpec(newblockSpecs, newitemSpecs));
        }
        ClearSpecs();
        return success;
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        if (!_IsActive) return false;
        bool success = RunReplace(block);
        if (success && AddWithoutReplace) {
            // check the source block isn't one we're placing to avoid repeating until script timeout
            bool isValidTarget = filteredObjectNames.Length > 0 && filteredObjectNames.Find(sourceBlockModel.AsBlockInfo().IdName) < 0;
            if (isValidTarget) Editor::PlaceMacroblock(Editor::MakeMacroblockSpec(newblockSpecs, newitemSpecs));
        }
        ClearSpecs();
        return success;
    }

    bool RunReplace(CGameCtnAnchoredObject@ item) {
        if (sourceItemModel is null || !applyToItems) return false;
        if (!MatchesConditions(item)) return false;
        auto sourceModel = sourceItemModel.AsItemModel();
        if (AddWithoutReplace) {
            Editor::ItemSpec@ newitemSpec = Editor::MakeItemSpec(sourceModel, item.AbsolutePositionInMap, Editor::GetItemRotation(item));
            newitemSpec.pivotPos = Editor::GetItemPivot(item);
            newitemSpec.coord = Editor::GetItemCoord(item);
            newitemSpec.isFlying = item.IsFlying ? 1 : 0;
            newitemSpec.color = KeepSourceColor ? sourceItemColor : item.MapElemColor;
            newitemSpec.variantIx = KeepSourceVariant
                ? sourceModel.DefaultPlacementParam_Content.PlacementClass.CurVariant
                : item.ItemModel.DefaultPlacementParam_Content.PlacementClass.CurVariant;
            newitemSpecs.InsertLast(newitemSpec);
        } else {
            // this handles mw refs, model id, and author id
            Editor::SetAO_ItemModel(item, sourceModel);
            if (KeepSourceColor) item.MapElemColor = sourceItemColor;
            if (KeepSourceVariant) item.ItemModel.DefaultPlacementParam_Content.PlacementClass.CurVariant = sourceModel.DefaultPlacementParam_Content.PlacementClass.CurVariant;
        }
        return true;
    }

    bool RunReplace(CGameCtnBlock@ block) {
        if (sourceBlockModel is null || !applyToBlocks) return false;
        if (!MatchesConditions(block)) return false;
        if (AddWithoutReplace) {
            bool isFree = Editor::IsBlockFree(block);
            Editor::BlockSpec@ newblockSpec = isFree
                ? Editor::MakeBlockSpec(sourceBlockModel.AsBlockInfo(), Editor::GetBlockLocation(block), Editor::GetBlockRotation(block))
                : Editor::MakeBlockSpec(sourceBlockModel.AsBlockInfo(), block.Coord, block.Dir);
            if (!isFree) newblockSpec.isGhost = true; // cannot place 2 normal blocks in the same spot, so make it a ghost block.

            newblockSpec.color = KeepSourceColor ? sourceBlockColor : block.MapElemColor;
            newblockSpec.variant = KeepSourceVariant ? sourceBlockVarIx : Editor::GetBlockInfoVariantIndex(block);
            newblockSpecs.InsertLast(newblockSpec);
        } else {
            // set blockinfo handle
            Editor::SetBlock_BlockInfo(block, sourceBlockModel.AsBlockInfo());
            if (KeepSourceColor) block.MapElemColor = sourceBlockColor;
            if (KeepSourceVariant) {
                // Can cause crashes if the variant doesn't exist
                Editor::SetBlockInfoVariantIndex(block, sourceBlockVarIx, true);
            }
        }

        return true;
    }

    void CheckBlockVariant(CGameCtnBlock@ block) {
        auto variant = Editor::GetBlockInfoVariant(block);
        if (variant is null) {
            @variant = Editor::GetBlockInfoVariant(block);
            if (variant is null) {
                NotifyWarning("Find/Replace: Block variant does not seem to exist for the new block model.");
            }
        }
    }


    void ApplyTo(CGameCtnBlock@ block) override {
        RunReplace(block);
    }

    void ApplyTo(CGameCtnAnchoredObject@ item) override {
        RunReplace(item);
    }

    void AfterApply() override {
        if (AddWithoutReplace) {
            Editor::PlaceMacroblock(Editor::MakeMacroblockSpec(newblockSpecs, newitemSpecs), true);
        }
        ClearSpecs();
        if (ClearAfterRun) {
            @sourceItemModel = null;
            @sourceBlockModel = null;
            filteredObjectNames.RemoveRange(0, filteredObjectNames.Length);
        }
    }

    bool ClearAfterRun = true;
    bool AddWithoutReplace = false;
    bool KeepSourceColor = false;
    bool KeepSourceVariant = true;

    void DrawInner() override {
        UI::TextWrapped("Find all instances of an item or block and replace it with a source item/block.");
        UI::TextWrapped("\\$f80Warning:\\$z Replacing some blocks (e.g., checkpoints) may result in a crash. Please save your work before using this tool.");

        _IsActive = UI::Checkbox("Apply to new blocks/items as you place them (if in filter)", _IsActive);
        ClearAfterRun = UI::Checkbox("Auto-clear sources and filter after apply", ClearAfterRun);
        AddWithoutReplace = UI::Checkbox("Add new blocks/items without replacing the original", AddWithoutReplace);
        KeepSourceColor = UI::Checkbox("Use color from source block/item instead of targets", KeepSourceColor);
        KeepSourceVariant = UI::Checkbox("Use variant from source block/item (disabling might cause a crash in some cases)", KeepSourceVariant);

        UI::AlignTextToFramePadding();
        if (sourceItemModel is null) {
            UI::Text("Source Item: null");
            UI::SameLine();
            if (awaitingPickedItem) {
                UI::Text("Ctrl+hover an item to select it as the source item.");
            } else if (UI::Button("Pick Source Item")) {
                startnew(CoroutineFunc(SetSourceAwaitPickedItem));
            }
        } else {
            auto item = sourceItemModel.AsItemModel();
            UI::Text("Source Item: " + item.IdName);
            UI::SameLine();
            if (UI::Button("Reset Source Item")) {
                @sourceItemModel = null;
            }
        }

        UI::AlignTextToFramePadding();
        if (sourceBlockModel is null) {
            UI::Text("Source Block: null");
            UI::SameLine();
            if (awaitingPickedBlock) {
                UI::Text("Ctrl+hover a block to select it as the source block.");
            } else if (UI::Button("Pick Source Block")) {
                startnew(CoroutineFunc(SetSourceAwaitPickedBlock));
            }
        } else {
            auto block = sourceBlockModel.AsBlockInfo();
            UI::Text("Source Block: " + block.IdName);
            UI::SameLine();
            if (UI::Button("Reset Source Block")) {
                @sourceBlockModel = null;
            }
        }

        UI::Separator();

        GenericApplyTab::DrawInner();
    }

    void SetSourceAwaitPickedItem() {
        awaitingPickedItem = true;
        Notify("Ctrl+hover a Item to select it as the source Item.");
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto start = Time::Now;
        while (GetApp().Editor !is null && start + 5000 > Time::Now) {
            yield();
            if (editor.PickedObject !is null) {
                @sourceItemModel = ReferencedNod(editor.PickedObject.ItemModel);
                sourceItemColor = editor.PickedObject.MapElemColor;
                break;
            }
        }
        awaitingPickedItem = false;
    }

    void SetSourceAwaitPickedBlock() {
        awaitingPickedBlock = true;
        Notify("Ctrl+hover a Block to select it as the source Block.");
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto start = Time::Now;
        while (GetApp().Editor !is null && start + 5000 > Time::Now) {
            yield();
            if (editor.PickedBlock !is null) {
                @sourceBlockModel = ReferencedNod(editor.PickedBlock.BlockInfo);
                sourceBlockColor = editor.PickedBlock.MapElemColor;
                sourceBlockVarIx = Editor::GetBlockInfoVariantIndex(editor.PickedBlock);
                break;
            }
        }
        awaitingPickedBlock = false;
    }
}
