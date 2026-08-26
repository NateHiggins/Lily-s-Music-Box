# SR7-N — the hose is not water

**Status: production-rendered proof complete.**

Base **`31f30b7`** "Put the real sky above the Orison". SR7-M landed upstream
as `2d32e75` while this was being built, and `origin/main` then moved three
more times in Codex's weather/sky/celestial lane; the branch was replayed onto
each new head and this sheet was re-shot on the last one.

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn` — the F01 stair core, on the
south landing beside the standpipe riser. Shot through the player's own camera,
lit by the core's own pendant. No proof-only light, mesh, material, camera rig
or production owner.

## The thesis

**A hose is not water.** The apparatus states it as arithmetic:

```
line_made_up() = gasket_seated AND coupling_made_up
             AND nozzle_coupled AND nozzle_shut
```

`hose_racked` is not a term. Fifty feet of sound flax line, folded on its rack
behind clear wired glass, contributes exactly nothing.

The sheet says it twice, in two zeroes:

* **A SHUT CABINET IS A SHUT CABINET.** Frame `00` is the cabinet as found —
  three of four joints wrong. Frame `14` is the same cabinet with the line
  fully made up and the tag signed. Whole-frame RMSE between them:
  **0.0000550**, against a camera A/A floor of 0.0000173. Re-racking the hose
  in the *same* cabinet scores 0.0142 — 258 times larger. The glass shows the
  hose. It does not show the joint.
* **A MADE-UP COUPLING IS A MADE-UP COUPLING.** Frame `06` is the coupling
  screwed up over an EMPTY POCKET. Frame `10` is the same coupling with a
  gasket in it. On the declared joint crop they differ by **exactly
  0.000000** — while breaking that same joint open scores **0.0820**. The
  joint camera's own A/A pair is **byte-identical** (matching SHA-256), so this
  is a true zero measured against a true zero. The thread is not the seal, and
  a photograph cannot tell you which one you have.

## Where it hangs, and why

### The audit

| Evidence | Finding |
| --- | --- |
| Fire mechanism in `game/` | **None.** No prop, no data record, no job, no activity, no case. |
| Fire *appearance* | `orison_detail_pass.gd` batches, on every floor, a red riser Ø 0.11 at b(3.02, −3.02) with brass couplings at z+0.18, **z+1.55** and z+2.92, a flat red "extinguisher cabinet" at b(−2.76, −3.10), and pipe brackets. All MultiMesh: **no collision, no script, no owner**. |
| `roof_hose` | `building_layout.json` already carries a 2 m strip of `soot` furniture at b(−9.6..−9.5, 4.9..6.9) lying beside the water tank. A piece of hose that is not water, in the layout file, since before this increment was named. |
| Water ownership | `RoofTankBallcockProp` (SR7-C) says in its own header: *"There is no water system in the Orison to join."* `BoilerProp` owns steam feedwater only. |
| Alarms | `SmokeDetectorProp` is a **save alias for `VantryPointProp`** — not a detector. |
| Egress signage | `wayfinding_signage_pass.gd` hangs 8 enamel FIRE EXIT plates at b(4.98, 2.92). Signs, not apparatus; a different wall and a different job; untouched. |

**The audit changed the design.** The honest move was not to invent a second
standpipe. This apparatus hangs on the riser the building already draws, at the
coupling it already draws, at the height it already chose.

### Every number derived

| Quantity | Source | Value |
| --- | --- | --- |
| wall | atrium east wall x 3.25, t 0.18 → inner face | **x 3.16** |
| floor | solid landing across the well's south strip | y −3.16…−1.46 |
| the south face | batched panel 2.52…2.94, decal 2.12…2.60, brackets 2.15, riser 3.02 | **full** |
| first window opening on the east face | layout | y −1.45 |
| rack height | **C26-1403.0**: five to six and one-half feet above the landing | 1.524…1.981 |
| rack pins | authored at local y 0.42, origin at 1.20 | **1.620 m** = 5 ft 4 in |
| the riser's own coupling | batched at z+1.55 | inside the same band |
| take-off, measured live | b(3.062, −3.020, 1.550) | **0.042 m from the riser's axis, radius 0.055 — inside the pipe** |

**The cabinet stands at b(3.16, −2.48), facing west.** It was moved there: the
first sheet was shot at −2.62, where the gap between the cabinet's cheek and
the riser is 0.035 m and the branch was a claim nobody could photograph. At
−2.48 there are **0.175 m** of open wall and the branch crosses them in frame
`01`.

## Mechanism, and what is documented

Three faults as found, and one honest duty that is not a fault.

| | as found | documented by |
| --- | --- | --- |
| the coupling | made up over an **empty pocket** | Bowes US 1,093,528 (filed 18 Jul 1913, patented 14 Apr 1914): a pocket "into which is fitted a substantially U-shaped gasket or washer 11, the latter serving to prevent leakage". Benzinger US 1,257,785, assigned to W. M. Schoenle (filed 18 Aug 1917, granted 26 Feb 1918): gaskets "in series in hindering leakage". |
| the play-pipe | **not coupled**, lying in the rack | Stillwaggon US 1,150,075 (filed 5 Feb 1915, patented 17 Aug 1915): the nozzle is the rack's own catch — pull it and "the result is the precipitation of the hose to the floor, uncoiled". |
| its control valve | **open** | Baker US 1,132,899 (filed 13 Aug 1914, patented 23 Mar 1915): the play-pipe's "control-valve adapted to prevent the force of the water … from causing the pipe to kick or pull back". |
| the folds | **set on the same crease** | 29 CFR 1910.158(e)(2)(v), modern and cited as modern: linen hose "unracked, physically inspected for deterioration, and reracked using a different fold pattern at least annually". |

The cabinet itself is C26-1404.0's: one swinging leaf with "a large panel of
clear wired glass", marked across **the panel** — so the red letters go on the
glass — "'FIRE HOSE' in red letters at least two and one-half inches in
height". The hose is C26-1398.0's 1½ in. flax line and the tip C26-1400.0's
⅝ in. smooth bore. That text is the NYC code of **1938**, ten years after this
building is played in, and is cited as the earliest verifiable wording for an
arrangement that was already ordinary — NFPA's Committee on Standpipe and Hose
Systems reported in 1912, was amended 1914, adopted 1915, and had revisions
adopted in **1926 and 1927**.

**The valve is not a verb.** There is no control that opens it. A watchman who
opened a house standpipe valve to see whether there was water would flood the
stair hall and soak fifty feet of linen that is extremely difficult to dry.
The refusal is the lesson: the one action that would prove there is water is
the one action you must not take.

## Definitive frames

All 1280×720. SHA-256 truncated to 32 hexadecimal characters. Three cameras:
the cabinet, the valve column, and the stair core.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_cabinet_control_a.png` | `6a8cf1da5cbb159846b2a614013b2595` | **As found**: shut, FIRE HOSE across the wired glass, fifty feet behind it, and no line. |
| `00_cabinet_control_b.png` | `be28c1867dcc2755d3fd4c647da3b2a9` | The cabinet camera's A/A floor. |
| `01_core_control_a.png` | `ab6ba00cc92ff79f9fc9bac311ea2b49` | **The place**: the stair core, the riser the building already drew, and the branch crossing to the cabinet. |
| `01_core_control_b.png` | `b2682cbd2a817a464de25fe6e26a070d` | The core camera's A/A floor. |
| `02_open_as_found.png` | `693043b96c65924304a33e9b90262adc` | Open: a full rack of sound linen in front of three broken joints. |
| `03_joint_control_a.png` | `72e83460146e6b69a0dee179c4aee91d` | The valve column as found. |
| `03_joint_control_b.png` | `72e83460146e6b69a0dee179c4aee91d` | The joint camera's A/A floor. |
| `04_refolded.png` | `255d9a12041513c1912e510857387357` | **Correct work**: re-racked on a different fold. The scalloped edge moves. |
| `05_sign_refused_hose_present.png` | `fe469832abe3694e718a6041fdab28cb` | **Refusal**: hose racked, sound, freshly folded — and the tag will not be signed. |
| `06_joint_after_refold.png` | `6d6b63b9ba835f7b87e12f4fb404deea` | The joint after that good work: unchanged, because it was never the problem. |
| `07_gasket_refused_through_joint.png` | `622646c28e36959c619422928ef97f1d` | **Refusal**: the gasket held against a made-up joint. You cannot reach the pocket through it. |
| `08_joint_broken_empty_pocket.png` | `23df49f83513e3e0546dab9406025ec1` | **The fault, at last visible.** The joint broken open and the pocket black and empty. |
| `09_gasket_seated.png` | `edf227c199d429619c98f4a5baea035c` | The gasket in the pocket. |
| `10_joint_made_up_properly.png` | `45f6ee13d6efd93b898c763344344e99` | Made up again — **and indistinguishable from `06`.** |
| `11_line_made_up.png` | `b17627f8b901eb0f087fd8b3b36372eb` | The play-pipe coupled at the hose's far end and its control valve shut. Four terms true. |
| `12_tag_signed.png` | `0131b7b78113ab01d26373e252dcde23` | The tag on its wire: **03.00 / MADE UP**. Not "tested" — nothing here was tested. |
| `13_valve_refused.png` | `7034b359bc51b946f8ea0fd9171bd3fd` | **Refusal**: the wheel takes weight and does not come round. |
| `14_shut_with_a_line.png` | `0aa4cd533261b78d994e3bcae0498270` | Shut again, over a made-up line — **and the same picture as `00`.** |
| `15_restored_after_abort.png` | `caa900c6d178b9460560fd99d84e4f25` | Abort: the whole fault back. |
| `16_core_after.png` | `404f4211cae78b22d822dadf4e025a93` | The core, unchanged. |

