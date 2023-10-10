- shaded_geoms in S2M

- [x] place macroblock air mode
- filter inventory
- [ ] favorites for inventory
- check item placed when selecting in manip mesh
- ensure item saved before editing properties
- [x] custom selection
- recently selected blocks and items history
- [x] Quick idea please, would it be possible to redirect to the "Picked Item" tab when clicking this button on the "Blocks & Items" tab?
- [x] edit block coord of item


- ~~copy placement params from 1 item to another~~
- script to do item manipulation
- investigate placing items on freeblocks when a normally placed block is close
-

- scenery spray
  - mouse button to apply scenery (maybe blocks, maybe items)
  - trees but randomize each click


- media tracker
  - auto label text stuff
  - custom playback speed (clip player, 0x33c)
  - clip browser?

// To get clip from EditorMediaTracker
// offsets: 0x228, 0x80, 0x0


CPlugSurface 0xA0 (160) large

0x18: Buffer<CPlugMaterial>
0x28: Buffer<GmSurfaceIds>
0x38: GmSurf
0x40: Skel

0x68-0x78: uncleared??

0x88: FID -> CustomConcrete_X2.dds



GmSurf: 0x90 (144) large

0x0c: surf type
0x10: ??
0x14: vec3 gameplay dir

0x20: buffer (len: 839)
0x30: buffer<struct 0x10> (len: 1456)
    -> u32, u32, u32, [PhysicsId, GameplayId, ??, 0x0]
0x40: null/buffer (len: 1456)
0x50: null/buffer or nod pool? (len: 2294)
0x68: 0x2
0x6c: vec3?
0x78: vec3?
0x84: ffff / 0
0x88: unk? uncleared?





copy array elements not working properly
water buf
