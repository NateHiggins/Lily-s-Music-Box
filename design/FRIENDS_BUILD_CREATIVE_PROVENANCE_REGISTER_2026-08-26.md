# Friends-build creative provenance register — 2026-08-26

**Purpose:** turn `FRIENDS_BUILD_LICENSE_AND_THIRD_PARTY_AUDIT_2026-08-26.md`'s
unresolved creator questions into records an owner can actually answer.

**Base:** `4272189ff6fbde321412d022bb55f1f5bf421157` (pushed `origin/main`,
"Codify the Orison owner voice"). ADMIN-LIC1 is integrated at `1e5dc76`.

**Godot was not run.** No existing asset, code, manifest, licence or design file
was edited.

> **OWNER CORRECTION — 2026-08-26, after listening to the files:** “these are
> text to voice samples.” The 34 then-shipped Ogg files are therefore classified as
> **temporary text-to-voice samples, not human recordings**. The TTS product and
> terms remain unrecorded. The original git
> commit's phrase “The recording session came back” is not evidence of a
> performer and must not be used to reconstruct one. Sections 1, 3, 5, 6 and 8
> below incorporate this correction.
>
> **OWNER DISPOSITION — 2026-08-26:** “these not useful and should be
> discarded.” All 34 tracked TTS samples were removed. They no longer ship.
> Their filenames remain below as historical audit evidence and as reserved ids
> for future production takes; they are not a current asset family.
>
> **IMPLEMENTATION UPDATE — 2026-08-26:** `music_catalog.json` now declares
> `tracks.*.provenance` as `in_world_fiction` in a root-level
> `field_semantics` record. Its `rights_record` is explicitly null and the
> warning bars creator, licence, attribution and distribution-authority
> inference. `tools/audit_music_catalog.py` fails closed if that boundary moves.

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

1. **The 34 former Mina voice files were temporary text-to-voice samples.** The owner
   identified them after listening. Git's *“The recording session came back”*
   wording (`62ca805`, 2026-08-02) described a technical delivery as though it
   were a human performance; it did not establish one. Their TTS product/terms
   are **UNKNOWN**, but there is no human performer or performer agreement to
   chase. The owner rejected and removed them; they no longer ship. §5 records
   the correction and disposition.
2. **The music** — 36 library tracks, 3 title tracks, 36 cover images, all
   shipping — now has an owner ruling, recorded verbatim in §4. **What it does
   not have is date/version evidence of the provider terms it depends on.**
3. **`music_catalog.json` has a field literally named `provenance`, and it
   contains in-world fiction** — invented bands, invented years, invented
   pressing histories. It is excellent writing and it is **not a rights
   record**. A future audit or script reading that field by name would draw a
   confident wrong conclusion. **This was the single most dangerous artefact in
   the register and is now explicitly classified.**
4. **Manifest coverage is far narrower than it looks.** Four
   `art/audio/*.MANIFEST.md` files exist; **only one corresponds to shipped
   audio** (`The_Clockwork_Waltz` → the two `music/title/clockwork_waltz_*.ogg`
   files). The other three document songbook candidates that **do not ship**,
   and **35 of the 39 shipped tracks have no manifest at all**.

**Nothing here blocks a private friends build on its own.** Every row has a
disposition, and most are "ship with the record filled in afterwards". The two
original P0 findings are now resolved (§8).

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

The original version of this section used a fifteen-column Markdown table. It
was technically valid and functionally unreadable in a normal-width viewer.
The compact index below carries only comparison fields; complete evidence is in
the numbered records that follow.

| # | Family | Ships | Count | Status |
| ---: | --- | :---: | ---: | --- |
| 1 | Former Mina TTS samples | no | 0 current | GREEN — removed |
| 2 | Music, library | yes | 36 | P1 — provider evidence |
| 3 | Music, title | yes | 3 | P1 — provider evidence |
| 4 | Music covers | yes | 36 | P1 — method unrecorded |
| 5 | Catalogue `provenance` fiction | yes | 36 fields | GREEN — classified |
| 6 | Textures and materials | mostly | large | P1 — terms evidence |
| 7 | `viral_seed.ogg` | yes | 1 | P2 — name input |
| 8 | Freesound CC BY 4.0 | yes | 8 sources | GREEN — notice required |
| 9 | Freesound CC0 | yes | 7 sources | GREEN |
| 10 | Courier Prime | yes | 2 fonts | GREEN — notice required |
| 11 | Godot runtime | yes | 1 runtime | GREEN — notice required |
| 12 | Arcade packages | yes | 6+ | P2 — authorship record |
| 13 | Raw voice sources | no | unknown | not shipped |
| 14 | Songbook candidates | no | 3 | not shipped |

