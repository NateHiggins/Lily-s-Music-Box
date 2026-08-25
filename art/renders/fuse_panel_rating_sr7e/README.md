# SR7-E — the house panelboard's fuse rating

**Status: production-rendered proof complete.**

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, in `B1_ELECTRICAL` — the
basement electrical room production already had — on the front plane of the
baked cabinet `b1_panel0`. Shot through the player's own camera and lit by the
room's own cage bulb. No proof-only light, mesh, material, camera rig or
production owner.

Harness: `res://tests/MaintenanceFuseShot.tscn` through the serialized Godot
runner with `-Windowed`.

## The truth this teaches

**A fuse protects the WIRE, not the lamp.**

The link is sized to the conductor behind the wall, not to whatever is plugged
in at the far end. Put a thirty-ampere plug in a fifteen-ampere circuit and
every lamp still lights, nothing ever blows, and the last thing left to fail is
the wire itself. **There is no symptom.** The panel is working exactly as
somebody intended, and that is the fault.

The second truth is the safety one, and it is the first refusal in the chain:
the holder is LIVE whatever the lamps are doing. A fuse is not a switch.

Transferable verb: **`regulation`**, reused rather than invented — the ruled
six were complete at SR7-C. The dumbwaiter's brake band is sized to the load it
must hold; this fuse link is sized to the conductor it must protect. Same
principle, different machine.

## Sources

**Documented:**

- **The Edison base itself.** A 15, 20 or 30 ampere plug all screw into the
  same holder, so nothing in the fitting prevents the wrong one. This is the
  period hazard, and the National Electrical Code still answers it by
  restricting Edison-base plug fuses to existing installations showing *no
  evidence of overfusing or tampering*.
- **E. H. Taylor, assigned to Chase Shawmut Co., US 2,147,221,
  "Nontamperable and Noninterchangeable Plug Fuse", filed 21 September 1935,
  granted 14 February 1939.** Its stated objects name both period abuses
  exactly: that "a plug fuse having a larger current carrying capacity than is
  intended for the circuit cannot be inserted in the receptacle", and that "the
  terminals of the receptacle cannot be bridged readily by a metal conductor" —
  the coin behind the fuse.
  <https://patents.google.com/patent/US2147221A/en>

**Note the dates, because they are the point.** Taylor's rejection base is the
*cure*, and it is filed seven years after the Orison's 1928. This panel is the
disease with no cure yet available: every plug in the drawer fits every hole,
and the only thing between the building and a fire in the wall is somebody
reading a stamped number. `rating_at()` carries no gate because an Edison base
carries no gate, and the focused test asserts that.

**Orison-specific inference, stated plainly:** that *this* circuit is over-fused
today, the particular 30-in-a-15, the circuit card, the spare drawer, the lamp
index and the rejected-plug pose. The room, the three cabinets and the feeder
conduit are not — they predate this work.

## What production already owned

This apparatus adds **no second electrical plant**, because one exists:

- `B1_ELECTRICAL`, rect `[5.51, -9.65, 13.65, -1.0]`, a real generated room;
- `b1_panel0/1/2`, three baked cabinets on its east wall at x 13.30–13.44,
  standing 0.9 to 1.9 m above the basement floor, with `b1_econduit` on the
  same wall;
- `B1_ELECTRICAL_HUB` at `[10.0, -5.0, -2.4]` — **127 neighbours, the largest
  node in the acoustic/possession graph**, carrying the building's electrical
  spine;
- `SwitchSystem`, whose own header calls the switch *"the only thing that
  changes room power"*, over `LightFixtureProp.powered`.

What none of the three cabinets had was an inside. This is the working face of
the first of them: it stands on that cabinet's own front plane and builds west
into the room, so the baked box is its back.

## Definitive frames

All frames are 1280×720. SHA-256 truncated to 32 hexadecimal characters.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_panel_control_a.png` | `8819bad24af3964999423ef22045ce87` | As found: a thirty in a fifteen-ampere circuit, main closed, panel live, everything working. |
| `00_panel_control_b.png` | `8819bad24af3964999423ef22045ce87` | Same state, same camera — **byte-identical**. |
| `01_room_context.png` | `6e7c7ea2280fbeb9c3d80d460796a48e` | The apparatus in `B1_ELECTRICAL`, beside the cabinets production already had. |
| `02_stamp_read.png` | `878893a5165f51c7eb479d2dbb96fd3c` | The lamp index down at the cap: the stamped rating is the only place the fault is written. |
| `03_live_draw_refused.png` | `1126a969f3e0041964303919e2c939b1` | **Refusal 1 — the holder is live.** The plug lifts and is held; it will not come out under the main. |
| `04_main_open.png` | `8af5f48c5ec975f5e977f739c0fae46b` | Blades standing clear of their jaws. A knife switch shows you it is dead. |
| `05_plug_out.png` | `d70e8f597264e40eb4a400def67d174e` | The plug out, its link whole. It never blew because it never could. |
| `06_bigger_plug_refused.png` | `5edc887b1ca325b5cef9e5e7f2a5d82b` | **Refusal 2 — the fault offered as a repair.** Another thirty, held at the base mouth, refused. |
| `07_fifteen_seated.png` | `67840d48081c8f1b896be606ce48764a` | A fifteen seated; the warning stamp goes quiet. |
| `08_proved_under_load.png` | `c90b41669532b13f5f8e77e565a32644` | Main closed, proved under the circuit's whole load. |
| `09_committed.png` | `ed4e59e5c24b5de4b0645341a1adff40` | The committed condition. |
| `10_room_after.png` | `0770d26880241ef848616544acdb7331` | The room afterwards. |

## A/A pricing

Normalized RMSE, ImageMagick. **The A/A pair is byte-identical: RMSE exactly
0.000000**, confirmed by matching SHA-256. With `Engine.time_scale` at zero and
the prop's `_process` stopped, nothing in these frames moves between two
captures of the same state. Every state claim is made on that same camera, so
all of them are priced against that one floor.

| Pair | RMSE |
| --- | ---: |
| control A → control B | **0.000000** |
| control → stamp read | **0.052358** |
| stamp read → live draw refused | **0.005577** |
| live draw refused → main open | **0.002668** |
| main open → plug out | **0.004072** |
| plug out → **bigger plug refused** | **0.005554** |
| bigger plug refused → fifteen seated | **0.006492** |
| fifteen seated → proved under load | **0.002668** |
| control → committed | **0.052267** |

All twelve frames hash differently. Weakest claim: the main opening and closing
at 0.002668. Strongest: the stamp read at 0.052358.

**One earlier sheet had to be thrown away to get here.** The refusals were
originally a `sin(_t)` shudder, so with the world frozen for a photograph
`06_bigger_plug_refused` came back *byte-identical* to `05_plug_out` — a
refusal that only exists while the clock runs cannot be shown to anybody. Both
refusals are now deterministic poses: the plug lifts and is held, and the
oversized plug is held visibly at the mouth of the base that will not take it.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`.

