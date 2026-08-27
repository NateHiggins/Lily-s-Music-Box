# Engine extraction boundary — 2026-08-27

**Base:** `4d1028b32c181c2c6c1076303db13f3ffa98895a` (pushed `origin/main`).

**Godot was not run.** No import, capture, export, renderer, Blender or test was
run. No production code, data, scene, test, `TASKS.md` or existing design
document was modified. One new file.

**This is a decision document, not a second knowledge ledger.**
`design/ENGINE_KNOWLEDGE_LEDGER.md` holds the *observations*. This holds the
*boundary* — what may be called reusable, on what evidence, and what may not.

> **Labels.** **FACT** — verified in-tree at `4d1028b` by tracing callers, with
> a path and a number. **INFERENCE** — my reading. **OWNER** — a decision I am
> not making.

---

## A. The ruling

**(b) a reusable internal framework — and a narrow one, concentrated almost
entirely in the evidence toolchain rather than in the game systems.**

Not (a), because three things carry **no traced coupling to Orison** and one of
them is already parameterised for other projects — **which is not the same as
proven portable, and §D forbids me that word until a second consumer exists**: `tools/run_godot_serial.ps1` takes
`-Scene`, `-ProjectPath`, `-ShotDir`, `-LogPath`, `-TimeoutSeconds` and hardcodes
no Orison path; `game/tests/shot_harness.gd` is 159 lines that own no scene state
and read their output directory from the environment; `CelestialEphemeris` is
static astronomy taking explicit UTC and coordinates. **Not (c)**, because an
extractable toolkit requires a consumer and **no subsystem in this repository has
ever been consumed by a second project** — there is no second project. **Not
(d)**, and the numbers say so plainly: **54 of the repository's scripts reference
the `GameBoot` autoload**, `building_root.gd` is **2,851 lines making 28 autoload
references**, and the most-used interaction surface in the game — **66 files
defining `interact_prompt`, discovered by `has_method()` duck-typing — has no
base class, no interface and no registry.** A licensable engine is a set of
contracts other people can hold. **We have conventions we honour, which is a
different and much cheaper thing.** The honest sentence is: *we have built an
unusually rigorous evidence and measurement practice, and a game that obeys its
own conventions well.*

---

## B. Capability census

Portability is assigned from traced callers, not from prose. **Extraction cost
`unknown` is used where I did not trace deeply enough to commit.**

**Read the portability column as a coupling measurement, not a portability
proof.** `reusable-now` means *no coupling to Orison autoloads, data paths or
vocabulary was traced* — it does **not** mean the subsystem has run anywhere
else, because none has (§D). `reusable-with-work` means the coupling is real,
named in the row, and looks separable. `game-only` means the coupling is the
design.

