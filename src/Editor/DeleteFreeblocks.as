/*
    we can delete freeblocks by patching a jump and abusing the cursor picked block.
    Moreover, we can abuse macroblock groups and the macroblock mode to remove many free blocks at once.

    To get an appropriate macroblock ID, we can pick the number +1 more than the number of MBs.
    This works fine, it doesn't need to be a 'valid' id. (Just the same across blocks)

    We should wait for no picked block (and item) to be able to delete the free block to avoid interfering with the user.
    Additionally, we shouldn't do it on frames where other things are happening.

    LBM @ 0xBB8 is set to 1 when user is clicking.
    can check if delete key is down, (or wait some frames).
    also check for space bar.

    set 0xBE8 (mode) to 0x22 (free macroblock)
    set 0x630 (picked block) to block
    set all blocks macroblock id
    then patch and wait for deletion

    patch JNE to JMP as per below:

        44 39 7F 18 75 3C 44 39 BB 78 05 00 00 74 3E 8B 47 48 39 47 54 75 10 8B 47 4C 39 47 58 75 08 8B 47 50 39 47 5C 74 26 44 39 7F 04 75 0C 44 39 7F 0C 75 06 44 39 7F 08 74 14 83 BB E8 0B 00 00 02 74 0B 48 8B D7 48 8B CB E8 6D 2C 00 00

        44 39 7F 18 75 ?? 44 39 BB ?? ?? 00 00 74 3E 8B 47 ?? 39

        Trackmania.exe+ED741C - E8 5F280000           - call Trackmania.exe.text+ED8C80 { ->Trackmania.exe+ED9C80 }
        Trackmania.exe+ED7421 - 48 8B 6C 24 50        - mov rbp,[rsp+50]
        ! many jumps arrive here, so can't hook the above esp since we want to jump
        Trackmania.exe+ED7426 - 44 39 7F 18           - cmp [rdi+18],r15d { compare to delete flag on stack (set to 1)
        }
        Trackmania.exe+ED742A - 75 3C                 - jne Trackmania.exe.text+ED6468 { patch this to jmp when we want to delete the picked block
        }
        Trackmania.exe+ED742C - 44 39 BB 78050000     - cmp [rbx+00000578],r15d
        Trackmania.exe+ED7433 - 74 3E                 - je Trackmania.exe.text+ED6473 { ->Trackmania.exe+ED7473 }
        Trackmania.exe+ED7435 - 8B 47 48              - mov eax,[rdi+48]
        Trackmania.exe+ED7438 - 39 47 54              - cmp [rdi+54],eax
        Trackmania.exe+ED743B - 75 10                 - jne Trackmania.exe.text+ED644D { ->Trackmania.exe+ED744D }
        Trackmania.exe+ED743D - 8B 47 4C              - mov eax,[rdi+4C]
        Trackmania.exe+ED7440 - 39 47 58              - cmp [rdi+58],eax
        Trackmania.exe+ED7443 - 75 08                 - jne Trackmania.exe.text+ED644D { ->Trackmania.exe+ED744D }
        Trackmania.exe+ED7445 - 8B 47 50              - mov eax,[rdi+50]
        Trackmania.exe+ED7448 - 39 47 5C              - cmp [rdi+5C],eax
        Trackmania.exe+ED744B - 74 26                 - je Trackmania.exe.text+ED6473 { ->Trackmania.exe+ED7473 }
        Trackmania.exe+ED744D - 44 39 7F 04           - cmp [rdi+04],r15d
        Trackmania.exe+ED7451 - 75 0C                 - jne Trackmania.exe.text+ED645F { ->Trackmania.exe+ED745F }
        Trackmania.exe+ED7453 - 44 39 7F 0C           - cmp [rdi+0C],r15d
        Trackmania.exe+ED7457 - 75 06                 - jne Trackmania.exe.text+ED645F { ->Trackmania.exe+ED745F }
        Trackmania.exe+ED7459 - 44 39 7F 08           - cmp [rdi+08],r15d
        Trackmania.exe+ED745D - 74 14                 - je Trackmania.exe.text+ED6473 { ->Trackmania.exe+ED7473 }
        Trackmania.exe+ED745F - 83 BB E80B0000 02     - cmp dword ptr [rbx+00000BE8],02 { 2 }
        Trackmania.exe+ED7466 - 74 0B                 - je Trackmania.exe.text+ED6473 { ->Trackmania.exe+ED7473 }
        Trackmania.exe+ED7468 - 48 8B D7              - mov rdx,rdi
        Trackmania.exe+ED746B - 48 8B CB              - mov rcx,rbx
        Trackmania.exe+ED746E - E8 6D2C0000           - call Trackmania.exe.text+ED90E0 { call to delete routine
        }
        Trackmania.exe+ED7473 - 44 39 BB CC0B0000     - cmp [rbx+00000BCC],r15d
        Trackmania.exe+ED747A - 74 18                 - je Trackmania.exe.text+ED6494 { ->Trackmania.exe+ED7494 }

*/