- `MaintenanceFuseTest.tscn`: **PASS 56/56**. The book validates, holds the
  25–40 s window at five verbs, and reuses `regulation` rather than widening
  the ruled six. A 10, 15, 20 and 30 are all selectable in the same holder —
  the hazard itself, asserted. The plug will not be drawn under the main; a 20
  and a 30 are both refused and leave `fitted_rating` untouched; an over-fused
  panel carries its load perfectly and is *still* refused; and no patch can
  call an over-fused panel safe.
- `MaintenanceFuseLiveTest.tscn`: **PASS 27/27**. In the real Orison the
  apparatus stands on `b1_panel0`'s own front plane, inside `B1_ELECTRICAL`, at
  the cabinet's own height, facing the room; the reach opens the authored
  activity by name; and the whole chain lands. **The cross-system proof:
  231 lamps powered before and 231 after, no `room_toggled` published, the
  switch count unchanged at 215, and the electrical graph bit-for-bit what it
  was (127 hub neighbours, same node count).** The apparatus also adds no graph
  node of its own.
- `MaintenanceActivityTest`, `MaintenanceActivityLiveTest`,
  `MaintenanceServiceRoundTest`, `MaintenanceChuteLiveTest`,
  `InteractionInventory`: all **PASS**.
- `WalkTest` (FAST): 2 failures — `production spine loads the one authored job,
  the chirp hunt` and `boiler's long parts list stays merged (23 meshes)`. Both
  **pre-existing and reproduced identically on a clean `cf27f9a`**.

## Ownership

The prop owns its own panel and nothing else. It does not own the building's
lighting: `SwitchSystem.toggle_room()` remains the only thing that changes room
power and this apparatus never calls it. It closes no job, advances no case,
mutates no Dream state and adds no save owner. Only
`apply_maintenance_result` may record the panel safe — and it refuses unless
the fitted plug is no larger than the conductor.

Placement is one new `if floor_nodes.has("B1"):` branch in
`orison_detail_pass.gd`, the seam SR7-A through SR7-D used.
**`building_root.gd` is not touched**, and no `PROP_SCRIPTS` kind is
registered, so `walk_test`'s warehouse-orphan check is unaffected.

## REPORTED, NOT REPAIRED — and a correction to SR7-D

The player's service lamp is **deliberately off in this sheet**, and that is a
finding rather than a preference.

`_bake_cookie()` in `player_controller.gd` assigns `flashlight.light_projector`
from `_mask_view.get_texture().get_image()`. The three mask plates it is meant
to bake (`assets/ui/phone/mask_clean|cracked|haze.png`) are correct — I checked
them. But the baked **result** is not: the SubViewport's render target is
sampled before that viewport has drawn its own content, so the cookie captures
whatever frame was last resident in the target — currently a Dream Klimt plate
— and the torch then projects a gold mural onto the waking building.

Evidence:

- A paired capture of this same sheet with `set_lamp_enabled(false)` removes it
  **entirely**; with the lamp on it covers half the frame.
- The artifact has a hard straight cone edge and wraps over geometry, which is
  what a spotlight cookie does and what a reflection does not.
- It survives `cf27f9a`, which retired `klimt_reflected_world_v1.png`. A
  sibling plate, `klimt_reflected_rooms_v1.png`, is still present and tracked,
  and its flowerbed band and panel borders match what the cookie is projecting.

**This corrects my SR7-D report**, which stated the artifact was "not the
player's lamp". That conclusion was drawn from the source plates alone and was
wrong; the retirement of the world plate was therefore aimed at the wrong
target. The leak is in the cookie bake, not in any one asset.

Not repaired here: the renderer and Dream lanes are reserved this round.

## Limitations

- **One circuit, one cabinet.** `b1_panel1` and `b1_panel2` remain baked boxes.
  Nothing in the building consults `panel_safe`, and no lamp anywhere is on the
  circuit this panel protects — the conductor rating is a fact of the apparatus,
  not of a modelled circuit.
- Not on the Service Round route, and no job, case or resident refers to it.
- The apparatus is not on the acoustic/possession graph. Adding a node would
  mean a generator re-bake and an edge nobody asked for; `B1_ELECTRICAL_HUB`
  already carries this room.
