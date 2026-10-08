# Household stoves

Evidence class: **INERT**

All 18 existing ranges use one native gas-range prototype: 306 closed stocks,
34 partitions and 65,832 unique triangles. Original StoveProp remains unchanged.
Its collision, controls, state, flame, grease, blocked jets and audio remain
source-owned. The V2 subclass installs meshes under the original moving owners.

Run build_household_stoves.py, inspect_household_stoves.py,
inspect_household_stove_motion.py, inspect_household_stoves_context.py and
render_household_stoves.py in one Blender fabrication batch before import.
Review closed, open and all four indexed service poses. The motion inspector
samples 41 poses per station; it does not prove continuous clearance or four
simultaneously removed grates.

The child NativeServiceStock presentation frame fits loose grates/caps without
changing source transforms. A transform notification drives it from the source
tween. The native grate endpoint is -60 degrees; source owners still reach
-68 degrees. Caps seat on the hob. Original blocked jets remain live children.

Use household_stoves in OrisonV2FabricationBatch after one editor import.
Initial valve-pose expectations must include the two source ambient-lit
households. Optional actor selection limits captures only. All 18 actors and
72 burners remain covered by the validator. BroilerDrawer is passive in the
source and receives no new user actuator.

Read design/V2_HOUSEHOLD_STOVES_2026-10-08.md for retained failures, sample scope,
source ownership, final checks and the remaining whole-room finish issues.
