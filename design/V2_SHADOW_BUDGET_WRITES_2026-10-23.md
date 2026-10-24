# Redundant shadow-budget writes — 2026-10-23

Evidence class: **INERT**. Component, render and actual-input diagnostics, not
runtime qualification, human acceptance or V2 completion.

REPORT - redundant shadow-budget writes - 2026-10-23

Canonical checkout **C:/PleaseRemainOnTheLine**, branch
**codex/v2-acoustic-topology**, parent **99e93e64**. Previous goal turn made
progress: unchanged fire-service grip notification was repaired and pushed.
Shared bathroom-optics manifest work and unrelated street/art files are preserved.

| Location / reproduction | Severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Ceiling, task and general fixture budget callbacks | Repeated renderer invalidation | Every budget tick assigns shadow_enabled even when the boolean is unchanged | Four equality guards in the existing three fixture classes | Actual budget-method render control and26 state checks before/after |
| Moving objects/lights with cached shadows | Visual correctness risk | Cache reuse must not freeze genuine shadow changes | Keep all actual flag transitions and engine geometry/light invalidations |29-check motion control, including actual budget off/on |
| Far-shadow culling candidate | Unqualified tradeoff | Fixed-view original phases drift and some controls visibly remove shadows | No permanent culling or shadow-budget change in this checkpoint | Original controls and screenshots retained |
| Remaining large route spikes | Input cost | Consecutive synchronous saves remain about105ms inside one stress interval | Retain save authority and record the limitation | Same actual route, normal automatic writes and disk reconstruction |

