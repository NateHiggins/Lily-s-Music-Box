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

Choose only the lessons relevant to the current task; do not turn every repair
into a whole-world test campaign. Read linked evidence for its date and limits.

- **Installed ownership:** trace the selector, inherited entry script and actual
  loader. Editing an unused candidate does not update the game. Native visual
  replacement consumes existing mechanical/state owners; visual, simulated and
  player-operable are distinct capabilities. Assert nonzero expected part/owner
  counts so retired arrays cannot produce an empty passing loop.
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
- **Input:** exercise the first mouse increment, continued hold, travel stops,
  release and cancellation with the real controller. Toggle tests do not prove
  direct manipulation. Preserve draft/focus and pause/input ownership. Do not
  repair a blocked stance by shrinking the player capsule or excluding real
  gameplay blockers. See the [pull/input repair](../../../design/V2_PASSAGE_PULL_AND_OAK_2026-10-25.md).
- **Time and visibility:** derive reversible sky presentation from authoritative
  fractional campaign time, not scene uptime or an independent clock. Check
  pause and out-of-order return with rendered comparisons as well as uniforms.
  Keep future news hidden behind its reading/publication owners. A readable
  composited companion must still leave world blockers authoritative for its
  lamp; protect both positive visibility and negative occlusion controls.
- **Performance:** keep screenshot readback/PNG encoding outside measured input
  routes. Retain cold and warmed distributions, source-frozen paired routes and
  actual settings. CPU counters can lag/overlap; main-viewport GPU timing is not
  the sum of private viewports. Residency labels and compilation counters show
  correlation, not function attribution. Separate asset load, script, physics,
  shader compilation and render costs before assigning a cause or a speedup.
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
- **Static baseline provenance:** freeze inputs until the gate board finishes;
  its Git metadata is collected after its gates run. Restoring a clean tree at
  the end does not establish that earlier checks ran against that same tree.
- **Evidence pitfalls:** runtime-composing MultiMesh tests need the windowed
  backend here; headless identity readback is not proof of corrupt source poses.
  Use the pinned patched Vulkan engine and lane receipts. A graceful exit can
  precede test completion: require the test's complete output/contract. Freeze
  rendering inputs during source-bound runs; renew stale qualification rather
  than waiving or repinning it. See the [batch workflow](../../../art/blender/v2_batch_workflow.md).

[Astra's material-binding notes](../../../design/astra/work/apartment_material_binding/README.md)
preserve original fixture/runner failures and distinguish preparation from an
executed verdict. [Claude's lived-in pass](../../../design/CLAUDE_APARTMENT_LIVED_IN_PASS.md)
separates gameplay, simulated and visual function while limiting actor/draw cost.
Their historical baselines are not current acceptance. Preserve authoring/debug
stimuli as diagnostics rather than silently turning them into gameplay features.