### 3.0.1 Former Mina TTS samples

- **Path:** `assets/audio/voice/mina_c01_*.ogg`
- **Payload:** removed; 0 current files, 34 historical files recoverable from
  git history.
- **Creator/method:** no human performer; text-to-voice product unknown.
- **Date evidence:** added in `62ca805` on 2026-08-02; removed by owner ruling
  on 2026-08-26.
- **Authority/attribution/modification:** immaterial to the current payload.
- **Confidence/disposition:** HIGH; GREEN because absent.

### 3.0.2 Music — library and title

- **Paths/counts:** `assets/audio/music/library/*.ogg` (36) and
  `assets/audio/music/title/*.ogg` (3); all ship.
- **Creator/method:** owner-created with Gemini, per the owner statement in §4.
- **Evidence:** owner statement only. Catalogue `year` values are in-world
  fiction. One title family has a 2026-08-14 manifest with unfilled `OWNER:`
  fields; 35 of the 39 shipped tracks have no manifest.
- **Authority:** owner-stated; provider date/version evidence is not in-tree.
- **Attribution/modification:** none stated / not established.
- **Confidence/disposition:** MEDIUM; P1 under §4.

### 3.0.3 Music covers

- **Path/count:** `assets/audio/music/covers/*.webp`; 36; all ship.
- **Creator/method:** UNRECORDED. No prompt sheet, manifest or note was found.
- **Date evidence:** first appeared in merge commit `653316e`.
- **Agreement/authority/attribution/modification:** UNKNOWN.
- **Sources:** none recorded in the repository.
- **Confidence/disposition:** LOW; P1.

### 3.0.4 Catalogue provenance field

- **Path/count:** `game/data/music_catalog.json`; 36 `provenance` fields; ships
  as data.
- **Creator/method:** authored in-world fiction.
- **Known fact:** HIGH confidence that these are invented bands, years and
  histories—not rights evidence.
- **Disposition:** RESOLVED; schema-level classification preserves the fiction
  while barring rights inference, as detailed in §7.

### 3.0.5 Textures and materials

- **Path/payload:** `assets/building/textures/**`; ships except for six named sky
  exclusions.
- **Creator/method:** owner-directed Gemini image generation per
  `design/MATERIAL_PROMPT_SHEET.md`.
- **Evidence:** prompt sheet exists; individual asset dates and provider terms
  are not recorded in-tree.
- **Authority/attribution/modification:** UNKNOWN. Some source PNGs are excluded.
- **Confidence/disposition:** LOW–MEDIUM; P1.

### 3.0.6 Viral seed

- **Path/count:** `assets/audio/viral_seed.ogg`; one shipped file.
- **Creator/method:** repository-native, generated deterministically by
  `art/audio/build_viral_seed.py` from a WAV input.
- **Evidence:** tool tracked; input WAV unidentified.
- **Authority:** follows the unidentified input.
- **Confidence/disposition:** MEDIUM; P2—name the input.

### 3.0.7 Freesound derivatives

- **Path:** `assets/audio/freesound/processed/**`; ships.
- **CC BY 4.0:** 8 named sources. `ATTRIBUTION.md` is complete; attribution is
  required and modification is permitted. GREEN with notice.
- **CC0:** 7 named sources. Recorded in the same manifest; attribution is not
  required and modification is permitted. GREEN.
- **Raw sources:** `source/` is excluded from the payload.
- **Confidence:** HIGH.

### 3.0.8 Courier Prime

- **Path/count:** `assets/fonts/courier_prime/*.ttf`; two fonts inside the PCK.
- **Creator:** The Courier Prime Project Authors.
- **Evidence/authority:** in-tree `OFL.txt`; commercial use and modification
  permitted subject to the reserved name.
- **Attribution:** OFL clause 2 notice REQUIRED.
- **Confidence/disposition:** HIGH; GREEN with notice per ADMIN-LIC1.

### 3.0.9 Godot runtime

- **Payload:** included inside the executable.
- **Creator/licence:** Godot contributors; MIT.
- **Authority/modification:** permitted.
- **Attribution:** notice REQUIRED; official licence page is the evidence.
- **Confidence/disposition:** HIGH; GREEN with notice.

### 3.0.10 Arcade packages

- **Path/count:** `assets/arcade/packages/*.swcpkg`; 6+; explicitly included by
  `include_filter="*.swcpkg"`.
- **Creator:** UNRECORDED, presumed owner.
- **Method:** in-house format implemented by `arcade/swc_package_source.gd`.
- **Agreement/evidence:** none found.
- **Confidence/disposition:** LOW; P2—record authorship.

### 3.0.11 Families that do not ship

