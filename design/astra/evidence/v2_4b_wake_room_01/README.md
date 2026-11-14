# 4B sleeping alcove — source checkpoint

Base: 08f8abf. Engine verification pending; this is not visual acceptance or a
completed wake-room claim.

The V2 domestic furniture consumer now mounts a bed and nightstand in 4B's
sleeping alcove. Geometry reuses the existing spool bed and nightstand assembly
functions, including the bedside book and optically integrated glass. These
are new V2 specifications, not exact extraction of the legacy anonymous block
bed: its 1.35 by 2.60 metre footprint and cool bedding inform the replacement.
The semantic bed and bedside return anchors remain unchanged. New furniture
anchors sit at floor level, avoiding the semantic bed anchor's .55 metre lift.

Reproduce with `python design/astra/work/v2_4b_wake_room_01/extract.py`.
The script preserves all other installed furniture. The checked-in summary
records deterministic reproduction, unchanged prior eight records, unique
anchor identities, finite triangle arrays and static bedside clearance.
Geometry adds 1,004 bed triangles and 228 nightstand triangles.

The existing earned Dream boundary test now tracks both furnishings through
world retirement and checks the physical bed's floor elevation. After the real
wake transaction it drives six ordinary controller waypoints through the
alcove and hall openings and back, recording wake_route.json and a separate
bedside review image. The review camera turn is explicit test staging; the
production wake orientation has not been changed.

The serial runner refused the attempted boundary_01 run before launch because
Jawbreaker's test_hero_hole owned the engine lane (PIDs 544 and 25308). No
Godot parsing, runtime route, shader or image result is claimed for this change.
Run OrisonV2EarnedDreamBoundaryTest.tscn through the unchanged serial runner
with V2_EARNED_SAVE set to the preceding v2_mina_physical_residue_01/
earned_regression/earned_dream_pending.json; inspect stderr and the captures.

Next: execute that boundary check and revise placement/presentation from the
actual wake view, then finish room lighting/furnishings and the broader V2 work.
V1 remains the selector default; V2 and the failed S2J visual gate remain open.
