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
melting retreat, purple haze and cleared. A dormant encounter owns no visuals;
the world observer separately owns an invisible, inactive preparation instance.
Emergence lasts 2.2 seconds, observation 1.4 seconds, alarm 0.42 seconds,
melting 4.2 seconds and the final volumetric puff 5.5 seconds. Interference waits for contact without
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
On contact the whole anatomy collapses coherently into a spreading liquid pool,
then its remaining dense organs withdraw into the fluid. A UV-mapped native
residue mesh carries advecting rainbow pigment, metallic wet stock and broad
rough char patches. Dark wisps accompany the collapse. The pool sinks through
the support plane without changing the floor or collisions, then disappears
into a bounded purple volumetric puff. Phase ID 5 keeps the existing
COORDINATED_RETREAT enum for compatibility but now runs this melting sequence. The accepted lamp field supplies shader observation,
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
scattering. Cleanup unbinds owned materials and removes body, liquid pool, fog, droplets and
finite positional audio. The underlying task and support geometry are untouched.

Searching limbs use independent dart/hold/hover cycles and bounded approaches
to neighbouring tips; one manipulator keeps attending to the apparatus. Tip
movement is swept against actual solids within the 18 cm reach. Neighbour
samples measure proximity, not distinct contact events. Shared mid-body waves
preserve anatomical alignment and distal endpoints. Holding freezes searching.
Touch starts fast directional recoil and staggered curling/spasms, continuing
through collapse and diminishing as the anatomy sinks.

## Reproduce and inspect

`art/blender/scripts/build_tentacle_gang.py` reads the existing hero's asymmetric
profile and creates editable hero, normal, remnant and shared-root Blender files,
then exports glTF. **build_tentacle_gang_residue.py** authors the closed lobed
pool; **art/tools/build_tentacle_residue_maps.py** authors its measured fluid
relief. All anatomy and pool charts use 0.08 metres per tile. Do not edit exports. The normal model is the initial
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
The original reports preserve their historical acceptance limits. Current
results belong to **design/TENTACLE_GANG_COMPLETION_2026-10-26.md**.

The reviewed external rendering proposal and additional visual review criteria
are in **design/ENCOUNTER_RENDERING_PROPOSAL_REVIEW_2026-10-26.md**. Use its
exploration/contact/melt/puff sequence when reviewing the existing captures.
It preserves shared lighting, actual contact, native anatomy and resource
ownership; it does not require Alembic playback or a second-camera smoke portal.

World loading prepares actual mesh/material combinations and shaders without
contacts, sounds, gameplay mutation, or optical receiver bindings. The focused
test checks resource retirement at both encounter and preparation boundaries,
and rejects 100 ms first-use stalls in emergence, melting and smoke.
Preparation renders shared anatomy/pool/fog resources for eight frames in a
private SubViewport. Hidden loading alone left a 197 ms first-use stall after
a shader revision. The temporary viewport retires before encounter admission.
A fresh user pipeline-cache control passes; project shader and driver caches
were retained in that control.

The seven historical Texture RID warnings came from Godot 4.7.1's reflection
atlas, reproduced by **ReflectionAtlasRetirementTest.tscn** without the gang.
**tools/build_godot_reflection_fix.py** builds and pins the upstream backport for
this checkout's native lane; see **tools/engine_patches/README.md**. A fresh
checkout needs that build/configuration to use the fix. The official engine
remains installed and can still be selected explicitly as a diagnostic control.
