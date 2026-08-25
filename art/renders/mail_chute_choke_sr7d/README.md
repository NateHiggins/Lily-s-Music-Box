# SR7-D — the lobby mail chute and its choke

**Status: production-rendered proof complete, with two limits stated below.**

Captured 2026-08-25 in Forward+ (NVIDIA RTX 4080, Vulkan 1.4.341) through the
real `res://scenes/building/orison_root.tscn`, on the real F01 lobby east wall,
shot through the player's own camera and lit by the lobby's own fittings plus
the player's service lamp. No proof-only light, mesh, material, camera rig or
production owner.

Harness: `res://tests/MaintenanceChuteShot.tscn` through the serialized Godot
runner with `-Windowed`.

## The truth this teaches

**The collection box is empty. That is not evidence.**

Two letters that sprang open across the choke bear on each other corner to
corner, and the whole column above stands on that arch. Friction and geometry
hold it, not weight — so pulling the box empty from below changes nothing. The
arch has to be *found* through the glass, its load taken off *before* it is
broken, and free passage afterwards proved by something arriving.

The transferable verb is **`flow`**, reused deliberately rather than invented:
the ruled six were complete at SR7-C. The radiator teaches flow as air leaving
a pipe before steam can enter; this teaches the same word for solids, where the
obstruction does not drain away but holds itself up.

## Sources

**Documented mechanism:**

- **J. G. Cutler, US 284,951, granted 11 September 1883** — the multi-floor
  letter-box connection, first installed in the Elwood Building, Rochester. Its
  requirements are the load-bearing part here: the chute front must be **at
  least three-quarters glass so that clogs can be identified**; the lobby box
  is metal, marked "U.S. LETTER BOX", door hinged at one side with its bottom
  **not less than two feet six inches above the floor** (0.762 m, used directly
  as `BOX_DOOR_MIN`); a chute above two storeys carries an elastic cushion in
  the receptacle; and hinged, locked doors along the chute exist expressly so
  that stuck mail can be dislodged.
- **J. J. Cusick, US 1,450,139, filed 12 July 1922, granted 27 March 1923** —
  the choke. Cusick's problem statement *is* this activity's fault in the
  period's own words: bulky letters are "bent and compressed" to get through
  the slot, then expand and jam. His answer is a floor-local auxiliary chute
  with an **expansion chamber above a deliberate choke**, so the choke
  "excludes from the main chute matter that would clog the latter".
  <https://patents.google.com/patent/US1450139A/en>

**Orison-specific inference, stated plainly:** that *this* chute is jammed
today; the particular two-envelope arch; the catch tray; the clearing blade;
the test piece; and the glazed door on the collection box. A 1912 building
running in 1928 with a Cutler chute and a Cusick choke retrofitted in the
twenties is a credible configuration, but this installation is authored.

## What production contained before

**Nothing postal that moves.** The audit found no mail chute anywhere — no
geometry, no marker, no prop, no layout record. The only continuous vertical
shafts in the building are the **refuse** chute at (2.45, 6.05) and the lift;
neither is postal. `LobbyMailBank` (tenant boxes) and `LobbyPostTray` exist but
neither is a `FunctionalProp` with a maintenance contract, and there is no mail
delivery or sorting simulation anywhere — `mail_catalog.json` is four static
entries filtered lazily.

This apparatus adds the chute's **bottom**, which is the only part anybody
services, and does not invent the rest.

## Definitive frames

All frames are 1280×720. SHA-256 truncated to 32 hexadecimal characters.

| Frame | SHA-256 | Claim |
| --- | --- | --- |
| `00_works_control_a.png` | `bcd815a07f72dc3078ea96e62a310687` | As found at the works: arch standing, load on it, cover locked. |
| `00_works_control_b.png` | `af78fffb6ac919489e6c857a4b8620db` | Same state, same camera — the works A/A floor. |
| `01_box_control_a.png` | `7c562496aca46ff6a8b193bec251bca2` | As found at the box: **empty, while the chute above is choked.** |
| `01_box_control_b.png` | `cb0c0cf9a0c138a4db2737840d705164` | Same state, same camera — the box A/A floor. |
| `02_lobby_wall_context.png` | `d56b7b268103d726851e46935f5b9cf9` | The apparatus in the real east-wall run, beside the tenant bank and post tray. |
| `03_lamp_finds_the_arch.png` | `df1c439829106aba0aefb878883d8b73` | The lamp index run up the three-quarters glass to where the chute stops being empty. |
| `04_avalanche_refused.png` | `c32d42da6cf4cd8e3bf03ae95e9ecd1d` | **The mechanically false order:** blade offered at the span with the whole column still on it. Refused, and shaking. |
| `05_load_taken.png` | `4efb7934c454d77bf9cb4a6128a7429b` | Glass drawn in its grooves, catch tray up, load off — arch still standing. |
| `06_arch_broken.png` | `6b39b05d024aecf72b5fdc86d500aec6` | The span goes; the choke is a hole again. |
| `07_box_still_empty.png` | `ca1cd1f3bd1f76a93db4a98d8b2d1729` | **The chute is now clear and the box looks exactly as it did when choked.** |
| `08_test_piece_landed.png` | `a77a761a4b28f217b1f9dc931e2df8b7` | The only evidence there is: a test piece lying in the glazed box. |
| `09_committed.png` | `2dcaeca39eca094b003a886e9a8358ae` | The committed condition, cover re-locked and glass shut. |
| `10_wall_after.png` | `05c6bb47ad3f10cfa8a544c665412372` | The wall run afterwards. |

