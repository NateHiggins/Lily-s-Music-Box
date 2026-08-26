# K2-B — the clock must answer where you touched it

The second transition of the first minute, photographed in production from a
**fresh campaign** through the player's own camera, with the HUD left on.

---

## The audit, measured before a line was written

Standing at the pose a hand actually clocks in from — **b(4.84, −1.50, 1.62)**,
the nearest place whose own 2.10 m prompt ray still lands on `DetectorReach` —
and pressing E:

| Question | Answer |
| --- | --- |
| What changes at the detector in 0–3 s? | **Nothing.** `StationKey`, `StopLever`, `PaperPivot`, `MovementHand` and both proof marks were byte-identical at 0.15 s, 0.50 s, 1.00 s and 3.00 s. |
| What *is* the response? | A `pop`, and nothing else. |
| Where is the player facing? | East, at the detector. |
| Is the new paper in the frustum? | **No.** |
| Distance and angle to the report | **0.69 m at yaw +58.5°**, against a 70° camera's half-angle of **±35.0°**. The register body is out on pitch too (−26.6° against ±21.5°). |
| First moment the report is legible | Only after roughly **58° of head turn**. |
| Does existing text already solve it? | Partly — the objective card changes to "At the sloping register, lift the waiting report from its spindle", and the detector prompt changes to "Shift open — read the waiting reports". **The words carry it; the world carried none of it.** |

So the meaningful change happened 0.69 m away, outside the frame, silently and
instantly, while the apparatus under the player's hand said nothing at all.

## The fix

**At the clock.** The station key turns a quarter and springs back over 0.55 s,
and the plunger it drives comes 24 mm down on the sheet and leaves a mark. On a
Hahn or Newman detector that is not decoration added to the act — **it is the
act**: the key turn drives the punch, and the punch is what makes clocking in a
thing that happened rather than a thing that was claimed.

**And the mark lands in the wrong place, which is the point.** `dial_seated` is
false: the sheet is off its pin. The punch is fixed to the case, so it marks
whatever part of the paper is standing under it — the same spot at any hour of
the night. The player's own first act writes SR7-F's fault into the record
before anyone has explained what the fault is.

**A foot to the right.** The report stops appearing and starts **arriving**: it
drops down the spike over 0.62 s and the spindle nods and settles, with the
rustle the board already carried an emitter for. Motion at 58° off-axis is what
peripheral vision is for.

**Neither prop owns anything new.** The mark is derived from
`FirstShiftDirector`'s phase and stored nowhere; the landing is derived from the
register's own `slip_available()`. Both are transient presentation — nothing is
saved, and a resume restores the mark for free because the phase came back with
the save.

## Conditions, declared

| | |
| --- | --- |
| Base | `42fd79d` "Make performance stations carry their player" |
| Scene | production `res://scenes/building/orison_root.tscn`, fresh campaign |
| Camera | the player's own |
| Clock | `DAYNIGHT=0` · Lamp off · HUD on |
| STROKE crop | `180x210+558+233` of 1280×720 |
| MARK crop | `46x46+634+212` |
| SPINDLE crop | `110x140+640+240` |

**Each part is ONE FROZEN INSTANT.** Everything after the initial clock-in is an
A/B on that instant, because the detector's movement hand sweeps with the house
clock: an earlier pass thawed between shots and measured a 702×522 region for a
claim about a sheet of paper. Crops were taken from the measured difference
bounding boxes, not chosen by eye.

The whole sheet was **re-shot on `42fd79d`** after the branch was replayed onto
it, and every number re-measured. `origin/main` moved twice during this task —
to `b328c1c` and then `42fd79d` — and neither touches a scene, a prop or the
layout, but re-shooting settles it rather than arguing it. All figures
reproduced within 0.001.

## Frames

| File | md5 | What it is |
| --- | --- | --- |
| `00_detector_control_a.png` | `88b6392ecf0353a50fc89c888c3040e6` | **A/A**, and the key mid-throw. |
| `00_detector_control_b.png` | `88b6392ecf0353a50fc89c888c3040e6` | The same, untouched. |
| `01_the_key_turns.png` | `88b6392ecf0353a50fc89c888c3040e6` | The acknowledgement at the apparatus. |
| `02_the_key_home.png` | `4776d530478b48c87f702f0831c7e01d` | Same instant, throw zeroed. |
| `03_the_sheet_without_it.png` | `f4948bbb0e8391c2e8a6a6d0993c824d` | Same instant, mark hidden. |
| `04_the_punch_on_the_sheet.png` | `4776d530478b48c87f702f0831c7e01d` | Same instant, mark shown. |
| `05_a_refusal_wins_over_the_turn.png` | `84881871dcabdb3ab48b28588a5ee13d` | Key mid-throw **and** balking — the frame shows the balk. |
| `06_calm.png` | `4776d530478b48c87f702f0831c7e01d` | Everything let go. |
| `10_desk_control_a.png` | `c89b1089c5b2adcf18197fab702f610e` | **A/A** on the wide camera, and the paper mid-fall. |
| `10_desk_control_b.png` | `c89b1089c5b2adcf18197fab702f610e` | The same, untouched. |
| `11_the_paper_lands.png` | `c89b1089c5b2adcf18197fab702f610e` | The clock and the register in one frame. |
| `12_the_paper_settled.png` | `daf20a99aaa90b71060a1cb8b252c702` | Same instant, landing zeroed. |
| `13_the_report_taken.png` | `4246a4d0a65fb8892163113bfa119f58` | The report in hand. |
| `14_the_paper_lands_again.png` | `a11a656cba708a963c82f3d890180424` | The same landing value, re-posed. |
| `15_first_minute_continuity.png` | `4ea1d3ed5f487bd19c880d7ea7b2ff7d` | K2-A's corridor, end of the minute. |

