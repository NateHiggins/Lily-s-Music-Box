# Engine knowledge ledger

Evidence class: **INERT**. Living observations, not acceptance.

## October 28 — cooperative budgets require atomic-step attribution (L1)

Problem: occupied passage reconstruction still stalls despite an8ms fitting
budget. Frame-linked monotonic caller intervals in PR80, candidate
**0b8ccff6**, measure a first advance up to36.819ms and a complete fitting call
up to37.446ms. Ready-result gets are at most0.010ms in the complete diagnostic;
that does not exclude worker or deferred-render costs. Evidence and original
buffer-truncation failure: **V2_COOPERATIVE_NATIVE_FITTING_2026-10-23.md**,
October28 section; actual fullscreen route and original residency regression.

Reusable lesson, not a general performance guarantee: measure first preparation,
later chunks and completion separately. A cooperative deadline cannot interrupt
an atomic engine call or an unyielding preparation step. Record frame ids and
monotonic intervals, bound storage and detect dropped records. Parent callback
and nested-call durations overlap and must not be summed. The first4,096-record
buffer was inadequate; an8,192 cap retained all7,046 records on this route.
The probes are off by default and add no save or scheduling authority.

Godot constraint: a threaded API's caller time is not its worker/GPU cost.
Orison-specific scope: private source/collision validation, traffic and calendar
settings, this machine and route. Extraction caution: preserve those validation
owners and qualify another consumer before claiming a reusable contract (L3)
or cross-project proof (L4). This is observation (L1); atomic fitting remains
unrepaired, and the measurements do not establish a speedup.

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

Systemic decisions use `design/ENGINE_DECISION_RECORD_TEMPLATE.md` when they
change fact ownership, a cross-subsystem contract, generated schema/pipeline,
save/migration behavior, release-proof protocol, or a claimed reusable seam.
The accepted record must link evidence and state its §G level and falsification
condition. Local content, tuning and contract-preserving bug fixes do not need
an EDR.

The production interaction seam is inventoried separately in
`design/INTERACTION_CONVENTION_RECORD_2026-08-27.md`. Its shared method names
are a documented convention, not a reusable contract: `has_method` proves
neither paired capabilities nor signatures, results, reachability or effects.

## Evidence-level audit — 2026-08-27

This ledger uses the five levels defined in
`design/ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md` §G: observation (L1), local
invariant (L2), reusable contract (L3), second-consumer proof (L4), and product
claim (L5). A candidate seam is not automatically a contract. **No entry is L4
or L5 because no second project consumes any of these systems.** “Future”,
“candidate” and “should” below describe requirements learned from Orison, not
shipped interfaces.

| Section | Strongest honest level | Qualification |
| --- | --- | --- |
| 1. Authority | **L2 — local invariant** | Repeated ownership split; no named external interface, input/output schema or failure contract. |
| 2. World compiler | **L2 — local invariant** | Deterministic production pipeline evidence; current compiler and data remain Orison-shaped. |
| 3. Simulation acceleration | **L2 — local invariant** | Repeated timing/collision result; proposed duration injection is not an API. |
| 4. Claim sharding | **L2 — local invariant** | Proven in Orison's runner; aggregate manifest and generic shard API do not exist. |
| 5. Benchmark cameras | **L2 — local invariant** | Camera classes are stated requirements, not a packaged consumer contract. |
| 6. Render-pass census | **L2 — local invariant** | Measurements support this production policy; no generic station-census interface exists. |
| 7. Visual proof | **L2 — local invariant** | The protocol operates here; the manifest remains a proposed generic boundary. |
| 8. Reconstructible presentation | **L2 — local invariant** | Several repeated rules and candidate utilities; no single reusable API or failure schema. |
| 9. Semantic audio | **L3 — reusable contract** | Named ownership boundary plus cue/source inputs, arbitration outcomes, diagnostics and `stop_source()` failure/lifecycle behavior. Still no L4 consumer. |
| 10. Process safety | **L3 — reusable contract** | `run_godot_serial.ps1` and the capture protocol expose named inputs, receipts, mutex/timeout failures and bounded outputs. Still no L4 consumer. |

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

