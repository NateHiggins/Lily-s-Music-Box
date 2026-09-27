# V2 cab control panel

Evidence class: **INERT**

**art/blender/scripts/build_lift_cab_controls.py** generates the editable
**art/blender/lift_cab_controls.blend** and **game/assets/props/lift_cab_controls.glb**.
The rounded brass board has nine actual bores and turned collars, four
slotted fixings and two lower mounting spacers. It covers the original seven
floor buttons and the lower stop/alarm hardware. The existing floor legends
stay in place. No lettering is generated into the asset.

The back of the upper board seats at the enamel field. Lower 18 mm spacers
reach the exposed car wall. The floor and alarm caps reuse the accepted
Blender call-station cap; the red stop has its own larger rounded cap.
Production interaction signals drive a three-millimetre press and return.
Rapid repeated input cancels the old presentation tween. Input areas, floor
requests, travel interlocks, request lamps, bell and saves remain unchanged.
The red stop remains decorative; this geometry pass does not wire it to
emergency braking. V1 retains its original visual presentation.

OrisonV2CabControlsTest checks actual physics rays to all eight input areas,
wall contact at the lower mounting stations, button press/release and alarm
bell behavior, and captures the installed board in a windowed run. The
existing elevator route suite exercises all seven destinations with player
input. Receipts live under **tmp/lift-cab-controls**; this reference does not
promote schema-2 runtime-contract ledger proof.
