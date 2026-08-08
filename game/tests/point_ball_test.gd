extends Node
## Does Point Ball behave like a table, and does it score like the game?
##
## This is the test that could not be replaced by looking at it. Nobody
## can eyeball whether a cushion is elastic, whether two balls exchange
## momentum along the line of centres, or whether a fast ball tunnels
## through a rail — and all three are silent when wrong. A ball that
## leaks energy just feels "heavy"; a ball that tunnels only does it
## sometimes.
##
## So: physics first, then the rules that sit on it, then a whole game
## played out by two opponents to prove it terminates and scores.
##
## Runs headless. PointBall.resolve() steps a shot to completion with no
## frame loop, which is why a full game costs milliseconds here.

var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	_run()


## A table with nothing on it but the cue, for isolating physics.
func _bare() -> PointBall:
	var t := PointBall.new()
	t.start([{"name": "a"}, {"name": "b"}])
	for i in range(1, t.balls.size()):
		t.balls[i]["in"] = true
	return t


func _run() -> void:
	# ---- THE TABLE ---------------------------------------------------
	var t := PointBall.new()
	t.start([{"name": "you"}, {"name": "Cam", "npc": true}])
	_check("fourteen object balls, the 8 having walked",
			t.object_balls_left() == PointBall.OBJECT_BALLS)
	_check("six pockets", t.pockets.size() == 6)
	var overlapping := false
	for i in t.balls.size():
		for j in range(i + 1, t.balls.size()):
			if (t.balls[i]["p"] as Vector2).distance_to(
					t.balls[j]["p"]) < PointBall.R * 1.98:
				overlapping = true
	_check("the rack does not overlap itself", not overlapping)

	# ---- PHYSICS -----------------------------------------------------
	# A ball must STOP. Damping-style friction creeps forever and the
	# table never settles, which hangs the turn rather than ending it.
	var b := _bare()
	b.shoot(Vector2(1, 0), 0.5)
	b.resolve()
	_check("a struck ball comes to rest",
			(b.cue()["v"] as Vector2).length() == 0.0)

	# It must also stay on the table.
	b = _bare()
	b.shoot(Vector2(1, 0.37).normalized(), 1.0)
	b.resolve()
	var p: Vector2 = b.cue()["p"]
	_check("and stays on the cloth (%.2f, %.2f)" % [p.x, p.y],
			absf(p.x) <= PointBall.W * 0.5 + 0.001
			and absf(p.y) <= PointBall.H * 0.5 + 0.001)

	# Cushions must be counted, and must be elastic-ish rather than
	# absorbing everything.
	b = _bare()
	b.balls[0]["p"] = Vector2(0.0, 0.0)
	b.shoot(Vector2(1, 0), 1.0)
	b.resolve()
	_check("a hard shot finds cushions (%d)" % b.last_cushions,
			b.last_cushions >= 1)

	# Two balls exchange momentum: a full-ball hit sends the object away
	# and stops the cue near dead. Get the sign wrong and they pass
	# through each other, which looks like nothing at all.
	var c := PointBall.new()
	c.start([{"name": "a"}, {"name": "b"}])
	for i in range(2, c.balls.size()):
		c.balls[i]["in"] = true
	c.balls[0]["p"] = Vector2(-0.40, 0.0)
	c.balls[1]["p"] = Vector2(0.0, 0.0)
	c.balls[1]["in"] = false
	c.shoot(Vector2(1, 0), 0.55)
	# Measured AT THE MOMENT OF CONTACT, not at the end of the shot.
	# This table is 1.76 m long with elastic rails, so a well-struck
	# ball crosses it several times and can come to rest anywhere at
	# all — including back where it started. Asserting on the final
	# position tests the bounce pattern; asserting on the impulse tests
	# the collision, which is the thing that can actually be wrong.
	var obj_v := 0.0
	var cue_v := 0.0
	for _i in 900:
		c.step(1.0 / 60.0)
		var ov := (c.balls[1]["v"] as Vector2).length()
		if ov > 0.0:
			obj_v = ov
			cue_v = (c.balls[0]["v"] as Vector2).length()
			break
	_check("a full hit drives the object ball on (%.2f m/s)" % obj_v,
			obj_v > 1.0)
	_check("and stops the cue nearly dead (%.2f m/s)" % cue_v,
			cue_v < obj_v * 0.35)
	c.resolve()

	# ---- POTTING AND SCORING ----------------------------------------
	# A ball on the lip of a pocket, nudged in.
	var d := PointBall.new()
	d.start([{"name": "you"}, {"name": "Cam", "npc": true}])
	for i in range(2, d.balls.size()):
		d.balls[i]["in"] = true
	var corner: Vector2 = d.pockets[2]              # +x, -y
	d.balls[1]["in"] = false
	d.balls[1]["p"] = corner - Vector2(0.10, -0.06).normalized() * 0.09
	d.balls[0]["p"] = d.balls[1]["p"] - Vector2(0.10, -0.06).normalized() * 0.22
	var before: int = int(d.players[0]["score"])
	d.shoot((d.balls[1]["p"] - d.balls[0]["p"]).normalized(), 0.45)
	d.resolve()
	_check("potting a ball scores a point (%d -> %d)"
			% [before, int(d.players[0]["score"])],
			int(d.players[0]["score"]) > before)

	# THE RULE THAT MAKES THIS GAME ITS OWN GAME: the cue ball counts.
	var e := _bare()
	e.balls[0]["p"] = e.pockets[0] + Vector2(0.14, 0.14)
	e.shoot((e.pockets[0] - e.balls[0]["p"]).normalized(), 0.30)
	e.resolve()
	_check("the cue ball in a pocket is a POINT, not a foul",
			int(e.players[0]["score"]) >= 1)
	_check("and it comes back on the table",
			not e.cue()["in"])

	# ---- TURN ORDER --------------------------------------------------
	var f := PointBall.new()
	f.start([{"name": "you"}, {"name": "Cam", "npc": true}])
	_check("you are up first", str(f.current()["name"]) == "you")
	f.shoot(Vector2(1, 0.05).normalized(), 0.7)
	f.resolve()
	_check("one shot each, potted or not",
			str(f.current()["name"]) == "Cam")

	# ---- THE BONUS ---------------------------------------------------
	var g := PointBall.new()
	g.start([{"name": "you"}, {"name": "Cam", "npc": true}])
	for i in range(1, g.balls.size()):
		g.balls[i]["in"] = true
	g.phase = PointBall.Phase.BONUS
	g.balls[0]["p"] = Vector2(0.0, 0.0)
	# Across the table into a far pocket, off cushions on the way.
	g.shoot(Vector2(0.62, 1.0).normalized(), 1.0)
	g.resolve()
	if g.cue()["in"]:
		_check("the bonus pays for the cushions it took (%d for %d)"
				% [g.last_cushions, g.last_points],
				g.last_points >= maxi(1, g.last_cushions))
		_check("and that ends it", g.phase == PointBall.Phase.OVER)
	else:
		_check("a bonus that misses passes the shot on",
				g.phase == PointBall.Phase.BONUS
				and str(g.current()["name"]) == "Cam")

	# ---- A WHOLE GAME ------------------------------------------------
	# Two opponents playing it out. The claim is that it TERMINATES —
	# every object ball can actually be sunk, and the bonus can actually
	# be made — which is not obvious for a table with friction on it.
	var rng := RandomNumberGenerator.new()
	rng.seed = 20260808
	var h := PointBall.new()
	h.start([{"name": "you", "npc": true}, {"name": "Cam", "npc": true}])
	var guard := 0
	while h.phase != PointBall.Phase.OVER and guard < 600:
		var shot := PointBallAI.choose(h, "steady", rng)
		h.shoot(shot["dir"], shot["power"])
		h.resolve()
		guard += 1
	_check("two opponents play it to a finish in %d shots" % guard,
			h.phase == PointBall.Phase.OVER)
	_check("every ball is off the table",
			h.object_balls_left() == 0 and h.cue()["in"])
	var total := 0
	for pl in h.players:
		total += int(pl["score"])
	_check("everything that dropped was scored (%d points across %d)"
			% [total, h.players.size()], total >= PointBall.OBJECT_BALLS)
	print("      final: %s" % [h.log_lines.slice(
			maxi(0, h.log_lines.size() - 3))])

	print("[POINTBALL] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
