# V2 street boundaries and construction dogleg

The V2 runtime mounts the retained west street boundary in the normalized front-door frame. ExteriorDetailPass exposes a boundaries-only entry point; its existing production build retains the default six spans. V2 opens only the east north pavement and builds a covered timber dogleg there, with caged work lamps, a braced temporary closure and a contractor notice. The closure is a physical endpoint and view occluder, not an implemented new-region streaming gate.

The isolated V2 street generator extends the walk and road to these controls. `generation.json` records byte-identical regeneration, unchanged original generator, and exact preservation of the pavement-owned bodega world position. V1 geometry and layout were not modified.

`compatibility_01.log` passes 13 native comparisons with empty stderr: six default spans versus five in V2, three exact retained west collision centers/sizes, west timber-face and beacon transforms, and all three west storm curtain transforms, sizes and shader programs. This does not confer new human visual acceptance.

`route_03.log` passes 24 continuous player-controller waypoints with empty stderr: interior to west pavement, return east, covered turn, closure and return indoors. The fixture also verifies collision at the visible west timber and temporary closure, absence of the old east pavement blocker, and occlusion through the turn. `bodega.log` passes the existing 18-waypoint physical door/counter/return route with empty stderr. `composition.log` records the subsequent composed-world regression.

The first route passed spatially but its captures prompted visible lamp housings, a brace and a closure notice. The second capture exposed lettering behind its backing board; the third capture verifies corrected depth. The final notice copy changes the second line to WORK IN PROGRESS, because the opposite pavement does not provide an onward route. The third capture precedes that text-only correction; final composition loads the corrected source.

Remaining presentation includes the surrounding building fabric, better construction detailing, whole-world containment and frame-time review. The new shed is not an accepted showcase streetscape. Full golden shift and the other V2 completion gates remain open; V1 remains the selector default.
