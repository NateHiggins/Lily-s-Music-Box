# Orison v2 ADMIN-PREREQ-2 report — 2026-08-30

Status: **PASS — DRY RUN MAY RESTART AT PHASE 0**

Base: current `origin/main` at
`c2dc01771bc25b07f5dcf7a6040102345b8c57d5`.

This is an instrumentation report, not spatial evidence. It authorizes no
production geometry, selector change, M09, M10, cutover, v1 retirement, or
production-layout replacement.

## Reproduced gap

The second rebuild rehearsal correctly found that the data-consumption gate
enumerated numeric defaults only at the top level of the durable state. A
nested shop bucket could therefore contain unread or self-feeding numeric facts
without producing a finding. Mainline commit `c2dc017` repaired recursive JSON
enumeration in the approved exterior data home, but did not repair nested
durable-state analysis.

## Correction

`tools/audit_data_consumption.py` tool version 2 now:

- walks the complete declared `_fresh_data()` dictionary and retains dotted
  paths, including wildcard paths through arrays;
- resolves literal and constant dictionary keys;
- follows local and class-member aliases across functions;
- distinguishes reads, ordinary writes, and self-feeding monotonic writes;
- keeps sibling bucket identities separate while supporting deliberate generic
  container iteration;
- ignores state-looking prose inside string literals;
- treats equality as a read and compound assignment as a write;
- stops value-method chains at the durable field;
- invalidates reassigned local aliases while retaining a proved member binding
  across deterministic teardown; and
- fails closed when the durable schema is absent, uses unauditable inline
  containers, or hides a numeric default in an unsupported expression.

No exception, baseline, or suppression was added.

## Focused proof

`tools/tests/test_data_consumption.py`: **14/14 PASS**. Named fixtures prove:

- the approved nested exterior data home is enumerated and can go green;
- a meaningful nested reader goes green;
- nested unread and write-only numerics go red;
- direct and compound monotonic progress go red;
- equality, constant keys, class-member aliases, method chains, generic array
  readers, and numeric literal/constant forms are handled;
- sibling and unrelated fields cannot counterfeit a reader;
- strings cannot counterfeit source access; and
- absent or unauditable schema declarations fail closed.

The live audit remains honestly red and report-only: exit **1**, **1,304**
blocking records — 1,290 unread fields, 11 unread files, one malformed JSON
file, and the same two monotonic-only durable fields (`building_stability` and
`reality_coherence`). The correction reveals no new live nested schema because
no production shop bucket has been authored yet; it makes that future schema
auditable before it lands.

Standing gate results:

| Gate | Exit | Result |
|---|---:|---|
| completeness audit | 2 | expected incomplete rebuild; cutover scope still has 101 blockers |
| spatial dependency audit | 0 | clean |
| systemic authority audit | 0 | clean |
| data-consumption audit | 1 | intentionally red/report-only; 1,304 named blockers |
| completeness tests | 0 | 91/91 |
| spatial dependency tests | 0 | 51/51 |
| systemic authority tests | 0 | 34/34 |
| data-consumption tests | 0 | 14/14 |

## Preservation

The protected production paths have zero diff from the pin. Both production
layout copies remain SHA-256
`68838c933c0954092c63403f36ec7fb26d6c0956c01c23109465c680608b399d`.
The selector source remains SHA-256
`d2b3db95d72e4a418c0e7184e6b3368da723a945192024a10ee937ea604c9802`,
and its committed default remains **v1**.

## Disposition

All eleven dry-run prerequisite categories now have an independently exercised
instrument at the scope required by the plan. Restart the rebuild dry run from
Phase 0 against this repair. Production geometry remains prohibited until that
run passes Phases 0–4 and recommends the first bounded landing.
