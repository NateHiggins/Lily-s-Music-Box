# Orison v2 rebuild dry-run report — 2026-08-30

Commit pin: `b070cb434924bd53ed80222312e0c1343496f5b5`

Worktree: `C:\PleaseRemainOnTheLine-v2-dry-run-20260830`

Disposable output: `C:\PleaseRemainOnTheLine-v2-dry-run-artifacts-20260830-b070cb4`

Overall result: **BLOCKED — successful rehearsal; no Phase 4 geometry was
authorized or produced.**

## Lead findings

### 1. Phase 1 proved which instruments can go red

| Instrument | Deliberate condition | Exit | Decisive result |
| --- | --- | ---: | --- |
| serial runner, positive path | `orison_v2_presence_ledger_test` | 0 | `PASS checks=17` |
| serial runner, timeout path | M08E spatial at a one-second ceiling | 124 | runner killed the child and explicitly reported no suite verdict |
| serial runner, lane path | controlled process held the shared mutex | 73 | refused before launching Godot |
| blockout builder | nine malformed/dangling/overlap cases | 0 | each bad case was refused; no partial geometry and no selector-group join |
| completeness ledger | malformed committed JSON fixture | 3 | `ERROR: malformed v2 layout` |
| spatial dependency audit | malformed committed manifest | 3 | `ERROR: malformed manifest ... record without key` |
| systemic authority audit | malformed baseline plus actionable fixture | 5 | `MALFORMED baseline plus actionable findings` |

Every gate exercised a non-vacuous bad case. None required a baseline update.
The builder harness exits zero because refusal is the asserted behavior; its
individual malformed builds emit errors and build nothing.

### 2. The true two-root verdict

`orison_v2_two_root_matrix_test` completed under an explicit 120-second
ceiling. **Exit 0: PASS, 24 checks; v1→v1, v2→v2, v1→v2 and v2→v1 all 1/1.**
The run emitted the existing `cam_noel_witches` no-legal-wall warnings but no
failed check. M08E spatial also completed for the first time under the honest
ceiling: **exit 0, PASS**, including its collision-bearing service route and
production-layout byte-stability assertion.

### 3. Phase 2 dependency table

The owner had independently pre-verified four absences. Re-reading production
code, data and the binding documents finds a broader result: the axis direction
is ruled, but none of the eleven listed prerequisites is complete.

| # | Dependency | Yes/no | Evidence at `b070cb4` |
| ---: | --- | --- | --- |
| 1 | every new `game/data` file has a production reader or named exception | **NO** | no reader-existence gate exists; `ORISON_GENETIC_MEMORY_2026-08-29.md` explicitly schedules it before M11 |
| 2 | persisted numeric fields have readers and are not write-only monotonic progress | **NO** | no persisted-field reader/monotonicity gate exists; the same document identifies the missing structural companion |
| 3 | element-indexed lineage/corruption vocabulary covers street, apron, arcade, shops, B1 and service circulation | **NO** | `game/data/corruption_lineages.json` is absent; existing corruption remains resident-indexed |
| 4 | street/neighbourhood origin is ruled | **NO** | `ORISON_NEIGHBOURHOOD_ARRANGEMENT_DIRECTION_2026-08-29.md` rules **+z direction**, bands and portal plane, but does not declare an origin identity/transform contract |
| 5 | shop identifier namespace is ruled | **NO** | production contains several `SITE_SHOP_DOOR_`, `SITE_SHOP_HOURS_`, light-prefix and inventory `shop_id` forms; no binding namespace ruling exists |
| 6 | simulation-tier epoch is ruled | **NO** | the bucket document defines S0–S3 and elapsed simulation minutes but no epoch/origin or cross-clock conversion contract |
| 7 | anomaly/space binding frame is ruled | **NO** | no binding document or schema contract defines this frame |
| 8 | completeness ledger has an exterior/region axis | **NO** | the tool has floor/unit/space filters and only `site.street_threshold`; there is no region/exterior dimension |
| 9 | v2 exterior has an authoritative output home separate from v1 | **NO** | no v2 exterior output tree or schema authority exists |
| 10 | saved dream-module revision reconciliation exists | **NO (partial storage only)** | `dream_director.gd` saves `maze_revision` and reads the catalog version but never compares, migrates, rejects or reconciles a saved differing revision |
| 11 | floor-residency measurement exists before selecting the `floor_01` cut | **NO** | no residency manager/receipt exists; `ResourceLoader.load_threaded_request` remains unused for this purpose |

This table is the hard stop. Phase 4 was not entered.

## Phase status

| Phase | Status | Result |
| --- | --- | --- |
| 0 — pin and inventory | **FAIL** | inventory completed, but a Godot import dirtied the fresh worktree: 121 tracked texture `.import` files changed and two missing test `.uid` files were generated |
| 1 — prove instruments can be red | **PASS** | all required positive, timeout, lane, builder-refusal and bad-fixture paths were demonstrated |
| 2 — dependencies | **BLOCKED** | 0/11 complete; every row answered above |
| 3 — zero-geometry rehearsal | **BLOCKED** | checkpoint-impact prediction completed; shop/opening rehearsal stopped because its reader/frame/output prerequisites are absent |
| 4 — synthetic first-cell proof | **BLOCKED / NOT RUN** | prohibited by the Phase 2 result |

