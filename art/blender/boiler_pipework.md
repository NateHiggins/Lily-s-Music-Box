# Boiler steam feed, equalizer and discharge

Evidence class: **INERT**

The prior steam takeoff ended above the boiler without reaching the building
shaft. The low return was buried inside the fabricated casing; the relief
outlet ended as a tilted cylinder. This batch connects those visible fittings
with hollow Blender tubes, curved elbows, socket bands and fitted supports.

**scripts/build_boiler_pipework.py** reads the boiler anchor, control stance,
basement elevation and heat-shaft rectangle from the production layout. It
reproduces **boiler_pipework.blend** and
**game/assets/props/boiler_pipework.glb**. The export contains 25,920 triangles
in two finish meshes, approximately 1.65 MB. Inner tube walls are 5 mm thick;
UVs use physical metres. Existing **cast_iron** and **metal** catalogue finishes
are retained. No bitmap or material key is added.

The header joins the existing takeoff and runs to the heat shaft through a
wall sleeve. Three ceiling hangers support its exposed run. The equalizer
stands outside the boiler casing, returns into the lower casting, and has
two casing brackets. The smaller discharge runs from the existing safety
valve over the top and down the rear, with two brackets and an open outlet
above the hearth. Socket bands cover the component joints.

**orison_v2_boiler_pipework.gd** mounts the two meshes in the registered
building frame and derives collision from their exported triangles.
**BoilerProp.external_pipework** suppresses the obsolete local return and
tilted discharge in V2; the default remains false for legacy compositions.
The existing takeoff, safety valve, heat state, water controls, firing doors,
ash door and draft owner retain their authority.

Focused evidence is in **tmp/boiler-pipework**. Seven rays require both the
visible surface and its own matching collision. Three draft settings check
the damper's clearance from the discharge. Close fabrication views, a full
header view and the production carried-lamp view are inspected. The initial
fixture had a GDScript inferred-type error and was interrupted; it is not a
passing receipt. Later completed runs retain separate receipts.

The existing boiler body, outward door motion and service route are retained
as regression suites. Final clean candidate gates and bound suite receipts
belong in **tmp/boiler-pipework/verified**. This note claims no runtime-contract
or completeness-ledger promotion. The broader geometry/material pass remains
unfinished.
