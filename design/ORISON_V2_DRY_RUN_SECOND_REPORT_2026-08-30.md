# Orison v2 rebuild dry run, second report — 2026-08-30

Evidence class: **INERT - REPORT (dry run two, landed 2026-09-19 as history; the v1 atrium object-count drop it records is still unexplained)**

Pin: **5c1a96a8b397af71954edb233aed5953d7fbc5e0**

Execution branch: **codex/v2-dry-run-2**

Disposable output: **C:\PleaseRemainOnTheLine-v2-dry-run-2-output-20260830**

Overall result: **BLOCKED**. The run found that two of the eleven claimed
prerequisites are not implemented at the scope their contracts require. The
hard stop before Phase 3 therefore worked. No rehearsal data, geometry, floor
split, selector change, production cutover, baseline update or main merge was
performed.

## Lead findings

### The reader gate can go green

Yes. A clean mini-repository containing one JSON file, one exact production
path reader and readers for both leaf fields produced zero records and exit 0.
The paired unread fixture produced one unread file, one unread field and exit
1. The audit is not a constant-red instrument.

The live tree remains intentionally red and the gate remains report-only. This
run did not wire it into a runner or CI.

### The run-one atrium number was v1, not v2

The run-one command loaded **orison_root.tscn**, which is the v1 production
root. Executable benchmark code fixed the light budget at 64 active lights and
five shadow casters. With no explicit override it set **DAYNIGHT=0**, described
in the same source as canonical 03:00. Resolution was 2560 by 1440.

Therefore the 14,766-object, 18.75 ms result was nominally the same v1
seven-storey station and profile class as DT4. It was not a partial-v2-root
measurement. The unexplained 11,230-object reduction remains an unresolved
measurement discrepancy, so neither the object reduction nor the associated
boot improvement is accepted as a rebuild gain.

### Is piece two cheap?

| Synthetic kind | Answer | Reason |
|---|---|---|
| second shop | **NOT PROVEN** | Phase 3 could not legally create the first durable shop bucket because the reader and nested-persistence gates do not cover the approved exterior home |
| second threshold | **NOT PROVEN** | Phase 4 was prohibited by the Phase 2 hard stop |
| second route connection | **NOT PROVEN** | Phase 4 was prohibited by the Phase 2 hard stop |

This is deliberately not softened into “probably.” Expansion cost was the
Phase 4 acceptance criterion, and no synthetic instance was authorized.

## Phase status

| Phase | Status | Result |
|---|---|---|
| 0 — pin and inventory | **PASS** | pin, tools, processes, hashes, gates and output home were re-derived; import changed no tracked import bytes and generated exactly two missing test UIDs |
| 1 — instrument truth | **PASS** | positive, timeout, lane-refusal, malformed-builder, three malformed-audit, reader-red and reader-green paths all produced distinct expected results |
| 2 — prerequisites | **BLOCKED** | 9 yes, 2 no; all eleven rows were answered independently |
| 3 — zero-geometry rehearsal | **BLOCKED / NOT RUN** | the plan forbids authored rehearsal data after any prerequisite is absent |
| 4 — synthetic first-cell proof | **BLOCKED / NOT RUN** | Phase 3 did not pass; no render or expansion proof exists |

## Eleven-row dependency table

