# Cast and case authority audit — 2026-08-26

**Status:** administrative data-authority audit answering ADMIN-CAST1. It makes
a question decidable; it does not decide it.

**Base:** `51ac904df49082eeffc210f42492bfea6a9e50d8`.
The assignment asked me to verify `origin/main` was `f9cbd03` **or report the
newer exact SHA**. It has advanced by one commit: `f9cbd03` "Make ambient
weather tell the truth" → **`51ac904` "ADMIN-GTM1: a build is not a release"**.
`51ac904` is my own ADMIN-GTM1 document, integrated by Codex. Branched from
`51ac904`.

**No Godot. No production code, JSON, test, scene, asset, `TASKS.md` or
existing design document was edited. Nothing was fixed, added, removed or
renamed. No case two was chosen. No external state was touched.**

---

## 1. Executive finding

**This is not data drift, milestone drift, terminology drift, or a quiet cast
change. The premise is false, and the false premise is mine.**
`game/data/reality_cases.json` contains **eighteen** case records — one for
every resident — not eight. **Peter Wren, Cal Dwyer and Mae Kessler all have
entries** (`peter_form_corridor`, `cal_memory_radio`,
`mae_contradictory_antiques`), each at the apartment `ORISON_BIBLE.md` §IV.1
assigns them. **Sacha, Evelyn and Teresa having entries is not an anomaly — it
is the ruling being obeyed**, because §IV.1 explicitly orders the twelve
case-less designs to *"stay in `reality_cases.json`, `enabled: false`, as the
record of what was considered"* (`design/ORISON_BIBLE.md:346`). Exactly one
record is `enabled: true`: Mina's. The apparent contradiction reported as
**C-4 in `design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md` was produced by a
diagnostic command of mine that printed `list(keys)[:8]` of an eighteen-key
dictionary and reported the truncation as the whole file.** That erroneous
finding is now on `main` inside ADMIN-EA1 §14 and was repeated in the K2-G and
ADMIN-EA1 handoffs; it should be retracted. **The audit did, however, surface
four real defects that the false one was standing in front of** (§5.3, §6.3),
and one genuine terminological ambiguity in what "M7 template" means (§7).

---

## 2. Authority hierarchy

| Rank | Source | Standing | Basis |
| --- | --- | --- | --- |
| **1. NORMATIVE — fiction and cast** | `design/ORISON_BIBLE.md` §IV.1 (`:289`) | **Prevails over everything** | Its own words: *"Where the case files, the prop briefs or any plan disagree with it, this prevails."* Ruled 2026-08-10 at owner direction. |
| **2. NORMATIVE — product sequence** | `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md` | Product direction and milestone definitions | Named by `ORISON_BIBLE.md` §V as the product authority. Defers to the Bible on fiction. |
| **3. NORMATIVE — release scope** | `design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md` | Release route only | Owner-commissioned via K0-EA. **Contains a known error at §14 C-4** (§1 above). |
| **4. DERIVED — runtime truth** | `game/data/reality_cases.json`, `resident_schedules.json`, `dream_profiles.json`, `game/scripts/dream/dream_incarnation_profile.gd` | Implements 1 and 2 | Agrees with the Bible on all eighteen units (§3). **A JSON entry is not a cast decision** — the Bible says so directly. |
| **5. DERIVED — status overlay** | `design/MILESTONE_RECONCILIATION_2026-08-26.md` | Reports status; alters no definition | Its own words: *"reports status only and does not alter the milestone definitions."* |
| **6. ASPIRATIONAL** | `design/SIX_INCARNATIONS.md`, `DREAM_ENCROACHMENT_BRIEF.md`, `DREAM_FAUNA_BRIEF.md`, `DREAM_TEMPORAL_BIOLOGY.md` | Presentation design; **no case-ownership authority** | `SIX_INCARNATIONS.md:3–6` self-demotes its reflected-world sections to *"archival design record only"*. |
| **7. STALE / SESSION-LOCAL** | `design/next_session_plan.md`, `design/next_session_dream.md` | Working notes | Repeat the ruling accurately (`next_session_plan.md:438` — *"Six cases only… Peter is second"*) but carry no authority. |
| **8. EVIDENCE, NOT AUTHORITY** | render sheets (`art/renders/dream_profile_n9/` etc.), test suites | Prove what they measured | Completed work is evidence. **A landed Peter presentation proof is not a licence for a Peter case.** |

