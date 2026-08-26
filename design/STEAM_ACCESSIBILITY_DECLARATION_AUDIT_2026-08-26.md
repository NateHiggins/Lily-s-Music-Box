# Steam accessibility declaration audit — 2026-08-26

**Purpose:** the exact accessibility declaration we can honestly make for the
current Early Access build, and the exact one we cannot.

**Base audited:** `e81592d81fb91634676c8941259def896dc22576` (pushed
`origin/main`). Both commits named in the assignment were verified present as
ancestors: `b6fae5e` "Open building services during the night" and `59ca044`
"Expose dream sound captions with gameplay cues".

**No Godot was launched.** No test was executed. Every runtime claim below is
read from production source at this commit; every claim that requires a running
build or a human is marked **UNKNOWN — MANUAL**.

> **The governing principle.** Valve's documentation states no verification
> process for these declarations. **That is not permission; it is the reason to
> be strict.** A checkbox on a store page is a promise made to a person who
> will buy the game because of it. Where the evidence is a subsystem rather
> than the whole game, this document says so rather than rounding up.

**Headline:** on today's build we can honestly declare **one** Steam
accessibility label — **Custom Volume Controls** — with **Stereo Sound**
pending manual verification. Everything else is absent, narrow, or fails
Valve's own stated requirement.

---

## 1. Volume controls

**Status: IMPLEMENTED AND PLAYER-REACHABLE.** The strongest area in the build.

Six categories, defined once in `game/scripts/game_boot.gd:31–39` and applied at
`:121–146`:

| Slider label (as shown) | Setting key | Bus | Governs |
| --- | --- | --- | --- |
| MASTER | `master_volume` | `Master` | everything (default 0.82) |
| GAMEPLAY / CLUES | `gameplay_volume` | `Gameplay` | Interaction, State, **Navigation**, Hazard |
| VOICE / TELEPHONE | `voice_volume` | `Voice` | Dialogue, Telephone |
| WORLD / WEATHER | `world_volume` | `World` | RoomTone, Architecture, Weather, Machinery, Broadcast |
| MUSIC | `music_volume` | `Music` | Diegetic, Nondiegetic |
| INTERFACE | `ui_volume` | `UI` | interface sound |

**Precision that matters for the claim:** these are **six parent buses**, not
sixteen. `Telephone` and `Weather` appear in slider *labels* but are child buses
(`audio_policy.gd:15–34`) and have **no independent control**. A player cannot
lower weather without lowering room tone and machinery with it.

**Reach — two surfaces, and they are not equivalent:**

| | Title screen (`ui/title_screen.gd:31–43`) | In-game "Building Services" (`ui/pause_services.gd`) |
| --- | --- | --- |
| six volume sliders | ✔ | ✔ |
| sound-caption switch | ✔ | ✔ |
| **sleep-onset warning** | ✔ `_always_warn` | **✘ absent** |
| fullscreen | ✔ | ✘ |
| quality | ✔ | ✘ |
| local-weather consent | ✔ | ✘ |

**Persistence:** `user://orison_settings.cfg`; `GameBoot` is the single
persistence and apply authority and `PauseServices` explicitly owns no settings
(`pause_services.gd:3–4`).
**Live preview:** yes — `_preview()` writes the bus immediately.
**Reversibility:** "RETURN WITHOUT SAVING" calls `GameBoot.apply_audio_settings()`
to restore the persisted baseline (`pause_services.gd:53–62`). This is better
than most: the preview cannot strand a player in a mix they did not choose.

**Reach exception, IMPLEMENTED BUT NARROW:** `can_open()` refuses while
`call_locked` or while a `seated_interaction` is live (`pause_services.gd:32–35`).
**A player cannot reach the volume controls during a telephone call** — which is
precisely when a voice-level problem is most likely to be noticed. The
behaviour is deliberate (modal ownership) and is asserted by
`game/tests/pause_services_test.gd:27,30`; it is recorded here as a reach
boundary, not a bug.

**Test evidence in repo (not executed here):** `pause_services_test.gd` asserts
the surface exists, opens during ordinary play, pauses, exposes all six
controls, restores the user mix on cancel, and refuses during a protected call
or seated interaction. `audio_policy_test.gd` carries 23 checks.
**UNKNOWN — MANUAL:** whether the sliders are reachable and operable **by
keyboard or controller alone** (they are `HSlider`/`CheckBox` in a
`CanvasLayer`; focus order was not verified).

