# Golden-shift run — owner deferral, 2026-08-29

**Owner decision, verbatim:** "owner deprioritized the golden-shift
run; geometry rebuild takes priority; K2 runs after the floors land."

## What this is

A scheduling decision, recorded so nobody later wonders why the
eleven-beat item sits open. The human golden-shift run is not
scheduled now; the spatial rebuild (M11/M12 floors and apartments) has
priority; the K2 card runs once the floors are in.

## What this is NOT

**It is not an acceptance.** No beat was run and none is claimed. The
requirement golden.eleven_beats stays ABSENT and GOLDEN_SHIFT_V2 keeps
its single blocker. This document is deliberately named so the
completeness ledger refuses it as evidence — it proves nothing and can
promote nothing. Verified with:

```
python tools/audit_orison_v2_completeness.py --evidence-impact \
    design/ORISON_V2_GOLDEN_SHIFT_DEFERRAL_2026-08-29.md
```

## Why deferring costs nothing

The golden shift is its own readiness scope. The spatial rebuild is
gated on FULL_BUILDING_STRUCTURAL, which the golden shift never
touches. Every floor and apartment ChatGPT builds proceeds at full
speed with this item open.

## Why running it today would stop anyway

Beat 4 ("fetch it") has no part source under v2: the maintenance
shop/storage space does not exist in the v2 schema, so the run would
halt there by construction. That gap is already the top item of the
Sept-3 spatial work order. Deferring until a part-source space exists
is what lets the card run end to end instead of producing a
pre-determined stop.

## When it runs, and what is already true

After the floors land — specifically once a part-source space exists.
Everything automatable was verified on 2026-08-28 (see
ORISON_V2_M10_RUNWAY_REPORT_2026-08-28.md): every automated
precondition passes under explicit v2 selection, so the card needs
only a human in the chair. Selector default remains v1; this decision
authorizes no cutover, no M09, and no selector change.
