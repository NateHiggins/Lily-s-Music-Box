extends Node
## The wardrobe table: given a loop, a date, an hour, a place, an activity and
## the weather, each person is dressed the same way every time, and sensibly.

const Rules := preload("res://scripts/characters/wardrobe_rules.gd")

var _fails := 0
var _checks := 0


func _check(ok: bool, label: String) -> void:
	_checks += 1
	if not ok:
		_fails += 1
		print("  [FAIL] ", label)


func _ready() -> void:
	var rules := Rules.new()
	_check(rules.load_table(), "the wardrobe table loads")
	var cases := [
		["mina_vale", {"date": "1929-06-04", "hour": 10.0, "place": "home", "activity": "rest", "weather": "clear", "celsius": 21}, "casual", "at home on a June morning: casual"],
		["mina_vale", {"date": "1929-06-04", "hour": 23.5, "place": "home", "activity": "rest"}, "night", "at home late: night wear"],
		["mina_vale", {"date": "1929-06-04", "hour": 14.0, "place": "home", "activity": "sleep"}, "night", "asleep in the afternoon: night wear"],
		["mina_vale", {"date": "1929-06-04", "hour": 11.0, "place": "street", "activity": "errand", "celsius": 21}, "formal", "out on the street in June: formal"],
		["mina_vale", {"date": "1929-01-15", "hour": 11.0, "place": "street", "activity": "errand"}, "winter", "out on the street in January: winter coat"],
		["mina_vale", {"date": "1929-10-02", "hour": 11.0, "place": "street", "activity": "errand", "celsius": 3}, "winter", "a cold October day by the thermometer: winter coat"],
		["mina_vale", {"date": "1929-04-09", "hour": 11.0, "place": "yard", "activity": "errand", "weather": "snow", "celsius": 9}, "winter", "April snow: winter coat"],
		["mina_vale", {"date": "1929-01-15", "hour": 11.0, "place": "home", "activity": "rest"}, "casual", "January indoors: no coat"],
		["cal_dwyer", {"date": "1929-06-04", "hour": 13.0, "place": "home", "activity": "work"}, "work", "at work: work dress"],
		["cal_dwyer", {"date": "1929-06-07", "hour": 21.0, "place": "bar", "activity": "rest"}, "occasion", "the Harukiya in the evening: dressed for it"],
		["cal_dwyer", {"date": "1929-06-07", "hour": 12.0, "place": "bar", "activity": "rest"}, "casual", "the bar at noon is not an occasion"],
		["evelyn_marsh", {"date": "1929-10-12", "hour": 20.0, "place": "roof", "activity": "party", "celsius": 6}, "occasion", "the Emergence on the roof: best clothes, though it is cold"],
		["lena_ortiz", {"date": "1929-10-12", "hour": 16.0, "place": "home", "occasion": "emergence", "activity": "rest"}, "occasion", "the day of an occasion: dressed for it at home"],
		["omar_bell", {"date": "1929-07-24", "hour": 11.0, "place": "street", "activity": "errand", "celsius": 27}, "mourning", "out in the days after the death: mourning"],
		["omar_bell", {"date": "1929-07-24", "hour": 11.0, "place": "home", "activity": "rest"}, "casual", "at home in those days: not in black"],
		["omar_bell", {"date": "1929-08-20", "hour": 11.0, "place": "street", "activity": "errand", "celsius": 27}, "formal", "a month on: mourning is over"],
		["omar_bell", {"date": "1929-07-19", "hour": 11.0, "place": "street", "activity": "errand", "celsius": 27}, "formal", "the day before the death: no mourning"],
		["peter_wren", {"date": "1929-07-24", "hour": 10.0, "place": "street", "activity": "funeral"}, "mourning", "a funeral: mourning"],
		["jonah_price", {"date": "1929-06-04", "hour": 15.0, "place": "home", "activity": "rest"}, "night", "Jonah at home at three in the afternoon: his dressing gown"],
		["jonah_price", {"date": "1929-06-04", "hour": 15.0, "place": "street", "activity": "errand", "celsius": 20}, "formal", "Jonah out of doors: dressed"],
		["teresa_vale", {"date": "1929-06-04", "hour": 23.0, "place": "home", "activity": "work"}, "work", "Teresa on her night shift: her uniform, not night wear"],
		["iris_bell", {"date": "1929-06-04", "hour": 11.0, "place": "home", "activity": "rest"}, "work", "Iris at home by day: her painting overalls"],
		["nadia_quell", {"anchor": "drama", "date": "1929-08-24", "hour": 9.0, "place": "home", "activity": "rest"}, "occasion", "a loop that dresses the house: everyone, whatever the hour"],
		["rhea_sato", {"anchor": "friday", "date": "1929-07-19", "hour": 15.0, "place": "home", "activity": "rest"}, "occasion", "a loop that dresses only some: one of them"],
		["cal_dwyer", {"anchor": "friday", "date": "1929-07-19", "hour": 15.0, "place": "home", "activity": "rest"}, "casual", "and someone it does not name"],
		["mae_kessler", {"date": "1928-12-25", "hour": 13.0, "place": "home", "activity": "rest", "occasion": "Christmas"}, "occasion", "Christmas Day from the calendar: best clothes"],
		["nadia_quell", {"anchor": "some_other_lead", "date": "1929-06-04", "hour": 9.0, "place": "home", "activity": "rest"}, "casual", "a loop with no rule of its own: the common rules"],
	]
	for row: Array in cases:
		var got := rules.choose(str(row[0]), row[1])
		_check(got == str(row[2]), "%s (%s wears %s)" % [row[3], row[0], got])
	_check(rules.choose("mina_vale", {"date": "1929-01-15", "hour": 11.0, "place": "street"}, ["casual", "formal"]) == "formal", "someone with no winter coat goes out in the next thing that fits")
	_check(rules.choose("mina_vale", {"date": "1929-06-04", "hour": 23.5, "place": "home"}, ["formal"]) == "formal", "someone who owns one outfit wears it")
	var first := rules.choose("rhea_sato", {"date": "1929-06-08", "hour": 22.0, "place": "bar", "activity": "performance"})
	_check(first == rules.choose("rhea_sato", {"date": "1929-06-08", "hour": 22.0, "place": "bar", "activity": "performance"}) and first == "occasion", "the same facts give the same outfit")
	# Parts: three sets of five, as the cast builder writes them.
	var notes: Dictionary = {}
	for letter: String in ["a", "b", "c"]:
		for slot: String in ["top", "bottom", "over", "head", "feet"]:
			notes["%s_%s" % [letter, slot]] = {"slot": slot, "set": letter, "tags": []}
	notes["a_over"].tags = ["work"]
	notes["b_over"].tags = ["warm"]
	notes["c_over"].tags = ["night"]
	notes["c_top"].tags = ["night"]
	notes["c_bottom"].tags = ["night"]
	var formal: Dictionary = rules.parts_for("mina_vale", "formal", notes, "1929-06-04")
	_check((formal.parts as Array).size() == 5 and "b_over" in formal.parts and "b_head" in formal.parts and "b_top" in formal.parts, "formal: the street set, coat and hat on (%s)" % [formal.parts])
	var night: Dictionary = rules.parts_for("mina_vale", "night", notes, "1929-06-04")
	_check("c_over" in night.parts and "c_top" in night.parts and "c_bottom" in night.parts and not ("b_head" in night.parts or "a_head" in night.parts or "c_head" in night.parts),
		"night: the parts made for night, and no hat (%s)" % [night.parts])
	var winter: Dictionary = rules.parts_for("mina_vale", "winter", notes, "1929-01-15")
	_check("b_over" in winter.parts and (winter.parts as Array).any(func(part: String) -> bool: return part.ends_with("_head")), "winter: the warm outer layer and a hat (%s)" % [winter.parts])
	var working: Dictionary = rules.parts_for("mina_vale", "work", notes, "1929-06-04")
	_check("a_over" in working.parts, "work: the working layer (%s)" % [working.parts])
	var mourning: Dictionary = rules.parts_for("mina_vale", "mourning", notes, "1929-07-24")
	_check(str(mourning.tint) == "mourning" and rules.tint_colour("mourning").v < 0.3 and rules.tint_colour("") == Color.WHITE, "mourning: the street clothes, darkened")
	var same: Dictionary = rules.parts_for("mina_vale", "casual", notes, "1929-06-04")
	_check(same.parts == rules.parts_for("mina_vale", "casual", notes, "1929-06-04").parts, "the same person on the same day wears the same things")
	var seen: Dictionary = {}
	var slots_ok := true
	for day in 28:
		var worn: Dictionary = rules.parts_for("mina_vale", "casual", notes, "1929-06-%02d" % (day + 1))
		seen[str(worn.parts)] = true
		var slots: Dictionary = {}
		for part: String in worn.parts:
			slots_ok = slots_ok and not slots.has(notes[part].slot)
			slots[notes[part].slot] = true
		slots_ok = slots_ok and slots.has("top") and slots.has("bottom") and slots.has("feet")
	_check(seen.size() >= 4, "across a month the casual choices vary (%d different)" % seen.size())
	_check(slots_ok, "every choice has a top, a bottom and footwear, and one part to a slot")
	var apart := 0
	for day in 28:
		var date := "1929-06-%02d" % (day + 1)
		if rules.parts_for("cal_dwyer", "casual", notes, date).parts != rules.parts_for("mina_vale", "casual", notes, date).parts:
			apart += 1
	_check(apart >= 14, "two people do not move in step (%d of 28 days differ)" % apart)
	_check((rules.parts_for("mina_vale", "formal", {"a_top": {"slot": "top", "set": "a", "tags": []}}, "1929-06-04").parts as Array) == ["a_top"], "someone with one part wears it")
	print("WARDROBE RULES TEST: %s (%d checks, %d failures)" % ["PASS" if _fails == 0 else "FAIL", _checks, _fails])
	get_tree().quit(0 if _fails == 0 else 1)
