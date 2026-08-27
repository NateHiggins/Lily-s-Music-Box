# Narcolepsy lived-experience review — operations

**Status:** PROCESS DESIGN. No one has been contacted. No money has been spent.
No account, form, booking or agreement exists. Nothing here implies that any
organization or person has seen this game, agreed to review it, or endorsed it.

**Base:** `77525c5eefa0f26177bfc36032d84838c7fc9546` (pushed `origin/main`),
which contains `5b2bf5a` — "Draft the narcolepsy depiction review packet".

**Origin drifted during this task**, from `66d62d3` (the tip named in the
assignment) through nine commits to `77525c5`. **None of them touched any file
this document cites** — the marketing plan, the depiction packet, the maze
brief, `dream_profiles.json`, `game_boot.gd`, `accessibility_copy.gd`,
`sleep_pressure_director.gd` and the scope audit are all byte-identical across
the drift, verified path by path. The branch was replayed onto the new tip so
the change applies cleanly.

**Companion, not replacement:**
`design/NARCOLEPSY_DEPICTION_STATEMENT_AND_REVIEW_PACKET_2026-08-27.md` holds
the statement, the language rules and the review questions. **That document was
not modified.** This one specifies how the review is actually run, paid for,
recorded and closed.

**Godot was not run.** No test, import, capture, export or asset tool was run.
No production file was modified. One new file.

> **Four labels used throughout**
> **REPOSITORY FACT** — verified in-tree at `77525c5`, with a path.
> **INFERENCE** — my reading, labelled as mine.
> **EXTERNAL SOURCE** — cited at the point of claim, with an as-of date.
> **OWNER RULING REQUIRED** — a decision I am not making.

**This document gives no medical advice and no legal advice.** It does not call
the portrayal accurate, sensitive, approved, certified or endorsed, and nothing
in it may be quoted as if it did.

---

## 1. Executive verdict

### 1.1 What review this game actually needs before outreach

**Not one review. Three separable things, in this order.**

1. **A copy review that has to happen before anyone external is contacted at
   all**, because the store copy currently drafted contradicts the depiction
   statement (§1.4, C1). Sending a reviewer a statement that says *the Tenant
   does not come from narcolepsy* while the store page says *your narcolepsy
   drags you into the dark* wastes their time and asks them to referee an
   internal disagreement we have not resolved.
2. **A lived-experience review of the playable material**, by people with
   narcolepsy, paid, with the worst read included rather than hidden.
3. **A separate clinical fact-check**, narrow in scope, about whether the
   game's *mechanical* depiction misstates the condition.

**These are not the same review and must not be run as one meeting.**

### 1.2 What review cannot prove

- **It cannot certify accuracy.** No individual and no organization can. A
  reviewer speaks to what they saw, from their own experience.
- **It cannot cover material that did not exist when they looked.** A review is
  evidence about a build, and the packet already says this.
- **It cannot transfer responsibility.** If the depiction harms someone, "we had
  a reviewer" is not a defence and must never be used as one.
- **It cannot make a disputed creative choice safe.** It can make it *informed*.
- **It cannot represent everyone with narcolepsy.** Symptoms vary; the packet
  and `ORISON_MAZE_BRIEF.md:144` both already say so.
