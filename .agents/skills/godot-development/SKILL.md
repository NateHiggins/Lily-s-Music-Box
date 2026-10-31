---
name: godot-development
description: Implement, debug, integrate, and optimize Godot gameplay, scenes, UI, shaders, and persistence using project evidence and proportionate behavioral verification. Use a lightweight pass for small Godot edits; do not apply to unrelated documentation or tooling tasks.
---

# Deeper, not bigger

Improve execution of the user's request without enlarging it. Deliver the
requested behavior; preserve creative intent, working material, and existing
gameplay authorities. Use the full workflow for substantial features, difficult
bugs, integration, and performance work. For a small edit, inspect the affected
owner, make the change, and run the smallest meaningful check.

The workflow applies to general Godot development. The Orison paths, lane,
engine patch and acceptance rules below are this repository's constraints;
derive equivalents from evidence when working in another project rather than
copying its engine assumptions or fictional authorities.

## Inspect before deciding

Read the applicable repository instructions and design documents. In this
repository, start with [DOCS.md](../../../DOCS.md), follow its Bible precedence,
and obey [AGENTS.md](../../../AGENTS.md). Verify the checkout, outstanding changes,
and shared Godot lane before editing or running anything.

Determine the engine version, renderer, implementation language, target platforms,
and relevant architecture from project settings, export presets, runner evidence,
scenes, scripts, and resources. A declared project feature version is not proof
of the executable's exact build; an export preset is not device qualification.
Trace the affected input, signals, node lifecycle, resource ownership, and state
owners as relevant. Distinguish documented intent from implemented behavior.
When API behavior is uncertain, consult official Godot documentation matching
the verified engine version; state any documentation/version gap.

## Choose the missing engineering step

Before substantial edits, briefly identify the step most likely to expose a
real failure: reproduce the bug, trace a signal, inspect lifecycle or shared
resources, profile the affected route, or find the authoritative gameplay state.
Do only what the request needs. This is a working decision, not a prompt rewrite,
approval ceremony, or mandatory elaborate plan.

Keep inventory, quests, resident relationships, time, weather, dialogue, and
persistence with their established owners. Preserve the author's voice,
aesthetic, atmosphere, and game feel. Avoid unrelated features, dependencies,
frameworks, and architectural rewrites. Ask only when an unresolved choice would
materially change the outcome and project evidence cannot resolve it.

## Implement and verify the requested behavior

Continue through inspection, implementation, verification, and repairs within
scope once authorized. Do not stop at diagnosis. Seek additional authorization
only for actions that actually require it.

Choose checks that can expose the affected failure:

- **Bug:** reproduce the reported conditions, then repeat them after the fix.
- **Gameplay:** run the relevant scene and exercise the actual affected input
  and interaction, including interruptions or lifecycle changes when relevant.
- **Scene or UI:** inspect the running layout, visibility, focus, input, and
  camera behavior. Reading code or a passing parser cannot establish appearance.
- **Persistence:** exercise save/load through the validated owner, including
  reconstruction and relevant failure/recovery paths; protect real player saves.
- **Performance:** measure a realistic baseline and compare the same route and
  settings afterward. Record frame-time distributions and spikes, attribute
  costs, and tie budgets to evidenced target hardware rather than invented FPS
  targets. Preserve atmosphere and detail through measured tradeoffs.
- **Multiplayer, when applicable:** check authority, replication, and behavior
  across peers; do not add networking to a single-player task.

Use this repository's shared-lane wrappers and required receipts/gates; never
launch Godot directly or disturb another contributor's process. Respect current
input restrictions: a window on another desktop alone does not guarantee mouse
isolation. For art, follow [the batch workflow](../../../art/blender/v2_batch_workflow.md)
and finish related Blender review before combined Godot captures.

Add tests for meaningful behavior, not implementation-shaped assertions. Keep
verification proportionate; reuse unchanged evidence where valid and repeat a
check only when changed inputs, failures, or unresolved concerns justify it.

## Minimize time spent running Godot

Fast iteration is a priority. Before launching, identify the changed behavior,
the smallest check that can expose its failure, and the expected startup/run
cost from existing receipts. Do not repeat long walks through unchanged areas
to reach the work. Use an explicit test-only starting fixture near the affected
area, then exercise its real controller, input, collision and state owners.
Keep that fixture separate from production spawning; report its narrower scope.

