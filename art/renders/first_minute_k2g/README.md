# K2-G — the apartment is not the fault

The seventh transition of the first minute. K2-F got a new player to the 2A
door. This asks whether they can cross it, tell the fault from the flat, and
find the responsible object — inside 45 seconds, without a waypoint.

---

## The audit, and two things I got wrong on the way

Measured with the production body under production collision, from where K2-F
left the player.

**What the order actually says.** The authored objective for the one production
job is not vague and not misleading:

> `issued` — "A Vantry point in 2A is issuing a line-test tone. **Find it by ear.**"
> `acknowledged` — "Follow the chirp to the 2A point and open the grille."

That instruction is *precise*. 2A holds **three** Vantry points — living,
bedroom and bathroom — and only the faulted one sounds, so the ear really is the
discriminator, and "the 2A point" is resolvable exactly the way the copy says.

**What the building did with it.** `ChirpHunt._chirp_loop` waited
`randf_range(50, 95)` seconds **before** each chirp, and the loop starts at
building boot. A player entering 2A therefore arrives at an arbitrary phase:

| | |
| --- | ---: |
| mean wait for the one cue the order names | ≈ 36 s |
| worst case | **95 s** |
| the ceiling | 45 s |

Nothing else in the room sounds. So there was nothing to listen *to*, and
nothing to do but stand still and hope. **The instruction was honest and the
mechanism did not honour it.**

### Two corrections I had to make to my own probes

1. **`z 6.22` is not floor three.** Vantry points sit 3.02 m above their *own*
   floor, near the ceiling. My first probe read the height as a storey and very
   nearly reported the fault as being in the wrong apartment.
2. **I reported a threshold I had never tried to cross.** The 2A doorway is at
   y −1.25…−2.00; the door prop's *origin* is at y −2.11, on the jamb, which is
   wall. Walking the origin's y stops dead at x −4.91 against
   `F02_walls/StaticBody3D`, and I first wrote that down as "the body cannot
   enter". Mapping the doorway in plan showed the opening plainly, and a body
   driven along y −1.40 or −1.70 **passes straight through**. There is no entry
   defect. The probe was walking into a wall next to an open door.

### What the audit cleared

| Suspected blocker | Measured | Verdict |
| --- | --- | --- |
| door locked | `leaf_state = "closed"`, unlocks with the case | not a blocker |
| door won't open | `interact()` → `open = true` | not a blocker |
| body can't enter | passes along the real doorway | **my probe's error** |
| chirp inaudible in room | 16 m emitter, target 2.0 m away | not a blocker |
| chirp loses the mix | wins by **5.7 dB** over the next loudest | not a blocker |
| target unreachable | in reach ≤ 2.0 m, 62° above the eye | not a blocker |
| **the schedule** | **50–95 s, worst case 95 s** | **the blocker** |

## The change

**One band, in the one owner.** `ChirpHunt` is the sole owner of the chirp's
schedule; nothing else in the codebase references the interval.

```gdscript
const CHIRP_MIN := 12.0
const CHIRP_MAX := 22.0
```

- the **first** cue now arrives within 22.0 s of entering, always;
- a **second** arrives within 44.0 s, which is what makes the point findable by
  *inference* rather than by luck — hear it, move, hear it again, and the
  direction resolves;
- worst case threshold-to-target measured live: **23.21 s** against the 45 s
  ceiling.

**It is still a fault, not a beacon.** Twelve to twenty-two seconds of silence
at a stretch is a long time in a dark flat; the player still has to listen, move
and compare. The focused suite asserts that directly — a minimum silence, an
irregular band, and a source scan proving the loop **senses nothing about the
listener**. A fault that chirps because someone walked in is a beacon wearing a
fault's clothes, and this is not that.

**The fiction cost, stated rather than hidden:** the chirp now recurs roughly
three times a minute instead of roughly once. Mina reports it "annotated to the
minute", which this does not contradict, but it is a real change to the
character of the fault and it was made deliberately.

**What I did not do.** No sign, no waypoint, no marker, no glow, no second chirp
owner, no tutorial save key, no objective rewrite. The copy was already correct;
it was the mechanism that had to be repaired.

## Conditions, declared

Captured through the canonical wrapper on the pushed base.

```powershell
pwsh -NoProfile -File tools/run_godot_capture.ps1 `
  -Scene res://tests/ChirpReachableShot.tscn `
  -ProjectPath <worktree>/game `
  -ShotRoot <worktree>/art/renders/first_minute_k2g `
  -RunName production_04 -ExpectedFrames 11 -TimeoutSeconds 60 `
  -Resolution 1280x720
```

| | |
| --- | --- |
| Base | `0392768` "Integrate K2-F quantified direction proof" |
| Run | `production_04/` — receipts, metrics, manifest and contact sheet beside the frames |
| Camera class | **playable** — body, eye, carried service set and streaming origin agree with every frame |
| Clock | `DAYNIGHT=0` · lamp off · HUD hidden by name |
| GRILLE crop | `[550, 311, 180, 150]` — clears the 160×120 framing floor, holds the whole subject |
| EXACT box | `[591, 335, 99, 103]` — the measured difference box, identical at 6 % and 20 % |

**What this sheet can and cannot price.** K2-G's change is a *schedule* — an
interval, not a pixel — and there is no honest way to photograph one. So exactly
**one** visual A/B claim is made: the grille, which is the physical outcome of
working the correct target. Everything else is declared context.

## The capture receipt

