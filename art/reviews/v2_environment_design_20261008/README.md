# V2 environment design dossier (2026-10-08)

Evidence class: **INERT**

Review-and-design packet for every discrete area of the Orison V2, the street
and the attached playable areas, captured from build `fdf01a36` on main and
redesigned room by room. It is addressed to the owner and to the implementing
agents (ChatGPT/Codex). It changes no code, no data and no ledger status.

## Deliverables

| File | What it is |
|---|---|
| `V2_environment_design_dossier.pdf` | The dossier: front matter, level plans with capture stations, the complete area checklist, then one section per area (identity, captioned evidence, observed versus interpretation, room narrative, proposed backstory, numbered changes, implementation and acceptance). |
| `dossier.html` | Offline companion with the same content and full-size tiles. |
| `dossier.json` | The complete machine-readable document (`orison.environment-design-dossier.v1`). |
| `change_register.csv` / `.xlsx` / `.json` | The editable change register: one row per numbered change with stable ids (`<SPACE_ID>-nnn`, `CITY_*-nnn`, `BW-nnn`), priority, action, objects, placement, dimensions, construction, materials, wear, lighting, sound, purpose, sources, dependencies, preserve, acceptance, and empty `status` / `owner_notes` columns. |
| `coverage_checklist.csv` | Every area with its coverage class (inspected, partial, inaccessible_teleported, unreviewed), view count and change count. |
| `census.json` | Per-space inventory from the blockout anchors and installed data (`sources/build_census.py`). |
| `review_notes.json` | Image-review notes merged from the contact-sheet reviews (`sources/merge_reviews.py`). |
| `plans/plan_*.png` | Per-level plans drawn from the blockout with the capture stations. |
| `images/` | 640 px JPEG review tiles, one per captioned view. |
| `evidence/` | Sweep records (`sweep_run1.json`, `sweep_run2.json`), runtime node census, run receipts and logs, the copied-local-asset manifest and the full-resolution capture inventory (SHA-256 of 1,202 PNGs retained locally at `C:/ov/envdossier_out/<run>/shots`). |
| `sources/` | The capture scene (`orison_v2_environment_dossier_sweep.gd` + `.tscn`), the stage script, the census, plan, sheet and merge builders. |
| `content/` | The authored content modules the builder reads (`front_matter.py`, `_common.py`, `areas_*.py`). |
| `content/status.py` | Implementation status per change id (`proposed`, `implemented`, `verified`, `deferred`, `rejected`) with the owner note and evidence pointer; the builder overlays it on the register (`python build_dossier.py --register-only` rewrites the register without the PDF). |
| `implementation/<slice>/` | Verification evidence for implemented changes: captures (1280 px JPEG), the fabrication `batch.json`, run receipts, sweep records and a SHA-256 manifest. INERT, never runtime proof. |

Rebuild with `python build_dossier.py` (ReportLab, Pillow, pypdf; openpyxl for
the XLSX). `pdf_validation.json` records the page count and the file hash.

## How the evidence was made

The capture scene extends `OrisonV2CitySweep` and was installed temporarily in
`game/tests/` of a detached capture worktree at the same commit
(`C:/ov/envdossier`), then removed. Per semantic space it records an overview,
a reverse view, a threshold view from outside the principal door (the leaf is
opened by the ordinary door interaction when not locked and closed again) and
up to three detail views toward authored anchors, runtime props, windows or
doors; with `DOSSIER_CITY=1` it adds the city sweep's shop, bar, floor-survey
and street stations plus bodega, alley, facade and subway views. Both long
runs went through the lane broker and wrote `suite_run` receipts. Campaign time
was frozen at 1928-11-10 20:00; production fixtures as authored; player lamp
on; carried set hidden. Every frame is a teleported inspection station, not a
played route; nothing here is a runtime contract or an acceptance.

The capture worktree needed the gitignored machine-local runtime textures
copied from the canonical checkout at the same commit; their hashes are in
`evidence/copied_local_assets.json`.

## Implementation

Changes are implemented in slices on this branch. Each slice edits the
authoring sources (never generated glTF or runtime JSON by hand), re-projects
(`tools/build_v2_completion_interiors.py` and kin), rebuilds touched Blender
families with `art/blender/scripts/run_fabrication_batch.py`, then verifies in
a short-path worktree: the fabrication batch for the touched modules, the
route suites that cross the changed rooms (pointer suites need `-Windowed`),
and this packet's sweep scene over the changed spaces. The register's
`status` column and `implementation/<slice>/` record the outcome.

