class RandomizerTab : Tab {
    RandomizerTab(TabGroup@ p) {
        super(p, "Randomizer", "\\$bff"+Icons::Random+"\\$z");
    }

    bool applyToItems = true;
    bool applyToBlocks = true;
    bool applyToBakedBlocks = false;

    bool randomizeColor = true;
    bool randomizeLM = false;
    bool randomizeDir = true;

    void DrawInner() override {
        UI::TextWrapped("Randomize properties for blocks/items");
        UI::Separator();
        applyToItems = UI::Checkbox("Apply to Items", applyToItems);
        applyToBlocks = UI::Checkbox("Apply to Blocks", applyToBlocks);
        applyToBakedBlocks = UI::Checkbox("Apply to Baked Blocks", applyToBakedBlocks);
        randomizeColor = UI::Checkbox("Randomize Color", randomizeColor);
        randomizeLM = UI::Checkbox("Randomize LM Quality", randomizeLM);
        randomizeDir = UI::Checkbox("Randomize Block.Dir (N/S/E/W)", randomizeDir);
        UI::BeginDisabled();
        UI::Text("future features?");
        UI::Checkbox("Randomize Variant", false);
        UI::Checkbox("Randomize CP Linkage", false);
        UI::EndDisabled();
        UI::Separator();
        if (UI::Button("Randomize " + Icons::Random)) {
            RunRandomize();
        }
    }

    void RunRandomize() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto map = editor.Challenge;
        if (applyToBlocks) {
            for (uint i = 0; i < map.Blocks.Length; i++) {
                RandomizeBlock(map.Blocks[i]);
            }
        }
        if (applyToBakedBlocks) {
            for (uint i = 0; i < map.BakedBlocks.Length; i++) {
                RandomizeBlock(map.BakedBlocks[i]);
            }
        }
        if (applyToItems) {
            for (uint i = 0; i < map.AnchoredObjects.Length; i++) {
                RandomizeItem(map.AnchoredObjects[i]);
            }
        }
        Editor::RefreshBlocksAndItems(editor);
    }

    void RandomizeBlock(CGameCtnBlock@ block) {
        if (randomizeColor) block.MapElemColor = CGameCtnBlock::EMapElemColor(Math::Rand(0, 6));
        if (randomizeDir) block.BlockDir = CGameCtnBlock::ECardinalDirections(Math::Rand(0, 4));
        if (randomizeLM) block.MapElemLmQuality = CGameCtnBlock::EMapElemLightmapQuality(Math::Rand(0, 7));
    }
    void RandomizeItem(CGameCtnAnchoredObject@ item) {
        if (randomizeColor) item.MapElemColor = CGameCtnAnchoredObject::EMapElemColor(Math::Rand(0, 6));
        if (randomizeLM) item.MapElemLmQuality = CGameCtnAnchoredObject::EMapElemLightmapQuality(Math::Rand(0, 7));
    }
}
