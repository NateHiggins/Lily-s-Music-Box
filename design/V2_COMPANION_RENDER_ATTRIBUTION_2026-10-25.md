# Companion and first-render attribution

Evidence class: **INERT**. Diagnostic observations only. No runtime-contract,
whole-world, performance qualification, default cutover or human acceptance.

## Method and preserved failures

The paired production-world scenes use the original carrier and the opt-in
companion at the same entrance, frozen campaign date 1928-11-10 20:00, seed
1928, requested uncapped rendering/VSync off, 1280×720, FOV 72, physics 60 Hz,
and the existing driver cache. The cache is neither cleared nor controlled.
Actual effective FPS/present settings were not sampled after composition;
these settings are requests, not proof of the driver's pacing policy.
The original runs first. Cache and order effects prevent attributing differing
medians to a production improvement. All captures, logs, wrapper receipts,
executed-source snapshots and raw samples are preserved in
**art/reviews/v2_carrier_cost_20261025** with SHA-256 entries in **archive.json**.

The short route uses actual W/S and mouse events twice, presentation hiding,
motion and lamp controls, recall, free-cursor inspection, specific lamp-contact
grab, partial mouse travel, next-click release and return to walking. No cell
boundary is crossed: load/unload counts remain zero. Detailed furniture,
streaming transitions, saves and whole-world access remain outside this route.

**original_v1** passes 13 checks. **companion_v1** fails one of 13 checks:
release is asserted before the buffered synthetic event is consumed.
**companion_v2** fails Godot type inference on the fixture's untyped grab
readback before world construction; only its verified owned engine is stopped.
It has no runtime verdict. Both original failures remain unchanged.
**companion_v3** explicitly types the readback and holds synthetic press/release
through frame-post-draw. It passes 18 checks with 1,444 samples. Traces show
the controller consumes the buffered input on the following frame. This does
not measure physical-device input latency or establish a dropped human click.
No production interaction behavior was changed to repair the fixture.

## Measurements

The sample clock never resets at physics ticks or phase changes. Construction-
overlapping intervals are excluded from playable distributions; phase-boundary
intervals remain in the overall distribution. Capture/readback intervals are
explicitly excluded. **tools/analyze_v2_carrier_cost.py** reproduces the summary
and callback overlap from raw timestamps. CPU render boundaries, process and
physics monitors overlap and lag: they must not be summed or interpreted as
GPU completion. Observer-query timing is recorded separately. Callback probes
are bounded, opt-in and disabled in normal play.

| Run | Playable intervals | p50 / p95 / p99 / max, ms | Max pre/post-draw span, ms |
|---|---:|---|---:|
| Original v1 | 937 | 33.762 / 38.747 / 47.817 / 5875.285 | 5768.283 |
| Companion v1, failed release | 987 | 31.949 / 37.107 / 39.644 / 5231.147 | 5079.413 |
| Companion v3, extended controls | 1441 | 31.706 / 36.043 / 66.129 / 5423.349 | 5260.119 |

These aggregate routes have different control lengths; do not treat the third
row as an optimized comparison. The large initial spike occurs with both
carriers. Original v1's largest carrier callback is 638 microseconds, while
its renderer measurement query is at most 33 microseconds. Companion v3's
largest presentation, flight and mechanism callbacks are respectively 83,
316 and 188 microseconds. Flight's query/move/pose subspans are nested;
they are not additional costs to add to the inclusive callback.

The initial pipeline counters rise to 250 surface/42 draw/160 specialization
for the original and 256/42/153 for companion v1. Node/resource counts remain
stable across the large interval, with zero reflection probes and zero cell
load/unload cycles. This locates most of the observed pause between render
boundaries, rather than in measured companion callbacks. It does not isolate
shader compilation, GPU uploads, engine scene traversal or driver stalls.
Startup's lagging physics monitor includes construction time and cannot be
reported as an actual physics callback. Companion flight initialization also
contains two awaited physics frames; its setup span is wall time, not CPU work.

Godot's [pipeline documentation](https://docs.godotengine.org/en/4.6/tutorials/performance/pipeline_compilations.html)
distinguishes surface/draw compilation from background specialization. Counter
growth alone cannot prove which mechanism caused this interval. Earlier
reflection warmups remain rejected as documented in
**V2_REFLECTION_PIPELINE_WARMUP_2026-10-23.md**.

## Rejected quality change

The same companion scene compares 8×/4×/8× MSAA with separate transition and
warmed windows. All three actual captures were inspected. The three-second
warmed median/p95/p99/max distributions, in milliseconds, are:

| Setting | Intervals | p50 | p95 | p99 | max |
|---|---:|---:|---:|---:|---:|
| 8× before | 95 | 30.868 | 34.961 | 35.917 | 35.952 |
| 4× warmed | 94 | 31.540 | 34.190 | 34.564 | 34.792 |
| 8× return | 94 | 31.282 | 34.649 | 36.281 | 36.322 |

No useful median or measured GPU gain appears. The production setting stays
8×. Configuration-transition render intervals remain in the raw records;
setter CPU duration is not separately instrumented. This is a rejected
diagnostic tradeoff, not a delivered performance fix.

## Issue log

| Location / reproduction | Severity / evidence | Repair / verification |
|---|---|---|
| Entrance, initial composed-world render | High: 5.23–5.88 s wall intervals in both carriers | Added separated callback/render instrumentation; cause not fully isolated, no optimization claimed |
| Companion diagnostic, lamp release assertion | Fixture defect: buffered event consumed next frame | Hold each synthetic event through post-draw; v3 passes actual grab/motion/release |
| Companion teardown | Open renderer lifetime defect: two light-unpair errors in v3 stderr | No suppression; no clean lifetime qualification |
| Main-view 8× MSAA | Investigated cost, no gain from 4× | Downgrade rejected; 8× restored and asserted |

REPORT - companion-render-attribution - 2026-10-25

Branch / starting HEAD / integrated main parent:
**codex/v2-main-integration-20261024 / 5fbca089 / bde30c08**.
Named paths only; canonical shared changes and unrelated orphan UIDs preserved.
Protected17 and selector logic unchanged by these diagnostic paths. Reader:
zero NEW fields. Spatial: no new classifications/drift. Authority: no new
actionable/policy failures; 23 existing review-only findings retained.
Ledger status changes: none. Final management verifier and current-source
surface/global runtime renewal remain pending. Two renderer teardown errors,
the initial-render stall and the full companion C–G/V2 scope remain open.
Decision needed from owner: none. This is a draft integration checkpoint.

Follow-up: **V2_DEVICE_LIGHT_PAIRING_2026-10-25.md** records a pre-tree render-
layer initialization repair and a clean-stderr occupied-world rerun. The
original two errors above remain part of this unchanged failed-lifetime
observation. The initial-render stall remains unresolved in the follow-up.
