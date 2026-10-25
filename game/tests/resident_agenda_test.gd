extends Node
## The residents' agenda, headless: every resident has a lived day in every
## season; hard blocks always hold; bad weather keeps the frail indoors; a
## resolved story beat retires the compulsion and brings the change; trusted
## residents come to find the player and wary ones keep away; friends visit
## and the people who avoid each other do. With AGENDA_REPORT set, the four
## sample days are written out as timetables.

const SCENARIOS := [
	{"name": "Winter Tuesday, sleet", "day": "tue", "doy": 15,
		"weather": {"temperature_c": -3.0, "rain_intensity": 1.2, "snow_intensity": 0.5, "wind_speed_kmh": 40.0}},
	{"name": "Spring Sunday, fair", "day": "sun", "doy": 112,
		"weather": {"temperature_c": 16.0, "rain_intensity": 0.0, "snow_intensity": 0.0, "wind_speed_kmh": 12.0}},
	{"name": "Summer Saturday, hot and clear", "day": "sat", "doy": 195,
		"weather": {"temperature_c": 31.0, "rain_intensity": 0.0, "snow_intensity": 0.0, "wind_speed_kmh": 8.0}},
	{"name": "Autumn Thursday, steady rain", "day": "thu", "doy": 297,
		"weather": {"temperature_c": 10.0, "rain_intensity": 1.5, "snow_intensity": 0.0, "wind_speed_kmh": 22.0}},
]
const PLACES := ["unit", "visit", "lobby", "mail_bank", "corridor", "stairs", "half_landing", "laundry",
		"roof", "light_court", "bodega", "harukiya_bar", "luncheonette", "hand_laundry", "news_cigars",
		"photo_supplies", "out"]

var _fails := 0
var schedule: ScheduleDirector
var agenda: ResidentAgenda
var weather: Dictionary = {}
var known: Dictionary = {}
var trust: Dictionary = {}
var player := ""


func _check(label: String, ok: bool) -> void:
	print("RESIDENT AGENDA: ", label, " = ", ok)
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	CampaignClock.new().configure_date(1928, 11, 10, 9 * 60)
	schedule = ScheduleDirector.new()
	add_child(schedule)
	schedule.setup(null, {})
	agenda = ResidentAgenda.new()
	add_child(agenda)
	_check("the agenda reads its motives and every resident is on the timetable",
			agenda.setup(schedule, func() -> Dictionary: return weather, func() -> String: return player,
			func(flag: String) -> bool: return known.has(flag),
			func(resident: String) -> int: return int(trust.get(resident, 0))))
	if agenda.enabled:
		_run()
	print("RESIDENT AGENDA TEST: %d failures" % _fails)
	get_tree().quit(0 if _fails == 0 else 1)


func _run() -> void:
	_check("all eighteen residents have motives", agenda.order.size() == 18)
	var plans := {}
	var started := Time.get_ticks_msec()
	for scenario: Dictionary in SCENARIOS:
		weather = scenario.weather
		plans[scenario.name] = {}
		for slug in agenda.order:
			plans[scenario.name][slug] = agenda.day_plan(slug, scenario.day, scenario.doy, false)
	var per_day := float(Time.get_ticks_msec() - started) / float(SCENARIOS.size() * 18)
	print("  full-day plan: %.1f ms per resident-day" % per_day)
	_coverage(plans)
	_hard_blocks()
	_weather(plans)
	_story()
	_player()
	_people(plans)
	_reconstruct()
	var kitchen := _kitchens()
	if OS.get_environment("AGENDA_REPORT") != "":
		_report(plans, OS.get_environment("AGENDA_REPORT"), kitchen)


## Every resident's day is covered end to end with legal places and activities.
func _coverage(plans: Dictionary) -> void:
	var gaps := 0
	var illegal := 0
	for scenario: String in plans:
		for slug: String in plans[scenario]:
			var at := 0
			for segment: Dictionary in plans[scenario][slug]:
				if int(segment.start) != at:
					gaps += 1
				at = int(segment.end)
				var place := str(segment.place)
				var root := "unit" if place.begins_with("unit") else ("visit" if place.begins_with("visit:") else place)
				if root not in PLACES or str(segment.activity) not in agenda.motives.activities:
					illegal += 1
					print("  illegal: %s %s %s %s" % [scenario, slug, place, segment.activity])
			if at != 1440:
				gaps += 1
	_check("every resident's day runs midnight to midnight without a gap", gaps == 0)
	_check("every place and activity is in the timetable grammar", illegal == 0)


