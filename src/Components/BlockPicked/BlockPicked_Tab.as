class FocusedBlockTab : Tab, NudgeItemBlock {
    private ReferencedNod@ pinnedBlock;

    FocusedBlockTab(TabGroup@ parent) {
        super(parent, "Picked Block", Icons::Crosshairs + Icons::Cube);
        removable = true;
    }

    ReferencedNod@ get_FocusedBlock() {
        return pinnedBlock;
    }

    void set_FocusedBlock(ReferencedNod@ value) {
        @pinnedBlock = value;
    }

    // ! use block desc instead

    // // cache stuff to try and refind blocks on refresh
    // private vec3 fb_Pos;
    // private vec3 fb_Rot;
    // private bool fb_IsGhost;
    // private bool fb_IsGround;
    // private string fb_BlockName;
    // void CacheFocusedBlockProps() {
    //     auto block = FocusedBlock.AsBlock();
    //     fb_Pos = Editor::GetBlockLocation(block);
    //     fb_Rot = Editor::GetBlockRotation(block);
    //     fb_IsGhost = block.IsGhostBlock();
    //     fb_IsGround = block.IsGround;
    //     fb_BlockName = block.BlockInfo.Name;
    // }

    // bool CachedMatchesBlock(CGameCtnBlock@ block) {
    //     return block.BlockInfo.Name == fb_BlockName
    //         && Math::Vec3Eq(fb_Pos, Editor::GetBlockLocation(block))
    //         && Math::Vec3Eq(fb_Rot, Editor::GetBlockRotation(block))
    //         && fb_IsGround == block.IsGround
    //         && fb_IsGhost == block.IsGhostBlock()
    //         ;
    // }


    private bool showHelpers = true;
    bool get_ShowHelpers() {
        return showHelpers;
    }
    void set_ShowHelpers(bool value) {
        showHelpers = value;
    }

    private bool showBlockBox = true;
    bool get_ShowBlockBox() {
        return showBlockBox;
    }
    void set_ShowBlockBox(bool value) {
        showBlockBox = value;
    }

    protected bool m_BlockChanged = false;

    void DrawInner() override {
        CGameCtnEditorFree@ editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (FocusedBlock is null || FocusedBlock.AsBlock() is null || editor is null) {
            UI::Text("No picked block. Ctrl+Hover to pick a block.");
            return;
        }
        auto block = FocusedBlock.AsBlock();
        auto pos = Editor::GetBlockLocation(block);
        auto rot = Editor::GetBlockRotation(block);

        CopiableLabeledValue("Coord", block.Coord.ToString());
        CopiableLabeledValue("Pos", pos.ToString());
        CopiableLabeledValue("Rot", rot.ToString());
        LabeledValue("Is Ghost", block.IsGhostBlock());
        LabeledValue("Is Ground", block.IsGround);
        LabeledValue("Variant", block.BlockInfoVariantIndex);
        LabeledValue("Mobil Variant", block.MobilVariantIndex);

        UI::Separator();

        ShowHelpers = UI::Checkbox("Draw block rotation helpers##" + idNonce, ShowHelpers);
        ShowBlockBox = UI::Checkbox("Draw block box##" + idNonce, ShowBlockBox);

        auto m = mat4::Translate(pos) * EulerToMat(rot);

        if (ShowBlockBox) {
            nvgDrawBlockBox(m, lastPickedBlockSize);
            nvgDrawBlockBox(m, vec3(32, 8, 32));
        }
        if (ShowHelpers) {
            nvg::StrokeWidth(3);
            nvgMoveToWorldPos(pos);
            nvgDrawCoordHelpers(m);
            // nvgDrawCoordHelpers(m * mat4::Translate(vec3(16, 2, 16)));
        }

        UI::Separator();

        UI::Text("Set Block Props:");

        vec3 prePos = Editor::GetBlockLocation(block);
        vec3 preRot = Editor::GetBlockRotation(block);

        if (Editor::IsBlockFree(block)) {
            Editor::SetBlockLocation(block, UI::InputFloat3("Pos.##pos" + idNonce, Editor::GetBlockLocation(block)));
            Editor::SetBlockRotation(block, UX::InputAngles3("Rot (Deg)##rot" + idNonce, Editor::GetBlockRotation(block)));
        } else {
            block.CoordX = UI::InputInt("CoordX##" + idNonce, block.CoordX);
            block.CoordY = UI::InputInt("CoordY##" + idNonce, block.CoordY);
            block.CoordZ = UI::InputInt("CoordZ##" + idNonce, block.CoordZ);
            if (UI::BeginCombo("BlockDir##" + idNonce, tostring(block.BlockDir))) {
                for (uint i = 0; i < 4; i++) {
                    if (UI::Selectable(tostring(CGameCtnBlock::ECardinalDirections(i)), uint(block.BlockDir) == i)) {
                        block.BlockDir = CGameCtnBlock::ECardinalDirections(i);
                    }
                }
                UI::EndCombo();
            }
        }
        auto preCol = block.MapElemColor;
        block.MapElemColor = DrawEnumColorChooser(block.MapElemColor);

        m_BlockChanged = preCol != block.MapElemColor
            || !Math::Vec3Eq(prePos, Editor::GetBlockLocation(block))
            || !Math::Vec3Eq(preRot, Editor::GetBlockRotation(block));

        if (m_BlockChanged) {
            trace('Updating picked/pinned block');
            // ensure we dereference the block by nullifying FocusedBlock first -- can cause a crash when changing normal block positions (seems okay otherwise), apparently b/c the block memory is cleared when it otherwise wouldn't be
            @FocusedBlock = null;
            // // add a reference for testing -- will leak memory but not much
            // block.MwAddRef();
            @block = Editor::RefreshSingleBlockAfterModified(editor, block);
            trace('Return block null? ' + tostring(block is null));
            if (block is null) {
                @FocusedBlock = null;
            } else {
                @FocusedBlock = ReferencedNod(block);
            }
        }

        // UI::BeginDisabled(!m_BlockChanged);
        // if (UI::Button("Refresh All##blocks" + idNonce)) {
        //     trace('refreshing blocks; changed:');
        //     @lastPickedBlock = null;
        //     @block = null;
        //     Editor::RefreshBlocksAndItems(editor);
        //     trace('refresh done');
        //     if (m_BlockChanged) {
        //         @lastPickedBlock = ReferencedNod(editor.Challenge.Blocks[editor.Challenge.Blocks.Length - 1]);
        //         UpdatePickedBlockCachedValues();
        //         trace('updated last picked block');
        //         @block = lastPickedBlock.AsBlock();
        //     } else {
        //         trace('block not changed');
        //     }
        // }
        // AddSimpleTooltip("Note! This may not reliably find the block again. \\$f80Warning: \\$zAll pinned blocks will be cleared. \\$888Todo: use block coords to find block again.");
        // UI::EndDisabled();

        if (block is null) return;

        UI::Separator();
        if (Editor::IsBlockFree(block)) {
            UI::Text("Nudge block:");
            DrawNudgeFor(block);
        } else {
            UI::Text("Cannot nudge non-free blocks.");
        }
    }
}

class PickedBlockTab : FocusedBlockTab {
    PickedBlockTab(TabGroup@ parent) {
        super(parent);
        removable = false;
    }

    bool get_ShowHelpers() override property {
        return S_DrawPickedBlockHelpers;
    }
    void set_ShowHelpers(bool value) override property {
        S_DrawPickedBlockHelpers = value;
    }
    bool get_ShowBlockBox() override property {
        return S_DrawPickedBlockBox;
    }
    void set_ShowBlockBox(bool value) override property {
        S_DrawPickedBlockBox = value;
    }

    ReferencedNod@ get_FocusedBlock() override property {
        return lastPickedBlock;
    }

    void set_FocusedBlock(ReferencedNod@ value) override property {
        @lastPickedBlock = value;
        if (value !is null) {
            UpdatePickedBlockCachedValues();
        }
    }
}

class PinnedBlockTab : FocusedBlockTab {
    PinnedBlockTab(TabGroup@ parent, CGameCtnBlock@ block) {
        super(parent);
        removable = false;
        @FocusedBlock = ReferencedNod(block);
    }
}
