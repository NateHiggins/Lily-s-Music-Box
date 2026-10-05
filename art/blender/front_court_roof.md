# Front-court roof frame and exposed soffit

Evidence class: **INERT**

Classification: **ADAPTATION**. A daylight street review identified the large
gray shape above the entrance as the retained roof slab underside, rather than
neighboring scenery. The published roof deck spans the recessed front court;
this assembly supplies fitted steel below it and an exterior concrete finish.
Roof dimensions, thickness, walking surfaces, openings and original slab bodies
retain their source owners. Heating cuts remain parked.

**scripts/prepare_front_court_roof.py** derives three bay stations from the
south deck and the nearest F06 side-wall records. The right wall steps from
**9.22 m** to **8.02 m** behind the leading bay; the left face stays at
**-5.32 m**. Initial probes aimed at the unstepped right line miss the two
rear bays. The completed inspection checks all actual bracket anchor seats.

**scripts/build_front_court_roof.py** creates three closed I-section girders,
six knee brackets, shelf/back plates and 48 anchor/head pairs. The girder top
meets the source slab underside at **19.0 m**; its **18.45 m** bottom meets each
bracket shelf. This establishes geometric contacts, not structural capacity.
The source file **front_court_roof.blend** retains **117** positive closed stocks.
The installed export has **25 bounded draws / 5,418 triangles**, strict metre
UV charts, corrected tangent handedness and **zero UV fallbacks**. Catalogue
**cast_iron** and **metal** maps use local material duplicates and relative native
paths. Generated glTF is rebuilt from Blender.

The original exposed roof-underside arrays now use the existing calibrated
**concrete** key and ceiling surface recipe. Indoor ceilings keep their existing
finish. No second slab face, walking surface or collider is introduced by the
finish change. The frame's fixed colliders match its delivered native faces.

**scripts/inspect_front_court_roof.py** reopens the saved file, checks all stock
volumes, bounds, map paths, source bindings and partition counts, then renders
three views. Retained production masonry/slabs are temporary context and are
never saved into the native. The three renders were directly inspected.

The initial live probe failed to compile three untyped dynamic expressions;
its failure receipt remains. The repaired **OrisonV2FrontCourtRoofTest** completes
**356 checks**, including all **48** masonry anchor seats, **24** shelf/girder
footprint samples, **nine** slab contacts, strict mapping and actual calibrated
soffit maps. Captures and wrapper receipts remain inspection evidence, not
runtime contracts or completeness promotion. Bound candidate verification,
normal roof/key/entry routes and the broader finish review govern publication.

Native and live inspection records are under **tmp/v2-facade/roof-frame-native**
and **tmp/v2-facade/roof-frame-focused-v2**. The existing roof illumination
failure, larger material review, building acceptance, utility completion and
V1 retirement remain open.

The first committed comparison passed the frame, façade, roof route and key
contract, but the older soffit test still assumed one shape per platform body.
The two published roof-door landings already retain their source boxes plus
native curb envelopes. The corrected inspection accounts for those exact
source-owned shapes and checks every imported face within **20 microns**;
other platforms retain the strict original single-box assertion. No production
collision or underside-coverage tolerance changes for this test correction.