Slices landed so far (evidence folders in parentheses):

1. Fridge count, living-room pendants, 4D closet lock (`slice1`, `slice1b`,
   `baths` for the water-closet measurements).
2. Second beds out, radios in six homes, moves and sign fixes (`slice2`,
   `slice2b`, `slice2c`).
3. Public-hall flush domes on landlord switches, enamel unit numerals on the
   entry leaves, 5C stance moves (`slice3b`, `numerals`, `numerals2`).
4. Period furniture forms: pedestal round tables, rolled sofa arms, oak shelf
   posts (`slice34`).
5. Bath tile on one face only (a far-face skin on interior wet walls) and
   room leaves a step lower (`slice5`, `slice5b`; `skinbase` is the pre-skin
   comparison, `floorbase` the pre-skin floor-surface baseline).
6. Resident furniture for the six completion homes from existing variants,
   signal outlets beside every switch, the ducts measured (`slice6`,
   `slice6d`, `routes6b`, `ducts`; `bisect_*` hold the route-test receipts
   at main, slice 1 and slice 5).
7. Kitchen sets: four new surface-stock forms and fifty-two records on the
   drainboards and prep cabinets of all eighteen kitchens (`slice7`).
8. Hall stands in the eighteen apartment vestibules, a new domestic-objects
   form (`slice8`, `slice8b` for the corrected D-plan placement).
9. Paper, book, tray, frame, clock, can, parcel and flask stock on the
   residents' tables, nightstands, coffee tables, hall stands, an icebox
   top and a kitchen floor; the 1D, 2C and 4C prep cabinets mounted as
   completion copies (`slice9`; `slice9e`, `slice9f` and `slice9g` at the
   final tree, where the household save owner adopts the copies and its
   suite counts the hall lights of slice 3, stale since then; `slice9h`
   is the upper-kitchen baseline at slice 8).
10. Chain door guards on the apartment face of the eighteen entry leaves and
    the Armchair seating form for 5B's listening chair and 1A's reading
    chair (`slice10`; `slice10b` re-runs the fabrication batch with a valid
    capture actor; `slice10c` is the door-hinge baseline at slice 9).
11. 5B's reel-deck table, second deck and tape shelves with reel-box rows,
    3B's outgoing shelf with parcels, 6B's desk arrangement with a wire
    wastebasket, 2A's unlabelled carton (`slice11b`; `slice11` is the first
    run, red on two placements fixed before the squash).
12. Wall pieces: 4B's case wall and 5A's plan wall (pinboard variants), a
    wall-art form for 5C's diptych and the framed pairs in 4A and 1A
    (`slice12`; `slice12b` re-runs the apartment batch after its roster
    was held to the original category set).
13. Cloth: a garment-rail form (2B's repair rail, 4B's closet rail) and a
    hung-blanket form (2C's second bedroom, 3D's study), with five tinted
    cloth keys on the catalogue linen (`slice13`).
14. One use object in each of the eighteen private halls: a wicker hamper,
    a boot tray with galoshes or a crate (`slice14b`, `slice14c` after two
    narrow-hall objects moved out of the door route; `slice14base` is the
    upper-furniture baseline at slice 13).
15. Wall art in the residents' rooms: a photograph style for the wall-art
    form, 2C's album pair, 3D's three images, 3A's diagram and portrait,
    5B's two works and 2A's caption wall (`slice15`).
16. Bedside and tabletop stock: eight small forms on the nightstands and
    5C's table (`slice16`, `slice16c` with close-ups; the surface-stock
    suite now takes ORISON_STOCK_CAPTURE_IDS).
17. 2B's bedside and client chair, 3A's compost pail, 4D's luggage (a
    suitcase form) (`slice17b`; `slice17` stood the chair in the door route).
18. Studio forms: 2B's treadle sewing machine, 3B's radio teardown, 5C's
    easel and failed canvases (`slice18`).
19. 3A's propagation shelves and seed jars, covered objects on 6C's
    archive shelves and 4C's museum shelf, 6C's card cabinet (`slice19`).
