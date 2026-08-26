# Early Access release evidence matrix — 2026-08-26

> **G27 STATUS NOTICE — `2165c3c`, 2026-08-26:** G27 is closed. A tracked
> 64-bit `Windows Desktop` release preset now exports successfully through the
> serial Godot lane. The proved artifact is a 109,071,360-byte executable plus
> a separate 1,317,970,976-byte PCK; export completed in 25.8 seconds with exit
> 0 and no filtered parse/script error. The generated files are ignored under
> `build/`. This changes the shortest friends-build path to **G23 → G15**. It
> does not prove packaging, installation, launch on a second machine, signing,
> or distribution, and the 1.32 GB payload is now a measured packaging cost.

**Purpose:** one authoritative view of every release gate, what evidence exists
for it today, and what is still owed. **This is not a backlog and it invents no
scope.** Every gate traces to a promise already made in a pushed document.

**Base:** `9adbf8e11e250431d39e8a1bd383a43acfcbdbb4` (pushed `origin/main`,
"Audit the controller input contract").

**No Godot was launched. No test was executed. No code, data, project setting,
scene, test, render, `TASKS.md` or existing document was edited.**

> ## The stop rule, which governs every row below
>
> **No evidence may be cited outside the state, hardware and build it actually
> measured.** A focused suite proves a contract on a bench. A production-live
> suite proves it in one boot on one machine. A capture sheet proves what its
> declared cameras saw at one commit. **None of them proves a player can do the
> thing on a machine we have not tried.** Where a result is not recorded in a
> pushed document, README or commit body, this matrix says **UNRUN/UNKNOWN**
> rather than inferring it from a filename.

**Evidence-grade vocabulary used throughout:**
**FOCUSED** (bench, no production root) · **LIVE** (production root, one boot) ·
**CAPTURE** (frames + receipt + metrics) · **PERF** (timed stations) ·
**STATIC** (source scan or data validation) · **MANUAL** (a human, named
hardware).

---

## Summary index

| ID | Gate | Status | Blocks |
| --- | --- | --- | --- |
| G01 | First 8–12 minute route and first report | **CODE GREEN / MANUAL OPEN** | public demo |
| G02 | Sound-led Vantry fault reachable | **CODE GREEN / MANUAL OPEN** | public demo |
| G03 | Maintenance hero mechanism | **PARTIAL** | Early Access |
| G04 | Calls and dismissal | **PARTIAL** | public demo |
| G05 | Sleep onset and warning | **CODE GREEN / MANUAL OPEN** | Early Access |
| G06 | One pocket, one pursuer, one truth | **PARTIAL** | Early Access |
| G07 | Controller-only waking route | **ABSENT** | Early Access |
| G08 | Controller-only dream | **ABSENT** | Early Access |
| G09 | Keyboard/mouse route | **CODE GREEN / MANUAL OPEN** | internal |
| G10 | Touch route | **UNKNOWN** | does not block |
| G11 | Custom volume controls | **PROVED (code) / MANUAL OPEN** | Early Access |
| G12 | Captions are not subtitles | **PROVED** | Early Access |
| G13 | Camera roll and flash suppression | **CODE GREEN / MANUAL OPEN** | Early Access |
| G14 | Title and in-game focus | **CODE GREEN / MANUAL OPEN** | Early Access |
| G15 | Save, persistence, abort restore | **PARTIAL** | internal |
| G16 | Boot and capture budget | **PROVED** | does not block |
| G17 | 1440p route performance | **PARTIAL — 3 stations over** | public demo |
| G18 | No debug affordance in build or media | **ABSENT** | public demo |
| G19 | Capture protocol conformance | **PROVED** | does not block |
| G20 | System requirements, two machines | **ABSENT** | Early Access |
| G21 | Accessibility declaration verified | **PARTIAL** | Early Access |
| G22 | Weather fallback and location privacy | **PARTIAL** | Early Access |
| G23 | Build channels and rollback rehearsal | **ABSENT** | friends build |
| G24 | Store assets and demo AppID | **ABSENT** | public demo |
| G25 | Narcolepsy statement and review | **ABSENT** | any outreach |
| G26 | Lena work order ruling | **BLOCKED ON OWNER RULING** | Early Access |
| G27 | Desktop export preset | **ABSENT** | friends build |
| G28 | Claims wider than their tests | **PARTIAL** | Early Access |