### Candidate seam — L2, not yet a reusable contract

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

### Candidate seam — L2, not yet a reusable contract

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

### Candidate seam — L2, not yet a reusable contract

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

### Candidate seam — L2, not yet a reusable contract

A future generic test runner would need named claim shards, per-shard watchdogs,
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

### Candidate seam — L2, not yet a reusable contract

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

### Candidate seam — L2, not yet a reusable contract

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
with no inspected loss of architectural or light-pool legibility. That supports
an atrium candidate, not a building-wide default: a policy is only as broad as
the views its A/B evidence covers. Performance evidence supports a visual
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

### Candidate seam — L2, not yet a reusable contract

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
is a candidate requirement for a future world compiler—an `absence
assertion`—not an interface the current compiler exposes.

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

### Candidate seams — L2, not yet reusable contracts

A small `PoseCountdown` utility could standardize arm/advance/normalized-value
and remaining-time behavior. A stronger render harness should freeze one
instant, toggle exactly one fact, derive candidate crops from the measured
difference bounds, and reject suites whose interesting section was skipped.
A future frame-legibility probe should take a player pose, facing, FOV and a
target set and report distance, yaw, pitch, occlusion and in-frustum status;
K2-A through K2-C have each rebuilt this same diagnostic by hand.

### Visible state belongs in snapshots

The A11 fortune-head static audit caught a common split-brain bug before its
engine run: `coin_loaded` and sequence were snapshotted, but the last nod/shake
pose was not. A gameplay snapshot that restores variables while leaving a
different visible answer is not a restoration. Future snapshot tooling should
require each animated part to declare the state field or deterministic derive
function that owns its settled transform. Abort tests must compare both the
state dictionary and every declared visible pose; refusal poses need the same
coverage because “nothing happened” is not an acknowledged interaction.

### World-wayfinding contract

K2-D (`3b9fa4b`) found that a directional sign can be present, readable and
still lie. Its complete contract has four independently measured facts: where
the sign hangs, which way its readable face points, which way that makes the
reader face, and where traversable geometry actually opens. The local
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

## 9. Source-owned sound needs centralized attention policy

### Learned

Spatial emitters alone do not produce an intelligible sound world. Orison had
strong individual mechanisms but at least 142 statically visible construction
paths competing through mostly `Master`, with 29 literal `tick` and 17 `knock`
helper requests carrying unrelated meanings. The reusable boundary is:

- the world object owns the fact and requests a semantic cue;
- a catalog owns variants, purpose, bus, distance and limits;
- a bounded policy owner arbitrates priority, concurrency and mix state;
- the acoustic scene owns listener-relative transmission;
- diagnostics record what presented, refused, stole a voice or was stopped;
- accessibility exposes only information available in the audible event.

`AudioPolicy.stop_source()` is as important as playback: repair, abort and
despawn must silence the exact source without reaching into unrelated voices.
A source id plus cue id makes that boundary testable.

### Reusable contract — L3, no second-consumer proof

The reusable contract is the semantic cue schema, stable bus builder, fixed voice pools,
source-scoped lifecycle, composable mix-state requests and audit tooling. Keep
Orison's cue vocabulary, 550-node building graph and historical recordings as
content. Do not productize a singleton that owns game state; productize the
competition and evidence contracts downstream of state.

## 10. Process safety is part of the engine workflow

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

### Reusable contract — L3, no second-consumer proof

The current contract comprises serialized execution, structured result
extraction, stable temp-log locations, exact artifact manifests, dirty-tree
guards and ownership-aware worktree support. Packaging, versioning and external
support remain L5 questions; they are not present product features.

## 11. Extraction-census disposition — 2026-08-27

This closes the per-row ledger backfill requested by
`design/ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md` §I. The portability words in
that audit measure traced coupling; the evidence level here measures what has
actually been specified and proved. Consequently, a `reusable-now` row may
still be L2, while an L3 contract may sit in an implementation classified
`reusable-with-work`.

