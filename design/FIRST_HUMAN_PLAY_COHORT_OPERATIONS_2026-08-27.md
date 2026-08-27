# First human-play cohort — operations

**Status:** PLAN. **No one has been recruited, contacted, scheduled or paid. No
build has been distributed. No account, key, form or agreement exists.**

**Base:** `0029c4a94d428b4c05881d5a0c2de4fac8b83247` (pushed `origin/main`,
"Keep narcolepsy from becoming the monster in store copy"), which contains
`963b3b4` ("Ratchet the reduced tick debt into the release gate").

**Origin advanced during this task**, from `66cff04` to `0029c4a`. The single
new commit rewrote the store copy this plan cites, **which unblocked Lane B**
(§13 C4, §14 precondition 7). The branch was replayed onto the new tip and every
affected claim re-verified rather than shipped stale.

**Godot was not run.** No test, import, capture, export, packaging or asset tool
was run. No production code, data, scene, test, existing design document,
`TASKS.md` or release script was modified. One new file.

---

## 0. The one rule this document exists to enforce

**A tester is not a reviewer, and the two jobs cannot be merged to save money.**

> A friend who finds the stair sign confusing has told you something true about
> **navigation**. They have told you **nothing** about whether the depiction of
> narcolepsy is defensible.
>
> A paid reviewer with narcolepsy who tells you the onset reads as a fainting
> gag has told you something true about **depiction**. They have told you
> **nothing** about whether the opening route is completable unaided — and
> asking them to prove it wastes the thing you are paying for.

**They differ in population, consent, payment, session shape, facilitator
conduct, evidence, and what a finding is allowed to close.** Everything below is
organised as **Lane A** (friends-build usability) and **Lane B** (paid
lived-experience depiction review), and the seams between them are named
explicitly in §4.3.

### 0.1 Four labels, used throughout

| Label | Meaning |
| --- | --- |
| **REPOSITORY FACT** | Verified in-tree at `0029c4a`, with a path |
| **SOURCED** | External source, cited at the point of claim with a date |
| **INFERENCE** | My reading, labelled as mine |
| **RECOMMENDATION** | What I suggest; the owner decides |
| **OWNER DECISION** | I am not answering it (§11) |

### 0.2 Full-file inspection rule

**Binding on this document and on every finding produced by either lane.**

> **No count, census, or absence claim may be made from truncated output.**
> A `head`, a `grep` sample, a first-page read, or a paginated view is a
> **pointer**, never evidence. Parse the whole file, state the denominator, and
> state the tool that produced it.

**INFERENCE — this rule is here because the project has already been burned by
its absence.** `EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md:13` records a contradiction
reported from the first eight of eighteen JSON keys. Every count in §1 below was
produced by a whole-file parse, and each states its denominator.

**Applied to cohorts:** *"testers didn't mention the stairs"* is not a finding
unless every session record was read. **Silence in a partial read is not a
result.**

---

## 1. Repository facts this plan is built on

All verified at `0029c4a` by whole-file inspection.

### 1.1 The work is human-shaped and it has never been done

**REPOSITORY FACT.** `EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md`
summarises **28 gates: 5 PROVED, 10 CODE GREEN / MANUAL OPEN, 9 PARTIAL,
2 ABSENT, 1 BLOCKED ON OWNER RULING, 1 UNKNOWN.**

**Ten gates are waiting for a human.** That is the cohort's job list, not a
vague desire for feedback.

G01's manual criterion is already written and this plan adopts it verbatim
rather than inventing one:

> **desktop, fresh save, unaided, no console/debug/noclip; observation =
> finishes and can state their next intention throughout; signer = owner. This
> is K2, `TASKS.md:105`, and it has never been done.**

### 1.2 Which gates each lane can and cannot close

| Gate | Status | **Lane A can close** | **Lane B can close** | Note |
| --- | --- | --- | --- | --- |
| G01 first 8–12 min route | MANUAL OPEN | **YES** | no | The core Lane A job |
| G02 sound-led fault reachable | MANUAL OPEN | **YES** | no | |
| G05 sleep onset and warning | MANUAL OPEN | **partly** | **partly** | **The seam — §4.3** |
| G07 controller-only waking route | MANUAL OPEN | **YES** | no | README already asks for it |
| G08 controller-only dream | MANUAL OPEN | **YES** | no | |
| G09 keyboard/mouse route | MANUAL OPEN | **YES** | no | |
| G11 custom volume controls | MANUAL OPEN | **YES** | no | |
| G13 camera roll / flash suppression | MANUAL OPEN | **YES** | no | Accessibility, Lane A |
| G14 title and in-game focus | MANUAL OPEN | **YES** | no | |
| G18 no debug affordance in build | MANUAL OPEN | **YES** | no | Also a stop rule (§8.4) |
| G25 narcolepsy statement and review | PARTIAL | **NO — never** | **YES, and only Lane B** | Blocks any outreach |
| G23 channels and rollback | MANUAL OPEN | internal | no | Rehearse before either lane |

**INFERENCE:** Lane A can close nine gates. Lane B can close one. **That
asymmetry is not a reason to under-resource Lane B** — G25 blocks *any outreach*,
which means it blocks the store page, the trailer and the press kit, while the
nine Lane A gates block a public demo. Lane B is the smaller job and the harder
block.

### 1.3 The condition is not named anywhere a player can see

**REPOSITORY FACT.** A whole-tree search of `game/` and `distribution/` for
`narcolep` or `cataplex` returns **zero matches.** The nearest player-facing text
is mechanical:

```
game/scripts/ui/accessibility_copy.gd:9   "ALWAYS USE GRADUAL SLEEP WARNING"
game/scripts/ui/accessibility_copy.gd:11  "Shows the gradual warning before every sleep onset."
```

This is carried forward from
`NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md` §2.1 and
re-verified at this base. **§7 prices the consequence.**

### 1.4 One case ships, and it cannot produce a sudden onset

**REPOSITORY FACT**, whole-file parses:

- `game/data/reality_cases.json` — **18 case records, exactly 1 enabled**
  (`mina_caption_crisis`).
- `game/data/dream_profiles.json` — **6 onset profiles.** Only
  `mina_release_print` is reachable, and its `allowed_forms` is
  `["gradual"]`. The five sudden-capable profiles (0.64–0.72 s) belong to
  disabled cases.
