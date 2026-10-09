"""Shared helpers for the dossier content modules.

Every area entry is a dict with the keys the builder expects. Family helpers
below produce the repetitive rooms (bathrooms, vestibules, private halls,
kitchens, circulation) from a standard narrative plus the per-resident delta
that makes the room theirs. Nothing here is canon by itself: canon is cited in
`canon`, additions are listed under `proposed_backstory`, and every change is
a proposal with a stable id `<SPACE_ID>-nnn`.

Priority: P1 = reads wrong from the doorway or breaks the resident's legibility;
P2 = strengthens the room's story or period truth; P3 = polish.
Action: add | move | refine | remove | keep.
"""

SIGNAL_YES = "carries signal: Rule of Signal applies (forty years early, Bakelite/brass/cloth flex, repairable)"
SIGNAL_NO = "no signal: 1927 vintage, second-hand, probably a bit broken"

# canon references used across rooms (short tags; the dossier front matter expands them)
C_BIBLE_III = "Bible III (building: brass mail bank, dog-leg stair, one lift, light court, Vantry points)"
C_BIBLE_IV = "Bible IV cast table (identity, face, wound)"
C_BIBLE_VIII2 = "Bible VIII.2 Rule of Signal"
C_BIBLE_VIII4 = "Bible VIII.4 technology quirks (Bakelite, cloth flex, valves, ice and coal, no aluminium)"
C_BIBLE_VIII5A = "Bible VIII.5.a fridges are a mix (iceboxes most; electric monitor-top four flats)"
C_BIBLE_VIII5B = "Bible VIII.5.b Vantry points are listeners, no smoke detectors"
C_BIBLE_VIII5C = "Bible VIII.5.c one-pipe steam heat, 1912 coal boiler"
C_BIBLE_VIII5D = "Bible VIII.5.d basement laundry: two wringer washers, two rinse tubs, ceiling airer, no dryer"
C_BIBLE_VIII5E = "Bible VIII.5.e lobby master clock four minutes fast; 4B drop-octagon clock; witness clocks"
C_BIBLE_VIII5F = "Bible VIII.5.f / Wardrobe Bible (1927 clothes, mostly older)"
C_BIBLE_VIII5H = "Bible VIII.5.h 1912 fabric, 1927 demolition, 1928 reopening; residents moved in within twelve months"
C_BIBLE_VIII5I = "Bible VIII.5.i bathrooms share four roof ventilators; painted gravity registers"
C_ACCORDS = "Bible VII.9-15 Harukiya Accords (decay outranks spectacle; nothing floats; wear is positional; retrofits read as a timeline; Shenmue test; light is practical)"
C_LIFE = "apartment_life_profiles.json (sets, hero object, contradiction, cleanliness)"
C_STORY = "resident_story_details.json (story panel detail)"
C_DECOR = "design/resident_decor_profiles.json (composition principle)"
C_WEB = "design/ORISON_RELATIONSHIP_WEB.md (tentative threads)"
C_SCHED = "game/data/resident_schedules.json (routines)"
C_APPL = "design/ORISON_APPLIANCE_BIBLE.md"
C_WARD = "design/ORISON_WARDROBE_BIBLE.md"
C_LIVED = "design/CLAUDE_APARTMENT_LIVED_IN_PASS.md (per-unit intent, essential-life layer, kits)"
C_ENTROPY = "TASKS.md section E (E2: inherited patina stays baked, accrued grime is simulated; E10 three appliance states)"
C_MATRIX = "design/PROP_SET_INTERACTION_MATRIX.md (OPERATE / INSPECT / RESIST-REFUSE / AMBIENT rulings)"
C_SHOPS = "design/SHOP_INTERIOR_BUILD_GUIDE.md"
C_BAR = "docs/harukiya_reference_notes.md (CANONICAL / INFERRED / NYC ADAPTATION / NECESSITY ledger and the 2026-08-16 amendments)"
C_OWNER = "art/data/v2_owner_improvement_20261008.json (work completed or underway)"
C_COMMENSALS = "design/ORISON_COMMENSALS_BRIEF.md (C1 landed: moths at the entry lamps, riser mice audio on one F02 run, one 4B kitchen roach scatter, one weed cluster)"

