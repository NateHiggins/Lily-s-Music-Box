# Fitted hand-laundry apparatus

Evidence class: **INERT**

Classification: **ADAPTATION**. The Model Laundry source in
**art/data/shop_interiors.py** owns two tubs and rims, a timber hand wringer,
its rubber rolls and crank, an iron heater, four flat irons and two five-lath
drying racks. The 23 original identities, material keys and source envelopes
remain in the editable native. Shop authority, stock, keys and hours retain
their existing owners.

**scripts/build_laundry_apparatus.py** makes 142 individually closed stocks
in ten assemblies: hollow tapered zinc basins with rolled rims and low metal
stands; a timber wringer with opposed rubber rolls, bearings, integral gears,
pressure screws and a crank; an iron heating plate on a braced stand; pointed
flat irons with curved handles; and drying laths, crossmembers, ceiling plates,
pulley wheels and terminated rope loops. The export has 18 bounded material
partitions and 32,980 triangles. The native retains all 23 original boxes.

The wringer is a declared form adaptation. The original separated roll boxes
become opposed rolls centered at 0.965 and 1.105 metres; the pressure yoke
reaches 1.288 metres. The period mechanism is informed by the cooperating
rolls and pressure frame in the [1924 US1488884A patent](https://patents.google.com/patent/US1488884A/en).
No reference photograph is projected, baked or committed. The apparatus is
static: a working wringer release, gas supply, water supply and airer controls
are open work. The rope loops retain the authored rack height and terminate
in its crossmembers; they do not claim an operating hoist.

The tubs have a 3-mm wall and an open cavity above an inner bottom at 0.373
metres. Their stands bear on the existing 0.01-metre floor. The heater plate
meets the four iron soles at 0.75 metres. The drying-rack plates meet the
existing 3.3-metre ceiling. Twenty-four external contact samples accompany
the construction record; this establishes contact, not structural capacity.

The new **iron_blackened** catalogue entry supplies a local bare-iron finish
for these irons, heater and wringer hardware. Its code-authored periodic maps
describe fine casting grain and oxide, with a 0.4-metre tile and 0.08-mm normal
relief. The older painted-radiator **cast_iron** maps are retained elsewhere.
All previous 60 runtime definitions and 15 visual locks remain unchanged.
Zinc, metal, timber and rubber retain the original shop shipping variants;
rope uses the existing locked **linen**. Each material is cloned locally.

The shared fitter removes only the 276 exact original box triangles. Import
can retain two metal draws with different collision suffixes, so the fitter
checks both names and changes only a draw that owns a removed boundary.
Remaining serialized vertex attributes and material slots stay identical.
Physical boundaries use the same fitted triangles as the visible export.
Both initial Passage mounting and streamed reconstruction apply the fitter.

The surface conversion now transfers imported UV scale and offset. Native
metre charts therefore reach the layered retail shader at their declared
physical tile scale. Identity transforms, triplanar projection, calibrated
architectural relief, surface state ownership and the carried lamp remain
unchanged. **SurfaceUvTransformTest** compares rendered identity and transformed
checker samples, including nonuniform scale and nonzero offset.

**scripts/inspect_laundry_apparatus.py** checks source and map hashes, closed
positive stocks and connected assembly contact graphs and renders fourteen
native views. **OrisonV2LaundryApparatusTest** checks exact source trimming,
literal other attributes, imported charts and tangents, local material maps,
collision, contact samples, hollow basins and standing-capsule detail views.
These inspection reports and images do not grant runtime ledger promotion.

Other shop machinery, building services and the broader geometry and texture
review remain open; this document does not claim completion of that work.
