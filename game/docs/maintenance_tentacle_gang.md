# Maintenance tentacle gang

The owner requirements are in
`design/TENTACLE_GANG_ENCOUNTER_BRIEF_2026-10-25.md`. Source implementation
does not by itself satisfy that brief's visual or composed-world acceptance.

`maintenance_tentacle_observer.gd` is mounted by the V2 runtime root. It reads
the existing WorkOrders job library and stage owner, resolves the loaded repair
target, and checks a floor support ray, standing reach, line of sight and a
clearance cylinder. Active grabs, released mouse, locked input and blocked saves
prevent emergence. No work order, inventory, case, NPC or save mutation belongs
to this observer.

Frequency is deterministic: the task and repair-target identity hash must pass
one in seventeen admission. Consumption is once per task per loaded waking
world. It is deliberately **visit-local**, with no serialized poses, particles,
materials, seeds or new campaign fields. Reloading a waking world starts a new
visit. Removing the task or unloading the physical target cleans up immediately;
finishing a repair does not substitute for physical contact.

The encounter follows dormant, emerging, observing, interfering, contact alarm,
coordinated retreat, purple haze and cleared. Dormant owns no visual resources.
Emergence lasts 2.2 seconds, observation 1.4 seconds, alarm 0.42 seconds,
withdrawal 2.4 seconds and haze 5.5 seconds. Interference waits for contact without
a timeout. There is no health, damage, pursuit or repair-state writer.

The distal pad exposes the existing constrained-grab descriptor. A primary click
acquires it, mouse movement compresses its real represented pad, and the next
click releases. Compression exceeding two millimetres latches one contact with
the touched limb and world point. A targeting ray, lamp change, proximity or
uncompressed grab cannot trigger the retreat. This implementation does not yet
claim hand-collider or held-object contact routes.

All anatomy shares one local deformation function. Muscles have three radial
depth bands; there are separate nerves, cross-links, ganglia, pressure chambers,
gold inclusions, cilia, ocelli, connective septa and vascular/digestive channels.
Retreat advances from distal tissue toward a shared buried root; dense organs
withdraw ahead of membrane. The accepted lamp field supplies shader observation,
including the local light-avoidance deformation. The encounter neither constructs
a lamp field nor reads ecological exposure as illumination.

The membrane is a closed, UV-mapped wall. Screen-space transmission carries the
scene behind that wall; dense tissue retains ordinary shadowing. Statoliths
settle with bend, and the common deformation includes twist and volume-preserving
axial contraction. The accepted lamp's intensity rate damps avoidance. During
interference, manipulator pads probe actual apparatus collision and approach it
within an 18 cm extension limit, rejecting other solid obstructions.

Mesh receivers use the existing registry and lamp layer. Haze and finite
droplets bind to the same field, with the existing dust shader supplying droplet
scattering. Cleanup unbinds owned materials and removes body, fog, droplets and
finite positional audio. The underlying task and support geometry are untouched.

## Reproduce and inspect

`art/blender/scripts/build_tentacle_gang.py` reads the existing hero's asymmetric
profile and creates editable hero, normal, remnant and shared-root Blender files,
then exports glTF. Do not edit those exports. The normal model is the initial
runtime tier; hero/remnant exports are available but automatic tier switching
has not been qualified. `art/tools/build_tentacle_gang_maps.py` authors the three
deterministic PBR map families without photographic inputs. Their catalogue keys
also live in the layout generator so regeneration preserves them.

Run imports and tests only through the repository's Godot lane. The focused
windowed scene is **res://tests/MaintenanceTentacleGangTest.tscn**. Supply
**-ShotDir** and **-LogPath**. The test writes its own schema-2 runtime contract,
captures, engine errors and measured frame timing. It uses a native radiator,
production player input and the shared production atmosphere, but it is an
isolated bench, not a played full-world acceptance receipt.

**res://tests/MaintenanceTentacleWorldTest.tscn** exercises the installed radiator
through the mounted observer. Its repairable job, frequency override and standing
approach are explicit test preconditions. It does not prove campaign progression.
The optical bench preserves native filament cooling when measuring lamp-off;
the shared optical field and native visible light retain their existing owners.

The review packet lives at **art/reviews/tentacle_gang_20261025/README.md**.
It includes quantitative optical comparisons, collision/anchor overlays,
test-written lifecycle receipts, resource checks and measured frame timings.
The implementation report records installed-world results and shared-tree gate
limits. Full visual approval of anatomy and retreat, audio listening review,
global surface qualification and first-use hitch optimization remain separate
from a successful source build or wrapper receipt.

The acceptance follow-up is **design/TENTACLE_GANG_ACCEPTANCE_FOLLOWUP_2026-10-25.md**.
It records the verified loading preparation and the owner-requested goo/melt
sequence, which remains a separate implementation step at this checkpoint.
