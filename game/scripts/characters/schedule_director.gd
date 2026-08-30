class_name ScheduleDirector
extends Node
## The residents get a clock.
##
## Reads game/data/resident_schedules.json — the hand transcription of
## design/ORISON_ARCHETYPE_SCHEDULES.md — and, on the same real-local-time
## clock the sky already obeys (day_night_director.gd), tells
## ResidentRoutines where each of the eighteen should be: home, a room in
## the building, the bodega across the street, the Harukiya under it, or
## "out", which is an honest despawn through the lobby door.
##
## Selection contract (mirrors the JSON's meta.schema): for the current
## minute of the current day, the most specific covering block wins —
## special_days (day of year) > monthly+days > days > base. Blocks with a
## `chance` roll once per (resident, day), deterministically, so a 35%
## breaker-walk either happens tonight or it doesn't, rather than
## flickering per tick.
##
## Determinism: WalkTest runs under DAYNIGHT=0 and this director goes
## inert there — the canonical 03:00 building keeps its pre-schedule
## behaviour byte for byte. SCHEDULE=1 forces the director on (for
## schedule-specific tests), SCHEDULE=0 forces it off, SCHEDULE_DAY and
## SCHEDULE_DOY pin the calendar the way DAYNIGHT_FORCE pins the clock.

const SCHEDULE_PATH := "res://data/resident_schedules.json"
const DAY_NAMES := ["mon", "tue", "wed", "thu", "fri", "sat", "sun"]
const MONTH_DAYS := [31, 28, 31, 30, 31, 30, 31, 31, 30, 31, 30, 31]

## Blender-XY anchors for the shared destinations. Unit interiors and
## visit targets are derived from the layout instead. The two street
## venues are `exterior`: unreachable by the portal graph, so routines
## walk the resident to the lobby door and cross them over hidden — the
## same honest abstraction the lifts already use.
const ANCHORS := {
	"lobby": {"floor": "F01", "at": Vector2(0.0, -8.6)},
	"mail_bank": {"floor": "F01", "at": Vector2(4.55, -8.85)},
	"light_court": {"floor": "F01", "at": Vector2(-2.2, -1.2)},
	"laundry": {"floor": "B1", "at": Vector2(0.0, 5.0)},
	"roof": {"floor": "ROOF", "at": Vector2(-2.0, 6.0)},
	"bodega": {"floor": "F01", "at": Vector2(16.8, -8.6), "exterior": true},
	"harukiya_bar": {"floor": "B1", "at": Vector2(-1.75, -31.1),
			"exterior": true},
	# THE VANTRY ARCADE. Four of the eleven shops are somewhere a resident
	# has an actual reason to be. ResidentNav derives each point from the
	# installed Passage door; the clock carries no duplicate world literals.
	#
	# Only four. Every shop COULD take visitors and a building whose
	# residents visit all eleven equally is a building of errand-runners
	# rather than people; these are the four the layout already asserts
	# somebody uses (SHOPS in gen_layout says the luncheonette is where
	# residents sit between shifts and that Nadia is in the photo shop
	# more than she is upstairs).
	"luncheonette": {"passage": true, "exterior": true},
	"hand_laundry": {"passage": true, "exterior": true},
	"news_cigars": {"passage": true, "exterior": true},
	"photo_supplies": {"passage": true, "exterior": true},
}
## Corridor ring fallback for corridor / stairs / half_landing / doorway
## targets, resolved on the resident's own floor.
const RING_POINT := Vector2(4.38, 0.0)

var routines: ResidentRoutines
var data: Dictionary = {}
var enabled := true
var _layout: Dictionary = {}
var _levels: Dictionary = {}
var _accum := 9.0               # resolve on the first tick
var _dispatched: Dictionary = {}
var campaign_clock: CampaignClock


func setup(target: ResidentRoutines, layout: Dictionary) -> void:
	routines = target
	campaign_clock = CampaignClock.new()
	campaign_clock.bind_state()
	_layout = layout
	_levels = layout.get("meta", {}).get("levels", {})
	var file := FileAccess.open(SCHEDULE_PATH, FileAccess.READ)
	if file == null:
		push_warning("resident schedules missing: " + SCHEDULE_PATH)
		enabled = false
		return
	data = JSON.parse_string(file.get_as_text())
	if typeof(data) != TYPE_DICTIONARY or not data.has("residents"):
		push_error("resident schedules unparseable")
		data = {}
		enabled = false
		return
	match OS.get_environment("SCHEDULE"):
		"0":
			enabled = false
		"1":
			enabled = true
		_:
			# Tests pin DAYNIGHT=0 for the canonical 03:00 building; the
			# schedule stands down with the sky so they stay deterministic.
			enabled = OS.get_environment("DAYNIGHT") != "0"
	print("[SCHEDULE] director %s: %d residents on the clock" % [
			"live" if enabled else "inert",
			data.get("residents", {}).size()])


