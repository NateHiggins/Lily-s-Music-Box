# Engine knowledge ledger

Status: living evidence record. This is not a claim that Orison is already a
general-purpose engine. It records what this production has taught us, which
parts appear reusable, and what must be separated or stabilized before reuse,
licensing or support.

Every durable entry should name:

- the production problem;
- the reusable rule or contract;
- evidence (commit, test, render sheet or measurement);
- Godot-specific constraints;
- what remains game-specific;
- extraction and migration cautions;
- failed approaches worth not repeating.

## 1. Authority before machinery

### Learned

Systems stay composable when one owner mutates each durable fact and physical
objects publish or present neutral observations. WorkOrders owns work stages;
RealityCases owns case stages; FirstShiftDirector owns the opening ritual;
props present those facts and emit bounded signals. A register, key hook,
watch station or clock must not quietly become a second ledger.

### Evidence

- SR7-F through SR7-L production/live suites prove apparatus state without
  duplicating work, case, access or persistence owners.
- K2-A (`f7db405`) adds an audible clock and wayfinding plate without teaching
  either presentation object about ritual, work-order or case mutation.
- `game/docs/core_loop.md` documents the current product spine.

### Reusable engine seam

A future tool should expose explicit fact-owner interfaces and neutral event
contracts. Presentation modules should be able to subscribe, render and refuse
without importing the durable owner. Static source scans and runtime mutation
censuses are valuable enforcement, not merely style checks.

### Extraction caution

Do not generalize Orison’s named job/case schemas into an engine API. Extract
the ownership pattern, transaction boundary and validation hooks; keep game
vocabulary in adapters.

### Derived presentation contract

K2-C (`6bed0c0`) demonstrates a useful ownership split for objective text: the
lifecycle owner supplies its factual sentence, while the phase owner composes
immediate context from public facts without storing a second objective state.
Clearing the presenter and rebuilding it from owners produced a byte-identical
frame. Tests should assert the semantic property—such as “station named but not
ordered”—rather than brittle literal copy or capitalization.

## 2. Data builds the world; runtime objects explain it

### Learned

The building is most reliable when layout data owns geometry and placement,
while runtime props own behavior. Generator invariants catch spatial mistakes
before Godot; live tests catch imported geometry, ownership and interaction
seams afterward. Editing generated copies without editing their source is not a
fix.

### Evidence

- Roof egress correction `c78a280` was made in `art/data/gen_layout.py` and
  regenerated into both layout copies; the live body then reached z=4.5.
- SR7 apparatus placement consistently uses `orison_detail_pass.gd` rather
  than teaching `building_root.gd` every prop family.
- WalkTest and presentation audits distinguish authored-layout truth from
  runtime collision/render truth.

### Reusable engine seam

Package a compiler pipeline with: canonical source data, deterministic
generation, mirrored-output verification, spatial invariants, and a runtime
binding layer. Generated artifacts should carry provenance and be reproducible
without Blender/Godot editor state.

### Extraction caution

Orison’s coordinate conversion, storey ids and room taxonomy are product data.
The reusable part is the compiler contract and validation protocol.

## 3. Simulation acceleration must preserve the thing being proved

### Learned

Increasing time scale alone changes collision displacement per physics step
and can make a route test pass through walls. Raising physics ticks in the same
ratio preserves displacement, but high global rates can overload a production
scene and run slower. Accelerate the smallest owner that contains the wait.

### Evidence

- GoldenLoop `cf310da` completes at x4/240 with permanent block timings.
- WalkTest experiments at x5/300 and x8/480 became slower or starved call
  coroutines; those candidates were withdrawn.
- `b328c1c` makes CallInterface’s existing test-only wait factor explicit and
  uses a test-only elevator travel multiplier while preserving physical door,
  interlock and rider assertions.

### Reusable engine seam

Provide scoped simulation clocks or injectable duration policies per subsystem
instead of one global overclock. A physics test must record time scale, tick
rate and displacement-per-step. Test hooks must default to shipping behavior
and be visibly named as non-production controls.

