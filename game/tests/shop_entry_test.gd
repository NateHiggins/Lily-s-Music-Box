extends Node
## Can the player actually GET INSIDE the two shops?
##
## RouteProbe sweeps a capsule and names what stops it, which is the
## right tool for finding a blocker — but a clear sweep is not the same
## claim as "a person can walk in". The sweep ignores gravity, steps,
## stair treads, the collide-and-slide the controller actually uses, and
## a door leaf that swings. Twice now this street has reported clear
## routes into shops nobody could enter.
##
## So this drives the REAL PlayerController with its real physics from
## the street, through the door, to a spot well inside, and asks where
## it ended up. The bar is the harder of the two: its floor is 2.87 m
## below the pavement and the way in is fifteen treads down a shaft
## 1.15 m wide.

var root: Node3D
var _fails := 0


func _check(label: String, ok: bool) -> void:
	print("  [%s] %s" % ["ok" if ok else "FAIL", label])
	if not ok:
		_fails += 1


func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.6).timeout
	await _run()


## Steer toward an XZ target until close enough or out of time.
func _goto(pl, target: Vector2, timeout: float) -> void:
	var t := 0.0
	while t < timeout:
		var pos := Vector2(pl.global_position.x, pl.global_position.z)
		if pos.distance_to(target) < 0.45:
			break
		var dir := (target - pos).normalized()
		pl.autopilot = Vector3(dir.x, 0, dir.y)
		await get_tree().create_timer(0.1).timeout
		t += 0.1
	pl.autopilot = Vector3.ZERO


func _place(pl, at: Vector3) -> void:
	pl.autopilot = Vector3.ZERO
	pl.velocity = Vector3.ZERO
	pl.global_position = at
	for i in 8:
		await get_tree().process_frame


## Stand a body-sized capsule just ahead of where the player stopped and
## say what is already there. Reasoning about which slab ends where has
## now produced three wrong answers on this doorway.
func _name_blocker(at: Vector3) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.524
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), at + Vector3(0, 0.80, 0))
	q.collide_with_areas = false
	var hits := root.get_viewport().find_world_3d().direct_space_state \
			.intersect_shape(q, 8)
	if hits.is_empty():
		print("        nothing occupies %v — the stop is a LEDGE or a"
				% at + " step, not a wall")
		return
	for h in hits:
		var c = h.collider
		var p = c.get_parent() if c else null
		print("        blocked by %s parent=%s"
				% [str(c.name), str(p.name) if p else "-"])


## Sweep a body-sized capsule along a line and say where it stops and on
## what. Same trick as RouteProbe, run here because the door has to be
## OPEN for the answer to mean anything.
func _sweep(from: Vector3, to: Vector3) -> void:
	var shape := CapsuleShape3D.new()
	shape.radius = 0.33
	shape.height = 1.524
	var q := PhysicsShapeQueryParameters3D.new()
	q.shape = shape
	q.transform = Transform3D(Basis(), from + Vector3(0, 0.79, 0))
	q.motion = to - from
	q.collide_with_areas = false
	var space := root.get_viewport().find_world_3d().direct_space_state
	var res := space.cast_motion(q)
	var frac: float = res[0] if res.size() > 0 else 1.0
	print("        sweep %v -> %v stopped at %d%%" % [from, to,
			int(frac * 100.0)])
	if frac >= 0.999:
		print("        ...the doorway itself is CLEAR; the walk is the"
				+ " thing at fault, not the world")
		return
	q.transform = Transform3D(Basis(),
			from + (to - from) * frac + Vector3(0, 0.79, 0))
	for h in space.intersect_shape(q, 6):
		var c = h.collider
		var p = c.get_parent() if c else null
		print("        on %s parent=%s"
				% [str(c.name), str(p.name) if p else "-"])


