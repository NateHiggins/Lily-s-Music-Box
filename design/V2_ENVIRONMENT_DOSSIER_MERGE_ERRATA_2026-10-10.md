# V2 environment dossier: merge report errata (2026-10-10)

Evidence class: **INERT**

This note corrects `design/V2_ENVIRONMENT_DOSSIER_MERGE_REPORT_2026-10-10.md`
and the packet `art/reviews/v2_environment_design_20261008` after the merge
(main d38e7795). The report and its sidecar
`design/reports/V2-ENV-DOSSIER-2026-10-10.json` were verified as written and are
left unchanged; read this note beside them. It promotes nothing, changes no
row's status (the register stays 375 verified, 87 implemented, 107 deferred,
15 rejected), and writes row, space and anchor ids in bold. The receipts it
names are wrapper receipts (suite_run), not runtime proof (RUL-003). An
adversarial check of a first draft (four agents, each trying to refute its
claims against the repository) corrected several statements below.

## 1. Deferral premises the repository contradicts

Three of the report's section 6 blockers rest on facts that are false in the
repository. The affected rows stay deferred; their reasons in
`content/status.py` now state what blocks them.

**Service spine width.** The 1.2 m premise was in `content/status.py`, not in
section 6, which names only "Service spine is a shell (**BW-006**)". **BW-006**'s
note and seventeen templated rows said the service halls are 1.2 m wide and the
whole width is the route. That holds for **F01_SERVICE_HALL**,
**F02_SERVICE_HALL**, the **F02_SERVICE_HALL_SOUTH** to
**F06_SERVICE_HALL_SOUTH** halls and the crossings. It is false for:

- **F03_SERVICE_HALL** to **F06_SERVICE_HALL**, which are 2.4 m wide (x 7.1 to
  9.5 in `game/data/orison_v2_blockout.json`); F03's purpose names bypass and
  inspection clearance around continuous risers. The risers
  (**HEAT_STACK**, **TELEPHONE_MESSAGE_RISER**, **ELECTRICAL_SERVICE_RISER**)
  stand in the east half at x 8.45 to 9.3, z 0.3 to 1.15. Beside the cluster
  the free floor is about 1.35 m, which is the bypass itself; the spare width
  outside a 1.2 m route lies along the rest of the east half.
- **F01_CORE_TO_SERVICE**, which is 2.0 m across with no riser in it.

**F03_SERVICE_HALL-001** to **F06_SERVICE_HALL-001** no longer wait on
**BW-006**'s chase; they wait on a node probe of the hall and a family for the
forms. **F01_CORE_TO_SERVICE-001** and **BW-006**'s own note are corrected to
match. The other hall, south-hall and crossing rows wait on **BW-006**, as their
notes say. No riser-choke ruling is pending: the southern F02/F04 riser choke
is spatial debt accepted at M11B
(`design/ORISON_V2_M11B_HUMAN_ACCEPTANCE_RECEIPT_2026-08-31.md`).

