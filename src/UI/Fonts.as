bool AreFontsLoaded = false;
UI::Font@ g_Heading = null;
UI::Font@ g_Mono = null;

Meta::PluginCoroutine@ fontLoadCoro = startnew(_LoadFonts);

void _LoadFonts() {
    @g_Heading = UI::LoadFont("DroidSans.ttf", 20.0, -1, -1, true, true, true);
    @g_Mono = UI::LoadFont("DroidSansMono.ttf", 16.0);
    AreFontsLoaded = true;
}
