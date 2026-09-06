# Solid2 smooth normals: live GPU refresh and Item.Gbx persistence

Current `Trackmania.exe` (`0x140000000`) Ghidra audit, 2026-09-03. This is a
research receipt; no plugin code was changed. Ghidra names, prototypes, types,
plate comments, and instruction comments were improved during the pass and the
project was saved.

## Answer

**Yes, with an important qualification.** A `CPlugVisualIndexedTriangles`
already used by a `CPlugSolid2Model` can have its smooth normals replaced while
the item is open and already rendered, provided its existing
`CPlugVertexStream` has:

- a CPU-accessible Position descriptor (semantic 0),
- a CPU-accessible Normal descriptor (semantic 5),
- retained CPU index data,
- matching logical vertex/index counts, and
- no concurrent rebuild/reload while raw pointers are in use.

The descriptor's `pCpuData` is not the backend/GPU buffer. It is retained CPU
attribute storage. Both the Item.Gbx serializer and the renderer upload path read
from it. Consequently, normals written there are genuinely archived. To make an
already-created GPU resource show the new normals immediately, the stream must
also enter the native dirty/refresh callback path.

There is no native in-place "generate Solid2 smooth normals" method. The only
confirmed generator, `NPlugModel_MeshConvertPolySmoothingGroupsToPolyNormals`
(`0x140673B60`), belongs to the earlier `CPlugModel` authoring/export pipeline.
For an already-interned Solid2 visual, E++ must compute normals itself and write
the existing Normal stream.

Do **not** manufacture `CPlugVisual3D::Vertexes` on a stream-backed visual. That
creates a conflicting CPU-visual archive path (`0902C004`) and has already
crashed on reload/exit at `Trackmania.exe+0x18D74FB` (`0x1418D74FB`).

## Relevant live layouts

### `CPlugVisual` / `CPlugVisual3D` / indexed triangles

| Object | Offset | Meaning |
|---|---:|---|
| `CPlugVisual` | `+0x24` | flags; bit 7 (`0x80`) is `UseVertexNormal` |
| `CPlugVisual` | `+0xB8` | number of vertex-stream refs (archive bound: at most 4) |
| `CPlugVisual` | `+0xC0` | pointer to first `CPlugVertexStream` ref |
| `CPlugVisual3D` | `+0x130/+0x138/+0x13C` | CPU `Vertexes` pointer/count/capacity, record stride `0x28` |
| `CPlugVisualIndexed` | `+0x180` | `CPlugIndexBuffer*` |
| `CPlugIndexBuffer` | `+0x20` | packed static/index-format flags |
| `CPlugIndexBuffer` | `+0x28/+0x30/+0x34` | retained CPU index pointer/count/capacity |

For a normal stream-backed Solid2 visual, `nVertexStreams != 0` and the
`CPlugVisual3D` CPU vertex count should remain zero.

### Corrected `CPlugVertexStream` (`0x09056000`, size `0x70`)

| Offset | Field | Persistence/lifetime meaning |
|---:|---|---|
| `+0x18` | `pRenderWrapper` | Vision-owned `0x38`-byte renderer wrapper; backend resource is wrapper `+0x28` |
| `+0x20` | `pGpuBufferResource` | separate refcounted `CPlugGpuBuffer` resource |
| `+0x28` | `pSharedSource` | optional shared `CPlugVertexStream`; archived as a Nod ref |
| `+0x30` | `nVertexCount` | **logical** vertex count used by archive and upload |
| `+0x34` | `nAllocatedVertexCount` | allocated CPU vertex capacity/count |
| `+0x38` | `dwFlags` | bit 0 static; bit 1 renderer dirty/queued; bit 4 suppresses dirty callback |
| `+0x3C` | `dwLayoutMask` | derived semantic/layout mask |
| `+0x40/+0x48/+0x4C` | descriptors pointer/count/capacity | descriptor stride `0x10` |
| `+0x50/+0x58` | `pCpuMirror/cbCpuMirror` | retained CPU storage consumed by save and GPU upload |
| `+0x60` | `pOwnedAlloc` | game-heap allocation owned by this stream |
| `+0x68` | `nSharedUsers` | incremented/decremented on a shared source |

