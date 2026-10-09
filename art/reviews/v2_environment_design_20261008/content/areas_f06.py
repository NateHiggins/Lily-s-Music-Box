"""F06: circulation, 6A Sacha Reed, 6B Jonah Price, 6C Mae Kessler, 6D landlord storage."""
from _common import *

GC = "F06 / circulation"
G6A = "F06 / 6A Sacha Reed"
G6B = "F06 / 6B Jonah Price"
G6C = "F06 / 6C Mae Kessler (case)"
G6D = "F06 / 6D landlord storage"

INTRO_6A = ("<b>Sacha Reed, 6A.</b> Photographer-documentarian (they/them), camera and adapter tangle, no camera body visible on the person; the recording displaced the experience; experience can "
            "precede proof (Bible IV). Canon: the living room treated as a photo workspace with a backdrop rail, a charging bench and contact sheets, cases stacked at the door, no sofa and no "
            "television, eats standing at a counter used as a light table, nocturnal, one practical folding chair in a room built for an audience of lenses (contradiction), the contact sheet of the "
            "motif as hero object, cleanliness 0.55. In this world photography is dear and recording is cheap (Bible VIII.4), so every print here is money. Sacha is Auggie Reed's line and "
            "photographs Malcolm's plants on Sundays (web II.8), Iris's canvases, and the singers at the Harukiya on Fridays; night photography of the building Mon/Wed and the roof Tue/Thu. "
            "<i>Proposed backstory:</i> the one print of a plant in the flat is Malcolm's geranium. <b>Build state:</b> the main room has the tripod, two softboxes, a gear crate, two coils, a round table, "
            "radio and repaired bookshelf; the study has the desk wall with headphones, cans, papers and a mug (the punchlist's monitor overlap row belongs here). No backdrop rail, no light table, no chair.")

INTRO_6B = ("<b>Jonah Price, 6B.</b> Insomniac writer, navy dressing gown as the outfit, an annotated notebook in the pocket, a week unshaven; endings avoided until they bite; endings do not "
            "erase continuation (Bible IV; VI.6 proposes the spine is can't finish). Canon: a writing sightline from the bed, a task lamp, a draft archive, bookstore receipts, cold-drink rings on "
            "every surface, the wastebasket of rejected endings (hero object), the bed facing the desk so the last thing he sees is the unfinished page (contradiction), cleanliness 0.42, sleeps at "
            "the desk. He is the convicted man's son and cannot finish the family's story because finishing means writing the verdict (web II.1); Cal's reel holds the chapter; Sunday noon he brings "
            "two coffees to Noel's door; Saturday nights he holds the Harukiya between songs. <i>Proposed backstory:</i> the rejected endings are all the same chapter. <b>Build state:</b> the main room "
            "has the draft, references, cold coffee, radio and a plain bookshelf; the alcove has bed, nightstand, wardrobe. The desk exists only as a dining table; the sightline is not built.")

INTRO_6C = ("<b>Mae Kessler, 6C.</b> Antiques appraiser and the last of the Kessler Estate that owns the building (web I: 1893), bottle-green coat re-lined twice, silver pageboy, white cotton "
            "gloves worn as manners; certainty is not memory; contradiction is survivable (Bible IV.1, a case: antiques reporting incompatible provenance). Canon: white gloves by the door, a "
            "catalogue table, a packing station, gloved handling, a provenance cabinet composition (objects classified on walls, people kept close on furniture), two catalogue cards for one object in "
            "her hand (contradiction), the locked provenance drawer (hero object), nothing after 1935 which here means nothing after 1927, careful and spare, cleanliness 0.9, the second bedroom "
            "converted to a provenance archive, the monitor-top she has never replaced (one of the four). The 1912 Vantry prospectus is on her shelf and is the most disquieting object in the "
            "building (Bible VIII.3, VIII.5.h); she takes tea with Nadia on Thursdays and neither says the thing (web II.2). <i>Proposed backstory:</i> the Kessler Estate ledger sits beside the "
            "prospectus and is never opened. <b>Build state:</b> the main room has a sofa, coffee table, round table, old radio, oddments, catalogues, a sectional bookshelf and a radio; a second made "
            "bed in BED2; two wardrobes in the studio closet. The archive does not exist.")

