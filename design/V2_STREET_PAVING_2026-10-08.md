# Street paving detail and retained boundary owners

Evidence class: **INERT**

REPORT - V2 street paving import batch - 2026-10-08

Branch / starting HEAD / origin/main / merge-base: **main / 7023ec99 / same / same**.

Twenty retained V1 street records now have native visual replacements: eight
pavement joints, five coping runs, four passage paving fields and three damp
patches. The source plans, street/floor collision, route guides, emitters and
interaction owners remain. The editable native contains 186 positive closed
stocks, exported in 20 material groups and 9,048 triangles. Existing concrete
maps supply all finishes; there are no new catalogue keys or bitmap textures.

The main fitted slab is reused unchanged. Its 24 saved masonry masks exactly
match the original construction table; consumed front-door/F01 floor fields
and the removal list also match their historical fixture-bound sources. The
original pins are retained, with an explicit consumed-source comparison beside
them. This clears the local review obligation without blanket repinning other
families or claiming whole-file/native equality for the masonry.

The eight 35 mm-wide raised black strips become 7 mm seams seated at +0.4 mm and
clipped to the actual fitted floor. Coping stones sit on the original curb at
+0.12 m, with small arrises and 4 mm joints. Native support review caught the
last proxy projecting 640 mm beyond that curb; the final east end fits its real
bearing. Four passage fields gain metre-mapped panels, 3 mm joints and 0.8 mm
arrises over their unchanged physical floors. Damp films remain inside their
source envelopes and the curb, using irregular outlines and vertex edge fade.
These are passive surface finishes, not a drainage or liquid simulation.

## Review and verification

The [review packet](../art/renders/orison_v2/street_paving_20261008/review.json)
indexes native and installed views with source hashes. Native views use neutral
daylight and simplified retained floor/road/curb context. Their before images
compare original proxy shape using catalogue reference finishes. Installed
before/after pairs use the actual original draws and unchanged production
lighting, with the existing carried lamp enabled and its device hidden for
inspection. The coping-end production view is partly enclosed by retained shed
boards; a separate native endpoint plate exposes the fitted termination.

Native reopening checks all 186 closed stocks, actual export bounds, three
wet-edge alpha ranges and 223 bearings. Fitted-floor samples raycast the saved
native triangles; curb/passage samples compare original collider bounds and
actual new triangles. Worst front-floor error is under 0.01 micrometres. The
export tangent validator passes all 20 groups and 9,048 triangles. Blender
caught a winding issue, a context-transform issue and the real coping overhang
before import; those logs remain diagnostics.

One warm import and two windowed shared-world runs were used. In run 01, the
unchanged fitted-slab module passed **1,132 checks**, including original room
floor ownership and actual first-hit bearings. The street module completed its
geometry and 21-waypoint crossing, but rejected a blocked damp close-up camera.
The combined run is **failed**, never acceptance. Its supported installed views
are retained as scoped visual observations against unchanged production inputs.

Run 02 moves only that camera to a checked clear standing position, adds exact
local material/map comparisons, and captures only the missing view. It passes
**511 module checks plus eight batch checks**, zero failures, in one world.
All 223 installed contacts and the original 21-waypoint input/physics crossing
and return pass again. The test-written schema-2 runtime contract covers its
composition, scoped route and owner retirement; save reconstruction is not
executed. Seven pre-existing Texture-RID shutdown warnings remain. No empty-
stderr or complete-V2 acceptance claim is made.

The existing slab test now supports the shared world without dropping its
checks. The planner recognizes both new shared modules. Its old source hashes
remain visible as historical drift; the explicit native comparison supplies
their narrower interpretation. Reader NEW=0, spatial drift clean, six batch
tools tests pass, and GDScript syntax preflight passes.

## Closeout

Implementation commit **e02cfdc5** passed fresh-checkout static candidate
verification against **7023ec99**: 49 board entries, zero regressions, no
timeouts, a clean checkout, 17 unchanged protected paths, selector V2 and no
ledger requirement changes. The existing incomplete ledger remains unchanged;
this is a relative gate pass. The verifier did not repeat Godot. Its
[JSON](../art/renders/orison_v2/street_paving_20261008/verification.json) and
[readable result](../art/renders/orison_v2/street_paving_20261008/verification.md)
retain the full comparison. Both temporary verification checkouts were removed.

The [committed binding comparison](../art/renders/orison_v2/street_paving_20261008/committed_runtime_binding.json)
matches the canonical runtime digest to the executed contract and checks eight
committed test, fixture, runtime and export files byte for byte. The fresh
checkout differs in line endings on 343 runtime inputs; all normalize to the
same text, but its raw digest differs. No fresh-checkout runtime execution or
additional runtime proof is inferred from that static comparison.

The [next planner baseline](../art/renders/orison_v2/street_paving_20261008/fabrication_baseline.json)
contains 103 registered families, 34 historical source drifts, zero missing
registered inputs and 69 unregistered builders. The shared root addition flags
all families conservatively against the prior snapshot; only the directly
affected slab/detail/crossing checks are renewed here. Repeating the new
snapshot produces zero newly changed families. Historical drift stays visible.

Worktree clean at end: no; owner insitu notes/captures, supplied dossier/review
inputs, two pre-existing EOL-only changes and unrelated generated UIDs remain
outside this batch. Only named owned paths are staged. Protected 17/17 and V2
selector/explicit V1 rollback are checked by candidate verification. No ledger
requirements are promoted by this INERT report.

Changes outside expected boundary: shared test-module registration and planner
alias support, needed to avoid separate world launches. Open findings: broader
street/shell polish, rear/service interfaces, city ground/roof boundaries and
independent service/weather capacity. G15 remains conditional and uninstalled.
Decision needed from owner: none.

Last line: street batch implementation, scoped runtime review and static
candidate verification complete. Continue with rear/service shell interfaces
and remaining city ground/roof boundaries; broader V2 remains open.
