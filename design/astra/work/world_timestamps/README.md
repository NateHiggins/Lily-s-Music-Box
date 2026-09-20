Current status: root applied the five production owners and the final fixtures. Preserved original source failed 51/76; candidate, restored and final fixtures passed 76/76. Wrapped-time and late-sampling omissions produced intended reds and restored exact bytes. Initial job/register regressions remain preserved; reviewed fixture revisions then passed (jobs PASS, register 153/153). See `design/astra/evidence/world_timestamps/validation.json` and `design/astra/reviews/world_timestamp_review.md` for exact receipts, source scope and retained warning. No new engine runs are requested by this status note. The historical preparation text below remains as provenance, including its earlier not-applied statements.

---

# World timestamp provenance proposal

Prepared outside live `game/` at source HEAD
`e72320288d256e4d20386e8f28c116fe962788fc`. This is an inspectable seven-file
proposal, not an applied or runtime-validated repair. `preparation_receipt.json`
records exact original/candidate hashes. No game files, host metadata/entropy
exemptions, audit tools, baselines or canon were edited by this preparation.

The current authority is `design/ORISON_CAMPAIGN_CALENDAR_RULING_2026-09-05.md`:
authored November 10, 1928; hour/minute sampled once at creation; accumulated
simulation minutes afterward. Wrapped minute of day cannot measure multi-day
elapsed time. `CampaignClock` validates protected state before binding;
`RealityState` preserves compatible additive fields and known envelopes. Neither
owner is changed by this proposal.

## Proposed production paths

| Path | Change |
| --- | --- |
| `game/scripts/game/maintenance_inventory.gd` | Qualified campaign minutes for new acquisition/consumption |
| `game/scripts/game/work_orders.gd` | Qualified issue/close/adoption minutes; retain original source on migration/retirement |
| `game/scripts/reality/organism_incidents.gd` | Qualified campaign minutes for a newly reported incident |
| `game/scripts/props/night_register_prop.gd` | Qualified campaign minutes for a newly signed line |
| `game/scripts/game/chirp_hunt.gd` | Pass the existing stable legacy order/job IDs through adoption and retirement |

The other two proposed files are `game/tests/world_timestamp_test.gd` and
`game/tests/WorldTimestampTest.tscn`. `world_timestamps.patch` contains only these
seven paths. `originals/` remains immutable. `prepare.py` is the historical first
preparation; do not rerun it over the later mid-report refinement. The current
patch and preparation receipt bind the reviewed final proposal and controls.
No package preparation writes live game files or launches Godot.

## Units, legacy values and migration

New fields retain their existing names and get per-field basis metadata:
`acquired_at_basis`, `consumed_at_basis`, `issued_at_basis`, `closed_at_basis`,
`reported_at_basis`, and register `at_basis`, all `campaign_elapsed_minutes`.
Values come from the existing CampaignClock's accumulated elapsed minutes. Each
owner holds one reusable clock handle; it must bind successfully before the
timestamped action mutates its facts. A refused/invalid clock cannot fall back to
elapsed zero or a new host read.

Unqualified old timestamps are kept unchanged; no bulk migration labels host Unix
seconds as campaign minutes. A newly consumed legacy item may therefore have an
old unqualified `acquired_at` and a new qualified `consumed_at`. A newly closed old
order can likewise retain unqualified issuance beside qualified closure. There
is no subtraction, sorting, expiry or neglect consequence added for these values.
A future numeric consumer must first establish a compatible basis; missing or
unknown qualification does not authorize a duration calculation.

Adoption is an observed event distinct from original issuance. A migrated job gets
`adopted_at` and `adopted_at_basis`; it copies original issuance/basis only when
present in the source order and retains the entire source in `legacy_order`, with
its stable `legacy_order_id`. Historical title/objective strings in that opaque
archive are never used as current presentation; the job library still supplies
current objectives.

If authored job progress already exists, it remains intact while retirement
archives the source order. That route does not fabricate an adoption timestamp or
overwrite the current job's issuance. Repeating the migration after retirement or
reload does not duplicate/restamp anything. A conflicting previously archived
source causes retirement to refuse, leaving both current source records available
instead of overwriting history. The stable mapping remains ChirpHunt's; WorkOrders
owns archival transfer and lifecycle legality.

Existing old record replacement behavior remains domain-owned: a later incident
report replaces the per-unit latest incident record, while register lines append.
The proposal preserves old timestamps on restore and on continuing an existing
record; it does not create a general historical event log for every incident.

## Consumer inventory before preparation

The original named-field search across `game/**/*.gd`/`*.json` found eight host
Unix writes and no production numeric read, sort or elapsed calculation for those
particular timestamp fields. The similarly named OpenShiftSituation `closed_at`
belongs to a different record with an existing basis/migration contract and is not
changed here. Organism `at` is a three-coordinate spatial value, unlike register
line `at`; it is not a timestamp target.