**No source at rank 1–4 contradicts another on cast membership.** Every
disagreement found in this audit is at rank 4 and below, and is a defect rather
than a rival claim.

---

## 3. Complete cast-to-case matrix

Eighteen residents. Sources: `ORISON_BIBLE.md:289–307`;
`game/data/reality_cases.json`; `game/data/resident_schedules.json`
(18 records); `game/data/resident_story_details.json`
(`expected_residents: 18`); `game/data/dream_profiles.json`;
`game/scripts/dream/dream_incarnation_profile.gd:9–24`;
`game/data/maintenance_jobs.json`.

**Schedule unit and case unit agree for all eighteen residents — zero
mismatches.**

| resident_id | Display name | Apt | Ruled six | Sanctioned exp. | reality case id | enabled | Work order | Sched | Dialogue/call | Dream profile | Milestone role | Release route | Contradictions |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| `mina_vale` | Mina Vale | 2A | **● 1st** | — | `mina_caption_crisis` | **true** | `vantry_chirp_2a` | ✔ | `case01_dialogue.json`, 34 nodes | `mina_release_print` | M2–M6 | **IN — the whole route** | none |
| `peter_wren` | Peter Wren | 4A | **● 2nd (ordained)** | — | `peter_form_corridor` | false | — | ✔ | — | `peter_release_print` | **M7 template** | OUT | see §4 |
| `juno_kells` | Juno Kells | 2C | **●** | — | `juno_feedback_tetris` | false | — | ✔ | — | `juno_release_print` | M8 | OUT | none |
| `cal_dwyer` | Cal Dwyer | 5B | **●** | — | `cal_memory_radio` | false | — | ✔ | — | `cal_release_print` | M8 | OUT | none |
| `omar_bell` | Omar Bell | 3B | **●** | — | `omar_unrepairable` | false | — | ✔ | — | `omar_release_print` | M8 | OUT | none |
| `mae_kessler` | Mae Kessler | 6C | **●** | — | `mae_contradictory_antiques` | false | — | ✔ | — | `mae_release_print` | M8 | OUT | none |
| `rhea_sato` | Rhea Sato | 3D | — | **○ 1st** | `rhea_bad_karaoke` | false | — | ✔ | — | — | expansion | OUT | none |
| `nadia_quell` | Nadia Quell | 5A | — | **○ 2nd** | `nadia_code_pinball` | false | — | ✔ | — | — | expansion | OUT | none |
| `lena_ortiz` | Lena Ortiz | 2B | — | — | `lena_unraveling` | false | **`lena_radiator_round_2b`** | ✔ | — | *`lena_visible_patch` — does not exist* | none | OUT | **§5.3 D2, D3** |
| `evelyn_marsh` | Evelyn Marsh | 1A | — | — | `evelyn_paper_jam` | false | — | ✔ | — | — | none | OUT | none |
| `teresa_vale` | Teresa Vale | 1D | — | — | `teresa_call_bells` | false | — | ✔ | — | — | none | OUT | none |
| `sacha_reed` | Sacha Reed | 6A | — | — | `sacha_camera_delay` | false | — | ✔ | — | — | none | OUT | none |
| `malcolm_reed` | Malcolm Reed | 3A | — | — | `malcolm_memory_plants` | false | — | ✔ | — | — | none | OUT | none |
| `cam_ortiz` | Cam Ortiz | 4C | — | — | `cam_tilted_room` | false | — | ✔ | — | — | none | OUT | shares 4C — §3.1 |
| `noel_price` | Noel Price | 4C | — | — | `noel_domestic_museum` | false | — | ✔ | — | — | none | OUT | shares 4C — §3.1 |
| `iris_bell` | Iris Bell | 5C | — | — | `iris_runaway_paint` | false | — | ✔ | — | — | none | OUT | none |
| `jonah_price` | Jonah Price | 6B | — | — | `jonah_sentence_insects` | false | — | ✔ | — | — | none | OUT | none |
| `transient_guests` | Transient Guests | 4D | — | — | `transient_infinite_checkout` | false | — | ✔ | — | — | none | OUT | a group, not a person — §3.1 |

