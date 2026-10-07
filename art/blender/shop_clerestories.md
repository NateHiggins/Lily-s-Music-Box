# Source-owned shop clerestories

Evidence class: **INERT**. Fabrication guide, not whole-shop acceptance.

Eleven original borrowed-light outlines supply 89 source records: 55 trim
members, ten glass boxes and 24 adjoining plaster records. The funeral wall
retains its chapel aperture and lintel. Photo retains its accepted 6mm pane.

**build_shop_clerestories.py** makes 342 closed stocks, 32 material partitions
and 60,216 triangles. Exact retirement removes 1,068 source triangles. Ten
30mm glass boxes become 6mm sheets at their original centres and width/height
envelopes. Split muntins, jamb stops and beads meet both sheet faces. Sill and
head bearing planes remain. Existing painted trim, plaster and glass maps
remain. The registered public **Glazing** shader is a local per-cell override
with .06 roughness; shared materials remain owned by their catalogue.

Replacement plaster has real rebates around the sill/head, retained party
wainscot and funeral chapel lintel. A grid boundary mesh makes each wall stock
one closed volume without internal faces. The 251 contacts include floor,
jamb, wainscot, brick and reciprocal accepted-fixture bearings. Photo rail
packer samples sit 10mm beside the screw axes. Four accepted portrait-rail
rods retain their original 2mm radius and 6mm embedment; only those bounded
cylinders are admitted. Other penetrations refuse. No layout is hand-edited.

**inspect_shop_clerestories.py** updates linked-object transforms before BVH
checks. It checks positive closed volumes, connected assemblies, metre UVs,
exact retirement, bearings and intersections against 50 context families.
Native contact rays start inside the 6mm rebate to avoid its opposite face.
A full preflight without rendering precedes eleven isolated and eleven room
views. Isolated Photo views omit its separate pane; room views include it.
Native glass is an approximation; production remains the optical authority.

**OrisonV2ShopClerestoriesTest** runs in the shared fabrication world. It checks
physical triangles, materials, contacts, retained Photo asset binding, sheet
envelopes, optical ownership, empty plaster rebates and sill/head bearings.
Passage residency checks every new owner after unload/reload.

Runtime contacts use a near start and long ray to resolve small triangles.
New native owners retain a 30-micrometre limit. Retained V1 draws additionally
allow one XYZ encoding step, their mesh-bounds diagonal divided by 65,535.
Eleven retained contacts differ from ideal source coordinates by up to
0.107mm; actual imported triangles confirm the same offsets. Each measured
offset and computed budget is recorded. Legacy imports remain unchanged.

Retained masonry beyond these lights, rear connections, useful daylight,
services, weather capacity and human acceptance remain separate. This family
adds no traversable opening and grants no whole-shop acceptance.