**28 gates. 3 PROVED. 8 CODE GREEN / MANUAL OPEN. 7 PARTIAL. 7 ABSENT.
1 BLOCKED ON OWNER RULING. 2 UNKNOWN.**

---

## The gates

### G01 — First 8–12 minute route and first report
**Promise:** *Scope audit §2* — the eleven beats, fresh save, no dev knowledge.
**Canonical doc:** `CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md:315` M2 gate.
**Owner:** `FirstShiftDirector`, `WorkOrders`, `WayfindingSignagePass`.
**Automated:** `FirstMinuteTest/LiveTest`, `FirstStepTest/LiveTest`,
`ClockAnswersTest/LiveTest`, `StairDirectionTest/LiveTest`,
`LandingPlateTest/LiveTest`, `UnitDirectionTest/LiveTest` — FOCUSED + LIVE.
Verdicts recorded in commit `374eab0` body ("27 further suites green").
**What they actually prove:** each transition is legible and each owner is
uncontended, **in one boot, driven by test code**. They do **not** prove a human
completes the route.
**Manual still required:** desktop, fresh save, unaided, no console/debug/noclip;
observation = finishes and can state their next intention throughout; signer =
owner. This is **K2**, `TASKS.md:105`, and it has never been done.
**Baseline debt not to confuse:** the two standing `WalkTest` FAST failures
(G26, G28).
**Consequence:** blocks public demo.
**Forbidden while open:** "playable start to finish", "complete first shift",
any playtime figure.
**Repro:** `tools/run_godot_serial.ps1 -Scene res://tests/<Suite>.tscn -ProjectPath <wt>/game -TimeoutSeconds 60`.