## A/A pricing

Normalized RMSE, ImageMagick. Two frozen A/A pairs, one per close camera.

**Works camera** (floor **0.002154**):

| Pair | RMSE | × floor |
| --- | ---: | ---: |
| control A → control B | 0.002154 | 1.0 |
| control → avalanche refused | 0.060636 | **28.1×** |
| avalanche refused → load taken | 0.022016 | **10.2×** |
| load taken → arch broken | 0.008093 | **3.8×** |

**Box camera** (floor **0.001174**) — and this is the sheet's argument:

| Pair | RMSE | × floor |
| --- | ---: | ---: |
| control A → control B | 0.001174 | 1.0 |
| box choked → box clear | 0.007800 | 6.6× |
| **box clear → test piece landed** | **0.037576** | **32.0×** |

**Clearing the entire chute changes the collection box 0.0078. One letter
arriving in it changes the same box 0.0376 — 4.8× more.** That is the honest
measured form of "the empty box lies": the box is far more sensitive to a
single arrival than to the entire difference between choked and clear.

Weakest claim on the sheet: the arch dropping, 3.8× its floor. Strongest: the
test piece arriving, 32×.

## What this sheet does NOT prove, and one defect it exposes

- **It does not show a multi-floor shaft, because there is not one.** The chute
  runs up into the lobby ceiling and stops. No upper landing has a letter slot
  in production, so the activity's Orison line — a letter posted on a floor with
  no slot — is currently an anomaly with no family. Building the upper slots and
  a traversable barrel is the obvious follow-up and is deliberately not claimed.
- **An unrelated production defect is visible in these frames and I did not
  cause it.** A Dream asset is rendering in the waking lobby:
  `game/assets/dream/klimt_reflected_world_v1.png`, the Dream maze's
  equirectangular "reflected world" mural, appears as a large gold Klimt plate
  across the lower right of the wall — most obvious in `02_lobby_wall_context`
  and along the right edge of the works frames. Its only binding in the
  codebase is as the `reflected_world` shader uniform on the Dream's Klimt gold
  material (`dream_maze_builder.gd:725`), whose own comment states it is
  "sampled ONLY by the reflection vector of molten metal" — i.e. it should
  never be visible outside the Dream. It is **not** the player's lamp: the
  lamp's projector cookie bakes from `assets/ui/phone/mask_clean|cracked|haze.png`,
  which are correct torch patterns. The same artifact appears in the SR7-B
  elevator frames, so it predates this apparatus. The works and box cameras were
  turned a few degrees north to keep it off the subject; it is **reported, not
  repaired**, because the Dream lane is reserved this round.

## Executable proof

Every run went through `tools/run_godot_serial.ps1`.

- `MaintenanceChuteTest.tscn`: **PASS 54/54**. The book validates, holds the
  25–40 s window at five verbs, and is asserted to REUSE `flow` rather than
  invent a seventh word. `box_appears_empty()` is proved not to consult
  `arch_standing` — the apparatus never quietly tells the player the answer.
  The glass will not draw under a locked cover; the blade will not enter under
  one either; the arch cannot be cut with its load still on; a test piece posted
  into a choked chute never arrives; and no patch can call a choked chute clear.
- `MaintenanceChuteLiveTest.tscn`: **PASS 25/25**. In the real Orison the
  apparatus stands at (5.24, −6.75) strictly between the post tray and the
  porter board, faces the lobby, and **the measured mail-wall composition it
  was dropped beside is untouched** — bank still at z 7.88 with ≤16 meshes and
  its 24/18 elevation, tray still at 7.40, and the chute is a *sibling* of the
  bank rather than inside its mesh budget.
- `MailBankTest`, `DeadLettersTest`, `MaintenanceActivityTest`,
  `MaintenanceActivityLiveTest`, `MaintenanceServiceRoundTest`,
  `PassageVisibilityTest`, `InteractionInventory`, `ServiceWireResponseTest`:
  all **PASS**.
- `WalkTest` (FAST): the whole mail-wall clearance block is green — bank centre,
  tray derivation, the ≤16 mesh budget, the master-clock non-intersection and
  the **150 mm minimum measured at 0.179 m**, both leaf-sweep clearances and the
  0.70 m standing lane. Two failures remain (`the chirp hunt`, `boiler's long
  parts list stays merged`), both **pre-existing and reproduced identically on a
  clean `a29ea47`**.

## Ownership

The prop owns its apparatus and nothing else. It moves no mail, simulates no
postal round, closes no job, advances no case, publishes no Dream fact and adds
no save owner. Only `apply_maintenance_result` records the chute clear — and it
refuses to do so while the arch still stands.

Placement is one insertion in the existing `if floor_nodes.has("F01"):` block of
`orison_detail_pass.gd`, the same hand-authored seam SR7-A/B/C used.
`building_root.gd` is not touched.