### Failed approach

“Turn the whole world up until the test fits” is not a performance solution.
It increases engine work, creates timing races and can invalidate collisions.

## 4. Honest shards are better than a monolithic timeout

### Learned

A release gate that times out after printing many successes has no final
verdict. If two independently meaningful performances cannot share a mandatory
process ceiling, split them by claim—not arbitrarily—and boot production for
each. Coverage ownership must be explicit so nothing silently disappears.

### Evidence

- `b328c1c` replaces monolithic WalkTest FULL with FULL-PHYSICAL and
  FULL-CASES. PHYSICAL owns traversal, the rider-carrying lift, Case 01, street,
  roof and Room 0. CASES owns all eight calls, convergence, broadcast, Evelyn
  and sanity. Both print final verdicts below 60 seconds and reproduce only the
  same two established failures.
- Permanent phase markers show where wall time is actually spent.

### Reusable engine seam

An engine test runner should support named claim shards, per-shard watchdogs,
machine-readable phase timings and an aggregate manifest proving complete
coverage.

### Extraction caution

Sharding cannot become a way to avoid integration. Each shard must instantiate
the production root and the manifest must identify cross-shard seams.

## 5. A benchmark camera must carry the player’s world with it

### Learned

Moving a detached camera while leaving the player, carried lamp and streaming
origin elsewhere measures a world no player can produce. A composition camera
over an open void is also not a gameplay station and must be labeled as such.

### Evidence

- K1’s submission census found the detached atrium camera while the player lamp
  remained in the lobby; the lamp alone overlapped roughly 1,250 caster
  surfaces.
- Moving the body to the original atrium-eye lens made it fall to B1, proving
  that lens is not occupiable.
- Current instrument work adds a real F03 landing station (23.70 ms) and a
  player-height north-pavement station (16.67 ms), while retaining aerial
  atrium/street cameras as explicitly playerless composition views.

### Reusable engine seam

Performance stations need a declared camera class:

1. `playable`: body, eye, carried lights, audio listener and streaming origin
   move together;
2. `composition`: no player-owned light or gameplay claim;
3. `isolated`: a deliberately synthetic diagnostic with its exclusions named.

The harness should fail if a playable lens has no supporting floor or if the
player/light diverges beyond tolerance.

### Failed approach

Treating a free camera as “just the player’s eyes” produced confident but
misattributed shadow costs.

## 6. Count render passes, not scene nodes

### Learned

This build is submission-bound. One visible surface can be resubmitted into
many shadow views, so scene-tree mesh counts and visible draw calls alone do
not explain frame time.

### Evidence

- The corrected F03 landing census reports about 1,314 visible calls and
  19,299 shadow calls at 24.33 ms.
- The composition atrium census reports about 3,072 visible and 21,957 shadow
  calls.
- Current decomposition rejects blind merging and a 12 m prop cull; hiding
  props or reducing shadow work moves the frame, stopping prop scripts barely
  does.

### Reusable engine seam

Ship a station census that reconciles renderer counters with frustum surfaces,
attributes owners/zones/materials, and reports caster overlap per light. A
performance decision should name the resource it spends: CPU submission, GPU
fill, VRAM, physics, audio or persistence.

### Failed approaches

- Blind static merging can worsen the frame and destroy moving/material seams.
- Distant prop culling did not move the current atrium frame.
- Disabling all shadows is an upper-bound control, not a visual policy.

### Current decision example

At the playable F03 landing, retaining 64 lit fixtures while reducing ranked
shadow casters measures 23.70 ms at 16 shadows, 18.02 at 8, 16.67 at 6 and
15.28 at 5, repeated at the same 15.28 ms. The same-camera architecture crop
prices the five-shadow image at 0.01761 RMSE against a 0.01098 temporal floor,
with no inspected loss of architectural or light-pool legibility. That licenses
an atrium candidate, not a building-wide default: a policy is only as broad as
the views its A/B evidence covers. Performance evidence licenses a visual
decision; it does not make the decision by itself.

