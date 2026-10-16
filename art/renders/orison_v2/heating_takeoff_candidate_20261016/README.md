# Lobby heating takeoff candidate

Evidence class: **INERT**. Native prototype, not installed-world or runtime acceptance.

The lobby shares F01 H-A with apartment 1A. This design splits the retained
parent run around a 90 mm fitting gap instead of duplicating the riser port.
The socket has 25 mm parent insertions and a 30 mm branch insertion. Its
minimum flow radius remains 24 mm; the main casting has 0.2 mm internal relief.
The branch boss is 1 mm smaller in radius than the main body to avoid tangent
Boolean boundaries. External casting edges have 0.8 mm radii.

Six planning tests pass, including reverse pitch, lost floor and nonfinite
source rejection. The saved native model passes 50 assembled bore/socket probes,
closed-stock volume/manifold checks and noncollapsed UV checks: 18,628 triangles.
The transformed endpoint uses 96 actual mesh vertices and reaches the planned
floor stub. Both final renders were reviewed. Existing custom iron_neutral maps
are bound by hash. No generated texture or lettering was added.

Native: **art/blender/heating_takeoff_candidate.blend**.
Recipes: **tools/plan_v2_heating_takeoff.py** and
**art/blender/scripts/review_heating_takeoff.py**. The plan and report bind their
actual source/material inputs. No Godot run was used for this prototype.

Remaining work: cut the actual parent stock at the declared gap, fit and inspect
the full native assembly, add supports and floor sleeve, mount the lobby body,
update the source roster and aperture, then export and perform composed runtime
verification with the rest of the batch. The existing 18-emitter world and all
23 authored demands remain unchanged. Sealed/vacant/storage units remain sealed.
