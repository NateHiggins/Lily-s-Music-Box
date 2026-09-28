# V2 fabricated roof house tank

Evidence class: **INERT**

**art/blender/scripts/build_house_tank.py** reads the existing roof-tank fixture
records in **game/data/orison_v2_blockout.json**, then generates editable
**art/blender/house_tank.blend** and **game/assets/props/house_tank.glb**.
The tank gains individual timber staves, backed joints, an underside floor,
arrised iron supports, rivets, three courses of binding straps with lap plates,
washers and hex nuts, and a folded weather lid with standing seams.
The twenty-three existing fixture records carry fabrication and part-role tags;
both the Blender generator and runtime consume those tags. Their identities,
positions, sizes and collision flags are unchanged.

The overflow collector uses fitted timber staves, a solid floor, iron rim and
binding. Its X cheeks own the corners; the end boards terminate against them,
avoiding overlapping corner faces. The mouth stays open beneath the existing
overflow outlet.

Three material batches replace twenty-three primitive fixture visuals. All
original collision owners remain enabled at their authored sizes.
The existing ballcock, service reach, maintenance director,
abort/restore behavior and save state remain with their current owners.
This pass adds no opening lid or new controls. Rebuild the Blender asset if
the semantic tank dimensions or relative fixture positions change.

OrisonV2HouseTankTest checks eighteen tank and five collector colliders,
fourteen actual contacts, imported timber/support/lid fit, the collector's
open cavity, the live service mechanism, and three windowed views.
OrisonV2RoofRouteTest exercises real movement around the
supports, ordinary E entry to maintenance, abort/restore, successful repair,
the parapets and return to F06. Logs and suite-run receipts are under
**tmp/house-tank**. Captures in the focused test use inspection fill; the
existing roof route also captures production morning lighting. No runtime-
contract or completeness-ledger promotion is claimed.

The collector follow-up's logs and receipts are under **tmp/tank-collector**.
