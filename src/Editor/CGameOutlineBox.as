namespace Editor {
    namespace GameOutlineBox {
        CPlugTree@ GetLinesTree(CGameOutlineBox@ box) {
            if (box is null) return null;
            auto linesTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, O_CGAMEOUTLINEBOX_LINES_TREE));
            if (linesTree is null) return null;
            return linesTree;
        }

        CPlugTree@ GetQuadsTree(CGameOutlineBox@ box) {
            if (box is null) return null;
            auto quadsTree = cast<CPlugTree>(Dev_GetOffsetNodSafe(box, O_CGAMEOUTLINEBOX_QUADS_TREE));
            if (quadsTree is null) return null;
            return quadsTree;
        }
    }
}
