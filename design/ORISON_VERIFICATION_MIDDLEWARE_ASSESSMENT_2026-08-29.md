# Verification middleware — an adversarial assessment

**Status:** decision input, not proof. Named so the completeness ledger refuses
it as evidence; space identifiers are **bold**, never backticked.
**Question:** should this body of work be extracted into a standalone
AI-empowered game-engine middleware product?
**Method:** every number below was measured at HEAD `1209df3` by running the
tools, not by reading about them. Where a claim is inferred rather than
measured, it says so.
**Prior ruling this must answer to:**
`design/ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md`, which already ruled
*"(b) a reusable internal framework — and a narrow one, concentrated almost
entirely in the evidence toolchain."* That ruling **survives** everything below.

---

## Verdict

**Do not build a product. Build one tool, in a week, against somebody else's
repository — and let that decide it.**

The thesis you asked me to test — *almost everything built here is machinery for
keeping an AI-assisted process honest, and AI-heavy development needs a
different class of tool* — is **false in both halves as stated**, and I can put
numbers on how false. What survives is narrower, more defensible, and more
interesting than the original claim. It is also probably not a year of work.

There is one genuinely novel thing in this repository. It is not the audits. It
is a small, sharp idea about **what a document is allowed to prove**, and it
fits in about 800 lines.

---

## Part 1 — The thesis, measured

### 1.1 "Almost everything built here is honesty machinery" — refuted

Two independent measures, and they agree.

**By line.** 353,055 lines of hand-authored text (excluding 292,157 lines of
generated data, of which `building_layout.json` alone is 145,298):

| bucket | lines | share |
| --- | ---: | ---: |
| game code + scenes | 120,922 | 34.3% |
| game tests (363 files) | 75,569 | 21.4% |
| design documents (222) | 64,137 | 18.2% |
| art pipeline Python | 28,208 | 8.0% |
| art documents | 22,882 | 6.5% |
| other projects in-tree | 17,644 | 5.0% |
| **gate / audit tools (18)** | **13,967** | **4.0%** |
| **their tests (79)** | **6,308** | **1.8%** |
| other tooling | 3,418 | 1.0% |

Verification machinery is **5.7%**. Include all 363 game test scenes and it is
27.1%. Include every verification-flavoured design document and it is 33%. The
absurd maximum — all tests, all design prose — is 45.3%. *"Almost everything"*
needs something like 80%.

**By commit,** which does not weight generated JSON at all: of 1,115 commits,
**35 (3.1%) touch a gate file at all**. Classified by dominant category: DOC
36.6%, GAME 30.5%, ART 21.6%, VERIF 7.8%.

Two methodologically independent measures land in the same 3–8% band. For
*"almost everything"* to hold, the attention-per-line multiplier on gate code
would have to exceed 10×, and nothing supports that.

**There is also a competing explanation the thesis does not exclude.** Every one
of the 18 gate tools was created between 2026-08-26 and 2026-08-28. The first
four appear on the same day as `b43cbe1` *"Prioritize a fundable early-access
build"* and `71eec55` *"Charter Early Access distribution and marketing."* The
gates may not be a response to an internal honesty crisis at all. They may be
**audience-facing legibility**, built the week the project first needed to
demonstrate to outsiders that its claims were real. Both readings fit the data
equally well. That is a problem for a product thesis that depends on the first.

### 1.2 "AI-heavy development needs a different class of tool" — refuted in kind

Take the eleven finding classes in `audit_systemic_situation_authority.py` — the
richest taxonomy in the repository — and ask of each whether a human team would
produce the same defect.

**Textbook defects, catalogued between 1970 and 1999 (five):**
`DIRECT_NPC_KNOWLEDGE_WRITE` and `FOREIGN_PHYSICAL_MUTATION` are encapsulation
violation and feature envy (Law of Demeter, 1987). `DUPLICATE_CUSTODY` is two
owners of one fact (Codd, 1970). `HOST_CLOCK_MUTATES_WORLD` is ambient
nondeterminism — the reason clock injection and `SOURCE_DATE_EPOCH` exist.
`AUTONOMY_DEPENDS_ON_PROXIMITY` is simulation coupled to culling, which every
open-world game since Ultima VII has shipped.

