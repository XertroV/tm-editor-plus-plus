bool AreFontsLoaded = false;
UI::Font@ g_Heading = null;
UI::Font@ g_Mono = null;
int f_NvgFont = nvg::LoadFont("DroidSans.ttf");

awaitable@ fontLoadCoro = startnew(_LoadFonts);

void _LoadFonts() {
    @g_Heading = UI::LoadFont("DroidSans.ttf", 20);
    @g_Mono = UI::Font::DefaultMono;
    AreFontsLoaded = true;
}
