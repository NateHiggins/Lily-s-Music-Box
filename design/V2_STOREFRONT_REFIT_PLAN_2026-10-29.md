# V2 storefront refit — implementation plan

Evidence class: **INERT**. A plan for building the six reference cards in
**C:/ov/reports/storefront_research_20261028** (REFERENCE_CARDS.md, dated
2026-10-28). Nothing here is built, rendered or accepted.

## October30 intake and coordination

The reference cards and **sources.md** have been read with the entrance audit
and current installed sources. Of19 research source records,15 remain identical
after LF normalization; the four changes are instructions/Bible/city reporting,
not the packet's storefront geometry/owner sources. Historical dates, inaccessible
images and estimated dimensions retain their original uncertainty labels.
The current entrance portal is newer than the facade packet's baseline; see
**V2_FRONT_ENTRANCE_REMODEL_2026-10-27.md** for that reconciliation.

Proposed compact batch: first survey the six existing frontages and their exact
retirement boundaries; prove the shared profiles on Otis & Son; then reuse them
for Luncheonette, Hardware & Paint and News & Cigars. Extend the existing bodega
builder for its street awning and finish with Harukiya's restrained surround.
Keep the bodega and bar on the street and all four arcade shops inside Vantry.
No new shop mechanics, rooms or playable interiors. Reuse existing doors, counter
displays, globes, stools, papers, glass and catalogue finishes rather than
rebuilding functioning apparatus. The entrance/window repair and ongoing
background-city work must agree on shared ground and support envelopes first.

Prior recommendations, answered in section 5 on November 1: reuse a suitable registered cloth initially,
propose dark green for the grocery, and omit the optional news hatch unless it
can demonstrably preserve the live counter approach. No new catalogue stock or broad rebuild commission follows from them.

## 1. Scope

The cards cover six existing frontages. None moves, and none gains gameplay:

| Card | Frontage | Current owner on main |
|---|---|---|
| 1 Grocery | street bodega | **art/blender/scripts/build_bodega_frontage.py** and its hash-bound fixture **game/tests/fixtures/orison_bodega_frontage.json** |
| 2 Hardware | Vantry Arcade, HARDWARE PAINT | passage cell glTF front, photographic glazing (**orison_v2_photo_glazing.gd**), sign marker **SITE_SHOP_SIGN_HARDWARE_PAINT** |
| 3 News | Vantry Arcade, NEWS CIGARS | same cell pattern; the live counter sale stays (**_mount_news_stand**) |
| 4 Pharmacy | Vantry Arcade, Otis & Son | same cell pattern; existing show globes and druggist owners stay |
| 5 Lunch counter | Vantry Arcade, Luncheonette | same cell pattern; diner counter, urns and stools stay |
| 6 Bar | Harukiya street door | bar module; door, stair, room and fiction stay |

Kept unchanged on every frontage:
- every leaf (0.95 × 2.10 m, Harukiya 0.90 × 2.10 m), its swing and hand;
- the walking routes and thresholds;
- stock, hours, keys, saves and radio settlement.

Inside the arcade there are no weather awnings or pavement displays.

## 2. Shape of the work

Follow the arcade's existing pattern (**shop_joinery**, **news_fittings**,
**hardware_drawers**). The new family is **shop_frontage**, made of:

- **art/data/shop_frontage/source_plan.json**: for each shop, the exact
  original front records it retires (fascia, head, bulkhead, transom and
  glazing bars) and the card's chosen dimensions.
- **art/blender/scripts/build_shop_frontage.py**: one shared kit, varied
  per shop. The kit is:
  - one family of jamb, rail and sill profiles;
  - one door casing;
  - one sign bracket with a wall plate and brace;
  - one fixed-pose awning;
  - a small set of trade-display silhouettes.
- **art/blender/scripts/inspect_shop_frontage.py**: closed volumes, metre UV
  derivatives, bearings against the retained shell, exact source
  retirement, and intersections with every accepted neighbouring family.
