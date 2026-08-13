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
- `walk_test.gd:2942-2954` — **no `retail_shop_` mesh AABB may exceed 8.0 m**
  in x or z. A hall wider than 8 m therefore *cannot* be one batch: the
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

*To verify before Phase 2 commits to this: sweep `RouteProbe` along the south
pavement past both boundary boxes. The boxes are 7.55 m deep in y and may not
close the south walk, in which case those four are reachable by a walk nobody
intended rather than unreachable. Either way the consolidation stands; only
the wording of the justification changes.*

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

## 6. Zone ownership (to be built, per D-2)

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

## 10. Owner decisions required

1. **Sequencing.** This brief contradicts `a8eda17` (2026-08-13), which ruled
   M0 → M1 loop spine and said not to begin street or shop expansion work.
   Both cannot be first. Recommend: map redesign proceeds, and the execution
   plan + `next_session_plan.md` are rewritten to place it as M1.5, so the
   next agent does not inherit two contradictory orders.
2. **Code prefix `passage`** confirmed (D-4), fiction stays "Vantry Arcade".
3. **Portal at x ≈ 14** — east of the bar's mass — accepted, or the hall goes
   west of x −12 at the cost of the druggist's north bay.