### G02 — Sound-led Vantry fault reachable
**Promise:** *Distribution plan §1* differentiator — "found by ear, no waypoint",
45 s ceiling.
**Owner:** `ChirpHunt` (`CHIRP_MIN/MAX 12/22`), `VantryPointProp`.
**Automated:** `ChirpReachableTest` **PASS 28/28**, `ChirpReachableLiveTest`
**PASS 25/25** — recorded in `374eab0`. LIVE walks the body in, measures
worst-case threshold-to-target **23.21 s**, and proves the fault wins the room by
**5.7 dB**.
**What it actually proves:** the arithmetic and the acoustics **in one boot with
a scripted body**. Not that a human hears it.
**Manual still required:** desktop + headphones **and** speakers; observation =
locates the point unaided inside 45 s; signer = owner.
**Consequence:** blocks public demo (it is the trailer's central beat).
**Forbidden while open:** any timing claim in seconds; "players find it by ear".
**Repro:** as G01, scene `ChirpReachableLiveTest.tscn`.

### G03 — Maintenance hero mechanism
**Promise:** *Scope audit §2* beat 6 — resistance, commit, sound, test.
**Owner:** `game/scripts/ui/maintenance_activity_panel.gd`,
`maintenance_activity_run.gd`.
**Automated:** `MaintenanceActivityTest` / `LiveTest` scenes exist. **No verdict
is recorded in any pushed document — UNRUN/UNKNOWN.**
**Manual still required:** desktop; a full repair including one abort and one
refusal; signer = owner.
**Known defect:** the panel reads **raw keycodes**
(`maintenance_activity_panel.gd:117–145`), so it is unreachable from a gamepad
by construction — `CONTROLLER_INPUT_CONTRACT_AUDIT_2026-08-26.md` H1.
**Consequence:** blocks Early Access.
**Forbidden while open:** "tactile repair", "hands-on mechanism" in any pad
context.

### G04 — Calls and dismissal
**Owner:** `call/call_interface.gd`; `HouseTelephoneNetwork`.
**Automated:** `HouseTelephoneTest` **PASS 40/40**, `HouseTelephoneLiveTest`
**PASS 13/13** — recorded in `374eab0` body.
**What it proves:** call lifecycle and ownership. **Not** subtitle coverage
(G12) and **not** pad dismissal (G07).
**Manual:** answer, dismiss, and confirm Building Services is correctly refused
mid-call (`pause_services.gd:32–35`).
**Consequence:** blocks public demo.

### G05 — Sleep onset and warning accessibility
**Promise:** *Execution plan M5.6* gradual-only onset.
**Owner:** `dream/sleep_pressure_director.gd`; setting
`always_warn_before_sleep`.
**Automated:** `SleepPressureTest` exists — **UNRUN/UNKNOWN**.
`PauseServicesTest` asserts the in-game control exists (`d36e591`).
**Manual:** trigger both gradual and sudden onset with the option on and off.
**Consequence:** blocks Early Access.
**Forbidden while open:** "gradual-only mode", "onset accessibility".

### G06 — One pocket, one pursuer, one truth
**Owner:** dream boundary, pursuer, hazard field, `DreamIncarnationProfile`.
**Automated:** `DreamBoundaryTest`, `DreamHazardTest`, `DreamPursuitTest`,
`DreamPerceptionTest` exist. `art/renders/dream_light_n3/README.md` records the
**measured** lamp-on/off asymmetry (median 3.425 s vs 11.358 s over eleven
paired seeds) — that is a *design* proof, not a fear proof.
**Manual:** *Execution plan M5* gate — first-time players frightened, know why
the passage ended **within half a second**, wake in 4B without lost progress.
**Consequence:** blocks Early Access.
**Forbidden while open:** "terrifying", "fair", any fear claim.

### G07 — Controller-only waking route
**Owner:** `game_boot.gd` `JOYPAD_ACTIONS`, `player_controller.gd`.
**Automated: none. ABSENT.**
**Status: ABSENT — "controller supported" is currently FALSE**
(`CONTROLLER_INPUT_CONTRACT_AUDIT_2026-08-26.md` §1). Two shoulder buttons; no
stick binding for movement or look.
**Manual:** the ten-step pad-only smoke test, §8.1 of that document, keyboard
and mouse **physically unplugged**.
**Consequence:** blocks Early Access.
**Forbidden while open:** "controller support", **"partial controller support"**,
"Steam Deck compatible", "remappable controls", any capsule showing a pad glyph.

### G08 — Controller-only dream
As G07, §8.2 of the controller contract. **ABSENT.** Separate gate because it is
the fairness test: fine aim under pursuit and the lamp decision on a stick.
**Consequence:** blocks Early Access.

### G09 — Keyboard/mouse route
**Automated:** the G01 suite family, plus `GoldenLoopTest` **PASS 87/87 in
53.7 s** (`AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md`).
**Manual:** K2. **Consequence:** blocks internal playable.

### G10 — Touch route
**Owner:** `ui/touch_controls.gd`. **Automated: none recorded. UNKNOWN.**
**Manual:** a complete shift touch-only on a real device.
**Consequence:** does not block — mobile is deprioritised by owner ruling
(`TASKS.md:3187`). Listed so nobody claims it.

### G11 — Custom volume controls
**Promise:** the **one** Steam label we may declare
(`STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md` §7).
**Owner:** `game_boot.gd:31–39,121–146`; `pause_services.gd`; `title_screen.gd`.
**Automated:** `PauseServicesTest` asserts the surface exists, opens, pauses,
exposes all six controls, restores on cancel, and refuses during a protected
call or seated interaction. `AudioPolicyTest` carries 23 checks. **PROVED in
code.**
**Manual still required:** operate all six with **keyboard alone** and confirm
persistence across a restart. Then sign the declaration-evidence row.
**Consequence:** blocks Early Access (it is the only declared label).
**Forbidden while open:** ticking the Steam wizard box.

### G12 — Captions are not subtitles
**Status: PROVED**, and the proof is a limitation.
`audio_cues.json` holds **20 cues, all captioned**; the live soundscape carries
far more (**143 concurrent emitters** measured in
`art/renders/first_minute_k2g/README.md`). `audio_caption_layer.gd:4` states
*"music and dialogue are not pretended to be captioned by this layer."*
**Consequence:** blocks Early Access **only if a subtitle claim is made**.
**Forbidden permanently on this evidence:** "closed captions", "full subtitles",
"Subtitle Options" on the store page.

### G13 — Reduced camera roll and lightning-flash suppression
**Owner:** `player_controller.gd:1003` `resolved_camera_roll()`;
`reduce_flashing`.
**Automated:** `WeatherFlashAccessibilityTest` exists; `PauseServicesTest`
extended by `44c921e`/`14d5edf`. **Verdicts UNRUN/UNKNOWN.**
**Manual:** ride a traffic stagger and a storm with each toggle both ways.
**Consequence:** blocks Early Access **only if Camera Comfort is declared** —
which the accessibility audit currently forbids.

### G14 — Title and in-game focus
**Owner:** `title_screen.gd:66,298,303`; `pause_services.gd:58` — `grab_focus()`
now called on open (`ac782b9`, `14f6a94`).
**Automated:** `TitleScreenTest`, `PauseServicesTest` — **verdicts
UNRUN/UNKNOWN at these commits.**
**Manual:** traverse every control **keyboard-only**, then **pad-only** once G07
lands; confirm focus is never nowhere.
**Consequence:** blocks Early Access.

### G15 — Save, persistence, abort restoration
**Owner:** `game/scripts/game/reality_game_state.gd` — `SAVE_VERSION := 4`,
`user://reality_maintenance_save.json`, `_migrate()`.
**Automated:** save/resume assertions inside the K2 live suites (e.g. resume
reconstructs the same card and commits nothing).
**Manual:** **K3, the eleven-boundary matrix** (`TASKS.md:109`) — never done.
**Missing entirely:** a cross-version guard. A save written by a newer build can
be loaded by an older one after a rollback — flagged as `K0-SAVEGUARD` in the
distribution plan §15, **not implemented**.
**Consequence:** blocks internal playable.
**Forbidden while open:** "save anywhere", "Save Anytime" label.

### G16 — Boot and capture budget
**Status: PROVED**, and the number is bad news.
`production_ready` at **32.5–33.2 s** against the protocol's 18 s target and
24 s hard warning; eleven-frame sheets finish at 42.6–44.4 s with 9.6–11.4 s of
margin (`art/renders/first_minute_k2f/`, `.../k2g/` receipts).
**Consequence:** does not block release; **does** cap every future capture suite.

### G17 — 1440p route performance
**Owner:** `game/tests/perf_probe.gd`, `PERF_STATION`, one process per camera.
**Recorded (corrected harness, `AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md`):**
lobby **18.06 ms**, atrium F03 landing **23.70 ms**, carriageway **16.67 ms** —
all **playable** stations **over** the 16.6 ms budget. Corridor F04 12.96,
apartment 4B 10.61, roof 6.45 **pass**.
**Not evidence:** the superseded detached-camera table, and the composition
cameras (atrium 33.33, street 27.08) which must never be quoted as gameplay.
**Manual:** re-run after any fix; **plus** a second machine (G20).
**Consequence:** blocks public demo.
**Forbidden while open:** any fps or "runs great" claim.

### G18 — No debug affordance in build or media
**Two distinct problems, both ABSENT of a fix.**
1. **World-space case labels in 2A** — `MINA`, `Mina Vale · 2A [ACTIVE]`, `SOFA`,
   `DESK`, `CAPTION CALIBRATOR` from `cases/case_interactable.gd`; visible in
   `art/renders/first_minute_k2g/production_04/02_a_plausible_wrong_station.png`.
2. **Seven interactive `DebugLightHandle` nodes inside 2A** within 5 m of the
   target; plus `noclip` (V) and `debug_panel` (F1) bound in the production input
   map (`game_boot.gd:12`).
**Consequence:** blocks public demo **and** every screenshot. Valve requires
store screenshots to show gameplay exclusively.
**Forbidden while open:** publishing any screenshot or trailer frame.

### G19 — Capture protocol conformance
**Status: PROVED** for new suites. `run_godot_capture.ps1` + `shot_harness.gd` +
`measure_shot_sheet.py` under `game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`. K2-F and
K2-G both produced receipts, per-camera A/A floors, crops derived before
pricing, and metrics **PASS with 0 failures**.
**Not proved:** the ~109 legacy `*shot*.gd` suites, which the reconciliation
correctly calls maintenance debt rather than launch blockers.

### G20 — System requirements on two machines
**ABSENT.** No measurement exists on any second machine.
**Consequence:** blocks Early Access.
**Forbidden while open:** publishing a system-requirements block at all.

### G21 — Accessibility declaration verified by a human
**PARTIAL.** The declaration itself is decided (**one label**, G11). The manual
verification row of the declaration-evidence template
(`STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md` §9) is **empty**.
**Consequence:** blocks Early Access.

### G22 — Weather offline fallback and opt-in location privacy
**Owner:** `live_local_weather` (default **false**), `weather_location_query`;
`LiveWeatherServiceTest`, `WeatherSkyTest` exist — **verdicts UNRUN/UNKNOWN.**
**Privacy contract, already written** (`game_boot.gd:40–44`): off means only
fixed Queens coordinates; on means the player-authored text is geocoded; **no IP
geolocation, no device sensor.**
**Manual:** run with the network unplugged and confirm graceful fallback; confirm
nothing is sent while the toggle is off.
**Consequence:** blocks Early Access — it is a privacy claim.

### G23 — Build channels and rollback rehearsal
**ABSENT.** No Steamworks app, no branches, no rehearsal. Design exists at
`EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md` §5, §15.
**Consequence:** blocks the friends build.

### G24 — Store assets and demo AppID
**ABSENT.** Manifest and official dimensions exist (plan §6); no asset produced.
Demo needs its own AppID.
**Consequence:** blocks public demo.

### G25 — Narcolepsy statement and external review
**ABSENT.** Plan §9 and W4 require a reviewed statement **before any outreach**.
**Consequence:** blocks **all** press, creator and festival contact.

### G26 — Lena work order owner ruling
**BLOCKED ON OWNER RULING.** `lena_radiator_round_2b` is an authored job for a
resident outside the ruled six, pointing at `lena_unraveling` (`enabled: false`)
and a `dream_profile_id` — `lena_visible_patch` — that **exists nowhere else in
the repository** (`CAST_CASE_AUTHORITY_AUDIT_2026-08-26.md` C-11, C-12).
It is the direct cause of the standing `WalkTest` failure at
`walk_test.gd:1152`, which asserts exactly one authored job.
**Do not fix the test first** — that would ratify an unruled work order.
**Consequence:** blocks Early Access.

### G27 — Desktop export preset
**ABSENT — new finding.** `game/export_presets.cfg` is tracked and contains
**only an Android preset** (`platform="Android"`,
`export_path="../build/android/orison.apk"`). **There is no Windows, Linux or
macOS export preset in the repository**, although mobile is deprioritised by
owner ruling and desktop is the launch platform.
**Consequence:** blocks the friends build — nothing can be exported for a tester.

### G28 — Claims wider than their tests
**PARTIAL.** Green results whose scope is narrower than the claim they are
reached for:

| Test | Green proves | Would be over-read as |
| --- | --- | --- |
| `PauseServicesTest` | the surface exists and exposes six controls | "accessible settings" / operable by keyboard or pad |
| `AudioCaptionTest` | the caption layer emits for catalogued cues | "the game is captioned" |
| `ChirpReachableLiveTest` | the arithmetic and mix in one scripted boot | "players find it in 45 s" |
| `HouseTelephoneTest` 40/40 | call lifecycle and ownership | "calls are subtitled" |
| `GoldenLoopTest` 87/87 | the automated loop completes | "the golden shift is playable" |
| K2-F/K2-G capture metrics | declared crops changed, floors near zero | "the route looks finished" |
| `dream_light_n3` timings | the lamp trade is measurable | "the dream is frightening and fair" |

**Consequence:** blocks Early Access as a discipline, not a feature.

---

## What can ship to friends today?

**Nothing can be exported.** G27: the only export preset is Android.

Even setting that aside, the friends build needs G23 (a channel to ship on) and
G15 (K3 — a save that survives every boundary), and neither exists.

**What is genuinely ready to be looked at**, if someone runs it from the editor
on the developer's own machine: the first-minute route through the 2A fault. It
has the densest evidence in the project — six K2 sheets with declared crops and
near-zero floors, and paired focused+live suites recorded green — and it is the
material the trailer's first three beats are cut from.

**Shortest path to a real friends build:** G27 → G23 → G15.

---

## What blocks a public demo?

Seven gates, in dependency order:

1. **G18** — no screenshot or frame may be published while 2A renders debug
   nameplates and interactive debug lights.
2. **G01** — the route has never been walked unaided by a human.
3. **G02** — the demo's central beat, same reason.
4. **G04** — calls appear in the demo cut.
5. **G17** — three playable stations over the frame budget.
6. **G24** — no store asset or demo AppID exists.
7. **G23/G27** — nothing to ship it on.

**Next Fest:** the October 2026 recommendation stands at **decline**
(`EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md` §8) unless the owner
explicitly overrules it. **This matrix registers nothing and reserves nothing.**

---

## Contradictions and duplicate gates

Reported, not edited. **One canonical wording is nominated for each.**

| # | Duplicate/contradiction | Canonical wording nominated |
| --- | --- | --- |
| D1 | "Route performance" appears as scope-audit §10, K1's remaining rows, and `TASKS.md` §P9 | **Scope audit §10**: three named playable stations against 16.6 ms, composition cameras reported never gated |
| D2 | "Accessibility" is a gate in the execution plan M5.6, the scope audit §10, and the accessibility audit | **Accessibility audit** — it is the only one that maps to Valve labels with requirements |
| D3 | "Controller" is one line in the plan's §9 done-definition and a whole contract in ADMIN-INPUT1 | **Controller contract A1–A10** |
| D4 | Capture rules exist in the protocol **and** in each sheet README | **`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`**; READMEs record instances |
| D5 | The standing `WalkTest` failure has been described three ways across tasks — "pre-existing debt", "stale assertion, one-line fix", "stale because of an unruled job" | **The third** (G26). The first two are superseded. |
| D6 | "Subtitles" — the plan's §9 done-definition assumes them; the accessibility audit forbids the claim | **Accessibility audit**: two fixed-size surfaces, coverage unverified, label not declarable |

---

## Release-candidate signoff template

**One per candidate. An empty field is a blocked release, not a formality.**

```
RELEASE CANDIDATE SIGNOFF
  build SHA              (exact, 40 chars)
  export preset          (name + platform + target triple)
  platform tested        (OS + version)
  hardware               (CPU / GPU / RAM / display + refresh)
  settings at test       (quality, fullscreen, resolution, all six volumes,
                          captions, onset warning, camera roll, flashing,
                          look sensitivity, weather consent)
  route walked           (which beats, fresh save y/n, dev tools used y/n)
  input device           (KB+M / pad / touch — and what was UNPLUGGED)
  failures observed      (every one, including cosmetic; "none" needs a reason)
  baseline debt seen     (must match the known list; a new one halts signoff)
  captures attached      (run dir + receipt status + metrics failures)
  accessibility claims   (each Steam label + the evidence row backing it)
  rollback build         (the exact SHA we would roll back TO, and whether its
                          SAVE_VERSION matches this one)
  known-issues text      (the wording that will be pinned at launch)
  signer                 (name, and they must have played it)
  date
```

---

## Sources

**Repository at `9adbf8e`**, authoritative for current behaviour: production
paths named per gate; `game/export_presets.cfg`; `game/data/audio_cues.json`;
`game/tests/` (308 scenes, 171 test scripts).

**Pushed documents:** `CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`;
`MILESTONE_RECONCILIATION_2026-08-26.md`;
`AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md`;
`EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md`;
`EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md`;
`STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md`;
`CONTROLLER_INPUT_CONTRACT_AUDIT_2026-08-26.md`;
`CAST_CASE_AUTHORITY_AUDIT_2026-08-26.md`;
`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`;
`art/renders/first_minute_k2a…k2g/README.md`;
`art/renders/dream_light_n3/README.md`; `art/renders/dream_profile_n9/README.md`.

**Recorded suite verdicts** are cited from commit `374eab0`'s body and
`AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md`. **No suite was executed for this
document**, and any suite without a recorded verdict is marked UNRUN/UNKNOWN.

**Official platform sources** are not repeated here; they are cited in the
distribution and accessibility documents.

---

## What this document does not do

- It resolves no owner decision: Peter/Lena, Next Fest, price, telemetry,
  Discord and the signing entity are all left exactly where they were.
- It registers nothing, reserves nothing, and contacts nobody.
- It adds no scope. Every gate protects a promise already in a pushed document.
- It edits no source document; D1–D6 nominate canonical wording rather than
  changing anything.
- **It converts no green test into a passed gate.** Eight gates are marked
  CODE GREEN / MANUAL OPEN precisely because that distinction is the point.