## 7. Visual proof requires its own control floor

### Learned

Renderer motion, weather clocks and temporal accumulation mean one global A/A
number is dishonest. Every claimed camera and crop needs its own frozen floor.
State identity and photograph identity are different claims.

### Evidence

- SR7 render sheets declare per-camera crops, A/A controls, abort frames and
  quantitative differences.
- K2-A records nonzero rain-camera floors while the desk control is exactly
  byte-identical.
- Several SR7 sheets discarded visually identical refusal poses before tests
  made the intended mechanical distinction observable.

### Reusable engine seam

Provide a render-proof manifest containing camera, crop, state fixture, random
seed, temporal controls, hashes and difference metric. The tool should flag
claims priced against a different camera’s floor.

`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md` and the paired capture/measurement
tools now make this operational: one non-retrying serialized windowed wrapper,
a 54-second scene budget with timing checkpoints, exact frame receipts,
no-overwrite output, linear-RGB pair metrics and an automatically labelled
contact sheet. After five migrated suites, replace the provisional phase
targets with measured p50/p90 timing rather than folklore.

K2-F's first migrated run is the initial datum: full production ready at
32.519 s, first capture at 37.4, eleven frames finished at 42.692, process exit
at 47.537. Explicit HUD hiding reduced literal waits from 14.7 to 3.4 s and the
corridor A/A floor from 0.136 to 0.0007028. A rejected run also proved that a
generic CanvasLayer sweep can remove carried equipment; capture masks are part
of playable-camera state and must preserve the player subtree deliberately.

## 8. Transient presentation should be reconstructible

### Subtraction is a first-class world change

Removing an object is not proved by deleting one spawn call. A baked carcass,
generated layout record, late runtime builder, interaction expectation or old
camera composition can preserve different versions of the same retired thing.
The PHONE-C arrival-wall audit therefore treats absence as a compiled
invariant: remove the canonical generator record, regenerate mirrored data and
baked geometry, forbid both authored id and runtime node, narrow dependent
tests deliberately, and retain a same-camera empty-wall control. This pattern
belongs in a reusable world compiler as an `absence assertion`, not as an
informal cleanup note.

The failed alternative is asset substitution: replacing obsolete wall art
with a newer bitmap preserves the unearned footprint and often hides why the
object failed. Archive provenance separately; make the empty composition earn
or reject any successor.

### Learned

A satisfying physical answer does not require a new durable fact. K2-B derives
the watch-clock punch from the first-shift phase and the report landing from
the register's existing availability. Each effect is a float countdown decayed
in `_process`, while one `_refresh_*` function is the sole writer of every
moving part's pose. Save/load reconstructs the settled presentation from its
real owner, and a frozen test can drive and hold the transient pose directly.

### Godot-specific constraints

- `Engine.time_scale = 0` stops tweens and `_process`; a pose that must survive
  a frozen evidence frame should be computed from explicit state, not entrusted
  to an active Tween.
- Shader time may continue independently, so weather in frame needs its own
  A/A floor even when gameplay time is frozen.
- A statically typed seam can reject a duck-typed test double before the
  intended call; test stubs must extend the real class or the suite must prove
  the bind succeeded before counting downstream assertions.
- `AudioStreamPlayer3D.max_distance` is a hard cutoff, while default 3D audio
  supplies no architectural occlusion. A source may therefore vanish just
  outside its radius yet remain audible through a slab just inside it. Route
  guidance must be priced from distance, interval, competing emitters and the
  actual propagation model rather than from “it is spatial audio.” K2-C counted
  141 playing emitters at the report desk and rejected making one intermittent
  upstairs chirp louder as a navigation fix.

### Reusable engine seam