| Census capability | Ledger disposition | Level | Boundary and missing evidence |
| --- | --- | --- | --- |
| Serial test runner | Process safety (§10) | **L3** | PowerShell parameters in; serialized process, filtered verdict and bounded timeout/mutex failures out. Fixed Orison mutex/default vocabulary requires extraction work; no second consumer, packaging or support. |
| Capture evidence harness | Process safety (§10) and visual proof (§7) | **L3** | `setup`, `capture` and `finish` plus frame receipts/no-overwrite failures form a held contract. Only Orison suites have consumed it. |
| Shot measurement | Process safety (§10) and visual proof (§7) | **L3** | CLI/manifest inputs and metrics/contact-sheet outputs are explicit. Python dependency packaging and a second consumer are absent. |
| Celestial ephemeris | Pure calculation candidate | **L2** | Tests repeatedly hold explicit UTC/coordinate calculations, but the ledger has not recorded a complete named output/error/precision contract. Attribution is unresolved. |
| Maintenance activity framework | Authority (§1) and reconstructible presentation (§8) | **L2** | Data-driven local boundary with `submit(verb, value, held)`; extraction audit records its focused/live evidence as UNRUN/UNKNOWN at the checkpoint. |
| Activity panel UI | Reconstructible presentation (§8) | **L2** | Input/presenter behavior is locally tested. Hardcoded hints, player-private input-family discovery and Orison styling prevent a reusable contract claim. |
| Semantic audio policy | Source-owned sound (§9) | **L3** | The semantic source/cue/arbitration/diagnostic/lifecycle contract is explicit. `AudioPolicy` itself remains an Orison-coupled autoload and is not the reusable claim. |
| Acoustic graph | Source-owned sound (§9) | **L2** | Production graph and suites prove local behavior. `GameBoot`, autoload lifetime and Orison's 550-node content remain coupled; no independent graph contract is recorded. |
| Conductor clock | Source-owned sound (§9) | **L1** | A tick-source candidate was observed. The census records no dedicated evidence, and its autoload/data coupling is unqualified by a test here. |
| Interaction verbs | Interaction convention record | **L2** | A 65-prompt/71-action census and production dispatch trace establish a local convention. There is deliberately no interface, signature contract or registry. |
| WorkOrders | Authority (§1) | **L2** | Issue/close and job-stage behavior are repeatedly tested in Orison. `RealityState`, system-clock stamps and product job schemas remain part of the boundary. |
| Cases / rules | Authority (§1) | **L2** | Case suites hold local ownership invariants. Autoloads, case ids, residents and data schema are the design, not adapter inputs. |
| RealityState persistence | Authority (§1) and visible snapshots (§8) | **L2** | Save compatibility is locally tested. Version 4, fixed user path and Orison-shaped payload have no generic migration/error contract. |
| Procedural building / detail passes | Data builds the world (§2) | **L2** | Generator/live invariants are strong local evidence. Floors, room taxonomy, coordinates, autoloads and the Orison plan are total coupling. |
| Day/night + weather | Data/runtime split (§2) | **L2** | Local weather service behavior and opt-in policy are tested. Queens defaults, `GameBoot`, provider/privacy terms and offline consumer behavior prevent L3. |
| Input abstraction | Reconstructible presentation (§8) | **L2** | Controller mappings are tested here. The whole InputMap and Orison verbs live in `GameBoot`; no registration, conflict or migration contract exists. |
| Performance station harness | Benchmark cameras (§5) and render-pass census (§6) | **L2** | Production stations and measurements hold local invariants. The 985-line probe names Orison scenes/stations and exposes no generic station schema. |
| Localization / House English | Data/runtime split (§2) | **L2 prototype** | `term`/`render_line` have focused evidence, but there are zero production callers and one fixed data path. This is not production proof or a localization API. |
| Dream / living architecture | Data builds the world (§2) | **L2 game-only** | Extensive suites establish many local invariants. Profiles, cases, residents, generated media and Orison topology are inseparable product content. |

