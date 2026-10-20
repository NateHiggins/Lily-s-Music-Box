# Full-length hose: surface and mesh-cost review

Evidence class: **INERT**. Candidate construction and focused diagnostic;
no runtime contract or V2 completion promotion.

The uninstalled 15.24 m hose now has 82,432 triangles, down from 271,360
(69.6% fewer). Thirty-two cross-section samples and sixteen semicircle samples
retain the original ports and the solved full length. Native review of the
exported candidate still passes 65 rack-bearing rays, 65 deliberately displaced
carrier controls and eight rear-bracket contacts at the original 100-micrometre
tolerance. The maximum resting cloth-bearing gap is 50.366 micrometres. Static
self/case/coating/tin/gasket checks find no crossings in their stated scope.
The shaft, nut and thirteen carriers also retain their measured clearances.

**art/blender/scripts/build_fire_capacity_candidate.py** is the standalone
owning recipe. It writes only beneath repository **tmp** and has no production
publication path. **art/blender/scripts/review_fire_capacity_candidate.py**
reviews the actual finished candidate mesh and fails on failed contact,
crossing or displaced-carrier checks. Its optional render skip reuses already
reviewed images without changing the geometry checks. Editable candidate files
remain in **tmp/v2-fire-hand-20261019/capacity_stock_native1**.

The former global longitudinal chart stretched the inside bends. The revised
unwrap separates the cloth at the bends, follows the warp direction, and
authors surface-metre triangle charts. Whole catalogue tile offsets are removed
from chart phases to improve float precision without changing the sampled linen
pattern. The existing registered custom linen supplies albedo, roughness and
OpenGL normals at its catalogue tile period. No new material key or texture
compression exemption was added. Source and exported tangent derivatives pass.

## Original loaded checks

The original packet is **art/reviews/v2_fire_capacity_surface_20261019**.
It preserves source snapshots, the generated construction record, native
previews and contact diagnostics, original failed and corrected run receipts,
and both windowed voxel-light frames. The later post-run source snapshot is
identified as such; it is not described as a pre-run snapshot.

**stage22_capacity1** failed under default Godot mesh compression: loaded metre
charts stretched by up to 21.2%, and 3,593 tangent derivatives failed. This is
the measured reason for the single-asset full-precision mesh-import policy in
**art/tools/fix_v2_mesh_imports.py**. Texture compression and mipmaps remain
unchanged. The original failure is retained, not replaced by a new result.

After import correction, **stage22_capacity2** completed in 10.16 seconds with
zero failed checks, zero script errors and empty stderr. Actual imported UVs
have maximum edge excess 0.179 micrometres and widest measured scale 1.000859;
all tangent derivatives pass. All three actual loaded PBR images have mip
chains. Both frames use the production reduced carried voxel-light owner,
which initializes successfully without a patterned projector. Its isolated
teardown is warning-free. This narrows the lifecycle investigation; it does
not clear the seven Texture RID warnings from the earlier composed world.
The wrapper is **suite_run**, not a test-written runtime contract.

The native and Godot frames were inspected directly. The candidate shows cloth
weave and bend relief under the offset source, with much darker unlit sides.
These are isolated fitting previews, not an installed-world appearance grant.
Reader baseline reports zero new fields; mesh-import policy check passes.
Four focused surface regressions also pass: import repair preserves unrelated
settings, loaded mipmaps remain mandatory, filtering remains mandatory, and
unused UVs cannot satisfy the surface rule.

## Remaining work

The game asset is referenced only by its candidate bench. It does not replace
the installed cabinet stock. Deployment, refolding, coupled nozzle movement,
all changed rack poses, label/tag clearance, saved-pose reconstruction and
mechanical certification remain unfinished. Complete those before installing
the family and renewing the combined surface, route and eight-station proofs.
Human appearance acceptance and the broader V2 build remain **OPEN**. The
last clean production checkpoint verifier at **5d7fe292** still reports 114
broader regressions; no merge-readiness claim is made for this candidate.
