# Hose spray readability and first-use allocation — 2026-10-24

Evidence class: **INERT**. Rendered, actual-input and performance diagnostics;
no runtime_contract, surface promotion, human acceptance or V2 completion.

REPORT - hose spray readability and input allocation - 2026-10-24

Canonical checkout **C:/PleaseRemainOnTheLine**, branch
**codex/v2-acoustic-topology**, parent **191d5de3**. Previous turn made verified
progress in installed maintenance coverage and exposed weak spray visibility.
Shared bathroom manifest additions and unrelated street/tent/traffic/art/UID
work remain outside this checkpoint. Only the hose's spray presentation and
its preparation timing change in production; mechanical, water, inventory,
NPC, case and save authorities remain unchanged.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Charged hose, F02 cabinet and landing | Weak feedback | Original384 small droplets are hard to see; temporary magenta controls prove particles reach the expected region |128 longer, narrower overlapping streaks, with a restrained optical scattering fill | Actual floor and stairwell views reviewed; five actual aim/inspection directions |
| Water in the nozzle's hard shadow | Incorrect visual emphasis | Larger opaque-looking droplets resemble oil; disabling shadow reception or increasing backlighting alone is insufficient | Retain lit custom water maps and use a0.35 minimum fill term; disable water shadow casting and GI participation | Low/middle/high fill comparison retained; middle chosen for readable water without adding scene lights |
| Backlit trial, first lever operation | Input hitch | Two trials show128–132ms intervals; traced emitter construction costs81.384ms, including76.304ms mesh/material assignment | Prepare the disabled emitter during world setup; keep it hidden until flow | All eight report hidden/non-emitting/GPU-inactive before flow; final first-input peaks52.919/59.223ms |
| Physical-map validation | Incomplete mip evidence | A nonzero mip count alone does not prove a complete chain | Strengthen the focused actual-input fixture with exact counts and original map identity | All three256×256 maps expose8 expected mip levels |

The original registered albedo, roughness and normal textures remain sampled
through the water mesh's UVs. The normal map and lit roughness response remain
enabled. The fill is a deliberate visual approximation for unresolved light
scattering in a fast, aerated stream; it is not a new lamp or a hydraulic
simulation. Particle GI is disabled. Shadow-disabled and backlit-only trials
remain as rejected alternatives. No lettering, generated image, Blender stock,
physical collision boundary or catalogue key changes.

The droplet mesh retains its80-triangle topology. Maximum geometry capacity
per active emitter falls from384×80=30,720 to128×80=10,240 triangles. This is
capacity, not a count of visible triangles or submitted primitives across all
render passes. Streak aspect and cone angle are visual approximations of fast
water. Actual flow still comes from the original connection, supply, pressure
and separate nozzle-lever owners. GPU particles remain the only continuing
spray animation; stable hose cloth/fluid CPU callbacks still stop.

