# EN-2 — the weld is the portal

"Impossible molten golden hyperdimensional shifting interplanar dimensional
welds that work like portals." Built 2026-08-22 on EN-1b.

R6 already keeps **one bounded shared-world camera** awake at the breach
(`DreamViewPortal`: 384 × 672, shares the World3D, excludes the wound's own
presentation layer so recursion depth is provably zero) and feeds its
texture to the wound. EN-2 gives the same feed to every molten surface:
`DreamMazeRoot._push_portal_to_welds` pushes `portal_view`, `portal_live`
(R6's phase while its view is useful, 0 when it sleeps) and the breach's
frame (centre, side, up, half extents) each frame, and the Klimt surface's
weld layer maps the live view in that frame, spread `portal_spread` 2.6×
over the lesion, inside the bead's core. No second camera, no new space,
no new rule about where the player can go: the seam around the lesion
shows the place the wound already shows, and the reflected-world plate
stands in wherever R6 is asleep or absent.

## What it found

The probe's portal rule never opened on the seam: the bead sits on the
drive contour 0.24, where the local gold phase is zero, while the rule
asked for phase past 0.55 — true only deep inside the lesion. The weld now
opens on **R6's own wakefulness at the breach** (`portal_live`), or by the
local rule where a pocket has no R6. And the view needed toning (× 0.5):
R6's camera carries a 3.2× exposure for the wound's dark aperture, which
in a molten seam read as a white line.

## Frames

`sheet_en2_portal.jpg` — the EN-1 stand at full exposure with R6 awake
(`DREAM_PORTAL_TRACE=1`: `phase=1.000 visible=true`): the wound's aperture
at left, the lesion, and the weld ring whose core now carries the live view
behind the heat (8× crop at right). `00/02/04_klimt_*.png` are the
shipping surface at the three states.

Cost at this stand: 04 high 5.2 ms with R6 awake (the SubViewport renders
the destination room each frame — R6's known aperture-facing price), 2.1 ms
with it asleep; latent 2.6, mid 2.1. Contracts: Atlas, Hazard 42, Lineage,
RoomBuilder, Surface Target 105, Incarnation — all PASS.

## Not done

- The weld vocabulary does not yet place R6's camera (it keeps R6's own
  bounded pose from the viewer); a drift of the destination pose along the
  seam's flow is the next taste row.
- The ornament is still computed under the layers (perf row: trim the
  Klimt ornament where flesh/skin cover it).
