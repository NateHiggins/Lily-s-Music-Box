# Reference: evidence and instruments

Evidence class: **INERT - REFERENCE**. Part of *The AI Studio Manual*, second edition (2026-10-03). Opened by section from the operating core, `AI_GAME_DEVELOPMENT_MANUAL.md` one directory up; never read front to back. Section numbers are permanent. Labels: **[M]** held on both source projects, **[C1]** / **[C2]** seen on one, **[X]** machinery for one project's scale.

Sections here: §8.1, §8.3 to §8.6, §8.8, §8.9, §9 to §9.9. Retired: §8.2 (core A10), §8.7 (now §28), §9.6 (the report sidecar is the receipt committed with the change, §8.4).

## §8.1 The five tiers

| Tier | Artifact | Proves | Cannot prove |
|---|---|---|---|
| Static gate | a gate's exit code and named findings on the board | the source tree has no new finding of that class against the baseline | anything about runtime |
| Run receipt | written by the runner after any launched run | a process started and ended with this exit against this test script and this digest of runtime inputs | which contracts the test executed |
| Runtime contract | a receipt the test itself writes, with named contracts each executed and PASS, in the production composition | the declared contracts ran in the production runtime | beauty, usability, fear, clarity, comprehension |
| Capture packet | frames with per-frame SHA-256, the capture's declared settings, a control | frames rendered under a declared camera; a measured pixel difference | acceptance; execution; "it looks right" |
| Human acceptance | the owner's verdict naming the commit, the build or packet, the exact question, accepted debt and a scope boundary | a person accepted exactly that claim at exactly that commit | anything outside its recorded scope |