func _run() -> void:
	var pl = root.player

	# ---- THE BODEGA -------------------------------------------------
	# Stand on the pavement west of the door and walk in.
	await _place(pl, Vector3(15.0, 0.2, 12.55))
	await _goto(pl, Vector2(18.67, 12.30), 8.0)
	await _goto(pl, Vector2(18.67, 10.80), 8.0)
	await _goto(pl, Vector2(18.46, 8.50), 8.0)
	var p: Vector3 = pl.global_position
	print("      bodega: ended at %v" % p)
	# Inside means past the shopfront (z < 11.8) and within the shop's
	# own walls (x 15.5..19.3).
	_check("the player walked into the bodega",
			p.z < 11.6 and p.x > 15.4 and p.x < 19.4)
	_check("and got properly inside, not stuck in the doorway",
			p.z < 10.0)

	# ---- THE BAR ----------------------------------------------------
	var red = root.find_child("F01_BAR_RED_DOOR", true, false)
	_check("the red door exists", red != null)

	# The mouth of the stair, on the pavement in front of the shaft.
	await _place(pl, Vector3(4.875, 0.2, 27.60))
	await _goto(pl, Vector2(4.875, 29.40), 8.0)
	print("      bar: lobby at %v" % pl.global_position)
	_check("the player got through the street door",
			pl.global_position.z > 28.6)
	# Down fifteen treads. Steering straight at the vestibule and letting
	# gravity and the step logic do the descending.
	await _goto(pl, Vector2(4.875, 33.00), 12.0)
	await _goto(pl, Vector2(4.875, 34.60), 12.0)
	var b: Vector3 = pl.global_position
	print("      bar: ended at %v" % b)
	_check("the player descended the stair (y %.2f)" % b.y, b.y < -2.0)
	_check("and reached the vestibule at the bottom",
			b.z > 33.8 and b.x > 4.2 and b.x < 5.6)

	# ---- AND THROUGH THE RED DOOR INTO THE ROOM ---------------------
	# The vestibule is not the bar. The red door at the foot of the
	# stair is the last one, and it had the same hinge-at-centre fault
	# as the other three — so reaching the vestibule proved nothing
	# about getting in.
	#
	# Stand OUT of the swing before opening it. The leaf sweeps 0.88 m
	# about its hinge into a shaft 1.15 m wide, so anywhere near the
	# doorway is inside the arc, and an opening door correctly shoves a
	# body that is standing in it — which tells you nothing about
	# whether the doorway is passable.
	await _goto(pl, Vector2(5.15, 34.95), 8.0)
	if red:
		red.npc_set_open(true)
		await get_tree().create_timer(0.9).timeout
		print("      red door open=%s  node=%v" % [red.open,
				red.global_position])
		for c in red.get_children():
			if c is AnimatableBody3D:
				for s in c.get_children():
					if s is CollisionShape3D:
						print("        leaf shape at %v (box %v)"
								% [s.global_position,
								(s.shape as BoxShape3D).size])
	# Through the middle of the opening. It runs z 33.95..34.90 and a
	# body is 0.66 wide, so a waypoint even 15 cm off centre walks them
	# into the jamb — which looks exactly like a blocked door and is not
	# one.
	await _goto(pl, Vector2(4.60, 34.42), 8.0)
	await _goto(pl, Vector2(3.60, 34.42), 8.0)
	await _goto(pl, Vector2(2.60, 34.50), 10.0)
	var r: Vector3 = pl.global_position
	print("      bar room: ended at %v" % r)
	# THE REAL ASSERTION, on where WALKING got to — not on where a
	# teleport got to, which is a different and much weaker claim.
	_check("the player walked through the red door into the bar",
			r.x < 3.9 and r.y < -2.0)

	# Then, separately: can a body cross the room once inside? This
	# catches furniture placed across the lane, which is exactly what
	# was blocking it.
	await _place(pl, Vector3(3.40, -2.75, 34.42))
	for i in 20:
		await get_tree().process_frame
	var inside: Vector3 = pl.global_position
	print("      placed inside, settled at %v" % inside)
	_check("a body can stand inside the bar room",
			inside.x < 3.9 and inside.y < -2.0)
	await _goto(pl, Vector2(2.40, 34.60), 8.0)
	var across: Vector3 = pl.global_position
	print("      walked on to %v" % across)
	_check("and can cross the room rather than wedging in the furniture",
			across.x < 3.0)

	print("[SHOPS] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