This table creates no new L4 or L5 entry. It also does not lower strong local
game evidence merely because the code should never be extracted: evidence
level and portability answer different questions.

## 12. Weather and celestial services: facts flow inward, authority does not

**Evidence level: L2 — local invariant.** `LiveWeatherServiceTest`,
`CelestialEphemerisTest`, `WeatherSkyTest`, `LIVE_WEATHER_CONTRACT.md` and
`CELESTIAL_SKY_CONTRACT.md` prove these boundaries inside Orison. Neither
service has a second consumer; the live service is coupled to `GameBoot`, and
the pure ephemeris lacks a complete error/precision compatibility contract.

### Ownership chain

```text
GameBoot settings (network off by default; optional authored place text)
  └─ LiveWeatherService
       ├─ Open-Meteo geocode/forecast, or deterministic QA simulation
       └─ normalized data-only snapshot
            └─ BuildingRoot adapter
                 ├─ DayNightDirector: sole Environment/sky/key writer
                 ├─ WeatherFX: precipitation, mist, wind and flash scheduler
                 └─ PeriodRealityLayer: bounded ambience consumer

UTC + snapshot latitude/longitude (Queens defaults when absent)
  └─ CelestialEphemeris pure static calculations
       └─ DayNightDirector applies Sun, Moon, phase, stars and sky basis
```

Network weather and astronomical geometry are deliberately different seams.
`CelestialEphemeris` performs no I/O and discovers no location: its public
functions take UTC and coordinates explicitly and return numbers/vectors. The
live service owns location policy but no renderer. `BuildingRoot` translates a
normalized snapshot into presentation facts; existing visual owners remain
the only writers of nodes and shader state.

### Privacy, opt-out and fallback

- `weather_network_enabled` defaults to `false`; in that state `refresh()`
  issues no request and the authored Queens storm remains untouched.
- When network weather is enabled without local matching, the service sends the
  fixed Queens coordinates `40.75, -73.92` to Open-Meteo.
- Local matching is a second opt-in. Only player-authored city/postal text is
  sent to the geocoder; blank text falls back to the fixed Queens request. The
  code performs no IP, locale or device-location discovery.
- Request start, HTTP, geocode and incomplete-weather failures emit
  `weather_failed` without publishing a replacement snapshot. Existing
  presentation therefore remains authored, or retains the most recent
  successful in-memory snapshot if one was already applied.
- `_awaiting` is cleared before failure is emitted, so the next scheduled
  refresh can retry rather than deadlocking the service.

### Refresh and cache truth

The service attempts one refresh on `_ready()` and then at most once every 900
seconds while no request is in flight. Each HTTP request has an eight-second
timeout. A local-location refresh performs one geocode request followed by one
forecast request; the handler returns between them so geocoder JSON is never
parsed as weather.

There is **no disk cache, TTL record, ETag handling, replay file or persisted
last-known observation**. `_snapshot` and `_location` are memory only. “Cache”
must not be claimed for this subsystem. On a new offline process the game uses
authored weather; after a successful observation, a later failure leaves that
already-applied presentation in place for the life of the scene.

### Reusable candidate and extraction caution

The reusable pattern is the authority split: optional I/O publishes bounded
facts; failure publishes no false replacement; established production owners
apply those facts; pure astronomy accepts explicit observer inputs. The current
implementation is not an extractable service contract. It imports `GameBoot`
settings, hardcodes Queens and Open-Meteo endpoints, emits unversioned
dictionaries, and has no injected transport, clock, cache policy, provider
terms adapter or structured failure type.

`CelestialEphemeris` is the cleaner candidate, but its documented lunar model
is visual rather than navigational and explicitly omits refraction, libration,
topography and eclipses. Any future API must state those accuracy/failure bounds
rather than treating deterministic vectors as a general astronomy promise.

## 13. Productization questions to answer before extraction

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

## 14. Proof tooling boundary: mechanism, adapter and evidence content

**Evidence level:** the runner/harness/measurement contracts are L3 inside this
repository; portability remains separately qualified. No item has L4
second-consumer proof.

