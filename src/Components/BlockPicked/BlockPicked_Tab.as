class FocusedBlockTab : Tab, NudgeItemBlock {
    private ReferencedNod@ pinnedBlock;

    FocusedBlockTab(TabGroup@ parent) {
        super(parent, "Picked Block", "\\$f44" + Icons::Crosshairs + "\\$z" + Icons::Cube);
        removable = true;
        SetupFav(InvObjectType::Block);
    }

    ReferencedNod@ get_FocusedBlock() {
        return pinnedBlock;
    }

    void set_FocusedBlock(ReferencedNod@ value) {
        @pinnedBlock = value;
    }


    bool get_favEnabled() override property {
        return FocusedBlock !is null && FocusedBlock.nod !is null;
    }

    string GetFavIdName() override {
        return FocusedBlock.AsBlock().BlockInfo.IdName;
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
    //         && MathX::Vec3Eq(fb_Pos, Editor::GetBlockLocation(block))
    //         && MathX::Vec3Eq(fb_Rot, Editor::GetBlockRotation(block))
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

        UI::TextWrapped("\\$f80Warning! \\$zRefreshing blocks can sometimes result in a crash. To disable auto-refresh, uncheck 'Save to refresh' under the 'Advanced' menu. Some maps are prone to this, but most are okay.");
        UI::Separator();

        auto block = FocusedBlock.AsBlock();

        // if this is true the block was removed from the map
        if (Reflection::GetRefCount(block) == 1) {
            @FocusedBlock = null;
            return;
        }

        BlockDesc@ preDesc = BlockDesc(block);
        // Editor::UpdateBakedBlocksMatching(editor, preDesc, preDesc);

        m_BlockChanged = false;

        UI::Columns(2);

        CopiableLabeledValue("Type", block.DescId.GetName());
        CopiableLabeledValue("Coord", block.Coord.ToString());
        CopiableLabeledValue("Pos", preDesc.Pos.ToString());
        CopiableLabeledValue("Rot", MathX::ToDeg(preDesc.Rot).ToString());
        UI::BeginDisabled(preDesc.IsFree);
        if (UX::SmallButton("Convert to Free")) {
            startnew(CoroutineFunc(ConvertBlockToFree));
        }
        UI::EndDisabled();

#if SIG_DEVELOPER
        if (UX::SmallButton(Icons::Cube + "Explore Block")) {
            ExploreNod(block.DescId.GetName(), block);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(block)));
#endif

        UI::Text(Editor::IsBlockFree(block) ? "Free" : block.IsGhostBlock() ? "Ghost" : "Normal");
        UI::SameLine();
        UI::Text(block.IsGround ? "/ Ground" : "/ Not Ground");
        LabeledValue("Variant", block.BlockInfoVariantIndex);
        UI::SameLine();
        LabeledValue("Mobil Variant", block.MobilVariantIndex);
        UI::SameLine();
        LabeledValue("Mobil Index", block.MobilIndex);
        auto mbInstId = Editor::GetBlockMbInstId(block);
        LabeledValue("MB Inst ID", mbInstId);
        if (mbInstId >= 0) {
            UI::SameLine();
            if (UX::SmallButton("Clear")) {
                Editor::SetBlockMbInstId(block, -1);
            }
        }

        UI::NextColumn();

        if (UX::SmallButton("Edit This Block")) {
            Editor::OpenItemEditor(editor, block.BlockModel);
        }
        if (UX::SmallButton("Edit This Block (Method 2)")) {
            startnew(Editor::OpenItemEditorMethod2Ref, block.BlockModel);
        }

        if (block.BlockInfo !is null) {
            ItemModelTreeElement(null, -1, block.BlockInfo.MaterialModifier, "Material Modifier", true, O_BLOCKINFO_MATERIALMOD).Draw();
            ItemModelTreeElement(null, -1, block.BlockInfo.MaterialModifier2, "Material Modifier 2", true, O_BLOCKINFO_MATERIALMOD2).Draw();
        }

#if SIG_DEVELOPER
        if (UI::Button(Icons::Cube + " BlockInfo")) {
            ExploreNod("Info: " + block.DescId.GetName(), block.BlockInfo);
        }
        UI::SameLine();
        CopiableLabeledValue("ptr", Text::FormatPointer(Dev_GetPointerForNod(block.BlockInfo)));
#endif
        UI::Columns(1);

        if (block.Skin is null) {
            UI::TextDisabled("No Skin");
        } else {
            ItemModelTreeElement(null, -1, block.Skin, "Skin", true, O_CTNBLOCK_SKIN).Draw();
        }

        UI::Separator();

        ShowHelpers = UI::Checkbox("Draw block rotation helpers##" + idNonce, ShowHelpers);
        ShowBlockBox = UI::Checkbox("Draw block box##" + idNonce, ShowBlockBox);

        auto m = mat4::Translate(preDesc.Pos) * EulerToMat(preDesc.Rot);

        if (ShowBlockBox) {
            nvgDrawBlockBox(m, lastPickedBlockSize);
            nvgDrawBlockBox(m, vec3(32, 8, 32));
            // test code for rotate map
            // auto m2 = mat4::Translate(CoordToPos(nat3(24, 8, 24))) * EulerToMat(vec3(0, PI/2., 0.)) * mat4::Translate(CoordToPos(vec3(-24, 8, -24))) * m;
            // nvgDrawBlockBox(m2, lastPickedBlockSize);
            // nvgDrawBlockBox(m2, vec3(32, 8, 32));
            // nvgDrawCoordHelpers(m2);

            // auto pos = (m2 * vec3()).xyz;
            // auto rot = vec3(0, CardinalDirectionToYaw(int(block.Dir) - 1), 0);
            // auto coord = Editor::BlockPosAndCoordSizeToCoord(pos, Editor::GetBlockCoordSize(block), int(block.Dir) - 1);
            // auto m3 = mat4::Translate(CoordToPos(coord)) * EulerToMat(rot);
            // nvgDrawBlockBox(m3, Editor::GetBlockCoordSize(block) * MAP_COORD, cCyan);
            // nvgDrawBlockBox(m3, MAP_COORD, cCyan);
        }
        if (ShowHelpers) {
            nvg::StrokeWidth(3);
            nvgMoveToWorldPos(preDesc.Pos);
            nvgDrawCoordHelpers(m);
            // nvgDrawCoordHelpers(m * mat4::Translate(vec3(16, 2, 16)));
            nvgCircleWorldPos(Editor::GetCtnBlockMidpoint(block));
        }

        UI::Separator();

        UI::PushItemWidth(G_GetSmallerInputWidth());

        UI::Text("Set Block Props:");

        bool safeToRefresh = true;

        if (Editor::IsBlockFree(block)) {
            Editor::SetBlockLocation(block, UX::InputFloat3("Pos.##pos" + idNonce, Editor::GetBlockLocation(block)));
            Editor::SetBlockRotation(block, UX::InputAngles3("Rot (Deg)##rot" + idNonce, Editor::GetBlockRotation(block)));
        } else {
            // if (!block.IsGhostBlock()) {
                // UI::TextWrapped("\\$f80Warning!\\$z Modifying non-free, non-ghost blocks *might* cause a crash if *other* plugins keep a reference to this block around. Other plugin devs should consult the Editor++ documentation.");
                // UI::TextWrapped("Blocks on pillars seem to cause crashes always.");
            // }
            UI::TextWrapped("\\$f80Warning!\\$z Modifying non-free blocks *might* cause a crash when refreshing. You *must* save and load the map after changing these. \\$f80No live updates!");
            UI::TextWrapped("(Note: direction and color seem to be almost always okay to refresh, so these will refresh.)");
            safeToRefresh = false;

            block.CoordX = UI::InputInt("CoordX##" + idNonce, block.CoordX);
            block.CoordY = UI::InputInt("CoordY##" + idNonce, block.CoordY);
            block.CoordZ = UI::InputInt("CoordZ##" + idNonce, block.CoordZ);
            if (UI::BeginCombo("BlockDir##" + idNonce, tostring(block.BlockDir))) {
                for (uint i = 0; i < 4; i++) {
                    if (UI::Selectable(tostring(CGameCtnBlock::ECardinalDirections(i)), uint(block.BlockDir) == i)) {
                        block.BlockDir = CGameCtnBlock::ECardinalDirections(i);
                        safeToRefresh = true;
                    }
                }
                UI::EndCombo();
            }
        }

        block.MapElemLmQuality = DrawEnumLmQualityChooser(block.MapElemLmQuality);
        block.MapElemColor = DrawEnumColorChooser(block.MapElemColor);

        bool blockNudged = false;
        UI::Separator();
        UI::Text("Nudge block:");
        blockNudged = DrawNudgeFor(block);
        m_BlockChanged = blockNudged || m_BlockChanged;
        if (m_BlockChanged) {
            dev_trace('Nudge block: changed');
            if (Editor::IsBlockFree(block)) {
                startnew(CoroutineFunc(CheckDeleteFreeblockAfterNudge)).WithRunContext(Meta::RunContext::MainLoop);
            }
            safeToRefresh = true;
        }

        auto @desc = BlockDesc(block);

        m_BlockChanged = m_BlockChanged
            || !MathX::Vec3Eq(preDesc.Pos, desc.Pos)
            || !MathX::Vec3Eq(preDesc.Rot, desc.Rot)
            ;

        // UI::Text("m_BlockChanged: " + m_BlockChanged);

        if (!m_BlockChanged && preDesc.Color != block.MapElemColor) {
            safeToRefresh = true;
            m_BlockChanged = true;
        }

#if DEV
        if (m_BlockChanged) {
            // dev_trace('block changed');
            // dev_trace('poss: ' + preDesc.Pos.ToString() + " -> " + desc.Pos.ToString());
            // dev_trace('pos changed: ' + !MathX::Vec3Eq(preDesc.Pos, desc.Pos));
            // dev_trace('rots: ' + preDesc.Rot.ToString() + " -> " + desc.Rot.ToString());
            // dev_trace('rot changed: ' + !MathX::Vec3Eq(preDesc.Rot, desc.Rot));
            // dev_trace('rot delta len sq: ' + (preDesc.Rot - desc.Rot).LengthSquared());
            // dev_trace('rot delta len sq: ' + ((preDesc.Rot - desc.Rot).LengthSquared() < 1e10));
            // dev_trace('color changed: ' + (preDesc.Color != block.MapElemColor));
        }
#endif

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
            @block = blockNudged ? editor.Challenge.Blocks[editor.Challenge.Blocks.Length - 1] : Editor::RefreshSingleBlockAfterModified(editor, desc);
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

        UI::PopItemWidth();
    }

    void ConvertBlockToFree() {
        auto block = FocusedBlock.AsBlock();
        if (block is null) return;
        @FocusedBlock = ReferencedNod(Editor::ConvertBlockToFree(block));
    }

    void CheckDeleteFreeblockAfterNudge() {
        if (Editor::HasPendingFreeBlocksToDelete()) {
            Editor::RunDeleteFreeBlockDetection();
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor.Challenge.Blocks.Length > 0)
            @FocusedBlock = ReferencedNod(editor.Challenge.Blocks[editor.Challenge.Blocks.Length - 1]);
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
