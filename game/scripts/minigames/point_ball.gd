class_name PointBall
extends RefCounted
## POINT BALL — the game they play on the Harukiya's table since
## somebody walked off with the 8.
##
## Fourteen object balls and a cue. Players take ONE shot each, turn
## about, and anything that drops is a point — including the cue ball,
## which in any other game is a foul and here is just a point. You keep
## going until every object ball is gone.
##
## Then the BONUS BALL: with the table clear, the last thing to sink is
## the cue itself, and every cushion it touches on the way down is
## another point. So the game ends on the one shot where hitting nothing
## is worth everything, which is a joke the table earns by having had
## its 8 ball stolen.
##
## THE PHYSICS AND THE RULES LIVE HERE AND NOTHING ELSE DOES. No camera,
## no input, no frame — step() takes a delta and the table resolves. A
## shot can therefore be simulated to completion in a headless test in a
## few milliseconds, which is the only way a game like this can be
## trusted: you cannot eyeball whether a cushion is elastic.

const W := 1.76                  # playing surface, metres
const H := 1.06
const R := 0.0285                # ball radius (57 mm ball)
const POCKET_R := 0.055
const OBJECT_BALLS := 14         # fifteen minus the one that walked

const FRICTION := 0.42           # m/s^2, cloth
const CUSHION_BOUNCE := 0.78
const BALL_BOUNCE := 0.95
const STOP_BELOW := 0.020        # m/s, below which a ball has stopped
const MAX_POWER := 3.4           # m/s off the cue tip

enum Phase { OPEN, BONUS, OVER }

## Balls are dictionaries so the table can be inspected in a test
## without reaching through a node. Index 0 is always the cue.
var balls: Array = []
var pockets: Array[Vector2] = []
var phase: int = Phase.OPEN
var players: Array = []          # [{name, score, npc}]
var turn := 0
var shots := 0

## Set while a shot is resolving, read by the UI and the tests.
var moving := false
var last_potted: Array = []      # ball indices potted by the last shot
var last_cushions := 0           # cue-ball cushion contacts, last shot
var last_points := 0
var log_lines: Array = []


func _init() -> void:
	pockets = [
		Vector2(-W * 0.5, -H * 0.5), Vector2(0.0, -H * 0.5),
		Vector2(W * 0.5, -H * 0.5), Vector2(-W * 0.5, H * 0.5),
		Vector2(0.0, H * 0.5), Vector2(W * 0.5, H * 0.5),
	]


func start(names: Array) -> void:
	players = []
	for n in names:
		players.append({"name": str(n.get("name", "?")),
			"score": 0, "npc": bool(n.get("npc", false))})
	turn = 0
	shots = 0
	phase = Phase.OPEN
	log_lines = []
	_rack()


func _rack() -> void:
	balls = []
	# The cue, on the baulk line.
	balls.append({"p": Vector2(-W * 0.25, 0.0), "v": Vector2.ZERO,
		"in": false, "cue": true})
	# A PROPER TRIANGLE WITH A HOLE IN IT. Five rows of 1-2-3-4-5 is a
	# real rack; the 8 lives in the middle of the third row, so leaving
	# that one slot empty is literally the fiction — you can see where
	# it should be.
	#
	# (Racking 1-2-3-4-4 instead does not work: two consecutive rows of
	# the same size line up exactly, so neighbouring balls sit one row
	# gap apart, which is less than a diameter. They start overlapping.)
	var apex := Vector2(W * 0.22, 0.0)
	var dx := R * 1.76           # row pitch, ~sqrt(3) * R with air
	var dy := R * 2.06           # along-row pitch, just over a diameter
	var rows := [1, 2, 3, 4, 5]
	for row in rows.size():
		var n: int = rows[row]
		for i in n:
			if row == 2 and i == 1:
				continue         # the 8 ball. Somebody has it.
			var off := (i - (n - 1) * 0.5) * dy
			balls.append({"p": apex + Vector2(row * dx, off),
				"v": Vector2.ZERO, "in": false, "cue": false})


func cue() -> Dictionary:
	return balls[0]


func object_balls_left() -> int:
	var n := 0
	for i in range(1, balls.size()):
		if not balls[i]["in"]:
			n += 1
	return n


func current() -> Dictionary:
	if players.is_empty():
		return {}
	return players[turn % players.size()]


## Strike the cue ball. `dir` is a unit-ish aim, `power` is 0..1.
func shoot(dir: Vector2, power: float) -> void:
	if phase == Phase.OVER or moving:
		return
	var c := cue()
	if c["in"]:
		_respot()
		c = cue()
	c["v"] = dir.normalized() * clampf(power, 0.05, 1.0) * MAX_POWER
	moving = true
	last_potted = []
	last_cushions = 0
	last_points = 0
	shots += 1


## Advance the table. Returns true while anything is still rolling.
func step(delta: float) -> bool:
	if not moving:
		return false
	# Fixed sub-steps: a 3.4 m/s ball crosses its own diameter in 17 ms,
	# so a frame-sized step would let it tunnel through a cushion or
	# straight past another ball.
	var sub := 8
	var h := delta / sub
	for _s in sub:
		_integrate(h)
	if not _anything_moving():
		moving = false
		_settle()
		return false
	return true