`CPlugVertexAttributeDescriptor` is exactly `0x10` bytes:

```text
+0x00 void* pCpuData
+0x08 u32   dwSemanticFormatStride
             bits 0..8   semantic (0 Position, 5 Normal)
             bits 9..17  format (2 Float3, 14 Dec3N)
             bits 18..27 source stride
             bits 28..31 encoding mode
+0x0C u32   dwOffsetAndFlags
             bits 2..11 byte offset; bit 1 disables renderer upload
```

Important correction to the current spike: `IE_Visual.as` reads vertex count at
stream `+0x34`. Current native code proves that the logical/serialized count is
`+0x30`; `+0x34` is allocation state. Until that source is corrected, a live
probe is safe only when `+0x30 == +0x34`. Otherwise it can read/write capacity
tail vertices.

## Confirmed native path

### 1. Native normal generation is an authoring-stage path only

`NPlugModel_MeshConvertPolySmoothingGroupsToPolyNormals` (`0x140673B60`) requires
`CPlugModel+0x150 & 2`, an authoring polygon mesh, smoothing-group adjacency,
and poly attribute channels 2/3. For each polygon vertex it walks neighboring
faces admitted by the smoothing-group mask, deduplicates coincident face
normals, sums them, normalizes the sum, and writes authoring poly-normal IDs.

Its sole direct caller is `0x14067EB80`. That caller invokes the generator while
exporting/converting `CPlugModel`, before visuals are built. It then clears the
authoring-state bit and proceeds into visual construction. It is not callable as
an in-place `CPlugSolid2Model` or `CPlugVertexStream` normal generator.

`CPlugImportMeshParam::ForceSmoothNormals` is likewise only an import parameter
at `+0x1C` (`Register_CPlugImportMeshParam_ClassInfo`, `0x140617A80`). It is not
a runtime Solid2 switch.

### 2. The visual flag does not generate data

`CPlugVisual_SetUseVertexNormal` (`0x140405050`) changes flags `+0x24` bit 7. If
the state changes and visual dirty suppression is not active, it also sets the
visual dirty bit and invokes the visual dirty callback. It never touches vertex
bytes.

`CPlugVisual_ApplyVertexDeclLayout` (`0x140404890`) sets `UseVertexNormal` when
the material/declaration mask already includes normals (`0x40`). It also does
not generate any normals.

### 3. Solid2 archives the visual and stream bytes

The full write path is:

```text
CPlugSolid2Model_SerializeArchiveChunk                 0x140437DB0
  CPlugSolid2Model_SerializeChunk000Body              0x1404372F0
    GbxArchive_SerializeVersion10_CPlugVisualVector   0x14043E080
      indexed CPlugVisual ref (usually 0901E000 concrete class)
        CPlugVisual_SerializeArchiveChunk             0x140402020
          chunk 0900600F
            packed visual flags (includes UseVertexNormal)
            logical vertex count
            indexed CPlugVertexStream refs
              CPlugVertexStream_SerializeArchiveChunk 0x140447530
                chunk 09056000
                  logical count from stream+0x30
                  stream flags
                  optional shared-source Nod ref
                  descriptors
                  descriptor-derived attribute bytes
        CPlugVisual3D_SerializeArchiveChunk            0x14049A160
        CPlugVisualIndexed_SerializeArchiveChunk       0x1404588F0
          nested CPlugIndexBuffer archive
            CPlugIndexBuffer_SerializeArchiveChunk    0x140429AC0
```

At `0x140447530`, when `pSharedSource == null`, the writer iterates each
descriptor and copies `element_size(format) * nVertexCount` bytes from that
descriptor's `pCpuData`, stepping by the packed source stride. The normal bytes
written by E++ are therefore the exact source of the normal plane in the GBX.
The writer may encode Float3 normals as Dec3N depending on descriptor encoding;
the reader reverses that conversion.

