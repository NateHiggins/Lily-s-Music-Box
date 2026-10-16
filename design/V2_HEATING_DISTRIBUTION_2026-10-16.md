# V2 native heating distribution

Evidence class: **INERT**. Implementation status, not room promotion or
full-building acceptance. Broad checkpoint verification is in progress.

## Installed change

Eighteen installed radiators now have source-routed native supply branches
connected to four vertical mains and a fitted boiler receiver. The assembly
includes 184 branch couplings, four blind main caps, 40 shaft supports, 413
underfloor hangers and 18 floor sleeves. Seventeen shorter radiator bodies
receive hollow tailpieces between their fixed unions and first castings.
The ten-section radiator already reaches its union.

The existing HeatBalance demand roster, boiler, radiator controls, maintenance
inventory, direct-manipulation targets and save authorities remain in place.
The 23-demand heating model is not reduced to the 18 installed emitters.
This change installs physical fabric; it does not replace the acoustic graph.

The building layout contains 18 floor apertures and 22 shaft openings.
Shaft cuts are clipped to their owner, preserving the blockout validator.
Two upper-floor branches were rerouted to clear neighboring radiator bores.
Floor collars cover the square apertures. Buried distribution meshes do not
add triangle collision; the existing building and radiator walking hulls
remain authoritative. The visible boiler feed retains matching mesh collision.

## Surfaces and provenance

The seven level/shaft mesh batches use existing custom **iron_neutral** PBR
maps, authored UVs, unit runtime UV scale and mipmapped filtering. The boiler
feed retains its separate metric UV convention. Imported distribution charts
require the narrow full-precision exception registered in the mesh policy;
the earlier compressed candidate collapsed small UV triangles.

