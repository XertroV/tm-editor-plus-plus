mixin class NudgeItemBlock {
    float m_PosStepSize = 0.1;
    float m_RotStepSize = .01745;

    // draw preferably draw as final thing as can invalidate item/block reference
    void DrawNudgeFor(CMwNod@ nod) {
        auto item = cast<CGameCtnAnchoredObject>(nod);
        auto block = cast<CGameCtnBlock>(nod);

        vec3 itemPosMod = vec3();
        vec3 itemRotMod = vec3();

        m_PosStepSize = UI::InputFloat("Pos. Step Size", m_PosStepSize, 0.01);
        m_RotStepSize = Math::ToRad(UI::InputFloat("Rot. Step Size (D)", Math::ToDeg(m_RotStepSize), 0.1));

        UI::AlignTextToFramePadding();
        UI::Text("Pos:");
        UI::SameLine();
        if (UI::Button("X+")) {
            itemPosMod = vec3(m_PosStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::Button("X-")) {
            itemPosMod = vec3(-m_PosStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::Button("Y+")) {
            itemPosMod = vec3(0, m_PosStepSize, 0);
        }
        UI::SameLine();
        if (UI::Button("Y-")) {
            itemPosMod = vec3(0, -m_PosStepSize, 0);
        }
        UI::SameLine();
        if (UI::Button("Z+")) {
            itemPosMod = vec3(0, 0, m_PosStepSize);
        }
        UI::SameLine();
        if (UI::Button("Z-")) {
            itemPosMod = vec3(0, 0, -m_PosStepSize);
        }

        UI::AlignTextToFramePadding();
        UI::Text("Rot:");
        UI::SameLine();
        if (UI::Button("P+")) {
            itemRotMod = vec3(m_RotStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::Button("P-")) {
            itemRotMod = vec3(-m_RotStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::Button("Y+##yaw")) {
            itemRotMod = vec3(0, m_RotStepSize, 0);
        }
        UI::SameLine();
        if (UI::Button("Y-##yaw")) {
            itemRotMod = vec3(0, -m_RotStepSize, 0);
        }
        UI::SameLine();
        if (UI::Button("R+")) {
            itemRotMod = vec3(0, 0, m_RotStepSize);
        }
        UI::SameLine();
        if (UI::Button("R-")) {
            itemRotMod = vec3(0, 0, -m_RotStepSize);
        }

        if (itemPosMod.LengthSquared() > 0 || itemRotMod.LengthSquared() > 0) {
            if (item !is null) {
                item.AbsolutePositionInMap += itemPosMod;
                item.Pitch += itemRotMod.x;
                item.Yaw += itemRotMod.y;
                item.Roll += itemRotMod.z;
            } else if (block !is null) {
                // todo
                if (Editor::IsBlockFree(block)) {
                    Editor::SetBlockLocation(block, Editor::GetBlockLocation(block) + itemPosMod);
                    Editor::SetBlockRotation(block, Editor::GetBlockRotation(block) + itemRotMod);
                } else {
                    warn('nudge non-free block');
                }
            } else {
                warn("Unhandled nod type to nudge!!!");
                if (nod !is null) {
                    warn("Type: " + Reflection::TypeOf(nod).Name);
                }
            }
            // update and fix picked item (will be replaced)
            auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
            Editor::RefreshBlocksAndItems(editor);

            if (item !is null) {
                // the updated item will be the last item in the array and has a new pointer
                // items that weren't updated keep the same pointer
                @lastPickedItem = ReferencedNod(editor.Challenge.AnchoredObjects[editor.Challenge.AnchoredObjects.Length - 1]);
                UpdatePickedItemCachedValues();
            } else if (block !is null) {
                @lastPickedBlock = ReferencedNod(editor.Challenge.Blocks[editor.Challenge.Blocks.Length - 1]);
                UpdatePickedBlockCachedValues();
            }
        }
    }

}
