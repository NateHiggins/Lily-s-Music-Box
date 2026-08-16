# Vantry Arcade reconstruction — V2: the rooms behind

Built 2026-08-16 under `design/VANTRY_ARCADE_RECONSTRUCTION_BRIEF.md`,
on top of V1's raised nave. V2 gives every sales floor a real room
behind it and keeps every ruled contract.

## What stands now

- **Eleven rear stock rooms** beyond the band wall (2.60 m deep, full
  storey height), each with its own concrete floor, plain plaster
  linings and ceiling, shelving run, stacked stock and crates in
  half-light — joined to their shop's own bounded batch so the light-
  selection contract keeps holding (widest bucket probed 10.24 m,
  walk gate moved 9.0 → 10.5 with the measurement).
- **The borrowed light.** The authored trades own the bottom 2.3 m of
  every back wall, so the shared device is the one the period used
  over a stock partition: a glazed strip at 2.35–3.05 with trim and
  muntins, through which the rear room's upper volume reads. The hall
  wall behind it is banded to match (solid below, pierced band,
  solid above) — no invisible collision anywhere.
- **The funeral chapel.** The one floor-level opening, because the
  shop data has promised "the chapel is behind the front room" all
  along: the authored drape row now parts at a cased doorway, a
  chancel rail bars entry (visible barrier, honest under the Check 3
  playable contract), pews, catafalque plinth and draped walls beyond.
- **A service vestibule beyond every rear room** — the far doorway
  opens into a real half-metre recess with a dark door at its end, so
  "darkness beyond" is light falloff, not a painted plate. (The first
  attempt used the city soot plate, which read as a lit tenement
  facade through the opening; the vestibule replaced it.)
- The generator's shop-content alarm was raised 1300 → 1550 records
  deliberately (measured 1480 after V2), and WalkTest's three mirror
  contracts moved in step — each with the measurement in its comment.

## Proof

| check | result |
|---|---|
| `gen_layout.py` self-audits | clean |
| PassageHours / Nav / Visibility / Ownership / Finish / LightingAudit | **all PASS** |
| WalkTest FULL (x8 / 480 Hz) | **PASS** |
| Passage northbound, pinned night | **13.20 ms** (V1 was 13.03; blocker baseline ≈17.8) |
| throat / southbound | 10.10 / 10.51 ms |

## Frames (business hours, 12:30 — grilles folded, shop lamps live)

- `01_locksmith_layers` — aisle → glass → benches → the key board on
  the rear wall (a grid of brass keys that reads like a lit facade at
  distance — it is the authored fitting, working) → plaster band above.
- `02_hardware_depth` — inside HARDWARE PAINT: counter zone, drawer
  wall, and the borrowed light with the dark stock room beyond. The
  golden-loop shop, untouched at floor level.
- `03_chapel_doorway` — the parted drapes, cased opening, rail, and
  the unlit chapel. Its half-light arrives with V4.
- `04_aisle_oblique` — the borrowed-light band running above the
  fascias beneath V1's clerestory and vault.

## Held code

Same coordination state as V1: `gen_layout.py` and now
`shop_interiors.py` carry the reconstruction changes uncommitted while
the parallel session's W1 street wall is in flight in the same file.
Docs, renders, the shot scene and the walk-contract updates commit;
generator hunks and regenerated artifacts follow the moment W1 lands.

## Reproduce

```powershell
cd art\data; python gen_layout.py; cd ..\..
cp art\data\*.json game\data\
& "C:\Program Files\Blender Foundation\Blender 5.2\blender" -b -P art\blender\scripts\build_orison.py
C:\devkit\bin\godot.cmd --headless --path game --import
$env:SHOT_DIR=(Resolve-Path 'art\renders\vantry_arcade_v2').Path
C:\devkit\bin\godot.cmd --path game res://tests/VantryDepthShot.tscn
```
