# The Orison editorial pass — 2026-10-22

Evidence class: **INERT**. An editorial ledger and report. It changes no
requirement status and proves no runtime behaviour.

*Developmental, line and continuity edit of every story and flavor text the
repository holds, against the Bible, the owner-voice style guide, the cast
voice map and the Lily Fern voice guide. Written by the editor for the owner
(Lily Fern, she/her). Facts are cited by path; judgments are labelled as the
editor's.*

---

## 1. Verdict in one paragraph

The authored text of this project is in better condition than the brief
expected. The Mina tree, the readable library and its sixty spreads, the
dead letters, the maintenance activities, the night-register and watch
copy, the mail, the hum notice and the V2 landing notices are finished
writing in one consistent moral physics with distinct mouths. This pass
therefore changed little and recorded a great deal. It made **eleven text
fixes** where canon, continuity, period or plain correctness required them
(section 4), rebuilt one legacy texture that carries baked text, and left
every strong line alone. The remaining work is not prose quality. It is
**eight canon decisions** only the owner can make (section 6), and one
structural fact: roughly half the authored flavor text is wired only to the
retired V1 building and is not reachable in the shipping V2 runtime
(section 3).

## 2. What the project actually is

- **Title.** At the start of this pass the covenant named the game
  *Please Remain On The Line* and a test pinned the title screen; the
  brief's *Please Stay on the Line* matched nothing in the tree. The owner
  ruled the rename on 2026-10-22 (D1, Bible §VIII.5.m). The building and
  the working name remain **the Orison**.
- **Period and place.** Saturday, 10 November 1928, a prewar block in
  Queens, New York, in a world where signal technology ran forty to sixty
  years ahead of everything else (Bible §VIII). The Rule of Signal is the
  period test for every object. Dates the player can read are 1928 and the
  station's own 1962–1999 catalogue; both are ruled.
- **Cast.** Eighteen residents, six with cases (Mina complete, Peter
  ordained second, then Juno, Cal, Omar, Mae), one Tenant who is the
  building, an androgynous night-maintenance player in 4B, and the desk
  callers who are "layers, not rivals" of the walking cases.
- **Two runtimes.** The shipping build is the V2 runtime
  (`game/scripts/building/orison_v2_runtime_root.gd`). The V1 building
  (`building_root.gd`) is a rollback behind an environment variable. Text
  wired only through V1 is authored, tracked and edited below, but a
  player on the current build does not meet it.

## 3. Coverage ledger

Status key: **LIVE** reachable in V2; **V1** reachable only in the retired
building; **UNWIRED** data no runtime reads; **DEBUG** behind the developer
overlay. Verdict key: **keep** finished and in voice; **fixed** edited this
pass; **flag** needs an owner decision (section 6).

### 3.1 Data files (`game/data/`)

