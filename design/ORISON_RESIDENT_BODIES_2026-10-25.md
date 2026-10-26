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
and the front door (**F01_DOOR_06**, added after the entrance rebuild). The
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
fire-line stair cabinet (**F02_FIRE_LINE_STAIR** and the same stack on every
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
**F02_DOOR_02**. Now:
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

## 5. Sacha Reed, 6A, and the other residents (2026-10-26)

`tools/build_resident_routes.py` drafts a route file for every resident
without one (16 in all):
- room centres, with crossings 0.7 m either side of each door or opening;
- a public walk to the floor's stair head;
- the shared stacked stair chain down to F02;
- places and an `away` point.

**Clearing the drafts.** The probe now suggests a detour for a blocked edge,
as well as a clear spot for a blocked node. A sample with no floor counts as
bridged when there is floor 15 cm ahead and behind it along the edge: the
capsule spans a threshold gap under a wall. `tools/apply_route_probe.py`
moves the nodes and inserts a `<a>_via_<b>` waypoint for each detour. Seven
rounds took the 16 drafts from 195 findings to 31.

**Sacha Reed** is the third body
(`game/data/orison_v2/sacha_reed_routine.json`), the first draft to clear
the probe. `OrisonV2ResidentWalkTest` (`RESIDENT=sacha_reed`, in the game
window) walks a resident to every place their route file names and home
between each. It applies Lena's checks: no teleport, no block, no leaf
overlap, every own door closed. Sacha walks 1,215 m with 0 failures.

**A rule changed in the route owner.** Sacha's first walk stuck on a sill
edge in the F06 west hall: a near-vertical face 1.4 cm proud of the floor.
The owner now walks over a steep face within 6 cm of the current floor
height. The earlier comment said it should; the code refused it. Lena's
route still passes (175 m, 0 failures).

**The other 15 drafts stay on branch `claude/all-resident-bodies`.** They
are not registered. Their 31 remaining findings need hand placement:
- `bed1` and `main` nodes wedged by beds and dining chairs (C units, 3A,
  4A, 1D);
- vestibule nodes inside their own entry leaf's open swing.

## 6. Not done

- Lena and Sacha open doors with no reach-and-push gesture. Only Mina has
  door clips.
- They do not walk into other flats, the roof or the Arcade. They leave at
  the stair head.
- Fifteen residents still have no body. Adding one is a cleared route file,
  a line in `ResidentRoute.ROUTES` and a reader-gate entry for its `places`.

## 7. Sacha integration continuation (2026-10-26)

The paused verification batch completed on **e548aef1**. Its original wrapper
receipts and logs are preserved without modification in
**art/reviews/resident_routes_20261026/original_verification.zip**:

| Played check | Actual result | Limitations |
|---|---|---|
| Sacha, generic resident tour | 1,216.2 metres, 36 checks, zero failures; empty stderr | Forced destinations exercise the registered route; not an ordinary full-day agenda or save/reload test |
| Lena route regression | 174.7 metres, zero failures | Shutdown reports seven Texture RIDs; retained as an unresolved finding |
| Mina door safety | 81 checks, zero failures; empty stderr | Door-owner regression, not a new player-interaction qualification |
| Player vertical route | 124 waypoints, zero failures | Shutdown reports the same seven Texture RIDs; no clean teardown claim |

The first failed Sacha walk and the original headless trim refusal are retained
alongside the successful runs. The latter is the known headless MultiMesh pose
readback limitation; composed source-pose surveys must run windowed. Neither
failure is overwritten by the later successful logs.

The integration branch starts from current main **0e615f91**. Its Sacha code/data
tree is byte-identical in Git to Claude's **6152df98** tree. Every original run
matches runtime-input digest
**f353d2cb2801414dc23c1dc6c0af48f7c1ac6c7f2012d20d396bd45dd8f17260**.
The original checkout's raw test hashes were checked against their receipts;
tests in the integration checkout match after LF normalization (the generic
walk test has checkout-only CRLF conversion). Full source equivalence and
comparisons are recorded inside the archive. No receipt is repinned, and no new
execution is asserted by that comparison. Unchanged long routes are reused
under the batch workflow rather than rerun for this report.

These are legacy played checks and wrapper **suite_run** receipts, not schema-2
ledger **runtime_contract** proof. This INERT note does not promote any space,
grant human acceptance, establish save continuity or claim V2 complete. The
fifteen drafts remain preserved remotely on **claude/all-resident-bodies** and
remain unregistered.

A complete clean-main static board is captured under
**C:/ov/reports/sacha_integration26/main_0e615f91**. It retains the existing three
surface-qualification defects and six blocker counts **7 / 8 / 110 / 42 / 134 /
136**. Final candidate comparison, protected 17-path checks, V2 selector/V1
rollback, changed gate review and reader NEW verification are recorded by the
candidate verifier under the same external report root and summarized on the PR.
This report grants no exemption for a regression. The changed reader-gate line
only registers the new resident's existing shared `places` consumer; spatial
records name the new authored test/route coordinates. Neither changes an
acceptance threshold.
