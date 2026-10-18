# Bounded trim fitting and measured startup — 2026-10-18

Evidence class: **INERT**. Implementation and diagnostic report. No spatial,
runtime, human or photoreal acceptance comes from this document.

The current rendered-world startup profile measured 99.21 seconds. Its broad
stage marks locate expensive construction work; they do not isolate every
statement within a stage. The trim experiment follows that measurement rather
than assuming that a conspicuous triangle loop owns the startup cost.

The first experiment compared native replacement filtering across 74 actual
programmes and 275 source draws. Both repetitions retained identical serialized
mesh buffers and removal counts. The proposed helper took 0.18 seconds against
0.62 seconds for the original across both repetitions. That small absolute
saving does not justify claiming a major startup repair. The helper is retained
as a rejected production candidate; shipping replacement logic is unchanged.

Room trim previously considered wall stock across all storeys before clipping
the resulting profiles back into the room's vertical band. The bounded filter
retains stock intersecting or touching that band, including tall walls crossing
storeys, in its original order. Face extraction, visible-return subtraction,
corner ownership, profile generation, casing cuts and materials remain their
existing authorities. No profile, material, contact tolerance or UV is changed.

The first windowed source-stock comparison covered all 216 enclosed rooms and
12,390 generated instances. Original and filtered compositions had identical
instance buffers, source identities, meshes, materials and separate-cap flags.
The measured fitting work took 11.65 seconds before and 0.82 seconds after in
that diagnostic. This is a same-run fitting measurement, not a guaranteed
whole-game startup improvement. A second run exercises the shipping filter
against a retained unculled composition reference.

The composed surface suite now repeats the differential check in the actual
production frame, including current window and service clearances. Its new
reference and review scripts participate in the surface input digest. This
matters because a zero-origin source bench alone cannot establish that the
transformed production room produces the same fitted instances.

The first startup probe was explicitly stopped after its source preparation
failed, before it could produce a valid profile. A later headless profile
refused a MultiMesh trim pose. Neither is accepted as a successful world run.
The windowed profile completed with 218 stage marks and no script errors.
Original logs, wrappers, probe sources and measurement JSON are retained in
**art/reviews/v2_startup_trim_20261018/**. The probes do not own game state.

## Management report

    REPORT - V2-STARTUP-TRIM - 2026-10-18
    Branch / HEAD / origin/main / merge-base: main / pending source commit / de076e789b834b7b1290dbac8c5d657d6a11f748 / de076e789b834b7b1290dbac8c5d657d6a11f748
    Worktree clean at end: no; inherited shared-checkout changes are excluded.
    Protected 17/17: pending clean comparison. Selector: v2; explicit v1 rollback retained.
    Ledger before -> after: 0/1/48/25/65/67 -> pending qualification; no new grant requested.
    Gates: reader NEW0; physical-input tools tests 11 pass; complete clean comparison pending.
    Godot receipts: profile1 PASS 275/0; startup3 completed PASS 218 stage marks; millwork1 and millwork2 completed PASS 216/0. These are INERT diagnostics, not runtime grants.
    Numbers: 1715 source walls; 216 enclosed rooms; 12390 source-bench instances; 11.65 -> 0.82 seconds same-run fitting.
    Changes outside expected boundary: surface digest explicitly registers both differential review sources; original replacement filtering remains unchanged.
    Open findings: composed qualification, whole-startup measurement and clean comparison remain pending. Broader V2 obligations and human/photoreal acceptance remain open.
    Decision needed from owner: none for the authorized build/performance work.
    BLOCKED composed qualification and clean comparison pending