### 3.1 Two matrix observations that are *not* contradictions

- **Cam Ortiz and Noel Price both occupy 4C** in `reality_cases.json` **and** in
  `resident_schedules.json`. The two derived sources agree, so this is a
  consistent shared flat, not drift. **[Not verified:]** whether the Bible
  intends 4C as a two-person flat. Recorded, not resolved.
- **`transient_guests` is a group record**, so "eighteen residents" is
  seventeen named individuals plus one transient party. The Bible's
  *"eighteen"* language and `expected_residents: 18` both count it as one.

---

## 4. Peter evidence dossier

### 4.1 Claims that Peter *is* case two / the template

| # | Evidence | Location | Weight |
| --- | --- | --- | --- |
| P1 | *"4A ● **Peter Wren** — the ordained second (§I)"* | `ORISON_BIBLE.md:289` table | **Rank 1. Decisive on fiction.** |
| P2 | *"none of the other **four** shall be built before Peter meets Mina's bar"* | `ORISON_BIBLE.md` §IV.1 Consequences | Rank 1 |
| P3 | *"**M7 — Prove the template with Peter.** Peter is the ordained second case."* | `CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md:385,387` | **Rank 2. Decisive on sequence.** |
| P4 | *"six are case residents: Mina, Peter, Juno, Cal, Omar and Mae"* | `…EXECUTION_PLAN.md:47` | Rank 2 |
| P5 | `const IDS := ["mina", "peter", "juno", "mae", "cal", "omar"]` — **Peter is slot 2 in production code** | `game/scripts/dream/dream_incarnation_profile.gd:9` | Rank 4, strong corroboration |
| P6 | `CASE_IDS["peter"] = "peter_form_corridor"`; `PROFILE_IDS["peter"] = "peter_release_print"` | same file, `:12,:20` | Rank 4 |
| P7 | `peter_release_print` exists in `dream_profiles.json` — one of exactly six | `game/data/dream_profiles.json` | Rank 4 |
| P8 | `"peter_form_corridor": {"unit": "4A", "incarnation": "peter", "profile": "peter_release_print"}` and `PALETTE_INDEX{"mina…": 0, "peter_form_corridor": 1}` | `game/scripts/reality/apartment_encroachment.gd:96,136` | Rank 4 — **Peter is literally index 1 after Mina's 0** |
| P9 | *"then the other five in owner order (Peter, Juno, Mae, Cal, …)"* | `DREAM_ENCROACHMENT_BRIEF.md:139` | Rank 6, consistent |
| P10 | N9 shipped a Peter shared-profile production proof | `art/renders/dream_profile_n9/README.md` | **Evidence only** — see P-C3 |
| P11 | Peter has a case record at his ruled apartment | `reality_cases.json` → `peter_form_corridor`, unit 4A | Rank 4 |

### 4.2 Claims *against*, or that qualify, Peter as case two

| # | Evidence | Location | What it actually says |
| --- | --- | --- | --- |
| P-C1 | *"M7 — Peter template — **Not licensed yet**… Peter assets/content may exist, but the Mina definition of done is not met."* | `MILESTONE_RECONCILIATION_2026-08-26.md:37` | Not a challenge to identity — a **gate on starting**. |
| P-C2 | *"Do not start Peter because supporting assets happen to be ready."* | `MILESTONE_RECONCILIATION_2026-08-26.md:142` | Anticipates exactly the reasoning P5–P10 could invite. |
| P-C3 | *"All six downstream presentation profiles are now authored. **This empty gate does not manufacture or enable any waking case.**"* | `dream_incarnation_profile.gd:28–30` | The code **disclaims** the inference. The strongest single line in this dossier. |
| P-C4 | *"This does not enable Peter's waking case loop."* | `design/next_session_dream.md:473` | Same disclaimer, independently stated. |
| P-C5 | Peter has **no work order, no dialogue, no call material** | `maintenance_jobs.json`, `case01_dialogue.json` | He is designated, not authored. |
| P-C6 | `peter_form_corridor.enabled = false` | `reality_cases.json` | Consistent with P-C1; **but see D1 — the flag is inert.** |

