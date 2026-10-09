"""F03: circulation, 3A Malcolm Reed, 3B Omar Bell, 3D Rhea Sato, 3C sealed."""
from _common import *

GC = "F03 / circulation"
G3A = "F03 / 3A Malcolm Reed"
G3B = "F03 / 3B Omar Bell (case)"
G3D = "F03 / 3D Rhea Sato (sanctioned expansion)"
G3C = "F03 / 3C sealed"

INTRO_3A = ("<b>Malcolm Reed, 3A.</b> Horticulturist, moss silhouette, secateurs in a hip sheath, earth under the nails; he kept a cutting alive so a goodbye would not finish; compost is "
            "transformation (Bible IV). Canon: a propagation shelf at the window light, a pruning station, reused jars, a soil-tracked entry, a compost pail under the sink, the empty memorial pot "
            "on the sill above the sink (hero object), one shelf spot kept clear and dusted and never filled (contradiction), cleanliness 0.6, early sleeper, the monitor-top kept since it was "
            "new (one of the four). His layer is 1918 (web I): the cutting came from a windowsill geranium the morning of a goodbye the influenza did not let him finish, to Auggie Reed, whose "
            "name he took; Sacha (6A) is Auggie's line and photographs his plants on Sundays (web II.8). He works the parks greenhouse by day, the roof beds at dawn and dusk, and hands out "
            "rooted cuttings on Saturdays so everyone in the building has a descendant of the same plant. <i>Proposed backstory:</i> the empty pot stands where the plant would have been "
            "happiest; the geranium itself is the story specimen and is never named. <b>Build state:</b> the main room already carries the potting bench, specimen, cuttings, seed jars, radio "
            "and a repaired bookshelf; it needs the propagation shelf at the window, the jars everywhere and the one clear place.")

INTRO_3B = ("<b>Omar Bell, 3B.</b> Repair technician and the building's super in all but title; an apron of categorized tools; he cannot declare anything unrepairable (Bible IV.1, a case: "
            "appliances arriving from incorrect timelines). Canon: repair intake and outgoing zones, labelled fastener drawers, a service aisle, boots and toolbelt at the door, two of every "
            "appliance with one half torn down on newspaper, the sacrificial teardown appliance as hero object kept broken on purpose for parts and company, cleanliness 0.8, maintenance "
            "0.98, early sleeper who wakes at 03:00 to check the B1 breaker panel. Married to Iris (5C) since 1977 and not in the same room since the blackout (web II.3); his notes to the super "
            "are notes to himself; Tuesday nights he re-caps Cal's chassis in 5B; Thursday mornings he does the Iris round while she is out by arrangement. <i>Proposed backstory:</i> the "
            "sacrificial teardown is a radio chassis from the night of the 1977 blackout. <b>Build state:</b> the densest workroom in data (workbench, two tool shelves, toolboard, parts crate, "
            "trays, jars, manuals, coil, bench lamp, wall radio, projector) with a service door from the kitchen onto the south service hall. The alcove wardrobe shows its unfinished back to "
            "the main room (punchlist). It needs the intake/outgoing logic and the teardown.")

INTRO_3D = ("<b>Rhea Sato, 3D.</b> Vocal coach and recording artist, severe bob, tuning fork on a neck chain; her mistakes accumulate as a captive note; imperfection can be voluntary "
            "(sanctioned expansion). Canon: an edit desk, take sheets, a hydration station, thrift-glam entry, a voice-care bathroom, tea, honey and lemon in a spotless never-used kitchen, no "
            "television, the isolated microphone case as hero object, a dressing mirror facing away from the booth (contradiction), the office converted to a vocal booth, cleanliness 0.65. "
            "She deleted take 18 and it survives in Juno's archive one floor down (web II.7). At 20:00 she files the day's sessions in the error archive. <i>Proposed backstory:</i> the error "
            "archive is a card index in a cabinet with a drawer per flaw. <b>Build state:</b> an A-type completion home furnished from 5C templates (bed, wardrobe, table, chair, WC, sink) with a "
            "monitor-top where the Bible allows an icebox and an empty study. Nothing says a singer lives here.")

