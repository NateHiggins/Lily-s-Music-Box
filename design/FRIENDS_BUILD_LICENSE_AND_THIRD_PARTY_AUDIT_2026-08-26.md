# Friends-build licence and third-party rights audit — 2026-08-26

**Purpose:** what `LICENSE.txt` can honestly contain, given what the friends
build actually ships. `tools/package_friends_build.ps1` now requires an
owner-supplied `-LicensePath` and deliberately refuses to invent one. This
audit is about what that file has to say.

**Base:** `4b4a01638e5c80488c0e2327ea2ed1ce69847a77` (pushed `origin/main`).

**Godot was not used, launched, imported, or inspected through.** No code, data,
scene, tool, `TASKS.md` or existing document was edited.

> ## Stop rule
>
> **Missing evidence is UNKNOWN or BLOCK. It is never permission.** No licence
> is inferred from a filename, a folder name, a website's reputation, or the
> word "free". Where a right is claimed, this document names the file, the
> manifest, or the upstream licence text that grants it — and where it cannot,
> it says so and stops.

---

## 1. Executive ruling

**A `LICENSE.txt` containing only a statement about Nate's own work would be
incomplete, and one of the omissions is a breach rather than an oversight.**

The build bundles the **Courier Prime** typeface under the **SIL Open Font
License 1.1**, whose clause 2 requires that *"each copy contains the above
copyright notice and this license"* — text that is already sitting in the
repository at `game/assets/fonts/courier_prime/OFL.txt` and **is not currently
in the payload**. The font is baked into the `.pck`, so it ships.

Three further obligations are real and cheap: **Godot's MIT notice**, the
**eight CC BY 4.0 Freesound derivatives**, and the fact that the seven **CC0**
sounds need no notice but should be recorded so nobody re-litigates them.

**Three shipped families are UNKNOWN by the project's own records** — the 75
music files, the 34 voice takes, and the AI-generated texture corpus — and one
of those, the music, is UNKNOWN *because the project's own manifests say so*,
carrying unfilled `OWNER:` fields including legal status.

**The owner has not chosen a licence for the original work, and this document
does not choose one.** §6 lays out the options.

---

## 2. Category audit

Every row traces to a file in this repository or to a primary source in §11.

