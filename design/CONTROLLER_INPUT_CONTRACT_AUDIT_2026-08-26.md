# Controller input contract audit — 2026-08-26

> **IMPLEMENTATION NOTICE — `1112cb9`, 2026-08-26:** the H1, H2, H4 and H5
> blockers identified below are now implemented on `main`. Maintenance uses
> semantic adjust/commit/cancel actions; the Otis board owns focus and accepts
> directional selection, accept and cancel; left-stick movement and
> right-stick rate look reach the shared player paths; and the first complete
> world/UI controller map is registered in `game_boot.gd`. Evidence:
> `ControllerInputTest` PASS 20/20, `MaintenancePanelInputTest` PASS 17/17,
> `OtisPanelInputTest` PASS 7/7, `MaintenanceActivityTest` PASS, and
> `InteractionInventory` exit 0. This is an implementation milestone, **not a
> certification claim**: the physical-pad matrix and first-minute playthrough
> required by §§7–8 remain outstanding.

**Purpose:** the complete input contract for the Early Access vertical slice, as
an implementation brief and acceptance matrix. **This document does not claim
controller support exists. It defines what would have to be true before anyone
may say so.**

**Base audited:** `f9d3fdc` — the pushed `origin/main` tip at commit time.
The audit began at `d36e591` and **origin advanced three commits during the
work**, two of which touch input directly: `44c921e` "Reduce camera roll and
tune look sensitivity" and `14d5edf` "Let players suppress lightning flashes".
Rather than ship a document that was stale on arrival, the branch was moved to
the new tip and every affected row re-verified. What changed is recorded in
§4.1; **no joypad, invert-Y or dead-zone work landed, so every controller
finding below stands unchanged.**

**No Godot was launched. No code, project setting, scene, test, render,
`TASKS.md` or existing document was edited.** Repository source is authoritative
for current behaviour; Godot 4 official documentation is the only source used
for engine claims.

---

## 1. The ruling

> ### "Controller supported" is currently **FALSE**. Not partial. Not unknown.

A player holding a gamepad **cannot move and cannot look**. Two shoulder buttons
are bound, on top of an otherwise keyboard-and-mouse-only scheme
(`game/scripts/game_boot.gd:19–22`):

```gdscript
const JOYPAD_ACTIONS := {
    "lamp_toggle": JOY_BUTTON_LEFT_SHOULDER,
    "radio_toggle": JOY_BUTTON_RIGHT_SHOULDER,
}
```

`move_*`, `run`, `crouch`, `jump` and `interact` carry **only** keyboard events
(`:5–13`). Look is read from raw `InputEventMouseMotion`
(`player_controller.gd:365–367`). A repository search for `JOY_AXIS`,
`InputEventJoypadMotion` or `get_axis` in the player and boot scripts returns
nothing.

**Two shoulders are not a controller.** They are a convenience for a player
already holding a keyboard.

### The good news, which is structural