**House design-doctrine enforcement (five):** `OBJECTIVE_UI_LEAK`,
`COMPLIANCE_DEAD_END`, `ABSTRACT_JUDGMENT_FACT`, `TIMER_IMPERSONATES_ACTOR`.
These enforce *"situations, not assigned objectives; work optional"* — the
project's own manifesto. That is a design bible with a linter, not honesty
machinery, and it says nothing about who wrote the code.

**Not a defect (one):** `DYNAMIC_UNRESOLVED` is a static-analysis limitation —
13 of 57 findings.

Exactly **one** class, `TEST_AUTHORITY_SHORTCUT`, targets unearned green. It is
the classic *testing-the-mock* smell, for which mutation testing has existed
since 1978. It has found **one** instance in the entire repository.

The right name for this pack is **architecture fitness functions** (Ford,
Parsons and Kua, 2017), pointed at defects catalogued between 1970 and 1999. No
amount of tool maturity converts a Law-of-Demeter check into a new category of
instrument.

**The test corpus also undercuts the premise.** The thesis assumes *"tests that
pass without proving anything."* Measured: of 199 `*_test.gd` files, **198 have
a genuine failure path** (`fails += 1` … `quit(fails)`), with **5,377 check
calls** — 27 per file. `celestial_ephemeris_test.gd` asserts against J2000, the
USNO sidereal angle and a specific 2023 lunation. This is a dense, real suite.
(The five `quit(0)` offenders in §2.9 of the genetic memory document are five of
360, not the norm.)

### 1.3 What actually survives — and it is worth having

> **Agents produce ordinary defects at a rate that breaks the review budget,
> with confident prose attached.**

The datum is **1,115 commits in 32 days**, ~34 a day, from a single human
owner's direction. Nothing in that sentence is about a *new kind* of defect. It
is about **rate**, and about one genuine asymmetry:

An agent's wrong answer arrives **fluent, structured, internally consistent and
formatted like a finding**. `e81592d` is the specimen: a diagnostic printed
`list(keys)[:8]` of an eighteen-key dictionary, and the truncation was written up
as a complete record. The first eight keys happened to produce *"a symmetrical,
plausible and entirely invented contradiction."* It survived review and reached
the owner as a recommended action.

A human making the same slip usually produces something that *looks* like a
mistake. Pattern completion does not. **The plausibility is manufactured by the
error, not despite it** — and plausibility is exactly what survives review.

That is the true claim, and it is narrower than "a different class of tool." It
says: when production outruns review, the scarce commodity stops being analysis
and becomes **the discipline of not producing analysis you cannot support**.
That is a real product idea. It is much smaller than a middleware platform.

**One further piece of evidence, and it is the best in this document.** The
analyst who produced §1.2 first reported that 111 of 199 test files had no
failure path — a false finding from a regex that missed the codebase's
`_check`/`quit(fails)` idiom. It caught and corrected itself before reporting,
at a cost of one file read. That is a live instance of the exact failure mode
under discussion, self-caught, cheaply. It argues both ways: the errors are real
and constant, *and* they are cheap to kill if anyone checks.

---

## Part 2 — Tool by tool: what is general, what is Orison

I measured coupling three ways: constant-table share, domain vocabulary outside
those tables, and engine/platform dependence.

### 2.1 The surprise: the flagships are far less Orison-coupled than they look

| tool | lines | constant tables | domain vocabulary **outside** tables |
| --- | ---: | ---: | ---: |
| `audit_orison_v2_completeness.py` | 2,499 | 186 (**7.4%**) | 45 lines (**1.8%**) |
| `audit_systemic_situation_authority.py` | 1,040 | 126 (12.1%) | 2 lines (**0.2%**) |
| `audit_orison_spatial_dependencies.py` | 1,478 | 424 (28.7%) | 3 lines (**0.2%**) |

