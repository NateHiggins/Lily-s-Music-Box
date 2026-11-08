---
name: orison-optimization
description: Profile and reduce Please Stay on the Line CPU, GPU, loading, memory and repository costs while preserving game behavior and visual intent. Use for measured performance work and audited size reduction; ordinary gameplay repairs use godot-development.
---

# Make the existing game run better

Act as Orison's optimization specialist, coordinating with the integration lead.
Improve the requested bottleneck without expanding the feature or substituting
a cheaper game. Follow [AGENTS.md](../../../AGENTS.md), [DOCS.md](../../../DOCS.md)
and Bible precedence. Use [developer continuity](../developer-continuity/SKILL.md)
for current custody, and [Godot development](../godot-development/SKILL.md) for
implementation and qualification. This skill does not resume a paused goal.

## Establish the actual problem

Inspect the canonical checkout, current owners, live jobs and existing evidence.
Choose one observed symptom: a frame spike, sustained render cost, first-use
stall, reload delay, growing memory or excessive packaged/source files. Read the
actual scene/loader/callback path; labels and callback counts are not attribution.
Use official documentation for the verified engine when API semantics are unclear.

Before substantial edits, state the suspected cost, a reversible discriminator,
the behavior/appearance that must survive, and the smallest useful measurement.
Prefer existing nearby production fixtures. Compile and exercise the affected
input before spending a full-world startup or long route. Do not raise player
speed, relax tolerances, skip collisions or shorten the real interaction to pass.

## Measure comparable work

- Record source signatures, actual patched engine, hardware/driver, resolution,
  renderer, quality settings, VSync/cap, weather/date, camera/route and host load.
  Separate first process/startup, cold first use, warm reuse, transitions and reload.
  Do not call a warmed filesystem or shader cache a cold baseline without evidence.
- Use frame deltas and monotonic elapsed time: sample count, p50/p95/p99, maximum
  and frames over an explicit budget. Relate budgets to the release target and
  actual hardware; do not invent a universal FPS target or derive precise times
  from integer FPS. Record route duration so faster playback cannot fake a gain.
- Exclude screenshot readback, PNG encoding, diagnostic hashing and log bursts
  from interaction timings; report their costs separately. Include relevant
  private viewports. CPU/GPU/physics monitors are not necessarily additive or
  per-frame: the pinned engine's process/physics monitors publish one-second peaks.
- All Godot/GPU work joins the shared FIFO lane with fresh LogPath receipts.
  Use hidden-desktop native-resolution windows for actual frames/input. Arrange
  a matched baseline/treatment in one batch where practical; freeze consumed
  inputs. Coordinate CPU-heavy construction too: owning the GPU lane does not
  prove an uncontended machine. Never interrupt another owner's job.
- Use profilers to locate candidates, then verify unprofiled. This engine needs
  both `--debug --profiling` and a real `BEGIN PROFILING` marker; sampling/stdout
  can distort timing or break route deadlines. Preserve those failures. Use an
  A/A return to the same view or repeated pair when drift leaves the result unclear.

## Reduce the attributed cost

| Cost | Preferred investigation and boundaries |
| --- | --- |
| Script/physics | Trace repeated queries, signatures and allocations. Reuse a validated read within a synchronous non-mutating operation before adding persistent caches. Any cache/index needs invalidation for movement, doors, pose, restore and ownership changes. Compare accelerated queries with the original narrow phase on imported geometry, including holes and boundary cases. Keep real grab, carry, contact and release owners. |
| Rendering | Separate overdraw, shadows, fog/sky, draw submission, private viewports, loaded maps and geometry. Use bounded controls to establish cause, then restore presentation. Culling/LOD must preserve silhouette, world occlusion and authored detail at the required view; mesh-body replacement can help but needs actual transition/return/zoom checks. Do not claim savings from triangle counts alone. Use the [texture/shader](../godot-textures-and-shaders/SKILL.md) and [Blender](../blender-asset-development/SKILL.md) skills when relevant. |
| Loading/memory | Attribute import/load, shader compilation, construction, upload and retirement separately. Preparation is not free: report time to first usable control, preparation time, first interaction and residual spikes. Exercise cancellation, re-entry, transition and teardown. Bound caches by owner/lifetime; prove retired resources are released and repeat-cycle memory stabilizes. A smooth warmed route alone does not prove startup improved. |
| Saves/I/O | Measure serialization, validation, disk work and the following draw interval separately. Preserve validated campaign snapshots, write barriers, recovery and save/reload/Continue boundaries. Never remove validation or postpone durability silently to hide a stall. Verify queued/background work settles correctly on exit and reconstruction. |
| Repository/package size | Count tracked source, generated cache, external evidence and shipped assets separately. Trace consumers/export dependencies before deduplicating or moving files; preserve recoverable authoring sources, failures and provenance. Reuse existing archives rather than copying evidence into another giant folder. File-count/disk savings are not frame-time improvements. Respect current cleanup authorization and other contributors' custody. |

## Qualify the result and stop at the right boundary

Compare the same workload after each meaningful change. Check actual rendered
appearance and affected input/save lifecycle, not just counters. Keep the real
lamp's blockers, protected conversation/input ownership, time/weather/publication,
inventory, quests and resident/save authorities intact. An optimization must not
manufacture observations, skip simulation outcomes or alter dated story facts.

Retain a candidate only when measurements support the intended improvement and
required behavior remains correct. Report uncertainty or mixed results; revert
only your own isolated unsuccessful experiment. Do not silently trade atmosphere
or quality for speed. Agree any material design tradeoff with the owner/lead.

Deliver a compact before/after comparison with settings, distributions, preparation
and memory costs, evidence paths, affected behavior checks and remaining limits.
Use existing ledgers and TASKS.md. Runtime proof requires the actual test-written
contract; wrapper exit0, INERT profiles and screenshots are distinct evidence.
Renew affected source-bound qualification and required candidate gates before
merge; batch related repairs to avoid repeated renewals. Stage named paths only.
Delegate independent read-only attribution or external assets with explicit file
owners; keep live-source edits and dependent fixes under the integration lead.

## Existing entry points and lessons

Read only the relevant owner/test and its latest ledger section, not every file:

- [Entry preparation test](../../../game/tests/v2_entry_render_preparation_test.gd)
  and [city ledger](../../../design/V2_CITY_CONTEXT_REPORT_2026-10-19.md): paired
  entry routes, preparation cost, native/LOD qualification and remaining limits.
- [Played attribution](../../../game/tests/v2_attributed_played_profile.gd),
  [nook profile](../../../game/tests/v2_nook_world_profile.gd) and
  [hose profile](../../../game/tests/v2_hose_fps_world_profile.gd): inspect their
  actual start/fixture scope before claiming continuous playable-world coverage.
- [Background save attribution](../../../design/V2_BACKGROUND_HOUSEHOLD_SAVES_2026-10-23.md)
  and [save validation costs](../../../design/V2_SAVE_UTF8_COST_2026-10-23.md):
  deferred cost, storage boundaries and narrow evidence claims.
- [Performance re-audit](../../../design/DT4_PERFORMANCE_REAUDIT.md): why FPS
  quantization and historical bottleneck claims require renewed measurements.
- [Pipeline tools](../../../tools/PIPELINE_TOOLS.md): lane environment scoping,
  receipts, gates and candidate verification. Existing test flags are inputs,
  not stable APIs; read their consumers before composing a batch.

Update this skill when reproduced evidence changes optimization practice.
Keep transient PIDs, current scores and queue state in the handoff, not here.