## Sleep, work, transit and ritual blocks are never bent.
func _hard_blocks() -> void:
	weather = SCENARIOS[0].weather
	var broken := 0
	for slug in agenda.order:
		for minute in range(0, 1440, 30):
			var block := schedule.resolve(slug, "tue", float(minute), 15, false)
			if str(block.get("activity", "")) not in agenda.motives.hard_activities:
				continue
			var lived := agenda.decide(slug, "tue", float(minute), 15, false)
			if str(lived.get("place", "")) != str(block.get("place", "unit")):
				broken += 1
				print("  hard block bent: %s %d %s -> %s" % [slug, minute, block.place, lived.get("place", "")])
	_check("hard blocks (sleep, work, transit, ritual) always hold", broken == 0)


## Exposed choices made of their own will, summed over residents.
func _exposed_minutes(plan: Dictionary, sources: Array) -> int:
	var total := 0
	for slug: String in plan:
		for segment: Dictionary in plan[slug]:
			var place := str(segment.place).split(":")[0]
			if bool(agenda.motives.places.get(place, {}).get("exposed", false)) and str(segment.source) in sources:
				total += int(segment.end) - int(segment.start)
	return total


func _weather(plans: Dictionary) -> void:
	var sleet := _exposed_minutes(plans[SCENARIOS[0].name], ["need", "friend", "shadow", "growth"])
	var spring := _exposed_minutes(plans[SCENARIOS[1].name], ["need", "friend", "shadow", "growth"])
	print("  minutes out of doors by choice: sleet %d, spring %d" % [sleet, spring])
	_check("residents go out of doors by choice in fair weather", spring > 0)
	_check("sleet keeps them in: fewer chosen minutes out of doors", sleet < spring)
	var kept := 0
	for slug: String in plans[SCENARIOS[0].name]:
		for segment: Dictionary in plans[SCENARIOS[0].name][slug]:
			if str(segment.source) == "timetable":
				continue
			if str(segment.why).contains("cold") or str(segment.place) == "laundry":
				kept += int(segment.end) - int(segment.start)
	print("  sleet: %d minutes sought warmth by choice" % kept)
	var hot_air := 0
	for slug: String in plans[SCENARIOS[2].name]:
		for segment: Dictionary in plans[SCENARIOS[2].name][slug]:
			if str(segment.place) in ["roof", "light_court"] and str(segment.source) != "timetable":
				hot_air += int(segment.end) - int(segment.start)
	print("  hot Saturday: %d minutes on the roof or in the light court by choice" % hot_air)
	_check("a hot clear day draws residents up for air", hot_air > 0)


## The story beat: a resident's compulsion runs until their case is resolved,
## then the change appears instead.
func _story() -> void:
	weather = SCENARIOS[1].weather
	known.clear()
	var before := _sources("sun", 112)
	for slug in agenda._arcs:
		known[str(agenda._arcs[slug][0])] = true
		known[str(agenda._arcs[slug][1])] = true
	var after := _sources("sun", 112)
	known.clear()
	print("  compulsion minutes before %d, after %d; changed minutes after %d" % [
			before.get("shadow", 0), after.get("shadow", 0), after.get("growth", 0)])
	_check("unresolved residents act on their compulsions", int(before.get("shadow", 0)) > 0)
	_check("resolution retires every compulsion", int(after.get("shadow", 0)) == 0)
	_check("resolved residents do something new", int(after.get("growth", 0)) > 0)
	known[str(agenda._arcs["teresa_vale"][0])] = true
	known[str(agenda._arcs["teresa_vale"][1])] = true
	var rested := 0
	for segment: Dictionary in agenda.day_plan("teresa_vale", "sat", 195, false):
		if str(segment.source) == "growth":
			rested += 1
	known.clear()
	_check("Teresa, her beat resolved, lets an hour go undefended", rested > 0)


