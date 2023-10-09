const string EDITORPLUGIN_EDITORPLUSPLUS_SCRIPT_TXT = """
 #RequireContext CMapEditorPlugin

 #Include "TextLib" as TL
 #Include "TimeLib" as TiL
 #Include "MathLib" as ML

main() {
    log(""^This);
    declare Integer LastUpdate = Now;
    declare metadata Integer EPP_EditorPluginLoads for Map = 0;
    EPP_EditorPluginLoads += 1;

    while(True)
    {
        if (CustomSelectionCoords.count > 0) {
            declare Int3[] Tmp = [];
            foreach (Coord in CustomSelectionCoords) { tmp.add(Coord); }
            CustomSelectionCoords.clear();
            foreach (Coord in Tmp) { CustomSelectionCoords.add(Coord); }
        }

        if (Now - LastUpdate > 1000) {
            declare metadata Integer EPP_MappingTime for Map = 0;
            EPP_MappingTime += (Now - LastUpdate);
            LastUpdate = Now;
        }

        yield;
    }
}
""".Replace('_"_"_"_', '"""');