| Capability | Owner / path | Orison assumptions coupled in | External API | Tests / evidence | Portability | Cost | EA relevance | Next-project relevance | Licence blockers |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| **Serial test runner** | `tools/run_godot_serial.ps1` | **None traced.** Fully parameterised | PowerShell params | Used by every suite; `test_release_pipeline_contract.ps1` | **reusable-now** | S | High — all evidence | **High** | Godot licence notice; support burden if leased |
| **Capture evidence harness** | `game/tests/shot_harness.gd` (159 ln) | **None traced.** Header states it owns no scene state; `SHOT_DIR` from env | `setup(owner, suite_tag, expected, …)`, `capture`, `finish` | `audit_shot_suites.py`; `CAPTURE_EVIDENCE_PROTOCOL.md` | **reusable-now** | S | High | **High** | Same |
| **Shot measurement** | `tools/measure_shot_sheet.py` | Manifest-driven crops | CLI + manifest | Used across `art/renders/` | **reusable-now** | S | High | High | Python deps |
| **Celestial ephemeris** | `building/celestial_ephemeris.gd` (112 ln) | **None.** 0 autoloads, 0 `res://`, explicit UTC + lat/long | static funcs | `CelestialEphemerisTest`; `CELESTIAL_SKY_CONTRACT.md` | **reusable-now** | S | Low | Medium | NASA/USNO source attribution |
| **Maintenance activity framework** | `game/maintenance_activity_director.gd` (76), `_run.gd` (129) | **None traced** — 0 autoloads, 0 Orison vocabulary. Data-driven | `submit(verb, value, held)` | `MaintenanceActivityTest`/`LiveTest` — **UNRUN/UNKNOWN** | **reusable-with-work** | M | High (G03) | **High** | Its panel is not portable (below) |
| **Activity panel UI** | `ui/maintenance_activity_panel.gd` | Godot UI, hardcoded key hint string | none | `MaintenancePanelInputTest` 18/18 | game-only | M | High | Low | — |
| **Semantic audio policy** | `audio/audio_policy.gd` (410 ln) | **Autoload singleton**; `GameBoot`; 1 `res://data` path | `stop_source()`, cue requests | Ledger §9; `audit_audio_emitters.py` | **reusable-with-work** | L | High (K0-AUDIO) | **High** | Ledger already warns: productize contracts, **not the singleton** |
| **Acoustic graph** | `audio/acoustic_graph.gd` (250 ln) | **Autoload**; `GameBoot`; Orison's 550-node graph is content | data-driven | `AcousticGraph` suites | reusable-with-work | M | High | Medium | — |
| **Conductor clock** | `audio/conductor_clock.gd` (102 ln) | Autoload; `AcousticGraphData` | tick source | — | reusable-with-work | S | Medium | Medium | — |
| **Interaction verbs** | **No owner.** 65 files currently define `interact_prompt`; `player_controller.gd:328` finds them by `has_method()` | Every implementor is a prop | **documented convention only** — see `INTERACTION_CONVENTION_RECORD_2026-08-27.md` | 164 prompts; no interface test | **game-only** | **L** | High | Medium | **Nothing to license: the API does not exist** |
| **WorkOrders** | `game/work_orders.gd` (320 ln) | `RealityState` autoload; system-clock stamps | issue/close | `WalkTest` (one standing failure, G26) | reusable-with-work | M | High | High | — |
| **Cases / rules** | `game/reality_case_manager.gd`, `reality_rule_director.gd` | **2 autoloads each**; `res://data` schema; case ids | data-driven | Case suites | game-only | L | High | Low | — |
| **RealityState persistence** | `game/reality_game_state.gd` (280 ln) | `RealityCases` autoload; `SAVE_VERSION := 4`; `user://reality_maintenance_save.json`; Orison-shaped payload | save/load | `RealitySaveCompatTest` 14/14 | reusable-with-work | M | High (G15/K3) | Medium | Migration commitments if leased |
| **Procedural building / detail passes** | `building/*_pass.gd` (43 files) + `building_root.gd` **2,851 ln, 28 autoload refs** | **Total.** Floor ids, room kinds, the Orison plan | none | Layout and walk suites | **game-only** | **L** | High | Low | — |
| **Day/night + weather** | `day_night_director.gd` (528 ln), `live_weather_service.gd` (316) | `GameBoot` settings; Queens fallback coordinates | opt-in settings | `LiveWeatherServiceTest`; `LIVE_WEATHER_CONTRACT.md` | reusable-with-work | M | High (G22) | Medium | Open-Meteo terms; privacy disclosure |
| **Input abstraction** | `game_boot.gd` (241 ln) owns the whole InputMap; **54 files reference `GameBoot`** | Action names are Orison verbs (`lamp_toggle`, `activity_commit`) | `ACTIONS`, `JOYPAD_ACTIONS` | `ControllerInputTest` | reusable-with-work | M | High (G07–G09) | Medium | — |
| **Performance station harness** | `tests/perf_probe.gd` (985 ln) | 5 traced couplings to Orison scenes/stations | `PERF_STATION` env | G17 — now proved on the primary machine | reusable-with-work | M | High | **High** | — |
| **Localization / House English** | `language/house_english.gd` (70 ln) | 0 autoloads; 1 data path | `term()`, `render_line()`, plain mode | A test exists | **prototype** | S | **None — zero production callers** | Medium | — |
| **Dream / living architecture** | `scripts/dream/` (56 files) | Total — Orison profiles, cases, residents | none | Extensive suites | **game-only** | L | High (G06) | Low | Generated-media provenance |

