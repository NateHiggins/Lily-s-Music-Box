# Residents with walking bodies

Evidence class: **INERT - DESIGN NOTE**

*Session task 2026-10-25, done here at the owner's request: "Give a second
resident a walking body in V2."*

## 1. One route owner for anybody

Until now only Mina walked in V2, through a route owner written for her
alone. That owner is now shared: `game/scripts/characters/orison_v2_resident_route.gd`.
It reads one route file per resident:

| Field | Meaning |
|---|---|
| `resident`, `name`, `unit` | whose body, the name it answers to, their flat |
| `frame` | `orison_v2_blockout`; points are adapter-root local (plan x, floor height, plan y) |
| `doors` | the flat's own doors; each must belong to the unit |
| `paths` | chains of named points; a name shared between chains is one point |
| `places` | agenda place → point; any `unit:<room>` without a point uses `unit` |
| `away` | optional point where the body leaves unseen for places the route cannot reach |

The resident's agenda (`design/ORISON_RESIDENT_AGENDA_2026-10-24.md`) is
restricted to the places the route reaches.

Every resident on a route shares the same building doors and the same
public network. The doors are the mail room's, the laundry's, the bodega's,
and the front door (`F01_DOOR_06`, added after the entrance rebuild). The
network runs down the stairs to the lobby, the mail bank, the laundry, the
street and the bodega.

Mina's own owner (`orison_v2_mina_routine.gd`) is now a thin subclass. It
keeps her animation behaviour (door gestures, tired idle) and her late hurry
to the bodega. Anyone else walks on the shared idle and walk clips, and opens
doors without a gesture.

## 2. Lena Ortiz, 2B

Lena is the second body (`game/data/orison_v2/lena_routine.json`). She is
sociable, makes rounds in the corridors, shops at the bodega, and already
carries her shopping home (`design/ORISON_INVENTORIES_2026-10-25.md`).

**Inside 2B** her route covers:
- her chair
- the main room
- the vestibule and entry door
- the private hall, kitchen, bedroom and bath

**Outside** it runs down the east hall to the core, where it joins the
public network.

**Visits** to other flats, the roof and the Arcade take her to the stair
head, and she leaves there unseen, as Mina does going out.

## 3. Clearing the routes

`OrisonV2RouteProbe` (`game/tests/orison_v2_route_probe.gd`, `ROUTE_FILE`)
checks a route file in the production V2 root. At every point, and every
10 cm along every flat edge, it needs floor support and room for the
0.28 m capsule. It runs twice: once with the doors closed, then with every
door on the route open, because a swung leaf blocks like furniture. For
anything blocked it suggests the nearest clear spot.

The probe found the cause of the Mina route failures already on main. The
fire-line stair cabinet (`F02_FIRE_LINE_STAIR` and the same stack on every
floor) stands where the shared stair points were. The owner chose to keep
the cabinet where it is, rather than edit the hash-bound blockout. The
shared points move about 15 cm clear in both route files:
- `stair_top_clear` and `basement_stair_top_clear`, to the cabinet's east side
- `basement_stair_bottom`, off the south wall

The same probe cleared Mina's flat:
- `bed_approach` steps off the 2A hall hamper.
- A new `bath_in` point takes her past the open bath leaf and clear of its
  closing sweep before she turns to the sink stance, so she can shut the door
  behind her.

One rule changed in the shared owner: a resident whose next step takes them
away from a door does not start opening it yet. A sink stance inside a door's
sweep used to deadlock: she waited for a leaf that would not swing into her.

**Doors that ease shut.** Main's passage-first doors
(`game/scripts/props/easy_door_motion.gd`) close by themselves at
0.2 rad/s, 3.5 s after opening. Before closing they looked only for the
player, who has a collision exception with the leaf. A resident has none,
so every route on main met a leaf easing shut across it: Mina's failed at
`F02_DOOR_02`. Now:
- a door holds its self-close while any resident stands within reach of
  its leaf;
- a resident stepping into a leaf already easing shut gets it swung back
  open, rather than a leaf frozen halfway.

## 4. Measured

- **Route probe:** 0 failures, with doors closed and open.
- **`OrisonV2LenaRouteTest`, run in the game window:**
  - Lena walks 175 m: kitchen, bedroom, bath, chair, the east hall, the
    lobby, the mail bank, out to the street and home.
  - No teleport and no block, and her capsule never overlaps a leaf.
  - Every door she opened is closed behind her.
- **All four Mina route rounds now pass** (bodega, mail, laundry, domestic),
  as does `OrisonV2MinaDoorSafetyTest`. All four rounds failed on main.

Both route tests hide the player's arrival body. It stands by the front
door, and a resident rightly will not swing a leaf through it.

## 5. Not done

- Lena opens doors with no reach-and-push gesture. Only Mina has door clips.
- She does not walk into other flats, the roof or the Arcade. She leaves at
  the stair head.
- No third resident yet. Adding one is a route file plus a line in
  `ResidentRoute.ROUTES`, checked with the probe.
