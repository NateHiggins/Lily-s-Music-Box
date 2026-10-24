# Reference: git, the machine and the engine

Evidence class: **INERT - REFERENCE**. Part of *The AI Studio Manual*, second edition (2026-10-03). Opened by section from the operating core, `AI_GAME_DEVELOPMENT_MANUAL.md` one directory up; never read front to back. Section numbers are permanent. Labels: **[M]** held on both source projects, **[C1]** / **[C2]** seen on one, **[X]** machinery for one project's scale.

Sections here: §4 to §4.4, §10.1 to §10.5, §28. Engine facts are for **Godot 4.7.1 on Windows 11**, the build both projects used; each says whether P2 measured it or it is carried from P1. Verify every one on your pinned build and keep your own dated list.

## §4 Git in detail

- **Staging and stashing [M].** Stage named paths and read the staged list before every commit. Never a bare stash: the stash stack is shared; prefer a work-in-progress commit. Commit bodies also say what was wrong before, and the design document changes in the commit of the code it governs.
- **"Untracked" is a statement about your index, not the remote [C1].** A stale worktree's import minted 47 resource-id files with values different from the main line's; merging them would have rewritten identities silently. Never commit an id file the main line already has under a different value.
- **Worktrees** live at short paths; deep paths exceed the OS path limit and break the engine's import cache. Name every worktree in the pickup and the rules file; a lint fails a dated "current checkout" block that disagrees with the worktree list. Scar [C2]: the rules file named one checkout while a second worktree, in the agent's temporary session directory, held a branch of unproven work.
- **Retire by archive-then-remove [C1]:** an annotated tag before any deletion; files moved to an archive with a SHA-256 manifest hashed before and after; a triage table the owner approves. Classify every commit not on the main line (already in main, accepted candidate, proven but human-pending, failed gate, superseded, evidence only, quarantined, duplicate, unknown). Use the NUL-separated status output; the porcelain form escapes non-ASCII paths.
- **Work found in no ref** is rescued by a copy-only snapshot with a manifest, then committed through a temporary index onto a backup branch, never by touching the source tree. P1 rescued 2,081 uncommitted files that way.
- **Measure one commit from a clean temporary worktree** while the main checkout holds unfinished work; a baseline is never written from a dirty tree.
- **Large packs.** Keep masters out of git: a 400 MB archive cost P1 a day of failed pushes. Ignore large binaries from the first commit and add a size guard.
- **When a ruling lands, sweep the tree.** Search the old practice across the README, tools, design documents and build guide; rewrite or delete each instrument that embodies it; untrack anything an ignore rule was added for after it was committed; add a static gate that searches for the forbidden command. P1's retired backup scripts still ran add-all after the ban.
- Keep the repository root free of any engine project, and never keep a submodule pointer without its configuration and a reachable commit. Never keep a checkout or evidence under a file-sync folder.
- No hook is installed silently: a tool prints the hook and a person wires it.

## §4.1 The engine lane

- **Machine-wide, across projects [M, widened by C2].** From P2's first hour another project's session ran the same engine every few minutes, behind a lock this runner could not see; a count of processes by engine image name was the only shared guard. Agree one lock name and location for every project on the machine, write it in each build guide, and keep the process count as backstop.
- **Exit codes.** 73: lane busy, nothing started. 124: killed at the ceiling, the suite reported nothing. 78: cannot run (engine, project or log directory missing, or the pin does not match). Anything else nonzero from the engine is reported as 1 with the raw code in the receipt (§9).
- **Waiting.** The runner offers an explicit, recorded wait for a quiet window with a deadline, so nobody writes a poller. A battery holds the lane for its whole run, not per suite, so no other engine starts between two suites.
- **Never close another session's engine, or the owner's.** The editor's project-manager window counts as a running engine (carried from P1, where an idle one held the lane for six hours).
- Give the owner one command that shows who holds the lane. The play launcher waits its turn and holds the lane while the game is open.

## §4.2 Machine setup a fresh clone must reproduce

Write all of it into the build guide; none of it lives in a tracked file by itself.

