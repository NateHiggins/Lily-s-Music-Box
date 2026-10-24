# Physical service-set UI and flush ceiling listener

Evidence class: **INERT**. Scoped diagnostics and a test-written composed
contract; not whole-V2 or human acceptance.

## Scope and authority

On 2026-10-23 the owner authorized autonomous Godot use again. Earlier notes
requiring approval are historical. Shared-lane wrappers remain mandatory.
The owner also requested flush ceiling detectors and an efficient physical UI.

The native Vantry 28-R is installed. Removing the duplicate procedural body
changes 384 MeshInstance3D nodes to 29 native partitions /22,522 source triangles.
The radio, WorkOrders, incoming-call, optical lamp, receipt-count and retained-
copy APIs remain the owners. Optical material references now bind the actual
native lens/jewels. Rear speaker/mouthpiece fittings and the continuous paper
path come from the Blender recipe; no GLB was hand-edited.

The instrument stays visible low at the right while walking. Raising it uses
40% of viewport width instead of a fixed right third; the viewport resizes only
on pose/window changes. Thirty columns and ten rows retain full messages across
pages. Finished copy feeds 20mm clear of the head; the platen/finger wheels
follow the authored 8mm roller radius. The fixed web stays seated while ink
advances through the viewing window. Metadata no longer overprints the title.
Full direct grabbing of the handheld's own controls remains migration work;
existing keyboard/wheel seams are retained.

## Issue log