| Layer | Current owner | Classification | Coupling / extraction boundary |
| --- | --- | --- | --- |
| Serialized process core | `tools/run_godot_serial.ps1` | **L3 contract; reusable-with-work** | Parameters cover scene/project/output/window/timeout/args, and failures are bounded. `Global\OrisonGodotSingleInstance`, default `<repo>/game` and Orison diagnostics remain fixed; namespace/default must become inputs before an uncoupled claim. |
| Scene capture core | `game/tests/shot_harness.gd` | **L3 contract; reusable-now by traced coupling** | Owns no scene state or camera; takes owner/tag/frame count/budget and absolute `SHOT_DIR`; emits PNGs plus receipt or explicit budget/path/frame failure. Location under `game/tests` is packaging debt, not state coupling. |
| Image measurement core | `tools/measure_shot_sheet.py` | **L3 contract; reusable-now by traced coupling** | Directory + optional manifest in; hashes/luma/linear-RGB RMSE/threshold verdict/contact sheet out. “Orison” appears only in prose. Requires Python, NumPy and Pillow. |
| Capture orchestration adapter | `tools/run_godot_capture.ps1` | **Orison adapter; reusable-with-work** | General parameters wrap the runner, but default game path, `orison_capture_*` log name and fixed Orison render-gate census are product conventions. Receipt schema is useful; gate discovery must be injected. |
| Screenshot migration inventory | `tools/audit_shot_suites.py` | **Repository-specific audit; reusable-with-work** | Hardcodes `game/tests`, `*_shot.gd`, Orison production-root spelling and source heuristics. It reports migration risk, not runtime truth. |
| Capture evidence protocol | `game/docs/CAPTURE_EVIDENCE_PROTOCOL.md` | **Reusable practice; local evidence** | Receipts, no-overwrite, control floors and serialized execution generalize. Current 54/60-second budgets and suite examples are Orison measurements, not universal defaults. |
| Performance probe | `game/tests/perf_probe.gd` | **Game-only evidence content** | Loads Orison waking/dream scenes, stations, light policy and environment gates. `PERF_STATION` is a useful adapter idea, not a generic harness hidden inside 985 product-shaped lines. |
| Individual `*_test.gd` / `*_shot.gd` scenes | `game/tests` | **Game-only evidence content** | State fixtures, cameras, crops, thresholds and acceptance claims encode Orison. They consume proof tools; they are not part of the tools' portability claim. |
| Render sheets and receipts | `art/renders/**` | **Historical evidence artifacts** | Immutable evidence for the commit/build/camera that produced them. Never package as a toolkit runtime dependency or rewrite old protocol facts to match a new harness. |

The extraction unit is therefore not “the tests folder.” It is the smallest
mechanism whose inputs, outputs and failures do not name Orison state, plus a
new consumer's own adapters and evidence scenes. A reference project must use
the harness and measurement contract without importing Orison scenes, gates,
autoloads or thresholds before L4 can be claimed.

## 15. Save/reload is fact reconstruction, not scene restoration

**Evidence level: L2 — local pattern with focused repository evidence.** The
full transaction trace is in
`design/SAVE_RELOAD_TRANSACTION_MODEL_2026-08-27.md`.

`RealityState` owns one versioned JSON fact store. Domain owners commit job,
item, case, coordinator, dream, onset and residue facts; presentation owners
rebuild text, settled mechanisms, route cues and generated world state after
load. Future-version saves are neither merged nor overwritten. A write failure
leaves the in-memory mutation intact and reports that progress may be lost, so
this is not an atomic database transaction.

The focused core-loop proof round-trips eight semantic campaign states. K3 is a
different claim: eleven player-route checkpoints, each requiring a correct
resume location, immediate practical intention, durable job/case owner and
physical world answer. Automated coverage cannot close that human matrix, and
K3 remains open until the route is walked against a named build and save
version.

Extraction caution: the reusable idea is a single fact authority plus
idempotent reconstruction. The current untyped dictionary, fixed Orison path,
direct file replacement and local migration policy remain L2 product code, not
a packaged persistence layer.