| Source | Text type | Status | Verdict and notes |
|---|---|---|---|
| `case01_dialogue.json` | Mina's 34-node dialogue, player choices, 28 authored silences | LIVE | **keep.** Auditor PASS 34/34 reachable. The strongest writing in the tree. Node ids are voice-take names; untouched. |
| `maintenance_jobs.json` | Two work orders, stage objectives, summaries | LIVE | **keep.** "Find it by ear" protected. 002 closes "THE PATCH IS VISIBLE AND HOLDING." |
| `maintenance_activities.json` | Ten service activities: cues, confirmations, three-layer stories, sourced history | LIVE (cues, titles, completion notes shown) | **keep.** The best object writing in the game; the 1939 fuse-patent citation is the template for a correct post-1928 date. |
| `mail_catalog.json` | Welcome letter, hum notice, two parcels | LIVE | **fixed** (F1): welcome letter now signed "— Management", per Bible §IV and the web. Body kept. |
| `prop_service_wire.json` | 80 telegram fact cards and the surface matrix | LIVE | **fixed** (F4): the shop-sign card no longer names vinyl. All other cards kept; a few read as sourced trivia by design (telegram_style.md). |
| `shop_inventory.json` | One stocked part and its provenance | LIVE | **keep.** |
| `otis.json` | Lift floors, quirks, rider notes | LIVE | **keep.** "Six has to be asked for twice." |
| `house_telephones.json` | Documented telephone terms, endpoints | LIVE | **keep.** |
| `audio_cues.json` | 31 accessibility captions | LIVE | **keep.** Plain, physical, unfunny where required. |
| `orison_v2/domestic_furniture.json` (source `art/data/orison_v2/domestic_furniture_source.json`) | Five landing notices signed MANAGEMENT; one Estate seal | LIVE | **keep.** Hash-pinned by thirty Blender receipts; no edit attempted. "Coal in: 6 November 1928." |
| `orison_v2/diner_overhead.json`, `hardware_stock.json` | Menu board, night-service card | LIVE | **keep.** Prices plausible for a 1928 lunch counter. |
| `orison_v2/exterior/exterior_geometry.json` | Facade address lettering | LIVE | **flag** D7: "600 WEST 138TH STREET" is a Manhattan address in a Queens game. |
| `library.json` | 30 books, 8 shelf orders, 8 sorting schemes | LIVE (V2 readable library, WIP) and V1 | **keep.** Hash-pinned. Every book year at or before the 1928 cutoff (period audit PASS). Two books flagged D3. |
| `orison_v2/book_spreads.json` | 60 original passages, marginalia, plate captions | LIVE (WIP; integration blocked by input qualification) | **keep.** Hash-pinned; 20–90 words per body enforced by test. Finished writing. |
| `reality_cases.json` | 18 case records; only `portal_rule` is displayed | LIVE (Mina) / UNWIRED (17 disabled) | **keep.** Disabled cases stay as the record of what was considered (Bible §IV.1). |
| `reality_rules.json` | Transmission and residue notes | UNWIRED (fields unread) | **keep.** Design text. |
| `dream_profiles.json` | Three dream hazard captions, portal truths | LIVE (captions only) | **keep.** |
| `historical_radio_reallocation.json` | 11 November 1928 wireless notice | LIVE | **keep.** Sourced, period-correct, test-pinned. |
| `dead_letters.json` | 23 letters, clues, 'why' lines, four 'gone' notes | V1 | **fixed** (F8): Dorothy Ash's death moved from "eleven years ago" to "four years ago" so it agrees with the association minutes that stop in 1924. The rest kept; the pre-1928 tenancy it implies is D2. |
| `music_catalog.json` | Station legend, 36 track provenances, 18 anecdotes and gift lines | V1 | **fixed** (F9): Rhea's anecdote now agrees with the web and her schedule that take eighteen was the honest, flawed take. Seven post-1999 track years remain an open owner question (prior audit). |
| `resident_story_details.json` | 18 three-item biographies | V1 (field unread) | **keep.** A few modern nouns ("cassette", "takeout") are licensed by the Rule of Signal or unseen. |
| `apartment_life_profiles.json` | Dressing notes, contradictions | V1 design data | **keep.** |
| `resident_schedules.json` | 327 schedule details and labels | LIVE as behaviour, never as text | **keep.** Rich, in voice; dates after 1928 are the ruled "centuries of tenancy" (audit R1). |
| `domestic_radios.json` | Receiver profiles and reasons | LIVE (reasons unread) | **keep.** |
| `domestic_anomaly_props.json`, `domestic_witness_clocks.json` | Anomaly kinds and tells | V1 | **keep**; internal ids. D6 notes "smart speaker" and "security camera" exceed the 1967 signal ceiling in the design doc. |
| `trivia_darts.json` | 26 colour-quiz questions | UNWIRED | **flag** D5: British pub-quiz deck (ten-shilling note, pillar box) with 1959–1966 references, unreachable. |
| `house_english_lexicon.json` | 28 terms, house and plain | UNWIRED | **keep.** Best-prepared copy asset in the tree; "carrying" appears twice with two meanings (noted for the language owner). |
| `light_provenance.json` | 191 generated fixture cards | DEBUG | **keep off-screen.** Generated flavor, UNRULED, guarded by `field_semantics`. Not editorial text. |
| `lobby_notices.json`, `mailbank_cards.json`, `signage_plates.json` | Atlas indexes; text baked into PNGs | V1 | See 3.3. |
| `songbook/last_train_home.json` | Phrase prompts ("Where you were when you realised.") | LIVE (title only shown; prompts unread) | **keep.** |
| `found_art_catalog.json`, `hallway_art.json`, `character_*_art.json`, `stair_landing_art.json` | Placement of images; captions never shown | V1 | n/a. Lettering inside the landing art is dated 1930s–1962 (prior audit did not inspect art). |

