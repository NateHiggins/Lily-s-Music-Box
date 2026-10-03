# Orison operating boiler window

Evidence class: **INERT**

This construction report grants no runtime-contract or completeness promotion.
Heating-distribution cutouts remain parked. Whole-shell weather, roof drainage,
combustion-air performance and final material acceptance remain open.

## Existing opening and source ownership

The completed alley well exposed **B1_BOILER_AIR_E**, but that opening still
held one fixed blockout glass card and the generic decorative double-hung frame.
The new **ADAPTATION** fits the existing 1.2 by 1.0 metre opening. Its sill/head
remain Y **-1.8/-0.8 m**, Z **2.6..3.8 m**, and masonry reveal X
**15.58..15.93 m**. No masonry, floor, well, grate or utility aperture is cut.

**art/data/boiler_window/source_plan.json** owns the construction dimensions.
**art/blender/scripts/build_boiler_window.py** reads the existing layout and
retained masonry reveal table, refuses a changed opening, and regenerates
**boiler_window.blend**, **boiler_window.glb**, the construction inventory and
the physical test fixture. Source bindings hash LF-normalized text; generated
JSON and the precision import are protected from line-ending conversion.
The exported glTF is never hand-edited.

## Fabrication and physical owners

The inward hopper has a folded 2 mm steel reveal liner, weather returns,
compression seat, falling exterior sill/drip, six 4 mm glass panes, framed
sash/muntins, two bottom hinges with pins, a turning cam/strike, and two
articulated two-link stays. Eight flange washers/heads sit on the actual wall
beds; their embedded shanks remain editable native construction. This is a
source-fitted arrangement, not a manufacturer reproduction or capacity rating.

There are **71 closed positive native pieces** and **16 runtime material
partitions / 2,128 triangles**. Original masonry owns buried liner/return and
anchor contact surfaces. Muntins stop at their shared crossbar boundaries;
paired contact faces are omitted to prevent the coplanar patches found in the
first native rendering. Explicit orthonormal metre UVs, tangents and a
full-precision import preserve the thin folded parts. Metal, dull brass and
aged rubber use existing catalogue keys; the panes retain the production
architectural glass shader. No generated lettering, new texture or light recipe.

Only this boiler opening replaces generic framing/glazing. Its original semantic
parent and existing clearance reservation remain. The other **71** window
assemblies retain their existing source and generic test coverage. Each visible
new material partition has matching imported triangle collision, including the
moving glass. The original room wall, exterior masonry and ground remain the
owners beneath the fitted liner; the existing well/grate retain their owners.

## Manual operation and durable state

**orison_v2_boiler_window.gd** mounts under the original opening. The existing PropControlArea adapter binds the room-side
physical cam handle, which alone publishes the ordinary open/close verb. Opening turns
the latch before tilting the sash inward to **35 degrees**; closing seats the
sash before engaging the latch. Four rigid 270 mm stay links update from their
actual end joints at each physics pose. A player volume within the sampled
sweep prevents starting motion; an actor entering during movement pauses it.
The adapter follows the actual cam pose; no new interface is introduced.
The control never creates a maintenance completion, heat event or Dream fact.

The existing HouseholdState owner adds one boolean **window** record under the
original semantic ID. It stores the chosen setting, not tween phase, coordinates
or links. Reconstruction and mid-session load apply a complete physical pose.
Older payloads without that record inherit the closed default without an eager
rewrite. Protected saves reject the window interaction. No second save writer
or new save file is introduced; V1 and the existing 185 settings retain their
owners. The household suite now exercises all **186** settings through its own
temporary real save, reconstruction, legacy default and shutdown paths.

## Inspection and regression boundaries

Saved-source inspection reopens the actual native file, checks closed positive
volume, LF source bindings, 36 leaf/reveal poses and both-side closed/open
renders. Diagnostic masonry, lights and cameras are never saved back.
The installed focused suite checks actual source/triangle/material mapping,
eight fixings and original wall beds, six closed physical panes, 72 stay-joint
samples, retained sill/head/reveal, an occupied sweep, fifteen open upper air
rays into the well, and ordinary input from a walking approach and return.
Normal controller movement includes the unchanged full basement service circuit.

Ground/alley suites first require the new closed physical barrier, then exclude
only its fitted bodies to reproduce the original air reservation below it.
The frozen original 48 ground discovery stations remain unchanged. Excluding
new glazing when testing the older substrate does not prove ventilation;
the separate focused suite tests the actual open configuration without that
exclusion. No collision tolerance, player capsule or runner gate is relaxed.

The clean base is **9f652f287794777b4e69560e378489f736e55aad**, with its complete
47-gate board at **tmp/roof-base-flashings/9f652f2-clean-board.json**. Exact
candidate proof belongs to **tmp/boiler-window/verified/verification.json**.
Wrapper receipts and captures are INERT observations, not schema-2 runtime
proof. Original owner captures and their removed-shot state are preserved.
Nine individually reviewed spatial records are appended, preserving all 6,407
prior records. The interaction census adds one named control with same-file
**interact_control** through the existing adapter. Census smoke-test counts
advance by exactly that classified control; carrier prohibitions, relationship
checks, scanner rules and the frozen legacy carrier baseline remain unchanged.
Same-camera diagnostic views also substitute the retained previous frame/glass
card, recording main-viewport visible draws/primitives before and after, including
the actual standing approach. Earlier total-render observations include
offscreen work and are retained separately. These counters do
not establish frame-rate acceptance.

The first harness run lacks a capture helper and ends at the runner ceiling;
it has no suite verdict. The corrected prototype passes 99 waypoints and
physical/input checks. The household prototype exposed a test resolving the
semantic opening rather than its saved control; that test now exercises the
existing save owner's registered subject. Failed receipts are retained.

Open work: main-roof finish/falls/outlets and downstream drains, residual court
and street-main connection, whole-shell/joint weather performance, independent
bar/bodega/arcade services, farther city construction and the broad surface pass.
This window closes a bounded architecture gap and establishes no rated
combustion-air supply. Heating cutouts stay parked pending shell readiness.
