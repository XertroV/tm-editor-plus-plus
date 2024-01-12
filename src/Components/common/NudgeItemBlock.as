const float hueRed = 0.0;
const float hueGreen = 0.3;
const float hueBlue = 0.6;

mixin class NudgeItemBlock {
    float m_PosStepSize = 0.1;
    float m_RotStepSize = .01745;

    // draw preferably draw as final thing as can invalidate item/block reference
    bool DrawNudgeFor(CMwNod@ nod) {
        auto item = cast<CGameCtnAnchoredObject>(nod);
        auto block = cast<CGameCtnBlock>(nod);

        vec3 itemPosMod = vec3();
        vec3 itemRotMod = vec3();

        m_PosStepSize = UI::InputFloat("Pos. Step Size", m_PosStepSize, 0.01);
        m_RotStepSize = Math::ToRad(UI::InputFloat("Rot. Step Size (D)", Math::ToDeg(m_RotStepSize), 0.1));

        UI::AlignTextToFramePadding();
        UI::Text("Pos:");
        UI::SameLine();
        if (UI::ButtonColored("X+", hueRed)) {
            itemPosMod = vec3(m_PosStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("X-", hueRed)) {
            itemPosMod = vec3(-m_PosStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Y+", hueGreen)) {
            itemPosMod = vec3(0, m_PosStepSize, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Y-", hueGreen)) {
            itemPosMod = vec3(0, -m_PosStepSize, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Z+", hueBlue)) {
            itemPosMod = vec3(0, 0, m_PosStepSize);
        }
        UI::SameLine();
        if (UI::ButtonColored("Z-", hueBlue)) {
            itemPosMod = vec3(0, 0, -m_PosStepSize);
        }

        UI::AlignTextToFramePadding();
        UI::Text("Rot:");
        UI::SameLine();
        if (UI::ButtonColored("P+", hueRed)) {
            itemRotMod = vec3(m_RotStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("P-", hueRed)) {
            itemRotMod = vec3(-m_RotStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Y+##yaw", hueGreen)) {
            itemRotMod = vec3(0, m_RotStepSize, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Y-##yaw", hueGreen)) {
            itemRotMod = vec3(0, -m_RotStepSize, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("R+", hueBlue)) {
            itemRotMod = vec3(0, 0, m_RotStepSize);
        }
        UI::SameLine();
        if (UI::ButtonColored("R-", hueBlue)) {
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
            return true;
        }
        return false;
    }
}