The completeness ledger's canon — `CANON_FLOORS`, `UNIT_FUNCTIONS`,
`F01_PROGRAM`, `B1_PROGRAM`, `ROOF_PROGRAM`, `FLOOR_CIRCULATION`,
`SERVICE_SYSTEMS`, `RITUAL_IDENTITIES`, `UNIT_PREFIX_EXACT`, `V1_TO_V2_ALIASES`,
`ACCEPTANCE_GRANTS`, `EVIDENCE_NAME_MARKERS` — is **186 lines of 2,499**.
Mechanism is 78%. Almost every remaining "domain" hit is a comment, a docstring
or CLI help text.

**This refutes the intuitive assumption that extraction is a rewrite because the
canon is baked in.** It is not baked in; it is a small, replaceable table. If
the tools fail to extract, it is for a different reason (§5).

The three flagships are also barely Godot-coupled: `.gd` appears 18, 43 and 9
times respectively; `res://` appears 0, 4 and 0 times. The systemic audit is a
**text scan over GDScript source** — coupled to a language's surface syntax, not
to this game.

### 2.2 The genuinely general ideas, ranked, with honest prior art

**1. Evidence intake as a filename allowlist — genuinely novel, and the best
idea here.** A document may prove something only if its *name* declares it to be
proof; refused documents are never even opened, so they cannot influence a
conclusion by accident; refusals are printed with reasons and excluded from the
provenance hash. Plus `--evidence-impact PATH`, which answers *"would committing
this document change any status?"* with exit 0 / 1.
I know of no prior art for this. Provenance systems (SLSA, in-toto, sigstore)
attest *artifacts*, not *claims*. Documentation linters check style, not
whether a document is licensed to promote a requirement. This is the one idea in
the repository I would call new, and it exists precisely because an AI-heavy
process generates documents faster than anyone reads them, and those documents
get fed back to tools.
*Implementation:* `tools/audit_orison_v2_completeness.py:388-439,2273`.

**2. Line-independent finding identity.** sha1 of (domain, class, file, scope,
normalized expression); line numbers reported, never compared. Measured payoff:
`568a6c2` shifted twelve records by seven lines each against a 3,626-record
manifest and **no classification moved**.
*Prior art:* real but partial — `git blame --ignore-rev`, semgrep's fingerprints,
SonarQube's issue hashes. **Known but well executed**, and executed better than
most.

**3. A typed suppression contract.** A baseline entry suppresses *exactly one
shape of one finding*: class change fails, confidence increase fails, a test-tier
entry may never baseline a production finding, and clean removal is a reported
non-failing cleanup. One class is designated permanently un-baselinable.
*Prior art:* baseline files are universal (`semgrep --baseline-commit`, eslint
`--fix-dry-run`, SonarQube). The **typing** of the suppression is the
contribution. **Known but well executed.**

**4. A disposition manifest for what has silently become a contract.** The
spatial dependency audit's title says it: *"what the building accidentally
promised."* Nine dispositions — `MUST_PRESERVE_ID`, `PRESERVE_OR_ALIAS`,
`REPLACE_WITH_NAMED_ANCHOR`, `REGENERATE_CONSUMER`, `UPDATE_TEST_FIXTURE`,
`HISTORICAL_EVIDENCE_ONLY`, `SAFE_TO_CHANGE`, `OWNER_DECISION`, `UNRESOLVED` —
over 3,626 records, and a graded staleness policy where only the load-bearing
dispositions fail on disappearance.
*Prior art:* this is API-deprecation planning and database-column-removal
planning, done systematically, which is rare. The general idea — *an identifier
becomes a contract by being used, not by being declared* — travels well.
**Known but rarely done.**

**5. False-positive discipline that counts what it suppressed.** 3,131 of 3,418
`Vector3` literals are counted in statistics and deliberately kept out of the
manifest — a 92% suppression rate, with a written policy, and the suppressed
pool still reported. Of 57 systemic findings today, 45 are `REVIEW` and zero are
new-actionable.
**The distinguishing feature of these audits is not what they find; it is what
they refuse to report, and the fact that they count it.** That is a real
philosophical position and it is the opposite of every incumbent's incentive.