Use static checks or an existing small family bench before composing the world.
Inspect the suite's actual programme, not its name: a surface survey may also
run unrelated interaction families. Prefer its existing scoped modes when they
cover the change, and verify the resulting contract states exactly what ran.
Combine closely related checks when this saves startup cost without creating
an oversized failure-prone suite. Reserve full played routes for integration
checkpoints or changes whose dependency coverage genuinely requires them.
Reuse valid unchanged route evidence instead of repeating it for each repair,
visual adjustment, report edit or diagnostic. A performance experiment should
measure a short, repeatable representative segment, excluding unrelated travel.
For performance captures, coordinate CPU-heavy native construction and rendering
as well as GPU work with other agents. Record concurrent host load; a free Godot
lane alone does not establish an uncontended timing baseline. Callback counts
identify candidates, not cost: use reversible controls before reducing fidelity.
Do not shorten runs by raising player speed, relaxing deadlines/tolerances,
bypassing affected interactions or weakening acceptance. An interrupted run is
partial evidence even if closing its window returns exit zero: require the
test-written completed contract before claiming a pass. Respect shared-lane
ownership when cancelling or rescheduling; never stop another agent's run.

## Report the evidence honestly

Separate what changed, what ran, what passed, and what remains unverified. Retain
original failures. Distinguish diagnostics, runtime qualification, and human
acceptance under the repository's evidence rules. Headless parsing and automated
tests do not prove visual presentation, interaction, or game feel.

If Godot, graphics, target hardware, or required assets are unavailable, finish
independent work and name the precise limitation. Never claim a playtest from
static inspection or headless checks. Technical checks establish functionality;
the owner's judgment and actual playtesting establish humor, atmosphere,
readability, and feel.

## Reuse demonstrated project lessons

- **Body LOD and retained equipment:** inspect the whole rendered assembly at
  distance, not only the new body indices. A correct authored building LOD can
  coexist with a destructively simplified retained rooftop tank. Isolate the
  affected owner; preserve native/LOD0 buffers and collision. If the automatic
  tail is broken, remove it only for that asset, inspect the same far view and
  record the added primitives/draws and measured timing limits. Retaining a full
  body is an explicit interim cost; keep a complete replacement-body task open.
  See the city report's canonical northeast intake/tank repair.

- **Yield boundaries:** capture immutable layout and source guards before the
  first cooperative yield. Taking a snapshot after validation can bless an
  intervening mutation. Test cancellation and source/layout/pose changes at
  each added boundary, plus exact final geometry/material/collision output.
  Measure operation durations inside the stage; subtracting timestamps across
  yields includes waiting frames. See the prologue ledger's canopy preparation
  candidate and its retained original/equivalence controls.

- **Reusing scene-test helpers:** inspect _ready and deferred startup before
  add_child. Set an explicit externally managed mode before attachment so a
  camera helper cannot compose a second world. Exercise a small lifecycle
  control before the expensive combined run. See the prologue ledger's retained
  canopy/lamp combined01 failure; standalone defaults must remain unchanged.
- **Composed fixture readiness:** a startup marker can precede the first normal
  process/draw. Before timing an installed mechanism, await real physics/draw
  registration. If it appears stuck, record frame count, callback clock, power,
  pause and ancestor processing modes before extending a timeout. Use a fresh
  log directory for every retry; archive original failures before any reuse.
- **Native CLI arrays:** pass multiargument engine overrides through the lane
  JSON batch format. A comma-separated array passed through another pwsh -File
  can become one literal argument. Inspect the actual child command and native
  viewport before treating a launch as input/visual evidence. Preserve and
  retire only a demonstrated malformed run owned by this task; never stop a
  foreign process. See the prologue ledger's sink presentation qualification.
- **Runtime branches:** parsing and successful instantiation do not execute
  conditional branches. Exercise the changed branch with actual values. On the
  pinned Godot build, a ternary producing an untyped Array can fail when assigned
  to Array[String] at runtime; use explicit typed construction/assignment or an
  intentionally untyped local rather than trusting preflight alone.
  Grammar checks and editor imports also do not prove semantic compilation of
  an unnamed dependency. Type values read through dynamic Node properties
  explicitly where inference has no declared type, then load the selected scene.
