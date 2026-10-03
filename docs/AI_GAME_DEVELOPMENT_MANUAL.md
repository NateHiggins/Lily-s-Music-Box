# THE AI STUDIO MANUAL

*How a game gets built by one human creator and an AI engineering team, as
learned on this repository, written so that an AI coder can run the same
process on a new game from a one-line prompt.*

Evidence class: **INERT - REFERENCE MANUAL**. This document promotes nothing
in any ledger. Identifiers are written in bold, never backticked (RUL-011).

Status: **living document**. First edition 2026-09-26, derived from this
repository at commit **3e46e7b** (1,374 commits, 2026-02-17 to 2026-09-21).
Section 22 says how to keep it current. Where this manual and a ruling in
`design/ORISON_BIBLE.md`, `AGENTS.md` or `design/RULINGS.json` disagree about
*this* project, those win; this manual describes the method, not the canon.

Edited 2026-10-03: added section 5.8 (the oracle front door: starting from
an oracle packet instead of a sentence), template 21.14, and the oracle's
entries in sections 0, 20, 22, 23, 24, 26 and 27. Nothing else was changed.

---

## 0. How to use this manual

**You are the AI coder.** The human hands you this file and one sentence, for
example: *"Build me a battle royale that plays like a knockoff of Zelda in
16-bit style."* Your job is to turn that sentence into a finished, shippable
game with the human as **creator** (taste, fiction, scope, money, public
claims) and you as the **engineering team** (plan, build, verify, report, ask
only what only the creator can answer).

**Two ways in.** The creator may hand you one sentence, or an **oracle
packet**: a game description written by `oracle/` (THE BLANK DECK), a short
text adventure that derives a design from how one person plays. A packet
replaces the sentence, not the method. Section 5.8 says how day zero
changes when the prompt is a packet.

The method has one shape, repeated at every scale:

1. **Capture intent verbatim** and turn it into a covenant that outranks
   everything else (Part III).
2. **Build one complete vertical slice** before any breadth (Part IV).
3. **Prove every claim with a file a second tool can re-check**, never with
   prose or a typed exit code (Part V).
4. **Let a human accept player-facing work**; a green test is not one of the
   checks (Part VII).
5. **Write down every hard lesson as a checked rule** so it is never relearned
   (Part IX).

**Day zero and day one are the same day:** the day the prompt arrives.
Read in this order on that day: section 0, section 5 (day-zero protocol),
section 23 (day-one checklist), then Part V before writing any tool. Read
Part X (the worked example) when you receive the prompt. Everything else is
reference.

**Scaling.** The source project is a first-person 3D horror game with a
procedural building, eighteen simulated residents, two AI agents sharing one
git tree and roughly 83 verification tools. A small 2D game does not need all
of it. Section 24 says what to skip. The parts that never scale down are the
covenant, the vertical slice, the receipts and the human gate.

**Where the evidence lives.** Every practice here cites the file in this
repository where it can be read in the original. When a citation and this
manual disagree, read the file.

---

# PART I. WHAT HAPPENED HERE

## 1. The source project in one page

**The game.** *Please Remain On The Line*: a 1928 Queens apartment block, the
Orison, where sound moves through the building's wiring. The player is a
night-shift maintenance tenant. Godot 4.7.1, Blender, Python. Repository
`github.com/NateHiggins/Lily-s-Music-Box`, checked out at
`C:/PleaseRemainOnTheLine`.

**The team.** One owner. Claude Code sessions (author trailer
`Co-Authored-By: Claude ...`, long narrative commit bodies). An OpenAI Codex
agent called **Astra** (model `gpt-6-astra` at ultra effort, no approval
prompts, full sandbox access per `C:/Users/nate_/.codex/config.toml`; short
imperative subjects, empty commit bodies). Both agents commit under the
owner's git identity and share one working tree. The rules file both read is
`AGENTS.md`; `CLAUDE.md` is literally the one line `@AGENTS.md`.

**The timeline of process maturation** (from `git log`, DOCS.md, the
management records and `design/WORKTREE_CONSOLIDATION_2026-09-21.md`):

| Phase | Dates | What happened | Process instruments gained | What it cost |
|---|---|---|---|---|
| Prototype | 2026-02-17 | A Codex-authored Godot mobile MVP arrives as GitHub PR #1. Five months of silence. | A repo. | Nothing yet. |
| Blockout burst | 2026-07-29 to 07-31 | One Claude session lands the 3D building, the audio-virus prototype, the desk-call loop and the first handoff: 34 commits and 248,809 insertions in one day, delivered through owner-merged PRs #2 to #8. First "Merge parallel session" commit. | `HANDOFF.md`, `design/next_session_plan.md`, backup scripts (later a foot-gun, see 9.7). | `git add -A` swept a screen recording and 33 scratch renders into history within 24 hours. |
| Systems explosion | August (1,097 commits, 35 per day typical, 139 on 08-26) | Materials, shops, residents, cases, the dream world, service round apparatus, weather, audio, early-access scoping. Direct commits to main; PRs stop. | `TASKS.md` shared queue (08-09), `DOCS.md` map (08-10), the Bible (08-03), audits with frozen baselines, the capture protocol, run cards, acceptance receipts, the engine knowledge ledger. | A runner reported exit 0 for every failing suite for 334 commits. Every audit tool arrived in one 72-hour burst (08-26 to 08-28, 22,848 lines), the week early access was chartered. Dream breadth grew to "the single largest consumer of recent capacity and the smallest contributor to the promise" before a scope audit noticed. |
| Rebuild beside the old world | 08-28 to 09-14 | The v2 building blockout starts beside v1 behind a selector; a completeness ledger grades every requirement; the M08 to M11 chain lands. | Completeness ledger, evidence intake by filename, runtime-contract receipts, runner exit-code truth, reader gate, the M11 dry-run rehearsals. | Hash-bound artifacts broke on a fresh checkout because of autocrlf. A flattering count (first slice 0 blockers) was repeated four times before a hardened tool showed 7. |
| Governance | 09-04 to 09-19 | The owner mandates Astra as executive; interim management (Claude) evaluates every branch, writes dispatches and the report format, merges with the verifier. 09-18 is the governance day: gate board, receipts, verifier, lane broker, doc lint, rulings index, `AGENTS.md`, all in one day. | `tools/gate_board.py`, `tools/run_receipt.py`, `tools/verify_candidate.py`, `tools/lane.ps1`, `tools/lint_design_doc.py`, `design/RULINGS.json`, `tools/PIPELINE_TOOLS.md`. | Two lines both believed they were canonical and diverged into a 26-file conflict. Work existed in no git ref (2,081 uncommitted files in the main checkout) and had to be rescued. |
| Consolidation and cutover | 09-19 to 09-21 | 34 worktrees become 7 then 1; 18 checkouts become 1; branches are tagged before deletion; V2 becomes the playable default in three small commits with an explicit rollback switch. | Archive-then-remove sweeps with SHA-256 manifests, `tools/lanes.py`. | About 40 GB of archives and a long-path failure during removal; the drifted instruments of section 9.7 were left standing. |

The whole arc is the lesson: **every instrument in Part V was built after the
loss it prevents.** Build them before you need them. The cadence numbers
(a median of 5 files and about 200 changed lines per August commit; 52% of
August commits touching both code and a document) are what "small, documented commits" looks like
in practice.

**The two repositories.** A second project, the Semantic World Compiler at
`C:/FPSengine01`, builds the arcade machines and hands over a hashed,
proven build output through a documented contract (`DOCS.md` "The two
repositories"). The pattern for any external generator is in 13.6.

---

# PART II. THE OPERATING MODEL

## 2. Roles and authority

The source project ran as a small studio with written roles. Names are
Orison's; the shape is generic.

| Role | Who | Owns | Never does |
|---|---|---|---|
| **Owner / creator** | the human | Taste, fiction, scope, money, public claims, release, anything irreversible. Rules by one-line chat decisions or long pasted mandates. | Verifies receipts by hand; that is the team's job. |
| **Executive** | one agent under a written mandate (`design/astra/OWNER_MANDATE.md`) | Content direction, the live completion ledger, an append-only decision log, a risk register, work sequencing. Splits internally into a root that owns commits and scoped sub-agents that review without staging. | Cutover, release, retirement of the old world, destructive deletion, paid review, mutually exclusive creative choices: reserved to the owner. |
| **Management** | one agent, usually the other vendor | Evaluates every branch against main, writes dated dispatches with a serial queue and a gate-to-start per task, defines the report format, re-verifies every developer report in a fresh worktree, merges with `--no-ff` on owner authorization, keeps `AGENTS.md`, `DOCS.md` and the rulings index current, does housekeeping. | Accepts a report on trust. |
| **Developer** | any agent taking one dispatched task in its own worktree | Closes the task with a clean tree and a report ending in one machine-checkable line. | Grades itself with an instrument it rewrote in the same change. |
| **Verifier** | a tool plus a discipline | `tools/verify_candidate.py`: fresh checkout, gate board versus merge-base, protected paths, doc lint, Godot suites with receipts, report sidecar compared claim by claim. The discipline: one analyst and one skeptic per group; management writes its own errors into a "Correction to the record" section. | Manufactures a greener answer than the underlying check gave. |

**What the owner reserves, written down.** The mandate lists boundaries no
agent crosses alone (`design/astra/OWNER_MANDATE.md` section 20): adopting
dirty work with unreconstructable provenance, mutually exclusive creative
decisions, paid external review, production selector cutover, public claims
and release, retirement of the old world, destructive deletion of recoverable
history. Everything else is delegated as "proceed autonomously through
reversible, in-scope work". Copy this list on day one and add to it; it is
the difference between an autonomous team and a runaway one.

**Owner instructions are quoted verbatim, dated, and filed before anyone
acts.** Long mandates are attached with their SHA-256 recorded so the ruling
is citable forever (`design/astra/AUTHORITY_HIERARCHY.md`). One-line chat
decisions ("remove yes, merge yes, clean yes") are quoted where they bind and
cited as "owner instruction in chat <date>".

**Repository access is capability, not authority.** A style directive's
clause "do not stop at proposals if repository access allows implementation"
was struck on process grounds before any of its 33 phases was read
(`design/ORISON_STYLE_DIRECTIVE_INTEGRATION_RULING_2026-08-29.md`). An agent
that can edit a file has not thereby been asked to.

### 2.1 Precedence when documents disagree

Apply this ladder, top wins (`DOCS.md`; `design/astra/AUTHORITY_HIERARCHY.md`):

1. The latest explicit owner ruling.
2. The covenant (Bible) for fiction; the newest dated ruling inside it.
3. The player-facing ethos (`design/VIRTUAL_ENVIRONMENT_ETHOS.md`).
4. Migration and save contracts.
5. Current machine-encoded canon and authored data.
6. Scoped checkpoints and human acceptance receipts, for exactly the commit
   and claim they name.
7. Plans, audits, task lists, prose. "Assertions of present state are
   hypotheses until matched to current source and receipts."

**On a new project, use this ladder and no other.** Write it into `DOCS.md`
and into the covenant's first paragraph in the same words (template 21.2).
The source project kept two ladders, one in `DOCS.md` with the covenant first
and one in the authority hierarchy with the latest owner ruling first
(section 25). Do not copy that split.

**Do not pick a side quietly.** A disagreement goes into the covenant's
Disputed Texts section with an interim that holds until ruled, or into an
**AUTH-nn** conflict table (claim | ruling and concrete consequence). When
two lines both claim to be canonical, write the ruling with its reason and
offer the owner the reverse, priced: "Ruling: one canonical line, and it is
main", followed by what sequencing the reverse would cost (RUL-002;
`design/ORISON_V2_INTERIM_MANAGEMENT_EVALUATION_2026-09-16.md`).

### 2.2 The rulings index

Standing rulings get a stable id so briefs, critiques and reviews cite
**RUL-nnn** instead of restating a sentence (`design/RULINGS.json`, schema
`orison.rulings.v1`; `tools/check_rulings.py`). The index is append-only and
explicitly not an authority: every entry names its source, and the source
wins. Retire a ruling only by appending a later one that lists it under
**supersedes**. The checker validates ascending ids, that in-tree sources
exist, and fails the build if any tracked text file cites an undefined id.
The executive keeps its own append-only decision log (**ASTRA-Dnnn**,
`design/astra/DECISION_LOG.md`) whose entries name hashes and say what they
do *not* prove.

Create the index on day zero with an empty list; the checker exits 0 on it.
The top-level shape is `{"schema": "<game>.rulings.v1", "note": "<an index,
not an authority; append only; checked by tools/check_rulings.py>",
"rulings": []}`. Template 21.13 gives one entry. Make the checker exit 1 on a
non-ascending id, a missing in-tree source, an unknown superseded id, or any
tracked text file that cites an undefined id. A branch-qualified source is a
warning, not a failure.

### 2.3 The dispatch loop

One task moves through five documents:

1. **Dispatch record** (management, dated, INERT): where the work actually
   is, findings on in-flight work, findings on main, rulings made by
   management "owner may override", a serial queue (each task reports before
   the next starts), decisions only the owner can make, the required report
   format, later appended reviews and the merge record.
   Example: `design/ORISON_V2_INTERIM_MANAGEMENT_DISPATCH_2026-09-13.md`.
2. **Developer report** in the fixed format (section 2.4), optionally with a
   committed JSON sidecar (`orison.dispatch-report.v1`, fields in
   `tools/PIPELINE_TOOLS.md`) that the verifier checks claim by claim.
3. **Verification** by `tools/verify_candidate.py` in a fresh worktree,
   output `verification.{md,json}`, last line `MERGE-CANDIDATE <sha>` or
   `BLOCKED <reasons>`.
4. **Merge record** appended to the dispatch document: sha, what was
   accepted, what regressions were owner-ruled (`--accept-regression`),
   what remains open. Land each accepted candidate as one `--no-ff`
   integration merge so the whole landing reverts with
   `git revert -m 1 <merge sha>`. Append a row per landing to an integration
   register: exact sha, named changes, status and consumer, proof,
   protected-path verification, actual exits, limits, and the rollback
   command written out. Record that no rollback was executed when none was
   (`design/astra/INTEGRATION_REGISTER.md`).
5. **Correction to the record** when management was wrong: dated, in place,
   reopening every decision the false finding closed (evaluation of
   2026-09-16 section 7: a number repeated four times without checking the
   receipt).

### 2.4 The developer report format

Copy this shape exactly (`design/ORISON_V2_INTERIM_MANAGEMENT_DISPATCH_2026-09-13.md`
section 7). The last line is machine-checkable.

```
REPORT - <task id> - <date>
Evidence class: INERT
Branch / HEAD / origin/main / merge-base:
Worktree clean at end: yes|no (list anything left)
Protected paths: n/n      Selector: <value>
Ledger before -> after: <counts> -> <counts>; requirements_changed: [...]
Gates (real exit codes, with -LogPath): <each static gate> / <each tools test>
  / <each engine suite with its PASS line and receipt path>
Numbers management asked for:
Changes outside the expected file boundary, and why:
Open findings not fixed:
Decision needed from owner:
Last line: MERGE-CANDIDATE <sha> | BLOCKED <reason> | NEEDS-OWNER <question>
```

Rules that go with it: cite the receipt file, never a typed exit code; report
a nonzero-but-known exit as nonzero; a dirty tree is not a state a task may
end in; a report is not a consumer and proves nothing by itself.

**Never delete a field from this format.** When a field does not apply yet,
write none and give the reason. Write "Protected paths: none declared" until
the owner freezes a file or rules a first cutover; after that, declare them in
`design/PROTECTED_PATHS.json` as a list of {path, sha256 of LF-normalized
bytes, ruling id} and make the verifier read it. Write "Selector: none" until
a rebuild runs beside an old world (section 7.9). Until the completeness
ledger exists, write the ledger line as the counts from the requirement table
in the execution plan.

### 2.5 Reviews between agents

Before another agent implements a change, write a pre-implementation review
and have that agent accept it as the adversarial contract. After landing,
review read-only against exactly the points declared beforehand, and list
owner-accepted deviations as not-defects so they are not re-litigated (the
Juno dream review on the source project: ten pre-declared points, two
owner-accepted deviations). File every review as a pair: `review.md` with the
prose verdict and `review.json` with schema, status, head, checks passed of
total, dependency hashes verified, and required_changes as {id, kind, path,
line, finding, repair} (`design/astra/reviews/`). Reviews meant to be pasted
to the other agent go in one fenced block.

### 2.6 One agent, one human

With a single agent, play the developer in one session and management in a
separate later session that reads only the committed report and the tree.
The management session runs the verifier itself. The owner never runs the
verifier and never checks a receipt. The owner's standing licence (section
5.4) lets management merge a MERGE-CANDIDATE into main with `--no-ff`.
Anything on the reserved list still goes to the owner. Keep the reserved list
and the licence sentence in `design/OWNER_MANDATE.md` (INERT), created on day
zero even when no agent holds executive authority.

## 3. The document system

### 3.1 One map file at the root

`DOCS.md` is the map: a numbered precedence ladder, a table of document
**kinds** with a trust level each, a "where to look for..." question-to-file
table, and an "adding a document" rule. It was created on 2026-08-10 by a
documentation audit that found four documents claiming the wrong engine
version. Create yours in week one, before the fourth document exists.

| Kind | Trust | Where |
|---|---|---|
| **Covenant** | Binding until the owner amends it. | `design/<GAME>_BIBLE.md` |
| **Reference** | How a subsystem actually works. Kept current. Written *after* the code exists. | `game/docs/`, `art/docs/`, `docs/` |
| **Brief / proposal** | Not canon until ruled. Says so in its first line. | `design/*_BRIEF.md` |
| **Direction** | The owner's own words, verbatim, never edited. | `design/*_DIRECTION*.md` |
| **Prompt sheet** | Inputs to asset generation; historical once used. | `design/*_PROMPTS.md` |
| **Brief in data shape** | Design written as JSON but read by nobody; kept out of the data tree so it is not mistaken for game data. | `design/*.json` |
| **Queue** | Open work, one line each, deleted when done. | `TASKS.md` |
| **Audit** | Evidence with a method and confidence levels; findings graduate to the queue, the audit stays as the record. Never edits what it audits. | `design/AUDIT_*.md`, `design/*_LEDGER.md` |
| **Checkpoint / receipt** | Evidence for the ledger. Admitted by filename marker only. | `design/<PROGRAM>_*_CHECKPOINT_<date>.md`, `*_RECEIPT_*.md` |
| **Build guide** | How to build and verify. Mechanics only. | `HANDOFF.md` |
| **Rules for agents** | Standing practice relearned the hard way, each rule tagged with its ruling id. | `AGENTS.md` (read by every vendor through `CLAUDE.md`) |

Three status documents, three jobs, never duplicated: the roadmap, the live
queue, the build guide. "Two copies of a status always disagree, and the
reader has no way to tell which one is lying." When overlap happens anyway,
log it as a disputed text and edit the offender to carry the interim.

The adding-a-document rule stops sprawl. A rule goes in the covenant as a
dated ruling, not in a new file. A proposal ends `_BRIEF.md` and says in its
first line that it is not canon. A task is one line in `TASKS.md`, or it
needs a brief. Then add the new file's row to the map, or nobody will find it
(`DOCS.md`).

### 3.2 The evidence-class header

Every design document states its class in its first 30 lines:
`Evidence class: **INERT**` for reports, briefs, dispatches, plans and
manuals; a checkpoint or receipt names itself as evidence. A ledger admits a
document by its **filename marker** (CHECKPOINT, GRAYBOX, ACCEPTANCE,
RECEIPT, VERTICAL_CORE, SCHEMA_GENERATOR) and refuses a marker-named file
whose header says INERT; a header never admits a document the name does
not. Inert documents write identifiers in **bold**; evidence documents write
them in backticks, because a backticked id in an admitted checkpoint promotes
that requirement. `tools/lint_design_doc.py` errors when header and filename
disagree and prints the ledger's evidence impact for evidence documents. Run
it before committing any design document.

Why: the ledger once globbed every design document, so a bug report that
mentioned a room id promoted the room it reported (RUL-011;
`design/ORISON_V2_COMPLETENESS_LEDGER_GUIDE.md`). Prose is not evidence.

**On a new project, choose the evidence prefix on day zero** and write it
into `AGENTS.md`: the game's short name in capitals. Name every evidence
document `design/<PREFIX>_<MILESTONE>_<MARKER>_<date>.md` with CHECKPOINT,
ACCEPTANCE or RECEIPT as the marker. Drop GRAYBOX, VERTICAL_CORE and
SCHEMA_GENERATOR; they name source-project programs. The lint and the ledger
read the prefix and the marker list from one shared constant.

### 3.3 The task queue

`TASKS.md` rules, verbatim in spirit: add to the bottom of a section; ids are
permanent and never renumbered; claim by putting your name on the line; no
name means unclaimed; lettered section prefixes (**K** core loop, **D**
decisions, **H** housekeeping, one letter per subsystem) so two agents adding
at once do not collide; one line each, or it needs a brief; delete when done
because git is the log; if a task is wrong, say so on the line rather than
quietly removing it. The **D** section holds only things "blocked on someone
choosing", never on effort.

### 3.4 Session pickup

Each session starts at `design/next_session_plan.md` ("NEXT SESSION, START
HERE"), rewritten by **prepending** a dated pickup block over the previous
one so old pickups stay as history. A pickup block carries: read first in
this order; immediate next action; execution order; non-negotiable
constraints; open owner decisions; the next deliverable to the owner; and
the rule "Do not silently select one of the gated dream items; ask". A parallel
creative lane (the songbook) ran on its own bridge plan and delta log so
re-entry "is a read, not an archaeology dig"
(`design/ORISON_SONGBOOK_BRIDGE_PLAN.md`, `design/ORISON_SONGBOOK_DELTA_BRIEF_0815_0820.md`).

### 3.5 Production-contract documents

When a subsystem lands, write one file beside it in `game/docs/` with a fixed
header: *"Landed as <milestone> on <date>. The ruled experience remains in
<brief>; this file describes the runtime that exists."* Then: **Scope** (one
paragraph of what it is, one list of what it deliberately does *not* do);
**Owner graph** (an ASCII tree of who calls whom, drawn from real call
sites); **Saved facts** (every persisted key and what is explicitly not
saved); **Signal contract** (each signal, emitter, and exactly when);
**Restore rules**; **Proof** (test scenes by name with N/N counts);
**Deliberately deferred**. When a subsystem replaces another, prepend a dated
supersession banner and a dependency census (migrate / retain / replace /
archive) instead of rewriting. Example: `game/docs/core_loop.md` with its
"Authority by owner" table (Owner | Owns | Does not own); `game/docs/service_set.md`.

### 3.6 Direction documents

A long owner prompt is saved as its own file: title
*"<SUBJECT>, OWNER DIRECTION (<date>), verbatim"*, an italic preamble saying
the file is the ruling and is not edited and naming the separate brief that
is the build log, a rule, then the owner's text untouched. Engineer commentary
is confined to labelled italic notes ("Renderer note (Claude): ...") or an
appended migration record. A Status section may grow beneath the quote;
corrections come as new files that name what they supersede. Even a one-line
remark is preserved as a quoted open item. Examples:
`design/DREAM_TENTACLE_DIRECTION.md` through `_3.md`, `design/MODEL_28R_DIRECTION.md`.

### 3.7 How a brief becomes canon

1. File `design/<NAME>_BRIEF.md` whose first line says *"Proposed <date>.
   Not canon until the owner rules."*
