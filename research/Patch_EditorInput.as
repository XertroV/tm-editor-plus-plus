class MemPatcher {
    protected string pattern;
    protected string[] newBytes;
    protected string[] origBytes;
    protected uint16[] offsets;
    protected bool applied;
    uint64 ptr;

    MemPatcher(const string &in pattern, uint16[] offsets, string[] newBytes) {
        this.pattern = pattern;
        this.newBytes = newBytes;
        this.offsets = offsets;
        this.origBytes.Resize(newBytes.Length);
        ptr = Dev::FindPattern(pattern);
        applied = false;
    }

    ~MemPatcher() {
        Unapply();
    }

    void Apply() {
        if (applied || ptr == 0) return;
        applied = true;
        for (uint i = 0; i < newBytes.Length; i++) {
            origBytes[i] = Dev::Patch(ptr + offsets[i], newBytes[i]);
        }
    }

    void Unapply() {
        if (!applied || ptr == 0) return;
        applied = false;
        for (uint i = 0; i < newBytes.Length; i++) {
            Dev::Patch(ptr + offsets[i], origBytes[i]);
        }
    }

}

// 0x74 = je, 75 = jne,
// 0xEB = jmp
namespace PatchEditorInput {
    // this test is triggered every frame, it is true when there are mouse inputs (RAX=1)
    // this patches a je to a jmp
    MemPatcher@ P_MOUSE_INPUT_TEST = MemPatcher("85 C0 74 69 0F 1F 80 00 00 00 00 48 8B 4B 70 48 8D 54 24 60 48 8B 01 FF 90 80 01 00 00 85 C0", {2}, {"90 90"}); // {0xEB});

    // this part loads the type of event in and jumps if there is no type
    MemPatcher@ P_MOUSE_BUTTON_TYPE_TEST = MemPatcher("48 33 C4 48 89 84 24 10 01 00 00 48 8B 42 10 45 8B F0 48 8B DA 48 8B F1 48 85 C0 0F 84 ?? ?? ?? ?? 8B B9 08 0F 00 00", {27}, {"90 90 90 90 90 90"});

    // when it's a mouse event, we check if it's LMB
    // this patches cmp rbx,rax to cmp rbx,rbx and `mov [rdi+00000BB8],eax` to `mov eax,[rdi+00000BB8]` so we move use mouse value set in editor
    MemPatcher@ P_MOUSE_BUTTON_ONE_TEST = MemPatcher("48 3B D8 0F 85 1F 0F 00 00 49 8B CE E8 ?? ?? ?? ?? 89 87 B8 0B 00 00 85 C0 0F 84 71 12 00 00 8B 8F B0 0B 00 00 8B 95 78 01 00 00 41 3B CC", {0, 17}, {"48 39 DB", "8B 87"}); // {0x8B, 0x87});



    // get the special nod that sets input values on input port
    const string patternSetMouseInput = "8B 48 18 89 4E 38 49 8B CC E8 ?? ?? ?? ?? 48 8D 15 ?? ?? ?? ?? 8B 48 18 89 4E 3C 49 8B CC";
    Dev::HookInfo@ setMouseHook;
    // bool hookMouseInput() {
    //     auto ptr = Dev::FindPattern(patternSetMouseInput);
    //     @setMouseHook = Dev::Hook(Dev::FindPattern(patternSetMouseInput), 1, "OnSetMouseValue", Dev::PushRegisters::SSE);
    //     return true;
    // }
    // bool setupMouseHook = hookMouseInput();

    void Unload() {
        if (setMouseHook !is null) Dev::Unhook(setMouseHook);
    }

