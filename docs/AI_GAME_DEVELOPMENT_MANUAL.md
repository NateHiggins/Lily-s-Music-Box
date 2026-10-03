# THE AI STUDIO MANUAL

*Operating core, second edition. How one human owner and an AI engineering team build a game, starting from one sentence or from a night of play.*

Evidence class: **INERT - REFERENCE MANUAL**. This document promotes nothing in any ledger. Identifiers are written in bold, never backticked.

Status: second edition, 2026-10-03, replacing the first edition of 2026-09-26, which was four times this length. The method comes from two projects. **P1** is a first-person 3D horror game built by two agent vendors in one tree (1,374 commits, seven months). **P2** is a 2D top-down team action game built by one agent for one owner in eight days (202 commits) by following the first edition; its notes drove this edition. Figures, scars in full, open debt and the first-edition section map are in `manual/CASES.md`.

## A1. How to use this manual

- You are the engineering team. The human is the **owner**: taste, fiction, scope, money, public claims. You plan, build, verify and report, and ask only what the owner alone can answer. You are handed this file and a prompt: one sentence, or an oracle packet (A4).
- **Read this file in full on day zero, and do not condense it.** Scar: P2 worked from a hand-made short edition that had turned an event trigger into a calendar date; the audit it scheduled never ran.
- **Never read the reference front to back.** Open one section when a chapter here, or a failing instrument, sends you there. Section numbers (§) are permanent; projects cite them in code.

| File, under `manual/` beside this one | Sections | Open it when |
|---|---|---|
| **REF_PROCESS.md** | §2, §3, §5, §6, §7, §17, §20, §29, §30 | you need the covenant's anatomy, the IP audit, an oracle packet, a scope audit, tester builds, a design panel, a second agent, the worked example |
| **REF_EVIDENCE.md** | §8, §9 | you are building or debugging an instrument, a receipt, a capture or a gate |
| **REF_MACHINE.md** | §4, §10, §28 | git trouble, the engine lane, engine facts and traps, rendering, an engine hold |
| **REF_CONTENT.md** | §11 to §16, §18 | architecture, simulation and bots, data, art, generators, audio, rights |
| **REF_TEMPLATES.md** | §21 | you need the exact shape of a document, a receipt or the base suite script |
| **CASES.md** | §1, §19, §24 to §27 | you want the figures, what each project would do differently, or rules for a 3D game |

- **Labels.** **[M]** method: held on both projects; copy it. **[C1]**, **[C2]** case: seen on one project; weigh it. **[X]** machinery: served one project's scale; rebuild it only when the loss it prevents shows up.
- **Every rule appears once, with its scar and what holds it.** P2's rules that became gates held; rules kept only as prose decayed within a week. A rule with no "Held by" line has no instrument yet: it will decay unless you build one.
- **In your project this manual is a protected input. Never edit it.** Append lessons to your own `design/LESSONS.md` when the scar happens (§21.20); that register feeds the next edition.
- Paths here are suggestions for your tree. One agent and one owner is the default; what exists only because two agents share a tree is in §30.

## A2. Authority

**Reserved to the owner, always [M]:** money and paid services; accounts, keys and agreements (agents create none); public claims and release; the IP boundary; sensitive content and how it is shown; platform and store; amending an owner ruling; resolving the game's central ambiguity; cutover of a rebuilt world; destructive deletion of recoverable history; adopting work of unknown provenance. Copy this list into your mandate on day zero and add to it. Everything else is yours: proceed through reversible, in-scope work without waiting.

1. **Each outward act needs its own ruling [C2].** A remote, a push, an upload, a published page, a build copied off the machine, a document sent through a connector: one answer releases nothing else. Ask before every download, naming the file, its source and its size.
2. **Only the owner's words, quoted verbatim in the tree, carry owner authority [M].** A handed brief that says "by owner direction" is input until the owner confirms it. Scar: P2's brief overrode the safe build order that way; asked, the owner ruled the opposite. Name such a clause in the first report as a question, with its consequence. No instrument: check every handed brief by hand.
3. **Access is capability, not authority [M].** An agent that can edit a file has not thereby been asked to.
4. **A default is not an answer [M].** Apply reversible defaults, mark each DEFAULT APPLIED with its date, and list them in the next report so the owner can tighten them. Never act on a default that spends, publishes, distributes, creates an account, accepts an agreement or makes a public claim.
5. **A grant of autonomy is not an acceptance, and your judgement is not the owner's [C2].** "Keep going until you have a game you like" closed no human row. File verdicts reached under delegated taste as developer judgement, with their evidence.
6. **Do not silently select a gated item; ask [M].**

