# Encroachment sweep equivalence — prepared, unrun

This is a focused actual-method comparison of the original case-outer sweep and
the proposed one-census sweep, both layered over the same reviewed registration
and ownership repair. It is outside the live game. No engine or timing result is
claimed.

The baseline is the exact 7c54c18154ccf8de8c3bce13a356329344dec19411adb2f1237425ae99eb90db
ownership candidate. The one-census candidate is
b5b977c6cdd83d4e60b1ea333822d26489651819efa3ed99163dcea180183a94 from the parent's
revisions/ownership_7c54c_01 package. prepare.py checks that nothing outside
reach_props differs. Adapted copies remove only the global class_name line
and normalize line endings so the real methods can coexist in one process.
Preloads and all methods, including real registry refresh, remain intact.

The independent source review found no definite blocker in the proposed
case/mesh loop interchange. Existing metadata remains authoritative; unclaimed
overlaps use the first authored case; the mesh census is new on each call; the
same state push and final storey refresh run. Existing owner annotations,
SurfacePass callbacks, field lifetime, and world geometry are not changed.

## Specimen and observable contract

The same deterministic specimen recipe is instantiated four times: baseline
and selected implementation in each of the two authored case orders. It uses
real SurfacePass-produced layered materials, actual MeshInstance3D overrides,
actual FunctionalProp, SubViewport/actor boundaries, actual LivingField
textures/classifier and production reach_props, _bind_storey,
_apply_prop_states, and _push_living_lifecycle methods.

The units' bounds, floor containers and intensity inputs are authored by this
fixture. It does not call build() or claim that a production case finish,
glTF floor, or real building was assembled. The unknown-owner specimen supplies
explicit imported/retired-case metadata as an input; ordinary known-owner
metadata is created by the first real sweep, then tested after moving/sharing.

Independent expectations cover:

- Seven initial and ten later case rows; two disjoint cases, overlapping bounds
  with reversed case order, a separate upper floor, and a rotated box whose
  center is outside the flat while its extent overlaps.
- Exact source pointers and albedo/roughness retention on separate installed
  copies; an already-owned material retains its owner and sharing after moving.
- A moved unclaimed draw, new node, and replaced full override discovered on a
  normal later sweep. Unknown owners remain untouched.
- Disabled and repeated/no-op calls; stable installed identities and unique
  active registry; stale exploration candidates are refreshed.
- Private SubViewport, CharacterBody3D, both shipped resident groups, NPC-named
  ancestors and queued deletion excluded; an ordinary FunctionalProp allowed.
- An actual SurfacePass-produced surface finish remains installed, retains its
  cache pointer, and receives field lifecycle updates. No manufactured finish
  row is offered as proof of production build().
- Numeric first/second mask expectations for two independent intensities, then
  immediate changed values on current installed draws. Real STAIN/EXCHANGE
  classification reaches those draws and the finish, preserves field texture
  pointers and leaves the upper floor on its own field.
- Detachment removes active case rows/registration; all four roots and owner
  nodes are actually freed before the footer. Process diagnostics must also
  show no resource retention.

Each phase records installed material sharing groups, case membership/order,
registry entries and all enumerated shader uniform values. Material sharing is
normalized by the first sorted draw/surface using each actual resource.
Floating values are normalized to 1e-6. Texture resources are represented by
class/path/dimensions and field identity, with separate direct pointer
assertions for the relevant field and copied source textures. This is a
source-bound comparison of this sweep change, not an arbitrary texture-pixel
or rendering equivalence proof. No render/performance/visual acceptance is
inferred.

## Selective source controls

priority.patch reverses only the inner selection of an unclaimed case.
Known metadata, eligibility, all state and registration work remain intact.
Both order-specific overlap oracles and matching snapshot comparisons must
fail; baseline checks and retirement must complete cleanly.

drop_late.patch retains the first mesh census in owner metadata. The exact
first/repeated phases must still compare equal; new-node ownership/state and
later membership/sharing comparisons must fail. The detached node stays alive
until synchronous calls finish, and snapshot serialization explicitly labels
detached rows. A freed-node/path diagnostic is not an accepted control failure.

gate.py keeps a selective red at diagnostic exit 1. It requires actual engine
exit 1, complete footer/JSON, both orders' named selective failure, zero baseline
or unrelated assertions, complete retirement, source stability, and no native,
script, warning, crash or retention diagnostic. A candidate requires engine 0,
all assertions and all twelve comparison phases equal. Any unexpected failure
is a new fixture or product issue, not an expected-red exception.

## Installation and execution proposal

Only after an explicit source/engine handoff, copy the six files beneath this
package's proposed/game/tests into matching live test paths. Do not replace
the live production owner for this focused comparison: each selected source
variant is a separately bound test copy. Run the unchanged
tools/run_godot_serial.ps1 against
res://tests/EncroachmentSweepEquivalenceTest.tscn, headless with --verbose,
timeout 60 seconds, unique SHOT_DIR and fresh process-local APPDATA.

Run selected modes candidate, priority, drop_late, then exact restored
candidate, using ENCROACH_SWEEP_VARIANT. Each process compares its selected
copy to the actual baseline itself. Preserve native exit, wrapper exit,
stdout/stderr, equivalence.json, duration, engine hash, exact command/env,
before/after project/runtime source hashes and copied source bytes. Retain all
failed preparation attempts; a source correction requires a new folder/run.
Do not reuse or delete the profile from an earlier run.

Require current frozen production dependencies to match at final handoff;
especially SurfacePass, LivingField, FunctionalProp and their shaders. If the
registration candidate changes, regenerate into a new revision rather than
calling these older copies current. The final comparison must be re-established
against the exact candidate actually proposed for production.

The parent still requires ownership-repair-only composed measurement first,
then the final real-root lifecycle/rendering and sampled transition proof.
This focused fixture cannot establish the time saved by the one-census change,
real build ownership completeness, actor route/arrival correctness, shader
appearance or release performance.

This new preparation supersedes the retained, unrun 69e28e package only for the final nullable living_source guard inherited outside reach_props. Earlier sources and receipts were not overwritten.

The subsequent gate-contract revision archives the exact earlier 17-control
preparation under gate_contract_revision/originals. expected_check_contract.json
binds the unchanged fixture hash and the declared 171 context/label rows in
their exact order: two setup checks, four sets of 38 specimen checks, twelve
phase comparisons, one fact check and four retirement/receipt checks.
A plausible shortened 150/150 footer, repeated label, or reordered label fails
even if all remaining rows and all twelve phase payloads appear clean.
The updated 19 pure controls are metadata/source tests only; the engine is
still unrun and 171 must not be lowered to accommodate an unexpected run.
