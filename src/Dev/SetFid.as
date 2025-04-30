enum Drive {
    User, Fake, Game
}


CSystemFidFile@ GetFid(Drive drive, const string &in path) {
    switch (drive) {
        case Drive::User: return Fids::GetUser(path);
        case Drive::Fake: return Fids::GetFake(path);
        case Drive::Game: return Fids::GetGame(path);
    }
    throw("Invalid drive: " + tostring(drive));
    return null;
}

string FmtFidDrivePath(Drive drive, const string &in path) {
    switch (drive) {
        case Drive::User: return "<User>/" + path;
        case Drive::Fake: return "<Fake>/" + path;
        case Drive::Game: return "<Game>/" + path;
    }
    throw("Invalid drive: " + tostring(drive));
    return "";
}

CSystemFidFile@ SetNodFid(CMwNod@ nod, Drive drive, const string &in path) {
    if (nod is null) throw("Nod is null");
    auto fid = GetFid(drive, path);
    if (fid is null) throw("Could not create fid for " + FmtFidDrivePath(drive, path));
    // handle existing fid
    LinkFidAndNod(fid, nod);
    return fid;
}

void UnlinkFidAndNod(CSystemFidFile@ fid) {
    if (fid is null) throw("Fid is null");
    if (fid.Nod is null) return;
    Dev::SetOffset(fid.Nod, 0x8, uint64(0));
    Dev::SetOffset(fid, O_FID_Nod, uint64(0));
}

void LinkFidAndNod(CSystemFidFile@ fid, CMwNod@ nod) {
    if (fid.Nod !is null) {
        UnlinkFidAndNod(fid);
    }
    // nods are not refcounted by fid linkage
    Dev::SetOffset(fid, O_FID_Nod, nod);
    if (nod !is null) Dev::SetOffset(nod, 0x8, fid);
}
