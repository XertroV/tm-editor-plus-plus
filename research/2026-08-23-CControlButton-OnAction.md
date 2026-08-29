# CControlButton / CControlBase `OnAction` (2026-08-23)

Ghidra project `tm2020-headless`, program **Trackmania.exe**, image base `0x140000000`.

## Short answers

- **Native addresses (suggested names now in the DB):**
  - `CControlBase_OnAction` = `0x14013fff0` (body `0x14013fff0`–`0x1401400ab`)
  - `CControlButton_OnAction` = `0x14014e330` (body `0x14014e330`–`0x14014e423`)
  - `CControlBase_OnAction_MwThunk` = `0x140143f84` — 9-byte `mov rax,[rcx]; jmp [rax+0x200]`
  - `CControlEntry_OnAction` = `0x1401464a0` (calls base, not virtual)
  - `CControlEnum_OnAction` = `0x140146a60` (calls base, not virtual)
- **Is OnAction a vtable method?** Yes. Slot **vtable+0x200**, index **64**. `__thiscall`, **`this` only** (no extra args).
- **Does it call a data function pointer stored on the control?** Not a `CFastDelegate` / raw `void(*)()` field that OnAction invokes directly.
  - CMw reflection **does** store a callable at `CMwMemberInfo+0x20` = the **vtable thunk** `0x140143f84` (not an instance field).
  - Instance field **`this+0x50`**: if non-null, `CControlBase_OnAction` **tail-jumps** `(*(this+0x50))->vtable+0xF0`. Null → that call is skipped (no-op for the base method). The class of `+0x50` is **not** named in `CMwMemberInfo` (not `Parent`, not `Nod`). Same `vtable+0xF0` pattern is used for right-click objects at `+0x88` / `+0x90`.
  - `CControlButton+0x1F0` is **`CPlugSound* ActionSound`**, not a delegate. Null → use style-context default sounds.
- **Typical Nadeo menu button vs a bare `CControlButton`:**
  - Menu buttons are `CControlButton` (or another `CControlBase`) with `+0x50` usually set; base OnAction tail-calls that object’s `vtable+0xF0` (the live click side-effect / ML listener). Button-specific toggle+sound **does not run** on that path (tail jump never returns).
  - A button with `+0x50 == 0` (no listener): base returns; `CControlButton_OnAction` then toggles (if `Parent` at `+0xE8` is set) and plays sound. No script page involvement from this function.
- **Safe to Call from Openplanet as today?** Yes — `.OnAction()` is the game virtual / CMw method (same slot a real left-click uses). A raw `Call1` of **`0x14013fff0`** on a `CControlButton` **is not** the same: it skips the button override. Raw `Call1` of **`0x140143f84`** or `vtable+0x200` matches `.OnAction()`. Extra args are unused. The mouse path AddRef/Releases around the virtual; OP’s handle already holds a ref.
- **Related:** no type named `CControlEvent` in this binary. Mouse-up/left-click is `CControlBase_HandleInputEvent` (`0x140140770`, vtable+0x218 family) matching `InputEvent_MouseLeftButton` then calling `vtable+0x200`. Keyboard nav (`CEventMenuNavigationOnAction`) is a separate ML path, not this function.

## Call graph

```
real left click
  CControlBase_HandleInputEvent  @ 0x140140770
    AddRef
    this->vtable[64] OnAction()     // +0x200
    Release

Openplanet / CMw method "OnAction"
  CControlBase_OnAction_MwThunk  @ 0x140143f84
    jmp [this->vtable + 0x200]

CControlButton_OnAction          @ 0x14014e330
  CALL CControlBase_OnAction     @ 0x14013fff0
    flags+0x130 bit1? return
    +0x180 effect-state? NotifyEffectEvent(id=8)   // ActionEffect slot, does not invoke a user fp
    +0x50 == 0? return to button body
    Is(CControlButton=0x7007000)? skip sound in base
    else PlayPlugSound(style ctx +0x130 or +0x128)
    TAIL jmp (*(this+0x50))->vtable+0xF0          // never returns to button override
  // only if +0x50 was null:
  Parent@+0xE8 && byte@+0xF1? toggle / UpdateVisual
  PlayPlugSound(ActionSound@+0x1F0 or style default)
```

