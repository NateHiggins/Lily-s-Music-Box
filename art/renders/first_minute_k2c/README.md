# K2-C — three instructions are not a first step

The third transition of the first minute, photographed in production from a
**fresh campaign** at the pose the paper actually comes off the spindle.

---

## The audit, measured before a line was written

At the acceptance pose — **b(4.84, −2.27, 1.62)**, facing the spindle — the card
read:

> Follow the chirp to the 2A point and open the grille. Before you leave the
> lobby, take the TOUR KEY from its hook. It opens no door. On the way, work
> STATION 2 if you see it. The mark is evidence, not permission.

Three imperatives. Here is where the things they name actually are:

| Target | Distance | Yaw | Pitch | Occlusion | In a 70° frame? |
| --- | ---: | ---: | ---: | --- | --- |
| the register/spindle | 0.45 m | +0.0° | −26.6° | — | **no** (below ±21.5) |
| tour-key guard | 0.85 m | **−60.9°** | −13.6° | clear | **no** |
| lobby detector | 0.89 m | +62.5° | −11.7° | blocked | **no** |
| central watch register | 1.36 m | −72.6° | −8.5° | clear | **no** |
| STATION 2 (F02) | 10.64 m | **−175.3°** | +16.4° | blocked | **no** |
| the stair | 5.59 m | +154.9° | — | **blocked** | **no** |

**Not one thing the card named was in the frame.** STATION 2 is behind the
player and a floor up; the stair they must use is behind them and occluded.

**And the leading verb asked for a sense the building cannot deliver from
there.** The fault fires on a **50-to-95-second random timer**, from an emitter
whose `max_distance` is **16 m**, at a point a storey up through a slab — into a
lobby where **141 emitters are already playing**. A player who does as
instructed and listens hears the building, not the chirp. "Find it by ear" is a
good instruction beside the grille and a poor one at the desk.

**Route freedom was already fine.** At the moment of acceptance the job is
`acknowledged` and the case is `active` with **no key carried and no station
mark**. Nothing gated on either. The problem was never the rules — it was that
three imperatives read as a checklist, and the first one was unusable.

## The change

The card now opens with the one thing a hand can act on in the next few seconds
— **where** — and the two optional clauses drop into the indicative:

> **Unit 2A, one floor up.** Follow the chirp to the 2A point and open the
> grille. The TOUR KEY hangs by the register; it opens no door, but a round is
> signed for. STATION 2 is on the way up if you want the mark — evidence, never
> permission.

The job's own sentence survives **unedited**, straight after the first step —
`WorkOrders` still authors it. The unit and its floor are read off the job spec,
so this is presentation of somebody else's fact and works for any job rather
than being a second copy of this one.

**Nothing in the world changed.** No waypoint, no arrow, no outline, no compass,
no new prop, no new save key. See the `ROOM` column below.

## Conditions, declared

| | |
| --- | --- |
| Base | `b43cbe1` "Prioritize a fundable early-access build" |
| Scene | production `res://scenes/building/orison_root.tscn`, fresh campaign |
| Camera | the player's own, from b(4.28, −2.10, 1.62) at the acceptance pose |
| Clock | `DAYNIGHT=0` · Lamp off · HUD on |
| CARD crop | `380x200+14+14` of 1280×720 |
| ROOM crop | `880x700+390+10` — everything that is **not** the card |

**One frozen instant.** The shift is opened and the paper taken while thawed;
then time stops and every frame is an A/B on that instant, so nothing in the
room can drift between two frames being compared.

**No audio is claimed from these stills.** The chirp's behaviour is proved in
state by the focused and live suites — which is the point, since the finding is
that the sound was not reaching the player.

## Frames

