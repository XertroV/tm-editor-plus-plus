
const string PluginIcon = "\\$ff3" + Icons::Bolt + "\\$3af" + Icons::Cogs + "\\$z";
const string MenuTitle = PluginIcon + "\\$s " + Meta::ExecutingPlugin().Name;

const float TAU = 6.28318530717958647692;

const int TWO_BILLION = 2000000000;

const string NewIndicator = "\\$af3 New!";
void SameLineNewIndicator() {
    UI::SameLine();
    UI::Text(NewIndicator);
}
