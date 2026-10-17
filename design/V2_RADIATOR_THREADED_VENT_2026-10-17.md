# Native radiator cap threads and timber grain

Evidence class: **INERT**. Focused fabrication and control report, not acceptance.

The vent cap and receiving neck now have matching helical geometry. The custom
stock uses a 1.5 mm pitch over 12 mm of engagement: eight actual turns. This is
an authored fitting, not a claim of a commercial thread standard or maker.
An entrance chamfer clears the cap's eased shoulder. The cap's travel follows
the same dimensions as its native geometry; proximity still only catches the
thread, and reverse mouse rotation must seat it. The receiving chamber now has
actual surface collision when the player carries the loose cap.

Manufacturing dimensions live in
**art/data/orison_v2/radiator_vent_thread_source.json**. The projection tool
**tools/build_v2_radiator_vent_thread.py** validates that recipe and ships only
the version, pitch, engagement and carried collision envelope needed at runtime.
The reader gate reports zero new unread fields. A freshness test prevents the
shipped travel from diverging from the native authority; invalid dimensions,
booleans, insufficient samples and contradictory engagement are rejected.

Seated and partial cap saves now carry thread version 2. Older unversioned
two-turn saves migrate by their existing withdrawal depth. If that depth exceeds
the new engagement, the same cap becomes a free part at its old pose. Otherwise
it follows the new helix at that depth; its angular phase changes to match the
new thread. Loose saved parts retain their existing poses and identities.

The short timber wedges did not qualify for the shared slender-stock grain
heuristic. Their native metre charts now explicitly follow the stock length.
Exported positions and normals remain exact; the top tangents align with the
length axis. This changes grain direction without changing support geometry,
canonical material scale, physics, material keys or the fixed stock's identity.

Final native evidence: 3,043 thread-travel and radial-clearance checks pass over
65 poses, including a wrong-phase collision control. Minimum sampled running
clearance is approximately 66 micrometres. The existing 82 chamber, float, needle
seat, fixed-orifice and air-route checks pass. The cap's seated shoulder contact
is admitted only where a plane separates both entire triangles; there is no
blanket contact waiver. Rechecking the earlier unrelieved stock with that final
test still detects real shoulder intersections. Five retained insert stocks keep
their exact exported buffers. Final export tangent validation passes.

The first neutral exploded capture cropped the cap. Corrected final native views
include the whole assembly. Boolean rebuilds also changed buffer ordering, so
the final native file received fresh fit checks, renders, import and actual-input
qualification rather than being certified by an unsuccessful byte comparison.

The final production-player hand bench passes: 448 surface checks, 20 inherited
pose cases, actual eight-turn removal/reseating, Space inspection, changed-pose
restore, legacy depth migration and the physical repair completion flow. Stderr
is empty. The final composed radiator/fuse review passes all 1,180 checks with no
script errors; its existing seven-Texture-RID shutdown warning remains open.
Two projection tests and all 1,253 texture / 26 precision-mesh import policies
pass. No new texture maps or precision exemptions were added.

Evidence is in **art/reviews/v2_radiator_cutover_20261017/threaded_vent**. Earlier
failed native diagnostics and intermediate captures remain distinguishable from
the final outputs. Historical source pins and receipts were not renewed.

The cloth's stiffness, remaining hard brass details, prominent timber finish,
other small threaded fittings, the full played repair route and disk-save proof
remain open. Broad stale V2 runtime/spatial/surface qualification and human
appearance acceptance remain separate. This checkpoint does not complete V2.
