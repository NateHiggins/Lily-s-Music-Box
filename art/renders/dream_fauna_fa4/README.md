# FA-V4 — collision-free DreamWalk fauna inspection

Closed 2026-08-21 on Godot 4.7.1 Compatibility / OpenGL 3.3. A debug
instrument, not a feature: the dream's fauna have no collider by contract, so
DreamWalk's `F` key could never name one. It names them now, and nothing
about the fauna changed to allow it.

## What `F` reports

Aim at a creature in `res://tests/DreamWalk.tscn` and press `F`. Below the
existing architecture identification the HUD and log now carry:

```
FAUNA Gilder's Button (crop)  [GildersButtons #0 of 8]  room @1.0.0.2.1.0.0
  at (2.23, 0.04, 0.85)  2.26 m  miss 0.00 m  radius 0.12 m  scale (0.20, 0.04, 0.20)
  custom (0.5033, 16448.0, 1024.0, 45276.0)  gpu readback (0.5029, 16448.0, 1024.0, 45248.0)
  phase 0.503  nutrient 0.251  emergence 0.251  activity 0.000  hue 0.690  pattern 0.863  flags [PEARL_COLONY]
  density { "nutrient": 0.2509, "grazer": 0.4205, "predator": 0.0, "detritus": 0.0496 }
  material gait 0.030 @ 1.80 Hz  gold_gain 1.00  dark_glow 0.100  vertex_channels 1  lamp_energy 0.64
  shader res://shaders/dream_fauna.gdshader  compiled true  shadows OFF
```

Family label and batch slot, the packed `INSTANCE_CUSTOM` record both raw and
decoded through `DreamFaunaChannels.decode`, the named flag bits, the live
room key and its four-density trophic record, the batch material's facts
(unset uniforms fall back to the shader's declared default via
`RenderingServer.shader_get_parameter_default`), the shader path, whether it
compiled, and the shadow setting.

## How it selects, and what it does not do

`DreamFaunaDirector.inspect_ray(from, dir, max_distance)` is an analytical
pick over the director's **own submission record** (`_records`, what `_apply`
last handed each batch): the live instance whose centre is nearest the ray in
angular terms, inside its bounding radius plus a 3.4° cone, no further along
the ray than the real physics hit (+0.35 m for a creature standing on the
surface the ray lands on). A creature behind a wall is therefore still hidden
by the wall. `nearest_to(point, batch_name)` is the straight-line form the
probe uses.

The record is the source rather than the MultiMesh buffer because the
renderer's readback is not a contract: under `--headless` Godot's dummy
renderer answers identity transforms and `(0,0,0,1)` custom data for every
instance. The report also carries the readback as `gpu_custom` so the two can
be compared, and the windowed probe does compare them (below).

Adds no collision, no per-creature node, no pathfinding, no production UI:
the suite asserts node count, `CollisionObject3D`/`Light3D` count,
realization signature and plan bytes are unchanged by inspection.

## Production proof

`DREAM_WALK_PROBE=<dir>` stands the player 1.8 m from the nearest live
creature on the room-centre side, faces it, presses `F`, saves `fa4_probe.png`
and exits 0 only if the pick names that exact instance, its shader compiled,
and the record matches the GPU buffer.

- `fa4_probe.png` — the HUD frame above.
- `fa4_probe.log` — `picked=true (got GildersButtons#0, wanted
  GildersButtons#0)  compiled=true  buffer_match=true  fauna_nodes=11`,
  0 script/shader errors.
- `dream_fauna_test.log` — `DreamFaunaTest` 28/28 headless (21 prior + 7
  FA-V4), 0 errors.

## Two pre-existing faults the instrument exposed

1. **`DreamWalk._class_of` errored on every fauna material.** It did
   `int(null)` for any ShaderMaterial without a `motif` uniform; the five FA-V1
   fauna material bindings trip it, 20 `SCRIPT ERROR`s per census. Fixed: such
   materials now classify as `FAUNA (<family>)` by their `dream_fauna_family_index`
   meta, or as `shader <file> (no motif)`, and `_isolate` no longer casts a
   null. The startup census now reads
   `"FAUNA (Gilder's Button (crop))": 1, ... "shader dream_lineage_gold.gdshader (no motif)": 5`.
2. **`str(Vector3).pad_decimals(2)` truncates at the first component** —
   `F: (2.17` instead of `(2.18, 0.00, 0.84)`. Replaced with
   `DreamFaunaDirector.fmt_vec3`.

## A measured fact about the packed channel contract

`DreamFaunaChannels` documents "two exact bytes" per float. On the
Compatibility renderer the GPU never sees float32 instance custom data: GLES3
`MeshStorage` packs it as four half-floats and `Math::make_half_float`
truncates the mantissa. The probe measured it directly:

| | phase | nutrient·emergence | flags·activity | hue·pattern |
|---|---:|---:|---:|---:|
| record (CPU) | 0.5033 | 16448 | 1024 | 45276 |
| `compatibility_half()` model | 0.5029 | 16448 | 1024 | 45248 |
| GPU readback | 0.5029 | 16448 | 1024 | 45248 |

The high byte of every pair survives exactly (a multiple of 256 is
representable and truncation toward zero never crosses below it); the low
byte is quantized to steps of 8–32 depending on the high byte. The suite now
asserts the model over all 256 high bytes. Affected low bytes are
`emergence`, `activity` and `pattern_jitter` — presentation only; the CPU
owner positions and feeds at full precision. Nothing was changed about the
packing; the claim is now accurate and the F key shows both values.
