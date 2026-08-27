# Early Access release evidence matrix — 2026-08-26

> **G22 PRIVACY GATES — 2026-08-26:** network weather is now a separate
> default-off setting; with it off, `LiveWeatherService` issues no request and
> retains the authored Queens fallback. Enabling it explicitly names
> Open-Meteo and IP exposure; location text remains a second opt-in. Both
> Songbook recording routes now stop at one just-in-time local-only microphone
> notice whose `NOT THIS TIME` branch performs without constructing or starting
> `MicRecorder`. `SongbookMicConsentTest` PASS 7/7, including the real
> recorder constructed with neither its microphone stream nor record effect
> active and a repeat-take refusal that destroys any previously accepted
> recorder; cancel and panel close also stop capture synchronously,
> `LiveWeatherServiceTest` PASS (0 failures), `WeatherSkyTest` PASS (0
> failures), `TitleScreenTest` PASS (0 failures), and production-root
> `SongbookTest` PASS (0 failures). `FriendsPrivacySurfaceTest` PASS 8/8 pins
> the production capability census at one HTTP client, one microphone stream,
> one developer-gated clipboard writer, and zero raw socket/process/shell/device
> identifier APIs. Windows indicator behavior and an actual
> unplugged-network session remain manual.
>
> **FOCUS / COMFORT FOCUSED VERDICTS — 2026-08-26:** `TitleScreenTest`
> exits PASS with 0 failures, `PauseServicesTest` passes 16/16, and
> `WeatherFlashAccessibilityTest` passes 2/2. These prove reachable surfaces,
> focus acquisition and the code-side reduced-roll/flash contracts. They do not
> replace pad-only traversal, restart persistence, or a human storm/traffic
> comfort check; G11, G13 and G14 retain those manual portions.
>
> **G15 ROLLBACK GUARD — `RealitySaveCompatTest`:** version 4 now refuses to
> merge or overwrite any save carrying a newer version. The runtime remains on
> fresh data with a named read-only latch; an ordinary commit preserves the
> future file byte-for-byte, and only the player's explicit new-campaign action
> releases the latch. Focused proof passes 7/7 and the existing production-root
> `DreamBoundaryTest` remains PASS (39 checks). The eleven-boundary manual save
> matrix is still open, so G15 remains partial rather than proved.
>
> **G27 STATUS NOTICE — `2165c3c`, 2026-08-26:** G27 is closed. A tracked
> 64-bit `Windows Desktop` release preset now exports successfully through the
> serial Godot lane. The proved artifact is a 109,071,360-byte executable plus
> a separate 1,250,936,396-byte PCK after unreferenced raw audio masters were
> excluded from both platform presets; the final export completed in 14.5
> seconds with exit 0 and no filtered parse/script error. The generated files are ignored under
> `build/`. This changes the shortest friends-build path to **G23 → G15**. It
> does not prove packaging, installation, launch on a second machine, signing,
> or distribution, and the 1.25 GB payload is now a measured packaging cost.

> **CONTROLLER STATUS — `a6c4ba1`, 2026-08-26:** G03 is no longer blocked by
> raw keycodes: the maintenance hero mechanism and Otis board consume semantic
> actions, controller movement/look/world/UI bindings are registered, look
> settings are persisted on both settings surfaces, pause and cancel have
> distinct ownership, and the shared-A double-fire is dynamically refused.
> Focused evidence is green, including `MaintenancePanelInputTest` 18/18.
> G07 remains open at **MANUAL/PHYSICAL PAD**, not code-absent: no person has
> yet completed the eleven-beat first route pad-only, and no second controller
> family or hot-swap session has been signed off. G08 remains open independently
> for the controller-only Dream route.

> **G18 STATUS — `d205e5a`, 2026-08-26:** generic case-object titles,
> resident/status nameplates and light-tuning handles are now absent unless
> `ORISON_DEVELOPER_OVERLAYS=1` is explicitly set; ordinary boot no longer
> instantiates the handles. `ReleasePresentationTest` PASS 5/5, Mina gameplay
> and character suites PASS, and InteractionInventory exits 0. The floating
> `SOFA`, `DESK`, `WINDOW` and `MINA` nouns remain intentionally: they are the
> authored caption anomaly and removing them would remove the case mechanic,
> not debug UI. G18 is code-closed for those audited affordances but still
> requires a fresh production capture before public media is cleared.
>
> **G18 VISUAL EVIDENCE — `art/renders/release_presentation_g18/`:** a fresh
> windowed production capture with overlays unset shows no resident/status
> nameplate, generic object title or light marker in the resolved 2A control;
> the final frame adds only the intended `REFRIGERATOR` waking residue. The
> measured residue delta is 3.39× the temporal A/A floor. G18 is therefore
> closed for the audited 2A affordances. This does not approve arbitrary older
> screenshots, which may still contain overlays baked before `d205e5a`.

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
| G07 | Controller-only waking route | **CODE GREEN / MANUAL OPEN** | Early Access |
| G08 | Controller-only dream | **CODE GREEN / MANUAL OPEN** | Early Access |
| G09 | Keyboard/mouse route | **CODE GREEN / MANUAL OPEN** | internal |
| G10 | Touch route | **UNKNOWN** | does not block |
| G11 | Custom volume controls | **PROVED (code) / MANUAL OPEN** | Early Access |
| G12 | Captions are not subtitles | **PROVED** | Early Access |
| G13 | Camera roll and flash suppression | **CODE GREEN / MANUAL OPEN** | Early Access |
| G14 | Title and in-game focus | **CODE GREEN / MANUAL OPEN** | Early Access |
| G15 | Save, persistence, abort restore | **PARTIAL** | internal |
| G16 | Boot and capture budget | **PROVED** | does not block |
| G17 | 1440p route performance | **PARTIAL — 3 stations over** | public demo |
| G18 | No debug affordance in build or media | **CODE GREEN / MANUAL OPEN** | public demo |
| G19 | Capture protocol conformance | **PROVED** | does not block |
| G20 | System requirements, two machines | **ABSENT** | Early Access |
| G21 | Accessibility declaration verified | **PARTIAL** | Early Access |
| G22 | Weather fallback and location privacy | **PARTIAL** | Early Access |
| G23 | Build channels and rollback rehearsal | **CODE GREEN / MANUAL OPEN** | friends build |
| G24 | Store assets and demo AppID | **ABSENT** | public demo |
| G25 | Narcolepsy statement and review | **ABSENT** | any outreach |
| G26 | Lena work order ruling | **BLOCKED ON OWNER RULING** | Early Access |
| G27 | Desktop export preset | **PROVED** | friends build |
| G28 | Claims wider than their tests | **PARTIAL** | Early Access |

