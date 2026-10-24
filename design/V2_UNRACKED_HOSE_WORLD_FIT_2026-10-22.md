# Unracked hose world fit and receiving-stock repair — 2026-10-22

Evidence class: **INERT**. Candidate diagnostics and continuation only.
No production installation, save/rebuild, released-hose or spray acceptance.

The separate 135-ring hose now has a compact floor layout that clears all
eight installed cabinet locations. The full 15.24 m material and 17,280 native
triangles remain. The stored folds have no hose simulation. The candidate is
still mounted only by diagnostics; the production installer is unchanged.

| Location / reproduction | Severity / evidence | Repair / verification |
| --- | --- | --- |
| Long initial extension beside stairs | High: all eight first proposals hit architecture or the walked player. Rotating the long loop also fails at F02. | A compact 2.288-turn off-rack floor layout preserves every material interval. Its minimum nonadjacent envelope separation is 67.622 mm, with no physical bend-bound violations. **world_coil_v4** records clear proposals at all eight stations with player collision retained. |
| F02 landing edge | High: the first compact layout reaches the next flight's first nosing. | Shift the floor-layout centre 150 mm toward the cabinet and walk to the clear operating stance. The stair, player and case collisions remain active. All eight corrected proposals clear. |
| Removal at the walked F02 cabinet | Required actual input, not a fact toggle. | Primary click grabs the nozzle, 25 mouse motions pull it 200 mm, the stored folds disappear, and the next click releases. CPU input p50/p95/p99/max is 0.668/1.000/11.757/15.152 ms; the last call performs the swap. These are handler timings, not displayed latency or world frame-time gains. |
| Moving receiving stock | High: the previous guard swept the barrel but omitted the travelling hose seat and nut. | Cache native annular sectors before input, preserve their bores, and sweep their complete translation/rotation along with the barrel. The isolated obstruction test and full-length input pass. No new target scan or independent reticle state is added. |
| Default detached nozzle | Required: the bare hose must be selectable without inventing a connection. | A static seat collider exposes the same owner grip when the nozzle is loose. **bare_end_v5** grabs the seat, moves the separate nozzle out through actual grab/mouse/depth input when obstructed, then removes and releases the hose. The loose nozzle remains an external cloth and fitting obstacle. |
| Existing nozzle-carry regression | An old horizontal waypoint at the exact bearing height fights physical recovery by about 106 micrometres, beyond its 100-micrometre target tolerance. | Both current and previous-checkpoint sources reproduce the failure. Add a real 1 mm lifting waypoint before withdrawal; preserve the original final goal, tolerance and every collision check. The combined nozzle, fold and hand programme passes in **nozzle_control_lift_v1**. |
| Receiving-cache initialization | Diagnostic defect: a nonindexed transient mesh produces Nil where the native sector helper expects indices. | Add explicit native triangle indices. **world_coil_v3** retains the original errors and false configured rows; its wrapper's zero exit is not a successful layout check. |
| Actual unracked carrying beside F02 | High and still open: **world_coil_v5** spends 44.910–74.076 ms per motion, then two of eight small motions stall on incompatible follower support planes. | The complete-world programme now exposes the problem with setup excluded and one event per rendered frame. Profile solver, native world/self contacts and fitting guards before choosing the next repair. The isolated guide timing does not qualify this floor layout's carrying performance. |

With the added receiving-stock guard, the isolated 272-event full-length pull
has CPU accepted-pose p50/p95/p99/max **4.934/5.286/5.439/5.663 ms**, zero
pending events, and 15.098208 m endpoint span. The original 15.09 m threshold
and full 15.24 m material are unchanged. This costs slightly more than the
barrel-only guard and protects additional physical stock. It is not a measured
played-world optimization.

The first world input phase incorrectly includes preceding setup and delivers
several motions per rendered frame. Its seven frame samples must not be used
to attribute a 428.830 ms spike to the interaction. The corrected programme
waits for setup/acquisition frames, delivers one motion per rendered frame,
captures swap/release frames, and separately exercises small unracked carrying
motions. After excluding each phase's first partial timer interval and retaining
three post-release presentation frames, removal has frame p50/max
**42.693/85.296 ms** over 27 samples. Carrying has **162.201/187.307 ms** over
10 samples. Eight carry input calls have CPU p50/max **45.608/74.076 ms**;
two stall. These short samples identify an unresolved problem, not a matched
before/after optimization or adequate tail qualification. The diagnostic's
immediate feedback field is sampled before the next physics publication;
verify authoritative blocked feedback at presentation as part of the repair.

Native review of the corrected initial world poses groups eight records into
two exact bind/current-frame identities. Both native solids have zero crossing
triangle pairs and nonmanifold edges, positive volume and a working crossing
control. The six aliases reuse only identical native pose review. The full
neutral overview and actual F02 swap image were inspected. Coarse bends near
the retained case lead remain a visual limitation of the candidate.

## Continuation report

Branch **codex/v2-acoustic-topology**, canonical shared checkout. Previous
pushed checkpoint **8bb0b745**; origin main and merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Named paths only; no worktree.

The production cabinet's mechanical, inventory, NPC, case and household save
owners remain unchanged. The new static seat callback returns no target when
no hose provider is installed. A/B control restores the current source
byte-for-byte after the previous-source run. Original failures are retained;
the one-shot native and wrapper receipts are diagnostics, not runtime contracts.

The complete world-fit board remains 107 PASS, two FAIL and one INCOMPLETE:
the existing surface/completeness qualification debt remains. Reader audit
has zero new unread fields. All seventeen protected paths match main after
LF normalization, with selector V2 and explicit V1 rollback intact. Four
incidental test spatial records are reported; none is a new failing binding.
The clean-main comparison has 79 regressions, including preceding branch debt
and these report-only records. This is not a management merge candidate.

Original logs, test-written wrappers, failed fixtures, posed native solids and
source snapshots are retained in **art/reviews/v2_unracked_hose_world_20261022**.
Its manifest maps byte-exact gzip copies to their original paths and hashes.

Remaining installation requirements: real-world carrying performance and
geometry, released behavior, protection against other bodies entering the
cloth after acceptance, transported fitting/cloth self-contact, coupling-aware
save/rebuild, free-cursor inspection away from the cabinet, a usable supply
valve and controllable nozzle spray. The valve is still locked to transient
play and no water effect is implemented. Broader V2 inspection and human
acceptance remain open. Do not install this as a complete hose feature.

Decision needed from owner: none. Continue the authorized full-length usable
hose, preserve obstructions, and keep the stored representation static.
