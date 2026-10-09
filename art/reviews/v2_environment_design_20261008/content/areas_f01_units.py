"""F01 apartments: 1A Evelyn Marsh and 1D Teresa Vale."""
from _common import *

G1A = "F01 / 1A Evelyn Marsh"
G1D = "F01 / 1D Teresa Vale"

INTRO_1A = ("<b>Evelyn Marsh, 1A.</b> Retired teacher, plum cardigan, red pencil; the wound is that care became correction (Bible IV). Canon gives the flat formal balance, "
            "a marking desk, a tea service, corrected grocery lists, a medication organizer as the hero object and one contradiction: a spare guest cup, never once used. "
            "Her schedule is the building's clock: breakfast at a properly set table with the radio news, the bodega at 07:00, the lobby noticeboard red-pencilled at 08:30, "
            "the bake-and-deliver round on Saturdays, Peter intercepted at the mail bank at 18:00, radio quiz programmes corrected aloud in the evening, lights out by 23:00. "
            "The wardrobe bible adds the pre-war silhouette (hems never shortened, hair never cut) and a thin gold wedding band she has not removed since 1901. "
            "<i>Proposed backstory:</i> she married in 1901, fought the Board of Education's ban on married women teachers and kept her post; the permission letter is framed beside "
            "her retirement certificate (the decor profile's orderly pair); she was widowed before the war and the one photograph in the flat is his, because photographs are dear here. "
            "Her 1954 class register (web I) sits on the study shelf with one name underlined twice: Peter Wren's (web II.6). "
            "<b>Build state:</b> 1A is one of the six completion-interior homes furnished from 5C templates (a bed, a wardrobe, a table, a chair, a WC and a sink support) with flush domes "
            "in every room and no radio, no reading chair and no desk. It is spatially proven and visually anonymous.")

INTRO_1D = ("<b>Teresa Vale, 1D.</b> Night nurse at St. Adjutor's, navy scrubs and cape, a dented thermos and a fob watch; the wound is that rest summons alarms (Bible IV). "
            "She sleeps ten to five, shops on the way home in yesterday's uniform, and her flat is a sparse threshold with the night-shift memory deeper inside (decor profile). "
            "Canon: the silenced alarm clock as hero object, blackout curtains and a bell she cannot unplug as the contradiction, cleanliness 0.55, thermos and leftovers in the kitchen, "
            "the office converted to a night-shift station, a hamper and an exhausted half-finished meal (lived-in brief). She is Mina's mother one floor down (web II.4); their hours "
            "never overlap, and she was on the custody ward the night Price died (web II.1). <i>Proposed backstory:</i> the bell she cannot unplug is a 1912 Vantry house bell "
            "wired before the building had tenants, the only one still connected; she moved the alarm clock to the icebox top the first week and has not touched it since. "
            "<b>Build state:</b> 1D was furnished from 2B's templates and carries Lena's fabric worktable, pattern board and two fabric shelves. A night nurse's flat currently reads as a "
            "seamstress's workroom; this is the single largest legibility defect among the eighteen homes and it is a data copy, not a design.")