**6. Scoped readiness with no single percentage.** Six ordered scopes, per
requirement, and a banner — `FIRST SLICE READY - PRODUCTION CUTOVER NOT
IMPLIED.` — printed *inside* the green so it cannot be quoted out of context.
*Prior art:* release-readiness checklists everywhere; the refusal to average is
the contribution.

**7. One-owner-per-consequence auditing.** The idea is good. The
*implementation* is 9 of 11 classes enforcing either 1970s coupling hygiene or
this game's design manifesto (§1.2). The general core is ArchUnit's territory.
**Reinvented existing wheel**, well.

### 2.3 What is genuinely unextractable

**The completeness ledger's canon tables** — but not for the reason expected.
They are only 186 lines. The problem is that **a customer would have to write
their own**, and writing them *is* the work. What the tool supplies is a status
ladder and an evidence-intake rule; what made it valuable here was somebody
encoding an architectural program into a reviewed table. Sell the frame and the
buyer receives an empty frame.

**The period cutoff** (`audit_period_dates.py`, 163 lines). Pure Orison, and
also the worst-designed gate in the tree (it fails the moment the owner makes
the decision it is waiting for). Do not extract it; do not imitate it.

**The room checkpoint family** (10,516 lines including guides). Bound to one
entity domain: `DEFAULT_LAYOUT = art/data/building_layout.json` and
`CHECKPOINT_GLOB = 'ORISON_*CHECKPOINT*.md'`; the symbol table *is* a building's
room/object JSON. Generalising means replacing "layout record" with an injectable
entity index — a rewrite, not a move. **However**, the reconciler demonstrably
works: it resolved **285 of 347** recorded decisions against the live layout
(satisfied 285, contradicted 0, unverifiable 59, malformed 3), and its fixture
suite drives it to `contradicted=5 → exit 1`, so it can fail. The *machine* is
sound; the *binding* is domain.

**The capture/release harness** (`shot_harness.gd`, `run_godot_serial.ps1`,
`measure_shot_sheet.py`, the packaging chain) is what the prior ruling called
*"the actual asset."* I agree it is the strongest existing seam, and it is
Godot-and-Windows-shaped in ways the audits are not. The chain-of-custody *idea*
separates from the PowerShell; the code does not.

---

## Part 3 — What the product would be

Six forms were considered seriously. One is recommended.

### Recommended: a **claim checker** — a linter whose input language is Markdown and whose symbol table is the repository

Not a code linter. A CLI that reads the progress documents an agent writes into
a repository — plan, checkpoint, ADR, PR body, session summary — and answers
three questions offline, with stable exit codes and `--json`:

1. **Checkability.** Does every entity this claim names resolve to exactly one
   thing in the repository?
2. **Reconciliation.** Is the resolvable claim still true of the current tree?
3. **Evidence resolution.** Does the cited proof artifact exist, and does it
   record what the claim says it records?

One sentence: *your agent said it did X and cited Y — does Y exist, and is X
still true?*

**Why this form and no other.** It is the only one where working code already
exists and runs; where the distinctive value is the **refusal semantics** rather
than the domain logic; where no incumbent occupies the niche; and where the demo
can fail.

The product's actual intellectual property is four sentences already written in
the source, and they are worth more than the 6,750 lines around them:

- *"Markdown is not a reliable database, so parsing is deliberately
  conservative"* (`room_checkpoint_reconciler.py:12`)
- *"rows without any backticked object id become UNVERIFIABLE, never guessed"*
  (`:18`)
- *"An image that exists proves only that an image exists"*
  (`room_evidence_verifier.py:8`)
- *"Absence of a failure line is NEVER interpreted as a pass"* (`:30`)

Every one is a rule about what the tool **refuses to conclude**. Semgrep,
CodeQL, ArchUnit and OPA all optimise for finding more. This optimises for a
graded, honest *"I cannot tell,"* published as a first-class status rather than
as silence. That inversion is the thing worth selling, if anything is.

