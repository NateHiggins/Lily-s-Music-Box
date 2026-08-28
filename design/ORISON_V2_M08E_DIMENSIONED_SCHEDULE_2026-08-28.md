# ORISON-V2-M08E dimensioned schedule — 2026-08-28

Status: construction basis authored before schema edits. Dimensions are clear plan dimensions in metres; the universal 0.66 m body, 0.90 × 0.90 m interaction stance, 0.90 m apartment route, 1.20 m public route, and 1.05 m service route remain controlling.

## F01 caretaker/watch station

The existing `F01_WATCH` room remains 4.20 × 4.40 m (18.48 m²), exceeding the 3.00 × 4.20 m program minimum. The lobby-facing south side remains visually open through the existing arrival composition; the 0.91 m east door remains the direct path to the primary core and the 0.91 m west door remains the mail/telephone connection.

The four existing production instruments form one compact U-shaped workplace around a 1.20 × 1.80 m desk/work reservation and a continuous 1.05 m internal circulation strip:

| Durable owner | Control position | Player stance | Reach | Relationship |
|---|---:|---:|---:|---|
| `F01_WATCHMAN_DETECTOR` | (-2.00, -3.10) | (-2.00, -2.20) | 0.90 | Arrival-side clock-in/out edge |
| `F01_NIGHT_REGISTER` | (-3.25, -0.05) | (-3.25, -0.95) | 0.90 | Paper acceptance and filing surface |
| `F01_SIGNAL_REGISTER` | (-4.90, -0.60) | (-4.00, -0.60) | 0.90 | Wired west wall, visible from desk |
| `F01_TOUR_KEY_GUARD` | (-4.90, -1.75) | (-4.00, -1.75) | 0.90 | Distinct custody hook beside register |

The standing route is arrival/lobby → detector → register → key → east core door, with the reverse sequence after the job. Door-swing reservations remain outside instrument and stance rectangles. No porter/admin desk is added; `LobbyPorterBoard` remains its existing owner.

## Apartment 2B — Lena Ortiz

The smallest defensible H-plan correction is a southeast residential wing reached by a 1.20 m public east hall. The south envelope extends 0.50 m, from -12.00 to -12.50, solely to retain a complete 3.30 × 4.00 m kitchen, 2.85 × 3.00 m bath, and independent private distributor. It does not move the accepted west 2A/F04 routes or either core.

| Space | Clear dimensions | Area | Ordinary use |
|---|---:|---:|---|
| Public east hall + controlled crossing | 2.90 × 1.20 + 1.20 × 1.20 | 4.92 m² | F02 core to identifiable 2B threshold across service spine |
| Vestibule | 2.00 × 2.70 | 5.40 m² | Privacy, coat/storage, room choice |
| Living/work room | 4.15 × 4.50 | 18.68 m² | Living, conversation, fabric repair |
| Kitchen | 3.30 × 4.00 | 13.20 m² | Complete 0.65 m run plus 1.05 m aisle |
| Bedroom | 3.30 × 4.00 | 13.20 m² | 1.40 × 2.00 m bed, side route and storage |
| Bathroom | 2.85 × 3.00 | 8.55 m² | Complete sanitary fixture zone |
| Private distributor/storage | 2.85 × 5.15 | 14.68 m² | Bath/bed distribution and vertical fabric storage |

The radiator sits at the exterior east wall at x=15.40, z=-3.00, aligned laterally to `HEAT_STACK` through the explicit F02 heat branch. Its 0.90 × 1.20 m stance is west of the unit; its vent/control side stays clear of the bedroom, bathroom, threshold leaf, work surface, and bed route. Lena’s conversation stance is in the living/work room without crossing a private fixed-use zone.

## B1 boiler route

B1 is added at y=-3.20 m. The primary stair continues one storey down with the established 1.20 m width, 0.160 m rise, 0.285 m tread and 1.20 m landing. A 4.10 × 1.20 m lit service approach connects the core to a 6.15 × 11.00 m boiler room (67.65 m²), exceeding the 5.40 × 7.20 m program minimum.

`B1_BOILER_01` is centered at (12.45, -0.50) with its water-column/control face to the west. Reservations are: 1.50 m firing/tended front, 1.20 m water-column approach, 1.20 m retreat aisle to the 1.05 m self-closing threshold, 1.05 m ash/draft side, and 1.20 m pipe/flue side. The room connects directly to the heat stack, wet/feed branch, service power branch and a bounded flue riser. The only new B1 spaces are core/arrival, the approach, and boiler room.

## Intentional limits

No unrelated basement room, 2B biography, case symbolism, final furniture, or runtime director is authorized here. The schedule reserves legitimate physical owners and routes only; FirstShiftDirector and ServiceRoundDirector composition remains a later runtime-parity action after human spatial acceptance.
