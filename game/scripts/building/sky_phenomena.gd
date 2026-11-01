extends RefCounted
## The year's sky spectacle (data/weather/phenomena.json), read by WeatherManager.
## Dated occurrences come from the file; rare phenomena may also roll a seeded
## daily chance, so a reload of the same campaign shows the same sky. The file
## is checked at load: every phenomenon dated inside the campaign, in season,
## with its sun window and weather requirements met by its own forcing.
const PATH := "res://data/weather/phenomena.json"
const SCHEMA := "orison.sky-phenomena.v1"
const SLOTS := 42
const FAMILIES := ["cloud", "dust", "dome", "electric", "optics"]
const UTC_OFFSET_MINUTES := -300
const LATITUDE := 40.75
const LONGITUDE := -73.92
## Fields an occurrence may force on the weather presentation while it shows.
const WEATHER_KEYS := ["temperature_c", "relative_humidity", "cloud_total", "cloud_low",
	"cloud_mid", "cloud_high", "wind_speed_kmh", "wind_gusts_kmh", "wind_direction_degrees",
	"precipitation_intensity", "rain_intensity", "snow_intensity", "dust",
	"thunderstorm", "wet", "snowing", "foggy", "weather_code"]
const BOOL_KEYS := ["thunderstorm", "wet", "snowing", "foggy"]
## requires key -> [condition field, comparison]
const REQUIRE_KEYS := {
	"thunderstorm": ["thunderstorm", "is"], "foggy": ["foggy", "is"],
	"precipitation_min": ["precipitation_intensity", "min"],
	"precipitation_max": ["precipitation_intensity", "max"],
	"cloud_total_min": ["cloud_total", "min"], "cloud_total_max": ["cloud_total", "max"],
	"cloud_low_min": ["cloud_low", "min"], "cloud_mid_min": ["cloud_mid", "min"],
	"cloud_high_min": ["cloud_high", "min"],
	"temperature_min_c": ["temperature_c", "min"], "temperature_max_c": ["temperature_c", "max"],
	"wind_min_kmh": ["wind_speed_kmh", "min"], "wind_max_kmh": ["wind_speed_kmh", "max"],
	"humidity_min": ["relative_humidity", "min"], "humidity_max": ["relative_humidity", "max"],
	"dust_min": ["dust", "min"],
}

var phenomena: Dictionary = {}      # id -> row
var ids_by_slot: Array[String] = []
var occurrences: Array[Dictionary] = []
var errors: PackedStringArray = []
var salt := ""
var first_ordinal := 0
var last_ordinal := 0
var _rolled: Dictionary = {}        # ordinal -> Array of synthesized occurrences


func load_schedule(path := PATH, seasonal := Callable()) -> bool:
	errors.clear(); phenomena.clear(); occurrences.clear(); _rolled.clear()
	ids_by_slot.clear(); ids_by_slot.resize(SLOTS)
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(path))
	if parsed is not Dictionary or str(parsed.get("schema", "")) != SCHEMA:
		errors.append("%s: not an %s document" % [path, SCHEMA]); return false
	if int(parsed.get("slots", 0)) != SLOTS:
		errors.append("slots must be %d" % SLOTS)
	salt = str(parsed.get("seed_salt", ""))
	var campaign: Dictionary = parsed.get("campaign", {})
	first_ordinal = ordinal_of(str(campaign.get("first", "")))
	last_ordinal = ordinal_of(str(campaign.get("last", "")))
	if first_ordinal <= 0 or last_ordinal < first_ordinal:
		errors.append("campaign window unreadable")
	for row: Variant in parsed.get("phenomena", []):
		_admit_phenomenon(row)
	for slot in SLOTS:
		if ids_by_slot[slot] == "": errors.append("slot %d has no phenomenon" % slot)
	var dated: Dictionary = {}
	for row: Variant in parsed.get("occurrences", []):
		var entry := _admit_occurrence(row, seasonal)
		if not entry.is_empty():
			occurrences.append(entry); dated[entry.id] = true
	for id: String in phenomena:
		if not dated.has(id): errors.append("%s is never dated in the campaign year" % id)
	occurrences.sort_custom(func(a, b): return a.start < b.start)
	return errors.is_empty()


func _admit_phenomenon(row: Variant) -> void:
	if row is not Dictionary: errors.append("a phenomenon is not an object"); return
	var id := str(row.get("id", ""))
	var slot := int(row.get("slot", -1))
	if id == "" or phenomena.has(id): errors.append("phenomenon id empty or repeated: %s" % id); return
	if slot < 0 or slot >= SLOTS or ids_by_slot[slot] != "":
		errors.append("%s: slot %d out of range or taken" % [id, slot]); return
	if str(row.get("family", "")) not in FAMILIES: errors.append("%s: unknown family" % id)
	if str(row.get("label", "")) == "": errors.append("%s: no period label" % id)
	var months: Array = row.get("months", [])
	if months.is_empty() or months.any(func(m): return int(m) < 1 or int(m) > 12):
		errors.append("%s: months must be 1-12" % id)
	var sun: Array = row.get("sun_degrees", [])
	if sun.size() != 2 or float(sun[0]) >= float(sun[1]) or float(sun[0]) < -90.0 or float(sun[1]) > 90.0:
		errors.append("%s: sun_degrees must be [low, high] within +-90" % id)
	for key: String in (row.get("requires", {}) as Dictionary):
		if not REQUIRE_KEYS.has(key): errors.append("%s: unknown requirement %s" % [id, key])
	_check_weather(id, row.get("weather", {}))
	var chance := float(row.get("chance_per_day", 0.0))
	if chance < 0.0 or chance > 0.05: errors.append("%s: chance_per_day must be 0-0.05" % id)
	if float(row.get("fade_minutes", 0)) <= 0.0: errors.append("%s: fade_minutes must be positive" % id)
	phenomena[id] = row
	ids_by_slot[slot] = id


