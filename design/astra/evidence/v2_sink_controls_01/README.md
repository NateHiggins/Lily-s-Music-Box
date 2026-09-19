# V2 sink valve integration

The four V2 sinks now expose independent hot and cold controls on the existing
valve caps. The shower valve factory is shared with the sinks, preserving the
shower's target positions and receptor pieces. TapProp still owns temperature,
mixing, animation, water and sound; its implementation is unchanged.

Previously the sinks' broad PrimaryInteraction Area intercepted the player
ray and dispatched to TapProp.interact_area(), which only handles curtains.
The new sink adapter removes that Area after installing the explicit controls.
It replaces the full-height fixture box with a lower hull ending near the rim
and a separate splash-panel box. Rays to the valves can pass above the lower
hull and in front of the splash. Collision-only fixture surfaces advertise
no interaction and cannot fall through to the generic water cycle.

Source checks preserve the layout, fitting records and shared tap/player/boiler
code. Control line and reach estimates pass for all four authored stances;
the two valve spheres do not overlap. Independent GDScript syntax parsing
passes. These calculations do not establish physics-ray results in the world.

The prepared 4B route now visits the kitchen and bathroom sinks and performs
the full hot/mixed/cold/off sequence with normal input. The hot-water harness
checks all six water fixtures' control ownership and independent actions,
sink Area replacement, shower collision and control retirement across world
reconstruction. These engine checks have not run.

**No Godot launched.** Physical targeting, sink/counter collision, 3B/4B route
regression, water presentation, materials, lifetime and performance remain
pending. The lower sink hull is still coarse; stopper access and exact bowl
collision are not solved. Valve persistence and default cutover remain open.

Run this packet's `check_source.py` for repeatable source checks only.
