# V2 environment design dossier (2026-10-08)

Evidence class: **INERT**

Review-and-design packet for every discrete area of the Orison V2, the street
and the attached playable areas, captured from build `fdf01a36` on main and
redesigned room by room. It is addressed to the owner and to the implementing
agents (ChatGPT/Codex). It changes no code, no data and no ledger status.

## Deliverables

| File | What it is |
|---|---|
| `V2_environment_design_dossier.pdf` | The dossier: front matter, level plans with capture stations, the complete area checklist, then one section per area (identity, captioned evidence, observed versus interpretation, room narrative, proposed backstory, numbered changes, implementation and acceptance). |
| `dossier.html` | Offline companion with the same content and full-size tiles. |
| `dossier.json` | The complete machine-readable document (`orison.environment-design-dossier.v1`). |
| `change_register.csv` / `.xlsx` / `.json` | The editable change register: one row per numbered change with stable ids (`<SPACE_ID>-nnn`, `CITY_*-nnn`, `BW-nnn`), priority, action, objects, placement, dimensions, construction, materials, wear, lighting, sound, purpose, sources, dependencies, preserve, acceptance, and empty `status` / `owner_notes` columns. |
| `coverage_checklist.csv` | Every area with its coverage class (inspected, partial, inaccessible_teleported, unreviewed), view count and change count. |
| `census.json` | Per-space inventory from the blockout anchors and installed data (`sources/build_census.py`). |
| `review_notes.json` | Image-review notes merged from the contact-sheet reviews (`sources/merge_reviews.py`). |
| `plans/plan_*.png` | Per-level plans drawn from the blockout with the capture stations. |
| `images/` | 640 px JPEG review tiles, one per captioned view. |
| `evidence/` | Sweep records (`sweep_run1.json`, `sweep_run2.json`), runtime node census, run receipts and logs, the copied-local-asset manifest and the full-resolution capture inventory (SHA-256 of 1,202 PNGs retained locally at `C:/ov/envdossier_out/<run>/shots`). |
| `sources/` | The capture scene (`orison_v2_environment_dossier_sweep.gd` + `.tscn`), the stage script, the census, plan, sheet and merge builders. |
| `content/` | The authored content modules the builder reads (`front_matter.py`, `_common.py`, `areas_*.py`). |

Rebuild with `python build_dossier.py` (ReportLab, Pillow, pypdf; openpyxl for
the XLSX). `pdf_validation.json` records the page count and the file hash.

## How the evidence was made

The capture scene extends `OrisonV2CitySweep` and was installed temporarily in
`game/tests/` of a detached capture worktree at the same commit
(`C:/ov/envdossier`), then removed. Per semantic space it records an overview,
a reverse view, a threshold view from outside the principal door (the leaf is
opened by the ordinary door interaction when not locked and closed again) and
up to three detail views toward authored anchors, runtime props, windows or
doors; with `DOSSIER_CITY=1` it adds the city sweep's shop, bar, floor-survey
and street stations plus bodega, alley, facade and subway views. Both long
runs went through the lane broker and wrote `suite_run` receipts. Campaign time
was frozen at 1928-11-10 20:00; production fixtures as authored; player lamp
on; carried set hidden. Every frame is a teleported inspection station, not a
played route; nothing here is a runtime contract or an acceptance.

The capture worktree needed the gitignored machine-local runtime textures
copied from the canonical checkout at the same commit; their hashes are in
`evidence/copied_local_assets.json`.

## Reading the register

Priority P1 = reads wrong from the doorway or the resident is not legible;
P2 = strengthens story, period truth or the Shenmue test; P3 = polish.
Action = add / move / refine / remove / keep. `BW-nnn` changes are
building-wide families cited by many rooms; fix the family, not the room.
Proposed backstory is labelled on every page and collected in the front
matter; none of it is canon until ruled.
