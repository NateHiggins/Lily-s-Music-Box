# Passage pull and oak repair, 2026-10-25

Evidence class: **INERT**. Focused repair report; no V2 completion or human acceptance.

REPORT — V2-PASSAGE-PULL — 2026-10-25

Branch / HEAD before checkpoint / fetched main / merge-base:
**codex/v2-main-integration-20261024 / 3bd90284 / 009fb212 / 2b7bf3db**.
Canonical acoustic work is untouched. Tracked worktree is ready for the named
checkpoint; 1,573 proven EOL-only import rewrites are restored, with no semantic
sidecars discarded. Unrelated untracked UIDs remain. Protected indexed
paths: **17/17** match fetched main. Selector: **V2**, explicit V1 rollback.
Ledger before/after: not rerun for this focused repair; no promotion claimed.
Requirement changes from this INERT report: none.

The owner's latest review rejected the plain passage shop pull and muddy oak.
This changes the common native presentation for all eleven retained shop doors.
The door's dimensions, hinge datum, floor clearance, 90-degree travel, lock,
household/save and passage-priority owners remain in place. Three interaction
defects found during actual input are repaired below.

| Issue / location | Reproduction / severity | Evidence | Repair | Verification |
| --- | --- | --- | --- | --- |
| Pull appearance / eleven passage shops | Approach the plain, faceted straight grip; medium visual | Previous native pull view in the leaf-renewal archive | Cast bow with curved returns, lobed beaded backplate and slotted through-fixing heads, seated on solid latch timber | Three native views and four final imported views reviewed; actual-input programme passes |
| Unresolved wood / same leaves | Close view shows enlarged low-resolution grain and heavy brown multiplication; medium visual | Old oak source is 317 square pixels at 0.72 m effective tile; original review retained | Existing registered 1024-square **door_oak** at its canonical 0.6 m tile and untinted source colour; rails horizontal, stiles/panel vertical | Native/imported views reviewed; UV, source colour/scale and complete loaded mip counts pass |
| Dropped grab / wide leaf | Open from close range until the grip passes behind the camera; medium interaction | Initial imported programme loses the grip in both directions | Explicit fixed-direction gestures retain their latched contact through the camera plane; existing reach, focus and ownership checks remain | Final input retains grip through both stops |
| Lost first increment / door | Start a 240-pixel gesture after a rendered frame; medium interaction | Before/after trace shows the immediate angle read unchanged; end is 86.25 instead of 90 degrees | Suspend AnimatableBody physics synchronization while held, publishing direct hand motion immediately; resume on release | Final trace advances on the first event and both 240-pixel gestures reach 90 degrees |
| Rejected outward angle / passage leaf | Validate the negative snapshot of an outward-opening door; medium save validation | Initial test refuses its own snapshot | Apply the existing 100-degree legacy allowance in the declared swing direction | Both signs round-trip through the live validator/restorer; no disk reconstruction claimed |

This is an original period interpretation informed by the surviving 1925
[Sargent Colonial hardware catalogue](https://www.historicnewengland.org/explore/collections-access/gusn/267071).
Reference images are not baked or included. The existing door-oak material
already belongs to the catalogue; no texture files, new material keys, shaders
or shared material defaults change. Its linear source texel density is about
3.9 times the replaced plate at these physical scales.

The editable Blender file keeps 25 separate closed stocks. Export combines
the brass fittings into one mesh per side: nine meshes total, previously 13.
The first handle draft had 13,604 triangles; the reviewed final draft has
6,644, versus 2,124 in the old plain family. GLB grows from 318,848 to 983,492
bytes. This spends geometry on the requested close-view silhouette and
attachments; it is not a measured performance improvement. Native derivative
validation passes, with minimum tangent agreement above 0.9999999. Source
preflight passes. Aperture, owners and stop data compare equal.

The new finish diagnostic reuses the real player-input easy-door programme
with the production passage class, checking both swing directions, grabbing,
240-pixel motion, release, passage priority, slow closing, interruption, lock
authority, loaded UVs/maps and two-side rendered views. It performs no
environment impact/sweep tests. It is an isolated diagnostic, not occupied-world,
disk reconstruction, input-to-display latency or schema-2 runtime qualification.
The old historical sweep harness is not used as acceptance for this change.

The completed shipping-code input batch passes **619** passage finish/hand
checks in **75.34 s**, the ordinary-door **34** checks in **38.98 s**, original
device **70** checks in **18.24 s**, and world-space companion **83** checks in
**12.90 s**. All four wrapper receipts have completed=true, exit=0 and empty
stderr. The first imported run's five failures, the next two runs' two
failures, all motion traces and the original material preflight failure are
retained. A first device-control run separately failed radio acquisition once;
the unchanged device test passes in the final batch. Its cause is not isolated.

The first neutral Godot fixture supplied diffuse colour but no reflection
environment, making metallic brass too dark for a useful finish review.
The final visual rerun supplies a procedural reflection sky and checks the
exact expected mip-level count, rather than merely checking for some mipmaps.
The final visual rerun passes **619 checks in 69.60 s**, with an empty stderr
and completed exit-0 wrapper receipt. All four views are reviewed. An initial
attempt at that fixture used an invalid reflection enum and never entered the
test; only its verified owned engine was stopped, retaining the wrapper's
exit-minus-one receipt, exact parse stderr and executed source. This is not a
runtime verdict. The corrected enum is documented in the official Godot
[Environment reference](https://docs.godotengine.org/en/4.6/classes/class_environment.html).
These remain isolated diagnostics, with installed-world lighting acceptance open.

Current full surface qualification separately stopped before world composition
on the Mina retained-normal calibration expectation. The independent original
glTFs show Mina alone has a retained source normal, at the default 1.0 scale;
the other 17 use generated 0.35 atlas relief. The check now derives retained
normal calibration from the original asset; no shipping materials change.
The focused programme passes that calibration. Original stderr and wrapper
receipt remain preserved. Full-world surface qualification still needs a new
run and reviewed captures.

Gates: source preflight PASS; native tangent validation PASS; authored imports
**1,443 correct / 0 repairs**, exit 0; reader audit **NEW 0**, exit 0; spatial
dependency scan **clean, all drift categories empty**, exit 0. Design lint is
run before the checkpoint. Completeness, systemic/period gates, tool suites and the
full candidate verifier are not rerun for this focused checkpoint. The prior
integration board and its surface-binding regression remain reported in the
main merge review. No measured frame-time improvement is claimed here.

Changes outside the original art boundary: shared fixed-gesture handling,
DoorProp's held synchronization and independent source-normal test expectation,
each required by a reproduced failure. Open findings: installed passage
lighting, full world/access/save qualification, final main reconciliation,
initial render stall and the unresolved one-off radio acquisition failure.
Decision needed from owner: none. Broader V2 work remains active.

Byte-exact logs/receipts, failed programmes, reviewed native/imported images,
motion traces, import cleanup and exact executed test-source snapshots are in
**art/reviews/v2_passage_pull_finish_20261025**, with a SHA-256 manifest. The
wrapper files are **suite_run**, not test-written schema-2 runtime contracts.

BLOCKED for merge: current-source full-world qualification and latest-main reconciliation remain open.