Fifteen frames, **nine** distinct files. The collisions are **A/A pairs that
are also their own state frame** — the pair *is* the key-turning frame and *is*
the mid-fall frame — and `02`, `04` and `06` are one file because all three are
the same thing: key home, mark on the sheet, nothing balking. The sheet does not
stage a second copy of a frame it already has.

## The floors, first

| A/A | RMSE |
| --- | ---: |
| part A, whole frame | **0** |
| part B, whole frame | **0** |
| on STROKE / MARK / SPINDLE | **0**, **0**, **0** |

Every floor is exactly zero, byte for byte. Every number below is worth what
these are.

## The clock answers

| Change | RMSE | Moving region |
| --- | ---: | --- |
| key home → **mid-stroke** | **0.0116** | **176 × 208 px** |
| sheet without → **with the mark** | **0.0171** | 8 × 8 px |
| calm → **refusal**, same part | **0.0752** | 214 × 262 px |

**Read the region column with the RMSE column.** A still frame under-reports
motion: the stroke's 0.0116 is against a floor of exactly zero, but the number
that decides whether a player notices is that **the key and plunger move a
176 × 208 pixel region** — a real piece of machinery working, not a twitch.

The refusal is **6.5× the stroke**, which is the ordering claim in the code
photographed: a machine saying no is louder than a key coming home.

## The paper arrives

Spindle crop, against a floor of exactly zero.

| Change | RMSE |
| --- | ---: |
| mid-fall → **settled** | **0.0598** |
| settled → taken | **0.121** |
| the same landing value, re-posed | **0** |

That last row is the determinism proof: the same countdown driven the same way
produces the identical crop, to the pixel. (Whole-frame, `14` differs from `11`
— replacing a report is not the same board state as never having taken one, and
the board says so elsewhere on its face.)

## What this sheet does not show

- **The sounds.** The punch and the paper rustle are real and are proved in
  state by the focused suite, not claimed from stills.
- **The mark is small — 8 × 8 px at 0.9 m.** That is honest: a punched hole in a
  paper dial *is* small. It is a detail rewarded on the second look, not the
  load-bearing response. The stroke is the response.

## Discarded passes

1. **The key alone.** First version had no plunger: the key moved a **24 × 39
   px** region and the mark it left was **11 × 13**. Correct, period-exact and
   too subtle to notice in ordinary play. The plunger — which is what the key
   drives on a real detector — took the moving region to 176 × 208.
2. **The pin dead under its guide.** With the mark on the plunger's own
   centreline the plunger covered it: the mark showed **10 × 4 px**, because the
   head stands 36 mm proud of the sheet. The pin now sits 0.14 rad beside its
   guide, and the mark reads **8 × 8** clear of it.
3. **Posing the key thirty lines above SR7-F's refusal branch.** The pose was
   computed correctly and then set straight back to zero on the same call, by
   the `else` that has always owned this key's angle. Every measurement read
   0.000 while the state was perfect. The turn now lives in that `else`.
4. **A camera at the interaction pose.** 0.32 m off the case at FOV 55 — the
   paper dial filled the frame and the station key was outside it entirely. A
   hand's reach is not a camera's.
5. **Thawing between shots.** The house clock advances and the movement hand
   sweeps, so an early landing measurement returned a 702 × 522 bounding box for
   a claim about one sheet of paper.
6. **A focused bench with a plain-`Node` stub director.** `bind_first_shift` is
   statically typed, so the stub was silently refused and the suite reported
   **21/21 with every interesting section skipped** on an out-of-bounds array.
   The stub now extends the real director. That green was the most dangerous
   kind.

## Reproducing

```bash
SHOT_PART=a tools/run_godot_serial.ps1 -Scene res://tests/ClockAnswersShot.tscn -ProjectPath <checkout>/game -Windowed -ShotDir <dir>
```

Then `SHOT_PART=b`.
