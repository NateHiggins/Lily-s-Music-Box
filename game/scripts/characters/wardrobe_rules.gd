extends RefCounted
## Which outfit a person wears, read from one table. The table is ordered: the
## first rule whose conditions all hold names the outfit. A loop's own rule
## comes first (a visit can dress the house for its occasion), then the
## person's own rules (Jonah lives in his dressing gown), then the common ones.
##
## This decides nothing about the world. Whoever owns the facts hands them in:
## the temporal loop its anchor, the calendar its date and occasion, the
## weather its temperature and fall, the clock its hour, the resident's
## schedule its place and activity. The same facts always give the same outfit.
##
## The situation is a Dictionary with any of:
##   anchor       the loop lead being visited, or ""
##   date         "YYYY-MM-DD"
##   hour         0 to 24, fractional
##   place        "home", "hall", "lobby", "street", "yard", "roof", "bar", ...
##   activity     "sleep", "rest", "work", "errand", "party", "funeral", ...
##   occasion     a calendar occasion's name, or ""
##   weather      "clear", "rain", "snow", ...
##   celsius      the temperature outdoors

const DATA := "res://data/characters/wardrobe_rules.json"

var table: Dictionary = {}


func load_table() -> bool:
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(DATA))
	if parsed is not Dictionary or int(parsed.get("schema_version", 0)) != 1:
		return false
	table = parsed
	return true


## The outfit for a person in a situation, from those they own. `owned` empty
## means any outfit may be named.
func choose(person: String, situation: Dictionary, owned: Array = []) -> String:
	var candidates: Array = []
	for row: Dictionary in table.get("loops", []):
		if str(row.anchor) == str(situation.get("anchor", "")) and not str(row.anchor).is_empty():
			var people: Array = row.people
			if people.is_empty() or person in people:
				candidates.append(str(row.outfit))
	for row: Dictionary in table.get("people", []):
		if str(row.person) == person:
			for rule: Dictionary in row.rules:
				if _holds(rule, situation):
					candidates.append(str(rule.outfit))
	for rule: Dictionary in table.get("rules", []):
		if _holds(rule, situation):
			candidates.append(str(rule.outfit))
	for outfit: String in candidates:
		if owned.is_empty() or outfit in owned:
			return outfit
	var fallback := str(table.get("default_outfit", "casual"))
	return fallback if owned.is_empty() or fallback in owned else (str(owned[0]) if not owned.is_empty() else fallback)


func is_outdoors(situation: Dictionary) -> bool:
	return str(situation.get("place", "")) in (table.get("outdoors", []) as Array)


func is_cold(situation: Dictionary) -> bool:
	if situation.has("celsius"):
		return float(situation.celsius) < float(table.get("cold_below_celsius", 8))
	var parts := str(situation.get("date", "")).split("-")
	return parts.size() == 3 and float(parts[1]) in (table.get("cold_months", []) as Array)


## In the days after the death the house goes out in black.
func in_mourning(situation: Dictionary) -> bool:
	var window: Dictionary = table.get("mourning", {})
	var today := _day_number(str(situation.get("date", "")))
	var first := _day_number(str(window.get("from", "")))
	return today >= 0 and first >= 0 and today >= first and today < first + int(window.get("days", 0))


static func _day_number(date: String) -> int:
	var parts := date.split("-")
	if parts.size() != 3:
		return -1
	return int(Time.get_unix_time_from_datetime_dict({"year": int(parts[0]), "month": int(parts[1]), "day": int(parts[2]), "hour": 12, "minute": 0, "second": 0}) / 86400)


func _holds(rule: Dictionary, situation: Dictionary) -> bool:
	if rule.has("activities") and not (str(situation.get("activity", "")) in (rule.activities as Array)):
		return false
	if rule.has("places") and not (str(situation.get("place", "")) in (rule.places as Array)):
		return false
	if rule.has("occasions") and not (str(situation.get("occasion", "")) in (rule.occasions as Array)):
		return false
	if rule.has("weather") and not (str(situation.get("weather", "")) in (rule.weather as Array)):
		return false
	if rule.has("outdoors") and bool(rule.outdoors) != is_outdoors(situation):
		return false
	if rule.has("cold") and bool(rule.cold) != is_cold(situation):
		return false
	if rule.has("mourning") and bool(rule.mourning) != in_mourning(situation):
		return false
	if rule.has("hours"):
		var hour := float(situation.get("hour", -1.0))
		var within := false
		for span: Array in rule.hours:
			within = within or (hour >= float(span[0]) and hour < float(span[1]))
		if not within:
			return false
	return true
