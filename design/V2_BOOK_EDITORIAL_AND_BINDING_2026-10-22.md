# Book editorial, continuous covers and attached pages — 2026-10-22

Evidence class: **INERT**. Scoped repairs, diagnostics and continuation only.

Follow-up: the open bookend sole finding below is subsequently repaired in
**design/V2_BOOKEND_BEARING_2026-10-22.md**. The original failure and this
checkpoint's original diagnostic packet remain unchanged.

| Location / severity | Reproduction / evidence | Repair / verification |
|---|---|---|
| Primary thirty bindings / high visual defect | Open covers expose a rigid rotated block rather than attached gatherings. | Native Blender deformation targets fan the text block into a shared sewn gutter and bow the top sheets. Hardbacks retain rigid boards and a hollow case spine. All thirty fully open gutters meet within 0.1 micrometre; 1,312 posed stock checks retain positive volume. These checks do not prove every possible self-intersection absent. |
| Eleven soft bindings / high visual defect | Separate thick covers and spine read as a hard case. | Each paperback/pamphlet has one connected thin stock wrapper, spanning back, spine and front with flexible folds. Eleven connected-component checks pass. Paper PBR preserves loaded normals/mips; hidden native contact templates retain physical protection. No stored paper simulation. |
| Book print / high readability defect | Flat ink disappears into the bowed left page; close light washes out text. | Derive print positions, normals and tangents from the imported page profile; matte physical glyphs, MSAA cutout coverage and cursor-centred reading zoom. The view rotates at its fixed eye; the floating binding stays static. Full-spread text remains small; zoom is needed. |
| Cover input / high latency | Actual constrained motion repeatedly rebuilds glyph meshes at every collision subdivision. | Keep every 0.02-radian obstruction check; apply the last accepted visible/physical pose once per mouse event. Matched 36-event input runs reduce handler p95 from 26.887 to 8.247 ms. First-use maximum remains 44.451 ms. |
| Held stock / high physical defect | Carried book contacts its player, pushes the player away and fails to reach the hand. | Temporary bidirectional carrier-only collision exceptions, shared by the native hand sweeps. Restore only exceptions owned by the grab on release/inspection. External stock, walls and mechanisms still block. Played world reaches its exact requested held centre with zero own-book contact samples. |
| Released book / high physical defect | Combined convex envelope jitters on the floor after a real 24-metre carry. | Controlled drop: combined hull still moving at 600 frames; original three native groups settle in 73. Retain compact hand/parked queries, restore native physical groups on release, inspection exit and loose save restoration. No forced sleep, damping workaround or disabled floor protection. |
| Shelf bearings / medium | New coherent sizes expose book/bookend heel intersections. | Fit heel positions against actual native depth and raise supported bindings from actual bearing stock. Three case styles are checked for initial overlap. Four passive native keepsakes add cup, letter packet, inkwell and model boat; cup mouth stays open through native concave static contact. |
| Loose bookend / OPEN medium collision defect | Downward input moves a repaired-case bookend sole from 0.833850 to 0.832430 m against a 0.833500 m shelf. | Original native cast/rest contact stops the metal piece but permits about 1.07 mm felt penetration. Neither a speculative damping change nor endpoint/plane refinements repaired it; those experiments are removed. The strict above-shelf assertion remains failing. Continue with the actual compound native contact, preserving collision protection. |
| Library saves / high compatibility | Earlier stored slot poses describe the old sizes. | Schema 4 includes geometry identity; schemas 2/3 refit parked copies to current authored spots while preserving loose poses, book order, move count and door authority. Actual-input bench includes displaced schema-3 slots and a separate loose copy. |

## Editorial programme

Authoring source: **art/data/readable_library/editorial.json**. The thirty
existing identities remain stable. Five formats supply pocket paperback,
trade hardback, reference/encyclopedia, illustrated/picture book and stitched
pamphlet dimensions. Thickness follows leaf count and stock thickness.

**Aster & Quay** supplies restrained literary/nature/verse editions;
**Darrow Scientific & Practical Books** supplies technical and workshop
editions. Private/local imprints preserve personal and civic editions.
Seven layouts cover fiction, manuals, two-column reference, illustrated
spreads, verse, ledgers and pamphlets. Nine retitles retain their old titles
as subtitles; the former generic etiquette volume becomes **Letters to an
Empty House**, original epistolary fiction retaining the condolence motif.
Ten protected case excerpts are byte-preserved by the publishing script.

Four original built-in imagegen illustrations accompany the editing pass;
prompts, generation provenance and hashes are retained under
**art/illustrations/book_editorial_20261022**. Reference photographs inform
binding form only and are neither baked nor committed. Lettering remains
runtime text. An earlier rejected rope illustration request is recorded;
its replacement is a separate model-boat frontispiece.

## Performance measurements

The installed-world route runs twelve actual movement waypoints, the actual
apartment door, detailed furnishings, pickup, turning and Space inspection
at 1280×720, Forward+, MSAA 8×, VSync off, uncapped, RTX 4080. No readback
occurs during timed phases. Each phase's first straddling interval is
excluded; distributions use linear quantiles. Full samples and reproducible
summarization are retained in the diagnostic packet.

