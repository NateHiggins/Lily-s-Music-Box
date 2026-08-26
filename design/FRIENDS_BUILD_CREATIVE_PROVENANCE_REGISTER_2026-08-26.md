# Friends-build creative provenance register — 2026-08-26

**Purpose:** turn `FRIENDS_BUILD_LICENSE_AND_THIRD_PARTY_AUDIT_2026-08-26.md`'s
unresolved creator questions into records an owner can actually answer.

**Base:** `4272189ff6fbde321412d022bb55f1f5bf421157` (pushed `origin/main`,
"Codify the Orison owner voice"). ADMIN-LIC1 is integrated at `1e5dc76`.

**Godot was not run.** No existing asset, code, manifest, licence or design file
was edited.

> **This document gives no legal advice and reaches no legal conclusion.** It
> separates four things that are routinely collapsed into one: what the owner
> *states*, what the repository *shows*, what a provider's terms *would need to
> prove*, and what remains *not established*. Only the first two are recorded
> here as facts, and they are labelled.

> **"Unknown is not forbidden."** An unknown blocks nothing by itself. But every
> unknown below carries an explicit friends-build disposition, because an
> unknown with no disposition is how something ships unexamined.

---

## 1. Executive verdict

**The friends build ships four creative families whose creator record is
thinner than the work deserves, and one field in the repository is actively
misleading.**

1. **The 34 Mina voice takes** are the most exposed. Git records a real
   recording session — *"The recording session came back"* (`62ca805`,
   2026-08-02) — and a technical delivery contract, but **no performer is named
   anywhere in the repository, and no agreement of any kind is recorded.** The
   raw takes exist off-repo at a gitignored path, so the evidence is
   recoverable by the person who has them. §5 is a five-minute questionnaire.
2. **The music** — 36 library tracks, 3 title tracks, 36 cover images, all
   shipping — now has an owner ruling, recorded verbatim in §4. **What it does
   not have is date/version evidence of the provider terms it depends on.**
3. **`music_catalog.json` has a field literally named `provenance`, and it
   contains in-world fiction** — invented bands, invented years, invented
   pressing histories. It is excellent writing and it is **not a rights
   record**. A future audit or script reading that field by name would draw a
   confident wrong conclusion. **This is the single most dangerous artefact in
   the register.**
4. **Manifest coverage is far narrower than it looks.** Four
   `art/audio/*.MANIFEST.md` files exist; **only one corresponds to shipped
   audio** (`The_Clockwork_Waltz` → the two `music/title/clockwork_waltz_*.ogg`
   files). The other three document songbook candidates that **do not ship**,
   and **35 of the 39 shipped tracks have no manifest at all**.

**Nothing here blocks a private friends build on its own.** Every row has a
disposition, and most are "ship with the record filled in afterwards". Two are
not (§8 P0).

---

## 2. Audit method

Everything below is derived from tracked files and git history at the base
commit. **No file extension was used to infer shipping**; the shipped set was
computed against `game/export_presets.cfg`'s actual `exclude_filter` and
`include_filter`.

```
git ls-files <path>                      # what is tracked
git log --diff-filter=A -- <path>        # when a file first appeared, and why
git log -1 --format=%B <sha>             # the commit's own account of itself
grep -oE 'exclude_filter="[^"]*"' game/export_presets.cfg | tr ',' '\n'
python3 -c "json.load(...)"              # catalogue fields, whole records
```

**The exclusion list, in full**, is the only thing standing between a tracked
file and the payload:

```
tests/*  ·  docs/*  ·  assets/audio/freesound/source/*
assets/audio/soundbits/*  ·  assets/building/textures/sky/*_source.png
assets/building/textures/sky/*_preview.jpg  ·  four named sky 4k PNGs
```

**No music, voice, cover, texture, model or arcade path is excluded.** Every
creative family in §3 ships except where the table says otherwise.

---

## 3. Shipped-creative census

