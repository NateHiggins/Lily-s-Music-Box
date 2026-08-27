# Save/reload transaction model — 2026-08-27

**Milestone:** K0-ENGINE support for K3. **Checkpoint:** `6912ff1`.
**Evidence level:** L2, local pattern with focused repository evidence. No second
consumer or extracted API exists.

This is a source trace, not a K3 completion claim. Godot was not run. The
eleven-boundary human matrix in `TASKS.md` remains open.

## Ruling

The save file is a versioned fact store, not a scene snapshot.
`RealityState` owns one JSON document at
`user://reality_maintenance_save.json`. Domain owners mutate their portion of
`RealityState.data`, call `RealityState.commit()`, and reconstruct presentation
from those facts after load. A reload transaction is therefore:

1. create fresh version-4 defaults;
2. refuse a future-version file without merging or overwriting it;
3. otherwise merge the parsed dictionary and apply additive migration;
4. emit `state_changed`;
5. let domain owners validate, reconcile and re-present their facts.

This is intentionally not atomic across multiple domain mutations. Each domain
method decides when a meaningful fact has reached a commit boundary. K3 must
therefore test player-visible intentions and physical answers, not merely that
JSON parses.

## Authority and failure boundary

| Concern | Owner | Contract |
| --- | --- | --- |
| File path, version, defaults, merge, migration and write refusal | `game/scripts/game/reality_game_state.gd` | `SAVE_VERSION = 4`; one injectable path; future versions run read-only and are never merged or overwritten |
| Work-order facts | `WorkOrders` | Restores validated job facts; objective text is derived from the job library |
| Carried/consumed maintenance items | `MaintenanceInventory` | Spent records persist, preventing load from minting an item again |
| Case truth | `RealityCases` / `RealityCaseManager` | Case stage and rule changes remain separate from repair presentation |
| Immediate campaign intention | `CoreLoopDirector` | Reconciles `core_loop` with existing job/case facts and suppresses duplicate requests |
| Dream transition | `DreamDirector` / `CampaignShell` | Saves identity and phase; reconstructs at a stable boundary rather than a chase frame |
| Gradual onset | `SleepPressureDirector` | Saves selected form and warning progress; derives transient safety blocks |
| Waking residue | `RealityState` plus manifestation owner | Commits provenance/anchor facts once; rebuilds the visible residue after load |

`RealityState.commit()` writes first and emits `state_changed` afterward. A
write failure does not roll the in-memory domain mutation back. The player
notice says progress since the last successful save may be lost. This is a
failure-reporting contract, not a transactional database guarantee.

## Saved facts versus reconstruction

Saved:

- job stage, origin, evidence and repair result;
- item acquisition and consumption;
- case stage, trust, recurrence, conversation and resolution facts;
- the coordinator's active job, boundary and one-shot request flags;
- dream seed, phase, context and outcome;
- sleep-pressure form/progress;
- waking-residue identity and provenance.

Derived after load:

- objective and work-order prose from authored libraries;
- prompt text, HUD cards and modal presentation;
- settled mechanism animation and ordinary scene transforms;
- transient input locks and dream safety blockers;
- the Dream maze from seed/revision rather than serialized geometry;
- the waking-residue prop/label from its committed anchor facts.

Saving presentation copies would create two authorities. The current pattern
instead requires each visible owner to be a deterministic reader of committed
facts or to declare an intentional stable restart point.

## What automated evidence actually covers

`game/tests/core_loop_test.gd` performs JSON stringify/parse/merge round trips
and rebuilds the coordinator at eight semantic campaign states:

| Automated boundary | Proved reconstruction |
| --- | --- |
| idle / before issue | no job is invented |
| issued or acknowledged | the same open job resumes |
| awaiting part | diagnosis/evidence and stage resume |
| repairable / part acquired | one item exists and no conversation is requested |
| repaired / conversation pending | the earned request is not duplicated |
| conversation complete | the closed job waits for final case integration |
| dream pending | one pending dream is re-requested after protection clears |
| wake complete | no dream, item or chirp is resurrected |

The test is valuable but does not use the production file path. Other live
suites prove narrower K2 intentions, such as reconstructing the same work-order
card without committing on resume. The continuous dream-boundary harness uses a
real JSON file under `user://tests/` and contains its cleanup.

None of those is the K3 acceptance test. K3 names eleven *player-route* beats
and requires the immediate practical intention, job/case owner and physical
world state to be correct at each one. The automated eight are semantic state
transitions; the human eleven are experiential route checkpoints. Their counts
need not match and must not be substituted for each other.

## K3 evidence schema

At each of the eleven route beats, record all four rows:

| Field | Required observation |
| --- | --- |
| Resume location | Player returns to a safe, comprehensible authored position |
| Immediate intention | The next practical action is visible/audible without developer knowledge |
| Durable owner | The expected job and case facts are neither missing nor duplicated |
| Physical answer | Doors, mechanisms, carried/spent items and route affordances agree with those facts |

A boundary fails if the JSON survives but any one of these four readings is
wrong. Capture the first failing boundary against the exact build and save
version; do not repair later boundaries until that first transaction is
understood.

## Known limitations and falsifiers

- The generic `data` dictionary has no schema validator at the file boundary.
- Writes replace the target directly; no temporary-file plus rename transaction
  is visible in `RealityState.save_game()`.
- Additive defaults and `_migrate()` are local migration policy, not a proven
  chain across public releases.
- A successful `FileAccess.open`/`store_string` is treated as a successful save;
  no read-back verification is performed.
- K3 has not proved production-path reload at all eleven route beats.

The L2 ruling rises only after a second consumer uses an explicit fact/migration
contract. It falls if a domain stores presentation as authority, mutates durable
facts without a commit path, or cannot reconstruct the same practical state
from a valid version-4 document.

## Next work

1. Run K3 only after the unaided K2 golden shift establishes the route.
2. Attach the eleven observations to the tested build/save version.
3. Promote the first failing boundary into one bounded owner-specific task.
4. Before a public update, test the previous public build's save and the
   future-version refusal path; do not infer either from the focused loop test.