| Location | Reproduction / severity | Evidence | Repair | Verification |
|---|---|---|---|---|
| Writer | At 48 characters/s, child double-consumes frame time and hides impression; high | **installed_stock/runtime_v1/** has near-zero peak | Parent residual character phase; bounded seating | Actual loop reaches 1.55mm; all three banks observed |
| Cooling | Emission off can leave live smoke visible; medium | Lifetime inspection | Hide particle draw and stop singe on cancellation | Actual power-off check |
| Materials | White imported stock and atlas without mips; high | **hot_type/runtime_v1/** | Catalogue binding and V2 atlas policy coverage | Loaded PBR/atlas mips pass |
| Import | Lossy mesh compression damages tiny UVs/derivatives; high | **imported_surfaces_v1.log**, worst tangent dot about 0.929 | Disable compression for this GLB, retaining GPU texture compression | All 29 imported metric charts and derivatives pass unchanged checks |
| Teardown | Whole-mesh overrides stacked over surface overrides produce null-material errors; medium | Ordered diagnostics **runtime_v4-v6/** | Surface overrides consistently | Normal printing/history/full unmount has no renderer errors |
| Readout | Head hides last lines and footer intersects title; medium | **profile_after/held_idle.png** and **runtime_v1/02_full_page.png** | Ten-row layout, raised metadata and delivery feed | Shaped text fits physical stock; final renders reviewed |
| 2A listener | Root is1.25 m above floor rather than at 3 m ceiling; high | Original anchor and owner backplate datum | Raise existing anchor | Five unfiltered ceiling rays within 1 mm |
| Grille | Legacy toggle does not prove overhead service; medium | No prior manipulation descriptor | Moving reach area, 160 px captive gesture, inspection view | Actual standing grab, pull, Space, free-cursor grab, push and release |
| Acoustics | Changed mount correctly refuses stale source binding; diagnostic | **profile_ui_final.log** | Rerun three source generators; normalize heating generator LF output | 28 tools tests; unchanged route/node content; composed startup passes |

The listener remains the Bible's1912 Vantry point and carbon-capsule repair.
Hand inspection reports through the existing inspected signal. It cannot invent
inventory or a successful repair. Only the one currently composed V2 listener
was surveyed, not 119 V1 placements. Its legacy surface finish and intermediate
grille-travel save/reconstruction are not qualified by this mount repair.

## Measurements

Packet **art/reviews/v2_handheld_20261023/**. **profile_before/** and
**profile_ui_v2/** use the same occupied 2A scene, 1280x720 Forward+, uncapped
frames, VSync off and identical 300-physics-tick movement/turning input per phase.
There are 894 and 928 raw observations. Captures/readbacks are outside samples;
the first partial interval per phase is excluded in **performance_comparison.json**.

| Phase | Before p50 / p95 / p99 / max ms | After p50 / p95 / p99 / max ms |
|---|---|---|
| First field report |21.36 /33.47 /43.81 /323.31 |20.87 /32.21 /39.70 /322.44 |
| Steady printing |20.79 /28.02 /34.84 /68.23 |19.76 /26.46 /29.20 /36.18 |
| Raised idle |19.87 /27.18 /31.34 /76.86 |19.92 /26.09 /27.52 /28.57 |
| Carried/lowered |20.61 /26.88 /30.70 /39.45 |19.65 /26.39 /28.92 /38.91 |

Steady-print held CPU median: 0.347 -> 0.140ms; GPU: 0.086 -> 0.080ms. The new
lowered pose renders the instrument, whereas the old pose hid it. One short
paired route is not a universal improvement. The approximately 322 ms first-use
spike remains, coinciding with 90 new surface pipelines and main-render/physics
work rather than a large held GPU cost. Process/physics monitors lag and overlap
rendering. Asset-load/streaming costs are not independently isolated here.
First field report is in an initialized world, not a cleared driver cache;
the always-visible pose can warm the instrument earlier than the old hidden pose.

Next investigate late room ReflectionProbe activation: a plausible source of
the pipeline burst, not a causal finding yet. Godot's [pipeline guidance](https://docs.godotengine.org/en/stable/tutorials/performance/pipeline_compilations.html)
describes declaring features before loading most geometry. Measure a controlled
early-feature treatment, preserving lighting/detail, before adopting it.

## Evidence and limitations

- **installed_stock/imported_surfaces_v2.log.receipt.json**: 51 direct checks
  plus shared metric/derivative checks on all 29 imported partitions; pass.
- **installed_stock/readout_final.log.receipt.json**: 21 production printer/state
  checks, complete pages, physical bounds, stop/rest and full unmount; pass.
  This isolated fixture is diagnostic, not a campaign contract.
- **profile_ui_v2/runtime_contract.json**: test-written schema-2 composed
  contract, 24 listener checks, two actual grabs, unchanged runtime digest;
  ceiling mount, direct manipulation and inspection cursor pass.
- **profile_ui_v2.log.receipt.json**: wrapper completion, not the contract.
  The baseline's existing seven texture-RID shutdown warning remains.

Original setup, compression, timing, stale-binding and teardown failures are
retained. No human sound/appearance acceptance, all-cell transition proof or
whole-V2 completion. The provisional singe is a quiet relay excerpt; smoke is
three short particles, with no new world light/shadow map or postprocess.
Remaining native case/feed detail and handheld-control hand migration stay open.

## Report

REPORT - physical-device-and-ceiling - 2026-10-23

Branch **codex/v2-acoustic-topology**, starting HEAD **99ea932d**. Named source,
art, tests, generated acoustics and review paths only. The unrelated spatial
dependency manifest remains unstaged. Extra acoustic paths are necessary
because the moved mount is a bound physical source; generators confirmed
unchanged network/route content. No catalogue keys or ledger requirements added.
Selector remains V2 with explicit V1 rollback. Static board: **gates/**.
All 17 protected paths are unchanged from the starting HEAD. The first board
exposed a stale trim snapshot after the anchor move. Fresh windowed discovery
observed 7,955 exactly identical source instances; the unchanged runtime trim
projection and all five trim tools tests pass. See **trim_source/** and
**gates_followup_staged/**. The two census-test failures identify the unrelated
unclassified **street_film_viewer.gd** and its extra prompt; they were not
silently rebaselined. Untracked street/tent physical inputs remain outside this
checkpoint. Global surface/rendered-review qualification is stale and needs
renewal; this local imported-surface pass does not replace it.
No clean merge-base board or management certificate. Reader remains 33 existing
NEW street/tent findings, with zero unread new device fields. Broad world
stutter, hose installation/save and the remaining V2 area/interaction work are open.

NEEDS-OWNER subjective appearance/audio acceptance only; no operational Godot
permission is pending, and autonomous repair work may continue.
