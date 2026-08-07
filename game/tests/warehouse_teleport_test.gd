extends Node
## Does the debug panel's warehouse teleport actually hold a player?
##
## The button's code path is four lines; what it cannot show from the
## panel is what physics does NEXT. This runs those same four lines
## against the real player body and then watches ninety physics frames:
## if the shed's collision works the player stands at the viewing stand;
## if anything snaps them home or the floor is fiction, the position
## drifts and the test says so with numbers instead of a shrug.

func _ready() -> void:
	RealityState.persistence_enabled = false
	RealityState.reset_campaign_for_tests()
	GameBoot.launch_mode = GameBoot.LaunchMode.DEBUG
	var root: Node3D = load(
			"res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	await get_tree().create_timer(1.5).timeout
	if root.get("warehouse") == null:
		print("[WHTP] FAIL: warehouse is null in DEBUG launch")
		get_tree().quit(1)
		return
	var to: Vector3 = root.warehouse.viewing_stand()
	print("[WHTP] viewing_stand = %v" % to)
	root.player.global_position = to
	root.player.velocity = Vector3.ZERO
	for i in 90:
		await get_tree().physics_frame
		if i % 30 == 29:
			print("[WHTP] frame %d pos %v on_floor %s"
					% [i + 1, root.player.global_position,
					   root.player.is_on_floor()])
	var p: Vector3 = root.player.global_position
	# The body's origin is at its FEET: standing on the slab means y is
	# ~0, not 1.7. The first criterion demanded the spawn height and
	# failed a fully successful teleport for landing.
	var ok: bool = p.distance_to(to) < 2.5 and p.y > -0.5
	print("[WHTP] RESULT: %s (final %v, target %v)"
			% ["PASS" if ok else "FAIL", p, to])
	get_tree().quit(0 if ok else 1)
