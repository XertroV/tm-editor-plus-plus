class ApplyRotationTab : GenericApplyTab {

    ApplyRotationTab(TabGroup@ p) {
        super(p, "Rotate Map", Icons::Magic + Icons::Refresh);
    }

    int2 centralCoord = int2(24, 24);
    // 90deg increments
    int rotationAmount = 1;

    void DrawInner() override {
        UI::TextWrapped("Rotate all blocks/items in the map around a central point (must be on-grid)");

        UI::Separator();

        centralCoord = UX::InputInt2XYZ("Rotate Around (X/Z)", centralCoord);
        rotationAmount = Math::Max(1, UI::InputInt("90 Degree Increments", rotationAmount)) % 4;

        UI::Separator();

        if (UI::Button("Rotate")) {
            startnew(CoroutineFunc(this.ApplyRotation));
        }
    }

    void ApplyRotation() {
        auto mapMb = Editor::GetMapAsMacroblock();
        for (uint i = 0; i < mapMb.macroblock.Blocks.Length; i++) {
            RotateMapElement(mapMb.macroblock.Blocks[i]);
        }
        for (uint i = 0; i < mapMb.macroblock.Items.Length; i++) {
            RotateMapElement(mapMb.macroblock.Items[i]);
        }
        for (uint i = 0; i < mapMb.setSkins.Length; i++) {
            RotateMapElement(mapMb.setSkins[i].block);
            RotateMapElement(mapMb.setSkins[i].item);
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto pmt = editor.PluginMapType;
        pmt.AutoSave();
        editor.SuperSweepAndSave();
        if (!Editor::PlaceMacroblock(mapMb.macroblock, false)) {
            NotifyWarning("Failed to place macroblock");
        }
        if (!Editor::SetSkins(mapMb.setSkins)) {
            NotifyWarning("Failed to set skins");
        }
        pmt.AutoSave();
    }

    void RotateMapElement(Editor::BlockSpec@ block) {
        if (block is null) return;
        block.flags = uint8(Editor::BlockFlags::Free);

        if (block.isFree) {
            auto cc = CoordToPos(nat3(centralCoord.x, 0, centralCoord.y));
            cc.y = block.pos.y;
            auto nextPos = RotateRelPosBy90s(block.pos - cc, rotationAmount);
            auto blockRot = EulerToMat(block.pyr);
            auto extraRot = mat4::Rotate(PI * -.5 * float(rotationAmount), UP);
            block.pyr = PitchYawRollFromRotationMatrix(extraRot * blockRot);
            block.pos = cc + nextPos;
        } else {
            auto cc = CoordToPos(nat3(centralCoord.x, 8, centralCoord.y));
            auto coordSize = Editor::GetBlockCoordSize(block);
            auto blockPos = Editor::GetBlockLocation(block);
            auto nextPos = RotateRelPosBy90s(blockPos - cc, rotationAmount);
            auto blockRot = vec3(0, CardinalDirectionToYaw(int(block.dir)), 0);
            auto extraRot = vec3(0, PI * -.5 * float(rotationAmount), 0);
            auto newDir = CGameCtnBlock::ECardinalDirections((int(block.dir) + rotationAmount) % 4);
            // block.coord = Editor::BlockPosAndCoordSizeToCoord(cc + nextPos, coordSize, newDir);
            block.dir = newDir;
            block.dir2 = newDir;

            // auto cc = int3(centralCoord.x, block.coord.y, centralCoord.y);
            // auto nextCoord = Nat3ToInt3(block.coord) - cc;
            // switch (rotationAmount % 4) {
            //     case 1:
            //         nextCoord = int3(-nextCoord.z, nextCoord.y, nextCoord.x);
            //         break;
            //     case 2:
            //         nextCoord = int3(-nextCoord.x, nextCoord.y, -nextCoord.z);
            //         break;
            //     case 3:
            //         nextCoord = int3(nextCoord.z, nextCoord.y, -nextCoord.x);
            //         break;
            // }
            // block.coord = Int3ToNat3(cc + nextCoord);
            // block.dir = CGameCtnBlock::ECardinalDirections((block.dir + rotationAmount) % 4);
            // block.dir2 = CGameCtnBlock::ECardinalDirections((block.dir + rotationAmount) % 4);
        }
    }

    void RotateMapElement(Editor::ItemSpec@ item) {
        if (item is null) return;
        auto cc = CoordToPos(nat3(centralCoord.x, 0, centralCoord.y)) + HALF_COORD;
        cc.y = item.pos.y;
        auto nextPos = RotateRelPosBy90s(item.pos - cc, rotationAmount);
        auto itemRot = EulerToMat(item.pyr);
        auto extraRot = mat4::Rotate(PI * .5 * float(rotationAmount), UP);
        item.pyr = PitchYawRollFromRotationMatrix(extraRot * itemRot);
        item.pos = cc + nextPos;
    }

    vec3 RotateRelPosBy90s(vec3 pos, int amount) {
        switch (amount % 4) {
            case 1: return vec3(-pos.z, pos.y, pos.x);
            case 2: return vec3(-pos.x, pos.y, -pos.z);
            case 3: return vec3(pos.z, pos.y, -pos.x);
        }
        return pos;
    }
}