Phase 0 was continued despite its cleanliness failure because the owner required
Phases 0 and 1 to complete unconditionally. The dirty files were not staged,
restored, accepted or baselined.

## Phase 0 inventory and import finding

- Python `3.12.10`; Godot `4.7.1.stable.official.a13da4feb`; Blender `5.2.0 LTS`.
- Initial Godot/Blender process census: empty.
- Initial worktree: clean, detached at the requested pin.
- Tracked `.uid` count: 750. Import rewrote **zero tracked `.uid` values**, but
  generated untracked `game/tests/orison_v2_blockout_guard_test.gd.uid` and
  `game/tests/orison_v2_presence_ledger_test.gd.uid`.
- Import also changed 121 tracked texture `.import` records. Therefore committed
  `.uid` values are stable, but the pin still does not remain clean across an
  import.
- `BuildingRootSelector.DEFAULT_ID` remained `"v1"`.

Baseline and final completeness were identical:

```text
requirements 144
ABSENT 46; SHELL_ONLY 3; PROGRAMMED 42
SPATIALLY_PROVEN 18; RUNTIME_PROVEN 34; HUMAN_ACCEPTED 1
blockers first-slice/golden/structural/runtime/cutover/retirement
0 / 1 / 80 / 45 / 95 / 97
stale checkpoint ids: B1_PUBLIC_LANDING_E (1)
```

The spatial audit remained clean (3,626 records, zero unclassified, changed,
vanished, unresolved or stale records). The systemic audit remained exit 0.
The suites remained 90/90, 51/51 and 34/34.

## Re-measured decision numbers

| Measurement | Stale value | `b070cb4` result | Decision impact |
| --- | ---: | ---: | --- |
| production boot | 27.7–33.2 s vs 24 s | **18.512 s**, exit 0; resource 2.123 s, assembly 14.581 s, first frame 1.807 s | materially improved and under the warning ceiling; measured headlessly after import |
| atrium eye, 2560×1440 | 25,996 objects, ~31 ms | **14,766 objects, 18.75 ms mean, 18.93 ms wall**, exit 0 | materially improved, still over 16.6 ms as a non-blocking composition camera |
| `floor_01` | 12.02 MB, one broad buffer | **12.115 MiB combined** (`.gltf` 0.651 + `.bin` 11.464), one buffer | effectively unchanged as a residency decision |

The GLTF has 531 mesh/POSITION accessors. Its union is x −112…108. The widest
individual position accessors span x −112…108 (220 m), −108.2…104.2 (212.4 m)
and −108…104 (212 m). It is still too broadly welded to select a cut by taste;
the missing residency measurement remains decisive.

The atrium performance receipt is deliberately marked inadmissible because the
import had already dirtied the worktree. It remains a valid development
measurement and is not promoted to acceptance evidence.

## What the 80 structural blockers mean

At the pin the 80 blockers are 42 ABSENT, 3 SHELL_ONLY and 35 PROGRAMMED.
Geometry generation alone clears **zero** ledger blockers because structural
completion requires `SPATIALLY_PROVEN`, not merely a room record. It would make
45 blockers eligible for proof by advancing the 42 absent and 3 shell-only
requirements to PROGRAMMED; the existing 35 programmed rows would not move.

The scratch checkpoint amendment—without geometry—predicts the only two
immediate structural clearances:

- `f01.watch_station` through backticked `F01_WATCH`;
- `unit.2B.entry` through backticked `F02_B_VESTIBULE`.

It exits 1 from `--evidence-impact` because those are real status changes. It
does not resolve `B1_PUBLIC_LANDING_E`: that identifier is a `platforms` record
inside `B1_PUBLIC_CORE`, while the stale-token census treats the old
space-shaped checkpoint mention as absent. Correcting it requires amending the
original claim/tool classification, not layering on new evidence.

Two more blockers, `circ.F02.public_landing` and
`circ.F04.public_landing`, need the already-described lateral opening records
and then checkpoint proof. The remaining 76 divide into:

- F01 program: `f01.mail_telephone`, `f01.parcel_package`,
  `f01.common_room`, `f01.staff_restroom`;
- circulation: 20 remaining F01–F06 landing/core/service rows;
- floors: F01–F06 and ROOF (7);
- apartments/functions: 31 remaining unit rows;
- B1 service rooms: coal, electrical, laundry, maintenance shop and storage;
- roof: bulkhead and tank machinery;
- service: wet, heat, telephone, passenger lift, service lift, electrical and
  fire-service risers.