**The bodega family.** Section 6 said "The bodega has no V2 fittings family"
(5 rows). It has one. `game/scripts/building/orison_v2_bodega_fittings.gd`,
mounted by the V2 runtime root since 3fb4df4b (2026-10-05, an ancestor of the
dossier's merge-base 2ea28ee0), swaps the meshes of the 58
**TEMPLATE_BODEGA_CELL_V1** nodes in its REPLACE_IDS from
`game/assets/props/bodega_fittings.glb`, after checking the digest of the whole
`exterior_geometry.json` (so any street-template edit also refuses it). What
blocks **CITY_BODEGA-001** to **CITY_BODEGA-004** is that the family only
re-meshes template nodes. The cards, the back notions counter, the ledger, the
derby and the film tins have no template node. They need new forms in the
build script and a runtime path that places them and gives them collision.
Slices 53 and 54 extended families that already mount records through
`orison_v2_shop_seating.gd`, so this is more work than those were.
**CITY_BODEGA-005**'s stand-in stock is the family's own output (the packet's
bodega_stock capture shows its rimmed tins). That row is a rework of the
family, plus a register on counter_till, which the family does not replace.

**The light budget.** Section 6 ("Light budget 16/16 and practical lights"),
the "16/16 light budget" in section 1's decision list and section 8's decision
7 rest on a budget the V2 runtime does not have on desktop. The V2 runtime
root composes LightRig, whose per-frame light budget has been off on desktop
since 2026-08-08 (`game/scripts/building/light_rig.gd`). Only shadow casters
stay capped, at 32. Mobile keeps its caps (ACTIVE_N_MOBILE 12, SHADOW_N_MOBILE
4). The 128 in `game/project.godot` is the Compatibility renderer's per-object
limit; desktop renders Forward+. V1's BuildingRoot still sets budgets of its
own. **BW-017**'s twelve hall domes already rely on the V2 behaviour. Decision 7
is withdrawn as framed. **B1_BOILER_ROOM-003** (cage bulbs over the firing
aisle) and **CITY_SHOP_OTIS_SON-001** are work to do, not rulings to wait for.
The carboy row is more than a lamp: `orison_v2_druggist_carboys.gd` turns
shadow casting off on the carboy glass, so the colour on the terrazzo must come
from a tinted light. **F04_LANDING-003** never cited the budget.

Section 6, restated for the three blockers:

| Report's blocker | Rows | Corrected |
|---|---|---|
| Service spine is a shell (**BW-006**) | 23 | 19 wait on **BW-006**. **F03_SERVICE_HALL-001** to **F06_SERVICE_HALL-001** wait on a node probe and a family |
| The bodega has no V2 fittings family | 5 | The family exists. Four rows need owned assemblies (build and runtime); one is a rework of the family |
| Light budget 16/16 and practical lights | 3 | No desktop budget. Three practicals to build: B1 cage bulbs, an F04 landing sconce, a tinted carboy backlight |

## 2. Evidence the packet lacked or misfiled

- **Folders added (open findings 1, 6, 8, 10, 16).** Copied from
  `C:/ov/envimpl_out`, where each was the only copy, LF-normalized and hashed
  as LF in its manifest. The four lane baselines of finding 6 are `base80`,
  `base48_routes`, `bedding_base43` and `f01base`. Finding 10's census is
  `census80`; its capture scene went into the packet's `sources/` in
  follow-ups 2. `slice9b` is finding 8: slice 9's first runs at ae5f26f6, six
  of seven refused at startup. `slice82` is slice 82's own runs at 5467439f, so
  report line 21 and finding 1 ("Slice 82 has no packet evidence") are out of
  date. Its fabrication batch records five failures (2B_dress_form,
  5B_aerial_wire, B1_cleat_run, B1_washer_supply, B1_rinse_taps); finding 13
  named two. The packet now holds 816 receipts in 109 tags (the report counted
  784 in 101); 30 of the 217 outside receipts are inside.
- **Slice 4's evidence (new finding).** Slice 4 (dae10668) filed its evidence
  under `implementation/slice34`. Slice 34 (0ef631a2) later wrote to the same
  folder and replaced its manifest and five receipt files (the fabrication
  and import receipts, the batch, and the sweep's census and shot list), so
  slice 4's rows cited files that were no longer what they named. Slice 4's
  evidence is restored byte for byte from dae10668 under
  `implementation/slice4` (16 manifest entries, every hash matching), and
  slice 4's citations point there. Slice 34's manifest no longer lists the
  2026-10-09 sweep and upper_lighting receipts, which were slice 4's runs.
  **BW-017** (a slice 3 row) cites the 4e589c0c upper-lighting run, which is
  that slice 4 receipt; its note now says so.
- **Mis-cited fixes.** **F01_D_KITCHEN-001**, **F02_C_KITCHEN-001** and
  **F04_C_KITCHEN-001** cited `slice9b` for the cabinet fix. `slice9b` shows the
  refused runs before it. They now cite `slice9e`, where 1D's completion route
  and the fabrication batch pass.
- **Evidence tags (open finding 8).** The status.py headers for slices 14, 27,
  28, 30 and 31 now cite the folders that exist (`slice14b` and `slice14c`,
  `slice27b`, `slice28b`, `slice30b`, `slice31b`). The README's `slice26b` now
  points to `slice26/receipts/rerun_b__*`. Two commit messages cannot be
  changed. 4433a936 cites `routes6/`; read `routes6b`. 355fb4ba cites
  `implementation/slice27/`; read `slice27b`.
- **The squash claim (open finding 7).** The README no longer says every
  squash is byte-identical to its WIP. It names the exceptions: slices 3 to 5;
  129e02d3 against d416d4ee; and the grouped slices (53, 55-56, 58-66, 68-74,
  76-79), which were verified once at the group's last WIP.
- **The storm frames (section 6, FX and weather).** Slice 81's clear sweep ran
  second, so its frames of facade_front_wide and route_orison_to_shop_bodega_1
  were written over the storm frames. The packet kept only the clear frame of
  each pair. The storm frames are restored byte for byte as
  `implementation/slice81/images/*_storm.jpg`. From the lane PNGs, which stay
  outside the packet, the mean absolute difference is 0.15 in 255 over the
  three channels on facade_front_wide (the 0.12 the note cited is its red and
  green) and 0.50 on the bodega route frame. The packet's JPEG pairs give 0.35
  and 0.86, which is compression noise. No receipt records the weather setting.
  **CITY_STREET-007**'s note now says all of this. The finding stands: V2
  composes no weather owner.
- **The 4C failure (open finding 12).** Nine status.py rows called 4C's
  completion-route failure a kitchen leg. The run stops at (2.02, 5.35), short
  of (1.05, 5.1). That is the leg into the bathroom toward the basin, blocked
  by the open leaf of **F04_C_PRIVATE_HALL_BATH_DOOR**. 2C fails the same way,
  including at the merge-base (`baseline_completion_2C`). No merge-base 4C run
  exists, so "pre-existing" for 4C is inferred from 2C. 1A's and 3D's failures
  are kitchen legs (the fridge in the kitchen-hall opening). Follow-ups 2
  (a8aa8a9b) already fixed **F04_C_MAIN-005**, the 2C rows and finding 12's
  other items.

## 3. Line endings and pins

The report's section 1 lists 15 paths marked -text in `.gitattributes` whose
blobs the branch turned from LF into CRLF: nine `art/blender/scripts/*.py`,
`art/data/prep_cabinets/source_plan.json`, four
`game/scripts/building/orison_v2_*.gd` and
`game/tests/orison_v2_completion_interiors_test.gd`. Follow-ups 4 puts all 15
back to LF, as they were at the merge-base. The diff against its parent is
empty under `git diff --ignore-cr-at-eol`.

- **No stored pin binds their raw bytes.** Eleven of the 15 are pinned by
  their LF-normalized hash, in the construction JSON beside each Blender family
  and in the matching `game/tests/fixtures/orison_*.json`. The other four
  (`orison_v2_domestic_doors.gd`, `orison_v2_surface_props.gd`,
  `orison_v2_surface_stock.gd` and the completion test) have no pin.
- **The freshness checks do hash raw bytes.** These are `test_sha256` and
  `runtime_inputs_sha256` in `tools/run_receipt.py` verify, and the ledger's
  `runtime_inputs_sha256`. The line-ending change therefore stales any receipt
  recorded against the CRLF tree, as any edit would.

Many other -text paths already held CRLF blobs at the merge-base: Blender
model scripts, several `art/data/orison_v2/*_source.json` files and review
sources. This note leaves them alone.

The fabrication planner (`tools/plan_v2_fabrication.py`) lists 51 of 103
families as REVIEW_DRIFT at the follow-ups tip. Most drift because shared
inputs moved (the blockout, `domestic_furniture.json`). Two drifts are scripts
this work changed after their family was built:
- surface_stock pins `inspect_surface_stock_context.py` at its d38e7795 hash,
  and follow-ups 1 changed it;
- reading_nook pins `orison_v2_domestic_furniture.gd` at its slice 66 hash,
  and slices 77 to 79 and 82 changed it.

Both refresh at those families' next rebuild. The planner is a review queue,
not a gate.

## 4. What stays open

- Slice commits 58 (e145c48d) to 66 (8f35dc22) do not compose the V2 world on
  their own: the id **6A_light_box** is duplicated until slice 67 (bbe0f527). Do
  not bisect into that range expecting a running world (open finding 15). The
  packet README now says so too.
- **Fixed on the follow-up branch:** findings 9 and 14 (a8aa8a9b, dd3fa9c1)
  and 12 (a8aa8a9b and this note).
- **Recorded here without a fix:** findings 6, 7, 8, 10 and 15, and parts of
  1, 3 and 16 (slice 82's runs, `bedding_base43` and 30 receipts are now in
  the packet).
- **Still open:** finding 1's BLOCKED d416d4ee, the seven unexplained failing
  receipts of finding 3, finding 4's ApartmentBatch script errors and
  finding 5's never-run suites. The follow-up branch
  `claude/v2-dossier-followups` repairs the suites and queues the runs for 4
  and 5; they wait on the Godot lane. Also open: finding 11's untested
  first-shift mapping, finding 13's five slice 82 refusals, and the 187 lane
  receipts still outside the packet.
