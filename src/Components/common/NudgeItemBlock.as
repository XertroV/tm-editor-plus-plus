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
                item.MwAddRef();
                // ! this works now but it does not repick a picked item
                auto itemSpecOrig = Editor::ItemSpecPriv(item);
                // we need to delete it first so that track map changes stays accurate.
                if (!Editor::DeleteBlocksAndItems({}, {itemSpecOrig})) {
                    warn("Failed to delete item for nudge");
                }
                item.BlockUnitCoord = PosToCoord(item.AbsolutePositionInMap);
                item.AbsolutePositionInMap += itemPosMod;
                item.Pitch += itemRotMod.x;
                item.Yaw += itemRotMod.y;
                item.Roll += itemRotMod.z;
                auto newItemSpec = Editor::ItemSpecPriv(item);
                if (!Editor::PlaceBlocksAndItems({}, {newItemSpec}, true)) {
                    warn("Failed to place item for nudge");
                }
                item.MwRelease();
            } else if (block !is null) {
                block.MwAddRef();
                auto blockSpec = Editor::MakeBlockSpec(block);
                // we need to delete it first so that track map changes stays accurate.
                Editor::DeleteBlocks({block});
                // we want to update the block as well as the spec so that we can re-find it again after refreshing.
                if (blockSpec.isFree) {
                    blockSpec.pos += itemPosMod;
                    blockSpec.pyr += itemRotMod;
                    Editor::SetBlockLocation(block, blockSpec.pos);
                    Editor::SetBlockRotation(block, blockSpec.pyr);
                } else {
                    blockSpec.pos += CoordDistToPos(blockCoordMod);
                    blockSpec.coord.x += blockCoordMod.x;
                    blockSpec.coord.y += blockCoordMod.y;
                    blockSpec.coord.z += blockCoordMod.z;
                    block.CoordX = blockSpec.coord.x;
                    block.CoordY = blockSpec.coord.y;
                    block.CoordZ = blockSpec.coord.z;
                    blockSpec.dir = CGameCtnBlock::ECardinalDirections(m_dir);
                    block.BlockDir = blockSpec.dir;
                }
                if (!Editor::PlaceBlocksAndItems({blockSpec}, {}, !blockSpec.isFree)) {
                    warn("Failed to place block for nudge");
                }
                block.MwRelease();
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
