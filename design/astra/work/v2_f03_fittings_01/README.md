# 3B domestic fittings — source checkpoint

Base: `5ecd79c938fbbab8b8143e22204eb9a4527e923a`. No Godot launched.

V2 now mounts the existing kitchen sink, gas stove, icebox, bathroom sink and
shower implementations through five named anchors. Original production marker
identities, unit 3B and appliance settings are preserved. The loader validates
records and anchors before mounting, restricts configurable properties, and uses
the existing adapter for lifetime ownership. Only the fridge has an existing
acoustic graph node; its position is rebound and restored through that adapter.
No acoustic identities or new repair jobs were invented.

The kitchen appliances form a run along the north wall with a 1.15 m reserved
work aisle. Five stance anchors and capsule stations accompany the fittings.
`placements.json` records conservative closed-body bounds estimated from the
existing prop source. The source check verifies exact anchor transforms, stance
and station correspondence, wall containment, closed-body separation, original
marker settings, older layout preservation and protected production files.
GDScript parsing uses gdtoolkit and does not establish Godot type correctness.
`author.py` reproduces the additions from the recorded base and refuses to
replace a layout that already contains changes.

The connected-world native fixture now checks all five production consumers,
interaction prompts, malformed/duplicate configuration rejection, and clearance
and floor support at the added stations in two reconstructions. It remains unrun.
Native mesh bounds, moving fridge/stove mechanisms, shower access, controller
ray targeting, saved state and visual acceptance are still unverified.

Fresh Python audit output is retained in `../../evidence/v2_f03_fittings_01`.
Systemic authority, interaction carriers, interaction implementors and audio
emitter audits and their self-tests pass. Completeness exits 2 with 114 cutover
blockers; data consumption exits 1 with no findings against the new fittings
file. Spatial dependencies and its live-repository self-test exit 1: 21 new
failing bindings include these new 3B references, previous F03 additions and
three optional F01 provider references. There are 17 classification changes,
no vanished targets and no unresolved save contracts. No baseline was refreshed
or failure suppressed. Audit self-tests other than the spatial live check pass.

3B still needs a WC, sleeping furniture and Omar's repair-work presentation.
Other F03 apartments, upper floors, traversal and the wider cutover contract
remain open. The V1 default selector is unchanged. Previous native receipts
remain evidence only for their recorded source hashes.
