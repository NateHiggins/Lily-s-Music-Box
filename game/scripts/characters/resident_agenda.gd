class_name ResidentAgenda
extends Node
## The residents' motives (design/ORISON_RESIDENT_AGENDA_2026-10-24.md).
##
## The timetable (ScheduleDirector, resident_schedules.json) says where each
## resident is meant to be. This layer decides where they actually go: every
## ten campaign minutes it scores the timetable block against needs-driven
## options (food, rest, washing, company, purpose, air, warmth), the
## resident's compulsions and, once their story beat is resolved, what they
## do instead, their friends and the people they avoid, the weather, the
## season's daylight, and the player. Hard blocks (sleep, work, transit,
## ritual) always hold; everything else can bend.
##
## Answers have the timetable block's shape (`place`, `activity`, `start_min`,
## `end_min`), so every consumer of ScheduleDirector.resolve() can ask this
## instead and gets the reason too (`source`, `why`, `motive`).
##
## Determinism: live state steps forward on the campaign clock. A load, a
## day change or a clock jump reconstructs the last six hours from the
## authored starting needs, with the present weather and no player, so the
## same campaign minute always gives the same building.

const SOURCE := "res://data/resident_motives.json"
const CASES := "res://data/reality_cases.json"
const WEATHER := preload("res://scripts/building/WeatherManager.gd")
const RECONSTRUCT_MINUTES := 360
const SHARED := ["lobby", "mail_bank", "laundry", "roof", "light_court", "bodega",
		"harukiya_bar", "luncheonette", "hand_laundry", "news_cigars",
		"photo_supplies", "otis_son", "hardware_paint"]

var director: ScheduleDirector
var motives: Dictionary = {}
var step := 10
var order: Array[String] = []
var enabled := false
var live_day := ""
var live_doy := -1
var live_minute := -1
var _live: Dictionary = {}
var _arcs: Dictionary = {}
var _units: Dictionary = {}
var _allowed: Dictionary = {}
var _conditions := Callable()
var _player_place := Callable()
var _knows := Callable()
var _trust := Callable()
var _accum := 0.0
var _cache_key := ""
var _cache: Dictionary = {}
## The households' pantries and iceboxes; null leaves meals to the timetable.
var larder: KitchenLarder
## Kitchen events are stamped in elapsed campaign minutes; a bench without a
## running clock stamps them by day of year instead.
var clock_stamps := true


## conditions() -> WeatherManager-style conditions; player_place() -> an
## agenda place token ("lobby", "corridor:F04", ...) or ""; knows(flag) ->
## bool; trust(resident) -> int. Each may be left invalid.
func setup(schedule: ScheduleDirector, conditions := Callable(), player_place := Callable(),
		knows := Callable(), trust := Callable()) -> bool:
	director = schedule
	_conditions = conditions
	_player_place = player_place
	_knows = knows
	_trust = trust
	var parsed: Variant = JSON.parse_string(FileAccess.get_file_as_string(SOURCE))
	if parsed is not Dictionary or float((parsed as Dictionary).get("schema_version", 0)) != 1.0:
		push_error("resident motives unreadable: " + SOURCE)
		return false
	motives = parsed
	step = int(motives.step_minutes)
	print("[AGENDA] motives from %s" % str(motives.source))
	var cases: Variant = JSON.parse_string(FileAccess.get_file_as_string(CASES))
	if cases is Dictionary:
		for case: Variant in (cases as Dictionary).values():
			var flags: Array = (case as Dictionary).get("resolution_flags", [])
			if flags.size() >= 2:
				_arcs[str((case as Dictionary).resident_id)] = [str(flags[0]), str(flags[1])]
	if director == null or director.data.is_empty():
		return false
	for slug: String in motives.residents:
		if not director.data.residents.has(slug):
			push_error("resident motives name an unknown resident: " + slug)
			return false
		order.append(slug)
		_units[slug] = str(director.data.residents[slug].unit)
	order.sort()
	enabled = true
	return true


## Resident id -> home unit, for the households' larders.
func homes() -> Dictionary:
	return _units.duplicate()


## Keep a resident's choices to places their body can reach (Mina's route
## graph). The timetable block is always allowed.
func restrict(slug: String, places: Array) -> void:
	_allowed[slug] = places.duplicate()


