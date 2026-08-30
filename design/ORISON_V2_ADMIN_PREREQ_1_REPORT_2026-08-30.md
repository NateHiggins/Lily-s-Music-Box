# Orison v2 ADMIN-PREREQ-1 report — 2026-08-30

## Outcome

All eleven dry-run prerequisites now have an implemented authority, instrument,
or measurement. No geometry was authored. This makes the next rehearsal
eligible to enter Phase 3; it does not imply that authored-data debt or the
whole-building blockers are resolved.

| Item | Cleared | Decisive evidence |
|---|---:|---|
| 1 reader gate | yes | **audit_data_consumption.py** exits 1 on live unread files and fields; fixture suite 4/4 |
| 2 durable numeric gate | yes | **building_stability** and **reality_coherence** report monotonic-write-only |
| 3 element lineages | yes | six space lineages load only when **ordinary_system** exists; era and wound have separate accessors |
| 4 neighbourhood origin | yes | shared-frame schema fixes the front-door threshold, positive Z and sole metric authority |
| 5 shop namespace | yes | shared-frame schema canonicalizes the bodega as **SHOP_BODEGA** |
| 6 simulation epoch | yes | real local epoch captured once; simulation elapsed time drives day, date, schedules and daylight thereafter |
| 7 anomaly binding | yes | shared-frame schema records pull and winner-plus-trace on space keys |
| 8 region ledger axis | yes | six exterior regions are named and filterable; completeness tests 91/91 |
| 9 exterior home | yes | Codex-approved isolated data, asset and staging homes are machine-readable; forbidden outputs named |
| 10 dream revision | yes | compatible saves reconstruct; unsupported revisions cancel before world swap |
| 11 floor residency | yes | seven floors measured with threaded wall, main-thread poll/get/instantiate and MiB provenance |

## Re-derived gates

At the pin, before changes: systemic 0, spatial 0, suites 90/90, 51/51 and
34/34. The completeness counts were 0/1/80/45/95/97, but the direct unfiltered
command returned exit 1 rather than the asserted exit 2 despite printing the
same blockers. That exit-contract discrepancy is recorded, not normalized.

After changes: systemic 0; spatial 0; completeness 91/91; spatial dependency
51/51; systemic authority 34/34; data-consumption 4/4; ADMIN prerequisite
runtime contract 11/11. The reader audit correctly remains red with exit 1.

The new region axis raises visible scope counts rather than hiding them:
first-slice 0, golden shift 1, structural 86, runtime 45, production cutover
101, v1 retirement 103. Requirements rise from 144 to 150. The six added
structural blockers are the six previously invisible exterior regions.

## Reader-gate findings

The first live run reports 1,272 unread leaf fields, ten unread whole files,
one malformed JSON file and two monotonic-only durable numbers. No exceptions
exist.

The three most surprising findings are:

1. **trivia_darts.json** is malformed by an invalid control character, so it
   cannot become live data even if a reader is added.
2. Ten complete authored files have no production path reader, including the
   notice atlas, creature index, material catalog, mailbank cards and resident
   animation/model data. The absence is broader than the known decor debt.
3. **light_provenance.json** has a file-level reference but no field-level
   consumer for its 191 fixture records. A named file reference had been
   masquerading as consumption.

The schedule census is also exact now: 415 unread outfit values, 26 unread
co-presence values and ten unread route polylines.

## Floor-residency measurement

Measurement root: standalone floor resource. Profile: headless Forward+,
threaded ResourceLoader. Simulation state: no campaign simulation. Scope:
F01–F06 and B1 only.

| Floor | Resident MiB | Threaded wall ms | ms/MiB | Main poll ms | Main instantiate ms |
|---|---:|---:|---:|---:|---:|
| F01 | 12.115 | 1115.602 | 92.086 | 0.788 | 15.633 |
| F02 | 6.019 | 679.787 | 112.932 | 0.489 | 3.085 |
| F03 | 6.137 | 757.928 | 123.508 | 0.544 | 2.802 |
| F04 | 6.291 | 687.022 | 109.207 | 0.485 | 2.747 |
| F05 | 6.218 | 740.671 | 119.121 | 0.481 | 2.871 |
| F06 | 6.263 | 679.861 | 108.550 | 0.520 | 2.724 |
| B1 | 2.794 | 622.854 | 222.940 | 0.421 | 2.567 |

This is measurement, not a regression threshold. It records what was measured
so a partial v2 root cannot be compared to a full v1 building as though they
were the same object.

## Preservation and unresolved owner decision

Both production layout files, floor 01 GLTF/BIN and
**BuildingRootSelector.DEFAULT_ID** are byte-identical to the pin. The selector
remains **v1**.

One owner decision remains deliberately outside the eleven: whether the
period-appropriate prose in **light_provenance.json**, after stripping any
absolute-year claim, should reach a player-visible surface. The reader gate
proves that it currently does not.

Godot's clean import generated UID sidecars for two pre-existing tests that
were not among the pin's committed UID set. It did not rewrite committed UID
values. Those foreign generated sidecars are excluded from this work.
