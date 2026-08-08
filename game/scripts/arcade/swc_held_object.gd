class_name SwcHeldObject
extends RefCounted
## What the player is holding, and what comes out of it.
##
## The viewmodel is the most-looked-at surface in a first-person game: it is in
## front of the camera every frame. A row of cabinets that redressed the walls,
## the light and the bodies and still handed the player the same grey pistol
## would give itself away in the first second of every machine.
##
## So a racing cabinet hands you a wheel and throws sparks, a management sim
## hands you a clipboard and issues a memo, and a dance cabinet hands you a
## microphone and throws a note. All three do twenty-four points of damage at
## four hundred and twenty rounds per minute, hitscan, identical spread. The
## object and the projectile are cosmetic to the last decimal - the shot has
## already landed by the time the projectile has left the frame, and the
## projectile is purely something to look at on its way to a hit that already
## happened.
##
## Built from `world_bible.held_object`. A package without one falls back to the
## graybox stub, which is the correct answer rather than a failure.

const _FALLBACK := {
	"form": "sidearm", "grip": "one_hand", "projectile": "bullet",
	"projectile_color": "#e8e4d8", "projectile_speed_mps": 46.0,
	"projectile_scale_m": 0.06, "trail": "line", "muzzle_flash": true,
}

## Where each grip sits relative to the camera. A wheel is low and centred; a
## lantern is out at arm's length; fists are wide and close.
const _GRIPS := {
	"one_hand": Vector3(0.22, -0.19, -0.38),
	"reading": Vector3(0.20, -0.22, -0.46),
	"two_hand": Vector3(0.04, -0.24, -0.44),
	"low_mount": Vector3(0.0, -0.34, -0.46),
	"shoulder": Vector3(0.16, -0.12, -0.30),
	"none": Vector3(0.20, -0.22, -0.34),
}


static func spec(package_held: Dictionary) -> Dictionary:
	var out := _FALLBACK.duplicate()
	for key in package_held:
		out[key] = package_held[key]
	return out


static func colour_of(held: Dictionary) -> Color:
	var text := String(held.get("projectile_color", "#e8e4d8"))
	return Color(text) if text.begins_with("#") else Color(0.91, 0.89, 0.85)