| File | md5 | What it is |
| --- | --- | --- |
| `00_acceptance_control_a.png` | `8b6ab0a9e293fd33a8c26781191b17e9` | **A/A** at the acceptance pose. |
| `00_acceptance_control_b.png` | `8b6ab0a9e293fd33a8c26781191b17e9` | The same, untouched. |
| `01_three_instructions.png` | `bf924927639d726babb18c55bf56f1bd` | The card **exactly as it read before**. |
| `02_one_first_step.png` | `2805bd5d9033ecfb1d9f4dfce2043661` | The same instant, one first step. |
| `03_a_lawful_alternate_order.png` | `f1c96e2358a6fd8a808e4060b8ae4620` | The key taken **second** — a lawful order. |
| `04_the_optional_mark_is_not_a_gate.png` | `8d98c350485fe5399f30755f119c63d0` | Key returned, STATION 2 marked; job and case unmoved. |
| `05_cleared.png` | `8a9fea4ab50981476ecc2aba77ce6e25` | The card cleared. |
| `06_rebuilt_from_the_owners.png` | `8d98c350485fe5399f30755f119c63d0` | Rebuilt from the owners alone. |

Eight frames, six distinct files. `00_a`/`00_b` are the A/A pair, and **`06` is
byte-identical to `04`** — which is the restoration proof, below.

## The floors, first

| A/A | RMSE |
| --- | ---: |
| whole frame | **0** |
| on CARD | **0** |
| on ROOM | **0** |

Exactly zero everywhere, byte for byte.

## The cue becoming legible

| | RMSE |
| --- | ---: |
| three instructions → one first step, **CARD** | **0.245** |
| the same change, **ROOM** | **0** |

**Read those two together.** The card changed by a quarter; the room did not
change by a single pixel. That is the whole claim of this increment stated
numerically: the fix is a sentence, and the world was not touched — no waypoint,
no highlight, no arrow, nothing added to the building.

## Route freedom, and the optional mark

| | CARD | ROOM |
| --- | ---: | ---: |
| key taken **second** (a lawful order) | 0.363 | **0.00174** |
| key returned + STATION 2 marked | 0.276 | — |

The room moves by 0.00174 for the alternate order and that is correct: taking
the key physically lifts it off its hook. It is a real object, not a flag.

The live suite proves what the stills cannot: with the mark made, the job stays
`acknowledged` and the case stays `active`. **Evidence, never permission.**

## Abort and restoration

| | RMSE |
| --- | ---: |
| cleared → rebuilt, CARD | 0.394 |
| **rebuilt vs. the frame before it was cleared** | **0** |

`06` is byte-identical to `04`. The card is cleared and then rebuilt from
`FirstShiftDirector`, `WorkOrders` and the custody owners alone, and comes back
*exactly*. Nothing about this increment is stored, so nothing has to be
restored.

## Discarded passes

1. **"STATION 2" written as "Station 2".** The card's established voice shouts
   its named things — `TOUR KEY`, `STATION 2` — and **six existing suites assert
   on that casing**. Sentence case broke all six for a reason that had nothing
   to do with what they were testing. The caps are back.
2. **Boosting the chirp so "find it by ear" would work.** Rejected on the
   measurement: 141 emitters are already playing, the emitter's reach is 16 m
   against ~19 m through a slab, and the interval is up to 95 s. Making it audible
   from the lobby desk would be a lie about propagation and a broad audio
   redesign, which the brief forbids.
3. **Putting the unit number on the register's report stub.** This is the
   strongest *physical* version of the fix — a two-part 1928 work order leaves
   its stub on the file — and the stub already exists as a blank 38 × 30 mm
   scrap with no legend. **It was not implemented**, because it must originate in
   `night_register_prop.gd`, one of K2-B's two files, and the brief requires
   stopping and reporting that seam rather than overlapping silently. It is
   reported, not taken.

## What this does not do

- It does not touch the chirp, the route, or any owner's state.
- It does not make the tour key or STATION 2 required, and does not make them
  invisible either — both are still named, in the indicative.
- It does not repair the fourth transition.