LightRig requests the same budget state repeatedly. The installed engine revision
increments the light version and notifies renderer dependencies on every shadow
setter call, even for an equal boolean. See the exact engine source:
[Godot a13da4feb LightStorage::light_set_shadow](https://github.com/godotengine/godot/blob/a13da4feb/servers/rendering/renderer_rd/storage_rd/light_storage.cpp#L238).
The inference that unnecessary assignments force work is independently exercised
in the renderer control; the source alone is not performance proof.

The repair adds equality guards around the primary shadow flag in CeilingLightProp,
LampProp and LightFixtureProp, plus the latter's entry spotlight. Budget selection,
power, local switch, color, energy, visibility, shadows requested, mirror selection,
service reachability and volumetric lighting retain their owners and values.
No new policy, tuning field, geometry, material or save schema is introduced.
The shared fixture code also serves V1; its requested boolean/visibility behavior
is unchanged, including actual false/true transitions and power refusal.

**setter_v1** is a static400-box exact-engine control. Stable and guarded phases
have zero shadow draws median; explicitly reassigning the true flag gives four
shadow draws median, while the boolean remains true throughout. The later control
calls the actual CeilingLightProp budget method. **budget_before_v1** gives four
draws median in that phase; **budget_after_v1** gives zero. Both pass26 checks
across all three fixture classes and the entry spot, including repeated states,
real transitions and powered/local-switch refusal. Both have empty stderr.

**motion_after_v1** passes29 checks with empty stderr. Geometry movement, light
movement and actual budget off/on each produce shadow draw samples
6/6/0/0/0/0/0/0: genuine changes refresh the map and then return to cached reuse.
This extra run overlaps static tooling, so its timing values are not used for a
performance comparison; only render counts and correctness checks are used.

The initial **probe_v1** walks five actual waypoints, opens the installed cabinet
through primary grab/motion/release, then fixes the camera. Both rendering policy
callbacks are paused identically in all phases; fixture animation/power still run.
Original/far-gap4/restored medians are33.742/31.389/34.106ms; far-gap8 gives34.033ms.
Removing all service shadows gives20.523ms; removing other point shadows18.697ms;
directional shadows off gives23.927ms. Later original phases fall to27.961ms, so
ambient activity/cache/atlas drift limits broader attribution. No permanent culling
is installed from these figures. Disabled states are diagnostics, not accepted
appearance. All13 checks pass, five walked waypoints, empty stderr. The gap is
camera-to-light-center distance minus authored light range, nearest live main or
mirror eye. It is not an occlusion or visibility proof.

The installed comparison reuses the preceding source-bound
**v2_commit_causes_20261023/world_after_v1** baseline. It runs the same ten-waypoint
actual hose approach, turn, grab, inspection, placement, charge and spray route,
1280x720 Forward+, VSync disabled, automatic persistence on an owned disposable
path. **v2_far_shadows_20261023/world_after_v1** passes49 checks and disk/world
reconstruction with empty stderr; both owned primary/backup cleanup results are0.
All13 changed household commits remain. No save coalescing or physics change occurs.

| Post-render interval | Before | Guarded |
|---|---:|---:|
| Samples |725|793|
| p50 |39.632ms|34.965ms|
| p95 |54.532ms|48.768ms|
| p99 |101.933ms|94.323ms|
| Maximum |167.854ms|166.297ms|
| Above100ms |8|5|

Root render CPU median22.155→20.414ms, GPU13.316→12.240ms. Render setup CPU median
1.549→.511ms, p95 5.838→2.124ms. Shadow draw median33315→29871; visible draw
median remains306. End-of-route inventory remains663 lights,159 visible and40
visible with shadows enabled. These counters lag rendering and CPU/GPU work
overlaps; do not add them as exclusive parts of a frame. The component control
establishes cache behavior more strongly than a single whole-route pair, whose
frame count and ambient activity differ. The observed median improvement is
about11.8%; it is not proof that every tail difference comes from this edit.

The largest guarded stress interval still has104.924ms household work across two
separate input actions. Save-related spikes remain. Passage residency stays
DORMANT, so cell streaming remains unmeasured. Borrowed-nozzle before/after views
retain the apparatus and warm lighting; unfrozen light/shadow patterns vary, and
no pixel equivalence or broad appearance acceptance is claimed.

Two executed fixture references are selectively registered: the actual F02 target
and the isolated render-control camera. Two pre-existing bathroom records remain
62 unstaged lines. Original early advisory counts, uninstalled culling controls,
source archives, captures and wrapper receipts remain in
**art/reviews/v2_far_shadows_20261023/**.

Branch / HEAD / origin/main / merge-base: **codex/v2-acoustic-topology** /
**99e93e64** / **ad5b3899** / **21f0b1fc**, origin refreshed. Protected17/17: working
content matches the frozen authorities with the authorized selector-only V2
default cutover and explicit V1 rollback. **protected.json** records the working
LF-normalized check, not clean-candidate qualification.

Full board and final reader/spatial/systemic recheck have no regressions against
the preceding shared-tree board:101 PASS,8 FAIL,1 INCOMPLETE;98 tools suites run
1194 tests with five existing failures across four suites. Existing physical
source wrong4, surface stale2, spatial8 failing/39 advisory, systemic26 review and
reader1141 unread/33 NEW findings are unchanged. Ledger240 requirements and
blocker counts7/8/110/42/134/136 are unchanged, requirements_changed empty.
**gates_final.json** explicitly combines the full outputs with the focused recheck
after adding diagnostic motion assertions; original boards are retained. Production
scripts remain unchanged throughout the full board and final world route.

Worktree clean at end: no. Only two executed fixture records (65 added lines) are
staged in the manifest; two shared bathroom records remain62 unstaged lines.
Unrelated untracked street/art/UID work is untouched. No worktree was created or closed, and no other contributor
Godot process was stopped. Production edits are limited to the three existing
fixture classes; test/report paths support the measured repair. No art, light
budget/mask, interaction, NPC/inventory/case owner or save transaction changes.
A clean merge-base board is unavailable for in-place candidate verification;
no candidate-verifier pass is claimed. **source_checks.json** verifies six
executed top-level test hashes; dependency sources and the later motion variant
are archived separately. Wrapper suite_run receipts and INERT test outputs grant
no schema-2 runtime_contract, surface/space promotion or human acceptance.

Decision needed from owner: none.

BLOCKED remaining stutter, broad interaction/surface/runtime/human coverage and actual cell transitions remain open
