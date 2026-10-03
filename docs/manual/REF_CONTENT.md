# Reference: architecture and content

Evidence class: **INERT - REFERENCE**. Part of *The AI Studio Manual*, second edition (2026-10-03). Opened by section from the operating core, `AI_GAME_DEVELOPMENT_MANUAL.md` one directory up; never read front to back. Section numbers are permanent. Labels: **[M]** held on both source projects, **[C1]** / **[C2]** seen on one, **[X]** machinery for one project's scale.

Sections here: §11, §12, §13.1, §13.2, §13.7, §14.1, §14.3 to §14.11, §15, §16.1 to §16.5, §18. Retired to `CASES.md`: §13.3 to §13.6 (the 3D chain, PBR ingest, cross-repository generators), §14.2 (services by medium, now a dated table per project), the old §13.7 (prototypes) and the old §16 list where it was specific to one 3D game.

## §11 Architecture doctrines

1. **One owner per fact [M].** Before writing a system, write its row: owner, owns, does not own. Every durable fact lives in exactly one subtree of one save document, and exactly one script may write it. Enforce ownership with an API that returns false outside its whitelist, not with a review rule. Derived quantities are computed from the one place the fact is set.
2. **Coordinators connect; owners rule.** A director listens at authoritative signals and makes legal calls on owners' public APIs; it owns none of the rules it connects. State machines reject illegal transitions without mutation or signal. Wait on the physical state, not the request, and make every routing failure loud and countable.
3. **Presentation never owns state.** A save is a versioned fact store, not a scene snapshot. Prose, prompts, HUD, animation and input locks are derived after load. Give every modal one owner that acquires and releases input and focus exactly once.
4. **The simulation's only output is a snapshot [C2]** shaped as the network would send it (§16.1). Views and bots consume it and decide nothing. A play-mode selector exists from day one, defaults to local, and warns when asked for a mode not yet built.
5. **Save boundaries [C1].** One document with a version; every domain mutation ends with a commit (write first, then emit); a future-version file is refused read-only, never merged; storage is crash-recoverable; production code never calls a wall-clock API.
6. **Data-driven construction with a reader gate [M].** Adding a fourth case is a dictionary, not a class. Runtime classes are chosen by kind strings (§9.3, §12).
7. **Content kinds as modules [C2].** Scar: adding one dungeon kind meant edits across the generator, interaction, navigation, checksum, snapshot, views, bots and suites, and the simulation file reached 2,095 lines. Give each content kind one module that declares its hooks and its own marker names, registered in one table; the simulation stays the one authority and dispatches by kind.
8. **Optional systems fail closed in production [C2].** Injecting each rule system as an optional object keeps tests small; a shipped data file that fails to load must stop the game with its reason. Scar: a missing combat file would have silently switched combat off.
9. **Authoring, runtime and proof projections [C1].** Complete authoring sources are projected by one tool into runtime data and into a test-proof file; a check mode refuses stale outputs; a change made only in a generated output is lost by design. Identify the writer of every file before editing it.
10. **Deterministic generators with hash-bound outputs [M].** Seeded randomness; per-id choices from a stable checksum, never a salted hash; generators validate their construction and refuse to write; imported and runtime invariants are proved after assembly. Stamp the input revision into generated artifacts, because a stale build tests green.
11. **World units are separate from canvas density [C2]** (§10.5).
12. **Selector with rollback [M]** (§7.9). One non-persistent authority maps ids to scenes, reads one override and falls back to a default with one warning. Cutover and rollback change only the default.
13. **Derive state from authored facts through one owner query**, never from a proxy that happens to correlate: a height test once classified a roof as indoors. Rule every shared frame (axis, origin, epoch, id namespace) in writing before the second author, and name the datum in the same expression as the offset.
14. **Every implementing script's header points back at its authority:** the covenant or specification section it serves, and what it does not own. The pointer from document to code then runs both ways.
15. **Add states, tasks and interfaces only when an observed instance demands them.** Default every interaction to its smallest satisfying mechanism; do not build systems nobody can feel. Two beginnings that reach one state are one system: do not build two.

## §12 The data layer