| # | Category | What ships | Evidence | Obligation | Friends-build status |
| --- | --- | --- | --- | --- | --- |
| 1 | **Original project code and content** | all GDScript, scenes, data, layout, writing | the repository; **no `LICENSE` file exists anywhere** (`git ls-files` finds none) | none imposed on us; **we impose nothing on the tester either** | **OWNER DECISION — §6** |
| 2 | **Godot engine / runtime** | the exported `.exe` embeds the engine | **MIT**, official **[S1]** | *"required to include the copyright notice and license statement somewhere in your documentation"*; a link to `godotengine.org/license` is *"an acceptable way to satisfy the license terms"* **[S1]** | **NEEDS NOTICE** |
| 3 | **Godot's own bundled third-party components** | FreeType, etc., inside the runtime | not enumerable without running Godot | Godot's guidance is the link in row 2; the engine also exposes `Engine.get_license_text()` / `get_copyright_info()` | **NEEDS NOTICE (satisfied by row 2's link)**; full enumeration **UNKNOWN — see §9** |
| 4 | **Addons / libraries** | — | **there is no `game/addons` directory** | none | **GREEN — nothing to do** |
| 5 | **Fonts — Courier Prime** | `CourierPrime-Regular.ttf`, `-Bold.ttf`, baked into the `.pck` | `game/assets/fonts/courier_prime/OFL.txt`; used at `ui/telegram_style.gd:9,11` | **OFL 1.1 clause 2: "each copy contains the above copyright notice and this license"**, as a stand-alone text file, header, or metadata field *"as long as those fields can be easily viewed by the user"* | **NEEDS NOTICE — MANDATORY** |
| 6 | **Audio — Freesound CC0** | 7 source recordings, processed into shipped `.ogg` | `game/assets/audio/freesound/ATTRIBUTION.md` §CC0, each with contributor, title and `freesound.org/s/<id>` URL | none legally required | **GREEN** (record anyway) |
| 7 | **Audio — Freesound CC BY 4.0** | 8 source recordings, processed into shipped `.ogg` | same manifest, §"Creative Commons Attribution 4.0" | **attribution required in the distributed work** | **NEEDS NOTICE** |
| 8 | **Audio — Freesound NonCommercial** | **nothing** | manifest: files marked excluded *"are not referenced by the game because their noncommercial license is incompatible with a potentially commercial release"* | n/a if truly absent | **GREEN, pending one check — §9 U1** |
| 9 | **Audio — music** | **75 files** under `assets/audio/music` (tracks + `.webp` covers) | `art/audio/*.MANIFEST.md` — Gemini/Lyria generations from **public-domain scores**, with the standing rule to *"never upload, link, hum or otherwise reference any historical recording, ever"* | **the manifests themselves carry unresolved `OWNER:` fields**, including `legal status`, `prompt used`, `model displayed`, `synthid / ai disclosure` | **UNKNOWN — §6 O3** |
| 10 | **Audio — voice** | **34 `mina_c01_*.ogg`** takes | the files; **no README, manifest or provenance note beside them**, and no design document names a performer, a method or a rights basis | unknown until the source is named | **UNKNOWN — §6 O4** |
| 11 | **Audio — `viral_seed.ogg`** | 1 file, preloaded by `audio/virus_sound_director.gd:9` | the file; **no provenance note found** | unknown | **UNKNOWN** |
| 12 | **Textures / materials** | the shipped texture corpus | `design/MATERIAL_PROMPT_SHEET.md` documents a **Gemini** image-generation pipeline with per-slot prompts | governed by the generating service's terms at time of generation, which are not recorded in-tree | **UNKNOWN — §6 O5** |
| 13 | **Reference-derived work** | period signage, notices, fixtures | `design/PROP_REFERENCE_NOTES.md`, patent/history research documents | research **about** sources, not copies of them — but not verified image-by-image | **UNKNOWN, low risk — §9 U3** |
| 14 | **Bundled arcade packages** | 6+ `.swcpkg` under `assets/arcade/packages/`, shipped via `include_filter="*.swcpkg"` | an **in-house** format (`arcade/swc_package_source.gd`) | appear original; **no provenance manifest exists** | **UNKNOWN, presumed original — §9 U4** |
| 15 | **Excluded from the export** | `tests/*`, `docs/*`, `assets/audio/freesound/source/*`, `assets/audio/soundbits/*`, source/preview sky textures | `game/export_presets.cfg` `exclude_filter` | n/a | **GREEN — correctly out** |

**The export filter already does real rights work**: it keeps the Freesound
**source** recordings and the `soundbits` family out of the payload. Only the
processed derivatives ship.

---

## 3. What the export filter does *not* do

`exclude_filter` removes `assets/audio/freesound/source/*` — **but
`ATTRIBUTION.md` itself is inside `assets/audio/freesound/` and is not
excluded**, so the attribution manifest is very likely already inside the
`.pck`. **That is not a substitute for a notice**: a file inside a packed
archive is not something a tester can "easily view", which is the standard OFL
clause 2 sets. It is a happy accident, not compliance.

---

## 4. Proposed `LICENSE.txt` structure

Minimal, and complete for what actually ships. **Bracketed lines are owner
decisions, not defaults.**

```
PLEASE REMAIN ON THE LINE — friends build <NNN>
Version 0.1.0

────────────────────────────────────────────────────────────────
1. THIS GAME
────────────────────────────────────────────────────────────────
Copyright (c) 2026 [OWNER LEGAL NAME OR ENTITY].

[ONE OF THE OPTIONS IN §6 — the owner chooses. Nothing here yet.]

This is a private test build. Please do not redistribute it.

────────────────────────────────────────────────────────────────
2. GAME ENGINE
────────────────────────────────────────────────────────────────
Made with Godot Engine, copyright (c) 2014-present Godot Engine
contributors, copyright (c) 2007-2014 Juan Linietsky, Ariel Manzur.
Licensed under the MIT licence. Full licence text and the licences
of Godot's own third-party components:
    https://godotengine.org/license/

────────────────────────────────────────────────────────────────
3. TYPEFACE
────────────────────────────────────────────────────────────────
Courier Prime.
Copyright 2015 The Courier Prime Project Authors
(https://github.com/quoteunquoteapps/CourierPrime).
Licensed under the SIL Open Font License, Version 1.1.

[VERBATIM OFL 1.1 TEXT — copy from
 game/assets/fonts/courier_prime/OFL.txt, unaltered]

────────────────────────────────────────────────────────────────
4. SOUND
────────────────────────────────────────────────────────────────
Some ambience is built from recordings published on Freesound.org
and used under Creative Commons licences. Attribution, with the
original title, contributor and link, for every CC BY 4.0 source:

[THE EIGHT CC BY 4.0 ENTRIES, copied from
 game/assets/audio/freesound/ATTRIBUTION.md]

The following are CC0 1.0 and require no attribution; they are
listed for completeness:

[THE SEVEN CC0 ENTRIES]

────────────────────────────────────────────────────────────────
5. EVERYTHING ELSE
────────────────────────────────────────────────────────────────
[Music, voice and generated art: see §6 O3-O5. Nothing may be
 written here until those are answered. An empty section is
 correct; an invented sentence is not.]
```

**Section 3 is the one that cannot be trimmed.** OFL clause 2 asks for the
notice *and* the licence, and the licence is ~4.5 KB. That is the whole reason
`LICENSE.txt` cannot be four lines.

---

## 5. Proposed `THIRD_PARTY_NOTICES.txt` structure

**Separation is cleaner and I would recommend it — but it costs a payload slot
(§7).** If the owner prefers it:

```
LICENSE.txt                 §1 only: the game, its copyright, its terms
THIRD_PARTY_NOTICES.txt     §2 engine · §3 typeface + OFL · §4 sound
                            · §5 reserved
```

**Why separate is better:** the game's own terms are the thing a tester actually
needs to read, and burying them above 4.5 KB of font licence guarantees nobody
does. **Why combined is defensible:** it keeps the five-file contract intact,
and OFL clause 2 does not care which file the text is in — only that a copy
accompanies the software and is easily viewable.

---

## 6. Owner decisions

### O1 — the licence for the original work

**Not chosen here.** The realistic options, with consequences:

| Option | What it means | Consequence for a friends build |
| --- | --- | --- |
| **All rights reserved / private testing only** | no rights granted beyond running this build; no redistribution | **Simplest and most reversible.** Says exactly what is true of a friends build. Forecloses nothing later. |
| **Proprietary EULA** | a written grant with named permissions and limits | More formal; needs drafting and arguably legal review; more than a six-person cohort requires |
| **A permissive open licence (MIT/Apache-2.0)** | anyone may reuse the code | **Irreversible for anything already published.** Would also raise the third-party questions in rows 9–14 far more sharply |
| **A copyleft licence (GPL family)** | derivatives must carry the same terms | Same irreversibility; interacts with commercial plans |
| **Source-available / shared-source** | published but restricted | Middle ground; needs bespoke drafting |

**Nothing about a private friends build requires more than the first option**,
and the first option is the only one that preserves every later choice. That is
an observation, not a recommendation — the ruling is the owner's.

### O2 — combined `LICENSE.txt`, or a separate notices file (§5, §7)

### O3 — music provenance
The `art/audio/*.MANIFEST.md` files carry unfilled `OWNER:` fields —
`prompt used`, `model displayed`, `gemini/lyria product`,
`synthid / ai disclosure`, and `legal status`. **The project's own record says
this is unresolved.** Also unresolved: `ORISON_SONGBOOK_GEMINI_LYRIA_HOUSE_FIVE.md`
states some tracks *"carry consultation notices… those reviews gate the
shipping master, not the private instrumental audition."* **Is a friends build a
private audition or a distribution?** It is handed to third parties, so I would
treat it as the latter — owner's call.

### O4 — voice takes
34 `mina_c01_*.ogg` files ship with **no provenance record of any kind**. Who
performed them, how, and under what agreement is unrecorded. Until answered,
this is the least-documented shipped family in the build.

### O5 — generated textures
Terms of the generating service **at the time of generation** are not recorded
in-tree. Worth capturing now while it is still reconstructible.

### O6 — the entity named in the copyright line
Same question as the distribution runbook's signing entity.

---

## 7. Consequence for the five-file payload contract

`tools/package_friends_build.ps1:108–111` enforces exactly:

```
BUILD_ID.txt · LICENSE.txt · PleaseRemainOnTheLine.exe
PleaseRemainOnTheLine.pck · README_TESTER.txt
```

and throws *"Staging directory violates the five-file artifact contract."*
otherwise.

**Two ways to satisfy the obligations, and they are not equivalent:**

| | Payload | Consequence |
| --- | --- | --- |
| **A — combined** | five files, unchanged | `LICENSE.txt` becomes ~7–8 KB: game terms, engine notice, full OFL text, sixteen sound credits. **The packager needs no change at all.** |
| **B — separated** | **six files** | Cleaner to read. **`$expected` must gain `THIRD_PARTY_NOTICES.txt`**, and the contract becomes a six-file contract. |

**I did not edit the packager.** If the owner picks B, that array is the single
line that changes, and the check should stay strict — its value is that it fails
closed.

**Either way, `-LicensePath` is already the right design.** It refuses to
invent a licence, which is exactly the behaviour that made this audit necessary
rather than optional.

---

## 8. Machine-checkable manifest proposal

A data file mapping shipped path families to provenance and obligation, so that
"is this licensed?" becomes a test rather than a memory.

**Proposed `game/data/asset_provenance.json`** *(proposal only — not created)*:

```json
{
  "schema_version": 1,
  "families": [
    {
      "id": "font_courier_prime",
      "paths": ["assets/fonts/courier_prime/*.ttf"],
      "origin": "third_party",
      "license": "OFL-1.1",
      "license_text": "assets/fonts/courier_prime/OFL.txt",
      "notice_required": true,
      "attribution": "Copyright 2015 The Courier Prime Project Authors",
      "ships": true
    },
    {
      "id": "audio_freesound_ccby",
      "paths": ["assets/audio/freesound/processed/**"],
      "origin": "third_party",
      "license": "CC-BY-4.0",
      "license_text": "assets/audio/freesound/ATTRIBUTION.md",
      "notice_required": true,
      "ships": true
    },
    {
      "id": "audio_music",
      "paths": ["assets/audio/music/**"],
      "origin": "generated",
      "license": "UNKNOWN",
      "notice_required": null,
      "ships": true,
      "blocks_release": true,
      "note": "art/audio/*.MANIFEST.md carry unresolved OWNER: fields"
    }
  ]
}
```

**The two rules that give it teeth:**

1. **Every path that survives the export filter must match exactly one family.**
   An unmatched shipped path is a **BLOCK**, not a warning — that is how a new
   asset family gets licensed instead of silently shipping.
2. **No family with `license: "UNKNOWN"` and `ships: true` may pass** unless the
   owner has explicitly waived it for a private cohort, recorded in the file.

### Smallest packaging validation

A pre-package check, **before** the five-file assertion:

```
1. enumerate the paths the export filter would include
2. match each against asset_provenance.json
3. FAIL on any unmatched path                         (rule 1)
4. FAIL on any UNKNOWN family with ships:true         (rule 2)
5. FAIL if any family with notice_required:true has no
   corresponding section in the supplied -LicensePath file
```

**Step 5 is the one that matters most**, because it is the failure this audit
found: a font whose licence the repository already contains, in a payload that
does not carry it. A grep for `"Courier Prime"` and `"godotengine.org/license"`
in the licence file would have caught it.

---

## 9. Unknowns

| # | Unknown | Why it is not resolved here |
| --- | --- | --- |
| U1 | Whether any NonCommercial Freesound file is still referenced | The manifest **says** they are excluded. Verifying means matching every shipped `processed/` derivative to its named source — doable offline, not done |
| U2 | Godot's full bundled third-party component list | Enumerable only via `Engine.get_license_text()` / `get_copyright_info()`, which requires running the engine. Godot's own guidance (the link) covers it **[S1]** |
| U3 | Whether any shipped texture reproduces a copyrighted reference | Would need image-by-image review against `PROP_REFERENCE_NOTES.md` |
| U4 | `.swcpkg` provenance | In-house format, presumed original; no manifest exists |
| U5 | `viral_seed.ogg` provenance | No note anywhere |
| U6 | Whether `ATTRIBUTION.md` is inside the shipped `.pck` | The filter does not exclude it, so probably yes — **but it is not "easily viewable" either way** (§3) |
| U7 | The generating services' terms at generation time | Not recorded in-tree; reconstructible now, harder later |

---

## 10. Contradictions and corrections

**No contradiction found between existing documents.** Two corrections to my own
earlier work:

- `FRIENDS_BUILD_DISTRIBUTION_RUNBOOK_2026-08-26.md` §1 recorded **"LICENSE —
  ABSENT"** and §8 flagged third-party assets as *"UNKNOWN and out of scope
  here"*. Both were accurate; **this document supplies the scope that was
  deferred**, and upgrades the font from an unexamined risk to a **mandatory
  notice**.
- That runbook's §4 artifact contract lists `LICENSE.txt` as an owner action
  (O5) without specifying content. **§4 here is that content**, and §7 records
  that satisfying it may cost a sixth file.

**Canonical, going forward:** third-party rights and notice obligations →
**this document**. Channel and packaging → the runbook. Privacy → the privacy
audit. None of those three overlaps another.

---

## 11. Sources

| # | Source | Type | URL / path | Accessed | Supports |
| --- | --- | --- | --- | --- | --- |
| S1 | Godot Engine licence | official | https://godotengine.org/license/ | 2026-08-26 | MIT; *"required to include the copyright notice and license statement somewhere in your documentation"*; a link to that page is *"an acceptable way to satisfy the license terms"*; **no splash/logo requirement stated** |
| S2 | SIL Open Font License 1.1 | **in-tree primary** | `game/assets/fonts/courier_prime/OFL.txt` | in repo | clause 2 — *"each copy contains the above copyright notice and this license… as stand-alone text files, human-readable headers or in the appropriate machine-readable metadata fields… as long as those fields can be easily viewed by the user"*; copyright line: *"Copyright 2015 The Courier Prime Project Authors"* |
| S3 | Freesound attribution manifest | **in-tree primary** | `game/assets/audio/freesound/ATTRIBUTION.md` | in repo | 7 CC0 and 8 CC BY 4.0 entries with contributor, title and `freesound.org/s/<id>`; NC files marked excluded |
| S4 | Songbook generation manifests | **in-tree primary** | `art/audio/*.MANIFEST.md` | in repo | Gemini/Lyria generation from public-domain scores; **unresolved `OWNER:` fields incl. legal status** |
| S5 | House Five songbook book | **in-tree primary** | `design/ORISON_SONGBOOK_GEMINI_LYRIA_HOUSE_FIVE.md` | in repo | *"All five are rights-GREEN"*; consultation notices *"gate the shipping master, not the private instrumental audition"*; never reference a historical recording |
| S6 | Material prompt sheet | **in-tree primary** | `design/MATERIAL_PROMPT_SHEET.md` | in repo | the Gemini texture-generation pipeline |
| S7 | Export preset | **in-tree primary** | `game/export_presets.cfg` | in repo | the `exclude_filter`; `include_filter="*.swcpkg"` |
| S8 | Packager | **in-tree primary** | `tools/package_friends_build.ps1:9–10,80–111` | in repo | mandatory `-LicensePath`; the five-file `$expected` array and its throw |

**No licence was inferred from a filename, a folder name or a reputation.**
Every GREEN row above cites either an upstream licence text in the repository or
an official page in this table.

---

## What this document does not do

- It chooses no licence for the original work (§6 O1).
- It edits no packager, export preset, manifest, asset or existing document.
- It creates no `LICENSE.txt` — it proposes a structure the owner can approve.
- It treats no missing evidence as permission: five families are UNKNOWN and one
  category is BLOCK-shaped until an owner answers.