### 3.2 Scripts carrying prose (`game/scripts/`)

| Source | Text type | Status | Verdict and notes |
|---|---|---|---|
| `call/case_library.gd` | Eight desk cases: callers, residents, console hints, outcomes | LIVE | **keep**; canon as shipped (Bible §V). Residents' modern vocabulary on the desk is D4. |
| `cases/mina_case_gameplay.gd` | Objectives, calibration feedback, two letter drafts, evidence cards | LIVE | **fixed** (F2, F3): "uncaptained" → "uncaptioned"; the letter's "Work order 002-A" → "Work order 001", the chirp order the player holds. |
| `cases/mina_caption_manifestation.gd` | Caption claims on 2A objects | LIVE | **keep.** |
| `cases/portal_rule_display.gd` | "ACCEPTED LOCAL EXCEPTIONS" board | LIVE | **keep.** |
| `game/service_round_director.gd` | Lena's three exchanges and player choices | LIVE | **fixed** (F6): one player choice that stated the theme now states the evidence. |
| `game/first_shift_director.gd` | Arrival and register instructions | LIVE | **keep.** Test-pinned; the shouted TOUR KEY and STATION 2 are deliberate. |
| `game/chirp_hunt.gd` | Stage prompts for the 2A point | LIVE | **keep.** Prompt literals are pinned by the carrier baseline. |
| `game/door_keyring.gd`, `props/key_copy_counter.gd` | Key permission copy | LIVE | **keep.** |
| `game/historical_radio_notice.gd` | Hand-copied wireless notice | LIVE | **keep.** |
| `reality/poltergeist_library.gd` | 18 ladders: whispers, voices, signatures, propagation hints | LIVE (whispers as world labels) | **fixed** (F5): Mina's caption of the player no longer assumes "he". The twelve case-less ladders are the haunting audit's open trim. |
| `reality/intrusions.gd` | Room captions, player captions, museum labels, word loss | LIVE | **fixed** (F5). |
| `ui/fourth_wall.gd` | Address-rung banners | LIVE | **keep.** Deliberately meta; the Bible's address rung. |
| `reality/organism_incidents.gd` | Seven residents' complaint notes | V1 | **keep.** Each in its mouth ("3B, Omar. There's something on the wall that works. I'd like it not to."). |
| `props/functional_prop.gd` | Fallback field slip for unregistered fittings | LIVE | **fixed** (F7): the slip now says it has no card on file instead of pretending to a record. |
| `props/night_register_prop.gd`, `watchman_clock_prop.gd`, `watch_register_prop.gd`, `watch_station_prop.gd`, `tour_key_guard_prop.gd` | Register, detector and station copy and prompts | LIVE | **keep.** Exemplary object copy: each card says what the record cannot know. |
| `props/fire_line_cabinet_prop.gd`, `soda_acid_extinguisher_prop.gd`, `fuse_panel_prop.gd`, `mail_chute_prop.gd`, `dumbwaiter_prop.gd`, `otis_prop.gd`, `elevator_interlock_prop.gd` | Apparatus cards and prompts | LIVE | **keep.** |
| `props/clock_prop.gd` | 4B clock work order | V1 | **fixed** (F10): renumbered 003; 002 belongs to Lena's round in the job library. |
| `props/possessed_domestic_prop.gd` | 16 inspection cards | V1 | **keep.** Test counts them. |
| `device/mechanical_teletype.gd`, `service_set_prop.gd` | Boot slip, device plates | LIVE | **keep.** "A hinge remembers its arc." |
| `ui/title_screen.gd`, `pause_services.gd`, `accessibility_copy.gd`, `game/reality_game_state.gd`, `game_boot.gd` | Menus, consent, save and failure copy | LIVE | **keep.** Plain where consent or loss is at stake; do not rewrite (prior census §12). |
| `ui/songbook_panel.gd`, `songbook/phonautogram_forge.gd` | Songbook machine copy, found-trace sleeves | LIVE | **keep.** |
| `ui/caretaker_notebook.gd`, `building/orison_v2_caretaking.gd`, `ui/maintenance_activity_panel.gd` | Care tests, rent, refusals | LIVE | **keep.** Rent instalments are D8. |
| `building/harukiya_interactables.gd` | Six look-point passages | LIVE | **keep.** "Everyone is looking at the door." |
| `building/broadcast_director.gd` | Television cards | V1 | **keep.** |
| `audio/music_director.gd` | Library panel, dedication copy | V1 | **keep.** |
| `building/maintenance_headquarters.gd`, `prop_catalog.json` shared props | "Ontological tape", "Elder-God Maintenance Tags", "SHAME, LOAD-BEARING" | V1 / UNWIRED | **flag** (minor): the earlier cosmic-joke register the Bible's tone has since left behind. Not edited because V1-only and unread. |
| `building/wayfinding_signage_pass.gd`, `building_entry_sign.gd`, V2 facade and cue scripts | Plates and signs | LIVE | **keep.** Six tasks of measurement stand behind the plates. |
| `phoneos/phone_os.gd` | 60 terminal lines | not instantiated | n/a; superseded fiction. |