- **Draw the data line on day one.** Every number a designer would tune or a player could feel lives in data, with one reader. Structural constants that only new code could change stay in code, with a comment saying why.
- **A minimal header [C2]** names the design document the file serves and which containers are identity maps (§21.9). Add a schema version or per-field descriptions only when a second reader or a migration needs them. A richer header [C1] adds: the edit rule ("edit this file and the document together"); the file's kind (hand transcription, generated projection, research copy-book); expected record counts; and tentative flags instead of deletion (proposed, enabled false).
- **One strict loader per file** validates shape and vocabulary, refuses bad data with a reason, and exposes typed accessors. Tests assert the reason's prefix. Fields are read by string-literal key (§9.3).
- When a brief asks for a config file before its reader exists, keep the numbers in the covenant until the reader lands.
- **Ask whether a table is derivable before authoring it;** author the query, not the table. State the minimum population at which a share or balance system becomes observable, and assert it.
- **When data has no reader, search the intended consumer for a hardcoded copy before deleting the file,** and make the code read the data. Audit the file the shipped program actually opens, not its twin. Two copies of a file without a diff tool drifted within nine days. A README asserting consumption is not consumption: one data file's own comment claimed seven readers, and it had none.

## §13.1 The art chain

**The 2D chain that was proven [C2]:** hand-written text sources for maps, compiled by a Python tool that validates and refuses to write on any finding; navigation built from the map data and checked for zero unreachable routes; generated sheets ingested deterministically (§14.5); a recorded patch layer (§13.2). One day took it from the first prompt to quilted, touched-up art.

**The invariant behind both chains [M]:** one script authors a semantic model, every downstream tool reads it, validation lives in the generator and only grows, and the same inputs give the same bytes. P1's 3D chain (a Python layout authority, a DCC build, the engine assembling the export) is in `CASES.md`.

## §13.2 Rules that transfer

- **Generated output is never edited in place.** Touch-ups are a recorded patch layer that the ingest applies over the untouched source; each patch file is hashed in the ingest record and undone by deleting it. Per-frame anchor points and quilting recipes use the same mechanism.
- A closed catalogue: materials, tiles or palettes go through one catalogue with a bridge file validated in both directions; an unmapped key fails the build. **But pin the shared palette after the owner rules on the look [C2]**, not before the first ingest; until then quantise each sheet to its own colour budget.
- Choose canvas density from the art source, not from an era's hardware.
- Names carry engine semantics (collision, visibility), so a name is a contract.
- Verification is a render or a measurement, never a code read.
- **Lettering.** With a NEVER block in every prompt, sheets came back clean [C2]; unasked marks crept in where the subject invites them (a tick on a clock face, a badge, a banner) and in the studio's own patches (a hand-drawn emblem read as a letter). Check every emblem for reading as a letter or a symbol.
- Keep an inspection scene under flat light that photographs every asset family for review, and record instrument findings separately from content critiques.
- Exchange generated assets between repositories as sealed archives with a hash the consumer re-verifies.

## §13.7 The review stage, and the move into the game

- **Review before import.** A test-only scene subclasses the views and loads ingested sheets from outside the project's resources. Nothing is imported or shipped before the owner rules. Under an engine hold, a contact sheet composed by script stands in, labelled a preview and not the game's render.
- **Plan the step after:** the ruling on the look; the ledger entries; the ruled sheets moved into the game with their readers; the placeholder drawing removed. Left unplanned, the game still draws placeholders.
- **Track import settings when art moves in.** The pixel-art contract (nearest filter, no mipmaps, lossless) lives in import settings; commit each texture's import file with those settings and review it.
- A new source takes its slot only if it beats the incumbent, in the engine, against reference.

## §14.1 The loop [M]

No generator is called from code for shipped art. You write prompt sheets as design documents; the owner runs consumer tools on the owner's own account; originals are never edited or committed; a deterministic ingest makes the game's files; the owner judges a render; the ruling is filed verbatim. Owner-found defects become tools.

