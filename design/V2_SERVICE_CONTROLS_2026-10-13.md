# V2 roof tank and dumbwaiter physical controls — 2026-10-13

Evidence class: **INERT**. Implementation and verification report; not a
room-acceptance checkpoint or a claim that V2 is complete.

## Changes

The installed roof tank exposes its stop wheel, float, captive lever weight
and indicator to click/grab, constrained mouse motion and click/release.
The stop wheel requires two clockwise turns to isolate the supply. Lifting
the isolated float drains it through the retained mechanism. The weight can
move before repair; the original force model rejects an ineffective setting.
An uninterrupted 1.8-second holding observation publishes the original
maintenance result. Completion does not reset the parts' physical positions.

The original wheel intersected the collector. A native dogleg and fitted
valve stem now place it 232 mm clear of the collector's side. Mesh owners,
the tank anchor, tower and collector collision remain with their original
authorities. Shaft rotation follows the actual wheel axis.

The dumbwaiter has two wooden rope grips, a split brake band, a threaded
tension wheel and a pivoted pawl working against a toothed drum. Pulling the
right rope fall down raises the car, lowers its counterweight and turns the
coupled mechanism. The pawl permits lifting and arrests descent; opening it
with a loose brake lets the car descend. A tightened brake resists rope pulls
and holds the car with the pawl clear. After 1.8 seconds unsupported by a hand,
that holding state publishes the retained brake-service result. Controls
remain operable after repair.

Both mechanisms use the existing household persistence authority. Roof
settings have seven validated fields; the dumbwaiter retains its five-field
mechanism state. Invalid or nonfinite values are rejected. Restoring a held
rope clears the transient hand support, so an unsupported car resumes descent.
V2 bypasses the old maintenance overlays; retained V1 APIs are not removed.

The household save listener now preserves live hand motion during unrelated
state notifications. It restores positions when the household payload changes
or RealityState replaces the save document, including an equal-valued reload.
Snapshot capture checks the same identity before writing, so a migrated load
cannot be overwritten before its announcement. RealityState remains the sole
save authority; no save format or protected authority file changes.

Space inspection uses the existing player inspection path. An optional
per-prop field of view fits the machinery and restores the original camera
lens on exit. The dumbwaiter inspection camera stays inside the narrow service
hall. A failed installed test had started beyond the hall wall; its corrected
standing position retains the wall and player collisions.

A later full-open native render caught the pawl crossing its solid deck and
bearing foot. The ongoing apartment run was deliberately stopped as an
unqualified diagnostic. A real clearance slot now passes through both stocks. The triangulated
native sweep tests 241 poses with zero deck/fixed-stock intersections. At
0.10 radians the nearest pawl edge is 97.516 mm from the drum axis, clearing
the 97 mm tooth envelope. The physical holding threshold now uses that
clearance, and releasing the rope seats the pawl instead of retaining a
raised ratchet-cam pose. The revised bench passes 36 input checks. Final whole-world surface
qualification now passes; the remaining gameplay/access renewal is described
below. Earlier receipts retain only their historical scope.

The shared native asset contains 700 closed construction stocks and 300
partitions across nine instruments. Final decoded primitive comparison against the parent finds eight changed
partitions and two additions, with 290 unchanged and none removed. New parts use the existing registered
materials and native UV workflow. No new material catalogue keys were needed.

## Evidence and limits

The final clearance asset previously passed 26,691 surface checks, 53
installed dumbwaiter checks, 52 installed roof checks and 115 gameplay
checks. The subsequent apartment run failed while closing 2B: an unrelated
RealityState commit made the household listener restore the last saved
position and cancel the hand. Per-frame diagnostics reproduced the failure.
These failed receipts are retained, not accepted as proof.

The household owner now distinguishes ordinary updates from replacement of
the authoritative save document. An unchanged household payload in the same
document leaves live manipulation alone; an actual replacement, including an
equal-valued document, still restores and cancels the hand. The focused
physical bench passes 99 checks, including both cases through actual click
input and a snapshot request before the load announcement. Snapshot capture
also detects document replacement and cannot overwrite the incoming save.
Its wrapper is **service_controls_20261013/shared_restore_final.log.receipt.json**.
An installed apartment assertion also commits during a held leaf operation.

The repaired installed apartment contract now passes 269 checks across 19
rooms with zero failures, including the deliberately injected unrelated
commit while closing 2B. Its strict spatial validator accepts the current
receipt and the canonical copy is renewed. Current wrapper:
**service_controls_20261013/apartments_stable.log.receipt.json**.

Final surface qualification also passes 26,691 checks with zero failures
across 24,476 draws, 16,516 meshes, 5,985 materials and 465 textures. The
canonical receipt, inventory and reviewed frontage/gallery images are renewed;
the independent surface qualifier reports zero defects. Current wrapper:
**service_controls_20261013/surfaces_stable.log.receipt.json**.

