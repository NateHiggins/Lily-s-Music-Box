# Prop reference comparison

Photograph every prop in the inspection shed, fetch licence-clean reference
photographs of the real object, lay them side by side, critique the gap, and
rank the work. The output is a brief, in priority order, saying what to change
in the modelling and the texturing of each prop.

## Why the shed, and why one at a time

Props are built in GDScript from primitives and live in a dark building at
night. The warehouse (`game/scripts/building/prop_warehouse.gd`) already puts
one of everything on a labelled grid under flat light; `PropWarehouseShot`
adds the discipline a comparison needs: each specimen alone in frame, from five
fixed bearings (three-quarter, front, side, high three-quarter, and from behind,
because a prop that declares no `warehouse_rotation_y()` may face away from the
aisle), at a camera distance derived from its own bounds, so a kettle
and a boiler fill the frame the same way and a reference photograph of either
can sit beside it.

## Steps

1. **Photograph.** Needs a real window and the Godot lane (the serial runner
   refuses while any Godot process, including an idle editor, is open).

   ```
   mkdir C:\PleaseRemainOnTheLine\art\renders\prop_reference_<date>\full
   SHOT_DIR=C:\...\art\renders\prop_reference_<date>\full
   tools\run_godot_long_suite.ps1 -Scene res://tests/PropWarehouseShot.tscn -LogPath <log>
   ```

   Writes `warehouse_manifest.json` plus `<specimen>/<bearing>.png`. Per
   specimen the manifest records kind, plinth label (the variant), mount,
   bounds in metres and a material census: surfaces, textured surfaces,
   shader surfaces, flat-colour share, triangle count. `SHOT_WAREHOUSE_ONLY`
   restricts to a kind list; `SHOT_WAREHOUSE_KIND` builds one family.

2. **Fetch references.** Wikimedia Commons only, because every file carries a
   machine-readable licence. Permissive licences pass (public domain, CC0,
   CC BY, CC BY-SA); non-commercial, no-derivatives, fair-use and unlabelled
   files are refused and the refusal is recorded. Bytes land under
   `art/reference/props/_fetched/<specimen>/` with `provenance.json`
   (title, URL, licence, author, credit, query, SHA-256). That directory is
   git-ignored; the provenance record is what the repository keeps.

   ```
   python tools/prop_reference_tool.py fetch --manifest art/renders/prop_reference_<date>/full/warehouse_manifest.json
   ```

   Queries come from `queries.json`, authored per kind and per variant from
   the prop script and `design/PROP_REFERENCE_NOTES.md`, then adversarially
   checked against the geometry the script builds. Commons full-text search
   rewards plain nouns: when the authored phrases leave a specimen below
   `--min-files`, derived fallbacks (noun, noun + 1920s, + advertisement,
   + photograph) run and every file records whether a fallback found it.
   `--sparse-only` revisits only the specimens still short; `--kinds` limits
   a run to named kinds (clear a specimen's folder first if its queries
   changed, because a re-run only fills gaps up to `--max-files`).

3. **Sheets.** One contact sheet per specimen (ours above, references below,
   facts in the header) beside the references, plus 640 px JPEG copies of our
   frames under the review directory and `comparison_index.json`.

   ```
   python tools/prop_reference_tool.py sheets --manifest ... --out art/renders/prop_reference_<date>
   ```

4. **Critique.** The review pass reads each sheet and writes one JSON per
   specimen into `critiques/` (axes 0-5 for object class, proportion,
   silhouette, detail, material, wear, mount; modelling and texturing
   bullets; effort; confidence). The critique is judgement; everything else
   here is measurement.

5. **Check, score and brief.** `check` validates every critique against
   `CRITIQUE_CONTRACT.md` and names the specimens still without one; the
   scorer refuses nothing, so run the check first.

   ```
   python tools/prop_reference_tool.py check --index .../comparison_index.json --critiques .../critiques
   ```

   Then score and render:

   ```
   python tools/prop_reference_tool.py score --index .../comparison_index.json --critiques .../critiques --out .../ranking.json
   python tools/prop_reference_tool.py brief --ranking .../ranking.json --out design/PROP_MODELING_TEXTURING_BRIEF_<date>.md --date <date> --preface .../preface.md
   ```

   `--preface` inserts a markdown file after the header: how the run was
   made, what the instrument found, and the limits of the pass.

   Priority = tier weight x installed factor x measured gap, discounted for a
   family a completed review already served unless its gap is still large;
   wholly flat-coloured specimens and specimens that drew nothing are pushed
   up. Tiers come from `tiers.json`, which mirrors `PROP_ART_BRIEF.md` and
   `PROP_ACTIVITIES.md`; installed counts are read from the layout, never
   typed in.

## Rules this tool obeys

- Third-party imagery is reference, not asset. It never enters an export, a
  texture, or git. Attribution lives in `provenance.json` and is cited by
  URL in the brief.
- The brief is named `BRIEF` so the completeness ledger refuses it as
  evidence; check with `--evidence-impact` before committing any design doc.
- Verify by rendering. A material census says what is flat colour; it does
  not say what looks wrong. The frames do.

Tests: `python tools/tests/test_prop_reference.py` (no network).

## Family review, before and after a rebuild

Props are being regenerated in Blender family by family (RUL-006). Each
family gets the same three steps, so the evidence for "this family is better"
is a set of files rather than an impression.

1. **Shoot before and after.** Same shed, same bearings, only the named
   kinds photographed. A tag directory is never overwritten.

   ```
   python tools/prop_reference_tool.py shoot --kinds stove --out art/renders/stove_review --tag before
   python tools/prop_reference_tool.py shoot --kinds stove --out art/renders/stove_review --tag after
   ```

2. **Pair them.** One sheet per specimen (before row over after row), a
   pixel-change value per bearing, and the census before and after.

   ```
   python tools/prop_reference_tool.py pair --before art/renders/stove_review/before \
       --after art/renders/stove_review/after --out art/renders/stove_review/pair
   ```

   Two shoots of an unchanged family measured at most 0.0004 per bearing on
   2026-09-18, so the default flag threshold of 0.01 is far above the shed's
   noise. Flags: `unchanged`, `census changed but no bearing shows it` (the
   change is invisible from the shed: check the bearings and the registration),
   `new specimen`, `specimen gone`, and a missing bearing on one side.

3. **Re-score and diff.** Rewrite the family's critiques against the new
   frames under `CRITIQUE_CONTRACT.md`, re-run `score`, then compare the two
   runs axis by axis:

   ```
   python tools/prop_reference_tool.py diff --before art/renders/prop_reference_2026-09-18 \
       --after art/renders/prop_reference_<new date> --kinds stove --out art/renders/stove_review/diff.md
   ```

The pixel change says something moved; only the critique says it moved
closer to the real object. The installed before/after render under the
building's own light is still required, because the shed is a lightbox.