### 3.3 Baked text (images built from authored strings)

| Source | Status | Verdict |
|---|---|---|
| `art/tools/build_lobby_notices.py` → `lobby_notices.png` | V1 | **fixed** (F11) and atlas rebuilt: the heat notice now teaches the one-pipe rule instead of telling tenants to bleed a steam radiator; the elevator notice now dates itself instead of narrating its own neglect. Other six kept, including the stale "Do not knock at 4B after 9 PM" (intentional, see section 7). |
| `art/tools/build_mailbank_cards.py`, `build_signage_plates.py` | V1 | **keep**; names and plate labels only. |
| `design/STAIR_LANDING_ART_PROMPTS.md` lettering | V1 | not text-editable; see D2. |

### 3.4 Design-side sketches reviewed

`design/ORISON_RELATIONSHIP_WEB.md` (tentative threads; fed the callers and
dead letters), `design/THE_TENANT.md` (speech deliberately withheld),
`design/DOMESTIC_WITNESSES.md`, `design/ORISON_ARCHETYPE_SCHEDULES.md`,
`design/HOUSE_ENGLISH_*.md`, `design/ORISON_FORTUNE_TELLER_BRIEF.md` (vignette
copy, not placed), `design/ORISON_AD_COPY.md` (marketing draft, 17 residents
by its own explanation), `audio_virus_prototype/docs/design/case_network_batch_01.md`
(NOT CANON by its header). None contains finished in-game text that the data
files lack. No sketch was promoted into the game.

## 4. Changes made (eleven text fixes, one asset rebuild)