func _check_weather(where: String, weather: Variant) -> void:
	if weather is not Dictionary: errors.append("%s: weather must be an object" % where); return
	for key: String in weather:
		if key not in WEATHER_KEYS: errors.append("%s: weather cannot force %s" % [where, key])
		elif key in BOOL_KEYS and weather[key] is not bool: errors.append("%s: %s must be true/false" % [where, key])


func _admit_occurrence(row: Variant, seasonal: Callable) -> Dictionary:
	if row is not Dictionary: errors.append("an occurrence is not an object"); return {}
	var id := str(row.get("id", ""))
	var date := str(row.get("date", ""))
	var where := "%s %s" % [id, date]
	if not phenomena.has(id): errors.append("%s: unknown phenomenon" % where); return {}
	var day := ordinal_of(date)
	if day < first_ordinal or day > last_ordinal: errors.append("%s: outside the campaign year" % where); return {}
	var clock := str(row.get("start", "")).split(":")
	if clock.size() != 2 or not clock[0].is_valid_int() or not clock[1].is_valid_int() \
			or int(clock[0]) > 23 or int(clock[1]) > 59:
		errors.append("%s: start must be HH:MM" % where); return {}
	var minutes := float(row.get("minutes", 0))
	if minutes < 1.0 or minutes > 600.0: errors.append("%s: minutes must be 1-600" % where); return {}
	var bearing := float(row.get("bearing_degrees", -1))
	if bearing < 0.0 or bearing >= 360.0: errors.append("%s: bearing_degrees must be 0-360" % where)
	var press: Dictionary = row.get("press", {})
	for field in ["headline", "record", "speaker"]:
		if str(press.get(field, "")) == "": errors.append("%s: press.%s is empty" % [where, field])
	_check_weather(where, row.get("weather", {}))
	var phenomenon: Dictionary = phenomena[id]
	var start := float(day) * 1440.0 + int(clock[0]) * 60.0 + int(clock[1])
	var entry := {"id": id, "date": date, "start": start, "end": start + minutes,
		"intensity": clampf(float(row.get("intensity", 1.0)), 0.0, 1.5),
		"bearing": deg_to_rad(bearing), "press": press,
		"weather": forcing(phenomenon, row.get("weather", {}))}
	var month := int(date.split("-")[1])
	if month not in (phenomenon.months as Array).map(func(m): return int(m)):
		errors.append("%s: out of season" % where)
	var elevation := sun_elevation(start + minutes * 0.5)
	var window: Array = phenomenon.sun_degrees
	if elevation < float(window[0]) or elevation > float(window[1]):
		errors.append("%s: sun at %.1f deg, outside %s" % [where, elevation, str(window)])
	if seasonal.is_valid():
		var conditions: Dictionary = seasonal.call(date)
		conditions.merge(entry.weather, true)
		var unmet := unmet_requirements(phenomenon, conditions)
		if not unmet.is_empty(): errors.append("%s: weather does not allow it (%s)" % [where, ", ".join(unmet)])
	return entry


## --- reading -----------------------------------------------------------------

static func forcing(phenomenon: Dictionary, extra: Variant) -> Dictionary:
	var weather: Dictionary = (phenomenon.get("weather", {}) as Dictionary).duplicate(true)
	if extra is Dictionary: weather.merge(extra, true)
	return weather


static func unmet_requirements(phenomenon: Dictionary, conditions: Dictionary) -> PackedStringArray:
	var unmet := PackedStringArray()
	var requires: Dictionary = phenomenon.get("requires", {})
	for key: String in requires:
		var rule: Array = REQUIRE_KEYS.get(key, [key, "is"])
		var have: Variant = conditions.get(rule[0], false if rule[1] == "is" else 0.0)
		var ok: bool
		match rule[1]:
			"is": ok = bool(have) == bool(requires[key])
			"min": ok = float(have) >= float(requires[key])
			_: ok = float(have) <= float(requires[key])
		if not ok: unmet.append(key)
	return unmet


## Whether a day's printed weather (both papers' ears) allows a phenomenon.
static func ear_allows(phenomenon: Dictionary, ear: String) -> bool:
	ear = ear.to_lower()
	for word: String in phenomenon.get("ear_none", []):
		if word in ear: return false
	var band: Array = phenomenon.get("ear_high_f", [])
	var high := RegEx.create_from_string("high (\\d+)").search(ear)
	if band.size() == 2 and high != null \
			and (int(high.get_string(1)) < int(band[0]) or int(high.get_string(1)) > int(band[1])):
		return false
	var wanted: Array = phenomenon.get("ear_any", [])
	return wanted.is_empty() or wanted.any(func(word): return str(word) in ear)