## Key offsets (CControlBase size `0x188`, CControlButton size `0x228`)

| Off | Evidence | What |
|-----|----------|------|
| vtable+0x20 | `CALL [rax+0x20]` with edx=`0x7007000` | `Is(CControlButton)` |
| vtable+0x200 | Mw thunk; button/base vtables | **OnAction** index 64 |
| vtable+0x218 | CControlBase slot = `0x140140850` | input: HandleInputEvent then fallback |
| vtable+0x220 | `0x140141220` | walk `+0x40` to root, then that object’s `+0x220`; else return 0. Used as sound-path predicate |
| vtable+0x248 | CControlButton = `CControlButton_UpdateVisual` `0x14014e5e0` | icon/label rebuild after toggle |
| vtable+0xF0 on `*(this+0x50)` | tail `JMP [rax+0xF0]` | bound listener / command Execute (class of `+0x50` not proven) |
| `+0x40` | vtable+0x220 walk | pointer chain (not `Parent`) |
| `+0x50` | OnAction assembly `CMP [rbx+0x50],0` then `MOV rcx,[rbx+0x50]` | listener object; **null = skip tail call** |
| `+0x88` / `+0x90` | HandleInputEvent right-click / other | same `vtable+0xF0` call pattern |
| `+0xE8` | `CMwMemberInfo` Parent offset `0xE8` | `CControlContainer* Parent` |
| `+0x120` | member table | `CMwNod* Nod` |
| `+0x130` | `TEST byte [rbx+0x130], 2` | flags; bit1 set → OnAction no-op |
| `+0x168` | GetStyleContext | cache for style/sound context |
| `+0x180` | NotifyEffectEvent | effect-state wrapper; first qword used as `CControlEffectMaster*` for slot lookup |
| `+0x1F0` | Button OnAction `MOV rcx,[rbx+0x1f0]` → PlayPlugSound | `CPlugSound* ActionSound` |

Class ids (registration): `CControlBase` `0x7001000` size `0x188`; `CControlButton` `0x7007000` size `0x228`; `CControlEntry` `0x7009000` size `0x208`; `CControlContainer` `0x7002000` size `0x1b8`; `CControlEffectMaster` `0x701c000` size `0x80`.

Vtables:

- `CControlBase` `0x141b59128` — OnAction slot `0x141b59328` → `0x14013fff0`
- `CControlText` `0x141b5c038` — OnAction slot still `0x14013fff0` (no override)
- `CControlButton` `0x141b5a960` — OnAction slot `0x141b5ab60` → `0x14014e330`
- `CControlEntry` `0x141b595e0` — OnAction → `0x1401464a0`
- `CControlEnum` `0x141b59970` — OnAction → `0x140146a60`

## CMw member record (not an instance fp)

`OnAction` string `0x141b59100`. Member record at **`0x141e72800`**:

- `+0x00` name
- `+0x10` **type `0x02`** (method)
- `+0x20` **`0x140143f84`** (thunk)
- member-id packing includes `0x13` / `0x07009000` at `+0x30`/`+0x34` (method metadata, **not** object offset `0x1E8`)

Thunk bytes at `0x140143f84`:

```
48 8B 01          mov rax, [rcx]
FF A0 00 02 00 00 jmp qword ptr [rax+0x200]
```

## Effect path (event 8 = Action)

`CControlEffectMaster_GetEffectSlot` (`0x140156da0`) case 8 returns `*(master+0x68)` = Openplanet `ActionEffect`. `CControlBase_NotifyEffectEvent` (`0x1401579f0`) with `param_3==8` looks that pointer up and updates MwId arrays; it **does not CALL** the effect as a function. Visual ActionEffect playback is separate from script dispatch.

## Mouse path vs `.OnAction()`

