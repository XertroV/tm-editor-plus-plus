namespace Editor {
    namespace MapBakedBlocksDirtyFlag {
        const string Pattern_SetDirty = "00 00 01 00 00 00 48 8B 91 ?? 04 00 00";
        MemPatcher@ SetDirty_Patch = MemPatcher(Pattern_SetDirty, {2}, {"00"}, {"01"});
        bool get_IsActive() { return SetDirty_Patch.IsApplied; }
        void set_IsActive(bool value) { SetDirty_Patch.IsApplied = value; }
    }
}

/**
Trackmania.exe.text+DE8C49 - 48 8B 81 A0040000     - mov rax,[rcx+000004A0] { get map from editor }
Trackmania.exe.text+DE8C50 - C7 80 64020000 01000000 - mov [rax+00000264],00000001 { sets dirty flag to update baked blocks }
Trackmania.exe.text+DE8C5A - 48 8B 91 A0040000     - mov rdx,[rcx+000004A0] { get map from editor again }
48 8B 81 A0 04 00 00 C7 80 64 02 00 00 01 00 00 00 48 8B 91 A0 04 00 00
48 8B 81 ?? 04 00 00 C7 80 ?? 02 00 00 01 00 00 00 48 8B 91 ?? 04 00 00
unique: C7 80 ?? 02 00 00 01 00 00 00 48 8B 91 ?? 04 00 00
unique: 01 00 00 00 48 8B 91 ?? 04 00 00
add 00 00 at start for safety
*/
;
