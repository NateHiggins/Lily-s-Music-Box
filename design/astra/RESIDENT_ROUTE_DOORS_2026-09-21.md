# REPORT - RESIDENT-ROUTE-DOORS - 2026-09-21

Evidence class: **INERT**. WIP checkpoint at the user's explicit commit-and-push request; no acceptance or ledger promotion.

Branch / base HEAD / origin/main / merge-base: **codex/astra-reconcile-20260919** / **1235ddf** / **e8b83a3** / **acdb4be**. The containing commit records this phase. Named work is committed together; historical untracked generated UIDs remain untouched.

## Implemented

The home-door checkpoint now extends to actual non-home route apertures. Residents request opening, wait for unlocked/open/settled readiness, and request closing after real crossing and full sweep clearance. Neighbours delay closing. Nine walking stages participate; hidden shop/lift transfers retain their existing semantics. DoorProp keeps collider, lock, sound and tween authority. Weak route references account for lifecycle and relocation. Opening clearance uses actual leaf collision boxes with bounded angular sampling. Bent routes request opening earlier; player yielding cannot bypass a home or general door hold.

## Verification and unresolved findings

Native focused checks: **ResidentDoorOpeningSafetyTest 44/44**, **ResidentRouteDoorsTest 110/110**, **ResidentDoorReadinessTest 134/134**. Completed wrapper receipts exit 0 with zero script errors. Initial route controls were **108/110** before relocation-cache correction. These are scoped diagnostics, not runtime_contract evidence.

Actual service passage is **not finished**. The original bounded real Juno/F03 utility route stalled before opening (**14/20**). The corrected coordinator opens and settles the door, but the 100-degree leaf still obstructs the unchanged angled approach: **14/20**, actual **F03_DOOR_01/HingedLeaf** collision at approximately **(-2.850626, 6.43, -7.638140)**. Every query retains all colliders. Do not waive this collision.

Next implementation: complete an owner-controlled NPC passage pose using the existing 168-degree parked opening, preserve the player's 100-degree interaction, allow widening a player-open leaf, and require the actual settled passage angle. Then replay the real service suffix before broad regressions. Two partial, unapplied agent drafts are preserved as text under **unapplied_parked_draft/**; the required DoorProp owner change is missing and the drafts are untested.

The service fixture's wait observation was corrected after the latest run to recognize a hold before alignment with the aperture. Physical collision and crossing checks are unchanged. This observation-only revision is not yet rerun; checkpoint hashes and tested hashes are recorded separately.

The untouched full Juno trip is separately **12/13**, refused by navigation at **F02:10:2**. Source/shipped-mesh analysis identifies her home spawn **(9.7428, 3.23, -3.2554)** overlapping **2C_benchstool**: hull **x 9.23–9.67, y 3.20–4.15, z -3.475–-3.005**, capsule radius **0.28 m**, centre only **0.0728 m** beyond the east face. Native initial-overlap attribution and a Body-clear home anchor are future placement work; preserve the furniture collider and failed full-trip test.

Exact logs, diagnostics, source hashes, source patches and receipts: **art/renders/resident_route_doors_20260921/**. Teardown/resource warnings and existing full-building findings remain recorded; no clean-teardown or all-resident/performance acceptance is claimed.

## Gates and handoff

Protected **17/17** match recorded origin/main blobs with no working diff; selector **v1**. Reader **NEW 0** and design/diff lint are checked before commit. Ledger before → after: not remeasured; requirements_changed **[]**. Wider movement regression batch and completeness/spatial/systemic/period/tools/fresh-candidate verification remain pending. No navigation, body dimensions, protected layouts, or Dream art changed.

Changes outside the runtime boundary: focused fixtures, corrected door-free negative control, diagnostic bundle, partial draft preservation and handoff. Decision needed from owner: none. This is a branch checkpoint for push, not a merge candidate; no merge into main.

**BLOCKED — actual service-route leaf clearance and broader V2 verification remain unfinished.**