---

## 2. Sound captions

**Status: IMPLEMENTED, DELIBERATELY NARROW. THIS IS NOT CLOSED CAPTIONING.**

Two layers, one player-facing switch.

**Waking semantic cues** — `ui/audio_caption_layer.gd`, setting
`gameplay_sound_captions`. Prints the cue's authored `caption` plus a relative
sector. Source: `game/data/audio_cues.json`.

> **The number that decides the honesty of any caption claim: the catalog holds
> 20 cues. All 20 carry a caption. The production soundscape carries far more —
> my own K2-G audit measured 143 `AudioStreamPlayer3D` instances playing
> simultaneously in a live boot.** Twenty captioned semantic cues is a bounded
> gameplay-cue catalog, not coverage of what the building sounds like.

The layer says so itself, in its own header
(`audio_caption_layer.gd:4`): *"music and dialogue are not pretended to be
captioned by this layer."*

**Dream directional hazards** — `dream/dream_caption_layer.gd`, setting
`dream_directional_captions`. Emits exactly two things: the cue and one of eight
sectors relative to facing.

**What they deliberately do NOT disclose**, and this is a design decision rather
than an omission (`game_boot.gd:48–56`, `dream_caption_layer.gd:12–18`):
distance, room name, case owner, or hidden ownership. The stated reason is that
a caption reader *"must get what the ear gets and no more, or the light decision
the dream is built on stops costing anything."* **This is the right call and it
must be described accurately on a store page**: the captions preserve the
puzzle, they do not substitute for hearing.

**One switch, two systems.** `pause_services.gd:_store_controls` writes the
checkbox to **both** `gameplay_sound_captions` and `dream_directional_captions`;
`_load_controls` shows it ticked if **either** is true. Defaults are **off**
(`game_boot.gd`).

**Distinguished from closed captions, explicitly:** closed captions would name
every meaningful non-speech sound, including ambience, music stingers and
off-screen events. This system names 20 authored gameplay cues and hazard tells.
**We may not call it closed captioning, subtitling, or "full captions".**

---

## 3. Dialogue and subtitles

**Status: IMPLEMENTED FOR TWO SURFACES; NOT CONFIGURABLE; COVERAGE UNVERIFIED.**

| Surface | Renders text | Speaker named | Font size | Configurable |
| --- | --- | --- | --- | --- |
| Case conversation (`ui/case_dialogue_panel.gd:36–42`) | ✔ speaker + line | ✔ (`_speaker`, coloured) | **17 / 16, fixed** | ✘ |
| Telephone/call (`call/call_interface.gd:150–154`) | ✔ `_subtitle`, autowrap | ✘ not by that label | **13, fixed** | ✘ |

**Voice exists:** 34 `mina_c01_*.ogg` takes under `game/assets/audio/voice`,
matching the 34 nodes in `game/data/case01_dialogue.json`. So Mina's
conversation is voiced **and** subtitled.

**Timing:** dialogue is **not** timed. Silence is a first-class authored option
via `silence_goto` (`case_dialogue_panel.gd:118`), not a timeout. Nothing forces
a choice.

**Configurability: none.** A repository-wide search for `subtitle_size`,
`caption_size`, `text_size`, `font_scale`, `ui_scale` returns **no matches**.
There is no size control, no background/opacity control, no positioning option.

**Coverage — UNKNOWN, MANUAL, AND THE REASON WE CANNOT DECLARE.** I verified
that two dialogue surfaces render text. **I did not verify that every meaningful
spoken or audio beat in the shift is covered**, and the brief is right to insist
on that distinction. Specifically unverified: the watchman/register apparatus,
the Passage proprietor, resident barks and schedule chatter, the broadcast and
radio layers, and any non-speech audio that carries story rather than gameplay
meaning. **Two captioned surfaces is not "subtitles for all spoken content."**

---

## 4. Input

**Status: KEYBOARD+MOUSE COMPLETE; CONTROLLER SEVERELY PARTIAL; NO REMAPPING.**

Actions are registered in code at `game/scripts/game_boot.gd:5–22`.

**Keyboard (`ACTIONS`)** — move ×4, run, crouch, jump, interact, shot_capture,
lamp, radio, music_player, **noclip (V)**, **debug_panel (F1)**, intro (F2).