## Replace whatever the camera is currently holding.
static func build_viewmodel(camera: Camera3D, held: Dictionary) -> Node3D:
	var existing := camera.get_node_or_null("WeaponViewmodel")
	if existing != null:
		camera.remove_child(existing)
		existing.queue_free()

	var root := Node3D.new()
	root.name = "WeaponViewmodel"
	root.position = _GRIPS.get(String(held.get("grip", "one_hand")), _GRIPS["one_hand"])
	camera.add_child(root)

	var accent := colour_of(held)
	match String(held.get("form", "sidearm")):
		"wheel":
			# A rim and two spokes, seen from behind as a driver would.
			var rim := _torus(root, 0.14, 0.014, Color(0.10, 0.10, 0.11))
			rim.rotation.x = deg_to_rad(74.0)
			for angle in [-0.6, 0.6]:
				var spoke := _box(root, Vector3(0.12, 0.012, 0.02), Color(0.42, 0.43, 0.46))
				spoke.rotation.z = angle
				spoke.position.y = -0.02
			_box(root, Vector3(0.05, 0.04, 0.03), accent).position = Vector3(0.0, -0.02, 0.0)
		"microphone":
			_cylinder(root, 0.014, 0.014, 0.16, Color(0.16, 0.16, 0.18)).rotation.x = deg_to_rad(64.0)
			var head := _sphere(root, 0.032, Color(0.55, 0.56, 0.60))
			head.position = Vector3(0.0, 0.07, -0.05)
			_sphere(root, 0.012, accent).position = Vector3(0.0, 0.07, -0.05)
		"clipboard":
			# Held at reading angle, not flat to the lens. Laid back any further and
			# an A4 board 40 cm from the camera becomes the entire lower frame.
			var tilt := deg_to_rad(-32.0)
			var board := _box(root, Vector3(0.15, 0.20, 0.008), Color(0.76, 0.70, 0.55))
			board.rotation = Vector3(tilt, deg_to_rad(15.0), 0.0)
			var paper := _box(root, Vector3(0.128, 0.172, 0.004), Color(0.94, 0.93, 0.88))
			paper.rotation = board.rotation
			paper.position = Vector3(-0.002, 0.004, -0.006)
			var clip := _box(root, Vector3(0.055, 0.018, 0.012), Color(0.62, 0.63, 0.66))
			clip.rotation = board.rotation
			clip.position = Vector3(0.0, 0.086, -0.026)
		"sword":
			_box(root, Vector3(0.026, 0.42, 0.010), Color(0.72, 0.74, 0.78)).position = Vector3(0.0, 0.16, -0.06)
			_box(root, Vector3(0.11, 0.020, 0.024), accent).position = Vector3(0.0, -0.03, 0.0)
			_cylinder(root, 0.016, 0.016, 0.10, Color(0.24, 0.16, 0.12))
		"wand":
			_cylinder(root, 0.010, 0.014, 0.30, Color(0.28, 0.20, 0.14)).rotation.x = deg_to_rad(58.0)
			var tip := _sphere(root, 0.026, accent)
			tip.position = Vector3(0.0, 0.11, -0.10)
			_emissive(tip, accent, 3.0)
		"yoke":
			var bar := _box(root, Vector3(0.30, 0.024, 0.024), Color(0.16, 0.17, 0.19))
			bar.position = Vector3(0.0, -0.02, 0.0)
			for side in [-1.0, 1.0]:
				var handle := _cylinder(root, 0.020, 0.020, 0.09, Color(0.10, 0.10, 0.12))
				handle.position = Vector3(side * 0.15, 0.02, 0.0)
			_box(root, Vector3(0.05, 0.03, 0.012), accent).position = Vector3(0.0, 0.0, -0.02)
		"racket":
			var head := _torus(root, 0.11, 0.010, Color(0.90, 0.90, 0.86))
			head.rotation.x = deg_to_rad(80.0)
			head.position = Vector3(0.0, 0.16, -0.06)
			_cylinder(root, 0.014, 0.016, 0.20, Color(0.20, 0.20, 0.22)).rotation.x = deg_to_rad(58.0)
		"gloves":
			for side in [-1.0, 1.0]:
				var fist := _box(root, Vector3(0.09, 0.08, 0.11), accent)
				fist.position = Vector3(side * 0.13 - 0.20, 0.0, 0.0)
				var wrap := _box(root, Vector3(0.095, 0.03, 0.115), Color(0.88, 0.86, 0.80))
				wrap.position = Vector3(side * 0.13 - 0.20, -0.05, 0.0)
		"lantern":
			var cage := _box(root, Vector3(0.09, 0.13, 0.09), Color(0.22, 0.20, 0.18))
			cage.position = Vector3(0.0, -0.02, -0.06)
			var flame := _sphere(root, 0.030, accent)
			flame.position = Vector3(0.0, -0.02, -0.06)
			_emissive(flame, accent, 2.4)
			_cylinder(root, 0.006, 0.006, 0.10, Color(0.30, 0.28, 0.26)).position = Vector3(0.0, 0.08, -0.06)
		"pointer":
			_cylinder(root, 0.008, 0.012, 0.20, Color(0.92, 0.90, 0.86)).rotation.x = deg_to_rad(58.0)
			var nib := _sphere(root, 0.016, accent)
			nib.position = Vector3(0.0, 0.07, -0.07)
		"blaster":
			_box(root, Vector3(0.06, 0.05, 0.24), Color(0.20, 0.22, 0.26)).position = Vector3(0.0, 0.0, -0.06)
			_box(root, Vector3(0.04, 0.10, 0.05), Color(0.15, 0.16, 0.19)).position = Vector3(0.0, -0.06, 0.03)
			var vent := _box(root, Vector3(0.02, 0.014, 0.10), accent)
			vent.position = Vector3(0.0, 0.03, -0.06)
			_emissive(vent, accent, 2.2)
		_:
			# The graybox stub: what a package that says nothing gets.
			_box(root, Vector3(0.08, 0.08, 0.28), Color(0.22, 0.23, 0.26)).position = Vector3(0.0, 0.0, -0.08)
	return root