func _process(delta: float) -> void:
	if not enabled or routines == null or data.is_empty():
		return
	_accum += delta
	if _accum < 4.0:
		return
	_accum = 0.0
	var info := day_info()
	if not bool(info.get("valid", false)):
		return
	var minute := minute_now()
	for slug in data["residents"]:
		var block := resolve(str(slug), str(info.day), minute,
				int(info.doy), bool(info.first_sat))
		var directive := directive_for(str(slug), block)
		var fingerprint := "%s|%s|%s" % [directive.get("key", ""),
				directive.get("mode", ""), directive.get("activity", "")]
		if str(_dispatched.get(slug, "")) == fingerprint:
			continue
		_dispatched[slug] = fingerprint
		routines.set_schedule(str(slug), directive)


## ---- clock ----------------------------------------------------------

static func minute_now() -> float:
	# Same envs, same precedence as DayNightDirector._minute_now, so the
	# sky and the residents can never disagree about what time it is.
	var force := OS.get_environment("DAYNIGHT_FORCE")
	if force != "":
		if DayNightDirector.STATE_MINUTES.has(force):
			return float(DayNightDirector.STATE_MINUTES[force])
		var bits := force.split(":")
		if bits.size() == 2 and bits[0].is_valid_int():
			return float(int(bits[0]) * 60 + int(bits[1]))
	if OS.get_environment("DAYNIGHT") == "0":
		return 180.0
	var clock := CampaignClock.new()
	return clock.minute_of_day() if clock.bind_state() else 180.0


## Non-leap arithmetic on purpose: the design doc's date keys are ruled
## off against a 365-day year (its own verification note says so).
static func doy_of(month: int, day: int) -> int:
	var total := day
	for m in range(month - 1):
		total += MONTH_DAYS[m]
	return total


func day_info() -> Dictionary:
	var forced_day := OS.get_environment("SCHEDULE_DAY")
	var forced_doy := OS.get_environment("SCHEDULE_DOY")
	if forced_day in DAY_NAMES and forced_doy.is_valid_int():
		return {"valid": true, "day": forced_day, "doy": int(forced_doy),
				"first_sat": forced_day == "sat" and
				OS.get_environment("SCHEDULE_FIRST_SAT") == "1"}
	return campaign_clock.day_info() if campaign_clock else {
		"valid": false, "reason": "campaign calendar provider required"}


## ---- resolution ------------------------------------------------------

func resolve(slug: String, day: String, minute: float, doy: int,
		first_sat: bool) -> Dictionary:
	var spec: Dictionary = data.get("residents", {}).get(slug, {})
	if spec.is_empty():
		return {}
	var m := int(minute)
	for sd in spec.get("special_days", []):
		if int(sd.get("doy", -1)) != doy:
			continue
		for b in sd.get("blocks", []):
			if _covers(b, m):
				return b
	var best: Dictionary = {}
	var best_rank := -1.0
	for b in spec.get("blocks", []):
		if not _covers(b, m):
			continue
		# The pair alternates nightly; the single spawned actor follows
		# guest_b, the night-visible one (schema note in the JSON meta).
		if str(b.get("role", "")) == "guest_a":
			continue
		var days: Array = b.get("days", [])
		if not days.is_empty() and not days.has(day):
			continue
		if str(b.get("monthly", "")) == "first" and not first_sat:
			continue
		var rank := 0.0
		if b.has("monthly"):
			rank = 2.0
		elif not days.is_empty():
			rank = 1.0
		if b.has("chance"):
			if _daily_roll(slug, doy, int(b.start_min)) > float(b.chance):
				continue
			rank += 0.5     # a fired chance block overlays its base
		if rank > best_rank:
			best_rank = rank
			best = b
	return best


