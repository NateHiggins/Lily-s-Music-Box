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

	print("[SHOPS] RESULT: %s (%d failures)"
			% ["PASS" if _fails == 0 else "FAIL", _fails])
	get_tree().quit(_fails)
