# Final base V1 execution verification

`candidate_v1_material_final_01` passes the final base-fixture contract:
**305/305 checks, actual engine 0, replayed diagnostic gate 0**. All 305 labels
match `viewport_guard_final_01_restored` in their exact order, including
repeated labels. All 62 retained artifacts and 32 source copies verify.

The before/after 4,045-path game/tools maps are identical within the final run.
The exact owner is `1a1b067f…`, BuildingRoot `cde44cd1…`, base fixture
`5ec63c36…` and scene `b9508089…`. Engine binaries and wrapper/gate/serial-runner
identities are stable and equal to the reference. Across the reference and
final run, the recorded source differences are the apartment owner and four
inactive equivalence copies. That is contract continuity, not a controlled
timing comparison.

All 18 expected PNG names, hashes and dimensions verify. The fixture completes
36 transitions in its six-cycle loop, five separate warmups, one Harukiya
capture return and one pre-retirement Passage return. Each transition retains
four sampled rendered frames and a separate 16-scan measurement. Actual shell
and selected-world WeakRefs are released; raw diagnostics contain no retained
resource report. The full separate-world control and both blocker-release
orders remain exercised.

## Raw diagnostics

Replaying the exact retained gate against the raw logs reproduces its recorded
classification exactly: zero unpair errors, zero soft-shadow
underflows, zero non-inherited error headers and no retention diagnostics.
The logs still contain five known external Vulkan manifest-loader error
entries, two loader warnings, 1,038 RGB8 conversion warnings and the existing
`cam_noel_witches` legal-wall placement warning. Those records are retained;
gate zero does not mean empty stderr.

## Direction-specific synchronous apply timings

These medians measure the visibility call, not total frame time or native
no-op call count. Warmups and the two one-off returns are excluded from the
main table. The JSON retains every sample, mean, extrema and nearest-rank p95.

| Main-loop direction | n | Median ms |
|---|---:|---:|
| Harukiya → Street, first cycle | 1 | 35.239 |
| Street → Passage | 6 | 1195.793 |
| Passage → Street | 6 | 1182.595 |
| Street → Orison | 6 | 40.123 |
| Orison → F04 | 6 | 4.280 |
| F04 → Orison | 6 | 3.126 |
| Orison → Street, later cycles | 5 | 37.155 |

The post-loop Orison→Harukiya return takes 2.642 ms. The post-control
Orison→Passage retirement return takes 1153.806 ms after the fixture's explicit
Orison visibility reset. Each has only one sample.

Across 144 main-loop sampled frames, budget observations are 1.0×60, 0.75×29,
0.5×15, 0.25×25 and 0.0×15. The governor remains adaptive. These substantial
Street–Passage stalls and variable budgets provide no fixed-quality speedup,
release-FPS, or confidence-interval claim.

## Scope and supplied visual review

This is the base fixture: it contains no material probe. Complete registered
lifecycle restoration and per-material retirement remain claims of the
separate `d67` observer receipts. This run verifies actual-root controlled
teleports, rendering, ownership and root retirement; it does not establish
player traversal or human acceptance.

Root independently reviewed all 18 final PNGs and reported recognizable
populated cabinet, Passage, lobby and F04 views, plus distinct initial,
restored and blocked square-control states. Root also retained the very dark
Harukiya/street views, foreground construction obstruction, coarse held model
and reflection bands as visual limitations. This supplied review adds no new
art or readability acceptance; this verifier checked image bytes and metadata.

Machine review: `final_v1_material_execution_review.json`, SHA256
`27e6f1f6b21a637c3400656c16a39742cd914845aafcc80ebad6d1c899c05d3c`.
Source result: `94babcd295c78c1212b8eaddb5aef55aa4f7e54f86606ee5ebbc8a1e04b89f9d`.