- `game/scripts/game_boot.gd:89` — `"always_warn_before_sleep": false`.

### 1.5 The tester README is good, and it is missing one thing

**REPOSITORY FACT.** `distribution/README_TESTER.txt` (read in full, 1 file,
all sections) already covers: unsigned-build SmartScreen warning and `.sha256`
verification; microphone consent and the NOT THIS TIME option; network weather
off by default and the IP-exposure disclosure; local user-data location and
non-removal; and a structured problem-report format that warns against attaching
personal information.

It also states the Lane A assignment in its own words:

> *"Controller-only completion of the entire first route is still awaiting human
> verification; please report the exact controller model and the last action
> that worked if you get stuck."*

**It contains no content note.** There is no mention of sleep onset, loss of
control, darkness, pursuit or frightening imagery. **§14 treats this as
precondition 1, blocking for both lanes**, and §13 C3 records that it is
unchanged since the ADMIN-REVIEW1 handback.

### 1.6 The channel already supports per-person revocation

**REPOSITORY FACT.** `FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md`
recommends an unlisted itch.io project with per-person download keys, noting
that *"a cohort of six friends is six keys you can withdraw."*

**REPOSITORY FACT.** `tools/package_friends_build.ps1` enforces a **six-file
artifact contract**, refuses to overwrite an existing numbered artifact, verifies
export artifacts against their source manifest and HEAD, and stamps
`README_TESTER.txt` with build number, version and short SHA.

**INFERENCE:** per-person revocable keys are not merely convenient — they are
what makes Lane B's withdrawal right (§6.9) actually enforceable. A shared link
cannot be withdrawn from one person.

---

## 2. Lane A — friends-build usability cohort

### 2.1 Definition

**Purpose:** determine whether a person who did not build this game can
complete, understand and operate the opening route on their own hardware.

**Population:** people with no development knowledge of this project.

### 2.2 Recruitment filters

**Required:**

- Windows desktop capable of running the build.
- Willing to play **unaided** and to be observed or to self-report.
- Willing to give the build back — i.e. accept a revocable key (§1.6).

**Deliberately sought, because the gate list demands it:**

| Filter | Which gate needs it |
| --- | --- |
| At least two on **controller only** | G07, G08 |
| At least two on **keyboard/mouse** | G09 |
| **Two distinct machines**, specs recorded | G20 (currently ABSENT) |
| At least one who **uses captions habitually** | G12, G13 |
| At least one **first-time horror player** | comprehension, not preference |

### 2.3 Exclusions

- **Anyone who has seen the level layout, the fault location, or these design
  documents.** One person who knows where the chirp is destroys G02 for that
  session; it cannot be un-known.
- **Anyone the owner cannot accept a bad result from.** **INFERENCE:** the
  failure mode of a friends cohort is politeness, and it is stronger between
  friends than between strangers.
- **Anyone recruited because they have narcolepsy.** See §2.4 — this is the most
  important exclusion in the document.

### 2.4 The exclusion that keeps the lanes separate

**A person with narcolepsy may absolutely be a Lane A tester** — they play games
and their machine is as valid as anyone's.

**But they are recruited as a tester, briefed as a tester, and paid as a tester,
and their session produces Lane A evidence only.** Nothing they say about the
depiction may be recorded as a Lane B finding, cited toward G25, or repeated as
"someone with narcolepsy played it and was fine."

**INFERENCE, and it is the ethical core of the two-lane split:** the alternative
is unpaid depiction review extracted from a friend under a usability pretext.
That is precisely the extractive pattern
`NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md` §8.5 prohibits.
**If a Lane A tester volunteers a depiction observation, §8.3 applies: thank
them, do not record it as a finding, and offer them a paid Lane B seat if they
want one.**

### 2.5 Consent — Lane A

Lane A is **not** research on human subjects and this document does not claim
otherwise. **SOURCED:** the Belmont Report's principle of *respect for persons*
requires that people "enter into the research voluntarily and that they are
provided adequate information in terms that are easy to understand and when they
are not under duress" — [HHS Belmont Report](https://www.hhs.gov/ohrp/regulations-and-policy/belmont-report/read-the-belmont-report/index.html)
(canonical URL; returned HTTP 403 to automated fetch on 2026-08-27, so the
wording above is taken from institutional summaries — verify against the primary
text before quoting publicly). **RECOMMENDATION: hold to it anyway.**

Consent covers: what the build does, the content note, the microphone and
network behaviour, what is recorded, what is retained, and the right to stop.
**Template at §9.1.**

### 2.6 Compensation — Lane A

**RECOMMENDATION:** friends testing a friend's game is a normal social
arrangement and does not require a professional rate. **But it is not free
either.** Offer a token of real value — a copy of the game on release plus a
named thank-you if they want one — and say so **before** the session, not after.

**SOURCED, and it cuts both ways:** the Belmont Report defines *undue influence*
as "an offer of excessive, unwarranted, inappropriate, or improper reward or
other overture to obtain compliance." **INFERENCE:** for Lane A the live risk is
the opposite of undue influence — it is **social obligation**, which produces
polite results rather than true ones. §9.3's opening script is written to defuse
it.

### 2.7 Session shape — Lane A

| Element | Value |
| --- | --- |
| Length | **60 minutes**, hard stop |
| Structure | 5 min setup · **20 min unaided play (§5)** · 15 min continued or resumed play · 20 min debrief |
| Facilitator | **One person. Silent during the unaided window** |
| Recording | Screen + audio **only with consent**; camera never |
| Materials | The packaged build via personal key, `README_TESTER.txt`, content note, a machine-spec form |

### 2.8 Facilitator conduct — Lane A

**Silent observation during the unaided window (§5.3).** Not "mostly silent."

**Prohibited throughout:** explaining the fiction; naming an objective; saying
"try listening"; reacting to a mistake; defending a design; saying "most people
find…"; and **any** disclosure that the character has narcolepsy (§7.2).

**SOURCED — and this is a real tension, named rather than hidden.** W3C WAI
describes accessibility usability testing as typically using a "think-aloud
technique with **high facilitator interaction**" — [W3C WAI, *Involving Users in
Evaluation*](https://www.w3.org/WAI/test-evaluate/involving-users/) (fetched
2026-08-27). **That is the opposite of G01's unaided criterion.**

