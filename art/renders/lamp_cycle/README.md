# The service lamp warms up, and it pops

*2026-08-17, owner request. Harness: `game/tests/LampCycleShot.tscn`.*

```bash
SHOT_DIR=<abs> godot --path game res://tests/LampCycleShot.tscn
```

A tungsten lamp does not fade on and fade off. Cold filament is a low
resistance, so switching on draws an inrush: the lamp **overshoots** and then
settles, climbing through red and amber to its working warm white. Switching
off is the same physics backwards and faster, which is why it **pops** — the
filament flares as the current collapses, then lets go down the colour ramp it
came up.

## Measured, per frame

**Warm-up** — 0.52 s, peak **0.795 against a 0.740 settled base**:

| t | energy | colour |
|---:|---:|---|
| 20 ms | 0.000 | `ff6b29` |
| 163 ms | 0.642 | `ff9656` |
| 203 ms | 0.722 | `ffa061` |
| **314–346 ms** | **0.792–0.795** | `ffbc7e` |
| 429 ms | 0.764 | `ffc689` |
| 579 ms | 0.740 | `ffcc8f` |

**Pop** — 0.24 s, flare then collapse:

| t | energy | colour |
|---:|---:|---|
| 20 ms | 0.740 | `ffcc8f` |
| **40 ms** | **1.008** | `ffc083` |
| 60 ms | 0.774 | `ffb677` |
| 80 ms | 0.549 | `ffab6c` |
| 100 ms | 0.331 | `ffa162` |
| 284 ms | 0.000, hidden | `ff6b29` |

The flare lasts about 60 ms, so **frame sampling catches its peak only
sometimes** — one run reports 1.008 and the next 0.748 for the same code. The
curve is the authority here, not any single frame.

## The rules never see the tail

`lamp_is_enabled()` used to answer `flashlight.visible`. That was fine while
the lamp was a boolean and is not fine now that switching off has a 240 ms
tail: the Vantry trunk's condition is `lamp_on`, and `DreamPursuer` acquires
through `lamp_finds_target()`. A filament still visibly dying would have kept
killing the player and feeding the Tenant after they had switched off.

So the switch and the filament were separated. `lamp_is_enabled()` now answers
the **switch position**, which flips on the same line the key is read; only the
picture and the sound lag. The frame table above shows it directly —
`lamp_is_enabled false` on the first frame of the pop, while `visible` stays
true for four more.

`DreamLightControlTest` reproduces N3's ruled contract to the millisecond:
`on=3.425 off=11.358 extinguish=11.225 shortening=69.8% buy=7.800s`. The
flourish spent none of it.

## No strobe, and no cooldown either

The brief bans flashing outright and *separately* guarantees that "repeated
toggling has no stamina cost and no arbitrary cooldown". Those pull in
opposite directions, so they are paid in different currencies: **the switch
always works instantly, and only the transient is rate-limited**
(`LAMP_TRANSIENT_MIN_GAP`, 0.55 s). Mash the key and the lamp obeys every
press — it simply stops blooming and popping, which is the part that could
flicker.

## Sound

Both cues are synthesised in code, as this project already does for its
traffic (`street_traffic.gd`) and its songbook (`song_synth.gd`) rather than
carrying wavs. Seeded fixed, so the lamp sounds like itself every run.

- **On** — a dry contact click (this is a lever on a service set, not a soft
  button) with the filament's low note swelling in behind it over the same
  half second the light takes to warm.
- **Off** — one event, meant to startle: hard attack, low body, quick decay,
  and the loudest thing the lamp ever does, so it lands as a decision rather
  than a UI beep.

## The key

Already dedicated, and unchanged: action `lamp_toggle` → **L**, plus gamepad
**left shoulder** and the touch `LAMP` button, all reaching
`PlayerController.toggle_lamp()`. It is deliberately usable while seated or
call-locked, because it is a physical switch in the hand rather than modal UI.

## Two sampling traps, recorded because they cost real time

1. **Wall-clock offsets lied.** The first sampler waited on `create_timer` at
   20 ms intervals and reported the pop as over almost instantly, which sent
   me tuning a curve that was fine. This scene runs 27 ms frames, so every
   offset resolved late. The lamp advances on `_process` delta; the frame's
   own clock is the only honest one.
2. **The sampler outran its subject.** Writing a PNG costs ~100 ms of frame —
   longer than the pop lasts — so saving every frame hid the transient it was
   built to show. Only a few frames are written now; the curve is traced
   numerically.

Both are the same mistake in different clothes, and it is the one this session
has already made twice elsewhere: **the instrument was the thing that was
wrong.**

## Gates

`DreamLightControlTest` PASS (N3 medians exact) · `DreamPursuitTest` 39/39 ·
`DreamHazardTest` 42/42 · `WalkTest` PASS · `GoldenLoopTest` 87/87 ·
`LightingAudit` 127 PASS
