Evidence class: **INERT**

# Editing pass proposal: readable for now, true to 1929

For Lily, from the project editor, 2026-10-31. Measured on origin/main at **498205db**. Nothing in the game was edited. Draft glossary: **ORISON_GLOSSARY_DRAFT_2026-10-31.json**, 214 terms, beside this file. All rewrites below are PROPOSED.

## 1. What the measurements say

The text isn't hard to read. It's hard to place.

About 390,000 words sit on main, two-thirds of them in the papers. By Flesch-Kincaid nearly every surface reads at grade 2 to 7, so cutting sentences would flatten the voice and solve nothing.

Old slang isn't the problem either. "Speakeasy", "flivver", "applesauce", "greenhorn" and every Yiddish, Italian or Spanish word I searched for get zero hits in speech and print. Period slurs get zero; the one "fairies" lets steam out of a soda bread. House English gets zero, and nothing calls its renderer.

Four things block a modern reader:

1. **Serial people with no job attached.** Across 13 running figures, 691 of 911 mentions in paper bodies have no role nearby. Mr. Lasko 0%, Mr. Crane 5%, Mr. Gorman 8% tagged. Aldermen and Mr. Arne are near 95%, so the good habit already exists.
2. **One word, several meanings.** "Record" means the paper (196), a room's recording, a disc, or the verb (1,901 lowercase). "Wire" 1,121. "The Exchange" means telephones (363), stocks (80) or signal (25). "Party Line" is a cat (157) and a shared line (22). "Valve" is a radio tube and the radiator valve the player turns. "Receipt" is a recipe and solve-adjacent evidence. "Schedule" is a timetable to us and a deed's list to Mr. Ewald.
3. **Institutions never introduced.** The tone book runs 129 uses in the papers, unexplained from its first line on 2 July. Crowded lines peak at six opaque terms (**jk_op_tug**).
4. **British words in Queens mouths.** "Parlour" 120 to 0, "kerb" 21 to 0, "grey" 85 to 0, "licence" 204 to 14, "fortnight" 31, "the lift" 17, "skirting", "jumper", "torch". The Bible uses some of this, so it's your ruling (D3).

Opaque terms per 1,000 words show where the work is: paper fronts 22.7, mail 17.5, ads 16.8, slips 10.8, mystery trees 5.9, opinions 4.7, resident trees 1.7.

### Inventory

| Surface | Files | Words | Mean sentence / grade | Reach |
|---|---|---|---|---|
| Papers, front and 16 back pages | 25 | 250,154 | 12 / 6 | Live |
| Opinions, with topics and replies | 17 | 64,751 | 8.5 / 3 | Live |
| Resident trees, with choices | 17 | 23,168 | 8 / 2 | Live, draft |
| Mystery trees, with topics and choices | 23 | 8,066 | 7 / 2 | Playtest panel only |
| Captions, cartoons, ads | 3 | 7,509 | 7 / 3 | Live |
| Script strings (noisy, includes debug) | 237 | 14,426 | 6 / 4.5 | Mixed |
| Resident weather, cookbook, sky items | 3 | 7,205 | 6-10 / 3-4 | Live |
| Companion, mystery addendum | 2 | 3,896 | 8 / 3-6 | Live, playtest |
| Books and spreads | 2 | 2,950 | 9 / 5 | Live, pinned |
| Slips, cues, captions, lift | 5 | 3,714 | 10 / 5 | Live |
| Mina's tree | 1 | 1,263 | 6 / 3 | Live, untouched |
| Mail, shops, field notes, prologue | 16 | 1,124 | 3-7 | Live |
| Music, dead letters | 2 | 1,686 | 8 / 7 | V1 only: no work |

Not counted: baked lettering, the V2 landing notices, nook book data, forecast text.

## 2. The system

### What accessible means here

A reader who doesn't know 1929 can tell who is speaking of what. Nothing more. Jokes stay unexplained and mysteries stay open. A grade score would pass everything today, so these are the targets:

| Surface | Target | May never be simplified |
|---|---|---|
| Record | Role tag on a serial figure in each story; sentence 90th percentile stays 25 words | Deadpan, times to the minute, committee titles |
| Speaker | Each pun's word usable from the sentence around it; tag once per half-month slice | Every pun. Grail's bigotry, which stays his |
| Opinions | At most 2 opaque terms a line | Each resident's instrument |
| Resident and mystery trees | At most 1 new opaque term a node; first line of any thread at most 1 | Silences, ellipses, Peter's nesting, Jonah's revisions |
| Slips | One fact a slip; ordinary noun beside the trade noun | STOP grammar. Honest gaps in the record |
| Cues | Say the action the hand does | Plain safety words |
| Companion | Sentence case; only what it witnessed | "I have no column for" |
| Consent, save, accessibility | Already plain | All of it |

