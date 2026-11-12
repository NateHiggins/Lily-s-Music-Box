extends Node
## The temporal investigation loop. A lead is an anchor: a place, a date, a
## start, a length and a question. The player pays a fare from banked funds to
## be put down at an anchor. There they work the room, a step at a time,
## until it gives up one piece of evidence. They take it, go home, pin it to
## the case wall in 4B, and the wall decides which leads are open next.
##
## Three clocks: the historical one (the civil calendar, moved by
## CampaignClock.rebase_calendar), the loop one (minutes since this run of the
## anchor began) and the player's own (elapsed minutes, which never go back, so
## rent and deliveries stay honest through every visit).
##
## Evidence is what each trip is for, and it is kept: the items taken (held in
## this ledger and filed in the valise) and what was heard. Also kept: the
## bank, its transactions, the wall, deductions. What a visit or a rerun puts
## back: the room's steps, and the REWOUND domains, which are pocket cash,
## tools and stores, keys, shop stock and standing with the residents.
## Money can therefore reach the bank only by a deposit made at home, and a
## deposit is one committed transaction.
##
## The companion has its own initiative (Bible, ruling of 2026-11-10): it
## draws the allowance, advises at home, hints and warns during a visit, and
## brings the player home when the hours end with the evidence in hand.
## Everything it says is authored here or in the anchors table (RUL-015).
##
## Time does not make the player wait (Lily, 2026-11-11). When a room can only
## be waited on, when the evidence is taken and the hours are running out, or
## when the player sits idle at home, the loop asks the campaign pace to run
## the clock to the next thing worth doing. Any step the player can act on,
## and any input at home, puts time back to its ordinary rate. WAIT asks for
## it, STEADY turns it off, PACE turns it back on.
##
## Every entry to the past goes through `jump`, `reset_loop` or `go_home`, and
## each of those goes through the clock's rebase, which refuses the murder
## hours. An anchor may not start or end inside them either.

signal changed
signal slip(title: String, body: String)
## The room's steps were put back: a rerun, an order fault, or leaving.
signal stage_reset

const KEY := "temporal"
const DATA_PATH := "res://data/temporal/anchors.json"
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const PaperPocket := preload("res://scripts/game/paper_pocket.gd")
## Campaign domains a visit borrows and gives back. Knowledge and the valise
## (PaperPocket.KEY) must never be among them: evidence is kept.
const REWOUND: Array[String] = ["caretaker_economy", "inventories", "door_keys",
		"shop_stock", "conversation_visits", "resident_trust"]
const STATES: Array[String] = ["CHOOSE_NEXT_ACTION", "SELECT_ANCHOR", "FUND_JUMP",
		"EXECUTE_JUMP", "RUN_LOOP", "INVESTIGATE", "RESET_LOOP", "RESOLVE_ANCHOR"]
const STEP_KINDS: Array[String] = ["at", "after", "shift", "flag"]
## The companion's pacing, in minutes of the loop clock.
const HINT_FIRST_MINUTES := 4.0
const HINT_EVERY_MINUTES := 12.0
const WARN_MINUTES := 10.0

var clock: CampaignClock
var economy: Node
var table: Dictionary = {}
var _poll := 0.0
## The campaign's pace, found on the clock driver; a test may hand one in.
var pace: CampaignPace
## Real seconds since the player last did anything.
var _idle := 0.0
## The elapsed minute a typed WAIT runs to, or -1.
var _wait_until := -1.0
## The run the companion has already announced.
var _pace_said := ""


func setup(campaign_clock: CampaignClock, caretaker_economy: Node) -> bool:
	clock = campaign_clock
	economy = caretaker_economy
	table = _load_table()
	if table.is_empty() or clock == null or PaperPocket.KEY in REWOUND or "knowledge_flags" in REWOUND:
		return false
	add_to_group("temporal_loop")
	if economy != null:
		economy.tip_percent = tip_percent_now
	mend()
	return true


## Put a ledger that does not agree with itself back in order: a visit to a
## lead that no longer exists, a state that says away with no visit, or home
## with one. Returns what was mended, for the log. Evidence is never touched.
func mend() -> Array[String]:
	var mended: Array[String] = []
	var value: Variant = RealityState.data.get(KEY)
	if value is not Dictionary or int(value.get("version", 0)) != 2 or table.is_empty():
		return mended
	var book := ledger()
	if book.get("visit") is not Dictionary:
		book["visit"] = {}
		mended.append("visit")
	var visit: Dictionary = book.visit
	if not visit.is_empty() and (not table.anchors.has(str(visit.get("anchor", ""))) or not visit.has("loop_started")):
		_give_back(RealityState.data, visit.get("world", {}) if visit.get("world") is Dictionary else {})
		book.visit = {}
		mended.append("lost_lead")
	if str(book.get("state", "")) not in STATES:
		book["state"] = "CHOOSE_NEXT_ACTION"
		mended.append("state")
	var away := not (book.visit as Dictionary).is_empty()
	var away_state := str(book.state) in ["RUN_LOOP", "INVESTIGATE", "RESOLVE_ANCHOR", "RESET_LOOP", "EXECUTE_JUMP"]
	if away and not away_state:
		book.state = "INVESTIGATE"
		mended.append("state_away")
	elif away and str(book.state) in ["RESET_LOOP", "EXECUTE_JUMP"]:
		book.state = "RUN_LOOP"
		mended.append("state_between")
	elif not away and away_state:
		book.state = "CHOOSE_NEXT_ACTION"
		mended.append("state_home")
	if away:
		if (book.visit as Dictionary).get("stage") is not Dictionary or ((book.visit as Dictionary).stage as Dictionary).get("done") is not Array:
			book.visit["stage"] = {"done": []}
			mended.append("stage")
		var known: Array = []
		for step: Dictionary in table.anchors[visit_anchor()].steps:
			known.append(str(step.id))
		var done: Array = book.visit.stage.done
		if done != known.slice(0, done.size()):
			book.visit.stage.done = []
			mended.append("steps")
	if not mended.is_empty():
		push_warning("temporal loop: mended %s" % [mended])
	return mended


