# Fitted front pavement — October 2, 2026

Evidence class: **INERT**

REPORT - V2 front public-floor ownership - 2026-10-02

Branch / HEAD / origin/main / merge-base: canonical **main**, published base
**97faa90eacfad8f2ea51d0145f2b699ba7f9d854**. The fitted paving is installed;
clean committed candidate comparison and publication are recorded after they run.
Worktree clean at this report: no, the named paving batch is in progress.
Protected 17/17 and V2 default/explicit V1 rollback require the candidate checks.
No runtime requirement or whole-shell readiness is claimed by this report.

## Original defect and final ownership

The registered source **pavement_slab** spans Orison-local X minus 25.5 to
20.3, Z minus 16.605 to minus 11.65, with 160 mm thickness below the existing
zero top datum. Its original rectangular volume extends 700 mm beneath five
retained first-storey room floors: **F01_D_BED**, **F01_D_BATH**, **F01_A_BATH**,
**F01_A_BED** and **F01_A_STUDY**. The active source floor volumes reproduce
that original overlap; this is a geometric before comparison, not a claim that
the removed original slab remains active in the installed world.

**build_front_pavement.py** derives the public envelope from the original street
record and named front door, and subtracts the current occupied floors, retained
editable masonry components, registered bodega floor, construction-shed floor
and curb volumes. The generator uses each owner's actual solid component or
source box rather than a whole-building bounding box. Thirty-two retained masks
govern the construction. Neither the floor datum nor any room, opening or
moving door is relocated.

**front_pavement.blend**, **front_pavement.glb** and
**front_pavement_construction.json** retain editable closed source construction,
37 export parts bounded to four metres, 1,656 triangles and 29.0439308275 cubic
metres of public slab. Zero-area edge contacts are split into their owning cell
fans without moving coordinates or deleting faces. The saved union has zero
nonmanifold edges and positive signed volume. Its original fifteen room stations
remain clear in the actual native source inspection.

**orison_v2_front_pavement.gd** mounts the asset in the named Orison front-door
frame and gives each draw matching mesh collision. The composed street removes
the old slab's draw and collider through **world_connection.json**; the original
template remains available to its retained source/review owners. Bodega, shed,
curb, alley and room floors retain their own volumes and collision.

## Mapping and direct inspection

Active metre UVs use small part-local coordinates, stable V translation and
the established glTF tangent handedness correction. Runtime paving uses the
existing mapped **concrete** key, its retained 2.8 metre physical tile scale
and local UV mapping. Native-precision import is explicit. No catalogue key,
generated lettering, texture file or global light setting is added.

The installed inspection at
**tmp/shell-readiness/front-pavement-production-inspection1.log.receipt.json**
passes 911 checks: all native parts and strict mapping derivatives, 592 actual
first-hit public-surface contacts, the five original overlap pairs and fifteen
frozen room-floor stations. Thirteen room rays first meet the retained floor;
two first meet their existing shower trays at plus 19 mm. Each tray is named,
recorded and excluded individually before confirming its underlying floor.
No original station is moved or omitted to obtain a pass.

All five installed player-height frames and the saved production-native overview
are directly reviewed. The façade, vestibule and alley joints show the fitted
surface. Existing ornamental joints, local shadow silhouettes and storefront
finish remain separate appearance work. The overview establishes native slab
form; successful ordinary-controller routes establish traversal separately.

Standard lane imports at **front-pavement-production-import4** and **import5**
complete with empty stderr and preserve the authored project settings. Earlier
explicit editor imports rewrote formatting and dropped the redundant default
Forward+ setting; the authored bytes were restored after checking every setting.
An intervening read-only experiment produced a safe-save diagnostic and is
retained as a qualified attempt, not used as a clean import receipt.

## Validation and remaining work

The production service-alley route at
**tmp/shell-readiness/front-pavement-production-alley-route1.log.receipt.json**
passes 25 ordinary-input waypoints through the rear door, street and front entry,
then returns and closes the rear leaf. Additional affected street, bodega,
transit, bar, arcade and resident-key routes, matched visible/hidden viewport
observations and the complete gate comparison are recorded when complete.

Changes outside the model: one runtime mount, composed removal of the old slab,
strict installed inspection and hash-bound fixture, regenerated fabrication
inventory, five individually reviewed room-identity references and report/map
updates. The prior remaining-transfer publication text is corrected to describe
its wrapper suites accurately; only the resident-key test independently writes
its own schema-2 runtime contract. Wrapper receipts grant no ledger promotion.

Open findings: broader street/courtyard subgrade, drainage grades and outlets,
boiler airwell/paving weather closure, retained city-plinth joins, finished paving
joints and wider independent service networks. The flat courtyard prototype is
still uninstalled and requires fresh ownership discovery after this publication.
Heating cuts remain parked. Raw architecture, infrastructure, mapping preparation
and final material/render polish remain separate states.

Decision needed from owner: none for this source-fitted slab repair.
Last line: candidate verification pending; the wider authorized task continues.

## Precommit validation results

The final installed inspection at
**tmp/front-pavement/production/OrisonV2FrontPavementTest.log.receipt.json**
repeats all 911 checks with empty stderr. Matched stationary main-viewport
visible/hidden observations add four to 31 draws and 116 to 892 primitives
across the five recorded views. This measures the installed paving's visible
geometry cost; no stable frame-time or performance-budget verdict is inferred.
All five final inspection views and the native source overview are reviewed.

Ten completed production wrapper suites under **tmp/front-pavement/production**,
plus the separate 25-waypoint service-alley round trip, retain the street crossing,
shed closure, receiving room, bodega power, subway gate, bar sanitary controls,
eleven arcade doors/locks and resident-key save/copy/permission behavior. Every
stderr is empty. Exact result lines and elapsed times are preserved in
**tmp/front-pavement/precommit-summary.json**. All 37 alley frames, both street
crossing frames, five shed views, seven receiving views, four power views and
four subway views are reviewed; ordinary route views retain the carried radio's
foreground and are not fine-finish acceptance.

The complete **tmp/front-pavement/precommit/board.json** has 47 gates:
zero regressions, reader NEW zero, spatial drift zero and no requirements
changed against genuine clean **97faa90**. Existing main incompleteness and the
retained rehearsal failure remain in the baseline. Only the five individually
reviewed test room identities are appended to the spatial manifest; no gate,
runner, baseline or protected receipt is rewritten. Clean committed candidate
comparison is still required before the authorized push.
