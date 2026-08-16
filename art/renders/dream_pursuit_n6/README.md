# N6 — Mina's release-print pursuit in the production dream scene

Landed 2026-08-15 from `DreamPursuitTest.tscn` (39/39, exact-count harness
with per-block sentinels) and `DreamPursuitShot.tscn` (production frames).
This closes the pursuit contract inside the real `DreamMazeRoot`; it is not
Gate C (hazards), Gate D (the complete passage) or Gate E (image/audio
polish).

## What exists now

- **Runtime maze assembly.** `DreamMazeBuilder` consumes the N2 catalog
  (`game/data/dream_module_catalog.json`) and the exact 64-bit campaign seed
  (as two 32-bit halves, per the N4 hex contract) and lays out the slot's
  eligible chain — for Mina's slot 1 exactly `D00 → D01 → D03 → D04 → D05`
  through edges `E00, E01_LIFT, E03, E04`. One seed bit mirrors handedness;
  one seed rebuilds one byte-identical plan; clear footprints never overlap;
  every chain door keeps the authored 0.91 × 2.13 m opening through a real
  0.20 m shared wall; connectors of later slots stay sealed as solid wall.
  Modules are honest graybox StaticBody3D collision, floor to lintel.
- **The dream body.** The real `PlayerController` spawns at the D00
  threshold with the real service lamp lit. The waking body was freed with
  its world; no transform crosses the N4 boundary.
- **The Tenant.** `DreamPursuer`: one invisible `CharacterBody3D` wearing
  Mina's own hero model (`mina_vale`) forced to
  `SHADOW_CASTING_SETTING_SHADOWS_ONLY` — every borrowed surface is outside
  the beauty pass, no light, no playing animation, no mesh outside the
  silhouette. Movement follows the assembled chain through per-door approach
  waypoints (perpendicular entry half a metre inside each module), with
  passed waypoints pruned every recompute, so the body follows the validated
  graph and never crosses closed collision: **0 route violations** across
  all measured runs.
- **N3's contract, ported unchanged.** Lit 6.35 ± 0.12 m/s with continuous
  clear-ray refresh; dark 3.35 ± 0.08 m/s toward a coarse last-known point
  heard every 0.72 ± 0.08 s; the terminal footstep rule (a stop is one final
  audible plant); capture radius 0.75 m; jitter seeded once from the
  campaign seed and never rerolled. Acquisition requires the player's real
  lamp owner (`lamp_is_enabled()`) AND a clear physics line on layer 1.

## Measured, deterministic (seed `f123456789abcdef`, 120 Hz fixed step)

| paired run in the real maze | capture |
|---|---:|
| lamp continuously on | **6.450 s** |
| lamp continuously off | **10.742 s** |
| lamp extinguished 0.15 s after acquisition | **10.600 s** |

Light-on shortens capture by **40.0%** (bar: at least one third).
Extinguishing after acquisition buys **4.150 s** on this course. Darkness
always still captures. The course: the dream body runs the chain at the
catalog's 4.60 m/s from mid-D01 toward the D05 far end while the pursuit
starts at the D01 west end.

## The four N6 proofs

1. **Silhouette never enters beauty** — every `GeometryInstance3D` under
   the pursuer is shadows-only and belongs to the borrowed silhouette; no
   light, no playing animation, no fallback capsule (the real `mina_vale`
   rig loads).
2. **Opaque module collision blocks acquisition** — a lit target behind a
   real module wall is not acquired; the same lamp through the open
   connector acquires.
3. **Lamp state changes pursuit through the existing public owner** —
   `toggle_lamp()` / `set_lamp_enabled()` on the real controller gate
   acquisition both directions, and the owner is the real service lamp
   (`flashlight.visible`), not a shadow flag.
4. **Capture reaches DreamDirector's existing outcome seam** — the pursuit
   itself commits `end_dream("capture")` through the campaign shell; the
   world returns to one waking slot; wake crosses the existing boundary
   with one stable residue; `OUTCOMES` is unchanged (`capture, fall,
   contact`); a mid-pursuit save restores at D00, never a chase frame.

## Frames

- `01_lamp_on_borrowed_shadow.png` — the player's own production camera:
  the warm beam splash on the D01 end wall with Mina's broad silhouette
  cast across it, and no body in the frame. The beam is a first-person
  instrument (screen mask + baked cookie) and only reads truthfully from
  the eye that carries it.
- `02_lamp_off_black_level.png` — the ruled navigable darkness: nearest
  floor silhouette and one cool receding practical (shot-scene orientation
  controls, as in N3), no body, no readable Tenant.

## Regression on the same source

DreamPursuitTest 39/39 PASS; DreamBoundaryTest 36/36 PASS; CoreLoopTest
PASS. GoldenLoopTest currently FAILS two K6 objective-title checks — this
failure reproduces on clean origin/main with all N6 work stashed (verified
by paired run 2026-08-15), predates N6, and is flagged as its own task; the
prime suspect is the case-object interaction rework in `1f8faa0`.

## Reproduce

One Godot instance at a time, each under 60 seconds:

```powershell
C:\devkit\bin\godot.cmd --headless --path game res://tests/DreamPursuitTest.tscn

$env:SHOT_DIR=(Resolve-Path 'art\renders\dream_pursuit_n6').Path
C:\devkit\bin\godot.cmd --path game res://tests/DreamPursuitShot.tscn
```

## Deliberately not in N6

Hazards (Gate C), the terminal-fold time cap, case-grammar captions, dream
audio, the receding in-maze practical, Peter and later profiles, and any
visual polish beyond graybox (Gate E). The run cap belongs to campaign slot
data when Gate D assembles the complete passage.