The hard part is already done. `PlayerController` **polls semantic actions**
rather than consuming raw events, deliberately, so that on-screen touch buttons
using `Input.action_press()` reach the same code path
(`player_controller.gd:344–351`, comment: *"POLLED, not event-driven… Polling is
the one path both a key and a thumb travel"*). **Every polled action becomes
controller-capable the moment a joypad event is added to it — no gameplay code
changes.** Movement already runs through `Input.get_vector()`
(`player_controller.gd:951`), which Godot documents as applying a circular
deadzone and returning analog strength.

**Two things are not free**, and they are the whole engineering cost: **look**
(§4) and **the modals** (§6).

---

## 2. Complete action × device matrix

**24 rows.** Device columns: **KB/M** = keyboard/mouse today, **Touch** =
`ui/touch_controls.gd` today, **Pad** = gamepad today, **Required** = the
binding this contract asks for. Xbox-style physical names throughout; see §5 for
equivalents.

### 2.1 Locomotion and camera

| # | Semantic verb | KB/M today (owner) | Touch | Pad today | Required pad | Hold/toggle |
| --- | --- | --- | --- | --- | --- | --- |
| 1 | `move_forward` | W — `game_boot.gd:6` | stick | **✘** | **LS ‑Y** | analog |
| 2 | `move_back` | S — `:6` | stick | **✘** | **LS +Y** | analog |
| 3 | `move_left` | A — `:7` | stick | **✘** | **LS ‑X** | analog |
| 4 | `move_right` | D — `:7` | stick | **✘** | **LS +X** | analog |
| 5 | **look** | `InputEventMouseMotion` — `player_controller.gd:365` **RAW** | drag → `look_delta` | **✘** | **RS, rate-based** | analog, §4 |
| 6 | `run` | Shift hold — `:975` | button | **✘** | **LT (hold)** + toggle option | **hold only today** |
| 7 | `crouch` | C toggle — `:358` | button | **✘** | **L3** | toggle |
| 8 | `jump` | Space — `:8` | — | **✘** | **Y** | press |

### 2.2 The physical verbs

| # | Semantic verb | KB/M today | Touch | Pad today | Required pad | Notes |
| --- | --- | --- | --- | --- | --- | --- |
| 9 | `interact` | E — `player_controller.gd:333` | button | **✘** | **A** | *the* universal verb; deserves the best button |
| 10 | `lamp_toggle` | L — `:338` | button | **LB** ✔ | **LB (keep) + X** | survives `call_locked` by design |
| 11 | `radio_toggle` | R — `:340` | button | **RB** ✔ | **RB (keep)** | survives `call_locked` by design |
| 12 | `music_player` | M — `music_director.gd:341` | — | ✘ | **UNKNOWN — §9** | reachability in the release build unverified |

### 2.3 Modal ownership

| # | Verb | KB/M today | Pad today | Required pad | Owner |
| --- | --- | --- | --- | --- | --- |
| 13 | open Building Services | `ui_cancel` — `player_controller.gd:370` | ✘ | **Menu/Start** | `pause_services.gd` |
| 14 | close Building Services | `ui_cancel` — `pause_services.gd:73` | ✘ | **B** or Menu | same |
| 15 | apply / return | mouse click | ✘ | **A** on focused button | same |
| 16 | close call | `ui_cancel` — `call_interface.gd:326` | ✘ | **B** | `call_interface.gd` |
| 17 | choose call option | mouse click | ✘ | **A** on focused button | same |
| 18 | choose dialogue option | mouse click — `case_dialogue_panel.gd:62` | ✘ | **A** on focused button | same |
| 19 | UI focus move | mouse / `ui_*` | ✘ | **D‑pad + LS** | every panel |
| 20 | close title settings | `ui_cancel` — `title_screen.gd:486` | ✘ | **B** | `title_screen.gd` |
| 21 | close elevator panel | **raw `KEY_ESCAPE`** — `otis_panel.gd:223–227` | ✘ | **B** | **RAW, §3** |

### 2.4 The repair mechanism

| # | Verb | KB/M today | Pad today | Required pad |
| --- | --- | --- | --- | --- |
| 22 | activity adjust | **raw `KEY_A`/`KEY_LEFT`/`KEY_D`/`KEY_RIGHT`, raw mouse motion, raw wheel** — `maintenance_activity_panel.gd:126–145` | **✘ by construction** | **LS ‑X/+X (analog) + D‑pad L/R (step)** |
| 23 | activity commit | **raw `KEY_E`/`KEY_SPACE`** — `:136` | **✘** | **A (hold-capable)** |
| 24 | activity abort | **raw `KEY_ESCAPE`** — `:121` | **✘** | **B** |

### 2.5 Developer bindings — **NEVER bound to a public controller input**

`shot_capture` (F), `noclip` (V), `debug_panel` (F1), `intro` (F2) —
`game_boot.gd:9,12–13`. **No gamepad button, stick click, trigger or chord may
reach any of these.** `noclip` in particular is polled in
`_process` (`player_controller.gd:352`) and would fire from any bound pad button.

---

## 3. Raw-event ownership hazards

**These are the blockers. An action read from a raw event type cannot be reached
by a gamepad no matter what is bound**, because a joypad emits
`InputEventJoypadButton` / `InputEventJoypadMotion`, and none of these sites
look at those.

| # | Site | Reads | Consequence |
| --- | --- | --- | --- |
| **H1** | `maintenance_activity_panel.gd:117–145` | `InputEventKey` keycodes `KEY_ESCAPE`, `KEY_A`/`KEY_LEFT`, `KEY_D`/`KEY_RIGHT`, `KEY_E`/`KEY_SPACE`; `InputEventMouseMotion.relative.x`; `MOUSE_BUTTON_WHEEL_*` | **The hero repair mechanism — beat 6 of the eleven — is unreachable from a gamepad by construction.** This is the single most important finding in this document. |
| **H2** | `player_controller.gd:365–367` | `InputEventMouseMotion` | look is mouse-shaped; a stick is position, not delta (§4) |
| **H3** | `player_controller.gd:368–369` | `InputEventMouseButton` → recapture mouse | harmless on pad, but the capture model has no pad equivalent (§7) |
| **H4** | `otis_panel.gd:223–227` | raw `KEY_ESCAPE` | elevator panel cannot be dismissed on pad |
| **H5** | `otis_panel.gd:198–215` | `gui_input` mouse motion + click | elevator floor selection is pointer-only |
| **H6** | `shot_capture.gd:30` | `_unhandled_key_input` | correct as-is — keep it key-only |

**Rule for the fix:** every one of H1, H4, H5 must be converted to **semantic
`InputMap` actions** before any binding work is worth doing. Binding buttons
first would produce a controller that walks around a building it cannot operate.

---

## 4. Look is the one genuinely new code path

`apply_look(rel: Vector2)` (`player_controller.gd:508–517`) consumes a **pixel
delta** and multiplies by `MOUSE_SENS := 0.0023` (`:31`). Mouse and touch drag
both produce deltas, so they share it correctly — the comment at `:513–514` says
so deliberately.

**A stick does not produce a delta. It produces a held position.** Feeding an
axis value into `apply_look()` yields a turn rate that depends on frame rate,
which is wrong.

**Required shape** (design, not implementation):

- a new rate-based entry point alongside `apply_look`, e.g.
  `apply_look_rate(axis: Vector2, delta: float)`, called from `_process`;
- turn rate in **radians per second**, multiplied by `delta`;
- both paths must end in the same clamp (`camera.rotation.x` to ±1.45, `:517`)
  and the same carried-device hand-lag call (`:515–516`), so mouse and stick
  cannot drift into two different feels — the existing comment's stated intent.

### 4.1 What landed mid-audit, and what it does not change

`44c921e` added `look_sensitivity` (0.25–2.0, persisted, in-game slider) and
`reduce_camera_roll`; `14d5edf` added `reduce_flashing`. These close three
findings from
`design/STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md`, and `eb7f1ad`
corrected an error of mine in that document — the always-on breathing sway
belongs to the **held service lamp**, not the camera; the uncontrolled camera
motion was event-driven **roll** during stagger and altered gravity, which now
has a reduction toggle.

**None of it moves the controller ruling.** No `JOY_AXIS`,
`InputEventJoypadMotion`, invert-Y or dead-zone code landed. The sensitivity
multiplier is applied inside `apply_look()`, which still consumes a **pixel
delta** — so it scales mouse and touch correctly and would scale a stick
**wrongly**, because the stick's problem is not gain, it is that a held position
is not a delta (below).

**Still missing today, for every device:**

| Setting | Status | Required |
| --- | --- | --- |
| look sensitivity | **IMPLEMENTED** — `look_sensitivity` 0.25–2.0, persisted, with an in-game slider (`player_controller.gd:511–514`, `pause_services.gd`) | **split it per device** — one multiplier cannot serve a pixel delta and a stick rate |
| invert Y | **absent** | per-device toggle, persisted |
| dead zone | **absent** (`get_vector` default: derived from action deadzones) | explicit inner dead zone, stick only |
| response curve | **absent** | a gentle exponent (design value ~1.5–2.0) applied to stick magnitude only — never to mouse |
| radial clamp | present for movement via `get_vector` | required for look magnitude too |

**Engine confirmation:** Godot documents `Input.get_vector()` as applying a
circular dead zone and limiting length to 1, and `get_action_strength()` as
returning scaled analog strength. **So movement needs no new code — only axis
events on the four `move_*` actions.** Look does need new code.

---

## 5. Recommended default layout

**One conventional Xbox-position layout.** PlayStation and Nintendo names below
describe **equivalent physical positions only**. This document makes **no
platform certification claim**; certification requirements are **UNKNOWN** (§9).

| Physical position | Xbox | PS equivalent | Nintendo equivalent | Bound verb |
| --- | --- | --- | --- | --- |
| left stick | LS | L3 stick | L stick | move (analog) |
| left stick click | L3 | L3 | L stick press | `crouch` (toggle) |
| right stick | RS | R3 stick | R stick | look (rate) |
| right stick click | R3 | R3 | R stick press | **reserved — unbound** |
| bottom face | **A** | ✕ | B | **`interact`** — the universal verb |
| right face | **B** | ○ | A | **back / cancel** |
| left face | **X** | □ | Y | `lamp_toggle` (second home) |
| top face | **Y** | △ | X | `jump` |
| left bumper | **LB** | L1 | L | `lamp_toggle` **(existing — preserved)** |
| right bumper | **RB** | R1 | R | `radio_toggle` **(existing — preserved)** |
| left trigger | **LT** | L2 | ZL | `run` (hold) |
| right trigger | **RT** | R2 | ZR | **reserved — unbound** |
| menu / start | **Menu** | Options | + | Building Services |
| view / back | **View** | Create | − | **reserved — unbound, never debug** |
| D-pad | D-pad | D-pad | D-pad | UI focus; activity step adjust |

**Why these choices:**

- **`interact` on A.** The game's own comment calls E *"the universal physical
  verb"* (`player_controller.gd:331`). The universal verb takes the button a
  thumb rests on.
- **LB/RB keep lamp and radio.** They are already bound and the existing comment
  explains why — *"reachable while both thumbs steer and look"*
  (`game_boot.gd:16–18`). That reasoning is correct and survives; X mirrors lamp
  for discoverability without removing LB.
- **`run` on LT, not L3.** L3 is taken by crouch, and an analog trigger gives a
  hold that does not fight the movement thumb.
- **Two positions deliberately empty.** R3 and RT are reserved so a later verb
  has somewhere conventional to go. **View/Back is left empty specifically so no
  one is tempted to put the debug panel there.**
- **"One physical verb" is preserved**: `interact` remains a single button that
  means "do the physical thing in front of you", and lamp/radio remain physical
  switches that work even while `call_locked` (`player_controller.gd:337–342`).

---

## 6. Modal ownership state table

The existing contract, which this preserves: **calls and seated interactions own
Back; ordinary play may open Building Services.**

| State | Owner | Back/B does | Menu does | A does | Focus needed |
| --- | --- | --- | --- | --- | --- |
| ordinary play | `PlayerController` | *(reserved — nothing)* | **open Building Services** | `interact` | — |
| Building Services open | `pause_services.gd` | **close without saving** | close | activate focused control | **✘ MISSING** |
| call active (`call_locked`) | `call_interface.gd` | **close call** | **refused** — `can_open():33` | choose focused option | **✘ MISSING** |
| seated interaction | seat owner | seat owner | **refused** — `can_open():34` | `interact` still passes (`:333`) | **✘ MISSING** |
| case dialogue | `case_dialogue_panel.gd` | *(none today)* | ? | choose focused option | **✘ MISSING** |
| maintenance activity | `maintenance_activity_panel.gd` | **abort** (raw ESC) | ? | commit (raw E/Space) | n/a — raw |
| elevator panel | `otis_panel.gd` | **close** (raw ESC) | ? | select floor (pointer) | n/a — raw |
| title settings | `title_screen.gd` | **close** — `:486` | — | activate focused control | **✘ MISSING** |
| dream | `PlayerController` + dream owners | *(reserved)* | **UNKNOWN — §9** | `interact` | — |

### The focus blocker

**`grab_focus()` is called exactly once in the entire codebase**
(`ui/songbook_panel.gd:198`, a text field). **No release-route modal grabs focus
when it opens, and no `focus_mode` or `focus_neighbor` is set anywhere.**

Godot's `Button`, `CheckBox`, `HSlider` and `OptionButton` default to focusable,
so `ui_up`/`ui_down` *can* traverse them — but with **no initial focus**, a pad
player opening any panel has nothing highlighted and no obvious way in.
**Every modal must grab focus on open and restore it on close.** This is
cheap and it is non-negotiable for a pad claim.

### Conflict risks

| # | Risk | Detail |
| --- | --- | --- |
| C1 | **`ui_cancel` overloaded** | it both opens Building Services in play (`player_controller.gd:370`) and closes panels (`pause_services.gd:73`, `call_interface.gd:326`, `title_screen.gd:486`). Moving *open* to **Menu** and leaving *close* on **B** removes the overload cleanly. |
| C2 | **`ui_cancel` default pad binding is UNKNOWN** | not verified from official Godot docs in this pass. **Bind explicit joypad events rather than relying on an engine default.** |
| C3 | **lamp/radio survive `call_locked` by design** | correct and must be preserved: `:337–342` runs before the `call_locked` return at `:343`. LB/RB must keep working during a call. |
| C4 | **`interact` passes through while seated** | `:333–335` deliberately allows E when `seated_interaction` is valid. A on pad must inherit exactly this, not a simplified version. |
| C5 | **Activity panel vs player polling** | the panel calls `set_input_as_handled()`, but `PlayerController` **polls** in `_process` and never sees `handled`. Once A is bound to `interact`, pressing A to commit a repair step could **also** fire `use_primary_interaction()`. **This is a real double-fire risk created by the polled design and must be tested explicitly.** |
| C6 | music player / arcade / phone panels | reachability in the release build unverified (§9) |

---

## 7. Mouse/controller hot-swap

Today the mouse is **captured** on click and released to visible when a panel
cannot open (`player_controller.gd:368–372`). There is no device-active concept.

**Required:** last-input-wins. A joypad event marks pad-active and hides the
cursor; a mouse motion or click marks mouse-active and restores capture.
`touch_input` already gates one branch (`:368`), so the notion of a current
device partially exists and should be generalised rather than duplicated.

**Non-goal for the first pass:** swapping button glyphs per detected pad brand.

---

## 8. Smoke tests

### 8.1 Minimum controller smoke test — waking route

**Pad only. Keyboard and mouse physically unplugged.** Fails at the first step
that needs another device.

1. Title screen: navigate to settings, change a volume slider, close, start.
2. Walk from the curb into the lobby; look around freely both axes.
3. Clock in at the watchman's detector (`interact`).
4. Take the first report at the night register.
5. Open Building Services (Menu), toggle a setting, apply, return.
6. Climb to F02, read the landing plate, cross to 2A, open the door.
7. **Find the Vantry fault by ear** and inspect the grille (`interact`).
8. Run the maintenance activity to a committed repair — **adjust, commit,
   and abort at least once** (H1).
9. Answer or dismiss one telephone call: B closes, A chooses.
10. Toggle lamp (LB and X) and radio (RB), **including during a call** (C3).

**Pass = all ten unaided, with no double-fire (C5) and no state where nothing
is focused (§6).**

### 8.2 Dream smoke test — separate, because it is the fairness test

1. Reach onset and enter the dream on pad.
2. Move and look under pursuit at full stick deflection; confirm the response
   curve does not make fine aim impossible.
3. **Make the lamp decision under pressure** — the game's central choice — using
   LB and X.
4. Survive or fail, and **wake in 4B**, on pad.
5. Confirm no dream-specific verb is unreachable and no modal opens without
   focus.

**Explicitly out of scope for both: rumble.** See §10.

---

## 9. Unknowns

| # | Unknown | Why it is not guessed |
| --- | --- | --- |
| U1 | Godot's default joypad bindings for `ui_cancel` / `ui_accept` / `ui_*` | not verifiable from the official pages fetched; the contract binds explicit events instead |
| U2 | Whether the music player, arcade and phone panels are reachable in the release build | reachability was not traced to the release route |
| U3 | Whether the dream has any verb beyond move/look/lamp/interact | dream input was not exhaustively traced |
| U4 | Console certification requirements | **UNKNOWN.** No platform-holder guidance was consulted; consoles are out of scope for Early Access |
| U5 | Whether any activity step imposes a reaction window | `maintenance_activity_run.gd:55` takes `hold_seconds` and a `tolerance`; a human must judge the timing envelope |
| U6 | Focus traversal order once focus exists | needs a running build |

---

## 10. Rumble — audited, and the answer is **not yet, and never for hazards**

The brief asked for an audit before any recommendation. Here it is.

**Rumble tied to dream hazards or pursuit proximity must not ship.** The dream's
entire design withholds distance: the caption layer is capped at *"the cue, and
one of eight sectors"*, and `game_boot.gd:48–52` states the reason — a caption
reader *"must get what the ear gets and no more, or the light decision the dream
is built on stops costing anything."* **A proximity rumble would hand a pad
player exactly the distance channel that captions deliberately refuse**, making
the game easier on one device and unfair on another. That is a design break, not
a feature.

**Rumble on confirmed mechanism contact** — the grille seating, a switch
catching — duplicates information the player already receives through sound and
visible result, leaks nothing hidden, and is the one legitimate use. **Even so
it is a post-Early-Access item**, because it needs the same
declaration-evidence treatment as any other claim.

**First-pass ruling: no haptics of any kind.**

---

## 11. Acceptance criteria for "controller supported"

All must hold simultaneously:

1. **A1** Both smoke tests (§8) pass **pad-only**, keyboard and mouse unplugged.
2. **A2** Every row of §2.1–2.4 has a working pad binding.
3. **A3** **No** developer action (§2.5) is reachable from any pad input.
4. **A4** No release-route verb is read from a raw event type (H1, H4, H5 fixed).
5. **A5** Every release-route modal grabs focus on open and restores on close.
6. **A6** Look has stick sensitivity, invert-Y, dead zone and response curve,
   all persisted, and mouse feel is unchanged.
7. **A7** No double-fire between a modal and the polled player loop (C5), proved
   by a test.
8. **A8** Hot-swap works mid-session in both directions without a restart.
9. **A9** An automated test asserts the joypad binding table matches this
   document, so a future edit to `JOYPAD_ACTIONS` cannot silently break it.
10. **A10** A human has completed a full shift on pad and signed the
    declaration-evidence row from
    `design/STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md` §9.

---

## 12. Implementation order

By owner path. **Refactor before binding** — binding first produces a controller
that can walk around a building it cannot operate.

| Step | Owner path | Work |
| --- | --- | --- |
| **1** | `ui/maintenance_activity_panel.gd` | H1 — replace raw keycodes with semantic actions (`activity_adjust_left/right`, `activity_commit`, `activity_abort`). **Highest value: this is the hero mechanism.** |
| **2** | `ui/otis_panel.gd` | H4/H5 — semantic close; focusable floor selection |
| **3** | `game_boot.gd` | add joypad events to existing actions per §5; add the new activity actions; **touch nothing in the developer set** |
| **4** | `player/player_controller.gd` | `apply_look_rate()` (§4); pad-aware capture/hot-swap (§7) |
| **5** | `game_boot.gd` + `ui/pause_services.gd` + `ui/title_screen.gd` | sensitivity, invert-Y, dead zone settings, persisted, with a control on both surfaces |
| **6** | every release-route modal | `grab_focus()` on open, restore on close, explicit `focus_neighbor` where the default order is wrong |
| **7** | `ui/pause_services.gd`, `call_interface.gd`, `case_dialogue_panel.gd`, `title_screen.gd` | Menu/B semantics per §6 |
| **8** | `game/tests/` | binding-table test (A9); double-fire test (A7); pad-only smoke checklist |

**Non-goals for the first pass:** remapping UI; per-brand glyphs; haptics;
console certification; touch parity beyond what exists; `music_player`, arcade
and phone panels unless U2 puts them on the release route.

**Remapping ruling:** **not required for Early Access.** It is a real
accessibility gap and is recorded as such in the accessibility audit, but a
correct fixed layout that reaches every verb is worth more than a remapper over
an incomplete one. Sequence it after A1–A10.

---

## 13. Forbidden wording until acceptance passes

**None of the following may appear in a store page, press kit, capsule, trailer,
festival listing, devlog or reply to a player** until §11 passes in full:

- "Controller support" · "Full controller support" · "Gamepad supported"
- "Partial controller support" — **also forbidden**: it implies you can play
  with a pad and merely navigate menus with a mouse. You cannot move or look.
- "Steam Deck compatible/verified" — Deck review tests controller support
  (`STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md` §10 S1 family)
- "Remappable controls" · "Custom controls" · "Play your way"
- "Invert Y" — absent for every device
- "Camera Comfort" — **look sensitivity and camera-roll reduction now exist**,
  but Valve's requirement also covers disabling uncomfortable motion generally,
  and the label is assessed in the accessibility audit, not here. Do not tick it
  on the strength of the controller work
- "Adjustable sensitivity" **for a controller** — the slider is real, but there
  is no controller for it to adjust
- Any capsule or screenshot showing a controller glyph

**Permitted today:** "Keyboard and mouse." Nothing more.

---

## 14. Sources

**Repository, at `d36e591`** — authoritative for current behaviour:
`game/scripts/game_boot.gd:5–22`; `game/scripts/player/player_controller.gd:31,
325–380, 508–517, 951–975`; `game/scripts/ui/touch_controls.gd:89–92, 152–160,
192`; `game/scripts/ui/pause_services.gd:32–35, 73–76`;
`game/scripts/ui/maintenance_activity_panel.gd:117–145`;
`game/scripts/ui/otis_panel.gd:198–227`; `game/scripts/call/call_interface.gd:326`;
`game/scripts/ui/case_dialogue_panel.gd:62`; `game/scripts/ui/title_screen.gd:486`;
`game/scripts/ui/shot_capture.gd:30`; `game/scripts/audio/music_director.gd:341`;
`game/scripts/ui/songbook_panel.gd:198`;
`game/scripts/game/maintenance_activity_run.gd:55`.

**Godot 4 official documentation**, accessed 2026-08-26:

| Page | URL | Supports |
| --- | --- | --- |
| `Input` class reference | https://docs.godotengine.org/en/stable/classes/class_input.html | `get_vector()` circular dead zone, length limited to 1, dead zone auto-derived from action dead zones when `-1.0`; `get_action_strength()` analog scaling; `exact_match` ignoring joypad motion direction |
| InputEvent tutorial | https://docs.godotengine.org/en/stable/tutorials/inputs/inputevent.html | `InputEventJoypadMotion` is analog axis data; `InputEventJoypadButton` is discrete; actions group events so one code path serves several devices. **Default `ui_*` joypad bindings were NOT documented on this page — recorded as U1.** |

**Platform-holder guidance:** none consulted. Console certification is **U4,
UNKNOWN**.

---

## What this document does not do

- It implements nothing and binds nothing.
- It does not claim controller support exists — §1 says the opposite.
- It sets no dates.
- It recommends no haptics (§10).
- It makes no platform certification claim; PlayStation and Nintendo names in §5
  are physical-position equivalents only.