| # | Dependency | Result | Independent evidence |
|---:|---|---|---|
| 1 | every new game/data file has a production reader or named exception | **NO** | **audit_data_consumption.py** enumerates only **game/data/*.json** with a non-recursive glob; it cannot see the approved nested exterior home **game/data/orison_v2/exterior/** |
| 2 | persisted numeric fields have readers and are not monotonic-only | **NO** | the durable-number pass parses only numeric defaults at the top level of **RealityState._fresh_data()**; nested persisted bucket records are invisible |
| 3 | element-indexed corruption lineage covers the six required kinds | **YES** | **corruption_lineages.json** contains street, entrance apron, arcade portal, shopfronts, B1 boiler and service circulation; the registry rejects rows without an ordinary owner |
| 4 | neighbourhood origin is ruled | **YES** | the shared-frame record makes the front-door threshold the origin, positive Z outward and the production layout the metric authority |
| 5 | shop namespace is ruled | **YES** | the shared-frame record declares **SHOP_** and canonical **SHOP_BODEGA**; the frame contract normalizes and rejects foreign forms |
| 6 | simulation epoch is ruled | **YES** | campaign creation samples local date/time once, then durable simulation minutes advance independently of host time |
| 7 | anomaly/space binding is ruled | **YES** | the shared-frame record indexes by space, separates era and wound, uses pull and winner-plus-trace and forbids a combined accessor |
| 8 | completeness has an exterior/region axis | **YES** | the ledger declares the region dimension, six exterior region requirements and a repeatable region filter; its 91-test suite passes |
| 9 | v2 exterior has a separate authoritative output home | **YES** | the shared-frame record approves separate data, runtime-asset and staging homes and explicitly forbids both v1 layouts and floor 01 assets |
| 10 | saved dream revision reconciliation exists | **YES** | compatible revisions migrate to current; unsupported revisions cancel before world swap and clear the transaction safely |
| 11 | floor-residency measurement exists | **YES** | the committed seven-floor receipt records standalone resource root, headless Forward+, no campaign simulation, threaded load, main poll/get/instantiate and MiB |

The ADMIN prerequisite runtime contract still passes 11 of 11 because it tests
the existence and narrow behavior of the new authorities. It does not exercise
a nested exterior data file or nested durable bucket number. That is the exact
gap this second run exposed.

## Phase 0

- Initial HEAD and merge-base were the requested pin.
- Python was 3.12.10, Godot was 4.7.1 stable and Blender was 5.2.0 LTS.
- Initial Godot and Blender process census was empty.
- The initial worktree was clean.
- Import completed with exit 0.
- Godot generated two missing identities:
  **orison_v2_blockout_guard_test.gd.uid** and
  **orison_v2_presence_ledger_test.gd.uid**. They were committed alone as
  **9307cd6**.
- All 121 tracked import files had working-tree byte hashes exactly equal to
  their HEAD blobs. No field, timestamp, path, import parameter or line ending
  changed. Git retained stale stat marks until a named index refresh. The
  correct recommendation is to make the Windows clean check refresh the index
  before interpreting status; do not commit or ignore unchanged metadata.
- **BuildingRootSelector.DEFAULT_ID** remained **v1**.

Baseline and final completeness were identical:

| Metric | Value |
|---|---:|
| requirements | 150 |
| absent | 52 |
| shell only | 3 |
| programmed | 42 |
| spatially proven | 18 |
| runtime proven | 34 |
| human accepted | 1 |
| first slice blockers | 0 |
| golden shift blockers | 1 |
| structural blockers | 86 |
| runtime blockers | 45 |
| production cutover blockers | 101 |
| v1 retirement blockers | 103 |
| v1 fallbacks | 7 |
| heuristic conclusions | 27 |
| stale checkpoint identifiers | 1 |

The spatial audit and systemic authority audit both remained clean.

## Phase 1 instrument matrix

| Instrument and condition | Exit | Decisive output |
|---|---:|---|
| serial runner, presence-ledger short suite | 0 | PASS, 17 checks |
| serial runner, M08E at one-second ceiling | 124 | child terminated; runner explicitly reported no suite verdict |
| serial runner while a controlled process held the global mutex | 73 | lane busy; no Godot process started; holder remained alive until cleanup |
| malformed blockout guard | 0 | clean fixture built; every dangling, overlap, wrong-table and missing-target mutation was refused with no partial geometry |
| malformed completeness input | 3 | malformed v2 layout |
| malformed spatial manifest | 3 | record without key |
| malformed systemic baseline with actionable fixture | 5 | malformed plus actionable findings |
| reader audit, unread file and field | 1 | one file-unread and one field-unread blocker |
| reader audit, fully consumed clean fixture | 0 | zero records, zero blockers |
| M08E spatial at 120 seconds | 0 | PASS, six unique owners, continuous service route and stable production layout |
| genuine two-root matrix at 120 seconds | 0 | PASS, 24 checks and all four reconstruction directions |

No red fixture exited zero except the builder guard, where refusal itself is
the asserted successful behavior. No selection was empty.

## Phase 2 hard-stop analysis

The approved exterior output home and the consumption tool disagree at their
boundary. A file such as **game/data/orison_v2/exterior/shops.json** is in the
only authorized home but is never enumerated by the gate. Adding an exception
would not help because the file is unseen, and baselining would conceal rather
than repair the defect.

The second gap is analogous. A bodega bucket needs nested durable facts such as
stock count and last-advanced simulation minute. The numeric audit reads only
top-level fresh-state defaults, so it cannot prove those fields have a reader
or detect a self-feeding monotonic implementation.

The minimum correction is bounded: recursively enumerate JSON under
**game/data**, preserve each relative path for exact reader matching, and add a
fixture in the approved exterior home; then walk the declared durable schema
recursively, with a fixture proving a nested unread and monotonic-only number
both go red. The reader tool should remain report-only afterward until the live
1,272 findings are triaged.

## Protected hashes

The before and after SHA-256 inventories are stored in the disposable output
directory. All 17 protected paths are identical: both production layouts, all
seven floor GLTF/BIN pairs, and the selector source. There are zero mismatches.

## Command and exit ledger

| Command group | Exit |
|---|---:|
| initial git pin, merge-base, status, process, version and hash inventory | 0 |
| initial completeness / spatial / systemic audits | 2 / 0 / 0 |
| initial completeness / spatial / systemic / reader suites | 0 / 0 / 0 / 0 |
| initial reader live audit | 1, intentionally red |
| Godot import | 0 |
| import byte comparison over 121 files | 0, zero differences |
| two UID named commit | 0 |
| Phase 1 serial short / timeout / lane refusal | 0 / 124 / 73 |
| builder guard | 0 |
| malformed completeness / spatial / systemic fixtures | 3 / 3 / 5 |
| reader bad / clean fixtures | 1 / 0 |
| M08E spatial / two-root matrix | 0 / 0 |
| ADMIN prerequisite runtime contract | 0, 11 of 11 |
| final completeness / spatial / systemic audits | 2 / 0 / 0 |
| final completeness / spatial / systemic / reader suites | 0 / 0 / 0 / 0 |
| final blocker scopes, first/golden/structural/runtime/cutover/retirement | 0 / 2 / 2 / 2 / 2 / 2 |
| final protected-hash comparison | 0, zero mismatches |

Full stdout, stderr, fixture trees and machine JSON reports remain in the
disposable output directory.

## Unresolved items

1. Reader enumeration is not recursive into the authoritative v2 exterior
   home.
2. Durable numeric analysis does not cover nested persisted bucket fields.
3. The v1 atrium station lost 11,230 submitted objects relative to DT4 without
   an identified production change; the run-one result is not accepted as an
   improvement.
4. Piece-two cost remains unproven for shop, threshold and route connection.

## Decision

**Repeat the dry run after named corrections.** Extend and fixture-test the
reader and durable-number audits at the scopes above, then restart at this pin
plus those corrections. Do not author geometry first.

This report does not authorize M09, selector changes, production cutover, v1
retirement, floor 01 splitting, a bounded v2 landing or a building-wide pass.
