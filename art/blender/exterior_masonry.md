# Orison exterior masonry leaf

Evidence class: **INERT**

The editable **exterior_masonry.blend** and generator
**scripts/build_exterior_masonry.py** derive the outer leaf from the occupied
V2 footprint, including partial wall extensions. Interior wall faces retain
their existing positions. The 210 mm outer leaf brings ordinary 140 mm walls
to the authored 350 mm total depth; it covers exposed slab bands and includes
convex corner closures. Narrow slots between neighboring rooms are excluded
where opposing leaves would overlap and bury an existing window.

The final source produces 340 exposed edge runs, 104 corner closures, 71
extended window spans and two door spans. Existing riser-aware reveal logic
remains authoritative for deep service-chase windows. Frames and glazing move
together. Door casings follow the installed depth; the outward rear service
leaf pivots at the exterior face. Door behavior remains with its existing owner.

The 561,588-byte export contains 7,992 triangles and two material surfaces using the existing runtime **brick** key,
with a restrained secondary tint. It has an active metre-based planar UV set;
production materials use their existing physical triplanar scale. Each visible
triangle assembly supplies its collision. This is structural fabrication with
existing materials, not the completed city facade or final material pass.

Eight production-camera views cover the front, both front obliques, side alley,
service core, rear entry and two elevated inspections. The focused test checks
texture-backed bindings, exported UVs and distributed physical shell contacts.
The existing window suite checks all 72 windows, 288 reveal contacts and nearby
trim. Alley and casing suites cover the changed door connection. Candidate
verification and its bound receipts live in **tmp/exterior-walls/verified**.

Earlier attempts in **tmp/exterior-walls** remain diagnostic only: the first
preview used unsupported MatLib keys; an initial contact probe used the wrong
triangle winding; a thickened narrow slot blocked one bathroom window; a
temporary diagnostic script had a type-inference error and timed out. None of
those runs counts as acceptance. Final receipts must show completed checks.

Remaining architectural work includes unified facade composition, setbacks and
roof closures, all location transitions, service supports, and full composed
city inspection. Follow **design/V2_CITYSCAPE_CONTINUATION_PROMPT_2026-10-01.md**.