When `pSharedSource != null`, the borrowing stream archives that stream Nod ref
and omits its local descriptors/data. `CPlugVertexStream_SetSharedSource`
(`0x140448520`) restores the borrower by copying the source count, flags,
descriptors, and CPU mirror pointers. The source stream is itself serialized on
its first indexed-Nod occurrence, so the bytes still persist. This also means a
write through a borrowed descriptor changes **every visual sharing that source**.

The index buffer remains CPU-backed too. Current chunk `09057001` serializes its
retained u16 index vector; on write it delta-encodes the vector in place, writes
it, then restores absolute indices by prefix sum.

### 4. Reload reconstructs CPU storage, then GPU storage

On read, `CPlugVertexStream_SerializeArchiveChunk`:

1. validates the logical count (`< 0x10000000`);
2. allocates game-heap CPU storage;
3. rebuilds descriptor pointers into that storage;
4. reads/decodes every attribute plane;
5. restores `+0x30` logical and `+0x34` allocated counts;
6. restores optional shared-source ownership; and
7. rebuilds the layout mask.

`CPlugVisual` restores the stream refs and packed visual flags. When streams are
present, it intentionally does not construct CPU `CPlugVisual3D::Vertexes`.
Solid2's post-read functions rebuild material/skeleton/LOD derived tables but do
not recalculate normals.

When Vision installs the visual, `Vision_CreateVertexStreamRenderWrapper`
(`0x140980540`) creates stream `+0x18`; `RenderVertexStreamBuffer_CreateAndUpload`
(`0x140A7D120`) allocates the backend resource and
`RenderVertexStreamBuffer_UploadCpuMirror` (`0x140A7D660`) uploads attributes
from `pCpuMirror`. Cold reload therefore displays the archived normals without
another generation pass.

### 5. Already-loaded GPU refresh is a separate path

Internal vertex-stream mutators follow the same sequence:

```c
old = stream->dwFlags;
mutate_cpu_storage();
if ((old & 0x2) == 0) {
    stream->dwFlags = old | 0x2;               // renderer dirty/queued
    if ((old & 0x10) == 0 && g_ctx && g_cb)
        g_cb(g_ctx, stream);
}
```

Current globals are:

- `g_vertexStreamDirtyContext` at `0x14201E5C8`;
- `g_vertexStreamDirtyCallback` at `0x14201E5D0`;
- current callback `Vision_QueueOrRefreshVertexStreamRenderWrapper`
  (`0x140980640`).

The callback refreshes immediately when legal or queues the stream for
`CVisionViewport_OutOfRenderUndirtyAll` (`0x1409D44A0`). That drain calls
`Vision_RefreshVertexStreamRenderWrapper` (`0x140980620`), which reaches
`RenderVertexStreamBuffer_Refresh` (`0x140A7DB60`). Dirty bit 1 recreates the
backend resource; otherwise the retained CPU mirror is uploaded. Upload ends in
`CPlugVertexStream_ClearGpuRefreshDirtyFlags` (`0x140448380`), clearing bits 1
and 4.

This proves the native refresh mechanism. It has not yet been invoked from
AngelScript in a live item-editor session, so the bridge into it remains a
live-validation item, not a shipped recommendation.

### 6. Item-editor save does no geometry conversion

The current save chain is:

```text
CGameEditorItem_SuperEditor_DoSave                    0x1411088B0
  FiberSaveItem                                       0x1410F6160
    CGameEditorItem_SaveItemToFidCallback             0x1410F6110
      CGameEditorItem_CompleteSaveOperation           0x1410F7C60
        NGameEditors_SaveNodToFidWithAssociationCleanup 0x140EBB3E0
          GbxArchive_SerializeNodToFid(fid, item, 10)  0x140905090
```

There is no visual intern, GPU readback, normal generator, or geometry cleanup
in this chain. `AfterSave` runs only after a successful save. Thus:

- saving archives the CPU descriptor bytes currently present;
- a GPU-only poke would not persist;
- waiting for GPU refresh is useful for visual confirmation, but not required
  for serialization; and
- reopen must wait for positive save completion, not a fixed one- or two-frame
  delay.

## Topology and smoothing preconditions

