# V3b — the street respacing, and the bug it uncovered

Owner direction 2026-08-16: "space the arcade on the street better, move
the subway exit and whatever else makes sense." Measuring the flank to
answer that found a real defect, not just a proportion problem.

## The defect

V3's frontispiece and K1's subway kiosk were **interpenetrating**:

| element | x span | source |
|---|---|---|
| frontispiece east pier | 17.45..18.05 | V3 |
| ...its base oversail | 17.39..**18.11** | V3 |
| ...its cap oversail | 17.37..18.13 | V3 |
| kiosk plinth | **18.10**..19.75 | K0/K1 |

10 mm of shared x, 620 mm of shared y, 160 mm of shared z — two limestone
masses occupying the same cubic centimetres, with a 50 mm air gap above.
Nobody saw it because every previous frame of that corner was shot at
night, where a 50 mm reveal between two limestone masses reads as one
lump. It was found by arithmetic on the flank, not by looking.

The cause is a stale clearance: K1 measured its 1.10 m of clear pavement
from the **bare portal** at x 17.00 in a world where nothing projected
from the face. V1/V3 then built the frontispiece into exactly that
clearance. Neither phase was wrong on its own.

## The fix

The east flank holds 2.47 m between the cap face (18.13) and the approved
20.60 stage edge. A 1.65 m kiosk centred in it gives balanced reveals:

```
frontispiece cap | 0.42 m | KIOSK 18.55..20.20 | 0.40 m | stage edge
```

0.42/0.40 reads as an intended gap; 0.05/0.85 read as an accident. Moved
with the kiosk: its eight-riser stair (18.85..19.90), the registered
`GROUND_HOLES` entry, the pavement cut that opens the earth for it, and
the K0 east approach light (19.88 → 20.33).

**Not taken:** the kiosk proposal's own documented remedy for an
east-strip conflict is to mirror it into the larger west residual strip.
The west run is reserved for the parallel street-wall session's W3
shopfronts, so taking it would have solved our problem with their space.

## The guard rail earned

The assert no longer only checks containment — it checks the *reveals*,
so this returns as a build failure rather than a render nobody questions:

```python
assert kx0 - FRONTIS_CAP_E > 0.30, "subway kiosk crowds the arcade frontispiece"
assert 20.60 - kx1        > 0.30, "subway kiosk crowds the east stage edge"
```

## Proof

`gen_layout.py` clean; 8/8 GLBs; PassageOwnershipAudit, PassageVisibility,
PassageNav, PassageHours, PassageFinish, LightingAudit,
StreetContainmentTest and **WalkTest FULL** all PASS on the moved kiosk —
the collision owner, the street route and the zone gate all survive it.

Frames: `01_frontispiece_head_on`, `02_frontispiece_oblique`,
`03_portal_close` (daylight) plus the full K0 seven-view gateway set
re-shot at the new position.

## Still open on this corner (not mine to fix)

The kiosk footprint overlaps the parallel session's in-flight W1 flank
wall band (x 17.35..20.60, y −28.42..−27.92) in plan. That predates this
respacing and is unchanged by it; it belongs to whoever reconciles W1
with K0/K1. Flagged, not touched.
