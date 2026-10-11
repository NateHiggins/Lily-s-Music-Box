# Household refrigerators

Evidence class: **INERT**

This family replaces visual stock on all 18 existing refrigerators and their
50 household inventory items. Four monitor-top cabinets and fourteen oak
iceboxes share immutable native meshes. Three cabinet and 22 food variants have
729 closed stocks, 76 partitions and 187,660 unique triangles.

The original FridgeProp remains the authority for doors, ice hatch, drip pan,
lamp, sounds, inventory RNG, saved state and interaction. The V2 subclass
retains source food nodes and records their original transforms/materials,
then installs fitted stock through one world-owned factory. Oak/enamel and
food tints stay household-specific. Lettering is Label3D. No new textures or
catalogue keys are introduced.

Run build_household_fridges.py, inspect_household_fridges.py,
inspect_household_fridge_motion.py and inspect_household_fridges_context.py
in one run_fabrication_batch.py process. The context checker includes complete
source food jitter/yaw envelopes, actual furniture and walls, full door motion,
all floor feet and adjacent stove service envelopes. Review both cabinet
states and every food prototype with render_household_fridges.py before import.

Use household_fridges in OrisonV2FabricationBatch. Optional
ORISON_FABRICATION_ACTORS limits screenshots only; all 18 actors are checked.
Await actual source tween target poses, and reject camera rays blocked by
moving leaves or structural case surfaces as well as physics obstacles.

Three V2 completion placements move clear of their existing sink frames. The
1A, 3D and 4D fridges stand on their kitchen's south wall east of the sink
counter, facing north, clear of the kitchen-hall opening (follow-ups slice 84);
the context inspector now refuses any closed case standing in a door or
opening passage.
Icebox shelves fit the source milk inventory. Read
design/V2_HOUSEHOLD_FRIDGES_2026-10-08.md for the exact changes, retained
failure receipts, source-binding reuse and whole-room lighting limitations.