---

## C. Five seams and five false friends

### The five highest-leverage reusable seams

1. **The serial runner + shot harness + measurement trio.** Already
   parameterised, already the thing that makes every other claim in this
   repository checkable. **This is the actual asset.**
2. **The evidence protocol itself** (`CAPTURE_EVIDENCE_PROTOCOL.md`) — the
   discipline of receipts, frame-count assertions, control floors and RESULT
   lines. Portable as a *practice* before any code moves.
3. **The maintenance activity core** — 205 lines across two files with zero
   autoload and zero Orison vocabulary. The nearest thing to an accidental
   library in the whole tree.
4. **The semantic-cue contract** — *not* `AudioPolicy` itself. The ledger's own
   §9 already draws this line correctly: source owns the fact, catalog owns
   variants, policy arbitrates, diagnostics record.
5. **`CelestialEphemeris`** — small, pure, tested, and genuinely finished.

### The five strongest false friends

1. **"Interaction system."** 66 implementors, 164 prompts, **no base class and
   no interface.** It looks like the most reusable thing here and is the least:
   extracting it means *writing* the contract, not moving one.
2. **`building_root.gd`.** 2,851 lines and 28 autoload references reads as "the
   engine's root". It is the Orison, assembled.
3. **The Dream substrate.** Ten modules, fauna, organelles, microbiology — the
   breadth suggests a generic creature framework. Every profile is keyed to an
   Orison case.
4. **House English.** A lexicon with a plain-language stratum and a renderer
   with a `plain` mode looks like a localization layer. **It has zero production
   callers** — a prototype, not a capability.
5. **RealityState persistence.** A versioned save with a rollback guard looks
   like a save framework. Its payload is Orison's world model, and the
   `RealityCases` autoload is baked into it.

**INFERENCE — the pattern across all five:** *shared base classes and consistent
conventions are being mistaken for interfaces.* Duck-typing that every author
happens to honour is not an API. It is a habit, and habits do not survive a
second consumer.

---

## D. The two-game rule

> **No subsystem may be described as engine-grade, portable, extractable or
> licensable until a second, tiny reference project consumes it without
> importing any Orison autoload, scene path, data file, case id, resident,
> floor id, job id or narrative state.**

**Until that proof exists, the correct words are "reusable-with-work" and
"we think".**

### The minimal reference project

**Deliberately trivial, and deliberately not a game.** One Godot project,
separate repository, no assets beyond primitives.

- A room with three primitive objects.
- Each object presents a prompt and accepts one verb.
- One object runs a two-step maintenance activity through the activity core.
- One object requests a semantic audio cue; a second requests a competing one.
- The project saves, quits, relaunches and restores which objects were used.
- One evidence scene captures three frames through the shot harness and writes
  a receipt.

### The evidence it must produce

| # | Evidence | Why it is the proof and not a demo |
| --- | --- | --- |
| 1 | It **contains no `res://data/` file from Orison** and declares **zero of Orison's eight autoloads** | The autoload count is the coupling |
| 2 | A **dependency list naming every symbol it imports** | Turns "it works" into a surface |
| 3 | The **serial runner drives it unmodified** | Proves the tool, not just the game |
| 4 | The **shot harness writes a valid receipt** from a project it has never seen | The strongest single claim available today |
| 5 | **Save, quit, relaunch, restore** with a payload that is not Orison's world | Persistence is where the coupling hides |
| 6 | A written list of **everything that had to be rewritten** to make it work | This is the real extraction cost, and it will be larger than the census guesses |

**Evidence 6 is the point of the exercise.** A reference project that succeeds
without surprises has probably been written by someone who already knew the
answers.