**28 gates. 5 PROVED. 10 CODE GREEN / MANUAL OPEN. 8 PARTIAL. 3 ABSENT.
1 BLOCKED ON OWNER RULING. 1 UNKNOWN.**

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
**Automated:** `ControllerInputTest`, `MaintenancePanelInputTest` and
`OtisPanelInputTest` prove registered movement, rate-shaped look, world/UI
actions, distinct pause/cancel ownership and semantic maintenance controls.
`PlayerController` now also replaces legacy `[E]` prompt carriers with `[A]`
after real pad input (`d1f0fe6`). **CODE GREEN / MANUAL OPEN.**
**Manual:** the ten-step pad-only smoke test, §8.1 of that document, keyboard
and mouse **physically unplugged**.
**Consequence:** blocks Early Access.
**Forbidden while open:** "controller support", **"partial controller support"**,
"Steam Deck compatible", "remappable controls", any capsule showing a pad glyph.

### G08 — Controller-only dream
As G07, §8.2 of the controller contract. The required movement, look, lamp and
interaction actions are code-green, but the Dream remains a separate manual
gate because it is the fairness test: fine aim under pursuit and the lamp
decision on a stick. **CODE GREEN / MANUAL OPEN.**
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
**Automated:** `WeatherFlashAccessibilityTest` **PASS 2/2**;
`PauseServicesTest` **PASS 16/16**, including the reachable flash and reduced
motion controls and preservation of physical inputs.
**Manual:** ride a traffic stagger and a storm with each toggle both ways.
**Consequence:** blocks Early Access **only if Camera Comfort is declared** —
which the accessibility audit currently forbids.

### G14 — Title and in-game focus
**Owner:** `title_screen.gd:66,298,303`; `pause_services.gd:58` — `grab_focus()`
now called on open (`ac782b9`, `14f6a94`).
**Automated:** `TitleScreenTest` **PASS (0 failures)** and
`PauseServicesTest` **PASS 16/16**, including keyboard/controller focus on open.
**Manual:** traverse every control **keyboard-only**, then **pad-only** once G07
lands; confirm focus is never nowhere.
**Consequence:** blocks Early Access.

### G15 — Save, persistence, abort restoration
**Owner:** `game/scripts/game/reality_game_state.gd` — `SAVE_VERSION := 4`,
`user://reality_maintenance_save.json`, `_migrate()`.
**Automated:** save/resume assertions inside the K2 live suites (e.g. resume
reconstructs the same card and commits nothing).
**Manual:** **K3, the eleven-boundary matrix** (`TASKS.md:109`) — never done.
**Cross-version guard:** implemented and focused-proved as recorded in the G15
status notice above. This closes the rollback overwrite mechanism, not the
manual eleven-boundary save matrix.
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
**CODE GREEN / MANUAL OPEN.** Generic case titles, resident/status nameplates,
light-tuning handles, noclip and clipboard tuning are gated behind explicit
`ORISON_DEVELOPER_OVERLAYS=1`. `ReleasePresentationTest` pins those boundaries,
and `release_presentation_g18` provides a clean production capture. The
remaining `SOFA`, `DESK`, `WINDOW` and `MINA` nouns are the authored caption
anomaly—the case mechanic—not generic debug labels (`022d123`).
**Manual:** sweep each candidate public screenshot/trailer frame; older media
can still contain affordances baked before the gate existed.
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
**Owner:** default-off network weather consent, `live_local_weather`,
`weather_location_query`. `LiveWeatherServiceTest` and `WeatherSkyTest` pass:
with network weather off, no request is issued and the authored Queens fallback
remains; enabling it names Open-Meteo and IP exposure, while authored location
text is a second opt-in. **PARTIAL.**
**Manual:** run with the network unplugged and confirm graceful fallback and the
Windows-facing consent presentation.
**Consequence:** blocks Early Access — it is a privacy claim.

### G23 — Build channels and rollback rehearsal
**CODE GREEN / MANUAL OPEN.** `FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md`
selects private itch keys for the first cohort; `package_friends_build.ps1`
produces a deterministic six-file artifact with build identity, licence,
tester notice and third-party notices. No operator has rehearsed upload,
installation, rollback or revocation on a second machine.
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
**PROVED.** The tracked `Windows Desktop` x86-64 preset exported through the
serial lane with exit 0: 109,071,360-byte EXE plus 1,250,936,396-byte PCK
(`2165c3c`; full receipt in the status notice above). Packaging, installation
and launch on a second machine belong to G23 and G20, not this preset gate.

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