- **Raw voice sources:** `assets/audio/voice/source/`; gitignored; count unknown.
- **Songbook candidates:** three `art/audio/*.MANIFEST.md` records; owner-created
  with Gemini/Lyria, dated 2026-08-14, with unfilled `OWNER:` fields. Do not
  conflate them with the shipped library/title families.

### 3.1 One-row-per-file: the 34 Mina TTS samples

**No performer agreement is expected because the owner states these are not
voice recordings.** What is mechanically proven is that **all 34 entered the
repository in a single commit**, `62ca805`, whose message describes one
“session.” That noun meant a batch/delivery here, not a human performance.

**They remain one historical placeholder family with 34 former members, now
removed.** Identifying the obsolete TTS product is optional archaeology, not a
release dependency. Replacement production performances will require their own
new provenance record and must not inherit this placeholder classification.

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

## 5. The Mina TTS-sample correction

Owner statements, recorded in sequence: **“there is no voice recordings yet,
those are placeholders i think”**, followed after audition by **“these are text
to voice samples.”** The second statement resolves the generation family.

This settles the important negative: do not invent a performer, session, or
agreement from the existence of playable speech files. It leaves three small
technical facts open:

1. Which TTS/text-to-voice product and tier produced them?
2. Do the gitignored source files still exist, and do they preserve product,
   settings, generation dates or terms evidence?
3. ~~Should friends builds retain TTS sample speech?~~ **Resolved: no. The owner
   found the samples not useful and ordered them discarded. Mina ships unvoiced
   until production casting.**

The third is a quality/disclosure ruling, not a rights inference. When real
voice production begins, create a fresh performer/terms/credit/source record;
do not edit this placeholder history into a fictional recording session.

---

## 6. Unknown is not forbidden — dispositions

Every unknown, with what happens to it for a **private friends build**.

| Family | Unknown | Friends-build disposition |
| --- | --- | --- |
| Former Mina TTS samples | none for current payload | **DO NOT SHIP — resolved and removed by owner.** Production casting creates a new record. |
| Music | provider terms evidence | **SHIP under the owner's recorded ruling (§4.1).** Collect E1–E4 while reconstructible. |
| Covers | method entirely unrecorded | **SHIP, record method.** Same workflow question as the tracks; ask once, answer both. |
| Textures | provider terms at generation | **SHIP, record.** Largest family, lowest per-item risk. |
| `provenance` field | none remaining | **RESOLVED:** ships as game content with an explicit `in_world_fiction` classification (§7). |
| `.swcpkg` | authorship unrecorded | **SHIP, presumed owner-created.** Confirm in one line. |
| `viral_seed.ogg` input | source WAV unidentified | **SHIP.** Name the input when convenient. |

**No family is BLOCKED for a friends build.** The two original P0 findings have
been resolved: the TTS samples were removed and the lore field was classified.

---

## 7. Repository records — one implemented, three proposed

Four small records were identified. The audit created none; the later catalogue
classification in item 3 is now implemented.

1. **`design/VOICE_PROVENANCE.md`** — §5's answers, once. Performer, agreement
   location, scope, credit preference, source-take location. Ten lines.
2. **`art/audio/MUSIC_PROVENANCE.md`** — E1–E6 in one table for all 39 shipped
   tracks plus the 36 covers, replacing the pattern where four manifests cover
   one shipped file.
3. **IMPLEMENTED — schema annotation on the misleading field.** A root-level
   semantic record avoids duplicating a warning across 36 tracks and changes no
   existing consumer:
   ```
   "field_semantics": {
     "tracks.*.provenance": {
       "classification": "in_world_fiction",
       "rights_record": null,
       "warning": "Never use this field to infer rights facts."
     }
   }
   ```
   `tools/audit_music_catalog.py` guards this boundary and all 36 required track
   records. `rights_record` remains null until a real machine-readable record
   exists.
4. **Extend `asset_provenance.json`** (proposed in ADMIN-LIC1 §8) with a
   `creator`, `method` and `evidence` field per family, so the machine check
   covers *who made it* and not only *what licence it carries*.

---

## 8. Blockers, ranked

**P0 — resolved**

| | |
| --- | --- |
| **P0-1** | **RESOLVED:** `field_semantics` classifies the field as in-world fiction and `audit_music_catalog.py` prevents rights inference. §7.3. |

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
- **The original audit created no record, template, manifest or annotation.** A
  later implementation added only the catalogue semantic boundary and its
  validator; the broader provenance records in §7 remain proposed.
- **The original audit edited no asset, code, manifest, licence or design file.**
- **It blocks nothing for a private friends build.** Both original P0 findings
  are resolved; remaining unknowns retain explicit dispositions.
