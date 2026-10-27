# Maintenance guide-bells

The V2 runtime mounts **MaintenanceGuideBells**, a read-only presentation
adapter. The owner's requirements are in
**design/VORTICELLA_GUIDE_BELLS_BRIEF_2026-10-25.md**. Implementation is separate
from acceptance: the two contract scenes below write their own scoped results.

The adapter reads WorkOrders and the existing first-shift report selection.
It uses an explicitly permitted, acknowledged, diagnosed, awaiting-part or
repairable job. Without a selected report, exactly one eligible job is needed;
multiple candidates produce no trail. Issued, completed and administrative
work produces none. The chirp's acknowledged discovery stage remains
unassisted. A job's **directional_assistance** boolean defaults to false.
This flag changes presentation eligibility, never task selection or progress.
The chirp's physical destination is the existing Vantry network's active owner.

## Supported traversal

**guide_bell_route.gd** builds candidate topology from V2 room rectangles,
openings, doors and native stair landings. Nearby open-plan candidate joins
are allowed only through the same physical checks. Every accepted edge needs
a loaded capsule sweep, unobstructed endpoints, and continuous centre/rim
floor samples. Closed leaves remain ordinary collision; the provider neither
opens nor unlocks them. A missing connection, unavailable floor or exhausted
bounded search returns an empty route. There is no straight-line fallback.
Moving lift travel is not asserted as a supported edge; authored stairs can
provide the alternative. Missing routes suppress presentation.

One polyline supplies placements, remaining distances, and player projection.
A projection across a wall or onto another floor is rejected. Source topology
is not itself proof of current traversability. The current suffix is checked
against physical collision every 0.4 seconds; reconstruction is limited to
0.8-second intervals. Invalid paths clear immediately on detection. Valid
revisions retain correctly projected cells without relocating them, retiring
off-route cells anatomically.

Cells use floor/wall seams, away from door sweeps and collision/interaction
volumes. They stand at decision points at least 2.75 route metres apart, up
to eight at once. On longer routes, previously unrepresented decision points
ahead can enter this bounded window as passed cells finish retracting;
consumed positions do not regrow. Their distal anatomy aims at the next supported route
waypoint; a direct ray through architecture is never used to aim at the
distant repair. The final work stance remains separate from the control.

## Cell and resource ownership

Each cell owns its anatomy instances, shared tissue materials and up to three
small Euplotes presentation instances. They do not enter DreamCritterController
or the tardigrade lunch record. A naturally nearby tardigrade can make the
colony shelter; nothing in the adapter changes the tardigrade's behavior.

Passing uses remaining route metres, a strict 0.55-metre margin and 0.4 seconds
of confirmation. Jitter cancels confirmation. Once wilting begins it cannot
reverse; consumed route coordinates prevent same-visit backtracking regrowth.
Germination takes 1.3 seconds, wilt 1.6 seconds and retraction 0.85 seconds.
The holdfast remains fixed while the stalk, lip, organs and cilia deform.
Cancellation, unloading, anchor replacement and scene teardown synchronously
release cell children and optical registrations. No new save fields exist.
Reconstruction starts from the current player, never an old trail origin.

The custom shaders bind the shared instantaneous lamp field and native lamp
receiver layer. They do not read DreamExposureField. Cloudy membrane transport
uses scene light and real internal geometry; there is no intrinsic emission,
directional glow mask or whole-body alpha fade. Cilia, vacuoles, nucleus,
helical fibers and granules occupy separate native depths. Materials and
textures are shared within a cell and loaded with mipmaps.
The purple membrane uses soft, seeded density patches at several scales.
Thin patches transmit more scene light, while the rim stays thicker and
wilting increases clouding. Its roughness varies with the mottling; transparency
does not come from a whole-body alpha reduction.

## Reproduction and review

- **art/tools/build_guide_bell_maps.py** regenerates the two original PBR recipes
  and registers their material keys.
- **art/blender/scripts/build_guide_bell.py** creates the editable Blender
  source, GLB and native preview. It checks UVs both before and after joins.
- **art/tools/check_guide_bell_asset.py** validates finite, noncollapsed UVs
  in the exported GLB rather than trusting pre-export geometry.
- **game/tests/GuideBellContract.tscn** exercises lifecycle, loaded maps,
  lamp directions, private symbionts, physical route negative controls and
  cleanup in an isolated fixture. Its valve check uses actual grab/motion/release.
- **game/tests/GuideBellWorldContract.tscn** checks the production mount,
  eligibility, physical placement and route queries in the composed building.
  Its observation positions are fixtures, not evidence of played traversal.

Run Godot only through the repository lane with a log path, and use windowed
runs for images. Each test writes a schema-2 runtime contract under SHOT_DIR;
the runner's receipt is separate process evidence. A passing numerical test
does not substitute for inspection of the captured anatomy and route views.
