# V2 washer release and continuous seating — 2026-10-20

Evidence class: **INERT**. Mechanical repair and diagnostic checkpoint;
no runtime-contract, spatial or human acceptance promotion.

REPORT - V2-WASHER-RELEASE - 2026-10-20

Branch / HEAD / origin/main / merge-base: **codex/v2-fire-fitting-checkpoint**;
preceding checkpoint **7e43085c**; integration main/merge-base **82887a14**.
The shared canonical checkout contains inherited uncommitted work. This is
an incremental checkpoint; current-main integration is not approved here.

The corrected import binding's first full run, **surface7**, completed 38,996
checks with one failure: the **F02_FIRE_LINE_STAIR** washer did not seat on
release. Its separate technical inventory found zero UV/PBR/mip/filter defects
across 26,844 draws, 17,517 meshes, 6,389 materials and 500 textures. Its
test-written contract remains FAIL. Original contract, inventory, wrapper and
logs are preserved under **art/reviews/v2_washer_release_20261020**; none is
repinned or published as passing evidence.

A focused actual-input test at the production F02 affine frame disproved a
timing-only explanation: a washer released 181 micrometres above the seat fell
past the 100-micrometre fitting band during gravity. Gravity now sweeps to a
point inside a crossed fitting band, then calls the unchanged seating predicate
on its actual collision-constrained pose. No tolerance, inspection fact or
thread/repair authority changes. The test allows two completed physics ticks
after release rather than asserting before gravity has run.

A physical 0.2 mm obstruction exposed another issue: the convex motion sweep
could miss thin sheet stock. Sixteen downward body rays through the native
washer's bearing annulus supplement that sweep. They exclude only the washer,
retain the 20-micrometre contact clearance and accept hits only within the
proposed movement. Stable support still uses the existing weak-reference/pose
tracking. The rays are sampled supplemental collision coverage, not a claim
of exact continuous collision against every possible sub-sample object.

Final focused windowed results: unobstructed above-band release passes through
real mouse grab/motion/release, fitting, tightening, removal and household save
restoration. The obstruction case also passes: the washer stops 20 micrometres
above the introduced sheet, remains unfitted, and reports that actual collider
as its support. Earlier failed timing-only and initial obstruction experiments
are retained alongside those passing diagnostics. Wrapper receipts prove these
diagnostics ran; they do not independently grant ledger runtime proof.

Protected 17/17: no protected path changes. The original cabinet maintenance,
inspection, thread and household authorities remain. V2 default and explicit
V1 rollback remain. Ledger before -> after: no promotion requested;
requirements_changed: []. Changes outside the expected file boundary: nineteen
newly compressed atlas imports now retain the importer's actual VRAM-cache
remap metadata; their authored parameters are unchanged.

Focused spatial and reader gates pass, with zero NEW unread fields. Both trees
have matching 6,066-entry surface-input hashes after this repair. Two inherited
incidental test references remain reported by the spatial audit.

A complete 95-gate clean baseline was captured at **82887a14**, with zero dirty
paths. Its temporary checkout was removed after the board completed. It is
retained here for later candidate verification; incremental comparisons alone
do not establish a merge candidate.

Open work: a fresh complete composed surface run must bind these changed
production/test inputs and pass before surface publication or integration.
Seven historical Texture RID exit warnings, photoreal appearance work,
continuous gameplay, V1 retirement and whole-building human acceptance remain
open. The separate native door-guard Blender study remains uninstalled.
Decision needed from owner: none.
