# Early Access critical path reconciliation — 2026-08-27

**Base:** `c1fcf4d80734c164d1677f5f0919da46a725a7fd` (pushed `origin/main`,
"Measure the Early Access shadow budget").

**Godot was not run.** No production code, data, scene, test, `TASKS.md`,
release script or existing design document was modified. One new file.

**Origin advanced twice during this task.** The assignment expected `218afdf`.
At first fetch the tip was `fa37744` and the expected G05/content-note
correction was **not present** — I verified its absence directly rather than
assuming. `218afdf` landed carrying it. Then `c1fcf4d` landed, **materially
changing G17 and therefore action N7**, which is no longer an optimisation task.
The branch was replayed onto each tip in turn and every claim below re-verified
at `c1fcf4d`; the gate census was re-parsed and is unchanged.

> **Four labels.** **REPOSITORY FACT** — verified in-tree at `c1fcf4d`, with a
> path. **INFERENCE** — my reading. **OWNER DECISION** — §8; I am not answering
> it. **RECOMMENDATION** — mine; the owner decides.

### Full-file inspection rule

**No count, census or absence claim in this document comes from truncated
output.** Every count states its denominator and the tool that produced it. A
`head`, a grep sample or a first-page read is a pointer, never evidence.
**Silence in a partial read is not a result.**

**Applied here:** the gate census in §2 was produced by parsing all 28 table rows
with a script, not by reading the summary line — **which is how §7 found that
the summary line is now wrong.**

---

## 1. The smallest Early Access promise

**Five sentences. This is the promise the ten actions exist to deliver.**

> You are the night superintendent of a 1928 New York apartment house that
> breaks in ordinary ways and answers in ways that are not. In one replayable
> shift you find a fault by ear, repair it with your hands, and earn the truth
> from the resident it belongs to. You work around narcolepsy, and when sleep
> closes the shift the house is not the house any more. You wake in 4B keeping
> every piece of progress you earned. One case, one dream pocket, one pursuer,
> one truth — everything else in the building is walkable and unpolished on
> purpose.

**REPOSITORY FACT:** this restates `EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md`
§2's eleven beats and §3's ceilings, **with one deliberate narrowing.** Beat 9 in
that document reads *"Succumb | onset, gradual and sudden"*. **That is no longer
true of the shipping slice** and §6 records it as a claim that narrowed.

---

## 2. Where the repository actually is

**REPOSITORY FACT**, produced by parsing all 28 gate rows of
`EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md` at `c1fcf4d`:

| Status | Count | Gates |
| --- | --- | --- |
| CODE GREEN / MANUAL OPEN | **9** | G01 G02 G07 G08 G09 G13 G14 G18 G23 |
| PROVED (code) / MANUAL OPEN | **1** | G11 |
| PROVED | **4** | G12 G16 G19 G27 |
| PARTIAL (all variants) | **10** | G03 G04 **G05** G06 G15 G17 G21 G22 G25 G28 |
| ABSENT | **2** | G20 G24 |
| BLOCKED ON OWNER RULING | **1** | G26 |
| UNKNOWN | **1** | G10 |
| **Total** | **28** | |

**Eleven distinct items need a human**: the nine CODE GREEN / MANUAL OPEN, plus
G11, plus **G05-a** which now sits inside a PARTIAL. **INFERENCE: that is the
cohort's job list, and it is the shape of the whole remaining problem — the code
is far ahead of the evidence.**

### 2.1 What landed while nobody was looking

**REPOSITORY FACT:** 122 commits since ADMIN-EA1 (`627eae5..c1fcf4d`, counted
with `git rev-list --count`). The three that most change this plan:

| Commit | Effect |
| --- | --- |
| `0029c4a` | Store copy no longer makes narcolepsy the agent of the horror; adds a **Representation copy gate**. **Unblocked the depiction lane** |
| `218afdf` | **Split G05** into a/b/c and **added the content note** to `distribution/README_TESTER.txt`. Closed the last shared cohort precondition |
| `1112cb9` + `d0fc374` | **Made the hero repair panel controller-reachable** — §7 C2 |
| `c1fcf4d` | **Measured a shadow policy that clears every playable station.** Turned N7 from optimisation into integration |

