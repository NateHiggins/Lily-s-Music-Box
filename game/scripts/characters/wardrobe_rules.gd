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
	return today != NO_DAY and first != NO_DAY and today >= first and today < first + int(window.get("days", 0))


const NO_DAY := -2147483648


## A count of days that runs on through any year (the story is before 1970,
## where the engine's own clock does not go).
static func _day_number(date: String) -> int:
	var parts := date.split("-")
	if parts.size() != 3:
		return NO_DAY
	var year := int(parts[0])
	var month := int(parts[1])
	var day := int(parts[2])
	var shift := (14 - month) / 12
	var y := year + 4800 - shift
	var m := month + 12 * shift - 3
	return day + (153 * m + 2) / 5 + 365 * y + y / 4 - y / 100 + y / 400 - 32045


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

## The parts to wear for an outfit, from the notes of the parts a person owns
## (part name to its note: slot, set, tags). An outfit is a way of choosing:
## which sets to draw the top, bottom and footwear from, whether an outer
## layer is worn and of what kind, and whether the head is covered. Within
## that, the choice turns on the person and the day, so someone is not in the
## same blouse every morning, but is in the same one all of that day.
func parts_for(person: String, outfit: String, notes: Dictionary, date: String) -> Dictionary:
	var look: Dictionary = {}
	for row: Dictionary in table.get("looks", []):
		if str(row.outfit) == outfit:
			look = row
	if look.is_empty():
		return {"parts": [], "tint": ""}
	var sets: Array = look.sets
	var tag := str(look.over_tag)
	var chosen: Array = []
	for slot: String in ["top", "bottom", "feet"]:
		var tagged := _owned(notes, slot, [], tag) if not tag.is_empty() else []
		var pool: Array = tagged if not tagged.is_empty() else _owned(notes, slot, sets, "")
		if pool.is_empty():
			pool = _owned(notes, slot, [], "")
		if not pool.is_empty():
			chosen.append(pool[_turn(person, date, slot) % pool.size()])
	var over: Array = []
	match str(look.over):
		"always":
			over = _owned(notes, "over", sets, "")
		"sometimes":
			if _turn(person, date, "over?") % 2 == 0:
				over = _owned(notes, "over", sets, "")
		"tagged":
			over = _owned(notes, "over", [], tag)
	if not over.is_empty():
		chosen.append(over[_turn(person, date, "over") % over.size()])
	if bool(look.head):
		var hats := _owned(notes, "head", sets, "")
		if hats.is_empty():
			hats = _owned(notes, "head", [], "")
		if not hats.is_empty():
			chosen.append(hats[_turn(person, date, "head") % hats.size()])
	return {"parts": chosen, "tint": str(look.tint)}


## The colour a named tint lays over what is worn, or white for none.
func tint_colour(tint: String) -> Color:
	for row: Dictionary in table.get("tints", []):
		if str(row.name) == tint:
			var c: Array = row.colour
			return Color(float(c[0]), float(c[1]), float(c[2]))
	return Color.WHITE


static func _owned(notes: Dictionary, slot: String, sets: Array, tag: String) -> Array:
	var names: Array = []
	for part: String in notes:
		var note: Dictionary = notes[part]
		if str(note.get("slot", "")) != slot:
			continue
		if not sets.is_empty() and not (str(note.get("set", "")) in sets):
			continue
		if not tag.is_empty() and not (tag in (note.get("tags", []) as Array)):
			continue
		names.append(part)
	names.sort()
	return names


static func _turn(person: String, date: String, what: String) -> int:
	return absi(hash(person + "|" + date + "|" + what))