The spike's cross-product accumulation is area-weighted: each triangle adds the
unnormalized face cross product to all three referenced vertices, then each sum
is normalized.

- If faces share an index, that vertex can store only one normal. Averaging all
  incident faces makes that indexed fan smooth.
- A crease-angle threshold cannot preserve two different normals on one shared
  index. Hard edges require splitting the vertex, duplicating **all** attributes,
  and rewriting affected indices before normals are calculated.
- Existing duplicate vertices (UV seams/material seams) can still be visually
  smooth if equivalent positions are grouped and assigned the same accumulated
  normal. They need not be welded, but the grouping rule must deliberately avoid
  real hard edges.
- Degenerate triangles should contribute nothing. A zero-length final sum needs
  an explicit fallback or should preserve the previous normal; silently using
  `+Y` can create visible spikes on isolated vertices.

For the first safe implementation, support only the existing topology and
produce a fully smooth fan per shared index. Vertex splitting/crease thresholds
are a separate topology-editing feature with much greater archive and lifetime
risk.

## Recommended safe sequence

### Review correction (2026-09-03)

The dirty/refresh callback sequence is proven as native behavior, but direct
invocation from AngelScript has not been live-validated. This receipt therefore
does not recommend it as a production step: it is an optional disposable-copy
probe after CPU-only persistence is proven. The existing `ItemEditor::SaveLoad`
dialog helper also uses fixed yields, so it is not treated as a positive native
save-completion signal.

### Confirmed portions through the CPU commit

1. Run on the main/game coroutine while `CGameEditorItem`, its `ItemModel`, the
   target Solid2, visual, stream, and index buffer are stable. Hold Nod handles;
   do not cache raw addresses across a yield.
2. Require an existing stream-backed visual and require
   `CPlugVisual3D::nCpuVertexes == 0`.
3. Resolve fresh descriptors by semantic. Require Position semantic 0 Float3
   and Normal semantic 5 in Float3 or Dec3N, both CPU-accessible. Reject missing
   Normal; do not grow the live descriptor vector in place.
4. Use logical vertex count `stream+0x30`, not allocation count `+0x34`. For the
   current spike, require them equal until its offset is fixed.
5. Require retained CPU indices, triangle count divisible by three, a supported
   u16 layout for the first implementation, and every index `< nVertexCount`.
6. Snapshot positions and indices into AngelScript arrays first. Compute and
   validate all finite normalized results before touching native memory.
7. In one non-yielding commit, write the complete Normal attribute through its
   existing `pCpuData`; preserve stream ownership/layout/counts and leave CPU
   `Vertexes` empty.
8. Set `UseVertexNormal` through the reflected/native setter so the visual flag
   is dirty and will be archived.
9. For persistence, invoke the normal item-editor save after the CPU commit.
   The existing `ItemEditor::SaveLoad` helper's fixed yields are not a positive
   completion signal; wait for the native save result/`CGameEditorItem_AfterSave`
   or otherwise prove the save completed before reopening the item from disk.
10. On the reloaded Nod graph, re-resolve all pointers and verify: stream count,
    semantic-5 descriptor, nonzero normal count, `UseVertexNormal`, and rendered
    appearance. Never touch the old raw addresses again.

### Plausible but not yet live-tested portions

- An AngelScript/`Dev::Function` wrapper for the exact dirty sequence and
  callback globals may make an already-loaded GPU resource update without
  leaving/reopening the editor, but it is not yet safe to recommend or ship.
  The native callback has renderer-wrapper, Vision-device, TLS, and queue
  lifetime preconditions that have not been exercised from AngelScript. A
  disposable-copy, main-thread probe must first validate the ABI, current-build
  guard, queued-drain terminal, and reload/unload behavior; absolute addresses
  are research evidence, not a durable shipping ABI.
- If dirty bit 1 is already set, the native convention is to avoid a second
  callback because a refresh is presumed queued. A live probe must confirm the
  item-editor stream cannot remain dirty-without-being-queued after unusual
  reload/error paths.
