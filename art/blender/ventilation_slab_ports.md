# Ventilation slab interfaces — October 1

Evidence class: **INERT**

REPORT - V2 VENTILATION SLAB FABRIC - 2026-10-01

## Scope and authority

The source-led runtime survey found actual fabric in the otherwise hollow duct
airways. **tmp/vent-fabric-audit/runtime-overlaps-before.json** records 158
triangle/route-owner intersections across 77 structural draws and 419 first-hit
physics samples. These counts describe discovery, not requirements acceptance.
The selected structural owners include the actual rooms, service risers and
Blender exterior masonry; the duct's own collision and four fan bodies are
excluded from the survey. Nine sampled physics rays and an independent
triangle/airway-box intersection test complement the source slab audit.

This batch fits the vertical floor penetrations and roof horizontal height.
It does not close the remaining branch-wall, exterior-leaf or chase crossings.
The four motors, twenty-three register locations/rosters, schedules, bearing
sound, maintenance state and passive-grille authority remain unchanged.

**completion_interiors_source.json** owns the roof-branch drop and 27 explicit
floor/ceiling apertures. **build_v2_completion_interiors.py** projects them into
the existing layout and consumer graph. Each aperture is clipped to its declared
room's slab footprint; the north/east boundary ports are intentionally partial
in that room owner. **roof_source.json** retains its six terminal fan apertures
and extends the A roof-chase port down to **18.795 m**. No runtime JSON or
exported glTF is edited independently of its source.

## Fitted construction

The roof branch centre is now **18.895 m**, an **85 mm** drop from the previous
centre. Its highest 194 mm seam reaches **18.992 m**, **8 mm** below the existing
ceiling underside. The highest bathroom branch remains at **18.690 m**; its
sheet and seams retain separation from the roof run. A trial **140 mm** drop
merged two upper branch envelopes and failed the original sheet-contact checks;
that failed receipt remains in the discovery directory.

The existing blockout slab builder retains one stable render node/material per
surface and one floor collision body. Explicit aperture cuts partition those
surfaces. Ceilings remain visual-only, as in the original construction. Both
adjacent floor and ceiling surfaces must be opened, but receive one physical
lining: **27 surfaces → 15 sleeves**, at A **3**, B **5**, C **2**, D **5** storey
crossings. There are four geographic MultiMesh draws sharing one native mesh.

**build_ventilation_slab_sleeve.py** keeps twelve editable sheet pieces in
**ventilation_slab_sleeve.blend** and exports the single shared mesh. The lining
has a **196 mm** clear bore, **200 mm** outer width and **202 mm** height over
the 200 mm slab. Two **224 mm** square escutcheons cover the slab edge. Each has
4 mm thickness and a 0.3 mm worked arris. The bore clears the 194 mm seam with
1 mm on each side. These fittings add no collision, interaction, light or
simulation. Boundary wall/weather sealing remains in the next fabric batch.

The sleeve uses existing MatLib **metal**, one active metre UV channel and the
official Blender export hook for UV handedness. Its committed import metadata
retains full vertex precision. The original duct generator consumes the same
authored height, retains eight geographic draws and regenerates its closed,
manifold native sheet/seam partitions with metric UV derivatives.

## Inspection, checks and cost

**discovery-before.log.receipt.json** binds the production discovery. Its four
views were inspected directly: the two upper branch views show slab intrusion;
the close floor views are obscured by retained shower/lavatory fixtures and
are not visual proof of concealed penetrations. Matched after views and the
throat/roof/second-floor views remain under **tmp/vent-fabric-audit**. The warm
carried lamp retains energy **6**, range **16**; no fill light or global material
change is used. Geometric and physics checks establish the concealed slab fit.

All four matched after views and nine refined throat/roof/branch views were
inspected directly. The independent repeated structural trace reports **118**
route-owner triangle intersections across **48** draws, **399** sampled first
physics hits, and **zero** remaining floor/ceiling intersections within its
sampled 150 mm airway volume. Remaining wall/chase/exterior intersections are
explicit open work. Orange masonry remains visible beside the A/C roof airways.

**throat-refined.log.receipt.json** completed with **398 checks**, all **23**
register ports, **8** duct draws and **13,806** imported duct triangles; zero
failures. It independently checks actual slab triangles, owner-filtered floor
physics through each port, retained floor collision beside every port, ceiling
collision ownership, original branch sheets, the longer roof uptake, sleeve
deduplication and imported UV/normal/tangent derivatives. Owner-filtered rays
prove the selected slab only; they do not bypass the open whole-wall route claim.
The sleeve has **528** triangles, **103,185-byte** native source and
**59,840-byte** GLB. Fifteen instances reference that one mesh. The regenerated
duct native source is **555,990 bytes**, GLB **1,633,256 bytes**, compared with
**557,914 / 1,647,060** in the previous roof batch. Source anchors and existing
branch supports are retained. Matched discovery startup observations
**18,927.150 → 19,335.654 ms**, with a focused **19,223.041 ms** observation,
are single samples, not stable FPS or performance acceptance.

## Binding and continuation

The complete clean baseline is **tmp/bodega-power/9b68818-clean-board.json**,
at published **9b68818220600f839468cae1d37342830cd67faa**. Final candidate
verification is **tmp/vent-fabric-audit/verified/verification.json**: published
**8eb96c7faa1c2d5e112e5871fe48181c6acd5166** passed its complete 45-gate board
and eight candidate-bound windowed suites. It recorded zero blocking findings,
zero new unread fields, zero board regressions, **17/17** protected paths and
unchanged requirement statuses. Require zero new unread fields, zero board
regressions, protected paths **17/17**, V2 default/V1 rollback, unchanged
requirements and owner capture bytes/absences. Wrapper receipts and images grant
no runtime-contract or completeness-ledger status. No gate or spatial-audit
heuristic is weakened.

Continue actual branch-wall/chase/exterior crossings, sleeves, bearing and access
checks. The bar, bodega and arcade keep the owner's independent-building-service
choice. Heating, water/drain, power, communications and the six location queues
remain open. Raw architecture, infrastructure, mapping preparation and final
material/render polish retain separate states.