AREAS = [
    core("F03_PUBLIC_CORE", GC, "F03 public core: stair, lift and 3C's locked door", "The dog-leg stair and lift at the centre; 3C's locked entry (F03_C_ENTRY_DOOR) opens here; openings to the east and west halls",
         "The core on this floor carries the second sealed door; Omar collars residents here between 19:00 and 21:00 (schedule: overflow). The half-landing above is Jonah's pause (schedule 17:00).", level="F03"),
    core("F03_SERVICE_CORE", GC, "F03 service core", "Service lift and stair with a door to the service hall", "The intermediate service transfer; the super's chalk tallies are densest on this floor because he lives on it.", level="F03"),
    core("F03_LANDING", GC, "F03 passenger lift landing", "At the top of the primary stair's flight; the lift plate and dial", "The landing's unique piece: the notice on the stair landing that dates from the reopening (Bible VIII.5.h), framed under glass.", level="F03"),
    public_hall("F03_EAST_HALL", GC, "F03 east hall: the approach to Omar", "From the core east to the service crossing", "Omar, whoever has collared him",
                "A hall where things wait for the super: a radiator section on the floor against the wall, a labelled parts bag hung on the dado, a crate of somebody's broken lamp. Nothing in the route.", level="F03"),
    service_hall("F03_SERVICE_CROSSING", GC, "F03 service crossing: Omar's front door", "The crossing where 3B's entry door (F03_DOOR_03) opens onto the service spine", "Omar's door opens straight onto the spine, which is why he is the super: his threshold is the building's workshop door. A boot scraper and a notice board of repair tags belong here.", level="F03"),
    service_hall("F03_SERVICE_HALL", GC, "F03 service hall (north)", "North maintenance route with the bypass and inspection clearance around the continuity ducts, door to the service core", "The widest service hall (2.4 m): room for a trolley and the inspection stance at the duct hangers; the duct supports are fitted (duct_supports.md).", level="F03"),
    service_hall("F03_SERVICE_HALL_SOUTH", GC, "F03 service hall (south): Omar's back door", "South run with 3B's kitchen service door (F03_B_SERVICE_DOOR)", "The only kitchen in the building with a service door onto the spine: Omar's intake comes in this way. A shelf for outgoing repairs beside the door.", level="F03"),
    public_hall("F03_WEST_HALL", GC, "F03 west hall: the approach to Malcolm", "From the core west to the southwest hall; 3A's entry (F03_DOOR_02)", "Malcolm, Sacha on Sundays",
                "Soil tracked in a fan from Malcolm's door; a rooted cutting in a jar left on the floor for a neighbour to collect (Saturday: everyone gets a descendant).", level="F03"),
    public_hall("F03_SOUTHWEST_HALL", GC, "F03 southwest hall: Rhea's approach", "Dead-end hall with 3D's entry (F03_D_ENTRY_DOOR)", "Rhea, nobody else",
                "A hall that ends at a singer's door: a noise-complaint note on the dado (schedule evidence; lived-in brief) and the quiet of a woman who records at night.", level="F03"),

    # ------------------------------------------------------------------ 3A
    vestibule("F03_A_VESTIBULE", "3A", G3A, "soil_tracked", "A 1.95 x 2.7 m vestibule off the west hall: boot scraper, hobnailed boots on newspaper, a trug, the flat cap on a nail, and soil in a fan from the mat that fades toward the main room.", group_intro=INTRO_3A),
    area("F03_A_MAIN", G3A, "ORISON", "Malcolm's living room: the propagation bench", "8.1 x 6.95 m, two west windows, openings to the vestibule and kitchen, door to the private hall", "Malcolm Reed; Sacha on Sunday mornings",
         ("The potting bench, the specimen, the cuttings and seed jars, the radio and the repaired bookshelf are installed. The room should be a botanical study (decor profile): the propagation "
          "shelf across both west windows at sill height, cuttings in reused jars in rows with their dates on tags, the bench with a watering tray, soil sweepings, a trug and the secateurs' "
          "sheath; the dining table pushed to the wall and used for repotting; the propagation diagram and the cutting portrait on the wall as evidence, not decor; and one shelf spot clear "
          "and dusted. The player infers a man who keeps other people's plants alive and one plant alive against a goodbye."),
         [change("F03_A_MAIN-001", "P1", "add", "Propagation shelf across the windows", objects=["new: 3A_prop_shelf (shelf family, 2.4 m long, 0.25 m deep) under both window sills with jars (desktop_stock jarrow family)"],
                 placement="Spanning the two west windows at 0.78 m, 0.1 m off the glass, jars in two rows with one gap of exactly one jar's width at the north end", construction="One shelf variant with jar rows; the gap is authored as an empty support, dusted (no dust decal there)",
                 materials="pine, glass jars, string tags", wear="water rings on the shelf, a green stain under the jars, dust everywhere but the gap", lighting="the window glow lights the jars from behind at day; at night the pendant", purpose="Life profile propagation_shelf; contradiction: one spot kept clear and never filled",
                 sources=["game/data/apartment_life_profiles.json", "art/blender/domestic_storage.md", "art/blender/desktop_stock.md"], preserve="Window light, radiator valve reach, route to the kitchen opening", acceptance="Overview from the vestibule reads two windows of jars with one gap"),
          change("F03_A_MAIN-002", "P2", "refine", "Potting bench working surface", objects=["3A_potting_bench (TableRect05)", "3A_story_cuttings, 3A_story_seed_jars, 3A_story_specimen (existing)"], placement="As installed, bench end against the pier",
                 construction="Add a zinc watering tray, a trug, a soil sweep decal on the floor under the bench, a pruning station (secateurs on a cloth)", materials="zinc, willow, oilcloth", wear="soil in the floor seams; a knife mark line on the bench edge", purpose="Life profile pruning_station; story panel pressed leaves and reused jars",
                 acceptance="Detail view of the bench"),
          change("F03_A_MAIN-003", "P2", "add", "The propagation diagram and the cutting portrait", objects=["new: two framed pieces (CharacterMemoryArt)"], placement="On the wall beside the private-hall door at 1.5 m, 0.4 m apart, not crowding the plants (decor profile)", construction="WallArtLaw; one diagram sheet (line decals), one small sepia plate",
                 purpose="Decor profile: evidence, not decor; the only photograph of a plant in the building is Sacha's (web II.8)", acceptance="Detail view shows two frames clear of the shelf"),
          change("F03_A_MAIN-004", "P3", "refine", "Repotting on the dining table", objects=["3A_din_t, chairs"], placement="Table against the inner wall; one chair under it, one pulled out", construction="A newspaper sheet decal and a pot on the table (desktop_stock)", purpose="Daily loop repot", acceptance="Reverse view")],
         canon=[C_BIBLE_IV, C_LIFE, C_DECOR, C_STORY, C_WEB], proposed_backstory=["The gap on the shelf is where the plant would have been happiest."], implementation=apt_impl()),
    kitchen("F03_A_KITCHEN", "3A", G3A, "jars_and_compost", "One of the four electric flats: the monitor-top is correct and loud. The empty memorial pot sits on the sill above the sink holding soil and nothing; the compost pail is under the sink; jars, not tins, on the cupboard shelf.",
            fridge="monitor", extra_changes=[change("F03_A_KITCHEN-003", "P1", "add", "The empty memorial pot above the sink", objects=["new: 3A_memorial_pot (desktop_stock terracotta pot with soil, no plant) on the window sill over F03_3A_KITCHEN_SINK_01"], placement="Window sill, centred, facing the room",
                                                   dimensions="0.14 m pot", construction="Desktop-stock pot variant with a soil fill and a water ring; INSPECT card only; hero object", materials="terracotta, dark soil, a chalk line on the rim", wear="the sill under it dusted clean in a ring",
                                                   purpose="Life profile hero object empty_memorial_pot; Appliance Bible III", sources=["game/data/apartment_life_profiles.json", "design/ORISON_APPLIANCE_BIBLE.md"], acceptance="Detail view at the sink"),
                                            change("F03_A_KITCHEN-004", "P2", "add", "Compost pail under the sink", objects=["new: 3A_compost_pail (desktop_stock enamel pail with lid)"], placement="On the floor under the sink support, clear of the tap stance", materials="chipped white enamel, a lid", purpose="Kitchen set jars_and_compost", acceptance="Reverse view")]),
    private_hall("F03_A_PRIVATE_HALL", "3A", G3A, "a trug of empty jars by the bath door; the oiled-cotton coat's drip mark on the floor."),
    bath("F03_A_BATH", "3A", G3A, "single_adult", "Soil in the basin trap, a nail brush, hands that never come clean (wardrobe bible); the punchlist's F03_A_BATH toilet-in-shower overlap was a V1 row and must be rechecked in the capture."),
    area("F03_A_BED", G3A, "ORISON", "Malcolm's bedroom", "5.4 x 5.45 m, two windows, door from the private hall", "Malcolm Reed",
         ("Bed, wardrobe, nightstand. He sleeps early in a union suit under a brown jumper; the seed catalogue is on the nightstand; the second window sill carries a tray of seedlings that need "
          "the morning light, because the main room faces west. A flat cap on the bedpost."),
         [change("F03_A_BED-001", "P2", "add", "Seedling tray on the sill and the catalogue", objects=["new: 3A_seed_tray (desktop_stock) on the window sill; a catalogue (papers) on 3A_bed0_ns"], placement="North window sill; nightstand top",
                 materials="wooden flat, newsprint, paper", purpose="Daily loop water; wardrobe bible late-night state", acceptance="Detail view of the sill")],
         canon=[C_WARD, C_LIFE], implementation=apt_impl()),

    # ------------------------------------------------------------------ 3B
    vestibule("F03_B_VESTIBULE", "3B", G3B, "boots_and_toolbelt", "2.0 x 2.7 m off the service crossing: boots on a tray, the ochre apron hung in frame with tools in its pockets (wardrobe bible late-night state), a parts bag, and a pegboard of other people's keys with tags. This is the building's service entrance in miniature.",
              group_intro=INTRO_3B),
    area("F03_B_MAIN", G3B, "ORISON", "Omar's workroom: intake, bench, outgoing", "4.15 x 5.55 m, one window, openings to the vestibule and the private hall", "Omar Bell; the appliances of the whole building",
         ("The workbench, two tool shelves, toolboard, parts crate, trays, jars, manuals, coil, the friction bench lamp, the wall radio and the projector are installed; the room is already the "
          "most specific in data. The logic the lived-in brief asks for is intake on one side, outgoing on the other, the bench between, and a clear service aisle: a crate by the door labelled "
          "with tags for things waiting diagnosis (story panel), a shelf of repaired things wrapped and tagged for return, and on newspaper on the floor the sacrificial teardown: a radio "
          "chassis half dismantled with its screws in a saucer, kept that way. Two of every appliance. The player infers a man who repairs everyone's things, keeps one broken for company, "
          "and whose home is maintained to a degree nobody else's is."),
         [change("F03_B_MAIN-001", "P1", "add", "The sacrificial teardown on newspaper", objects=["new: 3B_teardown (new native assembly: radio chassis with valves out, on a newspaper sheet, screws in a saucer)"],
                 placement="On the floor beside 3B_partscrate, 0.5 m from the wall, outside the bench aisle", dimensions="0.5 x 0.35 m", construction="One native assembly in the household_objects_radios family (chassis, three loose valves, a saucer, a sheet); INSPECT owner; never a live receiver",
                 materials="crackle-black steel, glass valves, newsprint decal", wear="solder splash on the newspaper, a scorch on the floor beside it", signal=SIGNAL_YES, purpose="Life profile hero object sacrificial_teardown_appliance; proposed backstory: the 1977 blackout chassis",
                 sources=["game/data/apartment_life_profiles.json", "art/blender/household_objects_radios.md"], preserve="Bench aisle and workbench stance, the task lamp's cord route (G14)", acceptance="Detail view from the bench stance"),
          change("F03_B_MAIN-002", "P1", "add", "Intake crate and outgoing shelf", objects=["3B_partscrate (existing) retagged as intake", "new: 3B_outgoing_shelf (Shelf01) with three wrapped parcels (desktop_stock)"], placement="Crate by the vestibule opening; shelf on the wall beside the private-hall opening at 1.1 m",
                 construction="Paper tags on string (desktop_stock), parcels in brown paper", materials="brown paper, string, pine", purpose="Life profile surface set repair_intake; story panel repair tags", acceptance="Overview reads a flow from door to bench to shelf"),
          change("F03_B_MAIN-003", "P2", "refine", "Fastener drawers on the tool shelves", objects=["3B_tools0, 3B_tools1 (Shelf01)"], construction="Add a bank of small labelled tins and a six-drawer fastener cabinet (desktop_stock) to the shelf variant", materials="tin, card labels (blank rectangles)", purpose="Life profile fastener_drawers; story panel sorted fasteners",
                 acceptance="Detail view of the shelves"),
          change("F03_B_MAIN-004", "P2", "keep", "Keep the wall radio, projector and bench lamp", objects=["3B_radio (HouseholdRadio at 1.82 m)", "3B_tv (ProjectorProp)", "F03_B_LAMP_01 (bench_friction)"], purpose="F14: Omar's is a case flat with a projector; the wall radio is his second set; the lamp is G14's fitted cord family", acceptance="Unchanged in the overview")],
         canon=[C_BIBLE_IV, C_LIFE, C_STORY, C_APPL, C_LIVED, C_WEB], proposed_backstory=["The teardown is a radio chassis from the night of the 1977 blackout."], implementation=apt_impl()),
    kitchen("F03_B_KITCHEN", "3B", G3B, "simple_and_maintained", "The only kitchen with a service door onto the spine (F03_B_SERVICE_DOOR): a workshop-enamel range (Appliance Bible IV: masking-tape residue, marker numbering, one panel replaced in mismatched paint) and a lid gasket replaced and dated. The kitchen linear light is his own fitting.",
            extra_changes=[change("F03_B_KITCHEN-003", "P2", "refine", "Workshop enamel on the range", objects=["F03_3B_STOVE_01"], construction="Apply the enamel_workshop recipe (owner finish profiles) to this range only", materials="white enamel with tape residue and one mismatched panel", purpose="Appliance Bible IV texture identity", sources=["game/data/orison_v2/owner_finish_profiles.json", "design/ORISON_APPLIANCE_BIBLE.md IV"], acceptance="Detail view at the range")]),
    private_hall("F03_B_PRIVATE_HALL", "3B", G3B, "the hall gives independent access to alcove and bath; a fire bucket of sand by the alcove door (the super's habit) and a torch on a hook."),
    area("F03_B_ALCOVE", G3B, "ORISON", "Omar's sleeping alcove", "3.5 x 4.3 m, one window, door from the private hall", "Omar Bell (asleep by 22:00, up at 03:00)",
         ("Bed, nightstand and the wardrobe whose unfinished back faces the main room (punchlist 2026-08-25 row). An early sleeper's room: the apron hung, spectacles on the nightstand, a wind-up "
          "alarm set for 03:00, boots paired under the bed. The alcove door is the only interior door he keeps closed."),
         [change("F03_B_ALCOVE-001", "P1", "refine", "Turn or back-panel the wardrobe", objects=["3B_aw_wardrobe (Wardrobe00)"], placement="Same anchor; rotate so the leaves face the bed, or add the finished back panel to the variant", construction="Wardrobe variant with a finished back (household_wardrobes family) or a yaw change in the source plan",
                 purpose="Punchlist: wardrobe faces the main room with its unfinished back panel", sources=["design/walkthrough_punchlist.md", "art/blender/household_wardrobes.md"], preserve="Leaf motions and the 42-leaf test", acceptance="Overview from the main room shows no raw back"),
          change("F03_B_ALCOVE-002", "P2", "add", "Bedside: spectacles, alarm, torch", objects=["new: desktop_stock on 3B_abed_ns"], purpose="Schedule: wakes 03:00 to check the breaker panel", acceptance="Detail view of the nightstand")],
         canon=[C_SCHED, C_WARD], implementation=apt_impl()),
    bath("F03_B_BATH", "3B", G3B, "single_adult_practical", "The one bathroom lit by a sconce globe instead of a dome: his own fitting. A shaving mirror hung where the sconce falls; a pumice; carbolic soap; the punchlist's toilet-in-shower overlap row must be rechecked in the capture."),

    # ------------------------------------------------------------------ 3D
    vestibule("F03_D_VESTIBULE", "3D", G3D, "thrift_glam", "A 2.6 x 2.7 m vestibule with three doors (entry, main, private hall): the dressing mirror turned to the door, a hat stand with three cloches, a shoe tree. The A-type plan gives her a proper entrance and she uses it as a stage wing.", group_intro=INTRO_3D),
    area("F03_D_MAIN", G3D, "ORISON", "Rhea's living room: a small stage", "7.45 x 3.35 m, one window, doors to vestibule, kitchen and bedroom", "Rhea Sato",
         ("A long front room with a 5C-template table and chair and a flush dome. Decor profile: a small stage, each image gets its own pool of negative space. It should hold the edit desk with "
          "take sheets, the hydration station (a tray with a jug, two glasses, honey, lemons), a chaise or daybed for the vocal rest, a thrift-glam dressing corner (a screen, a mirror, a lamp "
          "with a fringed shade), and no television. The images on the wall are three, far apart. The player infers a performer who controls every object because she cannot control the voice."),
         [change("F03_D_MAIN-001", "P1", "add", "Edit desk, take sheets and the hydration station", objects=["existing 3D_table as the edit desk; new 3D_take_sheets (papers), 3D_hydration_tray (desktop_stock), 3D_desk_lamp (task lamp family)", "new: 3D_wireless_table (TableRect07) and DomesticRadio_3D"],
                 placement="Desk against the window pier with the chair facing the room; tray on the desk's left; wireless table on the long wall", construction="Shared variants; desktop_stock pieces by support id; radio family", materials="oak, paper, glass, a brass tray", signal=SIGNAL_YES,
                 wear="ring marks from the glasses on the desk's left corner only", purpose="Life profile surface sets edit_desk, take_sheets, hydration_station; six homes have no radio", sources=["game/data/apartment_life_profiles.json", "game/data/orison_v2/domestic_radios.json"], acceptance="Overview from the vestibule door"),
          change("F03_D_MAIN-002", "P1", "add", "Chaise and the dressing corner", objects=["new: 3D_chaise (domestic_seating sofa variant), 3D_screen (new small folding screen, cloth family), 3D_mirror (mirror family), 3D_fringed_lamp (task lamp variant with a fringed shade decal)"],
                 placement="Chaise along the long wall under the dome; screen and mirror in the corner by the bedroom door, the mirror facing the vestibule and away from the study door (the contradiction)", construction="Shared variants plus one folding screen piece",
                 materials="worn velvet, silk fringe, a cracked mirror", purpose="Life profile: thrift_glam, dressing mirror facing away from the booth; story panel glamorous thrift-store clutter", acceptance="Reverse view shows the mirror's back toward the study"),
          change("F03_D_MAIN-003", "P2", "add", "Three images, far apart", objects=["new: three CharacterMemoryArt frames"], placement="At 1.5 m with at least 1.2 m between them", purpose="Decor profile: each image gets its own pool of negative space; avoid a salon wall", acceptance="Overview reads three isolated frames"),
          change("F03_D_MAIN-004", "P2", "refine", "Pendant instead of flush dome", objects=["F03_D_MAIN_LT"], construction="pendant_shade variant over the chaise", purpose="Living-room family lighting", acceptance="RoomLumaAudit unchanged")],
         canon=[C_LIFE, C_DECOR, C_STORY, C_WARD], implementation=apt_impl()),
    kitchen("F03_D_KITCHEN", "3D", G3D, "tea_honey_lemon", "The range is spotless because it is never used; the monitor-top in data should be an icebox (Bible VIII.5.a); the kettle is the only warm thing.",
            fridge="monitor", extra_changes=[change("F03_D_KITCHEN-003", "P2", "refine", "Monitor-top to icebox", objects=["F03_3D_FRIDGE_01 (FridgeMonitor -> FridgeIcebox)"], construction="Swap the household_fridges variant; keep the FridgeProp owner", purpose="Bible VIII.5.a prevails: four electric flats are 1A, 3A, 5B, 6C", sources=["game/data/orison_v2/household_fridges.json"], acceptance="Household fridge module passes with the icebox variant")]),
    private_hall("F03_D_PRIVATE_HALL", "3D", G3D, "a kettle on the floor outside the bath door for the steam routine; a hamper with a silk wrapper on top."),
    bath("F03_D_BATH", "3D", G3D, "voice_care", "A singer's bathroom: the steam kettle, pastilles, an inhaler, two glasses. The punchlist's magenta hamper intersecting a tan box was a V1 row; recheck."),
    area("F03_D_BED", G3D, "ORISON", "Rhea's bedroom", "4.35 x 5.15 m, one window, doors to the main room and the booth (study)", "Rhea Sato",
         ("Bed, wardrobe (templates). Severe order: the ink-blue frock on a hanger on the wardrobe door, a wool scarf on the bedpost for the throat, the tuning fork's chain on the nightstand, "
          "the silk wrapper folded. The booth door is beside the bed; she does not have to pass the mirror to reach it."),
         [change("F03_D_BED-001", "P2", "add", "Nightstand with the fork chain and scarf", objects=["new: 3D_bedside (Nightstand02) with desktop_stock: fork on a chain, a glass, a scarf on the bedpost (cloth)"], placement="Door side of the bed", materials="nickel, silk, wool", purpose="Wardrobe bible signature in all three states", acceptance="Detail view of the nightstand")],
         canon=[C_WARD], implementation=apt_impl()),
    area("F03_D_STUDY", G3D, "ORISON", "Rhea's vocal booth (converted study)", "3.1 x 2.7 m, one window, door from the bedroom", "Rhea Sato (records and files flaws at night)",
         ("Empty today. The profile converts the office into a vocal booth: blankets and a rug deadening the window and walls, a music stand, the isolated microphone case (hero object) on a "
          "stool, a reel deck on a shelf, headphones on a nail, and the error archive: a card-index cabinet with a drawer per flaw. The punchlist's old 3D booth/mirror overlap was a V1 artefact. "
          "The player infers the captive note: every mistake filed where she can find it."),
         [change("F03_D_STUDY-001", "P1", "add", "The booth: deadening, stand, case, deck", objects=["new: 3D_booth_blankets (cloth family), 3D_music_stand (asm_micstand reuse), 3D_mic_case (new desktop_stock: a latched wooden case with a velvet cut-out, closed), 3D_reeldeck (asm_reeldeck), 3D_headphones (asm_headphones)"],
                 placement="Blankets on the two solid walls and over the window; stand centred; case on a stool beside the door; deck on a wall shelf at 1.2 m", construction="Reuse the assemblies the matrix names (reeldeck, headphones, micstand are RESIST-REFUSE); case is INSPECT; blankets sewn-edged",
                 materials="brown wool, nickel, walnut case with brass latches, velvet", signal=SIGNAL_YES, wear="a chalk cross on the floor at the singing spot", purpose="Life profile room conversion vocal_booth; hero object isolated_microphone_case", sources=["game/data/apartment_life_profiles.json", "design/PROP_SET_INTERACTION_MATRIX.md"],
                 preserve="Door swing from the bedroom", acceptance="Threshold view from the bedroom reads a booth"),
          change("F03_D_STUDY-002", "P2", "add", "The error archive card index", objects=["new: 3D_card_index (domestic_storage small cabinet variant with 12 drawers, one open)"], placement="Against the wall beside the deck shelf", dimensions="0.45 x 0.35 m, 0.6 m high", materials="oak, brass label frames (blank)",
                 purpose="Schedule 20:00: the day's sessions filed, flaws tagged and cross-referenced; proposed backstory", acceptance="Detail view shows one drawer open with cards")],
         canon=[C_LIFE, C_SCHED, C_MATRIX], proposed_backstory=["The error archive is a card index with a drawer per flaw."], implementation=apt_impl()),

    # ------------------------------------------------------------------ 3C
    area("F03_C_RESTRICTED", G3C, "ORISON", "3C: the sealed apartment", "12.7 x 7.8 m shell behind the locked F03_C_ENTRY_DOOR on the public core", "nobody",
         ("The second sealed home, opening off the core itself so that every resident passes its door daily. The same keep-empty rule as 2D and the same threshold treatment on the core side; "
          "the difference is audience: this door is seen by everyone, so its paper is the one Evelyn has straightened and Nadia has noticed."),
         [change("F03_C_RESTRICTED-001", "P1", "keep", "Keep the interior empty", purpose="Intentional empty space", acceptance="Teleported overview unchanged"),
          change("F03_C_RESTRICTED-002", "P2", "add", "Sealed threshold treatment on the core side", objects=["new: notice frame beside F03_C_ENTRY_DOOR, paper strip over the slot, clean mat"], placement="Core side at 1.5 m", construction="Core notice family; strip decal", purpose="As F02_D_RESTRICTED-002, seen by the whole building", preserve="Locked state", acceptance="Threshold view from the core")],
         canon=[C_BIBLE_VIII5H, C_MATRIX], implementation={"sources": ["game/data/orison_v2/upper_floor_programs.json"], "dependencies": "none", "preserved": "Locked state, shell", "acceptance": "Door tests unchanged"}, coverage="inaccessible_teleported"),
]
