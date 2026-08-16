# Vantry Arcade reconstruction — V1: the nave raised

Built 2026-08-16 under `design/VANTRY_ARCADE_RECONSTRUCTION_BRIEF.md`
(owner commission: the Windsor Arcade idea at its 1926 maturity). V1 is
the architectural body of the hall; shops-as-real-rooms, storefront
families, the lighting hierarchy, evidence of use and the sanctioned
abnormalities are V2–V6.

## What stands now (all generator-owned, `gen_layout.py`)

- **The section grew from a 5.55 m shed to a 9.90 m nave.** Continuous
  limestone entablature over the storefronts at 3.55; a plaster
  clerestory order above it on each side's own party rhythm (the two
  faces disagree the way two rows of leases do), stepped-head clerestory
  lights with soot backing (dark until V4 lights them); limestone impost;
  the faceted glass barrel resprung at 7.20 with finer facets, arched
  iron ribs, gutter beams and a ridge.
- **The crossing event.** A stepped glass-and-iron lantern breaks the
  vault at mid-hall (≈11.5 m), with transverse glass diaphragms, corner
  posts and a stepped cap — and the four-faced milk-glass pendant clock
  hung at 5.9 m over a brass-and-terrazzo floor medallion. Moonlight
  through the lantern falls onto the vault in the night frames.
- **An axis with a destination.** North: the throat is a vestibule now —
  coffered lid, mosaic threshold band with a brass edge exactly on the
  expansion line. South: the terminating frontispiece — stepped gable,
  lunette (soot-backed; one day lit from a room that cannot exist),
  paired limestone pilasters and the building directory, all held within
  0.24 m of the wall so the x=14 schedule spine stays capsule-clear.
- **Dark terrazzo borders** down both aisle edges, collision-free by the
  new `nocol` contract in `build_orison.py` (floor inlays render without
  a trimesh, same law as the wear decals).
- **Pendant stems** for the eight existing aisle bulbs — ids, positions
  and the light budget untouched; they simply stop floating.
- **The street frontispiece** (same gateway proxy batch, zero new
  materials): engaged limestone piers with caps and urns, an eleven-
  voussoir blind archivolt rising two storeys into the upper wall,
  keystone, spandrel medallions, crowning cartouche; the middle three
  upper-wall window bays yield to solid masonry so the arch lands on
  wall, leaving two fenestrated wings.

## Proof

| check | result |
|---|---|
| `gen_layout.py` self-audits | clean, 333 walls |
| Blender rebuild | 8/8 floors exported |
| PassageHoursTest / Nav / Visibility / OwnershipAudit / Finish | **all PASS** |
| LightingAudit | PASS (127 spaces) |
| WalkTest FULL (x8 / 480 Hz) | **PASS** — every probed route survives |
| Passage northbound, canonical pinned night | **13.03 ms** vs the accepted ≈17.8 ms blocker |
| Passage throat reveal / southbound | 9.72 / 10.31 ms — under the 16.6 gate |
| street elevation | 27.50 ms — over, as before V1 (P1 territory) |

The northbound number is the headline: the clerestory walls occlude
foreign street draws that the old low shed let through, so the
reconstruction *paid for itself* — the station that M0.5 accepted as a
measured blocker now passes the 16.6 ms gate with margin. (Same noisy
machine; judge by the recorded run.)

## Frames

`01_street_portal` … `04_hall_north` are the canonical PassageShot
stations; `gateway/*` are the K0 seven-view set. All are canonical night
(DAYNIGHT=0) — the clerestory order, vault, lantern shafts, pendants and
inlays read in 03/04. The exterior frontispiece needs a daylight pass to
be judged and gets one with V3.

## Coordination state at build time

`art/data/gen_layout.py` also carried the parallel session's uncommitted
W1 street-wall upper storey (STREET_WALL_PROPOSAL) while V1 was built:
the two change sets integrate (V1's centers filter clears the middle
three bays *for* the frontispiece and keeps W1's wings) and every test
above ran against the combined tree. The V1 generator hunks and the
regenerated JSONs/GLBs are held out of the V1 docs commit until W1
lands, so neither session publishes the other's half-finished work.

## Reproduce

```powershell
cd art\data; python gen_layout.py; cd ..\..
cp art\data\*.json game\data\
& "C:\Program Files\Blender Foundation\Blender 5.2\blender" -b -P art\blender\scripts\build_orison.py
C:\devkit\bin\godot.cmd --headless --path game --import
$env:SHOT_DIR=(Resolve-Path 'art\renders\vantry_arcade_v1').Path
C:\devkit\bin\godot.cmd --path game res://tests/PassageShot.tscn
```