### 4.3 Reading

**No source disputes that Peter is the ordained second case.** Ranks 1, 2 and 4
agree, in the same order, down to a palette index. Everything in §4.2 gates
*when work may start*, not *who it is*. **Peter's identity is settled; Peter's
authoring is not begun.** The only open question the evidence raises is
terminological (§7).

---

## 5. Orphan case dossier — Sacha, Evelyn, Teresa

### 5.1 They are not orphans

`ORISON_BIBLE.md:346` orders their presence:

> *"**Deleting the twelve case designs.** They stay in `reality_cases.json`,
> `enabled: false`, as the record of what was considered. Promotion needs a
> ruling; deletion needs a better reason than tidiness."*

| Resident | Apt | Case id | enabled | Bible theme (§IV.1) |
| --- | --- | --- | --- | --- |
| Sacha Reed | 6A | `sacha_camera_delay` | false | "The record displaced the thing" (with Mina, Mae) |
| Evelyn Marsh | 1A | `evelyn_paper_jam` | false | "Repair as evasion" (with Lena, Omar) |
| Teresa Vale | 1D | `teresa_call_bells` | false | "Rest reads as failure" (with Cam) |

Each is named in the Bible's own theme table as a **variant the ruling
deliberately cut** — the ruling's stated logic is *"the eighteen wounds are six
themes written eighteen times"*. Their records are the receipt for that
decision.

### 5.2 What consumes them

| Consumer | Consumes disabled cases? |
| --- | --- |
| `RealityCases` (`reality_case_manager.gd`) | Loads **all** definitions into `definitions`; `case_for_resident()` will return a disabled case id |
| `CoreLoopDirector` | **No** — pinned to `JOB_ID := ChirpHunt.JOB_ID` = `vantry_chirp_2a` (`core_loop_director.gd:33`) |
| `DreamIncarnationProfile` | **No** — only the six in `IDS` |
| `apartment_encroachment.gd` | Only cases with an encroachment record |
| `poltergeist_library.gd` | Has a `peter_form_corridor` entry |
| Marketing copy | **No.** Neither `EARLY_ACCESS_SCOPE_AUDIT` nor `…DISTRIBUTION_MARKETING_PLAN` names a second case, resident or case count. |

### 5.3 Real defects found here

| # | Defect | Evidence | Why it matters |
| --- | --- | --- | --- |
| **D1** | **The `enabled` flag is inert.** No file under `game/scripts` reads `"enabled"` from case definitions, and `activate_case()` (`reality_case_manager.gd:51`) checks only `definitions.has(case_id)`. | grep for `"enabled"` in `game/scripts` returns no case-definition reader | The Bible's containment mechanism for the twelve is **honoured by convention, not enforced by code**. `RealityCases.activate_case("peter_form_corridor")` would succeed today. Nothing currently calls it — this is a latent hazard, not a live bug. |
| **D2** | **A second authored work order exists for a resident outside the ruled six.** `lena_radiator_round_2b` ("WORK ORDER 002 — BORROWED BREATH") targets `lena_ortiz`, unit 2B, `case_id: lena_unraveling` — a case the Bible places outside the six and which is `enabled: false`. | `game/data/maintenance_jobs.json` | The only place in the tree where a **job** implies case ownership for a non-six resident. It is also the direct cause of the standing WalkTest failure (`walk_test.gd:1152` asserts exactly one authored job). |
| **D3** | **Dangling reference.** That job declares `dream_profile_id: "lena_visible_patch"`. The string appears **nowhere else in the repository**; `dream_profiles.json` contains only the six release prints. | `maintenance_jobs.json:55` | A job points at a profile that does not exist. |
| **D4** | ADMIN-EA1 §14 C-4 is factually wrong and is on `main`. | §1 above | It is the reason this task exists. |