MemPatcher@ Editor_DeleteUnderCursor = MemPatcher(
    "44 39 7F 18 75 ?? 44 39 BB ?? ?? 00 00 74 3E 8B 47 ?? 39",
    {4}, {"EB"}, {"75"}
);

namespace Editor {
    // unique list of block specs to delete
    BlockSpec@[] pendingFreeBlocksToDelete;
    bool waitingToDeleteFreeBlocks = false;

    void QueueFreeBlockDeletionFromMB(MacroblockSpec@ mb) {
        if (mb is null) return;
        for (uint i = 0; i < mb.Blocks.Length; i++) {
            if (!mb.Blocks[i].isFree) continue;
            // NotifyWarning("Freeblock deletion disabled atm b/c game crashes");
            // return;
            QueueFreeBlockDeletion(mb.Blocks[i]);
        }
        // RunDeleteFreeBlockDetection();
    }

    void QueueFreeBlockDeletion(BlockSpec@ block) {
        if (block is null || !block.isFree) return;
        // don't ignore duplicates, and don't delete all matching freeblocks
        // if (pendingFreeBlocksToDelete.Find(block) != -1) return;
        pendingFreeBlocksToDelete.InsertLast(block);
        if (!waitingToDeleteFreeBlocks) {
            waitingToDeleteFreeBlocks = true;
            // startnew(WaitToDeleteFreeBlocks).WithRunContext(Meta::RunContext::MainLoop);
            // NotifyWarning('started wait to delete free blocks coro');
        }
        // Notify('added block to delete queue: ' + block.name);
    }

    bool HasPendingFreeBlocksToDelete() {
        return pendingFreeBlocksToDelete.Length > 0 && waitingToDeleteFreeBlocks;
    }

    // Run this in MainLoop or GameLoop
    void RunDeleteFreeBlockDetection() {
        if (pendingFreeBlocksToDelete.Length == 0) return;
        canDeleteFreeBlocks = true;
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        _delFreeOrigPlacement = Editor::GetPlacementMode(editor);
        _delFreeOrigEdit = Editor::GetEditMode(editor);
        _delFreeOrigItem = Editor::IsInAnyItemPlacementMode(editor) ? Editor::GetItemPlacementMode() : ItemMode::None;

        TrackMap_OnRemoveBlock_BeginAPI();
        // changing the placement mode triggers a cursor update
        if (_delFreeOrigPlacement != CGameEditorPluginMap::EPlaceMode::FreeBlock) {
            Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
        } else {
            Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::GhostBlock);
        }
        if (canDeleteFreeBlocks || waitingToDeleteFreeBlocks) {
            warn("Expected free block flags to be set to false!");
        }
        TrackMap_OnRemoveBlock_EndAPI();

