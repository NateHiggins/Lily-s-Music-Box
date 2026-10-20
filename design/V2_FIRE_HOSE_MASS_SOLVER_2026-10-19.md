# REPORT - V2-FIRE-HOSE-MASS - 2026-10-19

Evidence class: **INERT**. Uninstalled prototype and failed qualification.
No ledger promotion, completed deployment or human appearance acceptance.

Branch / HEAD / origin/main / merge-base: **codex/v2-fire-fitting-checkpoint** /
pre-write **8113bba08fb7df4b84d609e38a1436ca52da7e49** /
**82887a14d08357a400047624a6ce720351a748e0** / **82887a14**.
Worktree clean at end: the isolated checkpoint checkout is committed after
this report; the canonical shared checkout remains dirty with inherited work.
Protected 17/17: **no fresh verification**; this phase edits no protected path.
Selector: V2 retained; not independently requalified in this phase.
Ledger before -> after: not re-audited -> not re-audited;
requirements_changed: none claimed by this INERT document.

## Result and numbers

The new mass-aware kernel completes twelve bounded free-fall steps without
triggering the energy guard. Mean ring height falls approximately 47.01 mm;
the original segment lengths and fixed outlet remain valid. This improves
on the previous one-sided solver, which rejected free fall after about
6.55 mm of mean drop. It does not prove sustained release or settled cloth.

The penultimate diagnostic **stage27_mass9** remains **FAIL**. Floor
release stops at step 11 because the finite-bend residual reaches
20.06096 micrometres against a 20-micrometre bound. Length residuals at that
failure are approximately 0.988 micrometres per interval and 3.567 micrometres
accumulated. The rejected proposal is not applied. Supported energy falls
from 60.43765 to 59.09449. This is a convergence failure, not an energy pass
being treated as complete physics.

An offline replay of that exact case finds that one mass-balanced bend pass
meets all geometric bounds; a fourth repeated pass violates total length.
The final **stage27_mass10** adds a single bounded correction with full
revalidation. It resolves the subcase but encounters another native contact
and still **FAILS** supported release at step 11. That next kernel case has
approximately 10.14 micrometres interval error, 21.95 micrometres accumulated
error and 77.41 micrometres bend error. It is rejected, not installed.

The native asset remains 15.24 m, 3,472 rings and 444,416 triangles. No Blender
asset, material catalogue key, original maintenance authority or installed
cabinet was changed in this phase.

## Implementation and comparison

Material-length masses and a zero-inverse-mass outlet replace the one-sided
anchor-to-end projection. Adjacent distance constraints use a global
tridiagonal solve with Float64 factorization. Tangent-velocity projection
removes constraint-violating motion before the existing energy check.

A provisional 3 mm minimum bend radius prevents zero-radius hairpins and
undefined native skin tangents. The tightest authored rest radius measures
about 4.74 mm, so this bound preserves that stock. Two-interval bend rows
couple with length rows in an interleaved banded factorization. This is a
geometric bend limit, not calibrated elastic bend stiffness or twist response.

Support inequalities are projected separately. Treating every first contact
as a fixed equality overconstrained the varying cloth section; later runs
allow those positional constraints to release. Contact and bend projection
still compete and must converge before installation.

The kernel tries stricter 1-micrometre per-interval and 5-micrometre total
targets for early exit. At the iteration limit it admits only the original
length owner's unchanged 20-micrometre per-interval AND total bounds. The
finite-bend bound uses that same spatial precision. The caller independently
checks original lengths, native swept collision and energy. No failed
20-micrometre check was waived in the final run.

Contact normals are refined with a local ray against the same actual collider
surface. A missing shallow first-contact manifold can be probed at a prefix
advanced by at most 10 micrometres of vertex travel. The collision predicate
and one-micrometre narrow-phase margin remain unchanged. Invalid contact data
still rejects the proposal. This does not establish exact rigid-rotation CCD.

## Gates and original evidence

The packet is **art/reviews/v2_fire_hose_mass_20261019**. It retains all ten
original run logs, wrapper receipts, captured intermediate sources and final
post-run source copies. Six selected reviewed renders show free and supported
motion; repeated unchanged surface frames remain in the original temporary
run folders. No receipt is repinned.

- **mass1**: FAIL; free fall succeeds, positional support was overconstrained.
- **mass2/3**: FAIL; global support projection reaches its iteration limit.
- **mass4/5**: FAIL; a collapsed native tangent exposes the need for a bend
  limit. Missing-manifold fallback alone does not solve that geometry.
- **mass6–8**: FAIL; finite bend and extension need coupled convergence.
- **mass9**: FAIL, wrapper completed in 25.17 s, empty stderr. Free fall,
  native bend validity of accepted poses, atomic rejection, energy, original
  lengths, authored UV/PBR/loaded mips, bone deformation, hollow contact,
  transformed binding, JSON and actual grab/motion/release checks pass.
  Supported release completion remains failed.
- **mass10**: FAIL, completed in 26.87 s with empty stderr. Those same checks
  remain true, with the final accepted pose unchanged and the new convergence
  case exported. The failed test has not been removed or weakened.

The final **kernel_case.json** records the exact target, final iterate,
support planes, lengths, masses and bend spans for replay outside a full
rendered composition. The NumPy tool **tools/analyze_hose_constraint_case.py**
replays bounded corrections on an exported case without launching Godot.
Its **geometric_bounds_only** result explicitly excludes collision, energy,
native skin and appearance proof. **gravity_trace.json** records accepted step energies
and the final accepted pose. These are diagnostic data, not runtime contracts.
Reader and design lint are recorded with the checkpoint; no complete board,
tools battery, protected-path verification or global runtime renewal is claimed.

## Open findings and decisions

The render no longer shows the earlier explosive upward whipping. It still
shows creasing, unresolved cloth self-contact and an uncoupled bench fitting.
Human appearance acceptance remains **OPEN**. The prototype is bench-only;
the eight cabinets continue using their prior installed owners.

Required next work: replay the saved convergence case, resolve contact/bend
inequalities without relaxing bounds, then add sustained stability, elastic
bend/twist response, self-contact and real-time performance. Fitting/nozzle
coupling, held-end constraints, rack support/release, physical refolding,
household reconstruction and installed qualification remain unfinished.

Changes outside expected boundary: the new mass kernel is required for the
release solver; the packet and this report preserve its evidence. No owner
decision is needed. The full V2 goal remains active. The last full verifier
at **5d7fe292** still reports 114 broader regressions and is not renewed here;
seven earlier composed texture RID shutdown warnings remain open.

BLOCKED supported-release convergence; WIP draft is not a merge candidate.