---

## 6. Missing case dossier — Peter, Cal, Mae

### 6.1 Nothing is missing

| Resident | Case record | Apt in data | Apt in Bible | Dream profile |
| --- | --- | --- | --- | --- |
| Peter Wren | `peter_form_corridor` | 4A | 4A | `peter_release_print` ✔ |
| Cal Dwyer | `cal_memory_radio` | 5B | 5B | `cal_release_print` ✔ |
| Mae Kessler | `mae_contradictory_antiques` | 6C | 6C | `mae_release_print` ✔ |

All three exist, at the ruled apartment, with an authored dream profile.

### 6.2 Does anything expect records that are absent?

| Expectation | Satisfied? |
| --- | --- |
| `DreamIncarnationProfile.CASE_IDS` — six case ids | **Yes**, all six resolve |
| `PROFILE_IDS` — six release prints | **Yes**, all six in `dream_profiles.json` |
| `resident_story_details.expected_residents: 18` | **Yes**, 18 records |
| Bible: eighteen mailboxes, doors, schedules | **Yes**, 18 schedule records |
| A *playable* Peter/Cal/Mae case | **No — and nothing expects one.** No work order, dialogue, call material or director path exists, and two sources explicitly disclaim it (P-C3, P-C4). |

### 6.3 The genuinely absent thing

**Only Mina has a dialogue file.** `case01_dialogue.json` is
`case_id: mina_caption_crisis`, 34 nodes, voice prefix `mina_c01_`. There is no
`case02_dialogue.json` for anyone. **This — not the case records — is the
honest measure of how far a second case is from existing.**

---

## 7. The meaning of "M7 template"

The term carries **three distinct meanings** across sources, and this is the
one real terminological ambiguity the audit found.

| Source | What "template" means there | Type |
| --- | --- | --- |
| `EXECUTION_PLAN.md:385–393` | *"Build him by reusing the spine and changing content, repair mechanism, procurement verb, conversation pressure and dream grammar — **not by forking managers**."* Gate: Peter reaches Mina's quality bar, cases feel related but distinct, **no Mina-specific branch has leaked into shared code**. | **Authored playable case, whose purpose is to prove the implementation pattern.** Both at once. |
| `MILESTONE_RECONCILIATION_2026-08-26.md:37` | *"Peter assets/content may exist, but the Mina definition of done is not met."* | **Future milestone**, gated on M2–M6. |
| `dream_incarnation_profile.gd:28–30`, `next_session_dream.md:473` | Six presentation profiles authored; *"does not manufacture or enable any waking case"* | **Proof-only scaffold.** Presentation seam proved with Peter-salted data. |
| `art/renders/dream_profile_n9/README.md` | One real junction reversal in a Peter-salted pocket | **Proof-only scaffold**, evidence grade. |

**The ambiguity is live and consequential.** Under the execution plan, M7 is
not complete until a *playable Peter case* exists. Under the dream lane's
usage, "Peter's profile is proved" is already true. **Both statements are
correct in their own vocabulary, and they are two different completion
claims about the same name.** A reader moving between the two documents can
reasonably conclude M7 is much further along than the execution plan means.

**[Inference, flagged as mine:]** the execution plan's meaning is the one with
authority (rank 2), so M7 is not begun. But the vocabulary collision is the
mechanism by which "Peter assets are ready" could become "start Peter" — which
is precisely what `MILESTONE_RECONCILIATION:142` forbids.

---

## 8. Three owner-ruling options — stated neutrally, not ranked

### Option A — Peter remains the repeatability template and case two

*(This is the status quo. It requires no ruling; it is listed so the owner can
affirm it deliberately.)*

| | |
| --- | --- |
| **Files/milestones eventually affected** | None to change. Eventually: `maintenance_jobs.json` (a Peter job), a `case02_dialogue.json`, `reality_cases.json` (`peter_form_corridor.enabled → true`), M7 gate. |
| **Content preserved** | Everything. P5–P11 all remain correct without edit. |
| **Release promise impact** | **None.** Early Access is Mina-only either way. |
| **Minimum migration** | Zero today. |
| **Irreversible risks** | None from the ruling itself. The standing risk is **`MILESTONE_RECONCILIATION:142`** — affirming Peter may be read as licence to start him before M2–M6. |

