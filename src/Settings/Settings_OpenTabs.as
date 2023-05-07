
[Setting hidden]
string S_OpenTabs = "";

Json::Value@ _openTabs = null;

void MarkTabOpen(const string &in fullTabName, bool open) {
    auto j = GetOpenTabs();
    if (open) {
        j[fullTabName] = 1;
    }
}

Json::Value@ GetOpenTabs() {
    return null;
}