- **game/scripts/building/orison_v2_shop_frontage.gd**: a `mount_cell`
  owner added to the passage region's list. The bodega keeps its own
  builder and is extended, not replaced.
- **OrisonV2ShopFrontageTest**: retirement, materials, contacts, leaf
  clearance at every swing pose, and windowed standing views.

All lettering stays Label3D on the existing sign markers (RUL-008); no
generated map carries letters. Reference photographs stay in the external
report (RUL-007). Every new surface meets the UV, custom PBR and
loaded-mipmap rules of **design/V2_SURFACE_REQUIREMENTS_2026-10-11.md**
(RUL-012).

## 3. Slices, in order

Each slice is one shop: a Blender review, then a batched Godot capture,
per **art/blender/v2_batch_workflow.md**.

1. **Source inventory (no geometry).** For each cell, list the front
   records and measure the spans the cards marked S. Then choose a value
   inside each E range that fits the actual joinery, and write
   **source_plan.json**. This settles the card's caveat that a sign bay is
   not a surveyed aperture.
2. **Otis & Son.** Paired lights, ordered glazing bars and a dark lower
   field. The existing globes, counter and soda apparatus keep their
   materials and mechanisms. Lowest risk, so it proves the kit.
3. **Luncheonette.** One large clear light with a low sill, so the
   existing stools, urns and pie case read from the arcade. A tiled lower
   panel.
4. **Hardware & Paint.** An asymmetric display light with the door offset,
   a blade sign on two iron straps, and one tall tool silhouette group.
   The existing ladder, hose, drawers and tools keep their owners.
5. **News & Cigars.** A shallow fascia and sloping paper tiers. The
   optional service-hatch variant is omitted by the November 1 ruling (§5); the live counter
   sale is not enclosed.
6. **Street bodega.** Timber fascia, lower panels and a fixed canvas
   awning (0.8–1.2 m projection) on real brackets.
   - It extends **build_bodega_frontage.py**. The bodega fixture must be
     rebuilt, as with every door_prop change.
   - The awning must clear the inward leaf's 168° travel and the
     residents' "bodega" leg.
7. **Harukiya.** Minimal: a worn surround and threshold and one small
   plate. No new stair, step, areaway or secret door.

## 4. Verification each slice owes

- Native Blender renders and the inspect script.
- One windowed Godot capture batch for the slice.
- A small imported family bench checks changed surfaces, loaded maps and
  contacts; reuse unchanged family evidence. Renew the complete surface packet
  once at a coherent integration checkpoint, not after every slice.
- Short actual-controller/input segments crossing the changed frontage:
  - arcade shop routes and the public doors;
  - the resident key route (News & Cigars);
  - the bodega route and **OrisonV2RouteProbe** for every registered
    resident with a "bodega" place whose approach is affected.
- The spatial manifest regenerated as LF, and the reader gate at NEW 0.
- The 17 protected paths and the V2 selector unchanged. The blockout is
  not edited, so the ~30 hash-bound artefacts it would expire stay valid.

## 5. Owner rulings — November 1

Lily answered **owner-questions-20261101-e66188a0-v1**, Q06–Q08:

- **Awning cloth:** reuse registered **linen** for the first rendered candidate. Do not use modern **awning_vinyl** or silently add a new canvas catalogue finish. A later material change needs the candidate review to justify it.
- **Grocery palette:** dark green. This is an artistic choice, not a claim of historically matched color.
- **News hatch:** omit the optional fixed-pose storefront service-hatch variant and preserve the clear counter approach. Retain the installed News counter/frame, hours and purchasing owners; this does not authorize deleting existing shop apparatus.

The earlier October 30 recommendations are provenance; these three choices are now answered. Shared entrance/ground envelopes, measured clearance, surface qualification and appearance review remain. Existing slice order is unchanged. These rulings do not commission unrelated rebuilding or establish runtime/artistic acceptance.
