# Open Shift systemic-authority audit delta (ADMIN-ETHOS2)

Before: fresh `tools/audit_systemic_situation_authority.py` run against
the unmodified `codex/ethos-open-shift` tip (`5ed8bf3`, radiator rebuild
`f572896` included) with the reviewed main baseline — **exit 1, 63 total
findings, of which 14 belong to Open Shift (10 actionable STRONG).**
After the corrections — **exit 0, zero actionable, zero Open Shift
baseline entries added.** Test-tier and REVIEW findings never fail the
gate; they are listed for the landing review.

## Every original Open Shift finding and its disposition

| # | Finding (stable id) | Class / confidence | Where | Disposition |
| --- | --- | --- | --- | --- |
| 1 | `c1ec102902f269c2` | DUPLICATE_CUSTODY / STRONG | ecosystem `abandon_after` | **FIXED** — `part_custody` string removed; packing lives in `MaintenanceInventory` as `radiator_packing_2b`; `RadiatorProp.packing_location()` derives the single custodian |
| 2 | `32a9e860b06e7eb2` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | ecosystem `abandon_after` | **FIXED** — method deleted; boundary derives from attested state; resident belief `help_started_then_stopped` comes from `NpcObservationLedger.witness_visible_state` (in-home sight of the physical residue) |
| 3 | `62a2c47cefc7ca51` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | ecosystem `abandon_after` | **FIXED** — as #2; `relationship_consequence` no longer exists as a recordable fact |
| 4 | `743a524738ff2ffa` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | ecosystem `advance_autonomy` | **FIXED** — neighbor knowledge now earned via `AcousticGraphData.audibility` (and the honest neighbor is 3B `omar_bell`, which the riser actually reaches — not "2c_neighbor") |
| 5 | `5386e2a5390bb2d3` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | ecosystem `advance_autonomy` | **FIXED** — porter's knowledge comes from his own arrival inspection (`record_direct_observation`); resident's from the tag in her flat |
| 6 | `c9f9856f6153433d` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | ecosystem `meddle_wrong_valve` | **FIXED** — method deleted; the `turn_valve` surface is the meddle; observers learn via acoustic/sight routes |
| 7 | `095c20de83e20fb2` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | ecosystem `meddle_wrong_valve` | **FIXED** — as #6 |
| 8 | `4f36e2ab82ccb450` | TIMER_IMPERSONATES_ACTOR / STRONG | ecosystem `advance_autonomy` | **FIXED** — the elapsed bucket no longer performs compensation/shutoff; `PorterActor` forms intent, travels, inspects, can be blocked or stood down, and applies the shutoff through the mechanism's API; elapsed time only grants eligibility |
| 9 | `ac45653fa3bc63e2` | AUTONOMY_DEPENDS_ON_PROXIMITY / HEURISTIC | ecosystem `_process` | **DOCUMENTED (REVIEW remains)** — the ecosystem is a waking-root node, not room-local; simulation minutes are durable; every consequence catches up deterministically from saved facts (proven by `OpenShiftAuthorityTest`); the heuristic cannot see catch-up and honestly stays |
| 10 | `25368d8b7a67dca8` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | situation `_store` | **FIXED** — `npc_knowledge`/`relationship_consequence`/`part_custody` removed from the default record |
| 11 | `961636ad324ddebd` | DIRECT_NPC_KNOWLEDGE_WRITE / STRONG | situation `record_fact` | **FIXED** — whitelist rejects all three; `open_shift_situation_test` proves the rejection |
| 12 | `a490e1f4c4e8b891` | TEST_AUTHORITY_SHORTCUT / HEURISTIC | `open_shift_abandon_test` | **FIXED (ADD_PUBLIC_PROOF)** — boundaries now produced through surfaces + neglect minutes; no consequence method exists to call |
| 13 | `2e5f61e9fb62ee62` | TEST_AUTHORITY_SHORTCUT / HEURISTIC | `open_shift_meddle_test` | **FIXED (ADD_PUBLIC_PROOF)** — drives the `turn_valve` surface |
| 14 | `87377967ac3e46e6` | TEST_AUTHORITY_SHORTCUT / HEURISTIC | `open_shift_save_matrix_test` | **FIXED (ADD_PUBLIC_PROOF)** — all four dispositions produced through surfaces/minutes/actor before each save/load direction |

## Findings remaining after correction (all non-blocking)

Eight new review-only rows, none actionable, none baselined: the
ecosystem `_process` heuristic (#9 above); test-tier TIMER patterns in
`open_shift_ignore/save_matrix/authority` tests (tests drive injected
simulation minutes — that is their job); two DIRECT_NPC_KNOWLEDGE
matches inside `open_shift_situation_test`, which are the *negative*
proofs asserting `record_fact("npc_knowledge", …)` now returns false;
and the evidence-shot harness's domain-API calls (a capture generator,
not a behavior proof).

Reproduce both sides:

```bash
python tools/audit_systemic_situation_authority.py            # exit 0 now
python tools/tests/test_systemic_situation_authority.py       # 34/34
```
