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

The fitted export contains 9,480 triangles, 790 closed native stocks and two material surfaces using the existing runtime **brick** key,
with a restrained secondary tint. It has an active metre-based planar UV set;
production materials use their existing physical triplanar scale. Each visible
triangle assembly supplies its collision. This is structural fabrication with
existing materials, not the completed city facade or final material pass.

## Retained slab fit — 2026-10-05

Production room captures exposed brick underside triangles competing with the
retained ceilings at upper-storey setbacks. The generator now subtracts each
actual semantic ceiling volume, including its existing ports, before applying
the unchanged masonry service openings. Seventy-eight stock/slab interfaces
lose **6.05646 m³** of duplicate masonry. Wall bodies start at the slab top
where the lower occupied footprint supplies the slab; exposed exterior slab
bands retain their original extents. Aperture spans and the generated reveal
table remain unchanged.

**exterior_masonry_slab_fit.json** records source-bound ceiling volumes and
actual stock names/bounds. **scripts/inspect_exterior_masonry.py** reopens the
saved native file, checks every positive closed stock and its slab separation,
and renders temporary retained-ceiling context. An optional **--before** native
file enables a bidirectional occupied-cell comparison: the final masonry must
equal the former masonry minus the retained ceilings. Production verification
also clips every imported masonry underside against the actual ceiling
triangles, rather than accepting the source bounds as proof.

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