### Option B — another existing case-bearing resident becomes case two

| | |
| --- | --- |
| **Files/milestones eventually affected** | `ORISON_BIBLE.md:289` §IV.1 table and its §I consequence sentence (**a rank-1 fiction amendment**); `EXECUTION_PLAN.md:47,385–393`; `dream_incarnation_profile.gd:9` `IDS` **order**; `apartment_encroachment.gd:136` `PALETTE_INDEX`; `DREAM_ENCROACHMENT_BRIEF.md:139` owner order; `next_session_plan.md:438`. |
| **Content preserved** | All eighteen case records; all six release prints; all schedules and apartments. If the replacement is inside the six, `dream_profiles.json` needs nothing. **If it is from outside the six** (e.g. Lena, who already has a work order — D2), a seventh release print and an incarnation slot would be needed, and §IV.1's "six themes" rationale is directly engaged. |
| **Release promise impact** | **None** for Early Access. Post-launch content ordering changes. |
| **Minimum migration** | Amend the Bible table; reorder `IDS`; re-check `PALETTE_INDEX`; update the two plan references. **N9's Peter proof stays valid as a seam proof** regardless. |
| **Irreversible risks** | Amending a rank-1 owner ruling. **[Inference:]** the §IV.1 rationale ties each of the six to a distinct theme, so a substitution is a *thematic* decision, not a scheduling one — swapping in a resident from an already-covered theme reduces range by the ruling's own logic. |

### Option C — M7 proves only the engine/template; case-two identity unassigned

| | |
| --- | --- |
| **Files/milestones eventually affected** | `EXECUTION_PLAN.md:385–393` (M7 rewritten to name no resident); `MILESTONE_RECONCILIATION:37`. The Bible could stand unamended — §IV.1 names Peter "the ordained second" as *fiction ordering*, which Option C need not contradict if M7 stops being a content milestone. |
| **Content preserved** | Everything. |
| **Release promise impact** | **None** for Early Access. **[Inference:]** it removes a stated post-launch commitment, which is the option most compatible with Valve's rule against specific promises about future content, cited in `EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md`. |
| **Minimum migration** | Rewrite M7's gate as pattern-proof criteria (no Mina-specific branch in shared code; a second case authorable without forking a manager) and move resident selection to a later ruling. |
| **Irreversible risks** | **[Inference:]** M7's current gate derives its force from being a *whole authored case*; a pattern-only gate can be satisfied by refactoring alone, which is a weaker proof that the campaign repeats. Also: it resolves the §7 ambiguity by adopting the weaker meaning, so "M7 done" would no longer mean a second case exists. |

**Common to all three:** Early Access stays Mina-only unless the owner changes
the release promise first; dream breadth stays preserved and outside the
release route; nothing in the marketing documents names a second case, so no
option requires a marketing retraction.

---

## 9. Proposed canonical authority table

Offered for approval. **Not applied anywhere.**

| Question | Canonical source | Everything else is |
| --- | --- | --- |
| Who carries a case, and how many | `ORISON_BIBLE.md` §IV.1 | derived |
| Which apartment a resident occupies | `ORISON_BIBLE.md` §IV.1, mirrored in `resident_schedules.json` | derived |
| Case-two identity | `ORISON_BIBLE.md` §IV.1 ("ordained second") + `EXECUTION_PLAN.md` M7 | derived |
| Whether a case is *playable* | `maintenance_jobs.json` + a dialogue file + a director path — **not** `reality_cases.json` | — |
| What `reality_cases.json` is | **The record of what was considered.** `enabled: true` marks the playable set. | — |
| Milestone completion | `EXECUTION_PLAN.md` gates | reconciliation reports status only |
| Release scope | `EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md` | — |
| Presentation profiles | `dream_profiles.json`, `dream_incarnation_profile.gd` | **prove presentation only; enable no case** |