2. Quote the owner sentence verbatim at the top. Read it as N enumerated
   decisions. Measure before arguing. Separate what is already true from
   what is new ("four of the five claims are already shipped canon under
   other names, so most of this is ratification").
3. Adopt / amend / reject in tables, each adopted item naming the file it
   will live in.
4. End with numbered **owner decisions**, the safe defaults you applied under
   the standing licence (section 5.4) and may be tightened, and "the risk I
   care most about".
5. When the owner rules: rewrite the brief's header with the ruling and date
   ("Status: APPROVED, BINDING PRODUCTION DESIGN"), add a dated line to the
   covenant that cites the brief for construction detail, strike (never
   delete) the disputed item, move leftovers to the **D** queue, and make the
   ruling enforceable by a tool with a baseline where possible.

External and blind input (a style guide written without repository access, a
film reference, a proposal from another model) is **demoted to input, never
authority**: reviewed by independent readers with distinct lenses, sorted
into adopted / amended / rejected with measured corrections, and any
collision with a ruling becomes a named question to the owner citing
document and date. The source project's five lenses were authority, physical
scale, redundancy, omission and steelman. An assessment states its verdict
first, then what the plan already supports, then where the proposal
conflicts, graded BLOCKING, STRUCTURAL, COSMETIC or APPARENT ONLY, then the
cheapest architectural test walked through real call paths, then the changes
not worth making (`design/ORISON_PARANORMAL_PLURALISM_ASSESSMENT_2026-08-29.md`,
`design/ORISON_STYLE_DIRECTIVE_INTEGRATION_RULING_2026-08-29.md`).

## 4. Working in one shared tree

These rules are `AGENTS.md`, each written after the loss it prevents
(`design/ORISON_GENETIC_MEMORY_2026-08-29.md` section 6 lists five
`git add -A` incidents alone).

**Git (RUL-010).**
- Stage **named paths** only. Never `git add -A`, `git add .`, `git commit -a`.
  Run `git diff --cached --name-only` before every commit; the index is shared.
- Never a bare `git stash` or `git stash pop`; the stash stack is shared.
  Prefer a WIP commit. If you must stash, push with a unique tag, capture the
  SHA, apply (not pop), drop by tag.
- Branch from `origin/main`. Main is the one integration line (RUL-002).
  Agent branches are short-lived and named `<agent>/<topic>`.
- Give every AI commit a model-identifying trailer. Write commit bodies that
  record what was measured, which tests passed with counts, what was wrong
  before, what was retracted. Commit the design document in the same commit
  as the code it governs.
- "Untracked" is a statement about your index, not the remote. A stale
  worktree's engine import minted 47 resource-id files with values different
  from origin's; merging them would have rewritten identities silently.
  Never commit an id file that `origin/main` already has under a different
  value.
- A dirty tree is not a state a task may end in.

**Line endings and hashes.** **core.autocrlf** is on for Windows machines.
Anything hash-bound must be listed `-text` in `.gitattributes`, and any text
you hash must be hashed LF-normalized, or a fresh checkout breaks it. Prove it
in a fresh worktree at a short path.

**Worktrees.** Make them at short paths (`C:/ov/...`); deep paths exceed
MAX_PATH and break the engine's import cache. A worktree isolates files, not
the machine (section 4.1). Retire by **archive-then-remove**: annotated tag
`archive/<date>/<branch>` pushed before any deletion, files moved to an
archive with a SHA-256 manifest hashed before and after, a written triage
table the owner approves (`design/REPO_HOUSEKEEPING_2026-09-19.md`). Every
non-main commit is classified (canonical-already-in-main, accepted
candidate, technically-proven-but-human-pending, failed gate, superseded,
evidence-only, quarantined-dirty, duplicate, unknown) with `git cherry`
for duplicates. Work found in no ref is rescued by copy-only snapshot with a
manifest, then committed through a temporary index onto a pushed `backup/*`
branch, never by touching the source tree.

**Remote.** GitHub over HTTPS refused large packs; the fix was
`http.postBuffer=524288000`, `http.version=HTTP/1.1`, and when that was not
enough, `tools/push_chunks.py` and `tools/api_push_main.py`. Keep masters
(model exports, source zips, recordings) out of git; a 400 MB zip commit cost
a full day of failed pushes. Every ignore rule in `.gitignore` carries the
incident that caused it as a comment, so a reader can tell a rule from a
superstition.

**When a ruling lands, sweep the tree.** The day-one backup scripts that run
`git add -A` and the README section that teaches them were never retired
after the ban (section 9.7). `git grep` the old practice across README,
tools, design and HANDOFF, rewrite or delete each instrument that embodies
it, `git rm --cached` anything an ignore rule was added for after it was
committed, and add a static gate that greps for the forbidden command.

### 4.1 The engine lane

One engine process at a time across every worktree (RUL-009). Godot is run
only through `tools/run_godot_serial.ps1` (180 s ceiling),
`tools/run_godot_long_suite.ps1` (1,500 s) or `tools/lane.ps1`. The runner
takes a machine-wide named mutex, refuses if any engine process exists (an
idle Project Manager window held the lane for six hours once), redirects
stdout and stderr to `-LogPath`, and returns exit codes that mean one thing
each: the suite's own exit, **73** lane busy and nothing started, **124**
killed at the ceiling and the suite reported nothing, **78** cannot run.
Never close another agent's or the owner's engine window to free the lane.
`pwsh -File tools/lane.ps1 status` says who holds it; `run` and `batch`
wait with `-WaitMinutes` instead of failing. A fresh worktree needs
`--import` twice before any suite; "Nonexistent function" and "Could not
find base class" in a fresh tree are a stale import cache, not a code bug.

### 4.2 Machine setup a fresh clone must reproduce

None of this is in a tracked file on the source project; write it into your
`HANDOFF.md`. Engine console binary on PATH (the plain exe prints nothing).
**user.name**/**user.email** set to the identity you want in history.
`extensions.worktreeConfig=true` so per-worktree **core.longpaths** can be set,
but make worktrees at short paths anyway. Per-machine ignores in
`.git/info/exclude` or, better, the committed `.gitignore`. No hooks are
installed silently; a hook is offered with `--print-hook` and wired by hand
(`tools/room_gate_hook.py`). There is no CI, no `.github/`, no launch
config and no repo-side agent policy on the source project; the rules live in
`AGENTS.md` prose and the merge-time verifier. That is a gap, not a design
(section 24 recommends CI for a new project).

---

# PART III. FROM ONE SENTENCE TO A COVENANT

## 5. The day-zero protocol

You have received one sentence. Do not open the engine. Do this first, in
this order, and finish it the same day.

### 5.1 Read the sentence as N decisions

Quote the sentence verbatim at the top of a new file
`design/DAY_ZERO_<date>.md` (INERT) with its SHA-256, then decompose it.
The source project did this for every owner sentence ("Read as five
decisions", `design/DREAM_ENCROACHMENT_BRIEF.md`). For *"Build me a battle
royale that plays like a knockoff of Zelda in 16-bit style"*:

| Fragment | Decision it encodes | Already implied | Genuinely open |
|---|---|---|---|
| battle royale | a last-player-standing mode: many players, a shrinking arena, looting, one winner | the loop shape | player count, online versus local versus bots, session length |
| plays like Zelda | top-down action-adventure verbs: sword, shield, bombs, hookshot-class tools, hearts, keys, secrets, a readable overworld | the verb set and camera | which Zelda (the 2D SNES/GBA lineage is implied by "16-bit"), how much adventure versus arena |
| knockoff | affectionate homage to genre conventions | the register: fond, not parody | the IP boundary (section 5.6), which is reserved to the owner |
| 16-bit style | SNES-era pixel art, limited palettes, tile grids, sample-based music, a fixed low resolution | the art and audio pipeline | exact resolution and palette, chiptune versus tracker, aspect ratio |

Everything in "already implied" you may proceed on. Everything in
"genuinely open" is either a **default you apply under the licence**
(section 5.4) or a **question only the creator can answer** (section 5.3).

### 5.2 Measure what exists before proposing anything

The executive's first milestone on the source project was not code; it was a
read-only **repository truth packet** built from a fresh worktree
(`design/astra/REPOSITORY_TRUTH.md`, `BRANCH_ADOPTION_MATRIX.md`,
`AUTHORITY_HIERARCHY.md`, `DEBT_DEDUPLICATION.md`, `INTEGRATION_SEQUENCE.md`).
On a fresh project the equivalent is a **machine and inventory packet**:
engine version and binary path, DCC tools and versions, Python version,
GPU and display, git configuration knobs (section 4.2), any existing
prototypes, assets, fonts or music the creator already owns and their
licences, and any prior design text. Label every line REPOSITORY FACT (with
path), INFERENCE, EXTERNAL SOURCE (with as-of date) or OWNER RULING
REQUIRED. Assessment documents on the source project carry those four labels
throughout (`design/ORISON_PARANORMAL_PLURALISM_ASSESSMENT_2026-08-29.md`).

Write the packet to `design/MACHINE_INVENTORY_<date>.md` with
`Evidence class: **INERT**`, as one table with the columns Item, Value, Label
and Source. Include at least: operating system and version; engine version,
console binary path and its SHA-256; export templates; Python version; DCC
and image tools with versions; GPU, driver and display; git version and each
knob from section 4.2; the remote URL; assets the creator already owns and
their licences; prior design text.

### 5.3 Ask few questions, once, with defaults attached

Reserve day-zero questions for decisions that are **mutually exclusive,
expensive to reverse, or reserved to the owner**. Batch them in one message,
three to seven at most, each with the default you will apply if unanswered
and by when. Everything else is a default under the licence. The source
project's owner answered in one-liners ("1 yes, 2 + 3 apply cool yes unless
otherwise directed"); write questions that can be answered that way.

Always reserved to the owner (from `design/astra/OWNER_MANDATE.md` section
20 and TASKS.md section D practice): money and paid services; accounts,
keys and agreements (agents create none); public claims and release;
intellectual-property boundaries; sensitive content and its depiction; the
platform and store; anything that amends a ruling the owner made; anything
that would resolve the game's central ambiguity or reveal.

**A reserved decision may carry a working default only when the default is
reversible and nothing leaves the repository.** Build on it and mark it.
Never act on a default that spends money, creates an account, publishes,
distributes a build, accepts an agreement or makes a public claim; those
wait for the owner's answer. The date you attach to a default is when it
stands as a working assumption; that date never turns it into an owner
ruling. Until the licence sentence (5.4) arrives, apply only reversible taste
defaults and list them in the next report for ratification.

For the example prompt, the day-zero questions are: (1) online multiplayer,
or local and bots first with online as a later milestone (default: bots and
local, online is a gated milestone with its own cost estimate); (2) target
platform and store (default: Windows first, itch.io friends builds, Steam
later); (3) the IP boundary the owner accepts (section 5.6); (4) session
length and player count as a feel target (default: 8 to 16 players, five to
eight minutes); (5) budget for third-party services, including AI generators
and paid review (default: zero, free tiers only). Do not ask about names,
palettes, tile sizes or the shape of the first dungeon; propose them.

### 5.4 The licence for defaults

The owner grants a standing licence in one sentence and you write its scope
down. On the source project: *"this is a demonstration project of what we
can create, the rule of cool is key. Make it good, not correct"* (2026-08-17),
later *"apply cool yes unless otherwise directed"*. Its written scope: taste
rows and previously owner-gated items are covered; **safety rules are not
taste and stay** (no photosensitive flashing, no forced camera assault);
two classes are always reserved by name (amending an owner ruling; resolving
the central ambiguity). When you apply a default, mark it: *"Default applied
<date> under the rule-of-cool licence: ... The owner may tighten the
number."* (`TASKS.md` D5). Ask for the licence sentence on day zero if the
owner has not offered one.

### 5.5 Write the covenant the same day

Section 6 is the template. On the source project the Bible was created on
2026-08-03 at 197 lines and grew to 982 by dated accretion; the first version
was enough to bind every later decision. Write it before the first line of
code, because everything after it cites it.

### 5.6 The two flags you raise before building

**Intellectual property.** "Knockoff of Zelda" is a register, not a licence.
Genre conventions (top-down view, a sword and shield, hearts, keys, bombs,
secret walls, a shrinking arena) are not protectable; names, characters,
sprites, tunes, logos, text, specific level layouts and the trade dress that
identifies the original are. State the boundary as a fact, propose the
default (original names, original art and music, homage to conventions only,
no reference to the source franchise in any shipped asset or store copy),
and route the decision to the owner as reserved. Then keep building. Put the
boundary in the covenant as a one-sentence test (section 6.2) and let the
provenance register (section 15.4) enforce it per asset.

**Sensitive content and accessibility.** Decide on day zero whether the game
touches a topic that needs a review lane (illness, violence against people,
addiction, a real community) and whether it makes accessibility claims.
Section 6.6 gives the protocol. Photosensitivity is not taste: a
`reduce_flashing` setting that zeroes every flash at its single writer is a
day-one requirement for any game with lightning, explosions or screen
flashes (`WeatherFlashAccessibilityTest` on the source project).

### 5.7 The day-zero record

By the end of day zero these files exist: the day-zero decomposition; the
machine and inventory packet; the covenant skeleton; `DOCS.md`; `TASKS.md`
with sections and a **D** section holding the questions sent; `AGENTS.md`
copied from Part II and trimmed; `HANDOFF.md` with the machine setup. Commit
them together with a body that quotes the prompt.

### 5.8 The oracle front door: when the prompt is a packet

The creator does not have to write the sentence. `oracle/` at the root of
this repository is **THE BLANK DECK**: a text adventure of fifteen to
thirty-five minutes that watches how one person plays and writes the game
description for them (`oracle/README.md` to run it, `oracle/DESIGN.md` for
how it works and what was verified). The player carries a deck of blank
cards up through a strange house. Choices in which two desirable things
conflict are recorded as evidence on 86 play-preference dimensions, with a
confidence that cannot rise on one choice alone. At the top a Proprietor
reads the cards as five to nine visions of the game to come, and the
program writes an **oracle packet**. It never asks what games the player
likes, and it models play preferences only.

Run it with `python -m oracle`. It needs no dependencies and no model; with
a model backend installed and signed in, it narrates free text live.

**What the packet is.** A folder named **oracle_packet**:

| File | What it gives you |
|---|---|
| **GAME_DESCRIPTION.md** | The prompt, grown up: three dominant signals, two secondary and one productive contradiction, each with the behaviour it was seen in; design implications; a 31-field Game Design Vector; negative constraints; personal callbacks; one feature nobody asked for; what is not known; the visions; the scope constraints |
| **design_profile.json** | The same as data, with value, confidence, status and evidence for every dimension |
| **prophecy.md** | What the player was told |
| **BUILDER_PROMPT.md** | The instruction to the engineering team, including the progress protocol below |
| **transcript.md** | The night itself |

A packet is INERT. It is a brief derived from twenty to thirty-five
observations, it says where it does not know, and nothing in it is proof of
anything.

**How day zero changes.** The packet replaces the sentence, not the method.

| Step | With a sentence | With a packet |
|---|---|---|
| 5.1 decompose | Read the sentence as N decisions | Quote the prompt line of **GAME_DESCRIPTION.md** verbatim with the file's SHA-256. The decisions are already separated: every Game Design Vector field with a signal behind it is "already implied"; every field marked default or unknown is "genuinely open" |
| 5.2 measure | Machine and inventory packet | Unchanged |
| 5.3 questions | Three to seven, with defaults | None when the oracle started the build: the player is waiting at the reading table, and the builder's prompt says so. Apply reversible defaults and record each one. When a person hands you the packet, ask as usual |
| 5.4 licence | The owner's sentence | The packet's own: where it says unknown, choose within the scope constraints and record the choice |
| 5.5 covenant | Write it the same day | Write one page from the packet: the pitch and the central fantasy are the word; the negative constraints and the scope constraints are the laws, verbatim; the audiovisual mood is the style test; the unknowns are the disputed texts |
| 5.6 flags | IP and sensitive content | The packet names pleasures, not franchises, so add no franchise. It describes play and never a person, so it carries no sensitive data. Photosensitivity is still not taste |
| 5.7 record | The day-zero files | The same files, at the scale of the first column of section 24 |

**The visions are acceptance criteria.** The player has heard them. Each
vision in the packet names what in the design makes it true. Put each one in
the slice's beat table (7.1) as a row with the check that will show it: a
test where a test can see it, a run-card step (section 17) where only a
person can. A build that passes its tests and breaks a vision has failed.

**The negative constraints are laws,** as binding as the covenant's. **The
personal callbacks and the unrequested feature must be present** and
recognisable: they are how the player knows the game was made from their
night and not from a template.

**The scope is fixed by the packet,** because one agent builds the game
alone while the player waits: Godot 4.x; ten to thirty minutes of play; one
core mechanic and at most two supporting ones; visuals drawn in code; no
downloaded assets; single player, offline; nothing leaves the machine; one
documented command to run it and an automated smoke test. Of this manual
keep the covenant, the vertical slice, the receipts and the human gate; the
first column of section 24 says what else to skip. Reserved decisions (5.3)
do not arise inside that scope: there is no money, no account, no
publication and no public claim.

**Progress is reported truthfully or not at all.** While a builder works,
the oracle shows the player one line per real event ("A WORLD IS FORMING."
when the project file exists, "THE WORLD HAS DIED." when a test fails). The
builder appends one JSON object per line to **oracle_events.jsonl** in the
project root when, and only when, the thing has happened:

| Event | Emit it when | What the oracle checks before showing it |
|---|---|---|
| **packet_read** | the packet and the manual sections needed have been read | |
| **covenant_written** | the covenant exists | the named proof file exists |
| **project_created** | the engine project exists and opens | the named proof file exists |
| **first_run** | the project launched and exited cleanly | the named log or receipt exists |
| **core_verb_playable** | the player can perform the core verb | |
| **loop_complete** | one full pass through the primary loop works | |
| **test_failed** | a test or run failed | |
| **fixed** | that failure is fixed and the run is green again | a failure was reported first |
| **tests_passing** | the smoke test passes | the named receipt or log exists |
| **vision_fulfilled** | that vision is visibly true in the running game | the card is one the player was dealt |
| **done** | **BUILD_RESULT.json** is written | that file exists |

This is section 8 applied to a progress display: an event is a claim, and a
claim with no file behind it that a second tool can check is not shown. An
event emitted early is a lie told to the player. When the game runs and its
smoke test passes, write **BUILD_RESULT.json** (21.14) with the play
command; the oracle launches nothing until the player says yes to that
exact command.

**The human gate is the point.** The player plays the game and says whether
the oracle was right. Record that as an acceptance receipt (21.6), vision by
vision. It is the only evidence there will ever be that a reading was true,
and the only input that can improve the oracle's rules.

**What is and is not verified about the oracle** is in section 12 of
`oracle/DESIGN.md`. As of 2026-10-03: its 81 tests pass; five simulated
ways of playing produced, over ten seeded nights each, games that differed
in 8 to 24 of the 31 Game Design Vector fields; one short night was narrated
live through the Codex command line and its design and reading passed
validation. No builder has yet completed a game from a packet: the hand-off
and the progress reader are tested against a stand-in builder only, so the
event protocol above is unexercised by a real build.

## 6. The covenant

The covenant is the one document that outranks everything else until the
owner amends it. Its first paragraph states that rule about itself
(`design/ORISON_BIBLE.md`: "Where any other text disagrees with this one,
this one prevails until amended; where this one is silent, the systems of
record in section V speak. Disputed texts are confessed openly in section VI
rather than papered over.")

### 6.1 Anatomy

| Section | Content | Orison example |
|---|---|---|
| I. The word | The aesthetic statement, dated as ruled, and **one governing engine sentence** every scene must obey. | "both true": every explanation offered must be true, and neither may win. |
| I.1 The loop | The fiction of the core loop in one page. | The shift: problem, errand, repair, conversation, sleep, wake. |
| II. The motif | The one recurring device. | Four sounds and one missing fifth. |
| III. The world | The place, its rules, its antagonist if any. | The building; the Tenant; the phonautograph. |
| IV. The cast | One line per character with their wound or want; a note on why these and why this many (Orison: "Why six, and why these"); "what this ruling does not license". | Eighteen residents, six case residents. |
| V. Systems of record | One authority per question, ask nothing twice: a table mapping every recurring question to one file. | Product direction, next steps, defects, per-character mechanics, build mechanics. |
| VI. Disputed texts | Numbered disputes with the interim that holds until ruled. Ruled items are struck through and annotated "RULED <date>", never deleted. | Nine disputes, five ruled. |
| VII. The laws | Numbered, short, enforceable. | "Never hand-edit generated JSON or glTF." "Debug affordances are debug-only." |
| VIII. The style test | One test every object passes, the enumerated licensed exceptions, and dated rulings on open questions, each with "what this does not license" and "consequences elsewhere". | The Rule of Signal: does it carry, capture, switch, store or reproduce a signal? Yes: uncannily advanced. No: 1927 and second-hand. |
| IX onward | Later ruled subsystems, one section each, pointing at their briefs for construction detail. | The dream maze. |

Every ruling carries a date and the authority ("at the owner's direction").
Amend in place with "*(Amended <date> by section X)*". When the covenant
passes roughly a thousand lines, new rulings become standalone dated ruling
documents stamped over their predecessor and indexed in `design/RULINGS.json`.

### 6.2 The one-sentence test

The Rule of Signal is the most reused instrument in the source project's
canon: a single question that decides thousands of small choices without a
meeting. Write yours on day zero. For a 16-bit Zelda-like: *"Could this have
shipped on a 1994 cartridge?"* decides the palette, resolution, sample-based
audio, absence of real-time lighting, text length, and the shape of every
menu. Pair it with the IP boundary as a second test: *"Would a fan recognise
this as the genre, or as the franchise?"* The first answer is allowed; the
second is not. Enumerate the licensed exceptions in writing (a modern
save system, rebindable input, a resolution scaler) so nobody argues them
twice. Make the test enforceable where you can: the period-date audit
(`tools/audit_period_dates.py`) fails the source project's build if any
player-readable date exceeds the cutoff or any script reads the host
calendar for a world fact.

### 6.3 Systems of record

The table is the antidote to duplicated status. Fill it on day zero with
files that do not exist yet and create them when first needed:

| Question | Authority |
|---|---|
| Product direction, milestone order, definition of done | the execution plan |
| What to do next, in order | the session pickup |
| Known defects | the punchlist |
| Canon: premise, cast, laws, disputes | the covenant |
| Per-entity mechanics | the data files, each with a header naming its design doc |
| Build pipeline mechanics | `HANDOFF.md` |
| Which document wins | `DOCS.md` |

### 6.4 The owner's voice

If the game has authored text, write the owner's voice down so agents write
in it: a one-line promise, a signature movement, a table of moves with weak
versus house pairs, register separation (character speech, choices, object
copy, UI safety text, marketing), a private worksheet, a ten-question
checksum ("Eight yeses is a revision candidate. Ten yeses is not proof; read it
aloud."), and a mechanical audit that fails only on structure and never on
style (`design/ORISON_OWNER_VOICE_STYLE_GUIDE.md`, `tools/audit_authored_voice.py`).
Narrative companions (relationship webs, voice maps) stay documents with a
"tentative until played" banner and an admission test: a thread is canon-
worthy only if it can change what a player does.

### 6.5 The ethos

List what the game never does to the player and enforce it with a
baseline-gated static audit with named finding classes
(`design/VIRTUAL_ENVIRONMENT_ETHOS.md`, `tools/audit_systemic_situation_authority.py`).
The source project's list (no explicit objective, no failure state, no
morality meter, recoverability without erasure) is Orison content; the
practice is generic. For a battle royale the list might read: no pay-to-win,
no purchasable advantage, no dark patterns in matchmaking, no flashing above
the safe threshold, no voice chat without consent.

### 6.6 Sensitive topics, accessibility, platform declarations

- **Sensitive topics**: write the public claim boundary first ("what the
  game actually does"), then audit what a reviewer could actually reach in
  the shipping slice, then specify separate reviews (copy, lived experience,
  clinical or cultural), paid reviewers, unprompted questions before leading
  ones, a severity taxonomy where only the owner may lower severity in
  writing, mandatory stop conditions ("any project participant begins defending
rather than listening"), no majority vote, and the rule that silence is
  never approval (`design/NARCOLEPSY_DEPICTION_STATEMENT_AND_REVIEW_PACKET_2026-08-27.md`,
  `design/NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md`).
- **Accessibility**: declare exactly the labels that have a filled evidence
  row (owner file, reach, coverage boundary, test, manual verification,
  label, verbatim claim, known exceptions); "an empty field is a claim we do
  not make"; forbid the store phrases you cannot prove
  (`design/STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md`).
- **Privacy**: any network, microphone or location capability is audited
  end to end before a build reaches a tester; consent is an in-game state
  that must exist before the device opens, and a test proves the notice
  cannot call the capture code
  (`design/FRIENDS_BUILD_PRIVACY_AND_CONSENT_AUDIT_2026-08-26.md`,
  `design/LIVE_WEATHER_CONTRACT.md`).

### 6.7 Research binds style

A period, genre or style layer is research written as findings-to-
implementation tables before it changes the model. Each claim is labelled
documented / inferred / authored (the Harukiya reconstruction files every
decision as CANONICAL / INFERRED / ADAPTATION / NECESSITY and "nothing
invented is ever silently promoted"; `docs/harukiya_reference_notes.md`).
A detail is added only if it answers two of four questions (where, when,
weather, who) and is ranked by a cost ladder (`design/PERIOD_REALITY_LAYER.md`).
For a 16-bit homage the research layer is the hardware: palette counts,
sprite limits per scanline, tile sizes, sample rates, cartridge text budgets.
Write it as a document with sources, then as a tool that checks assets
against it.

---

# PART IV. PLANNING AND ITERATION

## 7. The vertical slice first

### 7.1 The product decision

The source project's execution plan opens with one decision and one
filtering question (`design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`): the
game is developed around one repeated dramatic loop, and every proposed piece
of work must answer *"Does this work make the next complete shift more
legible, more affecting, more frightening or more pleasurable to inhabit?"*
If the answer is no, defer it. A subsystem may be excellent and still be out of scope. Write your
question on day one and quote it in every dispatch.

### 7.2 The golden loop beat table

Define the vertical slice as a table of beats: player action, required
payoff. The first pass may be deliberately plain; it **may not omit a
beat**. "Polishing half a loop is not progress toward this milestone."
Orison's eleven beats (discover, inspect, plan, shop, return, repair,
converse, recur, succumb, scramble, wake) are its own; the discipline is
generic. For the example prompt the beats are: drop, loot, first fight,
first item that changes movement, zone closes, forced encounter, last
circle, win or die, post-match screen, queue again. Two valid beginnings
(a discovered issue, a reported issue) become the same job state after
acknowledgement: **do not build two quest systems.** Shops or rooms that
exist only to hand over an item are one fetch quest performed six times;
every mandatory detour must do two jobs.

### 7.3 Milestones are evidence gates, not dates

Each milestone is numbered steps plus a **Gate** paragraph naming the
evidence that closes it. Naming on the source project: a product ladder
(M0 to M8, with M0.5 inserted by ruling), a core-loop series (K, one task
per observed player-facing failure: K2-A to K2-G), subsystem letter series
(N dream substrate, R rendering, FA fauna, SR service round, PHONE-A to F),
D for owner decisions, H for housekeeping, and a separate rebuild ladder
(M08A to M12B) with governance ids (ASTRA-Dnnn, RUL-nnn). Choose a scheme on
day one and never renumber.

### 7.4 The three-document spine and the session loop

Direction (the execution plan), queue (`TASKS.md`) and mechanics
(`HANDOFF.md`) are three files with one job each. The session loop
(execution plan section 8): **before** a change, claim the task line, state
the milestone and gate it serves, capture a before render or a failing test;
**during**, build one vertical slice through all layers, regenerate, copy,
import and test after the last edit, verify visuals in a real window; **at
handoff**, record milestone, player-visible outcome, files changed,
generated outputs refreshed, test commands and results with counts,
before/after render paths, performance delta, remaining defect. In practice
this became a dated *"<X> checkpoint (<date>):"* paragraph in `HANDOFF.md`
and, for the rebuild, one `*_CHECKPOINT_<date>.md` document per slice
(section 8.5).

### 7.5 Owner direction becomes numbered tasks

An owner instruction is quoted verbatim, dated, and translated into
numbered task items with a **minimum provable slice** first. Anything gated
is never silently selected: "Do not silently select one of the gated dream
items; ask" (`design/next_session_dream.md`).

### 7.6 Reconciliation when status collides

When the plan, the queue and the punchlist disagree, write a dated overlay
that "reports status only and does not alter the milestone definitions": a
table of milestone | status | evidence already in production | gate still
owed; a Now / Next / Later sequence; the punchlist intake rule (blockers
enter now; uglies only when route-visible or a reproduced family; wishes
only after a playtest or owner promotion); active lanes; stop rules ("Do not
declare M2 complete from unit tests alone")
(`design/MILESTONE_RECONCILIATION_2026-08-26.md`). Findings become one
bounded task per observed player-facing failure, never a pre-authored
replacement backlog.

### 7.7 The scope audit, and run it early

Classify every milestone and open task into **launch blocker**, **attention
multiplier**, **post-launch**, **cut** or **evidence-only**. Produce: a
one-sentence promise; a hard content ceiling table; the critical path as a
chain; a **stop-building list with restart triggers**; trailer beats
licensed by named evidence; a fresh-player test cadence with numeric go/no-go;
a risk register; evidence-gated horizons; a proposed (not applied) queue
patch; a contradictions section (`design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md`).
The companion evidence matrix gives every gate: promise, owner, automated
proof, what it actually proves, manual proof still required, consequence,
forbidden claims while open, reproduction command, and a grade (FOCUSED,
LIVE, CAPTURE, PERF, STATIC, MANUAL) with status CODE GREEN or MANUAL OPEN
(`design/EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md`).

The cautionary tale: the dream ecology was phased to "done" within a day of
each owner direction, with tests and renders for every phase, and nothing in
that method asked whether the sequence served the release route until a
separate audit ranked it first under "stop building this now" (roughly 85
open bullets). **Schedule the scope audit at the end of the first month and
after every owner direction that opens a new numbered sequence.**

### 7.8 Record what is reusable while building

Keep an engine knowledge ledger from the first month: each entry names the
production problem, the reusable rule, evidence, engine constraints, what
stays game-specific, extraction cautions, and failed approaches
(`design/ENGINE_KNOWLEDGE_LEDGER.md`). Grade every claim on five evidence
levels and never claim above the earned one: L1 observation, L2 local
invariant, L3 reusable contract with names, inputs, outputs and failure
modes, L4 second-consumer proof importing none of this game's state, L5
product claim (`design/ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md` section G).
Nothing reaches L4 without a second game; mark anything above the earned
level UNSUPPORTED. Systemic decisions (fact ownership, cross-subsystem
contracts, generated schemas, save and migration rules, release-proof
protocols, claimed reusable seams) use the decision record template
(`design/ENGINE_DECISION_RECORD_TEMPLATE.md`) with a falsification condition
and a rollback path. Ordinary content, tuning and contract-preserving fixes
do not.

### 7.9 Rebuilds live beside the old world

When a large subsystem must be rebuilt, do not replace it. Write a **room
sentence** and keep / move / repair / replace / remove verdicts per element
(`design/ORISON_ROOM_RECONSTRUCTION_PLAN_2026-08-27.md`); a **migration
contract** inventorying every preserved identity, what survives, what is
free to change, and a compatibility architecture with an explicit selector
defaulting to the old world (`design/ORISON_REBUILD_MIGRATION_CONTRACT_2026-08-28.md`);
a **dry-run plan** that pins a base, proves the instruments can be red, lists
dependencies yes/no, rehearses with zero geometry and one synthetic cell,
and ends in a PASS / FAIL / BLOCKED receipt with one decision
(`design/ORISON_V2_DRY_RUN_PLAN_2026-08-30.md`). Cut over with a small
default flip plus an explicit rollback switch documented the same day
(RUL-004; `game/docs/v2_launch.md`; three commits on 2026-09-21).

### 7.10 A second creative lane

When the owner opens a parallel creative stream (the songbook), file the
owner brief verbatim as the reference text, put later ideas in dated addenda
that resolve contradictions explicitly, build phase one to the final data
shape with a test whose load-bearing assertion guards the founding rule,
stamp the proposal bible "PROPOSAL, OWNER REVIEW REQUIRED, NOT YET BINDING"
with a table of owner rulings Q1 to Qn worked through the text, keep a bridge
plan that funnels the lane through a few small owner inputs, and an
append-only delta log for re-entry (`docs/songbook_brief.md`,
`design/ORISON_SONGBOOK_MUSIC_BIBLE.md`, `design/ORISON_SONGBOOK_BRIDGE_PLAN.md`).

---

# PART V. EVIDENCE AND VERIFICATION

## 8. The proof ladder

The source project treats proof as a typed ladder, and almost every rung
was written after a weaker signal was mistaken for a stronger one. **One
artifact never stands for two facts.**

### 8.1 The five tiers

| Tier | Artifact | Proves | Cannot prove | Source |
|---|---|---|---|---|
| Static gate | an audit's exit code and named findings in a gate board | the source tree has no *new* finding of that class against a baseline | anything about runtime | `tools/gate_board.py`, `tools/audit_*.py` |
| Suite run receipt | `<log>.receipt.json` written by the runner after any launched run (`evidence_kind: suite_run`) | a process started and ended with this exit against this commit, this tree, this test-script SHA-256 and this digest of all runtime inputs | which contracts the test executed; it grants no ledger proof (RUL-003) | `tools/run_receipt.py` |
| Runtime contract | a schema-2 receipt written **by the test itself** (`evidence_kind: runtime_contract`) with four named contracts each executed and PASS (**production_composition**: the production scene assembled with unique exercised identities; **save_reconstruction**: saved facts rebuild the same state after reload; **premature_action_denial**: an action attempted before its precondition is refused without mutation; **teardown**: retained nodes, resources and playbacks measured as zero), production_runtime true, the expected selector, integer exit 0, timed_out false, and a test-source SHA-256 and runtime-inputs digest that still match the tree; paired with a claim row in a composition checkpoint | the declared contracts ran in the production runtime | beauty, usability, fear, clarity, comprehension | `tools/audit_orison_v2_completeness.py` |
| Capture packet | frames with per-frame SHA-256, a capture receipt with the capture-affecting environment gates, an A/A control pair priced before any A/B claim, a README | frames rendered under a declared camera class; a measured pixel difference | acceptance; execution; "it looks right" | `game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`, `tools/measure_shot_sheet.py` |
| Human acceptance | a durable owner-verdict file naming the reviewed commit, the accepted packet, the exact question answered, accepted non-blocking debt, and a scope boundary listing what it does **not** authorize | that a person accepted exactly that claim at exactly that commit | anything outside its recorded scope | `design/ORISON_V2_M11B_HUMAN_ACCEPTANCE_RECEIPT_2026-08-31.md`, `design/ORISON_V2_M08A_HUMAN_ACCEPTANCE_2026-08-28.json` |

### 8.2 What is explicitly not proof

A caption or prompt string in a receipt. A successful screenshot set (a
schema-1 capture receipt stood in for a runtime contract for weeks;
management quoted "first slice 0 blockers" four times before a hardened tool
showed 7). A wrapper run receipt. Test files, scene files or review cues
mentioned in prose. A checkpoint document for runtime tiers. A broad object
counter as leak evidence. A frozen duplicate frame as a temporal noise floor.
A green automated test as one of the human golden-loop checks. Historical
exit codes from before the exit-code bug was fixed. Any tool that
"manufactures a greener answer". A README asserting consumption. A data file
with no reader. A dark or default-state capture: that is NO RESULT, not NO
DEFECT (five panels shipped with passing tests and had never been on screen).

### 8.3 The completeness ledger

One read-only, stdlib-only tool encodes the program (levels, systems,
rituals, saves, human gates) as requirement rows, each with a required proof
tier and a status from an explicit ladder: ABSENT, SHELL_ONLY,
PROGRAMMED, SPATIALLY_PROVEN, RUNTIME_PROVEN, HUMAN_ACCEPTED, with
orthogonal flags (temporary fallback, blocked, not required). Readiness is
**scoped** (six ordered scopes from first-slice-technical to
old-world-retirement); each row lists which scopes it blocks, so "the
accepted route works" can never read as "the game is done". Counts are
"obligations, not completion percentages"; the tool never emits a
percentage. Exit codes are stable (0 clean, 1 retirement-only, 2 cutover
blocker, 3 malformed, 70 internal) and main deliberately exits 2 while
incomplete. Output is deterministic (no timestamps; provenance is the input
SHA-256) and writes are refused outside one documented directory
(`design/ORISON_V2_COMPLETENESS_LEDGER_GUIDE.md`). Evidence intake is by
filename only (section 3.2); a human acceptance can raise PROGRAMMED to
SPATIALLY_PROVEN through a curated grants table and never conjures runtime
proof.

### 8.4 Receipts bind a run to a tree

After any launched run with `-LogPath` the runner writes
`<log>.receipt.json` (`orison.run-receipt.v1`): completed, exit code, timed
out, elapsed, commit, tree, dirty paths, the scene's root test script and its
SHA-256, a digest of all runtime inputs (scripts, scenes, data, project
file), log hashes, PASS and FAIL line counts, and a stale-import-cache flag.
`run_receipt.py verify` re-hashes and answers BINDS, STALE or MALFORMED. If
the test source or any runtime input changed after the run, the receipt is
stale and cannot be cited. Refusals write no receipt because nothing ran.

### 8.5 Checkpoint anatomy

A milestone's own record of what was built and proved
(`design/ORISON_V2_M11B_SERVICE_OPENINGS_CHECKPOINT_2026-08-30.md`,
`design/ORISON_V2_M11D_ZERO_GEOMETRY_CHECKPOINT_2026-09-13.md`): title with
milestone id and date; evidence-class header; selector, base commit, branch;
a **pre-edit ledger declaration** predicting exactly which rows will move;
bounded implementation (named files and what was *not* changed);
independently derived numbers with margins; a focused objective test with
N/N counts and exit codes; an immutable capture packet with per-frame hashes
and camera provenance; the measured ledger before and after plus the
evidence-impact receipt for the document itself; protected-path hashes and
selector assertion; a full regression battery table (command, exit, result)
reporting nonzero-but-known exits as nonzero; explicit limitations and debt;
a decision line (MERGE-CANDIDATE, BLOCKED, NEEDS-OWNER) with human review
explicitly pending or recorded. Dream-line checkpoints add an "Ownership map
(written before implementation decisions)" section and close with "No
<other-subsystem> file was changed". Level checkpoints add machine-readable
sidecars (`.decisions.json` verdicts, `.evidence.json` claim manifests with
a manual-visual-proof-required flag) verified by a chain of read-only tools
(`design/ROOM_*_GUIDE.md`).

### 8.6 Verify by rendering, never by reading code

Visual claims are settled by rendered frames through the production scene
and the real player camera, with pinned clocks and seeds, **one declared
state change per comparison**, local A/A floors on the same camera and crop
(same build twice; publish the noise floor beside every delta), context
frames proving production placement, and every frame inspected full-size by
a human. Two identical renders differed on 86% of lobby pixels because
residents move: freeze what moves or measure the floor. Score claims by
linear-RGB RMSE with crops and floor ratios (`tools/measure_shot_sheet.py`).
A frozen capture camera per suspect view plus a false-colour id pass
(`tools/street_ownership.py`, `tools/street_provenance.py`) answers which
generator record drew a given pixel when merged buffers hide ownership. A
release perf probe reports median with p05 to p95 spread, cross-checked
against wall clock and frame count, with an A/A control; the frame is
measured at fixed camera stations, windowed, because headless renders
nothing and "reads as a pass".

**A feature that cannot be perceived in the canonical captures does not yet
count.** "If a feature exists in code but cannot be perceived in the
canonical screenshots or video, it does not yet count"
(`design/DREAM_TENTACLE_HERO_PASS.md`). Capture it with the actual player
light, camera and materials; clamp the camera to where a player can stand;
construct a rare state by hand when a normal take cannot settle it
(`game/tests/dream_hero_sweep.gd` runs one environment-selected mode per
subject).

### 8.7 When the engine cannot run: source-only checkpoints

When the lane is unavailable or the owner has paused the engine, the
executive invented a parse-only method (`design/astra/work/*/check_source.py`):
parse every changed script with a third-party parser (gdtoolkit, installed
outside the repo, version recorded), assert every literal resource path
exists, recompute geometry and topology independently in Python from the
JSON, assert a manifest is additive-only against `git show BASE:path`, diff
the protected paths, and write a receipt with an honest status:
SOURCE_CHECKS_PASS_NATIVE_UNRUN, SOURCE_PASS_RUNTIME_PENDING,
SOURCE_INTEGRATED_RUNTIME_PENDING. The parser proves syntax only; it
accepted a type inference the engine rejected, twice. When the engine
returns, the same packet gains a "Runtime follow-up" section above the
source checkpoint and the status moves to RUNTIME_PROVEN. Lane refusals are
recorded verbatim, never bypassed.

### 8.8 Evidence packets

Per-task material lives under `design/<agent>/work/<task>_NN/` (README,
check scripts, patches, originals, proposed, review.md plus review.json) and
`design/<agent>/evidence/<task>_NN/` (README, receipts, run directories with
raw logs and captures, a runtime summary). Numbering is per attempt; a
failed run keeps its number and nothing is overwritten. Both trees are
`** -text` in `.gitattributes`. The heaviest packets store before and after
full copies of the game tree with `[path, sha256]` lists, the exact runner
invocation, cleared environment keys, engine binary hash, and **omission
runs** (revert one fix, prove the red returns, restore exact bytes) so a
green is source-bound rather than coincidental. A live ledger names exactly
one hashed audit output and a render script refuses on any hash or head
mismatch (`design/astra/LIVE_STATE.json`, `tools/astra_render_packet.py`).
Named-path staging lists plus a checkpoint script that asserts HEAD equals
BASE, no cached diff, and untracked set equals the allowed set keep commits
scoped in the shared tree.

### 8.9 Prove the red before you believe the green

The runner reported exit 0 for every failing suite for 334 commits (Windows
PowerShell never populates the exit code unless the process handle is read
first), and an entire prior evidence base was demoted: "historical exit codes
are worthless" (`design/ORISON_V2_SEPT3_REBUILD_HANDOFF_2026-08-28.md` section 7).
Rules: push a
deliberately failing job through every runner and wrapper and confirm
nonzero **at the reader**; give every harness a pre-flight liveness check a
dead instrument cannot fake (assert the shader compiled by reading its
uniform list); date your apparatus and re-run everything certified while it
was broken; for every guard ask "if I delete the fix, does this fail?" and
"where does my expected value come from?"; every gate defaults red and
prints its scope and denominator in the success string; assert a known gap,
never skip the check; count artifacts declared before the run, not only the
exit code; a flaky test is worse than a failing one; bisect instead of
profiling the commit list for a plausible culprit; run a skeptic pass told
to refute, because every defect it found had passed its own suite
(`design/ORISON_RUNNER_EXIT_TRUTH_2026-08-29.md`, `AGENTS.md`).

## 9. The toolchain to build, in order

Every instrument is read-only against production data, writes only to a
directory the caller names, refuses to overwrite evidence, produces
deterministic output (no timestamps; provenance is an input hash), has
stable tested exit codes, and never retries in a loop.
`tools/PIPELINE_TOOLS.md` is the source project's reference; `tools/tests/`
(36 unittest files with synthetic fixtures) pins every exit code and
regression rule.

**Use one exit-code table for every instrument you build.** 0 means clean.
1 means a new finding or a regression against the baseline. 2 means known
incompleteness with no regression, and only a ledger may return it. 3 means
a usage error. 4 means a stale or malformed baseline or input. 5 means both 1
and 4. 70 means an internal error. The engine runner alone adds 73 for lane
busy, 124 for killed at the ceiling and 78 for cannot run. Never give a
number a second meaning. The source project's tools grew slightly different
tables (the ledger in 8.3 uses 1 and 3 differently); do not copy that.

**Write the runner, the lane lock and every gate in the Python standard
library on a new project**, not in PowerShell, so the same scripts run on
any developer machine and in CI. The source project's PowerShell runners and
Windows named mutex are its open debt (section 25). Take the lane with an
exclusive lock file in the system temp directory (**msvcrt.locking** on
Windows, **fcntl.flock** elsewhere) and hold it for the whole run. Before
launch, list running processes whose name starts with the engine binary's
stem and exit 73 if one exists. Exit 78 when the binary, the project file or
the log directory is missing. Launch the console binary with a ceiling,
redirect stdout and stderr to the log path, kill the process tree at the
ceiling and exit 124; otherwise exit with the engine's own code. Push a
deliberately failing suite through it before trusting it (8.9).

### 9.1 Build order

| Priority | Instrument | Source | What goes wrong without it |
|---|---|---|---|
| Day one | **Serialized engine runner** with mutex, process census, ceiling, log redirect and one-fact exit codes (suite exit, 73 busy, 124 killed, 78 cannot run) | `tools/run_godot_serial.ps1`, `tools/lane_common.ps1` | Two agents run the engine at once; a parse error idles forever; every refusal looks like a lane conflict. |
| Day one | **Run receipts** binding every launched run to commit, tree, test SHA and runtime-input digest | `tools/run_receipt.py` | Claims are typed, not filed; a stale run is cited as current. |
| Day one | **Rules file and rulings index** with a citation checker | `AGENTS.md`, `design/RULINGS.json`, `tools/check_rulings.py` | Rules are relearned; briefs cite rulings that do not exist. |
| Day one | **Design-document lint** for the evidence-class header | `tools/lint_design_doc.py` | Prose promotes requirements. |
| Week one | **Reader gate**: every shipped data file and field must have a production reader; frozen baseline; zero new findings | `tools/audit_data_consumption.py`, `tools/data_consumption_baseline.json` | Dead data never fails a test (two save floats survived four save versions unread). |
| Week one | **Gate board**: run every static gate and tools test, write board.json, compare against a baseline board; exit 1 only on regression; refuse cross-version compares | `tools/gate_board.py` | Main is never green, so "green" is not a gate; without a baseline nothing can merge. |
| Week one | **Candidate verifier**: fresh checkout at a short path under the machine's autocrlf, board versus merge-base, changed gate files flagged, docs linted, protected paths by blob identity, suites through the runner with receipt verification, report sidecar compared claim by claim | `tools/verify_candidate.py` | Management trusts reports; a candidate grades itself with an instrument it rewrote. |
| Week one | **Capture wrapper and shot harness** with a time budget, refuse-overwrite, per-frame hashes, capture-gate record, and a sheet measurer with A/A floors | `tools/run_godot_capture.ps1`, `game/tests/shot_harness.gd`, `tools/measure_shot_sheet.py` | Screenshots are taken by hand and nobody can say what changed. |
| Month one | **Lane broker and lanes ledger**: who holds the engine, wait instead of fail, every worktree and branch against main with a disposition | `tools/lane.ps1`, `tools/lanes.py` | Agents fight over the engine; 34 worktrees accumulate. |
| Month one | **Domain audits with frozen baselines** (interaction prompt carriers, implementor census, spatial dependency manifest, period or style dates, ethos, audio emitters, music catalogue) | `tools/audit_*.py` and their `*_baseline.json` | Conventions drift silently; the fiction's calendar leaks; a bus is missing on a player. |
| Month one | **Completeness ledger** with requirement rows, status ladder, scopes, evidence intake by filename | `tools/audit_orison_v2_completeness.py` | Progress is a feeling; "the route works" reads as "done". |
| Before testers | **Release pipeline**: warm checkout with cold import as an explicit stage, export through the runner with a clean-tree requirement and hash manifest, packager with content audits, an exact file contract, a mandatory owner-supplied licence, a notices generator that fails closed, hash sidecars, a tester README template filled from the exact commit, a release perf matrix, and a static pipeline contract test | `tools/warm_release_checkout.ps1`, `tools/export_friends_build.ps1`, `tools/package_friends_build.ps1`, `tools/build_third_party_notices.ps1`, `tools/run_release_performance_matrix.ps1`, `tools/test_release_pipeline_contract.ps1`, `distribution/README_TESTER.txt` | A build ships without its licence, with developer controls, or from a dirty tree. |
| When large | **Level checkpoint toolchain**: lint a checkpoint's verdict table for machine-checkability, reconcile it against the regenerated layout, verify cited proof artifacts exist, roll into a progress ledger with no COMPLETE state, chain by one gate command with an opt-in hook | `tools/room_*.py`, `design/ROOM_*_GUIDE.md` | Level acceptance lives in prose. |
| When large | **Provenance forensics**: false-colour id pass and ray-to-record attribution | `tools/street_ownership.py`, `tools/street_provenance.py`, `game/tests/StreetIdShot.tscn` | Nobody can name the flat black mass on screen. |

**Bootstrapping the gate board.** Run the board on the first commit that
contains the board tool. Store boards outside the repository at a short path
(`C:/ov/boards/main` on the source project). Rebuild main's board after every
merge to main, and gate every candidate with `--baseline` against it. A board
holds {schema, tool_version, created_utc, commit, tree, dirty_paths, python,
status_order, gates}; each gate row carries its real exit code, a severity,
defect counts, named defects and requirement states, and every tools test is
a gate of its own named `test:<file>`. A compare refuses when `tool_version`
differs. On a single canonical checkout, run the verifier with
`--in-place --baseline-board` against a board captured at the merge-base.

**What counts as a regression** (`tools/gate_board.py` docstring, all five
rules): a gate's severity rose (PASS < INCOMPLETE < FAIL < ERROR); a defect
count rose; a named defect appeared that the baseline lacked; a ledger
requirement's status fell or the requirement vanished; or a tools test file
ran fewer tests than before, because a deleted test is not a pass.
Everything else that moved is listed as a change or an improvement. Without a
baseline the board is a record and exits 0.

### 9.2 Gates that do not rot

A baseline is a ratchet: new finding fails, changed class fails, removed
finding is a clean note; identify findings by meaning (a hash of domain,
class, file, scope and normalized expression), never by line number; count
what the scanner suppressed; for every finding class commit the fixture that
turns it red and point the detector at a tree you know is ill (the ethos
audit caught 0 of 8 violations written in another team's idiom,
`design/ORISON_VERIFICATION_MIDDLEWARE_ASSESSMENT_2026-08-29.md`; ban the
shape, not the vocabulary); restate every UI prohibition as a storage or API
invariant; put the contract in the generator, not the generated output (a
regenerated catalogue erases hand edits); expect an honest metric to move
against you first and publish the expected movement before landing; a false
blocker is a tooling defect, never something to route around by renaming a
room; rehearse acceptance machinery on a synthetic subject; refuse to compare
boards of different tool versions (a v1/v2 pair produced 1,302 false
regressions).

### 9.3 The reader gate in one paragraph

A shipped data file must be opened by a production script by path, and
every leaf field must be read by name in a script that opens that same
file; JSON prose never counts; durable numeric fields whose only read is
their own assignment are reported separately; identity-map containers are
declared so record ids are not counted as fields. The baseline is debt, not
permission. Roughly half its findings are the gate's own blind spot, so the
count is not a dead-data count; the gate exists because no audit had a
NO_READER class and "a missing consumer produces no output", and no output never fails a test (`design/ORISON_DATA_CONSUMPTION_ANALYSIS_2026-08-30.md`).

### 9.4 Engine-side audits that never look at a pixel

A lighting audit checked coverage, storey selection and caster budgets and
passed for months while rooms shipped black, because it checks coverage and
never looks at a pixel (`TASKS.md` section L). Pair every
structural audit with a measured one (a windowed room-luma audit that turns
each room's own switch on and measures the near-black share), and keep an
INTENTIONALLY_DARK list with reasons separate from a KNOWN_DARK list that
must stay empty.

### 9.5 Measure before you architect

Run the null experiment first. Sweep the knob: identical frame time at
720p, 1080p and 1440p means not fill-bound; identical with 0 or 64 shadow
casters means not light-bound; the source project's frame is draw-call
bound, so GPU quality was free and geometry submission was the only lever.
Name which resource each dial spends (an atlas doubling that was free in
milliseconds cost 1,024 MB against a 256 MB budget). Fix the instrument
first (an integer fps divisor printed 500 ms for a 6.7 ms view). Census
where the geometry lives before optimizing (the column radiator was 62
meshes and 23 props carried 56% of all prop meshes; merging them took scene
meshes from 3,028 to 1,682, `art/docs/photoreal_target.md`). A documented engine limitation is a claim
with a date on it: three places asserted a renderer lacked a feature it
had, and it nearly cost a migration (`design/DT4_PERFORMANCE_REAUDIT.md`,
`design/TEXTURE_REPAIR_AND_PERFORMANCE_PLAN.md`).

### 9.6 Report sidecar

A developer may commit `reports/<task>.json` (`orison.dispatch-report.v1`)
beside the prose report with head, merge-base, selector, protected count,
ledger before and after, requirements changed, gate exit codes, suite exit
codes and the last line; the verifier checks each present key. A sidecar
cannot name the commit that contains it, so the verifier also accepts that
commit's parent.

### 9.7 Backups and the retired scripts

`tools/backup.ps1` and `tools/backup.sh` (2026-07-29) run `git add -A` and
push straight to main, and the README's "Local-first workflow" section still
teaches them. They predate the ban (RUL-010) and were never retired; do not
copy them. On a new project the backup is: named-path commits on an agent
branch, pushed; work in no ref rescued by manifest snapshot onto a pushed
`backup/*` branch; and a weekly worktree and branch sweep (`tools/lanes.py`).
Add a static gate that greps `tools/` and `README.md` for `git add -A` so
the sweep cannot regress.

## 10. Engine harness conventions and constraints

These are Godot 4.7.1 facts learned on the source project. Most have a
counterpart in any engine; verify each on yours and keep the list.

### 10.1 The test scene

A test is a scene whose single root node carries a script from
`game/tests/`, run headless as `godot --headless --path game res://tests/X.tscn`
through the runner. The script pins the environment first (day-night off,
persistence disabled, campaign reset so the user's save never leaks), seeds
state as a first launch would, instantiates the production world, awaits a
settle, runs check calls that print `[ok]`/`[FAIL]` (newer suites print
`[TAG] PASS|FAIL label`), prints one RESULT line, and ends with
`get_tree().quit(failure_count)` so exit code equals failures. Serious
suites carry a watchdog, an exact expected check count, an executed-block
ledger and START/COMPLETE sentinels so a silent partial run can never print
PASS. Prefer shortening the specific wait to scaling time (19.10). When a
suite must scale time, as the source project's long physical walks do, raise
the physics tick rate by the same factor and assert that per-step
displacement stays below half the width of the thinnest collider on the
route; engine timers scale with time scale too. Suites are sharded by
environment variable so the everyday gate stays under the runner ceiling.
Tests write their own JSON evidence sidecars with an explicit **scope**
string naming what they do not prove. Five test files once printed PASS and
quit 0 unconditionally: audit for that shape.

### 10.2 Headless versus windowed

Headless never fires the post-draw signal, reports zero for every rendering
counter, answers identity and defaults for instanced reads, and cannot
capture the mouse; every headless assertion about those things passes
vacuously. Screenshot, performance and pointer suites run `-Windowed`, and
the shot harness refuses when the display server is headless. Screenshot
suites read an absolute pre-existing output directory, hide every canvas
layer, make a camera current **and move the player with it** (streaming and
the light budget follow the player), await two process frames plus
post-draw, then save the viewport image. Perf runs windowed at a fixed
resolution, disable vsync and frame caps, pin the light and shadow budgets in
code, warm every station before timing (lazy shader compile), fail any
station below a minimum object count (an empty frame is a broken run, not a
fast one), and exit with the count of over-budget stations.

### 10.3 The capture time budget

The process ceiling is 60 s; a shot scene gets a 54 s internal budget with
6 s reserved for launch, exit and receipt. Targets: focused boot 18 s, full
production boot roughly 33 s (measured, n=2, so no p50/p90 yet), resolve
owners 4 s, warm-up 6 s, captures 0.35 s each, 18 frames maximum per shard.
Every timing checkpoint prints outstanding frames, reserve and slack;
negative slack means shard, never delete evidence or lower the expected
count. A shot may disable a feature group only when that group is outside
the claim, and the receipt records the exact gates; a reduced profile is
never described as an unqualified production capture
(`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`).

### 10.4 Godot-specific constraints

- The `_console` binary is mandatory on Windows; the plain exe prints
  nothing to stdout. Locate it by PATH; do not commit it (a 198,152-byte console
  stub is tracked by accident on the source project).
- `OS.set_exit_code()` does not exist in this build; quit with the count.
- A script that fails to parse does not fail; the engine idles with the
  error only in stderr. Every run needs a ceiling.
- `.godot/` and `*.import` are ignored, so import policy must be a
  reproducible pipeline step. Exception: force-track the `.import` of every
  texture loaded at runtime by path, because the editor never sees a
  runtime-loaded texture on a material and regenerates it with mipmaps off
  (`art/tools/fix_runtime_texture_imports.py`). `.uid` files are tracked
  (853 of them), which is why `git add -A` is banned.
- The engine rewrites `.import` and `.uid` line endings on import; check
  with `git diff --ignore-cr-at-eol --name-only` and restore before
  committing.
- Register the input map in code from an autoload and **poll** named
  actions in the player, so touch buttons, pads and tests can set action
  state without an input event; a verb read from a raw key or mouse event
  is unreachable from a pad no matter what is bound.
- Single inheritance forces composition and adapters; `has_method` proves
  spelling only, not paired capabilities, signatures or effects. Document
  the convention; add a base class only after an observed bug.
- Windows file rename deletes its destination first and there is no checked
  fsync: saves need a `.bak`, a transaction journal and a `.tmp` with
  verified reads (`game/scripts/game/reality_save_storage.gd`).
- Export dependency filters cannot see assets referenced by runtime
  strings; exclude superseded large assets by name and include non-resource
  packages with an explicit include filter.
- Android export requires `import_etc2_astc`; the compatibility renderer
  caps lights per object and lacks subsurface, SSR and volumetric fog;
  a shader material draw costs more than a standard material on it.
- Depth fog density is the asymptotic ceiling, not a rate.
- A queued 3D playback survives `stop()` before its first physics update;
  free and remake the voice.
- Godot does not diagnose two revisions of a JSON and its glTF loading
  together; embed the sibling binary's SHA-256 in the descriptor and verify
  at boot.
- The Project Manager window counts as a running engine; the lane rule
  applies to it.

---

# PART VI. CONTENT AND CODE PIPELINES

## 11. Architecture doctrines

Each doctrine below is stated as the source project states it, with the
file that proves it. They transfer to any engine.

1. **One owner per fact.** Before writing a system, write its row in an
   authority table: Owner | Owns | Does not own (`game/docs/core_loop.md`).
   Every durable fact lives in exactly one subtree of one save document and
   exactly one script may write that subtree; a curated owner map plus a
   static audit fails any other writer. Enforce ownership with an API that
   returns false for anything outside its whitelist, not with a review
   rule. Derived quantities are computed from the one place the fact is set,
   never counted in parallel.
2. **Coordinators connect, owners rule.** A director listens at
   authoritative signals and makes legal calls on owners' public APIs; it
   owns none of the rules it connects and persists only orchestration
   (active id, boundary, one-shot flags). State machines reject illegal
   transitions without mutation or signal emission. Write signal semantics
   down ("closing a dialogue panel is not a rule change").
3. **Presentation never owns story state.** The save is a versioned fact
   store, not a scene snapshot. Saved: stages, origins, evidence, custody,
   seeds, phases. Derived after load: prose, prompts, HUD, animation, input
   locks, procedural geometry from seed. The interaction presenter cannot
   make a prop respond, open a job or acquire an item
   (`design/SAVE_RELOAD_TRANSACTION_MODEL_2026-08-27.md`).
4. **Save boundaries.** One JSON at a user path with a version; every
   domain mutation ends with a commit (write first, then emit). Load: fresh
   defaults, refuse a future-version file read-only (never merge or
   overwrite), merge with additive migration, emit, owners reconcile and
   re-present. Storage is crash-recoverable. Tests write real files under a
   test path, never the production save. Timestamps use a campaign-clock
   basis; production code never calls a wall-clock API.
5. **Data-driven construction with a reader gate.** Content is JSON;
   "adding a fourth case is a dictionary, not a class". Runtime classes are
   chosen by marker kind strings from a layout produced by a deterministic
   generator. The reader gate (section 9.3) makes the absence of a consumer
   visible.
6. **Authoring, runtime, proof projection.** Complete authoring sources with
   attribution and planning notes are projected by one tool into runtime
   JSON that omits only scoped fields, and into a test-proof JSON that tests
   read; `--check` refuses stale outputs; a change made only in a runtime
   output is lost by design (`art/data/orison_v2/AUTHORING_PROJECTIONS.md`,
   `tools/build_v2_authoring_projection.py`).
7. **Deterministic generators with hash-bound outputs.** Seeded random,
   CRC-stable per-id choices instead of salted hashes, glTF descriptors that
   embed the sibling binary's SHA-256, a registry that verifies every
   hash-bound asset at boot and fails closed, and a generator/runtime
   interface map naming per artifact its authority, mirror step, consumer,
   failure behaviour and what is *not* enforced
   (`design/GENERATOR_RUNTIME_INTERFACE_MAP_2026-08-27.md`).
8. **Two-stage validation.** Source invariants before export (the generator
   validates its construction and refuses to write; the DCC build fails on a
   failed export), then imported and runtime invariants after assembly
   (suites prove collision, routes, markers, behaviour).
9. **Selector with rollback.** One non-persistent authority maps ids to
   scene paths, reads an environment override, falls back to a default with
   one warning; cutover and rollback change only the default; the selector
   is never serialized; saved facts reconstruct under either root
   (`game/scripts/building/building_root_selector.gd`, RUL-004).
10. **World-swap boundary.** A persistent shell holds one world slot with
    exactly one in-tree world; every phase transition is committed before a
    swap is requested; procedural worlds are pure functions of (seed, path,
    count) and store no map ("a pure function cannot leak, cannot corrupt a
    save, and reconstructs identically on any machine").
11. **Simulation tiers.** Rendering and simulation are bucketed separately
    (dormant, statistical, scheduled, embodied); every advance is a pure
    function of (facts, elapsed simulation minutes) so promotion and demotion
    are lossless; durable timestamps plus catch-up survive save, load and
    unload. Every simulated quantity needs a sensory tell: **no tell, no
    variable** (`design/ORISON_SIMULATION_BUCKET_ARCHITECTURE_2026-08-29.md`).
12. **Interaction protocol.** Duck-typed discovery walking the collider's
    ancestors; an empty prompt means unavailable; the controller owns the
    input carrier ([E], [A], [TAP]) and props return semantic text, enforced
    by a static audit with a legacy baseline; an adapter area presents
    multi-control mechanisms as the whole-object protocol; persistence
    routes through owners, never props
    (`design/INTERACTION_CONTRACT_2026-08-27.md`).
13. **Corruption indexed by the thing corrupted.** A selector keyed on a
    field 43 of 127 rooms lacked meant only six flats could ever be
    affected; the fix is an element-indexed registry whose loader refuses
    any entry without its ordinary counterpart, so "the corruption catalogue
    cannot outrun the simulation catalogue".
14. **Every implementing script's header points back at its authority.**
    Cite the covenant or brief section the script serves and quote the
    ruling (`game/scripts/dream/margin/dream_palp_behavior.gd` cites the
    ecology architecture's sections). Give an interactive-object script three
    header parts: the historical or design source, "THE TRUTH THIS TEACHES",
    and an OWNERSHIP paragraph listing what it does not own
    (`game/scripts/props/door_check_closer_prop.gd`). The link from document
    to code then runs both ways.

## 12. The data layer

Everything the runtime knows lives as JSON under one tree loaded through one
path scheme, so a single regex can find every reader. Every file has a
header before any record (`game/data/resident_schedules.json` is the
strongest example):

- **schema_version** as an integer mirrored as a constant in its loader,
  which refuses a mismatch.
- **meta.source** naming the design document the file transcribes,
  **meta.authored** stating the edit rule ("edit this file and the doc together - the
SIII interlocks are written into both sides"), and
  **meta.schema** with one sentence per field.
- The file's kind, declared: a **hand transcription** of a document, a
  **generated projection** (generator field, input hashes, "never edited
  here", a `--check` mode), or a **research copy-book** (research ledger
  path, period or style cutoff, per-record source ids, a status line saying
  which values remain owner-supplied; `game/data/prop_service_wire.json`).
- A **field_semantics** block classifying any field that could be
  mistaken for a rights or history claim (in-world fiction, rights record
  null; generated flavour, authored false), gated by a tiny audit that fails
  if the block moves.
- Self-check counts (expected record counts) and, where hash-bound, input
  hashes.
- **Tentative flags** instead of deletion: `proposed: true`, `enabled:
  false`, `status: opening_shift_prototype`, `production_default: false`.
  "All case content is tentative until its gameplay is worked through."

One strict loader class per file validates shape and vocabulary on load,
warns on every error and exposes only typed accessors; never scatter
`if unit == "2A"` chains. Never keep two copies of a file without a tool
that copies or diffs them; the one un-tooled duplicate drifted within nine
days. The reader gate runs from the first commit.

## 13. The art and world pipeline

### 13.1 The chain

Python authors a **semantic model**; the DCC tool builds deterministic
geometry from it; the engine assembles the export; audio, props and the
navigation graph read the **same coordinate-driven data**, so pipes and
sounds always correspond to actual structure (`art/README.md`). One script
(`art/data/gen_layout.py`, 10,984 lines) is the single coordinate authority
and refuses to write until roughly twenty validators pass (overlaps, door
widths, movement and door-swing audit, furnishing completeness, daylight,
ventilation, flue graph). Nothing is generated at runtime. Same inputs, same
bytes out. Inspect results in the DCC file before export.

### 13.2 Invariants that transfer to any project, including 2D

- One script authors the semantic model; every downstream tool reads it;
  validation lives in the generator and only grows.
- Naming carries engine semantics (`-col` visible plus collision,
  `-colonly` invisible collider; the material key is the catalogue key).
- Materials, tiles or palettes are a **closed catalogue** with a bridge file
  validated in both directions at build time; an unmapped key exits 1
  (RUL-008). A new finish goes through the catalogue or stays flat colour.
- Generated assets are never hand-edited (law 2 in the covenant). Hand
  edits vanish on regeneration; put the contract in the generator.
- Randomness is seeded; per-id choices use a stable checksum, not a salted
  hash.
- Verification is a render or a measurement, never a code read.
- Research is written as findings-to-implementation tables before it
  changes the model (`art/docs/research_1927_construction.md`).
- Art phases are assessed against a written definition of done, each phase
  verifiable before the next depends on it (`art/docs/photoreal_target.md`).

For a 16-bit game the chain becomes: Python tilemap and entity JSON (rooms,
collision, spawn markers, loot tables, arena rings), a deterministic tileset
and sprite-sheet build (palette quantisation to the fixed palette, cell-grid
slicing, animation strips), engine assembly from the same JSON. Drop
Blender, PBR map derivation, UV projection, glTF export, the 3D lighting and
occlusion work. Keep the shed: a fixed inspection scene under flat light
that photographs every asset family for review (`tools/prop_reference/README.md`).

### 13.3 Props and characters

Props began as parametric primitive assemblies in script, reviewed family
by family against period reference with before and after renders; a
reference tool then photographed all 69 specimens in an inspection shed,
fetched licence-clean references, scored seven gap axes per specimen under a
contract, and ranked them; the owner ruled that props are regenerated in the
DCC tool as named-part exports with the critiques as the spec, scripts
keeping every non-visual authority (RUL-006,
`design/PROP_MODELING_TEXTURING_BRIEF_2026-09-18.md`). Reference photographs
inform form only; they are fetched only from sources with machine-readable
licences, stored ignored with a provenance file, never baked, projected or
committed, and cited by URL (RUL-007). Characters came from an AI 3D
service, converted by scripts that strip baked emissive, grade albedo,
decimate to a measured budget and bake a shared gesture library onto each
rig; the owner ruled one active model per resident and no scaling of any
kind after baked scaling lost twice to unit normalization.

### 13.4 Building assets from Python when the DCC tool is unavailable

For a bounded edit of an existing exported asset (extract N nodes, move one
assembly, append a decorative batch) or when the DCC lane is blocked, patch
the glTF from Python with a fixed verification kit: hash inputs before and
after (the source is never an output); hash outputs and rebuild once to
prove idempotence; assert the original arrays are an untouched prefix;
assert buffer byte length equals file size; re-read your own binary and
check winding against stored normals; add negative controls that must fail;
label every preview "not a render"; set status to a SOURCE_* value until the
engine has run (`tools/build_v2_passage_gateway.py`,
`tools/check_v2_arcade_ceiling.py`). Never do this for new organic modelling.

### 13.5 Textures and the ingest

Textures arrive from image generators into an inbox that never ships, named
by a filename contract ("the filenames are the ingest contract"), and are
made game-ready by a deterministic ingest: watermark pre-crop or unblend,
flatten baked lighting before tiling, seamless edge-band crossfade, height
and normal derivation, roughness from a per-material base, colour anchoring
to a per-slot hex, a flat-surface check that refuses plates with baked
illumination, variants as family members, staging into the engine tree
(`art/tools/ingest_material_sources.py`). Slots are earned: a new plate
takes its slot only if it beats the incumbent in-engine against reference.
Generated textures carry no letters, numbers, words or logos; lettering is a
label node or a deterministic in-engine bake (RUL-008). Per-wall finishes
are baked from three masters with the wall slug as seed
(`tools/bake_wall_finishes.py`); procedural plates from pure math replace
photo sampling where possible (`tools/synth_plates.py`).

### 13.6 External generators and the cross-repository contract

A generator that lives in another repository hands over a hashed, proven
build output through a documented contract: the compiler at `C:/FPSengine01`
writes a catalogue with a scene hash and a gameplay-identical flag plus
package archives; the game ports the runtime as a prefixed copy (never a
submodule), reads the catalogue through one class, never edits it, ships the
packages via an explicit include filter, and asserts one gameplay
fingerprint across all packages in a test (`game/docs/arcade_cabinets.md`,
`DOCS.md` "The two repositories"). The compiler is not git-versioned, which
is tracked as the largest single risk on the queue; version everything.

### 13.7 Prototypes and side projects

Build the first idea as a zero-asset standalone project with its own
headless test, screenshot driver, debug panel whose skip-to-stage replays
the real input path, and a README checklist (`audio_virus_prototype/`).
Write the world as a NOT-CANON draft. When the real game starts, port the
prototype's fiction and interface as data plus a runner, and file the
prototype in-tree as `legacy_*` with "it is not the live game" in the README
and its own project file. Keep sibling projects in-tree only when their
content is content (finished games, engines); keep toolchains and packaging
out (a devkit inside the repo it builds broke PATH). Sealed cartridges
(finished HTML games) are never edited internally and must stay launchable;
their BYO-content rule (nothing adult bundled, a private on-device gallery)
was restated diegetically when ported into the in-world handset.

## 14. Generative assets

### 14.1 The loop

No generator is called from code for shipped art. The engineer writes
**prompt sheets as design documents**; the owner pastes them into consumer
tools, drops the outputs into the inbox under exact filenames; Python
ingests deterministically; the engineer renders; the owner judges renders
and the ruling is recorded verbatim in the document. Owner-found defects
become tools (a watermark report became `art/tools/scrub_source_watermarks.py`:
124 hits, 61 real, 63 false positives rejected by an alpha gate).

### 14.2 Generators by medium on the source project

| Medium | Generator | Evidence | Discipline |
|---|---|---|---|
| Images and textures | Gemini image generation; ChatGPT/OpenAI image tool; early FLUX.1-schnell via a keyless Hugging Face space | `art/textures/ai_sources/`, `art/tools/fetch_wall_sources.py` | watermark scrub, provenance `SOURCE.md` per asset |
| 3D characters and animation | Meshy (image-to-3D, text-to-motion) | `game/data/resident_hero_models.json`, `art/blender/meshy/` (ignored) | merge per-clip exports into one rigged file; strip emissive; grade; decimate |
| Music | Gemini app / Lyria 3 from attached public-domain sheet music; owner-generated | `design/ORISON_SONGBOOK_GEMINI_LYRIA_PROMPTBOOK.md`, `game/docs/title_screen.md` | objective pre-checks (duration, BPM, LUFS), manifest with model, date and disclosure fields, SHA-256 pinned masters |
| Voice | Windows offline TTS placeholders, later discarded by ruling; the game ships unvoiced | `art/tools/generate_placeholder_voice.ps1` | node id equals take filename; every encode self-decode-verified |
| Props, furniture | not generated; parametric, then DCC rebuilt | RUL-006 | |
| Reference photos | Wikimedia Commons only, licence-filtered | `tools/prop_reference/README.md` | form only, never baked (RUL-007) |

### 14.3 Prompt disciplines

Every prompt is self-contained so it can travel alone. Open with the medium
("a flatbed scanner scan of..."); state scale as a **count** of features,
not metres; ask for "a close crop of a much larger continuous surface"
rather than "seamless"; format first, period detail last; positives over
negatives except the one cheap unambiguous negative, "No letters or numbers
anywhere" (the single most-broken rule); per-slot colour anchors and a
white-balance clause enforced at ingest; batch preambles for multi-image
runs; layer-type contracts inside the prompt (two-tone stencils, brightness-
as-height reliefs, additive light-on-black); for characters an invariant
preamble and tail with only the body varying; for animation body-level
description, loop versus one-shot, one idea per clip, seconds not frames,
and a "what to reject" list; for music non-negotiable facts, section
structure by timestamp, targeted correction prompts for the common failure
modes, and NON-NEGOTIABLE / DESIRABLE / EXPENDABLE tiers; for key art,
references named as identity references, not edit targets, with a separate
corrective-edit prompt; and in every sheet a "what not to generate" section
(`design/MATERIAL_PROMPT_SHEET.md`, `design/ORISON_APOSE_PROMPTS.md`,
`art/docs/animation_prompts/`).

### 14.4 What a 16-bit project needs that this repository cannot tell you

The transferable core is the loop and the prompt disciplines. The PBR
machinery does not transfer. A pixel project needs palette quantisation to a
fixed palette, sprite-sheet slicing on a known cell grid, per-frame
animation strips, and either a generator that respects hard pixel grids or a
post-process that re-quantises. This repository contains no evidence of any
pixel-art generator, palette tool or sprite pipeline; which generator works
for sprites, how to keep a character consistent across frames, and whether
text-to-motion helps 2D at all are **unknown** here. Treat them as a
research task with a filed dossier (section 6.7) before the first asset is
committed.

## 15. Audio and licensing

### 15.1 Four provenance regimes

Recorded ambience and effects from Freesound, CC0 or CC BY 4.0 only,
non-commercial files downloaded but marked excluded and never referenced;
masters in an ignored source directory, re-downloadable by URL; only
processed derivatives committed, each listed in an attribution manifest with
title, contributor, URL and licence (`game/assets/audio/freesound/ATTRIBUTION.md`).
Music generated by the owner with a manifest per track (model, date,
disclosure, legal status) and masters pinned by SHA-256 and duration. Voice
placeholders from offline TTS, later discarded. Procedural synthesis
in-repo; a missing recorded key produces silence plus a warning, never a
test tone.

### 15.2 Audio as gameplay

Sound tells the player what acted, where, whether it took, what state the
mechanism entered, and what deserves attention next; silence is part of the
language (`design/SOUND_AS_GAMEPLAY_AUDIT.md`). Ownership in one sentence:
"Callers decide what happened;
this node only resolves bus, voice, priority, cooldown and diagnostics." Check in the bus tree as data in an
autoload and build it before any world owner arrives; put the cue vocabulary
in a JSON catalogue where each record carries its whole audibility and
concurrency contract; allocate a bounded semantic voice pool with per-source
cooldowns, instance limits, priority steal, and an event history that
records every refusal reason; make stopping as important as playing; compose
mix states rather than mutating the master bus; captions are accessibility
parity, not spoilers; treat every loudness or masking claim as a hypothesis
until a human listening run is admitted (`game/scripts/audio/audio_policy.gd`,
`game/data/audio_cues.json`, `tools/audit_audio_emitters.py`).

### 15.3 The rights chain is mechanised

The notices generator reads exactly the in-tree licence sources, throws if
any is missing or lacks its expected licence strings, assembles the notices
file with a static engine licence paragraph, and re-verifies the written
file. The packager runs it, requires an owner-supplied licence path (it
refuses to invent a licence), runs the content audits first, and enforces an
exact file payload. A static contract test asserts all of that without
launching the engine (`tools/build_third_party_notices.ps1`,
`tools/package_friends_build.ps1`, `tools/test_release_pipeline_contract.ps1`).

### 15.4 The provenance register

Before any tester build, three owner-facing audits each carry a stop rule:
missing evidence is UNKNOWN or BLOCK, never permission; owner statements are
recorded verbatim and labelled as statements, not findings
(`design/FRIENDS_BUILD_LICENSE_AND_THIRD_PARTY_AUDIT_2026-08-26.md`,
`design/FRIENDS_BUILD_CREATIVE_PROVENANCE_REGISTER_2026-08-26.md`,
`design/FRIENDS_BUILD_PRIVACY_AND_CONSENT_AUDIT_2026-08-26.md`). Every
AI-generated asset carries a source sidecar (generator, date, selection
note, exact prompt, source path, ingest tool, runtime key) written at
creation time; the fields you leave blank become the audit's UNKNOWNs weeks
later. Write the source and licence policy before downloading anything.

## 16. Simulation and environment patterns

Optional patterns, each with the failure it answers.

- **One durable clock, one writer.** An authored civil date plus the host
  minute sampled once at campaign creation; only elapsed minutes accumulate
  and are saved; one driver advances it and refuses to run twice; everything
  else reads. The population must never own a second clock
  (`game/scripts/game/campaign_clock.gd`, RUL-005).
- **Timetables authored from character, not gameplay need.** A design
  document derives each character's daily, weekly and annual timetable from
  who they are, hand-transcribed to JSON with the schema in its header, and
  a director resolves the most specific covering block deterministically
  (`design/ORISON_ARCHETYPE_SCHEDULES.md`, `game/scripts/characters/schedule_director.gd`).
  Temperament tables exist because everyone once made the same hard-coded
  decision and the building emptied in unison.
- **Navigation from the layout data, not a baked navmesh.** The generator
  is the authority on where walking is legal; the graph is built from its
  rooms, doors and lanes, pruned against authored walls, validated once
  against real colliders, and a route that would cross a wall returns the
  start point so the actor stands still and a harness can assert zero
  unreachable routes (`game/scripts/characters/resident_nav.gd`).
- **One environment writer.** Exactly one node writes absolute values into
  the environment, the sky key and the sky material; everything else
  supplies gains, publishes facts or consumes profiles. The two-writer bug
  it fixed: a debug change overwritten eight seconds later
  (`game/scripts/building/day_night_director.gd`).
- **Privacy-first live data.** Network off by default; the player types a
  location string (no IP, sensor or locale inference); a failed request
  leaves the authored default intact; one request on entry, at most one per
  fifteen minutes; the network layer owns no renderer node and publishes a
  normalized snapshot; a simulate mode feeds the same contract for QA
  (`design/LIVE_WEATHER_CONTRACT.md`). Test network code without a network:
  keep parsing and presentation as static functions tested on hand-built
  JSON, and stub the network by asserting that, with it disabled, no request
  starts and the snapshot is empty. Use canonical field names with no
  aliases; a reported zero is zero output; a request that cannot start
  clears its in-flight gate so a retry can happen
  (`game/tests/LiveWeatherServiceTest.tscn`).
- **Deterministic per-instance character.** Derive a fixture's or entity's
  personality from a stable authored id (hash to seed), and keep the
  classification of generated flavour (not authored, debug-surface only) in
  the generator payload so regeneration cannot erase the audit's authority
  boundary (`tools/author_light_provenance.py`).
- **Invisible systems must be testable.** A pressure model with no meter
  exposes its state and a force call only to tests and the debug panel
  ("an invisible system that only fires on its own schedule is untestable
  by definition"). Measure before redesigning: the haunting audit found 54%
  of authored acts unreachable because the ordinary state sat below the
  gates (`design/ORISON_HAUNTING_AUDIT.md`). When an audit changes a tuned
  constant, ship the fix with the old value and the audit's path in the code
  comment (`game/scripts/reality/sanity_director.gd`), file taste changes to
  the queue with their numbers, and record by name any system that looked
  idle and was deliberately kept.
- **The world is borrowed, not damaged.** A presentation effect snapshots
  every object it touches and restores it on an unconditional timer
  (`game/scripts/reality/intrusions.gd`, 26 s). A meta effect that looks like
  it touches the operating system or the save writes nothing real and has a
  hard wall-clock ceiling. A safety net returns the player to the last valid
  floor anchor when they leave the world, checking for non-finite values
  first, at high physics priority (`game/scripts/player/safety_net.gd`).
- **Would you do it twice, for no reward?** Test every interaction against
  six properties: resistance then release; discrete states with a commit;
  sound is the reward; immediately reversible; consequence optional; visibly
  a mechanism. The default tier is a mechanism of an hour or two. A rules
  module, a real minigame, is the exception and must earn it. "Do not build
  systems nobody can feel" and "do not promote a good mechanism into a bad
  game" (`design/PROP_ACTIVITIES.md`). A Zelda-like lives or dies on this.
- **Census the interactables, then rule each family.** A headless scene
  instantiates the production world and dumps facts only to JSON (class,
  count, prompts, colliders, audio, persistence), with a README giving the
  re-run command and the expected summary line
  (`game/tests/interaction_inventory.gd`). Rule every family into exactly one
  closed disposition: OPERATE, INSPECT, RESIST-REFUSE or AMBIENT
  ARCHITECTURE (`design/PROP_SET_INTERACTION_MATRIX.md`). Do not manufacture
  interactions to improve a percentage; one collider on a merged batch never
  counts as covering hundreds. Work in this order: fix dishonest silence,
  give owners to mechanisms that already have state, map gameplay visuals to
  their owners, add sparse hero targets, leave bulk ambient.
- **Minigames as pure rules modules.** Each rules module is a reference-
  counted object with no camera, input or frame, content in JSON, testable
  headless; a panel draws it and locks the player on open; the prop that
  opens it is a hand-sized handle, not the big geometry.
- **Input audited to named blockers.** A 24-row action-by-device matrix, a
  raw-event ownership hazard table, a modal ownership state table, pad-only
  smoke tests, acceptance criteria, an implementation order ("refactor
  before binding"), forbidden marketing wording, and an implementation
  notice that names tests with counts and says it is "not a certification
  claim" (`design/CONTROLLER_INPUT_CONTRACT_AUDIT_2026-08-26.md`).

---

# PART VII. HUMANS IN THE LOOP

## 17. Human acceptance

Automated evidence proves exactly the declared contract it ran, in one boot,
driven by test code. Human evidence proves that a person who did not build
the game can do the thing. The rule appears in every load-bearing place on
the source project: "do not infer it from a green unit test"; "a green test
is not one of the eleven checks"; "a capture receipt proves capture
integrity, not beauty, usability, fear, clarity or player comprehension";
"agent visual inspection grants no human acceptance."

### 17.1 The gate table

Every player-facing promise carries: what the automated suite actually
proves, what manual observation is still required, who signs (the owner),
what claims are forbidden while the gate is open, and what it blocks (public
demo, early access) (`design/EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md`).

### 17.2 Run cards

Written by the AI for a human in player language with no class names, ids
or coordinates, and with destinations deliberately withheld so the card
cannot pre-solve the beat. Fix the scope (fresh save; no console, debug
panel or noclip; no coaching; stop at the first unclear transition); a setup
table (build SHA, machine, input, defaults); separate the two jobs that
spoil each other (one uninterrupted walk; N independent save-and-reload
checks); per beat, what you are trying to do, what proves it happened,
where to save, what must reconstruct, and fill-in fields; stop rules (no
hint after confusion; "passed, but..." is a fail); an "if you get stuck,
the only thing to write" section; a verdict block with admissibility conditions;
and the routing rule: one observed failure becomes one bounded task named
after the missing transition (`design/GOLDEN_SHIFT_HUMAN_RUN_CARD_2026-08-27.md`).
A shorter disposition form runs four sessions (work, ignore, abandon,
meddle) and asks only non-leading questions.

### 17.3 Acceptance receipts

The AI produces a checkpoint marked HUMAN ACCEPTANCE PENDING plus an evidence
packet whose review sheet carries per-frame submission checks, a human
checklist and **one** perceptual question. The owner answers. The AI then
writes a receipt: reviewed commit (full SHA), accepted packet path, verdict,
owner statement in the owner's words, checklist answered, accepted non-
blocking debt (listed so it is neither re-litigated nor forgotten), and a
scope boundary stating what the receipt does **not** authorize. A decision
not to run the card is recorded as a deferral document named so the ledger
refuses it (`design/ORISON_V2_GOLDEN_SHIFT_DEFERRAL_2026-08-29.md`).

### 17.4 The punchlist

One row per finding: room | symptom with the instrument named | severity in
{blocker, ugly, wish}, plus resolved and info rows kept as evidence. Intake:
blockers immediately; uglies only when route-visible or a reproduced family;
wishes only after a playtest or owner promotion; update the existing row
rather than duplicate; diagnose repeated rows as one family before touching
instances (`design/walkthrough_punchlist.md`).

### 17.5 Tester builds

A deterministic artifact with an exact file contract (executable, data pack,
tester README, build id, licence, third-party notices); monotonic build
numbers never reused; hashes inside the build id and a hash sidecar for the
archive; a README template filled from the exact commit that carries
install, security-warning, input status, content note, microphone and
network consent, local files and a problem-report format; a feedback form
whose first required field is the build id; per-person revocable keys on an
unlisted page (a public playtest was refused because it has no expectation
of secrecy); a six-rung gate (exportable, packageable, distributable,
installable, playable, diagnosable) each proved by a different act; and the
stop rule that agents create no account, key, secret, spend or agreement
(`design/FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md`,
`distribution/README_TESTER.txt`).

### 17.6 Cohort operations

Usability testers and paid lived-experience reviewers are different
populations with separate ledgers and an immutable lane field. Facilitator
conduct is a strict intervention ladder. Session records keep OBSERVATION,
INTERPRETATION and DEFECT apart; only the owner writes a defect at triage;
every defect names its denominator ("2 of 6"); a preference never becomes a
defect by repetition; one anecdote is not consensus; a harm claim and a
no-harm claim are not symmetric. Cohort size follows the five-user rule;
follow-up cohorts must be new people because "a tester who has played it
cannot get lost in it again". Cadence: two players (can they finish
unaided), three (do they know their next intention; 80% of transitions
self-resolved within 45 s, `design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md`),
three fresh (is it good), with instrumented go/no-go; "no-go is a hold, not a scope cut"
(`design/FIRST_HUMAN_PLAY_COHORT_OPERATIONS_2026-08-27.md`).

### 17.7 Where the source project stood

As of 2026-09-21 no human had completed the golden-shift run card, no tester
had received a build, five scoped human acceptances existed and one was
pending. The instruments were built before the audience arrived; that is
the right order, and it is also a warning that instruments are not the game.

---

# PART VIII. THIRD-PARTY SOURCES

## 18. The registry

Everything external the source project used, with how provenance was kept
and what to do on a new project. "Terms unrecorded" means the repository
does not state the terms in force at the time of use; on a new project that
is an UNKNOWN the release audit will block on, so record the terms URL and
product tier at first use (section 15.4).

### 18.1 AI agents and advisory models

| Source | Used for | Terms | Provenance practice | New project |
|---|---|---|---|---|
| **Claude Code** (Anthropic; Fable 5, Opus 5, Fable 5.1) | Primary engineer from 2026-07-29: 723 co-authored commits; web sessions as author "Claude"; later interim management and verifier | Vendor terms; not recorded in-tree; no vendored code | `Co-Authored-By` trailer on every commit; session URL trailers on web sessions; named-path staging | Keep. Put `AGENTS.md` and a one-line `CLAUDE.md` in the first commit; require trailers; worktrees at short paths. |
| **OpenAI Codex** ("Astra", gpt-6-astra, ultra effort, no approvals, full sandbox) | The Feb 2026 MVP; from 2026-08-13 the second engineer in the same tree; from 2026-09-04 the executive under a written mandate | Vendor terms; not recorded | `design/astra/` packet: decision log, evidence directories with per-run receipts, a hash-bound live ledger | Keep with caveat: a second agent is valuable for adversarial review. Give it one integration line from day one and an in-tree decision log. Do not run a no-approval, full-access agent on a shared tree without the lane and staging rules in place first. |
| **ChatGPT** as an outside support model for the songbook lane | Creative advice via a committed handoff prompt; paused for five days | Service use | Handoff prompt and re-entry conditions committed as design documents | Keep with caveat: commit the handoff prompt and the delta log so a lane survives a pause. |

### 18.2 Generative AI services

| Source | Used for | Terms | Provenance practice | New project |
|---|---|---|---|---|
| **Google Gemini** image generation | Primary generator for material and wall-finish plates (277 tracked raw sources, never shipped) | Terms at generation time unrecorded (licence audit open question) | Raw sources tracked outside the export; generator identified by filename prefix; watermark scrub; provenance census | Keep with caveat: a `.source.md` beside every raw plate on day one (generator, date, prompt, terms URL); scrub watermarks; never ship raw sources. |
| **ChatGPT / OpenAI image tool** | Alternate material candidates, character memory and wall art atlases, telegram paper, title hero images, dream substance plates | Unrecorded beyond generator and date | `SOURCE.md` per set with generator, date, selection note and exact prompt | Keep with caveat: copy the per-set source file convention; add terms URL and product tier. |
| **FLUX.1-schnell** via a keyless Hugging Face Space and `gradio_client` | The first 16 wall-finish sources, fixed seeds, prompt saved beside each PNG (`art/tools/fetch_wall_sources.py`) | Weights Apache-2.0; Space terms not restated | Deterministic seed plus prompt sidecar; the script is the record | Keep with caveat: a public Space can vanish; record model revision and seed. |
| **Meshy** (image-to-3D, text-to-motion) | All hero and background characters (17 to 18 residents plus creatures), one vehicle | Not recorded in-tree | Raw exports ignored and re-downloadable; roster JSON names the dump date; pipeline docs describe every transformation | 3D: keep with caveat (record tier and terms at download; ignore raw exports from the first commit; merge clips before commit). 2D: not needed; a sprite pipeline is the unknown of section 14.4. |
| **Gemini app music / Lyria 3** | 36 library tracks, 3 title tracks, songbook audition candidates, from attached public-domain scores | Product tier, model, dates, terms and disclosure text are unfilled owner fields | Per-track manifest with prompt, score source, disclosure line and owner fields; masters SHA-256 pinned; audition-only until the register is filled | Keep with caveat: fill the manifest at generation time; keep AI music out of the shipped tree until rights fields are filled. |
| **Sora** (video) | In-game television clips; a watermark visible at close range | Not stated | A dated decision in the punchlist with a revisit condition | Keep with caveat: log the same kind of dated decision; a source note per clip. |
| **Windows offline TTS** | 34 placeholder voice takes to prove the dialogue chain; discarded by owner ruling 2026-08-26 | OS component; nothing shipped | Provenance register records the generation and the discard order | Keep with caveat: label placeholders as such in filenames so they cannot be mistaken for finals. |
| Cascadeur AI, Motorica | Named as intended targets of animation prompt sheets; never run | Unknown | Prompt conventions only | Not needed; name a tool only once it has produced an artifact. |

### 18.3 Engine, DCC tools and libraries

| Source | Used for | Terms | Provenance practice | New project |
|---|---|---|---|---|
| **Godot Engine 4.7.1** (console build; Forward+ desktop, compatibility mobile) | The game and the test host; export templates installed per machine | MIT; a static notice paragraph links the engine licence page | Version pinned in the project features and in the runner's binary name; binary hash recorded in evidence batches | Keep. Pin the exact patch version in the project file and the runner; run only the console build through the wrapper; do not commit the binary. |
| Godot 4.2+ / 4.4+ | Throwaway prototypes and the external compiler runtime | MIT | Each prototype's project file records its version | Not needed; start every prototype on the pinned engine. |
| **Blender** (5.2 in practice; the art README still says 4.5) | World compiler (`art/blender/scripts/build_orison.py`), prop regeneration, critter anatomy, character conversion | GPL tool; outputs are project-owned | Version stated inconsistently across docstrings; regeneration proven by byte-identical double export | 3D: keep, pin one version in one place the scripts assert against. 2D: not needed. |
| **ffmpeg 7.1** pinned by absolute path (an 8.x build on PATH broke a full day) | Every decode, encode, resample, loudness and clip build; self-decode verification of every encode | LGPL/GPL build; execution dependency only | Pinned path in every script with a warning on fallback | Keep. Pin an exact build by path; self-decode every encode; prefer Ogg Vorbis. |
| **gdtoolkit 4.5** (GDScript parser) | Source-only checkpoints when the engine could not run | MIT | Installed from an unpinned cache path outside the repo (a gap) | Keep with caveat: pin it in a requirements file; a parse is not a compile. |
| **Pillow, NumPy** | Texture ingest, watermark scrub, contact sheets, sheet measurement, id-pass readers, music analysis | HPND, BSD-3 | Imports named in scripts; no requirements file (a gap) | Keep; add a requirements file in the first commit. |
| **Python 3 standard library** (3.11+) | Every audit, gate board, receipt, verifier, lint, glTF builder, push tool, and `tools/tests/` are stdlib-only by policy | PSF | Docstrings state "standard library only" | Keep. Stdlib-only gate tooling is the most portable decision in the project. |
| glTF 2.0 specification | Direct manipulation of buffers and accessors in Python builders; per-floor import with name-suffix semantics | Khronos, royalty-free | Builder and check scripts are the record; outputs hash-compared | 3D only. |
| Theora / Vorbis | In-game video clips; long-form audio and title masters | Xiph BSD-style | Encoding recipe in the build script and the attribution file | Keep Vorbis; avoid Theora unless video is essential. |
| Godot addons, Asset Library, GDExtension | None used; recorded as a negative finding | n/a | Negative finding in the licence audit | Keep the no-addons default; if one is adopted, add its licence to the notice generator the same day. |
| godot_wry, gdCEF (webviews) | Evaluated and rejected 2026-08-08 (no render-to-texture on both platforms) | Not adopted | Decision kept only in agent memory (a weakness; the other agent cannot read it) | File rejected-dependency decisions in-tree. |
| pygame-ce, pytest | The pre-engine sibling project | LGPL, MIT | pyproject only | Not needed; stay on the engine. |
| PowerShell 7 and Windows PowerShell 5.1 | All runners, the lane broker, packaging scripts | MIT; OS component | Runner exit-code contract documented; receipts replace typed codes | Windows: require pwsh 7 explicitly. Cross-platform: Python-only wrappers and a flock file instead of a named mutex. |
| Windows named mutex and process census | The machine-wide engine lane | OS API | Lane ledger and receipts record holder and outcome | Keep; replace with a flock file on Linux and macOS. |
| xvfb-run | Documented path for windowed captures on headless Linux; unused here | MIT/X11 | Header comments | Only for Linux CI captures. |
| VS Code, Docker/WSL lane check, OneDrive | Editor; an unused container lane check; the pre-consolidation project folder that still receives some off-repo evidence | Various | Machine config only | Do not encode editor choice; never keep a checkout or evidence under a sync folder. |

### 18.4 Asset sources

| Source | Used for | Terms | Provenance practice | New project |
|---|---|---|---|---|
| **Freesound** (15 recordings: 7 CC0, 8 CC BY 4.0; 3 CC BY-NC excluded) | Ambient beds, events, prop loops, mechanical one-shots | CC0 needs no notice; CC BY shipped in the notices file; NC files listed as excluded and unreferenced | `ATTRIBUTION.md` keyed by source id, title, author, licence; masters ignored; derivatives committed; notice generated at package time | Keep exactly this. |
| Kenney, Sonniss GameAudioGDC, Pixabay audio | Recommended sources with licence-chain notes; not used | CC0 / bundle licence / Pixabay licence | Recorded as candidates with terms before use | Keep a pre-vetted source list with licence notes on day one. |
| **Courier Prime** (OFL 1.1) | HUD body and title type; the only shipped font | OFL: notice and licence text must accompany each copy | `OFL.txt` beside the font; the notice generator asserts its text and fails without it | Keep. For pixel art swap for an OFL bitmap font with the same discipline. |
| ESO GigaGalaxy sphere; NASA SVS lunar mosaic | Night-sky foundation and the moon disc | ESO credit recorded, licence line missing (verify CC BY 4.0); NASA "supplied for rendering use" with requested credit | `.source.md` sidecars with publisher, credit, URL, retrieval date | Add a Licence line to the sidecar template so the gap cannot recur. 2D: not needed. |
| **Wikimedia Commons** (and the archives reached through it) | Sole fetch source for prop reference photographs because its metadata carries machine-readable licences | PD, CC0, CC BY, CC BY-SA accepted; NC, ND, fair-use and unlabelled refused with the refusal recorded | `provenance.json` beside each ignored file; bytes never committed (RUL-007) | Keep for any reference imagery, 2D or 3D. |
| Owner-supplied photographs and plates; the 100-source biology dossier | Inspiration and species contracts | Per-source; some copyright reference-only | SHA-256 and source JSON; per-row licence table with a separate checker pass; "not cited" section for anything unconfirmed | Hash and licence-tag owner references; keep copyright-only references out of the repository entirely. |
| Escher and Klimt reference images committed in the pre-engine sibling | Reference beside AI tiles | Escher under copyright; Klimt public domain | None: a recognised legacy violation of RUL-007 | Ignore reference folders from the first commit; purge copyrighted references from history before any public release. |

### 18.5 Platforms and services

| Source | Used for | Terms | Provenance practice | New project |
|---|---|---|---|---|
| **Git for Windows**, git worktrees, `.gitattributes`; git-lfs installed but unused | The shared multi-agent repository, up to 34 concurrent worktrees | GPL-2.0 | `AGENTS.md` git rules; `.gitattributes` comments explain each `-text` line | Keep. Commit `.gitattributes` in the first commit with explicit `-text` for hash-bound files and `binary` for engine assets. |
| **GitHub** (HTTPS remote, Git Data API, `gh`) | Sole remote and backup; PRs #1 to #8, then a push target; archive tags and backup branches | Terms of service; rate limits | Remote endpoints listed in the repository truth packet; push workarounds documented | Keep with caveat: ignore every large binary from the first commit and add a pre-commit size guard so chunked-push tools are never needed. |
| **itch.io** (unlisted project, per-person keys, butler) | Recommended first tester channel; nothing created yet | Creator docs cited by URL; account and key are owner-only actions | Runbook cites the docs; owner actions listed separately | Keep: the cheapest private tester channel for any game. |
| **Steam** (Steamworks accessibility labels, Playtest, Early Access rules) | Planned primary distribution; the accessibility label list and screenshot rules were audited; Playtest refused as a private channel | Partner documentation, accessed 2026-08-26 | Audits cite the docs with access dates and refusal reasons | Keep with caveat: read the accessibility and screenshot rules before the first store asset. |
| **Open-Meteo** geocoding and forecast | The build's only HTTP client: optional live weather, off by default | Public API; attribution and commercial terms unrecorded (open question) | Contract document, privacy audit, tester README disclosure | Only if live data is a feature; default off, disclose, record the provider's terms in-tree before first use. |
| Android SDK, JDK 17, debug keystore; a separate WebView devkit outside the repo | Engine Android exports; standalone packaging of the HTML sibling games | SDK licence, GPL with classpath exception | Keystores ignored before creation; versions in the README | Only if mobile is a target; pin SDK versions to the export template; ignore keystores before creating one. |
| NVIDIA RTX 4080, Vulkan 1.4 | Named as capture and performance hardware in every checkpoint so numbers are not over-generalised | n/a | Hardware and renderer line recorded beside every perf number | Keep: always record GPU, driver and resolution beside any performance number. |

### 18.6 Reference material

The source project cites primary sources beside every historical,
mechanical, medical or design claim and never copies their text or images:
expired patents and period advertisements for mechanisms (a
`historical_source` field per maintenance activity); museum and archive
records paraphrased to mechanical fact for in-game copy (`design/PROP_TRIVIA_RESEARCH.md`,
research ledger rows R001 to R057); public-domain scores as music prompt
inputs; period construction and building-pathology articles as findings-to-
implementation tables; primary biology literature cited in the header of
any algorithm derived from it; NOAA and USNO formulas tested against
published instants; the engine's own documentation cited with version and
access date, unknowns filed as unknowns; medical charities and research-
ethics guidance for the depiction review, with fetch dates and 403 flags
recorded; the five-user rule and consent guidance for cohort operations;
named design precedents in code headers ("not copied dialogue"); public-
domain slang with attestation ids; public-domain art (Klimt) as art
direction named in the brief. The pattern that transfers: cite by URL with
an as-of date, label documented / inferred / authored, paraphrase to fact,
and re-verify before release.

### 18.7 The negative census

A dated grep census (2026-09-25) found no substantive use of Suno, Udio,
ElevenLabs, ambientCG, Poly Haven, textures.com, Midjourney, DALL-E by
name, Stable Diffusion, ComfyUI, Unsplash, Pexels, Sketchfab, Mixamo,
Krita, GIMP or Audacity. Keep a dated negative census beside the positive
registry so an audit can prove absence, and re-run it before each release.

### 18.8 The licence ledger a new project keeps from the first asset

One machine-checkable file (proposed on the source project as
`game/data/asset_provenance.json`, never created): every exported path
matches exactly one provenance family (original, generated-with-manifest,
licensed-with-attribution, public-domain-with-citation, reference-only-
never-shipped); UNKNOWN plus ships fails the package. The notices generator
reads only in-tree licence texts and fails closed. The owner chooses the
project's own licence and copyright entity in the first commit; on the
source project both were still pending at release-preparation time.

---

# PART IX. THE RULES

## 19. Hard-won rules, with their scars

The house grammar for a rule is *"X is not Y"*, because slogans propagate
between agents and sessions where paragraphs do not, and every rule carries
its scar so the next agent does not re-litigate it. Sources:
`AGENTS.md`, `design/ORISON_GENETIC_MEMORY_2026-08-29.md` (1,626 lines),
`design/ENGINE_RELEASE_PIPELINE_LESSONS_2026-08-27.md`, the management
dispatches, the `.gitignore` and `.gitattributes` comments, and the Claude
agent's cross-session memory. Install each rule **before** you need it;
every one of them was installed here after the loss.

### 19.1 Artifacts nothing consumes

- **A write is not a use. A missing consumer produces no output, and no
  output never fails a test.** Two save floats survived four save versions
  unread; 415 authored outfit values, a 17-household decorating brief and a
  10,516-line tool family with no caller all passed every test they owned.
  Rule: census readers at field granularity; the acceptance criterion for
  authored data is a named consumer symbol (file and line), never an
  internal consistency proof.
- **Ask whether the table is derivable before authoring it.** Author the
  query, not the table.
- **When an orphan is found, look for the hardcoded duplicate in the
  consumer before deleting it.**
- **State the minimum population at which a share or balance system becomes
  observable, and assert it.**
- **Give every audit finding a disposition typed by who can close it**, with
  a default action written at authoring time.
- **Catch the class with a build-failing invariant whose allow-list is empty
  and named**, never the instance.
- **A README asserting consumption is not consumption.** A data file whose
  own comment asserted seven readers had none.

### 19.2 Prove the red before you believe the green

- **A green instrument is not trusted until a fixture makes it red.** The
  runner reported exit 0 for every failing suite for 334 commits, and every
  exit code recorded in that window had to be thrown away.
- **One exit code never stands for two facts.** 73, 124 and 78 were split
  from measured suite durations, not a round number.
- **A dark or default-state capture is NO RESULT, not NO DEFECT.**
- **A boolean cannot see 64 mm.** A bound equal to the thing's own
  displacement is a tautology; ask where your expected value comes from.
- **Count artifacts declared before the run, not only the exit code.** A
  timeout with no capture line is a budget failure, not an image failure.
- **A flaky test is worse than a failing one.** Root-cause it (H21).
- **Bisect; do not profile the commit list for a plausible culprit.**
- **A capture proves frames rendered. Only a receipt the test writes proves
  execution.** (RUL-003)
- **Headless passes vacuously** for rendering counters, instanced reads and
  mouse capture: those suites run windowed.
- **A shader that fails to compile falls back to a lit material and looks
  like a lighting bug** while the harness reports frames saved; assert the
  shader compiled.
- **The instrument was the broken thing, not the subject**, six times out
  loud. Date your apparatus and re-run everything certified while it was
  broken.

### 19.3 Prose is not evidence, and access is not authority

- **A backtick is not a type.** A ledger that globbed design documents let
  a bug report satisfy the requirement it reported. Evidence intake is by
  filename allowlist decided before the file is opened; inert documents
  write ids in bold (RUL-011).
- **Repository access is capability, not authority.** A directive's clause
  licensing implementation without proposals was struck on process grounds.
- **Rigour deepens a review; it does not widen its corpus.** A 364-line
  ruling produced by five adversarial readers was struck 69 minutes later
  because nobody had grepped the covenant for the licences it contradicted.
- **File the workflow output or cite it as unfiled.** A "313-system census"
  was cited twice with no filed source.
- **Quote every number with its corpus.** A diagnostic printed the first
  eight keys of an eighteen-key dictionary and an invented contradiction
  reached the owner as a recommended action.
- **Run a proposed audit change against the real tree before recommending
  it.** A "free win" both reviewers recommended produced 48 false positives.
- **Retract in place, dated, and reopen every decision the false finding
  closed.** Management quoted "first slice 0" four times before a hardened
  tool showed 7.
- **Readiness is scoped; no green state implies the one below it.**
  Exportable, packageable, distributable, installable, playable,
  diagnosable are six different acts.
- **The human gate sits where the evidence is a first encounter.** A green
  test is not one of the eleven checks.
- **A report is not a consumer.** A commit proves bytes exist; a passing
  focused test proves its declared contract; a capture proves capture
  integrity; nothing more.
- **Owner statements are statements, not findings.** Record them verbatim
  and label them.

### 19.4 Measure before you architect

- **A documented engine limitation is a claim with a date on it.** Three
  places asserted the renderer lacked a feature it had.
- **Run the null experiment and publish the noise floor beside every
  delta.** Two identical renders differed on 86% of pixels because residents
  move.
- **A finding at one member is a fact about that member.** Write beside
  every general claim which members you measured.
- **If a 2x change in the knob moves the output less than 10%, instrument
  the mechanism instead of tuning.**
- **Name which resource each dial spends.** Free in milliseconds, 1,024 MB
  in VRAM.
- **Stamp the input revision into generated artifacts;** a stale build tests
  green.
- **Construct the situation rather than sampling the simulation.** A rare
  state is staged by hand for its capture.
- **Name the datum in the same expression as the offset and publish the
  resolver as a shared function.** Five clocks disagree because nobody ruled
  the epoch.
- **A centreline is not a face.** Four repeats in one day.
- **Print the number actually in force.** A wrong budget survived in three
  documents because nothing printed the one the code used, and a sweep
  silently no-opped for weeks.

### 19.5 Gates that do not rot

- **A baseline is a ratchet, not permission.** New fails; changed class
  fails; removed is a clean note; deleting the whole baseline must still
  exit clean.
- **Identify findings by meaning, never by line.**
- **Count what the scanner suppressed.**
- **For every finding class, commit the fixture that turns it red, and point
  the detector at a tree you know is ill.** Ban the shape, not the
  vocabulary.
- **Restate every UI prohibition as a storage or API invariant.**
- **Encode "undecided" as a checked value, but enumerate the decided states
  too.**
- **Put the contract in the generator, not the generated output.**
- **Expect an honest metric to move against you first**, and publish the
  expected movement before landing.
- **A false blocker is a tooling defect**, never something to route around
  by renaming a room.
- **Rehearse acceptance machinery on a synthetic subject.**
- **Boards of different tool versions refuse to compare.**
- **Verification machinery arrives the week the audience becomes
  external.** Every audit tool arrived between 08-26 and 08-28, 22,848
  lines in three days, the week early access was chartered. Name that date
  in advance and build it earlier.

### 19.6 Several agents in one tree

- **A worktree isolates files, not the machine.** One engine at a time via
  a named mutex plus a process census; never close a human's window.
- **Never `git add -A`.** Five incidents: swept scratch, a 170 MB binary the
  remote refused, another session's staged files committed under the wrong
  message, 40 minutes of untracked bakes deleted by a peer's commit cycle.
  Stage named paths and read `git diff --cached --name-only` before every
  commit.
- **Never a bare stash.** The stack is shared.
- **"Untracked" is a statement about your index, not the remote.** 47 id
  files minted by a stale import would have rewritten identities.
- **Autocrlf silently changes the SHA-256 of hash-bound text on a fresh
  checkout;** raw-hashing a working copy with mixed endings breaks the same
  way. Mark outputs `-text`, hash inputs LF-normalized, prove it in a fresh
  worktree at a short path.
- **Deep paths exceed MAX_PATH and break the import cache.**
- **A fresh worktree with no import cache fails every test with a
  parse-error cascade that is not a code bug.** Import twice first.
- **Nested `pwsh -File` flattens arrays**, so the engine silently ignores
  `--script`.
- **Rule every shared frame (axis, origin, epoch, id namespace) in writing
  before the second author.**
- **Audit the file the shipped program actually opens, not its twin.**
- **Record the failed approach beside the rule**, because an agent
  optimising locally routes around an unexplained constraint.
- **A dirty tree is not a state a task may end in.** One sat dirty for
  thirteen days.
- **Archive-then-remove with SHA-256 manifests;** use `git status -z`
  because `--porcelain` escapes non-ASCII paths.
- **Two lines that both believe they are canonical are a defect** (26-file
  conflict). One integration line (RUL-002).
- **Reviews meant for the other agent go in one fenced copy block**, not
  prose, so they can be pasted whole.
- **Decisions kept only in one agent's memory are invisible to the other
  agent.** File them in-tree.

### 19.7 Engine and asset traps

- **Only the console binary prints to stdout.**
- **A parse error idles forever;** every run has a ceiling.
- **The Project Manager window holds the lane.**
- **Force-track the import settings of runtime-loaded textures**, or mipmaps
  vanish on a fresh checkout and the shimmer returns.
- **The engine rewrites import and id files' line endings;** restore before
  committing; never commit an id the remote has under a different value.
- **Merged storey meshes hand the per-object light cap to an arbitrary
  subset**, so corridors went black at the far end while their domes glowed.
- **Depth fog density is a ceiling, not a rate;** at 0.86 every distant slab
  kept 14% contrast forever.
- **One material per buffer:** the DCC export merges by material, so a
  finish emitted with one winding per orientation back-face-culled from its
  own room and only west walls had ever rendered.
- **Lamp, then freeze; aim before physics off; the euler-spin pivot trap;
  measure the wall first.** Four proof-sheet re-shoots
  (`art/renders/watch_station_sr7j/README.md`; the agent memory note on render harness traps).
- **A lambda captures by value in this engine's script;** two hours lost
  twice.
- **Generator watermarks roll onto every tile** through the seamless
  crossfade and into every derived map; measure and unblend them on the
  sources, never paint over.
- **An AI source only takes its slot if it beats the current set** against
  reference, in-engine.
- **Lettering in generated textures is the single most-broken rule.** No
  letters, numbers, words or logos; lettering is a label node (RUL-008).
- **Reference photographs inform form only;** never baked, projected or
  committed (RUL-007).
- **Masters are re-downloadable; the merged deliverable is committed.** A
  400 MB zip cost a day of failed pushes.
- **A model ships and renders exactly as exported;** baked scaling lost
  twice to unit normalization.
- **Pin the ffmpeg build by path;** an 8.x build on PATH cost a day.
- **Two copies of a data file without a diff tool drift within days.**

### 19.8 Planning and scope

- **Milestones are evidence gates, not dates.**
- **Polishing half a loop is not progress.** The first pass may be plain; it
  may not omit a beat.
- **Do not build two quest systems.** Two beginnings, one job state.
- **Do not build systems nobody can feel. Do not promote a good mechanism
  into a bad game.**
- **Every owner direction phased to "done" in a day is a breadth risk;** the
  scope audit ranked the largest such sequence first under "stop building
  this now". Run the scope audit early and after every new sequence.
- **A build is not a release.** Six rungs, each proved by a different act.
- **No-go is a hold, not a scope cut.**
- **Nothing reaches evidence level four without a second game.**
- **Draft outlives implementation:** a NOT-CANON design draft can stay
  useful for months; label it and do not let it promote.

### 19.9 Talking to the creator

- **Quote the owner verbatim, date it, file it, then act.**
- **Do not silently select a gated item; ask.**
- **Ask few questions, once, with defaults attached.** The owner answers in
  one-liners.
- **The safe default is applied and marked, and the owner may tighten it.**
- **Anything that amends an owner ruling or resolves the central ambiguity
  is the owner's by name.**
- **Retract publicly, in the record, dated.**
- **A deferral is written so it cannot later be read as approval.**
- **Silence is never approval** (sensitive-topic review).
- **An empty field is a claim we do not make** (platform declarations).
- **Report faithfully:** if a suite failed, say so with the receipt; if a
  step was skipped, say so; a nonzero-but-known exit is reported as nonzero.
- **A capture receipt proves capture integrity, not beauty, usability, fear,
  clarity or comprehension.** Never claim what only a human can accept.

### 19.10 More rules from the lessons registry

Consolidated from the 191-entry lessons registry built for this manual;
each is generic and each has a scar.

**Evidence and measurement**
- **Every measurement script includes a planted failure it must detect
  before its pass is believed.** A clearance check still said PASS with a
  crystal planted inside the flesh; the cage was wound inside out
  (`design/HERO_TENTACLE_REMAINING.md`).
- **Define detectors by structure, not keywords, and publish recall on code
  you did not write.** A regex was false on the exact violations it was
  commissioned to find (`design/ORISON_VERIFICATION_MIDDLEWARE_ASSESSMENT_2026-08-29.md`).
- **Confirm absence by reading the code path, never by one grep.** A grep
  for the check returned only a PNG; the validator had landed four commits
  earlier (`design/ORISON_PARANORMAL_PLURALISM_ASSESSMENT_2026-08-29.md`).
- **Measure visual changes inside declared regions of interest with their
  own noise floors, never as whole-frame averages.** A swapped 4 cm object
  scored 0.003 over a 720p frame (`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md`).
- **Never sample a periodic system once;** assert on the peak over a window
  longer than any period in it, and construct the rare situation in the test.
- **Give machine-read identifiers a syntax prose cannot emit by accident**,
  and parse decisions only from designated structures.
- **When data has no reader, search the intended consumer for a hardcoded
  copy before deleting the file, and make the code read the data.** A dial
  map was deleted as dead while its hardcoded twin stayed
  (`design/ORISON_GENETIC_MEMORY_2026-08-29.md` Part 1).
- **Bisect every regression; when a suspect is cleared, edit every document
  that named it.** The first suspect, chosen by recency and plausibility and
  named in two committed records, was innocent (`TASKS.md` H20).

**Engine and runtime**
- **Accelerate tests by shortening the specific wait, not by scaling the
  world**, and record displacement per step whenever time is scaled. At 4x
  the walk test passed through walls; engine timers scale with time scale,
  so an 8x probe watched one simulated minute (`game/tests/walk_test.gd`).
- **Derive environmental state from authored facts through one owner query,
  never from a proxy that happens to correlate.** A height test classified
  the 19.2 m roof as indoors (`design/LIVE_WEATHER_CONTRACT.md`).
- **Derive every navigation point from authored geometry, test routes leg by
  leg with raycasts, and query collision with the actor's real shape.** The
  ground floor became eleven islands before a raycast test caught seven wall
  crossings (`game/scripts/characters/resident_nav.gd`).
- **Wait on the physical state, not the request;** make every routing
  failure loud and countable (`design/astra/RESIDENT_HOME_DOOR_2026-09-19.md`).
- **Give every modal one owner that acquires and releases input and focus
  exactly once**, and never let a modal commit share a button with a polled
  world verb. The lock flag had at least four writers
  (`design/INTERACTION_CONTRACT_2026-08-27.md`).
- **Make every randomised director stand down under test**, and keep any
  enumerable set in one constant that tests iterate.
- **Reset every in-flight flag on failure paths, and construct consumers
  before producers that publish on entry.** A simulated weather snapshot
  publishes synchronously on entry, so construction order matters.
- **Read engine object properties through the base-class API.** A
  subclass-only property read threw on the first spotlight, aborted the
  shadow budget loop, and turned an audit PASS into 77 failures
  (`game/scripts/building/light_rig.gd`).
- **Measure the precision of any per-instance channel on the target renderer
  before packing data into it;** only the high byte survived exactly.
- **Put the affordance guard in the base class so every interactive object
  is hittable, and make every refusal visible and explained.** The census
  found four dishonest silences (`design/PROP_SET_INTERACTION_MATRIX.md`).

**Performance**
- **Measure draw submissions for any effect and record the rejected
  alternatives with their numbers.** Three particle approaches cost 2.18 to
  2.66 ms before two batched meshes with shader streaks cost 0.455 ms
  (`design/ORISON_DRIVING_RAIN_SKY_PROPOSAL.md`).
- **Represent distant or numerous glows as emissive geometry, never as real
  lights**: under-door bars and roughly 1,570 neighbour windows
  (`art/docs/photoreal_target.md`).
- **Shadow casters are a budget separate from lights;** a new fixture ships
  with shadows off and earns a slot (owner ruling L13 in `TASKS.md`).
- **Budget the binding constraint (memory, skinning) rather than polygons.**
  173k extra triangles cost 0.1 ms; the texture maps would not fit a phone
  (`game/docs/character_budget.md`).

**Art**
- **Judge materials by sampling pixel values against neighbours in a real
  render, and fix physically, not with brightness cheats.** Flat brass lit
  from above measured darker than the oak beside it.
- **Classify every material as tiling or composition at ingest;** permit
  rotation only for grainless materials. Rotated oak laid boards across the
  room.
- **Divide out low-frequency lighting before any seamless pass**, gate with a
  relative threshold, and keep landmarks out of tiling swatches
  (`art/tools/ingest_material_sources.py`).
- **Turn research into named generator parameters with sources**, and record
  deviations as deliberate (`art/docs/research_1927_construction.md`).
- **Identify the writer of every file before editing it;** edit the authoring
  source, regenerate, and gate byte equality between mirrors.
- **Exchange generated assets between repositories as sealed archives with a
  hash the consumer re-verifies.**
- **Photograph every specimen with a calibrated harness, and record
  instrument findings separately from content critiques**
  (`tools/prop_reference/README.md`).

**Planning and creative direction**
- **Default every interaction to its smallest satisfying mechanism**, and
  require an argument before adding rules or scoring. The owner ruled the
  target is a fidget spinner, not a minigame (`design/PROP_ACTIVITIES.md`).
- **Add states, tasks and interfaces only when an observed instance demands
  them.** The telephone router's enum omits states no mechanism reaches
  (`game/scripts/building/house_telephone_network.gd`).
- **Add a gate only for a named defect; ask each milestone what is enjoyable
  in it; record what every supersession gives up**
  (`design/ORISON_DREAM_TAPESTRY_RULING_2026-08-29.md`).
- **Never let a fiction frame serve as a defect disposition;** every fact
  still needs an owner.
- **Give each uncanny entity one rule-breaking property, and test for
  restraint** (`design/DREAM_FIELD_DIRECTION.md`).
- **Test a third-party addon against the one non-negotiable requirement
  first;** vendor foreign code by scripted copy with a class prefix.

**Licensing, privacy and audio**
- **Clear every composition worldwide with dated evidence per work, and never
  depict or imply a real person without their own words**
  (`design/ORISON_SONGBOOK_MUSIC_BIBLE.md`).
- **Trace every capability's full production path before calling it
  opt-in.** The weather opt-in governed which coordinates were sent, not
  whether a connection happened
  (`design/FRIENDS_BUILD_PRIVACY_AND_CONSENT_AUDIT_2026-08-26.md`).
- **Measure every generated output objectively before a human listens.** Two
  music candidates arrived in the wrong meter and onset autocorrelation
  caught them.
- **Assume the session can end at any moment:** commit work in progress with
  a written resume sequence, and process long data incrementally.
- **Keep the repository root free of any engine project**, and never keep a
  submodule pointer without its `.gitmodules` and a reachable commit. The
  legacy arcade directory is empty on every checkout.

---

# PART X. WORKED EXAMPLE

## 20. "Build me a battle royale that plays like a knockoff of Zelda in 16-bit style"

This walks the prompt through the method. Dates are relative to receipt of
the prompt. Nothing here is a promise about how long a real project takes;
it is the order of operations and what proves each step.

The example starts from a sentence. Had the creator played the oracle
instead, day 0 would follow section 5.8: the packet answers most of the
questions in 20.1 with evidence or with a stated default, and the scope
would be a pocket game, not this one.

### 20.1 Day 0: decompose, inventory, covenant, questions

1. Create the repository with the day-zero record (section 5.7):
   `design/DAY_ZERO_<date>.md` quoting the prompt verbatim with its
   SHA-256 and the decomposition table from section 5.1; the machine and
   inventory packet (`design/MACHINE_INVENTORY_<date>.md`, 5.2); `DOCS.md`;
   `TASKS.md` with task sections **K** core loop, **A** arena, **C**
   characters and items, **W** networking, **R** release, **D** owner
   decisions, **H** housekeeping; `AGENTS.md` from Part II with the evidence
   prefix chosen (3.2); `design/OWNER_MANDATE.md` with the reserved list
   (2.6); `HANDOFF.md` with machine setup; `design/RULINGS.json` with an
   empty list (2.2).
2. Write `design/EXECUTION_PLAN.md` (INERT) with a milestone ladder:
   **M0** instruments (20.2); **M1** golden match against bots (20.3);
   **M2** art and audio pipeline (20.4); **M3** scope audit, second slice
   and friends build (20.5); **M4** online play, gated (20.6); **M5** release
   (20.7). Task letters in `TASKS.md` are for task ids only, never for
   milestones. Quote the filtering question at the top of the plan and in
   every dispatch, proposed: *"Does this work make the next complete match
   more readable, more tense or more fun to play again?"*
3. Write `design/<GAME>_BIBLE.md` (section 6.1). Section I: the aesthetic
   statement, proposed: *fast, fond, readable; sixteen strangers, one
   overworld, one survivor; every death is legible.* The governing engine
   sentence, proposed: *every fight is decided by something the player
   picked up and understood, never by something they could not see.*
   Section VIII: the one-sentence test *"Could this have shipped on a 1994
   cartridge?"* with licensed exceptions (rebindable input, integer
   scaling, a modern save system, online play if ruled). Section VI opens
   with the disputes you cannot settle: the IP boundary, the multiplayer
   mode, the platform. Section II holds the device every match repeats: the
   closing ring. Section IV says: *"No authored cast. Player avatars are
   interchangeable. A named character opens this section by owner
   ruling."* Section V is the table from 6.3. Section VII opens with the
   laws the manual already implies: generated assets are never hand-edited;
   debug affordances are debug-only; `reduce_flashing` zeroes every flash at
   its single writer.
4. Send the owner one message with five questions (section 5.3), defaults
   attached: online versus local-and-bots first; platform and store; the IP
   boundary; player count and session length as feel targets; budget for
   paid services. Ask for the licence sentence (section 5.4) if not
   offered. Proceed on reversible defaults only; nothing leaves the
   repository until the owner answers (5.3).
5. Apply defaults and mark them: bots first, online as the gated milestone
   **M4**; Windows first, with itch.io friends builds once the owner creates
   the account; original names, art and music, homage to conventions only;
   8 to 16 players, five to eight minutes; zero paid services.
6. Build the day-one rows of 9.1 before the day-zero commit: the engine
   runner, run receipts, the rulings checker and the design-document lint.
   They need no gameplay code.
7. Commit everything in one commit whose body quotes the prompt.

### 20.2 Week 1: instruments before content

Build the day-one and week-one rows of section 9.1 before the first
gameplay script: the serialized engine runner with one-fact exit codes,
run receipts, the rules file and rulings index with its checker, the
design-document lint, the reader gate with an empty baseline, the gate
board with a baseline board, the candidate verifier in fresh-checkout mode,
the capture wrapper and shot harness, and `tools/tests/` pinning every exit
code with fixtures. Push a deliberately failing test through every wrapper
and confirm nonzero at the reader (section 8.9). Write `HANDOFF.md` build
mechanics as you go. Record the engine version and every version-specific
API the harness relies on in one place.

Set the 2D contract in the project file with a dated, measured comment on
every rendering setting: a fixed internal resolution (propose 320 by 180 or
256 by 224; the owner's taste decides, under the licence), integer scaling,
nearest-neighbour filtering, a fixed palette file the style audit reads,
pixel-snapped cameras, and the input map registered in code from an autoload
with polled named actions (section 10.4).

### 20.3 Weeks 2 to 6: the golden match

The vertical slice is one complete match against bots (section 7.2). Beat
table, proposed:

| Beat | Player action | Required payoff |
|---|---|---|
| Drop | choose a landing spot on the overworld map | the choice visibly matters (loot density, distance from the first ring) |
| Loot | open a chest, pick up a sword, a shield, one tool | each pickup changes what the player can do, readably |
| First fight | a bot with the same verbs | damage, hearts, knockback, i-frames legible at 16-bit scale |
| Movement item | a tool that changes traversal (hookshot-class, bombs, boots) | a shortcut the player can see |
| Ring closes | the arena boundary advances | a threat that reads without a HUD explanation |
| Forced encounter | the ring pushes two players together | the fight the ring wrote |
| Last circle | two left, small arena | a duel the loadout decides |
| Win or die | a legible end | the death screen names what killed you |
| Post-match | one screen | what you found, who won, queue again |

Build it plain and complete; polish nothing until it exists end to end.
Architecture per section 11: one owner per fact (a match director that
connects the ring, loot, players and bots and owns none of their rules; a
loot library that loads JSON and refuses a malformed record; player facts in
one save-shaped document even if nothing persists yet); data-driven
everything (items, loot tables, ring schedule, bot temperaments, arena
markers in JSON with headers per section 12; the reader gate holds new work
to zero unread fields); a deterministic arena generator (Python writes the
tilemap and marker JSON from a seed; the engine assembles it; the same seed
produces the same bytes).

Prove it three ways before calling it landed: a headless suite that plays
one whole match at time scale 1.0 on a test ring schedule
(`game/tests/data/ring_schedule_fast.json`, phase durations in seconds),
shortening the specific waits rather than scaling the world (19.10), and
writes its own runtime-contract receipt with the four named contracts
(8.1, 21.10); a windowed capture packet of
the nine beats from the real player camera with per-frame hashes and an
A/A control (section 8.6); and a human run card (section 17.2) for the owner
and one friend: *fresh install, no coaching, play one match, stop at the
first moment you cannot tell what to do next.* The run card's finding
becomes one task each in **K**. Write the production-contract document
`game/docs/match_loop.md` after the code exists (section 3.5). Write the
milestone checkpoint (section 8.5) and, after the owner plays, the
acceptance receipt (section 17.3) with its scope boundary: it does not
authorize online play, a store page or any content beyond the slice.

### 20.4 Weeks 6 to 10: the art pipeline and the first real assets

Until now the slice ran on placeholder tiles. Now file the research layer
(section 6.7): the 16-bit hardware constraints as a document with sources,
then a style audit tool that checks every committed sprite and tile against
the palette and cell grid and fails the gate board on a violation. Build the
2D chain of section 13.2: tileset and sprite-sheet build from a closed
palette catalogue; naming that carries collision; an inspection scene under
flat light that photographs every asset family for review.

Generative assets go through section 14: prompt sheets as design documents
with the disciplines of 14.3 (count-based scale, the lettering ban, what not
to generate, an invariant preamble for character consistency); a filename
inbox; a deterministic ingest that re-quantises to the palette, slices on
the cell grid and writes a provenance sidecar; owner review by render; the
ruling recorded verbatim. Because this repository holds no sprite pipeline
evidence (section 14.4), the first two weeks of this phase are a filed
research task: which generator respects a hard pixel grid, how to keep a
character consistent across eight directions and five animations, whether
to generate at all or commission. State the unknowns as unknowns in the
checkpoint. Every asset carries its provenance family from the first
commit (section 18.8); nothing with UNKNOWN ships.

Audio per section 15: the bus tree as data, the cue catalogue with captions,
a bounded voice pool, CC0 and CC BY only with an attribution file, music
masters outside git with manifests, the notices generator wired into the
packager on the day the first licensed asset arrives.

### 20.5 Month 3: scope audit, second slice, friends build

Run the scope audit (section 7.7) now, not later: classify every open task
as launch blocker, attention multiplier, post-launch, cut or evidence-only;
write the one-sentence promise, the content ceiling (how many items, how
many arena biomes, how many bot temperaments), the critical path, the
stop-building list with restart triggers, and numeric go/no-go for fresh-
player tests. Expect the audit to find that arena breadth or item variety
has been eating capacity; that is what it is for.

Then the second slice adds only what the audit ranked as launch blocker:
usually more items than arenas, a second bot temperament so matches differ,
and the post-match loop. Each lands with a checkpoint, a receipt and a
punchlist pass (section 17.4).

Prepare the friends build (section 17.5): the six-file contract, monotonic
build numbers, the tester README template, the privacy audit (no network
yet, so it is short), the licence and provenance audits with stop rules,
and the six-rung gate. Nothing is distributed until the owner creates the
itch.io project and keys; agents create no accounts. Run the fresh-player
cadence of section 17.6 with two, then three, then three new players.

### 20.6 Month 4 onward: the online decision

Battle royale implies many humans in one match. Online play is a reserved
owner decision because it changes cost, operations and privacy. Present it
as a brief (section 3.7): the authoritative-server model the engine's high-
level multiplayer supports, the deterministic simulation the bots already
run on, what the save and match directors must not change, the consent and
privacy surface (names, voice, IP exposure), the hosting cost, the moderation
surface, and the acceptance evidence (a windowed two-client test through the
runner; a run card played by two humans on two machines). Milestone **M4**
lands beside the local mode behind a selector whose default stays local
until the owner authorises cutover (section 7.9), with an explicit rollback.
If the owner rules bots-only for release, the brief stays filed as a ruled
deferral, not a silent cut.

### 20.7 Release

The release pipeline of section 9.1 runs in this order: warm checkout with
cold import as a stage, export through the runner with a clean-tree
requirement, package with the three audits and the notices generator, the
release performance matrix on a second machine, the static pipeline contract
test, a rehearsed and timed rollback, the launch-week runbook with a first
patch or public note within a week. Store declarations follow section 6.6:
only labels with a filled evidence row. The engine knowledge ledger (section
7.8) records what this project taught that the next one can reuse, graded
honestly; nothing above L3 until the next game consumes it.

### 20.8 What the owner is asked, in total

Five questions on day zero. One licence sentence. A one-line ruling on each
brief (art direction, the online mode, the store page, the content ceiling).
The perceptual acceptance question at each checkpoint. Playing the run cards.
Creating accounts, keys and the licence text. Choosing the project's own
licence and copyright entity. Everything else is the team's, under defaults
the owner may tighten.

### 20.9 Honest risks in this plan

- A one-line prompt cannot decide taste. The manual makes the team ask
  little and propose much, but the owner still has to look at renders and
  play the run cards, or the game converges on the defaults.
- The 2D generative pipeline is unproven in this repository. Budget the
  research task and be prepared to commission or hand-author sprites.
- "Battle royale" hides an online-multiplayer project inside a 2D action
  game. Bots-first is the only way to reach a shippable slice in weeks; the
  online milestone is its own product.
- The verification machinery in Part V is roughly 83 tools on the source
  project. A small team builds the day-one and week-one rows and adds the
  rest only when a loss shows the need. Section 24 says what to skip.
- The IP boundary is a legal question the team can state but not settle.

---

# PART XI. APPENDICES

## 21. Templates

Copy these; every one is derived from a file in this repository named
beside it.

### 21.1 The rules file (`AGENTS.md`, read by every agent through a one-line `CLAUDE.md` containing `@AGENTS.md`)

```
# Working in this repository
Rules for every agent and every person. Each rule has an id (RUL-nnn) whose
source `python tools/check_rulings.py --show RUL-nnn` prints. DOCS.md says
which document wins a disagreement.

## Current checkout (<date>)
<where normal development happens; what to do with temporary checkouts>

## Git in a shared tree (RUL-nnn)
- Stage named paths only. Never git add -A, git add . or git commit -a.
- Never a bare git stash; prefer a WIP commit.
- Restore the engine's line-ending-only churn before committing; never
  commit an id file origin/main has under a different value.
- Hash-bound files are -text in .gitattributes; hash text LF-normalized.
- Worktrees at short paths. Branch from origin/main; main is the one
  integration line.

## The engine lane (RUL-nnn)
- One engine process at a time across every worktree; run only through
  the runner; exit 73 busy, 124 killed at ceiling, 78 cannot run.
- A fresh worktree needs --import twice. Screenshots need -Windowed.
- Every run gets a -LogPath; cite the receipt, not the exit code.

## Evidence and the ledger (RUL-nnn)
- Evidence is admitted by filename marker; every design document states
  its class in its first 30 lines; inert documents write ids in bold.
- Runtime proof is only a receipt the test writes.

## Gates and reports
- The gate is "nothing regressed against main's board".
- Every candidate is verified in a fresh checkout before merge.
- Reports use the fixed format and end MERGE-CANDIDATE | BLOCKED | NEEDS-OWNER.

## Art
- No lettering in generated textures; reference photos inform form only
  and are never committed; generated assets are never hand-edited.
- Verify by rendering, never by reading code.
```
Source: `AGENTS.md`.

### 21.2 The covenant skeleton

```
# THE <GAME> BIBLE
*The book of what is true. <date>.*
Where any other text disagrees with this one, this one prevails until
amended. A later explicit owner ruling prevails over this text and is folded
into it as a dated amendment. Where this one is silent, the systems of record
in section V speak. Disputed texts are confessed openly in section VI.

## I. THE WORD           aesthetic statement (ruled <date>); the one engine sentence
### I.1 THE LOOP         the core loop's fiction
## II. THE MOTIF         the recurring device
## III. THE WORLD        place, rules, antagonist
## IV. THE CAST          one line per character with a wound or want; why these; what this does not license
## V. THE SYSTEMS OF RECORD   one authority per question
## VI. DISPUTED TEXTS    numbered; interim holds until ruled; ruled items struck through with RULED <date>
## VII. THE LAWS         numbered, short, enforceable
## VIII. THE STYLE TEST  one sentence every object passes; licensed exceptions; dated rulings with
                         "what this does not license" and "consequences elsewhere"
```
Source: `design/ORISON_BIBLE.md`. Write every heading even when the game has
no use for the section; under one that does not apply, write one line saying
why and what would open it (20.1 step 3 shows this for a game with no
authored cast).

### 21.3 A brief's first lines

```
# <SUBJECT> BRIEF
*Proposed <date>. **Not canon until the owner rules.***
Evidence class: **INERT**
Owner direction, verbatim (<date>): "<sentence>"
Read as N decisions: 1. ... 2. ...
Already true / New / Adopt / Amend / Reject (tables, each with the file it lives in)
Owner decisions: 1. ... (default applied: ...; the owner may tighten)
The risk I care most about: ...
Sources: ...
```
After ruling, the header becomes `**Status: APPROVED, BINDING PRODUCTION
DESIGN (<date>).**` Sources: `design/ORISON_SERVICE_ROUND_BRIEF.md`,
`design/ORISON_MAZE_BRIEF.md`, `design/ORISON_STUDIO_BRIEF.md`.

A subsystem brief's body runs in this order: the promise in one sentence; an
audit of existing production truth; cited foundation (research, precedent);
a census of required endpoints or entities; an ownership contract; the rule
that ordinary operation is built before any special or uncanny variant; a
teaching sequence for any new vocabulary; art and sound budgets; required
focused and production-live tests; render proof; numbered delivery phases;
explicit refusals; a completion gate (`design/HOUSE_TELEPHONE_ECOLOGY_BRIEF.md`).

### 21.4 A direction document

```
# <SUBJECT>, OWNER DIRECTION (<date>), verbatim
*This file is the ruling and is not edited. <BRIEF>.md is the concept brief
and the build log.*
---
<the owner's text, untouched>
---
## Status (engineer, appended)
```
Source: `design/DREAM_TENTACLE_DIRECTION.md`.

### 21.5 A checkpoint document

```
# <MILESTONE> checkpoint, <date>
Evidence class: **EVIDENCE - CHECKPOINT** (or INERT - TECHNICAL CHECKPOINT
for a line the ledger must not read)
Base commit / branch / selector:
Pre-edit ledger declaration: rows this checkpoint will move: ...
Verdict and bounded change: what changed (named files); what did NOT change
Ownership map (written before implementation decisions)
Measured numbers, with margins and the noise floor
Focused test: <scene> N/N, exit 0, receipt <path>
Capture packet: <dir>, per-frame SHA-256, camera class, A/A control
Ledger before -> after; evidence-impact receipt for this document
Protected paths: n/n; selector asserted
Regression battery: command | exit | result (nonzero-but-known reported as nonzero)
Remaining limitations and accepted debt
Decision: MERGE-CANDIDATE <sha> | BLOCKED <reason> | NEEDS-OWNER <question>
Human review: PENDING | recorded in <receipt>
```
Sources: `design/ORISON_V2_M11B_SERVICE_OPENINGS_CHECKPOINT_2026-08-30.md`,
`design/DREAM_ECOLOGY_E1_CHECKPOINT_2026-08-28.md`. Never delete a field;
write none with the reason when it does not apply yet (section 2.4).

### 21.6 A human acceptance receipt

Prose (`design/ORISON_V2_M11B_HUMAN_ACCEPTANCE_RECEIPT_2026-08-31.md`):
reviewed commit (full SHA); accepted packet path; verdict; owner statement
in the owner's words; the exact question answered; accepted non-blocking
debt; scope boundary ("this receipt does not authorize ..."). JSON
(`design/ORISON_V2_M08A_HUMAN_ACCEPTANCE_2026-08-28.json`): schema_version,
receipt_type, reviewed_commit, accepted_packet, verdict, owner_statement,
owner_confirmation, checklist[], scope, authorization{...: false}.

### 21.7 A run card

Scope block (fresh save; no console, debug or noclip; no coaching; stop at
the first unclear transition; the watcher stays silent). Setup table (build
SHA, machine, resolution, input, audio, settings changed, fresh save
confirmed, start and end time). The jobs, separated. Per beat: what you are
trying to do; what proves it happened; where to save; what must
reconstruct; fill-in fields. Stop rules. "If you get stuck, the only
thing to write." Verdict block with admissibility conditions. Routing: one failure,
one bounded task. Source: `design/GOLDEN_SHIFT_HUMAN_RUN_CARD_2026-08-27.md`.

### 21.8 A dispatch record

Sections: 1 where the work actually is; 2 findings on in-flight work; 3
findings on main; 4 rulings by management (owner may override); 5 the serial
queue with a gate-to-start and a deliverable per task; 6 decisions the owner
must make; 7 the required report format (section 2.4); then dated appended
reviews and the merge record. Source:
`design/ORISON_V2_INTERIM_MANAGEMENT_DISPATCH_2026-09-13.md`.

### 21.9 A data file header

```json
{
  "schema_version": 1,
  "meta": {
    "source": "design/<DOC>.md",
    "authored": "hand-transcribed <date>; edit this file and the doc together",
    "schema": { "<field>": "one sentence per field" },
    "kind": "hand-transcription | generated-projection | research-copy-book"
  },
  "field_semantics": { "<field>": { "classification": "in_world_fiction", "rights_record": null } },
  "expected_count": 0
}
```
Sources: `game/data/resident_schedules.json`, `game/data/prop_service_wire.json`,
`game/data/music_catalog.json`.

### 21.10 A test script skeleton (GDScript)

```gdscript
extends Node
# <Suite>: one-line contract. Scope: what this does NOT prove.
const EXPECTED_CHECKS := 12
var _failures := 0
var _checks := 0
var _contracts := {}          # name -> {"executed": bool, "status": "PASS"|"FAIL", ...}

func _ready() -> void:
    OS.set_environment("DAYNIGHT", "0")        # pin the world
    # disable persistence, reset the campaign, seed as a first launch would
    var nodes_before := Performance.get_monitor(Performance.OBJECT_NODE_COUNT)
    var res_before := Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT)
    var world := load("res://scenes/<root>.tscn").instantiate()
    add_child(world)
    await get_tree().create_timer(1.0).timeout   # settle
    _check(world.has_node("Player"), "player present")
    _contract("production_composition", _failures == 0, {"identities": ["<unique id>", "<unique id>"]})
    # ... save and reload through the real save owner  -> _contract("save_reconstruction", ...)
    # ... attempt an action before its precondition   -> _contract("premature_action_denial", ...)
    world.queue_free()
    await get_tree().process_frame
    await get_tree().process_frame
    var retained_nodes := int(Performance.get_monitor(Performance.OBJECT_NODE_COUNT) - nodes_before)
    var retained_res := int(Performance.get_monitor(Performance.OBJECT_RESOURCE_COUNT) - res_before)
    _contract("teardown", retained_nodes == 0 and retained_res == 0, {"measurement_scope": "runtime_owned",
        "retained_nodes": retained_nodes, "retained_resources": retained_res,
        "retained_playbacks": 0})   # ask the audio owner for its live playback count
    var exit_code := _failures if _checks == EXPECTED_CHECKS else 1
    _write_receipt(exit_code)
    print("RESULT: %s checks=%d expected=%d failures=%d" % [
        "PASS" if exit_code == 0 else "FAIL", _checks, EXPECTED_CHECKS, _failures])
    get_tree().quit(exit_code)

func _check(cond: bool, label: String) -> void:
    _checks += 1
    if cond:
        print("[ok] " + label)
    else:
        _failures += 1
        print("[FAIL] " + label)

func _contract(name: String, passed: bool, extra := {}) -> void:
    var row := {"executed": true, "status": "PASS" if passed else "FAIL"}
    row.merge(extra)
    _contracts[name] = row
    _check(passed, "contract " + name)

func _write_receipt(exit_code: int) -> void:
    var path := OS.get_environment("RECEIPT_PATH")
    if path.is_empty():
        return                               # suites that claim no runtime proof skip this
    var test_path: String = get_script().resource_path     # res://tests/<suite>.gd
    var receipt := {
        "schema_version": 2, "evidence_kind": "runtime_contract",
        "production_runtime": true, "selector": OS.get_environment("SELECTOR"),
        "execution": {"completed": true, "exit_code": exit_code, "timed_out": false},
        "source": {"test_path": "game/tests/" + test_path.get_file(),
                   "test_sha256": FileAccess.get_sha256(test_path),
                   "repository_head": OS.get_environment("REPOSITORY_HEAD"),
                   "runtime_inputs_sha256": OS.get_environment("RUNTIME_INPUTS_SHA256")},
        "contracts": _contracts,
    }
    var f := FileAccess.open(path, FileAccess.WRITE)
    f.store_string(JSON.stringify(receipt, "  "))
    f.close()
```
Sources: `game/tests/walk_test.gd`, `game/tests/shot_harness.gd`, and the
admission rules in `tools/audit_orison_v2_completeness.py`
(`runtime_receipt_errors`). The runner computes the commit and the
runtime-inputs digest before launch and passes them in the environment,
because the engine cannot hash the tree it is running from. The test writes
the exit code it is about to pass to `quit()`; the verifier compares it with
the run receipt's exit. Print check lines only as `[ok] <label>` or
`[FAIL] <label>` and one final `RESULT:` line. The source project's receipt
writer counts any line containing the words PASS or FAIL, which is looser
than it should be; on a new project count only these prefixes. The engine's
resource monitor includes the loader cache, so a scene loaded once stays
counted after teardown; scope the measurement to objects the runtime
created, which is what the source's `runtime_owned` scope means. This
skeleton has not been run; the source project has not yet produced a
schema-2 receipt from any test (section 25), so prove the first one red
before trusting it (8.9).

### 21.11 Receipt fields

Run receipt (`tools/run_receipt.py`): schema, evidence_kind suite_run,
completed, exit, timed_out, elapsed, commit, tree, dirty_paths, scene,
root_test_script and its SHA-256, runtime_inputs_sha256, log hashes, PASS
and FAIL counts, stale_import_cache. Runtime contract (schema 2, written by
the test, exactly as the ledger checks it): schema_version 2, evidence_kind
runtime_contract, production_runtime true, selector, execution {completed
true, exit_code 0 as an integer, timed_out false}, source {test_path under
`game/tests/`, test_sha256, repository_head, runtime_inputs_sha256},
contracts as an object keyed by the four names, each {executed true, status
"PASS"}, with production_composition.identities a non-empty list of unique
strings and teardown {measurement_scope "runtime_owned", retained_nodes 0,
retained_resources 0, retained_playbacks 0}. Capture receipt
(`tools/run_godot_capture.ps1`): frames with SHA-256, camera class,
capture_gates, timing checkpoints.

The runtime-inputs digest is the SHA-256 of compact, ASCII-escaped UTF-8
JSON holding the sorted list of [relative POSIX path, SHA-256 of the file's
bytes] pairs over every game script, scene, resource, data file and the
project file (`tools/run_receipt.py`, `runtime_inputs_sha256`). The source
project hashes raw bytes; on a new project hash LF-normalized bytes so the
digest survives a Windows checkout (section 4).

### 21.12 The session pickup block

```
## <date> pickup: <one line>
- Governance: who holds authority; where the rules are.
- Where the work stands: <ledger counts>, <selector>, <protected n/n>.
- Read first, in this order: ...
- Immediate next action: ...
- Execution order (serial): ...
- Non-negotiable constraints: ...
- Open owner decisions: ...
- The next deliverable to the owner: ...
- Do not silently select a gated item; ask.
```
Source: `design/next_session_plan.md`.

### 21.13 A rulings index entry

```json
{ "id": "RUL-001", "date": "<date>", "authority": "owner | executive | management | practice",
  "summary": "<one sentence>",
  "source": "<in-tree path> | branch:<name>:<path> | <decision id> | owner instruction in chat <date>",
  "scope": ["<tag>"], "supersedes": [] }
```
Ids ascend. Retire an entry only by appending a later one that lists it
under supersedes. Source: `design/RULINGS.json`, `tools/check_rulings.py`.

### 21.14 The oracle packet and the build result

The packet's game description (written by `oracle/packet.py`; section 5.8
says how to build from it):

```text
# <working title>
Evidence class: **INERT** (an oracle packet: a design brief derived from play)
## The prompt                     > Build me **<title>**: <pitch>
## What the design stands on      3 dominant, 2 secondary, 1 productive contradiction; each:
                                  the signal, the behaviour it was seen in, the design consequence
## Design implications            8 to 14 sentences an engineer can act on; never scores
## Game Design Vector             31 rows: field, value, the signal that set it (or "default")
## Negative constraints           "No ...", "Do not ...", "Avoid ...": laws
## Personal callbacks             from <what the player did>, becomes <what it is in the game>
## The feature nobody asked for   the feature, and the behaviour it follows from
## What is not known              each unknown, and that nothing in the design depends on it
## The prophecy                   card, what the player was told, what makes it true
## Scope constraints              engine, size, art, audio, players, privacy, run and test
## How to build from this
```

The build result the builder writes in the project root when it stops:

```json
{ "status": "ok | failed",
  "title": "<final title>",
  "play_command": ["<executable>", "<arg>"],
  "summary": "<two sentences: what was built>",
  "visions": [{"card": "<card title>", "fulfilled_by": "<what in the game makes it true>"}],
  "defaults_applied": ["<each choice made where the brief was silent>"],
  "known_gaps": ["<anything promised that is not fully there>"] }
```

The play command is run from the project root. A result that claims a vision
is no evidence that the vision is true; the acceptance receipt (21.6) is.
Source: `oracle/content/builder_prompt.md`, `oracle/builder.py`.

## 22. Maintaining this manual

This is a living document. It stays true only if it is edited when the
practice changes.

- **When a ruling lands** (a new RUL-nnn, a covenant amendment, a new tool
  in `tools/PIPELINE_TOOLS.md`), add or amend the section that describes
  the practice and cite the ruling. Sweep the manual with `git grep` for
  the old practice the same day, as section 4 requires for the tree.
- **When a lesson is learned**, add it to Part IX in the "X is not Y" form
  with its scar (commit, file, cost), and add the rule to `AGENTS.md` if
  agents must obey it.
- **When a third-party source is adopted or dropped**, edit section 18 and
  the negative census.
- **Keep the evidence-class header** (`INERT`) and write ids in bold; run
  `python tools/lint_design_doc.py docs/AI_GAME_DEVELOPMENT_MANUAL.md`
  before committing.
- **Date every edit** in the status line at the top and keep the derived-
  from commit current. Do not rewrite history; append a dated correction
  where the manual was wrong, as management does in its own records.
- **Verify citations** when a cited file moves. A citation that no longer
  resolves is a defect in this manual, not in the tree.
- **Cross-agent**: this file is the one both agent vendors should read
  after `AGENTS.md`; add its row to `DOCS.md` and keep it there.
- **When the oracle changes** (its packet format, its event protocol, its
  scope constraints), edit 5.8 and 21.14 the same day. `oracle/DESIGN.md`
  is the oracle's own design record and `oracle/content/` its data; this
  manual only says how to build from what the oracle produces.

## 23. Day-one checklist

In order. Each item names its section.
When the prompt is an oracle packet and not a sentence, read 5.8 first: it
changes items 1, 10, 11 and 14, and the first column of section 24 cuts
most of the rest.

1. Quote the prompt verbatim with its hash; decompose it (5.1).
2. Machine and inventory packet with four-way labels (5.2).
3. Covenant skeleton with the one engine sentence, the one-sentence style
   test, the systems-of-record table and an open disputed-texts list (6).
4. `DOCS.md` with the kinds table and precedence ladder (3.1).
5. `TASKS.md` with lettered sections and a **D** section (3.3).
6. `AGENTS.md` from 21.1; `CLAUDE.md` containing `@AGENTS.md` (2, 4).
7. `design/RULINGS.json` and its checker (2.2).
8. `.gitignore` with an incident comment per rule; `.gitattributes` with
   `-text` for anything hash-bound; engine binaries never tracked (4).
9. `design/OWNER_MANDATE.md` (INERT) with the licence sentence quoted and
   dated and the reserved-decision list from section 2 (2.6).
10. Five questions to the owner with defaults; the licence sentence (5.3, 5.4).
11. The IP and sensitivity flags stated and routed (5.6).
12. The day-one rows of 9.1: the serialized engine runner, run receipts, the
    rulings checker and the design-document lint, in Python. Push a
    deliberately failing job through the runner and confirm nonzero at the
    reader (8.9). The reader gate, the gate board and the candidate verifier
    follow in week one (9.1, 20.2).
13. `HANDOFF.md` build mechanics and machine setup (4.2).
14. The vertical slice's beat table and the filtering question (7.1, 7.2).
15. The session pickup file (3.4).
16. The scope-audit date on the calendar, one month out (7.7).
17. The licence ledger and the source and licence policy, before the first
    download (15.4, 18.8).
18. One commit with a body that quotes the prompt.

## 24. Scaling down

| Practice | Solo human plus one agent, small 2D game | Two agents sharing a tree | The source project's scale |
|---|---|---|---|
| Covenant, disputed texts, dated rulings | Yes, always | Yes | Yes |
| Vertical slice first, beat table | Yes, always | Yes | Yes |
| `DOCS.md`, `TASKS.md`, `AGENTS.md`, rulings index | Yes | Yes | Yes |
| Serialized engine runner with receipts | Yes | Yes | Yes |
| Reader gate with baseline | Yes, cheap | Yes | Yes |
| Gate board with baseline compare | Yes | Yes | Yes |
| Candidate verifier in fresh checkout | Yes; the management session runs it, never the owner (2.6) | Yes | Yes |
| Lane broker, lanes ledger | No (one engine, one agent) | Yes | Yes |
| Completeness ledger with scopes | A requirement table in the plan is enough until the second milestone | Yes | Yes |
| Capture wrapper, A/A floors, sheet measurer | A simpler screenshot suite with hashes; A/A once the first visual claim is disputed | Yes | Yes |
| Executive and management roles | One agent plays developer and, in a separate session, management (2.6); the owner rules | Yes | Yes |
| Dispatch records, report format | Report format only | Yes | Yes |
| Evidence packets with before/after snapshots | No | When runtime claims are disputed | Yes |
| Level checkpoint toolchain, provenance forensics | No | When levels are content | Yes |
| Human run cards and acceptance receipts | Yes, always | Yes | Yes |
| Cohort operations, sensitive-topic review | Only if the game touches a real condition or community | Same | Yes |
| Release pipeline with notices generator | Yes, before the first tester | Yes | Yes |
| CI | Yes: run the static gates and the gate board on every push; run engine suites only on a runner that holds the pinned engine binary. The source project has none. | Yes | Yes |
| Oracle front door (5.8) | Optional: when the creator would rather play for half an hour than write the sentence | Same | Not used: the source project began from sentences |

## 25. Open debt on the source project, as read on 2026-09-26

Carried here so the manual does not present the method as finished.

- No schema-2 runtime-contract receipt exists yet in any test; the
  ledger's admission function exists but its first real producer is
  unconfirmed, so seven first-slice rows wait on a real contract run.
- No human has completed the golden-shift run card; no tester has received
  a build; five scoped acceptances exist and one is pending.
- The day-one backup scripts, the README's local-first section and the
  tracked console stub contradict RUL-010 and RUL-002 and were never swept.
- The gate board, verifier, lane broker and runners are Windows and
  PowerShell 7 specific; no POSIX equivalents exist.
- No CI and no installed hooks; every gate runs only when an agent types it.
- The art README says Blender 4.5 while every driver script targets 5.2.
- The reader-gate baseline of 1,308 findings is a frozen count, roughly half
  of it the tracer's own blind spot; it needs triage, not a number.
- The room checkpoint toolchain (10,516 lines) has no caller.
- Two precedence ladders coexist (the map puts the covenant first; the
  authority hierarchy puts the latest explicit owner ruling first); this
  manual follows the authority hierarchy and the map should be amended.
- Terms in force at generation time are unrecorded for every AI image, 3D
  and music service used; the owner has not chosen the project's licence.
- Owner decisions listed open since 2026-08-09 remain unruled; nothing
  nudges the owner to close old disputes.

## 26. How this manual was derived

Twenty-five read-only reader passes over this repository at commit
**3e46e7b** on 2026-09-25 and 2026-09-26, each over one area (governance,
pipeline tools, evidence, the engine harness, art, audio and licensing,
the multi-agent model, planning, architecture, creative authority, lessons,
git history, prototypes, generative assets, human acceptance, and ten gap
areas found by a completeness critic: population simulation, the horror
layer and production contracts, Python-built assets and provenance
forensics, environment and lighting, drifted instruments and git
configuration, audio as gameplay and the songbook, the executive's evidence
convention, props and input, the dream ecology and direction documents,
and the data layer), consolidated into registries of third-party sources
(75 entries), lessons (191 entries) and a ten-phase timeline, then written
by one author. The tools and practices registries were not consolidated;
Part V and section 27 were built from the reader maps and the tree instead.

Verification before first commit: every cited path was checked for
existence; every commit count, author trailer count, line count and dated
number was recomputed from git or grepped in its source, and six numbers
with no source were rewritten or removed; every quoted phrase of five words
or more was matched against the tree, and ten paraphrases that sat inside
quotation marks were replaced with the source's words; two independent
critics then read the manual, one as an AI coder trying to act on it and
one against the 25 area summaries, and their thirty findings were applied
after their facts were checked against the code. The design-document lint
passes. The Claude agent's cross-session memory directory was read as data.
No engine, DCC tool or build was run. The receipt-writing test skeleton in
21.10 is therefore unexecuted.

**2026-10-03 addition.** Section 5.8, template 21.14 and the oracle's rows
were written in the same session as `oracle/` itself, by the same author.
What was run for them: the oracle's 81 unit tests; fifty simulated offline
nights; one short live night narrated through the Codex command line; and
the design-document lint on this file and on the oracle's two documents.
What was not run: any engine, and any real build from a packet. Section 5.8
therefore describes a hand-off whose far side is still unexercised.

## 27. Tool inventory

Every script in the tool directories at commit **3e46e7b**, with its own first docstring line (generated 2026-09-26; scripts without a docstring are described from their code). Section 9.1 says which to rebuild first; this list says what exists.

### 27.1 `tools/`
- `tools/analyze_music.py`: Profile candidate soundtrack clips using ffmpeg + NumPy only.
- `tools/analyze_v2_lamp_material_performance.py`: Summarize the scoped native shader and paired GPU evidence; never award V2 acceptance.
- `tools/api_push_main.py`: Land local main on origin without pushing a pack.
- `tools/astra_prepare_inputs.py`: Assemble reviewed decisions and explicit owner-mandated outcome obligations.
- `tools/astra_render_packet.py`: Frozen Git views plus an explicitly sourced live ledger; no Git/game writes.
- `tools/astra_repository_snapshot.py`: Read-only Git census. Rendered reports use this frozen, sorted input.
- `tools/astra_run_audits.py`: Capture exact audit exits; never update baselines or rewrite old receipts.
- `tools/audit_audio_emitters.py`: Static inventory of Orison audio construction and semantic migration debt.
- `tools/audit_authored_voice.py`: Audit an Orison authored-dialogue tree without pretending to grade prose.
- `tools/audit_data_consumption.py`: Find shipped data and durable numeric fields that have no real consumer.
- `tools/audit_interaction_implementors.py`: T10 census audit: the interaction surface must not drift silently.
- `tools/audit_interaction_prompt_carriers.py`: T2 carrier audit: input carriers belong to the player, not the props.
- `tools/audit_music_catalog.py`: Fail closed when the Orison music catalogue confuses lore with rights.
- `tools/audit_orison_floor01_source_ownership.py`: Read-only M11C0 ownership census for the protected floor-one source.
- `tools/audit_orison_rooms.py`: Inventory Orison rooms and flag placement records needing human review.
- `tools/audit_orison_spatial_dependencies.py`: ADMIN-ARCH1 spatial dependency audit: what the building accidentally promised.
- `tools/audit_orison_v2_completeness.py`: ADMIN-ARCH2 completeness ledger: when is the Orison rebuild actually done?
- `tools/audit_period_dates.py`: Audit the Orison's dated data and every structural GDScript year consumer.
- `tools/audit_shot_suites.py`: Inventory Orison screenshot suites without launching Godot.
- `tools/audit_systemic_situation_authority.py`: ADMIN-ETHOS1: hidden quest logic and counterfeit world consequences.
- `tools/author_light_provenance.py`: Author stable characterful lighting cards for every practical source.
- `tools/backup.ps1`: One-command backup that runs git add -A and pushes to main (retired practice; contradicts RUL-010; do not copy)
- `tools/backup.sh`: Bash twin of backup.ps1 (retired practice; runs git add -A; do not copy)
- `tools/bake_wall_finishes.py`: Bake one unique PBR finish set for every room-facing masonry wall.
- `tools/build_historical_radio_notice.py`: Project the reviewed license notice into its shipped display data.
- `tools/build_third_party_notices.ps1`: Assemble THIRD_PARTY_NOTICES.txt from the in-tree licence texts; throws if any is missing or lacks its expected licence strings
- `tools/build_v2_arcade_ceiling.py`: Reference-inspired raised arcade ceiling, built without Blender or Godot.
- `tools/build_v2_authoring_projection.py`: Emit V2 runtime data and test proofs from complete household authoring inputs.
- `tools/build_v2_passage_gateway.py`: Extract the authored arcade entrance from the admitted street owner cell.
- `tools/build_v2_street_section.py`: Register the authored street section at the V2 front-door origin.
- `tools/check_rulings.py`: Check design/RULINGS.json and every RUL-nnn citation in the repository.
- `tools/check_v2_arcade_ceiling.py`: Static checks for the shipped ceiling detail and a labelled geometry study.
- `tools/compose_overlays.py`: Pre-composite stain/wear overlays onto texture sets, export-safely.
- `tools/export_friends_build.ps1`: Export the Windows tester build through the serial runner; requires a clean tree; writes an export manifest with exe and pck hashes
- `tools/gate_board.py`: One command for every static gate, one file for the result.
- `tools/generate_mina_character.py`: Reproducible stylized production character. With no environment configuration
- `tools/generate_resident_cast.py`: Generate the complete Orison resident cast through the shared IK pipeline.
- `tools/lane.ps1`: Lane broker: status | run | batch, waits for the engine lane with -WaitMinutes and holds it across a batch
- `tools/lane_common.ps1`: Shared mutex, process-census and receipt helpers for the runners and the broker
- `tools/lanes.py`: Every line of work in one table: worktrees and remote branches against main.
- `tools/lint_design_doc.py`: Make a design document say what it is, and check that the ledger agrees.
- `tools/m11c0_floor01_rehearsal/` (directory: 2 entries)
- `tools/m11c1_floor01_owner_first/` (directory: 6 entries)
- `tools/m11c1_floor01_rehearsal/` (directory: 3 entries)
- `tools/m11c2_floor01_production/` (directory: 2 entries)
- `tools/material_textures.py`: Turn generated material plates into validated, game-ready texture sets.
- `tools/measure_shot_sheet.py`: Measure and tile an Orison capture without invoking Godot.
- `tools/merge_m11c2_capture_receipts.py`: Merge process-isolated M11C2 Forward+ capture receipts.
- `tools/open_dream_ecology.ps1`: Uses the shared lane; closing the native window ends the inspection run.
- `tools/package_friends_build.ps1`: Package the six-file tester zip after three content audits; mandatory -LicensePath; hash sidecar; never reuses a build number
- `tools/prop_reference/` (directory: 14 entries)
- `tools/prop_reference_tool.py`: Entry point for tools/prop_reference. Run ``python tools/prop_reference_tool.py --help``.
- `tools/push_chunks.py`: Push main's outstanding objects to origin in small bites.
- `tools/rehearse_orison_floor01_partition.py`: Build and verify a disposable, whole-node floor_01 partition.
- `tools/relocate_v2_subway_pavement.py`: Open the sidewalk over the relocated stair without changing its perimeter.
- `tools/room_checkpoint_linter.py`: Read-only linter/scaffolder: make room verdicts machine-checkable BEFORE
- `tools/room_checkpoint_reconciler.py`: Read-only checkpoint reconciler: do room decisions survive regeneration?
- `tools/room_evidence_verifier.py`: Read-only evidence-receipt verifier: proof citations must resolve.
- `tools/room_gate_hook.py`: Opt-in pre-commit runner for the room reconstruction gate.
- `tools/room_layout_workbench.py`: Read-only per-room layout workbench for the Orison.
- `tools/room_reconstruction_gate.py`: One command to decide whether a room checkpoint is landable.
- `tools/room_reconstruction_progress.py`: Read-only floor reconstruction progress ledger for the Orison.
- `tools/run_godot_capture.ps1`: Windowed capture wrapper over the serial runner: time budget, refuse-overwrite, capture_receipt.json with per-frame hashes and capture gates
- `tools/run_godot_long_suite.ps1`: The serial runner's contract at a 1,500 s ceiling for the one long matrix
- `tools/run_godot_serial.ps1`: Runs one Godot scene, one process at a time, and reports honestly.
- `tools/run_orison_v2_m10.ps1`: Historical M10 runway runner for the v2 rebuild
- `tools/run_receipt.py`: Receipts for Godot runs: what ran, against which tree, and how it ended.
- `tools/run_release_performance_matrix.ps1`: Per-station fresh-process performance receipts with machine identity and an admissibility flag
- `tools/street_ownership.py`: Read the false-colour ownership pass written by StreetIdShot.tscn.
- `tools/street_provenance.py`: Stage two: take a mass's probe pixel back to the generator record.
- `tools/surface_library.py`: Process generated stain/wear overlays and furniture/appliance surfaces.
- `tools/synth_plates.py`: Synthesize original procedural source plates for the texture pipeline.
- `tools/test_release_pipeline_contract.ps1`: Static contract test of the whole release pipeline without launching the engine (requires pwsh 7)
- `tools/tests/` (directory: 37 entries)
- `tools/verify_candidate.py`: Verify a merge candidate the way management does, mechanically.
- `tools/warm_release_checkout.ps1`: Cold import as an explicit release stage; commit-bound readiness marker; SHA-256 seal of generated id files

### 27.2 `art/tools/`
- `art/tools/build_broadcast.py`: Build the Orison's television broadcast.
- `art/tools/build_coverage_contact_sheets.py`: Contact sheets for the M-COVER probe.
- `art/tools/build_dream_incarnation_v9_contact_sheets.py`: Join the six already-rendered production incarnation proofs.
- `art/tools/build_fauna_skins.py`: CT-1 -- family skin atlases for the dream fauna, built from the plates.
- `art/tools/build_fx_decals.py`: Generate the building's decal masks: wear, stains, shadows, damage.
- `art/tools/build_glass_maps.py`: Give the Orison's windows the two maps that make old glass look old.
- `art/tools/build_larder_labels.py`: Cut the grocery label sheet into the atlas the refrigerators read.
- `art/tools/build_lobby_notices.py`: Render the notices on the Orison's lobby bulletin board.
- `art/tools/build_mailbank_cards.py`: Render the name card for every box in the lobby mail bank.
- `art/tools/build_mailbank_textures.py`: Generate the lobby mail bank's textures: aged brass, typed name cards,
- `art/tools/build_phone_light_mask.py`: Render the phone-torch light mask.
- `art/tools/build_piano_truck_panel.py`: Compose the signwritten panel for the We Tuna Pianos truck.
- `art/tools/build_piano_truck_projection.py`: Cut the concept turnaround into projection plates for the piano truck.
- `art/tools/build_road_paint.py`: Worn white road marking, because the crossing was painted in linen.
- `art/tools/build_signage_plates.py`: Render engraved brass plates for every sign in the building.
- `art/tools/build_storm_skies.py`: Build the geography-locked four-state Orison storm panorama family.
- `art/tools/build_tv_clips.py`: Process each source video into its own clip for the broadcast director.
- `art/tools/build_wall_finish_textures.py`: Composite per-wall finishes from the AI-generated source library.
- `art/tools/build_window_joinery_maps.py`: Two materials the windows have been borrowing `trim` for.
- `art/tools/export_voice_script.py`: Export a human-readable recording script from a case dialogue tree.
- `art/tools/fetch_wall_sources.py`: Generate the wall-finish source library with FLUX.1-schnell.
- `art/tools/fix_runtime_texture_imports.py`: Give MatLib's runtime textures the import settings Godot never gives them.
- `art/tools/generate_placeholder_voice.ps1`: Placeholder voice takes from the dialogue JSON, via Windows' offline
- `art/tools/generate_runtime_materials.py`: Generate Godot's prop-material contract from the shared material catalog.
- `art/tools/grade_character_textures.py`: Grade the hero-cast albedos into the Orison's palette, in place.
- `art/tools/import_voice_takes.py`: Convert raw voice takes into game-loaded ogg vorbis, matched by filename.
- `art/tools/ingest_dream_material_sources.py`: Ingest case-specific dream substance plates.
- `art/tools/ingest_material_sources.py`: Turn AI-generated material photos into catalog texture sets.
- `art/tools/scrub_source_watermarks.py`: Find and remove the generator's sparkle watermark from AI source photos.
- `art/tools/ship_surface_tables.py`: MX-3 -- ship the height maps calibrated, and the wall mask library.
- `art/tools/slice_contact_sheet.py`: Cut a labelled contact sheet into one source image per cell.
- `art/tools/strip_character_emissive.py`: Strip the self-illumination Meshy bakes into every character export.
- `art/tools/strip_ogv_metadata.py`: Strip container metadata from every shipped .ogv, in place.

### 27.3 `art/blender/scripts/`
- `art/blender/scripts/bacillaria_model.py`: Rigid sliding Bacillaria raft, external builder module only.
- `art/blender/scripts/bake_dream_tentacle.py`: H1 — BAKE THE HERO'S ANATOMY (§19 of the menagerie brief).
- `art/blender/scripts/bake_model_moves.py`: Bake the shared biped clip set onto ONE hero model's own rig.
- `art/blender/scripts/build_dream_critter.py`: Deterministic Blender anatomy pilots; no implicit repository writes.
- `art/blender/scripts/build_dream_tentacle.py`: Build the Dream Tentacle as a LAYERED DEFORMABLE CREATURE.
- `art/blender/scripts/build_gesture_library.py`: Fold the merged Meshy animation packs into one shared gesture library.
- `art/blender/scripts/build_orison.py`: The world compiler: layout JSON to per-floor glTF and the master .blend (docstring says Blender 4.5; the script targets 5.2, which is what runs)
- `art/blender/scripts/build_traffic_vehicle.py`: Turn a raw Meshy export into a vehicle the street can actually carry.
- `art/blender/scripts/check_dream_critter_anatomy.py`: Read-only evaluated anatomy checks; no export, source save or generation.
- `art/blender/scripts/check_dream_tentacle_bind.py`: TB-13 — DOES THE CREATURE HOLD TOGETHER WHEN IT MOVES?
- `art/blender/scripts/check_dream_tentacle_clearance.py`: TB-15 / §23 — ANIMATION CLEARANCE, MEASURED.
- `art/blender/scripts/convert_dump_characters.py`: Convert the Meshy character dump into game-ready hero models.
- `art/blender/scripts/crystal_listener_model.py`: Fictional crystal listener with a stationary receiver and actual rotor.
- `art/blender/scripts/euglena_model.py`: Continuous Euglena pellicle, anterior reservoir and rooted flagellum.
- `art/blender/scripts/euplotes_model.py`: Euplotes cortex and fourteen cirri carried by eight existing gait groups.
- `art/blender/scripts/export_meshy_character.py`: Export the Meshy character to a glTF the game can load.
- `art/blender/scripts/fold_crab_model.py`: Fictional fold crab: one mantle with rooted jointed limbs and mouth organs.
- `art/blender/scripts/heliozoan_model.py`: Original Heliozoan cortex/ray authoring; controller owns selected-ray capture.
- `art/blender/scripts/lacrymaria_model.py`: External Lacrymaria authoring module; no import-time Blender mutations.
- `art/blender/scripts/merge_meshy_animations.py`: Fold a Meshy character and its animation exports into one rigged glTF.
- `art/blender/scripts/mesodinium_model.py`: Bilobed Mesodinium with contained host nuclei and retained prey plastids.
- `art/blender/scripts/noctiluca_model.py`: Original Noctiluca anatomy: vacuolate cortex, sulcus, grooved capture arms.
- `art/blender/scripts/render_dream_critter.py`: Matched studio renders of evaluated anatomy; never saves/exports the source.
- `art/blender/scripts/render_dream_tentacle_grey.py`: THE GREY TEST (design/DREAM_TENTACLE_BLENDER_BUILD.md, the last rule).
- `art/blender/scripts/render_dump_previews.py`: Render a front-view preview of every extracted Meshy character master.
- `art/blender/scripts/render_shop_heroes.py`: Render the static shop heroes in isolation without shipping duplicates.
- `art/blender/scripts/retarget_resident_moves.py`: Retarget Evelyn's Meshy animation set onto the shared resident skeleton.
- `art/blender/scripts/salpingoeca_model.py`: Salpingoeca: separate continuous cells joined through basal extracellular matrix.
- `art/blender/scripts/seam_grazer_model.py`: Fictional seam grazer: continuous low mantle and rooted ventral comb.
- `art/blender/scripts/spirostomum_model.py`: Source-only Spirostomum module for the shared Blender builder adapter.
- `art/blender/scripts/stentor_model.py`: External Stentor authoring draft; no import-time scene changes or exports.
- `art/blender/scripts/volvox_model.py`: External Volvox authoring module; not an admitted runtime asset.

### 27.4 `art/audio/`
- `art/audio/build_viral_seed.py`: Build the viral seed mix and its deterministic runtime feature envelope.
- `art/audio/songbook_candidate_precheck.py`: Songbook candidate processing: one command from a Gemini .mp4 to the
- `art/audio/songbook_scratch_return.py`: Songbook Day-1 tool: scratch vocal -> complete take -> true-varispeed return.

### 27.5 `art/data/`
- `art/data/gen_dream_maze.py`: Deterministic control assembler for the ruled Orison dream maze.
- `art/data/gen_layout.py`: Deterministic layout author for Orison Apartments.
- `art/data/shop_interiors.py`: Static interiors for the eleven shops in the Vantry Arcade.

### 27.6 `oracle/`
Added 2026-10-03, after the inventory above was generated: the oracle front door of section 5.8. Run with `python -m oracle`.
- `oracle/__init__.py`: THE BLANK DECK: a short text adventure that reads how you play.
- `oracle/__main__.py`: The package entry point: runs the command line.
- `oracle/backends.py`: Where the house gets its voice.
- `oracle/builder.py`: Handing the packet to an AI engineer, and telling the player the truth about the build.
- `oracle/cli.py`: Command line for THE BLANK DECK.
- `oracle/content.py`: Loads and validates the authored content in oracle/content/.
- `oracle/devview.py`: The developer view: everything the house knew and why it did what it did.
- `oracle/engine.py`: The night itself: the turn loop that joins the narrator, the world, the player model and the probe selector.
- `oracle/guard.py`: The boundary: this program models play preferences and nothing else.
- `oracle/model.py`: The hidden player model.
- `oracle/narrator.py`: The house with a model behind it.
- `oracle/offline.py`: The house with no model behind it.
- `oracle/packet.py`: The oracle packet: what the night hands to whoever builds the game.
- `oracle/probes.py`: Choosing what the house deals next.
- `oracle/session.py`: One night in the house: world state, session state, and persistence.
- `oracle/simulate.py`: Simulated players.
- `oracle/synthesis.py`: From how someone played to the game they should be given.
- `oracle/ui.py`: Terminal presentation: wrapping, a typewriter, a spinner, and a scripted stand-in for tests.
- `oracle/content/`: Everything authored: dimensions, 33 rooms, 14 thresholds, 29 signals, design rules, the reading tables and the five prompts.
- `oracle/tests/`: 81 unit tests; no model is called and nothing is launched.
