class JitterEffectTab : EffectTab {
    JitterEffectTab(TabGroup@ p) {
        super(p, "Jitter", Icons::Magic + Icons::Arrows);
        RegisterNewItemCallback(ProcessItem(OnNewItem), this.tabName);
        RegisterNewBlockCallback(ProcessBlock(OnNewBlock), this.tabName);
        // startnew(CoroutineFunc(AutorefreshLoop));
    }

    bool OnNewItem(CGameCtnAnchoredObject@ item) {
        if (!_IsActive) return false;
        ApplyJitter(item);
        // refreshThisFrame = true;
        return true;
    }

    bool OnNewBlock(CGameCtnBlock@ block) {
        if (!_IsActive) return false;
        if (!applyToFreeblocks) return false;
        if (block is null || !Editor::IsBlockFree(block)) return false;
        ApplyJitter(block);
        return false;
    }

    // don't need this anymore
    // bool refreshThisFrame = false;
    // void AutorefreshLoop() {
    //     while (true) {
    //         yield();
    //         if (refreshThisFrame) {
    //             auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
    //             Editor::RefreshBlocksAndItems(editor);
    //             refreshThisFrame = false;
    //         }
    //     }
    // }

    bool _IsActive = false;
    bool applyToFreeblocks = true;

    bool jitterPos = true;
    vec3 jitterPosAmt = vec3(8, 1, 8);
    vec3 jitterPosOffset = vec3(0, 0, 0);
    bool jitterPosSin = false;

    bool jitterRot = true;
    vec3 jitterRotAmt = vec3(Math::PI);

    bool jitterPhase = false;
    bool jitterLM = false;
    bool jitterColor = false;
    // bool jitterRotOnlyDir = false;

    bool autorefresh = false;

    void DrawInner() override {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        UI::Text("Jitter applies a random offset to newly placed items' position and/or rotation.");
        applyToFreeblocks = UI::Checkbox("Apply to Free Blocks", applyToFreeblocks);

        // UI::TextWrapped("\\$f80Note!\\$z Too much ctrl+z can undo the jitter (and a re-do is then required if jitter isn't active at the time of the undo).");
        if (UI::Button(_IsActive ? "Deactivate##jitter" : "Activate##jitter")) {
            ToggleJitter();
        }
        UI::SameLine();
        if (UI::Button("Refresh Items")) {
            Editor::RefreshBlocksAndItems(editor);
        }
        UI::SameLine();
        autorefresh = UI::Checkbox("Auto-refresh", autorefresh);
        UI::Separator();
        jitterPos = UI::Checkbox("Apply Position Jitter", jitterPos);
        AddSimpleTooltip("Apply a randomization to placed items' locations");
        jitterPosOffset = UX::InputFloat3("Position Offset", jitterPosOffset);
        AddSimpleTooltip("Offset applied to position before jitter.");
        jitterPosAmt = UX::InputFloat3("Position Radius Jitter", jitterPosAmt); // , vec3(8, 1, 8)
        AddSimpleTooltip("Position will have a random amount added to it, up to +/- the amount specified.");
        // jitterPosSin = UI::Checkbox("Position Jitter - Sine Wave", jitterPosSin);
        // AddSimpleTooltip("Sine wave profile will be applied. More items will be clustered around the center.\n(Theta offset = 90, so technically cosine but yeah.)");
        UI::Separator();
        jitterRot = UI::Checkbox("Apply Rotation Jitter", jitterRot);
        AddSimpleTooltip("Apply a randomization to placed items' rotations");
        // jitterRotAmt = UX::InputAngles3("Rotation Jitter (Deg)", jitterRotAmt, vec3(Math::PI));
        jitterRotAmt = UX::InputAngles3Raw("Rotation Jitter (Deg)", jitterRotAmt, vec3(Math::PI));
        AddSimpleTooltip("Rotation will have a random amount added to it, up to +/- the amount specified in radians.\nDefault limits: -3.141 to 3.141 (which is -180 deg to 180 deg)");

        UI::Separator();
        jitterPhase = UI::Checkbox("Randomize Phase Offset", jitterPhase);
        jitterLM = UI::Checkbox("Randomize LightMap Quality", jitterLM);
        jitterColor = UI::Checkbox("Randomize Color", jitterColor);
    }

    void ToggleJitter() {
        _IsActive = !_IsActive;
    }

    void ApplyJitter(CGameCtnAnchoredObject@ item) {
        // CGameCtnAnchoredObject@ item = cast<CGameCtnAnchoredObject>(_r);
        // print('jittering: ' + item.ItemModel.IdName);
        if (jitterPos) {
            auto _jitter = jitterPosAmt * vec3(Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0));
            item.AbsolutePositionInMap += jitterPosOffset + _jitter;
            // trace(_jitter.ToString());
        }
        if (jitterRot) {
            auto rotMod = jitterRotAmt * vec3(Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0));
            item.Pitch += rotMod.x;
            item.Yaw += rotMod.y;
            item.Roll += rotMod.z;
            // trace(rotMod.ToString());
        }
        if (jitterPhase) {
            item.AnimPhaseOffset = CGameCtnAnchoredObject::EPhaseOffset(Math::Rand(0, 8));
        }
        if (jitterLM) {
            item.MapElemLmQuality = CGameCtnAnchoredObject::EMapElemLightmapQuality(Math::Rand(0, 7));
        }
        if (jitterColor) {
            item.MapElemColor = CGameCtnAnchoredObject::EMapElemColor(Math::Rand(0, 6));
        }
    }

    void ApplyJitter(CGameCtnBlock@ block) {
        if (!Editor::IsBlockFree(block)) return;
        if (jitterPos) {
            auto _jitter = jitterPosAmt * vec3(Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0));
            Editor::SetBlockLocation(block, Editor::GetBlockLocation(block) + jitterPosOffset + _jitter);
        }

        if (jitterRot) {
            auto rotMod = jitterRotAmt * vec3(Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0), Math::Rand(-1.0, 1.0));
            Editor::SetBlockRotation(block, Editor::GetBlockRotation(block) + rotMod);
        }

        if (jitterLM) {
            block.MapElemLmQuality = CGameCtnBlock::EMapElemLightmapQuality(Math::Rand(0, 7));
        }

        if (jitterColor) {
            block.MapElemColor = CGameCtnBlock::EMapElemColor(Math::Rand(0, 6));
        }
    }
}
