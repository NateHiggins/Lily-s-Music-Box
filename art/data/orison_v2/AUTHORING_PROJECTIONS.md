# V2 household and construction authoring projections

The six `*_source.json` inputs listed in `tools/build_v2_authoring_projection.py`
retain the complete data that previously lived directly under
`game/data/orison_v2`. Edit these authoring sources, then run:

```console
python tools/build_v2_authoring_projection.py
python tools/build_v2_authoring_projection.py --check
```

The generator preserves every runtime value and record order. It removes only
these explicitly scoped fields from the runtime copy:

| Source | Authoring or proof information |
| --- | --- |
| domestic_furniture | Furniture record `source_component` and `support_source`, including all nested attribution |
| domestic_radios | Receiver record `bounds` reserved for the visual-clearance proof |
| heating | Network marker `yaw_deg`; mounted radiator orientation belongs to the existing adapter anchor |
| household_accessories | Accessory `bounds`, `motion_bounds`, and proof-camera `stance` |
| upper_floor_programs | Program `stage` and `pending` planning notes |
| exterior/construction_shed | Top-level `intent` authoring description |

The program planning notes are preserved pre-projection text. They do not report
current task completion or constitute a new runtime receipt.

The generator also writes `game/tests/data/v2_authoring_proof.json`, keyed by the
same furniture, receiver, and accessory identities used at runtime. The apartment
batch test reads its cupboard attribution, receiver clearance, and accessory
approach positions from that explicit proof source. Unused bounds and motion
reservations remain available to later proof work; moving them does not claim
that they have been tested.

`tools/tests/test_v2_authoring_projection.py` checks projection freshness, complete
value preservation, runtime/proof identity correspondence, scoped field removal,
and drift/mutation refusal. The runtime modules continue to validate and consume
the same runtime geometry, mechanisms, transforms, ownership, doors and circuits.
Historical receipts and captures are unchanged.

The roof uses `roof_source.json` and `tools/build_v2_roof.py` (with a matching
`--check` mode). Its semantic spaces, landing slabs, doors, parapets and approach
anchors project into `game/data/orison_v2_blockout.json`. The two new flights
inherit the installed primary/service stair dimensions; only the F06 core
ceilings are opened below them. This additive generator preserves all other
floor records. The same source now owns the raised timber tank, supports,
bindings, overflow butt and service anchor. V2 mounts the existing
RoofTankBallcockProp at that anchor; its mechanism and maintenance activity
remain production-owned. Ventilation and lift machinery are still unbuilt.

The older `design/astra/work/*/build.py` packets record earlier build steps.
Some still write the former runtime locations and are not current authoring
entrypoints. Replay those packets in their historical checkout. Before adapting
one for new work, route its complete authored output to the source listed here,
then generate the runtime/proof projections. `--check` refuses any direct runtime
overwrite; a normal projection run restores the current authoring source and
must not be used to preserve a newer change made only in a runtime output.