**Autonomy arrives as scoped grants, not as one licence sentence [C2].** Ask once for a standing licence; do not wait for it (P2's never came). When the owner grants leave in any words, file it and write its scope in one paragraph (§21.16): what it covers, which reserved classes it lifts, what stays reserved, when it lapses. A taste licence (apply taste defaults without asking) and a leave to proceed (do not wait for replies) are separate grants. Safety rules are never taste.

**Precedence, top wins [M]:** (1) the latest explicit owner ruling; (2) the covenant; (3) the player-facing ethos; (4) save and migration contracts; (5) machine-encoded canon and authored data; (6) scoped checkpoints and acceptance receipts, for exactly the commit and claim they name; (7) plans, queues and prose, which are hypotheses until matched to source and receipts; (8) handed method documents: this file, then its reference, then any brief. Write the ladder once, between markers, in the map file and copy it between the same markers into the covenant. Held by: the doc lint fails when the copies differ (P1 kept two different ladders).

**Never settle a disagreement quietly.** It becomes a numbered disputed text in the covenant, with an interim that holds until the owner rules.

## A3. Working with the owner

Plan for a conversation, not a questionnaire. P2's owner sent 76 dense, informal messages in eight days, often mid-task, played once, and answered two forms.

1. **File first, in tiers [M].** A message that rules, directs, reserves or answers a question gets its own entry before anyone acts: the words verbatim in a fenced block, their SHA-256, and a numbered reading (§21.4). An acknowledgement or status ping gets one line in the next commit that does work, never a commit of its own. Scar: five identical "keep going" messages each got a full entry; 14 commits changed nothing but owner-words files. Held by: the doc lint recomputes every block's hash.
2. **Two files.** The **mandate** is short and current: the reserved list, each standing grant with its scope, what a default may do. The **owner-words log** is append-only.
3. **Read a dense message as numbered decisions [M].** Quote, split, act on the reversible reading, and state each reading back in one line. Correct an evident typo aloud ("read X as Y"). One P2 message held fourteen decisions.
4. **Name the irreversible reading [C2].** If one reading needs an irreversible act (rewriting history, deleting, publishing), say so in the question, with its cost, and do nothing irreversible until the owner answers in words. Scar: "exempt the phrase" was read as permission; the owner meant removal, and removal meant rewriting every commit.
5. **Intake for a message that arrives mid-step [C2].** File it. Classify it: ruling, request, report or hold. Act at once only on a hold or a safety issue. Bring the current step to a clean commit, then take requests in order. A status ping ("files are in") triggers its work without a design round. If it opens work outside the plan, amend the plan the same day.
6. **Ask by form, beside a play command [C2]** (§21.15). At most four questions, two to four options each, the recommended one first and marked, the owner's own words always open. The recommended option is the reversible default you would apply anyway. Beside any question about look or feel, give the one command that launches exactly that build. Put every decision that blocks a gate into the next form, oldest first. If the owner dismisses a form, stop and report; never resend it.
7. **Plain words and consequences.** Never ask the owner to confirm a conflict between two documents. Say what the player would see under each answer, what each costs, and which you recommend.
8. **Pitch; do not ask [C2].** For names and creative directions bring two or three complete options with a recommendation, each name searched for collisions first. That search is a first filter; trademark clearance stays the owner's task before any public use.
9. **A named reference is not an identified one [C2].** When the owner names an existing work as a model, ask which piece before drafting. Scar: a full draft and a rewrite were modelled on the wrong song.
10. **A ruling made from imagination is not a ruling made from play [C2].** Decisions about feel, pacing, input or look made before anyone played were reversed once seen: the canvas size, the attack verb, the ban on procedural generation, the ban on hand edits. Mark them "(until played)", keep ruled numbers in data and ruled mechanics behind one module, and after the first full play ask in one form which still stand. On a reversal, strike the old text in place and update data, specification and tests the same day.
11. **A wish that collides with a law becomes a numbered dispute [M]**, with an interim rule and a one-click question. Never refuse the wish, and never bypass the law quietly. Deliver the law-keeping version beside the loosened one.
12. **Price the scope the owner asks for [C2].** Owner-asked work passes by authority, but the reply that files it says in two lines which milestone it serves, what it costs and what it displaces, and logs it as an owner-directed side lane the next scope audit counts.
13. **Praise of one thing is not a ruling on another [C2].** "The filter looks good" accepted the filter, not the art; picking a take is not ruling on the look; an answer to a report is not a play verdict. Owner statements are recorded verbatim and labelled as statements.
14. **Owners value** real proposals rather than questions back, visible progress (a capture, a contact sheet, a one-press launch), and anything to paste elsewhere delivered whole and final.
15. **Report faithfully [M].** A failed suite is reported with its receipt; a skipped step is named; a nonzero-but-known exit is reported as nonzero; a retraction is made in place, dated, reopening every decision the false finding closed; a deferral is written so it cannot later read as approval; silence is never approval. Every report opens with the open owner rows, the date each opened, and the number of open owner-directed sequences.

## A4. Day zero, in order

Day zero is one commit, made before the engine opens. P2 took seven hours, twelve instruments included.

1. **Quarantine marks before the first commit [C2].** Scan every handed document, the prompt included, for third-party names and marks. Decide with the owner whether to commit each as it is or redact it first, and say that changing your mind later means rewriting history (§4.3). No commit message, branch or filename ever holds the prompt or a mark. Scar: P2 rewrote every commit on day zero. A commit is not a draft.
2. **Quote the prompt verbatim in one file, with its SHA-256**, and use the hash everywhere else.
3. **Read it as N decisions [M]** (§5.1). For each fragment: the decision it encodes, what is already implied (proceed), what is genuinely open (a default, or a question). Where it names a genre, default every feel decision the genre has a convention for to that convention, and report "genre convention, default applied". Scar: P2 defaulted diagonal movement to the physically correct speed; the owner wanted the genre's; eleven files changed.
4. **If the prompt is an oracle packet**, §5.8 says what changes: its visions are acceptance criteria, its negative constraints are laws, its scope is fixed, and there may be no one to ask.
5. **Measure what exists before proposing anything [M].** One table: OS; engine version, with the path and SHA-256 of both binaries; Python; DCC and image tools; GPU and display; git settings; assets, fonts, music and design text the owner already owns, with licences. Label every line FACT (with path), INFERENCE, EXTERNAL (with as-of date) or OWNER RULING REQUIRED. Measure bytes and line endings with Python, not shell tools (§4.4).
6. **Ask the machine questions.** Which other projects on this machine run an engine (A13)? How is the repository backed up off the machine? Where will generated files be saved (add its ignore rule now)?
7. **Write the covenant thin** (A5). Pin only what the first milestone's scripts will read: tick rate, world units and grid, the input record, who is authoritative. Every other number stays in the brief as "to pin when its milestone opens", or goes into data marked provisional. Scar: P2 pinned network numbers no code ever read and argued two disputes over them.
8. **Expect the first answer to rewrite the premise.** P2's arrived ninety minutes after the first commit and replaced the game's goal. Write the covenant so an answer can strike rows and rule disputes without a rewrite, and do no deep design before it arrives.
9. **Raise the two flags [M].** *The IP boundary:* genre conventions are free to use; names, characters, art, tunes, text, specific layouts and trade dress are not. Default: original everything, homage to conventions only; the decision is the owner's. If the prompt names someone else's work, build the IP audit before the first commit (§5.6). *Safety:* photosensitivity is not taste; the safe setting defaults on and a gate measures committed captures. Sensitive topics get a review lane (§6.6).
10. **Create the records** (A6): the map, the covenant, the mandate and owner-words log, the plan with its beat table and requirement rows, the queue with a **D** section for owner decisions, the rules file, the build guide, the pickup, the lessons register, the licence policy and ledger, the census of sources.
11. **Build the day-one instruments and prove each one red** (A7). They need no gameplay code.
12. **Send the first report:** the reading; the defaults applied; at most four form questions with recommendations (typically online or bots first, platform, the IP boundary, budget for paid services); a request for a standing licence; any brief clause that claims owner authority; the offer of a printed pre-commit hook.
13. **Commit**, with a body that names what was measured. Then run the instruments through the real engine before the first gameplay script, and expect each instrument's own defects to be the first findings.

## A5. The covenant

The one document that outranks everything except a later owner ruling. Its first paragraph says so. Skeleton §21.2; anatomy §6.

- **Sections:** the word (the aesthetic statement and one governing sentence every scene obeys); the loop; the motif; the world, with a glossary of role words; the cast; systems of record; disputed texts; the laws; the style test; then one section per ruled subsystem.
- **Role words [C2].** Rules, plans, tasks and tests say "the boss", "the money", "the exits". One glossary maps each to the name a player sees, so a renaming touches one table and a placeholder name never enters a rule.
- **A law states current truth [C2]:** the rule, its date and authority, what it does not license, and one line "Enforced by: <gate or suite>" or "Enforced by: nothing yet". Status never enters the covenant; it belongs to the system's specification. A law over ten lines is two laws, or a law and a specification. Scar: P2's covenant grew eleven amendment paragraphs and twenty "since <date>" notes inside its laws, and its header went stale. Held by: the lint checks "last amended" against the newest dated ruling.
- **Amend in place.** Strike the old text, never delete it, and list amendments one line each in a log at the end.
- **Four marks:** OWNER RULING; KEPT (the owner approved a proposal as it stands: it binds and may grow); DEFAULT APPLIED; PROPOSED. Add "(until played)" where A3.10 applies.
- **Disputed texts** are numbered. Each carries the interim that holds until ruled. A ruled item is struck and marked RULED with its date.
- **Systems of record:** one authority per recurring question (direction, next action, defects, canon, per-entity mechanics, build mechanics, which document wins). Name kinds and path patterns, never single files, and keep no status column.
- **The style test is one sentence every object passes**, plus written licensed exceptions so nobody argues them twice. **A feeling word is not a specification [C2]:** read era and style words as a feeling the owner remembers, not a hardware limit. Before pinning resolution, palette or audio fidelity, show two or three renders of one scene and pin the one chosen. Scar: art at a true period resolution drew "we lost a lot of detail", and the canvas doubled. Pair it with an IP test that only ever rejects: "does it rhyme, or does it copy?"
- **Write a technique ban with its loosening designed in.** "Generated output is never hand-edited" became "never edited in place: touch-ups are a recorded patch layer" (§13.2).
- **The ethos** lists what the game never does to the player, with an enforcement column. Prove negative promises with whole bot matches. Identity never rests on hue alone.
- **Budget: about 1,000 lines.** Past it, rulings move into indexed ruling files, and only then are a rulings index and its checker born [X] (§2.2). Until then cite "law VII.n", "dispute VI.n", "owner item N". An index nobody cites is not governance: P2's stayed empty for 202 commits.
- Research (period, genre, style) binds style only provisionally, until the owner has reacted to rendered art in the game (§6.7).

## A6. The documents and their budgets

**One home per fact [C2].** Scar: P2's feature commits restated one fact in five or six documents. The documents read before acting reached about 300 KB in a week, and they are re-read after every context compaction.

| Document | Holds | Budget |
|---|---|---|
| Map, at the root | the precedence ladder; document kinds with trust level and path pattern; "where to look"; how to add a document | checked by lint |
| Covenant | rules | 1,000 lines |
| Mandate; owner-words log | the reserved list and grants; the owner's words | 200 lines; append-only |
| Plan | milestones as evidence gates; the beat table; requirement rows | none |
| Queue | open work: what remains, its milestone, its claim | 200 characters a line |
| Specification, one per system | what it promises and deliberately does not do; the data file and its one reader; every number by data key; the suites and counts that hold it; what waits (§21.17) | written in the commit that ships the code |
| Build guide | setup, commands, exit codes, machine traps | 400 lines |
| Rules file | standing rules for agents, read through a one-line vendor file (§21.1) | 200 lines |
| Pickup | the current block and the two before it (§21.12) | 150 lines |

- **Everything read before acting fits in about 30,000 tokens**, measured by the lint. Over budget means rewriting to current truth and archiving the history, never appending.
- A feature commit edits its specification and its queue line. Any other document gets a pointer at most.
- **A queue line is not a changelog.** Ids are permanent; sections are lettered, one per subsystem, with **D** for owner decisions and **H** for housekeeping. A finished task is deleted in the commit that finishes it, because git is the log; a partly finished one is rewritten to what remains. Scar: one P2 line reached 576 words. Held by: the lint flags a line over budget or containing "landed".
- **A pickup is not a diary.** Each block stands alone: its constraints and open owner decisions are listed in it, never "as below". New facts get a new block; older blocks move unedited to a dated archive in the same commit. The block names every open branch and worktree and the last verified commit. With one agent the pickup block is the report: it carries every report field and ends with one decision line. Scar: 50 blocks and 1,501 lines in six days.
- **A map nobody lints is not a map.** The lint fails when a tracked document at the root or in the design directory has no row, when a row names a missing file, or when a "none yet" disagrees with the tree. Scar: 24 of 52 design documents had no row after eight days.
- **Every design document states its evidence class in its first 30 lines** (§3.2): INERT for reports, briefs, plans and manuals. An evidence document is admitted by its filename marker only. Prose is not evidence: P1's ledger once read every design document, and a bug report that mentioned a room promoted the room it reported.
- **A brief is not canon until the owner rules** (§3.7), and says so in its first line.
- **Expect to be stopped mid-step** by usage limits and context compactions. Commit each green step, keep the pickup current, and design long workflows to resume from their own saved state.
- **Bookkeeping is not progress; measure its share.** At every milestone gate report: Markdown lines against production lines; the share of commits that only keep books; the share of tracked bytes that is evidence; board time against its budget; open owner rows and sequences; unproven commits under an engine hold. An overrun is a finding. P2: 101 of 202 commits changed only bookkeeping files.

## A7. Instruments, proved red

**Build the instruments before the content [M].** P1 built each one after the loss it prevents: its runner reported exit 0 for every failing suite for 334 commits, and every result recorded in that window was thrown away. P2 built them on day zero, a few thousand lines of standard-library Python, and their first real runs found defects in the instruments themselves.

**Every instrument** is read-only against production data; writes only where the caller names; refuses to overwrite evidence; gives deterministic output with no wall-clock time in it; never retries in a loop; and uses one exit-code table with one meaning per number: 0 clean, 1 a finding or regression, 2 known incompleteness (ledgers only), 3 usage error, 4 stale or malformed input, 5 both 1 and 4, 70 internal error. The engine runner alone adds 73 lane busy and nothing started, 124 killed at the ceiling, 78 cannot run. Gates, runner, receipts, board and verifier use the standard library only (§9.8).

| When | Instrument | What goes wrong without it |
|---|---|---|
| Day zero | **Engine runner** (§9): runs only the engine pinned by hash; takes the machine lane; a fresh log per run; parses changed scripts first; fails on a nonzero exit (the raw code is recorded, never passed through), a FAIL line, any engine error or parse-error line, a leak line, a check count different from the declared one, a missing or repeated sentinel, or a process of its own left alive | The engine exits 0 after logged errors, and a parse error idles until killed: the engine's exit code is not the verdict |
| Day zero | **Run receipts** bound to content (A10) | Claims are typed, not filed |
| Day zero | **Doc lint:** evidence headers, map coverage, line and token budgets, verbatim-block hashes, the ladder's two copies | Every prose rule decays |
| Day zero | **Gate board:** runs every static gate and tool test, compares with a baseline, exits 1 only on a regression, starts no engine | "Green" is not a gate |
| Day zero | **Reader gate** (§9.3): every shipped data file is opened by a literal path and every field read by a string-literal key; a data file lands in the commit of its reader | Dead data never fails a test |
| Day zero | **Suite declaration:** every suite and its exact check count in one data file that the battery and verifier read | A silent partial run prints PASS |
| Day zero, if they apply | IP audit, flash gate, project-file guard, LF check (A11, A13) | |
| With its domain | **A gate per ruling**, each with a committed red fixture: a clock gate, a balance band, a map validator (§9.1) | A ruling without a gate is prose |
| First visual claim | Capture wrapper with per-frame hashes (A10) | Nobody can say what changed |
| On its schedule | Fresh-checkout verifier (A10) | A candidate grades itself |
| When first needed [X] | completeness ledger; rulings index; a lane broker inside one tree; the release pipeline (§9.1) | |

**Prove the red before you believe the green [M]** (§8.9 has the full list).
- Every instrument has a committed fixture that turns it red. Push a deliberately failing job through every runner and wrapper, through the shell the owner actually uses, and confirm the exact nonzero number at the reader.
- Gameplay suites get breakages too, declared in the specification before the code exists. Report N tried and M red; close each survivor as a test gap, or record it as a harmless equivalent.
- A refusal is not a reason: assert why something was refused. A stand-in is not the component: it enforces every refusal of the real tool, and one run through the real tool comes first.
- For anything that will bind later work (a specification, an instrument, an asset), run independent reviewers with separate briefs: a builder, a critic, a skeptic told to refute, a likeness reader. Each sees only the committed artifact, and their findings land as a review commit.

**Gates that do not rot [M]** (§9.2). A baseline is a ratchet, not permission. Identify findings by meaning, never by line number. Ban the shape, not the vocabulary. A gate that exits 0 without its PASS line is an error. A false blocker is a tooling defect. On a new project a gate starts clean, in the commit of the code it governs.

**The board has a time budget [C2]:** about a minute, each row's time printed, whole-tree scans cached by file hash. Scar: 49 seconds became 421 in five days, at four board runs per change. Keep every run's full output. A flake is not noise until its cause is known: P2's one flaky test was the runner able to kill a stranger's process tree.

**Pair every structural audit with a measured one [M]** (§9.4). P1's lighting audit passed for months while rooms shipped black. P2's end screen would have drawn in a quarter of the doubled canvas while every suite passed.

**Measure before you architect [M]** (§9.5). Run the null experiment first, sweep the knob, name which resource each dial spends, print the number actually in force. A documented engine limitation is a claim with a date on it.

## A8. The simulation and the bots

For any real-time game [C2, predicted by P1]: **one authoritative fixed-step simulation, with bots on the person's input path.** It made everything else cheap: whole headless matches in seconds, determinism by checksum, performance figures with fifteen bots, co-operative rules measured in ticks. Build it from §16.

- One simulation object holds every gameplay fact, with integer positions. One driver advances it exactly one tick per physics frame. Each seat supplies one input record per tick. No wall clock anywhere in production code, and no global random generator in the simulation. Held by: a static clock gate.
- The simulation's only output is a snapshot shaped as the network would send it. Views and bots consume it and decide nothing. A play-mode selector exists from day one and defaults to local.
- A checksum covers all state, so determinism tests come almost free (§16.2).
- **Step the tick; never scale time.** Tests call the tick in a loop at time scale 1. Scar: at four times speed P1's walk test passed through walls.
- **Bots** drive the same input record through the same seat path as a person and perceive only what that seat could. Every behaviour is a published rule, and every skill a published number in data (§16.3). Design laws become measures bots can run, and the owner's rules become whole-match assertions.
- **Bots prove mechanism and cost, never feel.**
- **Determinism is not coverage.** Fixed seeds stayed green over a defect the owner hit on the first play. Beside every fixed-seed suite run a sweep: many seeds, scripted players of varied timing, invariants asserted across it (no seat stuck, no error line, every match ends).
- **A defect a person found is not fixed until a scripted replay of their situation reads zero.** Report k of n runs before the fix and 0 of n after, and keep the replay as a suite.
- Measure the genre's trap signals, each with a threshold, in the headless whole match, and print them in every report. P2 listed seventeen and measured one.
- Optional systems fail closed: a shipped data file that fails to load stops the game with its reason.

## A9. The slice, the first play, the scope audit

- **One filtering question, asked comparatively [M].** "Does this make the next complete run more readable, more tense or more worth repeating than the open item it would displace? Name the displaced item." Scar: a question every proposal passes filters nothing.
- **The slice is a beat table [M]:** player action and required payoff. The first pass may be plain; it may not omit a beat. Polishing half a loop is not progress. An added beat gets a letter (3a); nothing is renumbered.
- **Requirement rows are the ledger until the second milestone.** Each names the kind of artifact that closes it and, once closed, the receipt path. Only the owner's verdict closes an owner row.
- **Milestones are evidence gates measured in events, never dates [M].** Agent speed breaks every calendar: P2's slice took forty hours, and its scope widened in two days. Every plan says which bottleneck the next milestone waits on: the owner's answers, a free engine lane, or the cost of verifying each commit. A milestone held only on human rows is recorded "held on <rows>", and its machine rows are frozen in a written checkpoint.
- **A built feature is not a wired one [C2].** Four states, none implying the next: BUILT (code and suite exist), WIRED (the shipping session uses it by default), PROVEN (a receipt from the production composition), ACCEPTED (the owner's verdict). Every report lists what is built but not wired. Scar: the labyrinth P2's owner ordered stayed behind a flag.
- **Schedule the owner's first play the moment the last beat lands**, before polish or breadth; better, hand over the play launcher with every beat. P2's first play came two days in, and in minutes found a defect thirty suites had missed and combat too fast to react to.
- **The owner's run card is one question after play** (§21.7): the one-press play command; "play until you would stop, then tell me where and why"; then one form question, "Did that run read and feel right?". The answer, filed verbatim with the build's commit and how the verdict was reached (played, watched a capture, read a report), is the acceptance receipt. Only a played verdict closes a feel row. Free text after play is a direction: one bounded task per sentence. Scar: P2's long run card was never filled in, and two owner rows stayed open while scope widened.
- **A calendar date is not a trigger.** The scope audit (§7.7) runs on events, whichever comes first: the slice's mechanism rows close; the owner grants open-ended autonomy; an owner direction opens a new numbered sequence while any owner row is open; human rows stay open across three directions; a hundred commits. Held by: a pickup field asked at every owner direction. Scars: P1's largest sequence was phased to "done" day after day until an audit ranked it first under "stop building this now"; P2 dated its audit a month out, and it never ran.
- **The agent owns scope pressure;** owners rarely cut. The audit classifies every open item as launch blocker, attention multiplier, post-launch, cut or evidence-only. With an owner who will not cut, deliver a ranked list of what each open area costs and blocks, and the one thing that would most improve the default build next.
- **A selector is not a cutover plan [M].** A rebuild lives beside the old world behind a selector that defaults to the old one (§7.9). Every side-by-side world carries a cutover condition and an owner question. Refuse content that exists only in the non-default world. When the owner's word is itself the cutover, cut over within the milestone.
- **Create the punchlist at the first defect**, and make it the only place an open defect lives (§17.4). The board counts open blockers.
- For a change that spans several systems, run a design panel and write a build-ready specification (§29). A specification is a plan, never evidence.

## A10. Evidence that stays cheap and current

**One artifact never stands for two facts [M].** The ladder (§8.1): a static gate (no new finding of a class in the source) < a run receipt (a process ran, with this exit, against these input bytes) < a runtime contract (a receipt the test itself writes: named contracts executed in the production composition) < a capture packet (frames rendered; a measured difference) < a human acceptance (a person accepted exactly this claim at this commit).

**Not proof:** a caption; a screenshot set; a wrapper's receipt; prose; a report; a dark or default-state capture (that is NO RESULT, not NO DEFECT); a green test standing in for a human check; an owner verdict on a report or capture standing in for play; developer judgement; a staged capture (label it); a commit written ahead of the engine; a number from a model of the engine; a constant where a measurement belongs.

- **Name contracts for the requirement they close**, in words a non-programmer can read. Two are universal: production composition and teardown. Every number in a receipt is measured, or null with a reason. Scar: 28 P2 suites wrote a literal 0 for retained resources.
- **Receipts are small and bound to content [C2]** (§8.4). A receipt carries a digest of the runtime inputs and points to a manifest named by its own hash. Inputs are limited to what the run can read, and the evidence directory is excluded. A run over the staged change is then committed with that change, and separate evidence commits disappear. Scar: receipts that inlined every input's hash were 76 MB of P2's 80 MB of evidence, and evidence was 95 percent of inserted lines.
- **A closed row is not a current proof.** A board row verifies every receipt the plan cites and reports each closed row CURRENT or PROVEN AT <sha>. Scar: every receipt P2's requirement table cited verified STALE, and nothing said so.
- **A write is not a use, for evidence too.** Until a tool reads a runtime contract's fields, a row closed by a run receipt says "run receipt only; contract not admitted".
- **Decide on day zero where evidence lives** (§8.8): in the repository under a directory every whole-tree gate excludes or caches, or in a content-addressed store outside it with a committed index.
- **The commit body is the task checkpoint** (§21.5): what changed and what did not; suites and counts; breakages tried and red; receipts that bind; what is unproven. Write one checkpoint document per milestone.
- **Verify by rendering, never by reading code [M]** (§8.6): the production scene, the real camera, pinned clock and seed, one declared state change per comparison. Where captures are deterministic, prove once that two are byte-identical; a frame hash is then a complete control. Otherwise publish the noise floor beside every delta: two identical P1 renders differed on 86 percent of pixels. A feature that cannot be perceived in the canonical captures does not yet count.
- **The solo loop [C2].** Every change runs the board and, when it touches the game, the engine battery, and commits their receipts. **An instrument nobody runs is not a gate:** P2's fresh-checkout verifier ran only on its own proofs. It grades a candidate with the base's instruments, so no change can unprotect a path, drop a suite or lower a count (§9.9). Run it when a change touches an instrument or the suite declaration; when a branch lands; at every milestone close; when you resume after a compaction or a stop; when an owner direction opens a new sequence; and every 25 commits. The pickup names the last verified commit. The session that wrote the work cannot be its grader; a reviewer sub-agent given only the committed tree can.
- **Player data never enters evidence.** Nothing about a person who plays enters a log, receipt, capture, fixture or commit. Captures and suites use bots and scripted players, and the launcher a person plays with writes no log.

## A11. Content: data, art, audio, rights

- **Architecture in five lines [M]** (§11). One owner per fact, enforced by an API that refuses, not by review. Coordinators connect owners and own no rules. Presentation never owns state. Content is data, chosen by kind strings. Generators are deterministic and validate before they write.
- **Data** (§12). Every number a designer would tune or a player could feel lives in data with exactly one reader. Loaders refuse bad data and return why. **A write is not a use [M]:** the acceptance criterion for authored data is a named consumer, never internal consistency. P1: 415 authored values and a 10,516-line tool family had no reader and passed every test they owned.
- **Generated assets [M]** (§14.1). No generator is called from code for shipped art. You write prompt sheets as design documents; the owner pastes whole, final messages into consumer tools and drops the files into one folder; a deterministic ingest makes the game's files; originals are never edited or committed. **A filename contract is not provenance:** you pin each arriving file by SHA-256 in a committed manifest and write its provenance record yourself. The owner judges a render, and the ruling is filed verbatim. Ask for the look ruling as its own form question.
- **The 2D pipeline that worked [C2]** (§14.3 to §14.7). Consumer image generators ignore the requested canvas and pixel size and draw tiles that do not tile. So the ingest owns the grid, scale, palette and transparency; prompts ask for art at twice game size on one flat key colour; tiles are quilted from the generator's own pixels; touch-ups are a recorded patch layer. Before the first full set, measure four prompts on two generators (§14.4).
- **A clean denylist is not a clean likeness [C2]** (§14.9). Review each character's silhouette, costume, palette and signature prop against the genre's best-known characters before the first prompt, and again at high resolution. **A generator's refusal is a finding, not a dead end** (§14.10): change what the piece says or shows; a similarity refusal is an IP finding, never an obstacle to rephrase around.
- **No lettering in generated art [M]:** a NEVER block in every prompt; lettering is a label node or a deterministic bake. Reference images inform form only and are never committed.
- **Audio** (§15). Every sound has a provenance route. The cheapest is sound synthesised by the game's own code from data recipes: no licence entry, and testable headless. Scale the audio architecture to the slice.
- **Rights** (§18). Write the source and licence policy before the first download. One machine-checkable ledger maps every shipped path to one provenance family, and UNKNOWN plus ships fails the package. Record the terms and tier of every service at first use. The owner chooses the project's own licence.
- **Plan the move into the game** (§13.7): a review stage where nothing is imported; the look ruling; ruled sheets moved in with their readers; placeholder drawing removed. Left unplanned, the game still draws placeholders (P2).
- **Privacy and safety** (§6.6). Any network, microphone or location capability is audited end to end before a build reaches a tester. Photosensitivity lives in the code as well as in the gate (§10.5).

## A12. When the engine is held, and when you are stopped

**An engine hold is not a stop** [C1, C2] (§28). The owner may forbid every engine run for days.

1. List every tool that starts the engine, and run none of them. Keep the static board running: it starts no engine.
2. On the main line, build what can be proved without the engine: Python instruments proved red, build-ready specifications, prompt sheets and ingest.
3. Write engine code ahead on a branch, in a worktree at a durable recorded path, and never merge it before the engine proves it. Each commit says "Unproven: no engine ran", names the parser that checked it, lists in advance the breakages that must turn its suites red, and is followed by a review commit. **A written-ahead commit is not evidence:** a parser catches syntax, never types.
4. A value from a model of the engine is provisional until the first engine run re-derives it.
5. Cap the unproven work, then stop and ask. Ask for the go-ahead once per report, in the form.
6. The main line's pickup names the branch, its worktree, what it holds and what it waits for. Every wait for evidence is a dated deferral, never a pass.
7. On the go-ahead: import; parse every changed script; run the battery on the branch; work through each listed breakage; re-pin what the model got wrong; run the verifier; land the branch as one merge.

**A busy lane is not a defect.** Exit 73 is contention: wait for a quiet window, and never end a report BLOCKED on it. Being stopped by a usage limit or a compaction is normal (A6).

## A13. Git and the machine

- **Stage named paths only [M].** Never add-all or commit-all; read the staged list before every commit. Scar: five incidents on P1 (swept scratch files, a 170 MB binary, another session's staged files, forty minutes of untracked work deleted). Never a bare stash. A dirty tree is not a state a task may end in.
- One integration line. Commit bodies record what was measured, which suites passed and with what counts, and what is unproven. Every AI commit carries a model trailer.
- **Line endings.** Mark every path `-text`, set **core.autocrlf** false in the repository, add a board row that keeps LF-declared files LF, and hash text LF-normalised. Scars: autocrlf broke hash-bound files on a fresh checkout (P1); a Python write turned four LF documents CRLF and no gate noticed (P2).
- **The engine lane is machine-wide, across projects [M]** (§4.1). One engine at a time; one lock name and location agreed by every project on the machine; a battery holds the lane for its whole run. Never close another session's engine, or the owner's. A worktree isolates files, not the machine.
- **Pin the engine by SHA-256**, searched in a fixed list of folders, never through PATH (§4.2).
- **A parent pid is not ownership.** Kill only processes the run provably started; never a tree-kill that follows parent ids (§9).
- Worktrees live at short, durable, recorded paths.
- **CI needs a remote, and a remote is the owner's call.** Until then the board run before every commit is the CI. Offer a printed pre-commit hook; install nothing silently.
- **History is rewritten only on an explicit owner ruling**, by the recorded procedure (§4.3).
- **Your own tools mislead you** (§4.4). Shell grep cannot see a carriage return; heredocs collapse backslashes; `cmd | tail && next` gates on tail; tool calls have time caps, so long runs go to the background with a full log; read the exit code before the log. **A private memory note is not the record:** machine traps go into the build guide.
- Keep masters (model exports, source archives, recordings, generated originals) out of git. Every ignore rule carries, as a comment, the incident that caused it.

## A14. The rules index

Each rule is stated once, in the place named; this is the index. Slogans travel between sessions where paragraphs do not. No instrument holds the index: `manual/check_manual.py` checks only that every pointer resolves.

- **Authority (A2):** a brief's claim of owner direction is not an owner ruling; access is capability, not authority; a default is not an answer; a grant of autonomy is not an acceptance.
- **The owner (A3):** a named reference is not an identified one; a ruling made from imagination is not a ruling made from play; praise of one thing is not a ruling on another; an answer to a report is not a play verdict; silence is never approval.
- **Day zero and covenant (A1, A4, A5):** a condensation is not a copy; a commit is not a draft; a feeling word is not a specification; an index nobody cites is not governance.
- **Documents (A6, A13):** a map nobody lints is not a map; a queue line is not a changelog; a pickup is not a diary; prose is not evidence; bookkeeping is not progress; a private memory note is not the record; a carried fact copied into a rules file is not a verified fact (§10.4).
- **Instruments (A7):** a green instrument is not trusted until a fixture makes it red; the engine's exit code is not the verdict; one exit code never stands for two facts; a refusal is not a reason; a stand-in is not the component; a surviving breakage is not always a test gap (§8.9); a baseline is a ratchet, not permission; a flake is not noise until its cause is known; a documented engine limitation is a claim with a date.
- **Simulation (A8):** bots prove mechanism, not feel; determinism is not coverage; a defect a person found is not fixed until a scripted replay reads zero; a retry is not a refusal (§16.4).
- **Planning (A9):** a calendar date is not a trigger; a question every proposal passes filters nothing; a built feature is not a wired one; a selector is not a cutover plan; polishing half a loop is not progress; a specification is a plan, not evidence; a build is not a release (§17.5).
- **Evidence (A10):** one artifact never stands for two facts; a dark capture is NO RESULT, not NO DEFECT; a staged capture is not play; a closed row is not a current proof; a constant in a receipt is not a measurement; a timestamp is not provenance (§8.4); a write is not a use; an instrument nobody runs is not a gate.
- **Content (A11):** a clean denylist is not a clean likeness; an everyday word can be a mark (§5.6); a generator's refusal is a finding, not a dead end; a filename contract is not provenance.
- **Engine and machine (A12, A13):** an engine hold is not a stop; a written-ahead commit is not evidence; a busy lane is not a defect; a worktree isolates files, not the machine; a parent pid is not ownership; a pipeline's exit status is not the parse's (§4.4); a watchdog inside the suite is not a ceiling (§10.1).