A *build plus truthful checkpoint/traversal evidence* could eventually clear
those 76. The proposed current generator cannot honestly claim that outcome
yet: the composition census separately identifies 58 of 99 runtime authorities
that need named spaces, anchors or carriageway feeds, and the missing region,
exterior, lineage and frame prerequisites mean several required spatial kinds
cannot yet be authored in the authoritative v2 schema. A large generation pass
now would mostly turn ABSENT into PROGRAMMED while making the board look busier,
not complete.

## Phase 3 scratch result

The disposable candidate document was outside `design/` and was not staged.
`--evidence-impact` admitted its checkpoint-shaped name and predicted the two
status changes above. No synthetic shop data was authored because prerequisites
1, 5, 6, 7 and 9 are absent; doing so would create exactly the unread/unruled
data the rehearsal exists to prevent. No F02/F04 output was written because
there is no authoritative disposable exterior/output contract to contain a
mixed rehearsal. Baselines were untouched.

## Command and exit ledger

| Command or command group | Exit |
| --- | ---: |
| initial `git`, version, process, hash and six-gate inventory | 0 except completeness 2 (expected incomplete) |
| Godot editor import | process completed; shell wrapper lost its child code after the observation window; import log was not produced at the requested path |
| presence-ledger serial run, 120 s | 0 |
| M08E serial run, 1 s | 124 |
| controlled mutex lane-refusal run | 73 |
| blockout malformed-geometry guard | 0 |
| malformed completeness fixture | 3 |
| malformed spatial manifest | 3 |
| malformed systemic baseline + actionable fixture | 5 |
| M08E spatial, 120 s | 0 |
| two-root matrix, 120 s | 0 |
| boot-cost probe, 120 s | 0 |
| one-station release performance matrix | 0 |
| scratch checkpoint `--evidence-impact` | 1 (two predicted promotions) |
| eleven genetic/dry-run documents, individual `--evidence-impact` | 0 × 11; all refused as evidence, zero changes |
| final completeness / spatial / systemic audits | 2 / 0 / 0 |
| final completeness / spatial / systemic suites | 0 (90/90) / 0 (51/51) / 0 (34/34) |
| all read-only source searches, JSON inspection, GLTF measurement and hash comparisons | 0 |

Artifacts and complete stdout/stderr are retained under the disposable output
directory named at the top of this report.

## Before/after protected hashes

Every protected hash is identical before and after:

| Path | SHA-256 |
| --- | --- |
| both production layout JSON copies | `68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d` |
| `floor_01.bin` / `.gltf` | `e1d3454afb6079602b8cfe0dcb00d255e6aa68f7f247c5ecc39bd5791cfdc477` / `906f1f48c2fc8ff6e6af3048d0abca46416cd103bee8d818606a3c32c71fe5b1` |
| `floor_02.bin` / `.gltf` | `4b7d16ae8ed7df4a90f0626746ca5987bd02c61268f372fced86a3782760b69e` / `b3977546cabc72775ad63be53bfb2001ace51d13094b4ed8b719a979adc2d640` |
| `floor_03.bin` / `.gltf` | `8f84cb67f5f2fa8f2c5a5e47fbc418630957dbc8d6a96576e005c92ac6fcc9f8` / `21c506695edf27effa20c711f1daed939c807a774f5076656e8ff3e8be898d3f` |
| `floor_04.bin` / `.gltf` | `f57f45d79738086a5da23afd7d9a04d6f5596641193ec22856929de30b03e266` / `c1a03abba15f481e6318e27d5035dae13e3e5173f16c2f208711769ce3bf8df1` |
| `floor_05.bin` / `.gltf` | `a8e7f0fd106696a1c6c9823f30cf013b0f664e4dac5d763fc2c3d2c072dd54d8` / `d5860b28c47a110fcced5b8cd22c0f5d4ae0fc036dfc0d44fbe884a2def41e7a` |
| `floor_06.bin` / `.gltf` | `8389d2264ea4c6e4eb59fb35b58d7480b3823641c1471b593a85613883bd9f5f` / `96991ecf897b7882c68897eb9c8df5a678046e1567e8f59d51f21f6646209422` |
| `floor_b1.bin` / `.gltf` | `226437a3e2816882c04749918a4d99540ff2a4714d0a914b2dd2606ace8c4449` / `f151ff10c8d2420340fc522df5e9eb2ffbdf200be6068b302c6769881af8eb3e` |

## Decision

**Repeat the dry run after named corrections.** Before authoring geometry, land
the reader-existence and persisted-number gates; element-indexed lineage;
explicit origin, shop namespace, simulation epoch and anomaly-binding rulings;
the completeness region/exterior axis; a separate v2 exterior output home;
saved dream revision reconciliation; and a measured floor-residency result.
Also resolve the two missing test UIDs and decide whether tracked texture
`.import` metadata is intended to be a clean-worktree signal.

This report does not authorize M09, a selector change, production cutover, v1
retirement, `floor_01` cutting or a building-wide generation pass.