- Shared-source writes should persist through the source stream archive, as the
  serializer proves. Whether changing all sharers is acceptable is item-specific
  and must be shown in the UI before commit.
- A save immediately after the CPU write should persist even before GPU upload,
  because archive reads the CPU descriptor. The first live probe should still
  wait for refresh to make failures observable before writing a test file.

## Rejected unsafe paths

### Populate `CPlugVisual3D::Vertexes` on a stream-backed visual

Rejected. `CPlugVisual` chunk `0900600F` restores vertex count differently when
streams exist, while `CPlugVisual3D` chunk `0902C004` consumes its count from the
CPU-visual state without an independent count word. Creating both
representations produced a file whose load skipped/contradicted the expected
state and crashed at `0x1418D74FB`. The current spike's `EnsureCpuVertexes` path
must never be used for a visual with `nVertexStreams != 0`.

### Write the backend renderer/GPU allocation

Rejected. The backend buffer is behind the Vision wrapper at stream `+0x18` and
is not read by the GBX serializer. Mapping rules and render-thread ownership also
make a direct poke race-prone. Write retained CPU descriptor storage and ask
Vision to upload it.

### Call reset functions as a refresh mechanism

Rejected:

- `CPlugVisual_ResetGeometry` (`0x140403BD0`) zeros vertex count, invalidates
  AABB, and clears an auxiliary buffer;
- `CPlugVisual3D_ResetGeometry` (`0x14049A860`) can free CPU vertices; and
- `CPlugVisualIndexed_ResetGeometry` (`0x140458C40`) additionally resets the
  index buffer.

They destroy geometry state; they are not renderer invalidation helpers.

### Rebuild descriptors on an already-interned shared stream

Rejected for the first feature. `CPlugVertexStream_ConfigureDescriptorsAndCpuStorage`
(`0x140448F00`) clears shared-source ownership, recreates descriptors, reallocates
CPU storage, and queues GPU recreation. Calling it requires exact declaration,
material, packing, and sharing inputs. A wrong mask or lifetime decision can
invalidate every pointer held by the live visual and serializer.

### Cache raw stream/descriptor/index addresses across save or yield

Rejected. Descriptor rebuilds and vertex growth reallocate storage; item reopen
destroys the old visual graph; a shared source can detach; and renderer
transitions can release `+0x18`. Re-resolve after every yield or native operation
that can rebuild/reload.

### Toggle `IsStatic` off/on merely to obtain its dirty callback

Rejected as a production mechanism. `CPlugVertexStream_SetIsStaticAndQueueGpuRefresh`
(`0x140448390`) does queue the correct callback, but an immediate callback can
recreate the backend resource during the temporary wrong state. Use a dedicated
wrapper for the native dirty sequence instead.

## Live-validation plan

Use a copy of a small custom item with one indexed-triangle visual and obvious
curved/faceted geometry. Do not test on the only copy of an item.

1. **Cold baseline:** reopen the copy, record visual pointer, stream/source
   pointer, `+0x30/+0x34`, descriptor table, index count/type, normal checksum,
   and a screenshot. Confirm CPU `Vertexes` count is zero.
2. **Dry computation:** compute normals into script arrays only. Reject any
   out-of-range index, non-finite position/result, unsupported format, count
   mismatch, or missing semantic. Confirm no native bytes changed.
3. **CPU commit without save:** write the Normal descriptor and immediately
   reread/checksum it. Confirm Position/other attribute checksums and all counts
   are unchanged.
4. **Optional GPU-refresh probe:** only after the CPU-only persistence path is
   proven, execute the guarded dirty-callback bridge on a disposable copy.
   Observe dirty bit 1 set, then cleared by `0x140448380`; take a screenshot
   showing the shading change. If the bit never clears, do not continue that
   bridge experiment—reload the item copy. This is not a prerequisite for the
   CPU descriptor bytes to serialize.
5. **Save copy:** save under a new filename and wait for positive native save
   completion/`AfterSave`. Preserve the pre-save file.
6. **Cold reload:** reopen the new file. Re-resolve every pointer. Verify the
   semantic-5 checksum (allowing Dec3N quantization), bit 7, CPU `Vertexes == 0`,
   unchanged indices/positions, and the same visible shading.
