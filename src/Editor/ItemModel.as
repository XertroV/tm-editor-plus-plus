namespace Editor {
    void SetItemModel_DisableAutoCreateSound(CGameItemModel@ im, bool disable) {
        //
        uint flags = Dev::GetOffsetUint32(im, O_ITEM_MODEL_FLAGS);
        if (disable) {
            flags = flags | 2;
        } else {
            flags = flags & ~2;
        }
        Dev::SetOffset(im, O_ITEM_MODEL_FLAGS, flags);
    }

    bool GetItemModel_DisableAutoCreateSound(CGameItemModel@ im) {
        uint flags = Dev::GetOffsetUint32(im, O_ITEM_MODEL_FLAGS);
        return (flags & 2) != 0;
    }
}