func _sources(day: String, doy: int) -> Dictionary:
	var totals := {}
	for slug in agenda.order:
		for segment: Dictionary in agenda.day_plan(slug, day, doy, false):
			totals[segment.source] = int(totals.get(segment.source, 0)) + int(segment.end) - int(segment.start)
	return totals


## The player: trusted residents come to find them in a shared room; a
## resident who distrusts them keeps out of the room they are in.
func _player() -> void:
	weather = SCENARIOS[1].weather
	trust = {"lena_ortiz": 3}
	player = "lobby"
	agenda.advance("wed", 100, false, 600)
	var found := false
	for minute in range(610, 1200, 10):
		agenda.advance("wed", 100, false, minute)
		if str(agenda._live.lena_ortiz.choice.place) == "lobby":
			found = true
			break
	_check("Lena, who trusts the night man, comes down to the lobby where he is", found)
	trust = {"evelyn_marsh": -2}
	player = "mail_bank"
	agenda.live_day = ""
	agenda.advance("wed", 100, false, 1060)
	var avoided := true
	for minute in range(1070, 1110, 10):
		agenda.advance("wed", 100, false, minute)
		if str(agenda._live.evelyn_marsh.choice.place) == "mail_bank":
			avoided = false
	var timetable := str(schedule.resolve("evelyn_marsh", "wed", 1090.0, 100, false).get("place", ""))
	print("  Evelyn's timetable at 18:10 says %s" % timetable)
	_check("Evelyn, who distrusts the night man, skips the mail bank while he is at it", avoided)
	trust = {}
	player = ""
	agenda.live_day = ""


## Friends call on each other; people who avoid each other are not found in
## the same room by choice.
func _people(plans: Dictionary) -> void:
	var visits := 0
	var meetings := 0
	for scenario: String in plans:
		for slug: String in plans[scenario]:
			for segment: Dictionary in plans[scenario][slug]:
				if str(segment.source) == "friend":
					visits += 1
		for slug: String in plans[scenario]:
			for other: String in agenda.motives.residents[slug].avoid_people:
				var met := _shared_minutes(plans[scenario][slug], plans[scenario].get(other, []))
				if met > 0:
					print("  %s met %s by choice for %d minutes (%s)" % [slug, other, met, scenario])
				meetings += met
	print("  friendly visits across the four days: %d" % visits)
	_check("friends call on each other", visits > 0)
	_check("residents who avoid each other never choose the same shared room", meetings == 0)


func _shared_minutes(mine: Array, theirs: Array) -> int:
	var total := 0
	for a: Dictionary in mine:
		if str(a.source) == "timetable" or str(a.place).begins_with("unit") or str(a.place) in ["corridor", "out"]:
			continue
		for b: Dictionary in theirs:
			if str(b.place) == str(a.place):
				total += maxi(0, mini(int(a.end), int(b.end)) - maxi(int(a.start), int(b.start)))
	return total


## The same minute always answers the same way, and a load is quick.
func _reconstruct() -> void:
	weather = SCENARIOS[3].weather
	agenda._cache_key = ""
	var first := agenda.decide("jonah_price", "thu", 900.0, 297, false)
	agenda._cache_key = ""
	var started := Time.get_ticks_msec()
	var second := agenda.decide("jonah_price", "thu", 900.0, 297, false)
	var took := Time.get_ticks_msec() - started
	print("  reconstructing six hours for the building: %d ms" % took)
	_check("the same campaign minute gives the same answer", first == second)
	_check("every answer says why", str(first.get("why", "")) != "" and first.has("source") and first.has("motive"))
	_check("a load reconstructs the building in under a second", took < 1000)


