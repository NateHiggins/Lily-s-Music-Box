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

## First engine preflight and consolidated retry

The first two patched-engine imports completed in55.86s and12.14s, with zero
script errors. Production follower and runtime-root compilation passed. The
isolated fixture failed to compile at its untyped animation-position snapshot;
its rendered test was **not executed**. The snapshot now declares float, and the
world driver's adapter-derived position declares Vector3. Assertions are intact.
Original receipts remain in **intake_01/** under the external report directory.

The pending **world_02** job was cancelled while queued with no child process;
its guard could not pass because the isolated test never ran. A consolidated
**intake_02/batch.json** now queues compile, rendered isolated following, installed
corridor/stair/cost observation, then topological nook-parent compile. Live broker
**32268**, session**80997**. Do not restart original62828/6266 or23664/78725.
No imports are repeated; no runtime movement result is claimed yet.

Three final-GLB CPU round-trip previews (idle/walk/run) were inspected individually.
The156,822-triangle skinned export and texture layout survive reimport. Blender's
extra80-triangle bone-display helper is identified separately in
**RUNTIME_ROUNDTRIP.json**. Native review does not establish Godot optics or feel.

The importer rewrote437 otherwise identical import files; each was restored only
after its LF bytes matched HEAD. Its704 newly generated untracked legacy UIDs
were removed only with import-log or sole-import creation-window provenance,
tracked source ownership and origin/main absence checks. Recovery records remain
external in **IMPORT_CHURN_REVIEW.json** and **GENERATED_UID_CLEANUP.json**.
Adela's three new script UIDs and complete imported texture settings are retained.

Before retry admission, the installed-world driver was strengthened to write its
own schema2 **runtime_contract** with fixed production/test/dependency hashes,
five actually played movement legs and explicit capsule/catch-up assertions.
Its new hash-bound source/scene are marked **-text**. Optical and frame-time data
remain separately labelled INERT. This is authored verification only until run;
no contract result exists yet. The isolated fixture remains a narrower diagnostic.

## First rendered fixture: step failure retained

**intake_02** compiled all five scripts successfully. Its native3440x1440 fixture
then ran15 assertions:13 passed and2 failed, both on resuming across the150mm
step. Loaded original-UV PBR, three complete mip chains, clips, bend/wall blocking,
closed gate, protected input, pause and unchanged campaign facts passed their
isolated checks. All three resulting frames were individually inspected; this
is fixture appearance, not installed-building or artistic acceptance. The batch
stopped before the world route and nook-parent compile. Original logs/receipt,
frames and **DIAGNOSTIC_REVIEW.json** remain under **intake_02/**.

The candidate fix follows witnessed floor-support points instead of transient
player step-lift height. Breadcrumb arrival uses planar progress with a bounded
one-step height allowance; capsule collision and the22cm step limit remain.
Unsupported player frames add no airborne samples, and stationary players need
no repeated floor probe. Arbitrary jumps, lifts and ledge recovery remain
unqualified. Fixture assertions remain unchanged; position,
remaining-target and floor-state observations were added for diagnosis.
This movement revision is uncompiled/unverified until retry.

**intake_03/batch.json**, broker**63084**/session**62087**, is queued for the same
compile/fixture/world/nook-parent sequence. Original32268/80997 is terminal1;
do not restart it. No renewed physical packet, candidate or merge acceptance.

## Step fix passes; installed-world start corrected

**intake_03** compiled5/0 and passed all15 rendered fixture assertions in14.23s,
with empty shutdown stderr. Step completion now records actorX6.852 on floor
beyond the5.15–5.85m obstacle. Its production input digest is
**6fcbb2cf101ccaf87babf0fff07e93cfba99b7be51077a39c99c17835645dafc**.
This is isolated interaction verification, not installed-world acceptance.

The following installed-world run executed all five player waypoints but failed
three follower assertions. Its schema2 contract correctly says **passed:false**.
The inherited driver had relocated the player after Adela spawned: her initial
street position stayed **(0,0,3.1)** while the player was moved inside. The source's
bounded no-teleport guard correctly refused that discontinuity. The captured
corridor view contains no visible Adela, so its frame arrays do not establish her
rendering cost. Keep the original failed contract, image and logs unchanged.

The driver now overrides that diagnostic placement with **pass**, preserves the
actual street arrival, opens the existing front door through grab/mouse/release,
and walks into the lobby before the original corridor/stair legs. It requires
ten played waypoints with zero diagnostic relocations, retains the original
movement/catch-up/support assertions, waits for actual composition completion
and records trail state and the head's physical line blocker for interpretation.

**intake_04/batch.json**, broker**17256**/session**67677**, is queued. Its fixture
reuse guard has already passed: prior receipt/stdout, exact fixture/scene/window
helper sources and complete production digest match. It will recheck at admission;
the unchanged fixture is not rerun. Then compile, real-arrival world route and
nook-parent compile. Original63084/62087 is terminal1. No new physical packet,
world pass or merge acceptance is claimed. The native source's skin-influence
audit also confirms all78,620 vertices have1–4 influences; none require truncation
beyond the exported four-weight layout (**SKIN_INFLUENCE_REVIEW.json**, external).