> **Store-honesty note, not an accessibility item:** `noclip` and `debug_panel`
> are bound to single keys in the production input map. That is a debug
> affordance a buyer can trigger by accident.

**Controller (`JOYPAD_ACTIONS`, `game_boot.gd:19–22`) — exactly two bindings:**
`lamp_toggle` → left shoulder, `radio_toggle` → right shoulder.
**There is no analog stick binding for movement or camera.** Movement reads
`Input.get_vector("move_left"…)` (`player_controller.gd:951`), whose actions
carry **only** keyboard events; look reads `InputEventMouseMotion`
(`player_controller.gd:365–367`). A search for `JOY_AXIS`,
`InputEventJoypadMotion` or `get_axis` in the player and boot scripts returns
nothing.

> **Therefore: the game cannot be played with a controller today.** Any
> controller claim on a store page would be false. This also means
> `PLAN:476` §9's "controller … work" gate is genuinely open, not partially met.

**Touch:** `ui/touch_controls.gd` provides a stick, a look region and buttons,
sharing one movement code path with keyboard. **UNKNOWN — MANUAL:** whether a
complete shift is achievable touch-only on a real device.

**Remapping: ABSENT.** No rebinding UI exists; a search for `remap`/`rebind`
outside the dream builder and shader code returns nothing.

**Hold/toggle alternatives: ABSENT for run.** Run is hold-only
(`Input.is_action_pressed("run")`, `player_controller.gd:975`). Crouch is a
toggle (`is_action_just_pressed`, `:358`). There is no option to swap either.

**Simultaneous-input assumptions:** mouse-look plus WASD plus a modifier held
for running is the only fully supported scheme.

---

## 5. Visual

**Status: LARGELY ABSENT.**

| Item | Status | Evidence |
| --- | --- | --- |
| Text size | **ABSENT** | fixed 13/16/17; no scale setting anywhere |
| Contrast controls | **ABSENT** | no setting found |
| Colour alternatives | **ABSENT** | no colourblind mode found |
| Colour dependence | **UNKNOWN — MANUAL** | not audited; the signage family uses brass-on-dark and the dream uses a strongly coloured palette |
| Flashing / flicker | **PRESENT, UNCONTROLLED** | `weather_flash` drives a lightning term in the sky shader (`building_root.gd:929,1085`), fed by `day_night_director.gd:167`. **No intensity or disable option.** A photosensitivity consideration with no player control. |
| Camera motion | **PRESENT, UNCONTROLLED** | the camera rolls during traffic stagger and altered gravity (`player_controller.gd:919–973`). No reduction toggle, and **no look-sensitivity setting was found**. The breathing sway at `player_controller.gd:381–405` belongs to the held service lamp, not the camera. |
| Fullscreen | **IMPLEMENTED — title screen only** | `game_boot.gd:113–116`; absent from the in-game panel |
| Quality | **IMPLEMENTED — title screen only** | `quality` 0 cinematic / 1 balanced |

---

## 6. Gameplay and cognitive

| Item | Status | Evidence |
| --- | --- | --- |
| **Sleep-onset warning** | **IMPLEMENTED — TITLE SCREEN ONLY** | `always_warn_before_sleep` (`game_boot.gd:45–47`) forces the legible gradual warning. **Not reachable from the in-game panel**, so a player who discovers the need mid-shift must leave the game to change it. Given that the condition is the game's central mechanic, this is the reach gap I would fix first. |
| Difficulty | **ABSENT** | no difficulty setting |
| Navigation alternatives | **BY DESIGN, NOT AN OPTION** | the route is taught by signage and sound; there is deliberately no waypoint. There is **no alternative** for a player who cannot use the audio cue — the captions name the cue but withhold distance by design (§2) |
| Timing pressure | **PRESENT in core gameplay** | the dark scramble is a real-time pursuit with a bounded run (`dream_hazard.gd:63`, `run_cap_s`). Gradual-onset-only changes the *entry*, not the scramble |
| Pause | **IMPLEMENTED** | Building Services sets `get_tree().paused = true`, and requests a `paused` mix state |
| Save | **AUTOSAVE ONLY** | `RealityState.commit()` → `save_game()`; one file, `user://reality_maintenance_save.json`, `SAVE_VERSION := 4`. **No manual save, no slots** |