static func ordinal_of(date: String) -> int:
	var parts := date.split("-")
	if parts.size() != 3 or not parts[0].is_valid_int() or not parts[1].is_valid_int() or not parts[2].is_valid_int():
		return -1
	var month := int(parts[1]); var day := int(parts[2])
	if month < 1 or month > 12 or day < 1 or day > CampaignClock._days_in_month(int(parts[0]), month):
		return -1
	return CampaignClock._ordinal(int(parts[0]), month, day)


## Sun altitude for a campaign-local absolute minute (CampaignClock frame).
static func sun_elevation(absolute_minute: float) -> float:
	var utc := CampaignClock._datetime_from_minutes(absolute_minute - UTC_OFFSET_MINUTES)
	return CelestialEphemeris.altitude_degrees(CelestialEphemeris.sun_direction(utc, LATITUDE, LONGITUDE))


static func envelope(start: float, finish: float, fade: float, minute: float) -> float:
	if minute < start or minute > finish: return 0.0
	# Relative minutes: smoothstep calls absolute campaign minutes (~2.8 million,
	# a few apart) "equal" and would turn every fade into a step.
	var span := finish - start
	var edge := minf(fade, span * 0.5)
	var t := minute - start
	return smoothstep(0.0, edge, t) * (1.0 - smoothstep(span - edge, span, t))


## Seeded daily roll for phenomena with a chance_per_day. A rolled phenomenon
## shows once, inside its sun window, on a day whose seasonal weather and
## printed weather (ear_ok) allow it.
func rolls_for(ordinal: int, seed_value: int, seasonal_conditions: Dictionary,
		ear_ok := Callable()) -> Array:
	if _rolled.has(ordinal): return _rolled[ordinal]
	var found: Array = []
	var date := CampaignClock._date_from_ordinal(ordinal)
	for id: String in phenomena:
		var row: Dictionary = phenomena[id]
		var chance := float(row.get("chance_per_day", 0.0))
		if chance <= 0.0 or int(date.month) not in (row.months as Array).map(func(m): return int(m)): continue
		var rng := RandomNumberGenerator.new()
		rng.seed = hash("%s:%s:%d:%d" % [salt, id, ordinal, seed_value])
		if rng.randf() >= chance: continue
		var conditions := seasonal_conditions.duplicate(true)
		conditions.merge(row.get("weather", {}), true)
		if not unmet_requirements(row, conditions).is_empty(): continue
		var date_text := "%04d-%02d-%02d" % [date.year, date.month, date.day_of_month]
		if ear_ok.is_valid() and not bool(ear_ok.call(row, date_text)): continue
		# Quarter-hour scan for the first minutes inside the sun window.
		var window: Array = row.sun_degrees
		var inside: Array[float] = []
		for step in 96:
			var minute := float(ordinal) * 1440.0 + step * 15.0
			var elevation := sun_elevation(minute)
			if elevation >= float(window[0]) and elevation <= float(window[1]): inside.append(minute)
		if inside.is_empty(): continue
		var start: float = inside[rng.randi_range(0, inside.size() - 1)]
		var span := minf(rng.randf_range(35.0, 80.0), 15.0 * inside.size())
		found.append({"id": id, "date": date_text, "start": start, "end": start + span,
			"intensity": rng.randf_range(0.65, 1.0), "bearing": deg_to_rad(rng.randf_range(0.0, 360.0)),
			"press": {}, "weather": row.get("weather", {}), "rolled": true})
	_rolled[ordinal] = found
	return found


## Every occurrence showing at an absolute campaign minute, with its envelope.
func active_at(minute: float, rolled: Array = []) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var candidates: Array = occurrences.duplicate()
	candidates.append_array(rolled)
	for entry: Dictionary in candidates:
		if minute < float(entry.start) or minute > float(entry.end): continue
		var row: Dictionary = phenomena[entry.id]
		var level := envelope(entry.start, entry.end, float(row.fade_minutes), minute) * float(entry.intensity)
		if level <= 0.0: continue
		out.append({"id": entry.id, "slot": int(row.slot), "family": str(row.family),
			"flash": bool(row.get("flash", false)), "level": level, "bearing": float(entry.bearing),
			"progress": clampf((minute - float(entry.start)) / maxf(float(entry.end) - float(entry.start), 1.0), 0.0, 1.0),
			"weather": entry.weather, "label": str(row.label)})
	return out


## The next morning's papers notice what the sky did the day before.
func press_for_issue(issue_date: String) -> Array[Dictionary]:
	var out: Array[Dictionary] = []
	var issue_day := ordinal_of(issue_date)
	for entry: Dictionary in occurrences:
		if ordinal_of(str(entry.date)) + 1 == issue_day and not (entry.press as Dictionary).is_empty():
			out.append(entry.press)
	return out
