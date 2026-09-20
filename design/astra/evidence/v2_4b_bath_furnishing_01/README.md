# 4B bathroom source integration

Added source-derived `4B_wc` (328 triangles) and the existing
`F04_4B_SINK_01` lavatory owner to V2. The toilet sits toward the north-east
corner, facing into the room. The lavatory faces inward from the south wall.
Both have named approach anchors; the west entry and east window stay clear.

The original toilet assembly comes from `build_orison.py` and the exact 4B
layout record. V2 reuses `OrisonV2WaterCloset`/`BakedFurnitureInteraction` for
the flush and audio lifecycle. The lavatory uses the existing `TapProp`,
`bath_sink` subtype, `4B` unit and porcelain-fixture material. No new fixture
mechanics or persisted facts were invented.

The V2 domestic fitting loader now gives sinks a solid body derived from
their constructed local visual bounds. Previously their primary Area supplied
an interaction ray target but no movement collision; V2 does not include the
legacy baked fixture hull. The interaction Area remains slightly larger than
the body, as designed by FunctionalProp. This affects the existing 3B kitchen
and bathroom sinks as well as the new 4B lavatory. The shower is unchanged.

Source checks pass: repeated extraction, unique anchors, valid triangles and
normals, material files, toilet room containment, conservative lavatory
envelope and a 0.25 m radius route clearance calculation. A deliberately
blocking rectangle fails the clearance check. The sink envelope is a source
estimate, not measured Godot visual bounds. All prior furniture/fitting
records are preserved. The earned boundary harness now tracks both objects
through retirement and checks the reconstructed flush owner and lavatory body.

**No Godot was launched, per owner instruction.** Runtime casting, collision,
actual approach/use, retirement and appearance remain pending. Required next
engine checks include the 4B bathroom entry, both tap controls, stopper and
flush, the existing 3B domestic route, and the earned Dream/wake regression.

Plumbing remains incomplete: source review found that the V2 composition does
not yet connect taps to `BoilerTend`; mounting a TapProp alone does not establish
dynamic boiler-temperature delivery or a complete water/service topology.
This packet does not claim those systems, saved fixture state, room lighting,
whole-apartment completion or release readiness.

Rebuild with `python design/astra/work/v2_4b_bath_furnishing_01/extract.py`.
Check with `python design/astra/work/v2_4b_bath_furnishing_01/verify.py`.
