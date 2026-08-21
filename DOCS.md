# WHERE THINGS ARE WRITTEN DOWN

Seventy-odd documents live in this repository and another twenty-five in the
world compiler next door. This file is the map. **If you do not know where to
look, look here first.**

## Precedence — who wins when two documents disagree

1. **`design/ORISON_BIBLE.md`** — the covenant. It says so itself: where any
   other text disagrees, the Bible prevails until amended.
2. **The newest dated ruling** inside the Bible (`§VIII` carries them).
3. **This map**, for anything about where documents live.
4. Everything else.

A disagreement you cannot resolve is not a bug to paper over — the Bible has a
**§VI Disputed Texts** section for exactly that. Add to it rather than picking a
side quietly.

## The six kinds of document

Knowing which kind you are reading tells you how much to trust it.

| Kind | What it means | Where |
|---|---|---|
| **Covenant** | Rules. Binding until amended by the owner. | `design/ORISON_BIBLE.md` and the other `*_BIBLE.md` |
| **Reference** | How a subsystem actually works. Kept current. | `game/docs/`, `art/docs/`, `docs/` |
| **Brief / proposal** | **Not canon until ruled.** Says so at the top. | `design/*_BRIEF.md`, `docs/songbook_brief.md` |
| **Prompt sheet** | Inputs to asset generation. Historical once used. | `design/*_PROMPTS.md`, `*_PROMPT_SHEET.md` |
| **Brief in data shape** | Design written as JSON but read by nobody. Lives in `design/` so it is not mistaken for game data | `design/resident_decor_profiles.json` |
| **Queue** | Open work, one line each. Deleted when done. | `TASKS.md` |
| **Audit** | Evidence with a method and confidence levels. Findings graduate to the queue; the audit stays as the record | `design/AUDIT_*.md` |
| **Build guide** | How to build and verify. Mechanics only. | `HANDOFF.md`, `art/README.md`, `game/README.md` |

## Where to look for…

| If you want to know… | Read |
|---|---|
| What is true about this world | `design/ORISON_BIBLE.md` |
| What the game loop is and which milestone comes next | `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`, then `design/next_session_plan.md` |
| The final playable map: three zones, the Passage, measured perf baseline | `design/FINAL_MAP_REDESIGN_BRIEF.md` |
| Why an object looks forty years early | Bible §VIII.2, the Rule of Signal |
| What is open right now, and who has it | `TASKS.md` |
| Whether a system is actually used | `design/AUDIT_UNUSED_SYSTEMS_REPORT.md` |
| How to build the layout → Blender → Godot chain | `HANDOFF.md` |
| How to run a test, and which ones exist | `HANDOFF.md`, then `game/tests/` |
| What phase the art is in | `art/docs/photoreal_target.md` |
| Who lives in a flat and what their wound is | Bible §IV, then `game/docs/resident_character_cast.md` |
| How a prop should be built | `design/PROP_ART_BRIEF.md`, `design/PROP_REFERENCE_NOTES.md` |
| What a prop *does* | `design/PROP_ACTIVITIES.md` |
| Which foreground props and set heroes receive E, inspection, refusal or stay ambient | `design/PROP_SET_INTERACTION_MATRIX.md` |
| Where service-wire object facts and card sources live | `design/PROP_TRIVIA_RESEARCH.md`, then `game/data/prop_service_wire.json` |
| How the complete maintenance/case/dream-request loop is wired | `game/docs/core_loop.md` |
| How the bar works | `docs/harukiya_reference_notes.md` |
| How the karaoke/song system works | `docs/songbook_brief.md` |
| The machines in the bar | `game/docs/arcade_cabinets.md`, ruled in Bible §VIII.5.g |
| The proposed basement studio | `design/ORISON_STUDIO_BRIEF.md` *(proposal)* |
| The narcolepsy dream / the maze | `design/ORISON_MAZE_BRIEF.md` *(ruled production design)*, then `game/docs/dream_boundary.md` for the landed scene/save seam and `game/docs/dream_onset.md` for the protected onset owner |
| The ruled dream flora/fauna ecosystem and landed FA1–FA2 slices | `design/DREAM_FAUNA_BRIEF.md`, then `art/renders/dream_fauna_f1/README.md` and `art/renders/dream_fauna_fa2/README.md` |
| The six case-specific dream surface incarnations and AI-plate boundary | `design/SIX_INCARNATIONS.md` *(owner-directed plan; implementation review pending)* |
| Ruled waking-world vermin, birds and invasive flora | `design/ORISON_COMMENSALS_BRIEF.md` *(C1 landed; later breadth gated)* |
| The no-screen radio and attached work light in the player's hand | `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md`, `game/docs/service_set.md` *(ruled and landed)* |
| The HUD, telegram paper, type hierarchy and institutional world text | Bible §VIII.5.k, then `game/docs/telegram_style.md` *(ruled and landed)* |
| How sound moves through the building | `game/data/acoustic_graph.json`, `game/docs/sanity_system.md` |
| Why a texture tiles badly | `art/tools/ingest_material_sources.py`, and the compiler's `docs/provider-api.md` |
| What clothes people wear | `design/ORISON_WARDROBE_BIBLE.md` |
| What appliances exist | `design/ORISON_APPLIANCE_BIBLE.md` |
| How a household decorates | `design/resident_decor_profiles.json` *(brief, not loaded)* |

