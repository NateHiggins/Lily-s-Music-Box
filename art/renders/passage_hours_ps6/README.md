# PS6 — Vantry Arcade hours evidence

Captured 2026-08-15 from `PassageFinishShot.tscn` at the production 1280 × 720
viewport. All sets use the same five cameras; the original baseline predates
the hours owner and therefore contains four frames only.

- `before/`: canonical 03:00 before PS6. All eleven shops and all carts read as
  open, which is the defect.
- `after_night/`: canonical 03:00 production. Ten dark units sit behind open
  scissor lattice, three carts carry visible frame chains, and HARDWARE PAINT
  remains the single lit night-service counter required by the maintenance
  errand.
- `after_day/`: forced day evidence. Every lattice is folded at its pier, all
  eleven shop circuits are restored, and the cart chains are absent.

The grille reference is historical rather than a generic modern shutter.
Historic England records “sliding lattice gates” at the 1894 Hepworth's
Arcade and describes its iron-and-glass shopfront family:
https://historicengland.org.uk/listing/the-list/list-entry/1283101. The NYC
Landmarks Preservation Commission's storefront glossary independently names
internally mounted security/scissor gates:
https://www.nyc.gov/site/lpc/about/glossary.page.

## Performance control

`Perf.tscn`, `PERF_STATION=passage hall northbound`, canonical pinned night,
16/16 light/shadow budget, fresh process per measurement:

| state | run 1 | run 2 | mean |
|---|---:|---:|---:|
| production after-hours | 16.70 ms | 16.17 ms | 16.44 ms |
| `PASSAGE_HOURS_OFF=1` (open control) | 17.62 ms | 17.55 ms | 17.59 ms |

The production mean is 1.15 ms lower, but live resident submissions varied
between fresh processes; this pair therefore proves no regression and is not
claimed as exact per-source attribution. `PASSAGE_HOURS_OFF` is a retained
same-build diagnostic only. It forces the open/day shop state and disables the
hours clock; it is not a player setting.

## Executable proof

- PassageHoursTest: PASS, 15 checks / 0 failures.
- PassageFinishTest, PassageNavTest, ShopEntryTest, PassageVisibilityTest:
  PASS.
- PassageOwnershipAudit: 0 visible unclassified F01 draws.
- LightingAudit: 127 spaces, 11 intentionally ambient/dark, PASS.
- GoldenLoopTest: 65/65, including the physical night purchase and return.
- WalkTest FULL, x8 / 480 Hz: PASS.