- **The owner's part is one paste and one drop [C2].** Each prompt is whole and ready to paste, with no blanks to fill. You match each arriving file to its message, asking only when you cannot tell; pin it by SHA-256 in a committed manifest; and write the provenance record from the prompt sheet, the file's name and hash and the owner's message (§21.19). Fields only the owner knows (the model name as shown, the plan, the terms) are UNKNOWN and asked once per round, by form. A filename contract is a convenience; the manifest is the contract.
- Before the first file arrives, add an ignore rule for the folder the owner will save into. Hash every original the first time it is read, and ask the owner to keep a copy: P2's first round of originals is gone, unhashed.
- **A chat is the consistency instrument.** Keep one standing chat for tiles and one for characters and props. Send each message after the previous image has arrived, each telling the generator to keep the art-pixel size of a figure drawn earlier in the chat. Generators throttle bursts; send a few at a sitting.
- **Each round is a new dated sheet** that opens with what the last round returned and what changes because of it. A design change is re-prompted as the earlier message word for word plus one sentence. Under each message a "For:" line names the view function or data key that will read each cell.
- **Ask for the look ruling explicitly,** as its own form question: ship, ship with changes, not yet.

## §14.3 Prompt disciplines

General [M]: every prompt is self-contained; it opens with the medium; format first, detail last; positives over negatives, except the one cheap unambiguous negative; every sheet has a "what not to generate" section; for characters, an invariant preamble and tail with only the body varying.

For pixel art [C2]:
- **Size.** Never require a canvas size or an art-pixel size. The tools drew at two to three and a half times the requested density, each sheet at its own scale. Give sizes relative to a figure already drawn in the same chat.
- **Twice size.** Ask for art at twice its game size on purpose, with every outline two art pixels thick and no detail thinner; it halves to a crisp line.
- **Background.** One flat, pure key colour in every cell; no second colour, gradient or shadow; no sprite using it or anything near it. The tools return no alpha, so the key is the only transparency there is.
- **Grid.** An invisible grid of equal square cells, never drawn. Each sprite sits alone in the middle of its cell, feet on one line; each tile fills its cell edge to edge. Expect frames wider than their cell anyway.
- **Effects.** Whitelist them: none unless named. Generators add genre defaults (motion arcs, impact stars, a held weapon); every default that contradicts the design needs its own sentence. Tell modular parts what they must not carry.
- **Tiles.** Ask by role: floor variants, a wall's face, its top running one way, its top joining every way, gates open and shut. A wall's top and face are separate tiles.
- **Silhouette contract.** "No two share a silhouette"; tiers keep the first one's silhouette and add one accent of shape.
- **NEVER block.** No text, letters, numbers, runes, logos, signatures or watermarks. Describe every dial as plain, with no numerals or marks.
- **Names.** Name no existing work, studio, artist or character, and no era-and-genre style label: such a label can pull toward the dominant franchise as a name does.
- **Risk.** Send risky prompts as a ladder, safest first (§14.10).

## §14.4 The measured round of style