---

## 3. The critical path

Four destinations. **They are not one queue** — two of them run in parallel and
the plan is wrong if they are serialised.

### 3.1 To the first unaided friends cohort

```
Content note in README_TESTER  ── DONE (218afdf)
Package tooling + export       ── DONE (G27 PROVED; G23 mechanical proof)
Controller reaches repair      ── DONE (1112cb9, pinned by ControllerInputTest)
Overlay gate                   ── code DONE; G18 needs one human look
        │
        └──►  ONE REMAINING BLOCKER: a private channel with per-person
              revocable keys, and a signed-off build issued into it.
```

**INFERENCE: the friends cohort is one logistics task away from running.** Not
one code task. That is a better position than the gate ledger reads.

### 3.2 To the depiction review

```
Store copy contradiction  ── DONE (0029c4a)
Content note              ── DONE (218afdf)
G05-b scope defined       ── DONE (218afdf)
Process, templates, ledger── DONE (ADMIN-REVIEW1 + ADMIN-PLAY1)
        │
        └──►  ONE REMAINING BLOCKER: the paid review budget. §8 D1.
```

**This is the longest wall-clock pole in the project** — recruitment, a ten-day
asynchronous access period, sessions, triage, revision, re-review — **and it
blocks any outreach at all**, which means the store page, the trailer and the
press kit. **RECOMMENDATION: start it first, because it finishes last.**

### 3.3 To a release-candidate build

Needs, beyond the two above: **G03 G04 G05-a G06** human verification ·
**G17** a measured shadow policy integrated and re-verified (§4 N7) ·
**G20** a second machine ·
**G21 G22** completed · **G26** owner ruling · **G28** claims narrowed to
their evidence.

### 3.4 To a public Early Access page and build

Needs all of the above **plus G24** — store assets and an AppID, currently
**ABSENT**, and the only destination requiring money and an external account.

**INFERENCE — the ordering insight:** 3.1 and 3.2 share no remaining blocker.
One waits on a channel, the other on a budget. **Run them concurrently or lose
weeks for nothing.**

---

## 4. The next ten actions

**Exactly ten. Ordered by what unblocks the most.** Effort bands are XS/S/M/L
only. No dates are invented anywhere in this document.

---