## Pure, geometry-free facts for a place between two elapsed campaign minutes.
## Shop simulation consumes this result instead of duplicating timetable
## selection or inferring demand from elapsed time. Each resolved visit is
## emitted once at the start of its authored block.
func place_activity_facts(place: String, from_elapsed_minute: float,
		to_elapsed_minute: float, clock: CampaignClock) -> Dictionary:
	if place.is_empty() or data.is_empty() or clock == null \
			or from_elapsed_minute < 0.0 \
			or to_elapsed_minute < from_elapsed_minute:
		return {}
	var epoch: Dictionary = clock.day_info_at(0.0)
	if not bool(epoch.get("valid", false)):
		return {}
	var epoch_minute := int(epoch.get("minute_of_day", -1))
	if epoch_minute < 0:
		return {}
	var first_day := int(floor((float(epoch_minute) \
			+ from_elapsed_minute) / 1440.0))
	var last_day := int(floor((float(epoch_minute) \
			+ to_elapsed_minute) / 1440.0))
	var visits: Array[Dictionary] = []
	for day_offset: int in range(first_day, last_day + 1):
		var day_start_elapsed := float(day_offset * 1440 - epoch_minute)
		for raw_slug: Variant in data.get("residents", {}):
			var slug := str(raw_slug)
			var spec: Dictionary = data.residents[raw_slug]
			var starts := {}
			for block: Variant in spec.get("blocks", []):
				if block is Dictionary:
					starts[int((block as Dictionary).get("start_min", -1))] = true
			for special: Variant in spec.get("special_days", []):
				if special is not Dictionary:
					continue
				for block: Variant in (special as Dictionary).get("blocks", []):
					if block is Dictionary:
						starts[int((block as Dictionary).get(
								"start_min", -1))] = true
			for raw_start: Variant in starts:
				var start_minute := int(raw_start)
				if start_minute < 0 or start_minute >= 1440:
					continue
				var at_elapsed := day_start_elapsed + float(start_minute)
				if at_elapsed <= from_elapsed_minute \
						or at_elapsed > to_elapsed_minute or at_elapsed < 0.0:
					continue
				var info := clock.day_info_at(at_elapsed)
				if not bool(info.get("valid", false)):
					continue
				var block := resolve(slug, str(info.get("day", "")),
						float(start_minute), int(info.get("doy", 0)),
						bool(info.get("first_sat", false)))
				if str(block.get("place", "")) != place \
						or int(block.get("start_min", -1)) != start_minute:
					continue
				visits.append({
					"resident_id": slug,
					"activity": str(block.get("activity", "visit")),
					"at_minute": at_elapsed,
					"minute_of_day": start_minute,
				})
	visits.sort_custom(func(a: Dictionary, b: Dictionary) -> bool:
		if not is_equal_approx(float(a.at_minute), float(b.at_minute)):
			return float(a.at_minute) < float(b.at_minute)
		return str(a.resident_id) < str(b.resident_id))
	return {
		"authority": "ScheduleDirector",
		"place": place,
		"from_minute": from_elapsed_minute,
		"to_minute": to_elapsed_minute,
		"visits": visits,
	}


func _covers(block: Dictionary, minute: int) -> bool:
	return int(block.get("start_min", 0)) <= minute \
			and minute < int(block.get("end_min", 0))


## One roll per (resident, day, block): tonight the breaker walk happens
## or it does not, and the answer holds until tomorrow.
func _daily_roll(slug: String, doy: int, start: int) -> float:
	return float(absi(hash("%s|%d|%d" % [slug, doy, start])) % 10000) \
			/ 10000.0


## ---- mapping ---------------------------------------------------------

func directive_for(slug: String, block: Dictionary) -> Dictionary:
	if block.is_empty():
		# Coverage gaps do not exist in the data; this is the guests'
		# role-filtered hour and the inert fallback.
		return {"mode": "home", "activity": "rest", "key": "unit"}
	var place := str(block.get("place", "unit"))
	var activity := str(block.get("activity", ""))
	if place == "out":
		return {"mode": "offsite", "activity": activity, "key": place}
	if place.begins_with("unit"):
		return {"mode": "home", "activity": activity, "key": place}
	if place.begins_with("visit:"):
		var point := _visit_point(place.substr(6))
		if not point.is_finite():
			return {"mode": "home", "activity": activity, "key": place}
		return {"mode": "place", "activity": activity, "key": place,
				"point": point}
	if ANCHORS.has(place):
		var anchor: Dictionary = ANCHORS[place]
		var point := _passage_point(place) if anchor.get("passage", false) \
				else _world_point(str(anchor.floor), anchor.at)
		return {"mode": "exterior" if anchor.get("exterior", false)
				else "place",
				"activity": activity, "key": place,
				"point": point}
	if place in ["corridor", "stairs", "half_landing"]:
		return {"mode": "place", "activity": activity, "key": place,
				"point": _world_point(_home_floor(slug), RING_POINT)}
	push_warning("schedule place unmapped: " + place)
	return {"mode": "home", "activity": activity, "key": place}