RESIDENT = {
    "1A": "Evelyn Marsh", "1D": "Teresa Vale", "2A": "Mina Vale", "2B": "Lena Ortiz", "2C": "Juno Kells",
    "3A": "Malcolm Reed", "3B": "Omar Bell", "3D": "Rhea Sato", "4A": "Peter Wren", "4B": "the player",
    "4C": "Cam Ortiz and Noel Price", "4D": "the Transient Guests", "5A": "Nadia Quell", "5B": "Cal Dwyer",
    "5C": "Iris Bell", "6A": "Sacha Reed", "6B": "Jonah Price", "6C": "Mae Kessler",
}

def change(id, priority, action, title, objects=None, placement="", dimensions="", construction="", materials="",
           wear="", lighting="", sound="", purpose="", sources=None, dependencies="", preserve="", acceptance="", signal=SIGNAL_NO):
    d = {"id": id, "priority": priority, "action": action, "title": title, "objects": objects or [], "placement": placement,
         "dimensions": dimensions, "construction": construction, "materials": materials, "wear": wear, "lighting": lighting,
         "sound": sound, "purpose": purpose, "sources": sources or [], "dependencies": dependencies, "preserve": preserve,
         "acceptance": acceptance, "signal": signal}
    return {k: v for k, v in d.items() if v not in ("", None, [])}

def area(id, group, zone, title, location, users, narrative, changes, canon=None, proposed_backstory=None,
         implementation=None, evidence=None, coverage=None, captions=None, group_intro=None, capture_ids=None, level=None):
    d = {"id": id, "group": group, "zone": zone, "title": title, "location": location, "users": users,
         "narrative": narrative, "changes": changes, "canon": canon or [], "proposed_backstory": proposed_backstory or [],
         "implementation": implementation or {}, "evidence": evidence or {}}
    if coverage: d["coverage"] = coverage
    if captions: d["captions"] = captions
    if group_intro: d["group_intro"] = group_intro
    if capture_ids: d["capture_ids"] = capture_ids
    if level: d["level"] = level
    return d

APT_SOURCES = ["game/data/orison_v2_blockout.json (anchors, rects, doors, windows)",
               "art/data/orison_v2/completion_interiors_source.json and upper_floor_programs_source.json (authored unit programs)",
               "game/data/orison_v2/domestic_surface_props.json, domestic_fittings.json, household_accessories.json, bath_details.json (support-relative small objects)",
               "art/blender/scripts/build_domestic_objects.py, build_desktop_stock.py, build_household_wardrobes.py, build_domestic_storage.py (native families: extend, do not fork)",
               "game/scripts/building/orison_v2_completion_interiors.gd and orison_v2_domestic_*.gd (installation owners)"]

def apt_impl(extra_sources=None, dependencies="", preserved="", acceptance=""):
    return {"sources": APT_SOURCES + (extra_sources or []),
            "dependencies": dependencies or "Blender native batch per family (art/blender/v2_batch_workflow.md); one composed OrisonV2FabricationBatch run with the touched modules; no new MatLib key without the catalogue; Label3D for any lettering.",
            "preserved": preserved or "Every existing interaction owner (taps, cabinets, switches, radiator valve, wardrobe leaves, bookshelf panel), the clear 0.8 m circulation route from entry to bed, bath and kitchen, door swings and the authored window light; resident route anchors unchanged.",
            "acceptance": acceptance or "Threshold view from the entry door identifies the resident without a label; overview and reverse views show the three ordinary-life clues, two character clues and the one contradiction; no new prop inside a door swing or the 0.8 m route; OrisonV2CompletionInteriorsTest / OrisonV2ApartmentDoorRouteTest and the household save tests stay green."}

# ----------------------------------------------------------------- bathroom family
BATH_SETS = {
    "single_senior_medicated": "a senior's medicated routine: the medicine cabinet is the full one, a glass with a dosing spoon on the basin, a bath rail she fitted herself and keeps polished",
    "shift_worker": "a night worker's bathroom used at the wrong hours: towel never fully dry, blackout against the light-slot, uniform collar soaking in the basin",
    "single_adult_exact": "a single adult who keeps things exact: one toothbrush, one glass, towel squared on the rail, nothing on the floor",
    "single_adult": "a single adult's ordinary use: one of everything, a second towel that is really a floorcloth",
    "single_adult_practical": "a practical single adult: a nail brush, a pumice, carbolic soap, a shaving mirror hung where the light actually falls",
    "voice_care": "a singer's throat routine: steam kettle on the floor, a jar of pastilles, a mentholated inhaler, two glasses (gargle and rinse)",
    "two_adults_divided": "two adults who do not share: two of everything on opposite sides, two towels on separate hooks, a tape line nobody admits to",
    "rental_minimal": "a short-let bathroom: hotel-issue soap, one thin towel each, a house-rules card about the bath, nothing of anybody's",
    "brush_washing": "a painter's basin: turpentine jar, brushes bristle-up in a tin, pigment stain in the enamel crazing, a rag on the taps",
}