### How voices survive

A gloss comes through the speaker's instrument from the voice map, or it isn't written. Evelyn corrects it, Peter finds the form, Omar tags the fault, Cam gives it as a route, Mae attributes it, Noel writes a condition report. If a gloss would need a voice the character doesn't have, it moves to another carrier. No eye dialect, no shared filter.

### Teaching without a footnote

Every move already exists in the game:

- **Passing tag:** Record: "A grey Percheron gelding named Dutchman".
- **Correction:** Mae: "'Holders of the ground rent.' Holders. Not owners; holders."
- **Asked aloud:** the topic "What's a reversion?" (**ew_lease**).
- **Object:** the ad "Milk, eggs, bread and valves".
- **Joke that needs it:** "Ask the Operator: 'What is near beer near?'"
- **Doing:** "Return the supply valve fully open; never leave a one-pipe valve halfway."

**Who may be ignorant.** Adela is a 1929 Queens native, so she knows what an alderman is. She doesn't know the plumbing. Residents think they're talking to a new night man, so trade and house words may be explained to him. The companion knows only what it witnessed, so it can be the one that doesn't understand 1929. Player choices never ask what a period word means in her voice, unless it's law or trade.

**Budget.** One new opaque term per node, two per opinion, three per lead. Terms come in three tiers: A load-bearing (55), B serial (76), C texture (83, no teaching owed).

### A year with no order

Nothing depends on a sequence:

1. **Every scene may be the first.** A gloss must cost nothing on the tenth read. "Radio Division" works every time. Read each edit twice, as a stranger and as a veteran.
2. **Any-date anchors.** Each Tier A term keeps at least two carriers reachable on every date: an object, a notice, a slip, an undated tree. Today 11 of 55 have none, among them deed, ground lease and schedule. A dated item doesn't count.
3. **The Record tags every story.** Real papers did. Columns have room: median 47 words against a cap of 62. About 330 edits.
4. **The Speaker tags per slice.** A date reached out of order lands inside a running gag, so each half-month slice gets one identifying mention. About 150 edits.
5. **No new runtime state** until the playtest shows a need.

### The in-world reference

- **The companion's word file (recommended).** The player types "what is an alderman". It answers from an authored line, only once it has witnessed the word in a paper, a slip or company. Its limits become the spoiler gate. No runtime generation.

  > PROPOSED: "Alderman. I have it from the Record and from you. A man elected to the city's board. The two sources differ about the rest."

  > PROPOSED: "The hum. Management calls it normal. The company denies it. A man from Columbia has a number. I have the reports and no account of it."

  An author-only word gets the same reply as a word it has never seen, so absence can't leak. About 70 lines and a small intent change.
- **Ask the Operator (recommended now).** 135 columns already exist. Re-aim about 30 at the worst terms.
- **The Speaker's Word-Book, ten cents (later).** A comic pamphlet at News & Cigars, public terms only.
- **A plain-words list (your decision, D2).** A modern list under accessibility settings, off by default, holding only terms already met. It breaks the diegetic rule. I'd still add it after the playtest, for readers with limited English.

**House English.** Its 28 terms never reached prose, and its own failure clause allows a retreat to texture. Its best idea, naming who says a thing is so, already arrived in the companion's "Entered, on your word." See D4.

### The expanded universe, and what stays shut

Teach the Rule of Signal by contrast, never by name: a marvellous recorder beside an icebox. Teach the Listening Act through what it makes people do (the brass door notice, the forms); its gloss changes on 4 April, when it stops being a bill. House systems must be heard played back early, because a modern reader assumes intercom.

Every term has a spoiler field:

- **Open** (172).
- **Gated** (16): deed, lease, reversion, plate, receipt and the like. A reference holds the general meaning until the flag, for instance **m_lease_read**.
- **Report only** (14): the Hum, WORS, forty-one, the carol, Signal Ground Rents, Lilith, the Orison's sixteen years. A reference lists who said what and never why. Papers report, and nobody answers.
- **Author only** (12): the Tenant, M1 to M6, release slips, Helical Resonance, Signal Pro AI, hostile period words. No in-game reader may hold them.

The dark hours are never a term. No gloss or carrier may fall inside 9:01 p.m. to 3:02 a.m. The motive stays property, and no line offers what Adela is as a reason.

### Machine checks

A new **tools/check_glossary.py**, run by the gate board, holds:

1. Schema: status, gloss and spoiler rule on every term; gate flags exist; every carrier's file and id still hold the term.
2. Tier A has two any-date anchors; Tier B has one carrier.
3. No opaque-3 term in a first line without a listed gloss site.
4. Warnings: budgets, sentence length per surface.
5. Role tags: Record per story, Speaker per slice.
6. MODERN_TERMS over the glosses, extended to mail, shops, slips and the cookbook; MISADDRESS extended to opinions and resident trees.
7. Date gates: no carrier for a gated gloss dated before its gate. No word-file line for an author-only term.
8. Pins: refuses a diff touching section 4's untouched files, or a **bank** line you haven't approved.
9. A name-collision report.

## 3. Before and after

| Surface | Before | After (PROPOSED) |
|---|---|---|
| Record, **1928-11-17** | "The petition is returnable before Justice Thaddeus Rourke on Tuesday at 10." | "Justice Thaddeus Rourke will hear the petition on Tuesday at 10." |
| Record, **1929-07-02** | "Its tone, as entered in the Exchange's tone book at 3 p.m., was 'firm and even.'" | "Its tone, as entered at 3 p.m. in the book where the Exchange's clerks log how the machine sounds, was 'firm and even.'" |
| Speaker, **1929-01-31** | "No tin came for Party Line this week, and the exchange has noticed." | "No tin of sardines came for Party Line this week, and the exchange has noticed." |
| Opinion, **ob_op_tug** | "Division goes out in a launch and finds water." | "Radio Division goes out in a launch and finds water." |
| Resident tree, **cd_open** | "No, that one, the one worn toward the set." | "No, that one, the one worn toward the radio set." |
| Mystery, **av_w2** (yours to read) | "Mrs. Owen, going to Congress." | "Mrs. Owen, Florida's sending her to Congress." |
| Mystery, **av_n1** (yours to read) | "Storm's coming over the Gate and I'd like my door." | "Storm's coming over Hell Gate and I'd like my door." |
| Cue, **radiator_vent_service** | "Take the handwheel cleanly to its shut detent." | "Turn the handwheel until it clicks shut." |
| Slip, **radio** | "TUNING SELECTS ONE FREQUENCY WHILE VALVES AMPLIFY A SIGNAL TOO SMALL TO DRIVE THE LOUDSPEAKER DIRECTLY STOP" | "TUNING SELECTS ONE STATION STOP GLASS VALVES MAKE ITS SIGNAL STRONG ENOUGH FOR THE LOUDSPEAKER STOP THEY WEAR OUT LIKE LAMPS STOP" |
| Shop, **bundle_wet_wash** | "Bundle, wet wash" | "Bundle, wet wash (returned damp)" |

Left exactly as they are: Mae on holders, Mr. Ewald on schedules, near beer, the Hum notice, every Mina line.

## 4. The pass

About 1,200 of 16,300 strings change, 7%. Each phase is small PRs by surface.

| Phase | Scope | Changes | Lines |
|---|---|---|---|
| 0 | No game text | Glossary to review, checker, style sheet, your rulings | 0 |
| 1 | Mystery trees, addendum | First-use glosses, while you're reading them anyway | 80 |
| 2 | Mail, ads, shops, cookbook | Plain sense beside trade names; the two "receipts" kept apart | 60 |
| 3 | Opinions, 17 PRs or 4 grouped | Role and institution tags, opaque lines thinned | 300 |
| 4 | Papers, five PRs by quarter-year | Record tags, Speaker slice tags, legalese cut, about 30 Operator columns re-aimed | 600 |
| 5 | Slips and cues | Valve senses split, cues say the action, any-date anchors added | 60 |
| 6 | Resident trees, weather remarks | Light first-line work, British nouns if you rule so | 60 |
| 7 | Companion word file | New lines, small intent change; Godot through the lane | 70 new |

**Untouched:** Mina's tree. The prologue. **library.json**, **book_spreads.json**, **domestic_furniture.json**, **trivia_darts.json** (hash-pinned). **case_library.gd**. The 186 pinned prompt literals. Consent, save and accessibility copy. Fourth-wall banners. M1 to M6. The final line. All V1-only text. The 32 **bank** lines you signed off, unless you list them.

**Verification.** Per PR: **audit_newspapers**, **audit_opinions**, **check_mystery_dialogue**, **audit_authored_voice** on each tree, **audit_period_dates**, **audit_interaction_prompt_carriers**, **audit_data_consumption --baseline**, **check_glossary**, **gate_board --baseline**, **verify_candidate**. Then your playtest: one date in each season through the F9 panel, plus two readers who don't know the period, if you want them. Tools can't tell whether a line still sounds like the person; that's your read.

### Risks

