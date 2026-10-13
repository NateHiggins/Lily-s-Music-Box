# V2 apartment circulation repairs — 2026-10-13

Evidence class: **INERT**. Implementation and diagnostic report; this document grants no spatial, runtime or human acceptance.

## Changes

The 5B deck table previously ran north–south. Its top left only about 450 mm
between the dining table and its south end, and about 440 mm between its north
end and the wall. Neither gap admitted the standing player's 660 mm diameter.
The recorder and its supporting table now rotate together by 90 degrees. This
opens the route between the living area and private hall while preserving their
relative transform, height, identity and existing materials. No room, opening,
door, interaction or case-authority record changes.

The remaining-apartment walkthrough planner now samples the actual supporting
floor height within the player's existing low-step range. It therefore plans
across the low apartment thresholds without pretending those solids are absent.
A central ray can miss exactly on a floor-triangle join; four fallback rays,
10 mm from the centre and still inside the standing footprint, handle that seam.
Collision sampling waits two physics frames after a gesture. Every executed
waypoint still uses normal player movement, standing collision and the existing
arrival tolerances. These are test-planner corrections, not player bypasses.

## Focused review

Blender before/proposed renders reviewed the existing native table, recorder,
chairs and surrounding furniture before the anchor edit. The rendered Godot
5B view confirms the recorder remains seated and the private-hall approach is
open. Focused ordinary-controller routes through 4A, 5B and 5C reached every
room and returned through their entries, with real grab/motion/release gestures.
The relevant source, diagnostic summary and wrappers are preserved under
**art/renders/orison_v2/remaining_apartments_20261013/**. These focused diagnostics
are INERT, not schema-2 acceptance contracts.

The earlier nine-unit attempt reached 50 of 60 rooms and reported 16 failed
checks. It exposed the 4A bedroom planner seam, 5B furniture obstruction and a
5C bathroom-door gesture failure. That failed contract remains in **diagnostic/**.
The 5C gesture passed focused replay; this does not establish why its earlier
attempt failed. The previously recorded intermittent 2B close also remains an
open observation. Seven Texture RID shutdown warnings remain.

## Final verification

The source-bound nine-unit contract passes: 60 rooms, 782 executed checks
(781 recorded plus the final output-flush check), zero failures. The dedicated
SPATIAL_ACCESS checkpoint admits 54 requirement improvements; no human
acceptance is granted. All nine driver/root references retire.

The whole-world surface run passes 26,656 checks with zero failures: 24,464
draws, 16,514 meshes, 5,990 materials and 465 loaded textures. The canonical
surface receipt and rendered review are renewed. The only changed production
fields are the two 5B yaws, as checked in **placement-comparison.json**. Fresh
frontage and 5B views were reviewed; unchanged tower, washer, fire-repair and
front-gallery views are retained with this explicit scope.

The live-clock first-slice contract passes 113 checks, including actual disk
save/reconstruction. The existing apartment contract finally passes 19 rooms
and 268 executed checks. Its first attempt reproduced the 2B closing failure.
Twenty-four isolated gestures at three stances, then a full instrumented 2A/2B
route, passed; the full replay detected no native pointer events while grabbed.
These observations do not identify or fix the intermittent cause. Read-only
failure telemetry now records the leaf angle, desired-stop blockers, last-hand
contact sightline and controller state. It does not retry, move the player,
force the mechanism or relax an assertion. The failed and successful diagnostic
runs remain in **diagnostic/**; only the final schema-2 contract renews proof.

## Management report

REPORT - V2-APARTMENT-CLEARANCE - 2026-10-13

Branch / validation HEAD / origin/main / merge-base: main / 26681527 /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Publication targets **codex/v2-direct-manipulation-checkpoint** only.

Worktree clean at end: no. Inherited capture/receipt/import and line-ending
changes remain outside this checkpoint; see **inherited_worktree_paths.json**
in the packet. Named owned paths only are staged. Protected 17/17: yes.
Selector: V2, with the explicit V1 rollback unchanged.

Ledger before -> after (first slice / golden shift / structural / runtime /
cutover / retirement): **0 / 1 / 102 / 34 / 119 / 121** ->
**0 / 1 / 48 / 25 / 65 / 67**. The changed requirements are recorded in the
packet's gate-board comparison. Full-building readiness remains INCOMPLETE.

The final 55-row gate board has zero regressions against
**art/renders/orison_v2/front_restoration_20261013/gate_board.json**. All 45 tools
tests pass, including 108 completeness tests and eight spatial-evidence tests.
Completeness exits 2 (INCOMPLETE); the other nine static gates exit 0. Reader
NEW and spatial new-reference drift are both zero. The initial full board and
subsequent refresh boards are retained; unchanged tools-test rows are reused,
not represented as a second execution.
Godot evidence is in **remaining.log.receipt.json**, **surfaces.log.receipt.json**,
**apartments.log.receipt.json** and **firstslice.log.receipt.json** within the
packet. Each is a completed wrapper for its separate test-authored contract;
no wrapper or caption is promoted into runtime proof.

Changes outside the expected room-layout boundary: the collision-aware route
planner; failure-only apartment gesture telemetry; renewed bound receipts and
review; documentation and byte-preservation rules. The historical capture-only
completeness-test fixture excludes the new played-room checkpoint, just as it
already excludes the earlier played-apartment proof. Its assertions and all
production acceptance thresholds are unchanged.

Open findings: intermittent 2B close; the earlier 5C gesture failure is retained
without a claim that its cause is eliminated; seven Texture RID shutdown
warnings; remaining V2 work and human acceptance. No clean temporary-worktree
candidate verification or integration into origin/main is claimed.

Decision needed from owner: none for this scoped checkpoint.

BLOCKED full-building completion: remaining structural/runtime work and human acceptance.