| # | Family | Path / pattern | Ships | Count | Creator / performer | Method / tool | Date evidence | Agreement evidence | Commercial authority | Attribution | Modification | Source files | Confidence | Disposition |
| --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- | --- |
| 1 | **Mina voice** | `assets/audio/voice/mina_c01_*.ogg` | **yes** | **34** | **UNRECORDED** | a recording session; script `design/case01_recording_script.md`; importer `art/tools/import_voice_takes.py` | commit `62ca805`, **2026-08-02** | **NONE FOUND** | **UNKNOWN** | UNKNOWN | UNKNOWN | `assets/audio/voice/source/` — **gitignored** (`.gitignore:73`) | **LOW** | **P0 — §5** |
| 2 | **Music, library** | `assets/audio/music/library/*.ogg` | **yes** | **36** | owner (stated §4) | **Gemini** (stated §4) | catalogue `year` fields are **fiction** | owner statement only | **owner-stated** | none stated | n/a | none in repo | **MEDIUM** (owner statement, no provider evidence) | **P1 — §4** |
| 3 | **Music, title** | `assets/audio/music/title/*.ogg` | **yes** | **3** | as above | as above; **one has a manifest** | `The_Clockwork_Waltz.MANIFEST.md` — 2026-08-14 | manifest with **unfilled `OWNER:` fields** | owner-stated | none stated | n/a | none in repo | **MEDIUM** | **P1 — §4** |
| 4 | **Music, covers** | `assets/audio/music/covers/*.webp` | **yes** | **36** | **UNRECORDED** | **UNRECORDED** — no prompt sheet, manifest or note found | first appeared in a merge commit `653316e` | **NONE FOUND** | **UNKNOWN** | UNKNOWN | UNKNOWN | none in repo | **LOW** | **P1** |
| 5 | **`music_catalog.json` `provenance`** | `game/data/music_catalog.json` | **yes** (data) | 36 fields | authored fiction | writing | — | — | — | — | — | — | **HIGH — that it is fiction** | **P0 — rename/annotate, §7** |
| 6 | **Textures / materials** | `assets/building/textures/**` | **yes** (minus 6 sky exclusions) | large | owner-directed | **Gemini** image generation per `design/MATERIAL_PROMPT_SHEET.md` | prompt sheet, undated per-asset | provider terms **not recorded in-tree** | **UNKNOWN** | UNKNOWN | UNKNOWN | source PNGs partly excluded | **LOW–MED** | **P1** |
| 7 | **`viral_seed.ogg`** | `assets/audio/viral_seed.ogg` | **yes** | 1 | repository-native | **generated by an in-repo tool**, `art/audio/build_viral_seed.py`, deterministically from a WAV input | tool is tracked | n/a if the input is owner-created | follows the input | — | — | **input WAV not identified** | **MEDIUM** | **P2 — name the input** |
| 8 | **Freesound CC BY 4.0** | `assets/audio/freesound/processed/**` | **yes** | 8 sources | named contributors | recorded, then processed | manifest | `ATTRIBUTION.md` — **complete** | yes, with attribution | **REQUIRED** | permitted | `source/` **excluded** | **HIGH** | **GREEN — notice** |
| 9 | **Freesound CC0** | same | **yes** | 7 sources | named contributors | as above | manifest | `ATTRIBUTION.md` | yes | not required | permitted | excluded | **HIGH** | **GREEN** |
| 10 | **Courier Prime** | `assets/fonts/courier_prime/*.ttf` | **yes** (in `.pck`) | 2 | The Courier Prime Project Authors | third-party typeface | — | **`OFL.txt` in-tree** | yes | **REQUIRED** (OFL cl. 2) | permitted, name reserved | — | **HIGH** | **GREEN — notice, per ADMIN-LIC1** |
| 11 | **Godot runtime** | inside the `.exe` | **yes** | — | Godot contributors | MIT engine | — | official licence page | yes | **REQUIRED** | permitted | — | **HIGH** | **GREEN — notice** |
| 12 | **Arcade packages** | `assets/arcade/packages/*.swcpkg` | **yes** — via `include_filter="*.swcpkg"` | 6+ | **UNRECORDED** | in-house format (`arcade/swc_package_source.gd`) | — | **NONE FOUND** | presumed owner | — | — | — | **LOW** | **P2** |
| 13 | **Voice takes, raw** | `assets/audio/voice/source/` | **no** | ? | — | — | — | — | — | — | — | gitignored | — | not shipped |
| 14 | **Songbook candidates** | `art/audio/*.MANIFEST.md` × 3 | **no** | 3 | owner | Gemini/Lyria | manifests dated 2026-08-14 | unfilled `OWNER:` fields | — | — | — | — | — | **not shipped — do not conflate with rows 2–3** |