## A projectile, launched along a shot that has already been resolved.
##
## It is chasing a decision, not making one: `try_fire` did the raycast and the
## damage the instant the trigger went down. This travels for show and deletes
## itself on arrival, so a slow, fat, sparkly memo and a fast tracer are exactly
## as lethal as each other.
static func launch(parent: Node3D, held: Dictionary, from: Vector3, to: Vector3) -> void:
	var kind := String(held.get("projectile", "bullet"))
	if kind == "shock":
		# Contact work. A ring at the hit rather than something crossing the room.
		_impact_ring(parent, to, colour_of(held))
		return

	var body := Node3D.new()
	body.name = "Projectile"
	parent.add_child(body)
	body.global_position = from

	var accent := colour_of(held)
	var scale_m := float(held.get("projectile_scale_m", 0.06))
	var mesh: MeshInstance3D
	match kind:
		"memo":
			mesh = _box(body, Vector3(scale_m * 1.5, scale_m * 1.1, 0.004), Color(0.95, 0.94, 0.90))
		"block":
			mesh = _box(body, Vector3(scale_m, scale_m, scale_m), accent)
		"ball":
			mesh = _sphere(body, scale_m * 0.5, accent)
		"note":
			mesh = _box(body, Vector3(scale_m * 0.35, scale_m, scale_m * 0.35), accent)
			_emissive(mesh, accent, 2.4)
		"ember", "spark":
			mesh = _sphere(body, scale_m * 0.5, accent)
			_emissive(mesh, accent, 3.0)
		"tracer", "bolt":
			mesh = _box(body, Vector3(scale_m * 0.4, scale_m * 0.4, scale_m * 3.0), accent)
			_emissive(mesh, accent, 3.4)
		_:
			mesh = _sphere(body, scale_m * 0.45, accent)

	if mesh != null and kind in ["tracer", "bolt"]:
		body.look_at_from_position(from, to, Vector3.UP)

	var speed := maxf(4.0, float(held.get("projectile_speed_mps", 46.0)))
	var travel := from.distance_to(to)
	var tween := parent.create_tween()
	tween.tween_property(body, "global_position", to, travel / speed)
	if kind == "memo":
		# Paper tumbles. It still arrives exactly where the hitscan already did.
		tween.parallel().tween_property(
			body, "rotation", Vector3(0.0, TAU * 1.5, TAU * 0.5), travel / speed
		)
	tween.tween_callback(body.queue_free)


static func _impact_ring(parent: Node3D, at: Vector3, accent: Color) -> void:
	var ring := MeshInstance3D.new()
	var torus := TorusMesh.new()
	torus.inner_radius = 0.06
	torus.outer_radius = 0.10
	ring.mesh = torus
	ring.material_override = _material(accent)
	_emissive(ring, accent, 3.0)
	parent.add_child(ring)
	ring.global_position = at
	var tween := parent.create_tween()
	tween.tween_property(ring, "scale", Vector3.ONE * 3.0, 0.18)
	tween.parallel().tween_property(ring, "transparency", 1.0, 0.18)
	tween.tween_callback(ring.queue_free)


# ------------------------------------------------------------------ primitives


static func _material(colour: Color) -> StandardMaterial3D:
	var material := StandardMaterial3D.new()
	material.albedo_color = colour
	material.roughness = 0.55
	return material


static func _emissive(instance: MeshInstance3D, colour: Color, strength: float) -> void:
	var material := instance.material_override as StandardMaterial3D
	if material == null:
		return
	material.emission_enabled = true
	material.emission = colour
	material.emission_energy_multiplier = strength


static func _box(parent: Node3D, size: Vector3, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := BoxMesh.new()
	mesh.size = size
	instance.mesh = mesh
	instance.material_override = _material(colour)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _sphere(parent: Node3D, radius: float, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := SphereMesh.new()
	mesh.radius = radius
	mesh.height = radius * 2.0
	mesh.radial_segments = 10
	mesh.rings = 6
	instance.mesh = mesh
	instance.material_override = _material(colour)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _cylinder(parent: Node3D, top: float, bottom: float, height: float,
		colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := CylinderMesh.new()
	mesh.top_radius = top
	mesh.bottom_radius = bottom
	mesh.height = height
	mesh.radial_segments = 10
	instance.mesh = mesh
	instance.material_override = _material(colour)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance


static func _torus(parent: Node3D, radius: float, tube: float, colour: Color) -> MeshInstance3D:
	var instance := MeshInstance3D.new()
	var mesh := TorusMesh.new()
	mesh.inner_radius = maxf(0.001, radius - tube)
	mesh.outer_radius = radius + tube
	mesh.rings = 16
	instance.mesh = mesh
	instance.material_override = _material(colour)
	instance.cast_shadow = GeometryInstance3D.SHADOW_CASTING_SETTING_OFF
	parent.add_child(instance)
	return instance