**N1 — Fund the paid review panel, or decide not to yet**
· **Owner:** owner · **Gates:** G25, G05-b
· **Evidence:** `NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md`
§8.1 (rate UNKNOWN, two anchors with their limits); `FIRST_HUMAN_PLAY_COHORT_OPERATIONS_2026-08-27.md`
§12 (25.5 reviewer-hours as Lane B's floor)
· **Prerequisite:** none — every other precondition is now closed
· **Deliverable:** `R`, `C`, `T` supplied, or a written deferral
· **Exit (binary):** a figure exists in writing, **or** G25 is formally deferred
· **Effort:** XS · **Needs:** owner ruling, money. No Godot, no tester, no account

---

**N2 — Rule the Lena work order**
· **Owner:** owner · **Gates:** G26, and it unblocks G28
· **Evidence:** G26 — `lena_radiator_round_2b` points at `lena_unraveling`
(`enabled: false`) and a `dream_profile_id` `lena_visible_patch` that **exists
nowhere else in the repository**; it is the direct cause of the standing
`WalkTest` failure at `walk_test.gd:1152`
· **Prerequisite:** none
· **Deliverable:** keep, cut, or defer the job — a ruling, not a test edit
· **Exit (binary):** the ruling is recorded **and** `WalkTest`'s one-authored-job
assertion agrees with it
· **Effort:** XS · **Needs:** owner ruling
· **Do not fix the test first** — that ratifies an unruled work order

---

**N3 — Reconcile the evidence matrix with what is already true**
· **Owner:** Claude (Godot-free) · **Gates:** G28, and the accuracy of G03/G05
· **Evidence:** §7's three corrections — the stale summary count, G03's fixed
"known defect", and the sudden-onset claims that narrowed
· **Prerequisite:** none
· **Deliverable:** corrections in place, dated, in the matrix and the scope audit
· **Exit (binary):** the summary line's counts equal a fresh machine parse of the
table, **and** no gate cites a defect that no longer exists
· **Effort:** S · **Needs:** nothing
· **INFERENCE:** this must precede N5, or six testers spend a session hunting a
controller defect that was fixed weeks ago

---

**N4 — Stand up the private channel and issue build #1**
· **Owner:** Codex + owner · **Gates:** G23; enables G01 G02 G07–G09 G11 G13 G14 G18 G20
· **Evidence:** `FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md` recommends an
unlisted itch.io project with per-person revocable keys — *"six friends is six
keys you can withdraw"*; `tools/package_friends_build.ps1` enforces a six-file
artifact contract and refuses to overwrite a numbered artifact
· **Prerequisite:** N3 (so the build is measured against correct gates)
· **Deliverable:** a numbered artifact with `.sha256`, issued to six named people
as six revocable keys
· **Exit (binary):** six keys exist, each revocable independently, and one
non-developer machine has launched the artifact
· **Effort:** S · **Needs:** external account, owner. **No money required at this
tier — do not assume that; verify before committing**

---

**N5 — Run friends cohort round one**
· **Owner:** owner as facilitator · **Gates:** G01 G02 G05-a G07 G08 G09 G11 G13 G14 G18 G20
· **Evidence:** `FIRST_HUMAN_PLAY_COHORT_OPERATIONS_2026-08-27.md` §2 (Lane A),
§5 (route protocol, five-rung intervention ladder), §8 (taxonomy, stop rules)
· **Prerequisite:** N3, N4
· **Deliverable:** six session records; the G01 signature block filled or
explicitly failed
· **Exit (binary):** at least one tester completed the route **unaided with zero
interventions at rung 3 or above**, signed by the owner — **or** the first
blocking transition is named with a timestamp
· **Effort:** M · **Needs:** human testers
· **A hint given is a recorded gate failure, not a near-miss**

---

**N6 — Recruit and run the depiction review**
· **Owner:** owner · **Gates:** G25, G05-b
· **Evidence:** ADMIN-REVIEW1 §4 (reviewer brief), §8b (outreach drafts), §5
(protocol); ADMIN-PLAY1 §6 (blind → informed → copy passes)
· **Prerequisite:** N1 only. **Explicitly NOT N5** — Lane B never waits on Lane A
· **Deliverable:** three paid reviewers' written findings, triaged, with a
completed review record
· **Exit (binary):** every required finding is fixed or scoped under the four
§7.5 conditions, **and** reviewers have seen the revisions
· **Effort:** L · **Needs:** money, human reviewers
· **A usability observation may never close this gate**

---

**N7 — Land the measured 64/5 shadow policy and re-verify**
· **Owner:** Codex · **Gates:** G17, and it gates the public demo
· **Evidence:** `c1fcf4d` changed this gate's nature. At production **64/16**,
lobby 18.06, atrium F03 landing 23.70 and carriageway 16.67 ms are over the
16.6 ms budget. A completed **thirteen-station 64/5 cross-section clears every
playable station** — lobby **14.01**, landing **15.25**, carriageway **16.40**,
the other eight playable views 7.18–12.42 ms
(`AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md`). The two composition cameras
(atrium eye **22.93**, street elevation **26.28**) **remain over, are not
gameplay evidence, must never be quoted as such — and shadow rationing is not
their fix**
· **Prerequisite:** **the owner's unrelated uncommitted edit to the shared
`BuildingRoot` file must land first.** The gate says so in terms: integrate the
one-number policy *"without absorbing that owner's edit"*
· **Deliverable:** production requests 64/5; all thirteen stations re-run; frozen
visual pairs re-priced
· **Exit (binary):** every playable station at or under 16.6 ms **re-measured
after integration on the same corrected harness**, and the frozen pairs show no
lost railing, landing, relief or practical-light legibility
· **Effort:** S · **Needs:** Godot, and a shared-file sequencing decision
· **This is no longer an optimisation task.** The measurement is done; the risk
is now entirely in the integration — **stage named paths only, never `git add -A`,
or the owner's edit gets absorbed into a performance commit**

---

**N8 — Human-verify the three content gates**
· **Owner:** owner · **Gates:** G03, G04, G06
· **Evidence:** G03 needs a full repair including **one abort and one refusal**
(and the controller path, now that `1112cb9` reaches it); G04 needs answer,
dismiss and Building Services correctly refused mid-call
(`pause_services.gd:32–35`); G06's criterion is *Execution plan M5* — first-time
players frightened, knowing why the passage ended **within half a second**,
waking in 4B without lost progress
· **Prerequisite:** N5 (same sessions, different observation sheets)
· **Deliverable:** three signed verification records
· **Exit (binary):** each gate's stated manual criterion met and signed, or its
exact failure recorded
· **Effort:** S · **Needs:** human testers
· **G06 is a fear gate and only a first-time player can answer it** — it is spent
the moment they have played

---

**N9 — Close the loop on what round one broke**
· **Owner:** Codex · **Gates:** whichever N5 and N8 opened
· **Evidence:** the round-one finding ledger; ADMIN-PLAY1 §8.2's taxonomy —
release blocker and comprehension defect only
· **Prerequisite:** N5, N8
· **Deliverable:** fixes for every release blocker and comprehension defect;
polish notes and preferences deferred, **not fixed**
· **Exit (binary):** every finding classed blocker or comprehension defect is
closed and re-tested; **the count of deferred polish notes is stated**
· **Effort:** M · **Needs:** Godot
· **The discipline is refusing the polish notes**, not doing them

---

**N10 — Build the store page and acquire the AppID**
· **Owner:** owner + Codex · **Gates:** G24, and it completes the public path
· **Evidence:** G24 is **ABSENT**;
`EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md` §9 defines the press and
creator kit and requires a reviewed depiction statement before outreach
· **Prerequisite:** N6 complete (G25 blocks **any** outreach), N7 (no
performance claim without it), N5 (no playtime or completion claim without it)
· **Deliverable:** store page, capsules, trailer cut from proved material only
· **Exit (binary):** the page exists and **every claim on it maps to a closed
gate** — checked against G28
· **Effort:** L · **Needs:** money, external account, owner ruling
· **This is last for a reason.** Every earlier action is what makes its claims
true

---

## 5. Blockers, polish, and what is exiled

### 5.1 Blockers — on the path

N1–N10. Nothing else.

### 5.2 Exiled until a named re-entry gate

**REPOSITORY FACT:** each of these exists in the tree and has a design document
arguing for it. **INFERENCE: that is exactly why they are dangerous** — they are
well-specified, enjoyable, and off-path.

| Tempting work | Why it is off-path | **Re-entry gate** |
| --- | --- | --- |
| **Dream breadth** — fauna, organelles, microbiology, tentacle hero, encroachment, temporal specimens | Scope audit §3 caps Early Access at **1 pocket, 1 pursuer, 1 wake family, 1 release print**. It calls this "the largest single cut in this document" | After **G06 passes** with the one pocket. Not before |
| **Prop breadth** — service round, boiler, ballcock, chute, dumbwaiter, fuse, interlock, annunciator | The route needs five apparatus. Others may remain operable; **none may be required** | After **N9**, and only if a cohort finding names one |
| **New lore apparatus** — House English surfacing, light-fixture cards, the Vantry gateway/subway proposal | None is reachable by a player today. House English has **zero production callers**; the 191 fixture cards are behind `ORISON_DEVELOPER_OVERLAYS` | After Early Access ships. Fixture cards additionally blocked by the T1 temporal ruling |
| **Generalised engine extraction** (K0-ENGINE) | Continuous by charter, unbounded in practice. It makes nothing on this list true | Opportunistically **inside** an N7 or N9 fix, never as its own task |
| **Marketing experiments** — devlogs, sentiment tests, audience development | G25 blocks **any outreach**, and the Representation copy gate states that sentiment "never" evidences depiction safety | After **N6** closes G25 |
| **A second case (Peter, M7) and the six-case campaign (M8)** | Scope audit §3: *"Do not finish a second."* The execution plan runs to M8; Early Access stops around M6 | Post-launch content beat |

**INFERENCE:** five of these six have shipped code already. **The temptation is
not to build them — it is to finish them.**

### 5.3 Polish — real, and not now

Everything in ADMIN-PLAY1's taxonomy classed *polish note* or *preference*.
**N9's exit criterion requires stating how many were deferred**, so they are
counted rather than lost.

---

## 6. Claims that narrowed when G05 split

`218afdf` split G05 into **G05-a** (reachable gradual mechanics, MANUAL OPEN),
**G05-b** (reachable gradual depiction, blocked on review budget) and **G05-c**
(sudden onset, deferred, no playable evidence). **Four claims elsewhere in the
repository are now wider than the gate.**

| # | Claim | Location | Now |
| --- | --- | --- | --- |
| **W1** | Beat 9: *"Succumb \| onset, gradual and sudden"* | `EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md:103` | **The release promise itself over-claims.** The shipping slice is gradual-only. Corrected in §1 |
| **W2** | *"Prototype gradual and sudden sleep onset, dark scramble and bed return"* | `CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md:322` | An M2 task, not a shipped claim — but it is where the promise came from |
| **W3** | The reviewer packet asks for *"one gradual and one sudden onset"* | `NARCOLEPSY_DEPICTION_STATEMENT_AND_REVIEW_PACKET_2026-08-27.md:98` | Already flagged in ADMIN-REVIEW1 C2 and **still unamended.** Sending it as written asks a paid reviewer for material that does not exist |
| **W4** | Trailer beat *"Narcolepsy transition"* at 1:05–1:15 | `EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md:265` | Already `GATED` on K2. Must additionally not imply the sudden form |

**Not a defect and deliberately excluded:** `ORISON_MAZE_BRIEF.md:129` —
*"Later case profiles may permit sudden onset"* — is correctly future-tense and
needs no change.

---

## 7. Complete but still shown as open

**Three. All verified at `c1fcf4d`, and two of them are in documents I wrote.**

### C1 — The matrix summary index is one gate stale

**REPOSITORY FACT.** The summary at `:154` reads *"28 gates. 5 PROVED. 10 CODE
GREEN / MANUAL OPEN. 9 PARTIAL…"*. A script parse of all 28 rows gives **9 CODE
GREEN / MANUAL OPEN and 10 PARTIAL** — G05 moved when `218afdf` split it.
`218afdf` updated the table and the G05 section **but not the summary index.**

**INFERENCE:** harmless in itself, and it is the number a reader quotes. This is
the correction that justifies §0's inspection rule: **reading the summary line
instead of the table would have reproduced the error.**

### C2 — G03 still reports a defect that was fixed

**REPOSITORY FACT — the matrix contradicts itself, in the same file.**

At `:64` a banner reads: *"**CONTROLLER STATUS — `a6c4ba1`, 2026-08-26:** G03 is
no longer blocked by raw keycodes: the maintenance hero mechanism and Otis board
consume semantic actions… Focused evidence is green, including
`MaintenancePanelInputTest` 18/18."*

At `:204–206` the G03 gate section still reads: *"**Known defect:** the panel
reads **raw keycodes** (`maintenance_activity_panel.gd:117–145`), so it is
unreachable from a gamepad by construction."*

**The banner is right.** At `c1fcf4d` the panel handles input through semantic
actions — `activity_adjust_left`, `activity_adjust_right`, `activity_commit`,
`ui_cancel` (`maintenance_activity_panel.gd:117–150`) — and `game_boot.gd:26–28`
binds them to **D-pad left, D-pad right and A**, with `ui_cancel` on **B** and
`pause_services` on **START**. `ControllerInputTest` pins every one of those
bindings. Fixed by `1112cb9` and `d0fc374`.

**Correcting my own first reading of this:** I initially recorded that nobody
had noticed the fix. **That was wrong and unfair to the record** — the fix was
documented in a banner the same day it landed. The actual defect is narrower and
worse: **a reader who goes to the G03 section, which is where a gate's criteria
live, is told the opposite of what the banner says.**

**INFERENCE, and it changes the plan:** I carried H1 forward as a live blocker
through ADMIN-INPUT1, the QA matrix and ADMIN-PLAY1 — reading the gate section
and not the banner. **The controller lane of the friends cohort is not blocked**,
which is why N5 can run both input routes in round one. **G03's manual
verification is still open**, and the banner is precise about what remains:
G07 is open at *"MANUAL/PHYSICAL PAD"* — *"no person has yet completed the
eleven-beat first route pad-only, and no second controller family or hot-swap
session has been signed off."*

### C3 — Two cohort preconditions closed while ADMIN-PLAY1 was being written

**REPOSITORY FACT.** ADMIN-PLAY1 §14 lists nine preconditions. **Precondition 1**
(content note in `README_TESTER.txt`) was closed by `218afdf`, which added a
CONTENT NOTE section naming excessive daytime sleepiness, gradual involuntary
onset, sleep/wake hallucination, darkness, pursuit and distorted spaces — and
stating that the diagnosis is not named in-game and that sudden-onset profiles
are not enabled. **Precondition 7** (store copy) was closed by `0029c4a`.

**Consequence:** Lane A is now blocked on preconditions 2–5 only, of which
**2, 3 and 5 have mechanical proof already** — leaving **the channel (4)**. Lane
B is blocked on **the budget alone**.

### C4 — A correction to ADMIN-PLAY1's own headline

ADMIN-PLAY1 §1.1 says *"Ten gates are waiting for a human."* At `c1fcf4d` the
correct statement is **eleven distinct human tasks** — nine CODE GREEN / MANUAL
OPEN, plus G11, plus **G05-a**, which the split moved inside a PARTIAL row where
a status-column count no longer sees it. **The number went up because a gate got
more honest, not because work was added.**

---

## 8. Owner decisions — one box, unanswered

| # | Decision | Blocks | What exists to decide with |
| --- | --- | --- | --- |
| **D1** | **Paid review budget** — `R`, `C`, `T` | **N1 → N6 → N10.** The longest pole | ADMIN-REVIEW1 §8.1: rate UNKNOWN, two anchors with their limits stated, and an explicit refusal to invent a figure. ADMIN-PLAY1 §12: 25.5 reviewer-hours as Lane B's floor |
| **D2** | **Is narcolepsy named in-game?** | Store copy; the shape of N6's blind pass | **REPOSITORY FACT:** zero player-facing occurrences in `game/` or `distribution/`; `218afdf`'s content note says *"the diagnosis is not named by in-game text"*. N6's P1 pass is built to produce evidence on this |
| **D3** | **Sudden-onset review: now or deferred?** | G05-c; nothing else on the ten | Reviewing now means paying people to review a plan; deferring means the first sudden onset ships unseen by any reviewer. `218afdf` already rules it cannot be signed off until playable |
| **D4** | **Legal name and licence grant** | N10, and the third-party notice chain | `FRIENDS_BUILD_LICENSE_AND_THIRD_PARTY_AUDIT_2026-08-26.md` — the owner's own work has no declared licence. **No licence was chosen for you** |
| **D5** | **Release timing and channel** | N4 (friends tier), N10 (public tier) | Runbook recommends unlisted itch.io with revocable keys for the cohort and states that Valve's own documentation disqualifies Steam Playtest for it. **Whether Early Access is Steam, itch, or both is unruled** |

**Not owner decisions, and listed so they are not mistaken for any:** G26's
ruling is N2 and is on the path; the eleven beats and the content ceiling are
already ruled in the scope audit.

**One owner *action*, not a decision, and it currently blocks N7:** the shared
`BuildingRoot` file carries an unrelated uncommitted owner edit. `c1fcf4d`'s
integration gate says the measured shadow policy may only land *after* that edit
does, and **without absorbing it**. Nothing needs deciding — the edit needs
committing or reverting.

---

## 9. Pricing the 33-second boot into sequencing

**REPOSITORY FACT (G16, PROVED):** `production_ready` boots at **32.5–33.2 s**
against the capture protocol's 18 s target and 24 s hard warning. Eleven-frame
sheets finish at **42.6–44.4 s** with **9.6–11.4 s of margin** inside the 54 s
harness budget.

**What that arithmetic means for every verification run:**

| Consequence | Number |
| --- | --- |
| Fixed cost before frame one, on any production-root run | **~33 s** |
| Usable time inside the 54 s budget | **~21 s** |
| Practical ceiling per production-root sheet | **~11 frames** |
| Cost of splitting a 20-frame need into two runs | **a second full ~33 s boot** |

**Sequencing rules that follow. INFERENCE, but the arithmetic is not:**

1. **Run FOCUSED bench suites first.** They do not pay the production boot.
   Anything provable on a bench must not be proved on the production root.
2. **Batch every production-root check into as few boots as possible.** Two
   questions in one boot cost 33 s; in two boots they cost 66 s.
3. **Never design a sheet above eleven frames** without accepting a second boot
   and saying so in the receipt.
4. **N7 is the immediate worked example, and it is expensive.** G17's re-run is
   **thirteen stations, one process per camera** — thirteen separate production
   boots, roughly **33 s of boot each before a single frame is measured**, plus
   the frozen visual pairs. **INFERENCE:** budget the re-verification as a
   batch job, not as something squeezed between other work, and do not re-run
   all thirteen to check one station.
5. **N7 also changes this number.** A 64/5 shadow policy alters what the
   production root builds at boot — **re-measure the 33 s figure after N7 lands
   and before planning any capture campaign for N10's trailer.** The current
   number was measured at 64/16.
6. **The friends build is unaffected.** A tester's launch is not a harness run;
   this constraint prices *our* verification, not their experience.

---

## 10. The next two tasks, with non-overlapping paths

**RECOMMENDATION.** These can run at the same time and touch no common file.

### Next Codex task (Godot required) — N7

**Land the measured 64/5 shadow policy and re-verify all thirteen stations.**

Owned paths: `game/scripts/building/building_root.gd` (the one-number policy
only), `game/tests/perf_probe.gd`, `art/renders/perf_*/`,
`design/AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md`.

Why this one: the measurement is already done and it is the only remaining
pure-code item that blocks the public demo.

**Two conditions, both from the gate itself.** It cannot start until the owner's
unrelated uncommitted `BuildingRoot` edit lands, and when it does, **stage named
paths only** — the gate explicitly warns against absorbing that edit. **If the
edit has not landed, N7 is blocked and the next Codex task is N9's prep instead;
do not start N7 by working around a dirty shared file.**

### Next Claude task (Godot-free) — N3

**Reconcile the evidence matrix and the scope audit with what is already true.**

Owned paths: `design/EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md`,
`design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md`, and one new dated correction
note if the owner prefers additive over in-place.

Scope: C1's stale summary count, C2's fixed G03 defect, C4's human-task count,
and W1–W4's narrowed sudden-onset claims.

**No path overlap:** N7 touches `game/`, `tools/` and `art/renders/`; N3 touches
`design/` only.

---

## 11. DO NOW — exactly three

1. **N1 — Fund the review panel or defer it in writing.** It is the longest pole
   and every other precondition for it is now closed. **XS of owner time.**
2. **N3 — Reconcile the matrix.** Godot-free, blocks nothing, and prevents six
   testers hunting a fixed defect. **S.**
3. **N4 — Stand up the channel and issue build #1.** The single remaining
   blocker between here and the first human playing this game. **S.**

**INFERENCE: N2 is deliberately not here.** It is XS and genuinely blocking, but
it is a ruling about a resident's authored job — it belongs with N1's budget
decision in one sitting, not ahead of the cohort.

## 12. DO AFTER FIRST HUMAN — exactly three

1. **N9 — Fix what round one broke**, and *only* the blockers and comprehension
   defects. State how many polish notes were deferred.
2. **N8 — Verify G03, G04 and G06** with the cohort's remaining sessions.
   **G06 must use a first-time player** — the evidence is spent once they know
   the pocket.
3. **N10 — Build the store page**, with every claim mapped to a gate that is
   actually closed.

## 13. NOT BEFORE EARLY ACCESS

**Everything in §5.2, each with its named re-entry gate.** In one line: **the
second case, the Dream's other nine-tenths, every prop that is not one of the
route's five, House English, the fixture cards, the Vantry gateway, general
engine extraction, and every marketing experiment.**

**INFERENCE, and it is the point of this document:** the repository's problem has
not been a shortage of built things for some time. **Nine gates are code-green
and waiting for a person; one is waiting for a budget; one is waiting for a
sentence from the owner about a radiator job.** The next ten actions contain
**two** that require writing new game code.

---

## 14. Sources

**Repository, at `c1fcf4d`, whole-file or explicitly-cited-line reads:**
`EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md` (28 rows parsed;
G01 G03 G04 G05 G06 G16 G17 G18 G20 G23 G24 G25 G26 G27 sections) ·
`EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md:64` (CONTROLLER STATUS
banner) and `:204–206` (the contradicting G03 section) ·
`AUDIT_CURRENT_TREE_BASELINE_2026-08-26.md` (the thirteen-station 64/5 table and
its integration caveat) ·
`EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md` §2 §3 (`:95–130`) ·
`CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md` (M0–M8 headings; `:322`, `:478–488`) ·
`EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md` (`:52–90`, `:265`, §9) ·
`EARLY_ACCESS_GO_TO_MARKET_PROJECT.md` (76 lines) ·
`FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md` ·
`FIRST_HUMAN_PLAY_COHORT_OPERATIONS_2026-08-27.md` ·
`NARCOLEPSY_LIVED_EXPERIENCE_REVIEW_OPERATIONS_2026-08-27.md` ·
`NARCOLEPSY_DEPICTION_STATEMENT_AND_REVIEW_PACKET_2026-08-27.md:98` ·
`ORISON_MAZE_BRIEF.md:129` ·
**`distribution/README_TESTER.txt`** (full file, incl. the new CONTENT NOTE) ·
`tools/package_friends_build.ps1` · `TASKS.md:28–52`, `:105–110` (read-only) ·
`game/scripts/ui/maintenance_activity_panel.gd:108–170` ·
`game/scripts/game_boot.gd:20–60` · `game/tests/controller_input_test.gd` ·
`git rev-list --count 627eae5..c1fcf4d` = 122.

**No external sources were used.** This is an internal reconciliation; no
research question arose that the repository could not answer.

---

## 15. Limitations

- **Gate statuses are the matrix's, not independently re-derived.** I verified
  the three in §7 against source because they drive the ordering. **The other
  25 are taken as recorded** — and C1 and C2 are evidence that recorded statuses
  drift.
- **Effort bands are judgement, not measurement.** No task has been timed and no
  date appears anywhere in this document.
- **N4's cost assumption is flagged, not verified.** The runbook recommends a
  channel tier I did not confirm is free; N4 says to verify before committing.
- **G17 is no longer inferred — it is measured, and I have not re-measured it.**
  The thirteen-station 64/5 table is `c1fcf4d`'s evidence, taken as recorded.
  N7's effort band assumes integration is mechanical once the shared-file edit
  lands; **if the policy interacts with anything beyond `BuildingRoot`, that band
  is wrong.**
- **The two composition cameras stay over budget at 64/5** and the baseline says
  shadow rationing is not their fix. **Nothing in the ten actions addresses
  them**, because they are not gameplay evidence — but they will still look bad
  in a trailer frame, and N10 should not assume otherwise.
- **No test was run and no build was produced**, so every "DONE" in §3 means
  *code and its automated evidence exist*, never *a human confirmed it*. **That
  distinction is the entire subject of this document.**
- **The ten actions assume the eleven beats stand.** If D1–D5 change the scope,
  the ordering changes with it.