20. 2A's labelled box files, 6A's backdrop rail and print line (`slice20`).
21. The lobby noticeboard and 1928 photograph, the common room's armchair
    (`slice21`, `slice21b`, `slice21c`; `slice21base` holds the public-room
    suites at slice 20).
22. A drip pan under each of the fourteen iceboxes (`slice22`; `slice22b`
    narrows slice 20's backdrop clear of the tripod stance).
23. Basement: one household object in each of sixteen storage bays, five
    laundry baskets (`slice23`, `slice23b`, `slice23c`; `slice23base`,
    `slice23mina` and `slice23mina_base` hold the basement suites).
24. 2A's out-tray, 5A's torch, 5B's battery case, 4B's old cap, 3D's card
    index (`slice24`, `slice24c`).
25. 2C's rig deck and cable hook strip, 4D's print, 6A's archive crates
    (`slice25`).
26. 2C's and 4C's bookcases and 4C's colour board (`slice26`, `slice26b`).
27. 3A's memorial pot, 6A's plate box, loupe and print rack, 6C's never-opened
    ledger (`slice27b`; its `wake_*` receipts hold the unchanged wake suite).
28. The ground-floor service rooms: parcels, the parcel book, a scale and a stamp
    pad on the parcel racks; the operator's chair, headset and cord coil at the
    house board; the watchman's chair, coat and folded cot (`slice28b`).
29. The basement plant rooms: the boiler room's shovel, clinker rake, ash can and
    oil can; the electrical room's signal frame and fuse-panel conduit (`slice29`).
30. 5A's corrected floor plan on the icebox door and 2C's wardrobe as the session
    archive, two family variants (`slice30b`).
31. Bedsides in 1D and 3D, the scarf on 3D's bedpost, garments on bedroom chairs
    in 4C and 5C, 5C's face-down canvas, 1A's medication organizer (`slice31b`).
32. Service evidence: the laundry's oil can, belt and stepladder, the vestibule's
    umbrella stand, the lobby spittoon, the staff restroom's towel, mop and soap
    (`slice32`).
33. 6A's row of prints and the plant print on its bookcase, the roof bulkhead's
    washing line, watering can and trug, 2A's sofa cushions (`slice33`).
34. 1A's trunk of lesson plans and tea tins, the sweep's sack and rods in the
    service bulkhead, and a keep audit for nine keep items (`slice34`).
35. 5C's pigment store and 6C's packing store, 4C's two garment sets, 2A's full
    pinboard (`slice35b`; open-leaf renders under images).
36. Owner enamel finishes on six gas ranges (pristine, greasy, workshop, paint-flecked
    with a brush tin); the stove test walks each range's own assembly (`slice36`).
37. 4B's bare equipment shelf, 6B's cup rings, 3A's repotting, 5A's code books, 4B's
    boots and slip, and stronger grease and workshop wear on the ranges (`slice37`).
38. 2B's dress form, 2C's recorder and mug; 4A's taped form and 6A's light box are built
    here and placed again in slices 41 and 40 (`slice38`).
39. 2B's standing bolts and cutting kit, 3B's fastener cabinet, 3A's pruning station,
    and four rows closed against captures (`slice39`).
40. 5A's japanned lamp, glazed model case and T-square, 4D's open case and empty
    hangers, and an inspection sweep of seven rooms (`slice40`).
41. 4A's hall file, the toaster form moved beside the lever, and the basement shop's
    bulbs, crate and charging case (`slice41`).
42. 1D's house bell and quiet sign, 4C's route map, 5B's hearing aid, the rebuilt cone
    speaker, and a clear and a storm city sweep (`slice42`).
43. 6A's oak desk wall with the headsets laid flat, 3B's grey iron bench cupboard, and
    the service leaf's frame, mid rail and kick plates (`slice43`).
44. 2B's pot on the lit ring, 2C's tape boxes, 4A's chairs tucked, Mina's jacket and
    cloche, three household bedding states, bath tile on every sink wall, and two
    placement fixes the objects context inspector found (`slice44`).
47. A resident bath set on an opal glass shelf over every one of the 18 basins, and
    Wren's overflowed umbrella tray (`slice47`).
48. The building's paper trail: a framed notice on every core level, its words a
    Label3D the lamp reads (`slice48`).
49. Door thresholds: a household's mat at every apartment door (squared coir, worn
    coir, a rag rug, ribbed rubber, soil or paint on coir, the sealed door's dust mat),
    the paper on two, milk and a parcel on the wide core floor (`slice49`).
50. Stair wear and the one piece of its own on every core landing: every honed tread
    dished on the walking line, a framed canvas, photograph or wordless certificate per
    landing, and the prospectus roof-garden plate on F06 (`slice50`).
51. The sealed 3C door's dust mat and notice, the soot ghost above 5D's replaced door,
    and Cal's aerial lead along the F05 west hall on porcelain insulators (`slice51`).
52. Positional wear as soft projected decals: a grout-and-water ring at every bath's
    receptor and the mop-shadow corner; the walking line, door scuffs, mop corner and
    trolley rub in the thirteen upper halls, faint at production light (`slice52`,
    reruns in `slice52b`).
53. The news booth's stock (tied bundles, magazine fans, cigar boxes with a lid up,
    tobacco tins, papers under wordless mastheads) and the proprietor's worn rubber mat
    (evidence with slice 54 in `slice54b`).
