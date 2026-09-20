# REPORT - RESIDENT-HOME-DOOR - 2026-09-19

Evidence class: **INERT**. Home-door implementation checkpoint, with no spatial-ledger promotion.

Branch / base HEAD / origin/main / merge-base: **codex/astra-reconcile-20260919** / **c697ccb** / **e8b83a3** / **acdb4be**. The containing commit records this phase. Tracked paths are committed together; historical untracked generated UIDs remain preserved.

## Behavior and evidence

Residents now request their home entry to open, hold an idle pose until DoorProp reports unlocked/open/settled, then walk through. All five existing home-door route stages use the same readiness check. Requests refused during a closing tween retry; locked doors remain refused. After passage, closing stays asynchronous and a refused request stays pending until the real owner accepts it. DoorProp retains its collider, lock, tween, sound and interaction authority.

The previous full-building **F06_DOOR_02** failure was reproduced at step 442 with open=true/moving=true and physical leaf contact. The identical unchanged **ResidentF06RouteTest** passes 19/19 after the repair, reaching the authored waiting point in 1464 steps. The production departure is identical before and after, and physical movement uses zero collider exclusions.

**ResidentDoorReadinessTest** passes 134/134. It drives actual DoorProp tweens and all five ResidentRoutines callers in two private worlds, including translated/rotated/opposite-swing geometry, masonry refusal, full departure and home return, closing behind, locks, refused close/open retries, idle/walk selection and private-world retirement.

Exact stdout/stderr, wrapper receipts, JSON diagnostics and LF-normalized source hashes: **art/renders/resident_home_door_20260919/**. These are suite/physics diagnostics, not runtime_contract receipts.

## Gate and continuation boundary

Protected 17/17 and selector v1 are untouched by this phase. Ledger before → after: not remeasured; no changed requirement status claimed. The two native suites exit 0 after the change; the retained baseline deliberately exits 1. Reader and design lint are checked before this checkpoint. Full completeness/spatial/systemic/period/tools/candidate verification and the wider movement regression batch remain pending after the general-door extension.

The isolated door fixture reports nine ObjectDB instances and three resources at process teardown despite both private-world retirement checks passing. The logs retain that finding; this report makes no clean-teardown claim.

Changes outside the expected boundary: one focused fixture, scene, evidence bundle and this INERT report. No navigation, F06 fixture, collider-exclusion, body-size, protected-floor or asset changes.

Open work: home-entry handling alone does not cover service/storage destination doors or other residents' apartment entries on a route. The user requested door behavior generally, so a path-based non-home coordinator and shared close-occupancy check are being prepared next. Existing abstract shop CROSSING/teleport behavior is not being replaced with fabricated walking paths. New fixture spatial review and fresh final candidate verification also remain pending. Decision needed from owner: none. No push or merge.

**BLOCKED — general route-door coverage and final V2 reconciliation remain in progress; the recorded home-door collision is fixed.**
