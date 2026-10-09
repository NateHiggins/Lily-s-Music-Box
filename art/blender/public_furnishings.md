# Lobby benches and parcel racks

Evidence class: **INERT**

Rendered inspection found no waiting seats in the lobby and no shelving in the
parcel room. The architectural program calls for both. Two 1.8 m oak benches
now stand against the lobby side walls, outside its arrival/turn and radiator
reservations. Two 0.45 m deep timber racks provide fixed parcel shelves while
leaving both existing doors and the authored sorting aisle usable.

Rebuild **public_furnishings.blend** and **public_furnishings.glb** with
**art/blender/scripts/build_public_furnishings.py**. The editable library has
slatted seats and backs, arms, legs, housed rails, stretchers and small pegs.
The racks have uprights, shelf bearers, planked shelves, rear retaining lips,
cross-bracing and fasteners. Shared mesh resources produce eight installed
material batches and 14,256 triangles. Runtime bindings reuse oak and iron;
metre UVs are present. Grain direction and surface response remain part of the
coordinated material pass. No generated images or new material keys are used.

The V2 environment dossier (F01_PACKAGE-001) adds a separate load to each
rack: eight string-tied parcels by size, an auction crate, a bundle of
envelopes, the parcel book, a spring scale and a stamp pad. The runtime seats
each load in its rack's body, so the racks stay four bodies with the rack's
collision; the loads use the existing paper, linen, brass and book material
keys with tints.

These are fixed furnishings, not new sitting or parcel-custody interactions.
Existing room identities, doors, mail interactions and campaign state retain
their owners. **OrisonV2PublicFurnishingsTest** checks four contacts against the
imported surfaces, floor seating, mesh-edge intersection with installed solids,
and 29 walking waypoints including actual opening/closing of both parcel doors.
The apparent rack/riser overlap in the survey was checked against real solid
collision: no crossing was detected. Player and close detail renders were
inspected under **tmp/public-furnishings/shots**. Detail views add only a local
inspection fill. Final candidate receipts belong under
**tmp/public-furnishings/verified**.

The first run failed on a test-script type inference error before performing
its route and was stopped. Corrected double-import and focused runs passed;
the later **fit.log.receipt.json** includes the fixed-solid intersection check.
These wrapper receipts do not provide runtime-contract or building acceptance.
