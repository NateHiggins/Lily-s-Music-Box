# V2 storefront refit — implementation plan

Evidence class: **INERT**. A plan for building the six reference cards in
**C:/ov/reports/storefront_research_20261028** (REFERENCE_CARDS.md, dated
2026-10-28). Nothing here is built, rendered or accepted.

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
   service-hatch variant is held for your decision (§5); the live counter
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
- **OrisonV2SurfaceInventory**: no new unresolved surfaces.
- Route tests crossing the changed frontage:
  - arcade shop routes and the public doors;
  - the resident key route (News & Cigars);
  - the bodega route and **OrisonV2RouteProbe** for every registered
    resident with a "bodega" place.
- The spatial manifest regenerated as LF, and the reader gate at NEW 0.
- The 17 protected paths and the V2 selector unchanged. The blockout is
  not edited, so the ~30 hash-bound artefacts it would expire stay valid.

## 5. Decisions for the owner

- **Awning cloth.** The catalogue's only awning stock is **awning_vinyl**,
  which is wrong for 1928. Either add a **canvas_awning** key (plain and
  striped variants, with custom PBR maps) or reuse **linen**. The card asks
  for canvas.
- **Palette.** The cards suggest dark green or warm ochre for the grocery.
  No colour is historically matched, so the palette is yours.
- **News hatch.** Build the fixed-pose hatch variant, or skip it. Either
  way the live counter sale stays.
- **Order.** The slices above go from lowest risk to the hash-bound bodega.
  Reorder them if a particular frontage matters more.

No route clearance, performance change or appearance acceptance is claimed
by this plan.