    void Load() {
        auto ptr = Dev::FindPattern(patternSetMouseInput);
        if (ptr > 0) {
            @setMouseHook = Dev::Hook(ptr, 1, "OnSetMouseValue", Dev::PushRegisters::SSE);
        } else {
            warn("ptr 0");
        }
    }


}
uint counter = 0;
void OnSetMouseValue(uint64 r11, uint64 rsi) {
    // Dev::Write(rsi + 0x38, uint8(0x80));
    // trace('r11: ' + Text::FormatPointer(r11));
    if (r11 == 0) return;
    auto rax = Dev::ReadUInt64(r11 + 0xd8 + 0x20);
    if (rax > Dev::BaseAddress() && rax < Dev::BaseAddressEnd()) {
        // Dev::Write(rax + 0x18, uint8(0x80));
        // Dev::Write(rax + 0x28, uint8(0x1));
    }
    if (counter > 10) return;
    counter++;
    trace('Called | ' + Time::Now + ', r11: ' + Text::FormatPointer(r11) + ', rax: ' + Text::FormatPointer(rax) + ', rsi: ' + Text::FormatPointer(rsi));
    IO::SetClipboard(Text::FormatPointer(rax));
}




/*

Trackmania.exe+10DAB7B - 48 8D 4C 24 38        - lea rcx,[rsp+38]
Trackmania.exe+10DAB80 - E8 EBE818FF           - call Trackmania.exe+269470 { loads input? }
Trackmania.exe+10DAB85 - 85 C0                 - test eax,eax { called every input }
Trackmania.exe+10DAB87 - 74 69                 - je Trackmania.exe+10DABF2
Trackmania.exe+10DAB89 - 0F1F 80 00000000      - nop dword ptr [rax+00000000]



Trackmania.exe+F59AFE - 48 3B D8              - cmp rbx,rax
Trackmania.exe+F59B01 - 0F85 1F0F0000         - jne Trackmania.exe+F5AA26 { any mouse event checks this, jump != left mouse button }
Trackmania.exe+F59B07 - 49 8B CE              - mov rcx,r14
Trackmania.exe+F59B0A - E8 61E630FF           - call Trackmania.exe+268170
Trackmania.exe+F59B0F - 89 87 B80B0000        - mov [rdi+00000BB8],eax
Trackmania.exe+F59B15 - 85 C0                 - test eax,eax
Trackmania.exe+F59B17 - 0F84 71120000         - je Trackmania.exe+F5AD8E
Trackmania.exe+F59B1D - 8B 8F B00B0000        - mov ecx,[rdi+00000BB0]

48 3B D8 0F 85 1F 0F 00 00 49 8B CE E8 ?? ?? ?? ?? 89 87 B8 0B 00 00 85 C0 0F 84 71 12 00 00 8B 8F B0 0B 00 00 8B 95 78 01 00 00 41 3B CC

! change `mov [rdi+00000BB8],eax` to `mov eax,[rdi+00000BB8]` so we move use mouse value set in editor

48 3B D8 0F 85 1F 0F 00 00 49 8B CE E8 ?? ?? ?? ?? 8B 87 B8 0B 00 00 85 C0 0F 84 71 12 00 00 8B 8F B0 0B 00 00 8B 95 78 01 00 00 41 3B CC

! change CMP rbx,rax to CMP rbx,rbx

48 39 C0 // rax,rax
48 39 DB // rbx,rbx

offset 17



Trackmania.exe+F583C5 - 48 33 C4              - xor rax,rsp
Trackmania.exe+F583C8 - 48 89 84 24 10010000  - mov [rsp+00000110],rax
Trackmania.exe+F583D0 - 48 8B 42 10           - mov rax,[rdx+10] { moves input type in; need to avoid the test }
Trackmania.exe+F583D4 - 45 8B F0              - mov r14d,r8d
Trackmania.exe+F583D7 - 48 8B DA              - mov rbx,rdx
Trackmania.exe+F583DA - 48 8B F1              - mov rsi,rcx
Trackmania.exe+F583DD - 48 85 C0              - test rax,rax
Trackmania.exe+F583E0 - 0F84 28010000         - je Trackmania.exe+F5850E { jumping if no input type }
Trackmania.exe+F583E6 - 8B B9 080F0000        - mov edi,[rcx+00000F08]


48 33 C4 48 89 84 24 10 01 00 00 48 8B 42 10 45 8B F0 48 8B DA 48 8B F1 48 85 C0 0F 84 ?? ?? ?? ?? 8B B9 08 0F 00 00

offset = 27, 6x NOP bytes


*/