Also directly reusable, verbatim: the diagnostic vocabularies
(`EXACT/AMBIGUOUS/PREFIX_ONLY/KIND_NOT_ID/RUNTIME_ONLY/UNKNOWN/MISSING_TARGET`),
the reconciler verdicts (`SATISFIED/CONTRADICTED/OPEN/UNVERIFIABLE/MALFORMED`),
the citation statuses (`VERIFIED_PRESENT/RECORDED_PASS/RECORDED_FAIL/MISSING/
AMBIGUOUS/SYMBOLIC_ONLY/UNREADABLE/METADATA_MISMATCH`), the compound exit-code
convention (0/1/3/4/5/70, where 5 means both), and the confidence × disposition
split. Those taxonomies are the design work.

**What must be written new:** the entity-index abstraction (today it is one
building's layout JSON), a claim grammar that is not a room-verdict table,
citation resolvers for non-Orison artifact schemas, and packaging.

### Rejected, with reasons

**CI service.** Disqualified by this repository's own state: there is no
`.github`, no workflow file, and **no installed hook in any of 19 worktrees**. A
team proposing to sell hosted CI has never run CI. The form is also wrong for
the failure — `e81592d` *"survived review, reached the owner as a recommended
action"*; a PR gate fires hours after an agent has written twelve documents on
top of the false one. The check needs to run inside the agent's loop, not at
merge. And the niche is saturated.

**Agent harness.** The strongest *evidence* here is operational, not
verificational: `Global\OrisonGodotSingleInstance`, *"a separate worktree does
not create a separate engine lane"*, the `git add -A` ban. Real, unglamorous,
unaddressed problems — but the contribution is ~200 lines of PowerShell, and the
form ties the product to a vendor's agent runtime that changes monthly.

**SDK / library.** Nothing here has a second consumer to shape an API against.
Shipping an SDK now means guessing the seams, and §5 explains why that guess
will be wrong.

**Engine plugin.** The audits are 0.2–1.8% Orison and roughly as Godot-coupled;
a plugin form would *add* engine coupling the tools do not currently have. It
would make the product smaller, not larger.

**Methodology plus reference tooling.** This is the honest runner-up and may be
the right answer (§5). The genetic memory document beside this one is most of a
first draft. It is cheap, it is falsifiable, and it does not require carrying a
support obligation to strangers. The reason it is not first is that a book
without a tool cannot be checked, and *unfalsifiable advice is precisely what
this project spent a month learning to refuse.*

---

## Part 4 — Who is the user, and what must they already believe

**The honest answer is: a team that has already been burned.** Not by AI in
general — by one specific experience: shipping or nearly shipping something on
the strength of a document, a test, or a green signal that turned out not to
mean what it said.

Concretely: a 5–30 person team, one to two years into a codebase, running agents
across several parallel branches, producing more artifacts per week than any one
person reads. They have a design document nobody can enforce, a test suite whose
green they have privately stopped trusting, and at least one incident where a
plausible finding cost real time.

**What they must already believe, all four:**

1. That an artifact's *existence* is not evidence of its *integration*.
2. That a document asserting progress is not progress.
3. That the bottleneck has moved from producing work to verifying it.
4. That it is worth paying — in friction, on every commit — to make an agent's
   claims checkable.

Belief 4 is the killer. These gates are painful **on purpose**. This repository
has already produced a gate that fails when the owner makes a decision, a gate
that reported a built-and-accepted room as ABSENT over a comma, and a metric
that gets worse when you do the work correctly. A team that has not been burned
will read all three as the tool being broken, and they will not be entirely
wrong.

**How large is that population today?** Unknown, and I have no external data —
I have no web access and will not invent a number. Directionally it is growing
fast and is currently small, which argues for a **cheap, fast, falsifiable
probe** rather than a year of building.

---

## Part 5 — The strongest case against

Made properly. It is stronger than the case for.

### 5.1 The kill shot: the verification layer is not load-bearing, so the thesis is untested even at N = 1

The thesis is a **causal** claim: gates keep an AI process honest. The causal
chain is severed at the first link — **nothing forces a gate to run.**

- **No CI.** No `.github`, no workflow file, no pipeline config anywhere.
- **No installed hooks.** The shared git dir contains only the 14 stock
  `.sample` files, across **19 live worktrees**.
  `tools/room_gate_hook.py` says so itself: *"Nothing here installs itself."*
- **Only 469 of 7,217 audit lines — 6.5% — are wired into any automated path.**
  The single call site is `tools/package_friends_build.ps1:16-18`, invoking
  `audit_music_catalog.py` (89 ln), `audit_period_dates.py` (163 ln) and
  `audit_audio_emitters.py` (217 ln). The 2,499-line completeness ledger, the
  1,478-line spatial audit, the 1,040-line authority audit, the 642-line carrier
  audit and the 499-line implementor census are invoked by **no script, no hook,
  no pipeline**. They run when an agent types the command, and they matter when
  that agent reads the output.
- **A gate is standing red and unrepaired.**
  `audit_interaction_prompt_carriers.py` exits **1** at HEAD, on two
  `FORBIDDEN_KEYBOARD` findings in `clock_prop.gd:297,300`. *(In fairness: this
  is a recorded, owned deferral — the debt is named in four documents and held
  open pending K2 human evidence. But nothing was blocked. That is the point.)*

**The honesty in this repository is supplied by the discipline of the people and
agents running it. The tools are the notebook they write it in.** You cannot
sell the notebook as the discipline. A buyer who installs 19,438 lines of
scripts without the culture gets 19,438 lines of scripts nobody runs.

### 5.2 The project's own ruling already forbids the claim

`ENGINE_EXTRACTION_BOUNDARY_2026-08-27.md` §D: *"No subsystem may be described
as engine-grade, portable, extractable or licensable until a second, tiny
reference project consumes it."* §G: *"A claim at level N without every level
below it is marked UNSUPPORTED"* and *"No entry anywhere is at level 4."*
Verified: the knowledge ledger tallies 1 × L1, 12 × L2, 4 × L3, **0 × L4, 0 × L5**
across 21 graded rows. There is no second consumer of anything. The reference
project is gated behind a friends build that has not been issued.

The newer tooling does not rescue this — it makes it worse. All 18 verification
tools have exactly one consumer: the repository they were written inside, by
agents that could read that repository. §C's verdict applies verbatim one level
up: *conventions the tool's own author already knew, encoded as a checker.*

### 5.3 The tools are one to three days old and their semantics are still moving

**Eight of eighteen have exactly one commit** — not stability, but a tool that
has never received feedback. The flagship has five commits in two days, and
**every one changed what the tool says is true**: created at +2,035 lines in a
single commit; chronological evidence precedence added; evidence intake narrowed
(`d344fd9`, moving five ledger counts); the narrowing's own under-reporting
corrected 16 minutes later (`3aa3764`); a brittle purpose predicate replaced
(`568a6c2`). An interface that changed five times in two days cannot be sold as
a contract to strangers.

### 5.4 The moat question

If the ideas are good, what stops a model vendor shipping them inside the agent
in six months? Evidence discipline, citation checking and refusal-to-conclude
are exactly the kind of capability that migrates into the harness. **Verification
may be a feature, not a product.** I cannot refute this, and it is the argument
I would take most seriously.

### 5.5 Opportunity cost

95 production-cutover blockers remain, 46 of 144 requirements are ABSENT,
exactly 1 is HUMAN_ACCEPTED, and a whole-map rebuild is starting. A year on
middleware is a year not spent there. The game is also unshipped: selling the
methodology of an unshipped project is selling an unfalsified hypothesis.

### Does the case against win?

**On "build a product," yes. Decisively.** Points 5.1 through 5.3 are not
survivable in their current form. Nothing here is above evidence level 3 by the
project's own taxonomy, and level 4 requires exactly one thing: a second
consumer.

**On "there is nothing here," no.** Two things resist the demolition. The
evidence-intake idea (§2.2 item 1) is genuinely novel and I found no prior art
for it. And the *refusal* semantics — a graded, first-class *"I cannot tell"* —
run against every incumbent's incentives, which is usually where a real product
hides.

The correct response to a decisive case against a *year* is not to abandon the
idea. It is to **spend a week instead**, on the one experiment that converts the
whole question from argument to evidence.

---

## Part 6 — The smallest useful extraction

**One week. One tool. One repository that is not Orison.**

**What to build.** A single CLI, ~800 lines plus tests, no Godot, no game
assumptions, standard library only:

```
claimcheck <document.md> --repo <path>
```

It parses a Markdown document for claims of the form *"X is done / X exists / see
Y"*, resolves every named entity against an **injectable entity index** (for the
demo: the repo's own symbol table — file paths, function and class names, test
names), and emits one row per claim with a status drawn from the taxonomy that
already exists here: `SATISFIED`, `CONTRADICTED`, `OPEN`, `UNVERIFIABLE`,
`MALFORMED`. Plus the two rules that make it different from a link checker:

