# Early Access scope audit — 2026-08-26

> **Post-audit implementation update — 2026-08-26:** the “no settings surface”
> finding below was accurate at audit commit `627eae5` but is no longer current.
> Pushed production now exposes persistent Master, Gameplay, Voice/Telephone,
> World/Weather, Music and UI levels; gradual sleep warning; local-weather
> consent; and opt-in semantic gameplay-sound captions. Mix requests compose
> against user baselines. This closes ownership of the surface, not the whole
> accessibility gate: subtitle sizing, complete dialogue captions, dynamic
> range presets, pause-menu reach, input remapping and external review remain.

**Status:** decision document answering `TASKS.md:30` (**K0-EA**). This is the
scope ruling that `design/EARLY_ACCESS_GO_TO_MARKET_PROJECT.md` names as its
unblocking dependency ("Once K0-EA declares the target player journey and scope
ceiling…", §First planning gate).

**Authority it does not take.** `CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md` keeps
product direction and milestone definitions. `MILESTONE_RECONCILIATION_2026-08-26.md`
keeps status. `TASKS.md` keeps the executable queue. `walkthrough_punchlist.md`
keeps visual evidence. This document decides only **what ships first** and
**what stops**.

**Base audited:** `0392768` "Integrate K2-F quantified direction proof"
(882 commits, first `2026-02-17`). No Godot was launched to produce this
document; every runtime figure below is quoted from a dated authority in the
repository.

**Origin moved while this was being written**, to `d9f3153`, via `374eab0`
(K2-G), `bf7bd64` (semantic gameplay audio policy) and `d9f3153` (capture
budgeting). This document is deliberately **not** rebased onto them, because its
value is a set of exact line citations into `0392768` and none of the three
commits touches a cited authority except `game/project.godot`, whose line 18
is unchanged and whose line 34 now holds a new `AudioPolicy` autoload. Two
consequences are folded in below rather than left stale:

- **K2-G has landed** (`374eab0`), so its evidence is on `main` and its trailer
  beat is no longer gated on an unpushed branch;
- **`design/SOUND_AS_GAMEPLAY_AUDIT.md` is a new authority that postdates this
  audit** (`bf7bd64`). It is the correct owner of the audio gate in §10, and it
  states its own limitation plainly: *"No listening test or Godot process was
  used for this first pass. Numeric loudness and masking claims remain
  hypotheses until measured in a production walk."* **Its numbers must not be
  promoted to go/no-go thresholds until that walk happens.**

**Scale of the thing being cut down:** 318 top-level task bullets across 43
sections of `TASKS.md`; 298 test scenes; 163 `*test*.gd`; 109 `*shot*.gd`;
~40 substantial design documents. **The backlog is not the build.**

---

## 1. The Early Access player promise, in one sentence

> **You are the night superintendent of a 1928 New York apartment house: fix
> what the building actually breaks, earn the truth from the tenant it belongs
> to, and survive the dark when your own narcolepsy takes you mid-shift.**

Three commitments are load-bearing in that sentence, and each is already a
built contract rather than an aspiration:

| Clause | Why it is honest today | Evidence |
| --- | --- | --- |
| "fix what the building actually breaks" | one authored job with real stages, a physical fault, a part obtained from a shop, and a mechanism | `game/docs/core_loop.md`; `WorkOrders`; `game/data/maintenance_jobs.json` |
| "earn the truth from the tenant" | case conversation, recurrence and waking residue owners exist | `RECON:25` M4 row, "Case conversation, recurrence and waking residue owners exist" |
| "survive the dark…narcolepsy" | onset, pocket, pursuer, wake and persistent return implemented and tested | `RECON:25` M5 row, "Dream boundary, onset, pursuit/lifecycle systems and persistent return are implemented and tested" |

**What the sentence deliberately omits:** six cases, a campaign, a city, an
arcade, a film system, a studio, a telephone exchange, a language. All of those
exist in some measure. **None of them is promised.**

---

## 2. The smallest coherent playable journey that earns that promise

**The Mina shift, complete, replayable, and nothing else required.**

`PLAN:67` §3 already specifies it as eleven beats, and `PLAN:315` §M2 already
gates it correctly: *"a fresh player completes all eleven beats… without
console, debug panel, noclip or developer knowledge. Save/load succeeds after
every beat."* **The Early Access build is that gate plus presentation, not a
larger thing.**

| # | Beat | Ships as |
| --- | --- | --- |
| 1 | Arrival / alert | curb → lobby → clock-in → first paper |
| 2 | Inspect | 2A Vantry point, found by ear |
| 3 | Plan | the capsule is named; the counter is implied, not waypointed |
| 4 | Shop | one Passage shop, one procurement verb, one clue |
| 5 | Return | an Orison changed by absence |
| 6 | Repair | one tactile mechanism with resistance, commit, sound, test |
| 7 | Converse | Mina, using evidence |
| 8 | Recur | repair alone does not close the wound |
| 9 | Succumb | onset, gradual and sudden |
| 10 | Scramble | one dark pocket, one pursuer, one case truth |
| 11 | Wake | 4B, with residue |

**Around the journey, four things and no more:** a title screen
(`game/project.godot:18` already boots `scenes/ui/title_screen.tscn`), a save
that survives every boundary (`SAVE_VERSION := 4`,
`user://reality_maintenance_save.json`), a settings surface, and a quit.

**Replayability claim for Early Access is deliberately narrow.** One shift,
replayable because the building is simulated rather than scripted — schedules,
weather, light, residents and acoustics differ. **We do not claim campaign
length.** A second case is the first post-launch content beat, not a launch
promise.

---

## 3. Hard content ceiling

Everything below is a **maximum**, not a target. Under-filling is allowed;
exceeding requires an owner ruling.

| Domain | Early Access ceiling | Currently in tree | Ruling |
| --- | --- | --- | --- |
| **Cases** | **1 playable** (Mina) | 8 case ids in `game/data/reality_cases.json` | 7 remain defined-but-unreachable. Do not finish a second. |
| **Floors** | **route-visible only**: F01 lobby/office, F02 corridor + 2A, one Passage shop, 4B, one dream pocket | 8 levels, 11 shop interiors | The rest stays walkable and unpolished. No beautification pass off-route. |
| **Dream material** | **1 pocket, 1 pursuer, 1 wake outcome family, 1 release print** (Mina's) | ten-module substrate, fauna, organelles, microbiology, tentacle, encroachment, temporal specimens | The largest single cut in this document. See §6. |
| **Maintenance apparatus** | the five on the route: watch detector, night register, tour key, Vantry point, hardware counter | service round, boiler, ballcock, chute, dumbwaiter, fuse, interlock, annunciator | Others may remain present and operable; **none may be required**. |
| **Language** | **House English prototype, opening shift only**, 10–25 terms, with plain/parallel surface | `house_english.gd`, lexicon, `HouseEnglishTest` 5/5 | Attention multiplier, **not** a blocker. Must be skippable. |
| **Telephones** | **ambient + the existing report route** | PHONE-A/B landed; board, 4B suite, booth briefed | No required call in the eleven beats. |
| **Radios** | **ambient only** | one per household (`b66fdde`) | Zero required interaction. |
| **Weather / celestial** | **ambient only** | weather, sky, celestial ephemeris implemented | Zero required interaction. Trailer material, not mechanics. |
| **Audio** | route mix + one accessibility pass | acoustic graph, songbook, music director | No new songbook work. |
| **Optional delights** | **anything already built that costs zero route risk** | arcade, darts, pool, phonautograph, projector, bookshelf, fortune machine | Keep, do not extend. Each is a discoverable, not a feature bullet. |

**The ceiling rule, stated once:** *a feature already built can still be cut
from the release route.* Presence in the tree is not entitlement to the store
page, the trailer, the tutorial or the bug budget.

---

## 4. Classification of major open work

Five classes, as `TASKS.md:30` requires. Classified by family with named
exemplars; 318 bullets are not individually reproduced here.

### 4.1 Launch blockers

Nothing ships without these.

| Item | Source | Why it blocks |
| --- | --- | --- |
| **K2 — fresh-save golden shift** | `TASKS.md:105` | The promise *is* this route. Never yet walked end-to-end without developer knowledge. |
| **K3 — eleven-boundary save matrix** | `TASKS.md:109` | A save that loses a beat is a refund. |
| **Route performance breach** | `AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md` §Performance status | **Two *playable* stations on the route are over budget**: lobby 18.06 ms and atrium F03 landing 23.70 ms; carriageway 16.67 ms is a boundary breach. These are corrected-harness figures, not the superseded detached-camera table. |
| **K1 closure** | `TASKS.md:87` | Three performance rows and a shadow-policy proof still owed. |
| **Two standing WalkTest failures** | baseline §Established baseline debt | Verified still red on `0392768` this session. One of them — the authored-job count — is a *stale assertion*, see §14. |
| **M6 critical-route pass** | `PLAN:369` | Collision, clipping, reach, subtitle, controller, mix on the route only. |
| **Accessibility floor** | `PLAN:355` §M5.6 | Gradual-onset-only mode, subtitles, mix safeguards. Partially present (`sleep_pressure_director.gd` FORMS, `dream_caption_layer.gd` opt-out) but **no settings surface exists** — see §10. |
| **Three fresh-player tests** | `PLAN:369` §M6.6 | The gate that decides whether the promise reads. |

### 4.2 Attention multipliers

Ship if they cost no route risk; they are what makes a trailer land.

- **House English opening-shift prototype** (`TASKS.md:67`) — the single most
  distinctive thing in the project. Explicitly self-classified as an attention
  multiplier by its own task line. **Must remain skippable.**
- **The house telephone board and 4B suite** (`TASKS.md:76`) — PHONE-A/B are in;
  the *board* is the photogenic object.
- **"The House Heard Big"** (A11, `RECON:` Later section) — the reconciliation
  already rules it *"a strong trailer or demo anecdote"* and *"not an M2
  tutorial dependency"*. Correct on both counts. Optional post-first-shift.
- **Weather, celestial sky, neighbours, period exterior texture** — already have
  focused proof per `RECON:25` M6 row. **Free trailer footage. Zero mechanics.**
- **The dark scramble's presentation quality** — the horror beat is the hook.

### 4.3 Post-launch

Built or half-built, deliberately deferred.

- **M7 Peter** (`PLAN:385`) — the template proof. First post-launch content.
- **M8 remaining cases** (`PLAN:395`) — Juno, Cal, Omar, Mae.
- **The Passage's other ten shops** — one shop ships; ten remain rooms.
- **Arcade / studio / film / phonautograph expansions** (`TASKS.md` §A, §S, §F,
  §G — 43 bullets between them).
- **Entropy / dirt system** (§E, 18 bullets).
- **Street and traffic breadth** (§T, 18 bullets) beyond the route leg.
- **Mobile** — already deprioritised by owner ruling, `TASKS.md:3187`.

### 4.4 Cut / deprecated from the release route

Not deleted from the repository. Removed from the path to launch.

- **Dream biological breadth**: FA (16), TB (18), DF (12), DT (6), DO (6),
  LC (13), MBIO (6), T4 (6), CT (2) — **85 bullets**. The Early Access dream is
  one pocket and one pursuer.
- **MX layered surface system** (9) and **DP detail pass** — off-route quality.
- **General apartment beautification** — already a `RECON:` Later item.
- **The six-case cast data completion** (C2, `TASKS.md:3143`) — finishing hero
  models and decor for five unreachable residents is not a launch activity.
- **Sanctioned expansion (Rhea, Nadia)** — and see §14 for the fact that these
  two, plus three others, already have case entries while three ruled cases
  do not.

### 4.5 Evidence-only / history

Must not be counted as open work — the reconciliation already says so
(`RECON:` §Punchlist integration rule).

- `walkthrough_punchlist.md`: **31 `resolved` + 4 `info` rows**.
- 45 `wish` rows — deferred until a playtest promotes one.
- 50 `ugly` rows — **only route-visible ones enter M6**, per K4 (`TASKS.md:112`).
- **2 `blocker` rows** — but the file's own header states *"The current triage
  below reports no open blocker"*. See §14.
- The superseded eleven-station performance table in the baseline — explicitly
  labelled *"superseded as production evidence"*.
- The 102-suite `*_shot.gd` static inventory — *"maintenance debt, not 101
  launch blockers"* (`RECON:` Evidence infrastructure).

---

## 5. Critical path from `0392768` to release candidate

Only the blocking chain. Everything else runs beside it or waits.

```
0392768  (main today: loop spine + first-minute route K2-A…K2-F integrated)
   │
   ├─(a) K2-G ── LANDED as 374eab0; beat 2 is now findable by ear
   │
   ▼
[1] K2 — WALK THE ELEVEN BEATS, FRESH SAVE, NO DEV KNOWLEDGE      ← the gate
   │         output: the exact first missing/unclear transition
   │         (NOT a pre-authored backlog — TASKS.md:105 forbids that)
   ▼
[2] K-tasks generated by [1] ── bounded, one per observed failure
   │      (the K2-A…K2-G series is the working example of this shape)
   ▼
[3] K3 — ELEVEN-BOUNDARY SAVE MATRIX
   │      any boundary that loses state returns to [2]
   ▼
[4] ROUTE PERFORMANCE  ── lobby 18.06 → ≤16.6 ; F03 landing 23.70 → ≤16.6
   │                      carriageway 16.67 → ≤16.6 ; + K1's 3 remaining rows
   │                      + a visually proved shadow policy
   ▼
[5] M6 ROUTE-ONLY POLISH ── collision · reach · subtitle · controller · mix
   │                        + route-visible `ugly` rows only (K4)
   ▼
[6] ACCESSIBILITY + SETTINGS SURFACE  ← currently has NO owner; see §10, §11
   │
   ▼
[7] FRESH-PLAYER TEST ×3 ── fix observed confusion; do not add content
   │
   ▼
[8] RELEASE CANDIDATE ── warning-free, no debug dependency, no placeholder
                          on route (PLAN:476 §9 definition of done)
```

**Off the path, running in parallel, allowed to slip without moving launch:**
House English prototype · telephone board · trailer capture · store assets ·
press kit · engine ledger.

**Two dependencies that are commonly mistaken for path items and are not:**
Peter (M7) and any second case. `RECON:` §Stop rules already forbids starting
Peter *"because supporting assets happen to be ready."*

---

## 6. Stop building this now

Ranked by how much attention they are currently consuming against how much
Early Access needs them.

| # | Stop | Reason | Restart trigger |
| --- | --- | --- | --- |
| 1 | **Dream biological breadth** — fauna, organelles, lifecycles, microbiology, tentacle remodelling, temporal specimens, critter skins (**~85 open bullets**) | Early Access needs *one pocket, one pursuer, one truth*. This family is the single largest consumer of recent capacity and the smallest contributor to the promise. `PLAN:114` already rules the dream *"punctuation, not a separate campaign"* — the build has been treating it as a campaign. | After [7], as post-launch depth. |
| 2 | **Second-case work of any kind** — Peter content, case data for unreachable residents, C2 cast completion | `RECON:` §Stop rules forbids it explicitly. A second case doubles the polish surface before the first is proved. | M7, post-launch. |
| 3 | **Off-route environmental and material quality** — MX, DP, entropy, apartment beautification, street breadth beyond the route leg | Atmospheric breadth does not substitute for the golden shift. `RECON:10` says the same in the executive ruling. | M6+, and only if a playtest names it. |
| 4 | **New apparatus families** — additional service-round machines, additional shop interiors, additional delight props | The apparatus language is *already proved* (SR7 series). More instances do not raise the ceiling; they raise the bug surface. | Post-launch content beats. |
| 5 | **Bulk evidence-suite migration** — the 102-suite `*_shot.gd` population | `RECON:` migration policy already answers this: migrate when the subject is already being changed. Bulk migration is a 100-suite refactor with no player-facing effect. | Rule 5 of the migration policy: after five migrated full-root suites, re-derive timing targets. |

**A sixth, stated separately because it is a habit rather than a task family:**
stop treating a green focused suite as a beat. `RECON:139` §Stop rules:
*"Do not declare M2 complete from unit tests alone."* The K2-A…K2-G series is
the correct shape — each one measured a *player-facing* failure first.

---

## 7. Trailer / demo beat sheet — proved or explicitly gated material only

Every beat below names the evidence that licenses it. **`GATED` marks material
that may only be captured after the named gate closes**; it must not be shot
early and cut in.

| # | Beat | Material | Licence |
| --- | --- | --- | --- |
| 1 | The curb at night | street, traffic, weather, period exterior | `RECON:25` M6 row: weather/celestial/neighbours/exterior "have focused proof" |
| 2 | The lobby, and the clock-in | watchman detector → night register spindle | K2-B sheet `art/renders/…clock_answers…`; `ClockAnswersLiveTest` 42/42 |
| 3 | One paper, one instruction | the work-order card | K2-C sheet; `FirstStepLiveTest` 37/37 |
| 4 | Finding the stair by architecture | K2-D/K2-E signage, landing plate | `art/renders/first_minute_k2e/README.md`, floors 0 |
| 5 | The landing says which door | `FLOOR 2 · ← 2A 2B · 2C →` | `art/renders/first_minute_k2f/production_02/` — claim 0.183, floor 0 |
| 6 | **Finding the fault by ear** | the chirp, the grille dropping | **landed `374eab0`** — `art/renders/first_minute_k2g/production_04/`, claim 0.0955 @ 1984× floor. Cleared for use. |
| 7 | The Passage, and a proprietor | one shop, one part | `GATED` on [1] K2 |
| 8 | The repair mechanism, in hand | resistance → commit → test | `GATED` on M3 quality pass |
| 9 | Mina, answering | conversation with evidence | `GATED` on [1] K2 |
| 10 | Onset | the interval arriving | `GATED` on [5] |
| 11 | **The dark** | pocket, pursuer, lamp decision | `GATED` on [5]; N3's measured lamp-on/off asymmetry (3.425 s vs 11.358 s) is the *design* proof, not footage |
| 12 | Waking in 4B, changed | persistent residue | `GATED` on [3] |

**Capture rules, binding.** Player camera only — body, eye, carried lamp and
streaming origin together (`AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md` records
what happens when this is violated: a detached benchmark camera invalidated an
entire eleven-station performance table). No debug label may appear: **2A
currently renders world-space case labels** (`MINA`, `Mina Vale · 2A [ACTIVE]`,
`SOFA`, `DESK`, `CAPTION CALIBRATOR`) from `case_interactable.gd`, and seven
`DebugLightHandle` nodes are interactive inside 2A. **Both are trailer
blockers and are recorded in §11 as risks.**

**Demo cut:** beats 1–6 only, ending on the chirp found. That is the material
that is *proved today*, it is 8–12 minutes, and it ends on a discovery rather
than a cliffhanger.

---

## 8. Required assets

Deliberately not researched here — pricing, platform policy, competitors and
market size belong to **K0-GTM** (`TASKS.md:42`,
`EARLY_ACCESS_GO_TO_MARKET_PROJECT.md`). This section lists only what the
*build* must produce.

**Store page**
- capsule family (6 sizes) — one hero object, legible at 231×87
- 6–8 screenshots, all player-camera, all from a shipping build, none with a
  debug label
- trailer, 60–90 s, beat sheet §7
- short description = §1 promise, near-verbatim
- long description with an **honest Early Access statement**: one case, one
  shift, ~30 minutes, replayable, campaign to follow
- system requirements — **owed a measurement**, see §10
- content warnings: darkness, pursuit, sleep disorder depiction, period social
  content

**Press kit**
- fact sheet, logo, 10 stills, 3 clips, 1 GIF of the grille drop
- a one-paragraph statement on the narcolepsy depiction, reviewed before send
- named response owner

**Festival / demo**
- the 8–12 minute demo cut above, as a build
- a two-sentence pitch and a 30-second hook
- a booth loop that survives with no audio

**Creator-facing**
- 3 sanctioned discoverables that are *not* on the critical route (the arcade,
  the phonautograph, the fortune machine) so that coverage finds something the
  trailer did not spend

---

## 9. Fresh-player test cadence and go/no-go

`PLAN:369` §M6.6 requires three tests. This sets when and against what.

| Round | When | Players | Question | Go threshold |
| --- | --- | --- | --- | --- |
| **FP-1** | after [1] K2 | 2 | Can they finish the shift at all, unaided? | both finish; ≤2 assists each |
| **FP-2** | after [5] | 3 | Do they know their *next practical intention* at all times? | ≥80 % of transitions self-resolved within 45 s |
| **FP-3** | after [6] | 3 fresh | Is it *good*? | all 3 finish unaided; ≥2 volunteer a specific moment they liked |

**Instrumented go/no-go, applied at [8]:**

| Gate | Threshold | Source |
| --- | --- | --- |
| completion | 3/3 fresh players finish unaided | `PLAN:325` |
| time-to-target | no route transition exceeds **45 s** unaided | K2-G ceiling, generalised |
| save | 11/11 boundaries reconstruct | `TASKS.md:109` |
| comprehension | player can state what was physically wrong, and why repair alone did not fix Mina | `PLAN:340` M4 gate |
| fear/fairness | knows why the passage ended **within half a second** | `PLAN:355` M5 gate |
| no-dev-knowledge | zero console, debug panel, noclip | `PLAN:325` |

**No-go is a hold, not a scope cut.** If FP-3 fails, the answer is another pass
on the route — not a second case, and not more world.

---

## 10. Technical gates

| Gate | Target | Status today | Owed |
| --- | --- | --- | --- |
| **Performance — route playable stations** | ≤16.6 ms | lobby **18.06**, F03 landing **23.70**, carriageway **16.67** = OVER; corridor F04 12.96, 4B 10.61, roof 6.45 = PASS | three fixes + K1's three remaining rows + shadow policy proof |
| **Performance — composition cameras** | reported, not gated | atrium 33.33, street 27.08 | keep as worst-case; **never quote as gameplay** |
| **Save** | 11/11 boundaries; version migration | `SAVE_VERSION := 4`, `_migrate()` exists | K3 matrix; a corrupt-save path |
| **Accessibility** | gradual-onset-only; subtitles; mix safeguard | mechanisms exist (`sleep_pressure_director.gd` FORMS, `dream_caption_layer.gd` opt-out, `reduced_typewriter`) | **no settings surface exists in the tree** — this is an unowned blocker |
| **Audio** | route mix; no clipping; caption parity | acoustic graph, 143 simultaneous emitters observed in production; `design/SOUND_AS_GAMEPLAY_AUDIT.md` now owns the policy | a route mix pass and a loudness ceiling, **measured in a production walk** — that audit's numbers are self-declared hypotheses |
| **Input** | keyboard, mouse, controller; remap | keyboard/controller/touch share `PlayerController.toggle_lamp()` (N3) | a remap surface; controller navigation of every panel |
| **Distribution** | reproducible build channels | none in tree | K0-GTM owns; **blocked on nothing** — can start now |
| **Warnings** | zero on route | resident-navigation, found-art `cam_noel_witches` warnings recorded | clear or explicitly waive each |

**The accessibility line is the most under-owned item in this audit.** The
*mechanisms* are built and tested; the *player's ability to turn them on* is
not in the repository. That is a launch blocker with no current owner.

---

## 11. Risk register

| # | Risk | Owner | Likelihood | Impact | Mitigation | Trigger |
| --- | --- | --- | --- | --- | --- | --- |
| R1 | **K2 reveals many broken transitions, not few** | Claude | Medium | High — moves launch | K2-A…K2-G shows the shape works: one bounded task per observed failure | >8 new K tasks from one walk |
| R2 | **Route performance does not reach 16.6 ms** | Codex | **High** | High | 3 known breaches are all *long-view submission* cost, and the frame is known submission-bound not fill-bound (`TASKS.md:3216` §P9) | any station still >18 ms after one pass |
| R3 | **No settings/accessibility surface** | *unowned* | **High** | High — ships an inaccessible game | assign now; it is a UI task, not a systems task | still unowned at [5] |
| R4 | **Debug labels and handles in 2A reach a screenshot** | Mina case owner | Medium | High — a debug label in a trailer is a credibility loss | gate capture on a "no debug affordance on route" check | any capture shows a `Label3D` name |
| R5 | **Dream breadth resumes and consumes the run-up** | owner | **High** | Medium | §6 ruling; the work is preserved, not deleted | any new FA/TB/DF/DO/LC/MBIO commit before [7] |
| R6 | **Narcolepsy depiction lands badly** | owner | Low | **Very high** | `PLAN:114` already rules the condition is not evil and does not cause the Tenant; add a reviewed statement to the press kit before any outreach | any external reading that the condition is the villain |
| R7 | **Two standing WalkTest failures normalise** | Codex | Medium | Medium | one is a *stale assertion* (§14) and cheap; the other is a mesh-merge count | a third failure joins them |
| R8 | **Store/press work waits for content lock** | K0-GTM | Medium | Medium | §8 lists what needs no lock; start it now | no store asset exists at [5] |
| R9 | **The two punchlist `blocker` leads are real** — view-direction light loss, corridor ceiling gap (§14 C-5) | Codex | Medium | High if confirmed | reproduce both on the golden route before [5]; they are diagnostic leads, not yet defects | either reproduces on a route camera |
| R10 | **Boot cost blocks evidence** | Codex | Medium | Low–Medium | production root boots in **32.5–33.2 s** against the protocol's 24 s warning, leaving ~10 s usable margin in a 60 s capture | any suite that cannot fit 11 frames |

---

## 12. Four release horizons

Evidence gates, not dates — consistent with `PLAN:246`.

### H1 — Internal playable
**Entry:** [1] K2 walked, [2] its tasks closed, [3] save matrix green.
**Contains:** eleven beats, fresh save, no dev knowledge, ugly presentation
permitted.
**Exit:** the owner completes the shift without asking a question.

### H2 — Public demo
**Entry:** [4] performance, [5] route polish, FP-2 passed.
**Contains:** beats 1–6 (§7 demo cut) as a build; store page skeleton; trailer.
**Exit:** 3 external players finish the demo unaided; no debug affordance on
the route.

### H3 — Early Access launch
**Entry:** [6] accessibility + settings, [7] FP-3, [8] RC gates.
**Contains:** the complete Mina shift; one case; ~30 minutes; replayable;
honest EA statement.
**Exit:** all of §9's go/no-go table green.

### H4 — Post-launch campaign growth
**Contains, in order:** M7 Peter (proves the template) → route-visible punchlist
`ugly` backlog → the second and third cases → the Passage's other shops → dream
breadth → arcade/studio/film → entropy → mobile.
**Rule:** each case ships as a content beat with its own trailer moment. The
campaign is grown in public, which is what Early Access is *for*.

---

## 13. Proposed `TASKS.md` patch — text only, not applied

`TASKS.md` is not edited by this document. The following is the change this
audit recommends to the **K section only** (`TASKS.md:25`–`120`). Ids are
permanent; nothing is renumbered.

```diff
 ## K — Core loop / the complete shift

-- **K0-EA — PRIORITY: REORGANIZE THE MILESTONES AROUND A FUNDABLE EARLY-ACCESS
-  BUILD.** [...full brief...]
+- **K0-EA — CLOSED 2026-08-26.** Scope ruling published at
+  `design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md`: one-sentence promise, the
+  Mina shift as the whole release journey, a hard content ceiling, the
+  five-way classification, the critical path, the stop-building list, the
+  trailer beat sheet, the go/no-go table and four horizons. K0-GTM is
+  unblocked. Re-open only if the owner changes the promise.

+- **K0-ACCESS — LAUNCH BLOCKER, UNOWNED: THE PLAYER CANNOT TURN
+  ACCESSIBILITY ON.** The mechanisms exist and are tested — gradual-only
+  onset (`sleep_pressure_director.gd` FORMS), dream caption opt-out
+  (`dream_caption_layer.gd`), `reduced_typewriter` — but no settings surface
+  exists in the tree. Ship a minimal options panel reachable from the title
+  screen and from pause: onset form, captions, subtitle size, master/music/
+  effects, mouse sensitivity, invert-Y, controller remap. Accessibility that
+  cannot be switched on is not accessibility.

+- **K0-CAPTURE-HYGIENE — LAUNCH BLOCKER FOR MARKETING CAPTURE: NO DEBUG
+  AFFORDANCE ON THE ROUTE.** 2A renders world-space case labels (`MINA`,
+  `Mina Vale · 2A [ACTIVE]`, `SOFA`, `DESK`, `CAPTION CALIBRATOR`) via
+  `case_interactable.gd`, and seven `DebugLightHandle` nodes are interactive
+  inside 2A within 5 m of the Vantry target. Decide per family: ship, gate
+  behind a debug flag, or restyle. Evidence:
+  `art/renders/first_minute_k2g/production_04/02_a_plausible_wrong_station.png`.

 - **K1 — CURRENT-TREE BASELINE — RUN 2026-08-26, RED GATES REMAIN.** [...]
-  Finish the remaining three rows and price a visually proved shadow policy
-  before closing K1; FULL verdict recovery itself is complete.
+  Finish the remaining performance rows and price a visually proved shadow
+  policy before closing K1; FULL verdict recovery itself is complete.
+  NOTE: the row count is inconsistent with the baseline document — the audit
+  names eleven stations and tabulates ten corrected rows, which is one
+  outstanding, not three. Reconcile the count before closing.

 - **K2 — FRESH-SAVE GOLDEN SHIFT.** [...unchanged — this is the gate...]
 - **K3 — ELEVEN-BOUNDARY SAVE MATRIX.** [...unchanged...]
 - **K4 — ROUTE POLISH INTAKE.** [...unchanged...]

+- **K5 — ROUTE PERFORMANCE TO BUDGET.** Three playable stations on the golden
+  route exceed 16.6 ms: lobby 18.06, atrium F03 landing 23.70, carriageway
+  16.67 (boundary). The frame is submission-bound, not fill-bound
+  (`TASKS.md` §P9). Composition cameras (atrium 33.33, street 27.08) are
+  reported, never gated. Blocker for H2.
```

Additionally, and **not** as a patch: `TASKS.md` §K's own status footer should
eventually cite this document beside `MILESTONE_RECONCILIATION_2026-08-26.md`.
That edit belongs to whoever owns `TASKS.md`.

---

## 14. Contradictions, duplicate work and stale claims

Found by reading the authorities against each other and against the tree. Each
is a *finding*, not a repair; none was fixed by this document.

**C-1 — The reconciliation's M0 row is stale against the audit it cites.**
`MILESTONE_RECONCILIATION_2026-08-26.md:25` says *"FULL timed out after a
roof-route failure"* and owes *"Isolate monitor-door roof reach, then rerun
FULL"*. `AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md` — dated the same day —
records *"The former monitor-door blocker is closed"*, FULL split into PHYSICAL
and CASES, both printing verdicts under 60 s, and the roof reached at z=4.5.
**The gate the reconciliation still demands has already been met.**

**C-2 — Eight stations or eleven.** The same reconciliation row asks to *"rerun
FULL and the eight performance stations"*; the baseline states *"the production
harness now owns eleven stations"*. Two different instruments are being
referred to by one name.

**C-3 — "Three remaining rows" does not divide.** `TASKS.md:87` (K1) owes
*"the remaining three rows"*. The baseline names eleven stations and tabulates
**ten** corrected rows. Ten of eleven leaves one. Either the station count or
the remainder is wrong; both are cited as evidence for closing K1.

**C-4 — The ruled case six and the shipped case data disagree.**
`TASKS.md:3132` §C (ruled 2026-08-10, `ORISON_BIBLE` §IV.1): *"Six residents
carry cases: Mina, Peter, Juno, Cal, Omar, Mae. Rhea and Nadia are the
sanctioned expansion."* `game/data/reality_cases.json` ships eight ids:
`mina_caption_crisis`, `juno_feedback_tetris`, `omar_unrepairable`,
`rhea_bad_karaoke`, `nadia_code_pinball`, `sacha_camera_delay`,
`evelyn_paper_jam`, `teresa_call_bells`.
**Peter, Cal and Mae — three of the ruled six — have no case entry. Sacha,
Evelyn and Teresa have entries and are in neither the six nor the expansion.**
This matters beyond bookkeeping: `PLAN:385` makes Peter the M7 template, and
Peter is the one canonical case with no data.

**C-5 — The punchlist header contradicts its own rows, and the rows are not
trivial.** `walkthrough_punchlist.md` header: *"The current triage below
reports no open blocker."* The file contains **two rows marked `blocker`**, at
`:83` and `:84`:

- `:83` — *"named OrbitSweep stations … lights reportedly disappear with view
  direction"*;
- `:84` — *"reported ceiling gaps … upward ray plus `show_all_floors` toggle
  must distinguish ceiling ownership/visibility gating from the systematic
  corridor generator gap above"*.

Both are written as diagnostic leads rather than confirmed defects, which is
probably why the header discounts them. **But a light set that changes with
view direction, and a corridor ceiling gap, are both golden-route-visible if
real.** Either confirm and promote them, or downgrade and say so — the current
state lets a reader take "no open blocker" at face value. This is the one
contradiction in this list that could cost a launch rather than a citation.

**C-6 — A standing test failure is a stale assertion, not a defect.**
`game/tests/walk_test.gd:1152` asserts `job_ids() == [ChirpHunt.JOB_ID]` —
exactly one authored job. `game/data/maintenance_jobs.json` now declares two:
`vantry_chirp_2a` and `lena_radiator_round_2b`. This has been carried as
"established baseline debt" in the baseline document and in every K2 handoff.
**It is a one-line test fix, not a product defect**, and it is currently one of
the two failures that "must not normalize new failures."

**C-7 — Duplicate scope statements.** `TASKS.md:30` (K0-EA) and
`EARLY_ACCESS_GO_TO_MARKET_PROJECT.md` §First planning gate both specify the
scope-ceiling deliverable. This document satisfies both; they should point at
it rather than at each other.

**C-8 — "Eleven shops" is an asset count, not a content claim.** `PLAN:44`
lists *"eleven shop interiors"* under "What exists now". The Early Access
ceiling (§3) uses **one**. Nothing is wrong with the plan; the risk is that
the eleven gets read as shippable content depth.

**C-9 — Unverifiable-by-this-task claim, flagged not resolved.** The
reconciliation reports a pre-integration inventory of *"102 `*_shot.gd` suites:
62 appeared to boot the production root, 45 contained an unchecked PNG save"*.
The tree at `0392768` contains **109** `*shot*.gd` files. The difference is
consistent with suites added since the inventory, but this task was not
permitted to run `tools/audit_shot_suites.py`, so the reconciliation's figures
are **carried forward unverified**.

---

## 15. Sources

Every claim above traces to one of these. Line numbers are from `0392768`.

| Path | Used for |
| --- | --- |
| `TASKS.md:25–120` | K section; K0-EA:30, K0-GTM:42, K0-ENGINE:52, K0-LANGUAGE:67, K0-PHONE:76, K1:87, K2:105, K3:109, K4:112 |
| `TASKS.md:3132–3146` | §C cast ruling; C1:3138, C2:3143, C3:3146 |
| `TASKS.md:3187` | owner ruling, mobile deprioritised |
| `TASKS.md:3216` | §P9, submission-bound frame, deferred optimisation |
| `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md:7` | product decision, the six-step loop |
| `…:67` | §3 the golden shift, eleven beats |
| `…:315` | M2 gate |
| `…:340` | M4 gate |
| `…:355` | M5 gate, accessibility clause |
| `…:369` | M6 gate, three fresh-player tests |
| `…:385`, `:395` | M7 Peter, M8 six cases |
| `…:476` | §9 vertical-slice definition of done |
| `design/MILESTONE_RECONCILIATION_2026-08-26.md:10` | executive ruling |
| `…:25` | milestone status table |
| `…:71` | capture migration policy |
| `…:139` | stop rules |
| `design/AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md` | result matrix; roof closure; corrected vs superseded performance tables; established baseline debt |
| `design/EARLY_ACCESS_GO_TO_MARKET_PROJECT.md` | workstreams; required artifacts; first planning gate |
| `design/walkthrough_punchlist.md` | triage counts (exact severity-cell match): 2 blocker (:83, :84), 50 ugly, 45 wish, 31 resolved, 4 info |
| `design/ENGINE_KNOWLEDGE_LEDGER.md:19` | ownership-before-machinery contract |
| `game/docs/core_loop.md` | loop spine contract |
| `game/data/reality_cases.json` | eight shipped case ids |
| `game/data/maintenance_jobs.json` | two authored jobs |
| `game/scripts/game/reality_game_state.gd:9` | `SAVE_VERSION := 4`, save path, `_migrate()` |
| `game/project.godot:18,34` | title screen main scene; autoloads |
| `game/tests/walk_test.gd:1152` | the stale single-job assertion |
| `art/renders/first_minute_k2e/README.md` | K2-E measured evidence |
| `art/renders/first_minute_k2f/production_02/` | K2-F measured evidence |
| `art/renders/first_minute_k2g/production_04/` | K2-G evidence — landed as `374eab0` after this audit began |
| `design/SOUND_AS_GAMEPLAY_AUDIT.md` | audio-gate owner; postdates this audit (`bf7bd64`) |

**Counts produced by this audit** (repeatable without the engine): 318
top-level `TASKS.md` bullets across 43 sections; 298 test scenes; 163
`*test*.gd`; 109 `*shot*.gd`; 882 commits since 2026-02-17.

---

## What this document does not do

- It does not research market size, pricing, platform policy or competitors.
  That is **K0-GTM** (`TASKS.md:42`), and it is now unblocked.
- It does not change production code, tests, scenes, assets, capture tools,
  `TASKS.md`, the reconciliation, or any existing design document.
- It does not set dates. Every horizon in §12 is an evidence gate.
- It does not delete anything. Every cut in §4.4 and §6 is a removal from the
  *release route*, not from the repository. **Preserve the long game; do not
  require it for Early Access.**
