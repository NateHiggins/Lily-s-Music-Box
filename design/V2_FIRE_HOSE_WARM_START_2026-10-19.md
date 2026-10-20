# REPORT - V2-FIRE-HOSE-NATIVE-WARM - 2026-10-19

Evidence class: **INERT**. Scoped profiling and numerical/rendered diagnostics.
No runtime-contract, ledger promotion, installation or human acceptance.

Branch / HEAD / origin/main / merge-base: **codex/v2-fire-fitting-checkpoint** /
pre-write **bf63163c7c2be83a008839cf0de5d96d68b6fc2b** /
**82887a14d08357a400047624a6ce720351a748e0** / **82887a14**.
Worktree clean at end: isolated checkpoint committed after this report;
canonical main retains inherited shared work and named owned staging.
Protected 17/17: **no fresh verification**; no protected path edited here.
Selector: V2 retained, without renewed composed qualification.
Ledger before -> after: not re-audited -> not re-audited;
requirements_changed: none claimed. Historical evidence is not repinned.

## Result and numbers

The mass solver now calls a compiled version of its existing warm start.
The collapsed-bend repair, support projections, tridiagonal/banded solves,
Float32 vector operation order, Float64 factors, 8/128 work budgets and
early/final acceptance criteria remain. The extracted GDScript implementation
is retained as the reference and non-native fallback. The joint solver still
follows the warm start; the rejected direct-first shortcut was not revived.

All four saved warm inputs produce exactly equal coordinates, accepted flags
and iteration counts in native/reference comparison. Fixture calculations
are about 35-44 times faster. Checks also reject nonfinite native positions,
wrong hint count and nonfinite hints. Existing joint position/velocity parity,
independent residuals and kinetic-energy checks continue to pass.

Both windowed runs complete the same twelve free and 24 supported steps.
Their final saved pose, every per-step physics field, initial/final energy
and subdivision counts compare exactly equal. Supported energy remains
60.38629743 -> 51.16293544 at unit line density; free mean drop is 47.0098 mm.
Actual grabbing, mouse motion, release, lengths, fixed outlet, native sweeps,
skin, authored UV/custom PBR/loaded mips and reduced voxel-light checks pass.

| Supported-phase cost | GDScript warm baseline | Native warm |
| --- | ---: | ---: |
| Whole 0.2 s simulation | 45.434 s | 24.871 s |
| Position projection, including joint | 40.328 s | 19.740 s |
| Joint projection subtotal | 19.008 s | 19.243 s |
| Warm start and bridge, by subtraction | 21.320 s | 0.497 s |
| World-contact queries | 4.075 s | 4.105 s |
| Final swept veto | 0.637 s | 0.641 s |
| Velocity projection | 0.134 s | 0.138 s |
| Accepted skin updates | 0.018 s | 0.018 s |

This removes about 45% of this phase's elapsed time. It does **not** make
the simulation real time. Joint projection is a subtotal of position cost;
the table must not be summed without subtracting that overlap.

## Gates and records

Packet: **art/reviews/v2_fire_hose_native_warm_20261019**. It preserves the
original receipts, source variants, build log, comparison script, raw traces
and selected viewed current frames. Comparison JSON is INERT analysis.

| Original run | Wrapper result |
| --- | --- |
| stage30_profile1 | PASS, 67.74 s, instrumented GDScript warm baseline. |
| stage30_math1 | PASS, 6.45 s, saved joint and warm-reference cases. |
| stage30_native1 | PASS, 46.42 s, current rendered combined programme. |
| stage30_math2 | PASS, 6.45 s, current numerical harness and native input rejection. |

All four have empty stderr. The native source/DLL build binding passes;
reader baseline reports zero NEW fields. Design lint, filtered source diff
checks and candidate/current receipt binding accompany the checkpoint.
The unchanged evidence-selection tools retain their earlier 11 receipt and
27 surface-tool test passes; no unnecessary rerun is claimed. No full gate
board, candidate verifier, route, protected-path or surface-inventory renewal
was performed. The historical **5d7fe292** full verifier still had 114
regressions and is not a current result.

## Boundaries and remaining work

Outside the numerical port: timing fields identify projection, contact,
velocity, skin and rollback costs; the small numerical harness compares warm
outputs and rejects invalid inputs. Documentation points to this scope.
No Blender mesh, material, cabinet, mechanical fact, inventory, NPC or save
authority changes here. The compiled path is qualified only on Windows x64.

The viewed frame still shows overlapping cloth and an uncoupled fitting.
The candidate remains outside all eight cabinets. Joint/contact performance,
self-contact, material bend/twist, sustained settling, held-end/nozzle/rack
coupling, withdrawal/refolding and installed persistence remain unfinished.
Seven historical composed texture-RID shutdown warnings remain open. Broader
V2 completion and human appearance acceptance remain **OPEN**.

Decision needed from owner: none. Continue the now-measured joint/contact
bottlenecks and physical cloth integration, then renew composed qualification.

BLOCKED merge readiness: full hose physics, installation, real-time cost,
regression qualification and human appearance remain open.