## Where the resident is and why, at a campaign minute. The live state answers
## the present; any other minute is simulated from that day's midnight.
func decide(slug: String, day: String, minute: float, doy: int, first_sat: bool) -> Dictionary:
	if not enabled or not order.has(slug):
		return director.resolve(slug, day, minute, doy, first_sat) if director else {}
	var m := int(minute)
	if day == live_day and doy == live_doy and _live.has(slug) and m >= live_minute - step and m <= live_minute + step:
		return _decision(slug, _live[slug])
	var today := director.day_info()
	if str(today.get("day", "")) == day and int(today.get("doy", -1)) == doy \
			and absf(ScheduleDirector.minute_now() - minute) <= float(step):
		advance(day, doy, first_sat, m)
		return _decision(slug, _live[slug])
	var key := "%s|%d|%s|%d" % [day, doy, first_sat, m - m % step]
	if key != _cache_key:
		_cache = _simulate(day, doy, first_sat, maxi(0, m - RECONSTRUCT_MINUTES), m, false)
		_cache_key = key
	return _decision(slug, _cache[slug])


## The whole day as lived: [{start, end, place, activity, source, why}, ...].
func day_plan(slug: String, day: String, doy: int, first_sat: bool) -> Array:
	var states := _simulate(day, doy, first_sat, 0, 1440 - step, true)
	return states[slug].log if states.has(slug) else []


func _process(delta: float) -> void:
	if not enabled:
		return
	_accum += delta
	if _accum < 1.0:
		return
	_accum = 0.0
	var info := director.day_info()
	if not bool(info.get("valid", false)):
		return
	advance(str(info.day), int(info.doy), bool(info.first_sat), int(ScheduleDirector.minute_now()))


## Bring the live building to a campaign minute: step forward, or reconstruct
## after a load, a new day or a jump.
func advance(day: String, doy: int, first_sat: bool, minute: int) -> void:
	var target := minute - minute % step
	var now := _now_stamp(doy, target)
	# Midnight carries the household over; anything else unexpected rebuilds.
	var next_day := live_doy >= 0 and (doy == live_doy + 1 or (live_doy == 365 and doy == 1)) \
			and live_minute >= 1440 - 60 and target <= 60 and not _live.is_empty()
	if next_day:
		var at := 0
		while at <= target:
			_step(_live, day, doy, first_sat, at, true, false, now - float(target - at))
			at += step
	elif day != live_day or doy != live_doy or target < live_minute or target - live_minute > 60 or _live.is_empty():
		_live = _simulate(day, doy, first_sat, maxi(0, target - RECONSTRUCT_MINUTES), target, false)
	else:
		var at := live_minute + step
		while at <= target:
			_step(_live, day, doy, first_sat, at, true, false, now - float(target - at))
			at += step
	live_day = day
	live_doy = doy
	live_minute = target


func _simulate(day: String, doy: int, first_sat: bool, from: int, until: int, keep_log: bool) -> Dictionary:
	var states := {}
	for slug in order:
		var needs := {}
		for need: String in motives.needs:
			needs[need] = float(motives.needs[need].start)
		states[slug] = {"needs": needs, "choice": {}, "key": "", "until": -1, "log": []}
	var at := from - from % step
	while at <= until:
		_step(states, day, doy, first_sat, at, false, keep_log)
		at += step
	return states


## ---- one step ---------------------------------------------------------

func _step(states: Dictionary, day: String, doy: int, first_sat: bool, minute: int,
		live: bool, keep_log: bool, stamp := -1.0) -> void:
	var weather := _weather(doy)
	var light := _daylight(doy, minute)
	var player := str(_player_place.call()) if live and _player_place.is_valid() else ""
	var hours := float(step) / 60.0
	var chosen := {}
	for slug in order:
		var state: Dictionary = states[slug]
		var block := director.resolve(slug, day, float(minute), doy, first_sat)
		var pick := _choose(slug, state, block, minute, weather, light, player, states)
		chosen[slug] = pick
		# Residents choose in turn: those after see where those before are going.
		state.next = pick
	for slug in order:
		var state: Dictionary = states[slug]
		var pick: Dictionary = chosen[slug]
		_satisfy(slug, state, pick, weather, hours)
		if live and larder != null and str(pick.key) != str(state.key):
			_kitchen_event(slug, pick, stamp, minute)
		if str(pick.key) != str(state.key):
			if keep_log:
				state.log.append({"start": minute, "end": minute + step, "place": pick.place,
						"activity": pick.activity, "source": pick.source, "why": pick.why})
			state.since = minute
			state.until = minute + int(pick.minutes) if str(pick.source) != "timetable" else -1
		elif keep_log and not state.log.is_empty():
			state.log[-1].end = minute + step
		state.key = pick.key
		state.choice = pick
		state.erase("next")
	if live and larder != null:
		larder.spoil(stamp)


