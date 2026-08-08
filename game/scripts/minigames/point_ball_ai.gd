class_name PointBallAI
extends RefCounted
## Somebody to play against.
##
## It aims the way a person in a bar aims: find the ball with the
## friendliest line to a pocket, work out where the cue has to strike it
## (the ghost-ball point), hit that, and miss by a bit. The miss is the
## whole character of an opponent — a solver that never misses is not an
## opponent, it is a wall — so `skill` is an angular error in degrees
## and nothing else about the aim changes.
##
## In the BONUS phase it wants the opposite of a clean pot: the cue has
## to bank around and drop, and every cushion first is a point. So it
## deliberately aims off the pocket, into a cushion, and lets the table
## do the rest. It is not good at this. Neither is anyone.

## Degrees of error at the moment of striking. A tenth of a degree over
## a metre is about 2 mm at the object ball, so these are large numbers
## on purpose.
const SKILL := {"steady": 1.4, "loose": 3.2, "gone": 6.5}


static func choose(table: PointBall, skill := "loose",
		rng: RandomNumberGenerator = null) -> Dictionary:
	if rng == null:
		rng = RandomNumberGenerator.new()
		rng.randomize()
	var err: float = float(SKILL.get(skill, 3.2))
	if table.phase == PointBall.Phase.BONUS:
		return _bonus(table, err, rng)
	return _pot(table, err, rng)


## The best straight pot available, scored by how little the cue has to
## turn the object ball — a thin cut is a bad bet and it knows it.
static func _pot(table: PointBall, err: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var c: Vector2 = table.cue()["p"]
	var best := {}
	var best_score := -1.0
	for i in range(1, table.balls.size()):
		var b: Dictionary = table.balls[i]
		if b["in"]:
			continue
		var bp: Vector2 = b["p"]
		for pk in table.pockets:
			var to_pocket := (pk - bp)
			if to_pocket.length() < 0.001:
				continue
			var aim_at := bp - to_pocket.normalized() * PointBall.R * 2.0
			var to_ghost := aim_at - c
			if to_ghost.length() < 0.001:
				continue
			# The cut angle: 0 is a straight pot, 90 is impossible.
			var cut := rad_to_deg(to_ghost.normalized().angle_to(
					to_pocket.normalized()))
			if absf(cut) > 68.0:
				continue
			# Prefer straight, near, and a short run to the pocket.
			var score := (90.0 - absf(cut)) \
					- to_ghost.length() * 11.0 \
					- to_pocket.length() * 7.0
			if score > best_score:
				best_score = score
				best = {"dir": to_ghost.normalized(),
					"power": clampf(0.34 + to_ghost.length() * 0.30
							+ to_pocket.length() * 0.22, 0.30, 0.92)}
	if best.is_empty():
		# Nothing on. Roll at the pack and hope.
		var target := Vector2(PointBall.W * 0.25, 0.0)
		best = {"dir": (target - c).normalized(), "power": 0.62}
	best["dir"] = (best["dir"] as Vector2).rotated(
			deg_to_rad(rng.randfn(0.0, err)))
	return best


## Bonus: put the cue into cushions and then into a pocket. Aiming at a
## pocket off two rails is a real shot and it plays it badly on purpose.
static func _bonus(table: PointBall, err: float,
		rng: RandomNumberGenerator) -> Dictionary:
	var c: Vector2 = table.cue()["p"]
	# Pick the far pocket and aim at its mirror through a side cushion,
	# which is how a bank shot is aimed by eye.
	var pk: Vector2 = table.pockets[0]
	var far := 0.0
	for p in table.pockets:
		var d: float = c.distance_to(p)
		if d > far:
			far = d
			pk = p
	var wall := PointBall.H * 0.5 - PointBall.R
	var mirrored := Vector2(pk.x, (2.0 * wall * signf(pk.y)) - pk.y)
	var dir := (mirrored - c).normalized()
	dir = dir.rotated(deg_to_rad(rng.randfn(0.0, err * 1.4)))
	return {"dir": dir, "power": clampf(rng.randf_range(0.66, 0.94),
			0.5, 1.0)}
