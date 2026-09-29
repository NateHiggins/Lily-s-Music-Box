# Fabricated bedding across the fourteen installed beds

Evidence class: **INERT**

The bedroom sweep showed 65 mm rectangular blanket slabs and flattened oval
pillows using a paper finish. **build_bedding.py** now rebuilds an editable
**bedding.blend** and **game/assets/props/bedding.glb** library. Three sizes
cover all fourteen existing beds, including the longer player bed. Their wood
frames are copied from the authoritative domestic furniture source; frame
vertices match within each size. Added slats support the rounded mattress.
Thin blankets turn over the sides and foot, with small folds and a separate
turned-back edge. Padded pillows use linen. No placement, household identity,
wake anchor or bed dimensions are changed.

The domestic furniture consumer retains each authored wood/blanket binding
and uses four material batches per bed. The three variants share twelve mesh
resources. Imported metre UVs are present; broad fabric/wood mapping and lamp
surface-response review remain pending. No bitmap, new catalogue key or
lighting calibration is introduced. The bed's former full-height bounding box
is replaced by collision from the actual frame and bedding triangles.

**OrisonV2BeddingTest** checks fourteen bed identities, 56 mattress/blanket/pillow
contacts against rendered triangles, shared resources, pillow/headboard
orientation, and removal of the phantom box above the blanket. Player-height
inspection positions require both capsule clearance and a clear sightline.
All fourteen corrected captures were visually inspected. Focused evidence is
**tmp/bedding/views.log.receipt.json** and **tmp/bedding/shots**; candidate
verification belongs under **tmp/bedding/verified**. These are suite-run
receipts, not runtime contracts or whole-building acceptance.

The first render caught a reversed bedding axis relative to the preserved
frame; the generator and contact probes were corrected. The first mount also
raised scene-owner warnings; duplication now uses the established furniture
mounting method. Four initially obscured views were recaptured with explicit
sightline checks. None of those first attempts is presented as final acceptance.