| # | Path | Before | After | Why |
|---|---|---|---|---|
| F1 | `game/data/mail_catalog.json` | "— N. Quell, Management" | "— Management" | Bible §IV: Nadia "signs the player's welcome letter 'Management'"; web §II.2; wardrobe bible; her schedule: nothing she produces before midnight carries the name Quell. |
| F2 | `game/scripts/cases/mina_case_gameplay.gd` | "Leave silence uncaptained." | "Leave the silence uncaptioned." | Typo in a live objective; the case is about captions. |
| F3 | same | "RE: Work order 002-A" (both drafts) | "RE: Work order 001" | The chirp is WORK ORDER 001 in the job library the player holds; 002 is Lena's round. |
| F4 | `game/data/prop_service_wire.json` shop_sign | "PAINT METAL GLASS OR VINYL" | "PAINT METAL OR GLASS" | Vinyl signage postdates the 1928 cutoff the book itself declares; the research row (R028) names no material. |
| F5 | `game/scripts/reality/intrusions.gd`, `poltergeist_library.gd` | "[SUBJECT CHECKS BEHIND HIM AGAIN]", "...WHAT HE IS FEELING]" | "...BEHIND THEM AGAIN]", "...WHAT THEY ARE FEELING]" | The player is androgynous (Bible §I). Mina's clerical register survives; only the assumed pronoun goes. |
| F6 | `game/scripts/game/service_round_director.gd` | "The whole building proved this local fault." | "It took the whole building to prove one vent." | Player choices describe an intention or an actual line, never the theme (style guide §6). |
| F7 | `game/scripts/props/functional_prop.gd` | "MECHANISM ANSWERED TO HAND STOP CONDITION RECORDED STOP" | "NO CARD ON FILE FOR THIS FITTING STOP MECHANISM ANSWERED TO HAND STOP" | The fallback was flagged "coverage, not final flavor copy". An institution that admits the gap in its own file is the house register; a slip that claims a record it does not have is not. |
| F8 | `game/data/dead_letters.json` | Dorothy Ash died "eleven years ago" | "four years ago" | `library.json` and the readable spread give her minutes 1919–1924, "and then, abruptly, not." Two documents now agree. |
| F9 | `game/data/music_catalog.json` | "Take eighteen was perfect, so naturally I panicked and deleted it." | "Eighteen was the one where my voice broke and meant it, so naturally I panicked and deleted it." | Web §II.7 and Rhea's schedule: the deleted eighteenth take is the honest flaw that survives in Juno's archive. Nothing is revealed; the anecdote stops lying. |
| F10 | `game/scripts/props/clock_prop.gd` | "WORK ORDER 002 — WIND 4B" | "WORK ORDER 003 — WIND 4B" | Two orders carried the number 002; the job library's numbering is authoritative and the night register prints the number. |
| F11 | `art/tools/build_lobby_notices.py` and rebuilt `lobby_notices.png` | Heat: "Bleed your own radiator before reporting a cold line." Elevator: "This notice was posted in March and has not been taken down." | Heat: "The boiler is banked between 1 and 4 AM. A radiator that knocks or stays cold is to be reported in writing. Do not leave the supply valve part way: it is fully open or fully shut." Elevator: "Posted the 3rd of March. Remove when the car is returned to service." | One-pipe steam has automatic vents and a valve that is healthy only fully open or shut (Bible §VIII.5.c); a notice cannot narrate its own neglect, but a date and a removal instruction still pinned in November can. |

Representative before-and-after, with the reasoning in one line each:

> **Before:** "Use the calibrator once more. Leave silence uncaptained."
> **After:** "Use the calibrator once more. Leave the silence uncaptioned."
> The objective is the last instruction of the case; it had a typo in the one word the case is about.

> **Before:** "MECHANISM ANSWERED TO HAND STOP CONDITION RECORDED STOP"
> **After:** "NO CARD ON FILE FOR THIS FITTING STOP MECHANISM ANSWERED TO HAND STOP"
> The service wire is funniest and most honest when it records exactly what it has, including the gap.

> **Before:** "This notice was posted in March and has not been taken down."
> **After:** "Posted the 3rd of March. Remove when the car is returned to service."
> The old line was the author winking through the paper. The new one lets the paper be eight months late on its own.

## 5. What was deliberately not changed

- **Mina's 34 lines and 28 silences.** A mouth pass belongs to the case owner; the tree already passes the structural auditor and the voice checksum.
- **The desk cases** (`case_library.gd`): canon as shipped, by covenant.
- **Every hash-pinned file**: `library.json`, `book_spreads.json`, `domestic_furniture.json`, `trivia_darts.json`. Their text is finished; a byte change would invalidate thirty Blender receipts for no prose gain.
- **Every `[E]` prompt literal.** 186 are pinned by `tools/interaction_prompt_carrier_baseline.json`; they are ruled migration debt under RUL-013 and will be replaced by direct manipulation, not reworded.
- **Consent, privacy, save and accessibility copy.** Plain by design; the prior census marks it do-not-rewrite.
- **Title-screen footer** "EST. 1912 / PARTIALLY REOPENED 1928": both dates are ruled true and the building is indeed partly sealed.
- **"REALTY MAINTENANCE"** on the entrance plaque and the objective title, and "R. MAINTENANCE" on legacy notices: an in-world name, not a typo for the system.
- **The player's anecdotes and track provenances dated after 1928** in `music_catalog.json`: licensed by Bible §I and §III and recorded by the temporal audit (R1, R3).

