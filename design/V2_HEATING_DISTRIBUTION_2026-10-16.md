# V2 native heating distribution

Evidence class: **INERT**. Implementation and verification report. This does
not grant human acceptance or declare the complete V2 build finished.

## Result

Eighteen installed radiators now connect through native supply branches to
four mains and the boiler receiver. Seventeen shorter bodies have hollow
union tailpieces; the ten-section radiator already reaches its union.
There are 184 branch couplings, four blind caps, 40 main supports,
413 underfloor hangers and 18 floor sleeves. The layout has 18 floor apertures
and 22 shaft openings, clipped to their actual owners.

Existing HeatBalance, radiator/boiler controls, inventory, maintenance,
direct-manipulation and save authorities remain. The original 23-demand heat
budget is retained. Buried pipe meshes use the existing floor/shaft walking
hulls; visible boiler feed retains matching mesh collision. No new acoustic
graph is installed.

Seven level/shaft batches use custom **iron_neutral** PBR maps, authored UVs,
unit runtime scale and loaded mipmapped filtering. The narrow full-precision
import policy prevents small pipe charts collapsing. The boiler feed retains
its separate metric UV convention. Native recipes, plans and bound fixture
are documented in **art/blender/heating_distribution_workflow.md**.

## Verification

The native inspection covers 439,088 triangles including the separate boiler
feed. It passes UV, nonmanifold and signed-volume checks; 2,010 lumen probes,
40 cap probes, 160 main-support probes and 826 hanger-contact probes pass.
Export checks seven actual glTF round-trip batches. Focused composed checks
verify loaded maps, unobstructed capture stances, floor datums and actual
imported tails reaching the first radiator castings. Native and composed
renders were reviewed. These focused diagnostics remain distinct from the
test-authored runtime contracts below.

Packet: **art/renders/orison_v2/heating_distribution_20261016/**.
Surface packet: **art/renders/orison_v2/surface_requirements_20261011/**.

| Completed Godot suite | Result | Current execution wrapper |
| --- | --- | --- |
| Composed surfaces | 26,719 checks, zero unresolved | Surface packet **qualification.log.receipt.json** |
| First slice | 133 checks, zero failures | **firstslice.log.receipt.json** |
| Installed patrol save | 26 checks, zero failures | **save.log.receipt.json** |
| Apartment access | 19 rooms, 269 checks, zero failures | **apartments_portable.log.receipt.json** |
| Remaining apartment access | 60 rooms, 782 checks, zero failures | **remaining_portable.log.receipt.json** |
| Installed dumbwaiter | 53 checks, zero failures | **dumbwaiter.log.receipt.json** |
| Installed roof tank | 52 checks, zero failures | **roof.log.receipt.json** |

All seven contracts independently validate at their stated scope. Access
receipts serialize one fewer check than their suite totals because the final
output-flush check follows serialization. Surface coverage is 24,778 draws,
5,986 materials and 465 textures across 221 spaces and 13 resident cells.
Seven new portable-source captures were actually reviewed. Technical surface
qualification does not grant photoreal or human acceptance.

The first runs exposed oversized shaft cuts, shorter radiator union gaps and
an omitted floor datum on the first tailpiece candidate. These were corrected
without weakening the validators. Native floor-datum probes and actual loaded
mesh checks cover the corrected tails. The failed candidates remain historical
diagnostics, not current passes.

## Portability correction

The first fresh checkout rejected the canonical surface fingerprint. Twelve
untracked **washer_controls_T_*.png** leftovers entered source discovery but
did not travel with the commit. The current washer GLB has zero images and
texture bindings; tracked game sources and the composed draw/material/texture
inventory reference none of these files.

One narrowly scoped ignore rule excludes that stale generated namespace. The
actual washer GLB remains hashed. Twelve PNGs and twelve untracked import
sidecars were moved to a local ignored recovery folder outside Godot; hashes
were verified before and after moving. The surface fingerprint stayed unchanged
after retirement. No unused textures were added to shipping assets.

The surface and both spatial contracts were re-executed against the corrected
input set, never repinned. The other four bind unchanged physical runtime
inputs and keep their existing scope. Normal discovery and tracked-only
discovery now yield the same 4,812-file fingerprint. The failed fresh report,
provenance, membership check and retirement record are retained in
**diagnostics/fresh_checkout_fingerprint/**. The pre-capture source review is
now documented in **art/blender/v2_batch_workflow.md**.

## Management report

REPORT - V2-HEATING-DISTRIBUTION - 2026-10-16

Branch / HEAD verified / origin/main / merge-base: main /
57e6aadd416193ca3d9497555a236481a2ba107c /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Implementation commit: **ccb94d88d8abb1863ce6d2467b068d5fdea66480**.
Publication target: **codex/v2-direct-manipulation-checkpoint** only.

Worktree clean at end: no for the canonical shared checkout; inherited import,
UID, review-artifact and line-ending changes remain outside named owned paths.
The verifier's fresh candidate checkout was clean. Temporary verification
checkouts were removed by the verifier; its clean baseline cache is retained.
Protected 17/17: yes against origin/main. Selector: V2 with explicit V1 rollback.

Clean merge-base ledger before -> after: **0 / 1 / 102 / 34 / 119 / 121** ->
**0 / 1 / 48 / 25 / 65 / 67**. This includes preceding branch work, not only the
heating batch. The canonical preceding-checkpoint comparison was unchanged at
**0 / 1 / 48 / 25 / 65 / 67**, requirements_changed **[]**, after the two
new diagnostic radiator references were reviewed. Exactly those two source-
resolved, non-gameplay test records were appended to the spatial manifest;
all existing rows and classifications were retained.

Fresh verifier exit: **0**, NO REGRESSIONS; 53 tools suites pass. The ledger
itself exits 2 for its unfinished scope. Surface, import/mip, period, reader,
spatial and rulings gates pass. Reader has zero new unread fields. The exact
fresh comparison, changed requirement list and all gate results are archived
in **candidate_verification.json**, **candidate_verification.md** and the final
**gate_board.json/md**. Design-document validation has zero errors.

The fresh verification used **--no-godot**. It proves checkout portability and
static integration. The seven canonical runtime executions above retain their
own source bindings; no fresh import, fresh runtime or human acceptance is
inferred from the static verifier. Report/evidence follow-up changes no
production input.

Changes outside native heating: seven acoustic/heating tool suites; the two
reviewed spatial test references; exact import policy and fixture bindings;
hash-bound Git attributes; derived-file discovery; workflow documentation;
and executed evidence. Preparatory acoustic/ventilation candidates remain
uninstalled and unaccepted.

Open findings: coarse legacy valve/casting detail, uninstalled lobby emitter,
four restricted-cell radiator representations, broader acoustic migration,
remaining V2 requirements and human visual/listening/navigation acceptance.
The known seven Texture RID shutdown warning remains. Whole-game artistic,
performance and credentialed weather acceptance are outside these checks.
Decision needed from owner: none for continuing implementation.

MERGE-CANDIDATE 57e6aadd416193ca3d9497555a236481a2ba107c
