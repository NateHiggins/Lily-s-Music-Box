# Full-length hose: native skin and constrained hand motion

Evidence class: **INERT**. Candidate kinematics and focused input review;
no installed-world, deployment or runtime-contract acceptance.

The full 15.24 m cloth candidate now has a Blender-authored skin with 644
independent ring bones. Its existing 82,432 triangles, hollow cloth sections,
metre UVs and registered custom linen remain. The owning recipe is
**art/blender/scripts/build_fire_capacity_rig.py**. Editable rig output remains
under **tmp/v2-fire-hand-20261019/capacity_rig_native1**. No glTF was hand-edited.

**game/scripts/props/hose_length_constraint.gd** solves endpoint movement while
retaining every authored segment length and the fixed upper port. It rejects
nonfinite inputs, nonconvergence, stretched saved poses and a caller's contact
veto atomically. The total-length check also prevents many individually small
segment errors from accumulating into extra stock. Overreach stops at the
measured full length. This is a kinematic strand; it does not provide gravity,
self-contact, world collision or rack support on its own.

**game/scripts/props/native_hose_rig.gd** transports the actual imported bind
frames and expands the mesh's culling bounds as it moves. It preserves the
native finish and does not own maintenance facts. Its physical positions can
round-trip through JSON. This is not household persistence integration or a
disk/rebuild qualification. The rig projection is a test fixture because only
the candidate bench consumes it; no unused production data was registered.

## Original failures and corrected input evidence

The original packet is **art/reviews/v2_fire_hose_motion_20261019**. It retains
the first failed run, its failed frame and exact helper sources, the corrected
run, expanded final checks, native construction record and render snapshots.
Later source snapshots are identified as post-run, not pre-run captures.

**stage23_rig1** failed its rest-pose and cursor tests. The bone driver used
the older rest-relative convention, collapsing the skin, and the cursor sample
was outside the actual 23 mm fitting radius. The corrected driver supplies the
complete parent-local pose and the test targets the real annular stock. The
Godot documentation explains that 4.x bone poses include their rests:
[retargeting 3D skeletons](https://docs.godotengine.org/en/stable/tutorials/assets_pipeline/retargeting_3d_skeletons.html).
The actual installed-engine run, rather than that reference alone, proves the
corrected behavior here. No acceptance tolerance was loosened.

**stage23_rig2** passed the corrected programme. **stage23_rig3** then passed
the expanded programme, including maximum reach and cumulative-length negative
controls. The cursor targets a native fitting; a real primary-click event
grabs it without moving it, actual mouse motion moves the skinned cloth, and
the second click releases without snapping. Every segment and the upper port
retain their constraints; all 644 actual skeleton bones agree with the solved
points at rest, maximum extension and the moved pose. Camera framing stays
fixed. The measured small mouse gesture took about 0.5 ms, which is not a
full-deployment performance claim. Original and moved frames were inspected.

The same focused run retains the loaded UV/tangent checks and all three real
PBR mip chains, and renders under the production reduced carried voxel light.
It exits with zero failed checks, zero script errors and empty stderr. The
wrapper is **suite_run**, not a test-written runtime contract. Moving-pose UV
density and tangent behavior over complete deployment still need qualification.
Reader baseline returns zero new fields after moving candidate-only projection
data into the test fixture directory; the first six unread findings are kept.

## Work still required

This candidate remains referenced only by its bench. No installed fire cabinet
or original maintenance, inventory, save or NPC owner was changed. The native
fitting is a candidate grab handle, not a qualified attached-nozzle assembly.
The exercise proves bounded hand motion and a skinned response; it does not
prove complete paying-out, gravity, collision against the full cloth profile,
self-contact, rack release/refolding, coupled nozzle travel or all saved poses.
Those physical behaviors must be completed before world installation and the
combined surface, route, disk and eight-station programmes. Human appearance
acceptance and the broader V2 build remain **OPEN**.