def bath(sid, unit, group, bath_set, delta, extra_changes=None, location="", coverage=None, evidence=None, captions=None, group_intro=None):
    who = RESIDENT[unit]
    desc = BATH_SETS.get(bath_set, bath_set)
    nar = (f"Every V2 bathroom is a windowless 1928 reopening room on one of the four roof ventilators: a painted gravity register, "
           f"a cast-iron tub or shower receptor, a pedestal basin, a mirror medicine cabinet and a flush dome. What makes this one {who}'s is "
           f"{desc}. {delta} The room should pass the Shenmue test at the basin: evidence of construction (the register and its painted-over screws), "
           f"attachment (the cabinet's two fixings), use (the wiping arc on the mirror), age (crazed enamel, a hairline in the tile), maintenance "
           f"(a replacement chain on the plug) and consequence (a water line on the floor where the curtain leaks).")
    base = [
        change(f"{sid}-001", "P2", "refine", f"Resident bath set for {who}", objects=[f"{unit}_soap_dish", f"{unit}_hand_towel", f"{unit}_toilet_roll", f"F0{unit[0]}_{unit}_MIRROR_01 (medicine cabinet)"],
               placement="On the basin rim and the cabinet shelves, inside the existing bath_details supports; towel on the existing rail or on a new 300 mm brass hook beside the basin if no rail exists",
               construction="Small desktop-stock objects in the existing desktop_stock family (max 6 per bathroom), seated by support id, no new owner",
               materials="porcelain, nickel-plated brass, huckaback cotton; enamel with fine crazing", wear="wiping arc at eye height on the mirror, soap ring on the dish, a chip on the basin rim at the tap side",
               lighting="flush dome as authored; no added light", purpose=f"Reads as {who}'s routine, not a generic bathroom", sources=["game/data/orison_v2/bath_details.json", "game/data/orison_v2/household_accessories.json", "art/blender/desktop_stock.md"],
               preserve="TapProp cycle, curtain area, MedicineCabinetProp leaf and the I-key care inspection reach", acceptance="Detail view from the door shows the set without obstructing the basin stance"),
        change(f"{sid}-002", "P3", "refine", "Positional wear and water consequence", placement="Floor at the receptor edge and the wall at the register",
               materials="existing wet_cloth / local drain finish masks (B4 cloth batch) extended with a 0.4 m water line decal under the curtain hem", wear="darkened grout line along the receptor, paint lifted below the register, the mop-shadow corner the mop cannot reach",
               purpose="Accord 12: wear follows use; Accord 14: consequence within two metres", sources=["art/blender/scripts/owner_finish_materials.py (localized drain finish)", "game/data/orison_v2/owner_finish_profiles.json"],
               dependencies="E2: inherited patina baked; accrued grime simulated later by section E; author only the inherited layer here"),
    ]
    return area(sid, group, "ORISON", f"{who}'s bathroom", location or f"Private bathroom off the unit's private hall", who, nar, base + (extra_changes or []),
                canon=[C_BIBLE_VIII5I, C_LIFE, C_ACCORDS], implementation=apt_impl(), coverage=coverage, evidence=evidence, captions=captions, group_intro=group_intro)

