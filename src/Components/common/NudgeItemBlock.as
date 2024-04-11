mixin class NudgeItemBlock {
    float m_PosStepSize = 0.1;
    float m_RotStepSize = .01745;
    int m_CoordStepSize = 1;

    // draw preferably draw as final thing as can invalidate item/block reference
    bool DrawNudgeFor(CMwNod@ nod) {
        auto item = cast<CGameCtnAnchoredObject>(nod);
        auto block = cast<CGameCtnBlock>(nod);
        bool isFree = item !is null || (block !is null && Editor::IsBlockFree(block));

        vec3 itemPosMod = vec3();
        vec3 itemRotMod = vec3();
        int3 blockCoordMod = int3();
        int m_dir = 0;

        if (!isFree) {
            m_CoordStepSize = Math::Clamp(UI::InputInt("Coord. Step Size", m_CoordStepSize, 1), 1, 100);
        } else {
            m_PosStepSize = UI::InputFloat("Pos. Step Size", m_PosStepSize, 0.01);
            m_RotStepSize = Math::ToRad(UI::InputFloat("Rot. Step Size (D)", Math::ToDeg(m_RotStepSize), 0.1));
        }

        UI::AlignTextToFramePadding();
        UI::Text(isFree ? "Pos:" : "Coord:");
        UI::SameLine();
        if (UI::ButtonColored("X+", hueRed)) {
            if (isFree) itemPosMod = vec3(m_PosStepSize, 0, 0);
            else blockCoordMod = int3(m_CoordStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("X-", hueRed)) {
            if (isFree) itemPosMod = vec3(-m_PosStepSize, 0, 0);
            else blockCoordMod = int3(-m_CoordStepSize, 0, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Y+", hueGreen)) {
            if (isFree) itemPosMod = vec3(0, m_PosStepSize, 0);
            else blockCoordMod = int3(0, m_CoordStepSize, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Y-", hueGreen)) {
            if (isFree) itemPosMod = vec3(0, -m_PosStepSize, 0);
            else blockCoordMod = int3(0, -m_CoordStepSize, 0);
        }
        UI::SameLine();
        if (UI::ButtonColored("Z+", hueBlue)) {
            if (isFree) itemPosMod = vec3(0, 0, m_PosStepSize);
            else blockCoordMod = int3(0, 0, m_CoordStepSize);
        }
        UI::SameLine();
        if (UI::ButtonColored("Z-", hueBlue)) {
            if (isFree) itemPosMod = vec3(0, 0, -m_PosStepSize);
            else blockCoordMod = int3(0, 0, -m_CoordStepSize);
        }

        if (isFree) {
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
        } else {
            auto currDir = int(block.Direction);
            m_dir = currDir;
            UI::AlignTextToFramePadding();
            UI::Text("Dir:");
            UI::SameLine();
            if (UI::ButtonColored("North", currDir == 0 ? hueGreen : hueBlue)) {
                m_dir = 0;
            }
            UI::SameLine();
            if (UI::ButtonColored("East", currDir == 1 ? hueGreen : hueBlue)) {
                m_dir = 1;
            }
            UI::SameLine();
            if (UI::ButtonColored("South", currDir == 2 ? hueGreen : hueBlue)) {
                m_dir = 2;
            }
            UI::SameLine();
            if (UI::ButtonColored("West", currDir == 3 ? hueGreen : hueBlue)) {
                m_dir = 3;
            }
        }

        if (itemPosMod.LengthSquared() > 0 || itemRotMod.LengthSquared() > 0 || blockCoordMod.x != 0 || blockCoordMod.y != 0 || blockCoordMod.z != 0 || (block !is null && m_dir != int(block.Direction))) {
            if (item !is null) {
                // ! this works now but it does not repick a picked item
                auto newItemSpec = Editor::ItemSpecPriv(item);
                if (!Editor::DeleteBlocksAndItems({}, {Editor::ItemSpecPriv(item)})) {
                    warn("Failed to delete item for nudge");
                }
                newItemSpec.pos += itemPosMod;
                newItemSpec.pyr += itemRotMod;
                if (!Editor::PlaceBlocksAndItems({}, {newItemSpec}, true)) {
                    warn("Failed to place item for nudge");
                }

                // item.AbsolutePositionInMap += itemPosMod;
                // item.Pitch += itemRotMod.x;
                // item.Yaw += itemRotMod.y;
                // item.Roll += itemRotMod.z;
            } else if (block !is null) {
                auto blockSpec = Editor::MakeBlockSpec(block);
                Editor::DeleteBlocks({block});
                if (blockSpec.isFree) {
                    blockSpec.pos += itemPosMod;
                    blockSpec.pyr += itemRotMod;
                } else {
                    blockSpec.pos += CoordDistToPos(blockCoordMod);
                    blockSpec.coord.x += blockCoordMod.x;
                    blockSpec.coord.y += blockCoordMod.y;
                    blockSpec.coord.z += blockCoordMod.z;
                    blockSpec.dir = CGameCtnBlock::ECardinalDirections(m_dir);
                }
                if (!Editor::PlaceBlocksAndItems({blockSpec}, {}, !blockSpec.isFree)) {
                    warn("Failed to place block for nudge");
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