`CControlBase_HandleInputEvent` (`0x140140770`):

- Requires flags@`+0x130` sign bit (`(char)flags < 0`) or it returns 0.
- `InputEvent_MouseLeftButton` (and one sibling id) with pressed ≠ 0: AddRef (`+0x10`), **`vtable+0x200(this)`**, Release (destroy if 0).
- Right button: `(*(this+0x88))->vtable+0xF0` if that pointer is set.

So a real click and Openplanet `.OnAction()` share the **same virtual**. The click path extra work is input filtering + ref sandwich, not a different dispatch target.

## Unsafe / do-not-call notes

- **Do not** `Call` `CControlBase_OnAction` (`0x14013fff0`) on a `CControlButton` and expect button behaviour — override is skipped.
- **Do not** assume `+0x1F0` is a callback; it is a sound. Calling it as a function pointer will crash.
- `+0x50` dangling → crash on the tail `vtable+0xF0`.
- Flags `+0x130` bit 1 → silent no-op.
- OnAction can tear down UI (menu navigation). Mouse path AddRefs for that reason; keep an OP handle (or equivalent ref) if calling native yourself.
- `CMwCmdFastCall` exists (class `0x1012000`, size `0x38` = nod + two qwords) but **OnAction does not read a FastCall off the button**. If `+0x50` is a cmd/listener, that is a **vtable call on that object**, not a field at a FastCall offset on the control.

## Ghidra names added this pass

| Address | Name |
|---------|------|
| `0x14013fff0` | `CControlBase_OnAction` |
| `0x14014e330` | `CControlButton_OnAction` |
| `0x140143f84` | `CControlBase_OnAction_MwThunk` |
| `0x140143f78` | `CControlBase_Draw_MwThunk` |
| `0x140143f90` | `CControlBase_Clean_MwThunk` |
| `0x140140770` | `CControlBase_HandleInputEvent` |
| `0x140140850` | `CControlBase_HandleInputEvent_Fallback` |
| `0x1401464a0` | `CControlEntry_OnAction` |
| `0x140146a60` | `CControlEnum_OnAction` |
| `0x140143350` | `CControl_PlayPlugSound` |
| `0x140142f30` | `CControlBase_GetStyleContext` |
| `0x14013f6c0` | `CControlBase_ctor` |
| `0x14014dd50` | `CControlButton_ctor` |
| `0x14014da20` | `CControlButton_New` |
| `0x140159a20` | `CControlText_ctor` |
| `0x140156da0` | `CControlEffectMaster_GetEffectSlot` |
| `0x1401579f0` | `CControlBase_NotifyEffectEvent` |
| `0x140141220` | `CControlBase_VTable220_WalkField40` |
| `0x14014e5e0` | `CControlButton_UpdateVisual` |
| `0x140141560` | `CControlBase_ResolveEnumState` |
| `0x140023ba0` | `CControlBase_RegisterClass` |
| `0x140023ff0` | `CControlButton_RegisterClass` |
| `0x140023c10` | `CControlEntry_RegisterClass` |
| `0x140025d30` | `CControlEffectMaster_RegisterClass` |

Plate comments on OnAction / thunk / input / PlayPlugSound. Prototypes `__thiscall void (void *this)` on the two OnAction impls. `GET /save_all_programs` done.

## Open (not claimed)

- Exact C++ type of `CControlBase+0x50` (listener with `vtable+0xF0`). Ruled out: `Parent` (`+0xE8`), `Nod` (`+0x120`), `ActionSound` (`+0x1F0`), CMwCmdFastCall **as a field on the button**. Candidate: manialink wrapper / cmd object sharing the `+0xF0` Execute convention used at `+0x88`/`+0x90`.
- Whether `+0x50` vtable+0xF0 queues `CGameManialinkScriptEvent` (`EType::MouseClick=1`) onto `PendingEvents`. Not traced past the tail jump.
- `CEventMenuNavigationOnAction` / `ApplyInput` keyboard path: not this function.