# ----------------------------------------------------------------- vestibule family
ENTRY_SETS = {
    "orderly_teacher": "a coat on a proper hanger, galoshes paired toe-out on a drip mat, a corrected shopping list pinned at eye height, an umbrella furled and buttoned",
    "work_shoes_ready": "black laced shoes already pointing at the door, the navy cape on the first hook, a crushed cap, the thermos on the shelf where a hand finds it blind",
    "labeled_everything": "a key board with every hook labelled, a numbered coat hook strip, a wall file of out-letters, a label on the label maker's box",
    "clients_welcome": "a bentwood chair for a waiting client, a mirror, a pincushion on the shelf, a tape measure on the hook and a paper pattern taped to the door back",
    "working_musician": "cable cases stacked against the wall, a man's ulster on the hook, headphones hung by the cable, takeout menus under a magnet on the door",
    "soil_tracked": "a boot scraper, hobnailed boots on newspaper, a trug, soil tracked in a fan from the mat, a flat cap on a nail",
    "boots_and_toolbelt": "boots on a tray, the apron hung in frame with its tools in it, a parts bag, a pegboard of other people's keys with tags",
    "thrift_glam": "a dressing mirror turned to the door, a hat stand with three cloches, a scarf over the mirror corner, a shoe tree",
    "umbrella_and_stamped_shoes": "an umbrella in a drip tray that has overflowed into a tide mark, brown Oxfords with the heel worn on the outside, a hat a size out on the shelf, a stamped envelope not yet posted",
    "operator": "a service cap, the maintenance keyring on a nail, a stack of printed slips under a brass weight, the drip of the carried set's battery case on the mat",
    "bike_vs_gloves": "a bicycle wheel leaning where it should not, a satchel on the floor, and on the other wall a brushed hat and a folded pair of white gloves on a clean shelf",
    "rolling_luggage": "a cardboard case and a gladstone bag that do not match, a railway ticket on the shelf, a hotel-style rules card, no coat hooks in use",
    "measured_egress": "a scale rule and a folded plan on the shelf, a torch, a numbered key ring, a chalk mark on the floor at the door swing's measured limit",
    "antenna_experiments": "coils of aerial wire, insulators in a cigar box, a battery case on charge with a cloth lead to the signal outlet, a flat cap",
    "paint_tracked": "paint-stiff sand-shoes, a smock on the hook, a palette knife on the shelf, ultramarine footprints that fade toward the main room",
    "cases_stacked": "three fibre cases stacked by size, a tripod bag, a soft cap, a strap tangle hung on one hook",
    "bookstore_receipts": "a navy overcoat over pyjama trousers' worth of hooks, bookstore receipts pinned in a fan, unlaced shoes kicked under the shelf",
    "white_gloves_by_the_door": "white cotton gloves on a tray, a buttonhook, a mourning brooch box, a bottle-green coat on a wooden hanger, a card of visiting hours",
}

def vestibule(sid, unit, group, entry_set, delta, extra_changes=None, coverage=None, evidence=None, captions=None, group_intro=None):
    who = RESIDENT[unit]
    desc = ENTRY_SETS.get(entry_set, entry_set)
    nar = (f"The vestibule is the first room the player reads and the one that decides whether the flat belongs to somebody. "
           f"{who} should be legible here before any other room: {desc}. {delta} It is also where the building's own hardware shows: "
           f"the 1912 brass signal outlet beside the later switch plate, the chain guard on the entry door, the painted-over bell push, the Vantry point grille on the ceiling.")
    base = [
        change(f"{sid}-001", "P1", "add", f"Entry landing set for {who}", placement="Along the wall opposite the entry door swing, within 0.9 m of the door, leaving the authored route clear",
               dimensions="hook strip 0.6 m long at 1.65 m; shelf 0.3 m deep at 1.1 m; mat 0.6 x 0.9 m", construction="Entry kit from the shared desktop_stock / domestic_objects families; hooks and shelf as one native assembly per vestibule variant",
               materials="painted pine shelf, iron hooks, coir mat, brass drip tray", wear="scuff fan on the floor inside the door, hand-grime on the door edge at latch height, the wall rubbed by coats at shoulder height",
               lighting="flush dome as authored", purpose="Identify the resident from the threshold (lived-in acceptance criterion)", sources=["game/data/apartment_life_profiles.json entry_set", "art/blender/desktop_stock.md"],
               preserve="Door swing, 0.8 m route, SwitchPlate reach", acceptance="Threshold capture from the hall shows the set; door-route test unchanged"),
        change(f"{sid}-002", "P2", "add", "Building hardware: signal outlet plate and chain guard", objects=["new: brass flush signal-outlet plate beside the switch", "new: chain door guard on the entry leaf"],
               placement="Signal plate 0.15 m beside the existing SWITCH anchor at the same height; chain guard on the leaf at 1.5 m, keeper on the jamb",
               dimensions="plate 70 x 115 mm; chain 0.3 m", construction="Two small native parts in the fixed_lighting / door hardware families; no interaction", materials="brass with a dull lacquer, painted over at one screw",
               purpose="Bible VIII.3: every room has a signal point beside the power socket; Accord 11: one anchor painted over", signal=SIGNAL_YES,
               sources=["art/blender/light_switch.md", "art/blender/door_knob_set.md"], acceptance="Visible in the threshold view at eye height"),
    ]
    return area(sid, group, "ORISON", f"{who}'s vestibule", "Entry from the public hall; distributes to the main room and private hall", who, nar, base + (extra_changes or []),
                canon=[C_LIFE, "Bible VIII.3 (signal point in every room)", C_ACCORDS], implementation=apt_impl(), coverage=coverage, evidence=evidence, captions=captions, group_intro=group_intro)