## Four days of the house's kitchens, lived step by step: every household
## shops for its dish at the shops that sell it, cooks it, eats it and washes
## up; nothing goes below nothing; the icebox shows what is in it.
func _kitchens() -> Array:
	var larder := KitchenLarder.new()
	var loaded := larder.load_data(agenda.homes())
	for line in larder.errors.slice(0, 12):
		print("  kitchen error: ", line)
	_check("the cookbook and groceries load, a dish for every resident, every ingredient sold", loaded)
	if not loaded:
		return []
	_check("eighteen dishes in the house cookbook", larder.cookbook.dishes.size() == 18)
	var store := {}
	larder.event_limit = 100000
	larder.bind(store)
	_check("every household is seeded", larder.state.units.size() == 17)
	agenda.larder = larder
	agenda.clock_stamps = false
	agenda.live_day = ""
	weather = SCENARIOS[1].weather
	var days := [["wed", 100], ["thu", 101], ["fri", 102], ["sat", 103]]
	var negative := 0
	for pair: Array in days:
		for minute in range(0, 1440, 10):
			agenda.advance(str(pair[0]), int(pair[1]), false, minute)
			for unit: String in larder.state.units:
				for item: String in larder.state.units[unit].stock:
					if float(larder.state.units[unit].stock[item].qty) < 0.0:
						negative += 1
	var events: Array = larder.state.events.duplicate()
	agenda.larder = null
	agenda.clock_stamps = true
	agenda.live_day = ""
	var cooked := {}
	var shops := {}
	var counts := {}
	for event: Dictionary in events:
		counts[event.what] = int(counts.get(event.what, 0)) + 1
		if str(event.what) == "cooked" and not str(event.detail).begins_with("a plain"):
			cooked[event.resident] = true
		if str(event.what) == "shopped":
			for shop: String in larder.groceries.shops:
				if str(event.detail).contains(str(larder.groceries.shops[shop].name)):
					shops[shop] = true
	print("  kitchen events over four days (%d): %s" % [events.size(), counts])
	print("  dishes cooked by: %s" % [cooked.keys()])
	for slug in agenda.order:
		if not cooked.has(slug):
			print("  %s never cooked; still short of %s" % [slug, larder.missing(slug).keys()])
	print("  shops visited: %s" % [shops.keys()])
	_check("nothing in any larder goes below nothing", negative == 0)
	_check("residents shop, cook, eat and wash up", int(counts.get("shopped", 0)) > 0 and int(counts.get("cooked", 0)) > 0
			and int(counts.get("ate", 0)) > 0 and int(counts.get("washed up", 0)) > 0)
	_check("at least twelve residents cook their own dish in four days", cooked.size() >= 12)
	_check("the bodega and at least two Arcade shops are shopped at", shops.has("bodega") and shops.size() >= 3)
	var shown := 0
	for unit: String in larder.state.units:
		var rows := larder.icebox_rows(unit)
		shown += rows.size()
		for row: Array in rows:
			if int(row[4]) < 0 or int(row[4]) > 2:
				shown = -1000
	_check("iceboxes show what is in them, on real shelves", shown > 0)
	_check("the larder state survives a save", KitchenLarder.valid(store[KitchenLarder.STATE_KEY]))
	return events


func _report(plans: Dictionary, path: String, kitchen: Array) -> void:
	var lines: Array[String] = []
	for scenario: Dictionary in SCENARIOS:
		lines.append("## %s" % scenario.name)
		lines.append("")
		for slug in agenda.order:
			lines.append("### %s" % slug)
			for segment: Dictionary in plans[scenario.name][slug]:
				lines.append("- %s-%s %s, %s (%s): %s" % [_clock(int(segment.start)), _clock(int(segment.end)),
						segment.place, segment.activity, segment.source, segment.why])
			lines.append("")
	lines.append("## The kitchens, four days")
	lines.append("")
	for event: Dictionary in kitchen:
		lines.append("- day %d %s, %s %s: %s %s" % [int(event.at) / 1440, _clock(int(event.at) % 1440), event.unit,
				event.resident, event.what, event.detail])
	var file := FileAccess.open(path, FileAccess.WRITE)
	if file:
		file.store_string("\n".join(lines))
		print("  timetables written to %s" % path)


static func _clock(minute: int) -> String:
	return "%02d:%02d" % [minute / 60, minute % 60]
