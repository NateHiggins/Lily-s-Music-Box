# SR7-A — the service dumbwaiter and its automatic holding brake

**Status: production-rendered proof complete.**

Captured 2026-08-24 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, lit only by the building's own
lobby-corridor lighting. There is no proof-only wall, prop, material, light or
camera rig: the harness builds the whole Orison (488 functional props, 18
residents, 254 light sources), walks the back-of-house corridor to the hatch the
detail pass places on the F01 partition, and works the mechanism through the
same public preview and commit seam `MaintenanceActivityPanel` uses.

Harness: `res://tests/MaintenanceDumbwaiterShot.tscn` through the serialized
Godot runner with `-Windowed`.

## The apparatus

The mechanical basis is the 1910 New York dumbwaiter named in
`design/ORISON_SERVICE_ROUND_BRIEF.md` — counterweight, lift sheave and
automatic holding brake, US 950,828. All four are visible and all four move:

| Part | Node | What it does here |
| --- | --- | --- |
| Lift sheave | `LiftSheave` | turns as the car travels |
| Counterweight | `Counterweight` | falls exactly as far as the car rises |
| Holding brake | `BrakeBand` | closes onto its drum and darkens as it bites |
| Holding pawl | `HoldingPawl` | swings clear once the hand carries the load |
| Hand rope | `HandRope` | draws taut and swings in under strain |
| Car | `Car` | rises against the weight |

The truth the chain teaches: **the counterweight carries nearly all of the car,
so the band holds only the difference.** That is why a brake this small is
enough, and why letting the rope go before the band has bitten is the whole
danger — the hand is holding the same few pounds the brake is about to.

## Definitive frames

All frames are 1280×720. SHA-256 truncated to 32 hexadecimal characters.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_control_a.png` | `d182e7d2f4abc612e7ffd9f116afae22` | The fault as found: band off the drum, pawl carrying alone, car low, weight high. |
| `00_control_b.png` | `828d7ec05fcb6362e3b03a1af5345607` | Same state, same camera, same frozen world — the A/A floor. |
| `01_strain_taken.png` | `c102fbb351ddd4203605e680c6c69410` | The hand rope drawn taut and swung in: the load is on the hand. |
| `02_pawl_clear.png` | `4e66f01c14a35443226fef24df630e8d` | The pawl lifts out of its ratchet, because and only because the rope is carrying. |
| `03_counterweight_answers.png` | `1e3083155be414147dcbcfbd8afc93b7` | The car rises, the counterweight falls the same distance, the sheave turns. |
| `04_band_seated.png` | `43a28a2e664892735605f086641d80c8` | Committed: the band is home and biting, and everything else is back as found. |
| `05_pawl_refused.png` | `8870ba98f621eadd8559a0ea87bdfa4a` | The pawl asked to come clear against a slack rope. It does not move, and the mechanism shudders. |
| `06_wall_run.png` | `94ec09a130d4e800a5a3ea7d383d8a4f` | The hatch in its corridor, with a real door beside it and the porter's board beyond. |

## A/A pricing

Normalized RMSE, ImageMagick. The declared subject ROI is `520x660+385+30` —
the apparatus itself — because the frame is mostly corridor and a whole-frame
delta understates every change the activity makes.

| Pair | Whole frame | Subject ROI |
| --- | ---: | ---: |
| control A → control B | 0.000533 | **0.000071** |
| control → strain taken | 0.014948 | **0.024483** |
| control → pawl clear | 0.022838 | **0.037415** |
| control → counterweight answers | 0.046298 | **0.075739** |
| control → band seated | 0.013458 | **0.022032** |
| pawl clear → pawl refused | 0.030236 | **0.049540** |

The weakest worked state (`04_band_seated`, which changes only how tightly the
band is drawn onto its drum and how that lining takes the light) clears the
same-camera A/A floor by **311×**. The pawl lesson — the difference between a
pawl that came clear and one that refused — is priced against `02` rather than
against the control, because that is the comparison the player actually makes.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`.

- `MaintenanceDumbwaiterTest.tscn`: **PASS 28/28**. The authored book validates,
  the order is enforced, all three rejection reasons name themselves without
  moving the chain, a refusal costs only the retry, abort commits nothing, and
  both accessibility assists widen the mechanism without abolishing it.
- `MaintenanceDumbwaiterLiveTest.tscn`: **PASS 24/24**. In the real Orison: the
  hatch exists on F01, clear of the passenger shaft, on the porter board's wall
  run, facing the corridor; every patent part is present; the brake is
  ray-reachable; the reach opens the authored 1910 activity by name; the whole
  chain lands on the production mechanism; and the result closes no job and
  advances no case.
- `MaintenanceActivityTest`, `MaintenanceActivityLiveTest`,
  `MaintenanceServiceRoundTest`, `MaintenanceJobTest`, `MaintenanceCounterTest`,
  `ServiceSetTest`, `ServiceWireResponseTest`: all **PASS**.
- `InteractionInventory`, `PassageNavTest`: **PASS**. The navigation collision
  audit reports 368–369 edges cut by real geometry across runs (it varies with
  the building clock) and 0 stair legs obstructed, unchanged in kind from before
  the casing was added.

## What this does not yet close

- The dumbwaiter serves one landing. SR7-A is the brake, not the shaft: there is
  no second opening on another storey and nothing rides between floors.
- The apparatus is not yet on the Service Round route, and no job, case or
  resident refers to it. The prop reports completion by signal and waits.
- **The porter's board and the lobby mail bank on this same wall run are turned
  the wrong way.** They use `rotation.y = +PI/2`, which points their working
  faces into the partition at x 5.33; `06_wall_run.png` shows the board's blank
  back. The dumbwaiter uses `-PI/2` and faces the corridor. Correcting the two
  older props is a one-line change each in `orison_detail_pass.gd`, but they are
  landed SR2/mail-pass work and were left alone here.