## 6. Canon decisions isolated for the owner

Each is stated as the smallest decision that unblocks the dependent text.

- **D1 — Title. RULED 2026-10-22: *Please Stay on the Line*.** The owner
  ruled the rename after this pass reported the conflict. Applied in the
  same session: Bible line 7 and new §VIII.5.m, `project.godot`, both export
  preset fields, the title screen and its test, the project-identity test,
  the television hold card, `game/docs/title_screen.md`, README, HANDOFF, the
  tester readme, the environment ethos and the Astra governance documents.
  Dated historical reports keep the old title as history.
- **D2 — Traces of tenancy before 1928.** `dead_letters.json` (a tenant
  dead in 5D in 1924, a bank writing to a non-tenant "for a decade"),
  `library.json` ("Tenants' Association Minutes, 1919–1924") and the
  landing art imply the building had tenants during the sixteen dark years
  the Bible keeps silent. None explains anything; all of it deepens the
  silence. Decision: are undated or lightly dated *traces* of earlier
  occupants permitted under §VIII.5.h, as the found-document equivalent of
  "a resident may wonder aloud"? If no, the dead-letter 'gone' notes and the
  minutes need rewriting; if yes, record the licence beside §VIII.5.h.
- **D3 — Two books that predate the building.** *Concrete: Its Uses and
  Abuses* (1909) shows the Orison "as a plate, before the top two floors";
  the prospectus is 1912. Decision: keep as the disquieting object it is, or
  re-date to 1913. The editor recommends keeping it.
