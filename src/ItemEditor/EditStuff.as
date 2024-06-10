namespace Editor {
    void OpenItemEditorMethod2Ref(ref@ targetBm) {
        OpenItemEditorMethod2(cast<CGameCtnBlockInfo>(targetBm));
    }

    void OpenItemEditorMethod2(CGameCtnBlockInfo@ targetBm) {
        if (targetBm is null) {
            warn("OpenItemEditorMethod2: target block info is null");
            return;
        }
        auto editor = cast<CGameCtnEditorFree>(GetApp().Editor);
        auto inv = Editor::GetInventoryCache();

        // method 2 creates a new block from a compatible one, then force updates the block in the item editor, and save + reload.
        auto baseNode = inv.GetBlockByName("RoadTechStraight");
        auto bm = cast<CGameCtnBlockInfo>(baseNode.GetCollectorNod());
        // auto targetBm = cast<CGameCtnBlockInfo>(node.GetCollectorNod());

        // open editor
        Editor::OpenItemEditor(editor, bm);
        yield();
        yield();

        auto ieditor = cast<CGameEditorItem>(GetApp().Editor);
        auto blockItem = cast<CGameBlockItem>(ieditor.ItemModel.EntityModelEdition);
        auto blockInfo = cast<CGameCtnBlockInfo>(ieditor.ItemModel.EntityModel);

        // update the archetype block info id
        Dev::SetOffset(blockItem, GetOffset(blockItem, 'ArchetypeBlockInfoId_GameBox'), targetBm.Id.Value);

        // update catalog info

        blockInfo.CatalogPosition = targetBm.CatalogPosition + 1;
        blockInfo.PageName = targetBm.PageName;
        blockInfo.NameE = targetBm.Name;
        ieditor.ItemModel.Name = targetBm.Name;
        ieditor.ItemModel.CatalogPosition = targetBm.CatalogPosition + 1;
        ieditor.ItemModel.PageName = targetBm.PageName;

        auto saveName = "Custom_" + targetBm.IdName;
        ItemEditor::SaveItemAs(saveName);
        // ItemEditor::OpenItem(saveName);
        // ieditor.Exit();
        ieditor.AddEmptyMesh();
        yield();

        blockInfo.CatalogPosition = targetBm.CatalogPosition + 1;
        blockInfo.PageName = targetBm.PageName;
        blockInfo.NameE = targetBm.Name;
        ieditor.ItemModel.Name = targetBm.Name;
        ieditor.ItemModel.CatalogPosition = targetBm.CatalogPosition + 1;
        ieditor.ItemModel.PageName = targetBm.PageName;

        ItemEditor::UpdateThumbnail(2);
        ItemEditor::SaveItem();
    }

}