### 3.1 One-row-per-file: the 34 Mina takes

**No mechanically proven identical agreement covers all 34** — there is no
agreement in the repository at all. What *is* mechanically proven is that **all
34 entered the repository in a single commit**, `62ca805`, whose message
describes one session: *"The recording session came back… 34 for 34, no
orphans."*

**Therefore they are listed as one provenance family with 34 members**, and §5
asks whether one agreement covers them. If the answer is no, this table expands
to 34 rows. Every file shares: creator **UNRECORDED**, agreement **NONE FOUND**,
authority **UNKNOWN**, disposition **P0**.

```
mina_c01_fb_open      mina_c01_fb_sil       mina_c01_fs_flatter
mina_c01_fs_misread   mina_c01_fs_named     mina_c01_fs_now
mina_c01_fs_open      mina_c01_fs_people    mina_c01_fs_push
mina_c01_fs_push_sil  mina_c01_fs_silence   mina_c01_int_beat
mina_c01_int_open     mina_c01_res_open     mina_c01_rt_afact
mina_c01_rt_agree     mina_c01_rt_ann       mina_c01_rt_armor
mina_c01_rt_blank     mina_c01_rt_court2    mina_c01_rt_court_door
mina_c01_rt_earned    mina_c01_rt_guess     mina_c01_rt_guess_sil
mina_c01_rt_heart     mina_c01_rt_heart_sil mina_c01_rt_man
mina_c01_rt_open      mina_c01_rt_open2     mina_c01_rt_refill
mina_c01_rt_safe      mina_c01_rt_sil       mina_c01_rt_thin
mina_c01_rt_told
```

---

## 4. Gemini music

### 4.1 The owner ruling, recorded verbatim and not expanded

> **"All the music tracks were created with Gemini and non copyrightable."**

**Recorded 2026-08-26. Reproduced exactly. Not interpreted.**

### 4.2 The four-way separation

| Layer | Content |
| --- | --- |
| **Owner factual representation** | The tracks were **created with Gemini**, by the owner. This is a statement about *how the files came to exist* and it is the owner's to make. **Recorded as fact.** |
| **Repository evidence that supports it** | `art/audio/*.MANIFEST.md` document a Gemini/Lyria workflow. `design/ORISON_SONGBOOK_GEMINI_LYRIA_HOUSE_FIVE.md` and `ORISON_SONGBOOK_GEMINI_LYRIA_PROMPTBOOK.md` describe generation from **public-domain scores**, with a standing rule to *"never upload, link, hum or otherwise reference any historical recording, ever."* **This is real, contemporaneous, and it corroborates the method.** |
| **Provider terms that would need date/version proof** | Which Google product and tier generated each track, on what date, under which version of that product's terms, and what those terms said about output ownership and use. **None of this is recorded in-tree.** The manifests have fields for exactly this and they are unfilled. |
| **Legal conclusion NOT established here** | Whether the output is copyrightable, by whom, in which jurisdictions; whether it is public domain; whether use is exclusive; whether commercial distribution is permitted; whether attribution or AI disclosure is required. **This document reaches none of these conclusions and takes no position on the "non copyrightable" characterisation.** It is recorded as the owner's statement, not adopted as a finding. |

### 4.3 Exact missing evidence to make the ruling release-operational

Small, and mostly recoverable from the owner's own account history:

