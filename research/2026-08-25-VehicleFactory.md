# Scene vehicle factory (lifecycle handle)

Shipped `create` / `spawn` / `addN` go through `SpawnStadium`. `destroy` / `release` call `SceneVehicle.Release()`. Handles stay 1:1 with `ownedVis`. Unload `DestroyVis` first.

`ManageVehicles::SceneVehicle` is a handle whose `Release()` / destructor tears down the listed vis **and** the HMS dyna instance. Do not list-only forget a Bind car.

## API

```
ManageVehicles::SceneVehicle@ v = ManageVehicles::SpawnStadium(vec3(64, 64, 64));
v.Pose(vec3(80, 64, 64));          // AsyncState + dyna rec+0x08
v.Pose(vec3(80, 64, 64), yawRad);  // same + yaw around Y
v.SetSkin("Stadium_FRA");         // recreate-in-place with a new wrap dest
v.SetEveryTick(true);
v.Destroy();                      // alias of Release()
v.Release();                      // restore vis+0x50 instance id, official DestroyVis
```

Per-car `dest` / `model` / `skin` live on the handle (not only process globals `lastSkinnedS2m`). Export is MCP-only (`Editor::DevTest::ManageVehiclesOp`) — no new shared type, no game restart.

`~SceneVehicle` calls `Release()`. Last handle drop is enough. `ownedHandles` is detached on Release so the array does not pin a dead car.

## What Release does

Same path as shipped destroy: stash/restore Bind instance id, then AsCall `Unbind(*SMgr, vis)` (which calls `CHmsMgrVisDyna::InstanceDestroy`). Official `DestroyVis` via OnAction wraps the dying vis and AVs Openplanet.dll at +0x240. After a clean release, `dumpDyna` is `live+0x98=0`. Destroy-all / sweepDyna never touch official Test vis.

`ForgetOwned` still does **not** destroy vis or HMS.

## Pose (why the factory writes the dyna rec)

Listed vis keep `vis+0x50 == -1` (073C58D: `model+0x208[SMgr]` miss). The drawn mesh is the HMS record iso4 at `table + id*0x78 + 0x08`. See `research/2026-08-25-HmsVisInstances.md`.

## Predicates

- `SceneVehicleFactoryOk(ownedBefore, ownedAfter, alive)` — spawn is owned+1 and alive
- `SceneVehicleReleaseOk(aliveBefore, ownedBefore, aliveAfter, ownedAfter)` — release drops owned and marks dead