Recipes and regeneration commands are in
**art/blender/heating_distribution_workflow.md**. Source plans are in
**art/blender/heating_distribution/**. The native file and exported asset are
**art/blender/heating_distribution.blend** and
**game/assets/props/heating_distribution.glb**. The INERT fixture
**game/tests/fixtures/orison_heating_distribution.json** binds sources and assets.
The fabrication planner reports no source drift or missing inputs for this
family. Being bound is not runtime or artistic acceptance.

## Completed checks

- Saved native inspection: 439,088 triangles including the separate boiler
  feed; no collapsed UV charts, nonmanifold stocks or negative volumes.
- Native probes: 2,010 coupling/tailpiece lumen checks, 40 cap probes,
  160 main-support probes and 826 hanger-contact probes, plus sampled branch,
  receiver and floor-sleeve checks. Tail elevations are checked against their
  radiator floor datums.
- Export: seven batches with an actual Blender glTF round-trip check.
- Focused composed diagnostic: startup, loaded material mip chains,
  unobstructed capture stances, actual imported tailpiece elevations and
  intersection with the first radiator castings passed after correction.
- Boiler pipework diagnostic: seven surface/collision contact stations passed.
- Focused Python suites: 52 tests passed. Reader and spatial audits passed;
  all 17 protected paths match the published checkpoint after text normalization.

The current focused log, wrapper receipt, captures and native reports are in
**art/renders/orison_v2/heating_distribution_20261016/**. Wrapper receipts and
these diagnostic checks are not schema-2 runtime contracts. The final focused
run still reported the previously observed seven Texture RID shutdown warning.

## Review findings and remaining work

The first composed run exposed shaft cuts extending beyond their owner; the
cuts were corrected without relaxing validation. Better camera positions then
revealed the shorter radiators' missing union connections. The first tailpiece
build omitted the floor elevation; native floor-datum checks and actual loaded
mesh probes now cover that failure. The corrected sixth-floor capture shows
the connection seated between the union and casting.

The composed surface suite passed 26,719 checks with zero unresolved surfaces
across 24,778 draws, 5,986 materials and 465 textures. Its current source-bound
packet and reviewed renders independently qualify in
**art/renders/orison_v2/surface_requirements_20261011/**. This is technical
surface qualification, not photoreal acceptance. The first-slice gameplay
suite passed 133 checks; its schema-2 runtime contract independently validates
and is archived in the heating packet as **runtime_authority_receipt.json**.

The installed patrol save test passed 26 checks, including physical filing,
actual disk save and two fresh-world reconstructions. Its narrow contract
passed independent source, execution and observation checks; the restored
register render was reviewed. Evidence is archived under the heating packet
in **save/** with **save_qualification.json** and the completed wrapper.
The first apartment-access suite passed 269 checks across 19 rooms. Its
contract independently validates 268 recorded checks (the final output-flush
check is reported after serialization); the canonical access receipt is
renewed. The remaining-apartment suite passed 782 checks across 60 rooms; its
source-bound access contract independently validates 781 serialized checks.
The canonical receipt is renewed. The installed dumbwaiter suite passed
53 checks, including physical repair, partial-position disk save, fresh-world
restoration and measured retirement. Its runtime contract independently
validates. The roof-tank suite passed 52 checks and its actual runtime
contract independently validates input, guarded repair, partial disk state,
fresh-world reconstruction and measured teardown.

The first gate comparison found only two new diagnostic test references:
fifth- and sixth-floor radiator identities used by the supply capture checks.
Exactly those two source-resolved, non-gameplay test records were added to the
spatial manifest; all existing records and classifications were retained.
The spatial audit has zero new drift. The final gate comparison reports
NO REGRESSIONS, with all 53 tools suites passing and unchanged ledger counts.
The checkpoint is ready for commit; publication and fresh-checkout static
verification follow.
The acoustic ownership and ventilation tools remain preparatory work; their
candidates have not been installed or accepted. Existing valve/casting polish,
whole-building acoustic migration and human visual/listening acceptance remain
outside the completed checks above. V2 is not complete.


## Management report

REPORT - V2-HEATING-DISTRIBUTION - 2026-10-16

Branch / HEAD at validation / origin/main / merge-base: main /
4be598eaa7398df43cecfe32a360661cc8ec75f3 /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Publication target: **codex/v2-direct-manipulation-checkpoint** only.

Worktree clean at end: no. Inherited import, UID, review-artifact and
line-ending changes remain outside the named checkpoint paths.
Protected 17/17: yes against origin/main at the preceding committed checkpoint
and unchanged in this batch. Selector: V2, with explicit V1 rollback retained.

Ledger before -> after: **0 / 1 / 48 / 25 / 65 / 67** ->
**0 / 1 / 48 / 25 / 65 / 67**; requirements_changed: **[]**.
Comparison uses the stored preceding-checkpoint board from e2ffefd8, not a
clean merge-base board. No fresh-checkout merge verdict is claimed here.

Gates: 53 tools suites pass; final comparison reports NO REGRESSIONS.
The completeness tool exits 2 for its unchanged unfinished scope; the board
comparison exits 0. Surface qualification, mip/import policies, period,
reader and spatial gates pass. Reader has zero new unread fields.
The archived **gate_board.json** and **gate_board.md** retain exact results.

| Completed Godot suite | Result | Wrapper in heating packet |
| --- | --- | --- |
| Surface inventory | 26,719 checks, zero failures | Canonical surface packet qualification wrapper |
| First slice | 133 checks, zero failures | **firstslice.log.receipt.json** |
| Installed patrol save | 26 checks, zero failures | **save.log.receipt.json** |
| Apartment access | 19 rooms, 269 checks, zero failures | **apartments.log.receipt.json** |
| Remaining apartment access | 60 rooms, 782 checks, zero failures | **remaining.log.receipt.json** |
| Installed dumbwaiter | 53 checks, zero failures | **dumbwaiter.log.receipt.json** |
| Installed roof tank | 52 checks, zero failures | **roof.log.receipt.json** |

Test-authored contracts and independent qualifications are archived beside
the wrappers. Access receipts serialize one fewer check than their final
suite total because output-flush verification follows serialization.
The surface packet remains at its canonical path. No report or wrapper is
substituted for an executed runtime contract.

Changes outside native heating: seven preparatory acoustic/heating tool
suites; two narrowly reviewed spatial test references; exact import policy;
source/asset fixtures; hash-bound Git attributes; evidence and documentation.
No new acoustic graph is installed and no protected authority changes.

Open findings: coarse legacy radiator valves/castings, uninstalled lobby
emitter, restricted-cell acoustic representation, broader graph migration,
remaining V2 requirements, and human visual/listening/navigation acceptance.
The known seven Texture RID shutdown warning remains. Credentialed weather
and whole-game artistic/performance acceptance are not granted by this batch.
Decision needed from owner: none for continuing implementation.

BLOCKED merge-candidate status pending fresh-checkout verification;
reviewed checkpoint branch publication is the current release scope.


## Portable evidence renewal

Implementation commit: **ccb94d88d8abb1863ce6d2467b068d5fdea66480**.
The first fresh static verification rejected its surface fingerprint and the
associated apartment access evidence. The canonical comparison above passed,
but that did not establish checkout portability. Publication remains pending.

Twelve untracked **washer_controls_T_*.png** files entered the canonical
source fingerprint. They are stale loose extracts: the current native washer
GLB has zero embedded images and zero texture bindings, and no tracked game
source references their namespace. The failed fresh report and source analysis
are preserved under **diagnostics/fresh_checkout_fingerprint/** in this packet.
A narrow derived-file ignore now excludes these unused leftovers while the
actual washer GLB remains a hashed input. No capture or contract was repinned.

The composed surface and both apartment access contracts were re-executed
against the portable input set and independently qualified. The other four completed contracts bind the
unchanged production runtime digest and retain their existing narrow scope.
Fresh static verification must pass before branch publication.


Portable renewal progress: the surface suite completed in 320 seconds with
26,719 passing checks and unchanged inventory counts. Seven new captures were
reviewed and the canonical packet independently requalified. The 19-room
access renewal completed in 218 seconds with 269 suite checks; its 268
serialized checks independently validate. The 60-room renewal completed in 845 seconds with 782 suite checks; all
781 serialized checks independently validate. Its canonical receipt is renewed.
The input-membership diagnostic produces the same 4,812-file fingerprint
using normal discovery and tracked-only discovery. No physical production
source differs from the implementation commit after text normalization.


The current apartment execution wrappers are **apartments_portable.log.receipt.json**
and **remaining_portable.log.receipt.json** in the heating packet. Their actual
contracts and qualifications are retained in the matching portable subdirectories.
The current surface wrapper is the canonical packet's **qualification.log.receipt.json**.
The earlier wrappers remain historical evidence at their recorded input set.

The source-portability preflight is now documented in
**art/blender/v2_batch_workflow.md**. It requires named authored files to travel
with the commit and proven generated leftovers to stay out of source discovery.
The current follow-up changes only Git discovery, workflow documentation and
executed evidence. The fresh verifier will supply the final static board once,
using its existing clean merge-base cache. Publication is still pending that
verdict; no additional runtime or human acceptance is inferred.
