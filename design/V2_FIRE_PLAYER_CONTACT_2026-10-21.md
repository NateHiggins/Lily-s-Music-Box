# Native fire-door player contact — 2026-10-21

Evidence class: **INERT**. Scoped diagnosis and repair record. No runtime-contract,
human acceptance or V2 completion grant.

The cabinet's detailed glass, coatings and safety wire make the player capsule's
slide queries expensive. V2 now gives the player a separate contact body made
from the same cached hull resources already used by the door's authoritative
constraint. Original native colliders remain on world layer 1 for mechanisms,
carried objects and NPCs. The player keeps world layer 1 and adds a supplementary
query layer; only its eight original fire-door body pairs are substituted.

| Location / reproduction | Severity / evidence | Repair / verification |
|---|---|---|
| Fire cabinets on the played stair ascent, turn and descent | High: long slide calls contribute to repeated physics catch-up and 200 ms frame spikes. | Reuse 72 existing door constraint hulls for player-only contact. No visual geometry, material, maintenance fact, inventory, NPC, case or save owner changes. |
| First query-body experiment | Diagnostic failure: assuming every original shell was closed fails during preparation. | Preserve the failed source and receipt. Open shells are retained in the intermediate component experiment. |
| First alternate-mask route | Diagnostic failure after 18 waypoints: the replacement mask omitted original world layer 1 and violates the route invariant. | Reject that mask strategy. The shipped design keeps layer 1. The updated route guard permits supplementary layers while still rejecting the failed mask, which lacks bit 1. |
| Intermediate closed-component hulls | Mixed performance: movement p95 66.202 / 69.564 / 65.564 ms for original / candidate / restored, despite some tail improvement. | Not installed. Source, casts, frames and original failure history remain. |
| Existing constraint-hull experiment | Strong paired improvement on the same 51-waypoint route; all three inspection programmes pass. | Proceed to shipping-source verification. 864 real standing-capsule casts across eight doors retain sampled contacts, with zero measured cast difference under the declared 0.5 mm bound. This is not an absolute 1 µm native-boundary claim. |
| First shipping comparison, then repeated-turn bench | High: after ordinary looking, scale reads 0.999970 instead of one. The strict unit-frame guard restores original contact, invalidating the requested performance mode. | Original **shipping/profile.log** and **look_stress_v1.log** retain the failed runs. The original hand programme itself still passes. No failed mode is treated as measured optimization. |
| Second shipping comparison after yaw-expression repair | High: walking also accumulates frame decomposition error; scale reaches 0.999837 by the final restore. All 51 waypoints and three inspection programmes pass, but two mode assertions fail. | Original **shipping/profile_v2.log** and executed sources remain. Stabilize only the V2 player's near-unit rigid frame each physics tick, then repeat the comparison. Deliberately scaled or tilted frames retain fallback protection. |
| First fully functional shipping comparison | Mixed: **shipping/profile_v3** passes 51 waypoints and every mode assertion, but candidate movement p95 rises to 172.071 ms and maximum reaches 1,728.346 ms. | Keep the entire original run. Do not publish prototype gains as shipping gains. Avoid a redundant transform write every physics tick and add per-tick collision-state tracing before repeating. |

The production helper follows each moving door's actual part frame. It neither
rescans targets nor supplies a new manipulation state. A ray hitting its query
body resolves through the original hand provider to the same door part and
constraint. Mechanical sweep queries still detect the actual player: their
world-layer shape queries do not use the player's movement-pair exclusions.
Ordinary crouching stays supported. A changed capsule radius, tilted/scaled
body or debug noclip safely restores the original contact policy. Teardown
removes only this helper's proxies, supplementary layer and owned exceptions.
V1 players have no helper and retain their original collision policy.