Universal contracts: **production composition** (the production scene assembled, with unique exercised identities) and **teardown** (the runner's scan for leak and still-in-use lines, plus measured node and orphan-node counts). **Save reconstruction** (saved facts rebuild the same state after reload) joins when a save exists; **premature-action denial** (an action attempted before its precondition is refused without mutation) joins when a precondition gate exists. Every other contract is named for the requirement row it closes.

## §8.3 Requirement rows, and the completeness ledger [X]

- **Until the second milestone the plan's requirement table is the ledger.** Each row names the artifact kind that closes it and, once closed, the receipt path.
- **First instrument: are closed rows still current?** One board row verifies every receipt the plan cites and reports each closed row CURRENT or PROVEN AT <sha>. A second row reports whether the newest battery binds HEAD's runtime inputs, so a deferral shows on every run.
- **The completeness ledger [X, P1]** is one read-only tool that encodes the program as requirement rows, each with a required proof tier and a status from an explicit ladder (absent, shell only, programmed, spatially proven, runtime proven, human accepted). Readiness is scoped: each row lists the scopes it blocks, so "the accepted route works" can never read as "the game is done". It never emits a percentage; counts are obligations. It exits nonzero while incomplete, by design. Evidence intake is by filename only (§3.2).

## §8.4 Receipts

- **What a run receipt records:** completed; raw exit code; timed out; elapsed; the scene's test script and its SHA-256; the runtime-inputs digest; log hashes; counted PASS and FAIL lines; the declared and observed check counts; a stale-import-cache flag; the count of foreign engine processes seen. A verify command re-hashes and answers BINDS, STALE or MALFORMED. Refusals (73, 78) write no receipt, because nothing ran; a wrapper passes refusal codes through and writes none either.
- **The runtime-inputs digest** is the SHA-256 of a sorted list of [relative path, SHA-256 of LF-normalised bytes] over every script, scene, resource, data file and the project file the run can read. The list is written once as a **manifest named by its own hash** and shared; the receipt holds only the digest and the manifest's name. On a mismatch, verification re-derives the manifest and diffs. Scar [C2]: one wrapper receipt that inlined 5,467 input hashes was 812 KB.
- **Bind to content, not to a commit,** and exclude the evidence directory from every digest. A run over the staged change is then committed with that change. A receipt's dirty-path list ignores the evidence directory it writes into. Limit inputs to what the run can read: receipts rooted at the game directory survived P2's history rewrite; receipts rooted at the whole repository went stale with any change.
- **A wrapper over many runs** names its children's receipts by path and hash and never inlines them. Aim for under a hundred lines per receipt.
- **Measured, or null with a reason.** A constant in a receipt is not a measurement.
- **A timestamp is not provenance.** No instrument output carries wall-clock time; a creation time made capture records differ run to run. A board may record durations that no comparison reads.
- Field list: §21.11.

## §8.5 Checkpoints

At solo scale the commit body is the task checkpoint (§21.5). One checkpoint document is written per milestone: milestone id and date; evidence-class header; base commit; what was built, in named files, and what was not changed; independently derived numbers with margins; suites with N of N counts and receipt paths; the capture packet with per-frame hashes; requirement rows before and after; protected-path hashes; the regression battery as command, exit, result, with a nonzero-but-known exit reported as nonzero; limitations and debt; one decision line; human review pending or recorded. A milestone held on human rows still writes it (core A9). With a ledger [X], add a pre-edit declaration predicting which rows will move.

## §8.6 Captures and proof by rendering

- **Settle visual claims by rendered frames** through the production scene and the real player camera, with pinned clock and seed and one declared state change per comparison. Include context frames that prove production placement. A person inspects every frame at full size.
- **The control.** Deterministic captures [C2]: with a fixed-step seeded simulation and the movie writer at a fixed frame rate, repeat captures were byte-identical frame for frame. Prove that once; a changed hash is then a fact. Nondeterministic captures [C1]: capture the same build twice on the same camera and crop, and publish that noise floor beside every delta. Freeze what moves, or measure the floor.
- **Measure inside declared regions of interest** with their own floors, never as whole-frame averages: a swapped 4 cm object scored 0.003 over a whole frame. Score by linear-RGB RMSE on crops.
- **Never sample a periodic system once.** Assert on the peak over a window longer than any period in it.
- **Construct the situation rather than sampling the simulation.** A rare state is staged for its capture, and the capture is labelled a stage; list the missing behaviour that would let play reach it.
- **Drive captures with a scripted pilot through the real input path**, the path bots use.
- **A dark or default-state capture is NO RESULT.** P1 shipped five panels with passing tests that had never been on screen. Give every harness a pre-flight liveness check a dead instrument cannot fake: a shader that fails to compile falls back to a lit material and looks like a lighting bug while frames are saved, so assert that it compiled.
- **When merged geometry hides ownership [C1],** a false-colour id pass from a frozen camera answers which generator record drew a pixel.
- Movie-writer behaviour: §10.3. Performance probes: §10.2.

## §8.8 Where evidence lives

Decide on day zero (core A10). In the repository: one directory that every whole-tree gate excludes or caches, each packet's frames in one archive, a committed capture record with each frame's hash and the measured series, and a contact sheet. Outside it: a content-addressed store with a committed index of digests. Scar [C2]: evidence and captures were 92 MB of 95.5 MB tracked, and every whole-tree gate paid for them on every run.

Evidence packets [X, P1]: per-task material under a work directory (README, check scripts, patches, review) and an evidence directory (receipts, raw logs, captures). Numbering is per attempt; a failed run keeps its number and nothing is overwritten. The heaviest packets hold **omission runs**: revert one fix, prove the red returns, restore exact bytes, so a green is bound to its source rather than coincidental.

## §8.9 Prove the red before you believe the green

The core (A7) holds the rule. In full:

1. Every instrument has a committed red fixture, and a red case per exit code pushed through the real engine. Push a canary through the shell the owner uses and assert the exact number arrives. Scar [C1]: one shell never populated the exit code unless the process handle was read first, and 334 commits of exit codes were worthless.
2. **Date your apparatus** and re-run everything certified while it was broken. On P1 the instrument was the broken thing, not the subject, six times.
3. Every measurement script includes a planted failure it must detect: a clearance check still said PASS with an object planted inside the mesh.
4. For every guard ask "if I delete the fix, does this fail?" and "where does my expected value come from?" A bound equal to the thing's own displacement is a tautology.
5. Every gate defaults red and prints its scope and denominator in the success string. Assert a known gap; never skip the check.
6. Count artifacts declared before the run, not only the exit code. A timeout with no capture line is a budget failure, not an image failure.
7. Gameplay suites get breakages, declared in the specification before the code. Report N tried and M red; close each survivor as a test gap or record it as a harmless equivalent.
8. A survivor that removes your call may be the engine doing the thing itself: the engine made the first camera current and refused a duplicate input binding on its own. Strengthen the check until it turns red, or delete the redundant line; never leave a survivor unexplained.
9. Breakages of an instrument that acts on the machine run only against unit tests with stand-ins.
10. A stand-in enforces every refusal of the real tool, and one integration run through the real tool comes first. A fake runner without the real log rule hid a verifier that failed every real run.
11. Assert the refusal's reason. Drive every counter past 1 and up to its cap.
12. **A flaky test is worse than a failing one.** Root-cause it; an unexplained transient stays open with its log. File a flake in the queue in the commit that mentions it.
13. **Bisect;** do not pick a culprit by recency and plausibility. When a suspect is cleared, edit every document that named it.
14. Confirm absence by reading the code path, never by one search.
15. Run a skeptic told to refute. Every defect a skeptic found had passed its own suite; P2's skeptic tried 69 breakages of three new checks, and every one that stayed green was a test gap.
16. **The breakage manifest** (§21.18) makes all of this an instrument: one small patch per breakage, the suite expected to turn red and why; a tool applies each to a scratch copy, runs the suite through the runner, restores the exact bytes and writes a receipt.

## §9 The instrument contract and the runner

The contract and the exit-code table are in core A7. Additional rules:

- Subclass the argument parser so a usage error exits 3 (the default collides with the ledger's 2), wrap main so an uncaught exception exits 70, and force UTF-8 output.
- Build each mode of an instrument in the milestone that measures with it.
- **Runner specification [C2, corrected from the first edition].** The runner fails a run with exit 1 on any of: a nonzero process exit (the raw code is recorded and never passed through, because a suite's failure count can equal 73, 78 or 124); a FAIL line; an engine ERROR, SCRIPT ERROR or parse-error line, matched after stripping colour escapes and line ends; a leak-at-exit or still-in-use line; a check count different from the declared count; anything but exactly one START and one COMPLETE sentinel; any process of its own still alive afterwards. It runs only the engine pinned by hash and exits 78 otherwise. It refuses to overwrite a log (exit 3): give every run a fresh log path, and read the exit code before the log. Scar: a rerun under the same log name exited 3, and a search then read the stale log.
- **The lane:** an exclusive lock file at one agreed machine-wide location, held for the whole run or battery, with a census of running engine processes as backstop (§4.1). Exit 73 when busy; offer a recorded wait with a deadline.
- **Parse before running.** A suite whose script fails to parse idles until the ceiling while holding the lane. Parsing one script takes under a second (§10.4). The battery parses every changed script first and stops on any import or parse error.
- **Set ceilings near measured times.** P2's suites took 1 to 26 seconds against a default ceiling of 180.
- **Kill only what the run provably started.** A process is the run's leftover only if every process on its parent chain up to the run was created after the run began; a creation time that cannot be read is never claimed. Kill one process at a time through a handle checked against its creation time; never a tree-kill that follows parent ids. Count foreign engine processes in the receipt and never touch them. Scar: Windows reuses pids and never re-parents orphans; a walk up the parent chain could claim a stranger, and the only symptom was one flaky test.
- The play launcher a person uses waits its turn, holds the lane while the game is open, and writes no log or receipt.

## §9.1 Build order, and the gates that earned their place

The order is in core A7. Detail:

- **Domain gates that earned their place on P2**, each with a committed red fixture, a test per finding class, and a line in the covenant: a **clock gate** (no wall clock in production code; simulation time only from the tick; no global random generator in the simulation); a **balance band** (every weapon held to a band measured from the starting weapon; unknown fields refused; tightening is free, loosening waits for the owner in a commit of its own); a **map author** that validates and refuses to write on any finding; a **project-file guard**, because the editor drops comments when it saves the project file; the **flash gate**; the **IP audit**.
- **Domain audits that earned their place on P1:** input-prompt carriers; an interaction census; a spatial dependency manifest; period dates (no player-readable date past the cutoff; no script reads the host calendar for a world fact); the ethos; audio emitters; the music catalogue.
- **Capture wrapper:** a time budget, refuse-overwrite, per-frame hashes, a record of the capture's settings.
- **Release pipeline, before testers [X, P1; never exercised end to end]:** a warm checkout with cold import as an explicit stage; export through the runner from a clean tree with a hash manifest; a packager that runs the content audits first, enforces an exact file contract, requires an owner-supplied licence and refuses to invent one; a notices generator that reads only in-tree licence texts and fails closed; a tester README filled from the exact commit; a performance matrix on a second machine; a static contract test of the pipeline; a rehearsed, timed rollback.
- **When large [X, P1]:** a level-checkpoint toolchain and provenance forensics. P1's level toolchain (10,516 lines) never had a caller: build such things only on demand.
- **Bootstrapping the board.** Run it on the first commit that contains it, store boards in an ignored directory, write the baseline after each commit, and gate each change against it. No baseline is written from a dirty tree or over a regression.

## §9.2 Gates that do not rot

- A baseline is a ratchet: a new finding fails; a changed class fails; a removed finding is a clean note. A findings baseline is for adopting a gate on an existing tree; a new project starts at zero.
- Identify findings by meaning (a hash of domain, class, file, scope and normalised expression), never by line number. Count what the scanner suppressed.
- For every finding class commit the fixture that turns it red, and point the detector at a tree you know is ill. **Ban the shape, not the vocabulary:** an ethos audit caught 0 of 8 violations written in another team's idiom. Define detectors by structure, and publish recall on code you did not write.
- Catch the class with a build-failing invariant whose allow-list is empty and named, never the instance. Give every finding a disposition typed by who can close it.
- Restate every UI prohibition as a storage or API invariant. Put the contract in the generator, not the generated output.
- Encode "undecided" as a checked value, and enumerate the decided states too.
- Expect an honest metric to move against you first, and publish the expected movement before landing.
- Run a proposed gate change against the real tree before recommending it: a "free win" two reviewers recommended produced 48 false positives.
- What counts as a regression: a gate's severity rose; a defect count rose; a named defect appeared; a requirement's status fell or the requirement vanished; a test file ran fewer tests than before, because a deleted test is not a pass. Boards of different tool versions refuse to compare.
- **Board budget [C2].** Total and per-row time printed against about a minute. A gate over immutable evidence checks hashes on every run and re-measures only when a frame's hash or the gate's own source changes: P2's flash gate re-decoded 4,970 frames in pure Python on every run, about four minutes. Whole-tree text scans cache by file hash; history scans cover commits since the baseline plus the draft message. Independent rows run in parallel. When the committed tree equals the tree the pre-commit board measured, that board becomes the baseline without a second run. Keep every run's full output, and append every red row to an ignored catch log, so a milestone can say which gates earn their cost.

## §9.3 The reader gate

A shipped data file must be opened by a production script, and every leaf field must be read by name in a script that opens that file. JSON prose never counts. Durable numeric fields whose only read is their own assignment are reported separately. Identity-map containers are declared, so record ids are not counted as fields. **The convention that makes it exact [C2]:** each data file is opened by a literal path and every field is read by a string-literal key (`data["price"]`, never the dotted form), and a data file lands in the same commit as its reader. Started on an empty tree it cost nothing to hold at zero; P1 adopted it late and carried 1,308 findings, about half of them the gate's own blind spot. A Python gate that tokenises GDScript must treat a backslash and the character after it as never ending a string, raw strings included.

## §9.4 Pair structural audits with measured ones

A lighting audit checked coverage and budgets and never looked at a pixel [C1]; pair it with a windowed audit that turns each room's own switch on and measures the near-black share, keeping an INTENTIONALLY DARK list with reasons apart from a KNOWN DARK list that must stay empty. Every structural suite over presentation has a measured partner [C2]: a render, a still or a hash comparison. Any screen-space layer nobody listed breaks silently when the canvas changes.

## §9.5 Measure before you architect

- **Run the null experiment first, and sweep the knob.** Identical frame time at three resolutions means not fill-bound; identical with 0 or 64 shadow casters means not light-bound. P1's frame was draw-call bound, so GPU quality was free and geometry submission was the only lever.
- **Name which resource each dial spends:** a change that was free in milliseconds cost 1,024 MB of memory against a 256 MB budget. Budget the binding constraint, not the convenient one.
- **Fix the instrument first:** an integer divisor printed 500 ms for a 6.7 ms view.
- **Census where the cost lives before optimising:** 23 props carried 56 percent of all prop meshes.
- If doubling a knob moves the output less than a tenth, instrument the mechanism instead of tuning.
- A finding at one member is a fact about that member; write beside every general claim which members you measured. Quote every number with its corpus: a diagnostic that printed the first eight of eighteen keys produced an invented contradiction.
- **Print the number actually in force.** A wrong budget survived in three documents because nothing printed the one the code used.
- A percentile held against a "never above" budget is only a reading: mark it a default the owner may tighten, and count every sample over the line.
- Time the simulation tick headless (median, 99th percentile, worst tick and which one, with CPU and build type); measure frame cost windowed (§10.2). P2 rewrote route planning over packed arrays after measuring: 26 ms at the 99th percentile became about 4, with every answer unchanged, and a planted half-millisecond dawdle proved the measurement catches a regression.

## §9.7 Backups

A backup is an off-machine copy, which needs the owner (core A13), plus a verified bundle before any history rewrite (§4.3). P1's day-one backup scripts ran add-all and pushed to the main line, predated the ban and were never retired: when a ruling lands, sweep the tree for instruments that embody the old practice (§4).

## §9.8 Tooling policy

Gates, runner, receipts, board and verifier stay in the standard library; it is the most portable decision either project made. Content tools may use a small pinned package list, or external binaries pinned by path and hash, decided on day zero: an unpinned media tool on PATH cost P1 a day, and P2 measured music with unpinned binaries and no receipt. A helper two tools need lives in one shared module. A third-party parser catches syntax errors, never type errors; pin its version in a requirements file. Test a third-party addon against the one non-negotiable requirement first, and vendor foreign code by scripted copy with a class prefix.

## §9.9 The fresh-checkout verifier

It clones base and candidate fresh and grades the candidate with the **base's** board, runner, suite declaration and protected-path list. No candidate can therefore unprotect a path, drop a suite or lower a check count in the change that benefits from it. Every changed file under the tools directory is listed for a person to read. One run costs two boards and a battery (an estimated seventeen minutes on P2), so it needs the schedule in core A10, or it will not run. Protected paths are declared as a list of path, SHA-256 of LF-normalised bytes and the ruling that froze each.
