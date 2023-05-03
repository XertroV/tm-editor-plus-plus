class SetGhostVariantTab : Tab {
    SetGhostVariantTab(TabGroup@ parent) {
        super(parent, "Ghost Block Variant", "");
    }

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        _DrawGhostBlockVariant(editor);
    }

    void _DrawGhostBlockVariant(CGameCtnEditorFree@ editor) {
        if (editor.CurrentGhostBlockInfo is null) {
            UI::Text("Select a block in ghost block mode.");
            return;
        }
        auto currBlock = editor.CurrentGhostBlockInfo;

        UI::Text("Current Ghost Block: " + currBlock.Name);
        auto nbGroundVariants = currBlock.AdditionalVariantsGround.Length;
        auto nbAirVariants = currBlock.AdditionalVariantsAir.Length;
        UI::Text("Nb Variants (G / A): " + nbGroundVariants + " / " + nbAirVariants);

        auto forcedVariant = int(editor.GhostBlockForcedVariantIndex);
        bool forcedGround = editor.GhostBlockForcedGroundElseAir;

        if (forcedVariant < 0) {
            bool noVariants = 0 == nbGroundVariants | nbAirVariants;
            if (UI::Button("Enable Forced Variant")) {
                editor.GhostBlockForcedVariantIndex = 0;
            }
        } else {
            // we have 1 more than this, but this count == the max index, so we don't +1.
            auto maxVariantIx = forcedGround
                ? currBlock.AdditionalVariantsGround.Length
                : currBlock.AdditionalVariantsAir.Length;

            editor.GhostBlockForcedVariantIndex = Math::Clamp(UI::InputInt("Variant", forcedVariant), 0, maxVariantIx);
            auto newFGEA = UI::Checkbox("Forced Ground Else Air", editor.GhostBlockForcedGroundElseAir);
            if (newFGEA != editor.GhostBlockForcedGroundElseAir) {
                editor.GhostBlockForcedVariantIndex = Math::Min(forcedVariant, newFGEA ? nbGroundVariants : nbAirVariants);
                editor.GhostBlockForcedGroundElseAir = newFGEA;
            }
        }
    }
}