The ordinary mouse and stick look paths update yaw directly instead of repeatedly
multiplying the basis. CharacterBody walking also round-trips that basis through
physics, so the V2 opt-in controller orthonormalizes a near-unit frame at the
start of each physics tick. Its numerical guard is **0.0001** per scale component;
this prevents accumulated roundoff, rather than widening the contact helper's
unchanged supported-capsule predicate. Tilt remains tilt; the focused negative
control's real one-percent scale remains unsupported.
The final version writes a corrected frame only after error exceeds **0.000001**,
with the same **0.0001** upper guard. An already sound frame causes no transform
write. This reduces needless physics updates; the ordered runs do not isolate
that change from all engine/background variation.

## Paired playable measurements

The prototype's 1280×720 uncapped, VSync-off A/B/A uses the shipping controller
with lower-cap step eligibility enabled throughout. It repeats the same 51
walked waypoints, turns and three actual cabinet inspection/grab/motion/release
programmes. Images and setup/restore probes are excluded from measured windows.

| Movement frames | Original A | Constraint hulls B | Restored A |
|---|---:|---:|---:|
| Samples | 807 | 918 | 754 |
| p50 ms | 46.484 | 42.265 | 48.910 |
| p95 ms | 64.657 | 63.434 | 75.926 |
| p99 ms | 210.925 | 69.949 | 201.597 |
| Maximum ms | 228.905 | 88.751 | 239.385 |
| Frames over 100 ms | 27 | 0 | 29 |
| Maximum slide call ms | 27.728 | 9.819 | 28.055 |

The source is under **player_door_hull_diagnostic/attempt_v4_sources**, with
original **world_v4.log.receipt.json**, raw frame/tick samples and analysis.
This is a clean 51-waypoint diagnostic, not a schema-2 runtime qualification.
Repeated engine monitors are rolling and render-time getters can be delayed;
these numbers do not claim exact same-frame GPU attribution or hardware
input-to-photon latency. Unmeasured areas and other frame spikes remain open.

## Final shipping comparison

The same settings and 51-waypoint programme on the shipping helper and final
drift correction complete in **293.84 seconds**, with **zero route failures,
zero script errors**, all three actual inspection sequences, original-player
obstruction checks and mode-switch assertions passing. Original data and the
wrapper receipt are **shipping/profile_v4** and **shipping/profile_v4.log.receipt.json**.

| Movement frames | Original A | Shipping hulls B | Restored A |
|---|---:|---:|---:|
| Samples | 802 | 843 | 765 |
| p50 ms | 46.340 | 44.556 | 47.395 |
| p95 ms | 63.788 | 90.381 | 70.227 |
| p99 ms | 213.844 | 132.966 | 215.167 |
| Maximum ms | 224.012 | 138.980 | 241.511 |
| Frames over 100 ms | 27 | 36 | 26 |
| Recorded maximum slide call ms | 28.116 | 15.333 | 27.693 |

This is a measured tradeoff: the large tail spikes fall by roughly 38 percent
at p99, while **p95 and the count over 100 ms regress**. It is not universally
smoother, and further frame-pacing work remains open. Inspection p95 is
**99.947 / 82.036 / 98.978 ms** and p99 is **112.744 / 89.578 / 106.754 ms**;
inspection maxima remain **170.576 / 164.005 / 168.454 ms**. Stage-cost records
contain player ticks exceeding one millisecond, so their medians are not
unconditional physics-tick medians. The raw frame distributions include every
measured frame, including the earlier bad run's 1.7-second spike.

The added trace reports no unsupported player, call lock or missing world-layer
bit during measured movement. Seven tiny idle ticks at cycle switches inherit
the prior phase label while the mode has already changed; their original
0.070–0.127 ms records remain included. These are explicitly recorded in
**mode_trace_summary.json**, not silently removed from the data.

## Shipping checks and checkpoint

The focused shipping bench passes all original actual-input hand checks plus
the contact-policy checks: all eight stations and 72 shared shapes/frames,
crouching, smaller/tilted capsule fallback, noclip policy, direct mechanical
detection of the player, complete teardown and fresh installation. Its original
wrapper receipt records **46.16 seconds, exit 0, zero script errors**. The fixture
state changes test collision policy; the existing click/mouse/release and free
inspection cursor programme independently exercises input.

