class_name Otis
extends RefCounted
## OTIS — working the Orison's elevator for a shift.
##
## Eight landings, one car, and residents who want to be somewhere else.
## You send the car; it decides how much of that it is going to do. The
## difficulty is not authored as levels — it is the building's own
## traffic, and the car's own faults, arriving at once.
##
## THE CAR IS THE ANTAGONIST, and its faults are DATA rather than
## difficulty settings: the doors stick, it runs one past on a long
## trip, it will not hear the sixth unless asked twice, and it thinks
## about it before it moves. Every one of those is a thing a real lift
## in a building like this does, and every one is a rule the player can
## learn and work around. That is the whole game: not reacting faster,
## but knowing your machine.
##
## NO CAMERA, NO INPUT, NO FRAME. tick(delta) advances everything and
## the whole shift can be run headless in milliseconds.

const DATA := "res://data/otis.json"

enum Door { SHUT, OPENING, OPEN, SHUTTING }

var floors: Array = []
var car: Dictionary = {}
var rules: Dictionary = {}
var quirks: Array = []
var riders_pool: Array = []

## Live state.
var at := 1.0                    # the car, in floors, fractional while moving
var target := 1                  # where it is going
var door: int = Door.SHUT
var door_t := 0.0
var waiting: Array = []          # [{who, from, to, patience, left}]
var aboard: Array = []           # [{who, to}]
var delivered := 0
var gave_up := 0
var score := 0
var elapsed := 0.0
var log_lines: Array = []
var running := false

## New calls arriving on their own. Off makes the car answer only the
## people already waiting — which is how a single behaviour gets pinned
## down in a test, and how a first-run tutorial would want it.
var calls_enabled := true

var _move_delay := 0.0
var _asked: Dictionary = {}      # floor -> times asked (for the deaf sixth)
var _overshot := false
var _over_goal := -1.0           # set once per trip, in call_to
var _next_call := 0.0
var _rng := RandomNumberGenerator.new()
var _active: Array = []          # quirk ids in play this shift


func load_data() -> bool:
	var f := FileAccess.open(DATA, FileAccess.READ)
	if f == null:
		push_warning("otis: no data at " + DATA)
		return false
	var d: Variant = JSON.parse_string(f.get_as_text())
	if typeof(d) != TYPE_DICTIONARY:
		push_error("otis: unparseable data")
		return false
	floors = d.get("floors", [])
	car = d.get("car", {})
	rules = d.get("rules", {})
	quirks = d.get("quirks", [])
	riders_pool = d.get("riders", [])
	return floors.size() > 0 and riders_pool.size() > 0


func quirk(id: String) -> Dictionary:
	for q in quirks:
		if str(q.get("id", "")) == id:
			return q
	return {}


func has_quirk(id: String) -> bool:
	return _active.has(id)


## `with_quirks` null means the car as it really is — everything wrong
## with it at once. An ARRAY means exactly those, and an EMPTY array
## means a sound car. That distinction matters: it is how each fault can
## be pinned down on its own, and coding the empty array as "all" (which
## it was) makes every clean-car baseline silently run with every fault
## switched on.
func start(seed_value := 0, with_quirks = null) -> void:
	if seed_value != 0:
		_rng.seed = seed_value
	else:
		_rng.randomize()
	_active = []
	if with_quirks == null:
		for q in quirks:
			_active.append(str(q.get("id", "")))
	else:
		_active = (with_quirks as Array).duplicate()
	at = float(car.get("start_floor", 1))
	target = int(at)
	door = Door.SHUT
	door_t = 0.0
	waiting = []
	aboard = []
	delivered = 0
	gave_up = 0
	score = 0
	elapsed = 0.0
	log_lines = []
	_asked = {}
	_overshot = false
	_over_goal = -1.0
	_move_delay = 0.0
	_next_call = 0.0
	running = true


func top() -> int:
	return floors.size() - 1


func label_of(i: int) -> String:
	if i < 0 or i >= floors.size():
		return "?"
	return str(floors[i].get("label", str(i)))


## Ask the car for a floor. Returns whether it took the request — the
## sixth needs asking twice and says so.
func call_to(f: int) -> bool:
	if not running or f < 0 or f > top():
		return false
	var deaf := quirk("deaf")
	if has_quirk("deaf") and f == int(deaf.get("floor", -1)):
		_asked[f] = int(_asked.get(f, 0)) + 1
		if int(_asked[f]) < 2:
			log_lines.append("the car does not hear %s" % label_of(f))
			return false
		_asked[f] = 0
	if f != int(round(at)) or door != Door.SHUT:
		_move_delay = float(quirk("slow_start").get("delay", 0.0)) \
				if has_quirk("slow_start") else 0.0
	target = f
	_overshot = false
	# WHETHER IT RUNS PAST IS DECIDED ONCE, HERE. Re-deciding it every
	# tick against the remaining distance cancels the overshoot the
	# moment the car gets within four floors of the target — which is
	# always, eventually, so it never overshot at all.
	_over_goal = -1.0
	var over := quirk("overshoot")
	if has_quirk("overshoot") \
			and absf(float(f) - at) >= float(over.get("floors", 4)):
		var dir: float = signf(float(f) - at)
		var past: float = clampf(float(f) + dir, 0.0, float(top()))
		if absf(past - float(f)) > 0.01:
			_over_goal = past
	return true