# ----------------------------------------------------------------- private hall family
def private_hall(sid, unit, group, delta, extra_changes=None, coverage=None, evidence=None, captions=None, group_intro=None):
    who = RESIDENT[unit]
    nar = (f"A short distribution hall between bed and bath. It should not be dressed; it should be used. For {who}: {delta} "
           f"Halls are where the building's stratigraphy shows best because nobody decorates them: 1912 wainscot under 1928 paint, a radiator riser boxed in with a later board, "
           f"a Vantry grille, the door furniture of two eras.")
    base = [
        change(f"{sid}-001", "P2", "refine", "Hall use evidence (one object, not a kit)", placement="Against the wall clear of both door swings and the 0.8 m route",
               construction="One native object from an existing family (hamper, hat stand, folded-laundry shelf or boot tray) by the resident's routine", materials="period-appropriate: painted pine, wicker, tin",
               wear="rub line at hip height where the resident brushes past nightly; floor wear path from bed to bath", purpose="Accord 14 evidence within two metres; keeps the hall a hall",
               preserve="Door swings, route, bedside/bath approach stances", acceptance="Threshold view from the main room shows the hall as used, not empty, with the route visibly clear"),
    ]
    return area(sid, group, "ORISON", f"{who}'s private hall", "Between the main room, bedroom and bathroom", who, nar, base + (extra_changes or []),
                canon=[C_LIFE, C_ACCORDS], implementation=apt_impl(), coverage=coverage, evidence=evidence, captions=captions, group_intro=group_intro)

# ----------------------------------------------------------------- kitchen family
KITCHEN_SETS = {
    "proper_meals_for_one": "one place laid properly at every meal: a tray cloth, the good cup and the second cup that is never used, a tea caddy with a spoon on a string",
    "thermos_and_leftovers": "a dented vacuum flask and a dull nickel kettle, one pan, a plate of yesterday under a cloth, the alarm clock silenced on top of the icebox",
    "measured_portions": "labelled jars in rows, a kitchen scale, a measured half-loaf, the icebox shelves labelled in her own hand",
    "cooks_for_others": "the biggest pots in the building, a stack of borrowed plates with other people's names chalked underneath, a pie dish wrapped to go",
    "takeout_plus_coffee": "the range used as a shelf for tape boxes, a percolator on the only lit burner, takeout cartons folded flat for the bin, a single mug",
    "jars_and_compost": "jars not tins, a compost pail under the sink, seed trays on the sill, the empty memorial pot above the sink holding soil and nothing",
    "simple_and_maintained": "two of every appliance, one working and one half torn down on newspaper with its screws in a saucer; a lid gasket replaced, labelled with the date",
    "tea_honey_lemon": "a kettle, honey, lemons on a saucer, a spotless never-used range, a jar of pastilles, a glass with a gargle spoon",
    "identical_weekday_meals": "identical tins in identical rows, five identical lunch pails, a toaster with a replacement form taped to it that was never filed",
    "kettle_toaster_survival": "a kettle and a toaster on a counter otherwise bare, a tin of biscuits, the landlord's portable fan, slips and carbons under the bread board",
    "quick_food_vs_preserved": "one side of the counter quick food in paper, the other side preserved and labelled; a dead icebox nobody empties; a battered copper kettle both use",
    "inadequate_cookware": "one pan for everything, hotel-issue, a cold icebox with the ice card still in the window, a house-rules card about the gas",
    "efficient_batching": "batch cooking: four identical covered dishes, a corrected floor plan of this building pinned to the icebox door, a tin of candles and matches",
    "forgets_to_eat": "the range as a stand for radios, the icebox holding batteries and film, one bowl, one spoon, the kettle the only warm thing",
    "meals_between_coats": "paint on the handles, a burner used as a brush-drying rack, a plate with a thumbprint of viridian, a loaf going hard",
    "eats_standing": "a counter used as a contact-sheet light table, prints pegged on a string over the sink, a tin of batteries, no chair",
    "cold_drinks_and_rings": "ring stains on every horizontal surface, a wastebasket by the icebox full of paper, cold coffee in three cups, a bread knife in the butter",
    "careful_and_spare": "everything period-correct and nothing after 1935 (which here means nothing after 1927): a Hoosier-type cabinet in order, a covered butter dish, one good knife",
}