- **intake by declared kind** — a document may only *prove* something if its
  name says it is proof, and refusals are printed with reasons;
- **`--impact <path>`** — would adding this document change any conclusion?
  Exit 0 inert, 1 promoting.

**Against what.** A mid-sized open-source repository that has agent-written
planning documents in it and is not a game — one where `docs/` or `plans/`
contains ADRs or milestone notes with file and symbol references. Pick it
publicly and in advance.

**What the output looks like.** One table. Something like: *42 claims parsed; 31
SATISFIED; 4 CONTRADICTED (naming the file and the symbol that no longer exists);
5 UNVERIFIABLE with the reason; 2 MALFORMED. 3 of 11 documents admitted as
evidence, 8 refused by name.*

**What counts as failure — and this is the important half.** A demo that cannot
fail proves nothing; that is this project's own lesson (§5.4 of the genetic
memory document). The experiment fails if **any** of these hold:

1. Fewer than **three CONTRADICTED findings** that a maintainer of that
   repository agrees are real. Zero real findings means the discipline, not the
   tool, was doing the work here.
2. `UNVERIFIABLE` exceeds ~40% of claims. Above that the tool is a
   sophisticated way of saying *"I don't know,"* and nobody pays for that.
3. The entity index needs per-repository hand-curation to work. If the customer
   must author the canon tables, the value was the tables (§2.3) and the product
   is an empty frame.
