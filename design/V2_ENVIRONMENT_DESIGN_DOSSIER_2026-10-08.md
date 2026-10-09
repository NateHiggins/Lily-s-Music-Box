# V2 environment design dossier, 2026-10-08

Evidence class: **INERT**. Review and design; promotes nothing.

REPORT - V2 ENVIRONMENT DESIGN - 2026-10-08

Branch / base: `claude/orison-v2-environment-design-778e17` from main at
`fdf01a36`. No code, data, generator or protected path is changed by this
work; the packet is a review artefact under `art/reviews/`.

## What was delivered

`art/reviews/v2_environment_design_20261008/` holds the dossier PDF
(`V2_environment_design_dossier.pdf`), its HTML companion, the complete
machine-readable `dossier.json`, the editable change register
(`change_register.csv`, `.xlsx`, `.json`), the coverage checklist, per-level
plans with capture stations, 640 px review tiles for every captioned view, the
sweep records and run receipts, and the sources (capture scene, census, plan,
sheet and merge builders, content modules). `README.md` in the packet explains
each file.

The dossier covers every one of the 200 semantic spaces of
`game/data/orison_v2_blockout.json`, the Vantry Arcade and its eleven shops,
the Harukiya (descent, room, stage, WC), the bodega, the street, the facade,
the service alley and the subway approach, plus one building-wide page of
systemic findings. Each area carries identity, captioned current-build
evidence with observed problems kept apart from interpretation, a room
narrative, numbered changes with stable ids and placement relative to existing
anchors, and implementation and acceptance notes. Proposed backstory is
labelled on every page and collected in the front matter.

## How the evidence was captured

A temporary capture scene (`sources/orison_v2_environment_dossier_sweep.gd`,
extending `OrisonV2CitySweep`) was installed in a detached capture worktree at
the same commit (`C:/ov/envdossier`), run twice through the lane broker with
the long runner, windowed, and removed afterwards. Per space: overview, reverse
view, threshold view from outside the principal door (leaf opened by the
ordinary interaction where not locked), up to three detail views; with
`DOSSIER_CITY=1` the city sweep's stations plus bodega, alley, facade and
subway views. Campaign time was frozen at 1928-11-10 20:00; production
fixtures; player lamp on; carried set hidden. Receipts
(`evidence/runs/*/sweep.log.receipt.json`) are `suite_run` wrapper receipts and
bind `repository_head` fdf01a36; they are not runtime contracts. The capture
worktree needed the gitignored machine-local runtime textures copied from the
canonical checkout; their hashes are in `evidence/copied_local_assets.json`.

Every frame is a teleported inspection station. No route, lock, save or
acceptance is claimed. Sealed and restricted interiors were reached by
teleport only and are recorded as such in the coverage checklist.

## Canon findings recorded for the owner

Seven electric monitor-top refrigerators where Bible VIII.5.a allows four;
Prohibition absent from canon while the Harukiya pours; the election four days
before the game's start; schedules that still name televisions in a projector
world; six completion-interior homes furnished from copied templates (1D with a
seamstress's furniture); three converted second bedrooms not converted. Each
is recorded with the change ids that act on it and the Bible treated as
prevailing.

## Not claimed

No ledger status changes. No model, data or test was altered. The owner's
improvement JSON items (G, T, A families) are not re-proposed; dependencies on
their pending items (A05-A08, T07/T09, A01/A02 final review) are named per room.