- **Physical UI:** stored text and a finished print flag do not establish
  readable output. Inspect the delivered glyphs against glass, moving covers,
  keyboards and actual camera framing; wait for the real delivery motion.
  Continuous playthrough checks must inspect nested helpers too: differential
  captures may deliberately pause or hide the subject. Keep those controls in
  a separate recovery/optical programme and review ordinary captures in the
  uninterrupted route; never silently waive the interruption. See the prologue
  ledger's continuous actual-title programme.
  Validate optical checks against known obscured/hidden controls. A positive
  colour count is not proof if unrelated emissive hardware can satisfy it.
  Let the real lamp and pose transitions settle before freezing a capture;
  assert final power/visibility. For a fixed review stance, stop the body physics
  before placing and aiming the camera so its next step cannot change framing.
- **Review cameras:** inherit the intended production camera's cull mask.
  A default Camera3D can expose reflection-only avatars and create apparent
  geometry artifacts. The entrance review's white streak disappears with the
  first-person mask; preserve the mirror's separate inclusion of the avatar.
  Derive test stances through the actual owner's frame, not raw layout numbers.
  For LOD optics, a small end-cap arris can become subpixel even when indices
  switch correctly. Choose a resolvable actual structural face and retain the
  image-coverage assertion and blank control. A physics visibility ray can also
  hit an explicitly nonrendered travel limit. For that optical diagnostic only,
  retain the unfiltered result,exclude only the verified nonvisual owner,and
  assert its collision layer/shape stay exact; keep every rendered world blocker
  and gameplay/perception ray unchanged. Inspect the actual rendered result.
  See the city bridge intake's retained failures and corrected roof contract.
- **Mechanical handoffs:** advance from the outgoing owner's acknowledgement
  into the incoming owner's real readiness state. A protected observation pose
  may not yet permit typing; do not force a mechanism or weaken its constraints
  to satisfy a guessed delay. Bound retries and preserve accepted-command state.
  A public resume API does not prove automatic recovery: cancel through a real
  successor, release it, and exercise validated reload without a manual restart.
  Test reloads after completion has disabled processing too. Retire recovery at
  shutdown and preserve foreign input/camera ownership. Test each transient
  phase owner: DREAM recovery does not establish synchronization or title retry.
  A camera-only successor needs protection even when no text editor is active.
  For floating-point annual/seam checks, retain raw values and use signed cyclic
  distance with an explicit precision tolerance; positive modulo can turn a
  microsecond rounding error into an apparent full-year offset.
- **Clock coordinates:** separate reversible calendar presentation from
  monotonic elapsed/deadline counters. An annual civil loop must not wrap a
  service deadline. Derive paper, sky and adopted destination from one immutable
  target; test the annual seam, local-zone boundaries and validated reloads.

The [prologue ledger](../../../design/V2_PROLOGUE_2026-10-28.md) records the
annual-clock evidence and first-contact failures behind these lessons. Its
unqualified visual candidate is not a completed opening or an accepted remedy.

For texture, PBR, glass, sky or shader appearance work, also use
[godot-textures-and-shaders](../godot-textures-and-shaders/SKILL.md). It covers
surface ownership, physical sampling, optical boundaries and rendered checks;
this skill retains the runtime integration and gameplay verification workflow.

Choose only the lessons relevant to the current task; do not turn every repair
into a whole-world test campaign. Read linked evidence for its date and limits.

- **Installed ownership:** trace the selector, inherited entry script and actual
  loader. Editing an unused candidate does not update the game. Native visual
  replacement consumes existing mechanical/state owners; visual, simulated and
  player-operable are distinct capabilities. Assert nonzero expected part/owner
  counts so retired arrays cannot produce an empty passing loop.
- **Production parenting:** exercise the real node hierarchy. A cinematic tested
  beside the world can behave differently when installed beneath it. World-tree
  observers should distinguish borrowed world presentation from their own
  subtree, so they cannot hide their own veil/title or mute their own audio.
  Inspect the delivered frame: a completed timeline and visible Label property
  do not prove visible output. Use a demonstrated obscured frame as a negative
  control when adding optical checks.
