# Critique run - 2026-09-18

Instructions given verbatim to each reviewer (seven reviewers, ten specimens
each, whole families kept together). Kept beside the critiques so the record
shows how they were produced.

## Where things are

Repository root: `C:/PleaseRemainOnTheLine-propref` (all paths below are
relative to it).

- Contract you are writing to: `tools/prop_reference/CRITIQUE_CONTRACT.md`.
  Read it first, completely.
- Index of every specimen: `art/renders/prop_reference_2026-09-18/comparison_index.json`.
  Each entry carries `id`, `kind`, `label`, `size_m`, `mount`,
  `installed_count`, `tier`, `reviewed_before`, `triangles`, `surfaces`,
  `flat_colour_share`, `material_names`, `frames_small` (our four bearings as
  JPEGs), `references` (title, licence, Commons URL, local path), `sheet`
  (the contact sheet), `real_object` and `queries`.
- What the real object was, what the script builds, and what must not be
  reopened: `tools/prop_reference/queries.json` under `kinds.<kind>`
  (`real_object`, `period_note`, `what_the_script_builds`,
  `materials_expected`, `distinguishing_features`, `already_ruled`,
  `verified`). A kind with `verified: false` had its queries authored but
  not adversarially checked; treat its `real_object` as a reading, not a
  ruling.
- The prop scripts: `game/scripts/props/<script>.gd`; `queries.json`
  names the script per kind. Read the header comment and the build function
  before writing a modelling bullet.
- The house reference notes: `design/PROP_REFERENCE_NOTES.md` (grep the
  script stem). The art brief and its rules: `design/PROP_ART_BRIEF.md`
  sections 3, 6 and 8.

## What to produce

One file per specimen at
`art/renders/prop_reference_2026-09-18/critiques/<id>.json`, exactly in the
shape the contract gives. `specimen` must equal the file name. Axes are
integers 0-5. `confidence` is `high`, `medium` or `low`.

## How to look, in order

1. Open the sheet (`sheet` path) with the image reader. Ours are the top
   row; references are below with licence in the caption. If a reference is
   plainly off-topic (a house, a poster, a tow truck), ignore it and do not
   list it under `references_used`.
2. If the sheet's thumbnails are too small to judge a detail, open the
   individual bearing under `frames_small` and, for references, the local
   file under `references[].local`.
3. Silhouette and proportion first, against the metres in the header. Then
   the parts a hand would reach. Then the surfaces (the `high_quarter` and
   `front` bearings show finish best). The census tells you how many
   surfaces carry an albedo map; the frames tell you whether the ones that
   do read as the right substance.
4. Check `already_ruled` before every bullet. Anything you would change but
   may not goes under `not_reopened`.
5. Write bullets a modeller can act on, with a dimension, a primitive count
   or a material key. "Improve the hinges" is not a bullet.
6. A specimen with `has_geometry: false` (porch deck, shop sign) drew
   nothing in the shed. These two were written by management from the
   scripts alone before the reviewers started: every axis 0, confidence
   `low`, the summary saying why the shed cannot show it. Reviewers skip
   them; the scorer lists them apart at zero priority.

## What not to do

- Do not edit any file other than your critique JSONs.
- Do not invent references; only titles that appear on the specimen's
  sheet or in its `references` list may be named.
- Do not score taste. Axes measure the gap to the reference, per the
  contract's table.
- Do not skip a specimen. Ten files in, ten files out.