- **The engine pin:** the SHA-256 of both binaries (on Windows the console build is a wrapper that starts the windowed executable as its child), a fixed list of folders to search, exit 78 on any mismatch. Never find the engine through PATH: P2's machine held several copies. When the owner moved the engine, only the pin changed.
- Git identity; long-path settings; **core.autocrlf** false in the repository (it may be true at system scope); ignores committed, not per-machine.
- The agent's own tool limits: tool calls have time caps (ten minutes on P2), and a board plus its baseline overran one. Run long work in the background with its full output in a log file.
- Which other projects on the machine run an engine.
- Export templates and their versions; GPU, driver and display, recorded beside every performance number.

## §4.3 Rewriting history on the owner's ruling [C2]

Done once, on day zero, on an explicit ruling, and recorded. Never without the same kind of ruling.

1. Write a git bundle of all refs outside the repository, verify it, and record its SHA-256.
2. Replace exactly the redacted blobs in every commit with an index filter, leaving messages, authors and dates byte-identical. Check commit by commit.
3. Delete the original refs, expire the reflogs and garbage-collect.
4. Scan every object, reachable or not, for the removed text.
5. File a dated record: the old-to-new commit map; which receipts now verify STALE (those whose inputs include a rewritten file); how to verify them against a clone of the bundle.

## §4.4 Traps in the agent's own tool environment (Windows, Git Bash, PowerShell)

Hours went to the agent's own tools on both projects, and one trap corrupted code that still passed its tests.

1. Git Bash's grep cannot see a carriage return; it reported a CRLF file as LF. Measure line endings from bytes, in Python.
2. Python's text write emits CRLF on Windows. Write bytes or pass an explicit newline, and keep the board row that holds LF-declared files LF.
3. Shell heredocs collapse doubled backslashes and break on unbalanced quotes, even when the delimiter is quoted. Two script continuation lines were joined into one that still parsed, so the tests passed. Write such text with the file-writing tool or a script file.
4. `cmd | tail -1 && next` gates on tail, not on cmd. Gate on the text, or set pipefail.
5. Never wrap a gate in a process-launching cmdlet; read the exit code directly. One shell never populated a child's exit code unless the process handle was read first (P1: 334 commits of false zeros). Nested shell invocations can flatten array arguments, so the engine silently ignores a flag.
6. Tool calls have time caps. Run long boards and batteries in the background with their full output in a log, and read the log.
7. Keep every gate run's full output. Report a transient failure as open, with its log, never as fixed.
8. Read the runner's exit code before any log, and give every run a fresh log name.
9. Expect CRLF and colour escapes in the engine's redirected logs.
10. Copy machine traps into the build guide. An agent's private memory is only a pointer, never the record: P2's memory note said "details live in the build guide", and the build guide lacked four of these.

## §10.1 The suite

- **One base suite script that has run**, not a skeleton to copy (§21.10). A test is a scene whose root node carries a script extending the base, run headless through the runner. The base provides START and COMPLETE sentinels, a watchdog, an exact expected check count, a ledger of executed blocks, the contract receipt, and quits with the failure count.
- **Declare every suite and its exact check count in one data file** that the battery and verifier read; the battery fails on an undeclared test scene. The count includes the base script's own "every block executed" check, so set it from a real run. Never copy counts into prose: P2's hand-kept table had three wrong counts and nine missing suites.
- **Count twice, once outside the process under test.** When the suite frame was deliberately broken to print PASS, the runner's external count still failed the run. Audit for the shape P1 once shipped five times: a test file that prints PASS and quits 0 unconditionally.
- **Pin the world first:** persistence disabled and state reset so the user's save never leaks; tests write real files under a test path, never the production save; every randomised director stands down under test; any enumerable set lives in one constant that tests iterate.
- **Step the tick; never scale time [C2].** Keep the simulation a plain object; tests turn off the driver's processing and call its tick in a loop at time scale 1. If a legacy suite must scale time [C1], raise the physics rate by the same factor and assert per-step displacement stays below half the thinnest collider; engine timers scale with time scale too.
- **A watchdog inside the script is not a ceiling.** A suite that fails to parse has no watchdog at all, and a scene-tree timer cannot interrupt a synchronous loop. The runner's ceiling is the only guard that always works.
- **Refusal paths must be quiet** under a runner that fails on any error line: a loader returns its reason and leaves logging to its caller (see the JSON trap in §10.4).
- **Assert rules, not numbers that emerge from play.** The tick on which P2's boss fell moved three times with tuning, and each move rewrote a test. Keep any exact pins in one regenerated golden file with a reason per entry.
- Each suite's scope line says what it does not prove.

## §10.2 Headless and windowed