Twenty frames, **nineteen distinct files**. The one collision is
`03_joint_control_a` = `03_joint_control_b`: the valve camera's A/A pair is
byte-identical, which is what makes its declared crop's zeroes exact rather
than merely small.

## Pricing

Normalized RMSE, ImageMagick 7.1.2.

### The A/A floors, measured rather than assumed

| Camera | A/A floor |
| --- | ---: |
| cabinet | 0.0000173 |
| core | 0.0000111 |
| valve column | **0.000000 (byte-identical)** |

The two wide floors are **not zero**, and the sheet does not pretend otherwise.
The project renders at MSAA 8× with soft-shadow filter quality 3 and no
temporal AA; the shadow filter's sample pattern is not frame-stable, so two
identical frames of a large shadowed interior differ by a sparse single-pixel
speckle at the fifth decimal. Every whole-frame claim below is priced against
that floor. The valve camera sees a smaller, closer subject and its A/A pair
came back byte-for-byte identical; on the declared crops the floor is
**0.000000** and the identities there are exact.

### Whole frame

| Pair | RMSE | against a floor of |
| --- | ---: | ---: |
| **shut, no line → shut, LINE MADE UP** | **0.0000550** | 0.0000173 |
| **abort → as found** | **0.0000594** | 0.0000173 |
| **core after → core control** | **0.0000465** | 0.0000111 |
| re-racked on a different fold | 0.0142 | |
| the joint broken open | 0.0241 | |
| the line made up | 0.00984 | |
| the gasket seated | 0.00248 | |
| the tag signed | 0.00175 | |
| REFUSAL — sign it with the hose present | 0.0166 | |
| REFUSAL — the gasket through a made-up joint | 0.00632 | |
| REFUSAL — the valve | 0.00159 | |
| *(context)* the same frame on the previous base | 0.000455 | |