func _choose(slug: String, state: Dictionary, block: Dictionary, minute: int,
		weather: Dictionary, light: bool, player: String, states: Dictionary) -> Dictionary:
	var spec: Dictionary = motives.residents[slug]
	var traits: Dictionary = spec.traits
	var arc := _arc(slug)
	var candidates: Array[Dictionary] = []
	var duty := str(block.get("activity", "rest"))
	candidates.append({"key": "timetable|%s|%s" % [block.get("place", "unit"), duty],
			"place": str(block.get("place", "unit")), "activity": duty, "source": "timetable",
			"why": str(block.get("detail", "keeps to the timetable")), "minutes": step,
			"needs": {}, "hard": duty in motives.hard_activities})
	for option: Dictionary in motives.options:
		candidates.append(_candidate(option, "need", "need|" + str(option.id)))
	if arc < 2:
		for option: Dictionary in spec.shadow:
			candidates.append(_candidate(option, "shadow", "shadow|" + str(option.place)))
	else:
		for option: Dictionary in spec.growth:
			candidates.append(_candidate(option, "growth", "growth|" + str(option.place)))
	for friend: String in spec.friends:
		var other: Dictionary = states.get(friend, {}).get("choice", {})
		var unit := str(_units.get(friend, ""))
		if unit == "" or unit == str(_units[slug]) or other.is_empty():
			continue
		if str(other.place).begins_with("unit") and str(other.activity) not in ["sleeping", "shower"]:
			candidates.append(_candidate(motives.visit, "friend", "visit|" + unit,
					"visit:" + unit, "socializing"))
	if larder != null:
		_kitchen_candidates(slug, state, minute, traits, candidates)
	var trust := int(_trust.call(slug)) if _trust.is_valid() else 0
	var meet := "corridor" if player == "corridor:F0" + str(_units[slug]).left(1) else player
	# A trusted night man is worth seeking out where anyone may be: a shared
	# room, or the corridor of the resident's own floor.
	if trust >= int(motives.player.seek_trust) and (SHARED.has(meet) or meet == "corridor"):
		candidates.append({"key": "player|" + meet, "place": meet, "activity": "socializing",
				"source": "player", "why": str(motives.player.seek_why), "minutes": 30,
				"needs": {"company": 0.3}, "hours": [0, 1440]})
	# A choice made for a need is seen through: until its time is up it holds,
	# unless a hard block (sleep, work, transit, ritual) begins.
	var current: Dictionary = state.get("choice", {})
	if int(state.until) > minute and not current.is_empty() and str(current.source) != "timetable" \
			and not bool(candidates[0].hard) and not _avoided_there(slug, current, states):
		for candidate in candidates:
			if str(candidate.key) == str(state.key) and _open(slug, candidate, minute, light, traits):
				var held := candidate.duplicate()
				held.block = block
				held.motive = _motive(slug, state, held, weather)
				return held
	var best: Dictionary = {}
	var best_score := -INF
	for candidate in candidates:
		if not _open(slug, candidate, minute, light, traits):
			continue
		var score := _score(slug, state, candidate, weather, traits, arc, states)
		if player != "" and trust <= int(motives.player.avoid_trust) and _same_place(slug, candidate, player):
			score -= 1.2
		if str(candidate.key) == str(state.key):
			score += 0.6 if int(state.until) > minute else 0.1
		if score > best_score:
			best_score = score
			best = candidate
	best = best.duplicate()
	# Kept out of the timetable's room by the night man being in it.
	if player != "" and trust <= int(motives.player.avoid_trust) and str(best.source) != "timetable" \
			and _same_place(slug, candidates[0], player):
		best.source = "player"
		best.why = str(motives.player.avoid_why)
	best.block = block
	best.motive = _motive(slug, state, best, weather)
	return best


func _candidate(option: Dictionary, source: String, key: String, place := "", activity := "") -> Dictionary:
	return {"key": key, "place": place if place != "" else str(option.place),
			"activity": activity if activity != "" else str(option.activity), "source": source,
			"why": str(option.why), "minutes": int(option.minutes), "hours": option.hours,
			"daylight": bool(option.get("daylight", false)), "needs": option.get("needs", {})}


