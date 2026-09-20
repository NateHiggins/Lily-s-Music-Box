# Six-home bathroom detail batch

Source integration over `0123c92`. Godot remains paused; V2 is incomplete and
V1 remains default. This is not a runtime or human acceptance receipt.

All six developed homes (2A, 2B, 3A, 3B, 4A, 4B) now receive three supported
assemblies: a soap dish with bar, a pedestal-mounted towel rail with hanging
linen, and a cistern-clip toilet-roll holder. Eighteen assemblies use the actual
sink/toilet local coordinates. Soap brackets seat on the lavatory back; a
collar follows the tapered pedestal; the roll clips rest on the tank lid.
They introduce no wall coordinates, resident facts, lights, collision bodies,
interaction targets, consumable mechanics or save fields.

The generated triangles use the existing chrome, porcelain_fixture, enamel,
linen and paper material keys through the existing furniture material owner.
The bathroom loader shares seven immutable mesh/material batches among homes:
42 mesh instances and 6,552 total rendered triangles (1,092 unique triangles).
Those are source counts, not measured draw calls, memory or frame performance.
The detail nodes retire with their supporting fixture.

The full roster, support types, unique identities, finite coordinates,
support-local placement, bounded geometry, known materials and identical shared
geometry validate before any detail is mounted. Duplicate installation and
partial/invalid source batches are refused. Future furnishing clearance checks
now include these small visible meshes in the common obstacle census.

`../../work/v2_bath_details_01/check.py` passed: 6,864 established route samples,
25 domestic door sweeps, eighteen triangle-level sightlines to sink valves and
flush buttons, triangle winding and finite geometry checks, deterministic byte
generation, and a rejecting intrusive-geometry control. The existing accessory
checker also replays its cabinet swings/sightlines with the new bath obstacles.
Heating and prep-cabinet checks pass. The 56-control household persistence
source check is replayed into this packet, preserving its original receipts.
Its baseline data enumeration now uses its original git tree, so later additive
manifests do not incorrectly become historical protected files.

The three changed/new GDScripts parse, and existing fixture/control/save,
material-library and layout source is preserved. The apartment batch engine
test is extended for all eighteen physical attachments, material binding,
shared mesh resources, duplicate/invalid source rejection and disposal across
its existing two world lifetimes. None of those engine checks ran.

`geometry_study.png` is a flat-colour projection of the generated detail
triangles, inspected for source silhouette and assembly. It is not an in-game
screenshot and does not establish material appearance, lighting, voxel shadows,
reflections, final placement, collision/interaction behavior or performance.

Remaining V2 work includes the sixteen residential programs with their authored
occupied/vacant/sealed/storage dispositions, shared/service spaces, wider
resident/case migration and queued engine/visual/performance checks. S2J remains
open. This batch does not claim completion of the building or all furnishings.