static func _load_table() -> Dictionary:
	var file := FileAccess.open(DATA_PATH, FileAccess.READ)
	if file == null:
		return {}
	var parsed: Variant = JSON.parse_string(file.get_as_text())
	if parsed is not Dictionary or int(parsed.get("version", 0)) != 2 or parsed.get("anchors") is not Dictionary:
		return {}
	var fare: Dictionary = parsed.get("fare", {})
	for field: String in ["base_cents", "days_per_cent", "cap_cents", "worn_groove_divisor"]:
		if not fare.has(field):
			return {}
	# How time runs when there is nothing to do: rates are campaign seconds a second.
	var pace_rules: Variant = parsed.get("pace")
	if pace_rules is not Dictionary:
		return {}
	for field: String in ["wait_rate", "done_rate", "idle_rate"]:
		if float(pace_rules.get(field, 0.0)) < 1.0 or float(pace_rules[field]) > CampaignPace.MAX_RATE:
			return {}
	for field: String in ["idle_seconds", "landing_seconds", "ramp_seconds"]:
		if float(pace_rules.get(field, 0.0)) <= 0.0:
			return {}
	if not (parsed.get("stipend", {}) as Dictionary).has("cents") or str(parsed.get("bank_name", "")).is_empty() \
			or str(parsed.get("wall", "")).is_empty():
		return {}
	var clues := {}
	for anchor_id: String in parsed.anchors:
		var anchor: Dictionary = parsed.anchors[anchor_id]
		for field: String in ["title", "place", "where", "date", "start", "minutes", "question", "tier", "needs", "steps", "clue"]:
			if not anchor.has(field):
				return {}
		anchor["strict"] = bool(anchor.get("strict", false))
		# How the day is dressed: its season, what it falls beside, and what
		# the rooms show of it. The set dressers and the wall both read this.
		if str(anchor.get("season", "")).is_empty() or str(anchor.get("occasion", "")).is_empty() \
				or anchor.get("dressing") is not Array or (anchor.dressing as Array).is_empty():
			return {}
		# How the house's blinds and curtains stand on that day.
		var windows: Variant = anchor.get("windows")
		if windows is not Dictionary or float(windows.get("raise", -1.0)) < 0.0 or float(windows.raise) > 1.0 \
				or absf(float(windows.get("tilt_degrees", 999.0))) > 75.0 \
				or float(windows.get("curtain_open", -1.0)) < 0.0 or float(windows.curtain_open) > 1.0:
			return {}
		anchor["first_call_free"] = bool(anchor.get("first_call_free", false))
		var span := _anchor_span(anchor)
		# No anchor may touch the murder hours, by its own data.
		if span.is_empty() or CampaignClock.in_blackout(span.start) \
				or (span.start < CampaignClock.blackout_end_minute() and span.end > CampaignClock.blackout_start_minute()):
			return {}
		var clue: Dictionary = anchor.clue
		for field: String in ["id", "title", "body", "rest"]:
			if str(clue.get(field, "")).is_empty():
				return {}
		if clues.has(str(clue.id)) or (anchor.steps as Array).is_empty() \
				or (clue.has("rest_offset") and (clue.rest_offset as Array).size() != 3):
			return {}
		clues[str(clue.id)] = anchor_id
		var seen := {}
		for step: Dictionary in anchor.steps:
			if str(step.get("kind", "")) not in STEP_KINDS or str(step.get("id", "")).is_empty() \
					or seen.has(str(step.id)) or str(step.get("hint", "")).is_empty():
				return {}
			seen[str(step.id)] = true
			match str(step.kind):
				"at":
					if str(step.get("unit", "")).is_empty(): return {}
				"after":
					if _minute_of(str(step.get("time", ""))) < 0: return {}
				"shift":
					if str(step.get("object", "")).is_empty() or (step.get("axis", []) as Array).size() != 3 \
							or float(step.get("reach", 0.0)) <= 0.0: return {}
				"flag":
					if str(step.get("flag", "")).is_empty(): return {}
	if parsed.get("deductions") is not Dictionary or parsed.get("scrawls") is not Array or parsed.get("calendar") is not Array:
		return {}
	if parsed.get("events") is not Array:
		return {}
	for event: Variant in parsed.events:
		if event is not Dictionary:
			return {}
		for field: String in ["id", "mark", "from", "breaks", "until", "slip", "before"]:
			if str(event.get(field, "")).is_empty():
				return {}
		if int(event.get("tip_percent", 0)) < 1 or int(event.tip_percent) > 100 or int(event.get("allowance_cents", -1)) < 0 \
				or not (str(event.from) <= str(event.breaks) and str(event.breaks) <= str(event.until)):
			return {}
	var filing: Variant = parsed.get("filing")
	if filing is not Dictionary or int(filing.get("tolerance_days", 0)) <= 0 or filing.get("places") is not Array \
			or filing.get("columns") is not Array or parsed.get("neighbourhood") is not Array:
		return {}
	for anchor_id: String in parsed.anchors:
		if _map_cell(parsed, str(parsed.anchors[anchor_id].where)).x < 0:
			return {}
	for day: Variant in parsed.calendar:
		if day is not Dictionary or str(day.get("date", "")).split("-").size() != 3 \
				or str(day.get("name", "")).is_empty() or str(day.get("season", "")).is_empty():
			return {}
	for deduction_id: String in parsed.deductions:
		var deduction: Dictionary = parsed.deductions[deduction_id]
		if deduction.get("needs") is not Array or (deduction.needs as Array).size() < 2 \
				or str(deduction.get("line", "")).is_empty() or clues.has(deduction_id):
			return {}
		for need: Variant in deduction.needs:
			if not clues.has(str(need)):
				return {}
	# The tree: a lead needs evidence pinned or a deduction drawn, always from
	# rooms of a lower tier, so the tiers only climb.
	for anchor_id: String in parsed.anchors:
		for need: Variant in parsed.anchors[anchor_id].needs:
			var pieces: Array = [need]
			if parsed.deductions.has(str(need)):
				pieces = parsed.deductions[str(need)].needs
			for piece: Variant in pieces:
				if not clues.has(str(piece)) or str(clues[str(piece)]) == anchor_id \
						or int(parsed.anchors[str(clues[str(piece)])].tier) >= int(parsed.anchors[anchor_id].tier):
					return {}
	parsed["clue_anchor"] = clues
	return parsed


## Where a place code sits on the building map: x is the column (0 for a whole
## floor), y the row from the top. (-1, -1) when the code is not on the map.
static func _map_cell(source: Dictionary, where: String) -> Vector2i:
	var rows: Array = source.filing.places
	var columns: Array = source.filing.columns
	if where in rows:
		return Vector2i(0, rows.find(where))
	if where.length() == 2 and where.left(1) in rows and where.right(1) in columns:
		return Vector2i(columns.find(where.right(1)), rows.find(where.left(1)))
	return Vector2i(-1, -1)


static func _minute_of(text: String) -> int:
	var parts := text.split(":")
	if parts.size() != 2 or not parts[0].is_valid_int() or not parts[1].is_valid_int():
		return -1
	return int(parts[0]) * 60 + int(parts[1])


static func _anchor_span(anchor: Dictionary) -> Dictionary:
	var date := str(anchor.date).split("-")
	var minute := _minute_of(str(anchor.start))
	if date.size() != 3 or minute < 0 or int(anchor.minutes) <= 0:
		return {}
	var start := CampaignClock.calendar_minute_of(int(date[0]), int(date[1]), int(date[2]), float(minute))
	return {"start": start, "end": start + float(int(anchor.minutes))}