---

## E. Three product boundaries

**None of these is chosen here.** Each is described so a future decision has
something to be made *of*.

### E1 — Internal framework for our next game

**Promises:** that *we* can start a second project without re-deriving the
evidence discipline; that the runner, harness and measurement tools work
outside this repository.
**Must not promise:** stability for anyone else, backwards compatibility,
support, or that game systems come with it.
**Docs required:** the protocol, the runner's parameters, and the reference
project's dependency list.
**Versioning / support burden:** none beyond our own discipline. **Breaking it
costs us a morning.**
**Earliest honest milestone:** **after the reference project exists** (§D). Not
before, and it does not need Early Access to have shipped.

### E2 — Optional creator toolkit

**Promises:** that a third party can produce evidence-grade captures and
serialized test runs against their own Godot project.
**Must not promise:** gameplay systems, an editor, migration, or that our
conventions are theirs.
**Docs required:** installation, parameter reference, failure modes, a worked
example, and an explicit non-goals page.
**Versioning / support burden:** **real and permanent** — semantic versioning, a
changelog, an issue channel, and a compatibility statement against Godot
versions we do not control.
**Earliest honest milestone:** **after Early Access ships and after a second
consumer exists.** Two conditions, not one.

### E3 — Licensable standalone product

**Promises:** that someone can build something they depend on commercially.
**Must not promise:** anything at all today.
**Docs required:** everything in E2 plus security response, update cadence,
licence text, third-party notice chain, and a support contract.
**Versioning / support burden:** an ongoing obligation to strangers,
indefinitely.
**Earliest honest milestone:** **not decidable at this milestone and not
scheduled here.** The prerequisite is not code — it is a demonstrated appetite
to carry a support obligation, which is a business decision (§I OWNER).

---

## F. Phased extraction plan

**Early Access is the controlling milestone. Every phase below is subordinate to
it, and each has a hard stop.**

### Phase NOW — documentation and boundary discipline only

**Entry:** immediate.
**Work:** record boundaries in the ledger using §G's taxonomy; when touching a
subsystem for Early Access reasons, *note* its coupling; qualify the words
"engine", "portable" and "reusable" wherever they already appear.
**Exit:** every census row in §B has a ledger entry at the correct evidence
level.
**HARD STOP: no code moves, no directory is renamed, no interface is introduced
"while we are in there".** A refactor that serves extraction and not the ten
critical-path actions is out of scope, however small.

### Phase AFTER FIRST FRIENDS BUILD

**Entry:** a friends build has been issued and a human has walked the route.
**Work:** the reference project (§D), consuming **only** the runner and shot
harness — the two rows the census calls reusable-now.
**Exit:** evidence items 1–4 and 6 exist.
**HARD STOP: if the reference project needs any change to the Orison
repository, stop and write down what.** That change request *is* the finding.
Do not make it.

### Phase AFTER EARLY ACCESS SLICE

**Entry:** the Early Access slice has shipped.
**Work:** extend the reference project to the activity core and the semantic-cue
contract — the two game-side seams with the best evidence. Produce E1's
dependency list.
**Exit:** evidence item 5 exists; §B's cost estimates are replaced with measured
ones.
**HARD STOP: no toolkit or licence work.** E2 remains undecided.

### Phase AFTER A SECOND CONSUMER EXISTS

**Entry:** a real second project — not the reference — depends on at least one
seam.
**Work:** decide E1 formally; evaluate E2 against the support burden honestly.
**Exit:** a written decision, either way.
**HARD STOP: no licensable-product claim without §H answered in full.**

---

## G. Evidence taxonomy for ledger entries

**Five levels. Each requires every level beneath it.**