- **Shared resources and lifecycle:** duplicate only when local ownership needs
  it; preserve catalogue defaults, optical tint/alpha/culling and teardown
  restoration. Cache lifetime must follow the actual owner. Strong restoration
  references can keep retired materials/textures alive. Prove imported/source
  signatures before reuse; timestamps alone are not content identity. See
  [material lifetime evidence](../../../design/V2_PORTRAIT_RELOAD_AND_UV_LIFETIME_2026-10-24.md).
  Lifetime fixtures identify process caches by exact owner/resource identities;
  retain a same-type owned negative control rather than exempting a whole class.
- **Native import:** for Blender work use
  [blender-asset-development](../blender-asset-development/SKILL.md). Test imported
  UV precision, normal/tangent derivatives and loaded maps in a small family
  bench before a full world. Reuse the actual loader and preserve shared
  material ownership; a source GLB pass does not establish its imported result.
  The pinned glTF importer nests authoring metadata under `get_meta("extras")`;
  it also sanitizes illegal node-name characters. Preserve semantic key tokens
  in extras and verify the loaded bindings rather than relying on raw names.
  A reviewed source-binding refresh changes the containing fixture bytes too;
  check the complete declared downstream fixture closure before reopening the
  world. Prove unchanged consumed projections/native stock and retain prior
  pins or reports before refreshing metadata; do not blindly repin dependencies.
- **Input:** exercise the first mouse increment, continued hold, travel stops,
  release and cancellation with the real controller. Toggle tests do not prove
  direct manipulation. Preserve draft/focus and pause/input ownership. Do not
  repair a blocked stance by shrinking the player capsule or excluding real
  gameplay blockers. See the [pull/input repair](../../../design/V2_PASSAGE_PULL_AND_OAK_2026-10-25.md).
- **Time and visibility:** derive reversible sky presentation from authoritative
  fractional campaign time, not scene uptime or an independent clock. Check
  pause and out-of-order return with rendered comparisons as well as uniforms.
  Manual refresh tests do not prove that scheduling is connected: let the actual
  poll/signal observe changed authoritative time, including pause and resume.
  Keep future news hidden behind its reading/publication owners. A readable
  composited companion must still leave world blockers authoritative for its
  lamp; protect both positive visibility and negative occlusion controls.
