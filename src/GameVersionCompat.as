bool GameVersionSafe = false;
const string[] KnownSafeVersions = {
    "2023-03-31_13_17", "2023-04-28_17_34",
    "2023-05-05_21_05", "2023-06-23_16_27",
    "2023-07-10_19_57", "2023-08-31_17_17"
    };
const string configUrl = "https://openplanet.dev/plugin/editor/config/version-compat";

/**
 * New version checklist:
 * - Update KnownSafeVersions
 * - Update JSON config on site
 * - Update info toml min version
 */

void CheckAndSetGameVersionSafe() {
    EnsureGameVersionCompatibility();
    if (!GameVersionSafe) {
        WarnBadGameVersion();
        return;
    }
}

string TmGameVersion = "";
void EnsureGameVersionCompatibility() {
    if (GameVersionSafe) return;
    TmGameVersion = GetApp().SystemPlatform.ExeVersion;
    GameVersionSafe = KnownSafeVersions.Find(TmGameVersion) > -1;
    if (GameVersionSafe) return;
    GameVersionSafe = GetStatusFromOpenplanet();
    trace("Got GameVersionSafe status: " + GameVersionSafe);
}

void WarnBadGameVersion() {
    NotifyWarning("Game version ("+TmGameVersion+") not marked as compatible with this version of the plugin -- will be inactive!\n\nChecking new versions is a manual process and avoids crashing your game after an update.");
}

bool requestStarted = true;
bool requestEnded = true;

bool GetStatusFromOpenplanet() {
    // string configUrl = "https://openplanet.dev/plugin/" + Meta::ExecutingPlugin().ID + "/config/version-compat";
    trace('Version Compat URL: ' + configUrl);
    auto req = Net::HttpGet(configUrl);
    requestStarted = true;
    requestEnded = false;
    while (!req.Finished()) yield();
    if (req.ResponseCode() != 200) {
        warn('getting plugin enabled status: code: ' + req.ResponseCode() + '; error: ' + req.Error() + '; body: ' + req.String());
        return RetryGetStatus(2000);
    }
    requestEnded = true;
    try {
        auto j = Json::Parse(req.String());
        auto myVer = Meta::ExecutingPlugin().Version;
        if (!j.HasKey(myVer) || j[myVer].GetType() != Json::Type::Object) return false;
        // if we have this key, then it's okay
        return j[myVer].HasKey(TmGameVersion);
    } catch {
        warn("exception: " + getExceptionInfo());
        return RetryGetStatus(2000);
    }
}

uint retries = 0;

bool RetryGetStatus(uint delay) {
    trace('retying GetStatusFromOpenplanet in ' + delay + ' ms');
    sleep(delay);
    retries++;
    if (retries > 5) {
        warn('not retying anymore, too many failures.');
        return false;
    }
    trace('retrying...');
    return GetStatusFromOpenplanet();
}

[SettingsTab name="Game Version Check" icon="ExclamationTriangle"]
void OverrideGameSafetyCheck() {
    UI::Text("Game version safe? " + tostring(GameVersionSafe));
    UI::Text("Check request started: " + tostring(requestStarted));
    UI::Text("Check request ended: " + tostring(requestEnded));
    if (!GameVersionSafe && UI::Button("Disable safety features and run anyway")) {
        GameVersionSafe = true;
    }
}
