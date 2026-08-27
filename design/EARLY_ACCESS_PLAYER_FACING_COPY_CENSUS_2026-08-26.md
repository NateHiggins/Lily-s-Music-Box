# Early Access player-facing copy census — 2026-08-26

**Purpose:** what a player can actually read on the Early Access route, who is
speaking, which register governs it, whether it is canonical or scaffolding, and
where revising it would endanger consent, safety, accessibility, controls or an
irreversible consequence.

**Base:** `735ff1b0d2f80bb4fb0ccb5c3fb6cf79ea9e1381` (pushed `origin/main`, "Put
third-party notices in every friends package"). Preconditions verified present:
`ORISON_OWNER_VOICE_STYLE_GUIDE.md`, `ORISON_CAST_VOICE_MAP.md`,
`tools/audit_authored_voice.py`, ADMIN-PROV1, and `0a55185` as an ancestor.

**Origin drifted mid-task.** The brief named `0a55185`; while auditing, Codex
pushed `d31d803`, `81c0856` and `735ff1b`. This document was re-verified against
the new tip rather than shipped stale. One of those commits changed a
player-facing data file and is carried below (family 24, §10b).

**Godot was not run.** No production text, JSON, scene, script, existing design
document, localization resource or test was modified.

> ### P0 IMPLEMENTATION UPDATE — 2026-08-27
>
> Both P0 families identified here are now resolved in production. RealityState
> publishes structured, plain-language read/write incompatibility notices and
> an autoloaded UI presents them even when boot ordering would otherwise miss
> the signal. The notice names the consequence, preserves the newer file, and
> offers update/new-campaign remedies; dismissal does not release the write
> latch. The three microphone status lines now describe cancellation, latency
> compensation, local saving and zero upload without a wit move. Focused proofs:
> `RealitySaveCompatTest` PASS 14/14 and `SongbookMicConsentTest` PASS 8/8.

> ### Mina is text-only and unvoiced
>
> The 34 former `mina_c01_*.ogg` files were **temporary text-to-voice samples**,
> found unhelpful and ordered discarded; they were removed in `0a55185` and
> **zero voice files are tracked today** (verified: `git ls-files
> game/assets/audio/voice` returns nothing). They are **not** recordings,
> performances, subtitle coverage or shipped assets, and nothing in this census
> treats them as such. Mina's case is **text on screen, pending production
> casting.**

> ### Four things kept apart throughout
>
> **STRING EXISTS** — the literal is in the repository.
> **REACHABLE** — a player on the Early Access route can read it.
> **INFERENCE** — my reading, labelled as mine.
> **OWNER RULING** — a decision I am not making.

---

## 1. Executive verdict

**The route's copy is in better shape than its ownership record.** The
consent surfaces landed recently and are plain, accurate and unclever — that
work is done well. The problems are at three seams:

1. **RESOLVED:** two safety-adjacent strings carried a wit move where plain
   language was required. All three microphone status lines are now plain.
2. **RESOLVED:** the most irreversible path in the game had no player-facing copy.
   A save written by a newer build, loaded after a rollback, is refused via
   `push_warning()` — which goes to the engine log. **The player is told
   nothing.** (§4)
3. **House English is not reachable.** The lexicon carries a `plain` gloss on
   all 23 terms and `HouseEnglish` exposes a `"plain"` mode — and **no
   production file calls it.** There is no comprehension gap because there is no
   House English on screen yet. (§7)

A fourth seam surfaced on re-verification against the new tip: **a large body
of authored prose has no player surface.** 191 light-fixture cards are reachable
only through the F1 debug overlay, and House English is reachable from nowhere
at all (§7, §7b). That is not a defect — it is unbanked authored value, and it
is the cheapest content in the repository to surface.

**25 copy families** are counted. **164 distinct `[E]` interaction prompts
exist, 38 of them runtime-composed format strings** that cannot receive a mouth
pass in their current shape (§8).

---

## 2. Audit method

Repository-only. `tools/audit_authored_voice.py` was run on the Mina tree — it
is a Python structural auditor, not Godot — and its output is treated as
**advisory evidence for a human pass, never as literary judgment**, which is
what the tool itself says it is for.

```
grep -rlE '\.text = "|interact_prompt|return "\[E\]' game/scripts --include=*.gd
grep -rhoE 'return "\[E\][^"]*"' game/scripts --include=*.gd | sort -u
python3 -c "json.load(...)"                    # whole records, never truncated
python3 tools/audit_authored_voice.py game/data/case01_dialogue.json
git ls-files game/assets/audio/voice           # → empty, per 0a55185
```

**Auditor result, Mina tree:** `PASS (structure only; human mouth pass still
required)` — 34 nodes, all reachable; 937 spoken words; 290 choice words; mean
sentence 6.5 words; **authored silence on 28 of 34 nodes**; one advisory notice
(§10).

---

## 3. Copy family census

Register names are from the owner-voice guide §6, which separates **resident
dialogue**, **player choices**, and **object and maintenance copy**.

| # | Family | Path(s) | Construction | Surface / EA reachable | Speaker / owner | Register | Mouth | Status | Comprehension dep. | L10n ready | Sensitivity | Wit allowance | Action | Priority | Authorizing owner |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Title screen menu** | `ui/title_screen.gd` | literals | title, **yes** | the house | object copy | none | canonical | low | **no** — inline | low | restrained | keep | — | UI owner |
| 2 | **Settings labels** | `ui/title_screen.gd`, `ui/pause_services.gd` | literals | both, **yes** | the house | object copy | none | canonical | **high** | no | **accessibility** | **none** | keep | — | UI owner |
| 3 | **Consent tooltips — weather** | `title_screen.gd:267–278` | literals | title, **yes** | the house | object copy | none | **canonical, strong** | **high** | no | **privacy P0-class** | **none** | **DO NOT REWRITE** (§12) | — | privacy owner |
| 4 | **Consent tooltips — accessibility** | `pause_services.gd:140–147`, `title_screen.gd:250–260` | literals | both, **yes** | the house | object copy | none | canonical | **high** | no | **accessibility** | **none** | keep | — | accessibility owner |
| 5 | **Microphone consent panel** | `songbook_panel.gd:252–261` | literals | Songbook, **off-route** | the house | object copy | none | **canonical, strong** | **high** | no | **consent** | **none** | **DO NOT REWRITE** | — | privacy owner |
| 6 | **Microphone status lines** | `songbook_panel.gd:295,312,418` | literals + `%d`/`%0.1f` | Songbook, off-route | ambiguous | drifts to resident wit | none | **UNCERTAIN** | **high** | no | **consent** | **none allowed; wit present** | **REWRITE — §11** | **P0** | privacy owner |
| 7 | **Save / rollback refusal** | `game/reality_game_state.gd:108,113,136` | `push_warning()` | **ENGINE LOG ONLY — not player-facing** | nobody | — | — | **ABSENT** | **critical** | n/a | **irreversible consequence** | none | **AUTHOR NEW COPY — §11** | **P0** | save owner |
| 8 | **Work-order objectives** | `game/data/maintenance_jobs.json` `stage_objectives` | data literals | HUD card, **yes** | WorkOrders | object copy | none | canonical | **critical** | **yes — data** | none | restrained | keep | — | WorkOrders |
| 9 | **Mina case dialogue** | `game/data/case01_dialogue.json` | data literals | conversation, **yes** | **Mina Vale** | resident dialogue | **Mina, unvoiced** | canonical | high | **yes — data** | none | **full** | keep; mouth pass | P2 | case owner |
| 10 | **Player choices** | same file, `choices[].label` | data literals | conversation, **yes** | **the player** | player choices | player | canonical | high | yes | none | restrained | keep | — | case owner |
| 11 | **Authored silence** | same, `silence_goto` on 28/34 | data | conversation, **yes** | the player, by not speaking | player choices | — | canonical | **high** | n/a | none | n/a | **DO NOT TOUCH** | — | case owner |
| 12 | **Interaction prompts** | 164 distinct across `props/`, `game/` | **126 literal, 38 format** | world, **yes** | the apparatus | object copy | none | canonical | **critical** | **no — inline** | none | restrained | §8 | **P1** | each prop |
| 13 | **Door refusal** | `props/door_prop.gd:256` | literal `"[E]  Locked"` | world, **yes** | the door | object copy | none | canonical | **critical** | no | none | none | keep | — | DoorProp |
| 14 | **Chirp-hunt prompts** | `game/chirp_hunt.gd:90–103` | literals per stage | 2A, **yes** | the job | object copy | none | canonical | **critical** | no | none | restrained | keep | — | ChirpHunt |
| 15 | **Wayfinding signage** | `building/wayfinding_signage_pass.gd` | literals + `%d` floors | corridors, **yes** | the building | object copy | none | canonical | **critical** | no | none | **none** | keep | — | signage owner |
| 16 | **Audio cue captions** | `game/data/audio_cues.json` `caption` ×20 | data | opt-in overlay, **yes** | the house | object copy | none | canonical | **high** | **yes — data** | **accessibility** | **none** | keep | — | audio policy |
| 17 | **Telephone / call UI** | `call/call_interface.gd` | literals + subtitle | calls, **yes** | caller + house | mixed | caller | canonical | high | no | none | restrained | keep | — | call owner |
| 18 | **Watch / register / apparatus** | `props/night_register_prop.gd`, `watchman_clock_prop.gd`, `watch_register_prop.gd` | literals | route, **yes** | apparatus | object copy | none | canonical | high | no | none | restrained | keep | — | each prop |
| 19 | **House English** | `data/house_english_lexicon.json` (23 terms, `house`+`plain`), `scripts/language/house_english.gd` | data + renderer | **NOT REACHABLE — zero production callers** | — | — | — | **prototype** | n/a | **yes — data, best in tree** | none | n/a | §7 | — | language owner |
| 20 | **Diegetic notices / mail / library** | `lobby_notices.json`, `mail_catalog.json`, `mailbank_cards.json`, `dead_letters.json`, `library.json`, `signage_plates.json` | data | world props, **partly** | in-world authors | object copy | various | canonical | low | **yes — data** | none | **full** | keep | — | content owner |
| 21 | **Case-object world labels** | `cases/case_interactable.gd:44–52` | `Label3D` from a title | **2A, YES — visible** | **nobody** | — | — | **UNCERTAIN / reads as debug** | low | no | none | n/a | §9 | **P1** | Mina case owner |
| 22 | **Debug overlays** | `ui/building_debug.gd` (23 sites), `dream_tentacle_debug.gd` | literals | **F1, reachable in an unguarded build** | developers | — | — | **debug** | n/a | n/a | none | n/a | §9 | **P1** | debug owner |
| 23 | **Store/demo-facing copy** | `design/EARLY_ACCESS_DISTRIBUTION_MARKETING_PLAN_2026-08-26.md` §1 | prose in a design doc | **not in-game** | marketing | — | — | canonical draft | n/a | n/a | claims | restrained | out of scope | — | GTM owner |
| 24 | **Music catalog** | `game/data/music_catalog.json` — 36 tracks (`title`/`artist`/`year`/`provenance`/`mood`), 18 residents (`anecdote`/`gift_line`), station `name`/`legend`/`player_name` | data | **YES** — rendered at `music_director.gd:382,397` (track lore) and `:263–265` (anecdote + gift line) | in-world authors | mixed — resident dialogue **and** object copy | residents | canonical | low | **yes — data** | none | **full** | keep; see **§10b** | — | music owner |
| 25 | **Light fixture cards** | `game/data/light_provenance.json` — **191 fixtures**, each `display`/`resident`/`provenance`/`quirk` | data | **NO** — only consumers are `light_rig.gd:279` (`tuning_snapshot`) and `building_debug.gd:623` (**F1 overlay**) | the building's records | object copy | none | **prototype — authored, unsurfaced** | n/a | **yes — data** | none | full | **§7b** | **P2** | lighting owner |

---

## 4. The irreversible path with no copy — P0

`reality_game_state.gd` refuses to overwrite or fully load a save from a newer
build. Every one of those decisions speaks to the engine log:

```gdscript
:108  push_warning("refusing to overwrite newer Reality Maintenance save version %d" …)
:113  push_warning("could not write Reality Maintenance save")
:136  push_warning("save version %d is newer than supported version %d; running read-only" …)
```

`_announce_loaded()` emits `state_changed` and nothing else. **A grep across
`game/scripts/ui` and `game/scripts/campaign` for a save-failure or read-only
listener returns nothing.**

**INFERENCE:** a friends-build tester who rolls back a version and loads their
save gets a silently read-only session. Their progress appears to work and does
not persist. **The refusal logic is correct and recent — it is the copy that is
missing**, and this is the exact scenario the friends-build rollback policy
anticipates.

**Three strings are needed** (§11 batch items 1–3). **OWNER RULING** on wording
tone; the *requirement* is not a matter of taste.

---

## 5. The first ten minutes, in encounter order

Every string a new player meets before the 2A fault, in order.

| # | Moment | Copy | Family | Note |
| --- | --- | --- | --- | --- |
| 1 | Title screen | menu items | 1 | first impression |
| 2 | Settings, if opened | `EXCLUSIVE FULLSCREEN` · `ALWAYS WARN BEFORE SLEEP` · `CAPTION GAMEPLAY AND DREAM SOUND CUES` · `FETCH LIVE WEATHER FROM OPEN-METEO` · `MATCH WEATHER TO MY LOCATION` · `INVERT Y` | 2, 3, 4 | the consent moment |
| 3 | Weather tooltip | *"Makes an internet request and exposes your IP address to Open-Meteo. Off uses the authored Queens weather."* | 3 | **the strongest safety line in the build** |
| 4 | Location tooltip | *"Opt in by entering a city or postal code. Otherwise the Orison uses Queens, New York."* | 3 | plain, correct |
| 5 | Sleep tooltip | *"Uses the legible gradual warning for every sleep onset."* | 4 | plain |
| 6 | Curb → lobby | ambient signage: `LOBBY`, `NIGHT WATCHMAN`, `RESIDENTS — RING ONCE` | 15, 20 | period register |
| 7 | Watchman detector | `[E]` prompt | 12, 18 | first verb |
| 8 | Night register | `[E]` prompt, spindle response | 18 | K2-B's answer |
| 9 | **Work order card** | `"A Vantry point in 2A is issuing a line-test tone. Find it by ear."` | 8 | **the instruction the whole route rests on** |
| 10 | Stair signage | `FLOOR 1 — STREET` · `↑ 2 — 6` · `ALL FLOORS` | 15 | K2-D/E |
| 11 | Landing plate | `FLOOR 2` · `← 2A 2B` · `2C →` · `↓ STREET` | 15 | K2-F |
| 12 | 2A door | `[E]  Open door` / `[E]  Locked` | 13 | |
| 13 | Inside 2A | **case-object `Label3D`s** — `MINA`, `SOFA`, `DESK`, `CAPTION CALIBRATOR`, `Personal Style Guide` | **21** | **the register break, §9** |
| 14 | The Vantry point | `[E]  Inspect the chirping Vantry point` | 14 | |

**INFERENCE:** items 3–5 and 9 are the load-bearing comprehension strings.
Item 13 is the only place in the first ten minutes where the copy stops sounding
like the game.

---

## 6. Cleverness where plain language is required

Three findings. **The consent panels themselves are exempt — they are already
plain, and §12 protects them.**

| # | String | Path | Why it is a problem |
| --- | --- | --- | --- |
| **C1** | `"listening...   ·   ESC to give up on it"` | `songbook_panel.gd:295` | Shown **while the microphone is recording**. "Give up on it" describes the **stop control** dismissively; a player who wants recording to end now must read a joke to find out how. A stop control is a safety control. |
| **C2** | `"nothing leaves this machine unless you keep it."` | `songbook_panel.gd:418` | A **privacy claim** carrying a wit move. The conditional is the problem: **INFERENCE** — it is meant as "unless you save it here", but it reads as "keeping it is what sends it". A privacy sentence must not be ambiguous in the direction of alarm. |
| **C3** | `"heard you %d ms late. holding that."` | `songbook_panel.gd:312` | Reports the result of a **microphone calibration** in an idiom that does not say what was kept or where. Runtime-composed, so it is also §8. |

**Not findings, deliberately:** `"ESC to step away from the machine"`,
`"any key to lift the stylus"`, `"ESC stops the take."` These are diegetic
object copy in a legitimate register, and `"ESC stops the take."` is the plainest
stop instruction in the panel. **Full wit allowance is correct for the Songbook
generally** — the three above are specifically the consent-and-safety subset.

---

## 7. House English — no comprehension gap, because there is no surface

**STRING EXISTS.** `game/data/house_english_lexicon.json` carries 23 terms, each
with `house`, `plain`, `kind` and `origin`. Example: `"tenant-says"` → plain
`"reported by the occupant"`. `scripts/language/house_english.gd` exposes
`term()`, `render_report()` and `render_line()`, each with a `"plain"` mode.

**NOT REACHABLE.** A repository search for `HouseEnglish` or `house_english`
outside the module itself returns **no production caller**. It is a prototype
with a test.

**INFERENCE:** there is currently **zero** House English on any player surface,
so there are no places where it appears without its plain stratum. **The data
model is the best-prepared copy asset in the repository** — it is the only
family that already separates a literal carrier from a plain meaning — and it is
the natural template for §13.

**OWNER RULING required** before any of it surfaces: whether the plain stratum
is a toggle, a hover, a parallel line, or a first-encounter gloss.

---

## 7b. Authored copy with no player surface

Two families are fully written and cannot be read in normal play.

| Family | Volume | Reachability | Evidence |
| --- | --- | --- | --- |
| House English (19) | 23 terms, each with a plain gloss | **none** | no production caller |
| Light fixture cards (25) | **191 fixtures**, each with `display`, `resident`, `provenance` and `quirk` | **F1 debug overlay only** | `fixture_provenance()` has exactly two callers: `light_rig.gd:279` (`tuning_snapshot`, a tuning dump) and `building_debug.gd:623` |

A sample fixture card, in full:

> `display` — "B1 Navigation — opal schoolhouse dome"
> `resident` — "the superintendent"
> `provenance` — "Queens Electric Porcelain Works, installed 1979, service
> card F7076. Wartime utility wiring, repeatedly patched."
> `quirk` — *(authored per fixture)*

**INFERENCE:** this is the *inverse* of the usual copy problem. It is not
scaffolding leaking onto a player surface (§9) — it is finished, in-register,
per-object prose that the player has no verb to reach. **A superintendent who
inspects a lamp is the most natural reader imaginable for a lamp's service
card**, and the data is already keyed by fixture.

**OWNER RULING required:** whether fixture cards get a player-facing surface at
all. **I am not proposing the verb.** The finding is that 191 authored cards
currently exist for developers only, and the debug overlay is ruled off for
friends builds — which means shipping the friends build makes them reachable by
nobody.

---

## 7c. The copy's present is not the player's present

The player occupies **1928** — `period_reality_layer.gd:29` seeds its RNG
`19280501` and names the date in a comment. The authored records do not stay
there.

| Corpus | Dates it carries | Complete record read? |
| --- | --- | --- |
| Light fixture cards | **187 of 191 cite a year after 1928**, spanning 1928–1989 | yes — all 191 parsed |
| Music catalog | tracks dated to 1978; station "supposedly operated between 1962 and 1999" | yes — all 36 + station |
| Wayfinding, work orders, Mina's tree | period-consistent | yes |

**187 of 191 is not drift. It is a conceit**, and it is the same conceit as a
carrier-current station whose transmitter "has never been found" playing in a
1912 building. I am recording it, **not adjudicating it**, and specifically
**not** filing it as a contradiction — the whole record was read before this
paragraph was written, which is the stop rule this project already carries.

**Why a copy census cares:** the two families that speak from after 1928 are the
two with the weakest player surfaces (§7b, family 24). **INFERENCE:** if fixture
cards ever surface, the player meets a maintenance record dated fifty years
after the day they are living in — which is either the best thing in the build
or a bug report, depending on a ruling that does not yet exist.

**OWNER RULING required:** whether post-1928 dating in records the player can
read is intended effect or is confined to the radio conceit.

---

## 8. Runtime-composed strings that cannot take a mouth pass

**164 distinct `[E]` prompts exist; 38 contain a `%` format placeholder.**
Representative shapes:

```
"[E]  %s"                          "[E]  %s: %s"
"[E]  %s the %s"                   "[E]  %s  ->  move the index to  %s"
"[E]  %s  —  the songbook"         "[E]  %s -- fifty feet behind the glass"
"[E]  %s's books  —  wants tidying"
```

**The problem is not the formatting.** It is that the sentence's rhythm depends
on a substitution decided at runtime, so a writer cannot read the line as the
player will meet it, and a translator cannot reorder it. `"[E]  %s"` is the
extreme case: **the entire prompt is a variable**, so there is no authored line
at all.

Two further generated surfaces: the Songbook's `%d ms` (C3) and
`"%s / %s"` time displays, and the landing plates' `"↑ %d — 6"`, which is
correct as built — **INFERENCE:** a floor number is a number, not a mouth.

**Recommended, not performed:** enumerate the substitutions each format actually
receives, and promote any prompt whose variable set is small and closed into
explicit authored variants. **`"[E]  %s"` should be treated as unauthored copy
until its call sites are listed.**

---

## 9. Debug and internal identifiers visible to players

| # | Surface | Reachable | Finding |
| --- | --- | --- | --- |
| **D1** | Case-object `Label3D`s in 2A — `MINA`, `Mina Vale · 2A [ACTIVE]`, `SOFA`, `DESK`, `CAPTION CALIBRATOR`, `Personal Style Guide` | **YES — on the route, first ten minutes** | Built by `cases/case_interactable.gd:44–52` from each object's `title`. **They are not debug code**, but `[ACTIVE]` is a state marker in a player's field of view, and floating nouns over furniture read as developer scaffolding. **This is a register break, not a bug.** Already recorded as G18 in the release matrix and as a capture blocker. |
| **D2** | `ui/building_debug.gd`, 23 string sites, opened by **F1** | **YES in an unguarded build** | Developer overlay. The controller contract already rules it must be disabled for friends builds. |
| **D3** | `dream/entity/dream_tentacle_debug.gd`, 5 sites | conditional | Same class. |
| **D4** | Internal ids in prompts — `%s` substitutions drawn from node names | **possible** | **UNKNOWN:** whether any `"[E]  %s"` call site passes a node name rather than an authored noun. §8's enumeration would answer it. **Flagged, not asserted.** |

---

## 10. Duplication and collisions

| # | Finding | Assessment |
| --- | --- | --- |
| **X1** | `tools/audit_authored_voice.py` notices `'caller declines to state'` used by **3+ nodes** in the Mina tree | **Advisory, and almost certainly deliberate.** It is a bureaucratic refrain and the tool explicitly does not score style. **Recorded, not actioned.** The auditor's own words: stylistic observations "never change the exit code". |
| **X2** | `"CAPTION GAMEPLAY AND DREAM SOUND CUES"` is authored **identically in two files** — `title_screen.gd:258` and `pause_services.gd:140` | **Real collision.** Two systems own one player-facing sentence; editing one silently desynchronises the pair. Same pattern for the sleep-warning label, worded **differently**: `"ALWAYS WARN BEFORE SLEEP"` vs `"ALWAYS GIVE THE GRADUAL SLEEP WARNING"` — **the same setting, two names.** |
| **X3** | `"ESC to step away from the machine."` / `"ESC to step away."` / `"ESC to go back."` / `"ESC stops the take."` — four exits, four phrasings, one panel | **INFERENCE:** variety is deliberate and the register carries it, but `ESC stops the take` and `ESC to give up on it` (C1) describe the **same control** in the same flow. |
| **X4** | `[E]` prompt verbs across 164 prompts | Not audited for consistency; a shared verb vocabulary is likely worth having. **Out of scope; flagged.** |

**X2 is the one to fix**, because a settings label that disagrees with itself
across two surfaces is a comprehension failure, not a style one.

---

## 10b. Fields whose text is a voice, not a record

This is the census's thesis in one data field, and **the repository has already
solved it once.**

Commit `81c0856` ("Keep music lore out of the rights chain") added to
`music_catalog.json`:

```json
"field_semantics": {
  "tracks.*.provenance": {
    "classification": "in_world_fiction",
    "rights_record": null,
    "warning": "Authored diegetic history only. Never use this field to infer
                creator, licence, attribution, or distribution authority."
  }
}
```

**That is exactly right, and it is a precedent worth generalising.** A field
named `provenance`, holding sentences like *"Pressed for a Queens teachers'
union filing drive"*, is authored voice wearing the costume of a record — and
the costume is the point of the writing and the danger of the field.

**The identical hazard is unguarded one file over.** `light_provenance.json`
uses **the same field name** for 191 entries reading *"Queens Electric Porcelain
Works, installed 1979, service card F7076"* — manufacturer, date, document
number. **STRING EXISTS** and it is fiction; nothing in the file says so.

**INFERENCE:** the risk is not that a player is misled — it is that a *future
reader of the repository* is, exactly as the rights chain nearly was. A
plausible manufacturer and a service-card number are precisely the shape of
thing someone later cites as sourcing.

**Recommendation, not performed:** carry `81c0856`'s `field_semantics` block to
`light_provenance.json` — and treat `classification` as the seed of §13's
record format, where it becomes a field every string carries rather than a
warning two files happen to have.

**Not a defect in either file.** The music guard is new and correct; this is one
sibling file that has not received it yet.

---

## 11. First surgical rewrite batch — 20 strings, none performed

Ordered by risk. **No rewrite is performed here; wordings are illustrative, and
each needs its owner's approval.**

| # | Path | Current | Why | Owner |
| --- | --- | --- | --- | --- |
| 1 | `reality_game_state.gd:136` | *(no player copy)* | **AUTHOR:** a read-only-session notice naming the cause and what will not persist | save |
| 2 | `reality_game_state.gd:108` | *(no player copy)* | **AUTHOR:** a refusal-to-overwrite notice | save |
| 3 | `reality_game_state.gd:113` | *(no player copy)* | **AUTHOR:** a save-failed notice | save |
| 4 | `songbook_panel.gd:295` | `listening...   ·   ESC to give up on it` | C1 — stop control described dismissively | privacy |
| 5 | `songbook_panel.gd:418` | `nothing leaves this machine unless you keep it.` | C2 — ambiguous privacy claim | privacy |
| 6 | `songbook_panel.gd:312` | `heard you %d ms late. holding that.` | C3 — unclear what was kept | privacy |
| 7 | `pause_services.gd:145` | `ALWAYS GIVE THE GRADUAL SLEEP WARNING` | X2 — must match #8 exactly | accessibility |
| 8 | `title_screen.gd:250` | `ALWAYS WARN BEFORE SLEEP` | X2 — same setting, different name | accessibility |
| 9 | `title_screen.gd:258` + `pause_services.gd:140` | duplicated caption label | X2 — single-source it | accessibility |
| 10–15 | `cases/case_interactable.gd` label pipeline | `MINA`, `SOFA`, `DESK`, `CAPTION CALIBRATOR`, `Personal Style Guide`, `Mina Vale · 2A [ACTIVE]` | D1 — register break on the route; **`[ACTIVE]` first** | Mina case |
| 16 | `chirp_hunt.gd:92` | `[E]  Inspect the chirping Vantry point` | **INFERENCE:** "chirping" tells the player the answer they were asked to find by ear | ChirpHunt |
| 17–20 | four `"[E]  %s"` call sites | fully-variable prompts | §8 — unauthored copy | each prop |

**Explicitly not in the batch:** anything in §12.

---

## 12. Do not rewrite

Strong, load-bearing, or authored-for-a-reason. **Changing these costs more than
it gains.**

1. **`"Makes an internet request and exposes your IP address to Open-Meteo. Off
   uses the authored Queens weather."`** — the single best safety line in the
   build. Plain, complete, unflattering to itself. **Do not soften it.**
2. **`"Opt in by entering a city or postal code. Otherwise the Orison uses
   Queens, New York."`** — states the default, which is the hard part.
3. **The microphone consent panel** (`songbook_panel.gd:252–261`) — *"the
   Songbook will record your microphone and keep the take on this machine.
   nothing is uploaded. you can perform without recording."* Three sentences,
   each doing one job, offering a real refusal.
4. **`"A Vantry point in 2A is issuing a line-test tone. Find it by ear."`** —
   the instruction the entire sound-led design rests on. Precise and confident.
5. **The 28 authored silences** in the Mina tree. **`silence_goto` is a
   first-class player choice**, and the auditor counts it as content. Not copy
   to be tidied.
6. **Mina's dialogue lines.** Auditor PASS, 6.5-word mean sentence, correction
   and institutional carriers throughout. **A mouth pass belongs to the case
   owner, and it is not a defect list.**
7. **The wayfinding plates.** `FLOOR 1 — STREET`, `↑ 2 — 6`, `← 2A 2B`. Six
   tasks of measurement stand behind that wording.
8. **`"[E]  Locked"`.** Two words, unambiguous.

---

## 13. Localization-ready semantic record — proposal

The lexicon already proves the shape: a literal carrier and a plain meaning as
**separate authored fields**. Generalise that so translation and the mouth pass
never depend on runtime improvisation.

**Proposed `game/data/copy_records.json`** *(proposal only — not created)*:

```json
{
  "id": "prompt.vantry.inspect_faulted",
  "speaker": "apparatus",
  "mouth": null,
  "register": "object_and_maintenance",
  "evidence_owner": "ChirpHunt",
  "wit_move": "none",
  "heat": 0,
  "literal_carrier": "Inspect the chirping Vantry point",
  "plain_meaning": "Examine the Vantry point that is making the sound",
  "surface": "interaction_prompt",
  "variables": [],
  "comprehension_critical": true,
  "safety_class": "none",
  "classification": "operational_fact",
  "status": "canonical"
}
```

**The six fields that matter, and why:**

- **`speaker`** and **`mouth`** — separates *who owns the fact* from *whose
  voice says it*. Family 21's problem is that it has a surface and no speaker.
- **`evidence_owner`** — which system's truth this asserts, so a rewrite cannot
  silently change a claim.
- **`wit_move`** and **`heat`** — the owner-voice guide's own vocabulary,
  recorded per string, so `"none"` is enforceable on consent copy rather than
  remembered.
- **`literal_carrier`** vs **`plain_meaning`** — the lexicon's proven split;
  a translator gets both, and the plain stratum for House English (§7) already
  has somewhere to live.
- **`variables`** — an empty list is the definition of a string that can take a
  mouth pass. §8's 38 format prompts would carry their substitution sets here.
- **`classification`** — `in_world_fiction` or `operational_fact`, generalised
  from `81c0856`'s guard (§10b). This is the field that stops a diegetic
  service-card number from being read later as sourcing, and it is the one
  field here that the repository has already proved it needs.

**No runtime improvisation:** every surface renders an authored
`literal_carrier` or an authored `plain_meaning`. **Nothing is composed from
fragments at display time.**

---

## 14. Priorities

**P0 — RESOLVED** — 1. Save/rollback now has persistent player copy (§4).
2. Microphone status lines C1–C3 are now plain (§6).

**P1** — 3. Case-object labels on the route, `[ACTIVE]` first (D1). 4. X2's
divided settings labels. 5. Debug overlay reachability (D2/D3, already ruled
elsewhere). 6. Enumerate the 38 format prompts (§8). 7. Carry `81c0856`'s
`field_semantics` guard to `light_provenance.json` (§10b).

**P2** — 8. Mina mouth pass (case owner's, not a defect list). 9. `[E]` verb
vocabulary (X4). 10. The `copy_records.json` proposal. 11. Surface — or
formally shelve — the 191 fixture cards and House English (§7, §7b).

**Owner rulings outstanding, none of which I am making** — the House English
plain stratum (§7); whether fixture cards get a player verb (§7b); whether
post-1928 dating is intended on readable records (§7c). The save-failure tone
is now implemented as deliberately plain safety copy.

---

## 15. Sources

All in-repo at `0a55185`: `design/ORISON_OWNER_VOICE_STYLE_GUIDE.md` §6 ·
`design/ORISON_CAST_VOICE_MAP.md` · `tools/audit_authored_voice.py` (run) ·
`game/data/case01_dialogue.json` · `maintenance_jobs.json` ·
`house_english_lexicon.json` · `audio_cues.json` · `lobby_notices.json`,
`mail_catalog.json`, `mailbank_cards.json`, `dead_letters.json`, `library.json`,
`signage_plates.json` · `game/scripts/ui/title_screen.gd`, `pause_services.gd`,
`songbook_panel.gd`, `building_debug.gd`, `call/call_interface.gd` ·
`game/scripts/props/door_prop.gd` · `game/scripts/game/chirp_hunt.gd`,
`music_catalog.json`, `light_provenance.json`,
`game/scripts/audio/music_director.gd`, `game/scripts/building/light_rig.gd`,
`game/scripts/building/period_reality_layer.gd` · commits `d31d803`,
`81c0856`, `735ff1b` ·
`reality_game_state.gd` · `game/scripts/building/wayfinding_signage_pass.gd` ·
`game/scripts/language/house_english.gd` · `game/scripts/cases/case_interactable.gd` ·
`git ls-files game/assets/audio/voice` (empty) · commits `0a55185`, `735ff1b`.

**No external research. No legal advice.**

---

## 16. Scope and boundary

- **No string was rewritten**, and none was edited in place.
- **No production text, JSON, scene, script, design document, localization
  resource or test was modified.** One new file.
- Wordings in §11 are illustrative of the *problem*, not proposed final copy.
- §13 proposes a record format and creates nothing.
- **Advisory tool output is not literary judgment** — X1 is recorded and not
  actioned for exactly that reason.
- Where reachability was not provable from source, it is marked **UNKNOWN**
  (D4) rather than asserted.
- §7c reports a period pattern **after parsing all 191 fixture records and all
  36 tracks**, and files it as a conceit requiring a ruling — **not** as a
  contradiction. The rewrite batch remains capped at 20 and §10b's
  recommendation is a data guard, not a rewrite.