## 16. Lexical autoload references are not dependency counts

**Evidence level: L2 — measured local coupling census.**
`design/GAME_BOOT_COUPLING_CENSUS_2026-08-27.md` resolves the extraction
boundary's likeliest falsifier. Fifty-four scripts contain `GameBoot`, but 35
use only the pure static `b2g()` helper, four use only the static developer
overlay query, one is the owner and one is a comment. **Thirteen scripts consume
actual singleton state or behavior.**

The correction matters to estimates: coordinate conversion living on an
autoload is an ownership smell, not runtime singleton coupling. The remaining
13 consumers still span settings, launch mode, scene transition, audio policy
and settings persistence, so the correct extraction lesson is to name those
inputs separately—not package `GameBoot` as a service.

## 17. Next ledger work

- Add the eleven-boundary K3 observations after the unaided route is actually
  run; do not translate the eight automated semantic boundaries into human
  results.
- Generator/runtime interfaces and their current dependency graph are mapped in
  `design/GENERATOR_RUNTIME_INTERFACE_MAP_2026-08-27.md`; the main five-file
  mirror, Blender geometry branch, runtime consumers, satellite pipelines and
  missing revision/schema enforcement are explicitly separated.
- Extend the bounded notice-generator census in
  `design/ENGINE_NOTICE_GENERATOR_SCOPE_2026-08-27.md` only when an actual
  toolkit payload exists; current external dependencies are recorded, but no
  toolkit bill of materials exists.
- Weather/celestial ownership, opt-out/default-location policy, refresh and
  offline/no-disk-cache behavior are recorded in §12.
- Proof tooling, Orison orchestration adapters, performance/test scenes and
  historical evidence artifacts are separated in §14; the reference project
  still gates any L4 claim.
- `design/ENGINE_DECISION_RECORD_TEMPLATE.md` now governs new systemic
  authority/contract/schema/save/proof decisions and requires an evidence-level
  ceiling, falsification condition and explicit ledger update on acceptance.

## Diagnostic capture work in played profiles — 2026-10-21 (L1)

A played route's synchronous GPU image readback and PNG encoding can dominate
its apparent interaction spike. Measure those calls separately and disable
photographs in the default timing run, retaining an explicit capture control.
The counter control measured 18–24 ms readback and 252–259 ms PNG encoding;
capture-free counter frame windows peaked at 68–81 ms. This corrects attribution,
not production performance. Keep original samples and settings/cache limitations.
Evidence: **design/V2_COUNTER_CAPTURE_DIAGNOSIS_2026-10-21.md** and
**art/reviews/v2_counter_hitch_20261021/comparison.json**. This is an Orison-local
Godot observation, not a reusable profiler or input-to-photon measurement.

## Small physical return datums — 2026-10-21 (L1)

