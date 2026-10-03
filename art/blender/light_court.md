# Public light court, stair fit and skylight weather construction

Evidence class: **INERT**

The former 300 mm stair eye and closed public-core cap could not provide the
Bible's lobby-to-skylight eye. This bounded **ADAPTATION** widens that eye to
one metre within the existing public-core envelope. It installs fitted public
ironwork, landing guards, a ground-level court slab, local support frames,
pitched glazing and a source-fitted public-bulkhead weather cover. It does not
establish structural capacity, hydraulic capacity, complete weather closure or
human acceptance of the court's size. Heating apertures remain parked.

## Sources and repeatable construction

**art/data/orison_v2/vertical_services_source.json** owns the seven primary
stair dimensions and the public landing trims. **completion_interiors_source.json**
retains ownership of **B1_PUBLIC_LANDING_E**. **roof_source.json** owns the roof
landing, retained machinery deck and skylight opening. The existing three
authoring projectors produce **game/data/orison_v2_blockout.json**; no generated
layout or glTF is hand-edited.

| Native author | Saved source and runtime export | Installed owner |
|---|---|---|
| **build_light_court_stair.py** | **stair_ironwork_court.blend / .glb** | existing stair-ironwork mount; blockout retains treads, ramps and traversal collision |
| **build_light_court_structure.py** | **light_court_structure.blend / .glb** | **LightCourtStructure**, fourteen guards and two basement transfer mesh bodies |
| **build_court_roof_bridge.py** | **court_roof_bridge.blend / .glb** | **CourtRoofBridge**, native support collision |
| **build_roof_bulkhead_caps.py** | **roof_bulkhead_caps.blend**, original cap export and **light_court_skylight.glb** | retained **RoofBulkheadCaps** plus **LightCourtSkylight** |
| **build_roof_public_weathering.py** | **roof_public_weathering.blend / .glb** and construction JSON | **RoofPublicWeathering**, eight native draw/collision partitions |

All scripts are in **art/blender/scripts**; exports are in
**game/assets/props**. **art/data/roof_public_weather/source_plan.json** owns
weather adaptation dimensions. Portable construction fixtures live in
**game/tests/fixtures** and are explicitly INERT. Runtime reads only the
fourteen guard identity/bounds rows in **game/data/orison_v2/light_court_guards.json**.

## Fitted interfaces

Seven primary flights share origin **[1.4, -3.1]**, **1.05 m** flight width,
**1.00 m** eye, **1.20 m** half-landing, **285 mm** tread, **160 mm** rise,
ten risers per flight and **910 mm** stair guard height. The normal walking
centres are X **1.925 / 3.975 m**. The service stair and its original ironwork
remain unchanged. Original public ironwork remains available as a historical
asset; the new public assembly has four catalogue-mapped mesh partitions.

The eye at X **2.45..3.45 m**, Z **-1.90..-0.25 m** continues from the lobby
through the actual cap at **22.4 m**. A **200 mm** ground slab closes the soil
interface. Four B1 columns and two transfer beams seat beneath that slab.
Fourteen north/south landing guards have fitted feet and **1.05 m** envelopes.
West shaft platforms and six upper/ground west landing edges end at X **1.4 m**.
South/north platforms start there;
the east B1 landing begins at **4.5 m**. These are trims of named existing
owners, rather than new overlapping floors.

At the roof, the machinery deck ends at X **1.4 m** so it no longer occupies
the roof stair's headroom. **ROOF_PUBLIC_LANDING_E** spans X **4.5..5.4 m**,
Z **-1.90..1.65 m**, giving the roof circuit a **900 mm** clear east crossing.
Its **200 mm** slab rests at **19.2 m** on the local steel bridge; bridge
posts at X **4.625 m**, Z **-2.06 / 1.82 m** seat on the F06 slab at **16 m**.
The lift machine, suspension openings, guards and passenger-car authority
retain their owners.

Four skylight curbs seat on the **22.4 m** cap and rise to **22.68 m**. Four
copings carry real **4 mm** grooves; the weather apron/boots seat within them.
The tee frame carries six panes, each **6 mm** thick measured normal to its
sloped face, with **22.76 m** eaves and **23.16 m** ridge. The original
architectural glass and lamp/Dream optical consumers remain in place.

The public-bulkhead sheet is **1.2 mm** thick and falls **1% east**. A
four-facet **28 mm** cricket diverts the upstream field around the curb;
eighteen physical valley contacts are checked. A **50 mm radius** gutter
falls **0.5%** to its open outlet. The **76.2 mm bore** leader has three
fitted wall straps and ends at **19.225 m**, **25 mm** above the main-roof
deck. The downstream roof field and property connection are **OPEN**.

## Ground and dependent construction