| Phase | Samples | Before p50 / p95 / p99 / max ms | After carrier repair p50 / p95 / p99 / max ms |
|---|---:|---|---|
| Near detailed shelf | 119 | 31.100 / 36.290 / 37.174 / 38.634 | 31.913 / 36.888 / 38.020 / 41.037 |
| Turning | 47 | 35.230 / 40.161 / 43.571 / 44.372 | 33.752 / 38.151 / 38.919 / 39.425 |
| Pickup | 98 | 41.164 / 49.535 / 55.968 / 59.745 | 35.828 / 44.807 / 48.713 / 51.487 |
| Held turning | 31 | 49.633 / 57.892 / 58.742 / 58.981 | 33.929 / 39.620 / 43.097 / 44.208 |
| Enter inspection | 99 | 26.243 / 32.594 / 41.610 / 48.925 | 22.443 / 31.401 / 41.410 / 44.999 |
| Static inspection | 119 | 25.886 / 31.509 / 33.504 / 36.383 | 21.468 / 27.741 / 29.558 / 30.776 |

Held-turn frames over 50 ms fall from 13/31 to 0/31; pickup retains one.
This is a combined behavior/render comparison: the former carrier collision
also displaced the viewing position. It does not isolate a geometry speedup.
Intermediate post-art/pre-carrier results are worse and remain preserved.
No universal frame-rate or V2 performance acceptance is claimed.

Measured viewport render CPU/GPU p95 is 19.145/12.189 ms near the shelf and
12.426/8.468 ms in static inspection after repair. Timed library phases show
no pipeline compilation counter increments and dormant passage residency.
Process/physics monitor values are coarse and lagging; they are not a full
per-frame script/physics decomposition. Loading/compilation durations and
other streaming transitions need further attribution. This world route does
not open a cover: opening-handler figures come from a separate controlled
actual-input scene. Seven texture RID leaks at world teardown remain open.

## Continuation report

REPORT — V2 book editorial and bindings — 2026-10-22.
Branch **codex/v2-acoustic-topology**; preceding pushed HEAD
**b98efbd32763a5061b99dcd3ccdd78a0b972bc63**; origin main and merge-base
**21f0b1fc27ac8e25c8466fe1ed2ce64019ee7ede**. Canonical checkout only;
no temporary worktree. Worktree remains shared and dirty: earlier hose
scripts/diagnostics and unrelated untracked files are excluded. Named paths
only; 282 verified EOL-only import rewrites restored.

Protected seventeen paths match origin main; selector remains V2 with explicit
V1 rollback. No inventory, NPC, case, mechanical or save owner is replaced.
Native nook manufacture is rerun against its changed authoring inputs; its
GLB is byte-identical (**1325d4d6e7bb76985bd2f77dceeab8e980eaf6e7b606e5e65149ffb26d4110f5**),
so its unchanged render is reused. The sixty-one nook copies retain their
older bespoke sizes/bindings and are outside this thirty-title conversion.

Original full board: 104 PASS, five FAIL, one INCOMPLETE. Two newly exposed
failures were generated decoration names and stale nook manufacture. Direct
authored/native decoration identities replace unused generated prefixes;
actual native regeneration repairs the source binding. Targeted follow-up
passes spatial, all 59 spatial tests, all four nook tests, and reader with
zero NEW unread fields. Added diagnostic fixture references remain reported;
the full baseline comparison is retained, not rewritten as green. Surface
qualification and rendered review remain expired; preceding completeness
tests retain their two failures. All 61 focused reader/surface tool tests
pass. Ledger scope counts stay **7 / 8 / 110 / 42 / 134 / 136**;
requirements_changed is empty. No qualification receipt is repinned.

Final diagnostic verdicts and exact receipts are indexed in the packet
manifest under **art/reviews/v2_library_editorial_20261022**. Wrapper receipts
are **suite_run**, not test-written **runtime_contract** evidence. Early
timeouts, parser failures, native deformation failures, buried ink, failed
old input routes, failed drop controls and stderr are retained. The repeated
early v3 wrapper paths were reused before final unique run names; no original
runtime-contract receipt was overwritten. The v4 parser run was terminated
after identifying its own process; it grants no suite verdict.

Passing scoped checks include **final_print_v1**, 2,136 checks across all
thirty spreads and three case styles, and **final_hand_v1**, 76 actual-input,
slot, migration, obstruction and release checks with empty stderr. Expanded
**hand_contact_final_v1** runs 733 checks and retains one bookend failure;
it does not qualify the whole library. The save check distinguishes exact
payload reconstruction before physics resumes from resumed contact solving:
the latter changes the loose resting pose by about two micrometres and may
wake it. It must retain the pose within native contact precision; an exact
sleep flag four solver frames later is not a durable-save requirement.
Immediate exact payload reconstruction and resumed-pose checks both pass.

Still open: first-use cover spike, remaining world frame-time tails, broad
V2/source-bound qualification, nook conversion, denser varied shelf stocking,
installed hose aiming/full deployment/spray/release/save, and systematic
remaining-area inspection. The eleven arcade door clearance/sweep repairs
remain carried forward; Mina's raised black shelf silhouette remains the
diagnosed cast shadow. Decision needed from owner: none.

BLOCKED — merge qualification and wider V2 acceptance remain incomplete;
continue authorized repairs. No human acceptance or V2 completion is claimed.
