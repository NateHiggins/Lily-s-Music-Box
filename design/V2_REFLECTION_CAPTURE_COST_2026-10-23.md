# V2 reflection capture cost — 2026-10-23

Evidence class: **INERT**. Measured repair and visual review report;
not area acceptance, whole-world qualification or human acceptance.

## Issue log

| Location | Reproduction / severity | Evidence | Repair / verification |
|---|---|---|---|
| Existing occupied 2A movement/print route | First room probe stalls input; high | Prior **world_v2/** maximum 335.892 ms, 90 new surface pipelines | Omit shadow-map work from secondary cube captures; retain main shadows; final route below |
| Warmed bathroom/kitchen captures | Refresh after a circuit change; high | Lit kitchen refresh reaches 237.797 ms with capture shadows, 60.540 ms without | Same secondary-capture tradeoff; paired lit/dark views retained |
| Live bathroom mirror | Extra view costs about 5.5 ms CPU; medium | **production_v1/** active-mirror CPU median | Occlusion experiment rejected; original mirror/root restored |
| First appearance study | Camera initially aimed below the mirror; diagnostic limitation | **paired_views_v1/** shows sink/metal finishes, not useful mirror coverage | **production_v1-v2/** resolve actual mirror center; final run includes actual sidestep/turn |

Review root: **art/reviews/v2_reflection_capture_20261023/**. Original baselines
and diagnostic variants are retained. The earlier rejected shader warmups
remain rejected; none is installed. Main geometry, texture detail, glass,
normal mapping, primary lighting and physical mechanisms are unchanged.

## Capture repair and visual tradeoff

The production room probe still captures the actual room, retains its bounded
three-probe cache, box projection, size, origin, masks, face resolution and
30-second refresh schedule. SwitchSystem still invalidates room captures.
Probe diffuse ambient stays disabled. Only shadows inside these secondary
cube captures are disabled; the visible world and planar mirror still render
their existing shadows. The carried lamp remains excluded from room captures
as before. This does not disable reflections, replace them with fake images,
change a work/case authority or alter collision behavior.

Paired lit and dark bathroom/kitchen views retain room darkness and primary
shadows. Brass is slightly brighter in darkness without capture shadows; this
is the accepted visual tradeoff for lower capture cost, not a claim of exact
radiometric equivalence. Fixture personalities/weather can vary between
captures. These two rooms do not establish every daylight/weather/material
combination. The first study covers sink and metal stock; later views actually
show the live mirror. Further broad visual qualification remains open.

The [Godot ReflectionProbe reference](https://docs.godotengine.org/en/stable/classes/class_reflectionprobe.html)
documents this shadow-quality/performance tradeoff. The
[4.7 renderer source](https://github.com/godotengine/godot/blob/4.7-stable/servers/rendering/renderer_scene_cull.cpp)
renders all six cube faces in the initial capture step. A script refresh timer
cannot amortize those faces across frames. This explains why the existing
30-second timer does not prevent capture stalls; the actual runs measure the
cost rather than treating the source as a benchmark.

## Rejected mirror candidate

Only V2 temporarily opted the mirror viewport into the existing conservative
solid-wall occluders. The [Viewport reference](https://docs.godotengine.org/en/stable/classes/class_viewport.html)
requires an explicit opt-in for each extra viewport. Actual paired results did
not justify retaining it: lit mirror CPU median 5.629 -> 6.682 ms; dark mirror
5.394 -> 5.350 ms. Lit wall p50 rose 42.386 -> 48.357 ms, while dark wall p50
fell 46.698 -> 43.460 ms. No reliable improvement. Mirror and runtime-root
production files were restored to the starting checkpoint; no occlusion toggle
or extra proxy geometry is installed.

The candidate's short oblique route produced only two rendered samples while
physics caught up after a synchronous screenshot; it recorded a 420.782 ms
wall frame and new draw/specialization pipelines. Retain that observation,
but do not use two samples as a distribution or claim a smooth oblique route.
The final fixture settles the readback before sampling and awaits a rendered
frame per movement step. The persistent mirror grain/condensation pattern is
also present in the no-occlusion baseline, not a culling repair/regression.

## Measurements and scope

**compare.py** regenerates **comparison.json**. Standard movement phases use
the same actual W/S/turn sequence over 300 physics ticks, 1280x720 Forward+,
uncapped, VSync off. Exclude each phase's first partial sample. The room-refresh
phases are distinct still-eye diagnostics, with six full samples before the
refresh, so dropping a partial frame cannot hide the stall. Screenshots occur
after sampling. The final oblique mirror movement is a separate short actual
sidestep/turn, not a full room access route.

| Standard route phase | Before p50 / p95 / p99 / max ms | Final p50 / p95 / p99 / max ms |
|---|---|---|
| First report | 22.529 / 31.111 / 38.940 / 335.892 | 20.999 / 27.901 / 48.825 / 159.291 |
| Steady print | 21.251 / 27.706 / 30.351 / 37.122 | 22.001 / 28.216 / 30.724 / 38.762 |
| Raised idle | 20.812 / 27.490 / 28.932 / 31.613 | 21.199 / 27.915 / 29.999 / 31.589 |
| Lowered | 20.893 / 27.007 / 30.088 / 36.368 | 20.690 / 27.706 / 30.612 / 39.209 |

The final first-report maximum is 52.6% lower, with one frame above 100 ms
in both before and final runs. However, final p99 is worse. Earlier production
shadow-only run reaches p99/max 32.373/163.573 ms; the diagnostic shadow-off
control reaches 32.590/168.909 ms. Preserve all runs. This is a measured
worst-stall reduction with variable tails, not an across-the-board responsiveness
claim. Steady-state distributions remain similar/slightly worse.

The corrected final oblique bathroom phase has 29 complete samples:
p50/p95/p99/max 132.614/451.031/456.239/457.512 ms. This is a serious unresolved
actual-input defect. New draw/specialization pipelines appear during the turn;
physics and main-render costs also rise. The eight-frame settle and per-step
render await show it cannot simply be dismissed as the earlier two-sample
readback artifact. Profile the player's existing **profile_physics** /
**physics_profile_records** and step/contact path here, alongside renderer
cost, before selecting a repair. A diagnostic disable-step-guard comparison
would be causal evidence only, not permission to bypass physical protection.

Surface-pipeline count still increases by 90 on first use. This repair does not
solve that shader hitch. Renderer/process/physics timings overlap and lag;
asset loading and streaming are not independently isolated. No cold driver
cache claim. Mirror render monitors retain old values while sleeping; compare
them only when the recorded mirror is active. Broad movement, cell transitions,
near-furnishing costs and whole-V2 responsiveness remain open.

## Report

REPORT - reflection-capture-cost - 2026-10-23

Starting **b0bd72b9**, branch **codex/v2-acoustic-topology**. Named paths only;
unrelated spatial manifest and street/tent/traffic work preserved. No new
material key, physical surface or ledger promotion. The selector and explicit
V1 rollback remain unchanged. No management certificate or whole-V2 completion.

**production_final/carried_controls_runtime_contract.json** is test-written
schema 2, 71 actual-input checks pass. The separate listener/deployment
**production_final/runtime_contract.json** retains 24 listener checks and two
actual grille grabs. Those contracts qualify their stated interaction scope,
not reflection quality or smooth bathroom movement. **production_final.log.receipt.json**
binds to the final entry script/runtime and records wrapper completion only.
All original controls, paired variants and failed mirror/oblique attempts remain.
The original seven texture-RID shutdown warning remains; no new clean-shutdown
claim. All 17 protected paths remain unchanged versus the starting checkpoint.
Mirror and runtime-root source are unchanged after rejecting their candidate.

Fresh **gates/board.json**: reader remains 33 existing NEW street/tent findings;
carriers and systemic pass; spatial has the same eight failures and now 21
reported findings, including diagnostic fixture references. Do not blanket-
rebaseline the unrelated manifest. The preceding checkpoint ran all 98 tools
suites (1,194 tests), with five existing failures across four suites. No art
asset or import policy changed, so unchanged UV/PBR/mipmap proof is reused;
global surface/rendered qualification remains stale and needs renewal.

Remaining: first-use shader compilation, broader daylight/weather visual
review, dark-brass secondary-light leakage, the slower upper-room steady
frames, and the rest of the V2 repair and qualification queue. Human appearance
acceptance is open; no Godot operational approval is pending.