**reconcile_light_court_ground_source.py** binds a thirty-one-box production
survey to the actual layout and checks each identity-basis collision box
against its authored owner. Thirty retained masks move and one court
slab mask is added, giving **900** classified retained masks. Six surface
exclusions move and the new slab receives one exclusion. Every old/new volume
stays inside the unchanged B1 public-core reservation. Transfer-mesh aggregate
bounding boxes are never used to subtract soil.

The scoped reconciler updates five source bindings and preserves all others.
It rejects rotated/non-box substitutes and stale inputs. Replaying the eight
dependent native exports preserves their exact oriented triangles, positions,
normals, UVs and tangents, independently compared with the immutable **619e883**
baseline. Only binding hashes and two floating-point area summation diagnostics
are qualified in that comparison. The ceiling upper closures and terrain are
intentionally regenerated: ground now has **248 partitions / 1,986 triangles**.
Their identity and triangle counts are not claimed unchanged. Ceiling upper
closures retain fifty-one source-owned partitions with **374 triangles**; all
original contact/underside stations and non-overlap checks remain in the suite.

## Mapping, inspection and verification boundary

New construction uses existing catalogue keys, metre UVs and generated
tangents. Flat per-facet mapping preserves sloped surface lengths; whole-tile
UV rebasing avoids float32 precision loss without changing texture phase.
Thin glazing and folded weather sheets use full-precision imports. No new
lettered texture, reference photograph, material family, global light or
replacement optical shader is introduced.

**tmp/shell-weather/canonical-native-review** reopens the actual saved sources,
records their SHA-256 values and renders fifteen directly reviewed native
views: stair two, structure three, bridge three, roof/skylight three and weather
four. Native checks cover four closed mapped stair groups, forty-four closed
structure groups, two bridge groups, ten caps/fifteen skylight groups and 270
closed weather construction pieces. Studio changes are never saved back.

Installed checks use the composed production root and the actual controller.
The court/weather test inherits the twenty-waypoint entry walk and checks
the guard feet, transfer seats, twenty-five aperture stations, six glass panes,
forty first weather contacts, forty retained cap contacts, valleys, grooves,
open leader and imported UV derivatives. Separate roof/vertical/basement
walks cover **53 / 79 / 88** waypoints. The full lift inspection covers nineteen
waypoints and 2,062 suspension-clearance samples. An initial lift return walk
failed; the diagnostic repeat and restored uninstrumented repeat passed. The
failed receipt is retained and no geometry/motion tolerance was relaxed.

The slab sweep caught three duplicate faces at the ground west/south landing
seam; six source-owned west edges now abut the south landing at **1.4 m**.
Six other first contacts are the native bearing flanges **8 mm** below their
seated slab interfaces. The suite checks each first bearing's native top seat
before excluding only that bearing for a separate named slab query, retaining
all 603 platform stations and requiring exactly six fitted foreground contacts.
The small cap partition beside the aperture uses a planar mapping check with
complete indexed triangles and all existing metre/basis/derivative tolerances;
the closed-duct helper's nine-vertex minimum does not describe that partition.
The earlier failed receipts remain available. The overhead diagnostic capture
also received an explicit Vector3 type after its first startup parse failure;
double imports expose and validate the complete inherited script chain.

The original cap stations, wall bearings and underside probes remain. Only
the two installed weather-cover bodies are excluded when measuring their
retained original cap underneath; independent weather checks require the
first actual physical hit. Court inspection hides the handheld with its
production capture toggle while preserving the carried lamp. Diagnostic
overhead camera aim does not represent a player route or add camera controls.

The lobby well has a visible skylight from the inspected eye station. Some
approach views are obstructed by slabs/walls; this does not prove an eye from
every lobby station or a broad atrium design. Weather surfaces still require
the later production-material pass. Each court run also writes six INERT
draw/object/primitive counter observations in **court-fit.json**, with startup
timing in its adjacent log. They are scoped observations; a matched before/after
frame-time benchmark and broader H23 lighting/residency acceptance remain open.
Captures and wrapper run receipts grant no completeness-ledger promotion.

The complete clean base is **tmp/shell-weather/619e883-clean-board.json**.
Twelve individually reviewed live references are appended to the spatial manifest;
all 6,392 prior rows and audit logic are retained. Before publication, the exact
named-path candidate must pass the in-place verifier, all 47 comparative gates,
NEW unread zero, protected 17/17, V2 default/explicit V1 rollback and the bound
court, roof, ground, resident-key, Mina and reconstruction suites. Its final
result belongs to **tmp/shell-weather/light-court-verified/verification.json**.

## Open continuation

Main-roof falls/outlets, residual courtyard drainage, street-main connection,
boiler-window operating glazing, farther city/weather closure and independent
bar/bodega/arcade service fit remain open. Structural/weather capacity and
full-shell readiness are not established. Heating distribution cuts stay
parked. The wider architecture, infrastructure and final surface task continues.