| # | Evidence | Where it would live |
| --- | --- | --- |
| E1 | **Which product and tier** generated the tracks (the manifests' `gemini/lyria product` and `model displayed` fields) | one line per track, or one line for all if a single session |
| E2 | **Generation dates** — even month precision | same |
| E3 | **A dated copy or link to the terms in force at generation**, captured as text | `design/` or alongside the manifests |
| E4 | **Whether the UI displayed an AI-disclosure or SynthID notice**, and its wording (the manifests' `synthid / ai disclosure` field) | same |
| E5 | **Confirmation that no historical recording was referenced**, per the standing rule | one line; the promptbook already asserts the rule |
| E6 | **Whether the 36 cover images came from the same workflow** — row 4 has no record at all | a covers manifest |

**E1–E3 are the ones that convert the ruling from a statement into something a
future reader can verify without asking the owner again.**

### 4.4 What this does not change

The ruling addresses **the tracks**. It does not address the **36 cover
images** (row 4), which have no recorded method, or the **texture corpus**
(row 6). Those remain open on their own terms.

---

## 5. The Mina voice questionnaire

**Answerable in under five minutes by the person who was there.** No legal
knowledge needed — these are facts, not judgements.

```
MINA VOICE — CASE 01, 34 TAKES, RECORDED ON OR BEFORE 2026-08-02

Q1  Who performed them?
    [ ] the owner        [ ] a named person: ______________________
    [ ] more than one person (who did what): ____________________
    [ ] text-to-speech / AI voice — which product: ______________

Q2  If a person: was there any agreement, in any form?
    [ ] nothing written        [ ] messages/email — where: ________
    [ ] a signed document — where: _______________________________
    [ ] paid / unpaid / favour / collaborator (circle)

Q3  Does whatever agreement exists cover ALL 34 takes, or only some?
    [ ] all 34        [ ] some — which: ________________________

Q4  Was it understood the recordings would be in a game that might
    be sold?
    [ ] yes   [ ] no   [ ] never discussed

Q5  Would that person want credit, and under what name?
    [ ] yes, as: ____________________   [ ] no   [ ] ask them

Q6  Where are the raw source takes now?
    (game/assets/audio/voice/source/ is gitignored — is it still on
     the machine that recorded them?)
    ____________________________________________________________

Q7  Is the performer reachable today?          [ ] yes   [ ] no

Q8  Approximate recording date, if not 2026-08-02: ______________
```

**Q1 and Q4 are the two that matter most.** Everything else is bookkeeping that
can follow.

---

## 6. Unknown is not forbidden — dispositions

Every unknown, with what happens to it for a **private friends build**.

| Family | Unknown | Friends-build disposition |
| --- | --- | --- |
| Mina voice | performer, agreement | **SHIP, and answer §5 before any wider distribution.** A private cohort of named friends is the lowest-exposure use this material will ever have, and delaying costs the recall that makes §5 answerable. |
| Music | provider terms evidence | **SHIP under the owner's recorded ruling (§4.1).** Collect E1–E4 while reconstructible. |
| Covers | method entirely unrecorded | **SHIP, record method.** Same workflow question as the tracks; ask once, answer both. |
| Textures | provider terms at generation | **SHIP, record.** Largest family, lowest per-item risk. |
| `provenance` field | reads as a rights record | **SHIP the data — it is game content.** Annotate it (§7) so nobody mistakes it again. |
| `.swcpkg` | authorship unrecorded | **SHIP, presumed owner-created.** Confirm in one line. |
| `viral_seed.ogg` input | source WAV unidentified | **SHIP.** Name the input when convenient. |

**No family is BLOCKED for a friends build.** Two are P0 for anything wider.

---

## 7. Proposed repository records — described, not created

Four small records. **None is created by this document.**

1. **`design/VOICE_PROVENANCE.md`** — §5's answers, once. Performer, agreement
   location, scope, credit preference, source-take location. Ten lines.
2. **`art/audio/MUSIC_PROVENANCE.md`** — E1–E6 in one table for all 39 shipped
   tracks plus the 36 covers, replacing the pattern where four manifests cover
   one shipped file.
3. **An annotation on the misleading field.** The cleanest fix is a sibling key
   rather than a rename, so nothing that reads the catalogue breaks:
   ```
   "provenance"        → unchanged; in-world fiction
   "provenance_note"   → "IN-WORLD FICTION. Not a rights record.
                          See art/audio/MUSIC_PROVENANCE.md."
   ```
   A rename to `lore` or `in_world_history` is cleaner still but touches every
   consumer. **Owner/Codex call.**
4. **Extend `asset_provenance.json`** (proposed in ADMIN-LIC1 §8) with a
   `creator`, `method` and `evidence` field per family, so the machine check
   covers *who made it* and not only *what licence it carries*.

---

## 8. Blockers, ranked

**P0 — answer before any distribution wider than named friends**

| | |
| --- | --- |
| **P0-1** | **The Mina voice performer and agreement.** 34 shipped files, zero recorded authority. The one question whose answer decays with time. §5. |
| **P0-2** | **The `provenance` field is fiction and is named as though it is not.** Cheap to annotate; expensive if a future audit or automated check trusts it. §7.3. |

**P1 — collect while reconstructible**

| | |
| --- | --- |
| **P1-1** | Gemini music evidence E1–E4 (§4.3) |
| **P1-2** | Cover-image method — 36 shipped images, no record (row 4) |
| **P1-3** | Texture-generation terms at time of generation (row 6) |
| **P1-4** | Fill the four existing manifests' `OWNER:` fields, and note that three of them describe unshipped candidates |

**P2 — record when convenient**

| | |
| --- | --- |
| **P2-1** | `.swcpkg` authorship confirmation |
| **P2-2** | `viral_seed.ogg` input WAV identification |
| **P2-3** | Reference-derived art spot-check against `PROP_REFERENCE_NOTES.md` |

---

## 9. Correction protocol

Provenance findings get revised. When one does:

1. **Amend this register in place, dated, with the superseded text struck
   rather than deleted.** A provenance record that quietly changes is worth
   less than one that shows its own history.
2. **If a correction narrows a right** — a family turns out to be less freely
   usable than recorded — **it is P0 immediately**, regardless of its previous
   rank, and any build already distributed is listed with the date it went out
   and to whom.
3. **If a correction widens a right**, downgrade the rank and note the
   evidence. No build action needed.
4. **Never correct by deletion.** A row that turns out to be wrong becomes a row
   marked wrong.
5. **A correction that arrives after a build has shipped must name that build's
   number and SHA**, so the distribution log and this register agree.
6. **The owner's statements are recorded as statements.** If one is later
   revised, the original stays visible with both dates.

*This protocol is written from experience: an earlier audit of mine reported a
census from a truncated listing, and the correction was worth more than the
original finding because it showed how the error happened.*

---

## 10. Sources and commands

**Repository, at `4272189` — all primary:**

| Path | Supports |
| --- | --- |
| `git log -1 62ca805` | *"The recording session came back… 34 for 34, no orphans… Sources stay gdignored"*, dated 2026-08-02 |
| `.gitignore:73` | `game/assets/audio/voice/source/` excluded from the repository |
| `design/case01_recording_script.md:1–13` | the delivery contract — *"The filename is the contract"*; **names no performer and no terms** |
| `game/data/music_catalog.json` | 36 entries; fields `artist`, `year`, `provenance`, `mood`, `path`, `cover`; **`provenance` values are in-world fiction** |
| `art/audio/*.MANIFEST.md` | four manifests; unfilled `OWNER:` fields incl. `legal status`, `prompt used`, `model displayed`, `synthid / ai disclosure` |
| `design/ORISON_SONGBOOK_GEMINI_LYRIA_HOUSE_FIVE.md` | public-domain scores; *"never upload, link, hum or otherwise reference any historical recording, ever"* |
| `design/MATERIAL_PROMPT_SHEET.md` | the Gemini texture pipeline |
| `art/audio/build_viral_seed.py` | `viral_seed.ogg` is generated in-repo from a WAV input |
| `game/export_presets.cfg` | the full `exclude_filter`; `include_filter="*.swcpkg"` |
| `game/assets/audio/freesound/ATTRIBUTION.md` | 7 CC0 + 8 CC BY 4.0, fully credited |
| `game/assets/fonts/courier_prime/OFL.txt` | OFL 1.1 in-tree |
| `design/FRIENDS_BUILD_LICENSE_AND_THIRD_PARTY_AUDIT_2026-08-26.md` | the licence-side findings this register extends |

**No external browsing was performed.** The Godot MIT and OFL findings are
carried from ADMIN-LIC1, which cited them with access dates; nothing new
required a provider's terms page, because **the terms that matter here (E3) are
the ones in force on the owner's own generation dates, which no current page
can prove.**

---

## 11. Scope and boundary

- **This is not legal advice** and contains no legal conclusion. §4.2 exists to
  keep the owner's statement, the repository's evidence, and any legal question
  visibly separate.
- **It does not adopt, extend or narrow the owner's ruling.** The sentence in
  §4.1 is reproduced exactly and nothing is inferred from it.
- **It creates no record, template, manifest or annotation** — §7 describes
  four and creates none.
- **It edits no asset, code, manifest, licence or design file.**
- **It blocks nothing for a private friends build.** Two items are P0 for wider
  distribution, and both are answerable in minutes by the person who knows.
