extends Node3D
## Holds the sky spectacle year (data/weather/phenomena.json): every phenomenon
## dated inside the campaign, in season, at a sun altitude that suits it, under
## weather that allows it, on a day whose printed weather agrees, and reported
## by the next morning's papers. Rolled rarities are reproducible from the seed.
## The production WeatherManager then shows a dated event and forces its weather.

const Phenomena := preload("res://scripts/building/sky_phenomena.gd")
const Manager := preload("res://scripts/building/WeatherManager.gd")

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _seasonal(date: String) -> Dictionary:
	var parts := date.split("-")
	return LiveWeatherService.presentation(Manager.seasonal_snapshot({"month": int(parts[1]), "day": int(parts[2])}))


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	var schedule := Phenomena.new()
	var loaded := schedule.load_schedule(Phenomena.PATH, Callable(self, "_seasonal"))
	for problem in schedule.errors: print("    ", problem)
	_check("the schedule loads with no validation errors", loaded)
	_check("41 phenomena fill the 41 sky slots", schedule.phenomena.size() == Phenomena.SLOTS
			and not schedule.ids_by_slot.has(""))
	var dated := {}
	for entry: Dictionary in schedule.occurrences: dated[entry.id] = true
	_check("every phenomenon is dated at least once", dated.size() == schedule.phenomena.size())

	# The papers are the weather of record: each event's date must print weather that allows it.
	var catalog := NewspaperCatalog.new()
	catalog.load_all()
	add_child(catalog)
	var ear_failures: Array[String] = []
	var unreported: Array[String] = []
	for entry: Dictionary in schedule.occurrences:
		var row: Dictionary = schedule.phenomena[entry.id]
		var ear := (str(catalog.issue("record", entry.date).get("ear", "")) + " "
				+ str(catalog.issue("speaker", entry.date).get("ear", ""))).to_lower()
		if not Phenomena.ear_allows(row, ear):
			ear_failures.append("%s %s: the papers print '%s'" % [entry.id, entry.date, ear])
		var next_day := CampaignClock._date_from_ordinal(Phenomena.ordinal_of(entry.date) + 1)
		var issue := "%04d-%02d-%02d" % [next_day.year, next_day.month, next_day.day_of_month]
		if not catalog.has_issue(issue) or not catalog.sky_notices(issue).has(entry.press):
			unreported.append("%s %s" % [entry.id, entry.date])
	for failure in ear_failures: print("    ", failure)
	_check("every dated event agrees with the weather both papers printed", ear_failures.is_empty())
	_check("every event is reported in the next morning's papers", unreported.is_empty())

	# Seeded rarities: same seed, same sky; in season; inside the sun window; rare.
	var first: Array = []
	var second: Array = []
	var replay := Phenomena.new()
	replay.load_schedule()
	for ordinal in range(schedule.first_ordinal, schedule.last_ordinal + 1):
		var date := CampaignClock._date_from_ordinal(ordinal)
		var text := "%04d-%02d-%02d" % [date.year, date.month, date.day_of_month]
		first.append_array(schedule.rolls_for(ordinal, 1928, _seasonal(text)))
		second.append_array(replay.rolls_for(ordinal, 1928, _seasonal(text)))
	_check("rolled rarities reproduce exactly from the campaign seed (%d rolled)" % first.size(),
			JSON.stringify(first) == JSON.stringify(second))
	var counts := {}
	var misplaced: Array[String] = []
	for entry: Dictionary in first:
		var row: Dictionary = schedule.phenomena[entry.id]
		counts[entry.id] = int(counts.get(entry.id, 0)) + 1
		var elevation := Phenomena.sun_elevation(float(entry.start))
		var month := int(str(entry.date).split("-")[1])
		if elevation < float(row.sun_degrees[0]) or elevation > float(row.sun_degrees[1]) \
				or month not in (row.months as Array).map(func(m): return int(m)):
			misplaced.append("%s %s" % [entry.id, entry.date])
	_check("every rolled rarity is in season and inside its sun window", misplaced.is_empty())
	_check("rolled rarities stay rare (no phenomenon on more than 12 days)",
			counts.values().all(func(n): return int(n) <= 12))
	var other_seed: Array = []
	var third := Phenomena.new()
	third.load_schedule()
	for ordinal in range(schedule.first_ordinal, schedule.last_ordinal + 1):
		var date := CampaignClock._date_from_ordinal(ordinal)
		other_seed.append_array(third.rolls_for(ordinal, 77,
				_seasonal("%04d-%02d-%02d" % [date.year, date.month, date.day_of_month])))
	_check("a different campaign seed rolls a different year", JSON.stringify(other_seed) != JSON.stringify(first))

	# Fades are real at campaign scale: two minutes into an eight-minute fade is partial.
	var at := 2800000.0
	var rising := Phenomena.envelope(at, at + 30.0, 8.0, at + 2.0)
	_check("an event fades in over its fade minutes, not as a step (%.2f)" % rising,
			rising > .05 and rising < .5 and Phenomena.envelope(at, at + 30.0, 8.0, at + 15.0) == 1.0)

	# A broken document is refused at load with a reason, not shown wrong.
	var broken: Dictionary = JSON.parse_string(FileAccess.get_file_as_string(Phenomena.PATH))
	broken.occurrences[0].date = "1930-01-01"
	broken.phenomena[0].weather["hail_size"] = 3
	var path := "user://sky_phenomena_broken.json"
	var file := FileAccess.open(path, FileAccess.WRITE)
	file.store_string(JSON.stringify(broken))
	file.close()
	var refused := Phenomena.new()
	_check("a date outside the year and an unknown forcing are refused",
			not refused.load_schedule(path) and refused.errors.size() >= 2)

	await _production_manager(schedule)
	print("SKY PHENOMENA SCHEDULE: %s" % ["PASS" if _fails == 0 else "FAIL (%d)" % _fails])
	get_tree().quit(0 if _fails == 0 else 1)


