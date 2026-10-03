# V2 jointed roof weather course

Evidence class: **INERT**

**art/blender/scripts/build_roof_coping.py** reads the four existing cap fixtures
tagged with the roof-coping fabrication family. It generates editable
**art/blender/roof_coping.blend** and **game/assets/props/roof_coping.glb**.
Individual stones have sloped crowns, shallow underside drip grooves,
expansion joints and mitered corner returns. One material batch reuses the
installed concrete finish.

The former cap boxes overlap at each inside corner while leaving the outer
quadrant incomplete. Their visuals are hidden; the Blender weather course
has one continuous corner outline with exclusive adjoining stone faces.
The four existing cap colliders and all parapet guards remain unchanged.
The stone crest follows the original collision top. Weathering overhangs and
the small outer corner returns are presentation, not new climbing surfaces.
Rebuild the Blender asset when the source cap dimensions or positions change.

OrisonV2RoofCopingTest reproduces the old overlap/missing-surface defects at
twelve stations using the retained box triangles, requires one new weather
surface at each station, and checks four real cap contacts. Two windowed
views inspect a miter and the jointed course. The roof route suite covers
the actual guarded perimeter, service access and return to F06. Logs and
suite-run receipts live under **tmp/roof-coping**. Focused captures use
inspection fill. No runtime-contract or completeness-ledger promotion is claimed.