def kitchen(sid, unit, group, kitchen_set, delta, extra_changes=None, coverage=None, evidence=None, captions=None, fridge="icebox", group_intro=None):
    who = RESIDENT[unit]
    desc = KITCHEN_SETS.get(kitchen_set, kitchen_set)
    cold = ("an oak icebox with a zinc lining, a drip tray under it that someone has to empty and an ice card in the window" if fridge == "icebox"
            else "an electric monitor-top on splayed legs, new, expensive, noticeably loud, and the neighbours know who has one")
    nar = (f"The kitchen is 1890 while the parlour is 1970 (Bible VIII.4): an enamel gas range on an angle-iron base, a sink with a drainboard, a wall cupboard, "
           f"the sliding preparation cabinet, {cold}. What makes it {who}'s is {desc}. {delta} Light is the kitchen linear or flush dome and the window; "
           f"the Vantry point on the ceiling listens to the kettle.")
    base = [
        change(f"{sid}-001", "P1", "refine", f"Kitchen set for {who}", objects=[f"{unit}_prep_cabinet", f"{unit}_k_wall_cupboard", f"F0{unit[0]}_{unit}_STOVE_01", f"F0{unit[0]}_{unit}_FRIDGE_01", f"F0{unit[0]}_{unit}_KITCHEN_SINK_01"],
               placement="On the preparation cabinet top, the drainboard, the range's cold side and the icebox top, within the existing support ids; nothing on the floor in the cross-passage",
               construction="Surface props from desktop_stock (mugs, dishrack, jars, tins, bread board) selected per kitchen_set; at most 8 pieces, merged per family", materials="enamel (tenant-specific variant), tin, glass jars, porcelain, oilcloth on the cabinet top",
               wear="grease film on the wall behind the range at splash height, a scorched ring on the cabinet top beside the range, worn oilcloth at the working edge", lighting="as authored; the range's pilot is the only new glow and only where the resident cooks",
               purpose="Appliance Bible III: the appliance that tells the truth about the tenant", sources=["design/ORISON_APPLIANCE_BIBLE.md", "game/data/orison_v2/domestic_surface_props.json", "art/blender/desktop_stock.md"],
               preserve="StoveProp oven leaf, FridgeProp leaf and ice door, TapProp cycle, toaster carriage and crumb pan, prep cabinet slide, kitchen cross-passage", acceptance="Overview shows the set from the kitchen opening; no prop within the oven or fridge door sweep"),
        change(f"{sid}-002", "P2", "add", "Ice card and drip tray evidence" if fridge == "icebox" else "Monitor-top electric evidence", objects=[f"F0{unit[0]}_{unit}_FRIDGE_01"],
               placement="Ice card in the kitchen window's lower pane facing out (icebox units); zinc drip tray on the floor under the icebox with a water tide line", construction="Card as Label3D-free coloured rectangle with the number as a painted numeral quadrant (no lettering in texture); tray as a desktop-stock piece",
               materials="card stock, zinc", wear="the tray's tide line and a rust bloom at one corner", purpose="Bible VIII.5.a: which number is showing is a fact about that household", signal=SIGNAL_NO,
               sources=["design/ORISON_BIBLE.md VIII.5.a"], acceptance="Visible in the reverse view; the tray does not enter the fridge door stance"),
    ]
    return area(sid, group, "ORISON", f"{who}'s kitchen", "Off the main room through the kitchen opening", who, nar, base + (extra_changes or []),
                canon=[C_BIBLE_VIII4, C_BIBLE_VIII5A, C_APPL, C_LIFE], implementation=apt_impl(), coverage=coverage, evidence=evidence, captions=captions, group_intro=group_intro)

