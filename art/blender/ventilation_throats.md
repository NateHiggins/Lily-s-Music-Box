# Ventilation sheets and fitted roof throats

Evidence class: **INERT**

## Scope and construction authority

The installed graph in **completion_interiors.json**, V2 layout levels and
existing register/fan anchors own all four routes and their 23 registers.
**build_ventilation_ducts.py** constructs continuous 2 mm sheet shells around
the existing 180 mm sections, open register plenums and seam shoes. The eight
material partitions replace eight box MultiMesh draws. Existing outer collision,
65 branch supports, register acoustics, motor schedules and saved state remain.
The editable **ventilation_ducts.blend** retains every construction volume and
airway cutter. The generated GLB is never edited by hand.

The existing ventilator generator now makes a hollow 200 mm square curb throat
inside its unchanged 720 mm footprint. The flashing's 176 mm aperture laps the
180 mm duct's 2 mm walls. The uptake seats at the 169 mm flashing top. Housing,
rain hood, motor/guard, panel, rotor and shutter pivots remain their original
geometry/authorities; V1 is unchanged.

**roof_source.json** explicitly owns four 200 mm deck ports, matching lower
ceiling ports over the north bathroom and restricted southeast room, two
200 mm west-chase bores and the west fan A terminal chase connection. The
roof projector adds these bounded structural records without changing room,
door, window, slab datum or fixture identities. Each Floor/Ceiling retains one
render owner and the original collision node path; its physical pieces omit
only the declared aperture. Chase masonry remains beside the two bores.

The old roof source was missing fabrication metadata for 27 already-installed
tank/coping fixtures. Reprojection initially removed their bindings. Those
exact existing fields are now preserved in the authoring source, with a
regression check for installed-fixture preservation and first-table round trips.

## Mapping preparation and measured cost

Every exported sheet vertex has active metre UVs, a unit normal and tangent.
Boolean joints are conditioned at 5 micrometres; zero-area and ill-conditioned
triangulation diagonals are dissolved without moving the shell boundary. The
generator checks that all eight partitions remain closed manifold sheets.
Double-precision geometric normals define the UV planes. A Blender exporter
hook authors their analytic planar derivatives before serialization; this
avoids MikkTSpace zero tangents at very narrow junction corners. An independent
test derives direction/handedness from the actual imported triangles and UVs.

The new asset's committed import settings disable vertex compression: the
default shifted seam vertices by up to 0.22 mm across the full stack bounds.
Importer precision now preserves the original fitting dimensions and metre
mapping; the measured UV excess is at most 1.91 micrometres. Other assets'
import settings remain unchanged. This canonical-checkout verification does
not establish fresh-checkout or autocrlf behavior.

The duct GLB is **1,647,060 bytes**, its editable source **557,914 bytes**.
The refitted fan GLB is **1,572,056 bytes**, up from **920,844**; its editable
source is **311,921 bytes**. There are **13,930 imported duct triangles**,
eight duct draws and eight retained hanger draws. This is physical sheetwork,
not a new simulation. Startup observations are **19.693 / 19.426 s**; these
single samples establish no stable FPS or rendering-budget acceptance.

## Rendered inspection and scoped checks

**tmp/roof-throats/before-lit** and **after-final** contain matching roof and
inside-throat views of all four machines. Inside views use the unchanged
carried warm lamp and are impossible player stances intended for assembly
inspection. They add no fill light and claim no continuous traversal. All four
before inlet plates and after sleeves were inspected directly. The last D
view is darker; the imported triangle and physics probes provide its fit
measurement. The second-floor branch view is separate room-level discovery.

**OrisonV2VentilationThroatTest** provisionally passes **247 checks / 23 ports /
8 partitions / 0 failures** in **throats-final.log.receipt.json**. It checks actual
register mouths and side sheet, seam/corner/stem/roof lumen continuity, active
mapping and UV derivatives, flashing beside each port, real deck/chase physics,
retained deck bearing and every authored slab cut. These are static geometric
claims, not proof of airflow through every intervening building component.
No runtime-contract or completeness-ledger promotion follows from the captures
or wrapper receipts. Fan operation, hanger contacts, continuous roof movement,
city composition and apartment lifetime require their own bound suites.

Failed discoveries remain under **tmp/roof-throats**: the first import command
passed its arguments incorrectly and reached its ceiling without a verdict;
the first production run found the missing fixture bindings and seam caps.
Later mapping runs exposed compressed fitting vertices, collinear triangles,
zero weighted tangents and UV conditioning. Corrections change source geometry
preparation and preserve all imported-fit requirements. The final independent
export check and production geometry run pass. Timer settlement is scoped only
to optics/retired audio; no audit or systemic baseline is weakened.

## Gates, binding and remaining networks

The complete clean baseline is **tmp/heating-attachments/b893fc4-clean-board.json**.
The precommit board reports zero regressions, reader NEW **0** and unchanged
ledger counts **[7,8,127,42,151,153]**. Four individually reviewed test references
extend the spatial manifest from **6,338** to **6,342**; all prior records and
heuristic classifications remain. Final candidate binding belongs to
**tmp/roof-throats/verified/verification.json**. Published on canonical main as
**72b3033117058f17c480bb43092e510c79de7b8e** after all seven bound windowed suites
passed: throat **247**, hanger **395**, roof ventilators **4 machines / 4 actuations**, ventilation **23**,
roof route **51**, city **1,253 / 450 contacts**, apartment batch **20,315**;
zero failures. The complete clean next baseline is
**tmp/roof-throats/72b3033-clean-board.json**. Its comparison has zero regressions,
no requirement changes and no new unread fields. These scoped checks do not
complete the remaining fabric/network work below.
Protected paths **17/17**, selector V2/V1 rollback, keys/copies/door locks,
News Cigars initial unlock and owner capture absences remain required.

The sheet airways and terminal ports do not prove every concealed penetration.
Continue north/east masonry sleeves, remaining branch fabric interfaces and
supports/access. Neighboring fabric remains visible at the side in the inner
shaft discovery views; full envelope clearance is still a separate trace.
Heating, water/drain, power and communications distribution remain open.
The owner's October 1 choice gives the bar, bodega and arcade buildings
independent incoming services and local plant; no Orison cross-feed is implied.
All six location buckets retain their separate raw architecture, infrastructure,
mapping-preparation and final-polish states in the production map. This batch
closes none of those phases.