AREAS = [
    core("F06_PUBLIC_CORE", GC, "F06 public core: the top of the stair", "Stair and lift at the top occupied floor; 6C's entry (F06_DOOR_06) opens here; the roof stair continues above", "Mae's door opens on the core; the stair continues up to the roof bulkhead, so this core carries roof traffic (Malcolm at dawn, Juno and Sacha at 02:00). Its unique piece: the Vantry prospectus's roof-garden plate, framed, the drawing with people in it.", level="F06",
         extra_changes=[change("F06_PUBLIC_CORE-003", "P2", "add", "The prospectus roof-garden plate", objects=["new: framed plate (CharacterMemoryArt) on the half-landing wall below the roof flight"], placement="At 1.5 m on the landing wall", construction="WallArtLaw; a sepia drawing rectangle with figures as silhouettes", purpose="Bible VIII.3: the roof garden is drawn with people in it because the drawing was a promise", acceptance="Detail view from the landing")]),
    core("F06_SERVICE_CORE", GC, "F06 service core", "Service lift landing and stair; continues to the service roof bulkhead", "The service stair's last flight before the roof; a coal-dust tread line from the roof chimney work.", level="F06"),
    service_hall("F06_SERVICE_HALL", GC, "F06 service hall (north)", "The 2.4 m maintenance route beside the service core", "The top service hall: the ventilation branch drops are closest to the roof plant here (slab ports); their hangers must read seated.", level="F06"),
    public_hall("F06_EAST_HALL", GC, "F06 east hall: toward the landlord's door", "From the core east to the service crossing and 6D", "nobody; the landlord's agent",
                "The quietest public hall; the only one where the mop reaches every corner because nobody walks it. A folded ladder against the wall (the landlord's).", level="F06"),
    service_hall("F06_SERVICE_CROSSING", GC, "F06 service crossing: 6D's door", "The crossing with 6D's locked door (F06_DOOR_05)", "Landlord storage behind a locked leaf: a brass plate (no lettering), a padlock hasp added over the mortise lock (Accord 13: two eras of lock), dust.", level="F06"),
    service_hall("F06_SERVICE_HALL_SOUTH", GC, "F06 service hall (south)", "Short south run", "Dead end; cage bulb; a roof-tank drip stain on the ceiling plaster (the tank is above).", level="F06"),
    public_hall("F06_WEST_HALL", GC, "F06 west hall: Sacha and Jonah", "The 6.1 m hall with 6A (F06_DOOR_02) and 6B (F06_DOOR_03) entries", "Sacha at 02:00, Jonah at every hour",
                "Two night people's doors: a fibre case left outside Sacha's door at 02:00 with a strap over it; bookstore receipts blown under Jonah's door; a cold mug on the dado shelf.", level="F06"),

    # ------------------------------------------------------------------ 6A
    vestibule("F06_A_VESTIBULE", "6A", G6A, "cases_stacked", "2.7 x 3.25 m off the west hall: three fibre cases stacked by size, a tripod bag, a soft cap, a strap tangle hung on one hook. The player infers equipment before a person.", group_intro=INTRO_6A),
    area("F06_A_MAIN", G6A, "ORISON", "Sacha's photo workspace", "7.35 x 5.75 m, one window, openings to the vestibule and private hall, door to the bedroom", "Sacha Reed (20:00: backups, three copies, two locations)",
         ("The tripod, two softboxes, gear crate, two coils, a round table and chairs, the radio and a repaired bookshelf are installed. The profile converts the living room into a photo workspace: "
          "no sofa, no television; a backdrop rail across the end wall with a roll of paper, the charging bench with battery cases and flash tins, contact sheets pegged on a string, one practical "
          "folding chair, and an actual rest/eating perch so the room stays habitable (lived-in brief). The decor profile asks for an editorial sequence, camera lowered before the command to look. "
          "The player infers a person who records everything and keeps almost no picture of themselves; and that photography here is an occasion (every print cost money)."),
         [change("F06_A_MAIN-001", "P1", "add", "Backdrop rail, charging bench and the folding chair", objects=["new: 6A_backdrop_rail (wall rail with a paper roll, cloth family), 6A_charging_bench (work_tables) with battery cases and flash tins (desktop_stock), 6A_folding_chair (new small seating variant)"],
                 placement="Rail across the end wall opposite the vestibule at 2.2 m with paper hanging to the floor; bench against the window pier; the single chair at the bench", construction="Rail as a static assembly; bench from work_tables; chair as one new seating variant; tins RESIST-REFUSE (flash powder) per the photo shop's safety rule",
                 materials="iron rail, grey seamless paper, pine bench, wet-cell cases in wood, tin", signal=SIGNAL_YES, wear="paper scuffed at the floor, a burn on the bench", purpose="Life profile room conversion photo_workspace; surface sets backdrop_rail, charging_bench; contradiction: one practical folding chair", sources=["game/data/apartment_life_profiles.json", "design/CLAUDE_APARTMENT_LIVED_IN_PASS.md"],
                 preserve="Tripod, softboxes, crate, coils (RESIST-REFUSE owners), route to the bedroom door", acceptance="Overview reads a studio with one chair"),
          change("F06_A_MAIN-002", "P1", "add", "Contact sheets on a string and the motif sheet", objects=["new: 6A_print_line (string with pegged contact-sheet rectangles) and the hero contact_sheet_of_the_motif pinned above the bench"], placement="String from the rail post to the window pier at 1.9 m; hero sheet on the pier at 1.5 m",
                 construction="Papers-family rectangles with a grid of small frames (no lettering); hero sheet INSPECT", purpose="Hero object contact_sheet_of_the_motif; story panel contact sheets and unshown photographs", acceptance="Detail view at the bench"),
          change("F06_A_MAIN-003", "P2", "add", "Editorial sequence on the wall", objects=["new: three small prints in a row (CharacterMemoryArt)"], placement="On the wall beside the private-hall opening, away from the door swing and the bookshelf (decor profile)", purpose="Decor profile editorial_sequence", acceptance="Detail view"),
          change("F06_A_MAIN-004", "P2", "add", "Malcolm's plant, the one picture of a plant", objects=["new: one small print on the bookshelf (desktop_stock frame)"], purpose="Web II.8; proposed backstory", acceptance="Detail view of the shelf")],
         canon=[C_BIBLE_IV, C_LIFE, C_DECOR, C_STORY, C_WEB, C_BIBLE_VIII4], proposed_backstory=["The one print of a plant in the flat is Malcolm's geranium."], implementation=apt_impl()),
    kitchen("F06_A_KITCHEN", "6A", G6A, "eats_standing", "The counter is a contact-sheet light table (a frosted glass over the prep cabinet with a lamp under it), prints pegged on a string over the sink, a tin of batteries, no chair.",
            extra_changes=[change("F06_A_KITCHEN-003", "P2", "add", "Light table on the prep cabinet", objects=["new: 6A_light_table (desktop_stock frosted glass plate on a frame) on 6A_prep_cabinet with a small lamp beneath (task lamp family, no new light slot unless budget allows; else an unlit visual)"], purpose="Kitchen set eats_standing; Appliance Bible III", preserve="Prep cabinet slide", acceptance="Detail view")]),
    private_hall("F06_A_PRIVATE_HALL", "6A", G6A, "a 5.0 m hall with a string of drying prints across it at 1.9 m (the player ducks nothing: above eye) and a case on the floor against the wall."),
    bath("F06_A_BATH", "6A", G6A, "single_adult", "A window bath that doubles as a darkroom rinse: a developing tray in the receptor, a red bulb jar on a nail (unlit), a strap on the hook."),
    area("F06_A_BED", G6A, "ORISON", "Sacha's bedroom", "4.45 x 6.0 m, two windows, door from the main room", "Sacha Reed (nocturnal)",
         ("Bed, nightstand, wardrobe. The strap still round the neck out of habit (wardrobe bible) becomes a strap on the bedpost; a camera case open on the nightstand, the camera absent; "
          "the slate-green duck coat with too many pockets on the wardrobe leaf. No picture of themselves anywhere."),
         [change("F06_A_BED-001", "P2", "add", "Strap on the bedpost, empty case on the nightstand", objects=["desktop_stock on 6A_bed0_ns; cloth strap on 6A_bed0"], purpose="Wardrobe bible: the tangle without the camera is the character", acceptance="Detail view")],
         canon=[C_WARD], implementation=apt_impl()),
    area("F06_A_STUDY", G6A, "ORISON", "Sacha's study: the desk wall", "2.9 x 3.0 m, one window, door from the kitchen", "Sacha Reed",
         ("The desk wall, chair, headphones, cans, papers and mug are installed; the punchlist records three monitor props cutting into the desk wall (a prop-mesh issue). In this world the monitors are "
          "wrong: Sacha works with prints, loupes and a long-exposure plate. Replace the monitor props with a drying rack, a loupe, a plate box and the archive of three copies in two locations "
          "(one here, one in the crate)."),
         [change("F06_A_STUDY-001", "P1", "refine", "Monitors out, plates and loupe in", objects=["F06_A monitor props on 6A_deskwall (if still instantiated)", "new: 6A_plate_box, 6A_loupe, 6A_print_rack (desktop_stock)"], construction="Remove the MonitorProp instances for 6A or retarget them (matrix row: CRT monitor props are case/conductor-driven; 6A has no case); seat desktop_stock on the desk wall",
                 purpose="Punchlist overlap row; Bible VIII.4: no screens in a flat without a signal reason; the F14 ruling keeps screens out of 6A", sources=["design/walkthrough_punchlist.md", "TASKS.md F14"], preserve="Desk wall assembly", acceptance="Detail view shows no monitor"),
          change("F06_A_STUDY-002", "P2", "add", "Three copies, two locations", objects=["new: 6A_archive_boxes (crate family x3) under the desk wall, one open"], purpose="Schedule 20:00: backups, the liturgy", acceptance="Reverse view")],
         canon=[C_SCHED, C_BIBLE_VIII4], implementation=apt_impl()),

    # ------------------------------------------------------------------ 6B
    vestibule("F06_B_VESTIBULE", "6B", G6B, "bookstore_receipts", "2.8 x 2.5 m with the bath door off it: the navy overcoat on a hook over nothing (he goes out in it over pyjama trousers), bookstore receipts pinned in a fan, unlaced shoes kicked under the shelf.", group_intro=INTRO_6B),
    area("F06_B_MAIN", G6B, "ORISON", "Jonah's writing room: the sightline", "6.35 x 5.75 m, one window, openings to the vestibule and the private hall", "Jonah Price (20:00: televised verdicts, in a world with no television; the radio's crime serial)",
         ("The draft, references, cold coffee, the dining table and chairs, the radio and the plain bookshelf are installed. The decor profile is writer's pauses: words, missing words and one intimate "
          "tabletop watercolour; do not fill every silence. The room should turn the dining table into the desk with the task lamp, the draft archive on the shelf in boxes with dates, the "
          "wastebasket of rejected endings (hero object) beside it overflowing with crushed sheets, cold-drink rings on every horizontal surface, and the sightline: the alcove door open so the "
          "bed sees the desk. The player infers a man who starts books and cannot write the verdict."),
         [change("F06_B_MAIN-001", "P1", "add", "The desk, lamp and the wastebasket of endings", objects=["6B_din_t as the desk; new: 6B_lamp (task lamp variant), 6B_wastebasket (desktop_stock wire basket overflowing with crushed paper), 6B_draft_boxes (crate family x3) on F06_6B_BOOKSHELF_01"],
                 placement="Table square to the alcove door opening so the bed sees it; lamp at its left; basket on the floor at its right; boxes on the shelf", construction="Task lamp from the five variants (a new sixth variant is not needed; use office_green) with a G14 cord; desktop_stock basket with paper", materials="brass lamp, wire basket, foolscap",
                 wear="ring stains on the table in overlapping circles; ink on the table edge", purpose="Hero object wastebasket_of_rejected_endings; surface sets writing_sightline, draft_archive; contradiction: the bed faces the desk", sources=["game/data/apartment_life_profiles.json", "art/blender/task_lamps.md"], acceptance="Overview from the alcove door shows the lit desk"),
          change("F06_B_MAIN-002", "P2", "add", "One tabletop watercolour", objects=["new: 6B_watercolour (desktop_stock standing frame)"], placement="On the wireless table", purpose="Decor profile writer's pauses", acceptance="Detail view"),
          change("F06_B_MAIN-003", "P3", "add", "Rings everywhere", objects=["ring decals on 6B_din_t, 6B_wireless_table, the bookshelf top"], purpose="Kitchen set cold_drinks_and_rings; Accord 12", acceptance="Detail views")],
         canon=[C_BIBLE_IV, C_LIFE, C_DECOR, C_WEB, "Bible VI.6 (proposed spine: can't finish)"], proposed_backstory=["The rejected endings are all the same chapter."], implementation=apt_impl()),
    kitchen("F06_B_KITCHEN", "6B", G6B, "cold_drinks_and_rings", "Three cold coffees, a wastebasket by the icebox full of paper, a bread knife in the butter; the greasy enamel recipe on this range.",
            extra_changes=[change("F06_B_KITCHEN-003", "P2", "refine", "Greasy enamel on the range", objects=["F06_6B_STOVE_01 with the enamel_greasy recipe"], purpose="Appliance Bible IV", acceptance="Detail view")]),
    private_hall("F06_B_PRIVATE_HALL", "6B", G6B, "a 1.9 m hall between alcove and kitchen; the alcove door is kept open (the sightline) and propped with a book."),
    area("F06_B_ALCOVE", G6B, "ORISON", "Jonah's sleeping alcove: the bed faces the desk", "4.45 x 5.3 m, two windows, door from the private hall", "Jonah Price",
         ("Bed, nightstand, wardrobe. The bed should be turned so its foot faces the door and, through it, the desk; the notebook on the nightstand with a pencil in the gutter; the dressing gown on "
          "the bed; the wardrobe barely used (the gown is the outfit)."),
         [change("F06_B_ALCOVE-001", "P1", "move", "Turn the bed to face the desk", objects=["6B_abed", "6B_abed_ns"], placement="Bed rotated so the foot faces the private-hall door; nightstand on the window side", purpose="Contradiction: the bed faces the desk so the last thing he sees is the unfinished page", sources=["game/data/apartment_life_profiles.json"], preserve="Bedside clearance and the route", acceptance="Overview from the door shows the bed foot-on")],
         canon=[C_LIFE, C_WARD], implementation=apt_impl()),
    bath("F06_B_BATH", "6B", G6B, "single_adult", "Off the vestibule: a week's beard in the basin, ink on the towel."),

    # ------------------------------------------------------------------ 6C
    vestibule("F06_C_VESTIBULE", "6C", G6C, "white_gloves_by_the_door", "2.7 x 2.5 m off the public core: white cotton gloves on a tray, a buttonhook, a mourning-brooch box, the bottle-green coat on a wooden hanger, a card of visiting hours. Manners before entry.",
              extra_changes=[change("F06_C_VESTIBULE-003", "P1", "add", "Gloves on a tray and the buttonhook", objects=["new: 6C_glove_tray (desktop_stock) on the shelf with gloves; a buttonhook on a ribbon"], purpose="Entry set white_gloves_by_the_door; the signature prop", acceptance="Threshold view")], group_intro=INTRO_6C),
    area("F06_C_MAIN", G6C, "ORISON", "Mae's parlour: objects on the walls, people on the furniture", "6.1 x 5.3 m, one window, openings to vestibule, studio and private hall", "Mae Kessler (20:00: radio drama, letters to dealers); Nadia on Thursdays",
         ("The sofa, coffee table, round table and chairs, the old radio and oddments and catalogues, the sectional bookshelf and the radio are installed; this is the most furnished of the "
          "C-type homes. Decor profile: a provenance cabinet, objects classified on walls, people kept close on furniture, the art not obscured by the archive. The room should hang the classified "
          "objects (a row of small framed items with tags), keep the photographs of people on the tables, put the catalogue table at the window with the two cards for one object, and set the "
          "tea service for Thursday. The 1912 prospectus on the shelf beside the unopened Estate ledger. The player infers certainty worn as manners, and the one book she has never opened."),
         [change("F06_C_MAIN-001", "P1", "add", "The catalogue table with two cards for one object", objects=["6C_din_t as the catalogue table; new: 6C_catalogue_cards (papers: two cards), 6C_object_under_review (desktop_stock small object on a cloth), 6C_gloves_on_table"], placement="Table at the window; cards side by side beside the object", purpose="Contradiction: two catalogue cards for the same object, both in her hand; surface set catalog_table", sources=["game/data/apartment_life_profiles.json"], acceptance="Detail view of the table"),
          change("F06_C_MAIN-002", "P1", "add", "Prospectus and the unopened ledger on the shelf", objects=["F06_6C_BOOKSHELF_01 (sectional): the 1912 Vantry prospectus (a bound sales book with the roof-garden plate) and a thick ledger with a dust line showing it is never opened"], construction="Two bookpile objects as shelf contents; prospectus INSPECT via the bookshelf panel's card",
                 purpose="Bible VIII.3 and VIII.5.h: the prospectus is a sales book for a building that was demolished; proposed backstory: the Estate ledger never opened (web II.2)", sources=["design/ORISON_BIBLE.md VIII.3, VIII.5.h", "design/ORISON_RELATIONSHIP_WEB.md II.2"], preserve="BookshelfProp sorting panel", acceptance="Detail view of the shelf"),
          change("F06_C_MAIN-003", "P2", "add", "Classified objects on the wall, people on the furniture", objects=["new: a row of five small framed objects with tag rectangles (CharacterMemoryArt); two standing photographs (desktop_stock frames) on the coffee table"], placement="Row on the wall beside the studio opening at 1.5 m; frames on the coffee table", purpose="Decor profile provenance cabinet", acceptance="Overview"),
          change("F06_C_MAIN-004", "P2", "add", "The Thursday tea service", objects=["new: 6C_tea_service (desktop_stock: the good service on a tray) on 6C_cof"], purpose="Schedule: tea with Nadia Thursdays 16:00, the good service", acceptance="Detail view")],
         canon=[C_BIBLE_IV, C_LIFE, C_DECOR, C_WEB, "Bible VIII.3 / VIII.5.h (the prospectus)"], proposed_backstory=["The Kessler Estate ledger beside the prospectus is never opened."], implementation=apt_impl()),
    kitchen("F06_C_KITCHEN", "6C", G6C, "careful_and_spare", "One of the four electric flats: the monitor-top she has never replaced, kept pristine (enamel_pristine recipe); a covered butter dish; one good knife.",
            fridge="monitor", extra_changes=[change("F06_C_KITCHEN-003", "P3", "refine", "Pristine enamel on the range", objects=["F06_6C_STOVE_01 with the enamel_pristine recipe"], purpose="Appliance Bible IV", acceptance="Detail view")]),
    private_hall("F06_C_PRIVATE_HALL", "6C", G6C, "a 6.6 m hall: packing material (straw, a crate, paper) at the archive end, nothing at the bath end; the route clear."),
    area("F06_C_STUDIO", G6C, "ORISON", "6C studio closet: packing station", "3.4 x 2.5 m, opening from the main room, two wardrobes", "Mae Kessler",
         ("Two wardrobes: one clothes (the melton coat, long skirts, buttoned boots with the hook), one shelved for packing: straw, tissue, string, a small crate. The packing station of the profile."),
         [change("F06_C_STUDIO-001", "P2", "refine", "Second wardrobe as the packing store", objects=["6C_w1_wardrobe shelved variant with packing materials"], purpose="Surface set packing_station", acceptance="Open-leaf view")],
         canon=[C_LIFE], implementation=apt_impl()),
    bath("F06_C_BATH", "6C", G6C, "single_adult_exact", "Exact and old: a silver-backed brush set, a hair net, the pageboy's pins in a dish; the gloves never come in here."),
    area("F06_C_BED1", G6C, "ORISON", "Mae's bedroom", "3.3 x 3.8 m, one window", "Mae Kessler (early)",
         ("Bed and nightstand. Edwardian bones under a 1927 coat (wardrobe bible): the brooch off and placed on the nightstand, the hair released still holding its set, a long cardigan on the chair. "
          "A photograph of a man in a high collar on the nightstand, unexplained (the Estate)."),
         [change("F06_C_BED1-001", "P2", "add", "Brooch placed, photograph, hairpins", objects=["desktop_stock on 6C_bed0_ns"], purpose="Wardrobe bible late-night state; web II.2 as an object", acceptance="Detail view")],
         canon=[C_WARD, C_WEB], implementation=apt_impl()),
    area("F06_C_BED2", G6C, "ORISON", "Mae's provenance archive (converted second bedroom)", "3.3 x 3.8 m, one window, door from the private hall", "Mae Kessler",
         ("Data gives 6C a second made bed. The profile converts this room into a climate-conscious archive: shelving, a catalogue table, packing material, gloves, disputed family objects and the "
          "locked provenance drawer (hero object). The window gets a blind kept down (light damages paper). The player infers an appraiser who has catalogued every object but her family's part in the building."),
         [change("F06_C_BED2-001", "P1", "remove", "Remove the second bed and nightstand", objects=["6C_bed1", "6C_bed1_ns"], purpose="Lived-in brief: one bed; room conversion provenance_archive", sources=["game/data/apartment_life_profiles.json"], acceptance="No bed; sleeper count one"),
          change("F06_C_BED2-002", "P1", "add", "Archive shelving, catalogue drawers and the locked provenance drawer", objects=["new: 6C_archive_shelves (Shelf01 x3) with boxed objects under cloths, 6C_card_cabinet (domestic_storage small cabinet with drawers), 6C_provenance_drawer (one drawer with a brass lock; RESIST-REFUSE: locked, the reason is hers)"],
                 placement="Shelves on the two solid walls; cabinet under the window with the blind down; 0.8 m route kept", construction="Shelf family; cabinet variant; the locked drawer is a refusal owner with no key quest (matrix law)", materials="deal shelving, acid-free boxes, muslin, brass lock",
                 wear="none: the one room she keeps as a museum keeps itself", lighting="flush dome; blind down", purpose="Hero object locked_provenance_drawer; surface set gloved_handling; story panel contradictory inventories", sources=["game/data/apartment_life_profiles.json", "design/PROP_SET_INTERACTION_MATRIX.md RESIST-REFUSE law"], preserve="Door swing and route", acceptance="Threshold view from the hall reads an archive")],
         canon=[C_LIFE, C_LIVED, C_MATRIX], implementation=apt_impl()),

    # ------------------------------------------------------------------ 6D
    area("F06_D_RESTRICTED", G6D, "ORISON", "6D: landlord storage", "6.15 x 12.65 m shell behind the locked F06_DOOR_05 on the service crossing", "the landlord's agent; nobody",
         ("Locked landlord storage under the roof. Keep the interior as authored; on the crossing side a padlock hasp over the mortise lock, a brass plate without lettering, a dust line at the "
          "threshold, and the roof tank's drip stain on the ceiling plaster outside. If a teleported interior shows a bare shell, that is correct for a room the player never enters."),
         [change("F06_D_RESTRICTED-001", "P1", "keep", "Keep the interior as authored", purpose="Intentional restricted space", acceptance="Teleported overview unchanged"),
          change("F06_D_RESTRICTED-002", "P2", "add", "Padlock hasp and plate on the crossing side", objects=["F06_DOOR_05: hasp and padlock (door hardware family), brass plate"], placement="Hasp at 1.2 m across the leaf and jamb; plate at 1.5 m", materials="galvanised hasp (1928) over a brass 1912 escutcheon", purpose="Accord 13: two eras of lock; the matrix's locked-door reason is the landlord's", preserve="Lock state", acceptance="Threshold view from the crossing")],
         canon=[C_ACCORDS, C_MATRIX], implementation={"sources": ["game/data/orison_v2/upper_floor_programs.json (landlord_storage)"], "dependencies": "none", "preserved": "Locked state", "acceptance": "Door tests unchanged"}, coverage="inaccessible_teleported"),
]