- **Crucially, it cannot review what a player cannot reach.** **INFERENCE:** at
  least two of the packet's nine questions cannot be fully answered from the
  shipping slice — question 2 (whether onset reads as a cheap fainting mechanic)
  because the sudden form is unreachable (§2.4), and question 5 (whether "sleep
  attack" is acceptable in player-facing copy) because **no player-facing string
  uses that term, or any term, for it** (§2.1). Others are narrowed rather than
  blocked; I am not asserting a precise count.

### 1.3 Which roles must be separate

| Role | What they can speak to | What they must NOT be asked to do |
| --- | --- | --- |
| **Advocacy organization** | What they publish; where to look; whether an ask is appropriate | Review the game, vouch for it, or be named as involved |
| **Lived-experience reviewer** (paid individual) | Their own experience against what they saw | Speak for all people with narcolepsy; provide a quote for marketing |
| **Clinician** (paid, narrow scope) | Whether a mechanical claim misstates the condition | Judge whether the depiction is respectful — that is not a clinical question |
| **Sensitivity reader** (paid, craft role) | Language, framing, register, where the copy lands | Substitute for lived experience, or be the only disabled person consulted |
| **Community focus group** | Range and disagreement across several people | Vote a finding out of existence (§5.8) |

**None of these certifies accuracy, and two of them together do not either.**

### 1.4 The minimum ethical panel I recommend

**INFERENCE, and the whole document assumes it:**

- **Three paid lived-experience reviewers, engaged individually**, not one. One
  reviewer cannot show you variation, and variation is the thing the statement
  claims to respect. Three is the smallest number at which two can disagree and
  the disagreement is visible rather than decisive.
- **One paid clinician**, scope-limited to mechanical fact-check.
- **Zero unpaid reviewers.**
- **At least one reviewer who sees the sudden-onset material** (§2.4), because
  it is the sharpest version of the mechanic and the one most likely to read as
  a cheap fainting gag.

**OWNER RULING REQUIRED:** panel size and budget. If three is not affordable,
**the honest response is to review less material, not to pay fewer people
less.**

---

## 2. Audit — what a reviewer would actually be reviewing

Read before the packet was turned into a process. **Three findings change the
process itself.**

### 2.1 The game never says the word

**REPOSITORY FACT.** A search of `game/`, `art/` and `distribution/` for
`narcolep` or `cataplex` returns **zero matches** — no player-facing string, no
data record, no caption, no scene. The only occurrence anywhere in the tree
outside `design/` is a code comment:

```
game/scripts/game_boot.gd:87
    # Accessibility: later case profiles may allow a sudden sleep attack, but
    # this forces the same legible gradual warning Mina teaches first.
```

The nearest player-facing language is neutral and mechanical:

```
game/scripts/ui/accessibility_copy.gd:9   "ALWAYS USE GRADUAL SLEEP WARNING"
game/scripts/ui/accessibility_copy.gd:11  "Shows the gradual warning before every sleep onset."
```

**INFERENCE, and it reorganises the review:** the depiction claim does not live
in the build. It lives in the **store copy and the statement**. A reviewer who
only plays the game is reviewing an unnamed condition; a reviewer who only reads
the copy is reviewing a promise. **Both must be in the packet, in the same
session, or the review misses where the harm actually concentrates.**

### 2.2 The protective seams are real and worth showing

**REPOSITORY FACT.** `SleepPressureDirector` blocks onset for five stated
reasons (`sleep_pressure_director.gd:142–163`): `waking_world_unbound`,
`engaged`, `unstable_body`, `elevator_seam`, `traffic`. Its header states that
*"running, crouching, input and ordinary play never reduce pressure"* — the
condition is not a punishment for playing badly.

The accessibility contract is enforced in data, not by good intentions:

```gdscript
# sleep_pressure_director.gd:270–272
# Accessibility is a data contract, not a best effort. A future sudden-only
# profile would make Always warn lie, so the entire record is invalid.
if "gradual" not in onset.allowed_forms:
    return {}
```

**INFERENCE:** a profile that could make the "always warn" setting lie is
rejected outright. That is a strong, checkable design commitment and reviewers
should be told about it plainly — not as a defence, as a fact they can test.

### 2.3 The protective setting is off by default

**REPOSITORY FACT.** `game_boot.gd` ships `"always_warn_before_sleep": false`.

**INFERENCE:** defensible, since the shipping case is gradual-only anyway
(§2.4), but it becomes a live question the moment a sudden-capable case ships.
**This belongs in the reviewer's question set, not in a footnote.**

### 2.4 The sudden onset a reviewer needs to see is not in the shipping slice

**This is the finding that most changes the evidence packet.**

**REPOSITORY FACT.** `game/data/dream_profiles.json` holds **six** onset
profiles:

| Profile | Case | Allowed forms | Seconds |
| --- | --- | --- | --- |
| `mina_release_print` | `mina_caption_crisis` | **gradual only** | 2.6 |
| `peter_release_print` | `peter_form_corridor` | gradual, **sudden** | 2.2 / **0.65** |
| `juno_release_print` | `juno_feedback_tetris` | gradual, **sudden** | 2.4 / **0.70** |
| `mae_release_print` | `mae_contradictory_antiques` | gradual, **sudden** | 2.3 / **0.68** |
| `cal_release_print` | `cal_memory_radio` | gradual, **sudden** | 2.5 / **0.72** |
| `omar_release_print` | `omar_unrepairable` | gradual, **sudden** | 2.1 / **0.64** |

**REPOSITORY FACT.** `EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md:127` records
exactly **one** case enabled — Mina — with seventeen further records defined and
disabled. Mina's profile is gradual-only.

**Therefore: a reviewer who plays the Early Access build will never experience a
sudden sleep onset.** The five sudden profiles, at 0.64–0.72 seconds, belong to
cases a player cannot currently reach.

**INFERENCE — and this is exactly the trap the brief names.** The packet asks
for "a video of one gradual and one sudden onset." Producing the sudden clip
requires arming a disabled case. If we show it without saying so, the reviewer
believes they reviewed the game. If we omit it, we have hidden the worst read
behind a scope boundary and shown a curated highlight reel. **Neither is
acceptable.** §3.4 specifies the only honest handling: show it, label it
unreachable, and record the review as covering a *planned* mechanic.

### 2.5 CORRECTION — the store copy contradicts the statement

**This must be fixed before outreach, and it is not a matter of taste.**

The depiction statement says the Tenant *"does not come from narcolepsy"*.
`ORISON_MAZE_BRIEF.md:34` says the condition *"does not create the Tenant"*.
`ORISON_MAZE_BRIEF.md:1029` sets an explicit failure test:

> *"If they call it 'the narcolepsy monster,' representation has failed even if
> the chase is frightening."*

**REPOSITORY FACT.** `EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md`
drafts customer-facing copy that invites exactly that read:

| Line | Draft copy |
| --- | --- |
| `:61` (50-word pitch) | *"…before your **narcolepsy drags you into the dark**."* |
| `:71` (**store short description**) | *"Then your **narcolepsy takes you**, and the house is not the house any more."* |
| `:52` (tagline) | *"Survive the dark when your body takes you."* |

The same document, forty lines later, states the correct position:

> `:85` — *"Narcolepsy creates the vulnerable interval — it is not the monster,
> and the game does not say it is."*

**Being fair to the copy:** *"your narcolepsy takes you"* is, in isolation,
descriptive — the condition does cause the onset, and saying so is not
stigmatising. **The problem is the coupling.** In `:71` the clause is joined
directly to *"and the house is not the house any more"*, which places the
condition as the agent of the transformation. In `:61`, *"drags you into the
dark"* gives it agency and menace in five words. **The store short description
is the most-read sentence on a Steam page**, and it currently teaches the exact
sentence the maze brief calls a representation failure.

**INFERENCE:** the analysis in this project is right and the marketing copy has
not caught up with it. That is an ordinary drafting lag, not a values problem —
**but it blocks outreach**, because it is the first thing a reviewer would flag
and we already know about it.

---

## 3. Evidence packet specification

**Rule: the packet shows the worst read, not the best.** Every item is
identified by build and commit, and nothing is trimmed for flattery.

### 3.1 Identity block (mandatory on every artifact)

| Field | Value |
| --- | --- |
| `build_id` | exact packaged build identifier |
| `commit` | full 40-char SHA |
| `packet_version` | integer, incremented on any change |
| `date_prepared` | ISO date |
| `platform / settings state` | OS, resolution, and **every accessibility setting's value at capture** |

**A packet whose settings state is unrecorded is not reviewable**, because half
the questions are about whether the settings are sufficient.

### 3.2 Video artifacts

| # | Artifact | Requirement |
| --- | --- | --- |
| V1 | **One continuous first-shift-to-wake recording** | Unedited, uncut, single take, from shift start through onset, Dream pocket, and wake. **No cuts** — the pacing is part of what is being judged |
| V2 | **Gradual onset, isolated** | Mina's 2.6 s form, from the shipping case |
| V3 | **Sudden onset, isolated** | From a sudden-capable profile — **labelled per §3.4** |
| V4 | **Full Dream pocket and return** | Complete, including any capture/failure outcome, not only a clean run |
| V5 | **Settings surfaces** | Title and pause, every relevant control, shown being toggled |
| V6 | **The same onset with protections ON and OFF** | The A/B a reviewer needs to answer packet question 6 |

**Captions and audio must be intact.** A silent or caption-stripped video cannot
answer packet question 7.

### 3.3 Document artifacts

| # | Artifact |
| --- | --- |
| D1 | The current draft statement and store note, **verbatim and unedited** |
| D2 | **The store and trailer copy as currently drafted** — including the §2.5 lines. Do not send the corrected version only; if it has been corrected, send both and say which shipped |
| D3 | **Every player-facing line** touching sleep, onset, tiredness, naps, or the settings — with paths |
| D4 | A **plain mechanic map**: what causes onset, what blocks it, what the player loses, what they keep |
| D5 | **Known limitations and open questions** (§3.4, §3.5) |
| D6 | The language rules from the packet, so a reviewer can tell us where they are wrong |

**D4 in plain language, ready to send:**

> Sleep pressure builds over the shift. It is not increased by running, poor
> play or mistakes. When it is high enough and a case is ready, the game asks to
> begin a sleep onset. It will not do this while you are in a conversation or a
> call, while your footing is unstable, while you are in the lift, or near
> traffic. Onset takes about 2.6 seconds with a visible, audible warning. You
> then play a short dark sequence and wake up. **You keep your progress.** You
> may lose time, position and certainty about what happened.

### 3.4 Mandatory limitations disclosure

**Sent with the packet, not on request.**

1. **The sudden onset in V3 is not currently reachable by a player.** It belongs
   to a case that is disabled in this build. It is authored and intended to
   ship later. **You are reviewing a plan, not a shipped experience**, and the
   record will say so.
2. **The game never uses the word "narcolepsy."** The depiction is named only in
   the statement and store copy. If you think the game should name it, or should
   not, that is a finding we want.
3. **The gradual-warning setting is off by default.**
4. **One case ships.** The character's ordinary life is thin because there is
   one case, which is directly relevant to packet question 8.
5. **This slice does not depict cataplexy**, and the project has ruled it must
   not add that connection without separate informed review.

### 3.5 Questions we already know we cannot answer

Sent in the packet so reviewers do not have to discover them:

- Whether the *set* of symptoms shown is a reasonable selection, given that one
  case ships.
- Whether "sleep attack" is the right player-facing term — **note that no
  player-facing string currently uses it** (§2.1).
- Whether the sudden form's 0.64–0.72 s duration is defensible at all.

---

## 4. Reviewer brief — sendable draft

**DRAFT. NOT SENT. Not to be sent until §12's preconditions are met.**

> **Subject: Paid review request — depiction of narcolepsy in a horror game**
>
> Hello,
>
> I am making a first-person horror game called *Please Remain on the Line*. The
> player character is a night maintenance worker in a 1928 New York apartment
> building. The character has narcolepsy. Sleep onset interrupts the shift, and
> the game uses imagery from the boundary between sleep and waking as horror.
>
> **I am asking whether this depiction is defensible, and I am paying for your
> time to tell me it is not, if that is your answer.**
>
> **What I would send you**
> A build and recordings, including one continuous unedited run from shift start
> to waking; the sleep-onset sequences on their own; the full dream sequence and
> the return; the settings screens; every line of text in the game that touches
> sleep; the public statement I have drafted; and a plain description of the
> mechanics. I will also send you the store copy as currently written, including
> a line I already think is wrong, because I would rather you saw it than
> discovered it later.
>
> **What is still open**
> The public statement is unapproved. The store copy is unapproved. The text in
> the game, the sound and timing of the onset, the accessibility settings and
> their defaults, and how the dream is staged can all still change. A second
> case is not built, so what happens after this one is still open too.
>
> **What is fixed**
> The game is a horror game and the dream sequence is frightening. The character
> has narcolepsy and this is not a twist. **The supernatural threat is not caused
> by the condition** — if the game reads as though it is, that is a defect and I
> want to know exactly where it happens.
>
> **What I am not asking you for**
> I am not asking you to approve the game, to certify it as accurate, to speak
> for anyone else with narcolepsy, or to provide a quote for marketing. **I am
> not asking for your medical history and you should not send it.** You do not
> need to justify your experience to me.
>
> **No endorsement is implied by your involvement.** I will not name you, quote
> you, or say the game was reviewed by anyone, unless you give explicit written
> permission for each of those separately. You may decline all of them and still
> be paid in full.
>
> **Confidentiality** is not assumed. If you would prefer an agreement about not
> discussing the material before release, I am happy to agree one — but it is a
> separate conversation and it is not a condition of the work.
>
> **Payment** covers preparation time, the session, written follow-up, and a
> second look after changes. It is paid whether or not I act on your findings,
> and whether or not you finish, if the material is more distressing than
> expected. I would like you to tell me your rate.
>
> **Content note:** darkness, being pursued, involuntary loss of control, and
> frightening sleep-transition imagery.
>
> If this is not something you want to do, no explanation is needed.

---

## 5. Review protocol

### 5.1 Asynchronous access period — 10 days minimum

**Reviewers get the material for at least ten days before any live session.**

**INFERENCE:** the reason is specific to this subject. A person with narcolepsy
may need to view distressing material in short sessions across several days. A
same-day turnaround silently selects for people whose symptoms permit it, which
would bias the panel on exactly the axis the review exists to examine.

- No obligation to complete before the session.
- **No tracking of when or how long anyone engaged.**
- A named contact who can answer factual questions in writing.

### 5.2 Independent written notes before any group contact

**Mandatory and non-negotiable.** Each reviewer submits notes **before** hearing
any other reviewer. Notes are timestamped on receipt and stored unedited.

**INFERENCE:** the entire value of three reviewers is the variation between
them. A group discussion first collapses that into whoever speaks first.

### 5.3 Live session — 90 minutes, optional

Optional for every reviewer. A reviewer who submits written notes and attends
nothing is **paid identically**.

- Recorded **only** with explicit permission, asked at the start, revocable.
- One project person facilitating, one taking notes. **Not four staff and one
  reviewer.**
- Breaks whenever asked, no reason required.
- **The facilitator does not defend the game.** Explaining is fine; arguing is
  not.

### 5.4 Question order — fixed, and it matters

**Ordered so that the open questions come before the leading ones.**

1. What did you notice? *(unprompted — no framing at all)*
2. What was the worst moment for you, and what exactly caused it?
3. Did anything read as a joke at the character's expense?
4. Does the character seem like a person with a life, or a mechanic?
5. **Then, and only then:** the packet's nine questions in order.
6. Anything we did not ask that we should have?
7. What would you change first?

**INFERENCE:** the packet's question 1 — *"does the Tenant feel caused by
narcolepsy?"* — supplies the answer inside the question. Asking it first teaches
the reviewer our framing before we learn theirs. It stays, but it comes fifth.

### 5.5 Severity taxonomy

| Severity | Definition | Consequence |
| --- | --- | --- |
| **S1 — Harmful** | Would reasonably cause harm, humiliation or stigma to people with narcolepsy | **Blocks outreach and store copy.** Must be fixed |
| **S2 — Misleading** | Materially misstates the condition or its relationship to the fiction | **Blocks store copy.** Must be fixed or explicitly scoped |
| **S3 — Weakening** | Not harmful, but makes the depiction thinner or less credible | Should be fixed; may be scheduled |
| **S4 — Craft** | Register, wording, timing | Owner's discretion |
| **S5 — Intentional-choice challenge** | Reviewer disagrees with a deliberate fictional decision | §7.5. **Never silently downgraded** |

**A reviewer may propose a severity. Only the owner may lower one, in writing,
with a reason recorded in the ledger.**

### 5.6 Mandatory stop conditions

**Stop the session immediately, without discussion, if:**

- a reviewer asks to stop, or goes quiet after distressing material;
- a reviewer discloses health information we did not ask for **(§10.4)**;
- a reviewer appears to be experiencing symptoms;
- **any project participant begins defending rather than listening** — this one
  is on us, not them;
- a reviewer says they feel obliged to be positive.

**Stopping never reduces payment. Stopping is not a failed session.**

### 5.7 Revision ownership and re-review

- Findings are triaged by the owner within **10 working days**; every finding
  gets a written disposition, including rejections.
- **Re-review is triggered by:** any S1 or S2 disposition marked fixed; any
  change to the statement or store copy; enabling a sudden-onset case; any
  change to onset timing, warning, or the settings' defaults.
- **Re-review is paid separately** at the same rate.
- Reviewers see revisions **before** the statement is published (§12).

### 5.8 Disagreement — no majority vote

**If reviewers disagree, both positions are recorded and neither is erased.**

- Disagreement is **never** resolved by counting.
- A single S1 from one reviewer **is not overridden by two reviewers who did not
  see it**. It is investigated on its merits.
- Where a reviewer's minority position is not acted on, the ledger records the
  position, the reason, and that it was a minority view **without naming who
  held it**, unless they ask to be named.

**INFERENCE:** majority voting on a three-person panel would let two people
overrule the one person who was harmed. That inverts the point of the exercise.

---

## 6. Finding ledger schema

One durable record per finding. Proposed as
`design/narcolepsy_review_findings.json` — **not created here.**

```json
{
  "finding_id": "NR-0001",
  "packet_version": 1,
  "build_id": "",
  "commit": "",
  "observed_material": "V3 sudden onset clip, 00:00:04-00:00:06",
  "timestamp_or_range": "",
  "reviewer_role": "lived_experience",
  "reviewer_ref": "R2",
  "identity_protected": true,
  "description": "",
  "harm_mechanism": "",
  "severity": "S1",
  "severity_proposed_by": "reviewer",
  "severity_changed_by_owner": false,
  "severity_change_reason": "",
  "required_or_recommended": "required",
  "proposed_change": "",
  "owner": "copy | onset | audio | captions | settings | dream_staging | store | press_kit",
  "disposition": "open | accepted | scoped | declined",
  "disposition_reason": "",
  "evidence": "",
  "re_review_status": "not_required | pending | seen_by_reviewer | confirmed",
  "permission_to_quote": "none | internal_only | public_anonymous | public_attributed",
  "minority_position": false
}
```

**Rules that make the schema honest:**

- **`reviewer_ref` is a pseudonym by default** (`R1`, `R2`). Real identity lives
  only in the consent record (§10.2) and only where permission exists.
- **`permission_to_quote` defaults to `none`.** Absent an explicit value, the
  finding may not be quoted anywhere, including internally in a way that would
  identify the reviewer.
- **`declined` requires a `disposition_reason`.** A finding cannot be closed by
  going quiet.
- **`harm_mechanism` is mandatory for S1 and S2** — *what would happen to whom*,
  not just "this is bad". It is what makes a finding checkable after a fix.
- **A finding is never deleted.** Withdrawal by a reviewer (§10.5) sets the
  record to withdrawn and removes the content; the id remains so the count of
  what was raised stays honest.

---

## 7. Decision rules

### 7.1 What blocks outreach entirely

- **Any unresolved contradiction between the statement and the store copy.**
  **REPOSITORY FACT: this condition is currently met** — §2.5 — so **outreach is
  blocked today.**
- An evidence packet that cannot show the sudden onset, or shows it without the
  §3.4 disclosure.
- No compensation agreed (§8).
- No named person accountable for responding to findings.

### 7.2 What blocks store copy but not private testing

- Any open **S1** or **S2**.
- Any use of the condition as the grammatical agent of the horror (§2.5).
- Any claim of accuracy, sensitivity, approval or review-by-anyone that §12 does
  not license.
- Trailer beat `:265` ("Narcolepsy transition") shipping before review.

**Private playtesting with a content note may continue while these are open.**
Testers are not reviewers and their reactions are not review findings.

### 7.3 What requires a production change

- Onset timing, warning legibility, or audio that reviewers identify as reading
  like a faint or a gag.
- Settings defaults, if the panel finds the protections insufficient when off.
- Dream staging that makes the condition the source of the threat.
- Captions that misname what is happening.

### 7.4 What can be fixed in copy alone

- The store short description and 50-word pitch (§2.5).
- Tooltip and settings wording.
- The statement and the content note.
- Press-kit and tester-readme framing.

**INFERENCE:** the §2.5 problem is a copy fix. **That is good news and it is
also the trap** — it is cheap to fix, which is exactly why it should be fixed
before outreach rather than carried into the review as a question.

### 7.5 What may remain an intentional fictional choice after informed review

**A choice may stay only if all four hold:**

1. reviewers saw the actual material and understood it was deliberate;
2. their objection is recorded verbatim, at the severity **they** proposed;
3. the reason for keeping it is recorded and is not "it would be expensive";
4. **it is disclosed in the content note** — the player is told before they buy.

**A choice kept this way is never described as reviewed, accepted or endorsed.**
The honest phrasing is: *"reviewers raised this; we kept it; here is why."*

### 7.6 Who may close each class

| Class | Who may close |
| --- | --- |
| **S1** | Owner only, in writing, **after re-review confirms the fix** |
| **S2** | Owner only, in writing |
| **S3 / S4** | Owner, or the named category owner |
| **S5** | Owner only, under §7.5's four conditions |
| **Any finding, by withdrawal** | The reviewer, at any time, without reason |

**No finding is ever closed by a reviewer's silence** (§12).

---

## 8. Compensation and consent

### 8.1 The rate is UNKNOWN and must be quoted, not invented

**I could not find authoritative evidence of a market rate for narcolepsy
lived-experience review of a commercial video game.** No such figure is stated
here.

**Two anchors exist, and neither is that rate. Both are cited so the owner can
argue from evidence rather than from a number I made up.**

| Anchor | What it actually covers | Why it is not our rate |
| --- | --- | --- |
| **NIHR public-involvement payments (UK).** Reported range **£13.80 to £495** depending on activity, effective mid-December 2025, reviewed every three years. NIHR describes involvement payments as *not a wage* but a recognition of time, skills and expertise. — [NIHR payment guidance](https://www.nihr.ac.uk/about-us/who-we-are/policies-and-guidelines/payment-guidance-researchers-and-professionals); corroborated at [UCL Joint Research Office](https://www.ucl.ac.uk/joint-research-office/news/2025/dec/nihr-increases-payment-rates-public-involvement-research) (fetched 2026-08-27) | Publicly-funded **health and care research** involvement | We are a **commercial product**. A framework that explicitly calls itself not-a-wage is a poor basis for paying someone to improve a thing we intend to sell |
| **Sensitivity-reading rates.** Reynolds Journalism Institute (18 Dec 2023) reports an Editorial Freelance Association survey range of **"$31-$35/hr or one to two cents per word"**, and advises that for an experienced co-identifying professional you should *"expect to pay more than $100/hr"*, with uplifts for rush work, revisions and high-risk content. — [RJI](https://rjionline.org/news/contracting-and-paying-sensitivity-readers/) (fetched 2026-08-27) | **Editorial** sensitivity reading | Text review, not playing a horror game containing the reviewer's own condition |

**INFERENCE:** the RJI anchor is the closer of the two, and its *"more than
$100/hr"* guidance for experienced co-identifying professionals is the more
defensible floor for this work — but it is guidance about editorial work, and
**this is not that.**

**Recommendation: ask each reviewer their rate, pay it, and do not negotiate
downward.** If a reviewer has no rate, offer a written figure derived from the
RJI anchor and say how it was derived.

**OWNER RULING REQUIRED:** the budget. **Do not proceed on an unfunded panel.**

### 8.2 What is paid for

**All four, itemised in the agreement, whether or not each is used:**

| Component | Basis |
| --- | --- |
| **Preparation** — reviewing the packet asynchronously | Estimated hours, paid at the agreed rate, **not capped below the estimate** |
| **Session** | Full session length, paid if it ends early for any reason |
| **Written follow-up** | Paid separately |
| **Re-review** | Paid at the same rate, every time |

**Also:** accommodation costs (§8.3); a **kill fee of 100%** if we cancel inside
seven days; and **full payment if a reviewer stops** because the material is
more distressing than expected.

### 8.3 Accessibility and accommodation intake

Asked before the packet is sent, in writing, with "prefer not to say" available
on every item:

- preferred format for materials and for the session;
- session length and time of day that suits them, **including whether they need
  to avoid particular times**;
- breaks, captions, transcripts, screen-reader compatible documents;
- whether they would rather submit written notes and skip the session entirely;
- anything that would make this easier.

**We do not ask why any accommodation is needed.** Cost is ours.

### 8.4 Permissions — separate, explicit, revocable

**Six permissions, each asked separately, each defaulting to NO:**

| # | Permission | Default |
| --- | --- | --- |
| 1 | Use their **name** | NO |
| 2 | Name their **affiliation** | NO |
| 3 | **Quote** them internally | NO |
| 4 | **Quote** them publicly | NO |
| 5 | **Record** the session | NO |
| 6 | **Public credit** in the game or press kit | NO |

**A single "yes to everything" checkbox is not consent.** Permission 4 requires
the reviewer to see **the exact quotation in its exact context** before
publication.

**Revocable at any time, including after release, without reason.**

### 8.5 No testimonial fishing, and no exposure

**Prohibited outright:**

- asking a reviewer whether they "liked" the game;
- asking for a supportive quote at any point;
- asking a reviewer to post publicly about their involvement;
- offering credit, exposure, a copy of the game, or "supporting an indie
  developer" **in place of** payment;
- asking a reviewer to introduce us to other reviewers **for free**;
- treating a warm remark in a session as consent to quote it.

**A free copy of the game is a courtesy. It is not payment and must never be
described as part of one.**

---

## 8b. Outreach drafts — NONE SENT

**All four are drafts. Nothing has been sent, to anyone, at any time.** Draft 1
may not be sent until §7.1's blocks clear. Drafts 2–4 may not be sent until a
budget exists (§8.1).

### Draft 1 — routing inquiry to an advocacy organization

**Purpose: ask where to look. Not a review request.**

> **Subject: Where to find paid lived-experience consultants — narcolepsy in a video game**
>
> Hello,
>
> I am an independent developer making a horror game whose player character has
> narcolepsy. Before I publish anything that describes the depiction, I want it
> reviewed by people with narcolepsy, and I want to pay them properly.
>
> **I am not asking your organization to review the game or to endorse it**, and
> I would not describe you as involved. I read your published material and I can
> see that portrayal review is not something you offer.
>
> My question is narrower: **are you able to point me toward individual
> consultants with narcolepsy who take paid consulting work?** If you would
> rather not, that is an entirely reasonable answer and I will not follow up.
>
> If it is useful, I am happy to send the language rules I am working to, in
> case anything in them is wrong. No obligation to read them.
>
> I will not contact your support groups or helpline about this.

**Prohibited in this message:** asking for a quote, asking for endorsement,
asking for free review, asking for individuals' contact details, or implying a
prior relationship.

### Draft 2 — invitation to a paid lived-experience reviewer

**See §4.** That is the sendable brief.

### Draft 3 — clinician fact-check request

**Deliberately narrow. A clinician is not being asked whether the depiction is
respectful — that is not a clinical question.**

> **Subject: Paid narrow fact-check — sleep-disorder mechanics in a video game**
>
> Hello,
>
> I am making a horror game in which the player character has narcolepsy. I have
> a separate lived-experience review running; **this request is not that, and it
> is not a substitute for it.**
>
> **What I would like to pay you for is narrow:** whether the game's mechanical
> depiction states or implies anything about narcolepsy that is factually wrong.
> Specifically:
>
> 1. Sleep onset builds over a work shift and is not increased by exertion or by
>    the player performing badly. Is that a defensible depiction?
> 2. Onset is suppressed during conversations, unstable footing, lifts and
>    traffic. That is a game-safety decision. **Does it imply something untrue
>    about when sleep attacks occur?**
> 3. The game shows frightening imagery at the sleep/wake boundary. Is our
>    description of that as a sleep-transition experience, rather than as
>    psychosis or nightmare, correct?
> 4. The game does not depict cataplexy and does not link emotional intensity to
>    collapse. Is that omission itself misleading?
> 5. Our public statement is attached. **Does any sentence in it overstate what
>    is known, or read as medical advice?**
>
> **What I am not asking:** whether the game is respectful or well-made; for a
> diagnosis of a fictional character; for a quote; or for endorsement. I will not
> describe the game as clinically reviewed or approved.
>
> Please tell me your rate. I would rather be told the depiction is wrong than
> be told it is fine.

### Draft 4 — post-review confirmation note

**Sent to each reviewer after triage, before anything is published. This is the
message that makes §12.3 and §12.5 real.**

> **Subject: What changed after your review — and what I need to check with you**
>
> Hello,
>
> Thank you. Here is what happened to everything you raised — including the
> things I did not change.
>
> **Changed:** [list, each with what it now does]
> **Scoped for later, with a date:** [list, with reasons]
> **Not changed:** [list, each with the reason, at the severity you gave it]
>
> Where I kept something you objected to, I have recorded your objection at the
> severity you assigned, not a lower one, and it will appear in the game's
> content note so players know before they buy.
>
> **Two things I need from you, and "no" is a complete answer to both:**
>
> 1. **Do the changes actually address what you raised?** If they do not, they
>    are not finished. This re-look is paid at the same rate.
> 2. **Permissions.** As it stands I have you recorded as: [current answers].
>    Everything defaults to no. If you would like to change any of them, tell me;
>    if you would rather not reply, **nothing will be published and nothing will
>    be attributed to you** — silence means no, not yes.
>
> If you would prefer I delete your notes and the recording now, say so and I
> will, and your payment is unaffected.
>
> I am not going to describe the game as reviewed, accurate or approved. What I
> will say, if you are content with it, is that paid reviewers with narcolepsy
> looked at it and that specific things changed because of what they said.

---

## 9. Candidate routing table

**As-of 2026-08-27.** Fetched directly unless marked otherwise.

**The single most important row in this table is the pattern across all of
them:** *none of these organizations publishes an offer to review creative or
fictional portrayals.* Every "appropriate ask" below is therefore **routing
advice or signposting**, not review.

| Organization | Official URL | What the source actually says it offers | Appropriate ask | **Inappropriate inference** | Contact route | As-of |
| --- | --- | --- | --- | --- | --- | --- |
| **Narcolepsy Network** (US, member-led patient advocacy) | [narcolepsynetwork.org/about-us/media-kit/](https://narcolepsynetwork.org/about-us/media-kit/) | A media kit with organizational background and one explicit offer: media may contact them **to speak with a spokesperson**. No review, consulting, or creative-portrayal guidance is offered | Whether they can **signpost** appropriate paid lived-experience consultants; whether our language rules contain anything they would flag | That a spokesperson interview is a review, or that contact implies endorsement. **They are not a seal** — the packet already says this | Media inquiry email published on the media kit page | 2026-08-27, fetched |
| **Project Sleep** (US nonprofit) | [project-sleep.com/rising-voices/](https://project-sleep.com/rising-voices/) | **Rising Voices** trains people with narcolepsy and other sleep disorders in public speaking; trained speakers are described as available to give 20–35 minute presentations at events. Tuition is charged to participants | Whether they can point us toward trained speakers **who separately take paid consulting work** | **That Rising Voices is a review service.** It is a speaker-training program. Booking a speaker for an event is not a portrayal review, and an individual's participation is not the organization's endorsement | Published contact route on their site | 2026-08-27, **search-result summary only — project-sleep.com returned HTTP 403 to automated fetch; verify by hand** |
| **Wake Up Narcolepsy** (US nonprofit) | [wakeupnarcolepsy.org](https://www.wakeupnarcolepsy.org/) | Free online support groups, family weekend, Brown Bag webinars, a national summit, healthcare-professional resources, research funding and clinical-trial information. A "Media" section links to their YouTube channel | Whether they can signpost paid consultants. **Nothing else** | That support groups are a recruiting pool. **Do not approach a support group to solicit reviewers** — that is precisely the extractive pattern this document exists to avoid | General contact route on their site | 2026-08-27, fetched |
| **Narcolepsy UK** (UK charity) | [narcolepsy.org.uk](https://www.narcolepsy.org.uk/) | Telephone helpline and email support; school and employer education; resources for medical professionals, teachers and employers; campaigning on drug availability and DVLA matters; recruitment for their own research activity | Whether they can signpost consultants; whether their employer/education materials suggest workplace framings we have got wrong | **The helpline is for people who need support.** It is not a media channel and must not be used as one | Published general enquiry route — **not the helpline** | 2026-08-27, fetched |
| **NHS** (UK) | [nhs.uk/conditions/narcolepsy/](https://www.nhs.uk/conditions/narcolepsy/) | Public clinical information. Already cited in the packet and `ORISON_MAZE_BRIEF.md:153` | Factual baseline only | **A reference page is not a review, a consultation, or a clinician.** It cannot fact-check our specific mechanics | n/a — reference | 2026-08-27, previously cited in-tree |

**No personal contact details were collected, and none appear here.** Where a
route exists it is an organizational, publicly-published one.

**INFERENCE about sequencing:** approach at most **one** organization for
routing advice first, and do it **after** §2.5 is fixed. Approaching four at
once, before our own copy is consistent, would read as shopping for a name.

---

## 10. Privacy and records

### 10.1 Minimum data collected

**Only:** a name for payment, payment details, a contact address, accommodation
preferences, and the six permission answers.

**Never collected:** diagnosis, diagnosis date, medication, symptom history,
employment status, disability documentation.

### 10.2 Where things live

| Record | Location | Access |
| --- | --- | --- |
| Consent and permissions | Access-controlled, **separate from findings** | Owner only |
| Payment details | Owner's finance records | Owner only |
| Findings ledger | Project repository, **pseudonymous** | Project team |
| Recordings, if permitted | Encrypted, access-logged | Owner only |
| Build access | Time-limited link, **not a public URL** | Per reviewer |

**The link between `R2` and a real person exists in exactly one place.**

### 10.3 Retention and deletion

| Item | Retention |
| --- | --- |
| Session recordings | **Deleted within 30 days** of notes being written, or immediately on request |
| Raw notes containing identifying detail | Pseudonymised within 14 days |
| Pseudonymous findings ledger | Retained — it is the project's accountability record |
| Consent records | Retained while permissions are relied on; deleted on withdrawal |
| Payment records | As required for accounting, and no longer |
| Build access | Revoked at the end of the review period |

### 10.4 Unrequested health disclosures

**We did not ask, and reviewers may still tell us. Handle it as follows:**

- **Do not record it in the ledger.** Not in the description, not in the
  evidence field.
- If it is essential to why a finding matters, record the **finding**, not the
  disclosure: *"reviewer reports this maps to an experience they have had"* —
  never the experience.
- Do not repeat it to anyone, including elsewhere in the team.
- Do not use it to weight one reviewer's opinion above another's.
- **§5.6:** a disclosure is a stop condition. Pause, check they are alright,
  continue only if they want to.

### 10.5 Withdrawal

At any time, without reason, including after release: findings are marked
withdrawn and their content removed; permissions revert to NO; any published
quotation or credit is removed at the next possible update and immediately from
anything we control. **Payment is not clawed back.**

### 10.6 No public attribution by default

**The default public statement is that the game was reviewed by paid
lived-experience reviewers who have chosen not to be named.** That is the honest
sentence when permission 6 is not given — and it is a perfectly good sentence.

---

## 11. Production handback

**Recommendations only. No production file was touched. Ordered by what blocks
what.**

| # | Item | Category | Blocks |
| --- | --- | --- | --- |
| 1 | Rewrite the store short description so the condition is not the grammatical agent of the transformation (`:71`) | **store copy** | **outreach** |
| 2 | Rewrite the 50-word pitch's *"drags you into the dark"* (`:61`) | **store copy** | **outreach** |
| 3 | Review the tagline *"when your body takes you"* (`:52`) against the same rule | store copy | outreach |
| 4 | Reconcile marketing copy with `MAZE_BRIEF:1029`'s failure test and add that test to the copy checklist | store copy | outreach |
| 5 | Assemble the evidence packet to §3, including the §3.4 disclosure | press kit | review start |
| 6 | Decide the panel and budget (§1.4, §8.1) | — | review start |
| 7 | Decide whether `always_warn_before_sleep` should default true | settings | store copy |
| 8 | Decide whether the game should ever name the condition in-game (§2.1) | copy | store copy |
| 9 | Re-examine sudden-onset duration (0.64–0.72 s) before any sudden-capable case ships | onset presentation | second case |
| 10 | Confirm onset audio does not read as a faint or a gag | audio | store copy |
| 11 | Confirm captions name what is happening without medicalising it | captions | store copy |
| 12 | Confirm the Dream's staging never presents the condition as the threat's source | Dream staging | store copy |
| 13 | Add the content note to the tester readme before any external tester sees the build | tester readme | testing |
| 14 | Hold trailer beat `:265` until the review record is complete | press kit | trailer |
| 15 | Add the review record to the G25 gate evidence | — | G25 |

---

## 12. Stop rule

**The draft statement remains unapproved, and no outreach copy may lead with
narcolepsy or call the depiction accurate, until every one of these is true:**

1. **The named material was reviewed.** The record states the exact `build_id`
   and `commit`, and which artifacts each reviewer actually saw.
2. **Every required (S1/S2) finding is addressed** — fixed, or scoped under
   §7.5's four conditions with the objection recorded at the reviewer's own
   severity.
3. **Reviewers saw the revisions** and had the opportunity to say whether the
   fix worked. `re_review_status` is `seen_by_reviewer` or `confirmed`.
4. **Quotation and credit permission is explicit and current**, per §8.4, with
   any public quotation seen in context by the person quoted.
5. **No one's silence is treated as approval.** A reviewer who does not reply
   has not agreed. A finding left unanswered is not closed. An unreturned
   permission form is a **NO**.

**And two conditions specific to this project:**

6. **§2.5 is resolved before outreach begins**, not as a review finding.
7. **The review record states what was not reviewed** — at minimum, that the
   sudden onset was reviewed as a plan and not as shipped material (§2.4).

**A review is evidence about the material reviewed. It is not permanent
permission for later rewrites** — the packet's own words, and they govern here.

---

## 13. Corrections to prior project claims

**Stated plainly, not buried.**

**C1 — the store copy contradicts the depiction statement (§2.5).** The 50-word
pitch and store short description in
`EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md:61,71` make narcolepsy
the agent of the horror, which the statement, `MAZE_BRIEF:34` and
`MAZE_BRIEF:1029` all forbid. **This blocks outreach.** It is a copy fix.

**C2 — the packet asks for a sudden-onset clip the shipping build cannot
produce (§2.4).** Exactly one case is enabled and it is gradual-only. The five
sudden profiles belong to disabled cases. The packet's evidence list should be
read with §3.4's disclosure attached.

**C3 — the game never names the condition (§2.1).** Zero player-facing strings
in `game/`, `art/` or `distribution/` contain `narcolep` or `cataplex`. The
packet's question 5 asks whether *"sleep attack"* is acceptable in player-facing
copy; **no player-facing copy currently uses that term either.** The question is
still worth asking, but it is a question about copy we have not written yet.

**C4 — the marketing plan's assumption A4 is not a review finding.**
`:115` tracks *"the narcolepsy framing attracts rather than repels"* via devlog
sentiment. **INFERENCE:** that measures marketing performance, not whether the
depiction is harmful. It must not be cited as evidence for G25.

---

## 14. Sources

**In-tree at `77525c5`:**
`design/NARCOLEPSY_DEPICTION_STATEMENT_AND_REVIEW_PACKET_2026-08-27.md` ·
`design/EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md:52,61,71,85,115,265,348` ·
`design/EARLY_ACCESS_RELEASE_EVIDENCE_MATRIX_2026-08-26.md:143,400` (G25) ·
`design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md:127` ·
`design/ORISON_MAZE_BRIEF.md:34,142–154,1029` ·
`design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md:20,25,85,122,206,322,482` ·
`design/ORISON_OWNER_VOICE_STYLE_GUIDE.md:126,151` ·
`game/scripts/game_boot.gd:87` · `game/scripts/ui/accessibility_copy.gd:9,11` ·
`game/scripts/dream/sleep_pressure_director.gd:1–12,104–124,142–163,270–272` ·
`game/data/dream_profiles.json` (all 6 profiles parsed).

**External, all as-of 2026-08-27:**
[Narcolepsy Network media kit](https://narcolepsynetwork.org/about-us/media-kit/) (fetched) ·
[Project Sleep — Rising Voices](https://project-sleep.com/rising-voices/) (**403 to automated fetch; search-result summary only**) ·
[Wake Up Narcolepsy](https://www.wakeupnarcolepsy.org/) (fetched) ·
[Narcolepsy UK](https://www.narcolepsy.org.uk/) (fetched) ·
[NIHR payment guidance](https://www.nihr.ac.uk/about-us/who-we-are/policies-and-guidelines/payment-guidance-researchers-and-professionals) (**403 to automated fetch**), corroborated via
[UCL Joint Research Office](https://www.ucl.ac.uk/joint-research-office/news/2025/dec/nihr-increases-payment-rates-public-involvement-research) (fetched) ·
[RJI, "Contracting and paying sensitivity readers", 18 Dec 2023](https://rjionline.org/news/contracting-and-paying-sensitivity-readers/) (fetched) ·
[NHS narcolepsy](https://www.nhs.uk/conditions/narcolepsy/) (already cited in-tree).

---

## 15. Limitations

- **Two sources could not be read directly.** `project-sleep.com` and
  `nihr.ac.uk` both returned HTTP 403 to automated fetch on 2026-08-27. Claims
  from them are marked and must be verified by hand before being relied on. **In
  particular, the reported NIHR hourly figure of £27.50 appeared only in a
  search summary and is NOT verified here** — only the £13.80–£495 range is
  corroborated by a fetched source.
- **The £13.80–£495 range and the December 2025 effective date differ by two
  days between sources** (16 vs 18 December). Immaterial to this document;
  recorded so nobody treats either as checked.
- **No market rate for this specific work was found. §8.1 says UNKNOWN and
  recommends obtaining a quote.** No number was invented.
- **Reachability was established from source, not from running the game**, as
  required. The claim that a player cannot reach a sudden onset rests on one
  enabled case and Mina's gradual-only profile.
- **I did not audit art assets, audio files or scene-baked text** for
  sleep-related content. A caption or texture could name the condition where a
  string search would not find it.
- **Organizational offerings change.** Every row in §9 carries an as-of date for
  that reason.
- **I am not a person with narcolepsy, a clinician, or a lawyer.** Every
  judgment here is process design. **None of it substitutes for the review it
  describes**, and the finding that most needs a real reviewer — whether the
  depiction is defensible — is the one thing this document cannot answer.