## The production owner picks the dated tornado and forces its storm.
func _production_manager(schedule: Phenomena) -> void:
	var tornado: Dictionary = {}
	for entry: Dictionary in schedule.occurrences:
		if entry.id == "tornado": tornado = entry
	var minute := (float(tornado.start) + float(tornado.end)) * .5
	var date := CampaignClock._date_from_ordinal(int(floor(minute / 1440.0)))
	var clock := CampaignClock.new()
	clock.configure_date(int(date.year), int(date.month), int(date.day_of_month), int(fposmod(minute, 1440.0)))
	var env := Environment.new()
	var material := ShaderMaterial.new()
	material.shader = preload("res://shaders/v2_seasonal_sky.gdshader")
	var key := DirectionalLight3D.new()
	add_child(key)
	var director := DayNightDirector.new()
	add_child(director)
	director.setup(self, env, key, material)
	var manager := Manager.new()
	manager.configure(clock, director, material)
	add_child(manager)
	await get_tree().process_frame
	await get_tree().process_frame
	manager.elapsed = Manager.TRANSITION_SECONDS
	manager._phenomena_left = 0.0
	manager._process(.1)
	var ids: Array = manager.active_phenomena.map(func(e): return e.id)
	_check("the dated tornado is active at its scheduled minute", "tornado" in ids)
	_check("its storm is forced on the presentation (thunderstorm, rain)",
			bool(manager.current.get("thunderstorm", false)) and float(manager.current.get("rain_intensity", 0.0)) > .3)
	_check("the conditions published to residents name the phenomenon",
			(manager.current.get("phenomena", []) as Array).any(func(p): return p.id == "tornado"))
	if RenderingServer.get_current_rendering_method() == "forward_plus":
		var levels: PackedFloat32Array = material.get_shader_parameter("spectacle")
		_check("the sky shader receives the tornado slot", levels.size() == Phenomena.SLOTS and levels[16] > 0.0)
	manager.force_phenomenon("aurora", 1.0)
	manager._process(.1)
	_check("a forced phenomenon joins the active set", manager.active_phenomena.any(func(e): return e.id == "aurora"))