The current installed dumbwaiter contract passes 53 checks with zero failures,
including partial-position disk persistence and fresh-world reconstruction.
Its strict validator accepts the receipt and the canonical copy is renewed:
**service_controls_20261013/dumbwaiter_stable.log.receipt.json**.

The current installed roof contract passes 52 checks with zero failures,
including physical repair, partial-position disk save, fresh reconstruction
and measured teardown. Its strict validator accepts the renewed canonical
receipt: **service_controls_20261013/roof_stable.log.receipt.json**.

The current first-slice gameplay contract passes 115 checks, including
service-round disk persistence and fresh reconstruction. Its strict validator
accepts the renewed canonical receipt:
**service_controls_20261013/firstslice_stable.log.receipt.json**.

The final 60-room/nine-apartment route passes 782 checks with zero failures.
Its earlier run exposed an omitted transitive test binding. The declaration
was fixed, the actual route rerun, and its new test-authored receipt accepted
by the independent spatial validator. The canonical copy is renewed:
**service_controls_20261013/remaining_bound.log.receipt.json**. All completed
runtime receipts remain unmodified copies of their test-authored originals.

The new read-only **tools/preflight_spatial_test_bindings.py --all** checks
transitive test references before a long run. Its seven focused tests pass,
and all four spatial-contract declarations pass. The same missing helper was
also added to completion-access and roof-program declarations. Those two
contracts have not been rerun here and receive no new runtime acceptance.
The batch workflow and pipeline guide now require this preflight. Production
and surface inputs are unchanged by these declaration/tool edits.

## Management status

REPORT - V2-SERVICE-CONTROLS - 2026-10-13

Branch / HEAD at validation / origin/main / merge-base: main / b112e625 /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Publication target: **codex/v2-direct-manipulation-checkpoint**. No push or
integration into origin/main is authorized by this report.

Worktree clean at end: no. Inherited import, UID and review-artifact changes
remain outside the named checkpoint paths. Protected 17/17: yes, after LF
normalization, with raw comparisons disclosed in **protected.json**. Selector:
V2, explicit V1 rollback retained.

Ledger before -> after: **0 / 1 / 48 / 25 / 65 / 67** ->
**0 / 1 / 48 / 25 / 65 / 67**; requirements_changed: **[]**.
The comparison baseline is the previous physical-fuse checkpoint board,
not a clean merge-base checkout. This is not a fresh-checkout merge verdict.

The final full board reports **NO REGRESSIONS**. Completeness exits 2 because
V2 remains incomplete; spatial, systemic, period, reader, carriers, rulings,
surface qualification and both import gates exit 0. All 46 tools suites exit
0, including seven preflight tests. Reader NEW: 0. Exact commands, exits,
counts and comparison are in
**art/renders/orison_v2/service_controls_20261013/gate_board.json** and its
Markdown companion. Intermediate failed/expired boards remain historical.

Current Godot wrappers all report completed exit 0, with these PASS counts:

| Wrapper in the service-controls packet | Passed checks | Scope |
|---|---:|---|
| **shared_restore_final.log.receipt.json** | 99 | Actual manipulation, unrelated commit and replacement-document capture |
| **surfaces_stable.log.receipt.json** | 26691 | Composed custom PBR, UV, loaded mipmaps and reviewed renders |
| **dumbwaiter_stable.log.receipt.json** | 53 | Installed controls, disk save, reconstruction and teardown |
| **roof_stable.log.receipt.json** | 52 | Installed controls, disk save, reconstruction and teardown |
| **firstslice_stable.log.receipt.json** | 115 | Existing first-slice gameplay authority and save reconstruction |
| **apartments_stable.log.receipt.json** | 269 | Actual collision-bearing access and interaction in 19 rooms |
| **remaining_bound.log.receipt.json** | 782 | Actual collision-bearing access and interaction in 60 rooms |

Wrappers establish process outcomes; independent validators accepted the
corresponding test-authored runtime/spatial contracts before canonical renewal.
No wrapper or screenshot alone grants runtime acceptance.

Changes outside service geometry: household notification/capture handling;
its physical-input regression checks; optional inspection FOV; roof-route
standing positions; dependency declarations; reviewed spatial manifest entries;
and the dependency preflight plus workflow documentation. Each supports the
physical interaction change or prevents repeated invalid evidence runs.

Open findings not fixed: seven pre-existing Texture RID shutdown warnings;
remaining V2 geometry, gameplay, direct-manipulation and V1 retirement work;
human aesthetic acceptance. Completion-access and roof-program declaration
fixes have source preflight only, with no new runtime acceptance here.
Decision needed from owner: none for continued implementation.

BLOCKED full V2 integration: remaining build obligations and human acceptance;
this reviewed checkpoint has no new regressions against the stated baseline.
