# Native V2 patrol signal boxes

Evidence class: **INERT**. Implementation guide, not completion evidence.

The V2 runtime mounts **orison_v2_watch_station.gd**, a visual subclass of
the existing WatchStationProp, at the seven existing patrol anchors. The
original class, station table, controls, tour-key guard, network, records,
clock lookup, refusal poses and sounds retain their authority. V1 keeps the
original visual implementation. No new station or patrol requirement is added.

Native source is **art/blender/scripts/build_watch_stations.py**. It exports
**art/blender/watch_stations.blend** and **game/assets/props/watch_stations.glb**.
Twenty-one shared stock meshes provide the continuous cast case, light enamel
lining, hollow door aperture and sash, recessed empty socket, crank, coded
wheel stock, pawl, indicator, hinge knuckles and bent conduit. The existing
station number still determines how many wheel teeth are instantiated.
Existing Label3D nodes retain lettering; no text is baked into textures.
Existing catalogue material overrides, including registered clear glazing,
remain on the original named meshes. Superseded case cheeks, top/bottom blocks
and elbow visuals keep their nodes with empty meshes.

Two visual fits are deliberate. Door stock projects 14 mm forward of its old
slab plane, with separate glazing/sash offsets and three fitted hinge reliefs.
The original moving door pivot remains unchanged. The indicator's visual pivot
moves 38 mm inward because its original raised pose protruded through the right
cheek. Its rotation, state, number and signal behavior remain unchanged. The
loaded geometry review checks both indicator states inside the actual case and
samples the ordinary/refusal door range against the 120 mm cast rim.

The builder rejects nonmanifold stock, nonpositive volume and collapsed UVs.
Each stock exports one authored metre-scale UV layer. Blender curve cap seams
are welded before charting; annular sash geometry is built directly. These
checks prevent a successful-looking render from hiding an invalid stock mesh.
Run Blender with **--python-exit-code 1** so assertion failures stop the batch
before import. Native appearance review uses **review_watch_stations.py**.

The combined surface suite reuses **OrisonV2PatrolStationsTest** through its
**validate_in_world** entry point. The same existing checks operate all seven
boxes through the player's interaction ray, carry/return the tour key and
observe the seven register marks. The new loaded-stock review then inspects
apertures, door/indicator fit and actual open/marked/closed views. Runtime
UV/PBR/mipmap checks apply to every composed physical surface.

This batch also removes Blender's default cube UV layer before building the
authored window-stock charts. The window mechanisms and household defaults
are unchanged; current window appearance is reviewed in the composed run.
Older isolated window images remain historical mechanical references and
are excluded from the current visual-review manifest.
