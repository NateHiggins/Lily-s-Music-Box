extends Node
## Throwaway probe (not shipped): telemetry for the street-exit route.

var root: Node3D


func _ready() -> void:
	root = load("res://scenes/building/orison_root.tscn").instantiate()
	add_child(root)
	_run()


func _run() -> void:
	await get_tree().create_timer(1.2).timeout
	var pl: PlayerController = root.player
	pl.global_position = Vector3(0.0, 0.15, 9.0)
	pl.velocity = Vector3.ZERO
	var street_door: DoorProp = null
	for c in root.get_children():
		if c is DoorProp and c.global_position.z > 9.5 \
				and absf(c.global_position.x) < 1.0 \
				and c.global_position.y < 1.0:
			street_door = c
	if street_door == null:
		print("PROBE no street door")
		get_tree().quit(1)
		return
	print("PROBE door name=%s pos=%s yaw=%.1f leaf=%s" % [street_door.name,
			street_door.global_position, rad_to_deg(street_door.rotation.y),
			street_door.leaf_state])
	if not street_door.open:
		street_door.interact(null)
		await get_tree().create_timer(0.8).timeout
	var body: AnimatableBody3D = street_door._body
	print("PROBE leaf open=%s body_rot=%.1f body_gpos=%s" % [street_door.open,
			rad_to_deg(body.rotation.y), body.global_position])
	# leaf tip position in world
	var tip := body.global_transform * Vector3(street_door.width, 1.0, 0.0)
	print("PROBE leaf tip world=%s hinge=%s" % [tip, body.global_position])
	print("PROBE player after open pos=%s" % pl.global_position)
	# scan: surface height + hit object along the exit line
	var space := get_viewport().world_3d.direct_space_state
	var zf := 8.6
	while zf < 12.8:
		var q := PhysicsRayQueryParameters3D.create(
				Vector3(0.0, 2.0, zf), Vector3(0.0, -3.0, zf))
		var hit := space.intersect_ray(q)
		if hit.is_empty():
			print("PROBE scan z=%.2f  no floor" % zf)
		else:
			var nm: String = hit.collider.name
			var par := hit.collider.get_parent()
			if par:
				nm = par.name + "/" + nm
			print("PROBE scan z=%.2f  top=%.3f  %s" % [zf, hit.position.y, nm])
		zf += 0.2
	var t := 0.0
	while t < 6.0:
		var pos := Vector2(pl.global_position.x, pl.global_position.z)
		if pos.distance_to(Vector2(0.0, 12.5)) < 0.3:
			break
		var dir := (Vector2(0.0, 12.5) - pos).normalized()
		pl.autopilot = Vector3(dir.x, 0, dir.y)
		await get_tree().create_timer(0.1).timeout
		t += 0.1
		if int(t * 10.0) % 5 == 0:
			print("PROBE t=%.1f pos=%s vel=%s" % [t, pl.global_position,
					pl.velocity])
	pl.autopilot = Vector3.ZERO
	print("PROBE final pos=%s" % pl.global_position)
	get_tree().quit(0)
