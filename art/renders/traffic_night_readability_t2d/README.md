# T2d — canonical-night traffic readability

`TrafficNightReadabilityShot.tscn` holds three production traffic kinds at two
fixed pedestrian viewpoints under the canonical night and deterministic weather
seed. `control_a/` and `control_b/` both hide only
`TrafficWetHeadlightPools`; `final/` restores it. Two controls are retained
because live rain changes between otherwise identical frames and therefore a
single beauty A/B is not a strict one-variable pixel comparison.

The accepted response is deliberately surface-only: one 5.2 × 1.55 m broken
tungsten reflection ahead of each live vehicle, all carried in one shadowless
MultiMesh. The shader broadens and overlaps the two lamp traces, feathers every
edge and uses low-frequency breakup so it reads as wet paving rather than two
painted game stripes. It adds no `Light3D`, vehicle-body emission or brighter
street lamp.

`TrafficNightReadabilityTest.tscn` proves the structural contract and opposite
lane placement. The focused 1440p street station measured 29.99 ms with the
pool batch hidden and 30.29 ms in production, but those fresh processes also
differed by 10 objects and 15 calls. The timing delta is therefore inside live
runtime noise; the deterministic cost is exactly one shared draw while traffic
is visible and zero instances on an empty road.

Capture command:

```powershell
$env:SHOT_DIR='C:/PleaseRemainOnTheLine/art/renders/traffic_night_readability_t2d'
C:/devkit/bin/godot.cmd --path game --resolution 1280x720 res://tests/TrafficNightReadabilityShot.tscn
```
