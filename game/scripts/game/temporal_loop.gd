extends Node
## The temporal investigation loop. A lead is an anchor: a place, a date, a
## start, a length and a question. The player pays a fare from banked funds to
## be put down at an anchor, may run its hours as often as they like for
## nothing, and carries home only what they learned.
##
## Three clocks: the historical one (the civil calendar, moved by
## CampaignClock.rebase_calendar), the loop one (minutes since this run of the
## anchor began) and the player's own (elapsed minutes, which never go back, so
## rent and deliveries stay honest through every visit).
##
## Evidence is what each trip is for, and it is kept: what was heard (knowledge
## flags) and what was collected (the valise's evidence folder, papers and
## letters, which no visit or rerun touches). Also kept: the bank, its
## transactions, unlocked and resolved anchors, deductions. What a visit or a
## rerun puts back: the REWOUND domains, which are pocket cash, tools and
## stores, keys, shop stock and standing with the residents.
## Money can therefore reach the bank only by a deposit made at home, and a
## deposit is one committed transaction.
##
## The companion has its own initiative (Bible, ruling of 2026-11-10): it
## draws the allowance, advises at home, hints and warns during a visit, and
## brings the player home when the hours end with the question answered.
## Everything it says is authored here or in the anchors table (RUL-015).
##
## Every entry to the past goes through `jump`, `reset_loop` or `go_home`, and
## each of those goes through the clock's rebase, which refuses the murder
## hours. An anchor may not start or end inside them either.

signal changed
signal slip(title: String, body: String)

const KEY := "temporal"
const DATA_PATH := "res://data/temporal/anchors.json"
const Economy := preload("res://scripts/game/caretaker_economy.gd")
const PaperPocket := preload("res://scripts/game/paper_pocket.gd")
## A find kept in the valise's evidence folder is held in the ledger under
## this prefix, so a lead can ask for a thing collected as well as a thing heard.
const FOUND_PREFIX := "ev:"
## Campaign domains a visit borrows and gives back. Knowledge and the valise
## (PaperPocket.KEY) must never be among them: evidence is kept.
const REWOUND: Array[String] = ["caretaker_economy", "inventories", "door_keys",
		"shop_stock", "conversation_visits", "resident_trust"]
const STATES: Array[String] = ["CHOOSE_NEXT_ACTION", "SELECT_ANCHOR", "FUND_JUMP",
		"EXECUTE_JUMP", "RUN_LOOP", "INVESTIGATE", "RESET_LOOP", "RESOLVE_ANCHOR"]

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
	if parsed is not Dictionary or int(parsed.get("version", 0)) != 1 or parsed.get("anchors") is not Dictionary:
		return {}
	var fare: Dictionary = parsed.get("fare", {})
	for field: String in ["base_cents", "days_per_cent", "cap_cents", "worn_groove_divisor"]:
		if not fare.has(field):
			return {}
	if not (parsed.get("stipend", {}) as Dictionary).has("cents") or str(parsed.get("bank_name", "")).is_empty():
		return {}
	for anchor_id: String in parsed.anchors:
		var anchor: Dictionary = parsed.anchors[anchor_id]
		for field: String in ["title", "place", "date", "start", "minutes", "question", "evidence", "successors"]:
			if not anchor.has(field):
				return {}
		anchor["leads"] = anchor.get("leads", [])
		if anchor.get("hints") is not Array:
			return {}
		anchor["first_call_free"] = bool(anchor.get("first_call_free", false))
		var span := _anchor_span(anchor)
		# No anchor may touch the murder hours, by its own data.
		if span.is_empty() or CampaignClock.in_blackout(span.start) \
				or (span.start < CampaignClock.blackout_end_minute() and span.end > CampaignClock.blackout_start_minute()):
			return {}
	for deduction_id: String in parsed.get("deductions", {}):
		var deduction: Dictionary = parsed.deductions[deduction_id]
		if deduction.get("needs") is not Array or str(deduction.get("line", "")).is_empty():
			return {}
	if parsed.get("opening") is not Array:
		return {}
	return parsed


static func _anchor_span(anchor: Dictionary) -> Dictionary:
	var date := str(anchor.date).split("-")
	var hour := str(anchor.start).split(":")
	if date.size() != 3 or hour.size() != 2 or int(anchor.minutes) <= 0:
		return {}
	var start := CampaignClock.calendar_minute_of(int(date[0]), int(date[1]), int(date[2]),
			float(int(hour[0]) * 60 + int(hour[1])))
	return {"start": start, "end": start + float(int(anchor.minutes))}