| Stage | Elapsed | Protocol target |
| --- | ---: | --- |
| `production_ready` | **33.160 s** | ≤ 18 s, hard warning at 24 s |
| `owners_resolved` | 33.163 s | ≤ 4 s — 0.003 s here |
| `door_swung` | 37.719 s | — |
| `lamp_and_camera_settled` | 40.714 s | ≤ 6 s warm-up |
| eleven captures | 40.737 → 44.426 s | 0.35 s each budgeted, 0.34 s actual |
| `finish` | 44.426 s, **9.6 s of scene margin** | ≤ 54 s |

Boot is 9.2 s past the hard warning, as it was for K2-F. That is a
repository-wide property of `orison_root.tscn`, not something this sheet can
trim.

## The floors, first

Every claim is priced against a control **on the same camera at the same crop**.
No floor is shared across stations.

| Control | crop | linear RMSE |
| --- | --- | ---: |
| point station (`03_a` vs `03_b`) | whole frame | 0.00016 |
| point station | GRILLE | **0.0000481** |
| point station | EXACT | **0.0000431** |
| threshold station (`00_a` vs `00_b`) | whole frame | 0.00140 |

**The threshold floor is not zero, and that is reported rather than hidden.**
The carried service set is composited from a `SubViewport` set to
`UPDATE_ALWAYS`, so it re-renders every frame even with the world frozen; at the
threshold station it occupies an 84 × 74 region of frame. **Nothing is priced on
that station**, so it gates nothing — but a reader comparing the two control
pairs deserves to know why one is 30× the other.

## The claim

| Change | crop | linear RMSE | floor | ratio | declared minimum |
| --- | --- | ---: | ---: | ---: | ---: |
| grille closed → **open** | GRILLE | **0.0955** | 0.0000481 | **1984×** | 0.010 / 3× |
| the same | EXACT box | **0.1553** | 0.0000431 | **3599×** | 0.010 / 3× |

`measure_shot_sheet.py` reports **PASS, 11 frames, 6 pairs, 0 failures**.

`04_the_grille_closed.png` is **byte-identical to `03_point_control_b.png`** —
the "before" of the A/B *is* the control state, so the only difference between
the priced pair is the declared state change and nothing else.

**Luma: one warning, inspected and accepted.** Four point-station frames clip
2.50 % of pixels, above the 0.5 % inspection threshold. The clipped region is
the ceiling pendant behind the point — an in-frame practical light, not the
subject. Inside the priced crops the clipping is **0.13 % (GRILLE)** and
**0.000 % (EXACT)**. Black fraction peaks at 0.202 against a 0.65 threshold.

## Frames

All eleven inspected at full size. `production_04/contact_sheet.png` tiles them.

| File | What it is | Role |
| --- | --- | --- |
| `00_threshold_control_a.png` | the threshold, 78° | **A/A** |
| `00_threshold_control_b.png` | the same, unchanged | **A/A** |
| `01_the_room_from_the_threshold.png` | the doorstep at 100°, peripheral vision included | context |
| `02_a_plausible_wrong_station.png` | the room a new player actually reads | context |
| `03_point_control_a.png` | under the point, 38° | **A/A** |
| `03_point_control_b.png` | the same, unchanged | **A/A** |
| `04_the_grille_closed.png` | the fault, sealed | **A/B before** |
| `05_the_grille_open.png` | the grille dropped — the working target | **A/B after** |
| `06_the_point_from_the_threshold.png` | the same point, 3.5 m away: small, high, easy to miss | context |
| `07_the_door_to_target_line.png` | the open 2A door from the corridor | context |
| `08_an_ordinary_flat.png` | 2A as a home, not a puzzle | context |

## What the frames show that the change does not fix

**`02_a_plausible_wrong_station.png` is the honest picture of this task's
title.** The room is loud with named affordances — `MINA`, `Mina Vale · 2A
[ACTIVE]`, `Redaction Pencil`, `Caption Cards`, `SOFA`, `Personal Style Guide`,
`CAPTION CALIBRATOR`, `DESK` — and Mina Vale herself is standing in it at three
in the morning. Every one of those reads as more likely to be "the answer" than
a small unlabelled brass dome on the ceiling.

Those labels are world-space `Label3D`s built by `case_interactable.gd` and the
Mina case owner. **They are not mine and I did not touch them.** Two things are
worth recording about them:

- **none of them names the Vantry point**, so they do not give the target away;
- they are pure attention competition, and they are the reason the *acoustic*
  cue had to be made reliable rather than a *visual* one added.

The live suite proves the discrimination the labels cannot: the intercom — the
single most defensible wrong answer in the room, a signal head, in reach,
belonging to Mina — is **silent**, and the fault wins the room by 5.7 dB.

## Limitations, stated plainly

1. **A schedule cannot be photographed.** The central claim of K2-G is temporal
   and is proved in the suites, not on this sheet. The one visual claim here is
   the grille.
2. **`06_the_point_from_the_threshold.png` is the weakest frame and is meant to
   be.** The point is small, high and near a bright pendant. That is the honest
   reason the room has to be crossed, and it is why the ear leads.
3. **The point-station frames clip 2.5 % on the pendant.** Inspected above; the
   subject is not clipped.
4. **Seven `DebugLightHandle` nodes are interactive inside 2A** in a production
   build, within 5 m of the target. Reported, not repaired — not this lane.
5. **Mina is present in the flat during the whole sequence.** Her schedule is
   owned by `resident_routines`; K2-G neither moved her nor asserted anything
   about where she stands.

## Historical basis

**None is claimed.** This increment changes a timing constant on a fictional
1912 signalling device. No period source is cited because none is needed and
inventing one would be worse than saying so.
