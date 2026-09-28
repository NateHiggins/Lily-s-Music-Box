# V2 architecture handoff — 2026-09-27

Evidence class: **INERT**

REPORT - V2 architecture fabrication batches - 2026-09-27

Branch / HEAD / origin/main / merge-base: main in C:/PleaseRemainOnTheLine.
At preparation, HEAD and origin/main are fcf16e512d24bbcc1deb5b89a7089d2912145523.
The commit containing this handoff adds the roof coping batch described below.
Its exact candidate result belongs in tmp/roof-coping/verified/verification.md.

Worktree clean at end: no. Preserve the owner's pre-existing modified
art/renders/insitu/shots.md and untracked shot_024.png through shot_028.png.
Candidate verification temporarily backs these up and restores their exact
bytes, recording hashes in tmp/roof-coping/owner-restoration.json. These files
are not part of this work. No permanent worktrees or rescue archives were added.

Protected 17/17: yes through fcf16e5; final candidate rechecks all 17.
Selector: v2, with explicit ORISON_BUILDING_ROOT=v1 rollback retained.
Ledger before -> after through fcf16e5: [7, 8, 127, 42, 151, 153] ->
[7, 8, 127, 42, 151, 153]; requirements_changed: []. These are verifier counts
in FIRST_SLICE_TECHNICAL, GOLDEN_SHIFT_V2, FULL_BUILDING_STRUCTURAL,
FULL_BUILDING_RUNTIME, PRODUCTION_CUTOVER, V1_RETIREMENT order.
This document makes no runtime-contract or completeness promotion claim.

## Completed batches

Each batch includes editable Blender source, its generator and exported glTF,
production integration, focused regression coverage and inspected windowed
captures. Existing gameplay and collision owners remain authoritative.

| Commit | Work | Local candidate report directory under tmp |
|---|---|---|
| 89d3b2d | 23 bathroom ventilation registers, actual louver openings | vent-register/verified |
| 3dd60cc | Four roof ventilators, live rotors/shutters and corrected throat apron | roof-ventilator/verified-final |
| 0ea067d | 105 doors / 210 faces of mortise hardware; stile and brace clearance | door-knobs/verified |
| b0bb49f | 315 articulated hinges; corrected both swing axes | door-hinges/verified |
| cae3f20 | 72 window frames; opened the obstructing wet-chase aperture | window-joinery/verified |
| cb4706c | Removed 180 window/millwork overlaps; kept consistent stile spacing | window-trim/verified |
| b2e06da | Bonded chimney brick courses, open coping, corrected corner mortar | chimney-crown/verified |
| 2c46446 | Timber house tank, iron supports and detailed binding hardware | house-tank/verified |
| fcf16e5 | Open overflow collector, fitted boards, rim and fasteners | tank-collector/verified |
| This commit | Jointed roof weather course with mitered corners | roof-coping/verified |

Numbers management asked for: roof coping reproduces all 12 old box-overlap
or missing-corner defects, requires exactly one new surface at each station,
and checks four actual cap contacts. Focused windowed run reports
ROOF COPING: contacts=4 corner_stations=12 reproduced_old_defects=12 failures=0.
Both rendered views were inspected. Logs and bound suite-run receipt:
tmp/roof-coping/coping.log and tmp/roof-coping/coping.log.receipt.json.
Double import completed before this run. Spatial audit found no new failing
or reported findings. Roof-cap collision bodies and perimeter guards remain
unchanged; the small weathering returns are visual, not new climbing surfaces.

Gates (real exit codes, logs and receipts): each completed candidate above has
verification.md, verification.json and a full gate board, with zero regressions
against its clean preceding-main board. Latest completed fcf16e5 verification
passed HouseTank, Blockout, RoofRoute (51 waypoints), and actual title Continue
launch, all exit 0 with binding receipts. The final roof-coping candidate runs
the same roster with RoofCoping replacing HouseTank, plus double import and
all static/tools gates. Consult its exact report rather than inferring success
from this pre-verification handoff. Wrapper receipts are not runtime contracts.

Changes outside the expected file boundary, and why: fixture fabrication tags
in the blockout data let Blender and runtime share dimensions and ownership.
The roof batch adds four tags without changing positions or dimensions.
Earlier window work cuts only declared window apertures through intersecting
chases. Imported triangle bounds guide millwork clearance. DOCS indexes the
fabrication notes and this handoff. No protected systems were redesigned.

## Open findings not fixed / next work

- V2 architecture refinement is not complete. Continue small geometry batches
  from remaining primitive fixtures, preserving production behavior and testing
  real contacts and routes. Basement breeching elbows are one remaining target.
- Window sashes are static. Original glazing and collision behavior remain.
  General exterior wall thickness still follows the 0.14 m partition value;
  changing it to the separate 0.35 m parameter requires a broader fit/route pass.
- Tank lids are not operable; existing ballcock maintenance remains. These
  fabrication passes add no fluid or gas simulation. The lift emergency-stop
  presentation remains decorative.
- Owner-accepted TASKS H23 seams remain: DreamZooWarehouseTest placeholders,
  DreamVoxelV1Test shared allocation, and DreamCritterVoxelBindingTest channels.
  The historical M11C1 hash gate remains baseline debt. Do not claim every
  historical test is green or that the whole V2 specification is complete.
- Verification is in-place on the canonical checkout, not fresh-checkout proof.
  Capture files and detailed run evidence under tmp are local and uncommitted.

## Launch and resume

```powershell
cd C:\PleaseRemainOnTheLine
Remove-Item Env:ORISON_BUILDING_ROOT -ErrorAction SilentlyContinue
$env:ORISON_TITLE_DEBUG="1"
pwsh -File tools/lane.ps1 run -Scene res://scenes/ui/title_screen.tscn -Windowed -Runner long -TimeoutSeconds 1500 -LogPath tmp/v2-play.log
```

The long runner requires the explicit scene argument above. V2 is the default.
For rollback set $env:ORISON_BUILDING_ROOT="v1" before launching.
Zoo access: Debug Building -> F1 -> GO — teleports -> Dream zoo / Dream ecology.
Use Leave camera and Building return to return. Backtick releases the mouse.

Read AGENTS.md, DOCS.md and the consolidation document before resuming. Work
on current main, fetch/check newer work before editing, stage named paths only,
and never stop another project's Godot process. All Godot runs use the lane,
one process at a time; double import after asset/checkout changes, windowed
captures, actual rendered inspection and full candidate comparison remain
required. Keep the six owner capture files out of commits.

Decision needed from owner: none. The owner requested handoff, commit and push;
stop after verifying and publishing this batch.

MERGE-CANDIDATE: the commit containing this handoff, subject to its exact candidate report.