The last row is why this sheet was re-shot: Codex's "Put the real sky above the
Orison" moved this interior by 0.000455 — small in itself, but twenty-six times
the A/A floor and **eight times larger than every zero claimed above**. A sheet
carried across that commit would have been a sheet whose own noise swamped its
argument.

### Declared crops

| Subject (crop) | Change | RMSE |
| --- | --- | ---: |
| the joint `120x250+600+330` | A/A floor | **0.000000** |
| the joint | **HOLLOW JOINT → SEALED JOINT** | **0.000000** |
| the joint | control: refolding the hose | 0.000788 |
| the joint | **the joint broken open** | **0.0820** |
| the joint | the gasket seated in the pocket | 0.0129 |
| the folds `215x250+412+340` | A/A floor | **0.000000** |
| the folds | **re-racked on a different fold** | **0.0422** |
| the wheel `140x86+712+82` | A/A floor | **0.000000** |
| the wheel | **it takes weight and does not turn** | **0.0139** |
| the tag `104x62+780+226` | A/A floor | 0.0000282 |
| the tag | **the tag is written** | **0.0210** |

The joint crop is the sheet. **Breaking the joint open scores 0.0820; putting
a gasket in it scores 0.0129; and the difference between a sealed joint and a
hollow one scores nothing at all — the two frames are pixel-for-pixel the same
over the whole coupling.**

