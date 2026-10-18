# Finished-wall furnishing clearance and arcade fabric — 2026-10-18

Evidence class: **INERT**. Implementation and diagnostic report; no new
spatial, runtime, human or photoreal acceptance grant comes from this document.

## Placement

The production composition now measures the actual installed baseboard,
panel, cap and eye-rail instance envelopes. It checks 430 furnishing and
wall-hanging assemblies and adjusts 187. Floor furniture keeps a 12 mm gap
beyond the finished surface. Hanging pieces keep a 4 mm gap and move within
the existing floor/ceiling limits, preserving their wall plane and bearings.

The complete actor moves: visible stock, collision and supported objects keep
their relative poses. Paired dining chairs follow their table; separately
mounted receivers, lamps, terminal and light table follow their actual support.
Semantic anchors and acoustic bindings stay aligned. Approach markers retain
their floor height. A conservative neighbour/wall/door check rejects increased
overlap; small sideways moves are allowed where a direct outward nudge would
make a neighbouring fit worse. Reapplying composition does not move an
already fitted installation a second time.

Garment rails and wall-screwed shelves are treated as hanging installations.
The leaning ladder keeps both original bearings; its actual triangles, rather
than its enclosing box, are checked against trim. Existing native support
tests retain their 40-micron contact and normal limits. The family tests now
compare the authored pose plus measured refit, while retaining exact native
geometry, local frames, UV, normal, material and collision checks.

The first physical repair replay exposed a genuine access regression: the
shifted **2B_dress_form** blocked the held radiator insert. The ray diagnosis
identified the actual dress-form collider. Its authored anchor now sits
350 mm farther west in the same room, with unchanged yaw, identity and native
geometry. Actual unthreading, carrying, replacement, ordered repair outcome
and disk reconstruction subsequently passed. The hand's occlusion rule was
not relaxed. The workflow now explicitly includes neighbouring service paths.

## Arcade installation completed in the same batch

The canopy follows the retained rib envelope, replacing 34 source boxes and
three obsolete ornament draws with closed fitted glass, gables and structural
stock. The source includes a portable editable native file. The throat uses
5,824 eased bricks and recessed mortar, batched into four material draws.
Original registration, named ownership and the remaining architectural stock
are retained in both initial mounting and cell reconstruction.

Five registered custom PBR sets replace the arcade floor and masonry stock.
Pigment is separate from physical relief and roughness. Their normal gains
are calibrated from their own height recipes, rather than a global gain
increase. Loaded texture chains are complete. The retained floor partitions
use a 400 mm physical repeat; disabling compression on the passage import
corrected a measured 1.66 percent UV error on narrow border faces.

The isolated imported-cell bench passed 286 checks. The final composed
surface execution passed 32,756 checks with zero failures: 25,654 draws,
16,624 meshes, 6,104 materials and 497 loaded textures. Twenty-five changed
views were reviewed. These are technical and incremental appearance checks,
not a declaration that all stock is photoreal or all regions are complete.

## Retained diagnostics and verification

The packet is **art/reviews/v2_clearance_20261018/**. Failed trials are kept in
**diagnostics/**. They include the mistaken floor classification of hung stock,
obsolete absolute-position assertions, unsafe neighbour conflicts and both
actual insert-carry failures. The intermediate source3 surface pass was
superseded by the authored dress-form access correction; it was not repinned.

The existing three runtime packets are renewed only from original test-written
schema-2 contracts and matching completed wrapper/raw logs. The successful
first-slice execution reported 360 checks, including actual disk save/rebuild.
The home cohort passed 62 rooms, nine legs and 909 checks; the upper cohort
passed 69 rooms, eleven legs and 989 checks. Both recorded zero failures and
retired all tracked production roots/drivers. Clean candidate comparison is
pending below.

## Management report

    REPORT - V2-FURNISHING-CLEARANCE - 2026-10-18
    Branch / HEAD / origin/main / merge-base: main / pending source commit / 57df6f2289160b639a5941299a6b44a0650134e5 / 57df6f2289160b639a5941299a6b44a0650134e5
    Worktree clean at end: no; inherited UID/import, enamel metadata, old receipt and unrelated M08F test changes are excluded.
    Protected 17/17: pending clean candidate verification. Selector: v2; explicit v1 rollback retained.
    Ledger before -> after: 0/1/48/25/65/67 -> pending; requirements_changed: []
    Gates: reader NEW0; calibrated recipe projections wrong0/125; four focused catalogue/canopy tests pass; complete clean baseline has 82 rows and 70 passing tools suites.
    Godot receipts: surface4.log.receipt.json PASS 32756/0; first_slice_contract_20261011/suite_run.receipt.json PASS 360/0; home/upper canonical suite_run.receipt.json PASS 62/9/909/0 and 69/11/989/0.
    Numbers: 430 furnishings/hangings checked; 187 refits; 25 reviewed changed views; 497 loaded textures; the loaded mip policy qualifies.
    Changes outside expected boundary: catalogue/generator/import policy and shared native placement assertions support the installed arcade stock and finish-aware refit. No gameplay permission or contact tolerance weakened.
    Open findings: broader V2 structural/runtime obligations remain; seven existing Texture RID shutdown warnings, simplified cloth/wood/fascia finishes and opaque upper arcade equipment need further work. Historical broad provenance pins remain historical; no receipt was repinned. No human or photoreal acceptance granted.
    Decision needed from owner: none for this authorized fitting and verification work.
    BLOCKED clean candidate comparison pending
