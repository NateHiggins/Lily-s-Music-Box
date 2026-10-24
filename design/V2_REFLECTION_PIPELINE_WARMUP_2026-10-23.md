# V2 reflection pipeline warmup — 2026-10-23

Evidence class: **INERT**. Performance investigation and rejected candidate report,
not area acceptance or whole-world runtime qualification.

## Issue log

| Location | Reproduction / severity | Evidence | Repair / verification |
|---|---|---|---|
| Occupied 2A route, first field report | Walk and turn while printing; high, visible 322 ms stall | **profile_ui_v2/**: 90 new surface pipelines at first room probe | Rejected warmup treatments; production remains unchanged |
| Hidden-node warmup candidate | Same route; ineffective | **reflection_early_v1/**: 322.352 ms, 90 pipelines | Rejected; no hidden-only declaration retained |
| Separate-viewport candidate | Same route; extra renderer resources | **reflection_early_v2/**: 205.339 ms, zero late surface pipelines; 14 texture RIDs on shutdown | Rejected private viewport; reuse existing render target |
| Small fixture API typo | Fixture does not start | **reflection_warmup_small_v1.log.stderr**, wrapper timeout, no verdict | Correct API; original failure retained |

All paths above are under **art/reviews/v2_handheld_20261023/**. Small v2 and
v3 fail because immediately retiring the warm scene disables the rendering
feature again; v3 repeats v2 after an unsuccessful shell edit. Small v4 proves
keeping the feature alive works, v5 proves real-probe handoff, v6 uses the
existing viewport and restores the previous seven-RID warning baseline.

## Rejected treatment and costs

The candidate, now removed from production, rendered before ordinary V2 geometry was composed: a temporary camera renders a tiny
metallic box and reflection probe at a remote loading-only location. The draw
uses the existing viewport and MSAA configuration, does not swap the window,
and performs no image readback. The previous camera is restored immediately;
the temporary draw and light are hidden. The probe stays active until two
render frames after the first real room probe is added, then its entire
subtree retires. The initialization marker belongs to this world, so a later
world reconstruction does not mistakenly reuse an earlier scene's marker.
Compatibility / no-render-device paths skip this work.

The real probe's bounds, capture masks, shadows, lighting, refresh schedule,
three-room cache and material finish remain unchanged. Production retains its original behavior. No reflections are
disabled in production. This shifts shader preparation into loading; it does
not remove the subsequent room capture cost. The code makes one synchronous
draw during loading and never synchronizes the GPU in ordinary interaction.

[Godot's pipeline guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)
recommends initializing rendering features before loading most geometry. The
mere presence of a hidden probe was insufficient on this measured backend.
The [RenderingServer reference](https://docs.godotengine.org/en/stable/classes/class_renderingserver.html)
documents the forced draw and synchronization used here. These are design
references; the retained actual runs establish this implementation's behavior.

## Measurement and limits

Use **compare_reflections.py** and **reflection_comparison.json**. Each phase
uses the same 300 physics-tick W/S and turn route, 1280x720 Forward+, uncapped,
VSync off, same print card. Exclude each phase's first partial wall sample.
No screenshot/readback occurs during a sampled phase. This is an initialized
world and existing driver cache, not a cold-driver claim. Repeatability is
bounded to this short route; frame monitors overlap and lag, and loading /
streaming costs are not separately instrumented.

The no-reflections causal control reaches 46.802 ms maximum, zero probes and
zero late surface pipelines. It is a diagnostic intervention, deliberately
writes no runtime contract, and is not a shipping visual tradeoff. Removing
late compilation alone still leaves capture cost. Do not claim the full stall
is fixed, nor that process, physics and renderer timings can simply be added.

| First report treatment | p50 / p95 / p99 / max ms | Frames >100 ms | Late surface pipelines |
|---|---|---:|---:|
| Installed device, no warmup | 20.868 / 32.208 / 39.697 / 322.443 | 1 | 90 |
| Reflections disabled (diagnostic) | 21.410 / 32.448 / 42.488 / 46.802 | 0 | 0 |
| Hidden declaration (rejected) | 21.605 / 32.641 / 40.195 / 322.352 | 1 | 90 |
| Private viewport (rejected) | 21.864 / 30.648 / 35.992 / 205.339 | 1 | 0 |
| Existing viewport (rejected) | 19.621 / 32.184 / 106.191 / 259.590 | 3 | 0 |

The existing-viewport version spent 10.022 ms warming during loading. It kept
one real probe active and returned shutdown warnings to the original seven
texture RIDs. However, three frames over 100 ms and a much worse p99 reject
this treatment despite its lower maximum. Shader specialization and actual
capture remain involved; the measured counters do not prove those costs are
independent. Both production injection lines were removed and confirmed byte-
identical after newline normalization to **0548d2fd**. There is no shipping
reflection optimization from this investigation.

The remaining helper lives only in **game/tests/reflection_pipeline_warmup.gd**.
It is not referenced by production. The small fixture still exercises feature
handoff. Earlier full-world candidate observations describe the temporary
production injections, not the current runtime. To reproduce them deliberately,
call the helper before composition in the runtime root and retire it from the
real room-probe creation path; neither call is installed. Preserve this
separation when interpreting the historical runtime digests.

A useful next investigation is the cost of the first real cubemap capture and
shader specialization, with a stable, longer warm interval before input. Do
not silently disable reflections, accept the p99 regression or hide measured
stall frames by trimming them from the route.

## Report

REPORT - reflection-pipeline-warmup - 2026-10-23

Starting checkpoint **0548d2fd**, branch **codex/v2-acoustic-topology**. Named
paths only; unrelated spatial manifest and street/tent/traffic work preserved.
The prior complete static board remains **gates/** in the same review root;
its existing surface qualification, census, reader and spatial debt is not
rebaselined. The follow-up reader audit still reports the same 33 street/tent
fields. No new production data fields or ledger requirements are introduced.
No management certificate or whole-V2 completion claim. The retained composed candidate
schema-2 contract covers only the existing listener's flush mount, actual
grille grabs and inspection cursor, and actual E device deployment. Raw
frame timings and wrapper completion are separate from that contract.