## The persistent ledger.
func ledger() -> Dictionary:
	var value: Variant = RealityState.data.get(KEY)
	if value is not Dictionary or int(value.get("version", 0)) != 2:
		value = {"version": 2, "state": "CHOOSE_NEXT_ACTION", "bank_cents": 0,
				"transactions": {}, "anchors": {}, "items": {}, "deductions": [], "strings": [],
				"visit": {}, "selected": ""}
		RealityState.data[KEY] = value
	return value


static func valid(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	for field: String in ["transactions", "anchors", "visit", "items"]:
		if value.get(field) is not Dictionary:
			return false
	if value.get("deductions") is not Array or value.get("strings") is not Array:
		return false
	for string: Variant in value.strings:
		if string is not Array or (string as Array).size() != 2:
			return false
	for item: Variant in (value.items as Dictionary).values():
		if item is not Dictionary or item.get("pinned") is not bool:
			return false
	var bank: Variant = value.get("bank_cents")
	if (bank is not int and bank is not float) or float(bank) < 0.0 or float(bank) != floorf(float(bank)):
		return false
	return str(value.get("state", "")) in STATES


func state() -> String:
	return str(ledger().state)


func bank_cents() -> int:
	return int(ledger().bank_cents)


func in_visit() -> bool:
	return not (ledger().visit as Dictionary).is_empty()


func visit_anchor() -> String:
	return str((ledger().visit as Dictionary).get("anchor", ""))


func _record(anchor_id: String) -> Dictionary:
	var anchors: Dictionary = ledger().anchors
	if not anchors.has(anchor_id):
		anchors[anchor_id] = {"paid": 0, "loops": 0}
	return anchors[anchor_id]


## Minutes since this run of the anchor began: the loop clock.
func loop_minutes() -> float:
	var visit: Dictionary = ledger().visit
	return 0.0 if visit.is_empty() else clock.elapsed_minutes() - float(visit.loop_started)


func loop_minutes_left() -> float:
	if not in_visit():
		return 0.0
	return float(int(table.anchors[visit_anchor()].minutes)) - loop_minutes()


# --- Evidence and the wall ---------------------------------------------------

## The evidence item an anchor gives up.
func clue_of(anchor_id: String) -> Dictionary:
	return table.anchors[anchor_id].clue


func holds(item_id: String) -> bool:
	return (ledger().items as Dictionary).has(item_id)


func pinned(item_id: String) -> bool:
	return holds(item_id) and bool(ledger().items[item_id].pinned)


## Held but not yet on the wall, in the order taken.
func carried() -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in ledger().items:
		if not bool(ledger().items[item_id].pinned):
			ids.append(item_id)
	return ids


func on_wall() -> Array[String]:
	var ids: Array[String] = []
	for item_id: String in ledger().items:
		if bool(ledger().items[item_id].pinned):
			ids.append(item_id)
	return ids


func item_text(item_id: String) -> Dictionary:
	return clue_of(str(table.clue_anchor[item_id]))


## A lead is open when everything it needs is on the wall: a piece of
## evidence pinned, or a deduction drawn by joining pieces with string.
func unlocked() -> Array[String]:
	var ids: Array[String] = []
	for anchor_id: String in table.anchors:
		var open := true
		for need: Variant in table.anchors[anchor_id].needs:
			open = open and (pinned(str(need)) or str(need) in ledger().deductions)
		if open:
			ids.append(anchor_id)
	return ids


# --- Filing: every piece has a day and a place --------------------------------------

## Days from the start of the historical year to a date ("1929-07-19").
static func day_of_year(date: String) -> int:
	var parts := date.split("-")
	if parts.size() != 3:
		return -1
	return int(round((CampaignClock.calendar_minute_of(int(parts[0]), int(parts[1]), int(parts[2]), 0.0)
			- CampaignClock.loop_beginning_minute()) / CampaignClock.MINUTES_PER_DAY))


func days_in_year() -> int:
	return int(round(CampaignClock.loop_length_minutes() / CampaignClock.MINUTES_PER_DAY))


func item_day(item_id: String) -> int:
	return day_of_year(str(table.anchors[str(table.clue_anchor[item_id])].date))


func item_where(item_id: String) -> String:
	return str(table.anchors[str(table.clue_anchor[item_id])].where)


func dated(item_id: String) -> bool:
	return pinned(item_id) and bool(ledger().items[item_id].get("dated", false))


func placed(item_id: String) -> bool:
	return pinned(item_id) and bool(ledger().items[item_id].get("placed", false))


func filed(item_id: String) -> bool:
	return dated(item_id) and placed(item_id)


## The pinned piece waiting for its day, or "" when every pinned piece has one.
func undated() -> String:
	for item_id: String in on_wall():
		if not dated(item_id):
			return item_id
	return ""


## Set a pinned piece against a day of the year on the timeline. It holds
## only within a few days of the day it comes from.
func file_date(item_id: String, day: int) -> Dictionary:
	if in_visit() or not pinned(item_id) or dated(item_id):
		return {"ok": false}
	if absi(day - item_day(item_id)) > int(table.filing.tolerance_days):
		return {"ok": true, "held": false}
	ledger().items[item_id]["dated"] = true
	RealityState.commit()
	changed.emit()
	return {"ok": true, "held": true, "day": item_day(item_id)}


## Run a string from a pinned piece to a place on the building map. It holds
## only at the place the piece was found.
func file_place(item_id: String, where: String) -> Dictionary:
	if in_visit() or not pinned(item_id) or placed(item_id) or _map_cell(table, where).x < 0:
		return {"ok": false}
	if where != item_where(item_id):
		return {"ok": true, "held": false}
	ledger().items[item_id]["placed"] = true
	RealityState.commit()
	changed.emit()
	return {"ok": true, "held": true}


# --- Making sense of it: string between the pieces ------------------------------

func strings() -> Array:
	return ledger().strings


func joined(a: String, b: String) -> bool:
	for string: Array in strings():
		if (str(string[0]) == a and str(string[1]) == b) or (str(string[0]) == b and str(string[1]) == a):
			return true
	return false


## True when two pieces belong to one deduction: a string between them holds.
func belong(a: String, b: String) -> bool:
	for deduction_id: String in table.deductions:
		var needs: Array = table.deductions[deduction_id].needs
		if a in needs and b in needs:
			return true
	return false


func _strung_together(pieces: Array) -> bool:
	var reached: Array[String] = [str(pieces[0])]
	var grew := true
	while grew:
		grew = false
		for string: Array in strings():
			for way in 2:
				var near := str(string[way])
				var far := str(string[1 - way])
				if near in reached and far not in reached and far in pieces:
					reached.append(far)
					grew = true
	return reached.size() == pieces.size()


## A deduction the wall could draw now: its pieces are all pinned but not yet
## all joined. {} when there is none.
func open_deduction() -> Dictionary:
	for deduction_id: String in table.deductions:
		if deduction_id in ledger().deductions:
			continue
		var ready := true
		for need: Variant in table.deductions[deduction_id].needs:
			ready = ready and filed(str(need))
		if ready:
			return {"id": deduction_id, "needs": table.deductions[deduction_id].needs}
	return {}


## Run a string from one pinned piece to another. Home only. A string between
## two pieces that belong together holds; any other falls away. When every
## piece of a deduction is strung together, the deduction is drawn and may
## open leads.
func link(a: String, b: String) -> Dictionary:
	if in_visit():
		return {"ok": false, "code": "away"}
	if a == b or not pinned(a) or not pinned(b):
		return {"ok": false, "code": "not_pinned"}
	if joined(a, b):
		return {"ok": false, "code": "joined"}
	if not filed(a) or not filed(b):
		return {"ok": false, "code": "unfiled"}
	var book := ledger()
	book["tries"] = int(book.get("tries", 0)) + 1
	if not belong(a, b):
		RealityState.commit_background()
		return {"ok": true, "held": false, "deductions": [], "opened": []}
	var before := unlocked()
	(book.strings as Array).append([a, b])
	var drawn: Array[String] = []
	for deduction_id: String in table.deductions:
		if deduction_id in book.deductions:
			continue
		var needs: Array = table.deductions[deduction_id].needs
		var ready := true
		for need: Variant in needs:
			ready = ready and pinned(str(need))
		if ready and _strung_together(needs):
			book.deductions.append(deduction_id)
			drawn.append(deduction_id)
	var opened: Array[String] = []
	for anchor_id: String in unlocked():
		if anchor_id not in before:
			opened.append(anchor_id)
	RealityState.commit()
	changed.emit()
	return {"ok": true, "held": true, "deductions": drawn, "opened": opened}


## How far the case has grown over the flat: the wall spreads with it.
func spread() -> int:
	var filings := 0
	for item_id: String in on_wall():
		filings += (1 if dated(item_id) else 0) + (1 if placed(item_id) else 0)
	return on_wall().size() * 3 + filings + strings().size() * 6 + (ledger().deductions as Array).size() * 12


## The same as a share of the finished case, 0 to 1. At 1 the flat is consumed.
func spread_fraction() -> float:
	var whole := (table.anchors as Dictionary).size() * 5 + (table.deductions as Dictionary).size() * 12
	for deduction_id: String in table.deductions:
		whole += ((table.deductions[deduction_id].needs as Array).size() - 1) * 6
	return clampf(float(spread()) / float(maxi(1, whole)), 0.0, 1.0)


func answered(anchor_id: String) -> bool:
	return holds(str(clue_of(anchor_id).id))


## Pin the next carried item to the wall. Home only: the wall is in 4B, in the
## present. Returns the item, the leads it opened and any deduction drawn.
func pin_next() -> Dictionary:
	if in_visit():
		return {"ok": false, "code": "away"}
	var waiting := carried()
	if waiting.is_empty():
		return {"ok": false, "code": "nothing"}
	var before := unlocked()
	var item_id := waiting[0]
	var book := ledger()
	book.items[item_id]["slot"] = on_wall().size()
	book.items[item_id].pinned = true
	var opened: Array[String] = []
	for anchor_id: String in unlocked():
		if anchor_id not in before:
			opened.append(anchor_id)
	RealityState.commit()
	changed.emit()
	return {"ok": true, "item": item_id, "opened": opened}


# --- The room's steps ----------------------------------------------------------

func stage() -> Dictionary:
	var visit: Dictionary = ledger().visit
	if visit.is_empty():
		return {}
	if visit.get("stage") is not Dictionary:
		visit["stage"] = {"done": []}
	return visit.stage


func steps_done() -> int:
	return (stage().get("done", []) as Array).size()


## The step the room is waiting on, or {} when the evidence is out.
func current_step() -> Dictionary:
	if not in_visit():
		return {}
	var steps: Array = table.anchors[visit_anchor()].steps
	return steps[steps_done()] if steps_done() < steps.size() else {}


## True when every step is done and the evidence lies there to be taken.
func clue_ready() -> bool:
	return in_visit() and current_step().is_empty() and not answered(visit_anchor())


func _advance(step: Dictionary) -> void:
	(stage().done as Array).append(str(step.id))
	ledger().state = "RESOLVE_ANCHOR" if current_step().is_empty() else "INVESTIGATE"
	RealityState.commit_background()
	changed.emit()
	if current_step().is_empty() and not answered(visit_anchor()):
		slip.emit("THERE", "%s. Take it." % str(clue_of(visit_anchor()).title))


## What the world layer saw: where the player stands. Steps that only wait on
## a place, an hour or a thing known pass here.
func observe(unit: String) -> void:
	for guard in 8:
		var step := current_step()
		if step.is_empty():
			return
		var passed := false
		match str(step.kind):
			"at": passed = unit == str(step.unit)
			"after": passed = _hour_reached(str(step.time))
			"flag": passed = RealityState.has_knowledge(str(step.flag))
		if not passed:
			return
		_advance(step)


## Whether this run of the anchor has reached a time of day. Counted from the
## anchor's own start, so a room that begins before midnight and waits on an
## hour after it is not passed at once, or never.
func _hour_reached(time: String) -> bool:
	if not in_visit():
		return false
	var began := float(_minute_of(str(table.anchors[visit_anchor()].start)))
	return loop_minutes() >= fposmod(float(_minute_of(time)) - began, float(CampaignClock.MINUTES_PER_DAY))


## The player moved a thing in the room by hand, all the way.
## Returns "step" when it was the thing the room was waiting on, "fault" when
## a strict room was worked out of order and has put itself back, else "".
func report_shift(object_id: String) -> String:
	var step := current_step()
	if step.is_empty():
		return ""
	if str(step.kind) == "shift" and str(step.object) == object_id:
		_advance(step)
		return "step"
	var anchor: Dictionary = table.anchors[visit_anchor()]
	if not bool(anchor.strict):
		return ""
	for later: Dictionary in anchor.steps:
		if str(later.kind) == "shift" and str(later.object) == object_id and str(later.id) not in stage().done:
			stage().done = []
			ledger().state = "RUN_LOOP"
			RealityState.commit_background()
			stage_reset.emit()
			changed.emit()
			slip.emit("OUT OF ORDER", "It is all as it was. Begin again, and mind the order.")
			return "fault"
	return ""


## The player took the evidence the room gave up. It is kept from here on.
func take_clue() -> Dictionary:
	if not clue_ready():
		return {"ok": false}
	var clue := clue_of(visit_anchor())
	ledger().items[str(clue.id)] = {"pinned": false, "anchor": visit_anchor(), "run": int(_record(visit_anchor()).loops) + 1}
	PaperPocket.file_evidence("loop:" + str(clue.id), str(clue.title), str(clue.body))
	RealityState.commit()
	changed.emit()
	return {"ok": true, "item": str(clue.id), "title": str(clue.title), "body": str(clue.body)}


# --- Fares and the bank -----------------------------------------------------------

## The fare is fixed by the anchor and by how far the present is from it in
## the year: the same question from the same day always costs the same. The
## first call to the opening lead is on the house, and an answered anchor is a
## worn groove at a fraction of the fare.
func fare_cents(anchor_id: String) -> int:
	if not table.anchors.has(anchor_id):
		return -1
	var anchor: Dictionary = table.anchors[anchor_id]
	if bool(anchor.first_call_free) and int(_record(anchor_id).paid) == 0:
		return 0
	var fare: Dictionary = table.fare
	var year := CampaignClock.loop_length_minutes()
	var apart := fposmod(_anchor_span(anchor).start - _home_calendar(), year)
	var days := int(minf(apart, year - apart) / CampaignClock.MINUTES_PER_DAY)
	var cents := mini(int(fare.cap_cents), int(fare.base_cents) + int(ceil(float(days) / float(int(fare.days_per_cent)))))
	return cents / int(fare.worn_groove_divisor) if answered(anchor_id) else cents


func _home_calendar() -> float:
	var visit: Dictionary = ledger().visit
	if visit.is_empty():
		return clock.calendar_minutes()
	return float(visit.home_calendar) + clock.elapsed_minutes() - float(visit.left_at)


func _transact(identity: String, cents: int) -> bool:
	var book := ledger()
	if (book.transactions as Dictionary).has(identity) or int(book.bank_cents) + cents < 0:
		return false
	book.transactions[identity] = cents
	book.bank_cents = int(book.bank_cents) + cents
	return true


# --- The year's events ---------------------------------------------------------------

func today() -> String:
	var now := clock.local_datetime()
	return "" if now.is_empty() else "%04d-%02d-%02d" % [int(now.year), int(now.month), int(now.day)]


## The event the date falls in, with "broken" true from the day it breaks:
## the market's crash of October 1929 is the one the year has. {} otherwise.
func event_on(date: String) -> Dictionary:
	for event: Dictionary in table.events:
		if date >= str(event.from) and date <= str(event.until):
			var found := event.duplicate()
			found["broken"] = date >= str(event.breaks)
			return found
	return {}


## The share of a usual tip the tenants can spare today.
func tip_percent_now() -> int:
	var event := event_on(today())
	return int(event.tip_percent) if not event.is_empty() and bool(event.broken) else 100


func allowance_cents() -> int:
	var event := event_on(today())
	return int(event.allowance_cents) if not event.is_empty() and bool(event.broken) else int(table.stipend.cents)


## The house's daily allowance, once per day of the player's own time and only
## at home. It is the floor under the economy: a player with nothing can
## always afford the next lead in a few days.
func claim_stipend() -> Dictionary:
	if in_visit():
		return {"ok": false, "code": "away"}
	var day := int(clock.elapsed_minutes() / CampaignClock.MINUTES_PER_DAY)
	var cents := allowance_cents()
	if not _transact("stipend:%d" % day, cents):
		return {"ok": false, "code": "already_drawn"}
	RealityState.commit()
	changed.emit()
	return {"ok": true, "cents": cents}


## Pocket cash into the bank: one committed transaction, at home only. A
## visit's earnings are rewound with the visit, so they can never be banked.
func deposit(cents: int) -> Dictionary:
	if in_visit():
		return {"ok": false, "code": "away"}
	if cents <= 0 or economy == null or int(economy.book().cash) < cents:
		return {"ok": false, "code": "short"}
	var book := ledger()
	var serial := int(book.get("deposits", 0)) + 1
	var banked: bool = economy.purchase_repeat(str(table.bank_name), "deposit", cents, func() -> bool:
		if not _transact("deposit:%d" % serial, cents):
			return false
		book["deposits"] = serial
		return true)
	if banked:
		changed.emit()
	return {"ok": banked, "code": "" if banked else "refused", "cents": cents}


# --- Going and coming back ---------------------------------------------------------

func select(anchor_id: String) -> Dictionary:
	if in_visit():
		return {"ok": false, "code": "away"}
	if not table.anchors.has(anchor_id) or anchor_id not in unlocked():
		return {"ok": false, "code": "no_such_lead"}
	var book := ledger()
	book.selected = anchor_id
	book.state = "FUND_JUMP"
	return {"ok": true, "fare": fare_cents(anchor_id)}


## Select, fund and execute as one committed move: the fare leaves the bank
## and the calendar moves in the same save, or neither does.
func jump(anchor_id: String) -> Dictionary:
	var chosen := select(anchor_id)
	if not chosen.ok:
		return chosen
	var book := ledger()
	var record := _record(anchor_id)
	var fare := int(chosen.fare)
	if fare > int(book.bank_cents):
		book.state = "CHOOSE_NEXT_ACTION"
		return {"ok": false, "code": "fare", "fare": fare, "bank": int(book.bank_cents)}
	var span := _anchor_span(table.anchors[anchor_id])
	var home := clock.calendar_minutes()
	# Everything that can refuse is settled before the calendar moves.
	var receipt := "fare:%s:%d" % [anchor_id, int(record.paid) + 1]
	if (book.transactions as Dictionary).has(receipt):
		book.state = "CHOOSE_NEXT_ACTION"
		return {"ok": false, "code": "refused"}
	book.state = "EXECUTE_JUMP"
	if not clock.rebase_calendar(span.start):
		book.state = "CHOOSE_NEXT_ACTION"
		return {"ok": false, "code": "refused"}
	if fare > 0:
		_transact(receipt, -fare)
	record.paid = int(record.paid) + 1
	var world := _borrow(RealityState.data)
	book.visit = {"anchor": anchor_id, "home_calendar": home, "left_at": clock.elapsed_minutes(),
			"loop_started": clock.elapsed_minutes(), "world": world, "stage": {"done": []}}
	book.state = "RUN_LOOP"
	aide().warned = false
	aide().next_hint = HINT_FIRST_MINUTES
	RealityState.commit()
	stage_reset.emit()
	changed.emit()
	return {"ok": true, "fare": fare, "anchor": anchor_id}


static func _copy(value: Variant) -> Variant:
	return value.duplicate(true) if value is Dictionary or value is Array else value


## The borrowed domains of a campaign document, copied out.
static func _borrow(document: Dictionary) -> Dictionary:
	var world := {}
	for domain: String in REWOUND:
		if document.has(domain):
			world[domain] = _copy(document[domain])
	return world


## And put back as they were when the visit began.
static func _give_back(document: Dictionary, world: Dictionary) -> void:
	for domain: String in REWOUND:
		if world.has(domain):
			document[domain] = _copy(world[domain])
		else:
			document.erase(domain)


func _restore_world() -> void:
	_give_back(RealityState.data, (ledger().visit as Dictionary).get("world", {}))


## Run the anchor's hours again. Free: the fare bought the anchor, not the run.
## The room is as it was; evidence already taken stays taken.
func reset_loop() -> Dictionary:
	if not in_visit():
		return {"ok": false, "code": "home"}
	var book := ledger()
	var anchor_id := visit_anchor()
	var was := str(book.state)
	book.state = "RESET_LOOP"
	if not clock.rebase_calendar(_anchor_span(table.anchors[anchor_id]).start):
		# A refusal changes nothing: the room is where it was.
		book.state = was
		return {"ok": false, "code": "refused"}
	_restore_world()
	book.visit.loop_started = clock.elapsed_minutes()
	book.visit.stage = {"done": []}
	_record(anchor_id).loops = int(_record(anchor_id).loops) + 1
	book.state = "RUN_LOOP"
	RealityState.commit()
	stage_reset.emit()
	changed.emit()
	return {"ok": true, "loops": int(_record(anchor_id).loops)}


## Back to the present, which has moved on by exactly the time spent away.
func go_home() -> Dictionary:
	if not in_visit():
		return {"ok": false, "code": "home"}
	var book := ledger()
	var anchor_id := visit_anchor()
	var target := _home_calendar()
	var beginning := CampaignClock.loop_beginning_minute()
	target = beginning + fposmod(target - beginning, CampaignClock.loop_length_minutes())
	if CampaignClock.in_blackout(target):
		target = CampaignClock.blackout_end_minute()
	if not clock.rebase_calendar(target):
		return {"ok": false, "code": "refused"}
	_restore_world()
	book.visit = {}
	book.state = "CHOOSE_NEXT_ACTION"
	book.selected = ""
	_settle_pace()
	RealityState.commit()
	stage_reset.emit()
	changed.emit()
	return {"ok": true, "answered": answered(anchor_id), "carried": carried()}


## The last resort when neither a rerun nor the way home will take: the visit
## is closed where the calendar stands, the borrowed world is given back, and
## the player is home in every sense but the date. Evidence is kept.
func _abandon_visit() -> void:
	_restore_world()
	var book := ledger()
	book.visit = {}
	book.state = "CHOOSE_NEXT_ACTION"
	book.selected = ""
	_settle_pace()
	RealityState.commit()
	stage_reset.emit()
	changed.emit()


# --- The pace of time ---------------------------------------------------------------------

func _pace_owner() -> CampaignPace:
	if pace == null and is_inside_tree():
		var driver := get_tree().get_first_node_in_group("campaign_time_owner")
		if driver != null and driver.get("pace") is CampaignPace:
			pace = driver.get("pace")
	return pace


func _settle_pace() -> void:
	_wait_until = -1.0
	if pace != null and pace.reason.begins_with("loop:"):
		pace.settle()


## What the clock should run to now, and why: {} when the player has
## something to do, or has said STEADY. `until` is in elapsed minutes.
func pace_plan() -> Dictionary:
	if table.is_empty() or clock == null or bool(aide().get("steady", false)):
		return {}
	var rules: Dictionary = table.pace
	var now := clock.elapsed_minutes()
	if in_visit():
		var anchor_id := visit_anchor()
		var ends := float((ledger().visit as Dictionary).loop_started) + float(int(table.anchors[anchor_id].minutes))
		if answered(anchor_id):
			return {"until": ends, "rate": float(rules.done_rate), "why": "done:" + anchor_id,
					"say": "You have what you came for. I am running the clock to the end of the hours. HOME goes at once."}
		var step := current_step()
		if not step.is_empty() and str(step.kind) == "after":
			var began := float(_minute_of(str(table.anchors[anchor_id].start)))
			var due := float((ledger().visit as Dictionary).loop_started) \
					+ fposmod(float(_minute_of(str(step.time))) - began, float(CampaignClock.MINUTES_PER_DAY))
			if due > now:
				return {"until": minf(due, ends), "rate": float(rules.wait_rate), "why": "wait:%s:%s" % [anchor_id, str(step.id)],
						"say": "Nothing to be done here until %s. I am running the clock. STEADY stops it." % str(step.time)}
		return {}
	var day := floorf(now / float(CampaignClock.MINUTES_PER_DAY))
	if _wait_until > now:
		return {"until": _wait_until, "rate": float(rules.idle_rate), "why": "asked:%d" % int(day),
				"say": "Running the clock to tomorrow's allowance. STEADY stops it."}
	if _idle >= float(rules.idle_seconds):
		return {"until": (day + 1.0) * float(CampaignClock.MINUTES_PER_DAY), "rate": float(rules.idle_rate), "why": "idle:%d" % int(day),
				"say": "Nothing is pressing. I am running the clock toward tomorrow. Anything you do stops it."}
	return {}


func _set_pace() -> void:
	var owner := _pace_owner()
	if owner == null:
		return
	var plan := pace_plan()
	if plan.is_empty():
		if owner.reason.begins_with("loop:"):
			owner.settle()
		return
	var rules: Dictionary = table.pace
	owner.run_to(float(plan.until), float(plan.rate), "loop:" + str(plan.why), float(rules.landing_seconds), float(rules.ramp_seconds))
	if _pace_said != str(plan.why):
		_pace_said = str(plan.why)
		if not bool(aide().quiet):
			slip.emit("CLOCK", str(plan.say))


## Anything the player does ends an idle run at home, at once.
func _input(event: InputEvent) -> void:
	var acted := false
	if event is InputEventKey or event is InputEventMouseButton or event is InputEventJoypadButton:
		acted = event.is_pressed()
	elif event is InputEventMouseMotion:
		acted = (event as InputEventMouseMotion).relative.length() > 1.0
	elif event is InputEventJoypadMotion:
		acted = absf((event as InputEventJoypadMotion).axis_value) > 0.3
	if acted:
		note_activity()


## The player did something. Called for input, and by anything else that knows.
func note_activity() -> void:
	_idle = 0.0
	if pace != null and pace.reason.begins_with("loop:idle"):
		pace.settle()


# --- The companion's own initiative ---------------------------------------------------

func _process(delta: float) -> void:
	_poll += delta
	_idle += delta
	if _poll < 1.0 or clock == null or table.is_empty() or RealityState.save_write_blocked:
		return
	_poll = 0.0
	if not clock.loop_calendar_active():
		_settle_pace()
		return
	if in_visit():
		_attend_visit()
	else:
		_attend_home()
	_set_pace()


## The companion's own record: what it has already said and done unasked.
func aide() -> Dictionary:
	var book := ledger()
	if book.get("aide") is not Dictionary:
		book["aide"] = {"quiet": false, "drawn_day": -1, "nudged_day": -1,
				"next_hint": HINT_FIRST_MINUTES, "warned": false}
	return book.aide


## At home the companion acts for the player without being asked: it draws
## the day's allowance into the bank, and once a day says what it would do.
func _attend_home() -> void:
	var notes := aide()
	var day := int(clock.elapsed_minutes() / CampaignClock.MINUTES_PER_DAY)
	if int(notes.drawn_day) != day:
		notes.drawn_day = day
		var drawn := claim_stipend()
		if drawn.ok and not bool(notes.quiet):
			slip.emit("DRAWN FOR YOU", "The day's allowance, %s. Banked %s." % [Economy.money(int(drawn.cents)), Economy.money(bank_cents())])
		return
	# The year's events are told once each time the present comes to them.
	var event := event_on(today())
	if not event.is_empty():
		var telling := "%s:%s:%d" % [str(event.id), "broken" if bool(event.broken) else "before", day / days_in_year()]
		if str(notes.get("event_told", "")) != telling:
			notes["event_told"] = telling
			if not bool(notes.quiet):
				slip.emit(str(event.mark), str(event.slip) if bool(event.broken) else str(event.before))
			return
	if int(notes.nudged_day) == day or bool(notes.quiet):
		return
	notes.nudged_day = day
	slip.emit("ADVICE", home_hint())


## Away, it watches the hours: it says the next step when a while passes,
## warns before the hours end, and at the end either brings the player home
## with the evidence or begins the hours again.
func _attend_visit() -> void:
	var notes := aide()
	var anchor_id := visit_anchor()
	var left := loop_minutes_left()
	if left <= 0.0:
		if answered(anchor_id):
			var back := go_home()
			if back.ok:
				slip.emit("HOME", "The hours are done and you have what you came for. I have brought you home. Pin it to the wall.")
			return
		var again := reset_loop()
		if again.ok:
			notes.warned = false
			notes.next_hint = HINT_FIRST_MINUTES
			slip.emit("AGAIN", "%s. The hours begin again. Run %d." % [str(table.anchors[anchor_id].title), int(again.loops) + 1])
			return
		# The hours would not begin again. Home, then; and if even that is
		# refused, the visit is closed where it stands. Never left hanging.
		if go_home().ok:
			slip.emit("HOME", "The hours would not run again. I have brought you home. The lead is still open.")
		else:
			_abandon_visit()
			slip.emit("HOME", "The line dropped. You are home, and the lead is still open.")
		return
	if bool(notes.quiet) or answered(anchor_id):
		return
	if left <= WARN_MINUTES and not bool(notes.warned):
		notes.warned = true
		slip.emit("TIME", "%d minutes. Then the hours begin again. What you have taken, you keep." % int(ceil(left)))
	elif loop_minutes() >= float(notes.next_hint):
		notes.next_hint = loop_minutes() + HINT_EVERY_MINUTES
		# While the clock is being run through a wait, minutes are cheap: no hint for each dozen of them.
		if pace_plan().is_empty():
			slip.emit("HINT", visit_hint())


## The authored hint for the step the room is waiting on.
func visit_hint() -> String:
	if answered(visit_anchor()):
		return "You have it. HOME, and pin it to the wall."
	var step := current_step()
	if step.is_empty():
		return "%s. It is there now. Take it." % str(clue_of(visit_anchor()).title)
	return str(step.hint)


## What the companion would do next, from where the player stands at home.
func home_hint() -> String:
	if not carried().is_empty():
		return "You are carrying %s. Pin it to the case wall in 4B. The wall decides what opens." % str(item_text(carried()[0]).title)
	for item_id: String in on_wall():
		if not dated(item_id):
			return "%s is pinned but has no day. Slide its tag along the year to the day it comes from." % str(item_text(item_id).title)
		if not placed(item_id):
			return "%s has its day but no place. Pull its pin, then the pin of the room on the map where you found it." % str(item_text(item_id).title)
	var loose := open_deduction()
	if not loose.is_empty():
		var tries := int(ledger().get("tries", 0))
		if tries < 3:
			return "Something on the wall wants joining. Pull the pin of one piece, then the pin of another, and see if the string holds."
		return "Try a string from %s to %s." % [str(item_text(str(loose.needs[0])).title), str(item_text(str(loose.needs[1])).title)]
	var index := 0
	var cheapest := -1
	for anchor_id: String in unlocked():
		index += 1
		if answered(anchor_id):
			continue
		var fare := fare_cents(anchor_id)
		if fare <= bank_cents():
			return "A line is open: %s. Fare %s, banked %s. JUMP %d." % [str(table.anchors[anchor_id].title),
					Economy.money(fare), Economy.money(bank_cents()), index]
		cheapest = fare if cheapest < 0 else mini(cheapest, fare)
	if cheapest < 0:
		return "Every open line is worked. Read the wall."
	var pocket := int(economy.book().cash) if economy != null else 0
	if pocket + bank_cents() >= cheapest:
		return "The next fare is %s. You have it in your pocket. DEPOSIT %d." % [Economy.money(cheapest), cheapest - bank_cents()]
	return "The next fare is %s and %s is banked. The house pays for work done: take a job from the board, then DEPOSIT. The allowance comes daily besides." % [
			Economy.money(cheapest), Economy.money(bank_cents())]


# --- The paper ---------------------------------------------------------------------

## The typed commands the service set answers on paper. Returns {} when the
## text is not one of them, so ordinary correspondence goes on as before.
func command(raw: String) -> Dictionary:
	var words := raw.strip_edges().to_lower().split(" ", false)
	if words.is_empty() or table.is_empty() or RealityState.save_write_blocked:
		return {}
	match words[0]:
		"hint":
			return {"intent": "temporal", "text": visit_hint() if in_visit() else home_hint()}
		"quiet", "hints":
			aide().quiet = words[0] == "quiet"
			RealityState.commit_background()
			return {"intent": "temporal", "text": "I will keep to myself. HINT when you want one. HINTS to have me speak up again."
					if words[0] == "quiet" else "I will speak up when I have something."}
		"wait":
			if bool(aide().get("steady", false)):
				return {"intent": "temporal", "text": "THE CLOCK IS HELD STEADY. PACE LETS IT RUN."}
			if in_visit():
				return {"intent": "temporal", "text": "RUNNING THE CLOCK." if not pace_plan().is_empty()
						else "THERE IS SOMETHING TO DO HERE. HINT SAYS WHAT."}
			_wait_until = (floorf(clock.elapsed_minutes() / float(CampaignClock.MINUTES_PER_DAY)) + 1.0) * float(CampaignClock.MINUTES_PER_DAY)
			_set_pace()
			return {"intent": "temporal", "text": "RUNNING THE CLOCK TO TOMORROW'S ALLOWANCE. STEADY STOPS IT."}
		"steady", "pace":
			aide()["steady"] = words[0] == "steady"
			_wait_until = -1.0
			_pace_said = ""
			if words[0] == "steady":
				_settle_pace()
			RealityState.commit_background()
			return {"intent": "temporal", "text": "THE CLOCK KEEPS ITS OWN TIME NOW. PACE LETS IT RUN WHEN NOTHING IS DOING."
					if words[0] == "steady" else "THE CLOCK WILL RUN WHEN NOTHING IS DOING. WAIT ASKS FOR IT."}
		"leads":
			return {"intent": "temporal", "text": leads_text()}
		"wall":
			return {"intent": "temporal", "text": wall_text()}
		"bank", "balance":
			return {"intent": "temporal", "text": "%s\nBANKED %s   POCKET %s\nDEPOSIT n puts n cents by." % [
					str(table.bank_name).to_upper(), Economy.money(bank_cents()),
					Economy.money(int(economy.book().cash)) if economy != null else "?"]}
		"allowance":
			var drawn := claim_stipend()
			return {"intent": "temporal", "text": "ALLOWANCE %s BANKED." % Economy.money(int(drawn.cents)) if drawn.ok
					else ("NOT WHILE AWAY." if drawn.code == "away" else "TODAY'S IS DRAWN.")}
		"deposit":
			if words.size() < 2 or not words[1].is_valid_int():
				return {"intent": "temporal", "text": "DEPOSIT n. CENTS."}
			var put := deposit(int(words[1]))
			return {"intent": "temporal", "text": "BANKED %s. BALANCE %s." % [Economy.money(int(put.cents)), Economy.money(bank_cents())] if put.ok
					else ("NOT WHILE AWAY. MONEY EARNED THERE STAYS THERE. EVIDENCE COMES HOME." if put.code == "away" else "THE POCKET IS SHORT.")}
		"jump":
			var ids := unlocked()
			if words.size() < 2 or not words[1].is_valid_int() or int(words[1]) < 1 or int(words[1]) > ids.size():
				return {"intent": "temporal", "text": "JUMP n. SEE LEADS."}
			var anchor_id := ids[int(words[1]) - 1]
			var went := jump(anchor_id)
			if went.ok:
				return {"intent": "temporal", "text": anchor_text(anchor_id) + "\nFARE %s. AGAIN reruns. HOME returns." % Economy.money(int(went.fare))}
			match str(went.code):
				"fare": return {"intent": "temporal", "text": "FARE %s. BANKED %s. EARN, DEPOSIT, OR WAIT FOR THE ALLOWANCE." % [Economy.money(int(went.fare)), Economy.money(int(went.bank))]}
				"away": return {"intent": "temporal", "text": "HOME FIRST."}
			return {"intent": "temporal", "text": "NO LINE TO THAT HOUR."}
		"again":
			var again := reset_loop()
			return {"intent": "temporal", "text": "THE HOURS BEGIN AGAIN. RUN %d. NO FARE." % (int(again.loops) + 1) if again.ok else "NOTHING TO RUN AGAIN."}
		"home":
			var back := go_home()
			if not back.ok:
				return {"intent": "temporal", "text": "ALREADY HOME."}
			return {"intent": "temporal", "text": "HOME. THE PRESENT KEPT ITS OWN TIME." + ("\nPIN WHAT YOU CARRY TO THE WALL IN 4B." if not (back.carried as Array).is_empty() else "")}
	return {}


func anchor_text(anchor_id: String) -> String:
	var anchor: Dictionary = table.anchors[anchor_id]
	return "%s\n%s, %s, %s. %d MINUTES.\n%s. %s.\n%s" % [str(anchor.title).to_upper(), str(anchor.place).to_upper(),
			str(anchor.date), str(anchor.start), int(anchor.minutes), str(anchor.season).to_upper(),
			str(anchor.occasion).to_upper(), str(anchor.question)]


## The season and nearest occasion of a calendar date ("1929-07-04"), from the
## year's table: what the house would be dressed for on that day. The occasion
## is named from a week before it until two days after.
func dressed_for(date: String) -> Dictionary:
	var parts := date.split("-")
	if parts.size() != 3:
		return {}
	var day := CampaignClock.calendar_minute_of(int(parts[0]), int(parts[1]), int(parts[2]), 0.0) / CampaignClock.MINUTES_PER_DAY
	var season := ""
	var occasion := ""
	var nearest := 1.0e9
	var nearest_occasion := 1.0e9
	for entry: Dictionary in table.calendar:
		var at := str(entry.date).split("-")
		var its_day := CampaignClock.calendar_minute_of(int(at[0]), int(at[1]), int(at[2]), 0.0) / CampaignClock.MINUTES_PER_DAY
		if absf(its_day - day) < nearest:
			nearest = absf(its_day - day)
			season = str(entry.season)
		if day >= its_day - 7.0 and day <= its_day + 2.0 and absf(its_day - day) < nearest_occasion:
			nearest_occasion = absf(its_day - day)
			occasion = str(entry.name)
	return {"season": season, "occasion": occasion}


## How a lead's day has the blinds and curtains: raise, tilt_degrees, curtain_open.
func windows_of(anchor_id: String) -> Dictionary:
	return table.anchors[anchor_id].windows


## What a lead's rooms show of their day, for whoever dresses the set.
func dressing_of(anchor_id: String) -> Array:
	return table.anchors[anchor_id].dressing


func leads_text() -> String:
	var lines: Array[String] = []
	if in_visit():
		lines.append("AWAY AT %s. %d MINUTES LEFT." % [str(table.anchors[visit_anchor()].title).to_upper(), int(ceil(loop_minutes_left()))])
	var index := 0
	for anchor_id: String in unlocked():
		index += 1
		var anchor: Dictionary = table.anchors[anchor_id]
		lines.append("%d. %s  %s %s  FARE %s  %s" % [index, str(anchor.title).to_upper(), str(anchor.date),
				str(anchor.start), Economy.money(fare_cents(anchor_id)), "WORKED" if answered(anchor_id) else "OPEN"])
		lines.append("   %s" % str(anchor.question))
	if not carried().is_empty():
		lines.append("CARRIED, NOT YET PINNED: %d." % carried().size())
	lines.append("BANKED %s. JUMP n. AGAIN. HOME. BANK. WALL. HINT." % Economy.money(bank_cents()))
	return "\n".join(lines)


func wall_text() -> String:
	var lines: Array[String] = ["THE WALL, 4B."]
	for item_id: String in on_wall():
		lines.append("- %s%s" % [str(item_text(item_id).title).to_upper(), "" if filed(item_id) else "  (not filed)"])
	for item_id: String in carried():
		lines.append("  (carried) %s" % str(item_text(item_id).title))
	for string: Array in strings():
		lines.append("  ~ %s to %s" % [str(item_text(str(string[0])).title), str(item_text(str(string[1])).title)])
	for deduction_id: Variant in ledger().deductions:
		lines.append("* %s" % str(table.deductions[str(deduction_id)].line))
	if lines.size() == 1:
		lines.append("NOTHING PINNED YET.")
	return "\n".join(lines)