func _integrate(h: float) -> void:
	for b in balls:
		if b["in"]:
			continue
		var v: Vector2 = b["v"]
		if v.length() <= 0.0:
			continue
		# Rolling friction: constant deceleration, not damping, because
		# a ball on cloth slows at a steady rate and stops dead rather
		# than creeping forever.
		var sp := v.length()
		sp = maxf(0.0, sp - FRICTION * h)
		if sp < STOP_BELOW:
			sp = 0.0
		b["v"] = v.normalized() * sp
		b["p"] = (b["p"] as Vector2) + (b["v"] as Vector2) * h
	_cushions()
	_collisions()
	_pockets()


func _cushions() -> void:
	var lx := W * 0.5 - R
	var ly := H * 0.5 - R
	for b in balls:
		if b["in"]:
			continue
		var p: Vector2 = b["p"]
		var v: Vector2 = b["v"]
		var hit := false
		if p.x < -lx:
			p.x = -lx
			v.x = absf(v.x) * CUSHION_BOUNCE
			hit = true
		elif p.x > lx:
			p.x = lx
			v.x = -absf(v.x) * CUSHION_BOUNCE
			hit = true
		if p.y < -ly:
			p.y = -ly
			v.y = absf(v.y) * CUSHION_BOUNCE
			hit = true
		elif p.y > ly:
			p.y = ly
			v.y = -absf(v.y) * CUSHION_BOUNCE
			hit = true
		if hit:
			b["p"] = p
			b["v"] = v
			# Only the CUE's cushions are worth counting: the bonus is
			# about how long you can keep it alive before it drops.
			if b["cue"]:
				last_cushions += 1


func _collisions() -> void:
	for i in balls.size():
		if balls[i]["in"]:
			continue
		for j in range(i + 1, balls.size()):
			if balls[j]["in"]:
				continue
			var a: Vector2 = balls[i]["p"]
			var b: Vector2 = balls[j]["p"]
			var d := b - a
			var dist := d.length()
			if dist >= R * 2.0 or dist <= 0.00001:
				continue
			var n := d / dist
			# Separate, then swap the velocity along the line of
			# centres — equal masses, so they exchange it outright.
			var overlap := R * 2.0 - dist
			balls[i]["p"] = a - n * overlap * 0.5
			balls[j]["p"] = b + n * overlap * 0.5
			var va: Vector2 = balls[i]["v"]
			var vb: Vector2 = balls[j]["v"]
			var an := va.dot(n)
			var bn := vb.dot(n)
			if an - bn <= 0.0:
				continue                 # already separating
			var imp := (an - bn) * BALL_BOUNCE
			balls[i]["v"] = va - n * imp
			balls[j]["v"] = vb + n * imp


func _pockets() -> void:
	for i in balls.size():
		var b: Dictionary = balls[i]
		if b["in"]:
			continue
		for pk in pockets:
			if (b["p"] as Vector2).distance_to(pk) <= POCKET_R:
				b["in"] = true
				b["v"] = Vector2.ZERO
				last_potted.append(i)
				break


## Everything has stopped: score the shot and hand the table over.
func _settle() -> void:
	var me: Dictionary = current()
	var pts := 0
	if phase == Phase.BONUS:
		# The bonus shot only scores if the cue actually drops. Leave it
		# on the table and the next player gets their go at it.
		if cue()["in"]:
			pts = maxi(1, last_cushions)
			me["score"] = int(me["score"]) + pts
			log_lines.append("%s sinks the bonus off %d cushion%s  +%d"
					% [me["name"], last_cushions,
					"" if last_cushions == 1 else "s", pts])
			phase = Phase.OVER
			last_points = pts
			return
		log_lines.append("%s leaves it on the table" % me["name"])
		last_points = 0
		_next()
		return

	# Open play: everything that dropped is a point, cue included.
	pts = last_potted.size()
	me["score"] = int(me["score"]) + pts
	last_points = pts
	if pts > 0:
		log_lines.append("%s pots %d  +%d" % [me["name"], pts, pts])
	else:
		log_lines.append("%s pots nothing" % me["name"])
	if cue()["in"]:
		_respot()
	if object_balls_left() == 0:
		phase = Phase.BONUS
		log_lines.append("table's clear — bonus ball")
	_next()


func _next() -> void:
	turn += 1


## Put the cue back on the baulk line, nudged clear if that spot is
## occupied.
func _respot() -> void:
	var c := cue()
	c["in"] = false
	c["v"] = Vector2.ZERO
	var spot := Vector2(-W * 0.25, 0.0)
	for _try in 24:
		var clear := true
		for i in range(1, balls.size()):
			if balls[i]["in"]:
				continue
			if (balls[i]["p"] as Vector2).distance_to(spot) < R * 2.2:
				clear = false
				break
		if clear:
			break
		spot += Vector2(0.0, R * 2.4)
		if spot.y > H * 0.5 - R:
			spot = Vector2(spot.x - R * 2.4, -H * 0.5 + R)
	c["p"] = spot


func _anything_moving() -> bool:
	for b in balls:
		if not b["in"] and (b["v"] as Vector2).length() > 0.0:
			return true
	return false


## Run a shot to completion without a frame loop. Tests use this; so
## does the NPC when it wants to know what a shot would do.
func resolve(max_seconds := 20.0) -> void:
	var t := 0.0
	while moving and t < max_seconds:
		step(1.0 / 60.0)
		t += 1.0 / 60.0
	if moving:
		# Pathological: stop everything rather than hang the table.
		for b in balls:
			b["v"] = Vector2.ZERO
		moving = false
		_settle()


func leader() -> Dictionary:
	var best: Dictionary = {}
	for p in players:
		if best.is_empty() or int(p["score"]) > int(best["score"]):
			best = p
	return best