After the yaw-expression repair, **look_stress_v2.log.receipt.json** records
**45.84 seconds, exit 0, zero script errors**. Both 1,000 mouse events and 1,000
stick-rate updates retain a unit supported frame. The actual one-percent scaled
player, smaller capsule, tilted capsule and noclip negative controls retain their
original fallback. The later walking-frame repair requires the final played
comparison and focused repeat below; this earlier pass is not substituted for it.

The intermediate, always-normalizing shipping version also passes the continuous
**94-waypoint** arrival, furnishings, cell-transition and physical repair route:
**285 seconds, zero failures, zero script errors** in **golden_v3.log.receipt.json**.
Its 3,597 frames have p50/p95/p99/maximum **32.077/61.525/119.390/151.060 ms**,
46 frames above 100 ms and none above 250 ms. This is an ordered separate run,
not a causal A/B measurement. The final hysteresis change is covered by the
51-waypoint comparison; this earlier broader run is retained at its actual source.
The same intermediate version passes all **54** shared reticle checks in
**reticle_v3.log.receipt.json**, **11.61 seconds**, and the full focused actual-hand
programme in **hand_v3.log.receipt.json**, **46.96 seconds**, both with zero script
errors. The final focused repeat at the hysteresis source also passes the
entire actual-hand programme and all collision, drift and fallback checks:
**art/reviews/v2_deployable_hose_20261021/contact_final.log.receipt.json**,
**45.35 seconds, exit 0, zero script errors**.

REPORT - V2-FIRE-PLAYER-CONTACT - 2026-10-21

Branch / pre-write HEAD / origin/main / merge-base:
**codex/v2-acoustic-topology** / **5cee5926** / **21f0b1fc** / **21f0b1fc**.
Worktree clean at end: **no**; shared untracked work and separate uninstalled
full-length hose development remain. Stage named owned paths only.

The 17 protected working contents match **origin/main** after LF normalization;
the unchanged selector defaults to V2 and retains explicit V1 rollback. The
reader gate reports **zero NEW unread fields**, historical unread count **1,109**.
The original complete working board at **board_initial** has **107 PASS / 2 FAIL /
1 INCOMPLETE**, with 97 of 98 tool suites passing. The failures are expired surface
qualification/rendered review and two live completeness assertions that depend
on current qualifications. Ledger blockers remain **7/42/110/8/134/136** in
technical/runtime/structural/shift/cutover/retirement order.

The historical comparison board at **1e8b332f** was dirty. It remains preserved,
but cannot serve as the required clean merge-base baseline. A temporary detached
checkout of **21f0b1fc** was verified clean, ran all 110 gates and tool suites,
and was removed after the result was copied outside it. Its complete clean board
at **clean_main_baseline/board.json** records **109 PASS / 1 INCOMPLETE**; main's
ledger blockers are **0/26/56/1/73/75** in the same order. The clean-main comparison
finds **77 initial regression entries**, including two diagnostic spatial entries
subsequently resolved. The targeted **registered_static** board reports spatial
drift zero and reader NEW zero; it is not substituted for a complete board. The
empty-selector attempt at **empty_selection_not_validation** ran no gates and
is explicitly **not validation**, regardless of its zero exit code.

Original source snapshots, failed runs and complete boards remain unchanged.
Owned current hash-bound text was normalized to LF after the runs, with no code
change; the archived executed bytes retain their original endings. The source
still needs renewed schema-2 qualifications and a final candidate comparison.
No source hash is repinned, no old runtime receipt is rewritten, and this
development checkpoint is **not** a green integration candidate.

The full-length hose, controllable water spray, further V2 repair/build coverage,
remaining spikes, full shift and human acceptance remain **OPEN**. The separate
native hose study is not installed by this player-contact repair. Decision
needed from owner: **none**.
