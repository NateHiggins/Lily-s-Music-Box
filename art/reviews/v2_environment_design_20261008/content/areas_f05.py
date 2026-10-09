"""F05: circulation, 5A Nadia Quell, 5B Cal Dwyer, 5C Iris Bell, 5D fire-damaged."""
from _common import *

GC = "F05 / circulation"
G5A = "F05 / 5A Nadia Quell (sanctioned expansion; Management)"
G5B = "F05 / 5B Cal Dwyer (case)"
G5C = "F05 / 5C Iris Bell"
G5D = "F05 / 5D fire-damaged"

INTRO_5A = ("<b>Nadia Quell, 5A.</b> Architect who became the building's live-in manager and organizes its tenants against her own employers, the Kessler Estate (Bible VI.3, ruled); she signs "
            "the player's welcome letter Management; she was silenced about violations once; name the violation. Canon: a plan wall, code books, emergency supplies, measured egress at the "
            "entry, efficient batching in the kitchen, the corrected floor plan of this building on the icebox door (hero object), the exit route measured, marked and blocked by nothing "
            "(contradiction: rehearsed), cleanliness 0.85, maintenance 0.9. Decor profile: an advocacy board, people and plans displayed like promises with room to annotate. She takes tea with Mae on "
            "Thursdays and neither says the thing (web II.2); she posts the tenant memo on her night round; she holds surgery hours in the lobby at 08:15; she is in Photo Supplies more than she is "
            "upstairs. <i>Proposed backstory:</i> her corrected plan shows a room that is not on the blockout. <b>Build state:</b> the richest study in data (plan shelf, model table, site "
            "model, pins) and a main room with a plantable, stool, pins, floor stack, papers, the counterweight lamp and a plain bookshelf. It needs the wall and the egress.")

INTRO_5B = ("<b>Cal Dwyer, 5B.</b> Radio collector, mustard cardigan with one pocket sagging under a battery case, a black Bakelite hearing-aid receiver on a brown cloth cord (a Rule-of-Signal "
            "device); perfect tuning preserves moments by preventing them ending; presence is not preservation (Bible IV.1, a case). Canon: a listening triangle, a repair mat, antenna experiments "
            "at the door, catalogued tapes, a chair worn toward the radio and not the television (hero object and contradiction), the range as a stand for three console radios, the icebox holding "
            "batteries and film, the reel deck the only warm thing, cleanliness 0.45, nocturnal, dozes in the chair. He is the WORS transmitter that walked in on two legs in 1962 and stopped in 1999 "
            "(web I); his Delayed Voice Reel holds Mina's four seconds (web II.1; never rendered audible, Bible VII.8); Juno trades tapes with him on Saturdays and Omar re-caps a chassis in situ "
            "on Tuesdays. <i>Proposed backstory:</i> the reel is a plain box among the dated tapes with a courthouse date. <b>Build state:</b> a story radio, headphones and lead in the main room, two "
            "radios on the hob and a comparison table in the kitchen; a monitor-top (one of the four). The listening triangle and the worn chair do not exist.")

INTRO_5C = ("<b>Iris Bell, 5C.</b> Painter, printed headscarf, paint-ruined overalls worn out of doors; imagined audiences hold every brush; creation need not perform (Bible IV). Canon: a pigment "
            "station, a drying rack, canvas storage, paint tracked from the door, a brush-washing basin, meals between coats, failed canvases facing the wall (hero object), the second bedroom "
            "converted to a painting studio, cleanliness 0.4. Decor profile: a private gallery, self and impossible space sharing one clean wall as a diptych. Married to Omar since 1977 and two "
            "floors from him since the blackout (web II.3); Sacha photographs her canvases on Sundays, the only lens she permits; she sings two songs at the Harukiya on Fridays, magnificently, and "
            "leaves. <i>Proposed backstory:</i> the failed canvases are portraits of one man. <b>Build state:</b> a C-type completion home with a colour board, solvents and studies in the main room, "
            "a second made bed in BED2 and two wardrobes in the studio closet. No studio exists.")

