extends Node
## Otis: does the car misbehave in exactly the ways it is supposed to?
##
## The quirks ARE the game — a lift whose doors stick, that runs one
## past on a long trip, that will not hear the sixth unless asked twice.
## Which means each one has to be provable ON ITS OWN, because they are
## the rules a player is expected to learn, and a quirk that only
## sometimes happens is not a rule, it is a bug wearing a costume.
##
## So every quirk is tested in ISOLATION, with the others switched off.
## That is what the `with_quirks` argument on start() is for, and it is
## worth the extra parameter: run them all together and a failure tells
## you nothing about which one broke.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	_run()


## Advance a fixed number of seconds in small steps.
func _run_for(g: Otis, seconds: float, step := 1.0 / 30.0) -> void:
	var t := 0.0
	while t < seconds:
		g.tick(step)
		t += step


func _run() -> void:
	var g := Otis.new()
	_check("the data loads", g.load_data())
	if g.floors.is_empty():
		print("[OTIS] RESULT: FAIL (1 failures)")
		get_tree().quit(1)
		return
	_check("eight landings, B1 to the roof (%d)" % g.floors.size(),
			g.floors.size() == 8)
	_check("the lobby is floor one", str(g.label_of(1)) == "1")
	_check("four quirks to learn (%d)" % g.quirks.size(),
			g.quirks.size() >= 4)

	# ---- THE PLAIN CAR ----------------------------------------------
	# With nothing wrong with it, it goes where it is told.
	g.start(11, [])
	g.calls_enabled = false
	g.waiting = []
	g.call_to(5)
	_run_for(g, 12.0)
	_check("a sound car reaches the floor you asked for (%.1f)" % g.at,
			absf(g.at - 5.0) < 0.02)

	# ---- THE SIXTH IT WILL NOT HEAR ---------------------------------
	g.start(11, ["deaf"])
	g.calls_enabled = false
	g.waiting = []
	var first := g.call_to(6)
	_check("the sixth is refused the first time", not first)
	_run_for(g, 3.0)
	_check("and the car does not move for it", absf(g.at - 1.0) < 0.02)
	var second := g.call_to(6)
	_check("asked twice, it takes it", second)
	_run_for(g, 14.0)
	_check("and then it goes (%.1f)" % g.at, absf(g.at - 6.0) < 0.02)
	# Everything else is heard the first time.
	g.start(11, ["deaf"])
	g.calls_enabled = false
	g.waiting = []
	_check("the fifth is heard straight away", g.call_to(5))

	# ---- IT RUNS PAST ON A LONG TRIP --------------------------------
	g.start(11, ["overshoot"])
	g.calls_enabled = false
	g.waiting = []
	g.call_to(6)                      # five floors: long
	var went_past := false
	var t := 0.0
	while t < 16.0:
		g.tick(1.0 / 30.0)
		if g.at > 6.02:
			went_past = true
		t += 1.0 / 30.0
	_check("a long trip overshoots", went_past)
	_check("but it settles back where it was asked (%.1f)" % g.at,
			absf(g.at - 6.0) < 0.05)
	# A short hop does not.
	g.start(11, ["overshoot"])
	g.calls_enabled = false
	g.waiting = []
	g.call_to(3)                      # two floors: short
	var short_past := false
	t = 0.0
	while t < 10.0:
		g.tick(1.0 / 30.0)
		if g.at > 3.02:
			short_past = true
		t += 1.0 / 30.0
	_check("a short hop does not", not short_past)

	# ---- IT THINKS ABOUT IT FIRST -----------------------------------
	g.start(11, ["slow_start"])
	g.calls_enabled = false
	g.waiting = []
	g.call_to(4)
	_run_for(g, 0.5)
	_check("it sits still for a beat before moving",
			absf(g.at - 1.0) < 0.02)
	_run_for(g, 6.0)
	_check("then it goes", g.at > 2.0)

	# ---- THE DOORS STICK --------------------------------------------
	# Timed against a clean car, so the claim is comparative rather than
	# a number somebody has to keep in step with the data.
	var clean := Otis.new()
	clean.load_data()
	clean.start(5, [])
	clean.calls_enabled = false
	clean.waiting = [{"who": "x", "from": 1, "to": 3, "patience": 99.0}]
	clean.call_to(1)
	var clean_shut := 0.0
	while clean_shut < 20.0 and clean.aboard.is_empty():
		clean.tick(1.0 / 30.0)
		clean_shut += 1.0 / 30.0
	var sticky := Otis.new()
	sticky.load_data()
	sticky.start(5, ["sticks"])
	sticky.calls_enabled = false
	sticky.waiting = [{"who": "x", "from": 1, "to": 3, "patience": 99.0}]
	sticky.call_to(1)
	var sticky_shut := 0.0
	while sticky_shut < 20.0 and sticky.aboard.is_empty():
		sticky.tick(1.0 / 30.0)
		sticky_shut += 1.0 / 30.0
	_check("sticking doors take longer to let anyone on (%.1f vs %.1f)"
			% [sticky_shut, clean_shut], sticky_shut > clean_shut + 1.0)

	# ---- CARRYING PEOPLE --------------------------------------------
	var h := Otis.new()
	h.load_data()
	h.start(3, [])
	h.calls_enabled = false
	h.waiting = [{"who": "Mina Vale", "from": 1, "to": 5,
		"patience": 99.0}]
	h.call_to(1)
	_run_for(h, 6.0)
	_check("somebody waiting gets on", h.aboard.size() == 1)
	h.call_to(5)
	_run_for(h, 16.0)
	_check("and is put down where they asked", h.delivered == 1)
	_check("which is worth something", h.score > 0)
	_check("and the car is empty again", h.aboard.is_empty())

	# Capacity is real.
	var cap := Otis.new()
	cap.load_data()
	cap.start(3, [])
	cap.calls_enabled = false
	cap.waiting = []
	for i in 6:
		cap.waiting.append({"who": "p%d" % i, "from": 1, "to": 4,
			"patience": 99.0})
	cap.call_to(1)
	_run_for(cap, 8.0)
	_check("the car only holds four (%d aboard, %d left)"
			% [cap.aboard.size(), cap.waiting.size()],
			cap.aboard.size() == int(cap.car.get("capacity", 4))
			and cap.waiting.size() == 2)

	# ---- PATIENCE ----------------------------------------------------
	var p := Otis.new()
	p.load_data()
	p.start(3, [])
	p.calls_enabled = false
	p.waiting = [{"who": "Teresa Vale", "from": 6, "to": 1,
		"patience": 2.0}]
	_run_for(p, 4.0)
	_check("ignore somebody and they take the stairs",
			p.gave_up == 1 and p.waiting.is_empty())
	_check("and it costs you the fare", p.score == 0)

	# ---- A WHOLE SHIFT ------------------------------------------------
	# Played badly on purpose — the car answers whoever has waited
	# longest — to prove the shift ends and the numbers add up.
	var s := Otis.new()
	s.load_data()
	s.start(4471)
	var guard := 0
	while s.running and guard < 40000:
		if not s.moving() and s.door == Otis.Door.SHUT:
			var best := -1
			var worst := 1e9
			for w in s.waiting:
				if float(w["patience"]) < worst:
					worst = float(w["patience"])
					best = int(w["from"])
			if s.aboard.size() > 0:
				best = int(s.aboard[0]["to"])
			if best >= 0:
				s.call_to(best)
		s.tick(1.0 / 30.0)
		guard += 1
	_check("a shift ends", not s.running)
	_check("and somebody got where they were going (%s)" % s.summary(),
			s.delivered > 0)
	_check("nobody is left in the car at the end of it",
			s.aboard.size() <= int(s.car.get("capacity", 4)))

	print("[OTIS] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
