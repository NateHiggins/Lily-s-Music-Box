# Vantry Arcade reconstruction — V3: frames, plaques, and the face

Built 2026-08-16 on V1+V2. Two halves: tenant differentiation at the
storefronts, and the daylight verdict on the street face the night
frames kept dodging.

## Storefront families

The authored fronts already carry per-trade body and accent materials;
V3 adds the tier the brief asked for — the metal the hand touches:

- **Bronze glazing families** for the leases that could afford them
  (druggist, funeral, pawn): bronze mullions, a bronze sill cap over
  the stall riser, a bronze head stop under the transom.
- **Nickel** for the newer signal trades (photo, radio); painted wood
  for everyone else, exactly as before.
- **Opal (acid-etched) transoms** for the druggist and funeral fronts;
  clear wired glass elsewhere.
- **An engraved brass tenant plaque** beside every door, on whichever
  side the door left free.

Bronze reads dark until it has light to work with — the flat-metal
lesson from the kitchen brass — so the glamour frame for these members
arrives with V4's showcase lighting, deliberately.

## The daylight verdict (01–03)

The V1 frontispiece composes from across the street: base (brick,
portal, lamps, kiosk), principal (engaged piers, the blind archivolt,
name band), attic. Two faults found and fixed in the same pass:

- Eleven spaced voussoirs read as floating crumbs with dark brick
  grinning through the joints → **sixteen oversized voussoirs** now
  overlap into one continuous stepped stone band.
- The parapet was a flat line → a **stepped center attic** with its
  own coping now crowns the axis.

Remaining honestly deferred: the upper wall's face brick renders very
dark under overcast (material grade, V5's aging pass), and the arch
tympanum could take a limestone field later.

## A test got more honest

PassageVisibilityTest went red mid-session with zero geometry cause:
it asserts the 03:00 grille composition but never pinned the clock, so
it followed the real wall clock — and the machine crossed 2 AM into
the 06:30–02:00 trading window. It now pins `DAYNIGHT=0` itself, like
PassageShot always has. The probe that found it also confirmed the
grille MultiMesh builds 1360 instances and the hours director's
registration is sound.

## Proof

Full Passage battery, LightingAudit and WalkTest FULL: **all PASS**
(visibility re-verified env-less after the pin). Passage northbound
**13.54 ms** at canonical pinned night; street elevation 25.80 ms —
still over its gate, as before the reconstruction (P1 territory).

Frames: `01_frontispiece_head_on`, `02_frontispiece_oblique`,
`03_portal_close` (daylight review, DAYNIGHT_FORCE=13:30 via
`VantryElevationShot.tscn`); `04/05` business-hours interior checks.

## Held code

`gen_layout.py` (V1 nave + V2 rooms/walls + V3 frames/plaques/arch/
attic) and `shop_interiors.py` (V2 borrowed lights, parted drapes)
remain uncommitted while the parallel session's W1 street wall is in
flight in the same file. Docs, renders, shot harnesses and test
contracts are committed.