---

## 7. Steam label mapping

Labels and their requirements are quoted from Valve's official accessibility
documentation (§8 S1), accessed **2026-08-26**. **Valve's list contains no
"closed captions", "sound captions" or "controller support" accessibility
label** — non-speech captioning is folded into *Subtitle Options*.

### DECLARE TODAY

| Label | Valve's requirement | Why we meet it |
| --- | --- | --- |
| **Custom Volume Controls** | *"Players can adjust the volume of the audio. Different types of audio can be muted independently."* Recommends separate sliders for music, effects, ambient and dialogue, and **ideally** distinct controls for gameplay-critical effects versus background | **Met, and arguably exceeded.** Six independent categories including the recommended gameplay-critical split (GAMEPLAY / CLUES vs WORLD / WEATHER). Persistent, reachable from title **and** in-game, with reversible live preview |

**That is the entire list.** One label.

### UNKNOWN — VERIFY BEFORE DECLARING

| Label | What must be checked |
| --- | --- |
| **Stereo Sound** | Valve's description for this label was not retrieved in this pass. The game outputs positional 3D audio through a bus tree, so it plausibly qualifies — **but the requirement text is unverified and the label must not be ticked on a guess** |
| **Touch Only Option** | `touch_controls.gd` exists; a complete shift touch-only on a real device is unverified |
| **Playable without Quick Time Events** | `maintenance_activity_run.gd:55–65` takes a `hold_seconds` and a `tolerance`; whether any step imposes a reaction window needs a human at the controls |

### DO NOT DECLARE TODAY

| Label | Why not |
| --- | --- |
| **Subtitle Options** | Requires customisable display **for all spoken content and essential audio information**, with adjustable background opacity and separate text scaling. We have two fixed-size surfaces, no customisation of any kind, and unverified coverage (§3) |
| **Adjustable Text Size** | Requires large default text or user increase to **≥38 px at 1080p**. Ours are 13/16/17 px, fixed |
| **Camera Comfort** | Requires disabling or reducing camera bob/shake **or not having them**. Camera roll during stagger and altered gravity cannot be reduced, and look has no sensitivity control (§5). The held lamp sways; the camera does not continuously breathe. |
| **Save Anytime** | Requires saving at any point with separate manual and auto slots. We autosave to one file (§6) |
| **Playable at Your Own Pace** | Requires no time limits in core gameplay. The dark scramble is a timed pursuit (§6) |
| **Keyboard Only Option** | Requires binding **all** actions including camera. Look is mouse-only (§4) |
| **Mouse Only Option** | Movement is WASD-only |
| **Adjustable Difficulty** · **Narrated Game Menus** · **Color Alternatives** · **Contrast Controls** · **Playable without Vision** | Absent (§5, §6) |
| **Chat Text-to-speech** · **Chat Speech-to-text** | Not applicable — no chat |

### Store copy that IS defensible today

> Six independent, persistent audio categories — master, gameplay cues,
> voice/telephone, world/weather, music and interface — adjustable from the
> title screen and from an in-game panel, with live preview. **Optional
> on-screen captions for a bounded catalogue of gameplay sound cues and dream
> hazard tells**, naming the cue and its direction.

**Store copy that is NOT defensible today:** "full subtitles", "closed
captions", "controller support", "remappable controls", "colourblind modes",
"adjustable text", "accessibility options" as an unqualified plural.

---

## 8. Remediation, prioritised

**Release-blocking honesty gaps** — each one is a claim we would otherwise be
tempted to make, or a reach failure that makes an existing feature unfindable.
No dates and no implementation are proposed.

| # | Gap | Why it blocks a credible declaration |
| --- | --- | --- |
| **B1** | **Sleep-onset warning is title-screen only** | The game's central mechanic has an accessibility option a player cannot reach once they need it. Adding it to the in-game panel costs one control on a surface that already exists |
| **B2** | **Controller is two shoulder buttons** | Not an accessibility label, but a claim a store page or press kit would make almost reflexively, and it would be false |
| **B3** | **Subtitle coverage is unverified** | We cannot say what fraction of meaningful audio is captioned. Until someone plays the shift and lists every uncaptioned beat, no subtitle claim is available |
| **B4** | **Uncontrolled lightning flash** | Photosensitivity has no label in Valve's list, so it will not appear on the store page — which makes it a duty of care rather than a compliance item |
| **B5** | **Event-driven camera roll has no reduction control and look has no sensitivity control** | Blocks *Camera Comfort*. The always-on breathing motion belongs to the held service lamp, not the camera; traffic stagger and altered gravity are the uncontrolled camera motions. |

