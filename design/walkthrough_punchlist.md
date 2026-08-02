# Walkthrough punchlist

Live log for the room-by-room pass. One line per finding:
`room | symptom | severity` — severity is `blocker` (breaks play),
`ugly` (wrong but survivable), or `wish` (make it better).

## 2026-08-01 walk — method and caveats

Walked by rendered evidence: `res://tests/WalkthroughShots.tscn` (new,
generated from building_layout.json room rects) produced 193 eye-height
stills — every room, two diagonals for rooms ≥ 20 m² — reviewed floor by
floor. `SCREENSHOT_TEST_CAMERA_LIGHT=1` was on, so lighting mood was NOT
judged (that stays LightingAudit's job); this pass is placement, geometry
and function only. Stills in the session scratchpad `walkthrough/` dir.

**Tool artifacts, not bugs (excluded below):** bath/office rects are carved
out of MAIN rects, so a MAIN corner camera can stand inside the nested
bathroom (every "D_MAIN renders a bathroom" frame: F01/F02/F03/F06). Corner
cameras also don't dodge furniture, so a wardrobe parked at the shot corner
fills the frame (C_BED2 on F02/F04/F05/F06 — the wardrobe-in-corner itself
may still deserve a look in-engine). Re-aim those cameras before trusting
those rooms as "clean".

**WalkTest baseline at walk time:** FAIL (5) — all five are elevator checks
(doors at own landing, reached F06/B1, doors reopen, rider travels), which
sit in the parallel session's uncommitted NPC-elevator work (`elevator.gd`
`npc_request` + routines). Theirs to land; everything else green.

**Hypothesis for the white-rectangle family** (hall voids, corridor boxes,
roof sign, above the B1 poster): these look like story/atmospheric decal
quads with no texture assigned — `story_decal.gd` and the new
`atmospheric_decal_pass.gd` are both mid-edit in the parallel session, so
coordinate before fixing.

## User-reported 2026-08-02 (lobby pass)

| room | symptom | severity |
|---|---|---|
| lobby | old generated wood mailbank still on the south wall — superseded by the functional brass bank; remove asm + marker from gen_layout and regen | ugly |
| F01 office | title-image plaque (maintenance_headquarters._build_plaque) — remove from world, retool the concept | ugly |
| foyer | bench is decorative and on the wrong side of the entry door — move across, add sit affordance, move Teresa's haunt with it | ugly |
| all floors | wall art misplacement family: pieces off-wall, floating, or crossing the mid-wall picture rail — full placement audit + a loud test | blocker |
| stairway | half-landings share/lack art — each of the seven landings needs a unique piece | wish |

## Systemic (one fix, many floors)

| room | symptom | severity |
|---|---|---|
| all bedrooms/kitchens | Blinds decoupled from windows: slats on bare brick with no frame, overshooting frames, or floating at ceiling height (F01 A/D_BED, F02 A_BED+B_KITCHEN+C_BED1, F03 A_BED, F04 A_BED+C_BED1+D_BED+B_KITCHEN, F05 A_BED+B_KITCHEN+C_BED1+D_BED, F06 A_BED+B_KITCHEN+C_BED1) — one placement offset in the window-dressing pass, not 15 bugs | blocker |
| several bedrooms | Windows glazed with brick — panes show wall texture, no glass (F01_COMMON_B, F02_D_BED, F05_D_BED, F06_D_BED) | ugly |
| several bedrooms | Wardrobe parked directly in front of a window (F01_A_BED, F03_A/D_BED, F04_D_BED, F02_A_BED) or crowding a doorway (F02_B_MAIN, F03_B_ALCOVE, F06_B_MAIN) | ugly |
| WSTOR F02–F06 | West storage: hard-edged untextured white slab covering most of the floor plus a bare white cube mid-room, every floor (F04 slab fills the walkable space) | blocker |
| HALL F01–F05 | Blank pure-white rectangle floating in/above the stair opening (also corridor-wall white boxes F02/F03, ROOF sign face, B1 above the exit poster) — see decal hypothesis above | ugly |
| all UTILITY | Duct/chase column freestanding mid-room, stops short of floor and/or ceiling, pendant lamp clipping into its face (B1, F02–F06) | ugly |
| A/B BATH all floors | Faucet hardware detached, floating above/behind the basin (F01_A, F03_A/B, F04_A/B, F05_A/B) | ugly |
| C/D BATH F02–F05 | Towel bar runs past its bracket across the door trim/switch plates (F02_C/D, F03_C, F04_C/D, F05_C/D) | wish |
| several BATH | Sticky-note/plaque decals at ceiling height, detached from their boards (F01_A, F03_B, F04_A, F06_A/B) | wish |
| unit MAINs | Lived-in socket prop labels ("Mysterious Hotel Towel", "Unfinished Manuscript", "Self-Appending Forms"…) float mid-air detached from props and render mirrored from behind (F01 lobby, F04, F06; F03 reviewer read them as intentional) — if they're meant as look-prompts they shouldn't be world-space always-on | ugly |

