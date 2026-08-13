# FINAL MAP REDESIGN — BUILD BRIEF

*Written 2026-08-13 against HEAD `9cc62a7`. Phase 0 measured, not recalled.
This is a build drawing. Where it says a number, that number came off a run
logged in `art/renders/map_before/` or the Phase 0 logs.*

Product purpose: the map serves one loop — issue, diagnose, cross the street,
obtain the part, repair, converse, narcoleptic scramble, wake in 4B. Three
zones only: THE ORISON, THE STREET, THE PASSAGE. No fourth neighbourhood.

---

## 1. Measured current state

All gates green before any edit:

| gate | result |
|---|---|
| project import | clean |
| WalkTest FAST | PASS, 428 checks |
| WalkTest **FULL** | PASS |
| LightingAudit | PASS, 127 spaces, 11 intentionally dark |
| ShopEntryTest | PASS, 0 failures |
| ScheduleTest | PASS, 18 residents on the clock |
| RealityCaseTest / ResidentCastTest | PASS |
| StreetBlockProbe | 2346 points, 73 blockers, **0 solid-and-invisible** |

Content: 484 functional props · 18 rigged residents · 165 fixtures in 119
rooms (75 exterior) · 606 lit windows · 546 acoustic nodes · 999 batched shop
boxes in 11 batches · 181 mesh buckets · 336 nav nodes over 8 floors.

### Performance before (windowed, 1440p, 8 stations)

| station | objs | calls | prims | ms |
|---|---|---|---|---|
| atrium eye (7 storeys) | 28,129 | 28,868 | 38.2M | **41.24** |
| street elevation | 14,074 | 17,339 | 9.7M | **31.24** |
| lobby | 17,188 | 22,252 | 22.1M | **28.78** |
| corridor F04 | 13,910 | 17,169 | 16.7M | **27.51** |
| roof | 2,535 | 2,801 | 0.58M | **20.41** |
| apartment 4B | 4,637 | 5,583 | 5.1M | **17.54** |
| arcade cluster | 5,107 | 5,186 | 1.5M | 15.17 |
| harukiya | 5,204 | 5,185 | 2.7M | 13.25 |

**6 of 8 over the 16.6 ms target.** Absolute ms swings >2x run to run on the
same build; read proportions.

---

## 2. The four discoveries that change the plan

**D-1. There is no dominant term. There are three, and they are per-station.**
Decomposition (`PERF_DIAG_ONLY=1 PERF_DIAG_STATION=…`):

| lever | atrium 28k objs | street 14k objs | roof 2.5k objs |
|---|---|---|---|
| silence 384 prop `_process`, still drawn | ~0% | ~0% | **−47%** |
| hide all illumination | −9..20% | **−34%** | −25% |
| all geometry `cast_shadow` off | −24..38% | −19% | −32% |

TASKS.md §P2 records "user prop scripts are not the cost" as a general
finding. It is true at the atrium and at the street, and **false at the
roof**, where ticking is the single largest lever. The generalisation was
measured at one station and over-applied. Corrected here: where there is much
to draw, submission dominates; where there is little, ungated per-frame work
dominates. The roof draws 2,535 objects — half the harukiya's — and is 54%
slower, because `_update_floor_visibility()` runs every physics tick writing
`.visible` over ~600 nodes, `StreetTraffic._process` advances 14 vehicles
regardless of whether the street is in view, and 384 prop callbacks tick from
anywhere in the building.

**D-2. No streaming system exists to configure.** One visibility gate,
storey-granular, `building_root.gd:1394-1445`, keyed off a single position,
gated by three hardcoded literals (`|x|<3.7`, `z∈(-3.7,6.9)` for the atrium;
`|x|>15.2 or |z|>11.2` for outside). No `VisibilityRange`,
`VisibleOnScreenNotifier3D`, HLOD, distance LOD or room gate anywhere.
Occlusion culling was removed 2026-08-05 but `project.godot:60` still sets
`use_occlusion_culling=true` with zero `OccluderInstance3D` in the project —
a live cost with no benefit. **Zone streaming is a new subsystem, not a
setting.** Scope accordingly.

**D-3. The measured light budget is not the documented one.**
`light_rig.gd:135-156` sets desktop to UNLIMITED/32, then
`building_root.gd:344-351` calls `set_budgets(14, 8)` immediately after
`add_child`, clobbering it. README:531-533 documents unlimited/32. Play runs
14/8. Every perf number above — and every before/after comparison — must pin
this explicitly or it measures an unintended configuration.

**D-4. `vantry` is already a code subsystem.** `vantry_point_network.gd`,
`vantry_point_prop.gd`, referenced by the call interface, signal terminal,
arcade cabinets and prop audio; 119 vantry points in the layout. Of the three
names offered, `vantry_passage` collides for the same reason `arcade` does.

**RULED for this build: code prefix is `passage`. Fiction remains "the Vantry
Arcade".** One unambiguous prefix per subsystem.

---

## 3. Hard constraints the relocation must not break

Test-enforced, all currently green:

- `walk_test.gd:2932` — F01 shop batches must number **exactly 11**.
- `walk_test.gd:2942-2954` — **no `retail_shop_` mesh AABB may exceed 9.0 m**
  in x or z. The legitimate maximum is the laundry metal family at 8.12 m;
  the guard remains far below the former 220 × 148 m floor-wide batch. A hall
  wider than 9 m therefore *cannot* be one batch: the
  eleven interiors stay eleven batches, and the hall shell is separate
  geometry outside the `retail_shop_` namespace.