| Original owner / lines | Actual consumers and behavior |
| --- | --- |
| `maintenance_inventory.gd:30,42` | `has_item`/`is_consumed` read only custody booleans. `item_state`, `serialize`, `restore` copy record fields verbatim; restore validates shop ID/consumed shape, not timestamp arithmetic. |
| `work_orders.gd:53,77,132,230` | Stage/status, part gating, objective reconstruction and signal payloads use domain facts. `serialize_jobs`/`restore_jobs` retain additive fields. `_valid_job_record` checks authored ID/stage/origin/evidence/repair result. No deadline uses issued/closed time. |
| `chirp_hunt.gd:89–103` | Actual migration maps old issued/active/closed status to issued/acknowledged/awaiting_part, adopts once, then retires the simple order. Originally it fabricated issue time and lost source timestamps; coexistence also retired the source. |
| `organism_incidents.gd:264` | `_rearm_from_ledger`, `_record`, `census` use condition/prop/fixed/closed identity. Dwell, roll retry, clearance and cooldown use transient delta-second accumulators, not `reported_at`. `_voice` already uses campaign minute-of-day for displayed clock text. |
| `night_register_prop.gd:619` | `_stored_lines`/`serialize` and maintenance snapshot/restore copy complete lines. Visuals count lines. `FirstShiftDirector.accept_signed_register:331` reads filing/job/report/key facts, not `at`; it cannot infer a route or elapsed duration. |
| `reality_game_state.gd:load_game,_validate_document` | Real persistence preserves compatible additive basis/archive fields. Version-0 default migration and existing deeper domain-schema limits remain unchanged. |

## Prepared proof and handoff sequence

`WorldTimestampTest` uses actual Inventory, WorkOrders, NightRegister and incident
report code, plus actual RealityState disk writes/loads. A stand-in building binds
the physical register to real WorkOrders. Survey presence is supplied at the real
incident report callback; this is not a full living-field or physical-route test.
The same fixture only calls pre-existing interfaces directly, so it can compile
against all five preserved original sources for the meaningful original red.

Expected checks cover exact 2.5 campaign minutes across the opening midnight;
4329.25 and 5761.5 elapsed minutes after several days; new issue/close/custody/report/
signature values; repeat-event idempotence; actual save/load with exact clock
equality; old unqualified timestamps retained beside new qualified values; real
ChirpHunt migration, repeat, reload and coexistence; archive-conflict refusal; and
invalid clock protection before timestamped mutations. The fixture owns teardown
and allows two frames plus 0.1 seconds for source-owned register audio retirement.

Independent review found a nested callback window in the first incident proposal:
issuing a work order can protect the save before the incident samples its clock.
The revised owner captures the validated observed minute before those callbacks.
The added fixture raises the real protection latch from the actual order-issued
signal. It distinguishes newer in-memory incident facts from the last successfully
saved document and verifies actual reload adopts only the latter. This simulates
the latch window, not a physical storage fault. The prior late-sampling proposal
is retained as a selective omission in `controls/mid_report_late_sample/`.

After root grants source/runtime ownership:

1. Install only the two proposed test files and run the unchanged original five
   production files for a genuine assertion red. Preserve raw sources and exits.
2. Apply the five proposed production sources; run the same fixture for green.
3. Temporarily install the four `controls/wrapped_minute/` owner copies. They keep
   every basis label but replace accumulated minutes with wrapped minute of day;
   exact multi-day timestamp assertions must fail. Restore exact candidate bytes
   in `finally`, verify hashes, then run restored green.
4. Run affected existing job, errand, register, incident, calendar and persistence
   regressions as needed. Existing tests' diagnostics remain evidence; no global
   audio reset, muting, baseline acceptance or source change is implied.

Before the restored final green, also run the single-file late-sampling omission
against the same final fixture, restoring exact candidate bytes in `finally`.

`run_case.py <fresh-name> timestamps --expected-exit 1` records an expected red;
omit the expected-exit option for green. Other named modes select existing owner
regressions. It uses `tools/run_godot_serial.ps1`, a fresh APPDATA, Git/Python and the
bundled PowerShell path declared by `PWSH`. It captures raw logs/exits, failed
assertions, full text runtime input hashes and the seven source copies plus clock,
storage and RealityState. The receipt preserves the raw process exit. The runner
returns a separate diagnostic gate which also requires stable recorded source,
the selected suite's PASS footer and no native error/retention diagnostics.
Expected negative runs remain red. `test_gate.py` includes zero-exit error and
retention, missing/wrong footer, native failure and source-drift controls;
warnings are retained for review.

No runtime result is asserted yet. The existing host-Unix audit proposal under
`work/save_recovery/unix_audit/` remains root-owned and is not bundled or silently
applied here. Host identifiers and RealityState dream-seed entropy remain outside
this production patch.