AREAS = [
    core("F05_PUBLIC_CORE", GC, "F05 public core: Iris's door on the stair", "Stair and lift; 5C's entry (F05_DOOR_06) opens here", "Paint-stiff footprints fade from Iris's door across the landing; the unique piece on this half-landing is a sketch of the light court (she draws it at 13:00).", level="F05"),
    core("F05_SERVICE_CORE", GC, "F05 service core", "Service lift landing and stair", "The service core above the floors where the player works least; its chalk is old.", level="F05"),
    service_hall("F05_SERVICE_HALL", GC, "F05 service hall (north)", "The 2.4 m maintenance and delivery continuity beside the service core", "Omar's Tuesday route to 5B with a chassis under his arm; a radio crate on the floor by the core opening.", level="F05"),
    public_hall("F05_EAST_HALL", GC, "F05 east hall: toward the fire door", "From the core east to the service crossing and 5D's sealed threshold", "nobody",
                "The hall toward the fire-damaged flat: the plaster here is the one place the 1927 demolition is allowed to show (a repaired patch of newer plaster, a soot ghost above the crossing opening). Accord 13: retrofits read as a timeline.", level="F05"),
    service_hall("F05_SERVICE_CROSSING", GC, "F05 service crossing: 5D's door", "The crossing where 5D's locked door (F05_DOOR_05) opens", "The sealed fire-damaged threshold: a 1928 replacement leaf in a scorched 1912 frame, soot above the lintel scrubbed to a ghost, a notice. See F05_D_RESTRICTED.", level="F05"),
    service_hall("F05_SERVICE_HALL_SOUTH", GC, "F05 service hall (south)", "Short south run", "Dead end; a cage bulb; the mop-shadow corner.", level="F05"),
    public_hall("F05_WEST_HALL", GC, "F05 west hall: Nadia and Cal", "The 6.1 m hall with both 5A (F05_DOOR_02) and 5B (F05_DOOR_03) entries", "Nadia, Cal, Juno on Saturdays, Omar on Tuesdays",
                "Two very different doors: Nadia's with a measured chalk tick on the floor at the swing's limit and a memo frame beside it; Cal's with an aerial wire run along the dado from the window end to his door (antenna experiments), tacked with insulators. The hall tells both stories.", level="F05",
                extra_changes=[change("F05_WEST_HALL-003", "P2", "add", "Cal's aerial wire along the dado", objects=["new: wire run with four porcelain insulators from the hall's window end to F05_DOOR_03"], placement="At 2.0 m along the dado, through a drilled hole beside the door", construction="Static wire family (radio_wire.md materials)", materials="copper wire, porcelain insulators", signal=SIGNAL_YES, purpose="Entry set antenna_experiments spills into the hall", sources=["art/blender/radio_wire.md"], acceptance="Overview along the hall shows the run")]),

    # ------------------------------------------------------------------ 5A
    vestibule("F05_A_VESTIBULE", "5A", G5A, "measured_egress", "2.7 x 3.25 m, the largest vestibule: a scale rule and a folded plan on the shelf, a torch, a numbered key ring, and a chalk mark on the floor at the door swing's measured limit. The exit route is rehearsed.",
              extra_changes=[change("F05_A_VESTIBULE-003", "P2", "add", "Chalk swing limit and a torch", objects=["new: chalk arc decal on the floor at the leaf's open position; desktop_stock torch on the shelf"], purpose="Contradiction: the exit route is measured, marked and blocked by nothing", acceptance="Threshold view")], group_intro=INTRO_5A),
    area("F05_A_MAIN", G5A, "ORISON", "Nadia's living room: the advocacy board", "7.35 x 5.75 m, one window, openings to the vestibule and private hall, door to the bedroom", "Nadia Quell; the tenants she organizes",
         ("The dining set, plantable, stool, pins, floor stack, papers, mugs, the counterweight lamp, bookshelf and radio are installed. Decor profile: an advocacy board, people and plans "
          "displayed like promises with room to annotate. The wall opposite the window should carry the plan wall: the building's drawings pinned in a row with annotations, the tenant memo "
          "drafts, the rent-strike ledger on the table (20:00: Estate correspondence answered as Management), code books on the bookshelf, a tin of emergency supplies (candles, a wrench, "
          "bandages) by the door. The plantable (an architect's drawing table) should stand at the window with its lamp. The player infers the manager who is the tenants' organizer against "
          "her own employer, and that nothing in her flat is where it could fall on anyone."),
         [change("F05_A_MAIN-001", "P1", "add", "The plan wall", objects=["5A_pins1 (existing)", "new: 5A_plan_wall (pinboard family 1.6 x 1.0 m) with four plan sheets (line decals), red annotation strokes, memo drafts"], placement="On the wall opposite the window at 1.4 m, clear of the bookshelf, nothing overlapping (decor: avoid cabinet overlap)",
                 construction="Pinboard variant, single tack owner", materials="cork, blueprint-blue paper, red pencil", purpose="Life profile plan_wall; decor profile advocacy board", sources=["game/data/apartment_life_profiles.json", "design/resident_decor_profiles.json"], acceptance="Overview from the vestibule reads the wall first"),
          change("F05_A_MAIN-002", "P1", "move", "Drawing table to the window", objects=["5A_plantable (assembly)", "5A_stool", "F05_A_LAMP_01 (architect_counterweight)"], placement="Plantable square to the window with the stool behind it and the counterweight lamp clamped to its edge, cord per G14's plan", purpose="Daily loop correct_plans at the window light; schedule 20:00 drafting",
                 preserve="Lamp cord route and the plantable's OPERATE/refusal owner (matrix)", acceptance="Reverse view shows the table lit at the window"),
          change("F05_A_MAIN-003", "P2", "add", "The rent-strike ledger and emergency supplies", objects=["new: 5A_ledger (papers bound variant) on 5A_din_t", "new: 5A_supplies_tin (desktop_stock tin with candles, a wrench, a bandage roll) by the vestibule opening"], materials="black cloth ledger, red tin", purpose="Life profile emergency_supplies; schedule: the rent-strike ledger signed Management", acceptance="Detail views"),
          change("F05_A_MAIN-004", "P2", "refine", "Code books on the bookshelf", objects=["F05_5A_BOOKSHELF_01 (plain)"], construction="Bookpile objects: thick uniform volumes with blank spines", purpose="Life profile code_books", acceptance="Detail view")],
         canon=[C_LIFE, C_DECOR, C_SCHED, C_WEB, "Bible VI.3 (ruled: the architect who became the manager)"], implementation=apt_impl()),
    kitchen("F05_A_KITCHEN", "5A", G5A, "efficient_batching", "A small kitchen with a door to the study: four identical covered dishes, and on the icebox door the corrected floor plan of this building (hero object), held by two magnets.",
            extra_changes=[change("F05_A_KITCHEN-003", "P1", "add", "The corrected floor plan on the icebox door", objects=["new: 5A_corrected_plan (papers sheet with plan-line decals and one red-inked room) on F05_5A_FRIDGE_01's leaf"], placement="Centred on the icebox leaf at 1.2 m; moves with the leaf", construction="Decal-plane child of the fridge leaf (the leaf is the owner); INSPECT via the fridge card",
                                                   purpose="Hero object corrected_floor_plan_of_this_building; proposed backstory: it shows a room that is not on the blockout", preserve="FridgeProp leaf and ice door", acceptance="Detail view at the icebox; leaf opens with the sheet attached")]),
    private_hall("F05_A_PRIVATE_HALL", "5A", G5A, "a 5.0 m hall with the measured route chalked at the turns; a fire bucket; nothing on the floor."),
    bath("F05_A_BATH", "5A", G5A, "single_adult_practical", "A bath with a window; the oxblood lip on a towel edge; a nail brush; the fob of keys on the cabinet knob."),
    area("F05_A_BED", G5A, "ORISON", "Nadia's bedroom", "4.45 x 6.0 m, two windows, door from the main room", "Nadia Quell",
         ("Bed, nightstand, wardrobe. Barefoot on a floor she has opinions about (wardrobe bible): the bed made square, the oxblood coat on a wooden hanger, a folding rule on the nightstand "
          "beside a notebook, the pressed line of the frock gone. A tape measure runs along the skirting where she checked the room's width."),
         [change("F05_A_BED-001", "P2", "add", "Nightstand set: folding rule, notebook, a reading lamp", objects=["desktop_stock on 5A_bed0_ns"], purpose="Signature prop; her notes to the Estate written in bed", acceptance="Detail view")],
         canon=[C_WARD], implementation=apt_impl()),
    area("F05_A_STUDY", G5A, "ORISON", "Nadia's drafting study and the site model", "2.9 x 3.0 m, one window, door from the kitchen", "Nadia Quell",
         ("The plan shelf, the model table with the site model, pins and a mug are installed; this is already the best small room in data. Refine: the model gets a glass case lid (a museum "
          "object, not traffic architecture, per the matrix), the plan shelf's rolls get paper bands, a T-square hangs on a nail, the pinboard carries the one drawing of the room that does not exist."),
         [change("F05_A_STUDY-001", "P2", "refine", "Case lid on the model, bands on the rolls, a T-square", objects=["5A_model (sitemodel), 5A_planshelf, 5A_pins2"], construction="Add a glass case variant to the model (INSPECT), paper bands to the rolls, a T-square on the wall", materials="glass, paper, boxwood", purpose="Matrix: the site model is a hero object", acceptance="Detail views")],
         canon=[C_MATRIX, C_LIFE], proposed_backstory=["The pinned drawing shows a room that is not on the blockout."], implementation=apt_impl()),

    # ------------------------------------------------------------------ 5B
    vestibule("F05_B_VESTIBULE", "5B", G5B, "antenna_experiments", "2.8 x 2.5 m with the bath door opening off it (the B-type variant): coils of aerial wire, insulators in a cigar box, a battery case on charge with a cloth lead to the signal outlet, the flat cap. The aerial wire enters through a drilled hole beside the door (see F05_WEST_HALL-003).",
              extra_changes=[change("F05_B_VESTIBULE-003", "P2", "add", "Battery on charge at the signal outlet", objects=["new: 5B_battery_case (desktop_stock wooden case with two jars) with a cloth lead to the new signal plate"], signal=SIGNAL_YES, purpose="Bible VIII.4 batteries are enormous; entry set antenna_experiments", acceptance="Threshold view")], group_intro=INTRO_5B),
    area("F05_B_MAIN", G5B, "ORISON", "Cal's listening triangle", "6.35 x 5.75 m, one window, openings to the vestibule and the private hall", "Cal Dwyer (20:00: he owns no television; the radio is the television)",
         ("The round dining table and chairs, the wireless table with the story radio, headphones and lead, and the domestic radio are installed. The room should be the listening triangle: the "
          "chair worn toward the radio (hero object), the reel deck the only warm thing on its own table, and the main set at the third point, with the headphones' lead running across the "
          "floor where he dozes; a repair mat on the dining table with a chassis on it (Tuesday's); the tape catalogue on shelves in dated rows, one plain box among them with a courthouse date "
          "(proposed; never audible). The decor profile asks for two works separated enough to feel like call and response, not centred. The player infers a man who keeps moments by never "
          "letting them end, and whose chair faces the wrong way."),
         [change("F05_B_MAIN-001", "P1", "add", "The worn chair facing the radio", objects=["new: 5B_radio_chair (domestic_seating armchair variant with the right arm worn through and the seat dished toward the radio side)"], placement="Facing 5B_story_radio on its wireless table at 1.6 m, back to the window, with the headphones' lead reaching it",
                 construction="Seating variant with a wear mask on the radio-side arm and a headrest grease decal", materials="moquette, oak", wear="the arm facing the radio bald; the other arm barely used", purpose="Hero object the_radio_chair_worn_wrong; contradiction", sources=["game/data/apartment_life_profiles.json"], acceptance="Detail view shows the wear direction"),
          change("F05_B_MAIN-002", "P1", "add", "Reel deck table and the tape catalogue", objects=["new: 5B_deck_table (TableRect05) with asm_reeldeck", "new: 5B_tape_shelf (Shelf01 x2) with dated reel boxes in rows (desktop_stock), one plain box"], placement="Deck table at the third point of the triangle by the private-hall opening; shelves on the wall beside the vestibule opening",
                 construction="Reeldeck RESIST-REFUSE owner per the matrix; shelves with box rows", materials="Bakelite deck, grey card boxes with date tags", signal=SIGNAL_YES, wear="the deck's heads bright; the shelf dust-free in one row's width", purpose="Life profile tape_catalog; Appliance Bible: the reel deck is the only thing warm; web II.1 the Delayed Voice Reel", sources=["design/ORISON_RELATIONSHIP_WEB.md II.1", "design/PROP_SET_INTERACTION_MATRIX.md reeldeck"],
                 preserve="Bible VII.8: the reel is never audible; no playback path", acceptance="Overview reads a triangle of chair, set, deck"),
          change("F05_B_MAIN-003", "P2", "add", "Repair mat on the dining table", objects=["5B_din_t with a cloth repair mat, a chassis, a soldering iron on a tin (desktop_stock)"], purpose="Life profile repair_mat; schedule: Omar re-caps a chassis here on Tuesdays", acceptance="Detail view"),
          change("F05_B_MAIN-004", "P2", "add", "Two works, off-centre", objects=["new: two CharacterMemoryArt frames"], placement="On the window wall, deliberately not centred, 1.0 m apart", purpose="Decor profile: call and response; avoid perfect centering", acceptance="Overview")],
         canon=[C_BIBLE_IV, C_LIFE, C_DECOR, C_APPL, C_WEB, "Bible VII.8 (the empty slot stays empty)"], proposed_backstory=["The Delayed Voice Reel is a plain box among the dated tapes with a courthouse date."], implementation=apt_impl()),
    kitchen("F05_B_KITCHEN", "5B", G5B, "forgets_to_eat", "The range is a stand for radios (two hob radios and the comparison table are installed: correct); the monitor-top is one of the four and holds batteries and film; one bowl, one spoon, the kettle warm.",
            fridge="monitor", extra_changes=[change("F05_B_KITCHEN-003", "P2", "add", "Batteries and film inside the monitor-top", objects=["F05_5B_FRIDGE_01 interior contents: battery cases and film tins (desktop_stock) on the shelves"], construction="Interior contents as owned scenery visible when the leaf opens", purpose="Appliance Bible III: fridge holds batteries and film", preserve="Fridge leaf", acceptance="Open-leaf detail view")]),
    private_hall("F05_B_PRIVATE_HALL", "5B", G5B, "a 1.9 m hall between alcove and kitchen with a wire run along the ceiling to the alcove set; valves in a cigar box on the floor against the wall."),
    area("F05_B_ALCOVE", G5B, "ORISON", "Cal's sleeping alcove", "4.45 x 5.3 m, two windows, door from the private hall", "Cal Dwyer (dozes in the chair; the bed is second choice)",
         ("Bed, nightstand, wardrobe. The hearing aid's cord coiled on the nightstand with its battery case when he does sleep; a bedside set with the dial glowing; the mustard cardigan on the "
          "bedpost; the counterpane barely disturbed because the chair gets most nights."),
         [change("F05_B_ALCOVE-001", "P2", "add", "Bedside set and the aid's coil", objects=["new: DomesticRadio-family bedside set on 5B_abed_ns; desktop_stock coil of cord with a battery case"], signal=SIGNAL_YES, purpose="Wardrobe bible towel state: the aid out, coiled beside him", acceptance="Detail view")],
         canon=[C_WARD, C_LIFE], implementation=apt_impl()),
    bath("F05_B_BATH", "5B", G5B, "single_adult", "The bath opens off the vestibule, not the hall: the receiver, cord and battery case coiled on the shelf, the only image of him without it (wardrobe bible)."),

    # ------------------------------------------------------------------ 5C
    vestibule("F05_C_VESTIBULE", "5C", G5C, "paint_tracked", "2.7 x 2.5 m off the public core: paint-stiff sand-shoes, a smock on the hook, a palette knife on the shelf, ultramarine footprints that fade toward the main room.", group_intro=INTRO_5C),
    area("F05_C_MAIN", G5C, "ORISON", "Iris's living room: the private gallery wall", "6.1 x 5.3 m, one window, openings to vestibule, studio and private hall", "Iris Bell (20:00: stretching canvases, half-watching nothing)",
         ("The dining set, bookshelf, wireless table, colour board, solvents and studies are installed. Decor profile: a private gallery, self and impossible space sharing one clean wall as a "
          "diptych, no utility hardware across faces. The room should keep one clean wall for the diptych (two canvases, a self-portrait and an impossible interior), and let the rest be a "
          "painter's: canvases stretched on the dining table, a stack of stretchers, the colour board, a rag on the radiator. The player infers the performer for an imagined audience, and the "
          "one wall she keeps clean for them."),
         [change("F05_C_MAIN-001", "P1", "add", "The diptych on the clean wall", objects=["new: two CharacterMemoryArt canvases 0.6 x 0.8 m, unframed, 0.3 m apart"], placement="Centred on the wall opposite the window, with no switch, pipe or register across it (the switch F05_C_MAIN_SWITCH is on another wall)", construction="WallArtLaw hooks; canvas edges show tacks",
                 materials="raw canvas edges, oil surface", purpose="Decor profile private gallery; avoid utility hardware across faces", acceptance="Overview reads the pair alone on the wall"),
          change("F05_C_MAIN-002", "P2", "add", "Stretching on the table", objects=["5C_din_t with a half-stretched canvas, a hammer, tacks (desktop_stock); 5C_stretchers (crate family stack)"], purpose="Schedule 20:00 stretching canvases; surface set canvas_storage", acceptance="Detail view"),
          change("F05_C_MAIN-003", "P3", "add", "A rag on the radiator", objects=["cloth family rag over F05_C_RADIATOR_01"], purpose="Cleanliness 0.4; Accord 9", preserve="Radiator valve and vent reach", acceptance="Detail view")],
         canon=[C_LIFE, C_DECOR, C_SCHED], implementation=apt_impl()),
    kitchen("F05_C_KITCHEN", "5C", G5C, "meals_between_coats", "Paint on the handles, a burner used as a brush-drying rack (brushes bristle-up in a tin on the cold burner), the icebox handle thumbed with viridian; the paint-flecked enamel recipe on this range only.",
            extra_changes=[change("F05_C_KITCHEN-003", "P2", "refine", "Paint-flecked enamel and the brush rack", objects=["F05_5C_STOVE_01 with the enamel_paintflecked recipe; desktop_stock brush tin on a cold burner"], purpose="Appliance Bible IV texture identity; III: one burner is a brush-drying rack", preserve="Stove owner", acceptance="Detail view at the range")]),
    private_hall("F05_C_PRIVATE_HALL", "5C", G5C, "a 6.6 m hall: canvases face the wall along it in a row (the hero object's overflow), leaving the 0.8 m route; a drip of ultramarine runs the hall's length."),
    area("F05_C_STUDIO", G5C, "ORISON", "5C studio closet: pigment and solvent store", "3.4 x 2.5 m, opening from the main room, two wardrobes", "Iris Bell",
         ("Two wardrobes: one clothes (overalls, a long cardigan, scarves), one shelved for pigment tins, solvent jars and rolled canvas. Dangerous and ordinary, like a 1928 painter's store."),
         [change("F05_C_STUDIO-001", "P2", "refine", "Second wardrobe as the pigment store", objects=["5C_w1_wardrobe (Wardrobe08) shelved variant with tins and jars"], materials="tin, glass, rolled canvas", purpose="Life profile pigment_station storage", preserve="Leaf motions", acceptance="Open-leaf view")],
         canon=[C_LIFE], implementation=apt_impl()),
    bath("F05_C_BATH", "5C", G5C, "brush_washing", "A painter's basin: turpentine jar, brushes in a tin, pigment stain in the enamel crazing, paint on the taps that never comes off."),
    area("F05_C_BED1", G5C, "ORISON", "Iris's bedroom", "3.3 x 3.8 m, one window", "Iris Bell (sleeps late)",
         ("Bed and nightstand; the overalls tied at the waist by the sleeves over the chair, bare feet with paint on them implied by the paint on the sheet's hem, the scarf off and hair down. "
          "A small canvas on the nightstand, face down."),
         [change("F05_C_BED1-001", "P2", "add", "Overalls on the chair, a face-down canvas", objects=["new: 5C_bed_chair (ChairOak) with overall silhouette; desktop_stock small canvas face down on 5C_bed0_ns"], purpose="Wardrobe bible late-night state; hero object echo", acceptance="Detail view")],
         canon=[C_WARD], implementation=apt_impl()),
    area("F05_C_BED2", G5C, "ORISON", "Iris's painting studio (converted second bedroom)", "3.3 x 3.8 m, one window, door from the private hall", "Iris Bell",
         ("Data gives 5C a second made bed. The profile converts this room: rigid canvas storage, a drying rack, the pigment station, a wash jar, failed work facing the wall, a protected "
          "floor. The window is the reason the studio is here. The player infers a working painter who keeps her failures carefully, faces hidden."),
         [change("F05_C_BED2-001", "P1", "remove", "Remove the second bed and nightstand", objects=["5C_bed1", "5C_bed1_ns"], purpose="Lived-in brief: retain one bed; room conversion painting_studio", sources=["game/data/apartment_life_profiles.json", "art/data/orison_v2/completion_interiors_source.json"], acceptance="No bed; sleeper count one"),
          change("F05_C_BED2-002", "P1", "add", "Easel, pigment station, drying rack, failed canvases facing the wall", objects=["new: 5C_easel (new small native family), 5C_pigment_table (work_tables), 5C_drying_rack (shelf family wall rack), 5C_failed_canvases (crate-family stack of six canvases face to the wall), 5C_wash_jar (desktop_stock), floor drop-cloth (cloth family)"],
                 placement="Easel at the window with the light from the left; pigment table against the inner wall; rack above it; the six canvases leaning face to the wall beside the door, outside the swing; drop cloth under the easel",
                 dimensions="easel 1.7 m high; canvases 0.5 to 0.8 m", construction="One new easel family (Blender) with an INSPECT owner; the rest from existing families; the canvases' backs show stretcher bars and one pencilled mark each (no lettering)", materials="pine, raw canvas, tin, glass, a paint-spattered sheet",
                 wear="paint spatter in a fan around the easel's feet; the window sill thick with pigment", lighting="flush dome stays; the window is the light", purpose="Hero object failed_canvases_facing_the_wall; contradiction: the failures are kept, carefully; proposed backstory: portraits of one man", sources=["game/data/apartment_life_profiles.json", "design/CLAUDE_APARTMENT_LIVED_IN_PASS.md"],
                 preserve="Door swing and the route", acceptance="Threshold view from the hall reads a studio; the canvases' faces are not visible from any station")],
         canon=[C_LIFE, C_LIVED, C_WEB], proposed_backstory=["The failed canvases are portraits of one man she stopped letting look."], implementation=apt_impl()),

    # ------------------------------------------------------------------ 5D
    area("F05_D_RESTRICTED", G5D, "ORISON", "5D: vacant after fire damage", "6.15 x 12.65 m shell behind the locked F05_DOOR_05 on the service crossing", "nobody",
         ("A locked, vacant flat with a ruled reason: fire. The interior, reached by teleport, should show the fire only if the shell owner wants it to; the player never enters, so the "
          "evidence belongs on the crossing side: a 1928 replacement leaf in a scorched 1912 frame, soot above the lintel scrubbed to a ghost, a notice, and the acoustic graph giving the flat a "
          "dead node. Keep the interior as authored."),
         [change("F05_D_RESTRICTED-001", "P1", "keep", "Keep the interior as authored", purpose="Intentional vacancy", acceptance="Teleported overview unchanged"),
          change("F05_D_RESTRICTED-002", "P2", "add", "Fire evidence on the crossing side", objects=["F05_DOOR_05 leaf: 1928 replacement variant (fresher paint) in a frame with a scorch decal at the head; a soot-ghost decal fan above the lintel; a notice frame"], placement="Crossing side; soot fan 0.8 m wide above the lintel", construction="Decals on the fitted casing and plaster; door variant swap if the fitted_door family has a 'replacement' finish",
                 materials="new oak leaf under cream paint; scorched 1912 frame", purpose="Bible VIII.5.h: 1912 fabric under 1928 rooms; Accord 13 retrofit timeline; the purpose text says fire damage and nothing shows it", sources=["art/blender/door_fabric / fitted door family", "design/walkthrough_punchlist.md (D units)"], preserve="Lock state", acceptance="Threshold view from the crossing")],
         canon=[C_BIBLE_VIII5H, C_ACCORDS], implementation={"sources": ["game/data/orison_v2/upper_floor_programs.json (disposition fire_damaged)"], "dependencies": "none", "preserved": "Locked state", "acceptance": "Door tests unchanged"}, coverage="inaccessible_teleported"),
]
