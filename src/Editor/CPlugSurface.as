namespace Editor {
    // safe version that doesn't crash the game if there are null materials
    void TransformMaterialsToMatIds(CPlugSurface@ surf) {
        bool hasNullMaterial = false;
        for (uint i = 0; i < surf.Materials.Length; i++) {
            if (surf.Materials[i] is null) {
                hasNullMaterial = true;
                break;
            }
        }
        if (hasNullMaterial) {
            // we need to remove null references to avoid crash -> easiest way is to zero materials buffer
            Dev::SetOffset(surf, GetOffset(surf, "Materials") + 0x8, uint32(0));
        }
        surf.TransformMaterialsToMatIds();
    }
}
