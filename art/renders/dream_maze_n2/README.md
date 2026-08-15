# N2 — dream-maze module substrate

Generated 2026-08-15 from the owner-approved production design in
`design/ORISON_MAZE_BRIEF.md`.

## Result

N2's paper/data substrate is complete:

- 10 ruled modules (`D00`–`D09`), 12 directed connections and 8 named hazard
  sockets;
- 18 live provenance checks against `building_layout.json` and
  `PlayerController`, including every source room rectangle, the atrium well and
  flight width, elevator shaft and door, F04 clear ceiling, capsule diameter and
  stair rise;
- 0 connector-span, capsule-margin, door-swing, hazard-clearance,
  hazard-warning, topology-reachability or footprint-overlap defects;
- 100/100 sequential seeds rebuild byte-identically, all 100 pass, all 100 are
  structurally distinct when the seed value is excluded from identity, and 0
  facts remain unresolved.

Canonical seed 0 places the lift branch above the dog-leg stair and the plant
rooms above the light-court walk. Its assembly identity is:

`e0b8461695996f5cc101148dbed39928d853b47c634632b210bfb0d47ad25ac3`

The lower drawing panel is an exact-to-scale **control packing**, not runtime
world placement. It proves the source footprints and either branch handing can
coexist without overlap. The upper panel is the directed connection authority.
The eventual runtime builder must satisfy both; it may not mistake the packing
coordinates for waking coordinates or quietly insert portal teleports.

## Reproduce

```powershell
python art/data/gen_dream_maze.py --seed 0 --audit-seeds 100
magick -background white -density 144 `
  art/renders/dream_maze_n2/dream_maze_top_down.svg `
  -resize 1800x1400 `
  art/renders/dream_maze_n2/dream_maze_top_down.png
```

`--check-only` runs the complete provenance, catalog and seed audit without
rewriting the generated JSON or SVG.

## Ownership

- `game/data/dream_module_catalog.json` owns module dimensions, source records,
  connectors, hazard sockets, topology and campaign unlock slots.
- `art/data/gen_dream_maze.py` validates and assembles that source.
- `art/data/dream_maze_layout.json` is generated canonical seed-0 output.
- `dream_maze_top_down.svg` is the generated vector control drawing.
- `dream_maze_top_down.png` is a raster review derivative only.

Edit the catalog or waking source and rerun. Never hand-edit the generated JSON,
SVG or PNG.

## Artifact hashes

| Artifact | SHA-256 |
|---|---|
| `game/data/dream_module_catalog.json` | `B405245BAE032D1D8F9681F33A5D0297C0E09260036086F5FD7DD4DAD6794DA3` |
| `art/data/dream_maze_layout.json` | `C0EA26F6E079361B55D7422D3DA382DE7E03533EF537741E7D158EDB2A57350C` |
| `dream_maze_top_down.svg` | `BB202ED3F31BFB0E9F0F54AD52519FF6D06DCCFF7DE85C750FA42873C2F0B29D` |
| `dream_maze_top_down.png` | `FF7ED2F68225AAEE7EEB2BCBE4AC7A81EED2FA4BA33C1FCAE311BEBCF1BF1249` |

## Deliberately not proved by N2

No Godot scene, navigation mesh, runtime connector, pursuit, audio source,
lighting, onset or save transition exists here. N3's disposable control
corridor must prove the light/acquisition relationship before production dream
geometry is built. K7 remains open and must document the landed K2–K6 spine
before the campaign scene boundary changes.
