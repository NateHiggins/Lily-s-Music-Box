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
| `content/status.py` | Implementation status per change id (`proposed`, `implemented`, `verified`, `deferred`, `rejected`) with the owner note and evidence pointer; the builder overlays it on the register (`python build_dossier.py --register-only` rewrites the register without the PDF). |
| `implementation/<slice>/` | Verification evidence for implemented changes: captures (1280 px JPEG), the fabrication `batch.json`, run receipts, sweep records and a SHA-256 manifest. INERT, never runtime proof. |

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

## Implementation

Changes are implemented in slices on this branch. Each slice edits the
authoring sources (never generated glTF or runtime JSON by hand), re-projects
(`tools/build_v2_completion_interiors.py` and kin), rebuilds touched Blender
families with `art/blender/scripts/run_fabrication_batch.py`, then verifies in
a short-path worktree: the fabrication batch for the touched modules, the
route suites that cross the changed rooms (pointer suites need `-Windowed`),
and this packet's sweep scene over the changed spaces. The register's
`status` column and `implementation/<slice>/` record the outcome.

Slices landed so far (evidence folders in parentheses):

1. Fridge count, living-room pendants, 4D closet lock (`slice1`, `slice1b`,
   `baths` for the water-closet measurements).
2. Second beds out, radios in six homes, moves and sign fixes (`slice2`,
   `slice2b`, `slice2c`).
3. Public-hall flush domes on landlord switches, enamel unit numerals on the
   entry leaves, 5C stance moves (`slice3b`, `numerals`, `numerals2`).
4. Period furniture forms: pedestal round tables, rolled sofa arms, oak shelf
   posts (`slice34`).
5. Bath tile on one face only (a far-face skin on interior wet walls) and
   room leaves a step lower (`slice5`, `slice5b`; `skinbase` is the pre-skin
   comparison, `floorbase` the pre-skin floor-surface baseline).
6. Resident furniture for the six completion homes from existing variants,
   signal outlets beside every switch, the ducts measured (`slice6`,
   `slice6d`, `routes6b`, `ducts`; `bisect_*` hold the route-test receipts
   at main, slice 1 and slice 5).
7. Kitchen sets: four new surface-stock forms and fifty-two records on the
   drainboards and prep cabinets of all eighteen kitchens (`slice7`).
8. Hall stands in the eighteen apartment vestibules, a new domestic-objects
   form (`slice8`, `slice8b` for the corrected D-plan placement).

Verification runs are made at WIP commits that are later squashed; the game
and art paths of each squashed commit are byte-identical to the WIP tree the
receipts name, which `git diff --stat <wip> <commit> -- game art` confirms.

## Reading the register

Priority P1 = reads wrong from the doorway or the resident is not legible;
P2 = strengthens story, period truth or the Shenmue test; P3 = polish.
Action = add / move / refine / remove / keep. `BW-nnn` changes are
building-wide families cited by many rooms; fix the family, not the room.
Proposed backstory is labelled on every page and collected in the front
matter; none of it is canon until ruled.