**RECOMMENDATION:** do not compromise between them — **sequence them.** The
first 20 minutes are silent and closed to G01/G02. Accessibility think-aloud, if
run, happens **after** the unaided window in the same session, and its findings
are tagged to a different gate set. **A think-aloud session cannot close G01.**

### 2.9 Recording, withdrawal, retention — Lane A

- Recording is optional; declining changes nothing about participation.
- A tester may withdraw at any time; their recording and notes are deleted on
  request, without reason.
- **Retention:** raw recordings deleted within **30 days** of notes being
  written. Session notes retained pseudonymously as gate evidence. Machine specs
  retained for G20 (they are evidence). Personal contact details deleted at
  cohort close.
- **Build keys revoked at cohort close** (§1.6).

---

## 3. Lane B — paid lived-experience depiction review

### 3.1 Definition and its authority

**Lane B is fully specified in
`design/NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md`, integrated
at `66cff04`. That document governs.** This section does not restate it; it
states only what changes when Lane B runs **alongside** a friends cohort.

**Purpose:** whether the depiction of narcolepsy is defensible. **G25 only.**

### 3.2 Population and exclusions

Paid individual reviewers with narcolepsy, engaged individually.

**Exclusions specific to running both lanes at once:**

- **No one may be in both lanes.** A Lane A tester cannot become a Lane B
  reviewer for the same build; their route experience is no longer fresh, and
  their unpaid session would retroactively look like the paid one's first half.
- **No reviewer recruited through a support group** — carried from the
  governing document's §9.
- **No reviewer recruited through the friends network**, because declining
  becomes socially expensive.

### 3.3 What changes when the lanes run together

| Risk | Control |
| --- | --- |
| Lane A findings cited toward G25 | Separate ledgers, separate `lane` field (§6.1). **A finding cannot change lane** |
| Lane B reviewer asked to comment on navigation | Out of scope, and **they are paid the same if they decline** |
| Reviewer sees Lane A's build key or tester list | Keys are per-person; the lists are not shared |
| One schedule pressures the other | **Lane B never waits on Lane A.** If Lane A slips, Lane B proceeds |

### 3.4 Consent, compensation, recording, withdrawal, retention

**Per the governing document**, not restated: six separately-defaulting
permissions; payment for preparation, session, written follow-up and re-review;
100% kill fee; full payment if a reviewer stops; recordings deleted within 30
days; withdrawal at any time including after release, without clawback.

**One addition specific to this cohort:** **the reviewer's build key is revoked
on their withdrawal, immediately**, which §1.6's per-person keys make possible.

---

## 4. Cohort sizing

### 4.1 The evidence for a small first cohort

**SOURCED.** Jakob Nielsen, *Why You Only Need to Test with 5 Users*, NN/g,
18 March 2000 — [nngroup.com](https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/)
(fetched 2026-08-27): five users find roughly 85% of usability problems under
the Nielsen–Landauer model `N(1−(1−L)^n)` with L ≈ 31%; the argument is for
**three small iterative rounds rather than one large study**.

**SOURCED, and this caveat is the one that matters here:** the same article
states that more users are needed when testing "several highly distinct groups
of users," recommending **3–4 users per category when there are two groups**.

**INFERENCE:** Lane A already contains at least two highly distinct groups —
**controller-only** and **keyboard/mouse** — because G07/G08 and G09 are
separate gates. So the five-user figure is a floor for *one* input route, not
for the cohort.

**This is also the citation that refuses to be stretched to Lane B.** Nielsen is
about finding usability problems by observing task performance. **It says nothing
about how many people are needed to judge whether a depiction is defensible, and
using it that way would be a category error** (§10).

### 4.2 Smallest viable first cohort

| Lane | Size | Composition | Rationale |
| --- | --- | --- | --- |
| **A** | **6** | 3 controller-only · 3 keyboard/mouse · across ≥2 distinct machines · ≥1 habitual caption user · ≥1 first-time horror player | 3 per input group per the two-group caveat; matches the runbook's "six friends is six keys" |
| **B** | **3 + 1** | 3 paid lived-experience reviewers, engaged individually + 1 paid clinician, narrow scope | Per the governing document §1.4 — three is the smallest number at which two can disagree and the disagreement stays visible |

**Total: 9 participants, 10 with the clinician.**

**RECOMMENDATION: do not shrink Lane B to fund Lane A.** If the budget forces a
choice, run Lane A with four and keep Lane B at three. Lane A findings are
recoverable by running another round; **a depiction review conducted by one
person is not a smaller review, it is a different and weaker claim** (§10).

### 4.3 The seam: G05, and how it is split

**G05's manual criterion, verbatim from the matrix, is:** *"trigger both gradual
and sudden onset with the option on and off."*

**REPOSITORY FACT: that criterion cannot be satisfied on the shipping slice.**
One case is enabled and its profile allows `gradual` only (§1.4). **A friends
tester cannot trigger a sudden onset, because no player can.** This is a
correction to the matrix and it is recorded as such in §13.

**G05 therefore splits, and each half goes to a different lane:**

| Half | Question | Lane | Closeable now? |
| --- | --- | --- | --- |
| **G05-a — mechanical** | Is the gradual warning legible, timely and does the setting behave in both states? | **A** | **Yes** |
| **G05-b — depiction** | Does the onset read as a fainting gag, a punishment, or a joke at the character's expense? | **B** | **Yes, for the gradual form** |
| **G05-c — the sudden form** | Both of the above, at 0.64–0.72 s | **neither, on this build** | **No** — §11.3 is an owner decision |

**INFERENCE:** recording G05 as a single gate closed by a single session is how
a navigation result would silently become a depiction claim. **Splitting it is
the whole point of this document.**

---

## 5. Lane A route protocol — the first 10–20 minutes, unaided

**Adopts G01's existing criterion. Does not invent a new one.**

### 5.1 Preconditions

- Packaged build from `tools/package_friends_build.ps1`, six-file contract
  intact, delivered by **personal revocable key**.
- **Fresh save. No prior session on that machine.**
- `README_TESTER.txt` **plus the content note** (§8.1 — currently missing, and
  blocking).
- **`ORISON_DEVELOPER_OVERLAYS` unset.** Verified before the session, not after.
- Machine specs recorded — they are G20 evidence.