# ----------------------------------------------------------------- circulation families
def public_hall(sid, group, title, location, users, delta, extra_changes=None, coverage=None, evidence=None, captions=None, group_intro=None, level=None):
    nar = (f"A 1912 public corridor under 1928 paint: wainscot to 1.1 m, a dado rail, the picture rail that survived the demolition, enamel floor plates in both cores, "
           f"a flush dome every few metres and the apartment doors with their transoms. {delta} The halls are where neighbours meet and where the building's own voice is loudest: "
           f"a riser knocks, a door spills light, the lift gate rattles in the shaft.")
    base = [
        change(f"{sid}-001", "P2", "add", "Door-threshold evidence per unit", placement="At each apartment door on the hall side: a mat, a milk bottle or a parcel per the resident's routine, within 0.5 m of the jamb and outside the swing",
               construction="One native object per door from the desktop_stock family (coir mat variants, a milk bottle pair, a string-tied parcel, a folded newspaper)", materials="coir, glass, brown paper",
               wear="the mat's worn centre, the floor varnish gone at the threshold", purpose="The hall tells you who lives behind each door before you knock (schedules: milk, parcels, Evelyn's corrected notices)",
               sources=["game/data/resident_schedules.json", "design/CLAUDE_APARTMENT_LIVED_IN_PASS.md"], preserve="Door swings, the 1.2 m hall route, resident yield radius", acceptance="Overview from the landing reads at least two different households from their thresholds"),
        change(f"{sid}-002", "P3", "refine", "Positional hall wear", placement="Floor centreline and the corner the mop cannot reach; wall at trolley height beside the lift",
               materials="existing public floor finish (A02) with an inherited wear mask only", wear="centreline dulling, a mop-shadow in the corner, the wall scuffed at 0.6 m by the porter's trolley",
               purpose="Accord 12", dependencies="E2: inherited layer only; accrued grime belongs to section E", acceptance="Reverse view shows the wear path aligned with the actual door positions"),
    ]
    return area(sid, group, "ORISON", title, location, users, nar, base + (extra_changes or []), canon=[C_BIBLE_III, C_ACCORDS, C_SCHED], coverage=coverage, evidence=evidence, captions=captions, level=level, group_intro=group_intro,
                implementation={"sources": ["game/data/orison_v2_blockout.json", "game/scripts/building/orison_v2_millwork.gd / art/blender/millwork_profile.md", "art/blender/wayfinding_plate.md"],
                                "dependencies": "Public floor finish owner (A02 pending final review in the owner JSON); desktop_stock family extension", "preserved": "Routes, door swings, lift approach, floor plates, switch reach",
                                "acceptance": "Overview, reverse and threshold views show no obstruction of the authored route; wayfinding plates still readable by lamp"})

def core(sid, group, title, location, delta, extra_changes=None, coverage=None, evidence=None, captions=None, group_intro=None, level=None):
    nar = (f"The stair core is the oldest thing the player touches: honed marble treads dished by sixteen years of feet, iron balusters, a rail polished gold at hand height, "
           f"the enamel floor plate, the lift landing with its brass call plate and the dial above it. {delta} Cores carry sound up and down the building; this is where the Tenant's body is audible.")
    base = [
        change(f"{sid}-001", "P2", "add", "Landing notice and the building's paper trail", placement="On the core wall beside the floor plate at 1.5 m, clear of the rail",
               dimensions="notice frame 0.35 x 0.45 m", construction="One framed notice board (Label3D text) per core level: the 1928 house rules on the public side, the service notice on the service side",
               materials="oak frame, glass, foxed paper", wear="a corner of the glass cracked and taped", purpose="Bible VIII.5.h: the paper trail begins in 1928; Nadia's memos signed Management need a place to be posted",
               sources=["design/ORISON_BIBLE.md VIII.5.h", "game/data/resident_schedules.json (Nadia posts the tenant memo Mon/Wed/Fri)"], acceptance="Readable by the service lamp from the landing"),
        change(f"{sid}-002", "P3", "refine", "Stair wear and the one unique landing piece", placement="Tread noses and the half-landing wall",
               materials="honed stair marble (art/blender/stair_honed.md) with inherited dishing; one framed piece per half-landing (punchlist: each of the seven landings needs a unique piece)", wear="dished treads, rail gold at hand height, paint rubbed at the turn",
               purpose="Accord 12 and the open punchlist row", preserve="Stair ironwork and tread collision", acceptance="Reverse view up the flight shows the dishing read against the lamp"),
    ]
    return area(sid, group, "ORISON", title, location, "all residents, the player, the lift", nar, base + (extra_changes or []), canon=[C_BIBLE_III, C_ACCORDS], coverage=coverage, evidence=evidence, captions=captions, level=level, group_intro=group_intro,
                implementation={"sources": ["art/blender/stair_ironwork.md", "art/blender/stair_honed.md", "art/blender/wayfinding_plate.md", "art/blender/lift_call_plate.md"],
                                "dependencies": "None beyond the stair/lift owners; notices are Label3D", "preserved": "Stair collision, lift landing doors and interlock, floor plates", "acceptance": "Route tests (vertical, elevator) unchanged; notice readable"})

