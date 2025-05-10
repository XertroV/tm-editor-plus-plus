const string DOUBLE_QUOTE = "\"";

class TabGroupMeta : HasCustomLogs {
    // LIFO if adding fav to top; FIFO otherwise.
    int[] favorites;
    int[] hidden;
    string parentTabId;
    int parentTabIdValue;

    TabGroupMeta(TabGroup@ parent) {
        parentTabId = parent.tabGroupId.Replace(DOUBLE_QUOTE, "");
        parentTabIdValue = StrToMwIdValue(parentTabId);
        _logMsgScope = "TabGroupMeta(" + parentTabId + ")";
        TabState::OnNewTabGroup(parent);
    }

    Json::Value@ _lastJson = null;
    string _lastJsonStr = "";
    Json::Value@ ToJson() {
        if (_lastJson !is null) return _lastJson;
        Json::Value@ j = Json::Object();
        j["hidden"] = J::From_ArrayMwIdValue(hidden);
        j["favorites"] = J::From_ArrayMwIdValue(favorites);
        @_lastJson = j;
        _lastJsonStr = Json::Write(j);
        return j;
    }

    void WriteToJson(Json::Value@ j) {
        j[parentTabId] = ToJson();
    }

    void WritingJson_WriteValueStr(string[]& parts) {
        if (_lastJson !is null) {
            parts.InsertLast(_lastJsonStr);
        } else {
            ToJson();
            parts.InsertLast(_lastJsonStr);
        }
    }

    void WritingJson_WriteObjKeyEl(string[]& parts) {
        parts.InsertLast('"' + parentTabId + '":');
        WritingJson_WriteValueStr(parts);
    }

    // a json object describing this group
    void FromJsonObj(Json::Value@ j) {
        if (j.GetType() != Json::Type::Object) {
            Warn("FromJsonObj", "expected object");
            return;
        }
        if (j.HasKey("hidden")) hidden = J::To_ArrayMwIdValue(j["hidden"]);
        if (j.HasKey("favorites")) favorites = J::To_ArrayMwIdValue(j["favorites"]);
    }

    // lookup this group's key in a json object. throws if not an object
    void LoadFromJson(Json::Value@ j) {
        if (j.GetType() != Json::Type::Object) throw("LoadFromJson: expected object");
        if (j.HasKey(parentTabId)) {
            FromJsonObj(j[parentTabId]);
        } else {
            // Debug("LoadFromJson", "no key for this group: " + parentTabId);
        }
    }

    void _MarkStale() {
        @_lastJson = null;
        TabState::SaveSoon();
    }

    void AddHidden(const string &in tabId) { AddHidden(StrToMwIdValue(tabId)); }
    void AddHidden(int id) {
        if (id == -1) return;
        if (hidden.Find(id) == -1) hidden.InsertLast(id);
        _MarkStale();
    }

    void RemHidden(const string &in tabId) { RemHidden(StrToMwIdValue(tabId)); }
    void RemHidden(int id) {
        auto ix = hidden.Find(id);
        if (ix != -1) hidden.RemoveAt(ix);
        _MarkStale();
    }

    void ToggleHidden(const string &in tabId) { ToggleHidden(StrToMwIdValue(tabId)); }
    void ToggleHidden(int id) {
        if (id == -1) return;
        auto ix = hidden.Find(id);
        if (ix == -1) hidden.InsertLast(id);
        else hidden.RemoveAt(ix);
        _MarkStale();
    }

    bool IsHidden(const string &in tabId) { return IsHidden(StrToMwIdValue(tabId)); }
    bool IsHidden(int id) {
        if (id == -1) return false;
        return hidden.Find(id) != -1;
    }

    bool IsFavorite(const string &in tabId) { return IsFavorite(StrToMwIdValue(tabId)); }
    bool IsFavorite(int id) {
        if (id == -1) return false;
        return favorites.Find(id) != -1;
    }

    void AddFavorite(const string &in tabId) { AddFavorite(StrToMwIdValue(tabId)); }
    void AddFavorite(int id) {
        if (id == -1) return;
        auto ix = favorites.Find(id);
        if (ix == -1) {
            favorites.InsertLast(id);
        } else {
            favorites.RemoveAt(ix);
            favorites.InsertLast(id);
        }
        _MarkStale();
    }

    void RemFavorite(const string &in tabId) { RemFavorite(StrToMwIdValue(tabId)); }
    void RemFavorite(int id) {
        auto ix = favorites.Find(id);
        if (ix != -1) favorites.RemoveAt(ix);
        _MarkStale();
    }
}


enum TabMeta_EOpenType {
    // Not a window
    Default = 0,
    // Popped out
    Window = 1,
    // Active meaning it's the last one selected under this group
    IsSelected = 2,
}