- **Headless passes vacuously** for anything rendered: it never fires the post-draw signal, reports zero for every rendering counter, answers defaults for instanced reads and cannot capture the mouse. Screenshot, performance and pointer suites run windowed, and the capture harness refuses when the display server is headless. Detect headless with `DisplayServer.get_name() == "headless"`.
- **Headless is the right place to measure the simulation's CPU cost [C2]:** time the tick, and report the median, the 99th percentile, the worst tick and which tick it was, with the CPU and whether the build is debug or release.
- **Every view exposes a pure function** that says what it would draw from one snapshot (words, pose, lit signs, a colour). Headless suites test that function; looks are settled by renders. Each suite's scope line says which of the two it proves.
- **Frame cost is measured windowed [C1]** at a fixed resolution, with vsync and frame caps off, budgets pinned in code, every camera station warmed before timing (shaders compile lazily), and any station below a minimum object count failed: an empty frame is a broken run, not a fast one. Report the median with its 5th to 95th percentile spread, cross-checked against wall clock and frame count.
- **A screenshot suite [C1]** reads an absolute, pre-existing output directory, hides overlays, makes a camera current and moves the player with it (streaming and light budgets follow the player), waits two frames and the post-draw signal, then saves the viewport image.

## §10.3 Capture budgets and the movie writer

Measure your own launch, boot and per-frame costs and set each capture's ceiling from them (P1's fixed budget for its 3D boot is in `CASES.md`). Negative slack means shard the capture; never delete evidence or lower the expected count. A shot may disable a feature group only when that group is outside the claim, and its record names what was disabled.

**The movie writer [C2, measured]:** it records at the project's configured viewport size, fixed at startup, and ignores the resolution flag; it silently shrinks a canvas enlarged at runtime; it writes a silent audio file; it is deterministic. Check its "recording movie in WxH" line. Check passes done at display resolution with stills taken from the root viewport's texture. Detect a recording with `Engine.get_write_movie_path() != ""`.

## §10.4 Engine facts and traps (Godot 4.7.1, Windows 11)

Keep a dated list of facts measured on your pinned build, each with its receipt, apart from facts carried over from elsewhere. **A carried fact copied into a rules file hardens into a rule:** P2's rules file stated as fact something its build guide listed as unverified. Rules files keep the measured-or-carried label too.

**Measured on P2:**
- An error pushed by script prints an ERROR line and the engine quits 0. A runtime SCRIPT ERROR lets the frame finish and quits 0; one bad line in a loop printed 2,851 identical errors.
- A script that fails to parse does not fail the run: the engine idles until killed. Every run needs a ceiling.
- Leak-at-exit lines usually follow a mid-suite error; they are knock-on effects, not causes.
- The console build's output reaches a redirected log, with CRLF line ends and, on some paths, colour escapes.
- `--check-only --script <path>` parses one file in under a second, with the real error line.
- One parse error cascades into "Cannot infer the type", "Could not resolve external class member" and "Failed to compile depended scripts" in every dependent script. Find the root cause by parsing the file you edited.
- Import writes an id file beside every script; track it. A script written while the engine cannot run has none until its first import.
- **One import suffices** when scripts reach each other by preloading their resource path and nothing declares a global class name: a fresh clone ran after one import. With global class names [C1] a fresh worktree needed two imports, and "Nonexistent function" or "Could not find base class" in a fresh tree were a stale import cache, not a code bug. Keep the stale-cache detector either way.
- Import leaves a hand-written project file byte-identical.
- With **core.autocrlf** false and every path `-text`, no line-ending churn appeared in 202 commits. The first edition's claim that the engine rewrites id and import files' line endings most likely came from autocrlf (inferred, not measured).
- Pass scene options after `++` and read them with `OS.get_cmdline_user_args()`.
- A project an agent builds can be text only: each scene file holds a root node and its script, and the world is composed in code.
- **Input:** register the input map in code, on physical keys, and poll named actions once per tick. Latch every press until the next tick takes it, so a tap shorter than a tick is never lost. Keys that change only presentation stay out of the input record. A verb read from a raw key event is unreachable from a pad.
- `JSON.parse_string()` prints an ERROR line on bad input; `JSON.new().parse()` does not. `Array.slice()` with decreasing bounds prints one too.

