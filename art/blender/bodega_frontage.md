# Fitted bodega frontage

Evidence class: **INERT**

Classification: **ADAPTATION**. This closes demonstrated gaps in the existing
shopfront and fills the original door's lower timber field. It does not accept
the entire shop shell, utility network or material family. Heating cuts remain
parked while the broader geometry and texture work continues.

## Source and construction

**art/data/bodega_frontage/source_plan.json** supplies the fitting dimensions.
**scripts/build_bodega_frontage.py** reads the actual exterior template, region
registration and unchanged **door_prop.gd** storefront builder. Three diagnostic
casts previously crossed empty bands above the display panes and central
transom. The existing 950 by 2,100 mm inward leaf also had no lower render infill,
despite its existing full physical box.

The saved **bodega_frontage.blend** contains **68 closed positive pieces**:
67 fixed frame, bead and upper-light stocks plus one raised leaf panel. The
installed export contains **three draws / 1,280 triangles**. Exact planar
subdivision omits **1,590** paired or buried contact cells, including partial
contacts with the original panes, piers, head, plinths and sill. Individually
closed native counterparts remain editable. Bounds are rounded in the authoring
source before grid construction, preventing floating-point sliver faces.

Two fixed imported surfaces receive matching triangle collision. The new panel
attaches inside the original hinged body's existing physical box and has no
second collider or input owner. The retained inward hand, 168 degree travel,
hardware, keys, lock state, shop hours, stock, independent services and saves
remain. Existing noncolliding window bars are replaced visually by fitted jambs.
The three original pane solids and physical owners remain; their local material
overrides use the already established clear dielectric shader.

Finished jamb clearance is **975 mm**, leaving **12.5 mm** beside each side of the
retained 950 mm leaf. This is the physical opening; the broader semantic threshold
reservation remains a separate source record. The frame's rear plane is at
**-15 mm** and its front at **85 mm** in the original shop coordinates. Its upper
lights are 6 mm thick. The raised lower panel stays within the retained moving
box at every pose; its 18 mm stock has a 28 mm rim, 9 mm bevel and 2 mm relief.

## Materials and inspection

The fitting reuses catalogued **oak_quartered**, the original leaf tint and
**0.8** scale multiplier. Each stile, rail and panel has metre UV charts with
texture V along its longitudinal grain. The local material duplicate receives
the existing albedo, roughness and normal maps with unchanged normal strength;
the shared MatLib projection remains intact. Blender images use relative paths.
The three loose GLB texture extracts are ignored import products. No new key,
bitmap, global shader or lighting change is introduced.

Saved-source inspection reopens the actual Blender file, checks all 68 closed
volumes, analytic bounds/volumes, map paths and source hashes, and renders three
views. Retained fabric and the original leaf carcass are temporary read-only
context and are never saved into the asset. The portable fixture binds
LF-normalized source bytes and the installed export hash.

The installed focused check passes **1,460 checks**, including **1,236** actual
exposed-face contacts, strict imported UV/tangent derivatives, three closed
former gaps and **57** original physical leaf poses at three degree intervals.
Ten same-camera before/after captures retain the production lamps. Their visible
draw counts are observations rather than frame-rate or weather-capacity proof.
Normal storefront and receiving walking checks are bound by the final candidate
verification in **tmp/bodega-frontage/verified/verification.json**.

Initial failures remain in **tmp/bodega-frontage**: the first test encountered an
incorrect name lookup and reached the runner ceiling without a verdict. The
runtime now uses the exterior owner's actual record metadata and rejects a
missing fitting. The next completed test recorded 732 short-ray misses. Godot's
**Geometry3D::segment_intersects_triangle** uses an absolute determinant parallel
threshold; small subdivided faces need longer segments. The final test retains
the 3 mm outside start and extends only the inward end in proportion to actual
triangle area. All required owners and the **50 micrometre** hit tolerance remain
unchanged. The same geometry then passes all contacts; no face was excluded.

## Management report

REPORT - BODEGA FRONTAGE - 2026-10-03

Branch / HEAD / origin/main / merge-base: canonical **main**, named-path candidate
over **036b2e478c03f567f7f39cdf220f30e7cd81db90**. Exact publication identity and
cleanliness belong to the bound report. Protected 17/17, default V2 and explicit
V1 rollback are enforced by the verifier. Ledger baseline **[7, 8, 127, 42, 151,
153]** is not promoted by this INERT record. All 47 gates compare with the complete
clean **tmp/roof-field/036b2e4-clean-board.json**. The reader gate requires zero NEW
unread fields, and the spatial audit requires no new failing or stale records.

Changes outside the asset/runtime/test boundary: hash attributes, three exact
derived-image ignore entries and documentation. Original shell, door builder,
material catalogue and source exterior data remain unchanged.

Open findings: shop-shell composition and broader material review, coordinated
main-roof falls/outlets, downstream drainage, court/street-main closure, remaining
independent shop service routes and broader city fabrication. Decision needed
from owner: none for this bounded fitting. The verifier determines publication.