func tick(delta: float) -> void:
	if not running:
		return
	elapsed += delta
	_calls(delta)
	_patience(delta)
	_doors(delta)
	_move(delta)
	if elapsed >= float(rules.get("shift_seconds", 180.0)):
		running = false
		log_lines.append("shift over")


## Somebody presses a button somewhere.
func _calls(delta: float) -> void:
	if not calls_enabled:
		return
	_next_call -= delta
	if _next_call > 0.0:
		return
	var gap: Array = rules.get("call_every", [7.0, 15.0])
	_next_call = _rng.randf_range(float(gap[0]), float(gap[1]))
	if waiting.size() >= 6:
		return                       # the landing is full; give it a rest
	var r: Dictionary = riders_pool[_rng.randi() % riders_pool.size()]
	var home := int(r.get("home", 1))
	# Half of them are going home, half are leaving it. Nobody in this
	# building rides the lift for fun.
	var from := home
	var to := 1
	if _rng.randf() < 0.5:
		from = 1
		to = home
	if from == to:
		to = 0 if from != 0 else top()
	waiting.append({"who": str(r.get("who", "somebody")),
		"from": from, "to": to,
		"patience": float(rules.get("patience", 26.0)),
		"note": str(r.get("note", ""))})


func _patience(delta: float) -> void:
	var out: Array = []
	for w in waiting:
		w["patience"] = float(w["patience"]) - delta
		if float(w["patience"]) <= 0.0:
			out.append(w)
	for w in out:
		waiting.erase(w)
		gave_up += 1
		log_lines.append("%s takes the stairs" % str(w["who"]))


func _doors(delta: float) -> void:
	if door == Door.SHUT:
		return
	door_t -= delta
	if door_t > 0.0:
		return
	match door:
		Door.OPENING:
			door = Door.OPEN
			_exchange()
			door_t = float(car.get("door_open_seconds", 2.2))
		Door.OPEN:
			door = Door.SHUTTING
			door_t = 0.6
		Door.SHUTTING:
			door = Door.SHUT


## Who gets off, who gets on.
func _exchange() -> void:
	var here := int(round(at))
	var off: Array = []
	for a in aboard:
		if int(a["to"]) == here:
			off.append(a)
	for a in off:
		aboard.erase(a)
		delivered += 1
		var pts := int(rules.get("delivered", 2))
		# Delivered with patience to spare is worth more: the game is
		# about keeping people happy, not merely moving them.
		if float(a.get("spare", 0.0)) > float(rules.get(
				"on_time_above", 0.5)):
			pts += int(rules.get("on_time_bonus", 1))
		score += pts
		log_lines.append("%s off at %s  +%d"
				% [str(a["who"]), label_of(here), pts])
	var cap := int(car.get("capacity", 4))
	var boarding: Array = []
	for w in waiting:
		if aboard.size() + boarding.size() >= cap:
			break
		if int(w["from"]) == here:
			boarding.append(w)
	for w in boarding:
		waiting.erase(w)
		aboard.append({"who": str(w["who"]), "to": int(w["to"]),
			"spare": float(w["patience"])
					/ maxf(1.0, float(rules.get("patience", 26.0)))})
		log_lines.append("%s aboard for %s"
				% [str(w["who"]), label_of(int(w["to"]))])


func _move(delta: float) -> void:
	if door != Door.SHUT:
		return
	if _move_delay > 0.0:
		_move_delay -= delta
		return
	# Where it is heading THIS instant: one past the target if this trip
	# was long enough to earn an overshoot and it has not happened yet.
	var goal := float(target)
	if _over_goal >= 0.0 and not _overshot:
		goal = _over_goal
	if absf(goal - at) < 0.01:
		if not _overshot and absf(float(target) - at) > 0.01:
			# It went past; now it comes back.
			_overshot = true
			log_lines.append("it runs past %s" % label_of(target))
			return
		at = float(target)
		if _needs_stop():
			door = Door.OPENING
			door_t = float(car.get("door_open_seconds", 2.2)) * 0.35
			if has_quirk("sticks"):
				door_t += float(quirk("sticks").get("door_extra", 1.6))
		return
	var speed := 1.0 / maxf(0.2, float(car.get("seconds_per_floor", 1.35)))
	at = move_toward(at, goal, speed * delta)


## Only open where there is a reason to.
func _needs_stop() -> bool:
	var here := int(round(at))
	for a in aboard:
		if int(a["to"]) == here:
			return true
	for w in waiting:
		if int(w["from"]) == here:
			return true
	return false


func moving() -> bool:
	return door == Door.SHUT and absf(float(target) - at) > 0.01


func summary() -> String:
	return "%d delivered, %d took the stairs, %d points" % [
		delivered, gave_up, score]