Before the first full set, send four representative prompts (a tile sheet, one character's frames, a part sheet, an enemy) once each to two generators, and measure the results in a table: canvas and format; art-pixel size against the size asked; background; grid lines; view angle; consistency between frames; anything drawn that was not asked for. Keep the generator that returns lossless images on a flat key colour without drawn grid lines. The table is the research dossier: rewrite the prompt sheet from it the same day. Measure again whenever the service's model changes.

## §14.5 The pixel ingest [C2]

About 750 lines of standard-library Python, deterministic: the same sources make the same bytes.

- **Sources.** Check every source against the SHA-256 its manifest pins. Refuse lossy formats: they smear the key colour into the art. A missing, unreadable or wrong file exits nonzero with nothing written.
- **Cells.** Cut cells on fractional bounds, because the generator's canvas rarely divides evenly.
- **Reduction by counting.** Each game pixel takes the most common colour among the generator pixels under it, in coarse colour buckets. The dark outline wins where it covers a set share (about a third; about half for faces, so eyes survive). The key colour wins, and becomes transparent, where it covers half. A dark key-hued pixel within two source pixels of the background is fringe, never colour or outline.
- **Palette.** Quantise each sheet to its colour budget by weighted median cut.
- **Placement.** Place each frame by its feet on a per-sheet anchor. A small piece touching a cell's edge belongs to a neighbour and is dropped in that cell only.
- **Scale.** Scale each sheet from one reference object whose game size is known, or from a step measured on another sheet of the same drawing.
- **Team colours.** Map a prompted grey ramp onto each team's colour ramp.

## §14.6 Tiles that tile [C2]

No prompt wording produced pixel tiles that tile, and one tile laid across a floor showed its grid. Quilt at the ingest instead: build wrapping textures from a sheet's named cells, laying patches three quarters of a tile wide every half tile; choose each patch from the closest-matching windows, by a seed of the sheet's and texture's names, weighted so plain tiles make up most of a floor; cut each patch along the path of least difference through the overlap; let the far edges overlap the near ones so the texture wraps. Every pixel is one the generator drew. Record cells, weights, length and seed. Do not crossfade pixel art: blending invents colours outside the palette and blurs the grid. Build test fixtures that carry the generator's faults: two breakages got past synthetic fixtures and were caught only in renders.

## §14.7 Characters from parts [C2]

A shared headless body in three greys, a head overlay per team, and team colour as palette variants kept the frame budget flat, at the cost of several review cycles: heads drawn at a different scale from the body, heads that brought their own collar, a measured anchor fooled by a raised arm. Keep a hashed frame-points file for anchor positions wherever measurement fails, and settle how a part sits by composing every team and facing at three settings and choosing by eye.

## §14.8 Key art [C2]

Paint it; generated pixel art turns to mush when enlarged. Lay it out by percentages, and give check guides in the generator's own pixels: the quiet strip, the margins, each crop, the clear space for type. Send the textless plate first and add lettering as a follow-up in the same chat. Attach no reference images by default: references carry whatever likeness they hold. Re-roll one fix at a time, in a stated removal order. For print, upscale a derived copy, set the title as real type, and proof in the print colour space.

## §14.9 Likeness review [C2]

- A prompt that named nothing was still withheld for similarity to third-party content: genre-standard costume on the shared body plus one team in a famous hero's signature colours was the likeliest cause (inferred from the prompt; the picture was never shown). A later painted take showed two more designs reading as famous characters, which the small sprites had hidden. The owner ruled them changed at the source.
- **Describe each character by silhouette, costume, palette and signature prop in the world brief, and review those against the genre's best-known characters before the first prompt.** Review again at high resolution with three readers: one checks the take against its sheet, one names what each figure resembles, one checks print and crop.
- **A likeness found in any picture is a likeness in the design:** fix the brief and every prompt that draws from it, and search the sheets already ingested for the same trait.

## §14.10 Refusals [C2]

Generators refuse for reasons unrelated to what was asked: a comic song was refused as political or religious; a looped rope was read as something darker. File a refusal's words verbatim and list the likeliest triggers: topic words, likeness, named styles. Send prompts as a ladder, safest first, so the step before a refusal names its cause, and give each risky line a named fallback. Before sending, have a reviewer act as a cautious content filter and estimate acceptance. Answer every refusal by changing what the piece says or shows, never by putting the same content into other words to get it past the filter. **A similarity refusal is an IP finding, never an obstacle to rephrase around.**

## §14.11 Music

- **Prompt shape [C2].** Lyrics under a "Lyrics:" header with section tags; anything in parentheses is sung as a backing vocal, so stage directions go in the description, with tempo set to the game's beat, metre, key, feel, instruments and who sings each line. P1's tiers: NON-NEGOTIABLE, DESIRABLE, EXPENDABLE, with targeted correction prompts for the common failures.
- **Measure before a human listens [M].** For every returned track: length, tempo, integrated loudness, the timestamps of the requested structure, its SHA-256 and the name the generator gave it. Two P1 candidates arrived in the wrong metre, and measurement caught them. Pin the measuring binaries and keep a receipt. Never commit the track.
- **Confirm the model piece before drafting** (core A3.9): offer the likeliest two or three, and ask for its address. **Rhyme the shape, never the sound:** a fanfare in the key of a famous one was moved to another key.
- Research on a copyrighted song may be blocked by a content filter; check originality by shape (no refrain, sentiment, melody or feel taken) and record that the research was blocked.

## §15 Audio and licensing

- **§15.1 Provenance routes.** (1) Recorded ambience and effects under CC0 or CC BY only: masters ignored and re-downloadable, processed derivatives committed, each in an attribution manifest (title, contributor, address, licence); non-commercial files are excluded and never referenced. (2) Music generated by the owner, with a manifest per track (model, date, disclosure, legal status) and masters pinned by hash, kept out of the shipped tree until the rights fields are filled. (3) Placeholders, labelled as placeholders in their filenames. (4) Public-domain music under guardrails written before the first piece: the composer died more than a century ago; the arrangement works only from a public-domain score, never a recording or modern edition; no piece a referenced film used. (5) **Sound synthesised by the game's own code from data recipes [C2]:** each sound a sequence of parts (wave, start and end pitch, duration, level), a short attack so parts do not click, everything rendered once at a fixed sample rate, noise from a fixed shift register. It needs no licence entry, its bytes are deterministic, and the view plays it from snapshot counters, never the simulation. A missing recorded key produces silence and a warning, never a test tone.
- **§15.2 Audio as gameplay.** Sound tells the player what acted, where, whether it took and what deserves attention next; silence is part of the language. Callers decide what happened; the audio owner only resolves bus, voice, priority, cooldown and diagnostics. **Scale it to the slice [C2]:** about twenty effects needed one rule for what you hear and a fixed low volume. The bus tree as data, a bounded voice pool with priorities, cooldowns and a refusal log, composed mix states, and captions as accessibility parity [C1] can wait for ambience and music. Every loudness or masking claim is a hypothesis until a human listening run.
- **§15.3 The rights chain is mechanised [C1].** A notices generator reads exactly the in-tree licence sources, fails if any is missing or lacks its expected text, and re-verifies what it wrote. The packager requires an owner-supplied licence and refuses to invent one. Clear every composition with dated evidence per work, and never depict or imply a real person without their own words.
- **§15.4 The provenance register.** You write it at ingest (§14.1). Before any tester build, the licence, creative-provenance and privacy audits each carry a stop rule: missing evidence is UNKNOWN or BLOCK, never permission.

## §16.1 The fixed-step simulation [C2]

- One simulation object holds every gameplay fact. One driver node advances it exactly one tick per physics frame; it never reads the frame's delta, and it reports an engine error if the physics rate differs from the simulation's.
- Positions are integer sub-pixels. A speed that does not divide evenly becomes a fixed cycle of integer steps keyed to the tick number (strides of 51, 51, 51, 51 and 52 sixteenths walk one 16-pixel tile in five ticks, from any starting phase).
- Before each tick the host asks every seat, in seat order, for its input record for that tick: tick, quantised move, button bits, facing. A record stamped for another tick is refused, and the body stands still.
- A static gate forbids wall clocks anywhere in production code. Inside the simulation it also forbids frame callbacks, timers, tweens, delta and the engine's global random generator.
- Each decision stream has its own random generator, seeded from a stable checksum of a name, not the engine's string hash, so adding a draw to one stream never shifts another.
- Bodies step through an explicit ordered list of ids. Dictionary keys are sorted before being iterated for state or hashing. Integer division truncates toward zero: floor explicitly where offsets can be negative.
- A 32-bit checksum covers all state.

## §16.2 Its tests

The same match played twice ends on the same tick with the same checksum. A simulation driven by the tick driver equals a twin stepped directly. Twins that differ in one input agree until that tick and differ after it, never before. Every new state field changes the checksum: generate checksum and snapshot from one field list, or make that test part of every feature's suite (P2 hand-listed both, complete only by convention). Whole matches with a bot in every seat run headless as fast as the machine allows, and a timed suite measures the tick with a full lobby. The genre's trap signals are measured in the same match and printed with their thresholds.

## §16.3 Bots

- **Same input path, honest perception.** Until each seat receives a filtered snapshot, restraint is only a convention; prove it by changing state the seat cannot perceive and asserting the bot's inputs are identical tick for tick.
- **Published rules.** Every behaviour is a rule a player could read; every skill is a number in data; every bot is seeded from a stable checksum of its name. Measure published probabilities over a run and print them beside the published value (73 of 90 against a published 75 in 100).
- **Co-operation through existing verbs.** Standing still asks for help; standing on a plate holds it. A bot therefore reads a person exactly as it reads a bot. Every wait on a partner has a published patience, after which the bot does the job alone or routes round it. Test pairs for livelock: one design's first roles would have made two bots loop forever.
- **Co-operative laws as measures.** "Solvable alone, quickest together" became: two bots take at least a quarter fewer ticks in total over many crossings, and are slower than one in no more than one crossing in twelve. When an owner idea assumes two players, add the smallest mechanic that lets one finish slowly, and report it as a default.
- **The owner's rules as whole-match assertions:** a crew earns its kit and defeats the boss without touching another crew; the boss falls without a single combo.
- A beat bots cannot yet reach unscripted is captured from a labelled staged scene, and the missing behaviour is listed.

## §16.4 Runtime procedural generation and rotating content [C2]

- **A generator is a pure function of its seed and data.** Before its output is used it is walked: every start reaches every goal and nothing is shut in for good. A failing seed is refused and the next one tried, within a tries limit kept in data.
- **A retry is not a refusal.** In an engine whose runtime errors return a default and carry on, a "try the next seed" loop turns a crash into a silent skip: 9 of 400 seeds crashed and were passed over. The generator returns an explicit refusal reason, refusals are counted by reason, and any engine error line fails the run. Sweep hundreds of seeds; sweeps of 20 and 40 never hit the crash.
- **Pin a digest of each swept seed's output,** so a fix shows exactly which layouts it changed and one stray random draw turns the check red on every seed.
- **Fairness by rotation:** for a competitive map, generate one part and rotate it into the others, and validate the partners and equal walking time.
- **Rotate content with a random stream of its own,** one stream per concern (layout, kinds, loot), so growing a pool does not reshuffle layouts. Tests pin the kinds they need.
- **Design the generator and the tile set together:** a small fixed set of tiles in the same cells on every area's sheet, so one ingest layout serves every biome.

## §16.5 Ambient-world patterns [C1; optional]

From one 3D game with a simulated population. Use what your game needs.

- **One durable clock, one writer:** an authored date plus elapsed minutes that accumulate and are saved; everything else reads it.
- **Timetables authored from character, not gameplay need,** resolved deterministically. Temperament tables exist because everyone once made the same hard-coded decision and the building emptied in unison.
- **Navigation from the layout data, not a baked mesh:** the generator is the authority on where walking is legal; derive every navigation point from authored geometry; test routes leg by leg with the actor's real shape; a route that would cross a wall returns the start point, so a harness can assert zero unreachable routes. P2 built the same pattern.
- **One environment writer:** exactly one node writes absolute values into the environment; everything else supplies gains.
- **Simulation tiers:** rendering and simulation are bucketed separately (dormant, statistical, scheduled, embodied), and every advance is a pure function of facts and elapsed time, so promotion and demotion are lossless. No tell, no variable: every simulated quantity needs a sensory tell.
- **Invisible systems must be testable:** expose state and a force call to tests and the debug panel only. Measure before redesigning: one audit found 54 percent of authored events unreachable. When an audit changes a tuned constant, keep the old value and the audit's path in the code comment.
- **The world is borrowed, not damaged:** a presentation effect snapshots what it touches and restores it on an unconditional timer; a safety net returns the player to the last valid floor.
- **Would you do it twice, for no reward?** Test an interaction for resistance then release, discrete states with a commit, sound as the reward, immediate reversibility, optional consequence, a visible mechanism. Census the interactables and rule each family into one disposition (operate, inspect, refuse, ambient); do not manufacture interactions to improve a percentage. Put the affordance guard in the base class, and make every refusal visible and explained.
- **Privacy-first live data:** network off by default; a failed request leaves the authored default intact; parsing and presentation are static functions tested on hand-built data.

## §18 Sourcing

- **Checklist before anything external is used:** the source and licence policy exists; the folder it lands in is ignored; the terms address and product tier are recorded at first use; the provenance family is chosen; the census is updated in the same commit.
- **A dated table per project** (medium, service and version or tier, terms address, what it produced, what it refused, kept or not), filled at first use. Both projects' tables are in `CASES.md`; treat them as dated case data, not recommendations.
- **The census of sources is a current record:** what is used and, dated, what is not. A gate fails when a prompt sheet, ingest manifest or requirements file names a source the census lists as unused. Scar [C2]: the census still said no generator had been run after three had.
- **The licence ledger:** one machine-checkable file from the first asset; every shipped path matches exactly one provenance family (original; generated, with manifest; licensed, with attribution; public domain, with citation; reference only, never shipped); UNKNOWN plus ships fails the package. It stays empty until something generated enters the game, so plan that move (§13.7).
- **Reference material [M]:** cite by address with an as-of date; label documented, inferred or authored; paraphrase to fact, never copy text or images; fetch reference photographs only from sources with machine-readable licences; reference images inform form only and are never baked, projected or committed; keep copyrighted references out of the repository entirely.
- Keep the no-addons default; if a dependency is adopted, add its licence to the notices the same day, and file rejected-dependency decisions in the tree.
