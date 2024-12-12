
class FindReplaceTab : GenericApplyTab {
    ReferencedNod@ sourceItemModel;
    ReferencedNod@ sourceBlockModel;
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

    // override this to clear picked block/item b/c we can get a crash if we picked one we're going to modify
    void BeforeApply() override {
        @lastPickedBlock = null;
        @lastPickedItem = null;
    }

    void OnEditorLoad() {
        @sourceBlockModel = null;
        @sourceItemModel = null;
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (!_IsActive) return false;
        return RunReplace(item);
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        if (!_IsActive) return false;
        return RunReplace(block);
    }

    bool RunReplace(CGameCtnAnchoredObject@ item) {
        if (sourceItemModel is null || !applyToItems) return false;
        if (!MatchesConditions(item)) return false;
        auto origModel = item.ItemModel;
        auto sourceModel = sourceItemModel.AsItemModel();
        Dev::SetOffset(item, GetOffset(item, "ItemModel"), sourceModel);
        Dev::SetOffset(item, 0x18, sourceModel.Id.Value);
        item.ItemModel.MwAddRef();
        origModel.MwRelease();
        return true;
    }

    bool RunReplace(CGameCtnBlock@ block) {
        if (sourceBlockModel is null || !applyToBlocks) return false;
        if (!MatchesConditions(block)) return false;
        auto origModel = block.BlockInfo;
        // set blockinfo handle
        Dev::SetOffset(block, GetOffset(block, "BlockInfo"), sourceBlockModel.AsBlockInfo());
        // set blockinfo MwId
        Dev::SetOffset(block, 0x18, sourceBlockModel.AsBlockInfo().Id.Value);
        Editor::SetBlockInfoVariantIndex(block, sourceBlockVarIx);
        block.BlockInfo.MwAddRef();
        origModel.MwRelease();
        return true;
    }

    void CheckBlockVariant(CGameCtnBlock@ block) {
        auto variant = Editor::GetBlockInfoVariant(block);
        if (variant is null) {
            // block.BlockInfoVariantIndex = 0;
            // todo
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
        if (ClearAfterRun) {
            @sourceItemModel = null;
            @sourceBlockModel = null;
            filteredObjectNames.RemoveRange(0, filteredObjectNames.Length);
        }
    }

    bool ClearAfterRun = true;

    void DrawInner() override {
        UI::TextWrapped("Find all instances of an item or block and replace it with a source item/block.");
        UI::TextWrapped("\\$f80Warning:\\$z Replacing some blocks (e.g., checkpoints) may result in a crash. Please save your work before using this tool.");

        _IsActive = UI::Checkbox("Apply to new? (as per filter)", _IsActive);
        ClearAfterRun = UI::Checkbox("Auto-clear sources and filter after apply", ClearAfterRun);

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
                sourceBlockVarIx = Editor::GetBlockInfoVariantIndex(editor.PickedBlock);
                break;
            }
        }
        awaitingPickedBlock = false;
    }
}
