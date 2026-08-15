# T7e per-letter neon batching proof

`control_a/` and `control_b/` are independent fresh processes with
`PERF_NEON_LETTER_BATCHING_OFF=1`; `production/` is an independent fresh
process with normal per-letter batching. All use 2560x1440, explicit
`DAYNIGHT_FORCE=night`, seed `19280731`, and the same three production-player
street lenses.

Fresh processes are deliberate. Applying a static merge after a sign is
already resident causes a transient renderer/light-atlas rebuild and is not a
truthful beauty comparison. The focused `NeonBatchTest` supplies the exact
single-variable geometry proof instead: two representative signs fall from
285 letter primitives to 51 finish draws; every per-letter AABB, emissive
material, drop animation and restore survives. In the loaded street census,
the visible Orison blade falls 202 -> 46 objects and the tenant cabinet
98 -> 20.

The fresh beauty frames show the same complete tube strokes, dead-letter
state, cabinets, glow and masonry wash. Cross-process rain/resident motion is
the measured noise floor, not attributed to batching.

| station | control A/B mean abs | control B/production mean abs |
|---|---:|---:|
| north pavement | 0.108528/255 | 0.535556/255 |
| south pavement | 0.096095/255 | 0.075463/255 |
| east road mouth | 0.400908/255 | 0.293140/255 |