## The persistent ledger. Created on first use with the opening leads.
func ledger() -> Dictionary:
	var value: Variant = RealityState.data.get(KEY)
	if value is not Dictionary or int(value.get("version", 0)) != 1:
		value = {"version": 1, "state": "CHOOSE_NEXT_ACTION", "bank_cents": 0,
				"transactions": {}, "anchors": {}, "evidence": [], "deductions": [],
				"visit": {}, "selected": ""}
		for anchor_id: Variant in table.get("opening", []):
			value.anchors[str(anchor_id)] = {"paid": 0, "loops": 0, "resolved": false}
		RealityState.data[KEY] = value
	return value


static func valid(value: Variant) -> bool:
	if value is not Dictionary:
		return false
	for field: String in ["transactions", "anchors", "visit"]:
		if value.get(field) is not Dictionary:
			return false
	for field: String in ["evidence", "deductions"]:
		if value.get(field) is not Array:
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


## Minutes since this run of the anchor began: the loop clock.
func loop_minutes() -> float:
	var visit: Dictionary = ledger().visit
	return 0.0 if visit.is_empty() else clock.elapsed_minutes() - float(visit.loop_started)


func loop_minutes_left() -> float:
	if not in_visit():
		return 0.0
	return float(int(table.anchors[visit_anchor()].minutes)) - loop_minutes()


func unlocked() -> Array[String]:
	var ids: Array[String] = []
	for anchor_id: String in table.anchors:
		if (ledger().anchors as Dictionary).has(anchor_id):
			ids.append(anchor_id)
	return ids


func holds(flag: String) -> bool:
	return flag in ledger().evidence


func evidence_missing(anchor_id: String) -> Array[String]:
	var missing: Array[String] = []
	for flag: Variant in table.anchors[anchor_id].evidence:
		if not holds(str(flag)):
			missing.append(str(flag))
	return missing


## The fare is fixed by the anchor and by how far the present is from it in
## the year: the same question from the same day always costs the same. The
## first call to an opening lead is on the house, and a resolved anchor is a
## worn groove at a fraction of the fare.
func fare_cents(anchor_id: String) -> int:
	if not table.anchors.has(anchor_id):
		return -1
	var anchor: Dictionary = table.anchors[anchor_id]
	var record: Dictionary = (ledger().anchors as Dictionary).get(anchor_id, {})
	if bool(anchor.first_call_free) and int(record.get("paid", 0)) == 0:
		return 0
	var fare: Dictionary = table.fare
	var year := CampaignClock.loop_length_minutes()
	var apart := fposmod(_anchor_span(anchor).start - _home_calendar(), year)
	var days := int(minf(apart, year - apart) / CampaignClock.MINUTES_PER_DAY)
	var cents := mini(int(fare.cap_cents), int(fare.base_cents) + int(ceil(float(days) / float(int(fare.days_per_cent)))))
	return cents / int(fare.worn_groove_divisor) if bool(record.get("resolved", false)) else cents


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
	var record: Dictionary = book.anchors[anchor_id]
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
			"loop_started": clock.elapsed_minutes(), "world": world}
	book.state = "RUN_LOOP"
	aide().warned = false
	aide().next_hint = HINT_FIRST_MINUTES
	RealityState.commit()
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
func reset_loop() -> Dictionary:
	if not in_visit():
		return {"ok": false, "code": "home"}
	var book := ledger()
	collect()
	var anchor_id := visit_anchor()
	book.state = "RESET_LOOP"
	if not clock.rebase_calendar(_anchor_span(table.anchors[anchor_id]).start):
		return {"ok": false, "code": "refused"}
	_restore_world()
	book.visit.loop_started = clock.elapsed_minutes()
	book.anchors[anchor_id].loops = int(book.anchors[anchor_id].loops) + 1
	book.state = "RUN_LOOP"
	RealityState.commit()
	changed.emit()
	return {"ok": true, "loops": int(book.anchors[anchor_id].loops)}