- Mesh buckets ≤190 (today 181); static boxes ≤1080 (today 999, 81 spare).
- Exactly 10 hero-tagged trades (funeral's hero is the in-situ bier) and
  exactly 11 ledgers, matched by id substring `_ledger`/`_book`. **Renaming
  during the move breaks validators without changing geometry.**
- Buffer fallback is the documented catastrophe: a fitting emitted without
  `batch=` joins the floor-wide F01 buffer whose AABB is 220×148 m; the
  per-object light cap then hands it distant street lamps and **the shop
  renders black**.
- NEWS & CIGARS: `leaf='locked'` emitted at `gen_layout.py:4265`, validated at
  `:6826`, and asserted in `shop_entry_test.gd:322-335` against **hardcoded
  world coordinates** (8.925 / 9.72, z 26.85..30.45). Moving that shop one
  metre silently converts those assertions into tests of empty pavement. The
  test must be re-anchored in the same commit that moves the shop.
- Shop floor top stays at **0.01** to match `sidewalk_s`; the shells were
  re-authored from 0.00..0.05 specifically to kill a 40 mm step at every
  threshold. Arcade cabinets carry no `z0` and stand at 0.00.
- `terrazzo, marble_lobby, subway_tile, linoleum, quarry_tile, timber,
  plywood, vinyl_oxblood, glassish` are **Blender-catalog only**, absent from
  `MatLib.SETS`. Any fitting rebuilt as a GDScript prop renders flat.

## 4. The eleven trades

| trade | tag | bay w × d | area m² | current x-range | inside stage bounds? |
|---|---|---|---|---|---|
| MODEL LAUNDRY | laundry | 5.40×7.00 | 37.8 | −32.4..−26.8 | **NO** |
| SHOE REBUILDING | cobbler | 5.40×6.00 | 32.4 | −26.8..−21.2 | **NO** |
| KEYS CUT | locksmith | 3.40×5.00 | 17.0 | −19.4..−15.8 | yes |
| RADIO SERVICE | radio | 3.00×5.00 | 15.0 | −15.8..−12.6 | yes |
| LUNCHEONETTE | diner | 5.00×7.00 | 35.0 | −11.4..−6.2 | yes |
| NEWS & CIGARS | news | 2.10×4.00 | 8.4 | 7.9..10.2 | yes |
| PAWNBROKER | pawn | 4.40×6.00 | 26.4 | 10.4..15.0 | yes |
| FUNERAL PARLOUR | funeral | 4.40×7.00 | 30.8 | 15.2..19.8 | yes |
| HARDWARE PAINT | hardware | 5.20×6.50 | 33.8 | 21.0..26.4 | **NO** |
| PHOTO SUPPLIES | photo | 5.00×6.00 | 30.0 | 26.4..31.6 | **NO** |
| OTIS & SON | druggist | 4.10×7.00 | 28.7 | −19.55..−15.25 (N) | yes |

Total interior ≈ **295 m²**, frontage sum ≈ 47.4 m.

**The consolidation argument is measurable, not aesthetic.** The lateral stage
boundary stands at `STAGE_W −20.10` / `STAGE_E +20.60`
(`exterior_detail_pass.gd:384-405`), while the shop parade runs x −32.4..31.6.
Four shops — laundry, cobbler, hardware, photo, **139 m² of researched,
fitted, lit interior** — lie wholly outside the lateral bounds. The Passage
brings all eleven inside one reachable envelope.

**CHECK 1 RESULT, measured 2026-08-13 — the claim above was wrong, and the
truth is worse.** `RouteProbe` (`route_probe.gd`, routes SOUTH WALK WEST /
EAST and the four door approaches) swept a 0.33 × 1.524 m capsule along the
south pavement at Godot z 26.03:

| sweep | result |
|---|---|
| south walk, x −18.0 → **−30.0** | **walkable end to end** |
| south walk, x +18.0 → **+29.5** | **walkable end to end** |
| to MODEL LAUNDRY door | reaches 94%, stops on `SITE_SHOP_DOOR_MODEL_LAUNDRY` HingedLeaf |
| to SHOE REBUILDING door | reaches 94%, stops on the shopfront glazing |
| to HARDWARE PAINT door | reaches 94%, stops on the shopfront glazing |
| to PHOTO SUPPLIES door | reaches 94%, stops on the shopfront glazing |

The four shops are **reachable by a route nobody intended**, not unreachable.
Every approach stops only where a body should stop — at the glass or on the
door leaf itself.

**The real defect is that the play space leaks.** `ExteriorStreetStageBoundary`
is two boxes 7.55 m deep centred at Blender y −13.45: they close the NORTH
walk and part of the carriageway and do not touch the south pavement at all.
A player can currently walk to x ±30, roughly 10 m past the intended lateral
limit, along the front of four shops that the composition never planned to be
seen up close. This is a containment failure, and it is why the boundary
rebuild in Phase 4 is load-bearing rather than cosmetic.

*Method note, per the ruling: this was measured, not inferred. The earlier
"wholly outside the lateral bounds" wording came off boundary dimensions and
was wrong. The consolidation argument stands unchanged — eleven shops in one
reachable hall — but its justification is containment, not inaccessibility.*

---

## 5. Where the Passage goes

**Constraint that fixes the location:** the Harukiya's mass `nbr_s2`
(−12.0, −38.2, 6.4, −28.32) already occupies the block directly behind the
south street face from x −12.0 to +6.4, 9.9 m deep. It is canon, built and
tested. The Passage cannot run straight back from the composition's centre.

**Decision: the portal sits east of the bar's mass, hall runs south.**
Depth is the cheap axis — `SHOP_PLAN` already cuts into the block and nothing
is authored behind the south row east of x 6.4. Width is expensive:
`_south_street_wall()` makes every shop its own generated building, so x0/x1
drives footprint, void, awning, blade and signage together.

- **Street portal** 6.0 m wide on the south face `BLDG_S = −28.316`, centred
  near x ≈ 14.0, inside `STAGE_E 20.60` with margin. Narrow portal, long hall
  — the Burlington/Leadenhall pattern, and the reason a 1912 demonstration
  building reads correctly.
- **Hall** runs south from the portal, units both sides of a central aisle:
  aisle 6.0 m clear (player body radius 0.33; carried crates need it), units
  up to 7.0 m deep each side, hall envelope ≈ 20 m × 26 m.
- **Frontage budget:** 47.4 m of shopfront over two sides = ~23.7 m per side,
  which fits 26 m of hall with party walls.
- Roof: glass-and-iron barrel over the aisle. Floor: terrazzo (Blender
  catalog, already available).

**Street section is unchanged and already correct:** WALK_W 4.572 (15 ft),
ROAD_W 9.144 (30 ft), KERB_N −14.75, KERB_S −23.894, WALK_S −23.744. One road
crossing of 30 ft each way. That is the Frogger beat; it needs integration,
not resizing.

---

## 6. Zone ownership (built in Phase 3, per D-2)

| zone | contains | visible from |
|---|---|---|
| ORISON | B1, F01–F06, roof, 18 households | street: facade + lit windows only |
| STREET | carriageway, both walks, traffic, city masses | always while outdoors |
| PASSAGE | hall shell + 11 shop interiors | street: portal glazing only |

Requirement: the player pays for one full zone plus controlled proxies.
Passage interiors must not submit while the player is on the street — today
nothing enforces this because nothing exists to enforce it.

---

## 7. Files to change (exact)

Insertion points, all verified this pass:

1. **Tables** — `shop_interiors.py`: `SHOPS` (:11), `SHOPS_N` (:39),
   `SHOP_PLAN` (:48), `SHOP_FLOOR` (:66), `SHOP_CEIL` (:74).
   `gen_layout.py`: `SHOP_SUB` (:4114), `SHOP_BLADE` (:4129),
   `SHOP_LETTER` (:4134), `SHOP_TRIM` (:4193), `SHOP_BLOCK` (:4157).
2. **Mass** — `CITY_BLOCKS` (`gen_layout.py:3709-3737`) for a hand-placed
   hall, or `_south_street_wall()` (:3740) for a generated host. Both land via
   `CITY_BLOCKS += _south_street_wall()` at :4167.
3. **Void** — `shop_voids()` (:4170-4192) must return the hall rect against
   its block id or the mass stays solid brick behind the glass. Re-read by
   `retail_pass` at :5619 and :5689.
4. **Ground** — anything opening the earth joins `GROUND_HOLES`
   (`site_pass():4478`) or the 220×148 m asphalt sheet lids it.
5. **Hollow** — storeys above a walkable ground floor join `HOLLOW` (:4589).
6. **Fabric** — `_storefronts()` + `build_shop_interiors()`, called only from
   `storm_pass()` at :4859-4865. A hand-authored enclosed room instead follows
   the Harukiya template in `retail_pass()` (:5572-6265).
7. **Order** — `main()` runs site_pass → retail_pass → storm_pass →
   street_lamp_markers (:8512), then `classify_door_markers` (:8516) and
   `validate()` (:8541). Anything emitted after :8516 gets no door
   classification; after :8541, no validation.

Runtime: `building_root.gd` (zone gate), `resident_nav.gd` (Passage anchors),
`shop_entry_test.gd` (re-anchor the news assertions), `perf_probe.gd` (three
new stations).

## 8. Risks and rollback

- **Nav cannot express the hall.** `resident_nav.gd` builds AStar from
  `building_layout.json` rooms/doors/walls and **never reads a prop**;
  `validate_with_collision()` raycasts once, two physics frames after build.
  Residents walk through furniture everywhere today (57 wall-crossing edges
  rejected, 314 relinked). A fitted hall with carts and counters is exactly
  the case it cannot route. **This is a work item, not a side effect.**
- Residents are parented to their home floor and never reparented, so an actor
  who walks to the Passage is culled with the floor they started on.
- `SafetyNet.exempt_zones` is populated only in the DEBUG branch
  (`building_root.gd:452-461`). Any playable volume the redesign adds outside
  the site box is rescued out of in a release build, presenting as a dead
  teleport.
- Per-shop light runs are computed from `SHOP_PLAN` depth
  (`max(2, round(depth/2.4))`); collapsing eleven depths into one hall re-opens
  the navy-interior failure the run was written to fix.
- Arcade cabinets bypass the buffer system entirely (`asm` handled at
  `build_orison.py:4052-4066` before the batch branch) and land in floor-wide
  buffers with shared hull collision.
- **Rollback:** each phase is one commit. Phase 2 (subtraction) is the only
  irreversible one and is committed alone, after the RouteProbe sweep.

## 9. Acceptance tests to add

- eleven shop identities exist exactly once; batches == 11; no obsolete
  street shop interior remains
- every customer shop has a clear entrance-to-counter capsule sweep
- NEWS & CIGARS proprietor side inaccessible, re-anchored to new coordinates
- Orison door, Passage portal and both pavements reachable
- street crossable with no damage, no reload, usable gap ≤ authored max
- shove recovery never lands the player in traffic, wall or scenery
- resident schedules reach Passage anchors
- no nav edge crosses a wall
- Passage interiors do not submit while the player is on the street
- Orison floors still draw when genuinely visible through the atrium
- all five generated JSONs synchronized art→game
- stations within target **with the light budget pinned** (see D-3)

## 10a. RULED 2026-08-13 — the envelope, measured and settled

Sequencing: this is **M0.5 — Final Map Substrate**, between M0 and M1.
`M0 baseline → M0.5 final map → M1 loop spine → M2 Mina graybox`. Not M1.5:
the maintenance-item contract must not bind to shop anchors and visibility
ownership that are about to be replaced. Bounded consolidation, subtraction
and optimization only.

**Portal and throat, ruled and checked:**

| element | envelope | check |
|---|---|---|
| street portal | x 11.0..17.0 at `BLDG_S −28.316`, 6.0 m | centred x = 14.0 |
| throat | x 11.0..17.0, south to y −38.4 | **clears Harukiya by 4.60 m in x** |
| main hall | x 4.0..24.0, y ≤ −38.4 | clears Harukiya rear (−38.2) by 0.20 m |

The throat is the architectural reveal, the acoustic transition and the
visibility portal: from the street it must stop the engine rendering eleven
interiors through one doorway.

**Measured blocker, and its resolution.** A hall carrying 47.4 m of frontage
needs two sides (unit 7.0 + aisle 6.0 + unit 7.0 = 20 m short axis) and ~24 m
of length. From y −38.4 that reaches **y −62.4**, exceeding `SITE_S = −42.0`
by **20.4 m**. Shifting east cannot fix a depth problem. Owner granted space
2026-08-13, so:

- **`SITE_S` extends from −42.0 to −66.0** (`gen_layout.py:3669`). The asphalt
  sheet already covers to y −82, so this is authored-extent bookkeeping plus
  moving the vista stops and far skyline back — not new playable street. The
  hall is enclosed; none of it is walkable from outside the portal.
- Hall clearance to the Harukiya is exactly the 0.20 m minimum. **Author the
  hall front at y −38.6 instead of −38.4** for 0.40 m, unless a rendered
  sightline needs the extra 200 mm.

**The ground the Passage occupies is the ground Phase 2 frees.** The generated
hosts for pawn (rear y −36.9..−39.7), funeral (−37.9..−40.7) and news
(−34.9..−37.7) currently stand exactly where the throat runs. Subtraction and
construction are the same volume, which is why they must be consecutive
commits on one branch and `main` must not rest in a no-shop state.

~~**Light budget pinned for all comparisons: 14 lights / 8 shadows**, the value
`building_root.gd:344-351` actually applies in play.~~ **FALSE, corrected
2026-08-13. The applied budget is 16 lights / 16 shadows.**
`building_root.gd:344` is an if/else and the CINEMATIC branch is the one
taken: `game_boot.gd:20` defaults `launch_mode` to `LaunchMode.CINEMATIC` and
`:22` defaults `quality` to 0, so line 348 `set_budgets(16, 16)` runs and the
14/8 at line 351 is unreachable under default settings. No test overrides it
— only `free_cam.gd:49`, `lighting_debug_test.gd:5` and
`warehouse_teleport_test.gd:14` set `DEBUG`, and none of WalkTest,
LightingAudit, ShopEntryTest, RealityCaseTest, StreetShot or StreetIdShot is
among them. The engine agrees: WalkTest FULL prints "the working set is the
nearest **16** of 104 eligible fixtures", "shadow casters capped at the
nearest **16**", and "circulation fixtures hold the budget (**15** lit)" —
15 lit is arithmetically impossible under a 14-light budget. `git blame` puts
the CINEMATIC branch at `bcd6450`, 2026-08-02, which is when the else branch
died; the claim above was written against the earlier shape and never
re-tested. TASKS.md's "Play runs 14/8" is wrong for the same reason.

**So the standing instruction is unchanged in spirit and changed in value:
every station in every future table states its budget, and that budget is
16/16 until someone deliberately changes it.** Nothing measured so far is
invalidated — before and after ran under the same 16/16 — but every table
labelled 14/8 is mislabelled. Fix or delete the clobber (§P4) before
re-measuring, and do not silently switch contracts mid-comparison. Note that
no code path prints the resolved budget, which is why this survived: the
number was read from source instead of from the engine.

## 10ab. CHECK 2 — probe built, leading candidate named, NOT yet closed

Probe: `game/tests/StreetOwnershipProbe.tscn` + `street_ownership_probe.gd`.
Walks the built scene and reports every mass whose world AABB intersects the
street volume (Godot x ±36, y −0.6..6, z 8..32) with a footprint ≥1.6 m². It
walks `MultiMeshInstance3D` as well, which does **not** inherit
`MeshInstance3D` — without that branch every traffic vehicle is invisible to
the probe, which is the exact class of mass this check exists to name. Run:
**412 records, 0 parse errors** (`own3.log`).

**Method caveat, or the table lies.** The by-owner rollup is dominated by
merged per-floor buffers whose AABBs span the whole site —
`F01_furniture_asphalt` reports 220.0 × 0.3 × 148.0 m. Those are the
documented floor-wide buffers, not objects in frame. Rank by individual node
and discard anything whose size approaches the site, or the answer is always
"F01".

**SwcGraybox was a FALSE POSITIVE, caught by world filtering.**
`arcade_machine.gd:2` `extends SubViewport` and `:82` sets
`own_world_3d = true`, so every receiver's SWC world lives in its own
`World3D`. It is in the scene tree and can never draw into the street. The
probe now prunes `SubViewport` outright and requires a candidate to share the
street camera's `World3D` and `Viewport` and be `is_visible_in_tree()`.
Records fell 412 → **254** and SwcGraybox disappeared. Scene-tree membership
is not render membership; the first draft conflated them.

**The corrected run exposes a harder limit: the masses have no individual
node.** Every remaining large candidate is a merged per-(floor, category)
buffer whose AABB spans wherever that category appears on F01 —
`F01_furniture_timber` 87.4 × 27.7 × 38.1, `F01_furnish_bakelite`
59.0 × 3.9 × 45.6, and so on. The builder merged the street's boxes into those
buffers, so "which node is the black slab" has no node-level answer. **AABB
ranking cannot close this check.**

**Closing it takes two stages, not one.** Hide/show per buffer is the only
*runtime buffer-level* evidence — it says which merged buffer contributes a
visible mass and nothing more. *(SUPERSEDED 2026-08-13 by §10ac: hide/show is
not the only runtime buffer-level evidence. A false-colour pass answers the
same question for every pixel in one render, with no differencing and so no
aligned-pair problem. The two-stage shape of the check was right; the
instrument for stage one was not. Kept per log-don't-delete.)* It cannot recover the source identity of
geometry Blender already merged. Buffer identification must therefore be
followed by source-level provenance: enumerate every generator record feeding
that floor/category/material, restrict by actual coordinates against the
camera volume, and if several survive, build a TEMPORARY unmerged diagnostic
of that category alone — source ids as node names, unique unshaded colours,
rendered from the exact `street_1.png` camera — then match silhouette to id.
Never commit the diagnostic geometry and never change production batching to
suit it. **Merged AABB size is not provenance.**

**Evidence ladder, in order.** Identical deterministic frame as baseline;
`StreetTraffic` hidden as negative control; then `M_screen`; then
`M_glassish`; then one buffer at a time. Compare aligned pairs only — never
two frames at different traffic simulation times, and never across a moving
sky (`street_shot.gd` now pins `DAYNIGHT=0` unless `DAYNIGHT_FORCE` is set,
so a pair differs by the hidden buffer alone).

**Traffic is back in the suspect pool.** The earlier "not traffic" reading
rested on SwcGraybox, which is withdrawn, so it carries no weight and traffic
is tested first.

Material flatness is a **prioritization clue, not silhouette evidence**, and
the source records prove why: the only F01 layout record using `screen` is
`storm_shop_radio_service_scope_face` at roughly 0.04 × 0.28 × 0.22 m, which
cannot individually be a street-sized slab; and `glassish` covers storefront
panes plus many small display objects, so its broad merged AABB implies no
large solid pane. Both are worth suppressing early because they are the only
FLAT entries among the large candidates — `M_screen` at albedo 0.29,0.31,0.33
and `M_glassish` at 0.89,0.93,0.95 — not because their AABBs are big.

*Superseded hypothesis, kept per the log-don't-delete rule:* the original
SwcGraybox reading was —

| node | size m | face m² | material |
|---|---|---|---|
| `@MeshInstance3D@26754` | 16.0 × 3.4 × 20.0 | 320.0 | `graybox_ambience_zone`, flat albedo 0.50,0.50,0.62 |
| `@MeshInstance3D@26755` | 8.0 × 3.4 × 8.0 | 64.0 | `graybox_ambience_zone`, flat |
| `@MeshInstance3D@26753` | 8.0 × 3.4 × 3.2 | 27.2 | `graybox_trigger_volume`, flat 0.90,0.60,0.20 |
| several | 4.0 × 0.3 × 4.0 | 16.0 | `graybox_floor` / `graybox_ceiling`, flat |
| several | 4.0 × 0.3 × 4.0 | 16.0 | `PresentationAnchor`, `worn_flagstone` / `vault_plaster` |

`SwcGraybox` is the arcade/signal-parlour runtime copy
(`game/scripts/arcade/swc_*.gd`, TASKS §A8). Large **flat-shaded, untextured**
boxes 3.4 m tall are the right silhouette, size and material for the masses in
`street_1.png`, and flat-shaded geometry in a night street reads black.

**This is a hypothesis with the right shape. It is NOT proven, and nothing may
be deleted on it.** To close Check 2: a controlled hide/show render pair with
`SwcGraybox` suppressed, matched to `street_1.png`'s camera, and the same for
`PresentationAnchor`. If this is a cabinet's internal world leaking into the
main scene rather than scenery, the fix is a reparent or a SubViewport — not a
deletion, and it would also be a live cost at every station.

## 10ac. CHECK 2 CLOSED 2026-08-13 — and the baseline is stale

**Headline: the black masses are parked cars that the data no longer
contains.** `888b1dc` (2026-08-11) deleted them, with the bus shelter and the
arrival rideshare, for the traffic redesign. *(Count corrected 2026-08-13:
`888b1dc`'s own message says "sixteen parked cars" and this brief repeated it
without counting. The records are **12 vehicle bodies** — `site_car0,1,2,5,6,7,8`
and `site_scar0,1,4,5,6` — plus 8 bus-shelter parts, 39 box records in all:
30 metal, 8 glassish, 1 timber. A commit message is a claim with an author,
not a measurement.)* `game/assets/building/*.gltf`
was last built 2026-08-10 at commit `7f09557` and has not been rebuilt since,
so the cars are still in every frame the engine draws. `gen_layout.py` no
longer emits `site_car*` at all and `walk_test.gd:196` already says they
"came out for the traffic redesign". They came out of the *records*. They did
not come out of the *build*.

**Eight commits have changed `building_layout.json` since the glTF was
built** (`f0bfa74`, `888b1dc`, `3f5278f`, `d53db48`, `e0ab378`, `980bee1`,
`11e3156`, `334efe7`); 212 furniture records exist in the as-built revision
and not in current data, 0 the other way. Anything measured from the current
build describes geometry the data does not have. Re-run Blender before any
further street measurement and certainly before subtraction — and re-measure
the M0.5 baseline afterwards, because `art/renders/map_before/street_1.png`
and `art/renders/map_check2/base/*` both contain phantom cars.

**The instrument** (reusable, committed): `game/tests/StreetIdShot.tscn` +
`street_id_shot.gd`, read by `tools/street_ownership.py` and
`tools/street_provenance.py`. From the frozen `street_shot.gd` camera with
`DAYNIGHT=0` and `StreetTraffic` hidden, every `GeometryInstance3D` sharing
the camera's `World3D` and `Viewport` gets a unique unshaded colour with fog,
lighting, tonemap, exposure, glow, SSAO and reflections off, and the frame
becomes an ownership map. Three properties make it evidence rather than
illustration:

- **The palette cannot wrap.** 4723 instances render in the main world and a
  16-step channel grid holds 4095, so the frame is painted in `ceil(n/4095)`
  passes and merged; id 0 means "named in another pass" and a pixel that is 0
  in every pass is a reported failure. It was 0 px. A denser grid was
  measured and rejected: Godot's dark-end sRGB round trip is not exact
  (nominal 8 lands at 1, 24 at 21, 40 at 38, 56 at 55), so 19 levels per
  channel would sit inside the round-trip error. 16 steps clear it twofold.
- **Nothing is unattributed.** 0 px unresolved, 0 px with no legend entry.
- **The ray builder is checked against the engine.** Stage two reimplements
  `project_ray_normal`; the shot prints five of the engine's own rays and the
  reader asserts against them before using any. Worst error 6.0e-07.

**A wrong first reading, logged.** The first pass credited 23% of the frame
to `WeatherFX/@MeshInstance3D@25804`, a 34 x 26 m quad. It is `_ground_flash`
(`weather_fx.gd:142`), `BLEND_MODE_ADD` with albedo alpha 0.0 — a surface
that can only ever brighten and was contributing nothing. The opaque override
had made it solid and it swallowed the whole carriageway. See-through
surfaces are now hidden rather than painted (411 of them), so a pixel goes to
the opaque thing actually being seen. **An opaque override is not a neutral
substitution.**

**Stage one, buffer ownership of the frame** (`overlay.png`):
`F01_furniture_metal` 15.7%, `F01_walls_fbrick` 11.9%,
`F01_furniture_sidewalk_haunted` 11.8%, `F01_furniture_brick_patched` 8.4%,
`F02_walls_fbrick` 7.8%, `F01_furniture_wet_asphalt` 5.4%,
`F01_furniture_asphalt` 5.2%, sky 4.2%. 90.9% of the frame is below luma 16,
so "dark" barely discriminates; what does is luma *spread* inside a mass. The
featureless slabs all sit at sd ≤ 0.5 against 2–4 for ordinary dark brick.

**Stage two, source records, restricted by coordinate.** Each mass's probe
pixel cast back through the camera's own ray, against the records the build
was actually made from:

| mass (bbox) | sd | nearest matching record | t |
|---|---|---|---|
| 460,264..605,599 | 0.18 | `site_booth` (metal) — still in current data | 3.64 m |
| 668,0..1047,630 | 0.47 | `site_car2` — **deleted by 888b1dc** | 3.71 m |
| 1141,304..1279,467 | 0.23 | `site_scar1` — **deleted by 888b1dc** | 10.45 m |
| 1243,543..1279,719 | 0.00 | `site_car1` — **deleted by 888b1dc** | 1.98 m |
| 593,586..692,700 | 0.00 | `retail_street_crate0` (assembly, candidate) | 3.20 m |

Verified in the other direction too: each record's own box projected back
into screen space lands on the mass it is supposed to explain —
`site_booth` predicts 459,263..594,603 against a measured 460,264..605,599,
`site_car2` predicts x 672..1048 against a measured 668..1047. **A record
that explains a silhouette must also predict where it sits.**

The tall foreground column is the telephone booth, which is authored, wanted,
and simply unlit. Everything else large and featureless is a phantom. Only
`retail_street_crate0` remains a candidate rather than an answer: `crate` is
an assembly whose shape lives in the Blender builder, so it has no box record
to intersect. If it matters after the rebuild, it needs the unmerged
diagnostic emit — and it may not survive the rebuild at all.

**Not done, deliberately:** no temporary unmerged production geometry was
emitted and production batching was not touched. There was no need — the
coordinate restriction left exactly one matching record per mass.

## 10ad. REBUILT 2026-08-13 — and what the rebuild did NOT fix

`782776c`, a standalone rollback commit carrying build products only.
`gen_layout.py` re-ran and produced all five JSONs **byte-identical** to what
was already committed, which is the finding restated: the layout data was
authoritative and current all along and the whole drift was Blender output.
Blender 5.2, 29 s, 8 floors exported, no `BUILD FAILED`.

**The subtraction reconciles to the vertex.** A box record is 24 vertices.
The 39 street vehicle and shelter records `888b1dc` removed are 30 metal, 8
glassish and 1 timber; F01's rebuilt buffers lose exactly 720, 192 and 24.
`rug_green` and `rug_warm` balance identically and `F01_furniture_rug_green-col`
disappears outright. F01 falls 332051 → 316044 vertices. No remainder.

One instrument caveat before the table: the before pass painted `ShaderMaterial`
surfaces opaque because it could not read them, and the after pass detects
their render modes and hides them (the puddle batch,
`exterior_detail_pass.gd:504`, is `blend_mix, depth_prepass_alpha` — the
WeatherFX mistake again at 0.22% of frame). Re-running the after pass with the
old instrument moves every figure below by less than 0.1 point, so it cannot
account for an 8.5-point swing, but the two passes are not byte-for-byte the
same instrument and the table should not pretend otherwise.

| | before (stale) | after (`782776c`) |
|---|---|---|
| `F01_furniture_metal` | 15.7% of frame | 7.2% |
| `F01_furniture_asphalt` | 5.2% | 7.5% |
| `F01_furniture_wet_asphalt` | 5.4% | 7.6% |
| largest metal mass | 74179 px (`site_car2`) | 15091 px (`site_lamp_pole4`) |

`site_booth` still owns 460,264..605,599 and still answers to `site_booth` in
**current** data by ray (3.64 m) and by back-projection (predicted
459,263..594,603). The remaining tall metal mass is the lamp pole. Everything
still large and featureless on this street is now authored.

**THE REBUILD BARELY CHANGES THE PICTURE, AND THAT IS THE POINT.** On the only
valid single-variable pair — `map_check2/id/beauty.png` against
`id_rebuilt/beauty.png`, traffic hidden in both, clock pinned in both — 6.28%
of pixels differ at all. Over `site_car2`'s own projected box the region stays
**100.0% below luma 16**, mean luma 0.13 → 0.27: unlit road at night is as
black as an unlit car, so deleting the car reveals more black.
`site_car1` and `site_scar1` do lift (0.39 → 3.74 and 0.38 → 0.95). The booth
region changes by 0.0%.

**With a negative control, because two renders of one scene are not
identical.** Rendering the *same* build twice: 0.46% of pixels differ, none by
more than 2, max channel delta 3 — the beauty frame carries live rain, so a
beauty A/B is not automatically single-variable. Against that floor the
rebuild is 6.28% changed, 3.87% by more than 2, max delta 130 — **13.8× the
noise**. Per region the separation is total: noise 0.0% inside every one of
`site_car1`, `site_car2`, `site_scar1` and `site_booth`, against signal 60.6%,
24.7%, 50.1% and 0.0%. The booth is the control that matters — it is the one
street mass that should not have moved, and it did not.

Two consequences, and the second is the one that matters for M0.5:

1. The proof that the cars are gone is the **ownership map**, not the
   appearance. A before/after of the lit frame would have shown almost
   nothing and could have been read as "the rebuild did nothing".
   `art/renders/map_baseline/rebuild_before_after.png` is that pair, published
   precisely because it looks unconvincing.
2. **The street's blackness was never mostly the phantom geometry.** 90.9% of
   the frame was below luma 16 before and 90.6% after. Naming and removing the
   masses did not brighten the street, because the street is unlit, not
   obstructed. Anything in the redesign that assumed clearing geometry would
   open the view up needs re-planning as a *lighting* problem.

**Baseline superseded.** `art/renders/map_baseline/street_1..4.png` is the
corrected M0.5 baseline: rebuilt geometry, `DAYNIGHT=0`, traffic live, same
camera. `art/renders/map_before/` and `art/renders/map_check2/base/` are
retained as the record of the phantom and **must not be used as comparison
partners** — `map_before` also predates the clock pin.

**THE REBUILD IS 99.24% NOT ABOUT THE STREET, AND THAT MUST NOT BE BURIED.**
`782776c` removes 122617 vertices building-wide — F01 −16007, F02 −24349,
F03 −22713, F04 −26675, F05 −19018, F06 −13855, B1 and ROOF unchanged. The 39
street records are 39 boxes × 24 = **936 vertices, 0.76% of it**. Every other
floor shrank *more* than the one that held the cars. The rest is 173 apartment
furniture records removed by the other five drifted commits, chiefly `3f5278f`
"Furniture becomes biography: the comfort set is opt-in now" — sofas, rugs,
plants, TVs, coffee-table clutter across F01–F06. 27 buffers disappear
outright and 122 change geometry; 0 nodes were added and no node transform
moved.

That is correct behaviour — the build is *supposed* to match the data — but it
means this commit is not a street fix. **Every interior visual and perf number
taken before 2026-08-13 is now stale too**, not just the street ones, and
anything downstream that assumed apartment dressing is on the earlier level
needs re-checking against the new build.

Verification: WalkTest **FULL** PASS, 499 checks 0 failures — the default is
FAST, which skips the physically-walked legs, and those are the ones geometry
can break. LightingAudit PASS 127 spaces. ShopEntryTest PASS. RealityCaseTest
PASS. Four "No wall-safe resident route" warnings appear on F03/F04; they are
standing noise, not new — the same-scene pair (`idmap.log` before,
`idmap_rebuilt.log` after) reports 363 nav edges cut on both sides, unmoved by
the rebuild. **Light budget: 16/16, not the 14/8 this brief claimed — see the
correction in §10a.** Before and after ran under the same budget, so the
comparisons hold; their label did not.

## 10ae. CHECK 3 CLOSED 2026-08-13 — dimensioned construction control

Rendered drawing and editable source:

- `art/renders/map_check3/passage_top_down.png`
- `art/renders/map_check3/passage_top_down.svg`

The drawing fixes the pre-subtraction substrate in Blender metres:

| control | exact envelope |
|---|---|
| street portal | x 11.000..17.000 at y −28.316; centre x 14.000 |
| throat | x 11.000..17.000, y −28.316..−38.600; 10.284 m long |
| expansion line | (11.000, −38.600) → (17.000, −38.600) |
| main hall | x 4.000..24.000, y −38.600..−64.600; 20.000 × 26.000 m |
| transverse bands | 7.000 m west shops + 6.000 m clear aisle + 7.000 m east shops |
| retained clearance | Harukiya rear y −38.200 → hall front y −38.600 = 0.400 m |
| authored extent | hall rear y −64.600 → approved `SITE_S` y −66.000 = 1.400 m |

This selects §10a's instructed −38.600 front rather than its preliminary
−38.400 line. The earlier “~24 m” is the net-frontage lower bound: 47.4 m of
approved shop frontage split over two sides. The ruled 26 m envelope supplies
52.0 m gross face, leaving 4.6 m for party walls and end conditions. It is not
a second hall size.

The playable Passage boundary is exact at substrate level: portal, throat and
hall interior only. Space outside the enclosing fabric is not playable. The
throat is the visibility and acoustic transition, so eleven interiors do not
submit from the street. Shop order is deliberately not assigned by this
drawing; Check 3 fixes the substrate without making an unruled merchandising
decision.

The drawing also carries Check 1's consequence: `STAGE_W` −20.10 and
`STAGE_E` +20.60 remain shown as temporary street-slice collision. Phase 4
replaces them with visible architecture/weather. No invisible collision is
extended across the leaking south walk.

## 10b. Pre-subtraction checks — CLOSED

1. ~~Ownership of every black mass in `art/renders/map_before/street_1.png`.~~
   **CLOSED 2026-08-13, §10ac.** Nothing anonymous was deleted, and nothing
   needs deleting: the masses are already-deleted records surviving in a
   stale build. The rule held and paid — the geometry that looked like a
   subtraction candidate was a rebuild.
2. ~~Top-down diagram: portal, throat, expansion point, hall envelope.~~
   **CLOSED 2026-08-13, §10ae.** The dimensioned PNG and editable SVG fix the
   construction controls and exact playable Passage boundary.
3. ~~Re-run the Blender build so the glTF matches the records.~~ **DONE
   2026-08-13, `782776c`, §10ad.** Baseline retaken at
   `art/renders/map_baseline/`.

Check 1 (the south-pavement sweep) is closed in §4. Its containment consequence
is an ordering rule: build and verify the honest visible street-end replacement
before retiring `ExteriorStreetStageBoundary`. Do not repair the leak by simply
extending another invisible collision box across the south walk.

**The subtraction gate is now open.** Phase 2 subtraction and Phase 3 Passage
construction remain consecutive rollback commits on one continuous branch;
`main` must not rest in a no-shop state.

## 10c. Closed owner decisions

- Sequencing is M0 → **M0.5 final map** → M1 loop spine → M2 Mina graybox.
- Code prefix is `passage`; fiction remains “the Vantry Arcade.”
- The street portal is centred at x ≈ 14, east of the Harukiya. Its ruled
  throat and hall envelope are recorded in §10a.

## 10af. PHASES 2–3 EXECUTED 2026-08-13 — subtraction and the Vantry Arcade

Phase 2 is the isolated rollback commit `e102a41`, **M0.5 phase 2: subtract the
obsolete street shop parade**. It removes the redundant street hosts, fitted
interiors and markers only after Checks 1–3 opened the subtraction gate. Phase
3 immediately restores all eleven researched identities inside the exact
Check 3 envelope; the branch never rests or pushes in a no-shop state.

The built order is:

| west side, north → south | east side, north → south |
|---|---|
| MODEL LAUNDRY | LUNCHEONETTE |
| SHOE REBUILDING | OTIS & SON |
| KEYS CUT | NEWS CIGARS |
| HARDWARE PAINT | PAWNBROKER |
| FUNERAL PARLOUR | RADIO SERVICE |
| — | PHOTO SUPPLIES |

The shell follows the drawing exactly: portal x 11..17 at y −28.316, throat
to y −38.600, then a 20 × 26 m hall x 4..24 / y −38.6..−64.6 with a 6 m clear
terrazzo aisle. Brick throat walls, eleven shopfronts, party walls, glass and
iron barrel vault, ribs and aisle lamps are authored architecture. The portal
glazing, fanlight, limestone head, ironwork and two jamb lanterns are a
separate STREET proxy; the full hall is not.

Ownership is source-preserving rather than inferred from merged AABBs:

- 1,185 Passage geometry records, all with an explicit shop or shell batch;
- exactly 11 fitted-shop batches importing as 263 local material draws;
- five separately gated shell draws;
- 69 marker-built Passage actors (doors, signs and lights);
- the widest shop draw is the legitimate 8.12 m laundry metal family, inside
  the 9.0 m local-bucket guard and nowhere near the deleted floor-wide batch.

The portal crossing is deterministic. From STREET, all 263 interior draws,
five shell draws and 69 Passage actors are hidden while the STREET-owned proxy
remains. Crossing the ruled plane reveals the hall; leaving reverses it. Four
resident schedule destinations derive both aisle and venue anchors from their
installed door records, and their routes use portal, throat and aisle spines
instead of duplicated coordinates.

Evidence from the final rebuilt geometry:

- `art/renders/map_passage/01_street_portal.png` — STREET proxy only;
- `02_throat_reveal.png`, `03_hall_south.png`, `04_hall_north.png` — the
  revealed shell, aisle and both shop bands;
- PassageVisibilityTest: PASS, 0 failures;
- PassageNavTest: PASS, 0 failures, all four resident routes capsule-clear;
- ShopEntryTest: PASS, 0 failures, all eleven thresholds and the NEWS & CIGARS
  locked proprietor side preserved;
- WalkTest FAST: PASS; WalkTest FULL prints PASS before the mandatory
  60-second watchdog terminates the lingering Godot process;
- LightingAudit: PASS, 127 spaces; ScheduleTest and RealityCaseTest: PASS;
- all five generated pairs (`building_layout`, `acoustic_graph`,
  `prop_catalog`, `material_catalog`, `fixture_light_map`) are byte-identical
  art → game.

Phase 3 does **not** close M0.5. Phase 4 must replace the leaking street ends
with visible architecture/weather and prove the south pavement contained
before `ExteriorStreetStageBoundary` retires. Photoreal finish, pushcarts and
the pinned 16/16 performance stations follow that honest boundary.

## 10ag. PHASE 4 EXECUTED 2026-08-13 — honest street ends

`ExteriorStreetStageBoundary` is retired. Its two 7.55 m-deep shapes covered
only the north pavement and part of the carriageway, leaving the south pavement
open to x −30 / +29.5. The replacement retains the approved spatial controls
`STAGE_W = −20.10` and `STAGE_E = +20.60`; it changes ownership, not location.

Each end now has three named collision spans over the complete street section:

| span | Blender y | visible owner |
|---|---:|---|
| north pavement | −9.45..−14.75 | wet timber construction hoarding |
| carriageway | −14.75..−23.894 | framed local storm curtain |
| south pavement | −23.894..−28.316 | wet timber construction hoarding |

The four pavement faces are a single local MultiMesh draw with visible plank
seams, old notices and four instanced oil work beacons. The two road mouths use
three transparent local weather layers each. Beacons are glow-only geometry:
Phase 4 adds **zero** real lights and spends nothing from the pinned 16/16
budget.

This deliberately does not settle `ORISON_STREET_BRIEF.md` §8. There is no
stinger, dedicated lightning, debris, person, arrival car or traffic-hours
change. The built result is the brief's quiet fallback — architecture at the
pavements, weather in the road — and remains compatible with either later
ruling on whether the street-end tear becomes loud.

Proof:

- `StreetContainmentTest`: PASS, 0 failures. A player-size capsule stops on
  `StreetEndWeatherBoundary` at both exact x controls in all six lanes; both
  central pavements remain reachable; all six collision spans name a live
  rendered owner; the temporary body is absent.
- `art/renders/map_street_ends/01_west_road_weather.png` and
  `02_east_road_weather.png`: the framed storm mouths from the carriageway.
- `03_west_south_works.png` and `04_east_south_works.png`: the formerly
  leaking south pavement visibly ends at timber works, not empty collision.
- WalkTest FAST: PASS and exits 0. WalkTest FULL prints PASS before the
  mandatory 60-second watchdog.

The first visual pass was rejected rather than buried: shaded near-black boards
collapsed into another anonymous black mass. The final face bakes the oil
beacon's weak warm response into wet timber, so the architecture remains
legible in canonical 03:00 production lighting without another light source.

Phase 4 closes Check 1's containment consequence. It does not close M0.5:
Passage finish and pushcarts, complete-route lock, and pinned 16/16 performance
stations remain.

## 10ah. PHASE 5 EXECUTED 2026-08-13 — Passage finish and movable layer

The Vantry Arcade now has the public-hall layer that cannot honestly live in a
merged Blender buffer:

- three individually physical 1920s handcarts — laundry sacks, market crates
  and news bundles — parked in threshold gaps on alternating sides;
- eleven dull-brass threshold nosings derived from the installed door markers;
- twenty-six cast-iron edge-drain sections under the glass roof; and
- one transparent batched wheel-wear pass, confined to the cart lanes rather
  than washing generic grime over the terrazzo.

The finish is three gated draws plus three carts. Each cart is a 46 kg
`RigidBody3D` with a 0.92 × 1.34 m hull, direct player collision and a deliberate
`[E] Shove handcart` verb. Cart physics, collision and rendering all freeze when
STREET owns the frame, so the movable layer does not silently keep simulating
behind the portal. No real light is added to the pinned 16/16 budget.

The starting layout preserves the exact x = 14 schedule spine and all eleven
shop approaches. `PassageFinishTest` proves the full 25 m spine capsule-clear,
moves the loaded market cart 97 mm under one shove, keeps it inside the bounded
hall, and proves the STREET gate disables and restores all three bodies.
`PassageNavTest` remains green for all four resident destinations;
`PassageVisibilityTest` now accounts for 69 marker actors plus three carts and
the three finish draws.

Rendered evidence is in `art/renders/map_passage_finish/`: one complete middle-
layer view and close views of all three loads. As in Phase 4, one rejected pass
is recorded instead of normalised: the first cart sides were 340 mm solid iron
plates and collapsed into near-black boxes at an angle. The final carts use
open narrow rails and posts, preserving the load, wheels and floor behind them
as a legible silhouette.

Phase 5 does not implement PS5 carrying or PS6 hours. Those change the gameplay
loop and answer an unresolved night-state question respectively; they are not
smuggled into M0.5's substrate. Complete-route and pinned performance acceptance
remain before M0.5 closes.

## 10ai. PHASE 6 EXECUTED 2026-08-13 — route lock and measured blocker

The final three-zone route is now one executable proof rather than a chain of
local sweeps. `FinalMapRouteTest` drives the real `PlayerController` from the
Orison lobby, through the landmark entry, across both Street kerbs, through the
exact portal and throat, down the x = 14 Passage spine and onto HARDWARE
PAINT's customer floor. It then walks the loaded map back to the lobby. The
test opens the two real door leaves, uses normal step-and-slide movement, and
asserts the portal plane, traffic-gap contract and both street-end controls.
It passes in both directions with zero failures.

That route exposed a zone-ownership defect in the old floor gate. PASSAGE was
geometrically outside the Orison envelope, so the generic `outside` branch
submitted the entire eight-floor apartment stack from inside the arcade. F01
also owns the original site export, making 170 non-Passage geometry draws
eligible inside the hall. The corrected rule is explicit:

- PASSAGE retains F01 as the imported hall host but hides F02–F06 and ROOF;
- Passage actors and interiors submit inside, while non-Passage F01 actors and
  the 170 foreign site draws do not;
- STREET retains its shallow portal proxy from either side of the plane; and
- the Passage envelope is vertically bounded at Godot y −0.50..5.80, so the
  aerial street-elevation benchmark at y 12 remains a STREET/exterior view.

`PassageVisibilityTest` proves all four rules. Visibility assignments are now
written only when their value changes; the existing per-physics-tick scan is
still present and is not represented as a complete streaming system.

### Pinned performance acceptance

`Perf.tscn` now owns and prints the resolved **16 light / 16 shadow** budget and
adds the three production Passage viewpoints used by the render harness. The
same 11-station run before and after the ownership correction measured:

| station | before ms | corrected ms | 16.6 ms gate |
|---|---:|---:|---|
| lobby | 31.55 | 29.90 | FAIL |
| atrium eye | 42.48 | 40.91 | FAIL |
| corridor F04 | 27.53 | 26.94 | FAIL |
| apartment 4B | 18.51 | 19.36 | FAIL |
| street elevation | 36.39 | 29.55 | FAIL |
| roof | 20.47 | 19.82 | FAIL |
| Harukiya | 12.49 | 11.01 | PASS |
| arcade cluster | 12.47 | 11.47 | PASS |
| Passage throat reveal | 14.91 | 12.55 | PASS |
| Passage hall southbound | 18.80 | 15.38 | PASS |
| Passage hall northbound | 38.37 | 23.97 | FAIL |

Absolute frame time remains noisy on this machine; the gate is evaluated on
the recorded run, not on a claimed precision the harness does not have. The
ownership correction is nevertheless material: two of three Passage stations
now meet target and the northbound view improves 37.5%. A separate northbound
diagnostic measured 9,153 objects / 12,112 calls at 26.11 ms. Hiding
illumination reached 17.73 ms; disabling all shadow casting reached 19.47 ms;
hiding functional props reached 19.22 ms. Stopping prop ticks, 12 m prop culls
and global prop batching did not produce a stable win. The remaining cost is
legitimate local content, light, shadow and submission rather than a second
foreign-zone ownership error.

No small-prop shadow policy is applied here. It changes the look and remains an
owner decision requiring before/after review. Under the execution-plan gate,
M0.5 therefore remains **open on an explicit measured blocker**: 7 of 11
critical stations miss 16.6 ms, including Passage northbound at 23.97 ms. The
owner must either accept that blocker or choose the visual performance policy
before M1 begins.

Final-state evidence:

- `art/renders/map_final_acceptance/01_street_portal.png`;
- `02_throat_reveal.png`, `03_hall_south.png`, `04_hall_north.png`;
- FinalMapRouteTest, PassageVisibilityTest, PassageFinishTest, PassageNavTest,
  ShopEntryTest routes, StreetContainmentTest, WalkTest FAST and FULL,
  RealityCaseTest and LightingAudit: all PASS with zero failures.

WalkTest FULL completes in 48.3 seconds at its supported x8 / 480 Hz setting.
The scale preserves the canonical capsule displacement per physics step. After
the physical walks and shared-elevator checks have completed, the harness now
pauses the eighteen unrelated resident routines while it drives Cases 02–08;
ScheduleTest owns those clocks, and the case order, timers and stateful
consequences are unchanged. This replaces the earlier x4 run that reached the
watchdog before printing a verdict.

## 10aj. SHADOW POLICY REVIEWED 2026-08-13 — real, capped, not enough. NOTHING APPLIED.

Instrument: `PERF_SHADOW_OFF` on `perf_probe.gd`, inert unless set, plus
`ShadowPolicyShot.tscn`, which reads the station list *and* the suppression
pass from perf_probe itself so the renders and the measurements can never
describe different cameras. Evidence: `art/renders/shadow_policy/`.

**Measure the noise before believing a delta.** Two identical baseline runs
differ by up to ±1.36 ms (atrium) and ±1.24 (roof), and the atrium's *object
count* swings 11% between identical runs. Two identical baseline **renders**
differ on **86.1% of lobby pixels** and 19.2% of harukiya's — residents move.
Draw calls at the Passage stations are stable to ~0.3%. Calls are the signal;
ms is the estimate.

**Northbound, at the pinned 16/16 budget:**

| policy | calls | ms | vs baseline |
|---|---|---|---|
| baseline | 11980 | 23.44 ±0.42 | — |
| A — all `furnish` props | 11950 | 23.67 | **0, inside noise** |
| B — shop stock/fittings | 10172 | 22.38 | −1.06 |
| A+B | 9618 | 21.42 | −2.02 |
| CONTROL — every shadow off | 6858 | 18.35 | −5.09 |

**No in-scope policy flips a single station.** Baseline fails 7 of 11; A, B and
A+B each still fail 7. Only the control flips one (4B 19.08 → 14.93) and it
*still* leaves northbound at 18.35, **1.75 ms over budget**. The ceiling on the
whole lever is −5.09 and the gate needs −6.84. **Shadow policy cannot pass the
Passage even taken to the unshippable extreme.**

**The one option that pays materially flattens the arcade.** B changes 75.5% of
northbound pixels at mean |Δ| 31/255 against a 0.1% noise floor: bays wash out,
shopfronts stop receding, piers go bright — see
`compare_passage_hall_northbound.png`. That is the stated reject condition, so
**B is rejected on its own evidence.** A is visually free (every station at or
inside its noise floor) and buys nothing where it is needed. Nothing narrower
helps either: A+B is −2.02 of the −5.09 ceiling and the missing 3.07 is
architecture — vault, shell, stairs — which is out of scope by instruction.

**RECOMMENDATION: approve no shadow policy.** Not "adopt the safest": no option
has a benefit that justifies a visual decision.

**Correction to §10ai, with the runs to back it.** Phase 6 recorded that
stopping prop ticks "did not produce a stable win". Repeated twice here at
northbound it is one of the *most* stable levers measured:

| | baseline | props drawn but not ticking |
|---|---|---|
| run 1 | 25.85 ms | 20.77 ms (−19.7%) |
| run 2 | 25.80 ms | 20.85 ms (−19.2%) |

Objects and calls are unchanged (9155 / 12404) because nothing stops being
drawn — it is pure CPU, and therefore **has no visual cost at all**. It is
worth about what the entire shadow lever is worth, for free. §2 D-1 found the
same at the roof (−47%) and this brief then generalised it away as "prop
scripts are not the cost"; they are the cost wherever there is little to draw,
and the Passage is such a place. **That is where the next measurement belongs,
not in shadows.**
