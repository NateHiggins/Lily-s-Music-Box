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

## 8. Process safety is part of the engine workflow

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

## 9. Productization questions to answer before extraction

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

## 10. Next ledger work

- Backfill the save/reload transaction model and eleven-boundary K3 findings.
- Map the generator/runtime interfaces and their current dependency graph.
- Inventory external tools, formats, licenses and reproducibility risks.
- Record the weather/celestial service architecture, opt-out/default-location
  policy and offline behavior.
- Separate reusable proof tooling from test scenes that encode Orison content.
- Add a decision record template and require new systemic tasks to append one
  evidence-linked ledger entry when they close.