        Editor::SetEditMode(editor, _delFreeOrigEdit);
        Editor::SetPlacementMode(editor, _delFreeOrigPlacement);
        Editor::SetItemPlacementMode(_delFreeOrigItem);
    }

    bool canDeleteFreeBlocks = false;
    void WaitToDeleteFreeBlocks() {
        RunDeleteFreeBlockDetection();
        return;
        // canDeleteFreeBlocks = false;
        // int lastDelPress = -1;
        // uint count = 0;
        // while (waitingToDeleteFreeBlocks) {
        //     if (count > 0) yield();
        //     count++;
        //     if (UI::IsKeyPressed(UI::Key::Delete)) {
        //         lastDelPress = count;
        //         continue;
        //     }
        //     if (lastDelPress + 2 > count) continue;
        //     auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        //     if (editor.PickedBlock !is null || editor.PickedObject !is null) continue;
        //     if (Editor::IsSpaceBarDown(editor)) continue;
        //     break;
        // }
        // canDeleteFreeBlocks = true;
        // warn("canDeleteFreeBlocks after " + count);
        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);

        // _delFreeOrigPlacement = Editor::GetPlacementMode(editor);
        // // changing the placement mode triggers a cursor update
        // if (_delFreeOrigPlacement != CGameEditorPluginMap::EPlaceMode::FreeBlock) {
        //     Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeBlock);
        // } else {
        //     Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::GhostBlock);
        // }
    }

    void Setup_DeleteFreeblockCallbacks() {
        RegisterNewBeforeCursorUpdateCallback(BeforeCursorUpdate_DeleteFreeblocks, "BeforeCursorUpdate_DeleteFreeblocks");
        RegisterNewAfterCursorUpdateCallback(AfterCursorUpdate_DeleteFreeblocks, "AfterCursorUpdate_DeleteFreeblocks");
    }

    void BeforeCursorUpdate_DeleteFreeblocks() {
        if (!canDeleteFreeBlocks) return;
        if (!waitingToDeleteFreeBlocks) {
            NotifyWarning("Unexpected: canDeleteFreeBlocks but not waitingToDeleteFreeBlocks");
            return;
        }
        warn('checking if safe to del free blocks');
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        if (editor.PickedBlock !is null || editor.PickedObject !is null) return;
        if (editor.Cursor is null) return;
        if (Editor::IsSpaceBarDown(editor)) return;
        canDeleteFreeBlocks = false;
        warn('proceeding with deleting free blocks');

        auto mbInsts = DGameCtnChallenge(editor.Challenge).MacroblockInstances;
        auto minInst = mbInsts.Length;
        if (minInst > 0) {
            minInst = mbInsts.GetMacroblock(minInst - 1).InstId;
        }
        auto mbInstId = Math::Rand(minInst + 1000, 100000000);
        CGameCtnBlock@[] blocks;
        BlockSpec@ bs;
        auto pmt = editor.PluginMapType;
        for (uint i = 0; i < pendingFreeBlocksToDelete.Length; i++) {
            @bs = pendingFreeBlocksToDelete[i];
            FindFreeBlockPMTAndSetMbId(pmt, bs, blocks, mbInstId);
        }
        dev_trace('set free block mb ids: ' + mbInstId + ' for ' + blocks.Length + ' blocks');
        pendingFreeBlocksToDelete.RemoveRange(0, pendingFreeBlocksToDelete.Length);
        if (blocks.Length == 0) {
            dev_trace('no blocks to delete');
            waitingToDeleteFreeBlocks = false;
            return;
        }
        // dev_trace("Autosaving");
        // editor.PluginMapType.AutoSave();
        // dev_trace("Autosaved");

        // now we need to set the cursor things
        Editor::SetPlacementMode(editor, CGameEditorPluginMap::EPlaceMode::FreeMacroblock);
        Editor::SetEditorPickedBlock(editor, blocks[0]);
        Editor::SetEditMode(editor, CGameEditorPluginMap::EditMode::Erase);
        // Temp Patch to delete what's under the cursor,
        Editor_DeleteUnderCursor.Apply();
        runFreeBlockAfterCursorUpdate = true;
        // NotifyWarning("ATTEMPTING TO DELETE BLOCKS: " + blocks.Length);
    }

    bool runFreeBlockAfterCursorUpdate = false;

    void AfterCursorUpdate_DeleteFreeblocks() {
        if (!runFreeBlockAfterCursorUpdate) return;
        runFreeBlockAfterCursorUpdate = false;
        Editor_DeleteUnderCursor.Unapply();
        waitingToDeleteFreeBlocks = false;
        canDeleteFreeBlocks = false;
        @lastPickedBlock = null;
        // we restore placement mode stuff layer anyway
        // auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        // if (editor is null) return;
        // Editor::SetPlacementMode(editor, _delFreeOrigPlacement);
        // Editor::SetEditMode(editor, _delFreeOrigEdit);
    }

    CGameEditorPluginMap::EPlaceMode _delFreeOrigPlacement = CGameEditorPluginMap::EPlaceMode::FreeMacroblock;
    CGameEditorPluginMap::EditMode _delFreeOrigEdit = CGameEditorPluginMap::EditMode::Erase;
    Editor::ItemMode _delFreeOrigItem = Editor::ItemMode::Normal;
}

void FindFreeBlockPMTAndSetMbId(CGameEditorPluginMapMapType@ pmt, Editor::BlockSpec@ bs, CGameCtnBlock@[]@ blocksToDel, uint mbInstId) {
    CGameCtnBlock@ b;
    for (uint i = 0; i < pmt.ClassicBlocks.Length; i++) {
        @b = pmt.ClassicBlocks[i];
        if (!Editor::IsBlockFree(b)) continue;
        if (Editor::GetBlockMbInstId(b) == mbInstId) continue;
        if (bs.MatchesBlock(b)) {
            Editor::SetBlockMbInstId(b, mbInstId);
            blocksToDel.InsertLast(b);
            break;
        }
    }
}