A small `PoseCountdown` utility could standardize arm/advance/normalized-value
and remaining-time behavior. A stronger render harness should freeze one
instant, toggle exactly one fact, derive candidate crops from the measured
difference bounds, and reject suites whose interesting section was skipped.
A reusable frame-legibility probe should take a player pose, facing, FOV and a
target set and report distance, yaw, pitch, occlusion and in-frustum status;
K2-A through K2-C have each rebuilt this same diagnostic by hand.

### Visible state belongs in snapshots

The A11 fortune-head static audit caught a common split-brain bug before its
engine run: `coin_loaded` and sequence were snapshotted, but the last nod/shake
pose was not. A gameplay snapshot that restores variables while leaving a
different visible answer is not a restoration. Reusable snapshot tooling should
require each animated part to declare the state field or deterministic derive
function that owns its settled transform. Abort tests must compare both the
state dictionary and every declared visible pose; refusal poses need the same
coverage because “nothing happened” is not an acknowledged interaction.

### World-wayfinding contract

K2-D (`3b9fa4b`) found that a directional sign can be present, readable and
still lie. Its complete contract has four independently measured facts: where
the sign hangs, which way its readable face points, which way that makes the
reader face, and where traversable geometry actually opens. The reusable
invariant is `glyph_direction == traversable_opening_direction`, proved by
collision queries rather than by authored coordinates alone.

Godot makes this unusually easy to invert: a `Label3D` reads toward local
`+basis.z`, while a camera looks along `-basis.z`. Any bearing implementation
must be checked against one rendered frame before it is trusted across a sign
family. A single body-height ray also cannot distinguish a solid wall from a
borrowed-light window; a vertical wall-profile sweep separates solid wall,
floor-up doorway and high-only opening. Add both sign-facing and wall-profile
queries to the planned frame-legibility tool.

### Failed approaches and extraction caution

Two writers setting the same transform can leave correct state with a
byte-identical image; one place must decide one part's pose. Source-scan tests
bounded by two unrelated function names are also placement-fragile—scan the
specific function contract instead. Package the countdown and proof protocol,
not Orison's named ritual phases or apparatus geometry.

## 9. Process safety is part of the engine workflow

### Learned

Tooling that permits two renderer instances, streams enormous teardown noise,
or stages generated debris makes evidence unreliable and collaboration unsafe.

### Evidence

- `tools/run_godot_serial.ps1` enforces one Godot instance and a 60-second
  ceiling.
- The working protocol redirects full logs and reports only verdict, capture,
  parse, timeout, mutex and process lines.
- Exact-name staging has preserved large dirty/untracked art and import trees
  across parallel workstreams.

### Reusable engine seam

Bundle serialized execution, structured result extraction, stable temp-log
locations, exact artifact manifests, dirty-tree guards and ownership-aware
worktree support. These are product features if the tool will be leased.

## 10. Productization questions to answer before extraction

1. Which modules can run without Orison’s autoloads and data schemas?
2. What are the stable extension points for compilers, props, cases, saves,
   rendering stations and evidence sheets?
3. Can every module declare mutations, signals, persistence and resource cost?
4. What deterministic replay guarantees are possible across Godot versions and
   rendering backends?
5. Which tools require Blender, ImageMagick, Python or platform-specific shell
   support, and how are those dependencies licensed and updated?
6. What is the supported user workflow: editor plugin, command-line compiler,
   runtime framework, hosted build service, or a combination?
7. How will templates remain generic without erasing the authored specificity
   that makes this game convincing?
8. What automated compatibility, migration, security and support commitments
   would leasing require?

## 11. Next ledger work

- Backfill the save/reload transaction model and eleven-boundary K3 findings.
- Map the generator/runtime interfaces and their current dependency graph.
- Inventory external tools, formats, licenses and reproducibility risks.
- Record the weather/celestial service architecture, opt-out/default-location
  policy and offline behavior.
- Separate reusable proof tooling from test scenes that encode Orison content.
- Add a decision record template and require new systemic tasks to append one
  evidence-linked ledger entry when they close.