- **Performance:** keep screenshot readback/PNG encoding outside measured input
  routes. Retain cold and warmed distributions, source-frozen paired routes and
  actual settings. CPU counters can lag/overlap; main-viewport GPU timing is not
  the sum of private viewports. Residency labels and compilation counters show
  correlation, not function attribution. Separate asset load, script, physics,
  shader compilation and render costs before assigning a cause or a speedup.
  Do not derive precise frame times from integer `Performance.TIME_FPS` values.
  Sample frame deltas and cross-check monotonic wall time over the same frames;
  a return-to-first-view A/A control can distinguish drift from a changed view.
  [Claude's probe re-audit](../../../design/DT4_PERFORMANCE_REAUDIT.md) records
  the quantization failure; its historical bottleneck/quality claims require
  current route, renderer and hardware measurements before reuse.
  A small timed reader/presenter excludes only its synchronous work; report
  deferred engine costs separately rather than clearing the whole feature.
  For repeated fixed-geometry queries, profile the actual restored/settling
  owner before optimizing. A conservative spatial index can retain the exact
  narrow phase; compare against the original scan on imported geometry, including
  negative coordinates, cell boundaries and holes. Separate synchronous reload
  costs from the following draw interval; retain residual spikes. The prologue
  ledger records the basin-plug equivalence and before/after evidence.
  Time the same invocation as the spike, not a previous instance's setup.
  Awaiting the next process frame before post-draw can miss an immediate draw
  after reload; retain that observation gap and sample the triggering iteration.
  Check counter semantics in the pinned engine: its process/physics monitors
  publish one-second peaks, not independent per-frame script/physics times.
  The local script debugger needs **both** `--debug --profiling`; require its
  `BEGIN PROFILING` marker. `--profiling` alone does not activate a debugger in
  this engine. Use `--ignore-error-breaks` for bounded unattended diagnostics.
  It samples a frame once per second, adds substantial instrumentation/stdout
  overhead and can make a previously passing controller route time out. Keep
  that failure; use call paths to choose unprofiled measurements. Shutdown
  totals may omit already-retired scripts (the occupied run printed zero), so
  inspect actual output rather than assuming a complete accumulation. Separate
  startup, streaming, test hashing and teardown. See
  [release attribution](../../../design/V2_BACKGROUND_HOUSEHOLD_SAVES_2026-10-23.md).
- **Read-only hot paths:** reuse an authoritative validated read within one
  synchronous, non-mutating query before considering persistent caches. Prove
  that the next call sees in-place edits, replacement domains and corruption
  in a different holder. Preserve the full validator and mutation/save owners.
  Audit authoring consumers as well as runtime references before relocating held
  assets; update generator destinations so they cannot silently restore retired
  runtime copies. With indexed deletions, stage the named paths before the surface
  snapshot: its tracked-import enumeration otherwise reads missing old sidecars.
  On Windows inspect junctions/reparse points before archiving, moving or
  removing a worktree. Resolve their targets and keep linked subtrees out of
  bulk file enumeration so cleanup cannot move the owner's only asset copy.
- **Owner-tick evidence:** an idle timer completing does not establish that a
  physics-polled owner has run. Await its normal state/tick with a bounded
  deadline and assert the result; do not force the refresh or outcome. Godot4.7
  `SceneTree.create_timer` defaults to process, not physics. Retain observed
  tick counts and original failures; clock projection, visibility and lifecycle
  are separate claims. See the prologue ledger's temporal identity diagnosis.
- **Static baseline provenance:** freeze inputs until the gate board finishes;
  its Git metadata is collected after its gates run. Restoring a clean tree at
  the end does not establish that earlier checks ran against that same tree.
- **Changed verification instruments:** inspect candidate changes to audits,
  exceptions, fixtures and source manifests before trusting their passing output.
  Keep any necessary owner-authorized exception narrow and retain negative
  controls for side effects and unrelated callers. See the prologue ledger's
  candidate instrument review for the source-bound checks and their limits.
- **Gate selection:** request each gate with a separate `--only` argument and
  inspect the resulting rows. An empty board proves no checks ran. Unknown
  selections now refuse before execution; do not treat an older empty green
  result as verification. See `tools/tests/test_gate_board.py`.
- **Evidence pitfalls:** runtime-composing MultiMesh tests need the windowed
  backend here; headless identity readback is not proof of corrupt source poses.
  Pointer/UI tests also need a real viewport: log its rectangle and require
  intended outside-clicks to lie outside the actual target before interpreting
  a failed gesture. Headless display sizes can be dummy values; passing model
  checks does not establish the rendered layout or pointer route. The prologue
  ledger retains the newspaper's headless failure and fullscreen comparison.
  Use the pinned patched Vulkan engine and lane receipts. A graceful exit can
  precede test completion: require the test's complete output/contract. Freeze
  rendering inputs during source-bound runs; renew stale qualification rather
  than waiving or repinning it. See the [batch workflow](../../../art/blender/v2_batch_workflow.md).
  Check each batch stage's receipt: an earlier stage passing does not establish
  that later stages started. Preserve a between-stage busy refusal and resume
  only unfinished stages through guarded wrappers; never restart a live handle.

[Astra's material-binding notes](../../../design/astra/work/apartment_material_binding/README.md)
preserve original fixture/runner failures and distinguish preparation from an
executed verdict. [Claude's lived-in pass](../../../design/CLAUDE_APARTMENT_LIVED_IN_PASS.md)
separates gameplay, simulated and visual function while limiting actor/draw cost.
Their historical baselines are not current acceptance. Preserve authoring/debug
stimuli as diagnostics rather than silently turning them into gameplay features.

## Keep this skill current

Update this existing skill when a reproduced failure or verified improvement
changes how future Godot work should be executed. Merge lessons with related
guidance, retain a source/evidence pointer and state engine/platform limits;
do not append a session diary or promote an unverified proposed fix into a rule.
Revise obsolete advice when contrary evidence appears. Keep detailed findings
in their existing subsystem ledger and texture/native authoring in the linked
skills. Validate skill structure and links after edits; documentation-only
maintenance does not require another Godot launch or gameplay acceptance claim.
