# Case files, figures and the first-edition map

Evidence class: **INERT - REFERENCE**. Part of *The AI Studio Manual*, second edition (2026-10-03). Opened by section from the operating core, `AI_GAME_DEVELOPMENT_MANUAL.md` one directory up. Everything here is one project's experience: weigh it, do not copy it. Paths and names in this file belong to the source projects, not to yours.

Sections here: §1 (the two projects), §19 (rules for a 3D game; how the first edition's rules fared), §24 (what a solo project used), §25 (open debt), §26 (how this manual was derived), §27 (the first-edition map).

## §1 The two source projects

### P1: a first-person 3D horror game, two agents, seven months

- **The game.** *Please Remain On The Line*: a 1928 apartment block where sound moves through the building's wiring; the player is a night-shift maintenance tenant. A procedural building, eighteen simulated residents. Godot 4.7.1, Blender, Python.
- **The team.** One owner. One agent vendor as primary engineer from 2026-07-29; a second vendor's agent in the same tree from 2026-08-13, made executive under a written mandate on 2026-09-04, with the first acting as management and verifier. Both committed under the owner's identity.
- **Scale.** 1,374 commits from 2026-02-17 to 2026-09-21; about 83 verification tools; in August a median commit touched 5 files and about 200 lines, and 52 percent touched both code and a document.

| Phase | What happened | What it cost |
|---|---|---|
| Blockout burst, 07-29 to 07-31 | The 3D building, an audio prototype and the first loop landed in one session: 34 commits in a day | Add-all swept a screen recording and 33 scratch renders into history within 24 hours |
| Systems explosion, August (1,097 commits) | Materials, residents, cases, a dream world, weather, audio; the covenant (08-03), the queue (08-09), the map (08-10) | The runner reported exit 0 for every failing suite for 334 commits. Every audit tool arrived in one 72-hour burst of 22,848 lines, the week early access was chartered. One content sequence grew until a scope audit ranked it first under "stop building this now" |
| Rebuild beside the old world, 08-28 to 09-14 | A second building behind a selector; a completeness ledger; runtime-contract receipts; the reader gate | Hash-bound files broke on a fresh checkout because of autocrlf. A flattering count ("first slice 0 blockers") was repeated four times before a hardened tool showed 7 |
| Governance, 09-04 to 09-19 | Gate board, receipts, verifier, lane broker, doc lint and rulings index, most of them in one day | Two lines both believed they were canonical and diverged into a 26-file conflict; 2,081 uncommitted files had to be rescued from the main checkout |
| Consolidation and cutover, 09-19 to 09-21 | 34 worktrees became 1; the rebuilt world became the default in three small commits with a rollback switch | About 40 GB of archives; retired instruments left standing |

- **The three scars that most shaped the manual.** The exit-0 runner (prove the red). Five add-all incidents (stage named paths). A ledger that read prose, so a bug report promoted the room it reported (evidence by filename). Behind all three: every instrument was built after the loss it prevents.
- **What it would do differently.** Build the instruments on day zero, in standard-library Python rather than a shell language. One integration line from the first hour a second agent joins. Run the scope audit on events. Pin every tool in a requirements file. Record the terms of every service at first use.
- **As of 2026-09-21** no human had completed its run card and no tester had received a build; five scoped human acceptances existed. The instruments were built before the audience arrived, which is the right order, and a warning that instruments are not the game.

**P1's 3D practices [C1].**
- *The chain:* Python authors a semantic model (one layout script, 10,984 lines, refusing to write until about twenty validators pass); the DCC tool builds deterministic geometry from it; the engine assembles the export; audio, props and navigation read the same coordinates. Nothing is generated at runtime.
- *Props and characters:* props began as parametric assemblies in script and were regenerated in the DCC tool as named-part exports, with photographed critiques as the specification and scripts keeping every non-visual authority. Characters came from an AI 3D service, converted by scripts that strip baked emission, grade colour, decimate to a measured budget and bake a shared gesture library. One active model per character; no scaling after export.
- *Patching an exported asset from Python*, for a bounded edit or when the DCC tool is unavailable: hash inputs before and after; rebuild once to prove idempotence; assert the original arrays are an untouched prefix and the buffer length equals the file size; add negative controls that must fail; label every preview "not a render". Never for new organic modelling.
- *The PBR texture ingest:* unblend generator watermarks on the sources; flatten baked lighting before tiling; seamless crossfade; derive height and normals; anchor colour per slot; refuse plates with baked illumination. None of it transfers to pixel art (§14.5, §14.6).
- *A generator in another repository* hands over hashed, proven outputs through a documented contract; the game ports the runtime as a prefixed copy, never a submodule, and asserts one fingerprint across all packages. That generator was not under version control, the largest single risk on the queue.
- *Prototypes:* the first idea was a zero-asset standalone project with its own headless test, later filed in the tree as legacy with "this is not the live game" in its README.
- *Capture budget:* a 60-second ceiling; a 54-second internal budget; focused boot 18 seconds, full production boot about 33; 0.35 seconds a frame; 18 frames a shard.

**P1's services, as of 2026-09-25 (dated case data, not recommendations).**

| Medium | Service | Note |
|---|---|---|
| Engineering | Claude Code; OpenAI Codex | Trailers on every commit; a decision log in the tree for the second agent |
| Images, textures | Gemini image generation; ChatGPT image tool; one open model through a public demo space | 277 raw sources tracked and never shipped; terms at generation time unrecorded |
| 3D characters, animation | Meshy | Raw exports ignored and re-downloadable; tier and terms unrecorded |
| Music | Gemini app (Lyria), from public-domain scores | 36 tracks; rights fields still unfilled, so audition-only |
| Video | Sora | A watermark visible at close range; a dated decision with a revisit condition |
| Voice | Offline text-to-speech placeholders | Discarded by ruling; the game ships unvoiced |
| Engine and tools | Godot 4.7.1; Blender 5.2; ffmpeg 7.1 pinned by path; gdtoolkit 4.5; Pillow; NumPy | Blender's version was stated inconsistently; no requirements file |
| Recorded audio | Freesound: 7 CC0 and 8 CC BY recordings; 3 non-commercial ones excluded | Attribution manifest; masters ignored |
| Font | Courier Prime (OFL) | Licence text beside the font; the notices generator fails without it |
| Reference photographs | Wikimedia Commons only, licence-filtered | Form only; bytes never committed |
| Platforms | GitHub; itch.io and Steam planned; Open-Meteo for optional live weather | No account created by an agent; weather off by default |

A dated search found no use of the other common generators, asset libraries or editors. One legacy violation stands: copyrighted reference images committed in a pre-engine sibling prototype, to be purged from history before any public release.

### P2: a 2D top-down team action game, one agent, eight days

- **The game.** *Hushbreakers*: a team action game in the genre homage its owner's sentence asked for, single-player against bots first. Godot 4.7.1 on Windows 11. One agent, one long session, one owner. It followed the first edition through a 652-line condensation made on day zero and a 505-line build brief written by another model.
- **Its figures are as its notes of 2026-10-03 report them;** they were not re-measured for this edition.

| Figure | Value |
|---|---|
| Commits | 202 on the main line, 15 on one side branch; per day 59, 57, 41, 0, 18, 22, 4, 1; no merges |
| Owner messages | 76; seventeen decisions filed on day zero; no licence sentence; one play; two answered forms |
| Day zero to the first gate | about seven hours, twelve instruments |
| The slice | about forty hours; 16 of 18 rows closed by receipt; two owner rows never closed |
| The owner's first play | about 51 hours after day zero |
| Scope-widening directions | four, in two days |
| Engine hold | from 2026-10-01 onward |
| Code | production script about 9,600 lines; engine tests about 14,700 lines, 39 suites, 482 checks; Python tools about 5,800 lines plus 4,300 of tests |
| Documents | about 17,400 lines of project Markdown; the must-read set about 300 KB (pickup 1,501 lines, build guide 1,222, covenant 897); 24 of 52 design documents missing from the map |
| Evidence | 1,193 run receipts; 95 percent of inserted lines; 92 of 95.5 MB tracked |
| Bookkeeping | 101 of 202 commits changed only bookkeeping files |
| Board time | 48.9 seconds on day zero; about 421 by the end; the battery 10 to 16 seconds at first, 188 later |
| First-edition sections its tree cites | §4, §4.1, §8.9, §9.1, §9.3, §10.1, §10.4, §17.2, §17.3, §21.10 and no others |

| Step | What happened |
|---|---|
| Day zero | Covenant, records and day-one instruments proved red, in seven hours. A history rewrite the same day: handed documents, and the first edition's own worked example, had put third-party marks into the first commit |
| The first answer | Ninety minutes later it replaced the game's goal; the covenant was amended eleven times that day |
| The slice | A complete match against bots in forty hours, every beat with receipts |
| The first play | Two days in: a defect no suite had caught, and combat too fast to react to |
| Widening, then a hold | Four directions widened the scope in two days; then the owner held every engine run, and the agent wrote specifications and code ahead on a branch |

- **The three scars that most shaped this edition.** Half of all commits were bookkeeping and the must-read documents reached 300 KB. The scope audit, dated a month out by a condensation, never ran while scope widened and two owner rows stayed open. The IP boundary was not clean before the first commit, and later reached from names to likeness.
- **What it would do differently.** Its ten headline lessons are the structure of this edition: a short core read in full; every rule held by an instrument; plans by events; a solo loop an agent will actually run; an owner protocol built on forms and play; one fixed-step simulation with bots on the input path; evidence that is cheap and current; a machine-wide lane and an engine-hold procedure; marks quarantined before the first commit; a measured 2D generative pipeline.

**P2's services, 2026-09-30 to 10-02 (dated case data).** Measure again whenever a service's model changes.

| Medium | Service and what it returned | Kept |
|---|---|---|
| Sprites and tiles | ChatGPT image generation: a 1254 by 1254 PNG for every sheet, whatever size was asked; kept a flat key colour | Yes |
| Sprites, one round | Gemini image generation: 2048 by 2048 JPEG, backgrounds varying cell to cell, grid lines drawn | No |
| Key art | ChatGPT image generation, landscape, painted style, no reference images attached | Yes; one take withheld for similarity |
| Music | Gemini (Lyria): tracks of about a minute | Yes; never committed |
| Measurement | the machine's own ffprobe and ffmpeg, unpinned | Should be pinned |
| Script syntax check | gdparse from gdtoolkit 4.5.0, installed by the owner's ruling | Yes |
| Sound effects | synthesised in the game (§15.1) | Yes |

## §19 Rules that belong to one kind of game

The rules index is in the core (A14). These are P1's rules for a 3D game [C1].

- A centreline is not a face: four repeats in one day.
- Merged storey meshes hand the per-object light cap to an arbitrary subset: corridors went black while their lamps glowed.
- Depth fog density is a ceiling, not a rate: at 0.86 every distant surface kept 14 percent contrast forever.
- One material per buffer: the DCC export merges by material, and a finish emitted with one winding per orientation back-face-culled from its own room.
- Lamp, then freeze; aim before physics goes off; measure the wall first. Four proof-sheet re-shoots.
- A model ships and renders exactly as exported; baked scaling lost twice to unit normalisation.
- Generator watermarks roll onto every tile through a seamless crossfade and into every derived map: measure and unblend them on the sources.
- Represent distant or numerous glows as emissive geometry, never as real lights. Shadow casters are a budget separate from lights; a new fixture ships with shadows off and earns a slot.
- Budget the binding constraint: 173,000 extra triangles cost 0.1 ms; the texture maps would not fit a phone. Measure draw submissions for any effect and record the rejected alternatives with their numbers.
- Judge materials by sampling pixel values against neighbours in a real render, and fix physically, not with brightness. Classify every material as tiling or composition at ingest; rotate only grainless ones. Divide out low-frequency lighting before any seamless pass.
- Measure the precision of any per-instance data channel on the target renderer before packing data into it: only the high byte survived.
- The mobile renderer caps lights per object and lacks several effects; a shader material costs more on it.
- A queued positional playback survives a stop before its first physics update: free the voice and remake it.
- Index a corruption or variant catalogue by the thing varied, with a loader that refuses any entry lacking its ordinary counterpart: a selector keyed on a field most rooms lacked could only ever affect six.
- Give each uncanny entity one rule-breaking property, and test for restraint.

**How the first edition's rules fared on P2.**

| First-edition rule | On P2 |
|---|---|
| A write is not a use | Confirmed: the reader gate stayed at zero. Extended to evidence nobody reads |
| Prove the red; a flaky test is worse than a failing one | Confirmed and extended (§8.9); the one flake was the runner able to kill a stranger's process tree |
| Run the null experiment and publish the noise floor | Superseded where captures are deterministic: the floor is zero by measurement |
| Verification machinery arrives the week the audience becomes external | Reversed: built on day zero in seven hours |
| A worktree isolates files, not the machine | Confirmed and widened: the machine was shared across projects |
| Import twice | Contradicted for scripts that reach each other by path (§10.4) |
| The engine rewrites id files' line endings | Not seen; most likely autocrlf |
| Lettering is the most-broken rule | Changed: clean with a NEVER block, except where the subject invites lettering |
| Run the scope audit early and after every new sequence | Right, and ignored, because a checklist and a condensation had cut it to a date |
| Skip the lane broker with one agent; CI always | Both wrong at this size: the lane was shared with another project, and CI is impossible without a remote |

## §24 What a solo owner and one agent on a small 2D game used

- **Always:** the covenant with numbered laws; the numbered owner-words log; the beat table and requirement rows; the runner with receipts; the board before every commit and a baseline after; the reader gate; a gate per ruling; the IP audit and the flash gate; the suite declaration with exact counts; the form-plus-play human gate; the machine-wide lane lock whenever anything else on the machine can start the engine.
- **When first needed:** the fresh-checkout verifier, on its schedule; the completeness ledger, after the second milestone; the rulings index, when a second authority exists or the covenant passes its budget; noise floors, only for nondeterministic captures.
- **Replaced:** production-contract documents, by one specification per system.
- **CI:** once the owner rules a remote.

## §25 Open debt

So the method is not presented as finished.

- **P1, as read on 2026-09-26:** no runtime-contract receipt had yet been produced by any test; no human had completed the run card and no tester had a build; retired backup scripts still contradicted the staging rule; runners and the lane broker were Windows-only shell scripts; no CI and no installed hooks; the reader-gate baseline was a frozen count, half of it the gate's own blind spot; a 10,516-line level toolchain had no caller; two precedence ladders coexisted; the terms in force for every generative service were unrecorded; owner decisions open since early August remained unruled.
- **P2, as read on 2026-10-03:** two owner rows never closed; the generated art's look never ruled, so the game drew placeholders; no licence sentence; the scope audit never run; the ordered labyrinth built but not wired; the verifier never run on a real candidate; nearly half the design documents missing from the map; an unexplained board transient; the cross-project lane race; engine evidence deferred under the hold, including a branch of fifteen unproven commits; network numbers pinned with nothing reading them; receipts cited by closed rows now stale; the battery not stopping after a failed import.
- **This manual:** the base suite script in §21.10 has not been run in the form printed; the breakage manifest, the owner's short run card, the provenance record and the lessons register are proposed and unexercised; no AI coder has built a game from an oracle prompt; tester builds, cohorts and release were planned on P1 and exercised on neither project; nothing here has been tried on a game that is not real-time.

## §26 How this manual was derived

- **First edition, 2026-09-26.** Twenty-five read-only reader passes over P1's repository at one commit, consolidated into registers of third-party sources and lessons, then written by one author. Every cited path, count and quotation was checked against the tree, and two independent critics' findings were applied. It ran to 3,209 lines, and to 3,406 with the oracle section added on 2026-10-03.
- **Second edition, 2026-10-03.** Rewritten from the first edition and from P2's notes for a second edition: 1,491 lines, written inside P2 by seven read-only readers, the developer's first-hand lessons and a critic (SHA-256 of the notes as received: `4fb10a7aeac4e1c1408764713655b32e74f1f0a6fa0b1407a629764dc1fa1e18`). P2's repository was not opened for this edition, on its notes' own advice, so nothing about P2 was re-measured here. The edition was cut to a core read in full and a reference opened by section, because P2's owner forbade reading the long manual front to back and its tree cited only ten of its sections.
- **Checked for this edition:** every section pointer in every file resolves (`check_manual.py`); the core is inside its word budget; no franchise, mark or project codename appears; the suite script passes a GDScript parser. No engine was run.
- **The first edition is not reproduced.** It remains in the source repository's history, in the pull request that introduced this manual. Its worked example names a franchise, so it must not be copied into another project.

## §27 Where first-edition sections went

| First edition | Second edition |
|---|---|
| §0 How to use; §22 Maintaining; §26 Derivation | core A1; §26 here |
| §1 The source project | §1 here |
| §2 Roles, §2.1 Precedence | core A2 |
| §2.2 Rulings index | §2.2 [X], deferred |
| §2.3 Dispatch, §2.4 Report format, §2.5 Reviews | §30; the solo report is the pickup block (core A6) |
| §2.6 One agent, one human | core A10 (the solo loop) |
| §3, §3.1, §3.3, §3.4, §3.5 Documents | core A6; §3.5 replaced by one specification per system (§21.17) |
| §3.2 Evidence-class header; §3.6 Directions; §3.7 Briefs | §3.2; §3.6 and core A3; §3.7 |
| §4 Shared tree; §4.1 Lane; §4.2 Machine setup | core A13; §4, §4.1, §4.2; new §4.3 (history rewrite), §4.4 (tool traps) |
| §5 to §5.7 Day zero | core A4; §5.1 and §5.6 kept as reference; new §5.8 (oracle prompt) |
| §6 to §6.7 The covenant | core A5; §6 |
| §7.1 to §7.5 Slice and planning | core A9, A3 |
| §7.6 to §7.10 | §7.6 to §7.10 |
| §8.1 to §8.9 Proof ladder | core A10, A7; §8.1, §8.3 to §8.6, §8.8, §8.9; §8.7 is now §28 |
| §9 to §9.7 Toolchain | core A7; §9 to §9.5, §9.7; new §9.8 (tooling policy), §9.9 (verifier) |
| §10.1 to §10.4 Engine harness | §10.1 to §10.4; new §10.5 (rendering) |
| §11 Architecture; §12 Data | core A11; §11, §12 |
| §13 Art pipeline | §13.1, §13.2, §13.7; the 3D chain is in §1 here |
| §14 Generative assets | core A11; §14.1, §14.3 to §14.11 |
| §15 Audio and licensing | §15 |
| §16 Simulation and environment patterns | core A8; §16.1 to §16.4; the ambient-world list is §16.5 |
| §17 Human acceptance | core A9; §17 |
| §18 The registry | §18; the tables are in §1 here |
| §19 Rules | stated once in their chapters; index in core A14; 3D rules in §19 here |
| §20 Worked example | §20, rewritten as an order of work with placeholders |
| §21 Templates | §21, revised; §21.8 retired to §30; §21.15 to §21.21 new |
| §23 Day-one checklist | core A4 |
| §24 Scaling down; §25 Open debt | §24 and §25 here |
| §27 Tool inventory | not reproduced; see §26 |
| new | §28 engine hold; §29 design panels; §30 a second agent |