## Back to the present, which has moved on by exactly the time spent away.
func go_home() -> Dictionary:
	if not in_visit():
		return {"ok": false, "code": "home"}
	var book := ledger()
	collect()
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
	var opened: Array[String] = []
	if evidence_missing(anchor_id).is_empty():
		book.state = "RESOLVE_ANCHOR"
		book.anchors[anchor_id].resolved = true
		for successor: Variant in table.anchors[anchor_id].successors:
			if not (book.anchors as Dictionary).has(str(successor)):
				book.anchors[str(successor)] = {"paid": 0, "loops": 0, "resolved": false}
				opened.append(str(successor))
	book.state = "CHOOSE_NEXT_ACTION"
	book.selected = ""
	RealityState.commit()
	changed.emit()
	return {"ok": true, "resolved": bool(book.anchors[anchor_id].resolved), "opened": opened}


## Move what the player now knows into the ledger, and draw any deduction it
## completes. Returns the new evidence and deduction ids.
func collect() -> Dictionary:
	var book := ledger()
	var found: Array[String] = []
	var drawn: Array[String] = []
	for find: Variant in PaperPocket.book().evidence:
		var held := FOUND_PREFIX + str(find.id)
		if held not in book.evidence:
			book.evidence.append(held)
			found.append(held)
	for anchor_id: String in table.anchors:
		for flag: Variant in table.anchors[anchor_id].evidence:
			if str(flag) not in book.evidence and not str(flag).begins_with(FOUND_PREFIX) and RealityState.has_knowledge(str(flag)):
				book.evidence.append(str(flag))
				found.append(str(flag))
	for deduction_id: String in table.get("deductions", {}):
		if deduction_id in book.deductions:
			continue
		var complete := true
		for flag: Variant in table.deductions[deduction_id].needs:
			complete = complete and str(flag) in book.evidence
		if complete:
			book.deductions.append(deduction_id)
			drawn.append(deduction_id)
	if in_visit() and not found.is_empty():
		book.state = "RESOLVE_ANCHOR" if evidence_missing(visit_anchor()).is_empty() else "INVESTIGATE"
	return {"evidence": found, "deductions": drawn}


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
		book["aide"] = {"quiet": false, "drawn_day": -1, "nudged_day": -1, "tiers": {},
				"next_hint": HINT_FIRST_MINUTES, "warned": false}
	return book.aide


## At home the companion acts for the player without being asked: it draws
## the day's allowance into the bank, and once a day says which line is open
## or what stands between the player and the next fare.
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


## Away, it watches the hours: it files what the player learns, speaks up
## with the next hint when a while passes with the question open, warns
## before the hours end, and at the end either brings the player home with
## the answer or begins the hours again.
func _attend_visit() -> void:
	var notes := aide()
	var anchor_id := visit_anchor()
	var news := collect()
	for deduction_id: String in news.deductions:
		slip.emit("DEDUCTION", str(table.deductions[deduction_id].line))
	var answered := evidence_missing(anchor_id).is_empty()
	if not (news.evidence as Array).is_empty():
		RealityState.commit_background()
		changed.emit()
		if answered:
			slip.emit("ANSWERED", "%s HOME when ready. AGAIN to run the hours once more." % str(table.anchors[anchor_id].question))
	var left := loop_minutes_left()
	if left <= 0.0:
		if answered:
			var back := go_home()
			if back.ok:
				var text := "The hours are done and the question is answered. I have brought you home."
				for opened: String in back.opened:
					text += " New lead: %s." % str(table.anchors[opened].title)
				slip.emit("HOME", text)
			return
		var again := reset_loop()
		if again.ok:
			notes.warned = false
			notes.next_hint = HINT_FIRST_MINUTES
			slip.emit("AGAIN", "%s. The hours begin again. Run %d." % [str(table.anchors[anchor_id].title), int(again.loops) + 1])
		return
	if bool(notes.quiet) or answered:
		return
	if left <= WARN_MINUTES and not bool(notes.warned):
		notes.warned = true
		slip.emit("TIME", "%d minutes. Then the hours begin again, and nothing you have learned is lost." % int(ceil(left)))
	elif loop_minutes() >= float(notes.next_hint):
		notes.next_hint = loop_minutes() + HINT_EVERY_MINUTES
		var hint := next_hint(anchor_id)
		if not hint.is_empty():
			slip.emit("HINT", hint)


## The next authored hint for a lead, a step plainer each time it is asked.
## The last one repeats.
func next_hint(anchor_id: String) -> String:
	var hints: Array = table.anchors[anchor_id].hints
	if hints.is_empty():
		return ""
	var tiers: Dictionary = aide().tiers
	var tier := mini(int(tiers.get(anchor_id, 0)), hints.size() - 1)
	tiers[anchor_id] = tier + 1
	return str(hints[tier])