class TabMeta : HasCustomLogs {
    // this should be the *full* tab name (including parent etc)
    string tabName;
    int tabNameIdValue;
    int openFlags;
    string idNonce;

    TabMeta(Tab@ parent) {
        tabName = parent.tabId.Replace(DOUBLE_QUOTE, "");
        tabNameIdValue = StrToMwIdValue(tabName);
        _logMsgScope = "TabMeta(" + tabName + ")";
        TabState::OnNewTab(parent);
    }

    void SetOpenFlags(Tab& tab) {
        openFlags = int(tab.windowOpen ? TabMeta_EOpenType::Window : 0)
                  | int(tab.isSelectedInGroup ? TabMeta_EOpenType::IsSelected : 0)
                  ;
        if (tab.windowOpen) {
            _Log::Trace("TabMeta", "SetOpenFlags: " + tabName + " windowOpen");
        }
    }

    bool get_IsSelected() {
        return (openFlags & int(TabMeta_EOpenType::IsSelected)) != 0;
    }

    bool get_WindowOpen() {
        return (openFlags & int(TabMeta_EOpenType::Window)) != 0;
    }

    void MarkStale() {
        @_lastJson = null;
        TabState::SaveSoon();
    }

    Json::Value@ _lastJson = null;
    Json::Value@ ToJson() {
        if (_lastJson !is null) return _lastJson;
        auto j = Json::Object();
        // j["tabName"] = tabName;
        j["openFlags"] = openFlags;
        j["idNonce"] = idNonce;
        @_lastJson = j;
        lastJAsStr = Json::Write(j);
        return j;
    }

    string lastJAsStr;
    void WritingJson_WriteValueStr(string[]& parts) {
        if (_lastJson !is null) {
            parts.InsertLast(Json::Write(_lastJson));
        } else {
            ToJson();
            parts.InsertLast(lastJAsStr);
        }
    }

    void WritingJson_WriteObjKeyEl(string[]& parts) {
        parts.InsertLast('"' + tabName + '":');
        WritingJson_WriteValueStr(parts);
    }

    void WriteToJson(Json::Value@ j) {
        j[tabName] = ToJson();
    }

    // a json object describing this tab's state
    void FromJsonObj(Json::Value@ j) {
        if (j.GetType() != Json::Type::Object) {
            Warn("FromJsonObj", "expected object");
            return;
        }
        if (j.HasKey("openFlags")) {
            openFlags = j["openFlags"];
            // _Log::Trace("\\$88fFromJsonObj::"+tabName, "openFlags: " + openFlags + " | j = " + Json::Write(j));
        }
        if (j.HasKey("idNonce")) {
            string _idN = j["idNonce"];
            if (_idN.Length > 0) {
                idNonce = j["idNonce"];
            }
            // _Log::Trace("\\$88fFromJsonObj::"+tabName, "idNonce: " + idNonce + " | j = " + Json::Write(j));
        }
    }

    // lookup this tab's key in a json object. throws if not an object
    void LoadFromJson(Json::Value@ j) {
        if (j.GetType() != Json::Type::Object) throw("LoadFromJson: expected object");
        if (j.HasKey(tabName)) {
            FromJsonObj(j[tabName]);
        } else {
            // Trace("LoadFromJson", "no key for this tab: " + tabName);
        }
    }

}



mixin class HasCustomLogs {
    string _logMsgScope;
    protected void Warn(const string &in method, const string &in msg) { _Log::Warn(_logMsgScope + "::" + method + ": " + msg); }
    protected void Debug(const string &in method, const string &in msg) { _Log::Debug(_logMsgScope + "::" + method + ": " + msg); }
    protected void Trace(const string &in method, const string &in msg) { _Log::Trace(_logMsgScope + "::" + method + ": " + msg); }
}



MwId _globalMwIdForConversion;
int StrToMwIdValue(const string &in str) {
     _globalMwIdForConversion.SetName(str);
    return _globalMwIdForConversion.Value;
}
string MwIdValueToStr(int id) {
    _globalMwIdForConversion.Value = id;
    return _globalMwIdForConversion.GetName();
}

namespace J {
    // json(string[]) <- int[]
    Json::Value@ From_ArrayMwIdValue(const int[] &in arr) {
        Json::Value@ j = Json::Array();
        for (uint i = 0; i < arr.Length; i++) {
            j.Add(MwIdValueToStr(arr[i]));
        }
        return j;
    }

    // int[] <- json(string[])
    int[] To_ArrayMwIdValue(Json::Value@ j) {
        if (j.GetType() != Json::Type::Array) return {};
        int[] arr;
        arr.Resize(j.Length);
        for (uint i = 0; i < j.Length; i++) {
            try {
                arr[i] = StrToMwIdValue(string(j[i]));
            } catch {
                _Log::Warn_NID("Error parsing MwId from json: " + getExceptionInfo());
                arr[i] = -1;
            }
        }
        return arr;
    }
}
