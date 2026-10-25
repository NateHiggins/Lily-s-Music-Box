# Original-carrier world baseline before companion cutover

Evidence class: **INERT**. Measured baseline, not a companion checkpoint or
whole-world performance acceptance.

The existing **V2HandheldProfile** ran windowed in the actual playable V2 world,
with the original installed carrier. It completed in 258.67 seconds, captured
811 frames and reported zero script errors. Source inputs stayed unchanged.
The wrapper receipt and all original samples, images and stderr are preserved
under **art/reviews/v2_companion_20261024/world_baseline_v1/**.

The four phases use the same 300 physics-tick forward/back/turn inputs at the
same starting station: 1280×720 Forward+, 60 Hz physics, uncapped, VSync off.
Screenshots/readbacks occur outside sampled intervals. This is an initialized
world with an existing driver cache. No native rendering overlapped the sampled
phases: the final lowered capture was written at 04:30:24Z, before the next
Blender command log was created at 04:30:29Z.

| Phase | Full intervals | Median / p95 / p99 / maximum ms | Frames >100 ms |
|---|---:|---|---:|
| First report | 172 | 26.24 / 33.92 / 159.38 / 338.50 | 2 |
| Steady report | 207 | 22.91 / 27.15 / 29.04 / 33.46 | 0 |
| Held idle | 215 | 22.95 / 26.08 / 27.39 / 28.11 | 0 |
| Lowered | 213 | 23.14 / 26.21 / 28.45 / 33.93 | 0 |

**summary.json** records both all-frame statistics and full intervals, with
linear interpolation at **(n−1)×p**. The table omits only the first partial
wall interval of each phase. Both 338.50 and 316.07 ms spikes remain included.
Raw samples are unchanged.

Steady-report median measured main-render CPU/GPU was 10.71/7.44 ms; the held
pass was 0.151/0.079 ms, and the physics monitor median was 3.505 ms. These
overlapping, delayed monitors cannot be added to explain a frame. Initial zero
render readings are retained rather than interpreted as zero rendering cost.

The two largest spikes occur near the first room-reflection refresh and late
pipeline creation. First report adds 81 surface and 117 specialization pipeline
counts, while steady report adds zero of either. This is correlation, not
isolated attribution to the printer, reflection capture or shader compilation.
Asset loading/streaming and individual script costs are not separately measured.
The earlier rejected reflection warmups remain rejected; this report installs
no visual downgrade or new warmup.

| Location / reproduction | Severity | Evidence | Repair / verification |
|---|---|---|---|
| First report after composed startup, short office route | High responsiveness issue | 338.50/316.07 ms spikes; first reflection refresh and new pipelines nearby | Open; needs controlled attribution and a repeatable improvement |
| Later steady printing and paired turning at that station | Baseline | 22.91 ms median, 33.46 ms maximum | No optimization claimed; compare the companion under identical settings |
| Shutdown | Existing diagnostic warning | Seven leaked Texture RIDs in original stderr | Preserved; not a passing resource-lifetime claim |

The test also writes its existing schema-2 **runtime_contract.json**. Its scope
is exactly one Vantry ceiling backplate: flush mount, actual click/motion/
release, Space inspection and free-cursor manipulation, plus E paper deployment.
It does not qualify companion movement, typing, dialogue, save/load, new glass,
all rooms, cell transitions, detailed-furnishing approaches or human acceptance.

REPORT - companion-world-baseline - 2026-10-25

Branch / HEAD / local origin/main / merge-base:
**codex/v2-main-integration-20261024 / 14cae0e4 / 862e54a2 / 55e60195**.
Worktree clean at end: no; earlier owned door, NPC and companion candidates,
native review and import churn remain. This checkpoint stages only named
baseline records and this document. Canonical shared work remains separate.
Protected 17/17: not recertified in this report-only checkpoint. Selector: V2;
the explicit V1 rollback remains unchanged.
Ledger before → after: not re-audited; requirements_changed: none claimed.
Gates: document lint clean; existing profile wrapper receipt completed with
exit 0 and **HANDHELD PROFILE: PASS samples=811**. No complete candidate board,
management certificate or merge qualification is claimed.
Numbers requested: frame distributions and spike counts above; no before/after
improvement yet. Changes outside boundary: none. Open findings: first-use
stall, broader routes and attribution, companion integration, existing Texture
RID warnings. Decision needed from owner: none.

BLOCKED merge qualification: companion runtime and broader performance work remain open.
