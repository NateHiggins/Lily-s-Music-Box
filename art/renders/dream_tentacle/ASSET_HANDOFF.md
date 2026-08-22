# §20–§22 — WHAT ACTUALLY CROSSES THE BORDER INTO GODOT

`game/tests/tentacle_asset_probe.gd` loads the exported hero and asks the
**imported** mesh what it has. Not the Blender scene, not the glTF — the thing
the engine ends up holding.

    godot --headless --path game res://tests/TentacleAssetProbe.tscn

## What it found

**The masks reached nothing.** §22 says *"don't force Godot to rediscover
anatomy procedurally if Blender already knows where everything is"*, and the
builder dutifully wrote ten `FLOAT_COLOR` attributes. They survive into the
glTF as `COLOR_0` … `COLOR_9` — and **Godot's importer maps only `COLOR_0`**.
Nine of the ten were dropped at the border, silently, while the shaders went
on rediscovering the anatomy procedurally. Exactly what §22 exists to prevent.

**There were no UVs at all.** `TEX_UV` missing, which blocks every bake, every
texture, and the whole of §20–§21.

## What it has now

The limb is a tube, so §21's *"unwrap the body into a relatively straight
strip"* is nearly free: U around the section, V along the length, assigned
per-loop so the seam column reads 1.0 rather than wrapping to 0.0 and
stretching one face across the entire map.

The masks are packed into channels that survive:

| channel | mask | measured range |
| --- | --- | --- |
| `COLOR.r` | flesh_thickness | 0.071 – 1.000 |
| `COLOR.g` | wetness | 0.247 – 0.753 |
| `COLOR.b` | gold_root | 0.000 – 0.957 |
| `COLOR.a` | sucker_region | 0.000 – 0.992 |
| `UV2.x` | ocular_region | 0.000 – 1.000 |
| `UV2.y` | distal_region | 0.000 – 1.000 |

The probe reports the ranges because **present is not the same as
meaningful** — a channel that comes through constant carries no anatomy, and
would pass a "does it exist" check while telling the shader nothing.

Four of the original ten were dropped deliberately, not for want of room:
`papilla` and `vascular` are noise fields, `phase_sensitive` is a smooth
function of length, and `contact_sensitive` is the sucker field plus the club.
A mask earns a channel when it encodes a **place noise cannot guess** — where
the eye is, where the metal enters, where the suckers grip, how thick the meat
is.

Side effect worth having: dropping nine redundant colour layers took the
exported asset from **3.1 MB to 2.2 MB**.

## Also confirmed

109 mesh instances, **109 carrying a skin** — the binding work reaches the
engine, not just the .blend.
