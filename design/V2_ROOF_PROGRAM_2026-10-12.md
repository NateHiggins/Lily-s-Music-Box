# REPORT — V2-ROOF-PROGRAM — 2026-10-12

Evidence class: **INERT**. Implementation and qualification report.

Branch / starting HEAD / origin/main: **main / c6366088 / c6366088**.
Clean comparison baseline: **06e74bf4**, the prior verified source candidate.
Owner decision required: **none**.

## Changes

The roof source now explicitly names the existing house-tank service and
public-core guarded lift machinery. Projection changes exactly two purpose
strings; all geometry, positions and other layout values remain unchanged.
A test-authored nine-space contract follows one continuous player route from
F06 through the roof service circuit and the existing guarded-drive checks.
The second circuit closes an already-open roof door through ordinary input
before its inherited closed-door checks. There is no second player placement.

The diagnostic also exposed accumulated scale drift in the carried-light
rotation. Both interpolation bases are now orthonormalized before slerp.
The final contract checks recovery from measured-size drift and convergence
to the intended aim. Positional lag and the existing lamp owner remain intact.

## Verification

The roof contract passes nine rooms, 80 waypoints and 175 checks, with zero
failures. It tests tank entry/recovery/service, independent lights, supply
bores, guarded machinery and real suspension motion. Its checkpoint records
which actions use ordinary input and which call production directors directly.
This grants scoped spatial access, not complete authority or human acceptance.

The combined surface run passes 25,763 checks with zero failures and zero
unresolved surfaces: 23,465 draws, 16,167 meshes, 5,827 materials and 445 textures.
The first-slice save/reconstruction contract passes all 113 checks. The
19-room apartment route passes 154 checks; the 43-room completion route also
passes with zero failures. All renewed receipts validate against the current
source hashes. Clean comparison is pending.

The sink pass requested by the owner is already implemented in the preceding
kitchen-faucet and casting batches. This run renews checks on all 18 sinks:
independent hot/cold/mixed water, targeting, fill/drain, boiler binding,
plug position, native drain bore and actual stand/countertop bearing.
Fresh 1A, 2A, 4B and 5C captures were reviewed. The standard frames support
outboard rails and saddles; compact bowls sit on their fitted frame or worktop.
No further sink source or geometry changes were needed for this renewal.

The reader audit reports zero new unread fields. Existing owner work remains
outside this batch. Only new test references are appended to the spatial
manifest; existing records and acceptance thresholds remain unchanged.

## Open findings

Full V2 remains incomplete. Before this batch the six blocker counts were
**0 / 1 / 103 / 34 / 120 / 122** (first slice, golden shift, structural,
runtime, production cutover, retirement). The finished comparison will record
the new counts. Godot still reports seven Texture RID leaks on shutdown;
resource-clean shutdown is not claimed. Existing modified and untracked owner
files remain in the shared checkout; this report does not claim a clean tree.

Packet: **art/renders/orison_v2/roof_program_20261012**.