**Post-launch improvements** (would each unlock a label, none blocks honesty):
text scaling → *Adjustable Text Size*; subtitle background/scale + full coverage
→ *Subtitle Options*; manual save slots → *Save Anytime*; keyboard look →
*Keyboard Only Option*; input remapping (no label, high value).

---

## 9. Declaration-evidence template

For every future accessibility claim. **A row is not complete until every field
is filled; an empty field is a claim we do not make.**

```
FEATURE:
  owner              (the one file/system that implements it)
  user reach         (exact surfaces; note any state where it is unreachable)
  coverage boundary  (what it covers AND what it explicitly does not)
  test               (path + what it asserts; a subsystem test is not coverage)
  manual verification(what a human confirmed, on what build, on what date)
  store label        (exact Valve label, or NONE)
  claim wording      (the sentence we will publish, verbatim)
  known exceptions   (every case where a player would find the claim untrue)
```

**Worked example, today's only declarable feature:**

```
FEATURE: category volume controls
  owner              game_boot.gd (persist/apply) + pause_services.gd, title_screen.gd (surfaces)
  user reach         title screen; in-game Building Services (ui_cancel)
                     NOT reachable during a call or a seated interaction
  coverage boundary  six PARENT buses; Telephone and Weather are children with
                     no independent control
  test               game/tests/pause_services_test.gd — surface exists, opens,
                     pauses, exposes six controls, restores on cancel, refuses
                     during modal ownership. NOT executed in this audit
  manual verification NONE YET — keyboard/controller operability of the sliders
                     is unverified
  store label        "Custom Volume Controls"
  claim wording      "Six independent, persistent audio categories, adjustable
                     from the title screen and in game, with live preview."
  known exceptions   unreachable mid-call; no per-child-bus control
```

---

## 10. Sources

**Official, primary, accessed 2026-08-26:**

| # | Page | Authority | URL | Supports |
| --- | --- | --- | --- | --- |
| S1 | Accessibility Features | Valve | https://partner.steamgames.com/doc/accessibility_features | the complete label list by category; the exact requirement text quoted in §7 for Custom Volume Controls, Subtitle Options, Adjustable Text Size, Camera Comfort, Save Anytime, Playable at Your Own Pace and Keyboard Only Option; the absence of any closed-caption or controller label; **no stated verification process** |

**Production source at `e81592d`:** `game/scripts/game_boot.gd`;
`game/scripts/audio/audio_policy.gd`; `game/scripts/ui/pause_services.gd`;
`game/scripts/ui/title_screen.gd`; `game/scripts/ui/audio_caption_layer.gd`;
`game/scripts/dream/dream_caption_layer.gd`;
`game/scripts/ui/case_dialogue_panel.gd`; `game/scripts/call/call_interface.gd`;
`game/scripts/player/player_controller.gd`; `game/scripts/ui/touch_controls.gd`;
`game/scripts/game/reality_game_state.gd`;
`game/scripts/game/maintenance_activity_run.gd`;
`game/scripts/dream/dream_hazard.gd`; `game/scripts/building/building_root.gd`;
`game/data/audio_cues.json` (20 cues); `game/data/case01_dialogue.json`
(34 nodes); `game/assets/audio/voice` (34 takes).

**Tests present and read, not executed:** `game/tests/pause_services_test.gd`,
`audio_policy_test.gd` (23 checks), `audio_caption_test.gd`,
`title_screen_test.gd`, `title_screen_audio_test.gd`.

**Cross-reference:** the 143-concurrent-emitter measurement in §2 is from the
K2-G production audit recorded in `art/renders/first_minute_k2g/README.md`.

---

## What this document does not do

- It implements nothing and promises no dates.
- It does not tick a box, draft a store page, or decide the release.
- It does not infer whole-game coverage from a subsystem test — where a claim
  needs a human at the controls, it says **UNKNOWN — MANUAL** and stops.
- It does not treat Valve's lack of verification as licence. **One label is the
  honest answer today, and one label is what we declare.**
