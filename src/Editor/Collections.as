namespace Editor {
    // Collections can have an IX ("#26" for stadium, "#299" for common, "#10003")
    // but this not always match the CollectionId (9 for stadium, 14 for common, 16 for #10003)
    // In macroblocks, we need to use the IX not the CollectionId (26, 299, 10003, etc)
    // Blocks and items use CollectionId, so we need to go from Id -> IX
    // Note: IX is an MwId. CollectionId is not.
    dictionary _CollectionIdToIx;
    bool InitializedCollectionIdMap = false;

    uint CollectionIdToIx(uint collectionId, const string &in collectionName = "") {
        if (!InitializedCollectionIdMap) {
            RunInitializeCollectionIdMap();
        }
        if (_CollectionIdToIx.Exists("#" + collectionId)) {
            return uint(_CollectionIdToIx["#" + collectionId]);
        }
        if (_CollectionIdToIx.Exists(collectionName)) {
            return uint(_CollectionIdToIx[collectionName]);
        }
        Dev_NotifyWarning("CollectionIdToIx: Could not find IX for CollectionId " + collectionId + " (" + collectionName + ")");
        return 0;
    }

    void RunInitializeCollectionIdMap() {
        InitializedCollectionIdMap = true;
        auto app = GetApp();
        auto gc = app.GlobalCatalog;
        for (uint i = 0; i < gc.Chapters.Length; i++) {
            _AddChapterCollectionToMap(gc.Chapters[i]);
        }
    }

    void _AddChapterCollectionToMap(CGameCtnChapter@ chapter) {
        auto ix = chapter.Id.Value;
        auto idUint = _GetChapterCollectionId(chapter);
        auto idText = _GetChapterCollectionIdText(chapter);
        if (idUint != 0) {
            _CollectionIdToIx["#" + idUint] = ix;
        }
        if (idText != "") {
            _CollectionIdToIx[idText] = ix;
        }
    }

    uint _GetChapterCollectionId(CGameCtnChapter@ chapter) {
        if (chapter.CollectionFid !is null) {
            auto collection = cast<CGameCtnCollection>(Fids::Preload(chapter.CollectionFid));
            if (collection !is null) {
                return uint(collection.CollectionId);
            }
        }
        if (chapter.Articles.Length > 0) {
            auto article = chapter.Articles[0];
            if (article !is null) {
                return article.CollectionId;
            }
        }
        Dev_NotifyWarning("Could not get CollectionId for chapter: " + chapter.IdName);
        return 0;
    }

    string _GetChapterCollectionIdText(CGameCtnChapter@ chapter) {
        if (chapter.CollectionFid !is null) {
            auto collection = cast<CGameCtnCollection>(Fids::Preload(chapter.CollectionFid));
            if (collection !is null) {
                return collection.CollectionId_Text;
            }
        }
        if (chapter.Articles.Length > 0) {
            auto article = chapter.Articles[0];
            if (article !is null) {
                return article.CollectionId_Text;
            }
        }
        Dev_NotifyWarning("Could not get CollectionId_Text for chapter: " + chapter.IdName);
        return "";
    }


    CGameCtnChapter@ GetChapterFromGlobalCatalog(uint chapterId) {
        auto app = GetApp();
        for (uint i = 0; i < app.GlobalCatalog.Chapters.Length; i++) {
            auto chapter = app.GlobalCatalog.Chapters[i];
            if (chapter.Id.Value == chapterId) {
                return chapter;
            }
        }
        return null;
    }
}
