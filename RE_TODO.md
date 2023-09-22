- shaded_geoms in S2M

- place macroblock air mode
- filter inventory
- favorites for inventory
- check item placed when selecting in manip mesh
- ensure item saved before editing properties
-

- ~~copy placement params from 1 item to another~~
- script to do item manipulation
- investigate placing items on freeblocks when a normally placed block is close
-


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