| Level | Name | What it takes | Example wording |
| --- | --- | --- | --- |
| **1** | **Observation** | Something was noticed once | *"Spatial emitters alone did not produce an intelligible sound world."* |
| **2** | **Local invariant** | It held repeatedly here, with a test or a measurement | *"142 construction paths competed through Master."* |
| **3** | **Reusable contract** | The boundary is stated as an API another author could hold — **names, inputs, outputs, failure modes** | *"Source owns the fact; policy arbitrates; `stop_source()` silences exactly one source."* |
| **4** | **Second-consumer proof** | A project that imports **no Orison state** used it (§D) | *"The reference project drove the harness unmodified."* |
| **5** | **Product claim** | Level 4 **plus** docs, versioning, support and §H | *"Supported for external use."* |

**Rules:**

- **A claim at level N without every level below it is marked `UNSUPPORTED`**,
  in the ledger, in that entry, in those words.
- **Today the ledger's strongest honest level is 3**, and only for the audio
  contract and the process-safety section. **No entry anywhere is at level 4**,
  because level 4 requires a second consumer and there is none.
- Level 3 is where most good engineering stops and should stop. **It is not a
  failure to remain at 3.**

---

## H. Licensing and compliance questions

**Open questions, recorded. No answers are invented and this is not legal
advice.**

1. **Godot / MIT notices.** Which notices must ship with a distributed artifact,
   and does that differ between a game and a tool? `tools/build_third_party_notices.ps1`
   exists and generates notices for friends packages — **what it covers has not
   been checked against a toolkit distribution.**
2. **Bundled third-party code.** Is any non-Orison code vendored in `tools/` or
   `game/`? The friends-build licence audit covered the game; **a toolkit is a
   different bill of materials.**
3. **Fonts and editor/tool licences.** Fonts shipped in a game and fonts shipped
   in a tool that others redistribute are different questions.
4. **Generated media provenance.** The owner's ruling that the music was made
   with Gemini is recorded in the provenance register. **It is recorded, not
   interpreted, and it must not be turned into a licence position here.**
5. **Support, security and update obligations.** E2 and E3 create duties to
   strangers. **What response commitment, if any, is the owner willing to make?**
6. **Telemetry and privacy.** The game ships none. **A tool that reports usage
   would be a new privacy surface**, and the friends-build privacy audit's
   conclusions would not transfer.
7. **Attribution for measurement sources.** `CelestialEphemeris` derives from
   NOAA, USNO Circular 179 and a NASA lunar mosaic. **Attribution requirements
   for redistribution are unchecked.**
8. **The name.** Whether any extracted product may carry a name associated with
   the game is unresolved and sits with the licence/name decision already open
   elsewhere.

---

## I. Follow-ups, ownership and falsification

### Top ten, in dependency order

| # | Task | Godot needed? | EA or post-EA | Notes |
| --- | --- | --- | --- | --- |
| 1 | **Complete 2026-08-27:** qualify existing "engine"/"portable" language in the ledger to §G levels | **No** | EA-safe | Ledger audit marks §§1–8 L2 and §§9–10 L3; none is L4/L5 |
| 2 | **Complete 2026-08-27:** add a ledger entry per §B census row at its true level | **No** | EA-safe | Ledger §11 maps all 19 rows: one L1, fourteen L2, four L3, zero L4/L5 |
| 3 | **Complete 2026-08-27:** write down the interaction contract that does not exist — **as a document, not code** | **No** | EA-safe | `INTERACTION_CONVENTION_RECORD_2026-08-27.md`; records a convention and explicit non-contracts, with no runtime refactor |
| 4 | Answer §H 1–3 against the existing notice generator | **No** | EA-safe | Fact-finding only |
| 5 | Build the reference project (§D) | **Yes** | **Post first friends build** | Phase 2 entry |
| 6 | Produce its dependency list and rewrite-cost list | Yes | Post-EA | Evidence 6 |
| 7 | Replace §B's `S/M/L` guesses with measured costs | Yes | Post-EA | |
| 8 | Decide E1 | No | Post-EA | OWNER |
| 9 | Evaluate E2's support burden | No | Post-EA | OWNER |
| 10 | Answer §H 5–8 before any external claim | No | Post-EA | OWNER |

**Six of ten need no Godot. Four of ten are Early-Access-safe documentation.
Only one requires new code, and it is gated behind a human playing the game.**

