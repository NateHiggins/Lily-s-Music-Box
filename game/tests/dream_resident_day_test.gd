extends Node
const Selection = preload("res://scripts/dream/dream_resident_day.gd")
var checks := 0
var failures: Array[String] = []
var observations: Array = []
func check(ok: bool, label: String) -> void:
	checks += 1
	if not ok: failures.append(label)
func _ready() -> void: run.call_deferred()
func at(result: Dictionary, minute: int, place: String) -> bool:
	return result.stops.any(func(row: Dictionary) -> bool: return int(row.minute) == minute and str(row.place) == place)
func day(weekday: String, doy: int, first: bool = false) -> Dictionary:
	return {"valid": true, "day": weekday, "doy": doy, "first_sat": first, "civil_date_valid": false}
func run() -> void:
	var directory := OS.get_environment("SHOT_DIR")
	if directory.is_empty(): get_tree().quit(2); return
	var original: Dictionary = RealityState.data
	var before: Dictionary = original.duplicate(true)
	var catalog := DreamMazeBuilder.load_catalog()
	var selector := Selection.new()
	var owner := ScheduleDirector.new()
	owner.data = JSON.parse_string(FileAccess.get_file_as_string(ScheduleDirector.SCHEDULE_PATH))
	var first := selector.resolve("peter_wren", day("sat", 336, true), catalog)
	var ordinary := selector.resolve("peter_wren", day("sat", 343), catalog)
	check(first.errors.is_empty() and at(first, 600, "lobby"), "first Saturday meeting takes Peter to the lobby at ten")
	check(not at(ordinary, 600, "lobby"), "ordinary Saturday does not invent the monthly meeting")
	observations.append({"case": "Peter monthly", "first": first, "ordinary": ordinary})
	var fired := -1
	var missed := -1
	for doy in range(1, 366):
		var selected: Dictionary = owner.resolve("omar_bell", "tue", 180, doy, false)
		if str(selected.get("place", "")) == "laundry" and fired < 0: fired = doy
		if str(selected.get("place", "")) != "laundry" and missed < 0: missed = doy
		if fired > 0 and missed > 0: break
	check(fired > 0 and missed > 0, "actual owner supplies both deterministic patrol outcomes")
	if fired > 0 and missed > 0:
		var patrol := selector.resolve("omar_bell", day("tue", fired), catalog)
		var sleeping := selector.resolve("omar_bell", day("tue", missed), catalog)
		check(at(patrol, 180, "laundry"), "fired chance patrol is present at three")
		check(not at(sleeping, 180, "laundry"), "missed chance patrol stays absent")
		check(patrol == selector.resolve("omar_bell", day("tue", fired), catalog), "the same day has the same patrol and rooms")
		observations.append({"case": "Omar chance", "fired_doy": fired, "missed_doy": missed, "fired": patrol, "missed": sleeping})
	var special := selector.resolve("juno_kells", day("tue", 306), catalog)
	var normal := selector.resolve("juno_kells", day("tue", 307), catalog)
	check(at(special, 1200, "roof"), "Juno's special day goes to the roof at eight")
	check(not at(normal, 1200, "roof"), "ordinary Tuesday does not borrow the special roof visit")
	var saturday := selector.resolve("mina_vale", day("sat", 340), catalog)
	check(at(saturday, 780, "laundry"), "Mina's Saturday laundry overrides the base bodega")
	observations.append({"case": "Juno special", "selected": special})
	var profiles: Dictionary = JSON.parse_string(FileAccess.get_file_as_string("res://data/dream_profiles.json")).profiles
	var subjects := {}
	for profile: Dictionary in profiles.values(): subjects[str(profile.pursuit.silhouette_resident)] = true
	for subject: String in subjects:
		for weekday: String in ScheduleDirector.DAY_NAMES:
			var info := day(weekday, 120, weekday == "sat")
			var result := selector.resolve(subject, info, catalog)
			check(result.errors.is_empty() and not result.rooms.is_empty(), subject + "/" + weekday + " resolves real rooms")
			var atlas := DreamAtlas.new()
			atlas.setup("f123456789abcdef", 0, "receiving", subject, weekday, result.rooms)
			check(atlas._day == result.rooms, subject + "/" + weekday + " atlas uses exact resolved sequence")
			for module_id: String in result.rooms:
				check(str(catalog.modules[module_id].day_of) == subject, "no foreign subject room " + module_id)
			var room: Dictionary = atlas.room(PackedInt32Array([0, 1, 2]))
			check(not str(room.source).begins_with("DAY_") or result.rooms.has(str(room.source)), "sampled personal room belongs to the selected actual day")
	check(is_same(original, RealityState.data) and before == RealityState.data, "selection leaves exact campaign reference and contents unchanged")
	owner.free()
	DirAccess.make_dir_recursive_absolute(directory)
	FileAccess.open(directory.path_join("result.json"), FileAccess.WRITE).store_string(JSON.stringify({"evidence_class":"INERT actual-day selection diagnostic, not played/art acceptance", "checks":checks,"failures":failures,"observations":observations}, "\t"))
	print("DREAM RESIDENT DAY: ", checks, " checks / ", failures.size(), " failures")
	get_tree().quit(0 if failures.is_empty() else 1)