func _open(slug: String, candidate: Dictionary, minute: int, light: bool, traits: Dictionary) -> bool:
	if str(candidate.source) == "timetable":
		return true
	var hours: Array = candidate.get("hours", [0, 1440])
	if minute < int(hours[0]) or minute >= int(hours[1]):
		return false
	if bool(candidate.get("daylight", false)) and not light and float(traits.night) < 0.8:
		return false
	var place := str(candidate.place)
	var spec: Dictionary = motives.residents[slug]
	if spec.avoid_places.has(place) and str(candidate.source) != "growth":
		return false
	if _allowed.has(slug):
		var allowed: Array = _allowed[slug]
		if not allowed.has(place) and not (place.begins_with("unit") and allowed.has("unit")):
			return false
	return true


func _score(slug: String, state: Dictionary, candidate: Dictionary, weather: Dictionary,
		traits: Dictionary, arc: int, states: Dictionary) -> float:
	var gains := _gains(candidate, weather)
	var score := 0.0
	for need: String in gains:
		score += _weight(need, traits) * _urgency(float(state.needs[need])) * float(gains[need])
	var place := str(candidate.place)
	var root := _root(place)
	var exposed := bool(motives.places.get(root, {}).get("exposed", false))
	score += float(candidate.get("bonus", 0.0))
	match str(candidate.source):
		"timetable":
			# A resolved story beat loosens the hold of the routine itself.
			score += 0.25 + float(traits.routine) * (0.35 if arc == 2 else 0.6)
			if bool(candidate.hard):
				score += 2.0
		"shadow":
			score += 0.15 if arc == 0 else 0.05
		"growth":
			score += 0.5
		"player":
			score += 0.25
	if exposed:
		score -= (1.0 - float(traits.hardy)) * (float(weather.rain) * 0.7 + float(weather.snow) * 0.9
				+ float(weather.cold) * 0.4 + float(weather.heat) * 0.2 + float(weather.wind) * 0.2)
	if not place.begins_with("unit"):
		score -= float(traits.homebody) * 0.15
	var spec: Dictionary = motives.residents[slug]
	for other: String in spec.avoid_people:
		if states.has(other) and _same_place(slug, candidate, _where(states, other)):
			score -= 1.5
	for friend: String in spec.friends:
		if states.has(friend) and str(candidate.source) != "timetable" \
				and _same_place(slug, candidate, _where(states, friend)):
			score += 0.25 * float(traits.sociable)
	return score


## Where another resident is going this step if they have chosen, else where
## they were.
func _where(states: Dictionary, other: String) -> String:
	var state: Dictionary = states.get(other, {})
	return str(state.get("next", state.get("choice", {})).get("place", ""))


func _avoided_there(slug: String, choice: Dictionary, states: Dictionary) -> bool:
	for other: String in motives.residents[slug].avoid_people:
		if states.has(other) and _same_place(slug, choice, _where(states, other)):
			return true
	return false


## Per-hour need changes for a choice: its activity, its place, and the
## option's own authored effect. Exposure in the cold costs warmth.
func _gains(candidate: Dictionary, weather: Dictionary) -> Dictionary:
	var gains := {}
	for source: Dictionary in [motives.activities.get(str(candidate.activity), {}),
			motives.places.get(_root(str(candidate.place)), {}), candidate.get("needs", {})]:
		for need: String in source:
			if motives.needs.has(need):
				gains[need] = float(gains.get(need, 0.0)) + float(source[need])
	if bool(motives.places.get(_root(str(candidate.place)), {}).get("exposed", false)):
		gains["warmth"] = float(gains.get("warmth", 0.0)) - float(weather.cold) * 0.6
	return gains


func _satisfy(slug: String, state: Dictionary, pick: Dictionary, weather: Dictionary, hours: float) -> void:
	var traits: Dictionary = motives.residents[slug].traits
	var gains := _gains(pick, weather)
	for need: String in motives.needs:
		var decay := float(motives.needs[need].decay)
		if need == "company":
			decay *= 0.5 + float(traits.sociable)
		elif need == "air":
			decay *= 1.0 + float(weather.heat)
		if str(pick.activity) == "sleeping":
			# Asleep, nobody is lonely and hunger slows.
			if need == "rest" or need == "company":
				decay = 0.0
			elif need == "food":
				decay *= 0.4
		state.needs[need] = clampf(float(state.needs[need]) + (float(gains.get(need, 0.0)) - decay) * hours, 0.0, 1.0)


