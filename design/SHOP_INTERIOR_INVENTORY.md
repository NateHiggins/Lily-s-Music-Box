# Shop interior second-pass inventory

Recorded before Phase 1, after the lighting-AABB repair.  “Existing” names
the generated fitting groups rather than pretending the first pass is empty;
“decision” is the authorized retain/replace/reposition/add action.

| Trade | Existing groups | Decision against `SHOP_INTERIOR_BUILD_GUIDE.md` |
|---|---|---|
| Model Laundry | five washer blocks, two automatic dryers, folding table, counter, shirt rail, bench | **Replace** every washer/dryer: this is a hand laundry, not the apartment basement. **Retain/rework** counter and shirt rail. **Add** parcel wall and ticket rail hero, flap, ironing table, sad irons and gas ring, sleeve board, mangle, tubs, pulley racks, stove and ledger. |
| Shoe Rebuilding | long bench, two-block finisher, shoe racks, eleven shoe blocks, counter | **Retain/rebuild** the plan. **Replace** the generic finisher with the measured common-shaft machine and dust hood. **Add** outsole stitcher, Singer patcher, lasts, sole/heel stock, waiting seat, ledger and leather-dust clean shadow. |
| Keys Cut | 7 x 14 key board, cutter bench and cutter, safe, counter | **Retain** board, safe and counter. **Rebuild** cutter as two vices/cutter/guide. **Add** grinder, bench vice, mortise-lock cloth, pick roll, padlock rail, stepladder and ledger. Keep the room concentrated. |
| Radio Service | service bench, open chassis, scope, valve shelves, counter | **Retain/rebuild** the hero bench under the Rule of Signal. **Add** signal generator, exposed valves, wet-cell charging rack, horn and cone speakers, wire/insulators, soldering gas ring, coils/condensers, ledger and a static 1610 receiver carcass with one later audio marker. |
| Luncheonette | counter and eight stools, back bar, two urn blocks, pie case, shelves, griddle | **Retain** the room-defining counter and stools. **Rebuild** urn silhouette with lids, taps and gauge glasses. **Add** soda fountain, syrup pumps, mixer, register, cigar case, menu board, fan, smallwares, ledger and window display. |
| News & Cigars | wall counter, paper rack, papers, cigar case, shelves | **Keep as a booth**, not an enterable room. **Reorient** service to the pavement hatch and lock the proprietor door. **Add** candy jars, pipes, plugs, punchboard, cash drawer, stool, racing form, ledger and the worn chair hollow. |
| Pawnbroker | two display cases, nine static clocks, grilled counter, arcade cabinet | **Retain** cases and grille. **Keep clocks static** and reuse the reviewed family’s proportions/material language. **Add** unredeemed parcel-wall hero, brass wicket, balance, loupe, safe, pledge ledger and specific non-precious pledges. |
| Funeral Parlour | sixteen chairs, lectern/book, pleated drapes, wreath stand | **Retain** the arrangement and judge it in situ. **Add** empty bier/trestles as deliberate negative space, palms, second wreath stand and ledger details. No preparation room. |
| Hardware & Paint | wall bins/stock, paint bench/cans, ladder, counter | **Retain** accreted stock and the only ladder on the block. **Add** drawer-wall hero, scale, hand shaker, paddle, colour-card blanks, glass rack, cutter, silhouette tool board with one absence, ledger and window display. |
| Photo Supplies | glazed counter, film boxes, enlargers, darkroom door/lamp, arcade cabinet | **Retain** darkroom hero and high enlargers. **Add** three period camera silhouettes, plates/film by size, tanks, trays, print dryer, tripod rack, flash-powder tins, portrait display, unclaimed-portrait rack and ledger. |
| Otis & Son | long counter, 54 drawer fronts, soda fountain/stools, dispensary, four block carboys | **Retain** the ordered plan. **Rebuild** show-globe hero with pedestals, stoppers and backlight. **Add** shop rounds, mortar/pestle, glazed balance, locked poison cupboard with tactile bottles, cartons, telephone, ledger and restrained window display. |

## Shared additions

Every shop receives one ledger, a closed back-of-house implication, and a
window-display argument.  Those are static batched fittings.  Readable text is
reserved for a very small marker-driven set; ordinary tickets, cartons and
labels remain illegible modelled paper or enamel plates.  The funeral parlour
and laundry are exempt from isolated hero judgment because their heroes depend
on room/counter context.

## Phase 0 measured baseline

- Installed interior boxes: **540**, explicitly owned by **11** shop batches.
- Pre-fix floor meshes: **3,276**. Rebucketed: **3,381** (+105 local meshes).
- Street elevation, before: **27,497 objects / 32,533 calls / 52.63 ms**.
- Street elevation, rebucketed: **27,281 / 32,234 / 52.11 ms**.
- Rebucketed lighting was measured before adjustment. The brightest inspected
  shop remained only luma p95 **103**, so no energy reduction was justified.
  The repair recovered visibility without stacking a second compensation.

## Phase 1 completion audit — 2026-08-09

- **999** installed static fitting boxes, owned by exactly **11** explicit
  shop batches.  They import as **181** `(shop, material)` meshes; every AABB
  remains local to one shop and below 8 × 8 m.
- All ten positive hero silhouettes exist as reusable tagged descriptors.
  The funeral parlour's hero remains the in-situ empty bier and seating void.
- All eleven ledgers exist.  The hand laundry contains no automatic washer or
  dryer; NEWS & CIGARS is a locked booth with a reachable pavement hatch.
- The five-foot capsule passes each of the ten public thresholds in both
  directions.  The news proprietor side is proven inaccessible.
- The clearance run exposed and removed four older faults outside the fitting
  list: shop voids cut with the wrong sign, five obsolete fake storefronts,
  the Harukiya ceiling slab crossing the luncheonette, and the exterior stage
  boundary crossing Otis & Son.
- Installed renders are in `C:/shots/orison_shop_pass/after`; isolated hero
  renders are in `C:/shots/orison_shop_pass/heroes`. Entered-shop mean luma is
  **17.1–39.0**, p95 **66.7–142.3**, with no clipped highlights.  This confirms
  the existing lamp energies after rebucketing; lowering them would undo the
  recovered visibility rather than remove overexposure.
- FAST and FULL WalkTest: **PASS** (the first FULL run exposed one intermittent
  2A bedroom route miss; the clean rerun completed in 62 seconds). Shop routes:
  **PASS**. LightingAudit: **PASS**, 127 spaces / 11 intentionally ambient or
  dark.
- Final performance versus the post-rebucket Phase 0 baseline is essentially
  flat overall: mean station time **46.25 ms vs 46.16 ms**. Street elevation is
  **52.43 ms vs 52.11 ms**; corridor F04 improves to **61.52 ms from 62.50**.
  The project-wide 16.6 ms target was already missed at every station and
  remains a separate scene-wide budget problem rather than a shop draw-call
  regression.

Phase 2 remains deliberately unbuilt pending separate approval: movable or
audible owners for the 1610 receiver, poison cupboard and register are not
smuggled into this static pass.