### 5.2 The window

**Twenty minutes from first control, or until the player reaches the fault,
whichever is later.** Not a fixed cutoff: **stopping a player mid-route to
respect a clock destroys the evidence you are collecting.**

### 5.3 Intervention rules — a strict ladder

**The facilitator says nothing until a rung is triggered, and then says only
that rung's exact words.**

| Rung | Trigger | Exact permitted words | Effect on evidence |
| --- | --- | --- | --- |
| **0** | Anything else | *(silence)* | Evidence intact |
| **1** | Player asks a direct question | *"I'd like to see what you do without me — carry on however you like."* | **Intact.** Log the question — it is a finding |
| **2** | Player stuck ≥ **3 minutes** with no new action | *"Take your time. There's no wrong move."* | **Intact.** Log the timestamp and location |
| **3** | Player stuck ≥ **6 minutes**, or asks to stop | *"Would you like a hint, or would you rather stop here?"* | **G01 FAILS for this session.** Record it as a fail, not a near-miss |
| **4** | Hint accepted | Give the **smallest possible** hint. Log it verbatim | **G01 failed.** Continue for other gates |
| **5** | Crash, distress, or a stop rule (§8) | Stop immediately | Session void for G01 |

**Rung 3 is a gate failure and must be recorded as one.** **INFERENCE:** the
temptation is to log "needed a small nudge at the stairs" and still call the
route complete. That is precisely the "claims wider than their tests" failure
G28 already tracks.

### 5.4 Observation, interpretation, defect — kept apart

**Every session record separates three columns. Confusing them is how a
preference becomes a bug.**

| Column | Definition | Example | Who may write it |
| --- | --- | --- | --- |
| **OBSERVATION** | What happened, timestamped. **No causes, no adjectives** | *"14:32 — walked past the landing plate twice, then went up"* | Facilitator, during |
| **INTERPRETATION** | Why it might have happened. **Explicitly a guess** | *"They may not have read the plate as directional"* | Facilitator, after, **labelled** |
| **DEFECT** | A claim that something is wrong, with the evidence that supports it | *"G01: the 2A landing plate did not resolve direction for 2 of 6 testers"* | **Owner only, at triage** |

**Rules:**

1. **An observation with no interpretation is still valid evidence.**
2. **An interpretation may never be promoted to a defect by the person who wrote
   it.** Triage is a separate step by a different reader.
3. **A defect must name its denominator** — "2 of 6", not "testers found".
4. **A single observation may become a defect** if severe, but it must be
   labelled `n=1` and §10 applies.

### 5.5 What Lane A must state to close G01

> Build `<id>` at commit `<sha>`, fresh save, `<name/pseudonym>` on `<machine>`
> with `<input>`, completed the opening route unaided in `<mm:ss>` with **zero
> interventions at rung 3 or above**, and could state their next intention at
> every checkpoint. Signed: owner.

**Anything less is not G01.** Six sessions where four completed unaided is
"four of six", which is a real and useful result — **and it is not a closed
gate.**

---

## 6. Lane B protocol under the unnamed-condition constraint

### 6.1 The problem, stated plainly

**REPOSITORY FACT (§1.3): the build never names narcolepsy.** A reviewer who
plays it sees involuntary sleep onset, a dark pocket, and a return. **They do not
see a claim about narcolepsy, because the build makes none.**

The claim lives in the statement and the store copy. **INFERENCE:** this means a
naive Lane B session would review the wrong artifact — a reviewer would form
their view from a build that is, as far as it is concerned, about a tired
maintenance worker.

### 6.2 The protocol that works anyway — three passes, in this order

**Order is load-bearing and must not be varied.**

| Pass | What the reviewer receives | Question | Why this order |
| --- | --- | --- | --- |
| **P1 — blind** | The build and video, **with no statement, no store copy, and no mention of narcolepsy** | *"What do you think is happening to this character?"* | **The only chance to learn what the game communicates on its own.** Once told, it cannot be un-told |
| **P2 — informed** | The statement, the store copy including the lines the project already believes are wrong, the mechanic map | *"Now that you know what it claims, does the material support it?"* | Separates *what the game says* from *what we say about it* |
| **P3 — copy** | The store copy alone | *"Would you object to this beside a trailer?"* | The copy is where the harm concentrates |

**P1 is the single highest-value hour in either lane, and it is destroyed by one
careless sentence.** Hence §7.2 and §8.6.

### 6.3 Pricing the limitation — explicitly

**The limitation is not free and the packet must say so in writing:**

> *The game never uses the word "narcolepsy." You will be reviewing (a) what the
> material communicates without being told, and then (b) whether our claims about
> it hold up. **If you conclude that a game which never names the condition
> cannot make the claim our store copy makes, that is a finding and it is one of
> the most useful ones you could give us.***

**INFERENCE:** the honest price is that **P1's result may invalidate the
statement rather than support it.** A reviewer who watches the whole build and
says "I would not have known this character had narcolepsy" has not failed to
review it — they have answered §11.2's owner decision with evidence.

### 6.4 What Lane B may never be asked

- Whether the route is navigable, the signage legible, or the controls good.
- To confirm a Lane A finding.
- To speak for anyone but themselves.
- For a quote, a testimonial, or a public statement of support.

---

## 7. Contamination controls

### 7.1 Evidence separation

