[Setting hidden]
bool S_LoadMapsWithOldPillars = false;

namespace PillarsChoice {
    void OnEditorStartingUp() {
        if (S_LoadMapsWithOldPillars) {
            ApplyOldPillars();
            startnew(WatchForEditorNull);
        }
    }

    void OnEditorUnload() {
        UnapplyOldPillars();
    }

    void WatchForEditorNull() {
        auto app = GetApp();
        while (app.Editor is null && app.CurrentPlayground is null) yield();
        // did we load into a playground instead of editor?
        if (app.Editor is null) {
            UnapplyOldPillars();
            return;
        }
        while (app.Editor !is null) yield();
        UnapplyOldPillars();
    }

    bool OldPillarsApplied = false;

    void ApplyOldPillars() {
        if (OldPillarsApplied) return;
        FindAndProcessRemapFolder("GameData/Stadium/Media/Modifier/TrackWallFromParent.Gbx", true);
        OldPillarsApplied = true;
    }

    void UnapplyOldPillars() {
        if (!OldPillarsApplied) return;
        FindAndProcessRemapFolder("GameData/Stadium/Media/Modifier/TrackWallFromParent.Gbx", false);
        OldPillarsApplied = false;
    }

    PillarMod@[] appliedPillars;

    void FindAndProcessRemapFolder(const string &in path, bool applyElseUnapply) {
        auto fid = Fids::GetGame(path);
        auto nod = cast<CPlugGameSkinAndFolder>(Fids::Preload(fid));
        if (nod is null) return;
        appliedPillars.InsertLast(PillarMod(nod));
    }


    class PillarMod {
        CPlugGameSkinAndFolder@ remapFolder;
        PillarMod(CPlugGameSkinAndFolder@ remapFolder) {
            @remapFolder = remapFolder;
            remapFolder.MwAddRef();
            PatchRemap();
        }

        void PatchRemap() {

        }
    }
}
