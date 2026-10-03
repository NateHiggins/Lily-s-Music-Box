# Bodega receiving room

Evidence class: **INERT**

The existing labelled delivery aperture ended in a noncolliding floor hint.
The actual walk to local Z **-11.65 m** fell **0.829 m** below datum in
**tmp/city-architecture/bodega-delivery-before-2.log.receipt.json**. This batch
adds a small room within the retained east-building envelope. Deliveries use
the existing storefront and sales aisle; no external rear route is authored.

**build_bodega_receiving.py** derives the 4.4 m width, floor end at **-10.54 m**
and 1.05 m delivery aperture from **exterior_geometry.json**. The inferred
receiving depth is **2.00 m**. Floor top remains zero; foundation is 0.30 m deep,
side walls 0.14 m, back wall 0.16 m, ceiling underside **3.15 m**. The retained
city mass begins above that ceiling. A fixed bench sits outside the incoming
capsule lane. Jambs sit outside the original clear opening. Small worked edges
use at most 3 mm bevels. Editable **bodega_receiving.blend** retains separate
parts; **bodega_receiving.glb** exports six material partitions, about 109 KB.

The source uses metre UVs, applied transforms and exported tangents. Runtime
keys **brick**, **terrazzo**, **plaster_stained**, **wood_dark**, **cast_iron** and
**porcelain** all map through MatLib. Godot checks active UVs, normals, tangents
and actual mapped albedo textures on every partition. Final material polish
remains open, including the existing shop's flat stock/display masses.

**orison_v2_bodega_receiving.gd** mounts fixed meshes and matching collision in
the registered shop frame. **OrisonV2ExteriorCell** remains owner of the moving
leaf, practical, shop simulation and counter. Five old noncolliding hint/reveal
boxes are removed. The existing delivery light moves onto a supported stem and
shade, keeping its colour, 0.78 energy and 3.2 m range. The small visible bulb
uses local emission from that same colour; there is no additional light owner.

The corrected **back_room_threshold** is local **(0.65,0,-10.56)**, facing rear.
Its 1.05 m by 2.25 m aperture contains one 0.95 m by 2.10 m service leaf, east
hinge, swinging into the receiving room. The existing DoorProp owns its swept
volume and input. The floor joins at datum zero with no duplicate slab. The
shop region includes the back wall at **-12.70 m**; public route nodes and shop
state retain their existing records. Internal route placements resolve through
the same semantic resolver. The room remains resident with the bodega.

**tmp/bodega-receiving/route1.log.receipt.json** records 30 actual waypoints,
zero failures, six receiving-owned structural rays, mapped-export checks,
ordinary input from both sides, inside closure/reopening and the return to
Orison. The same counter cannot supply the hardware shop's part or mutate the
shared job/inventory. No interstage teleport or manual door pose is used.
The scratch prototype pass is discovery only. Final candidate binding is
recorded in **tmp/bodega-receiving/verified/verification.json** for the verified,
pushed **7c2e35825df0b3827134739ac3c1c97448f4e3ec** implementation. All seven
requested suites passed; zero static regressions, reader NEW **0**, protected
**17/17** and selector **v2** with explicit V1 rollback were checked. The complete
clean next baseline is **tmp/bodega-receiving/7c2e358-clean-board.json**.

Before views are **tmp/city-architecture/bodega-delivery-before**. Production
after views in **tmp/bodega-receiving/views** were inspected directly, including
the bench/floor, supported practical/ceiling and closed leaf. The scratch camera
hides the device and moves the real observer for existing residency/light rules;
it proves no traversal. The real route's device partly occludes its right view.

Paired public-view samples use the previous city census and the same cameras.
Mesh count **11,401 → 11,406** includes six receiving partitions, the new moving
door and removal of old hints. Startup samples **19.97 → 24.04 s**; frontage
draw counters **30,598 → 33,663**, process **286 → 134 ms**; sales-floor draws
**26,768 → 29,344**, process **149 → 153 ms**. These single-frame multipass
samples vary with residency/light scheduling and are not stable FPS or a
performance acceptance claim. No global lighting or pipeline feature changes.

Two new spatial records were reviewed individually: generated mesh-owned
collision names and registered-frame structural test probes. The previous
6,313 manifest records and audit logic are preserved. Reader has zero new
unread fields. Shopfront/glazing detail and physical utility distribution
remain open; this receiving connection does not finish the bodega bucket.
