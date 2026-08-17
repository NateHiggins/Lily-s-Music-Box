# What a closed arcade leaves burning

*2026-08-17. Harness: `game/tests/VantryNightShot.tscn`.*

```bash
SHOT_DIR=<abs> godot --path game res://tests/VantryNightShot.tscn
SHOT_DIR=<abs> VANTRY_SECURITY_OFF=1 godot --path game res://tests/VantryNightShot.tscn
```

## The ruling

> "light the closed shops as realism determines. when instructions collide,
> favor realism." — owner, 2026-08-17

There was a real collision. `HANDOFF.md` PS6 (2026-08-15) records canonical
03:00 as **"ten dark shop circuits"**, and `38aba16` had just finished making
that true — before it, a closed shop was blazing through its own shutter.
Realism wins it, so the ten circuits are no longer dark.

## Nothing had ever photographed the state being complained about

Every arcade station shoots trading hours. `VantryDepthShot` forces 12:30 so
the grilles are folded and the shop lamps are the light. **The shut state —
grilles drawn, after 02:00, which is most of the game — had no camera at all**,
which is how "the interiors are dead behind their grilles" stayed an impression
instead of a frame. That is this project's second recurring lesson, again.

`VantryNightShot` is that camera, and it carries its own control so the pair is
one build apart and not one memory apart.

## Realism is graded, not uniform

A bulb in every shop is just the blazing shutter at lower wattage. What a trade
leaves on at three in the morning depends on what is inside worth watching:

| trade | gain | why |
|---|---:|---|
| pawn | 0.35 | a strongroom trade; the display light is effectively insurance |
| druggist | 0.30 | night bell and a locked poisons cabinet; the traditional lamp |
| locksmith | 0.25 | keys, blanks and a safe — a security trade watching itself |
| funeral | 0.22 | a chapel of rest keeps a low vigil light; custom, not security, and warmer and dimmer for it |
| news | 0.20 | tobacco behind the counter is the stock worth taking |
| diner | 0.20 | the counter light every luncheonette leaves for the cleaner |
| photo | 0.18 | film and cameras — but the DARKROOM stays dark, because a lit one is a ruined shelf of paper |
| radio | 0.15 | a workshop of other people's sets, half in pieces |
| laundry | 0.12 | other people's shirts; nobody breaks in for shirts |
| cobbler | 0.12 | the same, with lasts |

`HARDWARE PAINT` is deliberately absent: it is `NIGHT_SERVICE_TRADE`, stays
open and fully lit, and is the reference a security light must never be
confused with. Frame 06 is there to hold that comparison.

## Which fixture burns, decided by where it stands

Read from the layout rather than assumed. The aisle runs x 14–16, the
shopfront threshold at 16.5–17.1, and then:

| fixture | x | what it is |
|---|---:|---|
| `SITE_SHOP_LT_` | 16.54 | **outside** the glass line — the fascia |
| `SITE_SHOP_IN0_` | 17.95 | ~1.4 m inside the glass, at 2.92 m |
| `SITE_SHOP_IN1_/IN2_` | 20.5–23.05 | stock and rear |
| `SITE_SHOP_DARKROOM_` | 22.7 | deep, and a darkroom |

So a closed shop **puts out its sign and keeps one light burning inside the
front**. That is what a night security light physically is, it is the only one
visible from the aisle through goods, glass and drawn grille, and it feeds the
layered sightline V2 was accepted on — from the dark side this time.

## What the frames show

The security light does something the control cannot: **it lights the drawn
grille itself.** In the control the lattice is invisible because nothing
illuminates it, so a shut shop and a black hole look identical. Lit from
within, you can read that the shop is closed *and* see into it.

| file | |
|---|---|
| `01_pawnbroker_0.35` / `_CONTROL` | the brightest; counter, goods and tiled floor legible through the grille |
| `02_druggist_0.30` / `_CONTROL` | |
| `03_funeral_vigil_0.22` / `_CONTROL` | the vigil light, warm and low |
| `04_cobbler_0.12` / `_CONTROL` | the dimmest in the arcade — present, barely |
| `05_east_line_rhythm` / `_CONTROL` | the point of grading them: bright, dim and dark fronts down one aisle. The control's left side is a black void |
| `06_hardware_night_service` / `_CONTROL` | the night-service trade, open and fully lit |

## Cost: none, and the first measurement of it was wrong

Filtered single-station runs first suggested **+6 ms** across four stations,
which sent me to shadow slots as the culprit. That comparison was invalid:
the "before" numbers came from a full eleven-station run and the "after" from
`PERF_STATION`-filtered runs, which warm up at one station only. Measured
like against like, over full runs:

| station | before | with security lights | Δ |
|---|---:|---:|---:|
| arcade cluster | 11.91 | 12.77 | +0.86 |
| passage throat reveal | 11.51 | 10.90 | −0.61 |
| passage hall southbound | 10.21 | 11.09 | +0.88 |
| passage hall northbound | 13.46 | 13.04 | −0.42 |

All inside the noise band. **Ten security lights cost nothing measurable.**

`LightFixtureProp.wants_shadow` was added during the false alarm and is kept
on its own merits, which are image merits: a 12–35% bulb behind a drawn grille
has no business throwing a sharp architectural shadow down the nave. Its
justification is explicitly *not* the frame time, and the comment says so.

**Budget note, recorded rather than hidden.** At `throat_reveal` and
`southbound` the census reports the two dimmest and most distant security
lights — `FUNERAL_PARLOUR` and `PHOTO_SUPPLIES` — as *wanting to emit but
dropped*, alongside two of HARDWARE PAINT's. The 64-light budget binds at that
distance. It reads as shops dimming out down a long arcade, which is not
objectionable, but it is a real cap and not a rendering of the authored table.

## Gates

| gate | result |
|---|---|
| `PassageHoursTest` | PASS, 0 failures |
| `PassageFinishTest` | PASS, 0 failures |
| `ArcadeLightCensus` | PASS — 0 dead slots, no powered-off fixture holding a shadow map |
| `LightingAudit` | PASS — 127 spaces, 11 intentionally ambient/dark |

`ArcadeLightCensus` now reports **47 arcade fixtures, 25 switched off** at
canonical night, against 35 before. Ten circuits changed state, which is the
ruling, arithmetically.