## What the companion would do next, from where the player stands at home.
func home_hint() -> String:
	var index := 0
	var cheapest := -1
	for anchor_id: String in unlocked():
		index += 1
		if bool(ledger().anchors[anchor_id].resolved):
			continue
		var fare := fare_cents(anchor_id)
		if fare <= bank_cents():
			return "A line is open: %s. Fare %s, banked %s. JUMP %d." % [str(table.anchors[anchor_id].title),
					Economy.money(fare), Economy.money(bank_cents()), index]
		cheapest = fare if cheapest < 0 else mini(cheapest, fare)
	if cheapest < 0:
		return "Every open question is answered. Read the deductions under LEADS."
	var pocket := int(economy.book().cash) if economy != null else 0
	if pocket + bank_cents() >= cheapest:
		return "The next fare is %s. You have it in your pocket. DEPOSIT %d." % [Economy.money(cheapest), cheapest - bank_cents()]
	return "The next fare is %s and %s is banked. The house pays for work done: take a job from the board, then DEPOSIT. The allowance comes daily besides." % [
			Economy.money(cheapest), Economy.money(bank_cents())]


## The player asking for a hint outright.
func asked_hint() -> String:
	if not in_visit():
		return home_hint()
	if evidence_missing(visit_anchor()).is_empty():
		return "The question here is answered. HOME, or AGAIN."
	return next_hint(visit_anchor())


## The typed commands the service set answers on paper. Returns {} when the
## text is not one of them, so ordinary correspondence goes on as before.
func command(raw: String) -> Dictionary:
	var words := raw.strip_edges().to_lower().split(" ", false)
	if words.is_empty() or table.is_empty() or RealityState.save_write_blocked:
		return {}
	match words[0]:
		"hint":
			return {"intent": "temporal", "text": asked_hint()}
		"quiet", "hints":
			aide().quiet = words[0] == "quiet"
			RealityState.commit_background()
			return {"intent": "temporal", "text": "I will keep to myself. HINT when you want one. HINTS to have me speak up again."
					if words[0] == "quiet" else "I will speak up when I have something."}
		"leads":
			return {"intent": "temporal", "text": leads_text()}
		"bank", "balance":
			return {"intent": "temporal", "text": "%s\nBANKED %s   POCKET %s\nDEPOSIT n puts n cents by. ALLOWANCE draws the day's." % [
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
				"fare": return {"intent": "temporal", "text": "FARE %s. BANKED %s. EARN, DEPOSIT, OR DRAW THE ALLOWANCE." % [Economy.money(int(went.fare)), Economy.money(int(went.bank))]}
				"away": return {"intent": "temporal", "text": "HOME FIRST."}
			return {"intent": "temporal", "text": "NO LINE TO THAT HOUR."}
		"again":
			var again := reset_loop()
			return {"intent": "temporal", "text": "THE HOURS BEGIN AGAIN. RUN %d. NO FARE." % (int(again.loops) + 1) if again.ok else "NOTHING TO RUN AGAIN."}
		"home":
			var back := go_home()
			if not back.ok:
				return {"intent": "temporal", "text": "ALREADY HOME."}
			var text := "HOME. THE PRESENT KEPT ITS OWN TIME."
			for opened: String in back.opened:
				text += "\nNEW LEAD: %s." % str(table.anchors[opened].title).to_upper()
			return {"intent": "temporal", "text": text}
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
		var record: Dictionary = ledger().anchors[anchor_id]
		var mark := "ANSWERED" if bool(record.resolved) else "%d OF %d" % [
				anchor.evidence.size() - evidence_missing(anchor_id).size(), anchor.evidence.size()]
		lines.append("%d. %s  %s %s  FARE %s  %s" % [index, str(anchor.title).to_upper(), str(anchor.date),
				str(anchor.start), Economy.money(fare_cents(anchor_id)), mark])
		lines.append("   %s" % str(anchor.question))
		for lead: Variant in anchor.leads:
			if not RealityState.has_knowledge(str(lead)):
				lines.append("   SOMETHING ELSEWHERE WOULD HELP HERE.")
				break
	for deduction_id: Variant in ledger().deductions:
		lines.append("* %s" % str(table.deductions[str(deduction_id)].line))
	lines.append("BANKED %s. JUMP n. AGAIN. HOME. BANK. HINT." % Economy.money(bank_cents()))
	return "\n".join(lines)