7. **Second process/game reload:** close/relaunch Trackmania, reopen once more,
   and repeat the checks. This rules out persistence that came only from the
   in-memory Nod cache.
8. **Shared-source case:** only after the unshared case passes, test a visual
   whose stream `+0x28` is non-null. Enumerate all borrowers before writing and
   prove the save/reload result consistently changes exactly those sharers.
9. **Failure forensics:** on any crash, first run `tools/tm_logs.py`; record RIP,
   Called-from chain, `Openplanet.dll` versus `Trackmania.exe`, and the exact last
   completed phase. Relaunch with `tm-launch-direct --wait`, then reload the
   untouched baseline copy.

Acceptance is not just "the open editor looks smooth": the test file must retain
the normals after a full game restart, contain no CPU `0902C004` representation
for the stream-backed visual, and pass two save/reopen cycles without a crash.

## Ghidra improvements made in this pass

The database now has corrected real layouts for `CPlugVertexStream` and the new
`CPlugVertexAttributeDescriptor` structure. In particular, the former mistaken
`+0x28 pGpuBuffer` label is now `pSharedSource`; `+0x18` is the render wrapper;
`+0x30/+0x34` are separated into logical/allocation counts; and `+0x68` is the
shared-user count, not an allocation byte count.

Functions renamed, typed, and plate-commented:

| Address | Name |
|---:|---|
| `0x140447440` | `CPlugVertexStream_Destruct` |
| `0x140448380` | `CPlugVertexStream_ClearGpuRefreshDirtyFlags` |
| `0x140448390` | `CPlugVertexStream_SetIsStaticAndQueueGpuRefresh` |
| `0x1404484B0` | `CPlugVertexStream_RebindSharedCpuPointers` |
| `0x140448F00` | `CPlugVertexStream_ConfigureDescriptorsAndCpuStorage` |
| `0x1404491B0` | `CPlugVertexStream_SetDescriptorListAndVertexCount` |
| `0x140449320` | `CPlugVertexStream_InsertVertexRange` |
| `0x140449580` | `CPlugVertexStream_SetVertexCountAndQueueGpuRefresh` |
| `0x14044A9E0` | `CPlugVertexStream_MoveVertexRangeAndQueueGpuRefresh` |
| `0x14044B140` | `CPlugVertexStream_HasVerticesAndDescriptors` |
| `0x140980620` | `Vision_RefreshVertexStreamRenderWrapper` |
| `0x140980640` | `Vision_QueueOrRefreshVertexStreamRenderWrapper` |
| `0x1409D44A0` | `CVisionViewport_OutOfRenderUndirtyAll` |

Instruction comments were added at the Solid2 visual-vector archive call,
VertexStream shared-source decision, per-descriptor byte write, dirty-bit/tail
callback, renderer upload, and out-of-render queue drain sites.

Save-path improvements made concurrently in the shared database and incorporated
here: `CGameEditorItem_SaveItemToFidCallback` (`0x1410F6110`),
`NGameEditors_SaveNodToFidWithAssociationCleanup` (`0x140EBB3E0`), and
`Register_CPlugImportMeshParam_ClassInfo` (`0x140617A80`).

## Source cross-checks

- `src/Components/ItemEditor/IE_Visual.as`: current descriptor parsing,
  normal accumulation/write, and the unsafe CPU-buffer avoidance comment.
- `src/Components/ItemEditor/ItemBrowser.as`: editable visual flags,
  `RecalcSmoothNormals`, and counts shown in the browser.
- `src/ItemEditor/SaveLoad.as` and `src/Editor/Items.as`: current save/reopen
  helpers and their coroutine/yield behavior.
- private `2026-09-02-CPlugVisualFlagsAndNormals.md`: prior flag/generator
  baseline.
- private `2026-09-02-ItemBrowser-Geometry-RE.md`: audited class/vtable/archive
  baseline used before this deeper serializer/renderer trace.
- `research/2026-08-22-GbxFidRefSave.md`: item-editor GBX archive entry chain.