**GDScript traps (P2 unless marked):**
- `:=` cannot infer a type from an untyped Dictionary value, an Array element or an untyped call: the commonest parse error, about forty times.
- A method named `_get` overrides the object's own and fails to parse. A function named after a global utility (`wrap`, `clamp`, `lerp`) fails with "too many arguments". `Vector2i` has no `dot()`.
- Typed receivers move missing-method errors from runtime to parse time.
- A lambda captures local variables by value [C1]: two hours lost, twice.
- `has_method` proves spelling only, not signatures or effects [C1]. Read engine object properties through the base-class API: a subclass-only property read threw on the first object of another class and aborted a whole loop [C1].

**Carried from P1, not re-measured on P2:**
- The plain, non-console build prints nothing to standard output on Windows.
- `OS.set_exit_code()` is missing in this build; quit with the failure count.
- The editor drops comments when it saves the project file (hence the project-file guard).
- Import settings: the editor never sees a texture loaded at runtime by path and regenerates it with mipmaps off, so the import file of every such texture must be tracked. P2 tracks all import files by design; none existed yet.
- Windows file rename deletes its destination first and there is no checked sync: saves need a backup file, a journal and a temporary file with verified reads.
- Export dependency filters cannot see assets referenced by runtime strings: exclude superseded large assets by name and include non-resource packages explicitly.
- The engine does not diagnose two revisions of a data file and its binary sibling loading together: embed the sibling's SHA-256 in the descriptor and verify at boot.

Facts that matter only to a 3D game (fog, light caps, mobile renderer limits, merged meshes) are in `CASES.md` §19.

## §10.5 Rendering and presentation (2D) [C2]

- **A display filter at display resolution, with an exact canvas.** Render the game into a sub-viewport of the canvas's size, with nearest filtering and pixel snapping. Set the window's content scale mode to disabled. Draw the viewport's texture through the shader on a rectangle the largest whole multiple of the canvas the window holds, centred on a dark surround. Reparent the main scene into the viewport once it is ready. The "viewport" stretch mode alone cannot do this: it renders at canvas size and only then scales. Build none of it headless or while a movie records, so suites and captures see the plain canvas: forty review frames were hash-identical before and after the filter landed.
- **A filter that cannot cause flashing:** no time input, so nothing flickers, rolls or adds noise; work in linear light; give every canvas line its own scanline and divide each line's beam by its mean, so scanlines are texture, not dimming; below three screen pixels per canvas pixel, drop effects step by step; the switched-off branch equals the nearest-neighbour upscale pixel for pixel; every number lives in a bounded data file; the look is judged on stills.
- **Smoothing a fixed tick.** Each figure reads the physics interpolation fraction in its per-frame callback, interpolates between the last two snapshots and snaps to whole pixels. It never interpolates across a jump such as a door or a respawn.
- **Photosensitivity in the code, not only in the gate:** every room's floor within a small luminance band, so a room change cannot flash; darkening by at most a tenth of luminance per frame; no time input to the filter.
- **World units are separate from canvas density.** Doubling the canvas changed the camera's zoom, the HUD's scale and the ingest density, and no gameplay number.

## §28 Working while the engine is held

The seven steps are in core A12. Detail:

- **What P2 ran while held:** Python instruments proved red; four build-ready specifications; prompt sheets and art ingest; contact sheets composed by script. On a branch: fifteen commits in written-ahead and reviewed pairs. Prefer code written ahead to ever-longer designs: specifications ran to more than a thousand lines. Cap unproven work at a set number of commits or one milestone's worth.
- **The static board must start no engine.** Tool tests use a stand-in engine, and the real-engine battery is not named like a unit test, so the unit suite never starts it.
- **The worktree's path must be durable and recorded.** P2's sat in the agent's temporary session directory, beside uncommitted Python models that had produced pinned values.
- **Values from models.** A Python port of a generator, including the engine's random number generator, agreed with the engine's logs at the three points where they could be compared: that is agreement at three points, not "matched exactly". Commit any model that produces a pinned value beside its test. Defer any check that could only be pinned blind.
- **Source-only checkpoints [C1].** Parse every changed script with a third-party parser, with its version recorded; assert every literal resource path exists; recompute geometry and topology independently from the data; assert a manifest is additive-only against the base; and write a receipt with an honest status that says the engine has not run, which moves to runtime-proven only after it has. The parser accepted a type inference the engine rejected, twice. Lane refusals are recorded verbatim, never bypassed.
