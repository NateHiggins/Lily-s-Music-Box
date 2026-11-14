# 4B shower and V2 shower controls

The existing F04_4B_SHOWER_01 identity now mounts TapProp's shower in the V2
bathroom at building-local [-8.45, 0, 5.58], with a separate approach stance.
Its enamel receptor, exposed nickel work and textured curtain use the shared
production materials. BoilerTend discovers it through the existing mount
sequence, increasing V2's water-fitting roster from five to six.

Both V2 showers now receive ten low collision pieces matching the receptor
lips, walls, floor and rear splash. There is no full-height curtain collider.
Small Area targets at the actual hot and cold valve caps expose independent
player controls, forwarding to TapProp's existing setters and flow state.
The existing curtain target remains separate. Receptor hits stop the player's
ancestor lookup, so clicking the pan cannot invoke the generic water cycle.
TapProp, PlayerController and
BoilerTend themselves are unchanged.

The route harness is extended to walk to the shower, gather its curtain,
turn on hot water, mix in cold, close each valve independently and draw the
curtain again, using ordinary input and physical rays. Hot-water composition
and earned-wake checks cover control ownership, receptor geometry, supply
membership and teardown/reconstruction. These checks have not run.

Source checks preserve ten earlier fittings and all prior layout records,
confirm receptor containment and existing stance clearance, and estimate
0.12 m extra clearance beyond the player's 0.33 m radius along the bath entry
path. Valve targets are within the 2.1 m interaction range from the authored
stance. Independent GDScript syntax parsing passes.

**No Godot launched.** Compilation, actual targeting/curtain behavior, receptor
stepping, water presentation, materials, route regression (including 3B),
lifecycle and performance remain pending. No saved valve/curtain state,
complete plumbing topology or V2 completion/default cutover is claimed.

`check_source.py` in this packet reproduces source preservation and placement
checks without starting an engine. Its geometry estimates are not physics
or visual acceptance.
