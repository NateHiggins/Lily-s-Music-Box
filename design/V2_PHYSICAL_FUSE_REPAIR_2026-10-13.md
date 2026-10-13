# V2 physical fuse repair — 2026-10-13

Evidence class: **INERT**. Implementation and review report.
This report grants no spatial, gameplay, cutover or human visual acceptance.

## Behavior and retained authority

The installed basement panel now uses the ordinary click/grab, mouse movement
and click/release contract. Its cabinet swings about its hinge; the knife main
rotates about connected lower bearings. Four separate marked fuse plugs can
be unscrewed, carried, placed on the spare rack and screwed into the real branch
holder. Five turns produce the full thread travel. The mouse wheel supplies
depth movement for a held loose object, including from the fixed inspection
camera. The existing Space inspection and exit behavior remains in charge.

The retained panel owner rejects live withdrawal and an oversized replacement.
It publishes the existing service result only after a correctly seated plug
has held the restored load for 1.8 seconds. The V2 player route no longer opens
the maintenance minigame. Legacy maintenance APIs remain available to their
existing authorities and explicit V1 rollback.

Physical snapshots preserve cabinet/main travel and all four plug identities,
thread travel, positions and orientations. Restoration revokes stale grabs.
Historical service completion remains distinct from present electrical safety:
a partly unscrewed replacement cannot inherit a false safe state from the
completed service record. The existing household and save owners retain those
responsibilities; the helper controllers introduce no independent save domain.

## Native geometry and rendered condition

The Blender source contains fitted knife blades, connected bearings, full-size
bakelite caps, helical brass shells, contact buttons and a two-shelf folded
metal rack with retaining lips. Original mesh-node owners remain intact.
Generated glTF is not hand-edited. All seven changed partitions belong to M07;
decoded geometry in the other 291 partitions is unchanged against **555b01f3**.
The build contains 674 closed stocks and 298 runtime partitions.

The spare rack uses the existing registered neutral-iron PBR set. Fuse ratings
and the circuit card use Label3D; their letters are not baked into textures.
The ratings sit clear of their backing plates to prevent depth flicker.
Native and installed renders were reviewed and archived in
**art/renders/orison_v2/physical_fuse_20261013/native.png** and
**art/renders/orison_v2/physical_fuse_20261013/installed/repaired_panel.png**.
The final installed image shows readable ratings and the corrected metal rack.
Human aesthetic acceptance and broader building polish remain outstanding.

## Current verification and discovered route issue

The installed test passes 73 checks, exercising actual player input, static
inspection, guarded repair, a real disk save, destruction and fresh-world
reconstruction. Both sets of physical controllers retire. The wrapper receipt
is **installed.log.receipt.json**; the test-authored schema-2 contract is
**installed/runtime_contract.json** in that review packet.
The shared direct-manipulation suite passes 95 checks. The earlier native
inspection bench passed 62 checks. These are scoped proofs, not V2 completion.

The continuous basement run completed the fuse repair and reached 103
waypoints, but failed its last fire-door opening. A focused diagnostic found
that the next leaf-sweep query hit only the player, at 0.9 radians. Walking
back to x=10.95 allowed the same leaf to reach its full stop and allowed passage
through the door. The diagnostic deliberately retains its initial failure.
The route now includes that real step back, preserving the player capsule,
door sweep and all collision. The complete rerun reaches 105 waypoints with
zero failures (**basement.log.receipt.json**). This is the
continuous route result; the earlier failed run remains a diagnostic.

## Management status

REPORT - V2-PHYSICAL-FUSE-REPAIR - 2026-10-13

Branch / validation parent / origin/main / merge-base: main / 555b01f3 /
e0b0dd293325a49c207785888112262a4990e474 / same origin/main.
Intended publication target: **codex/v2-direct-manipulation-checkpoint**.
The shared checkout contains inherited changes; only owned named paths may
be staged. No origin/main integration is claimed.

The focused static board passes mesh UV/import, surface import, spatial,
reader and carrier gates. Reader NEW is zero. Exactly four reviewed fuse
references were appended to the spatial manifest; historical records and
dispositions were not replaced. A subsequent route audit remains clean.
All 17 protected paths match the merge-base using exact binary bytes and
LF-normalized text. Two inherited text files differ only in line endings;
the per-path comparison discloses both raw and normalized results. V2 remains
the default with the explicit V1 selector retained.

The initial full board had 44 passing tools suites; its completeness test
and surface gate correctly rejected expired global proofs. A fresh surface
qualification now passes 26,691 checks across 24,473 draws, 16,514 meshes,
5,985 materials and 465 textures, with zero noncompliant physical surfaces.
Its canonical packet was renewed from the completed test-authored receipt,
with reviewed fuse renders and fresh frontage/gallery captures. The independent
surface qualifier passes with zero defects. The live-clock 19-room access
contract also passes all 268 checks. First-slice reconstruction passes 115
checks after correcting an intermittent raw-Dictionary comparison in its test:
full-precision JSON can shift a fractional timestamp by one ULP. A 10,000-value
diagnostic reproduced 4,093 such comparisons, with a largest error of
0.00000000000000001388 minutes. The strengthened test checks the complete disk
record and reconstruction against the exact serialized representation, with
a separate timestamp-precision bound. Production save/work-order logic is
unchanged. The renewed 60-room access contract passes all 782 checks with zero
failures. This
report does not waive regressions or renew old hashes without new runs. Seven existing
Texture RID shutdown warnings remain; the installed test reports no ObjectDB
or resource-in-use warnings.

Final gate board: 55 rows, zero regressions against
**art/renders/orison_v2/remaining_apartments_20261013/gate_board.json**. All 45
tools suites pass. The ledger and three receipt-consumer suites were refreshed
after the final runtime receipt; other unchanged successful checks are reused
from this batch's full board. Both component boards and their hashes are
preserved in **gate_reuse.json**. No gate result was rewritten to manufacture
a pass. Ledger blockers remain first slice / golden shift / structural /
runtime / cutover / retirement = **0 / 1 / 48 / 25 / 65 / 67**.

A clean-checkout candidate verification and origin/main integration are not
claimed. Broader V2 work remains incomplete; the roof ballcock and several
other service mechanisms still have legacy maintenance-panel paths to migrate.
Human visual acceptance remains separate from these automated results.
