# F03 east route and Omar's 3B — source geometry checkpoint

Base: `7e8377e7441e1e1c86cd73e67458fe5d2befd6d5`. No Godot launched.

The actual V2 blockout data now includes the F03 public decision zone, east
approach, service crossing and north/south maintenance halls, plus 3B's vestibule,
living/work room, kitchen, private hall, sleeping alcove and bathroom. Original
3B room identities and `F03_DOOR_03` survive. The new rooms are source-authored
construction geometry, not finished interiors or a completed Omar case.

The service route bypasses continuous heat/telephone/electrical risers in a
widened inspection bay. A new service-entry platform supports the doorway at
the existing stair core. The service route reaches the kitchen without crossing
the living room, alcove or bathroom. Bath and kitchen remain reachable without
passing through the sleeping area. Living, kitchen, bath and sleeping dimensions
meet the checked program minima after subtracting the actual partition thickness.

Five doors, seven single-owner openings, three windows, six semantic anchors,
twelve capsule stations, ten route records, two service records and four hidden
use reservations accompany the eleven spaces and one platform. Kitchen exhaust
and heat connectivity are declared topology; this is not proof of functioning
ductwork or a derived full-building service graph.

Runtime mounts the existing RadiatorProp at `F03_B_RADIATOR_01`, preserving Omar's
3B/H-B/seven-section configuration from the original marker, binding inventory,
lowering the assembly to the floor, and relocating its existing acoustic node
through the scoped adapter. No new repair job or case fact is invented.

`author.py` deterministically reproduces only these additions from the recorded
base. It refuses to overwrite unrelated semantic layout edits. `additions.json`
is its reviewable output; the consumed authority remains the game JSON.

`check_source.py` checks original-record preservation, unique identities, disjoint
rooms, shared-boundary apertures, route topology, station floor support and riser
clearance, anchor containment, finished-clear room minima and protected V1 paths.
It parses the modified runtime and fixture with gdtoolkit, not Godot. The updated
native connected-world test checks the actual radiator and every F03 station's
capsule clearance and floor ray; it is prepared but unrun.

Completeness now recognizes 3B and F03's service route as PROGRAMMED. Cutover
remains blocked. Adding the unit also exposes its detailed room/proof obligations,
so the blocker count can increase without representing a regression. Spatial
dependency drift is retained for review, including preserved F03 identifiers
gaining a V2 target. No manifest was broadly refreshed or gate suppressed.

Next: finish 3B's functional domestic fittings and repair-work presentation;
complete 3A/3C/3D, including their canon-specific occupancy; then perform actual
public/stair/service traversal, controller interaction and saved-state checks
when native work resumes. F05/F06/roof and construction/Passage work remain open.
The selector remains V1; this checkpoint does not claim default readiness.