A four-millimetre momentary control could remain unarmed after release because
general approximate equality skipped a residual of a few micrometres. Clamp
and reach the actual rest datum, guard the spring tick against held/inactive
state, and test re-acquisition after partial strokes near tick boundaries.
The original controller fails the first regression; the corrected version
passes the same actual-input sequence and repeated runs. This is a local
Godot-coordinate observation, not a global epsilon change or a new save owner.
Evidence: **design/V2_CASE_CALIBRATOR_2026-10-21.md** and original/fixed runs in
**art/reviews/v2_case_calibrator_20261021/**. Case outcomes remain game-specific.


## Cooperative scene publication — 2026-10-28 (L1)

**Problem:** a fully fitted off-tree passage entered the scene tree in one burst
of 5,083 nodes. Four repeatable native-resolution route frames took 102–105 ms,
although the measured attachment plus resource cleanup was only about 27 ms.
Prefetch resource destruction was measured at roughly 10–11 ms; it was not the
main source of the complete frame stall. Do not equate one synchronous timer
with all work a scene-tree mutation schedules.

**Local rule:** after off-tree validation finishes, register complete cells in a
hidden pending root across frames. Keep access guarded, actor/counter ownership
suspended and the public cell map unpublished until the complete presentation
is ready. Cancellation and shutdown own both the still-private root and the
already-attached pending root. A per-cell allowance is cooperative: one large
cell can still exceed a frame's budget.

**Evidence:** merged PR **#73**, candidate **1b7d7013**, merge **23f65382**;
**design/V2_COOPERATIVE_NATIVE_FITTING_2026-10-23.md**, October 28 section.
Actual 124-waypoint route completion frames fell to 63–65 ms. The 57-waypoint
residency regression passed 1,935 checks, including 24 guarded publication
observations, both cleanup exits, source resource release and retained
actor/material/inventory identities. GPU percentiles were essentially unchanged;
ordinary p95 stayed near 65 ms and a 101 ms cold/other spike remained. This is
local improvement, not a general FPS or stutter-elimination claim.

**Godot constraint:** scene attachment can schedule deferred rendering/physics
work. CollisionObject3D defaults to DISABLE_MODE_REMOVE, so disabling a pending
parent's processing removes its static bodies and can bunch re-registration at
activation. Keeping per-cell collision registration enabled did not demonstrate
an additional frame-tail gain in the control. Hidden ReflectionProbes must also
remain hidden until full geometry exists; preserve one-time capture ownership.

**Extraction caution:** this is L1 production evidence, not a reusable loading
API. The barrier, public cell map, retained shop actors, prefetch dependencies
and cleanup are Orison-specific. Another consumer must define its own atomic
visibility/access boundary and cancellation ownership before reusing the method.
Current source-bound receipts and exact failed controls matter more than a
nominal scheduling budget. Do not relax a deadline merely to make a diagnostic
pass; distinguish the older stationary deadline from the actual played approach.


## Local frames and calendar-driven architecture — 2026-10-28 (L1)

**Problem / local rule:** facade and dial frames can have opposite handedness.
Normalize polygon winding against the actual tangent/up/outward basis, then
verify named front normals. Mechanical plates need meaningful origins and
separate layers. Float32 transformed export measurements matter as well as the
editable mesh. New direct helper dependencies belong in the producer's source
bindings before qualification; preserve dependency-only finalization separately.

**Evidence:** the Sohmer study in **design/V2_CITY_CONTEXT_REPORT_2026-10-19.md**;
5,392 loaded checks, actual clock poses and roughly 8 mm exported hand clearance.
The direct Windows overwrite failed with OSError 22; the existing validated
staged-export path succeeded. The new reader sampled 410 calls at at most
68 microseconds, while route maxima still exceeded 100 ms. A small synchronous
scope does not explain deferred engine work or clear the entire frame.

**Godot boundary:** architecture reads the existing CampaignClock. No new writer,
calendar seed or save fields. Test actual automatic updates, pause/resume and
rewind as well as manual refresh and rendered directions. In this project,
Godot-space pivots/normals are exported once from Blender coordinates; rotating
the display must keep its physical stock aligned.

**Reuse caution:** these are L1 Orison observations, not a reusable city/clock
engine contract. The facade reservation, local material catalogue, metadata,
loading owner and campaign service remain game-specific. Profile the real owner
and define lifecycle/coordinate boundaries before extracting an API. Small
lesson updates were added to the existing Blender/Godot skills; their structure
validators pass, with no invocation-policy change or new helper files.


### October 28 — actual frontage and detached observation

An isolated camera heading is not evidence of street frontage. Read registered
neighbors and inspect the real composed street before authoring the facade.
The rejected three-house experiment and final single-house correction remain
documented in **design/V2_CITY_CONTEXT_REPORT_2026-10-19.md**.

Detached inspection must retain residency under the parked body while adding
observer visibility. Reuse the existing input lease; restore only the camera's
own ownership and let protected interruptions keep theirs. Engine-dispatched
mouse tests must flush buffered synthetic events and sample after rendering;
do not weaken a real assertion or change production input settings to satisfy
test timing. Inactive debug tools should avoid ongoing frame work. These are
project observations, not a new movement or persistence authority.
