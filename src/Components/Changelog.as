class ChangelogTab : Tab {
    Json::Value@ versions;

    ChangelogTab(TabGroup@ p) {
        super(p, "Changelog", Icons::QuestionCircle);
    }

    void DrawInner() override {
        TryGetChangelog();
        if (versions is null) {
            UI::Text("Loading...");
            return;
        }
        for (uint i = 0; i < versions.Length; i++) {
            if (i > 0) UI::Dummy(vec2(0, 10));
            auto item = versions[i];
            DrawChangelogVersion(item);
        }
    }

    void DrawChangelogVersion(Json::Value@ j) {
        string version = j['version'];
        string changes = j['changes'];
        UI::Markdown("# Version: " + version);
        UI::Markdown(changes);
    }

    bool changelogGetStarted = false;
    void TryGetChangelog() {
        if (changelogGetStarted) return;
        changelogGetStarted = true;
        startnew(CoroutineFunc(GetChangelogAsync));
    }

    void GetChangelogAsync() {
        auto siteId = Meta::ExecutingPlugin().SiteID;
        if (siteId <= 0) throw('negative site it');
        string url = "https://openplanet.dev/api/plugin/" + siteId + "/versions";
        auto req = Net::HttpGet(url);
        while (!req.Finished()) yield();
        try {
            auto resp = req.Json();
            if (resp.GetType() != Json::Type::Array) throw("Response was not a json array: " + Json::Write(resp));
            @versions = resp;
        } catch {
            NotifyError("Exception getting changelog: " + getExceptionInfo());
        }
    }
}