func _decision(slug: String, state: Dictionary) -> Dictionary:
	var pick: Dictionary = state.choice
	if pick.is_empty():
		return {}
	var block: Dictionary = pick.block
	var out := {"place": pick.place, "activity": pick.activity, "source": pick.source,
			"why": pick.why, "motive": pick.motive, "start_min": int(state.get("since", 0)),
			"end_min": int(block.get("end_min", 1440)) if str(pick.source) == "timetable" else int(state.until),
			"timetable_place": str(block.get("place", "unit")), "deviation": str(pick.source) != "timetable"}
	if str(pick.source) == "timetable":
		for key in ["detail", "outfit", "with", "knowledge", "route"]:
			if block.has(key):
				out[key] = block[key]
	return out


## ---- the kitchen ------------------------------------------------------

## Shopping for the resident's dish where something is short, cooking it when
## everything is in and nothing is left, eating what is cooked, and washing up
## once the stack passes what this household tolerates.
func _kitchen_candidates(slug: String, state: Dictionary, minute: int, traits: Dictionary,
		candidates: Array[Dictionary]) -> void:
	var unit := larder.unit_of(slug)
	var dish := larder.dish_of(slug)
	if unit == "" or dish.is_empty():
		return
	var k: Dictionary = motives.kitchen
	# Shopping is for the next pot: nobody goes out again while one is full.
	var stop := larder.shopping_stop(slug, minute) if larder.portions(unit) == 0 else ""
	var shop_hours: Array = k.shop_hours
	var shop_open := (minute >= int(shop_hours[0]) and minute < int(shop_hours[1])) or float(traits.night) >= 0.8
	if stop != "" and shop_open:
		var place := stop
		# A body that cannot reach the shop runs the errand off the map.
		if _allowed.has(slug) and not (_allowed[slug] as Array).has(stop):
			place = "out" if (_allowed[slug] as Array).has("out") else ""
		if place != "":
			candidates.append({"key": "kitchen|shop|" + stop, "place": place, "activity": "shopping",
					"source": "kitchen", "shop": stop, "minutes": int(k.shop_minutes), "needs": {},
					"why": "shops at %s for the %s" % [larder.groceries.shops[stop].name, dish.name],
					"bonus": float(k.shop_bonus) + 0.1 * float(mini(5, larder.missing(slug).size()))
							+ 0.5 * _urgency(float(state.needs.food))})
	var hours: Array = k.cook_hours
	var cook_open := (minute >= int(hours[0]) and minute < int(hours[1])) or float(traits.night) >= 0.8
	if larder.portions(unit) == 0 and cook_open and larder.can_cook(slug):
		candidates.append({"key": "kitchen|cook", "place": "unit:kitchen", "activity": "cooking",
				"source": "kitchen", "minutes": mini(int(dish.minutes), int(k.cook_minutes_cap)),
				"needs": {"food": 0.3}, "why": "cooks the " + str(dish.name), "bonus": float(k.cook_bonus)})
	if larder.portions(unit) > 0:
		candidates.append({"key": "kitchen|eat", "place": "unit:kitchen", "activity": "eating",
				"source": "kitchen", "minutes": int(k.eat_minutes), "needs": {},
				"why": "eats what is left in the pot", "bonus": float(k.eat_bonus)})
	var stack := larder.dirty(unit)
	if stack >= larder.dirty_limit(unit):
		candidates.append({"key": "kitchen|wash", "place": "unit:kitchen", "activity": "dishes",
				"source": "kitchen", "minutes": int(k.wash_minutes), "needs": {},
				"why": "washes up %d pieces" % stack,
				"bonus": float(k.wash_bonus) + 0.05 * float(stack - larder.dirty_limit(unit))})