- **D4 — Modern vocabulary in resident mouths on the desk.** Sacha
  ("The comments are FROM the versions", "seeding"), Cam ("OUR toaster is
  from 1978"), Nadia ("automated order") speak from decades after 1928 in
  `case_library.gd`, which the Bible lists as canon as shipped. The callers
  are already from elsewhere in time. Decision: are the *residents'* desk
  lines also licensed by the purgatory reading, or should they be re-voiced
  to 1928 when the Case Network is next reviewed?
- **D5 — The darts deck.** `trivia_darts.json` is a British pub quiz
  (ten-shilling note, pillar box, London bus) with 1959–1966 answers, in a
  Queens bar, and nothing calls it. Decision: retire it, or rewrite it as a
  Queens deck when the board is wired.
- **D6 — Anomaly props past the signal ceiling.** `DOMESTIC_WITNESSES.md`
  caps signal witnesses at 1967, yet lists a "smart speaker" (2C, 4B) and a
  "security camera" (6A). The in-game cards already describe them as a
  Vantry diaphragm receiver and a Vantry camera mount, which is correct.
  Decision: amend the design doc's names to the cards' names.
- **D7 — The facade address.** `exterior_geometry.json` letters the front
  "600 WEST 138TH STREET". West 138th Street is in Manhattan; Queens numbers
  its streets without a compass prefix, and a 138th Street exists in
  Flushing and College Point. Decision: rule the address (for example
  "600 138TH STREET" or a named Queens avenue), then correct the two
  lettering records.
- **D8 — Rent.** The caretaker notebook collects five-dollar rent
  instalments from the player; Bible §I says the player "takes apartment 4B
  in exchange for working nights". Decision: is the instalment a token sum
  the fiction can carry (reduced rent for the night tenant), or should the
  notebook's copy call it something else?

## 7. Intentional anomalies retained

Recorded so nobody "corrects" them later.

- "Do not knock at 4B after 9 PM" on a legacy lobby notice: 4B is the
  player's flat; the notice predates them and belongs to the previous
  night tenant the web calls Mara Chen. Left as texture; it carries no motive.
- "ACCESSION 1927.4C.1" (Noel): the museum numbers by the year the flat was
  sealed, the year before the present.
- Jonah's witness clock reads "09:__"; it loses the end of its own time.
- The lobby master clock is permanently four minutes fast; the Handbook calls
  it authoritative (Bible §VIII.5.e).
- Resident memories of 1954, 1977 and 1999, and Cal's thirty-seven years of
  WORS, are ruled canon (temporal audit R1); never move them.
- Books in the Orison's library are "by" its residents. The building's
  library is written by its tenants; that is the purgatory speaking in a
  card catalogue, not an error.
- "REALTY MAINTENANCE" is the in-world name; "Reality Maintenance" is the
  system's.
- The fourth-wall banners ("Deleting ORISON APARTMENTS — do not turn off the
  system", "Your microphone has been open this entire time") are the
  Tenant's address rung and are meant to breach the frame.

## 8. Working glossary

Names and terms as the text uses them. Prefer these spellings.

| Term | Use |
|---|---|
| the Orison | the building; also the game's working name. Never "the Orison Apartments" except on the objective card "FIRST SHIFT — ORISON APARTMENTS" and the legacy sign. |
| *Please Stay on the Line* | the title (ruled 2026-10-22), rendered on three lines on the title screen; *Please Remain On The Line* is the retired title |
| Vantry, Vantry & Co. | the 1912 builders; "Vantry point" is the saucer-sized ceiling listener in every room; "Vantry service set" or "the carried set" is the player's radiophone; "service wire" and "field slip" are its printed paper |
| the Tenant | the one presence that is the building; "she" in `THE_TENANT.md`, "it" in the Bible; never given a form |
| Room 0 | "SHARED MECHANICAL / DEVOTIONAL / UNRESOLVED"; exists while the hum does |
| WORS 1610 | the laundry-room station, 1962–1999, transmitter never found |
| the motif | short, short, pause, long, missing; the fifth slot stays empty |
| Management | Nadia Quell's signature on every notice and the welcome letter; never "N. Quell" on anything produced before midnight |
| the Superintendent | by day, Omar Bell in 3B (V2 notices); the player is the night maintenance tenant, not the super |
| Realty Maintenance | the in-world firm on the plaque and legacy notices; "Reality Maintenance" is the design system's name and the acceptance board's heading |
| work order | numbered in `maintenance_jobs.json`: 001 THE CHIRP, 002 BORROWED BREATH; the legacy clock order is 003 |
| night register, watchman's detector, tour key, watch station | the lobby desk and its round; the tour key "opens no door" |
| the Passage, the Harukiya, the bodega, the Hardware Paint counter | the street shops; "bodega" is canon vocabulary |
| House English | the occupational cant (tenant-says, glass-says, square, cross, owing, heat-iron, work-paper); unreached by any production surface |
| the four seconds, State v. Price | Mina's blank; never rendered audible |
| release print, the embrace | the dream after a case closes, and how a passage ends |

## 9. Verification

- Every edited JSON file reparses. `tools/audit_period_dates.py` PASS;
  `tools/audit_authored_voice.py` on the Mina tree PASS (34/34, unchanged);
  `tools/audit_interaction_prompt_carriers.py` exit 0 (no `[E]` literal
  changed); the reader gate reports NEW 0 against its frozen baseline;
  `tools/lint_design_doc.py` reads this document as clean; the seventy
  tool tests guarding period dates, data consumption, prompt carriers and
  the lint pass under unittest.
- The lobby atlas was regenerated from its builder with the index
  unchanged (its JSON was restored after a line-ending-only diff).
- The gate board was run before the edits and again on the edited tree
  with `--baseline`. Verdict **REGRESSED (74)**, and the regression is the
  receipt discipline working as designed, not a defect in the text: the
  completeness ledger binds every runtime receipt to one digest over all of
  `game/scripts/**/*.gd` and `game/data/**/*.json`, and the surface
  qualification binds to the same inputs plus import parameters. Any edit
  to any script or data file expires every runtime receipt until the
  proving suites are re-executed source-current. The blocker counts moved
  0 / 1 / 56 / 26 / 73 / 75 to 7 / 8 / 110 / 42 / 134 / 136; 61
  requirements fell from RUNTIME_PROVEN to SPATIALLY_PROVEN or PROGRAMMED;
  `v2_surface_qualification` reports "rendering inputs changed"; two
  completeness live-repo tests fail for the same reason. Every static gate
  and every other tool test is unchanged. Re-earning the receipts needs the
  suites run from a short-path checkout (`tools/verify_candidate.py` is the
  management path) and is outside what this worktree can do.
- **Godot did not run here.** Two `--import` attempts through the lane
  runner crashed inside the engine (access violation, then heap
  corruption) while importing the Courier Prime fonts, before any scene
  could load. This worktree sits at the deep path the app created, which
  `AGENTS.md` warns breaks the import cache. The 436 generated `.uid`
  files and one rewritten `.import` were removed; none is committed. Every
  edit here is a string literal inside existing quotes, a comment, or a
  JSON value, so the suites that exercise the edited scripts
  (`ServiceWireResponseTest`, `MinaCaseGameplayTest`,
  `MaintenanceErrandTest`, `DeadLettersTest`, `MusicDirectorTest`,
  `ClockAnswersTest`) should be run from a short-path checkout before
  merge. This document claims no runtime proof.
- No voice-over exists to update (Mina is text on screen, pending casting);
  no localization resources exist. The recording script
  (`design/case01_recording_script.md`) is generated from the dialogue and
  the dialogue did not change.

- **Proof re-earned source-current (2026-10-23).** From the short-path
  worktree `C:/ov/edproof` on main `975da382` (which contains this pass,
  the title ruling and PR 13), two `--import` passes through the long
  runner, then: `MinaCaseGameplayTest`, `MaintenanceErrandTest`,
  `DeadLettersTest`, `MusicDirectorTest`, `ClockAnswersTest`,
  `ProjectIdentityTest`, `TitleScreenTest` and `GoldenLoopTest` all exit 0
  with wrapper receipts; `ServiceWireResponseTest` still hangs to the 180 s
  ceiling on its pre-existing `_counter_tap` read (a property removed on
  2026-08-27, known red since the 2026-09-16 evaluation), twelve checks in
  and before it reaches the edited sign-card text. The three contract
  suites were re-executed windowed and their original test-written
  receipts published: first slice (359 checks, 418 s), upper
  apartment/roof access cohort (993 checks, 69 rooms, 11 legs, 1,183 s;
  two earlier runs on the same tree failed different roof-leg physics
  checks and are retained as records, not repinned) and the composed
  surface qualification (40,134 checks, 995 s; the surface suite first
  stopped at its fixture preflight because PR 13 changed `door_prop.gd`
  without rebinding `orison_bodega_frontage.json`, so the owning Blender
  builder was re-run: asset bytes and the physical digest unchanged, only
  the binding renewed). Ledger blockers read 0 / 1 / 56 / 26 / 73 / 75
  again with zero requirement changes against the pre-edit ledger; the
  surface gate passes with zero defects. Run receipts, compressed logs,
  the archived previous packets and the board comparisons are under
  `art/reviews/v2_editorial_proof_20261022/`. The gate board verdict is
  recorded in that folder's `board_after/`.

## 10. Limitations stated plainly

- Text baked into art (landing posters, stair notices, the title) was read
  from its prompt files, not from pixels.
- `resident_schedules.json` was read as design text; it reaches the player
  only as behaviour.
- The Songbook has no canonical lyrics by design; nothing to edit.
- The desk cases were read in full and left as the covenant requires.
- This pass did not write Peter Wren's case. He is the ordained second case
  and has no dialogue; writing it would wire new content into progression,
  which the brief forbids, and the Bible reviews cases one at a time with the
  owner. *Later the same day the owner asked for dialogue drafts for every
  resident; those are in `design/ORISON_DIALOGUE_DRAFTS_2026-10-22.md` and
  `design/dialogue_drafts/`, as design-shape data read by nothing.*
