# THE VANTRY ARCADE — ARCHITECTURAL RECONSTRUCTION BRIEF

*Owner commission 2026-08-16: rebuild the arcade as a grand 1920s commercial
building. Conceptual ancestor: the Windsor Arcade (Fifth Avenue & 46th,
1901–1920), imagined surviving to architectural maturity in 1926 — late
Beaux-Arts monumental commerce with geometric Deco beginning to infiltrate.
This brief is the construction authority for the phased build; the fiction
stays "the Vantry Arcade," the code stays `passage`.*

## 1. Audit — what exists (2026-08-16)

- **Substrate (M0.5, ruled, ab120dc):** 20 × 26 m hall at x 4..24,
  y −38.6..−64.6; 6 m terrazzo aisle (x 11..17); two 7 m shop bands; eleven
  researched trades (W: laundry, cobbler, locksmith, hardware, funeral;
  E north→south: diner, druggist, news, pawn, radio, photo) with preserved
  bay widths; 10.284 m throat to the street portal; K0/K1 gateway host and
  exit kiosk; PS4 handcarts; PS6 night grilles; PS7 fitted shop interiors
  (263 bounded draws); PS8 route ownership. All of it works and is kept.
- **The architectural poverty being corrected:** the nave is a shed. The
  glass vault springs at SHOP_H 3.55 and peaks at ≈5.55 m; hall walls stop
  at 4.20; the portal frontispiece is one storey of flat host; the south
  end is a blank brick wall; shop backs terminate at their authored depth
  with nothing behind; there is no upper architecture anywhere.
- **Working systems that must not break:** shop thresholds, counters and
  `passage_shop_hours` markers (the golden loop buys the capsule at
  HARDWARE PAINT); PS6's three MultiMesh states; the aisle light ids in
  `fixture_light_map`; WalkTest/GoldenLoop probed routes down the aisle;
  the K0/K1 proven envelopes; the 9 m shop-batch contract.

## 2. Hard constraints

1. **Coordinates belong to `gen_layout.py`.** No hand-edited JSON/GLB.
2. **Playable boundary contract (Check 3):** play space is portal → throat
   → hall only. All new depth beyond the enclosing fabric is view-only
   scenery mass, like the street backdrop. Enterable back-of-house is an
   owner decision for a later phase, not a default.
3. **The interaction skeleton is frozen:** aisle edges x 11/17, shop bay
   packing, thresholds, counter anchors, grille markers, aisle light ids
   and positions, kiosk and host envelopes, SITE_S −66.0.
4. **Perf law:** the Passage northbound station stands at ≈17.8 ms
   (canonical pinned night) against 16.6 — already the accepted blocker.
   Boxes and pipes bake into per-batch-per-material buffers, so geometry is
   nearly free and **new material×batch pairs are the draw budget**. Every
   phase re-runs the owning station and reports the delta honestly.
5. Classical body dominant; Deco infiltrates as flattened/stepped detail.
   No generic Deco, no horror dressing, no sepia theme park.

## 3. The parti

A basilican commercial nave, 1926:

```
section through the aisle (x 11..17)
  0.00 – 3.55   storefront order: bronze-framed glazing, transoms,
                fascias (existing, enriched later per-tenant)
  3.55 – 4.05   continuous limestone entablature over the shops
  4.05 – 7.20   clerestory band: plaster pilasters on each party line,
                stepped-head clerestory lights between, frieze
  7.20 – 9.90   ribbed glass barrel vault (faceted, iron ribs, gutter
                beams, ridge) — apex ≈ 9.9 m over the aisle
  crossing      glazed stepped lantern to ≈ 11.5 m at mid-hall, and the
                four-faced pendant clock at 5.6 m — the postcard event
plan sequence   street → arched frontispiece → vestibule throat
                (coffers, mosaic threshold) → RELEASE into the nave →
                shop bays → crossing event → south terminating
                frontispiece: gable, lunette, building directory
```

Compression and release use the existing throat (4.2 m ceiling, now
coffered) against the raised nave. The side shop bands keep their 3.55/4.20
roofline — low aisles against a tall nave is the period section and it
keeps every existing shop, grille and counter exactly where it is.

## 4. Phases

- **V1 — RAISE THE NAVE (this build).** Everything in §3 that is hall
  fabric: entablature, clerestory order and lights, raised vault + ribs +
  gutter + ridge, crossing lantern, pendant clock, pendant stems for the
  eight existing aisle bulbs (positions unchanged), north/south nave
  gables, south frontispiece with directory and lunette, terrazzo aisle
  borders + crossing medallion, throat coffers + threshold band, and the
  street frontispiece upgrade around the portal (engaged piers, archivolt,
  keystone, spandrels, cartouche) in the existing gateway proxy batch.
  Existing materials only.
- **V2 — SHOPS BECOME REAL ROOMS.** Per-trade rear zones behind each sales
  floor as view-only depth: opened back walls, doorways, rear work/stock
  rooms in half-light, the service corridor implied beyond. The layered
  sightline (glass → goods → counter → shelving → rear door → darkness) is
  the acceptance test. Mezzanines for two prestige tenants.
- **V3 — STOREFRONT FAMILIES & TENANT DIFFERENTIATION.** Bronze storefront
  framing families, etched glass, brass plaques, blade/fascia refinement,
  per-tenant alteration eras; ties into the sign-service lane.
- **V4 — LIGHT.** The lighting hierarchy: clerestory day, lit shop worlds,
  showcase brightness, dim service edges; night-jewel state; the lit
  lunette nobody can reach (the first sanctioned abnormality).
- **V5 — EVIDENCE OF USE + HISTORICAL LAYERING.** Wear paths, worn
  thresholds and brass, parcel shelves, directories, ghost signs, one
  1950s fluorescent retrofit in a cheap tenant.
- **V6 — ABNORMALITIES, PERF RECONCILIATION, POLISH.** The restrained
  impossible: reflections, repetition, the directory listing a shop that
  is not there. Then the honest perf pass against P1.

## 5. V1 acceptance

- `python gen_layout.py` exits clean (its own overlap/audit gates).
- Full regen chain; Passage battery green: PassageHoursTest,
  PassageNavTest, PassageVisibilityTest, PassageOwnershipAudit,
  PassageFinishTest; WalkTest FULL; LightingAudit.
- Perf: the northbound station re-measured at canonical pinned night and
  reported against 17.8 ms.
- Renders: nave interior (day + night), crossing event, south terminus,
  street frontispiece — from player eye height.
