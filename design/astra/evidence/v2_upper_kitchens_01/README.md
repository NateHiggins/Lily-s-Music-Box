# Upper kitchen preparation and storage

All six occupied upper kitchens (5A, 5B, 5C, 6A, 6B, 6C) receive one operable
preparation cabinet and one fixed wall cupboard. This completes the current
preparation/storage category across twelve developed homes. It does not
complete their accessories, resident equipment, utilities, or apartment programs.

## Implementation

The six preparation cabinets retain the existing countertop, wood/plywood carcass,
trim panels, brass handles, shelves, separate collision members, and native
0.382 m bypass mechanism. The six wall cupboards reuse the existing upper-kitchen
source component and retain its provenance. They have fixed geometry and do not
claim inventory or opening behavior. No new material or lighting system is added.

The source adds twelve furniture records and eighteen anchors, bringing furniture
to 169 records. New static geometry is 864 triangles, plus 288 native panel/handle
triangles. Restricted 5D and 6D receive no domestic installation.

A/B layouts fit existing appliance and switch approaches. In the compact C
kitchens, the new west-wall cabinet sits beside the sink. Both kitchen switches
move to the clear south wall, and both sink standing positions move slightly.
These are six deliberate existing-anchor edits: two switches, two switch
approaches, and two sink approaches. The corresponding lighting probes change
with the physical switches. No appliance, room boundary, or door is moved.

`work/v2_upper_kitchens_01/build.py` regenerates from `73b65e6` and refuses unrelated
source changes. It checks three-dimensional furniture/fixture overlap, wall
support, complete cabinet width against apertures, room-door sweeps, and 1,276
conservative appliance-motion poses. Navigation covers 134 new/existing upper
approaches through 24,102 source route points and intermediate edge samples.
Source routing includes solid chases, ordinary open doors, restricted closed
thresholds, and open wardrobe leaves. It is not a continuous played route.

The existing household save owner now discovers preparation cabinets from the
validated furniture manifest. Its lower mirror/radiator roster remains scoped
to installed apparatus. There are 104 saved controls: 81 circuits, five ordinary
radiator valves, twelve preparation doors, and six medicine-cabinet doors.
Omitted controls inherit construction defaults; old facts are not eagerly
rewritten on load. The case-owned 2B radiator retains its separate authority.

## Runtime verification

All suites ran serially in windowed Godot 4.7.1 Forward+, 960x540 with dummy audio.
Final logs have empty stderr and no failures.

| Suite | Checks | Scope |
| --- | ---: | --- |
| Upper kitchens | 829 | All 134 standing approaches; six cabinet-panel rays; twelve sink-valve rays; material bindings; isolated saved changes; open/close physics; two lifetimes and teardown during motion |
| Household state | 76 | Full 104-control disk round trip; old 56-control roster; omitted defaults; invalid/protected saves; all twelve preparation-panel visual and physics transforms |
| Upper lighting | 8,249 | All 42 upper switches, including relocated C controls; physical rays/capsules, circuit isolation, saved state, storey gating and teardown |
| Apartment batch | 17,272 | Existing household/material/supply checks and all twelve fixed wall cupboards |

**26,426 checks pass.** The initial 805-check kitchen run also passed; the final
suite adds explicit hot/cold sink-handle reach checks because two sink approaches
were adjusted. No production changes were needed after these engine checks.

Replay source and retained evidence verification without launching Godot:

```powershell
python design/astra/work/v2_upper_kitchens_01/check.py
```

`receipt.json` records exact source and log hashes. Existing fittings, room
circuits, native cabinet mechanism, runtime material catalog, room programs,
runtime root and building selector are verified unchanged from the batch base.
The unrelated pre-existing dream-exposure work is excluded from this batch.

## Rendered inspection

`kitchens_01` retains twelve unedited 1280x720 production frames: matching closed
and open views in all six kitchens. The isolated campaign starts November 10,
1928 at 20:00. Only player locomotion/input are frozen. The real room lighting,
carried lamp, voxel field, shadows, materials and native panel animation remain
active. No fill lights, hidden architecture or replacement materials are used.
`comparison.png` is a labelled, resized contact sheet of those originals.

All twelve frames were inspected. Cabinet panels, contrasting wood shelves,
countertops, wall cupboards and their cast shadows are visible; the open shelf
appears in each matched open frame. These are close interaction views: the held
lamp occludes part of the lower cabinet and the framing crops cabinet extremities.
They do not establish a full-room art review. Existing hard shadow transitions
and fine surface/shadow banding remain lighting/material review items.

## Next V2 work

Continue whole-category upper-home accessories, installed heat, and resident
receivers/equipment/surface props. Eight remaining numbered apartment programs,
B1/shared/service spaces, physical utilities, resident migration, played routes,
representative performance and human acceptance remain open. V2 is incomplete;
V1 remains the default and S2J remains open.