### Owner decisions

| # | Decision | Why it is the owner's |
| --- | --- | --- |
| **O1** | Whether a support obligation to strangers is ever acceptable | E2 and E3 exist only if the answer is yes. **A technical audit cannot answer it** |
| **O2** | Whether the reference project is worth a phase-2 slot at all | It costs Early Access nothing only if it happens after the friends build |
| **O3** | Whether any extracted product may use a name tied to the game | Ties to the open licence/name decision |

### Repository facts that would falsify the headline ruling

**Stated so the ruling can be checked rather than believed.**

| If this were true | The ruling changes to |
| --- | --- |
| A second project already consumes any seam without Orison state | **(c) extractable toolkit** — the two-game rule would be satisfied |
| An interaction interface exists that I failed to find — a base class, registry or resource contract behind the 66 `interact_prompt` definitions | False friend #1 collapses; interaction becomes a real seam |
| The `GameBoot` reference count is inflated by static helpers like `b2g()` rather than genuine settings/InputMap dependency | Coupling is weaker than stated; several rows move toward reusable-with-work |
| `MaintenanceActivityTest` has a recorded green verdict I could not find | The activity core's evidence rises a level |
| Any `tools/` script hardcodes an Orison path I did not trace | The evidence toolchain is **not** reusable-now, and the ruling weakens toward (a) |

**INFERENCE:** the third row is the likeliest of the five to be partly true, and
I have not separated `GameBoot`'s static coordinate helper from its settings
singleton in the 54-file count. **That number should be read as an upper bound.**

---

## J. Sources

**Traced at `4d1028b`:** `game/project.godot` `[autoload]` (8 entries) ·
autoload reference counts by `grep -rl` across `game/scripts` ·
`game/scripts/game_boot.gd` · `building/building_root.gd` (2,851 ln, 28 refs) ·
`building/celestial_ephemeris.gd` · `building/day_night_director.gd` ·
`building/live_weather_service.gd` · `audio/audio_policy.gd`,
`acoustic_graph.gd`, `conductor_clock.gd` · `game/maintenance_activity_*.gd`,
`work_orders.gd`, `reality_game_state.gd`, `reality_case_manager.gd`,
`reality_rule_director.gd` · `player/player_controller.gd:299,328` ·
`language/house_english.gd` · `tests/shot_harness.gd`, `tests/perf_probe.gd` ·
`tools/run_godot_serial.ps1` params · `tools/` inventory ·
`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md` · `design/ENGINE_KNOWLEDGE_LEDGER.md`
(12 sections, incl. §9 added by `b70fa9a`) ·
`design/MILESTONE_RECONCILIATION_2026-08-26.md` ·
`design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md` · `TASKS.md` (read-only).

**Two directories named in the assignment do not exist:**
`game/scripts/interaction/` and `game/scripts/maintenance/`. Interaction has no
home directory because it has no owner (§C false friend 1); maintenance lives in
`game/scripts/game/`. **Recorded rather than reported as missing capability.**

---

## K. Limitations

- **Coupling was measured by symbol reference, not by call-graph analysis.**
  The `GameBoot` count is an upper bound (§I).
- **I did not run anything.** Every "test exists" is a file on disk; where no
  verdict is recorded in a pushed document, the census says **UNRUN/UNKNOWN**
  rather than assuming.
- **Extraction costs are estimates.** They are the least reliable column in §B
  and follow-up 7 exists to replace them.
- **`game/scripts/props/` (76 files) and `arcade/` (21) were not individually
  traced.** They are the largest bodies of code in the tree and are assumed
  game-only on the strength of their category, which is exactly the kind of
  inference this document warns against. **Recorded as a gap.**
- **This document proposes no rewrite, no migration and no new interface.**
  Follow-up 3 writes the interaction contract **down**; it does not implement it.
- **No market size, price, schedule or legal conclusion appears here**, and none
  should be inferred from the fact that E2 and E3 are described.