AREAS = [
    # ------------------------------------------------------------------ 1A
    vestibule("F01_A_VESTIBULE", "1A", G1A, "orderly_teacher",
              "The entry opens straight off the lobby (F01_A_ENTRY_DOOR connects F01_LOBBY), so Evelyn's threshold is the most public threshold in the building: her door mat is the one the whole lobby sees, and it is the cleanest. Three doors (main, private hall, lobby) leave one wall for the landing set.",
              extra_changes=[change("F01_A_VESTIBULE-003", "P2", "add", "The corrected notice on the back of the door", placement="Pinned on the inside face of the entry leaf at 1.5 m, clear of the knob",
                                    construction="One pinboard-family object (DomesticObject00 pinboard variant, 0.3 x 0.4 m) with two blank card rectangles and one red pencil line decal; no lettering",
                                    purpose="Her habit of correcting the building's notices starts at her own door (schedule: notices red-pencilled); the lobby reads it when the door is open",
                                    preserve="Door leaf collision and swing", acceptance="Visible in the threshold view from the lobby with the door opened by the ordinary interaction")],
              evidence={"limits": "1A entry is reached from the lobby, not a hall; the threshold view is from the lobby side."}),
    area("F01_A_MAIN", G1A, "ORISON", "Evelyn's living room: the marking table and the properly laid tray", "7.45 x 3.35 m front room off the vestibule, one window to the street side, doors to the kitchen and the bedroom", "Evelyn Marsh; the player on the Saturday bake round",
         ("A long, narrow front room with one window. Today it holds a 5C-template table and chair and a radiator. It should hold a teacher's living room arranged in formal balance: "
          "the dining table set for one with a tray cloth and the good cup, the second cup on the dresser that nobody has used, a reading chair by the window with a floor lamp, a wireless on its table "
          "with the quiz programme she corrects aloud, and the two framed documents centred on the long wall as a pair. Everything is pre-war in cut and immaculate in keeping; the "
          "wear is the wear of thirty-one years of care, not of neglect: the chair arm polished by one hand, the table edge where the marking pencil rests, a rub on the floor where the "
          "chair is pulled out at exactly the same angle twice a day. The player should infer a woman who still keeps school hours for nobody, and who corrects the world because "
          "she cannot stop caring for it."),
         [change("F01_A_MAIN-001", "P1", "add", "Wireless table and domestic radio", objects=["new: 1A_wireless_table (TableRect07)", "new: DomesticRadio_1A"],
                 placement="Against the wall opposite the window, 0.4 m from the bedroom door jamb, radio centred on the table facing the reading chair",
                 dimensions="TableRect07 as installed elsewhere (about 0.9 x 0.45 m, 0.75 m high)", construction="Reuse the shared native table variant and the DomesticRadio family with support id on the new table",
                 materials="walnut veneer table, Bakelite radio with a cloth grille and cloth-braided flex to the signal outlet", wear="dust shadow around the radio's feet, the dial knob polished",
                 purpose="Schedules: radio news at breakfast and quiz programmes in the evening; the Bible gives everyone sound and no television", signal=SIGNAL_YES,
                 sources=["game/data/orison_v2/domestic_radios.json", "game/scripts/building/orison_v2_domestic_radios.gd", "art/blender/household_objects_radios.md"],
                 preserve="FurnitureInteractionPass radio knob/switch owner", acceptance="Reverse view shows the radio lit; the radio operates with E"),
          change("F01_A_MAIN-002", "P1", "add", "Reading chair, floor lamp and the marking surface", objects=["new: 1A_reading_chair (domestic_seating armchair variant)", "new: 1A_lamp (task lamp 'office_green' variant on a floor stand or the existing landlord_enamel variant)", "existing: 1A_table, 1A_chair"],
                 placement="Chair angled 30 degrees to the window with its back to the kitchen door; lamp behind its outer arm; the existing table moved to the centre of the long wall as the marking table with its chair square to it",
                 dimensions="chair about 0.8 x 0.85 m; lamp 1.5 m high; table as installed", construction="Seating from the domestic_seating family; lamp from the task_lamps family with a cloth cord to a floor outlet per G14's source plan",
                 materials="moquette upholstery worn to the weave on the right arm, oak frame; green glass shade", wear="one arm polished, the seat cushion dished on one side only", lighting="the lamp is the room's second practical; flush dome stays",
                 purpose="Her two stations: the chair for the radio and ironing, the table for marking (daily loops: tea, mark, tidy)", sources=["art/blender/domestic_furniture.md", "art/blender/task_lamps.md", "game/data/orison_v2/task_lamp_supply.json"],
                 preserve="Route from vestibule to bedroom and kitchen doors; radiator valve reach", acceptance="Overview from the vestibule door reads chair, lamp, table and radio as one arranged room"),
          change("F01_A_MAIN-003", "P1", "add", "The orderly pair: retirement certificate and the married-teacher permission", objects=["new: two framed documents (CharacterMemoryArt / WallArtLaw hook)"],
                 placement="Centred on the long wall opposite the window at 1.55 m, 0.6 m apart, symmetrical about the marking table", dimensions="each 0.35 x 0.45 m",
                 construction="Two framed paper rectangles with an embossed seal shape and a signature stroke; no readable lettering (texture rule); hung through WallArtLaw",
                 materials="black-painted frame, foxed paper, a ribbon seal", purpose="Decor profile: retirement proof and hard-won permission treated as an orderly pair. Proposed backstory: the 1904 Board letter permitting a married woman to keep teaching",
                 sources=["design/resident_decor_profiles.json", "game/scripts/props/character_memory_art.gd"], acceptance="Detail view at 1.5 m shows two frames level to the millimetre"),
          change("F01_A_MAIN-004", "P2", "add", "Tea service and the unused second cup", objects=["new: 1A_tea_tray, 1A_cup_good, 1A_cup_spare (desktop_stock)"],
                 placement="Tray on the marking table's far end; the spare cup alone on the wireless table's edge, dust-ringed", construction="desktop_stock pieces seated by support id",
                 materials="porcelain with a gilt line worn at the handle, a tin caddy, a tray cloth", wear="the spare cup has a dust ring and no tea stain; the good cup has both",
                 purpose="The contradiction, in porcelain (life profile; Appliance Bible III)", acceptance="Detail view of the table shows two cups reading differently"),
          change("F01_A_MAIN-005", "P2", "add", "The one photograph", objects=["new: 1A_photo_frame (desktop_stock)"], placement="On the wireless table beside the radio, turned toward the chair",
                 dimensions="0.12 x 0.17 m", construction="Small standing frame with a sepia plate rectangle (no face detail at this scale)", materials="silver-plated frame tarnished at the back",
                 purpose="Bible VIII.4: a photograph is an occasion; proposed backstory: her husband's", acceptance="Visible in the radio detail view"),
          change("F01_A_MAIN-006", "P2", "refine", "Pendant instead of flush dome", objects=["F01_A_MAIN_LT (flush_dome_rise100)"], placement="Same anchor, pendant_shade variant at 2.2 m over the marking table",
                 construction="Swap the fixed_lighting variant to pendant_shade as every other MAIN room has", lighting="same energy; the shade throws the marking table into a pool and leaves the window dark",
                 purpose="The six completion homes are the only main rooms lit by a flush dome; the pendant is the authored family for living rooms", sources=["game/data/orison_v2/fixed_lighting.json", "game/data/orison_v2/room_lighting.json"],
                 acceptance="RoomLumaAudit unchanged; overview shows the pool on the table")],
         canon=[C_BIBLE_IV, C_LIFE, C_DECOR, C_SCHED, C_WARD, C_APPL], proposed_backstory=["The framed permission letter (1904) and the retirement certificate are the orderly pair.", "The photograph on the wireless table is her husband, dead before the war.", "The class register of 1954 is in the study with Peter Wren's name underlined."],
         implementation=apt_impl(extra_sources=["game/data/orison_v2/completion_interiors.json (1A furniture templates to replace)"]), group_intro=INTRO_1A),
    kitchen("F01_A_KITCHEN", "1A", G1A, "proper_meals_for_one", "The kitchen is compact (3.1 x 2.45 m) with the sink on a drainboard and the monitor-top she keeps immaculate; the hall opening lets the kettle be heard from the bath. The ice card convention does not apply: 1A is one of the four electric flats and the neighbours know it.",
            fridge="monitor", extra_changes=[change("F01_A_KITCHEN-003", "P2", "add", "Medication organizer, the hero object", objects=["new: 1A_medication_organizer (desktop_stock)"], placement="On the wall cupboard's lowest shelf at eye height, square to the shelf edge",
                                                    dimensions="0.2 x 0.08 m", construction="A seven-compartment tin with a hinged lid, a paper label rectangle per compartment (no lettering)", materials="japanned tin, paper", wear="the lid hinge bright from daily use",
                                                    purpose="Life profile hero object; the one examine-interaction the lived-in brief allows per unit", sources=["game/data/apartment_life_profiles.json"], acceptance="Detail view at the cupboard shows it; it has an INSPECT card and no state")]),
    private_hall("F01_A_PRIVATE_HALL", "1A", G1A, "the hall between vestibule and bath carries the ironing board folded against the wall and a laundry bag on a hook, because she irons things nobody will see (wardrobe bible)."),
    bath("F01_A_BATH", "1A", G1A, "single_senior_medicated", "The bath rail is hers, not the landlord's: a brass rail screwed into the tile beside the receptor with the screw heads painted to match, the only thing in the flat she fitted herself.",
         extra_changes=[change("F01_A_BATH-003", "P2", "add", "Bath rail fitted by the resident", placement="On the receptor wall at 0.85 m, 0.45 m long, clear of the curtain travel", construction="Native brass rail with two rose fixings in the bath_details family", materials="brass, screw heads painted tile-white", purpose="A senior's own maintenance (Accord 13: her retrofit, her decade)", preserve="Curtain travel and the shower stance", acceptance="Detail view at the receptor")]),
    area("F01_A_BED", G1A, "ORISON", "Evelyn's bedroom: pre-war order", "4.35 x 5.15 m, one window, doors to the main room and the study", "Evelyn Marsh",
         ("A square bedroom with a window, today a template bed and wardrobe. It should be the tidiest bedroom in the building: the bed made with hospital corners, a hand-knitted "
          "bed-sock pair on the counterpane, the plum cardigan on the chair back, a dressing table with a glasses chain and a powder box, the long grey plait's hairpins in a saucer. "
          "The wardrobe holds 1913-length skirts and a felt toque (wardrobe bible: she never shortened her hems). The player infers a woman who dresses fully, every day, though no one will come."),
         [change("F01_A_BED-001", "P1", "add", "Dressing table, chair and the pre-war wardrobe contents", objects=["existing: 1A_bed, 1A_wardrobe", "new: 1A_dressing_table (TableRect05), 1A_bed_chair (ChairDark), 1A_bedside (Nightstand02)"],
                 placement="Dressing table under the window with its mirror against the pier; chair at the bed foot with the cardigan over it; nightstand on the door side of the bed",
                 construction="Shared native furniture variants; the wardrobe's owned garment silhouettes set to long skirts and a toque (household_wardrobes garment set)", materials="oak, a lace runner, a swing mirror",
                 wear="the dressing table top faded in a rectangle where the runner has always been", purpose="Sleep schedule early (life profile); wardrobe bible silhouette", sources=["art/blender/household_wardrobes.md", "art/blender/domestic_furniture.md"],
                 preserve="Wardrobe leaves and route to the study door", acceptance="Overview from the main door shows the three pieces and a clear route to the study"),
          change("F01_A_BED-002", "P2", "add", "Bedside: spectacles, a glass with a dosing spoon, the red pencil", objects=["new: desktop_stock pieces on 1A_bedside"], placement="On the nightstand top", construction="Three small desktop_stock objects seated by support id",
                 materials="glass, nickel spoon, cedar pencil", purpose="Signature prop and medication routine within arm's reach", acceptance="Detail view of the nightstand")],
         canon=[C_WARD, C_LIFE], implementation=apt_impl()),
    area("F01_A_STUDY", G1A, "ORISON", "Evelyn's study: the class register", "3.1 x 2.7 m, one window, entered from the bedroom (F01_A_BED_STORAGE_DOOR)", "Evelyn Marsh",
         ("A small room off the bedroom with a window, authored as quiet work and household storage, and currently empty but for a flush dome. It should be the retired schoolroom: a "
          "narrow desk under the window with a blotter, an ink stand and a jar of red pencils sharpened to the same length, a shelf of class registers in order, a globe or a map rolled on "
          "its rod, a trunk of lesson plans and tea tins (story panel), and the ironing board's home. The player infers thirty-one years in one classroom, kept in order in one small room."),
         [change("F01_A_STUDY-001", "P1", "add", "Desk, chair and the register shelf", objects=["new: 1A_study_desk (work_tables family or TableRect05), 1A_study_chair (ChairDark), 1A_register_shelf (Shelf01)"],
                 placement="Desk under the window; shelf on the wall facing the door at 1.2 m; chair between", dimensions="desk about 1.1 x 0.6 m", construction="Shared native variants; the shelf's bookpile objects from desktop_stock with one register pulled forward 30 mm",
                 materials="oak, green blotter, foxed cloth bindings", wear="the desk edge worn pale where a wrist rests", lighting="flush dome; a candle stub in a tin on the shelf for the 1912 fabric's sake", purpose="Daily loop: mark; story panel: old lesson plans",
                 sources=["art/blender/work_tables.md", "art/blender/domestic_storage.md", "art/blender/desktop_stock.md"], preserve="Door swing from the bedroom", acceptance="Threshold view from the bedroom door reads a study"),
          change("F01_A_STUDY-002", "P2", "add", "The 1954 register with one name underlined twice", objects=["new: 1A_register_open (desktop_stock papers variant)"], placement="Open on the desk under the blotter edge",
                 construction="An open ledger with ruled line decals and one double red underline decal; no letters", purpose="Web II.6 (the Red Pencil) made an object; proposed backstory", sources=["design/ORISON_RELATIONSHIP_WEB.md II.6"],
                 acceptance="Detail view at the desk shows the double line"),
          change("F01_A_STUDY-003", "P3", "add", "Tea tins and the trunk of lesson plans", objects=["new: 1A_trunk (crate family), tins (desktop_stock)"], placement="Trunk against the wall beside the door, tins stacked on it", materials="tin-plate trunk with brass corners, printed tea tins (colour fields only)",
                 purpose="Story panel detail: retirement tea tins and lesson plans", acceptance="Visible in the reverse view")],
         canon=[C_STORY, C_LIFE, C_WEB], proposed_backstory=["The 1954 class register with Peter Wren's name underlined twice."], implementation=apt_impl()),

    # ------------------------------------------------------------------ 1D
    vestibule("F01_D_VESTIBULE", "1D", G1D, "work_shoes_ready",
              "1D's entry is on the service hall (F01_D_ENTRY_DOOR connects F01_SERVICE_HALL), not the lobby: she leaves and returns by the back of the building at 22:00 and 07:40, past the staff restroom, and never sees the lobby crowd. The vestibule is 2.0 x 2.7 m with an opening to the main room; one wall only.",
              extra_changes=[change("F01_D_VESTIBULE-003", "P2", "add", "The quiet sign near departure", placement="On the wall beside the entry door at 1.4 m, the first thing seen leaving", dimensions="0.2 x 0.15 m",
                                    construction="A small card in a frame with a single hand-drawn stroke (no lettering) and a hook under it for the fob watch", purpose="Decor profile: the quiet sign near departure; the fob watch lives here when she is home (wardrobe bible)",
                                    acceptance="Threshold view from the service hall shows card and hook")], group_intro=INTRO_1D),
    area("F01_D_MAIN", G1D, "ORISON", "Teresa's living room: the night station, not a sewing room", "4.15 x 4.5 m, one window, openings to the vestibule and the private hall", "Teresa Vale",
         ("The main room currently carries 2B's furniture by data copy: a fabric worktable, a pattern board and a dining set. None of it is Teresa's. The room should be the night-shift "
          "station the profile converts her office into (1D has no office in V2, so the station lives here): a daybed or the second chair where she collapses at 07:40, the blackout "
          "blind down at four in the afternoon, the thermos station on the wireless table, a drawer of alarm clocks and medicine, a laundry hamper of uniform cloth, a half-finished plate "
          "under a cloth. Sparse, pinned, nothing loose. The player infers a woman who sleeps in daylight and lives in a room arranged against the light."),
         [change("F01_D_MAIN-001", "P1", "remove", "Remove the seamstress copies", objects=["1D_fabric_worktable (TableRect05)", "1D_story_pattern_board", "1D_fabric_shelf_01, 1D_fabric_shelf_02 (private hall)"],
                 placement="n/a", construction="Delete the 2B-template records from completion_interiors source for 1D and re-project", purpose="A night nurse's flat must not read as a seamstress's; Lena's trade belongs to 2B alone",
                 sources=["art/data/orison_v2/completion_interiors_source.json", "tools/build_v2_authoring_projection.py"], preserve="Route, radiator, radio table", acceptance="Overview shows no cutting table or pattern board"),
          change("F01_D_MAIN-002", "P1", "add", "The night station", objects=["new: 1D_daybed (domestic_seating sofa variant Sofa195 with a blanket)", "new: 1D_alarm_drawer (small chest, domestic_storage)", "existing: 1D_wireless_table, 1D_din_t, chairs"],
                 placement="Daybed along the wall away from the window; chest beside its head; wireless table as the thermos station at the daybed's foot; dining table against the window pier with one chair",
                 construction="Shared native variants; a folded blanket and uniform apron silhouettes from the cloth family", materials="moquette, grey army blanket, deal chest", wear="the daybed cushion crushed at one end only; a ring on the chest top from the thermos",
                 lighting="pendant as authored; the blackout blind on the window (W-GLAZE family) down", purpose="Life profile: office becomes night_shift_station; sleep_schedule days", sources=["game/data/apartment_life_profiles.json", "art/blender/domestic_furniture.md", "art/blender/wet_cloth / cloth batch (B4)"],
                 preserve="Radiator reach and the opening to the hall", acceptance="Overview from the vestibule reads a day-sleeper's room"),
          change("F01_D_MAIN-003", "P1", "add", "Domestic radio for 1D", objects=["new: DomesticRadio_1D on 1D_wireless_table"], placement="On the existing wireless table", construction="DomesticRadio family, support id 1D_wireless_table", signal=SIGNAL_YES,
                 purpose="Six homes have no radio; the Bible gives everyone sound", sources=["game/data/orison_v2/domestic_radios.json"], acceptance="Radio present and operable"),
          change("F01_D_MAIN-004", "P2", "add", "The call bell she cannot unplug", objects=["new: 1D_house_bell (fixed wall bell, Bakelite dome on a brass base) with cloth flex to the signal outlet"],
                 placement="High on the hall-opening wall at 2.2 m, flex running visibly down to the signal plate", dimensions="dome 0.1 m", construction="Small native part in the fixed_lighting / signal family; no light; INSPECT card only",
                 materials="Bakelite, brass, cloth flex gone grey", wear="the flex taped where she tried to cut it", signal=SIGNAL_YES, purpose="Life profile contradiction: blackout curtains, and a bell she cannot unplug; proposed backstory: a 1912 Vantry house bell",
                 sources=["design/ORISON_BIBLE.md VIII.3", "game/data/apartment_life_profiles.json"], acceptance="Detail view at the opening wall shows bell and flex; no sound added here (the case owns it)"),
          change("F01_D_MAIN-005", "P2", "add", "Thermos station and half-finished meal", objects=["new: desktop_stock: dented vacuum flask, a plate under a cloth, a nickel kettle on the table"], placement="On the wireless table and the dining table",
                 materials="dented nickel, enamel plate, muslin", purpose="Story panel: thermos station; lived-in brief: exhausted half-finished meal", acceptance="Detail views of both tables")],
         canon=[C_LIFE, C_STORY, C_DECOR, C_WARD, C_WEB], proposed_backstory=["The bell is a 1912 Vantry house bell, the only one still connected."], implementation=apt_impl(extra_sources=["game/data/orison_v2/completion_interiors.json (1D copies of 2B furniture)"])),
    kitchen("F01_D_KITCHEN", "1D", G1D, "thermos_and_leftovers", "A B-type kitchen with its own door off the private hall. The alarm clock on the icebox top is the hero object: silenced, where she cannot hear it from bed.",
            extra_changes=[change("F01_D_KITCHEN-003", "P1", "add", "The silenced alarm clock on the icebox top", objects=["new: 1D_alarm_clock (desktop_stock) on F01_1D_FRIDGE_01"], placement="Icebox top, back corner, face to the wall",
                                                   dimensions="0.1 m dial", construction="A folding travelling alarm or bell-top clock from the desktop_stock family; INSPECT card; no signal (it is a wound clock)", materials="nickel case, cream dial without numerals",
                                                   purpose="Life profile hero object and Appliance Bible III line", sources=["game/data/apartment_life_profiles.json"], preserve="Fridge leaf and ice door travel", acceptance="Detail view at the icebox shows the clock turned away")]),
    area("F01_D_BED", G1D, "ORISON", "Teresa's bedroom: daylight blacked out", "3.3 x 4.0 m, one window, door from the private hall", "Teresa Vale",
         ("A small bedroom with a window and a 2B-template bed and wardrobe. It should be a day-sleeper's room: blackout blind and a blanket pinned over it besides, the bed made once and "
          "slept in at the wrong hours, the uniform dress on a hanger on the wardrobe door with the collar unpinned, a man's cardigan over the chair, nothing visually loud beside the bed "
          "(decor profile). The player infers the hours by the window, not by a clock."),
         [change("F01_D_BED-001", "P1", "add", "Blackout and the uniform on the door", objects=["existing: 1D_abed, 1D_aw_wardrobe", "new: blackout blanket over the blind (cloth family), uniform silhouette on the wardrobe leaf, 1D_bed_chair (ChairDark)"],
                 placement="Blanket pinned across the window head; uniform hung on the wardrobe's outer leaf; chair at the bed foot", construction="Cloth family pieces with sewn edges (B4); the wardrobe garment set navy and starched white",
                 materials="navy wool cape lining showing scarlet, grey-blue cotton, a grey blanket", wear="the blind's cord worn, the blanket's pins rusting the wall", lighting="flush dome; the room is dark by design in daylight", purpose="Sleep schedule days; wardrobe bible late-night state",
                 sources=["art/blender/household_wardrobes.md", "game/data/apartment_life_profiles.json"], preserve="Wardrobe leaves, bed stance", acceptance="Overview with the blind down reads as a day-sleeper's room"),
          change("F01_D_BED-002", "P2", "add", "Bedside with the fob watch hook and ear plugs", objects=["new: 1D_bedside (Nightstand01) with desktop_stock: a saucer of wax ear plugs, a glass, the fob watch on a hook"], placement="Nightstand on the window side of the bed",
                 materials="deal, nickel", purpose="Wardrobe bible: she times things without deciding to; the quiet beside the bed", acceptance="Detail view of the nightstand")],
         canon=[C_LIFE, C_DECOR, C_WARD], implementation=apt_impl()),
    private_hall("F01_D_PRIVATE_HALL", "1D", G1D, "a laundry hamper of uniform cloth stands by the bath door (the fabric shelves copied from 2B are removed under F01_D_MAIN-001); the hall is the route from the service door to bed at 07:40 and should carry the wear of that single line.",
                 extra_changes=[change("F01_D_PRIVATE_HALL-002", "P1", "remove", "Remove 2B's fabric shelves", objects=["1D_fabric_shelf_01", "1D_fabric_shelf_02"], purpose="Seamstress storage does not belong in the nurse's hall", sources=["art/data/orison_v2/completion_interiors_source.json"], acceptance="Hall shows a hamper, not fabric shelves")]),
    bath("F01_D_BATH", "1D", G1D, "shift_worker", "The bath has a window (one of the few), so the blackout extends here: a towel pegged across it. The collar and cuffs soaking in the basin are the only white things in the room.",
         extra_changes=[change("F01_D_BATH-003", "P2", "add", "Collar and cuffs soaking; towel over the window", objects=["new: desktop_stock soaking bowl with collar silhouettes; cloth family towel pegged on the window"], placement="Bowl in the basin; towel across the window head",
                               materials="starched linen, huckaback", purpose="Wardrobe bible: unpinning them is a decision; sleep schedule", preserve="Basin stance and tap cycle", acceptance="Detail at the basin")]),
]