Two ledgers, never merged. Every record carries an immutable `lane` field
(§8.1's schema). **A finding may not change lane.** If a Lane A session produces
a depiction observation, it is discarded from the evidence base and, if the
tester wishes, becomes a reason to invite them into Lane B **as a paid
reviewer**, reviewing fresh material.

### 7.2 The disclosure rule

**No Lane A facilitator may tell a tester the character has narcolepsy.**

Not because it is a secret — the store copy will say it — but because a tester
who is told will produce depiction opinions we have not paid for and cannot use,
and because it contaminates the blind read if that person later enters Lane B.

**If a tester works it out and says so:** log it as an **observation** (it is
genuinely interesting that the game communicated it), and **do not follow up
with questions.**

### 7.3 Facilitator contamination

**One facilitator should not run both lanes on the same build.** **INFERENCE:**
after six sessions watching people miss the landing plate, a facilitator cannot
hear a reviewer's onset comment without navigation in their head. If one person
must do both, **run all of Lane B first** — it is the smaller job and the harder
block.

---

## 8. Finding taxonomy, triage, and stop rules

### 8.1 Ledger schema

One record per finding, in the lane's own ledger.

```json
{
  "finding_id": "A-0001",
  "lane": "A",
  "gate_refs": ["G01"],
  "build_id": "", "commit": "",
  "participant_ref": "T3",
  "input_route": "controller",
  "machine_ref": "M1",
  "observation": "",
  "interpretation": "",
  "class": "comprehension_defect",
  "denominator": "2 of 6",
  "evidence": "session note ref, timestamp range",
  "intervention_rung": 0,
  "disposition": "open",
  "owner": "",
  "may_close_gate": false
}
```

**Rules:** `lane` is immutable. `denominator` is **mandatory** on any class above
*preference*. `may_close_gate` defaults **false** and only the owner sets it.
`observation` and `interpretation` are separate fields and **the schema will not
accept a defect with an empty `observation`.**

### 8.2 Taxonomy and triage matrix

| Class | Definition | Lane | Blocks | Who may close | Needs re-test |
| --- | --- | --- | --- | --- | --- |
| **Release blocker** | Prevents completing or launching the build | A | friends build | Owner | **Yes** |
| **Depiction blocker** | The depiction would harm or mislead | **B only** | **any outreach (G25)** | Owner, after re-review | **Yes, by a reviewer** |
| **Accessibility blocker** | A player cannot use a documented accessibility affordance | A | Early Access | Owner | **Yes** |
| **Comprehension defect** | The player could not understand or proceed | A | public demo (G01/G02) | Owner | **Yes** |
| **Polish note** | Real, not blocking | either | nothing | Category owner | No |
| **Preference** | Taste. **Not a defect** | either | nothing | Category owner | No |

**Two rules that make the matrix honest:**

1. **A depiction blocker can only be raised in Lane B.** A Lane A tester's
   discomfort is a polish note or a preference, however sincere.
2. **A preference never becomes a defect by repetition.** Three testers
   disliking the colour grade is three preferences. §10.

### 8.3 Stop rule — distress

**Applies to both lanes. Stop immediately, without discussion:**

- the participant asks to stop, or goes quiet after distressing material;
- the participant appears to be experiencing symptoms;
- a participant says they feel obliged to be positive;
- **any facilitator begins defending rather than listening.**

**Stopping never reduces payment or standing. A stopped session is not a failed
session.**

### 8.4 Stop rule — debug-overlay leakage

**If any developer affordance appears — a debug panel, a floating label, noclip,
a fixture card — stop the session, void it for G18, and do not resume on that
build.**

**REPOSITORY FACT:** the gate exists (G18, MANUAL OPEN) and the boundary is
`ORISON_DEVELOPER_OVERLAYS`, pinned by `ReleasePresentationTest`. **INFERENCE:**
a leak means the packaged artifact is not what the tests describe, which makes
every other finding from that build unreliable — not just G18's.

### 8.5 Stop rule — microphone and network consent

- **No session may enable the microphone without the tester choosing it in the
  game's own consent panel.** A facilitator may not do it for them.
- **No session may enable network weather on the participant's behalf.**
- If a participant enables either and then expresses second thoughts, **stop,
  turn it off, and delete anything captured.**

### 8.6 Stop rule — accidental disclosure

- **Lane A:** if a facilitator names the condition, stop, log the contamination,
  and **exclude that tester from Lane B permanently.**
- **Lane B:** if P1 material is disclosed before the blind pass, **P1 is void for
  that reviewer.** They are **paid in full** and move to P2.
- **Either lane:** if a participant discloses health information we did not ask
  for — pause, check they are alright, do not record it, do not repeat it, do
  not use it to weight their opinion.

### 8.7 Stop rule — broken build

If the build crashes, fails to launch, or its `.sha256` does not match: stop,
**do not substitute a different build mid-session**, and void the session for all
gates. **INFERENCE:** a session split across two artifacts produces evidence
attributable to neither.

### 8.8 Stop rule — evidence that cannot support the claim

**The most important stop rule, and the one most likely to be skipped.**

**Before any finding is written into a gate, the writer must answer:**

> *Does this evidence support this exact claim, on this exact build, for this
> exact population?*

**Stop and downgrade if:**

- the claim names a population wider than the participants (**"players find…"**
  from six friends);
- the claim covers material the participants did not reach;
- the claim is about depiction and the evidence is from Lane A;
- the claim is about navigation and the evidence is from Lane B;
- **the denominator is missing**;
- the finding rests on a truncated read of the session record (§0.2).

**This is G28 — "claims wider than their tests" — applied to human evidence
instead of automated evidence.**

---

## 9. Templates

**All are drafts. Nothing has been sent. Lane A templates may not be sent until
§12's preconditions are met; Lane B's are governed by the ADMIN-REVIEW1
document.**

### 9.1 Lane A — invitation

> **Subject: Would you play 40 minutes of my game and tell me where you got lost?**
>
> I've built the first stretch of a horror game and **nobody who isn't me has
> ever played it.** I need to find out whether it makes sense to someone who
> doesn't already know the answers.
>
> **What it involves:** about an hour. You play about 20 minutes on your own
> while I stay quiet, then we talk. You'd run it on your own Windows machine and
> I'd send you a personal download link that I can withdraw afterwards.
>
> **What I actually need from you:** to get lost, and to tell me where. If you
> finish smoothly, that's useful. **If you can't work out what to do, that's more
> useful, and it is a bug in my game and not a failure of yours.**
>
> **Content note:** darkness, being pursued, involuntary loss of control of the
> character, and frightening imagery around sleep. The build is not
> code-signed, so Windows may warn you about it.
>
> **What I'd rather you didn't do:** be encouraging. I have plenty of that.
>
> If you'd rather not, just say so — no reason needed, and I won't ask twice.

### 9.2 Lane A — consent preamble

> Before we start, so nothing is a surprise:
>
> - **You can stop at any time**, for any reason or none, and it changes nothing.
> - I'd like to record the screen and our audio. **You can say no and we'll carry
>   on exactly the same.** No camera, ever.
> - Recordings are deleted within 30 days. My notes are kept without your name.
> - I'll write down your machine's specs, because I need to know what it runs on.
> - **The game can use your microphone in one optional activity, and it will ask
>   you first. I'm not going to turn it on for you** — that's yours to choose.
> - Weather can make an internet request. **It's off by default and I'm leaving
>   it off** unless you want to try it.
> - Nothing you say tonight will be quoted anywhere with your name unless you
>   tell me separately that it can be.
>
> Anything you'd like me to do differently?

### 9.3 Lane A — session opening

> Right — a few things and then I'll shut up.
>
> **I'm not going to help you.** I'll be quiet while you play. That's not me
> being difficult; **it's the whole experiment.** If you get stuck, being stuck
> is the result I need.
>
> **Please don't try to be nice about it.** If it's boring, be bored. If you
> don't know what you're doing, say so out loud — that's the most valuable thing
> you can give me.
>
> Talk to yourself if it's natural. If it isn't, don't force it.
>
> **You cannot break it, and you cannot do it wrong.** Ready when you are.

### 9.4 Lane A — debrief

**Open questions first. Leading questions never.**

> 1. What was that?
> 2. What were you trying to do, and did you know what you were trying to do?
> 3. Where did you get stuck? Tell me what you were thinking at that moment.
> 4. Was there a point you nearly stopped playing?
> 5. Did anything look like a mistake in the game rather than a mistake by you?
> 6. *(controller only)* Was there anything you couldn't do with the pad?
> 7. What would you change first?
> 8. What did I not ask about that I should have?

**Prohibited:** *"Did you like it?"* · *"Was the stair sign clear?"* ·
*"Most people go left there"* · anything naming the character's condition.

### 9.5 Lane A — follow-up

> Thank you — genuinely, the useful part was [specific thing that went wrong].
>
> Here's what I changed because of your session: [list]. Here's what I'm not
> changing yet and why: [list].
>
> Your download key is now switched off — that's routine, not a comment on you.
> Your recording has been deleted / will be deleted on [date].
>
> If you'd like a credit in the game, tell me the name to use. **If you'd rather
> not appear anywhere, that's the default and you don't need to reply.**

### 9.6 Lane B — templates

**Do not draft new ones.** `NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md`
§4 and §8b already contain the reviewer brief, the routing inquiry, the clinician
request and the post-review confirmation note. **Use those verbatim.**

**One addition for the blind pass (§6.2), to be sent as P1's covering note:**

> For this first pass I'm deliberately **not** telling you what the game claims
> about itself. I'd like to know what it communicates without my help. I'll send
> the statement and the store copy afterwards, and you'll have a full second pass
> to react to those. **Both passes are paid.**
>
> If that arrangement doesn't suit you, say so and I'll send everything at once —
> **it's your call, and you're paid the same either way.**

---

## 10. Worked example — why one anecdote is not consensus

### 10.1 The scenario

Three paid Lane B reviewers see the gradual onset.

- **R1:** *"The two-and-a-half seconds felt about right. I've had that."*
- **R2:** *"It read as fainting. Fainting is a different thing and people already
  confuse them."*
- **R3:** *"Didn't bother me. What bothered me was that she wakes up and just
  gets on with it — nobody just gets on with it."*

### 10.2 What the project is tempted to conclude

> *"Two of three reviewers were fine with the onset, so the onset is fine."*

**Every part of that sentence is wrong.**

### 10.3 Why

**SOURCED.** W3C WAI states plainly: *"Avoid assuming that input from one person
with a disability applies to all people with disabilities,"* adding that
"getting input from a range of users is best" —
[W3C WAI, *Involving Users in Evaluation*](https://www.w3.org/WAI/test-evaluate/involving-users/)
(fetched 2026-08-27). **This applies to R1 exactly as much as to R2.** R1 saying
it felt right is not clearance; it is one person's experience, and treating it as
clearance is the same error as treating R2's objection as universal.

**Three specific failures in the tempted conclusion:**

1. **Counting.** The governing document's §5.8 forbids majority resolution:
   *a single S1 is not overridden by two reviewers who did not see it.* R2 named
   a **mechanism** — that the depiction may reinforce an existing confusion
   between sleep attacks and fainting. R1 and R3 did not refute that mechanism;
   **they did not address it.** Silence on a mechanism is not disagreement with
   it.
2. **Direction.** R1's comfort is being used as evidence of safety. It is
   evidence about R1. **A harm claim and a no-harm claim are not symmetric:** one
   person experiencing harm demonstrates that the harm is possible; one person
   not experiencing it demonstrates nothing about its absence for others.
3. **The finding that got dropped.** R3 raised something **nobody asked about** —
   that the character absorbs an onset and carries on with no aftermath. That is
   packet question 8, it is the only finding here that implicates the writing
   rather than the timing, and **it would vanish entirely from a majority vote,**
   because it is a minority of one on a question the other two did not answer.

### 10.4 The correct handling

- R2's finding is logged as a **depiction blocker** with its harm mechanism
  stated, at **the severity R2 assigned**, and is investigated on its merits.
- R1's comment is logged as an **observation**, not as clearance, and **is not
  cited as support for anything.**
- R3's finding is logged as a **depiction blocker or defect in its own right**,
  and marked `minority_position: true` **without naming who raised it**.
- **Nothing is closed by two-against-one.**

### 10.5 Why three paid reviewers do not become medical authority

**They do not, and the arithmetic never gets there.**

Three reviewers are three people's experience. They are **not** a clinical
finding, a prevalence claim, a community position, or a mandate. **INFERENCE:**
the failure mode is subtle and flattering — after a good review round it becomes
tempting to say *"people with narcolepsy told us…"*, which converts three paid
individuals into a constituency none of them agreed to represent.

**Permitted after a completed review:**

> *"Paid reviewers with narcolepsy looked at this material, and these specific
> things changed because of what they said."*

**Not permitted, at any panel size:**

> *"Reviewed by the narcolepsy community"* · *"Verified accurate"* ·
> *"Clinically reviewed"* · *"People with narcolepsy approved it"* ·
> *"Endorsed by…"*

**The clinician does not fix this either.** A clinician can say a mechanic
misstates the condition. **A clinician cannot say the depiction is respectful,
and cannot consent on anyone's behalf.**

---

## 11. Owner decisions — not answered here

| # | Decision | Why only the owner | What is blocked | What I supply |
| --- | --- | --- | --- | --- |
| **11.1** | **Cohort budget** | Spends money; sets the panel size; a trade-off between lanes | Both lanes | §12's parametric arithmetic. **No rate invented** |
| **11.2** | **Is narcolepsy named in-game?** | An authorial choice about the work | Store copy, §6's protocol design | **REPOSITORY FACT** that it currently is not (§1.3), and P1 (§6.2) is built to produce evidence bearing on it |
| **11.3** | **Is sudden onset reviewed now or deferred?** | Trades money against exposure | G05-c | **REPOSITORY FACT** that it is unreachable on this build (§1.4, §4.3). Reviewing now means paying people to review a plan; deferring means the first sudden onset ships unseen by any reviewer |

**I am not answering these and no default is implied by their order.**

---

## 12. Parametric budget

**No lived-experience market rate is asserted.** `R` is **owner-supplied**.
`NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md` §8.1 records that
no authoritative rate for this work was found, cites the two anchors it did find
with their limits, and recommends **asking each reviewer their rate and paying
it.** That stands.

### 12.1 Symbols

| Symbol | Meaning | Value |
| --- | --- | --- |
| `R` | Lane B reviewer hourly rate | **OWNER-SUPPLIED** |
| `C` | Clinician hourly rate | **OWNER-SUPPLIED** |
| `n_B` | Lane B reviewers | 3 (smallest viable) |
| `n_A` | Lane A testers | 6 |
| `T` | Token of value per Lane A tester | **OWNER-SUPPLIED** (§2.6) |

### 12.2 Lane B hours per reviewer

| Component | Hours | Basis |
| --- | --- | --- |
| P1 blind pass — build and video | 2.0 | One continuous run plus the isolated clips |
| P2 informed pass — statement, copy, mechanic map | 1.5 | |
| P3 copy pass | 0.5 | |
| Written notes before any group contact | 1.5 | Governing doc §5.2 |
| Live session | 1.5 | 90 minutes, optional, **paid whether or not attended** |
| Re-review after changes | 1.5 | Governing doc §5.7 |
| **Total per reviewer** | **8.5 h** | |

### 12.3 Arithmetic

```
Lane B reviewers   = n_B × 8.5 × R      = 3 × 8.5 × R  =  25.5 R
Clinician          = 3.0 × C                            =    3.0 C
Lane A tokens      = n_A × T            = 6 × T         =    6.0 T

FIRST COHORT TOTAL = 25.5·R + 3.0·C + 6.0·T
```

**Contingencies, additive and not optional:**

```
Kill fee (cancelled inside 7 days)      = up to 8.5 · R per affected reviewer
Stopped session, paid in full           = no reduction; already inside 25.5·R
Second re-review round                  = 1.5 · R per reviewer  = 4.5 R
Accommodation costs (§ governing doc)   = OWNER-SUPPLIED, unbudgeted here
```

**Worked shape, with `R` and `C` left symbolic:** at `n_B = 3`, Lane B's floor is
**25.5 reviewer-hours**. If the owner halves the panel to save money, the saving
is `8.5·R` — **one reviewer's fee** — and the cost is the ability to see
disagreement at all (§10). **INFERENCE: that is the worst-value saving available
in this plan.**

### 12.4 Follow-up cohort

Run only after the first cohort's required findings are addressed and re-tested.

| Lane | Size | Purpose |
| --- | --- | --- |
| **A2** | 5–8, **all new people** | Second Nielsen round on the revised build; add the machine diversity G20 still lacks |
| **B2** | Re-review by **the same** reviewers, plus optionally 1–2 new | Re-review is a governing-doc requirement; new reviewers give a fresh blind pass on changed material |

```
FOLLOW-UP TOTAL = (n_B × 1.5 × R) + (n_new × 8.5 × R) + (n_A2 × T)
```

**A2 must be new people.** A tester who has played it cannot get lost in it
again.

---

## 13. Corrections to prior findings

**Stated plainly.**

**C1 — three documents named in the assignment do not exist under those names.**
`EARLY_ACCESS_EXECUTION_PLAN.md`, `EARLY_ACCESS_GATE_LEDGER.md` and
`FRIENDS_BUILD_RUNBOOK.md` are absent from `design/`. I audited the actual
equivalents rather than reporting them missing:

| Named | Actual |
| --- | --- |
| `EARLY_ACCESS_EXECUTION_PLAN.md` | `CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md`, `EARLY_ACCESS_GO_TO_MARKET_PROJECT.md` |
| `EARLY_ACCESS_GATE_LEDGER.md` | `EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md` |
| `FRIENDS_BUILD_RUNBOOK.md` | `FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md` |
| "tester README material" | **`distribution/README_TESTER.txt`** — exists and is tracked |

**C2 — G05's manual criterion is unsatisfiable on the shipping slice, and this
corrects a document I wrote.** The matrix says *"trigger both gradual and sudden
onset with the option on and off."* One case is enabled and its profile allows
`gradual` only. **No participant in either lane can trigger a sudden onset,
because no player can.** I wrote that criterion in the evidence matrix before
auditing `dream_profiles.json`. §4.3 splits the gate into G05-a/b/c rather than
leaving a criterion nobody can meet.

**C3 — `distribution/README_TESTER.txt` still has no content note.**
`NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md` handback item 13
recorded this; it is unchanged at `0029c4a`. **It now blocks Lane A as well**,
because §9.1's invitation carries a content note the shipped README does not.
Those two must not disagree.

**C4 — RESOLVED DURING THIS TASK, and the resolution is recorded rather than
quietly absorbed.** The governing ADMIN-REVIEW1 document recorded that
**outreach was blocked** by store copy making narcolepsy the agent of the horror
(`EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md:61,71`). Commit
`0029c4a` rewrote all three lines — the hook, the 50-word pitch and the store
short description — so the condition names the interval and something else owns
the menace, and added a **"Representation copy gate"** applying
`ORISON_MAZE_BRIEF.md:1029`'s failure test to every store, press, trailer and
tester-facing line.

**Consequence for this plan: §14 precondition 7 is CLOSED and Lane B is no
longer blocked by copy.** Two clauses in that new gate govern this document
directly and are adopted here:

> *"Audience sentiment, conversion and engagement measure marketing performance.
> They are never evidence that the depiction is accurate or harmless."*
>
> *"Passing this internal gate permits paid review to begin. It is not review,
> endorsement, medical authority or community consensus."*

**INFERENCE:** the second clause is the same boundary §10.5 draws from the other
side. **Passing an internal copy gate is permission to start Lane B, not a
substitute for it.**

**Unchanged by the fix:** a friends cohort was never outreach in the first place
— it is private testing with a content note, permitted by the governing
document's §7.2. **Lane A's blocks remain §14's 1–5.**

---

## 14. Preconditions before either lane starts

| # | Precondition | Lane | Repository state |
| --- | --- | --- | --- |
| 1 | Content note added to `README_TESTER.txt` | **both** | **OPEN** (C3) |
| 2 | Build packaged by the contract, six-file artifact, `.sha256` issued | both | Tooling exists (§1.6) |
| 3 | `ORISON_DEVELOPER_OVERLAYS` verified unset in the artifact | both | Gate G18 open |
| 4 | Per-person revocable keys in place | both | Channel recommended, not established |
| 5 | Rollback rehearsed (G23) | both | MANUAL OPEN |
| 6 | Budget set; `R`, `C`, `T` supplied | **B**, partly A | **OWNER (§11.1)** |
| 7 | Store-copy contradiction fixed | **B only** | **CLOSED** by `0029c4a` — C4 |
| 8 | Two ledgers created, `lane` immutable | both | Schema at §8.1 |
| 9 | Facilitator assignment fixed (§7.3) | both | — |

**Lane A is blocked on 1–5. Lane B is blocked on 1–6 and 8** — precondition 7
closed during this task.

**INFERENCE:** with 7 closed, the only remaining Lane B blocker that is not
shared with Lane A is **the budget (§11.1)**. Lane B is now one owner decision
away from being runnable.

---

## 15. Sources

### 15.1 Repository, at `0029c4a` (whole-file inspection)

`design/EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md` (28-gate summary
index; G01 and G05 detail sections) ·
`design/NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md` (governing
document for Lane B) ·
`design/NARCOLEPSY_DEPICTION_STATEMENT_AND_REVIEW_PACKET_2026-08-27.md` ·
`design/FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md` ·
`design/FRIENDS_BUILD_PRIVACY_AND_CONSENT_AUDIT_2026-08-26.md` ·
`design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md:13,127` ·
`design/EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md:61,71` ·
`design/STEAM_ACCESSIBILITY_DECLARATION_AUDIT_2026-08-26.md` ·
`game/docs/CAPTURE_EVIDENCE_PROTOCOL.md` (referenced by the matrix's G19) ·
**`distribution/README_TESTER.txt`** (full file) ·
`tools/package_friends_build.ps1` (read-only) ·
`game/data/reality_cases.json` (18 records parsed, 1 enabled) ·
`game/data/dream_profiles.json` (6 profiles parsed) ·
`game/scripts/game_boot.gd:89` · `game/scripts/ui/accessibility_copy.gd:9,11` ·
`game/tests/` route suites, listed read-only.

### 15.2 External, all as-of 2026-08-27

| Source | Date | Exact proposition it supports here |
| --- | --- | --- |
| [W3C WAI, *Involving Users in Evaluation*](https://www.w3.org/WAI/test-evaluate/involving-users/) — **fetched** | current guidance | "Avoid assuming that input from one person with a disability applies to all people with disabilities"; a range of users is best; accessibility testing typically uses think-aloud with **high facilitator interaction**, distinct from conformance evaluation. Supports §10.3 and the §2.8 tension |
| [Nielsen, *Why You Only Need to Test with 5 Users*, NN/g](https://www.nngroup.com/articles/why-you-only-need-to-test-with-5-users/) — **fetched** | 18 Mar 2000 | 5 users ≈ 85% of usability problems under `N(1−(1−L)^n)`, L ≈ 31%; **3–4 per category when there are two distinct groups**; prefer three small rounds. Supports §4.1–4.2. **Practitioner research, not a primary standard** |
| [HHS, *The Belmont Report*](https://www.hhs.gov/ohrp/regulations-and-policy/belmont-report/read-the-belmont-report/index.html) — **HTTP 403 to automated fetch; wording via institutional summaries** | 1979 | Respect for persons, beneficence, justice; **coercion** = an overt threat of harm to obtain compliance; **undue influence** = an offer of excessive, unwarranted, inappropriate or improper reward to obtain compliance. Supports §2.5, §2.6 |
| [ICO, *Principle (c): Data minimisation*](https://ico.org.uk/for-organisations/uk-gdpr-guidance-and-resources/data-protection-principles/a-guide-to-the-data-protection-principles/data-minimisation/) — **HTTP 403 to automated fetch; wording via ICO-derived summaries** | current | Personal data must be "adequate, relevant and limited to what is necessary in relation to the purposes for which they are processed"; review periodically and delete what is no longer needed. Supports §2.9 retention |

---

## 16. Limitations

- **Two primary sources could not be read directly.** `hhs.gov` and `ico.org.uk`
  both returned HTTP 403 to automated fetch on 2026-08-27. Their propositions are
  marked and **must be checked against the primary text before being quoted
  publicly.**
- **The Nielsen source is practitioner research from 2000, not a standard.** It
  is cited for cohort sizing only, and §4.1 states explicitly that it does not
  transfer to Lane B.
- **This document is not legal advice and makes no regulatory claim.** Lane A is
  not regulated human-subjects research; the Belmont principles are used as an
  ethical frame, not an assertion that any regime applies.
- **No rate was invented.** `R`, `C` and `T` are symbols throughout.
- **Gate closeability in §1.2 is my mapping, not the matrix's.** The matrix
  states each gate's manual criterion; the lane assignment is **INFERENCE**.
- **Reachability facts were established from source, not from running the game**,
  as required. The claim that no participant can trigger a sudden onset rests on
  one enabled case and Mina's gradual-only profile.
- **I did not audit art, audio or scene-baked text** for sleep or condition
  content; a texture or caption could name what a string search cannot find.
- **The largest limitation is structural:** this plan can make a review honest,
  well-paid and well-recorded. **It cannot make the depiction defensible.** Only
  §11.2's and §11.3's decisions, and the reviewers themselves, bear on that.
