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

The clean preflight refused the old front-trim discovery binding after the
millwork source changed. A new windowed discovery observed all 9,085 source
instances exactly equal to the prior snapshot. The existing projection remains
42 fittings and 154 bounded cuts. Only the newly observed binding is published;
the prior snapshot, original run and exact comparison remain under
**trim_discovery/**. Five front-trim tools tests pass. No old runtime receipt
was repinned to the new source.

The first startup probe was explicitly stopped after its source preparation
failed, before it could produce a valid profile. A later headless profile
refused a MultiMesh trim pose. Neither is accepted as a successful world run.
The windowed profile completed with 218 stage marks and no script errors.
Original logs, wrappers, probe sources and measurement JSON are retained in
**art/reviews/v2_startup_trim_20261018/**. The probes do not own game state.

The actual composed comparison passed all 216 enclosed rooms and 12,392
generated instances with identical buffers and sources. Its fitting totals were
11.35 seconds unculled and 0.85 seconds culled. The source specimen and
production frame have different instance counts; equality is checked within
each actual frame. The surface suite passed 33,067 checks with zero failures;
28 current views were reviewed. The actual repair/save proof passed 360 checks.
The home cohort passed 62 rooms, nine legs and 909 checks; the upper cohort
passed 69 rooms, eleven legs and 989 checks. These are original test-written
contracts with matching completed wrappers and raw logs. No old receipt was
repinned.

The new surface run measured 96.11 seconds at world startup versus 99.21 in
the earlier windowed probe. That comparison is not controlled for cache/load;
it is not a guaranteed whole-startup improvement. The reproducible fitting
comparison above supplies the narrower timing evidence. Broader construction
costs, finish quality, navigation/performance and human acceptance remain open.

The final clean candidate comparison is retained under **final_verification/**.
It reports zero regressions, 17 unchanged protected paths and unchanged scoped
readiness. The added clock source test passes; the uninstalled clock and oak
artifacts supply no runtime or human grant.

## Management report

    REPORT - V2-STARTUP-TRIM - 2026-10-18
    Branch / HEAD / origin/main / merge-base: main / 69be3796af1ddef2cde5484e5bb6541e508009b1 (verified source/proof and uninstalled-art checkpoint; this report is a metadata follow-up) / de076e789b834b7b1290dbac8c5d657d6a11f748 / de076e789b834b7b1290dbac8c5d657d6a11f748
    Worktree clean at end: no; inherited shared-checkout changes are excluded.
    Protected 17/17: unchanged in the clean candidate comparison. Selector: v2; explicit v1 rollback retained.
    Ledger before -> after: 0/1/48/25/65/67 -> 0/1/48/25/65/67; requirements_changed: [].
    Gates: reader NEW0; complete clean comparison has 84 gates, 72 passing tools suites and zero regressions. The new clock-source test is an additional passing gate.
    Godot receipts: original test-written contracts and matching wrappers/raw logs: surface1 PASS 33067/0, service1 PASS 360/0, home1 PASS 62/9/909/0, upper1 PASS 69/11/989/0. Earlier profiles and source benches remain INERT diagnostics.
    Numbers: 1715 source walls; 216 enclosed rooms; 12390 source-bench instances; 11.65 -> 0.82 seconds same-run fitting.
    Changes outside expected boundary: surface digest explicitly registers both differential review sources; original replacement filtering remains unchanged.
    Open findings: whole-startup bottlenecks, broader V2 obligations and human/photoreal acceptance remain open. The clock and oak material candidates are uninstalled and unqualified for runtime. Seven existing Texture RID shutdown warnings remain.
    Decision needed from owner: none for the authorized build/performance work.
    READY verified source/proof checkpoint; no whole-V2 or human acceptance.
