# V2 completion-interior spatial access checkpoint — 2026-10-12

Evidence class: **EVIDENCE**. Automated spatial-access checkpoint only.
Status: **43 rooms reached through ordinary production movement; full runtime and human acceptance remain separate.**

## Executed scope

One production-selected V2 world hosts seven independently started legs: 1D,
1A, 3D, 4D, 2C, 4C and the staff restroom. Each unit has one initial placement;
all subsequent travel uses the normal controller and collision. No connected
floor-to-floor route is claimed. Resident scheduling remains running.

Doors use the real player ray, prompt and E input. Every visited apartment's
kitchen and bathroom valves exercise hot-only, mixed, cold-only and both-off
states; the staff basin does likewise. The locked owner store in 4D is tested
for refusal and remains excluded from spatial claims. The run passes **335
checks and 154 waypoints**, reaching all **43 rooms** below, with zero failures
and zero script errors.

- `F01_A_BATH`
- `F01_A_BED`
- `F01_A_KITCHEN`
- `F01_A_MAIN`
- `F01_A_PRIVATE_HALL`
- `F01_A_STUDY`
- `F01_A_VESTIBULE`
- `F01_D_BATH`
- `F01_D_BED`
- `F01_D_KITCHEN`
- `F01_D_MAIN`
- `F01_D_PRIVATE_HALL`
- `F01_D_VESTIBULE`
- `F01_STAFF_RESTROOM`
- `F02_C_BATH`
- `F02_C_BED1`
- `F02_C_BED2`
- `F02_C_KITCHEN`
- `F02_C_MAIN`
- `F02_C_PRIVATE_HALL`
- `F02_C_STUDIO`
- `F02_C_VESTIBULE`
- `F03_D_BATH`
- `F03_D_BED`
- `F03_D_KITCHEN`
- `F03_D_MAIN`
- `F03_D_PRIVATE_HALL`
- `F03_D_STUDY`
- `F03_D_VESTIBULE`
- `F04_C_BATH`
- `F04_C_BED1`
- `F04_C_BED2`
- `F04_C_KITCHEN`
- `F04_C_MAIN`
- `F04_C_PRIVATE_HALL`
- `F04_C_STUDIO`
- `F04_C_VESTIBULE`
- `F04_D_BATH`
- `F04_D_BED`
- `F04_D_KITCHEN`
- `F04_D_MAIN`
- `F04_D_PRIVATE_HALL`
- `F04_D_VESTIBULE`

## Bound proof and limits

Test: **game/tests/OrisonV2CompletionAccessContractTest.tscn**.
The test-authored schema-2 contract is committed at
**art/renders/orison_v2/completion_access_20261012/runtime_contract.json**.
The wrapper **run1.log.receipt.json** records execution only. Current runtime
and geometry/surface hashes, root and transitive helper hashes, complete walked
traces, actual positions inside current room boundaries and root/driver
retirement are validated before any room is admitted. Validation reports zero
errors. Changed inputs expire this proof; adding unvisited room names cannot
promote them. This uses the existing tested SPATIAL_ACCESS channel unchanged.

The production root and seven drivers retire. Godot again reports seven
Texture RID leaks at shutdown; resource-clean shutdown is not claimed.
The reviewed bedroom capture includes the service-wire device and is an access
illustration, not aesthetic approval. No disk reconstruction, case completion,
whole-building navigation or human acceptance is granted. Door and valve checks
do not certify every household object or resident schedule.

## Static verification

The spatial-dependency manifest registers only this new test's references.
The reader audit reports zero new unread fields. Eight proof-validation mutation
tests pass. Clean candidate **e72c8a1c** passes against the recorded
**6faf490e** baseline with zero regressions, all 17 protected paths unchanged,
selector V2 and zero document lint errors. No exemptions were used. The sole
gate-file change adds 49 new test references to the spatial manifest; existing
records and thresholds are unchanged. The comparison ran in the clean temporary
checkout with **--no-godot**, reusing the separately bound canonical runtime
receipt. **verification.json** and **verification.md** retain the comparison.
These rooms already had spatial status from older evidence: the new walked
proof strengthens current coverage but changes no requirement status or blocker
count (103 structural, 34 runtime, 120 production-cutover and 122 retirement).

## Remaining work

Whole-building structural, runtime, production-cutover and retirement gaps
remain, as does the human golden-shift acceptance. This checkpoint does not
close the broader geometry, narrative or visual-quality review.

## Bedding geometry renewal

The current test-authored room receipt was renewed after the October 12 bedding
polish, with the same rooms, route scope and passing check counts. Its wrapper
is **art/renders/orison_v2/bedding_polish_20261012/final-completion-access.log.receipt.json**.
The original wrapper and images above remain historical; this renewal grants
no additional requirement status or human acceptance.

## Roof-program runtime renewal

The room receipt was renewed after the roof purpose and carried-light rotation
changes, with the same 43 rooms and route scope. Its wrapper is
**art/renders/orison_v2/roof_program_20261012/completion-access.log.receipt.json**.
Earlier wrappers and images remain historical; the scope is unchanged.

## Bathroom tile renewal

The current source-bound receipt passes 43 rooms and 335 checks after the tile/UV
update. Wrapper: **art/renders/orison_v2/bathroom_tiles_20261012/completion-final.log.receipt.json**.
Scope and thresholds remain unchanged.
The completion driver now waits for the same ordinary-input door motion to
settle, with a three-second deadline, instead of checking at a fixed 0.6 seconds.
It retains the original angle tolerance; it does not retry or assign door state.
