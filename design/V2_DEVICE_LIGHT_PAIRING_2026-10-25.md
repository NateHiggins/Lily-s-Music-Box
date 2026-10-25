# Configure instrument render layers before insertion

Evidence class: **INERT**. Local renderer reproduction and one occupied-world
repair diagnostic. No schema-2 runtime qualification, general renderer repair,
default companion cutover, performance improvement or human acceptance.

## Defect and repair

The companion world runs in **V2_COMPANION_RENDER_ATTRIBUTION_2026-10-25.md**
end with two renderer-internal light-unpair errors. The production original
carrier uses a private world; the opt-in companion shares the occupied world.
The service prop formerly put the native printer and its labels into the tree
on layer 1, then recursively assigned layer 2 after printer construction.

The current engine identifies itself as Godot **4.7.1 / a13da4feb / Forward+**.
Its [renderer source](https://github.com/godotengine/godot/blob/a13da4feb/servers/rendering/renderer_scene_cull.cpp)
keeps geometry/light associations and checks for leftover associations when
removing a light. Unpairing consults the geometry's current layer. This informs
the reproduction; source inspection alone does not prove which world mesh
produced an error.

Separate windowed processes isolate six primitive conditions and the native
adapter. In **v3**, visible Mesh and MultiMesh layer changes from 1 to 2 each
produce the same two errors. Unchanged layers, preconfigured layer 2, a light
mask change, hiding before a geometry-layer change, and the standalone native
adapter all finish with empty stderr. Successful process exits alone do not
make the two failing renderer cases passes. Their original logs are retained.

The printer now accepts its presentation owner's render layer before entering
the tree. It assigns native meshes before adding the native model, and assigns
each physical Label3D before adding the label. ServiceSetProp supplies its
existing layer 2. Standalone printer callers retain default layer 1. Final
camera/light masks, manufactured stock, materials, print history, circuits,
mechanisms, targeting, WorkOrders and save authorities are unchanged. The
existing final recursive isolation remains as a compatibility guard.

This avoids the demonstrated unsafe registration sequence rather than hiding
lights at teardown or suppressing errors. No engine binary is patched. Other
late-layer-changing systems have not received general qualification from this
instrument-specific repair.

## Actual verification

All runs use the shared-lane wrappers. Sources stay frozen during the combined
**v4** batch. The original ServiceSetHandTest passes **70 checks**, and the
candidate CompanionWorldHandBench passes **83**, both with empty stderr. They
exercise actual keys, primary grabs, mouse travel, next-click releases, limits,
six controls, inspection and interruptions. The original and candidate control
captures and the real recall-face capture were viewed.

Occupied **world_v4** passes **18 checks**, records **1,482 samples**, and ends
with **empty stderr**, including no light-unpair errors. It takes 175 seconds
under the 600-second wrapper ceiling. The route covers the same short entrance
movement/turning, presentation/motion/light controls, recall, inspection and
physical lamp-contact grab/travel/release as the preceding probe. The actual
final world image was viewed. The companion remains **ORISON_COMPANION_WORLD=1**.

The probe now records actual FPS-cap and VSync API readbacks after composition:
**0** and **0**, matching uncapped rendering and VSync disabled. These API
readbacks do not measure driver scheduling or physical display latency.
World construction is **102755.364 ms**. The 1,479 complete postconstruction
wall intervals retain p50 **30.972**, p95 **36.858**, p99 **49.022**, maximum
**5304.446 ms**, including phase-boundary intervals. The largest CPU-observed
pre/post-draw span is **5146.929 ms**. This repair does not remove the first-
render stall. Different cache/order and control sampling forbid attributing
the lower median to this initialization change. No speed improvement is claimed.
The repeated 8×/4×/8× warmed medians are **30.158 / 30.214 / 30.353 ms**;
8× remains installed. Cell transitions, furnishings, save/rebuild and general
mirror-aware companion navigation remain outside this short route.

## Original failures and issue log

The first combined local reproduction has the original four errors intact.
The **v2** isolation batch used a CLI delimiter that preceded the runner's
appended scene path. It launched the default scene instead of the probe.
Its first run reaches wrapper timeout **124**, with no suite verdict. The
second mislaunch is aborted only after checking the owned broker and Godot
descendant identities; no other process is stopped. All logs, any existing
wrapper receipts and the abort annotation are preserved. These mislaunches
prove no pairing behavior or performance result. Explicit scene variants in
**v3** avoid that argument ordering. Early invalid static-audit flag attempts
are recorded as tooling mistakes; corrected invocations complete successfully.

| Location / reproduction | Severity / evidence | Repair / verification |
|---|---|---|
| Shared-world instrument startup then teardown | Renderer lifetime defect: two light-unpair errors in prior world runs | Set native mesh/label layers before tree registration; v4 world stderr empty, 18 functional checks pass |
| Visible primitive Mesh or MultiMesh, change layer after rendering | Isolated renderer repro: two errors per process | Preserve negative controls; preconfigured and hidden-before-change controls have empty stderr |
| First composed-world draw | High: 5304.446 ms wall, 5146.929 ms render boundary | Unresolved; API cap/VSync readback added, no optimization claimed |
| v2 isolation batch | Diagnostic invocation defect, no pairing verdict | Explicit exported scene variants; timeout and owned abort preserved |

Raw outputs, captures, before/after sources, runner receipts and a hashed
**archive.json** are in **art/reviews/v2_light_pairing_20261025**. These are
INERT diagnostics. The test writes no runtime-contract receipt. Existing
failed observations are not replaced by the clean follow-up.

REPORT - device-light-pairing - 2026-10-25

Branch / starting HEAD / integrated main parent:
**codex/v2-main-integration-20261024 / 7770040b / bde30c08**.
Named paths only; canonical shared changes and 596 unrelated orphan UIDs
preserved. No import sidecars changed. Protected17 and selector logic are
unchanged by this checkpoint. Ledger changes: none claimed. Reader: zero NEW
fields. Spatial: clean. Authority: zero NEW actionable/policy failures and the
same 23 review-only findings. No new physical stock or material catalogue key.
Full candidate verification, source-bound surface/global access/save renewal,
companion typing/context/persistence and the remaining started V2 work stay
open. Decision needed from owner: none. The full goal remains active.