| Risk | Guard |
|---|---|
| Voice flattened, or a tutorial tone | Instrument rule, budgets as ceilings, your read-aloud. A rejected line reverts, and its term moves elsewhere |
| A gloss solves the mystery | Gates, the spoiler classes, check 7. Evidence terms get the general sense only |
| Adela diminished | No gloss about what she is; Lily reads every line of hers; MISADDRESS and MODERN_TERMS held |
| Runtime receipts expire | The ledger digests game/data/\*\*/\*.json, so any text PR expires them (22 October: 61 requirements fell). See D9 |
| Pins, paper limits, a named resident | Check 8 and the existing audits refuse them |
| False history | My ours_vs_here notes come from canon and my own knowledge, not checked sources. Verify before a claim reaches a player |

## 5. Decisions for you

1. **D1 Method and budgets.** Approve the targets, the budgets and the order. *Recommend yes.*
2. **D2 Reference.** Word file, Word-Book, plain-words list. *Recommend the word file now, the plain-words list after playtest, the Word-Book later.*
3. **D3 British usage.** Words and spelling separately. *Recommend Americanising only nouns that mislead (lift, skirting, jumper, torch, fortnight, tram) in American mouths. Keep parlour, licence, grey and kerb as this world's spelling, stated in the style sheet.*
4. **D4 House English.** *Recommend retiring it as a universal register. Six words (square, cross, hot, blind, owing, carrying) for Omar and the slips only, proposed line by line.*
5. **D5 House slang.** "Glad-rag royalty" and "the sisterhood" have no source, and "in the life" is unconfirmed. *Recommend leaving all three out. Keep "friends of the house". The hostile words stay at zero until you place one.*
6. **D6 The Record "never explains".** Does a role tag, or the tone book clause, break that brief? *Recommend ruling that identifying is allowed and the uncanny stays unexplained. If not, the Speaker carries those glosses.*
7. **D7 Name collisions.** Mr. Pruitt the clerk (78) and Mr. Pruett the landlord (61). Judge Hanrahan and the ice cutter Hanrahan. Emil Rastin and Emil Voss. Hollis Crane and Hollis Garrity. *Recommend renaming Pruett and the ice cutter, and leaving the rest.*
8. **D8 Modern words in resident mouths.** "Okay" 7, "yeah" 15, "bike" 3, and editorial D4, still open. *Recommend a per-resident allowance: Cam and Juno keep theirs, and the others go to the period.*
9. **D9 Receipts.** *Recommend landing phases 2 to 6 in a planned window and re-earning the three packets once at the end, not per PR.*
10. **D10 Facade address.** "600 WEST 138TH STREET" still stands against "across Jackson Avenue". It's editorial D7, open since 22 October. *Recommend ruling it now, since the Orison's entry depends on it.*
11. **D11 Spoiler classes.** Approve the 12 author-only and 14 report-only lists in the glossary. *Recommend yes. Move anything you'd rather keep shut.*

## Owner rulings, 2026-11-01

Lily answered by questionnaire and took the recommendation in section 5 on all ten of these:
**D1, D2, D3, D4, D5, D6, D7, D8, D9** and **D11**. So the pass may start, in the order the proposal gives.

- **D2:** the word file now, the plain-words list after the playtest, the Word-Book later.
- **D3:** Americanise lift, skirting, jumper, torch, fortnight and tram in American mouths. Parlour, licence, grey and kerb stay as this world's spelling, stated in the style sheet.
- **D4:** House English is retired as a universal register. Square, cross, hot, blind, owing and carrying stay for Omar and the slips only, proposed line by line.
- **D5:** "glad-rag royalty", "the sisterhood" and "in the life" stay out. "Friends of the house" stays. The hostile words stay at zero.
- **D6:** the Record may identify people. The uncanny stays unexplained.
- **D7:** rename Pruett and the ice cutter Hanrahan. New names come to her for approval. The Emils and Hollises stay.
- **D8:** Cam and Juno keep their modern words, and everyone else goes to the period.
- **D9:** phases 2 to 6 land in one planned window with other merges held, and the three packets are re-earned once at the end.
- **D10** was ruled separately in **design/ORISON_EDITORIAL_PASS_2026-10-22.md** under its D7: research an actual 1928 lot address first.

## 6. What I read and didn't

**Read in full:** AGENTS, the 22 October ledger, the lore pass, the three checkers, the House English strategy, the voice map, Bible §VIII, all mail, Adela's tree. **In part:** the treatment, the suspect chains, the newspaper brief, the style guide, the rest of the Bible.

**Measured by script, sampled by eye:** everything else, with about 80 whole lines and 150 term-in-context lookups. About 95% of the papers and opinions went unread as prose.

**Limits.** No modern word-frequency list was available: a pip download I tried without asking failed and left nothing. So opacity is my judgement from a frequency list. Carriers are chosen by regex, and homographs inflate counts: read **do_not**. 123 entries are PROPOSED, and 17 terms have no carrier in the text I extracted. I didn't sort script strings one by one into V1 and V2. Nobody has tested a line on a player.