## A new choice's effect on the household's stock, whoever proposed it: the
## timetable's own meals and chores cook, eat and wash up too.
func _kitchen_event(slug: String, pick: Dictionary, stamp: float, minute: int) -> void:
	var at_home := str(pick.place).begins_with("unit")
	match str(pick.activity):
		"shopping", "errand":
			# The timetable's own errand to a counter buys what is short there too.
			var shop := str(pick.get("shop", pick.place))
			if larder.groceries.shops.has(shop):
				larder.shop(slug, shop, stamp)
		"cooking":
			if at_home:
				larder.cook(slug, stamp)
		"eating":
			if at_home:
				# A meal at home with the pot empty is cooked first, if it can be
				# and it is an hour for cooking (night people keep their own).
				var hours: Array = motives.kitchen.cook_hours
				var cooking_hour := (minute >= int(hours[0]) and minute < int(hours[1])) \
						or float(motives.residents[slug].traits.night) >= 0.8
				if cooking_hour and larder.portions(larder.unit_of(slug)) == 0 and larder.can_cook(slug):
					larder.cook(slug, stamp)
				larder.eat(slug, stamp)
		"dishes":
			larder.wash_up(slug, stamp)
		"chores":
			if at_home and larder.dirty(larder.unit_of(slug)) > 0:
				larder.wash_up(slug, stamp)


func _now_stamp(doy: int, minute: int) -> float:
	if clock_stamps and director.campaign_clock != null and director.campaign_clock.bind_state():
		return floorf(director.campaign_clock.elapsed_minutes())
	return float(doy * 1440 + minute)


## ---- inputs -----------------------------------------------------------

## 0 before the first resolution flag, 1 once named, 2 once resolved.
func _arc(slug: String) -> int:
	if not _knows.is_valid() or not _arcs.has(slug):
		return 0
	var flags: Array = _arcs[slug]
	if bool(_knows.call(str(flags[1]))):
		return 2
	return 1 if bool(_knows.call(str(flags[0]))) else 0


func _weather(doy: int) -> Dictionary:
	var raw: Dictionary = {}
	if _conditions.is_valid():
		raw = _conditions.call()
	if raw.is_empty():
		raw = WEATHER.seasonal_snapshot(_date_of(doy))
	var t := float(raw.get("temperature_c", 12.0))
	return {"rain": clampf(float(raw.get("rain_intensity", 0.0)) / 1.5, 0.0, 1.0),
			"snow": clampf(float(raw.get("snow_intensity", 0.0)), 0.0, 1.0),
			"cold": clampf((8.0 - t) / 18.0, 0.0, 1.0), "heat": clampf((t - 28.0) / 8.0, 0.0, 1.0),
			"wind": clampf((float(raw.get("wind_speed_kmh", 0.0)) - 30.0) / 30.0, 0.0, 1.0)}


## New York daylight by day of year, local noon at 12:00.
static func _daylight(doy: int, minute: int) -> bool:
	var length := 12.0 + 3.0 * sin(TAU * float(doy - 80) / 365.0)
	return absf(float(minute) - 720.0) < length * 30.0


static func _date_of(doy: int) -> Dictionary:
	var left := clampi(doy, 1, 365)
	for month in 12:
		if left <= int(ScheduleDirector.MONTH_DAYS[month]):
			return {"month": month + 1, "day": left}
		left -= int(ScheduleDirector.MONTH_DAYS[month])
	return {"month": 12, "day": 31}


## ---- places -----------------------------------------------------------

func _root(place: String) -> String:
	if place.begins_with("unit"):
		return "unit"
	if place.begins_with("visit:"):
		return "visit"
	return place.split(":")[0]


## Shared places are one room for everybody; a corridor is one per floor;
## a flat is shared only by a visit to it.
func _same_place(slug: String, candidate: Dictionary, other: String) -> bool:
	var place := str(candidate.place)
	if other == "" or place.begins_with("unit"):
		return false
	if place == "corridor" or place == "stairs" or place == "half_landing":
		return other == "corridor:F0" + str(_units[slug]).left(1)
	return place == other or (place.begins_with("corridor:") and place == other)


## The need this choice serves most, for the `motive` field.
func _motive(slug: String, state: Dictionary, pick: Dictionary, weather: Dictionary) -> String:
	var traits: Dictionary = motives.residents[slug].traits
	var gains := _gains(pick, weather)
	var best := ""
	var best_value := 0.0
	for need: String in gains:
		var value := _weight(need, traits) * _urgency(float(state.needs[need])) * float(gains[need])
		if value > best_value:
			best_value = value
			best = need
	return best


func _weight(need: String, traits: Dictionary) -> float:
	if need == "company":
		return 0.4 + float(traits.sociable)
	if need == "air":
		return 0.3 + (1.0 - float(traits.homebody)) * 0.5
	return 1.0


static func _urgency(level: float) -> float:
	return (1.0 - level) * (1.0 - level) + 0.02