Preparation allocates one emitter for each of the eight existing cabinets,
guarded against duplicate creation. It does not turn on emission or visibility.
The first takes16.835ms during startup; the remaining seven take0.144–0.178ms
each in the first final run. This trades bounded prepared resources and startup
work for avoiding creation during input. Exact allocated RAM/VRAM was not
isolated. Renderer state is checked with
[RenderingServer's inactive-particle query](https://docs.godotengine.org/en/4.7/classes/class_renderingserver.html#class-renderingserver-method-particles-is-inactive),
using each node's particle base RID. All eight checks pass in both final runs.

The fixed1280×720 Forward+ route uses VSync off on the same RTX4080 machine.
The first-spray phase includes actual acquisition/lever input and has few
samples; it is not measured display/input latency. NPCs and ordinary world
activity continue. Percentile analysis and raw rows remain in the packet.

| First-spray interval | Samples | Median / maximum, ms |
|---|---:|---:|
| Original before_v1 |4 |54.601 /65.310 |
| Rejected backlit final_v1 |3 |62.283 /132.023 |
| Rejected backlit repeat open_views_v1 |3 |54.992 /127.993 |
| Selected prepared_v1 |5 |43.339 /52.919 |
| Selected repeat prepared_v2 |4 |48.227 /59.223 |

The material changes and preparation timing are combined in the selected
version; the runs do not isolate the contribution of each change. The traced
81ms construction is directly observed in the rejected trial. Final logs show
creation before world readiness, with no creation call during first spray.

| Six-second sustained spray | Median / p95 / p99 / maximum, ms |
|---|---|
| Original |34.785 /37.999 /41.152 /64.134 |
| Selected run1 |32.842 /37.568 /39.450 /55.232 |
| Selected repeat |35.562 /40.019 /44.684 /66.132 |

The repeat's steady tails worsen. There is no reliable overall FPS or global
stutter improvement claim. The separate120-frame warmed floor controls give
median35.114/35.210ms for interleaved originals and32.555/35.585ms for final
runs; this variation likewise prevents attributing a steady speedup solely to
particle reduction. Rendering estimates are not exclusive CPU/GPU attribution.
Other first-render, shader, renderer-wait, loading and save costs remain open.

**prepared_v1** passes62 top-level checks,10 ordinary standing/stair waypoints,
five actual aim/inspection views, sustained supply/lever behavior, supported
release, remote inspection and real disk/world reconstruction. Saved physical
poses retain the existing10um tolerance and identical water/maintenance facts.
**prepared_v2** repeats58 checks, explicitly skipping only disk reconstruction.
Both have empty stderr. Their original repaired-line fixture is staged, so
this is not new assembly/procurement proof. The prior installed maintenance
review retains its separate actual union/washer/nozzle coverage.

**stock_v1** passes73 actual fixture checks with empty stderr: original hand,
charge, drain, cabinet clearance and release checks plus loaded map identity,
exact mip chains and optical shadow/GI settings. Its functional run overlaps
the static board; its timing fields are not used for performance comparison.
**hand_v1** is the earlier backlit-candidate fixture and is not the final look.

Packet: **art/reviews/v2_hose_spray_visibility_20261024/**. **before_v1** is the
unchanged original. **streaks_v1** is too dark; **styles_v1** compares shadow and
backlight treatments; **final_v1** and **open_views_v1**, despite the former's
name, are rejected backlit candidates. **fill_v1** retains the three scattering
levels and the cold allocation trace. A functional exit0 is not visual
acceptance of those rejected candidates. All source variants, images, original
logs and wrapper receipts remain; none is relabeled as runtime_contract proof.

Full board **gates/board.json** compares with exit0/no regressions:101 PASS,
8 FAIL,1 INCOMPLETE;98 tools suites/1194 tests and existing failures unchanged.
Spatial8 failing/39 advisory, reader1141 unread/33 NEW, systemic26, physical
imports wrong4 and surface qualifications stale2 remain. The four import
findings concern preserved untracked street/tent/traffic work. Ledger240,
blockers7/8/110/42/134/136, requirements_changed empty. The board starts after
the timed route freezes, alongside unmeasured reconstruction; no startup or
fixture speed claim uses that overlap. No audit baseline is relaxed. The focused post-staging reader/spatial board also reports no regressions; it does not rerun the other gates.

Worktree clean at end: no; original shared work remains. Protected17/17 and
selector V2 with explicit V1 rollback remain unchanged. Main observed at
**dcf60cf078b81ea7f51ed3e239a42d1274295aad**, merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. No clean candidate-verifier pass is
claimed. Changes outside the hose module are diagnostics, source/measurement
archives, byte-preservation rule and continuation documents.

Open: water impact/splash/wetting, full-distance payout, purchased washer
handoff/dressing, all-station maintenance, broader performance and the remaining
book/nook/device/bath/street/avatar scope. Spray review does not complete the
requested shower steam or side-correct glass condensation. Decision from owner:
none.

MERGE-CANDIDATE this verified hose checkpoint; the full V2 goal remains active