## Sheets that were discarded, and what discarded them

1. **The cabinet at b(3.16, −2.62), dark red on dark red.** The interior
   photographed as a black box under the core's one pendant 3.5 m away, the
   FIRE HOSE lettering was unreadable on the bottom rail, and the branch to the
   riser was hidden in a 35 mm gap. Fixed by a **pale lining** (period-true: a
   cabinet whose contents cannot be read is a cabinet nobody inspects — the
   same fix SR7-J's cast-iron station needed), by putting the red letters on
   **the panel** as C26-1404.0 actually says, and by moving the cabinet 0.14 m
   north so the branch is in the picture.
2. **A sheet where the refusals bled into the next frame.** A balk is a held
   pose that decays in `_process`, and a frozen sheet does not tick — so the
   joint camera photographed a coupling still tilted by the refusal BEFORE it,
   and the "refolding is not at the joint" control scored **0.044** on a crop
   that should have been at the floor. The harness now calms the instrument
   after every refusal frame; that control now reads **0.000792**. The
   measurement found the bug, not the eye.

A third, smaller correction: the door's glass panel left a 46 mm slot above the
bottom rail, through which the interior showed. `00 → 14` scored **0.0036** and
its difference image was a bright band exactly there. The pane now covers rail
to rail and the same pair reads **0.0000550**.

And a fourth: the whole sheet was shot once more after `origin/main` moved to
`31f30b7`, because Codex's new sky moves this interior by 0.000455 — see the
last row of the whole-frame table.

## Executable proof

Every run through `tools/run_godot_serial.ps1`, one instance, 60-second
ceiling, output redirected and only filtered results read.

- **`FireLineTest.tscn`: PASS 163/163**, exit 0, no parse errors, no timeout.
  - Exactly four line terms; **each one alone breaks the line** and is the only
    fault named when it does.
  - **Removing the hose entirely does not change `line_made_up()`**, and
    `line_made_up`'s own body, read out of the source file, never contains the
    string "hose".
  - As found: three of four joints wrong, and the made-up coupling is **not**
    one of them.
  - **You may not certify a joint you have not opened**: with all four terms
    forced true and nobody having looked, the tag still refuses.
  - Shut, every interior verb refuses and blames the door; the tag refuses on
    its own account.
  - Four faults produce **four different refusal poses**.
  - The valve refuses shut, refuses with the door open, refuses with a made-up
    line, and refuses after the tag is signed; no `valve_open`, `water_on`,
    `flowing`, `pressure_at` or `open_the_valve` exists anywhere in the source.
  - Refolding is permitted, changes `folds_fresh`, and cures **not one** fault.
  - One ordering rule, and it is mechanical; everything else is free order and
    reaches the same record. A coupling **will** go up over an empty pocket,
    because that is how this one was found.
  - Abort restores all ten owned facts and cannot retract what was published.
  - It answers a player looking straight at it, and that answer is the door.
  - The source reaches no `WorkOrders`, `RealityCases`, `RealityState`,
    `MaintenanceInventory`, `FirstShiftDirector`, `CoreLoopDirector`,
    `ObjectiveTracker`, `ScheduleDirector`, `SwitchSystem` or
    `WatchStationNetwork`, and declares no `required`, `must_visit`,
    `checklist`, `objective`, `completion`, `quest`, `waypoint` or
    `onboarding`.
- **`FireLineLiveTest.tscn`: PASS 66/66**, exit 0. On the real Orison: the
  cabinet is on the real east wall face, over the real landing, clear of the
  real window opening; the rack is at 1.620 m, inside the code band; the
  take-off is **0.042 m from the riser's axis** and level with its coupling;
  0.175 m of branch runs in the open. The whole chain works on the production
  instance. **No work order was issued, activated, advanced or closed**; the
  live job spine is byte-for-byte what it was and `has_open_work()` is
  unchanged; no case moved and no case signal was published; **not one save key
  moved**; not one of 113 real door leaves moved; not one of 248 lamps changed
  power; the watch line recorded nothing and still carries exactly its two
  authored boxes; the tour key never left its hook; the night register is
  untouched.
- **`InteractionInventory`: functional 281/36**, up one instance and one family
  for the cabinet. It was **280/35 at first** — the prop had `interact()` and
  no `interact_prompt()`, so the inventory did not count it and a player
  looking straight at it would have been told nothing. The inventory found
  that; the focused suite now asserts it.
- **`WalkTest` (FAST): 239 pass, 2 fail** — `boiler's long parts list stays
  merged (23 meshes)` and `production spine loads the one authored job, the
  chirp hunt`. Both **pre-existing**, and attributed by the sharpest test
  available: the same head, the same tree, with the four-line placement in
  `orison_detail_pass.gd` reverted so the cabinet is not in the building at
  all, gives **the identical 239 pass and the identical two named failures**.
  Neither is in the F01 stair core; one is a B1 boiler mesh merge and the other
  is the job library.
- Codex's reserved suites all PASS with the cabinet in the building:
  `FirstShiftRitualTest`, `FirstShiftOpeningLiveTest`,
  `FirstShiftOpenLineLiveTest`, `FirstShiftCustodyTest`, `CoreLoopTest`,
  `CelestialEphemerisTest`, `LiveWeatherServiceTest`. The whole SR7 watch line
  stays green: `WatchPairTest` 118/118, `WatchPairLiveTest` 42/42,
  `WatchStationLiveTest` 38/38, `WatchRegisterTest` 87/87,
  `WatchRegisterLiveTest` 40/40, `TourKeyTest` 65/65, `TourKeyLiveTest` 39/39,
  `NightRegisterTest` 148/148, `NightRegisterLiveTest` 64/64.

## Ownership, in one line each

- **`WorkOrders` — consulted, deliberately not used.** A work order in Orison
  is a *reported* fault with a unit and a symptom, and it counts toward
  `has_open_work()`. A standpipe inspection is nobody's complaint: it is a
  periodic duty owed to an insurer, and its output is a dated tag on a valve.
  Issuing a job for it would invent a tenth entry in the sole job library and
  make an optional inspection show up as open work — which is the checklist
  this increment exists to refuse. The live proof asserts the spine did not
  move.
- **`MaintenanceActivityLibrary` — consulted, deliberately not used.** Its
  verbs are `turn`, `align`, `hold_release` and its panel drives a stepped
  sequence. Breaking a coupling and finding a pocket empty is not a step in a
  sequence; it is a chain of hand operations at named places, which is the
  `PropControlArea` idiom SR7-G through SR7-M already use. No activity was
  added.
- **`RoofTankBallcockProp`** — cited, untouched. That the riser is fed from the
  Orison's own roof tank is **inference**: the tank is real geometry, but no
  pipe joins them and none is modelled here.
- **Its own condition** — owned entirely, ten facts, snapshot and restore under
  the same two method names `MaintenanceActivityPanel` uses.

## Limitations

- **One outlet is not a standpipe system.** Every floor's riser has a coupling
  at z+1.55; only F01 has a cabinet on it. Adding another is a placement.
- **Nothing consumes `line_inspected`.** No director, no case, no save. That is
  deliberate, and it means the inspection is genuinely optional — and equally
  that a made-up line is forgotten on reload.
- **The gravity tank's fire reserve is not modelled.** C26-1411.0's rule — the
  domestic draw-off set high enough that the standpipe capacity is reserved —
  is the sharpest "full tank, no water" truth in the period record, and it
  belongs to the roof tank, which SR7-C owns.
- **The wired glass is opaque.** Argued for in the prop's header rather than
  hidden: what a grimed pane delivers is the *shape* of a full cabinet, which
  is exactly the fact that does not matter. It is still a simplification.
- **The far end cannot be priced on its own crop.** The play-pipe shares the
  bottom of the case with the fold bights, so no crop separates them; the claim
  rests on the whole-frame number (0.00984) and on frames `02` and `11`.
- **The stair core is dim**, honestly so. The cabinet is on the best-lit wall
  of the best-lit core in the building — F01's pendant is 3.5 m away, the
  closest of any floor — and it is still a 1928 stair hall at three in the
  morning.
