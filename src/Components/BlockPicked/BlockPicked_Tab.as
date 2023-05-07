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
        BlockDesc@ preDesc = BlockDesc(block);
        // Editor::UpdateBakedBlocksMatching(editor, preDesc, preDesc);

        CopiableLabeledValue("Coord", block.Coord.ToString());
        CopiableLabeledValue("Pos", preDesc.Pos.ToString());
        CopiableLabeledValue("Rot", Math::ToDeg(preDesc.Rot).ToString());
        LabeledValue("Is Ghost", block.IsGhostBlock());
        LabeledValue("Is Ground", block.IsGround);
        LabeledValue("Variant", block.BlockInfoVariantIndex);
        LabeledValue("Mobil Variant", block.MobilVariantIndex);

        UI::Separator();

        ShowHelpers = UI::Checkbox("Draw block rotation helpers##" + idNonce, ShowHelpers);
        ShowBlockBox = UI::Checkbox("Draw block box##" + idNonce, ShowBlockBox);

        auto m = mat4::Translate(preDesc.Pos) * EulerToMat(preDesc.Rot);

        if (ShowBlockBox) {
            nvgDrawBlockBox(m, lastPickedBlockSize);
            nvgDrawBlockBox(m, vec3(32, 8, 32));
        }
        if (ShowHelpers) {
            nvg::StrokeWidth(3);
            nvgMoveToWorldPos(preDesc.Pos);
            nvgDrawCoordHelpers(m);
            // nvgDrawCoordHelpers(m * mat4::Translate(vec3(16, 2, 16)));
            nvgCircleWorldPos(Editor::GetCtnBlockMidpoint(block));
        }

        UI::Separator();

        UI::Text("Set Block Props:");

        bool safeToRefresh = false;

        if (Editor::IsBlockFree(block)) {
            Editor::SetBlockLocation(block, UI::InputFloat3("Pos.##pos" + idNonce, Editor::GetBlockLocation(block)));
            Editor::SetBlockRotation(block, UX::InputAngles3("Rot (Deg)##rot" + idNonce, Editor::GetBlockRotation(block)));
        } else {
            // if (!block.IsGhostBlock()) {
                // UI::TextWrapped("\\$f80Warning!\\$z Modifying non-free, non-ghost blocks *might* cause a crash if *other* plugins keep a reference to this block around. Other plugin devs should consult the Editor++ documentation.");
                // UI::TextWrapped("Blocks on pillars seem to cause crashes always.");
            // }
            UI::TextWrapped("\\$f80Warning!\\$z Modifying non-free blocks *might* cause a crash. You *must* save and load the map after changing these. \\$f80No live updates!");
            safeToRefresh = false;

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

        block.MapElemColor = DrawEnumColorChooser(block.MapElemColor);
        block.MapElemLmQuality = DrawEnumLmQualityChooser(block.MapElemLmQuality);

        auto @desc = BlockDesc(block);

        m_BlockChanged = preDesc.Color != block.MapElemColor
            || !Math::Vec3Eq(preDesc.Pos, desc.Pos)
            || !Math::Vec3Eq(preDesc.Rot, desc.Rot)
            ;


        UI::Separator();
        if (Editor::IsBlockFree(block)) {
            UI::Text("Nudge block:");
            m_BlockChanged = m_BlockChanged || DrawNudgeFor(block);
        } else {
            UI::Text("Cannot nudge non-free blocks.");
        }

        if (m_BlockChanged) trace('block changed');

        if (m_BlockChanged && safeToRefresh) {
            trace('Updating picked/pinned block');
            // ensure we dereference the block by nullifying FocusedBlock first -- can cause a crash when changing normal block positions (seems okay otherwise), apparently b/c the block memory is cleared when it otherwise wouldn't be
            @block = null;
            FocusedBlock.NullifyNoRelease();
            @FocusedBlock = null;
            // // add a reference for testing -- will leak memory but not much
            // block.MwAddRef();
            trace('cleared focus block, refreshing now');
            // Editor::UpdateBakedBlocksMatching(editor, preDesc, desc);
            @block = Editor::RefreshSingleBlockAfterModified(editor, desc);
            trace('Return block null? ' + tostring(block is null));
            if (block !is null) {
                @FocusedBlock = ReferencedNod(block);
            }
        } else if (m_BlockChanged && !safeToRefresh) {
            @tmpDesc = desc;
            // @block = null;
            // @FocusedBlock = null;
            // startnew(CoroutineFunc(RefreshSoonAsync));
            Editor::MarkRefreshUnsafe();
        }
    }

    BlockDesc@ tmpDesc;
    void RefreshSoonAsync() {
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (tmpDesc is null || editor is null) return;
        @FocusedBlock = null;
        // // add a reference for testing -- will leak memory but not much
        // block.MwAddRef();
        trace('async: cleared focus block, refreshing now');
        auto block = Editor::RefreshSingleBlockAfterModified(editor, tmpDesc);
        trace('Return block null? ' + tostring(block is null));
        if (block !is null) {
            @FocusedBlock = ReferencedNod(block);
        }
    }
}

[Setting hidden]
bool S_PickedBlockWindowOpen = false;

class PickedBlockTab : FocusedBlockTab {
    PickedBlockTab(TabGroup@ parent) {
        super(parent);
        removable = false;
    }

    bool get_windowOpen() override property {
        if (S_PickedBlockWindowOpen == tabOpen) {
            tabOpen = !S_PickedBlockWindowOpen;
        }
        return S_PickedBlockWindowOpen;
    }

    void set_windowOpen(bool value) override property {
        tabOpen = !value;
        S_PickedBlockWindowOpen = value;
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
