const string SPECTATORS_FOLDER = IO::FromStorageFolder("Spectators/");

void ExportItemSpectators(uint64 tqsPtr, uint nbTqs) {
    CheckCreateFolder(SPECTATORS_FOLDER);
    CheckItemSpectatorsReadme(SPECTATORS_FOLDER);
    OpenExplorerPath(SPECTATORS_FOLDER);

    uint elSize = SZ_GMQUATTRANS;
    string[] szTQs;
    for (uint i = 0; i < nbTqs; i++) {
        // quaternion
        auto rot = Dev::ReadVec4(tqsPtr + i * elSize + 0x0);
        auto pos = Dev::ReadVec3(tqsPtr + i * elSize + 0x10);
        szTQs.InsertLast(_ExportQuatPos(rot, pos));
    }
    auto csv = string::Join(szTQs, "\n");
    try {
        IO::File outf(SPECTATORS_FOLDER + "Export.csv", IO::FileMode::Write);
        outf.Write(csv);
    } catch {
        NotifyError("Failed to export: " + getExceptionInfo());
    }
}

const string _ExportQuatPos(vec4 q, vec3 p) {
    return string::Join({
        HighPrecisionFloat(q.x),
        HighPrecisionFloat(q.y),
        HighPrecisionFloat(q.z),
        HighPrecisionFloat(q.w),
        HighPrecisionFloat(p.x),
        HighPrecisionFloat(p.y),
        HighPrecisionFloat(p.z)
    }, ",");
}

const string HighPrecisionFloat(float x) {
    return Text::Format("%.7f", x);
}

// returns the new number of spectators
uint ImportItemSpectators(uint64 tqsPtr, uint nbTqs) {
    try {
        auto spectatorsQTs = LoadItemSpectatorsImportFile(SPECTATORS_FOLDER);
        if (spectatorsQTs is null) throw("Could not parse Import.csv -- spectatorsQTs is null");
        if (spectatorsQTs.Length > nbTqs) NotifyWarning("Too many spectators in Import.csv (will only populate the first "+nbTqs+" spectators)");
        if (spectatorsQTs.Length == 0) throw("Import.csv had 0 spectators");
        uint elSize = SZ_GMQUATTRANS;
        for (int i = 0; i < Math::Min(nbTqs, spectatorsQTs.Length); i++) {
            auto item = spectatorsQTs[i];
            Dev::Write(tqsPtr + i * elSize + 0x0, item.q);
            Dev::Write(tqsPtr + i * elSize + 0x10, item.p);
        }
        return spectatorsQTs.Length;
    } catch {
        NotifyError("Failed to import spectators. Exception: " + getExceptionInfo());
    }
    return nbTqs;
}


void DoubleItemSpectators(uint64 placementGroupPtr) {
    print("DIS PTR: " + Text::FormatPointer(placementGroupPtr));
    Dev_DoubleMwSArray(placementGroupPtr + 0x00, SZ_SPLACEMENTOPTION);
    Dev_DoubleMwSArray(placementGroupPtr + 0x10, SZ_GMQUATTRANS);
    // whatever this is, it's 2 bytes long
    Dev_DoubleMwSArray(placementGroupPtr + 0x20, 0x2);
    // the 4th array has a length of 0x18 -- duplicate of 1st array?; does not update for podium spots
    Dev_DoubleMwSArray(placementGroupPtr + 0x30, SZ_SPLACEMENTOPTION);
    NotifySuccess("Doubled spectator capacity (clones). Please continue editing and then save the item.");
    ManipPtrs::AddSignalEntry();
}

void ReduceItemSpectators(uint64 placementGroupPtr, float keepRatio) {
    Dev_ReduceMwSArray(placementGroupPtr + 0x00, keepRatio);
    Dev_ReduceMwSArray(placementGroupPtr + 0x10, keepRatio);
    Dev_ReduceMwSArray(placementGroupPtr + 0x20, keepRatio);
    // does not update for podium spots
    Dev_ReduceMwSArray(placementGroupPtr + 0x30, keepRatio);
    NotifySuccess("Reduced spectator capacity by " +Text::Format("%.1f", (1. - keepRatio) * 100)+ "%. Please continue editing and then save the item.");
}





class SpectatorQT {
    vec4 q;
    vec3 p;
    SpectatorQT(const string &in line) {
        auto fs = line.Split(",");
        q.x = Text::ParseFloat(fs[0]);
        q.y = Text::ParseFloat(fs[1]);
        q.z = Text::ParseFloat(fs[2]);
        q.w = Text::ParseFloat(fs[3]);
        p.x = Text::ParseFloat(fs[4]);
        p.y = Text::ParseFloat(fs[5]);
        p.z = Text::ParseFloat(fs[6]);
    }
}

SpectatorQT@[]@ LoadItemSpectatorsImportFile(const string &in folder) {
    SpectatorQT@[] ret;
    IO::File csv(folder + "Import.csv", IO::FileMode::Read);
    auto lines = csv.ReadToEnd().Split("\n");
    for (uint line = 0; line < lines.Length; line++) {
        auto trimmed = lines[line].Trim();
        if (trimmed.Length == 0 || trimmed.StartsWith("q")) continue;
        ret.InsertLast(SpectatorQT(trimmed));
    }
    return ret;
}


void CheckCreateFolder(const string &in folder) {
    if (!IO::FolderExists(folder)) {
        IO::CreateFolder(folder, true);
    }
}

void CheckItemSpectatorsReadme(const string &in folder) {
    string path = folder + "README.txt";
    try {
        IO::File readmef(path, IO::FileMode::Write);
        readmef.Write(ITEM_SPECTATORS_README);
    } catch {
        NotifyError("Failed to write spectators export README.txt file. Exception: " + getExceptionInfo());
    }
}


const string ITEM_SPECTATORS_README = """
Item Spectators Export/Import How To
------------------------------------

The file format is:
  - 1 line per spectator
  - Each line is a sequence of 7 floats
    - First 4: quaternion values
    - Last 3: position values (x,y,z)

Relevant Files (in this directory):
  - `Export.csv`
  - `Import.csv`

It's best to start by exporting a spectators item's quaternions and positions.
Then you can edit that using a script, and save the file as `Import.csv`.

If Import.csv has fewer lines than the item has capacity for, then the number of spectators will be reduced.

Example of such a script: https://github.com/XertroV/tm-editor-plus-plus/blob/master/examples/spectators_from_image.py
Example of usage: https://github.com/XertroV/tm-editor-plus-plus/tree/master/examples/terrain-spectators

For help, ping @XertroV in the support thread on Discord.

""";