## The two repositories

| | |
|---|---|
| `C:\PleaseRemainOnTheLine` | this one. The game, the art pipeline, the design canon. Git-backed. |
| `C:\FPSengine01` | the **Semantic World Compiler**, which builds the machines in the bar. |

The compiler is a separate project that produces a build output consumed here
(`game/assets/arcade/`). It shares a *format* with this repo, not code. Its own
map is its `README.md`, and its cross-project contract is
`docs/orison-arcade.md`.

> **`C:\FPSengine01` is not a git repository.** Everything in it is unversioned
> files on disk. This is tracked as **H2** in `TASKS.md` and is the largest
> single risk on that list.

## Two names for the same thing

`arcade` is the **subsystem**; the **signal parlour** is the fiction. The code
says `arcade_*` throughout because that is the lineage it grew from; the world
says receivers and programme cards because the Bible rules it so (§VIII.5.g).
They agree. See the note in `game/docs/arcade_cabinets.md`.

## Three "status" documents, three jobs

They have collided before. They do not overlap:

`design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md` is not a fourth status ledger.
It defines product direction, milestone order and acceptance gates; it changes
only when the product plan changes.

- **`art/docs/photoreal_target.md`** — the eight-phase art roadmap and its
  per-phase assessment. Long-lived.
- **`TASKS.md`** — the live queue. One line per open task, anyone may add,
  deleted when done.
- **`HANDOFF.md`** — how to build and verify, and nothing else.

Do not duplicate status between them. Two copies of a status always disagree,
and the reader has no way to tell which one is lying.

## Adding a document

- **A rule** goes in the Bible as a dated ruling, not in a new file.
- **A proposal** goes in `design/` ending `_BRIEF.md`, and says at the top that
  it is not canon.
- **A task** goes in `TASKS.md` as one line. If it needs a paragraph, it needs a
  brief.
- **A subsystem explanation** goes in `game/docs/` or `art/docs/` next to the
  thing it explains.
- **Then add it to the table above**, or nobody will find it.

## Known gaps in the documentation itself

- The eleven shops, the archived phone OS and the case network have reference
  docs of uneven depth. The carried-device migration is recorded in
  `design/VANTRY_SERVICE_RADIOPHONE_BRIEF.md` and `game/docs/service_set.md`;
  the old phone documents are historical inputs, not production authority.
- `docs/harukiya_reference_notes.md` owes an asset manifest and an interaction
  manifest, deliberately unwritten so far.
- Bible §VI holds eight disputed texts awaiting a ruling. They are disputes, not
  oversights.
- An audit is not a queue. `AUDIT_UNUSED_SYSTEMS_REPORT.md` carries the evidence
  and its findings live in `TASKS.md` §U; if the two ever disagree, the audit is
  the older document and the queue is what is being worked.