54. The hardware shop's paint tins in three sizes, dented, run and banded without words,
    and one drawer of the wall standing open (`slice54b`).
55. The photo supply shop: film stock in three sizes under wordless banded lids, two
    cameras and a lens in the case, and one print on the rail a building (evidence with
    slice 57 in `slice57b`).
56. The Keys Cut shop: blanks varied by row with one row empty, a lock case open, the
    safe's blank gold-leaf cartouche, the register open with a pencil on a string
    (evidence with slice 57 in `slice57b`).
57. The Radio Service shop: valves with getters in tube racks, the 1610 set's dial at the
    top of the band and its cone speaker, a meter and an iron on the bench, the wire on
    its reel (`slice57b`).
58. Resident objects: 1A's grab rail, 1D's towel over the bath window, Sacha's light
    table, 4D's lost-property shelves (evidence with slice 67 in `slice67`).
59. The basement's working evidence: the laundry rota and painted-over outlet, the
    cleated wiring and cartridge shelf, a dropped cartridge, the coal shovel.
60. Coal dust down the boiler approach and on the lowest service treads, the door
    sweep, the chute's dust fan and Omar's chalked log.
61. A water line under every shower curtain's hem and 5D's soot ghost as a soft
    projected fan.
62. The pawnbroker's ring in an envelope in the window and the safe's blank name
    panel.
63. The reading room's bookcases in varied runs with flat piles and a shelf of bound
    magazines.
64. The funeral register open at one signature, chairs off their marks, and the
    luncheonette's third stool worn to the cord.
65. Feathered pavement marks and wordless election broadsides on the street-end
    hoardings.
66. The last thresholds, 4B's worn alcove runner, Iris's paint rag on 5C's radiator
    and the padlock hasp on 6D's storage door.
67. The hall wear strengthened, the news mat and the drawer suite fixed, slice 58's
    light box renamed, and verification of slices 58-67 (`slice67`).
68. The house tank in staves, the mail bank's overfull boxes and ajar doors, and
    1A's corrected notice (evidence with slice 75 in `slice68`).
69. The hardware counter's bell and night-service card and a box of capsules on
    the rack; shop families gain Label3D labels.
70. The luncheonette's menu board in white push-in letters.
71. The luncheonette counter's sugar shakers and jar of pickled eggs.
72. The basement toolboard a shadow board with one tool out.
73. The basement nook's reader: a book tented on the cushion.
74. The cobbler's floor in a warm leather dust and the dark pairs brown leather.
75. The laundry's ticket halves in four ages and the oldest parcel row, and
    verification of slices 68-75 (`slice68`).
76. The coal chute seated on a boarded bunker, and the coal route through the
    vestibule leaves (evidence with slice 80 in `slice80`).

Verification runs are made at WIP commits that are later squashed; the game
and art paths of each squashed commit are byte-identical to the WIP tree the
receipts name, which `git diff --stat <wip> <commit> -- game art` confirms.

## Reading the register

Priority P1 = reads wrong from the doorway or the resident is not legible;
P2 = strengthens story, period truth or the Shenmue test; P3 = polish.
Action = add / move / refine / remove / keep. `BW-nnn` changes are
building-wide families cited by many rooms; fix the family, not the room.
Proposed backstory is labelled on every page and collected in the front
matter; none of it is canon until ruled.
