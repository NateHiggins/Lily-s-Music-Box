# Adela temporary model follower — November 3, 2026

Evidence class: **INERT**

Owner request: ingest Lily's newly downloaded animated Adela and have her follow
for now. This records authored work and native checks, not runtime acceptance.

## Installed candidate

Source ZIP SHA256 **c2bef9d98c60097e18e9e7115cceb93fa0a0a2f60d9aeca2d656440747931333**.
Original ZIP, FBX, source maps, editable Blender file and failed candidates remain
outside packaging at **C:/ov/asset-prototypes/adela-model-intake-20261103/**.
The runtime GLB retains the supplied 28-bone skin, original appearance and scale,
with personal walking/running and a restrained authored breathing idle.

The registered **resident_adela_voss** finish uses original atlas UVs and 2048px
albedo, normal and roughness. No generated likeness, donor rig, lights, dialogue,
resident schedule or persistent facts were added.

Native triangulation yields156,822 triangles. Microscopic source slivers needed
at most0.01002mm vertex adjustment and subpixel UV repair. Existing native export
hooks write correct UV frames; incompatible corners are split while preserving
positions, weights and joints:206,596 exported vertices,16,022,216-byte GLB.
The unchanged strict derivative checker passes all156,822 triangles; maximum
skin-weight sum error is1.79e-7. Earlier missing/invalid tangents, a truncated
index-count export and one quantized handedness failure are retained in
**NATIVE_FAILURES.json**; the producer now asserts the complete triangle count
before promoting its output. These checks do not establish runtime cost or look.

## Temporary behavior and boundaries

**adela_preview_follower.gd** follows bounded samples of the player's actual
walked path with a world-colliding capsule, short-step support, walk/run/idle and
no obstruction bypass. Protected input and pause hold it. Large path discontinuity
or overflow waits for reconnection rather than teleporting through geometry.

The V2 root enables this preview in debug after the prologue, with
**ORISON_ADELA_FOLLOW=0** to disable; release builds require explicit value1.
It stays outside resident, mystery, inventory, relationship, quest and save owners.
This visual preview does not establish Adela's presence on a narrative date.

## Verification and next action

CPU source previews were inspected; native atlas/export/skin checks and reader
NEW0 pass. No Godot import, loaded-mipmap observation, follower playtest or artistic
acceptance is claimed yet. The live shared-lane batch is recorded in
**C:/ov/reports/adela_follow_20261103/intake_01/**: two imports, changed-script
compile, then rendered real-controller bend/obstacle/step/prologue/pause checks.
Production-world following, appearance and cost remain open, as does renewal of
qualification invalidated by these new production inputs. PR151 is still draft.

Follow-up diagnostic preparation: the installed-world driver now exercises the
real first stair as well as a short corridor, captures the loaded actor and
records uncapped enabled/hidden/enabled frame samples. This is an observation,
not a controlled whole-game performance qualification. It is queued separately
at **C:/ov/reports/adela_follow_20261103/world_02/**, broker23664/session78725;
a guard refuses execution unless the isolated fixture passed on identical
production inputs. Its last stage compiles the nook inheritance chain in order
to expose the unresolved parent-class failure; it does not run the nook route.
Twenty-five existing material-catalogue, additive-binding and runtime-source
projection unit tests pass. No engine result is implied by these Python tests.