---

## 10. Exact patch plans — none applied

### 10.1 Correction that is independent of A/B/C

**Retract ADMIN-EA1 §14 C-4.** It is wrong and it is on `main`.

```diff
 **C-4 — The ruled case six and the shipped case data disagree.**
-`TASKS.md:3132` §C … `game/data/reality_cases.json` ships eight ids: …
-**Peter, Cal and Mae — three of the ruled six — have no case entry. Sacha,
-Evelyn and Teresa have entries and are in neither the six nor the expansion.**
+**C-4 — RETRACTED 2026-08-26 by `design/CAST_CASE_AUTHORITY_AUDIT_2026-08-26.md`.**
+`reality_cases.json` contains EIGHTEEN records, one per resident, not eight.
+Peter, Cal and Mae all have entries at their ruled apartments. Sacha, Evelyn
+and Teresa having entries is `ORISON_BIBLE.md:346` being obeyed: the twelve
+case-less designs stay in the file, `enabled: false`, as the record of what
+was considered. The finding was produced by a diagnostic that printed the
+first eight keys of an eighteen-key dictionary. No cast contradiction exists.
```

### 10.2 Defect patches (independent of A/B/C; **each needs an owner ruling first**)

- **D1 — inert `enabled` flag.** Either make `RealityCases.activate_case()`
  refuse a `enabled: false` definition, **or** record in the Bible that the flag
  is documentation only. *Not a silent fix: it changes what the runtime permits.*
- **D2 — `lena_radiator_round_2b`.** Owner ruling required on whether a second
  authored job for a non-six resident is intended. If yes, `walk_test.gd:1152`'s
  single-job assertion is stale and should be updated. If no, the job is removed.
  **Either way one of the two standing WalkTest failures is resolved.**
- **D3 — `lena_visible_patch`.** Author the profile, or remove the key.

### 10.3 Option-specific plans

**A (affirm):** no file changes. Optionally add one line to §IV.1 recording the
affirmation date, and one line to M7 restating `MILESTONE_RECONCILIATION:142`.

**B (substitute):** amend `ORISON_BIBLE.md:289` table row and the §I/§IV.1
consequence sentence → reorder `dream_incarnation_profile.gd:9` `IDS` → re-check
`apartment_encroachment.gd:136` `PALETTE_INDEX` → update
`EXECUTION_PLAN.md:47,385–393` → update `DREAM_ENCROACHMENT_BRIEF.md:139` →
update `next_session_plan.md:438`. **Bible first; code last.**

**C (unassign):** rewrite `EXECUTION_PLAN.md:385–393` as pattern-proof criteria
naming no resident → update `MILESTONE_RECONCILIATION:37` → add a §7
disambiguation note wherever "template" is used. **The Bible need not change.**

---

## 11. Stop rules against quiet cast drift

1. **A JSON entry is never a cast decision.** Only `ORISON_BIBLE.md` §IV.1 adds,
   removes or reorders a case resident.
2. **`enabled: true` is a ruling, not an edit.** Flipping a case to enabled
   requires a dated owner ruling recorded in the Bible.
3. **A work order for a resident outside the ruled six requires a ruling
   first.** D2 is exactly this, unruled.
4. **Presentation proof never licenses a case.** Keep
   `dream_incarnation_profile.gd:28–30`'s disclaimer wherever profiles are
   authored.
5. **"Template" must be qualified at every use** — *pattern-proof* or
   *authored case* (§7).
6. **Cite the file before reporting a contradiction, and print the whole
   record.** D4 exists because a diagnostic truncated a dictionary and the
   truncation was reported as the file. **A `[:8]` is not a census.**
7. **Marketing names no second case.** Already true; keep it true regardless of
   which option is chosen.
8. **Absence of a work order is the measure of an unbuilt case; absence from
   `reality_cases.json` proves nothing** — nobody is absent from it.

---

## 12. Unknowns requiring owner decisions