4. It takes more than a week. The estimate is the hypothesis.

**And the meta-rule from §2.2 of the extraction boundary, which still binds:**
the deliverable of the week is not the tool. It is **the written list of
everything that had to be rewritten to make it work.** That list is the real
extraction cost, and it will be larger than every estimate in this document.

**If the week succeeds:** the two-game rule is satisfied for one seam, the
knowledge ledger gets its first level-4 entry in the project's history, and the
year becomes a decision with evidence behind it.

**If the week fails:** you have lost a week, you have a publishable taxonomy, and
the genetic memory document beside this one becomes the deliverable — which was
always the honest runner-up.

---

## Appendix — two live defects found while assessing

Both were found by running the tools rather than reading them, and neither is
reported anywhere in `design/`.

**1. `tools/audit_orison_rooms.py` returns a false RED in its owner's own
shell.** It exits **1** under the default Windows console with
`UnicodeEncodeError: 'charmap' codec can't encode character '↔'` at line 210, and
exits **0** with `PYTHONIOENCODING=utf-8`. A verification tool whose verdict
depends on the console encoding of the machine running it. This is §2.3 of the
genetic memory document — *the instrument is the first suspect* — inside the
instrument shelf itself.

**2. `tools/audit_music_catalog.py` and `tools/audit_authored_voice.py` exit 2
when run with no arguments** — they require positional parameters, so a
"run every audit" sweep reports two spurious failures.
**Checked, and the release path is fine:** `tools/package_friends_build.ps1:15-17`
supplies each audit's arguments explicitly and checks `$LASTEXITCODE` after
each. This is a usability note about ad-hoc sweeps, not a release defect — and
it is worth recording only because *I* misread it as a defect on first pass,
which is §3.8 of the genetic memory document in miniature.