def service_hall(sid, group, title, location, delta, extra_changes=None, coverage=None, evidence=None, captions=None, group_intro=None, level=None):
    nar = (f"The service spine: narrower, unpainted above the dado, the risers exposed with their 1912 lagging, a cage bulb instead of a dome, the dumbwaiter and service stair at its end. "
           f"{delta} This is the player's own territory and should read as worked, not decorated: chalk marks on the pipes, a hook for the lamp, a crate on its side.")
    base = [
        change(f"{sid}-001", "P2", "add", "Maintenance evidence on the service spine", placement="On the riser cluster wall and the floor against it, outside the 1.2 m route",
               construction="Chalk valve marks (decal), a pipe tag per riser (Label3D), one crate, one coiled hose on a bracket; nothing on the route", materials="chalk, card tags on wire, pine crate, rubber hose",
               wear="drip stain under the valve, a boot scuff where the super stands", purpose="Accord 11 and 13: every pipe terminates and reads as a timeline; the super's rounds leave marks",
               sources=["art/blender/heating_distribution.md", "art/blender/duct_supports.md", "game/data/resident_schedules.json (Omar's rounds 08:00-12:00)"], preserve="Service route, dumbwaiter approach, door swings",
               acceptance="Threshold view from the crossing shows marked pipes and a clear route"),
    ]
    return area(sid, group, "ORISON", title, location, "the player, the super, deliveries", nar, base + (extra_changes or []), canon=[C_ACCORDS, C_BIBLE_VIII5C], coverage=coverage, evidence=evidence, captions=captions, level=level, group_intro=group_intro,
                implementation={"sources": ["game/data/orison_v2_blockout.json (service halls, risers)", "art/blender/fixed_lighting.md (cage bulbs)"], "dependencies": "none", "preserved": "Service routes and dumbwaiter/lift approaches", "acceptance": "Service route tests unchanged"})

def roof_deck(sid, group, title, location, delta, extra_changes=None, coverage=None, evidence=None, captions=None, group_intro=None):
    nar = (f"Open-air maintenance deck over the 1928 membrane: coping, parapets, the four ventilators, the tank on its legs, the chimney, the bulkheads. {delta} "
           f"The roof is where the prospectus drew people in a garden that was a promise; Malcolm keeps that promise alive in beds and communal planters, and the schedules put four residents up here on different nights.")
    base = [
        change(f"{sid}-001", "P2", "add", "Roof-use evidence by the schedules", placement="Where the deck is clear of plant, drainage and the authored falling field; never inside the ventilator curbs",
               construction="Instanced static objects: a watering can, a pigeon-stained coping stretch (C2 commensals when ruled), a line post for washing, a chalked tar patch", materials="galvanised tin, creosoted timber, tar",
               wear="tar patches, a ponding ring where the fall is wrong", purpose="Schedules: Malcolm's beds, Juno's roof mics on Mon/Wed, Sacha's photography Tue/Thu, Mae's unhurried hour on Sunday",
               sources=["game/data/resident_schedules.json", "art/blender/roof_membrane.md", "design/ORISON_COMMENSALS_BRIEF.md (C2 pigeons are gated)"], preserve="Falling field, drainage outlets, tank valve and ventilator guards",
               acceptance="Overview shows at least one object explaining who comes up here"),
    ]
    return area(sid, group, "ORISON", title, location, "the player, Malcolm, Juno, Sacha, Mae", nar, base + (extra_changes or []), canon=[C_BIBLE_VIII5I, C_SCHED, "Bible VIII.3 (the roof garden drawn with people in it)"], coverage=coverage, evidence=evidence, captions=captions,
                implementation={"sources": ["game/data/orison_v2_blockout.json ROOF spaces", "art/blender/roof_membrane.md", "art/blender/roof_coping.md", "art/blender/house_tank.md", "art/blender/roof_ventilator.md"],
                                "dependencies": "A06 roof field finish is pending in the owner JSON; sequence after it", "preserved": "Roof route, tank activity, ventilator refusal, bulkhead doors", "acceptance": "OrisonV2RoofRouteTest unchanged"})