| # | Question | Blocking what | Notes |
| --- | --- | --- | --- |
| **U1** | Affirm A, choose B, or adopt C? | Nothing today — Early Access is Mina-only under all three | The audit found **no evidence against A**. |
| **U2** | Is `lena_radiator_round_2b` intended? | One of the two standing WalkTest failures | D2. The only job implying case ownership outside the six. |
| **U3** | Should `enabled: false` be *enforced* or documented as inert? | D1 | Latent, not live. |
| **U4** | Author or delete `lena_visible_patch`? | D3 | Dangling reference. |
| **U5** | Which meaning of "M7 template" is canonical? | §7 | Independent of U1 — worth settling even under A. |
| **U6** | Is 4C intentionally a two-person flat (Cam + Noel)? | Nothing | Both derived sources agree; the Bible was not verified on this point. |
| **U7** | Does ADMIN-EA1 get a correction commit, or a note in this file only? | Accuracy of a landed document | My error; I did not amend ADMIN-EA1, per this task's constraints. |

---

## 13. Sources

Repository-only; no external research was required or performed.

| Path / key | Supports |
| --- | --- |
| `design/ORISON_BIBLE.md:289` §IV.1 | the ruled six; apartments; "prevails" clause |
| `design/ORISON_BIBLE.md:307` | Rhea Sato (3D), Nadia Quell (5A) as sanctioned expansion |
| `design/ORISON_BIBLE.md:342,346` | may not remove a resident; **the twelve stay in `reality_cases.json`, `enabled: false`** |
| `design/CLAUDE_LIVING_ORISON_EXECUTION_PLAN.md:47,385–393` | six case residents; M7 Peter; M7 gate wording |
| `design/MILESTONE_RECONCILIATION_2026-08-26.md:37,101,142` | M7 not licensed; Peter post-slice; do not start Peter on asset readiness |
| `design/EARLY_ACCESS_SCOPE_AUDIT_2026-08-26.md:§14 C-4` | the erroneous finding retracted here |
| `game/data/reality_cases.json` | **18 records**; `enabled=true` only for `mina_caption_crisis`; all resident_ids and units |
| `game/data/resident_schedules.json` | 18 residents; units agree with cases on all 18 |
| `game/data/resident_story_details.json` | `expected_residents: 18` |
| `game/data/dream_profiles.json` | exactly six release prints |
| `game/data/maintenance_jobs.json` (`:55`) | two jobs; `lena_radiator_round_2b`; `lena_visible_patch` |
| `game/data/case01_dialogue.json` | Mina only; 34 nodes; `mina_c01_` voice prefix |
| `game/scripts/dream/dream_incarnation_profile.gd:9,12,20,28–30` | `IDS` order; `CASE_IDS`; `PROFILE_IDS`; **the "enables no waking case" disclaimer** |
| `game/scripts/reality/apartment_encroachment.gd:96,136` | Peter 4A record; `PALETTE_INDEX` mina 0 / peter 1 |
| `game/scripts/game/reality_case_manager.gd:51` | `activate_case()` does not check `enabled` |
| `game/scripts/campaign/core_loop_director.gd:33` | the loop is pinned to `vantry_chirp_2a` |
| `game/tests/walk_test.gd:1152` | the single-authored-job assertion |
| `design/SIX_INCARNATIONS.md:3–9` | self-demotion to archival; owner-approved order, Cal fifth, Omar sixth |
| `design/DREAM_ENCROACHMENT_BRIEF.md:139` | owner order Peter, Juno, Mae, Cal … |
| `design/next_session_plan.md:438`, `next_session_dream.md:473` | "Peter is second"; "does not enable Peter's waking case loop" |
| `art/renders/dream_profile_n9/README.md` | N9 Peter shared-profile production proof |

---

## What this document does not do

- It does not choose case two, amend the Bible, enable a case, add or remove a
  record, rename anyone, or fix D1–D4.
- It does not harmonize contradictions; D1–D4 and the §7 ambiguity are reported
  as found.
- It does not treat completed work as authority: N9's Peter proof is listed as
  evidence and immediately qualified by the code comment that disclaims it.
- It does not change the release route. Early Access remains Mina-only under
  every option.
