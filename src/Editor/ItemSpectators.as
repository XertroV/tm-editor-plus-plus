const string SPECTATORS_FOLDER = IO::FromStorageFolder("Spectators/");

void ExportItemSpectators(CMwNod@ tqs, uint nbTqs) {
    CheckCreateFolder(SPECTATORS_FOLDER);
    CheckItemSpectatorsReadme(SPECTATORS_FOLDER);
    OpenExplorerPath(SPECTATORS_FOLDER);

    if (tqs is null) {
        NotifyError("Error: expected a list of quaternions and positions but got null.");
        return;
    }

    uint elSize = SZ_GMQUATTRANS;
    string[] szTQs;
    // vec4[] rots;
    // vec3[] poss;
    for (uint i = 0; i < nbTqs; i++) {
        // quaternion
        auto rot = Dev::GetOffsetVec4(tqs, i * elSize + 0x0);
        auto pos = Dev::GetOffsetVec3(tqs, i * elSize + 0x10);
        szTQs.InsertLast(_ExportQuatPos(rot, pos));
    }
    auto csv = string::Join(szTQs, "\n");
    IO::File outf(SPECTATORS_FOLDER + "Export.csv", IO::FileMode::Write);
    outf.Write(csv);
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
uint ImportItemSpectators(CMwNod@ tqs, uint nbTqs) {
    try {
        auto spectatorsQTs = LoadItemSpectatorsImportFile(SPECTATORS_FOLDER);
        if (spectatorsQTs is null) throw("Could not parse Import.csv -- spectatorsQTs is null");
        if (spectatorsQTs.Length > nbTqs) throw("Too many spectators in Import.csv (max lines: "+nbTqs+")");
        if (spectatorsQTs.Length == 0) throw("Import.csv had 0 spectators");
        uint elSize = SZ_GMQUATTRANS;
        for (uint i = 0; i < spectatorsQTs.Length; i++) {
            auto item = spectatorsQTs[i];
            Dev::SetOffset(tqs, i * elSize + 0x0, item.q);
            Dev::SetOffset(tqs, i * elSize + 0x10, item.p);
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
    // the 4th array has a length of 1
    // Dev_DoubleMwSArray(placementGroupPtr + 0x30);
    NotifySuccess("Double spectator capacity (clones). Please continue editing and then save the item.");
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
        if (lines[line].Length == 0) continue;
        ret.InsertLast(SpectatorQT(lines[line]));
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

Example of such a script: https://github.com/openplanet-nl/mlhook/blob/master/examples/spectators_from_image.py

For help, ping @XertroV in the support thread on Discord.


""";
