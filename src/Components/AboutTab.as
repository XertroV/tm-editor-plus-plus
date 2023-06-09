class AboutTab : Tab {
    AboutTab(TabGroup@ p) {
        super(p, "About", Icons::InfoCircle);
    }

    void DrawInner() override {
        UI::Markdown("""
 # Editor++

 Author: XertroV

 Editor++ has benefited from the prior work and research / contributions of:

 * Miss
 * Skybaxrider
 * BigBang1112
 * schadocalex
 * bmx22c
 * ArEyeses
 * Damel
 * Chraz

 With additional thanks for miscellaneous contributions from:

 * BigthirstyTM
 * SBVille
 * TNTree
 * Zai
 * Nightroast
 * TMTOM
        """);
    }
}