func _world_point(floor_id: String, at: Vector2) -> Vector3:
	var z := float(_levels.get(floor_id, 0.0))
	return GameBoot.b2g([at.x, at.y, z + 0.03])


func _passage_point(place: String) -> Vector3:
	var marker_id := str(ResidentNav.PASSAGE_PLACES.get(place, ""))
	for fl in _layout.get("floors", []):
		if str(fl.get("id", "")) != "F01":
			continue
		for marker in fl.get("markers", []):
			if str(marker.get("id", "")) == marker_id:
				return ResidentNav.passage_spots(marker).venue
	return Vector3.INF


func _home_floor(slug: String) -> String:
	var unit := str(data.get("residents", {}).get(slug, {}).get("unit", ""))
	if unit.length() < 2:
		return "F01"
	return "F0" + unit.left(1)


func _visit_point(target: String) -> Vector3:
	var unit := target.replace("_doorway", "")
	var floor_id := "F0" + unit.left(1)
	if target.ends_with("_doorway"):
		return _world_point(floor_id, RING_POINT)
	for fl in _layout.get("floors", []):
		if str(fl.get("id", "")) != floor_id:
			continue
		for room in fl.get("rooms", []):
			if str(room.get("unit", "")) != unit:
				continue
			if str(room.get("kind", "")) == "living" \
					or str(room.get("id", "")).ends_with("_MAIN"):
				var rect: Array = room.rect
				return _world_point(floor_id, Vector2(
						(float(rect[0]) + float(rect[2])) * 0.5,
						(float(rect[1]) + float(rect[3])) * 0.5))
	return Vector3.INF


## ---- self test (tests/ScheduleTest.tscn) -----------------------------

## Coverage and mapping proven without a building: every resident, every
## day shape, every ten minutes resolves to a directive whose mode is
## legal and whose point (when it has one) is finite. Returns failures.
func self_test() -> int:
	var fails := 0
	var day_shapes := [["mon", false], ["tue", false], ["wed", false],
			["thu", false], ["fri", false], ["sat", false], ["sat", true],
			["sun", false]]
	for slug in data.get("residents", {}):
		for shape in day_shapes:
			for m in range(0, 1440, 10):
				var block := resolve(str(slug), str(shape[0]), float(m),
						0, bool(shape[1]))
				var directive := directive_for(str(slug), block)
				if str(directive.get("mode", "")) not in [
						"home", "place", "exterior", "offsite"]:
					print("  [FAIL] %s %s %d: mode %s" % [slug, shape[0],
							m, directive.get("mode", "?")])
					fails += 1
				elif directive.has("point") \
						and not (directive.point as Vector3).is_finite():
					print("  [FAIL] %s %s %d: non-finite point for %s"
							% [slug, shape[0], m, directive.get("key", "?")])
					fails += 1
	var expectations := [
		["iris_bell", "fri", 1320, 0, false, "harukiya_bar", "exterior"],
		["mina_vale", "wed", 190, 0, false, "mail_bank", "place"],
		["teresa_vale", "mon", 300, 0, false, "out", "offsite"],
		["teresa_vale", "sat", 200, 0, false, "laundry", "place"],
		["omar_bell", "tue", 1290, 0, false, "visit:5B", "place"],
		["nadia_quell", "thu", 1000, 0, false, "visit:6C", "place"],
		["jonah_price", "sun", 720, 0, false, "visit:4C_doorway", "place"],
		["evelyn_marsh", "sat", 630, 0, true, "lobby", "place"],
		["evelyn_marsh", "sat", 630, 0, false, "corridor", "place"],
		["cam_ortiz", "wed", 215, 0, false, "bodega", "exterior"],
		["malcolm_reed", "wed", 1050, 0, false, "roof", "place"],
		["omar_bell", "wed", 1320, 194, false, "unit", "home"],
		["lena_ortiz", "wed", 700, 84, false, "corridor", "place"],
	]
	for e in expectations:
		var block := resolve(str(e[0]), str(e[1]), float(e[2]), int(e[3]),
				bool(e[4]))
		var directive := directive_for(str(e[0]), block)
		var key := str(directive.get("key", ""))
		var mode := str(directive.get("mode", ""))
		var want_key := str(e[5])
		var want_mode := str(e[6])
		if (key != want_key and not key.begins_with(want_key)) \
				or mode != want_mode:
			print("  [FAIL] %s %s %d doy%d: got %s/%s want %s/%s" % [
					e[0], e[1], e[2], e[3], key, mode, want_key,
					want_mode])
			fails += 1
	return fails
