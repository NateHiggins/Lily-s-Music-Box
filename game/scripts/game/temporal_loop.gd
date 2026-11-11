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


func setup(campaign_clock: CampaignClock, caretaker_economy: Node) -> bool:
	clock = campaign_clock
	economy = caretaker_economy
	table = _load_table()
	if table.is_empty() or clock == null or PaperPocket.KEY in REWOUND or "knowledge_flags" in REWOUND:
		return false
	add_to_group("temporal_loop")
	return true


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
	if not (parsed.get("stipend", {}) as Dictionary).has("cents") or str(parsed.get("bank_name", "")).is_empty() \
			or str(parsed.get("wall", "")).is_empty():
		return {}
	var clues := {}
	for anchor_id: String in parsed.anchors:
		var anchor: Dictionary = parsed.anchors[anchor_id]
		for field: String in ["title", "place", "date", "start", "minutes", "question", "tier", "needs", "steps", "clue"]:
			if not anchor.has(field):
				return {}
		anchor["strict"] = bool(anchor.get("strict", false))
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
	# The tree: every need is some other anchor's clue, and tiers only climb.
	for anchor_id: String in parsed.anchors:
		for need: Variant in parsed.anchors[anchor_id].needs:
			if not clues.has(str(need)) or str(clues[str(need)]) == anchor_id \
					or int(parsed.anchors[str(clues[str(need)])].tier) >= int(parsed.anchors[anchor_id].tier):
				return {}
	for deduction_id: String in parsed.get("deductions", {}):
		var deduction: Dictionary = parsed.deductions[deduction_id]
		if deduction.get("needs") is not Array or str(deduction.get("line", "")).is_empty():
			return {}
		for need: Variant in deduction.needs:
			if not clues.has(str(need)):
				return {}
	parsed["clue_anchor"] = clues
	return parsed


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
				"transactions": {}, "anchors": {}, "items": {}, "deductions": [],
				"visit": {}, "selected": ""}
		RealityState.data[KEY] = value
	return value


static func valid(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	for field: String in ["transactions", "anchors", "visit", "items"]:
		if value.get(field) is not Dictionary:
			return false
	if value.get("deductions") is not Array:
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


## A lead is open when everything it needs is pinned to the wall.
func unlocked() -> Array[String]:
	var ids: Array[String] = []
	for anchor_id: String in table.anchors:
		var open := true
		for need: Variant in table.anchors[anchor_id].needs:
			open = open and pinned(str(need))
		if open:
			ids.append(anchor_id)
	return ids


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
	var drawn: Array[String] = []
	for deduction_id: String in table.get("deductions", {}):
		if deduction_id in book.deductions:
			continue
		var complete := true
		for need: Variant in table.deductions[deduction_id].needs:
			complete = complete and pinned(str(need))
		if complete:
			book.deductions.append(deduction_id)
			drawn.append(deduction_id)
	RealityState.commit()
	changed.emit()
	return {"ok": true, "item": item_id, "opened": opened, "deductions": drawn}


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
			"after": passed = clock.minute_of_day() >= float(_minute_of(str(step.time)))
			"flag": passed = RealityState.has_knowledge(str(step.flag))
		if not passed:
			return
		_advance(step)


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


## The house's daily allowance, once per day of the player's own time and only
## at home. It is the floor under the economy: a player with nothing can
## always afford the next lead in a few days.
func claim_stipend() -> Dictionary:
	if in_visit():
		return {"ok": false, "code": "away"}
	var day := int(clock.elapsed_minutes() / CampaignClock.MINUTES_PER_DAY)
	if not _transact("stipend:%d" % day, int(table.stipend.cents)):
		return {"ok": false, "code": "already_drawn"}
	RealityState.commit()
	changed.emit()
	return {"ok": true, "cents": int(table.stipend.cents)}


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
	book.state = "RESET_LOOP"
	if not clock.rebase_calendar(_anchor_span(table.anchors[anchor_id]).start):
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
	RealityState.commit()
	stage_reset.emit()
	changed.emit()
	return {"ok": true, "answered": answered(anchor_id), "carried": carried()}


# --- The companion's own initiative ---------------------------------------------------

func _process(delta: float) -> void:
	_poll += delta
	if _poll < 1.0 or clock == null or table.is_empty() or RealityState.save_write_blocked:
		return
	_poll = 0.0
	if not clock.loop_calendar_active():
		return
	if in_visit():
		_attend_visit()
	else:
		_attend_home()


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
	if bool(notes.quiet) or answered(anchor_id):
		return
	if left <= WARN_MINUTES and not bool(notes.warned):
		notes.warned = true
		slip.emit("TIME", "%d minutes. Then the hours begin again. What you have taken, you keep." % int(ceil(left)))
	elif loop_minutes() >= float(notes.next_hint):
		notes.next_hint = loop_minutes() + HINT_EVERY_MINUTES
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
	return "%s\n%s, %s, %s. %d MINUTES.\n%s" % [str(anchor.title).to_upper(), str(anchor.place).to_upper(),
			str(anchor.date), str(anchor.start), int(anchor.minutes), str(anchor.question)]


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
		lines.append("- %s" % str(item_text(item_id).title).to_upper())
	for item_id: String in carried():
		lines.append("  (carried) %s" % str(item_text(item_id).title))
	for deduction_id: Variant in ledger().deductions:
		lines.append("* %s" % str(table.deductions[str(deduction_id)].line))
	if lines.size() == 1:
		lines.append("NOTHING PINNED YET.")
	return "\n".join(lines)
