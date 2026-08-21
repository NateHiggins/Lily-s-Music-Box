# Orison commensals C1 — production proof

**Closed 2026-08-20.** This is the ruled waking-world minimum slice, not dream
fauna, a case loop, a persistent infestation simulation, or permission for C2.

## What is in production

- `CommensalDirector` derives pressure, census and schedule from the campaign
  seed, `dreams_had` shift count and four existing owners. It writes no save.
- The two nearest authored `street_lamp` markers to `F01_DOOR_06` carry one
  shadowless lamp-moth MultiMesh. Small asymmetric vertex-coloured wings move
  on deterministic unsynchronised shader orbits; they emit no light.
- One deterministic F02 radiator/riser identity receives a single sparse
  high-pitched wall scrape through `AmbientSoundscape`'s existing event pool.
  The schedule has one cadence position, so it cannot spell the Tenant motif.
- `F04_4B_KITCHEN_SINK_01` supplies the roach origin, yaw and real room-facing
  gap. The authoritative `SwitchSystem.room_toggled` verdict arms one scatter
  per shift; `call_locked` delays it and subsequent toggles habituate.
- `StreetEndHoardingFaces` supplies the weed transform. Its base is derived
  from that owner's scaled vertical basis rather than copied from a world
  coordinate.

The result is exactly three MultiMesh presentation owners and no creature
nodes, particles, pathfinding, collision, lights, shadow casters, case binding
or generator edit. Animal activity is night-only; the static plant persists in
daylight as required by the species-specific ruling.

## Frames

- `01_lamp_moths_control_a.png`, `02_lamp_moths_control_b.png` — same-build A/A
  with C1 presentation hidden. The large intermittent exterior-light change is
  the live production noise floor; it is why the final is not judged by a raw
  whole-frame pixel delta.
- `03_lamp_moths_final.png` — production context at one of the two selected
  Orison-entry street lamps.
- `04_lamp_moths_close.png` — close production lens for the small, intentionally
  restrained moth silhouette.
- `05_hoarding_weed_final.png` — the derived hoarding-base cluster.
- `06_kitchen_quiet.png`, `07_kitchen_scatter.png` — one production camera
  before/after the 4B light verdict; the final shows the reduced-scale bodies,
  legs and feelers moving toward the fixture gap.

All seven frames come from `CommensalShot.tscn` at 1280×720 using the production
building, canonical 03:00 night and weather seed `19280731`. No helper light,
creature node, replacement room, hand-authored world position or `shots.md`
entry was added.

## Executable proof

`CommensalTest.tscn`: **19/19**. It proves deterministic re-derivation;
four-owner provenance; three batches; zero collision/lights/shadows;
per-instance-node absence; motif exclusion; floor/zone and species daylight
gates; protected windows; one-event habituation; shared ambience playback; and
a measured **1.5 µs** low-Hz tick against the 100 µs ceiling.

`WeatherPerf.tscn` used `PERF_COMMENSALS_VISUAL_OFF=1` for the same-build
controls, retaining construction, scheduling and indexing while hiding only
the presentations. Two controls measured **21.283 / 20.980 ms**; two C1 runs
measured **21.283 / 21.035 ms**. Means are **21.132 -> 21.159 ms (+0.028 ms)**.
The matched settled population is **8596 -> 8599 submitted objects (+3)**,
meeting the +3/+0.3 ms street contract. A separate structural-off pair exposed
why fresh-process object counts alone are unsafe here: asynchronous building
completion moves them by more than a thousand while direct frame time remains
stable.

Focused `Perf.tscn` A/A/final results:

| Station | Control A | Control B | C1 | Verdict |
|---|---:|---:|---:|---|
| lobby | 29.40 ms | 28.57 ms | 28.96 ms | inside control band |
| atrium eye | 38.91 ms | 39.80 ms | 39.25 ms | inside control band |
| roof | 42.01 ms | 36.72 ms | 36.30 ms | no increase; known broad roof variance |

The existing `Perf` baseline remains over its 16.6 ms global target and exits
1 for those stations; C1 does not claim to repair that pre-existing budget.
The existing found-art and resident-route warnings also remain unrelated.

## Boundary

C1 proves the shared waking presentation seam and unblocks the C2 ruling gate.
It does not silently approve pigeons, rat runs, guano/web decals, Passage/B1
breadth, complaints, countermeasure chores, a cat, or any animal signal role.