## Pre-seeded

| room | symptom | severity |
|---|---|---|
| all units | ~~TV picture bugs~~ FIXED: root cause was ffmpeg 8.1.2 writing malformed Theora; station rebuilt live (per-clip shuffle, E toggles sets, NPC watching, glow, 9-fault shader) | done |
| lobby | ~~duplicate Evelyn (test figure)~~ FIXED: lobby figure retired, assertions moved to the real 1A resident, UUID clips named by eye (ClipSheet.tscn) and ROLES re-pointed | done |
| all units | ~~17 residents still billboard sprites~~ FIXED: the generated `_rigged.glb` cast upgrades in place, and Evelyn's Meshy set is retargeted once onto their shared skeleton (`resident_moves.glb`) — every resident sits, works, reaches and glances; bespoke gaits still win where they exist. Hero models per the execution plan replace these as they land | done |
| broadcast | Sora watermark visible in some frames at close range — DECIDED 2026-08-01: don't care for now; illegible at play distance in every walkthrough still, and clips get re-cut when new broadcast footage lands. Revisit only if a marketing capture frames a TV close up | wish |
| B1 hall | ~~"KNOW YOUR EXIT" poster~~ VERIFIED in the walk: poster reads fine; only remaining issue is the white rectangle above it (decal family, parallel session's) | done |
| corridors | ~~door spill bars~~ VERIFIED 2026-08-02 unlit at play height: warm bar under 4A's door plus jamb slivers read clearly (b_40 re-render); only 9 doors leak by design (circulation/asleep gating) | done |

## B1

| room | symptom | severity |
|---|---|---|
| B1_STORAGE_CAGES | Cage partitions are solid opaque metal (no chain-link read), no cage doors or stored contents | ugly |
| B1_LAUNDRY | Washer/dryer units freestanding mid-floor away from every wall, drums facing open space — reads unplaced | ugly |
| B1_LAUNDRY | Empty white window-style frame embedded at ceiling height in the brick wall, top edge clipped | wish |
| B1_ATRIUM | Light-well tube intersected mid-height by a white rail/stringer; its lower run passes through the reading-nook furniture | ugly |
| B1_COAL | Only a bare untextured white block on clean brick — no coal, chute, or grime | ugly |
| B1_UTILITY | Pendant bulb overlapping the chase column (systemic, logged above) | — |
| B1_BOILER, B1_ELECTRICAL, B1_HALL | clean beyond systemic items | — |

## F01

| room | symptom | severity |
|---|---|---|
| F01_LOBBY | Order Board renders as three overlapping teal slabs at different depths; a stray label fragment clips the wall corner by the front desk | wish |
| F01_LOBBY | "Ontological Inspection Clipboard" / "Impossible Tape Measure" nameplates float ~1 m above their table props | wish |
| F01_COMMON_B | Unframed door-sized slab leans flat against the back wall — reads as a loose door leaf | ugly |
| F01_STORAGE_C | One shelf rack is rails-only (no boards) while its twin has full planks | wish |
| F01_HALL | "OUR QUEENS" poster overhangs the wall edge into the stairwell void | wish |
| F01_ATRIUM | Handrail stub protrudes from brick at rail height, attached to nothing; pale pink blotch decal on atrium brick | wish |
| F01_OFFICE | Framed print clips diagonally through the desk side panel; teal cup mounted on a vertical board face | ugly |
| F01_RESTROOM | Dotted diagonal seam across the upper wall — geometry gap or z-fight | wish |
| F01_A_BED | Window partially buried in brick (slats/frame fragments show through wall); grass-green patch on floor at wardrobe base | ugly |
| F01_A_BATH | Tan mat/caddy floats off the tiled shower wall | wish |
| F01_A_MAIN | Family photo frame overlaps the abstract canvas on the same wall | ugly |
| F01_D_BATH | Bath mat propped vertically against the door face — will clip on open | wish |
| F01_D_MAIN | Tall stepped untextured white mass near the right wall — identify the prop | wish |
| F01_D_OFFICE | Thin dark rod floats under the desk top, attached at neither end | wish |

## F02

| room | symptom | severity |
|---|---|---|
| F02_A_MAIN | TV wedged between sofa back and window, overlapping sill/blinds, no stand | ugly |
| F02_A_BATH | Gold sconce/decal at ceiling height | wish |
| F02_B_BATH | Wooden shelf above toilet broken apart — board and dowels hanging diagonally over the mirror | ugly |
| F02_B_BATH | Pinboard collage floats on the shower glass instead of a wall | ugly |
| F02_B_KITCHEN | Door trim outlines bare brick (door panel missing) beside a live light switch | ugly |
| F02_C_MAIN | TV overlaps window blinds; blank tan canvas hangs tilted off the brick wall | ugly |
| F02_C_BED1 | Picture frame wedged between wardrobe top and ceiling | ugly |
| F02_D_MAIN | Unit 2D entirely unfurnished (main/bed/office bare, no ceiling fixtures) — confirm vacancy is intentional | wish |
| F02_D_OFFICE | Dark geometry pokes through the right wall edge; floor sliver past the baseboard in the corner | wish |
| F02_HALL | Bridge painting hangs into the stair opening, overlapping the interior brick window | ugly |
| F02_ATRIUM | Beige lamp shade floats mid-air with no cord/arm to the brass pole | ugly |

## F03

| room | symptom | severity |
|---|---|---|
| F03_A_BATH / F03_B_BATH | Toilet sits half inside the shower enclosure — glass plane cuts the bowl | ugly |
| F03_B_ALCOVE | Wardrobe faces the main room with its unfinished back panel | wish |
| F03_C_BED2 | Counter/platform top pokes through the doorway wall plane, visible both sides | ugly |
| F03_C_MAIN | Gray squiggle prop clipped to the window frame edge at mid-height | wish |
| F03_D_BED | Floor-to-lintel sliver of blue fabric texture embedded in the wall beside the closet door, visible from both sides | ugly |
| F03_D_BATH | Magenta hamper intersects the tan box behind it | wish |
| F03_D_MAIN | Denim screen/fort walls clip through the glass coffee table; angled plank protrudes through their base | ugly |

## F04

| room | symptom | severity |
|---|---|---|
| F04_D_MAIN | Giant lumpy untextured white mass, floor to near ceiling, jagged silhouette, against the right wall | ugly |
| F04_B_MAIN | Tall featureless white box standing in the room (both angles) | ugly |
| F04_A_BATH / F04_B_BATH | Toilet-paper holder mounted inside the shower enclosure | ugly |
| F04_B_VESTIBULE / F04_B_CLOSET | Brass lever handle floats off the door face at an angle with a visible gap | ugly |
| F04_C_MAIN | Maroon ovoid embedded halfway into the partition-wall edge at ~1.2 m | ugly |
| F04_C_BATH | Tall brown plank floats on the wall above the towel rail | ugly |
| F04_D_OFFICE | Wooden post descends from the ceiling above the desk and ends mid-air | ugly |
| F04_B_ALCOVE | Pitch-black vertical void strip at the wall junction left of the bed; white block intersecting the mattress edge | ugly |
| F04_ATRIUM | Resident sprite stands outside the guardrail line over the atrium opening | ugly |
| F04_A_BED | Wardrobe crowds the bed's foot, sitting on its rug, covering the far window | wish |
| F04_D_MAIN | Small teal panel clipped into the rear door frame top | wish |
| F04_B_KITCHEN | Fridge silhouette has jagged alpha-cutout outline (also from B_MAIN) | wish |

## F05

| room | symptom | severity |
|---|---|---|
| F05_A_MAIN | Appliance text decal renders mirrored; black oval on rear wall is a featureless blob | ugly |
| F05_B_MAIN | Abstract painting rotated off its partition wall, floating in front of wardrobe edge; untextured teal box on the floor | ugly |
| F05_B_ALCOVE | Rod/bracket from the doorway header clips the wardrobe top | wish |
| F05_B_KITCHEN | Trim-outlined bricked-over doorway | wish |
| F05_C_MAIN | Drafting table leans at an unstable angle, legs off the floor, sinking into the wall | wish |
| F05_C_MAIN | Stray white streaks across the couch back cushions (seam/z-fight) | wish |
| F05_D_BED | Black headboard overlaps half the window frame | ugly |
| F05_D_MAIN | Dark untextured slab across a ceiling patch; lone concrete block mid-floor of an empty room | ugly |
| F05_D_OFFICE | Dark speckled object sunk into the right wall at mid-height | wish |
| F05_WSTOR | Full-width pitch-black void where the far wall should render | ugly |
| F05_HALL | Artwork clipped behind/into the elevator door surround at ceiling height | wish |
| F05_ATRIUM | Stair handrail overshoots its run; end cap penetrates the newel post | wish |

## F06

| room | symptom | severity |
|---|---|---|
| F06_A_MAIN | Floor-type scuff decals projected onto the CEILING near the wall corner (also C_MAIN) — atmospheric decal pass landing on the wrong face; coordinate with parallel session | ugly |
| F06_A_MAIN | Glowing art/TV panel overlaps window blinds | ugly |
| F06_C_BATH | Vertical brown strip above the towel rail — looks like a mis-rotated duplicate rail | ugly |
| F06_C_MAIN | "PROVENANCE UNKNOWN" sign overlaps the abstract painting; portrait painting sits in front of the fridge/cabinet face, clipping the counter | ugly |
| F06_D_BED | Bed and dressers are featureless pure-white boxes; both windows brick-filled; smoke detector tilted off-axis | ugly |
| F06_D_BATH | Orange bench/tabletop clips ~0.6 m of geometry through the closed bathroom door | ugly |
| F06_WSTOR | Floor is two mismatched slabs with a visible ledge drop | ugly |
| F06_HALL | Painting mounted flush against ceiling trim, clipped by the soffit | wish |
| F06_ATRIUM | Chandelier arm curves through the stair balusters; glowing blob on brick with no fixture mesh; hard black rectangle high on the atrium wall between rail flights | ugly |

## ROOF

| room | symptom | severity |
|---|---|---|
| ROOF | Freestanding sign board blank on both faces (white front, untextured gray back) — story decal/text missing | ugly |
| ROOF | Billboard/screen and HVAC-scale boxes render 100%-black on all faces while adjacent props at the same distance catch light — missing/unlit materials | ugly |
| ROOF | Verified clean: parapet/planter coverage continuous, no walk-off gaps; posts/plinths all grounded | — |

## Triage (proposed, not yet actioned)

**Fix-first (blockers):** the blinds/window offset (one systemic fix),
WSTOR white slab+cube (one prop, five floors). Both look like single
data-side fixes in gen_layout's furnishing pass.

**Coordinate with parallel session before touching:** white decal quads
(hall/corridor/roof/B1), ceiling scuff decals (F06), socket prop labels,
elevator WalkTest failures — all in their working set.

**Batchable per-floor trivia:** towel bars, sticky notes, faucet floats,
pendant-in-duct — each is one asm/socket offset in gen_layout.

**Re-shoot after fixes:** D_MAIN and C_BED2 cameras (nested-rect/furniture
artifacts), UTILITY/WSTOR _b corners.
